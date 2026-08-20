package
{
   /**
    * Phase 2 生存层控制器 v0.3.0 —— 瞄准回避重做版。
    *
    * v0.3 新增三维决策（用户决策 2026-08-18）：
    *  1. 智能分层 intel：SAPS(人形+亡灵)/DRONE(机械·僵硬)/BEAST(动物·0)。
    *     BEAST 完全不接入本层（躲避/掩体/撤退全关，原版行为），
    *     也不参与传播联动（见 TdfcMain.intelTier）。
    *  2. 移动形态 mobility：空中(isFly)→弹线垂直的 2D 机动（爬升/俯冲，
    *     取真垂直向量）；水中(isPlav)→2D 回避；地面→跳/跑。
    *  3. 武器角色 weaponRole：SNIPER→后撤/找掩体不跳；SHOTGUN→前冲+规避；
    *     GUN→躲射节奏；THROWER→扔完走；MELEE→纯接近+规避。
    *  4. 精准接管（仅智能层）：每帧写 owner.weaponSkill（散布公式
    *     deviation/skillConf/(weaponSkill+0.01) 的除数）——移动/躲时低倍率
    *     （打不准），站桩开火窗口（settleT）恢复高倍率精准。sniper 恒准。
    *     mazil 由原版 attack() 每发重写，不可作杠杆；weaponSkill 不会被
    *     原版逐发覆盖（1.02 反编译确认）。
    *
    * 其余机制（cel 直写 / dy 起跳 / 行为互斥优先级）沿用 v0.2.2。
    * 全 public API，不读写 internal。
    */
   public class TacticalCtrl
   {
      // ---- 武器角色 ----
      private static const R_MELEE:int = 0;
      private static const R_GUN:int = 1;
      private static const R_SNIPER:int = 2;
      private static const R_SHOTGUN:int = 3;
      private static const R_THROWER:int = 4;
      private static const R_MAGIC:int = 5;

      private static const TOL_RAD:Number = Config.AIM_TOL_DEG * Math.PI / 180;
      private static const COVER_DISTS:Array = [60, 120, 180];
      private static const HIT_WINDOW:int = 300;       // 受击窗口（撤退触发）

      /** 每帧更新单个单位的 Phase 2 行为。返回 true 表示本帧 TDFC 发出了移动指令。 */
      public static function update(u:*, st:TacticalState, gg:*, loc:*, tick:int):Boolean
      {
         var px:Number = TdfcMain.num(gg, "X", 0);
         var py:Number = TdfcMain.num(gg, "Y", 0);
         var ux:Number = TdfcMain.num(u, "X", 0);
         var uy:Number = TdfcMain.num(u, "Y", 0);
         var ucls:String = TdfcMain.shortClass(u);
         var hp:Number = TdfcMain.num(u, "hp", 0);
         var mhp:Number = TdfcMain.num(u, "maxhp", 1);
         var hpRatio:Number = mhp > 0 ? hp / mhp : 1;
         var inRetreat:Boolean = st.retreatT > 0;
         var inCover:Boolean = st.coverPhase > 0;

         // ---- 智能门控：BEAST 完全不接入 ----
         if (TdfcMain.intelTier(ucls) == 2)
         {
            st.dodgeT = 0; st.threatT = 0; st.coverPhase = 0;
            st.retreatT = 0; st.aimExposed = 0; st.settleT = 0;
            return false;
         }

         // ---- 持久运动速度（供精准接管与 idle 判定）----
         var speed:Number = Math.abs(TdfcMain.num(u, "dx", 0))
            + Math.abs(TdfcMain.num(u, "dy", 0));

         // ---- 武器角色与智能层 ----
         var role:int = weaponRole(u);
         var tier:int = TdfcMain.intelTier(ucls); // 0 SAPS 1 DRONE
         var allowTactical:Boolean = !inCover && !inRetreat && st.threatT <= 0;

         // ---------- 精准接管（仅智能层；SNIPER 恒准，MELEE 无关）----------
         if (tier <= 1 && role != R_MELEE)
         {
            if (st.baseSkill <= 0)
            {
               st.baseSkill = TdfcMain.num(u, "weaponSkill", 1);
               if (st.baseSkill <= 0.01)
               {
                  st.baseSkill = 1;
               }
            }
            var accurate:Boolean = (role == R_SNIPER) || (st.settleT > 0);
            if (!accurate)
            {
               var busy:Boolean = st.dodgeT > 0 || st.threatT > 0 || inCover || inRetreat
                  || speed > 3;
               if (busy)
               {
                  try { u["weaponSkill"] = st.baseSkill * Config.ACC_MOVE_MULT; }
                  catch (e:Error) {}
               }
               else
               {
                  try { u["weaponSkill"] = st.baseSkill; }
                  catch (e:Error) {}
               }
            }
            else
            {
               try { u["weaponSkill"] = st.baseSkill; }
               catch (e:Error) {}
            }
         }

         // ---- 活跃门控 ----
         var active:Boolean = (u["celUnit"] === gg)
            || (tick - st.lastHitTick) < 300
            || (tick - st.lastSeenTick) < 300;
         if (!active)
         {
            st.dodgeT = 0; st.threatT = 0; st.coverPhase = 0;
            st.retreatT = 0; st.aimExposed = 0; st.settleT = 0;
            return false;
         }

         // ===== 开火窗口状态机（settle）=====
         if (st.settleT > 0)
         {
            st.settleT--;
         }
         else
         {
            var aimedNow:Boolean = (gg["currentWeapon"] != null);
            if (aimedNow)
            {
               st.aimIdle = 0;
               // 顶着瞄准"放冷枪"：小概率强行站桩开一枪
               if (role == R_GUN || role == R_MAGIC)
               {
                  if (Math.random() < Config.SETTLE_FORCE_CHANCE && st.dodgeT <= 0)
                  {
                     st.settleT = Config.ACC_SETTLE_TICKS;
                     TdfcLog.line("aim", "SETTLE force " + TdfcMain.tag(u));
                  }
               }
            }
            else
            {
               st.aimIdle++;
               if (st.aimIdle >= Config.ACC_SETTLE_IDLE && role != R_MELEE
                  && Math.random() < 0.5)
               {
                  st.settleT = Config.ACC_SETTLE_TICKS;
                  st.aimIdle = 0;
                  TdfcLog.line("aim", "SETTLE idle " + TdfcMain.tag(u));
               }
            }
         }

         // ===== D. 撤退（优先于掩体：低血时离开而不是就近躲）=====
         if (Config.ENABLE_RETREAT && st.threatT <= 0 && st.dodgeT <= 0
            && tier <= 1 && doctRetreat(ucls, role) > 0)
         {
            if (!inRetreat && hpRatio < Config.RETREAT_RATIO
               && (tick - st.lastHitTick) < HIT_WINDOW
               && Los.toPlayer(u, loc, gg, 900))
            {
               var hadCover:Boolean = inCover;
               if (hadCover)
               {
                  st.retreatX = st.coverX;
                  st.retreatY = st.coverY;
                  st.coverPhase = 0;
               }
               else
               {
                  var side:Number = (ux >= px) ? 1 : -1;
                  var rx:Number = ux + side * Config.RETREAT_DIST;
                  var ry:Number = uy;
                  if (tileSolid(loc, rx, ry))
                  {
                     rx = ux + side * 140;
                     if (tileSolid(loc, rx, ry))
                     {
                        rx = ux - side * 120;
                     }
                  }
                  st.retreatX = rx;
                  st.retreatY = ry;
               }
               st.retreatT = Config.RETREAT_MAX;
               TdfcLog.line("retreat", "GO " + TdfcMain.tag(u)
                  + " hp=" + int(hp) + "/" + int(mhp)
                  + (hadCover ? " (from cover)" : "")
                  + " to " + int(st.retreatX) + "," + int(st.retreatY));
            }
            if (inRetreat)
            {
               st.retreatT--;
               if (dist2(u, gg) < Config.BACKS_BREACH * Config.BACKS_BREACH)
               {
                  st.retreatT = 0;
                  TdfcLog.line("retreat", "ABORT breach " + TdfcMain.tag(u));
               }
               else if (st.retreatT <= 0)
               {
                  TdfcLog.line("retreat", "END " + TdfcMain.tag(u));
                  if (Config.ENABLE_COVER && tier <= 1
                     && hpRatio < Config.RETREAT_RATIO * 1.4
                     && tick - st.lastCoverTick >= Config.COVER_CD)
                  {
                     var cpR:* = findCoverPoint(loc, u, ux, uy, px, py);
                     if (cpR != null)
                     {
                        st.coverPhase = 1;
                        st.coverT = Config.COVER_MAX_TICKS;
                        st.coverX = cpR.x;
                        st.coverY = cpR.y;
                        st.peekT = Config.PEEK_MIN;
                        st.peekOn = false;
                        TdfcLog.line("cover", "SEEK(after retreat) " + TdfcMain.tag(u));
                     }
                  }
               }
            }
         }

         // ===== A. 瞄准反应（按武器角色分派）=====
         if (Config.ENABLE_DODGE_AIM && allowTactical && tier <= 1
            && st.settleT <= 0 && st.dodgeT <= 0)
         {
            var w:* = gg["currentWeapon"];
            var wrot:Number = NaN;
            if (w != null && TdfcMain.num(w, "tip", 0) >= 3)
            {
               wrot = TdfcMain.num(w, "rot", NaN);
            }
            var aimed:Boolean = playerAimingAt(u, gg, loc, wrot, ux, uy, px, py);
            if (aimed)
            {
               st.aimExposed++;
            }
            else
            {
               st.aimExposed = 0;
            }
            if (aimed && !isNaN(wrot)
               && Math.random() < dodgeChance(ucls, role, tier))
            {
               st.lastDodgeTick = tick;
               dispatchDodge(u, st, loc, role, wrot, px, py, ux, uy, tick);
            }
            if (st.dodgeT > 0)
            {
               st.dodgeT--;
            }
         }

         // ===== B. 慢弹威胁躲避 =====
         if (Config.ENABLE_DODGE_THREAT && allowTactical && tier <= 1)
         {
            st.threatScan--;
            if (st.threatScan <= 0)
            {
               st.threatScan = Config.THREAT_SCAN_CD;
               if (st.threatT <= 0 && st.settleT <= 0)
               {
                  var t:* = findThreat(loc, u, ux, uy);
                  if (t != null)
                  {
                     st.threatT = Config.THREAT_DODGE_TICKS;
                     st.lastDodgeTick = tick;
                     // 冲量：水平离开弹体（飞行/游泳带垂直分量）；平射顺带一跳
                     var bX:Number = TdfcMain.num(t, "X", ux);
                     var bY:Number = TdfcMain.num(t, "Y", uy);
                     var awayX:Number = (ux >= bX) ? 1 : -1;
                     var spd2:Number = TdfcMain.num(u, "maxSpeed", 10);
                     if (spd2 <= 0.5)
                     {
                        spd2 = 10;
                     }
                     st.threatVX = awayX * spd2;
                     if (u["isFly"] == true || u["isPlav"] == true)
                     {
                        var rot2:Number = TdfcMain.num(t, "rot", 0);
                        st.threatVY = Math.cos(rot2) * spd2 * 0.7;
                     }
                     else
                     {
                        st.threatVY = 0;
                        if (Math.abs(Math.sin(TdfcMain.num(t, "rot", 0)))
                           < Config.DODGE_FLAT_SIN && u["stay"] == true)
                        {
                           hopKick(u);
                        }
                     }
                     TdfcLog.line("threat", "PROJ " + TdfcMain.tag(u)
                        + " vx=" + int(st.threatVX) + " vy=" + int(st.threatVY));
                  }
               }
            }
            if (st.threatT > 0)
            {
               st.threatT--;
            }
         }

         // ===== C. 掩体（低血由撤退接管）=====
         if (Config.ENABLE_COVER && !inRetreat && st.threatT <= 0 && st.dodgeT <= 0
            && tier <= 1 && doctCover(ucls, role) > 0)
         {
            var hitRecently:Boolean = (tick - st.lastHitTick) < 90;
            if (st.coverPhase == 0
               && hpRatio >= Config.RETREAT_RATIO
               && (hitRecently || st.aimExposed >= Config.EXPOSED_TICKS)
               && tick - st.lastCoverTick >= Config.COVER_CD)
            {
               var cp:* = findCoverPoint(loc, u, ux, uy, px, py);
               if (cp != null)
               {
                  st.coverPhase = 1;
                  st.coverT = Config.COVER_MAX_TICKS;
                  st.coverX = cp.x;
                  st.coverY = cp.y;
                  st.peekT = Config.PEEK_MIN;
                  st.peekOn = false;
                  TdfcLog.line("cover", "SEEK " + TdfcMain.tag(u)
                     + " to " + int(cp.x) + "," + int(cp.y));
               }
            }
            if (st.coverPhase == 1)
            {
               st.coverT--;
               var ddx:Number = st.coverX - ux;
               var ddy:Number = st.coverY - uy;
               if (ddx * ddx + ddy * ddy < Config.COVER_ARRIVE * Config.COVER_ARRIVE
                  || st.coverT <= 0)
               {
                  st.coverPhase = 2;
                  TdfcLog.line("cover", "HIDE " + TdfcMain.tag(u));
               }
            }
            else if (st.coverPhase == 2)
            {
               st.coverT--;
               st.peekT--;
               if (st.peekT <= 0)
               {
                  st.peekT = Config.PEEK_MIN
                     + Math.floor(Math.random() * (Config.PEEK_MAX - Config.PEEK_MIN + 1));
                  st.peekOn = !st.peekOn;
                  if (st.peekOn)
                  {
                     TdfcLog.line("cover", "PEEK " + TdfcMain.tag(u));
                  }
               }
               if (dist2(u, gg) < Config.BREACH_RANGE * Config.BREACH_RANGE
                  || st.coverT <= 0)
               {
                  st.coverPhase = 0;
                  st.lastCoverTick = tick;
                  TdfcLog.line("cover", "EXIT " + TdfcMain.tag(u));
               }
            }
         }

         // ===== 写入：位移(cel) / 冲量(dx,dy) / 瞄准锚定 三分层 =====
         var acted:Boolean = false;
         var relocating:Boolean = false;
         if (inRetreat)
         {
            writeCel(u, st.retreatX, st.retreatY);
            relocating = true;
            acted = true;
         }
         else if (st.coverPhase > 0)
         {
            if (st.coverPhase == 2 && st.peekOn && u["currentWeapon"] != null)
            {
               writeCel(u, px, py);
            }
            else
            {
               writeCel(u, st.coverX, st.coverY);
            }
            relocating = true;
            acted = true;
         }
         else if (st.relocT > 0)
         {
            writeCel(u, st.relocX, st.relocY);
            st.relocT--;
            relocating = true;
            acted = true;
         }
         // 瞄准锚定：非位移中、交战中的智能单位，枪口永远对准玩家
         if (!relocating && u["celUnit"] === gg && tier <= 1)
         {
            writeCel(u, px, py);
         }
         // 冲量：躲避/威胁只写 dx/dy（不写 cel，避免翻转抽搐 + 枪口乱甩）
         if (st.dodgeT > 0)
         {
            writeVel(u, st.dodgeVX, st.dodgeVY);
            acted = true;
         }
         if (st.threatT > 0)
         {
            writeVel(u, st.threatVX, st.threatVY);
            acted = true;
         }
         return acted;
      }

      // ============ 角色分派（瞄准反应） ============

      /**
       * 按武器角色与移动形态执行躲避动作。
       * v0.3.2 核心变更：躲避/威胁一律为**冲量**（写 dx/dy 几下，不写 cel）——
       * cel 是移动+瞄准共用通道，持续写躲避点会被原版 findCel 拉回 → 翻转抽搐
       * + 武器乱甩。冲量躲避期间 cel 保持瞄准玩家（枪口对人）。
       * 只有"正经位移"（狙击走位/掩体/撤退）才写 cel。
       * 弄冲量方向：空中(isFly)/水中(isPlav)取弹线真垂直向量；地面=水平离开玩家(+跳跃)。
       */
      private static function dispatchDodge(u:*, st:TacticalState, loc:*,
         role:int, wrot:Number, px:Number, py:Number, ux:Number, uy:Number,
         tick:int):void
      {
         var isFly:Boolean = (u["isFly"] == true);
         var isPlav:Boolean = (u["isPlav"] == true);
         var onGround:Boolean = (u["stay"] == true);
         var spd:Number = TdfcMain.num(u, "maxSpeed", 10);
         if (spd <= 0.5)
         {
            spd = 10;
         }

         // 弹线垂直向量（真 2D 躲避方向；旋转 90°）
         var pdx:Number = -Math.sin(wrot);
         var pdy:Number = Math.cos(wrot);

         if (role == R_SNIPER)
         {
            // 狙击：正经位移（cel）——优先掩体，无则直线后撤；不跳不冲量
            if (tick - st.lastSniperTick >= 90)
            {
               st.lastSniperTick = tick;
               var cp:* = findCoverPoint(loc, u, ux, uy, px, py);
               if (cp != null)
               {
                  st.relocT = Config.DODGE_TICKS + 12;
                  st.relocX = cp.x;
                  st.relocY = cp.y;
                  TdfcLog.line("dodge", "SNIPER cover " + TdfcMain.tag(u));
                  return;
               }
            }
            var rSide:Number = (ux >= px) ? 1 : -1;
            st.relocT = Config.DODGE_TICKS + 6;
            st.relocX = ux + rSide * 160;
            st.relocY = uy;
            TdfcLog.line("dodge", "SNIPER retreat " + TdfcMain.tag(u));
            return;
         }

         // 冲量速度基础：水平分量（地面）或真垂直(飞行/游泳)
         var speedX:Number = 0;
         var speedY:Number = 0;

         if (isFly)
         {
            // 空中机动：弹线真垂直向量（高度+水平）
            speedX = pdx * spd;
            speedY = pdy * spd * 0.7;
            st.dodgeT = Config.DODGE_TICKS;
            st.dodgeVX = speedX;
            st.dodgeVY = speedY;
            TdfcLog.line("dodge", "FLY " + TdfcMain.tag(u));
            return;
         }
         if (isPlav)
         {
            speedX = pdx * spd;
            speedY = pdy * spd;
            st.dodgeT = Config.DODGE_TICKS;
            st.dodgeVX = speedX;
            st.dodgeVY = speedY;
            TdfcLog.line("dodge", "SWIM " + TdfcMain.tag(u));
            return;
         }

         // ---- 地面 ----
         var flat:Boolean = Math.abs(Math.sin(wrot)) < Config.DODGE_FLAT_SIN;
         if (role == R_SHOTGUN || role == R_MELEE)
         {
            // 霰弹/近战：向玩家方向冲（前冲/逼近），平射顺带一跳
            var toP:Number = (px >= ux) ? 1 : -1;
            speedX = toP * spd * 1.1;
            if (flat && onGround)
            {
               hopKick(u);
            }
            st.dodgeT = Config.DODGE_TICKS;
            st.dodgeVX = speedX;
            st.dodgeVY = 0;
            TdfcLog.line("dodge", (role == R_SHOTGUN ? "SHOTGUN" : "MELEE")
               + " charge " + TdfcMain.tag(u));
            return;
         }

         // 步枪/投掷/魔法：几何——平射→跳（带一点后退分量），斜射→水平离开
         var away:Number = (ux >= px) ? 1 : -1;
         var hopDo:Boolean = flat && onGround;
         speedX = away * spd * (hopDo ? 0.5 : 1.0);
         if (hopDo)
         {
            hopKick(u);
         }
         st.dodgeT = Config.DODGE_TICKS;
         st.dodgeVX = speedX;
         st.dodgeVY = 0;
         TdfcLog.line("dodge", "GROUND " + TdfcMain.tag(u)
            + " hop=" + (hopDo ? 1 : 0));
      }

      // ============ 武器角色与概率 ============

      /** 武器角色：由 public 武器字段推断（tip/kol/rapid/precision/sniper）。 */
      private static function weaponRole(u:*):int
      {
         var w:* = u["currentWeapon"];
         if (w == null)
         {
            return R_MELEE;
         }
         var tip:Number = TdfcMain.num(w, "tip", 0);
         if (tip < 3)
         {
            return R_MELEE;
         }
         if (tip == 4)
         {
            return R_THROWER;
         }
         if (tip == 5)
         {
            return R_MAGIC;
         }
         if (TdfcMain.num(w, "kol", 1) > 1)
         {
            return R_SHOTGUN;
         }
         if (u["sniper"] == true
            || (TdfcMain.num(w, "rapid", 5) <= 2 && TdfcMain.num(w, "precision", 0) >= 60))
         {
            return R_SNIPER;
         }
         return R_GUN;
      }

      /** 触发概率：智能层人形 0.4；机械僵硬 0.15；按角色微调。 */
      private static function dodgeChance(cls:String, role:int, tier:int):Number
      {
         if (tier == 1)
         {
            return 0.15; // DRONE 僵硬
         }
         switch (role)
         {
            case R_SHOTGUN: return 0.6;
            case R_MELEE:   return 0.5;
            case R_THROWER: return 0.4;
            case R_SNIPER:  return 0.5; // 走位频率
            default:        return 0.4;
         }
      }

      /** 撤退比例（按类近似原 doctrine）；BEAST 由外部 intel 门控。 */
      private static function doctRetreat(cls:String, role:int):Number
      {
         if (role == R_MELEE)
         {
            return 0.15; // 近战型少撤
         }
         if (role == R_SNIPER)
         {
            return 0.3;
         }
         return 0.3;
      }

      /** 掩体可用性：近战不掩体；其余可用。 */
      private static function doctCover(cls:String, role:int):Number
      {
         if (role == R_MELEE)
         {
            return 0;
         }
         return 1;
      }

      // ============ 玩家瞄准检测 ============

      /** 玩家武器瞄准线是否指向本敌人（弹道角 wrot、距离、LOS）。 */
      private static function playerAimingAt(u:*, gg:*, loc:*, wrot:Number,
         ux:Number, uy:Number, px:Number, py:Number):Boolean
      {
         if (isNaN(wrot))
         {
            return false;
         }
         var w:* = gg["currentWeapon"];
         if (w == null)
         {
            return false;
         }
         var wx:Number = TdfcMain.num(w, "X", px);
         var wy:Number = TdfcMain.num(w, "Y", py);
         var dx:Number = ux - wx;
         var dy:Number = uy - wy;
         var d2:Number = dx * dx + dy * dy;
         if (d2 > Config.AIM_DODGE_RANGE * Config.AIM_DODGE_RANGE)
         {
            return false;
         }
         var aim:Number = Math.atan2(dy, dx);
         var diff:Number = wrot - aim;
         while (diff > Math.PI) diff -= Math.PI * 2;
         while (diff < -Math.PI) diff += Math.PI * 2;
         if (Math.abs(diff) > TOL_RAD)
         {
            return false;
         }
         return Los.toPlayer(u, loc, gg, Config.AIM_DODGE_RANGE);
      }

      // ============ 慢弹威胁扫描 ============

      /** 同 v0.2.1：只处理 Bullet/SmartBullet（PhisBullet 交还原版 findGrenades）。 */
      private static function findThreat(loc:*, u:*, ux:Number, uy:Number):Object
      {
         var uvx:Number = TdfcMain.num(u, "dx", 0);
         var uvy:Number = TdfcMain.num(u, "dy", 0);
         var hitR:Number = Config.THREAT_HIT_R;
         var proj:* = loc["firstObj"];
         var nodes:int = 0;
         var threat:Object = null;
         while (proj != null && nodes < 256)
         {
            nodes++;
            var cls:String = TdfcMain.shortClass(proj);
            if (cls == "Bullet" || cls == "SmartBullet")
            {
               if (proj["owner"] !== u && TdfcMain.num(proj, "liv", 0) > 0)
               {
                  var vel:Number = TdfcMain.num(proj, "vel", 0);
                  if (vel > 0 && vel < Config.SLOW_SPEED_THRESH)
                  {
                     var rot:Number = TdfcMain.num(proj, "rot", 0);
                     var vx:Number = Math.cos(rot) * vel;
                     var vy:Number = Math.sin(rot) * vel + TdfcMain.num(proj, "ddy", 0);
                     var bx:Number = TdfcMain.num(proj, "X", ux);
                     var by:Number = TdfcMain.num(proj, "Y", uy);
                     var ox:Number = bx - ux;
                     var oy:Number = by - uy;
                     var rvx:Number = vx - uvx;
                     var rvy:Number = vy - uvy;
                     var len2:Number = rvx * rvx + rvy * rvy;
                     var tt:Number = 0;
                     if (len2 > 0)
                     {
                        var dot:Number = ox * rvx + oy * rvy;
                        tt = Math.max(0, Math.min(1, -dot / len2));
                     }
                     var cx:Number = ox + tt * rvx;
                     var cy:Number = oy + tt * rvy;
                     var dmin:Number = Math.sqrt(cx * cx + cy * cy);
                     var rr:Number = hitR + TdfcMain.num(proj, "explRadius", 0);
                     if (dmin < rr)
                     {
                        threat = proj;
                        break;
                     }
                  }
               }
            }
            proj = proj["nobj"];
         }
         return threat;
      }

      // ============ 掩体点搜索 ============

      private static function findCoverPoint(loc:*, u:*, ux:Number, uy:Number,
         px:Number, py:Number):Object
      {
         var bestX:Number = 0;
         var bestY:Number = 0;
         var bestD:Number = -1;
         for (var dir:int = 0; dir < 8; dir++)
         {
            var ang:Number = dir * Math.PI / 4;
            var cx:Number = Math.cos(ang);
            var cy:Number = Math.sin(ang);
            for (var di:int = 0; di < COVER_DISTS.length; di++)
            {
               var dx:Number = ux + cx * COVER_DISTS[di];
               var dy:Number = uy + cy * COVER_DISTS[di];
               if (tileSolid(loc, dx, dy))
               {
                  continue;
               }
               if (!Los.clear(loc, dx, dy, px, py))
               {
                  if (bestD < 0 || COVER_DISTS[di] < bestD)
                  {
                     bestD = COVER_DISTS[di];
                     bestX = dx;
                     bestY = dy;
                  }
                  break;
               }
            }
         }
         if (bestD < 0)
         {
            return null;
         }
         return { x: bestX, y: bestY };
      }

      // ============ 写入与工具 ============

      /** cel 直写（保留 celUnit，不打断交战；原版移动/瞄准消费 celX/celY）。 */
      private static function writeCel(u:*, x:Number, y:Number):void
      {
         try
         {
            u["celX"] = x;
            u["celY"] = y;
         }
         catch (e:Error) {}
      }

      /** 随机力度起跳（跳高随机化避免僵硬；jumpdy public）。 */
      private static function hopKick(u:*):void
      {
         try
         {
            var mult:Number = Config.DODGE_HOP * (0.7 + Math.random() * 0.5);
            u["dy"] = -TdfcMain.num(u, "jumpdy", 15) * mult;
         }
         catch (e:Error) {}
      }

      /** 冲量写速度（躲避/威胁用；垂直分量为 0 时不写 dy，让重力/跳跃支配）。 */
      private static function writeVel(u:*, vx:Number, vy:Number):void
      {
         try
         {
            u["dx"] = vx;
            if (vy != 0)
            {
               u["dy"] = vy;
            }
         }
         catch (e:Error) {}
      }

      private static function tileSolid(loc:*, x:Number, y:Number):Boolean
      {
         var solid:Boolean = true;
         try
         {
            var t:* = loc["getAbsTile"](x, y);
            if (t != null)
            {
               solid = (t["phis"] == 1);
            }
         }
         catch (e:Error) {}
         return solid;
      }

      private static function dist2(u:*, v:*):Number
      {
         var dx:Number = TdfcMain.num(u, "X", 0) - TdfcMain.num(v, "X", 0);
         var dy:Number = TdfcMain.num(u, "Y", 0) - TdfcMain.num(v, "Y", 0);
         return dx * dx + dy * dy;
      }
   }
}