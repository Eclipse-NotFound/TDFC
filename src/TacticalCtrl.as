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
      private static const THREAT_AVOID_DISTS:Array = [90, 160];
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
                     var rot:Number = TdfcMain.num(t, "rot", 0);
                     var pvx:Number = Math.cos(rot);
                     var pvy:Number = Math.sin(rot);
                     var pt:* = pickSafePoint(loc, ux, uy, pvy, -pvx);
                     if (pt == null)
                     {
                        pt = pickSafePoint(loc, ux, uy, -pvy, pvx);
                     }
                     if (pt != null)
                     {
                        st.threatX = pt.x;
                        st.threatY = pt.y;
                     }
                     else
                     {
                        st.threatX = ux + (ux >= px ? 1 : -1) * 120;
                        st.threatY = uy;
                     }
                     if (Math.abs(pvy) < Config.DODGE_FLAT_SIN && u["stay"] == true)
                     {
                        try { u["dy"] = -TdfcMain.num(u, "jumpdy", 15) * Config.DODGE_HOP; }
                        catch (e:Error) {}
                     }
                     TdfcLog.line("threat", "PROJ " + TdfcMain.tag(u)
                        + " to " + int(st.threatX) + "," + int(st.threatY));
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

         // ===== 写入仲裁：撤退 > 掩体 > 威胁躲避 > 瞄准躲避 =====
         var acted:Boolean = false;
         if (inRetreat)
         {
            writeCel(u, st.retreatX, st.retreatY);
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
            acted = true;
         }
         else if (st.threatT > 0)
         {
            writeCel(u, st.threatX, st.threatY);
            acted = true;
         }
         else if (st.dodgeT > 0)
         {
            writeCel(u, st.dodgeX, st.dodgeY);
            acted = true;
         }
         return acted;
      }

      // ============ 角色分派（瞄准反应） ============

      /**
       * 按武器角色与移动形态执行躲避/走位动作，并写出躲避点与（可选的）起跳。
       * 空中(isFly)取弹线真实垂直向量（2D 机动）；地面限水平+跳跃；
       * 水中(isPlav)取 2D。
       */
      private static function dispatchDodge(u:*, st:TacticalState, loc:*,
         role:int, wrot:Number, px:Number, py:Number, ux:Number, uy:Number,
         tick:int):void
      {
         var isFly:Boolean = (u["isFly"] == true);
         var isPlav:Boolean = (u["isPlav"] == true);
         var onGround:Boolean = (u["stay"] == true);

         // 弹线垂直向量（真 2D 躲避方向；旋转 90°）
         var pdx:Number = -Math.sin(wrot);
         var pdy:Number = Math.cos(wrot);

         if (role == R_SNIPER)
         {
            // 狙击：优先找掩体/拉距离，不跳；有走位冷却
            if (tick - st.lastSniperTick >= 90
               && applySniperReposition(u, st, loc, px, py, ux, uy))
            {
               st.lastSniperTick = tick;
               TdfcLog.line("dodge", "SNIPER cover " + TdfcMain.tag(u));
               return;
            }
            // 无掩体可去：直线后撤（水平离开玩家）
            var rSide:Number = (ux >= px) ? 1 : -1;
            st.dodgeT = Config.DODGE_TICKS;
            st.dodgeX = ux + rSide * 160;
            st.dodgeY = uy;
            TdfcLog.line("dodge", "SNIPER retreat " + TdfcMain.tag(u));
            return;
         }

         if (role == R_SHOTGUN)
         {
            // 霰弹：前冲逼近 + 横抖；平射也跳
            var adv:Number = 0.55; // 贴上玩家 55%
            var tx:Number = ux + (px - ux) * adv;
            var ty:Number = uy + (py - uy) * adv;
            // 横向抖动
            var j:Number = (Math.random() > 0.5 ? 1 : -1) * 45;
            st.dodgeT = Config.DODGE_TICKS;
            st.dodgeX = tx + j;
            st.dodgeY = ty;
            if (Math.abs(Math.sin(wrot)) < Config.DODGE_FLAT_SIN && onGround)
            {
               try { u["dy"] = -TdfcMain.num(u, "jumpdy", 15) * Config.DODGE_HOP; }
               catch (e:Error) {}
            }
            TdfcLog.line("dodge", "SHOTGUN charge " + TdfcMain.tag(u));
            return;
         }

         if (role == R_MELEE)
         {
            // 近战：直线逼近 + 侧抖 + 靠近时跳
            var tx2:Number = px + (ux > px ? 1 : -1) * 30;
            var ty2:Number = py;
            st.dodgeT = Config.DODGE_TICKS;
            st.dodgeX = tx2;
            st.dodgeY = ty2;
            if (Math.abs(Math.sin(wrot)) < Config.DODGE_FLAT_SIN && onGround)
            {
               try { u["dy"] = -TdfcMain.num(u, "jumpdy", 15) * Config.DODGE_HOP; }
               catch (e:Error) {}
            }
            TdfcLog.line("dodge", "MELEE close " + TdfcMain.tag(u));
            return;
         }

         // ---- GUN / THROWER / MAGIC：标准几何躲避 ----
         if (isFly)
         {
            // 空中机动：弹线垂直向量（含高度分量）
            var fd:Number = 120;
            st.dodgeT = Config.DODGE_TICKS;
            st.dodgeX = ux + pdx * fd;
            st.dodgeY = uy + pdy * fd;
            if (Math.abs(pdy) > 0.3)
            {
               try { u["dy"] = pdy * 4; } catch (e:Error) {} // 高度机动
            }
            TdfcLog.line("dodge", "FLY " + TdfcMain.tag(u));
            return;
         }
         if (isPlav)
         {
            st.dodgeT = Config.DODGE_TICKS;
            st.dodgeX = ux + pdx * 90;
            st.dodgeY = uy + pdy * 90;
            TdfcLog.line("dodge", "SWIM " + TdfcMain.tag(u));
            return;
         }
         // 地面：平射→跳；斜射→水平走位（v0.2.2 几何规则）
         var side2:Number = (ux >= px) ? 1 : -1;
         var hop:Boolean = false;
         if (Math.abs(Math.sin(wrot)) < Config.DODGE_FLAT_SIN && onGround)
         {
            hop = true;
         }
         var dd:Number = ux + side2 * Config.DODGE_DIST;
         if (tileSolid(loc, dd, uy))
         {
            dd = ux - side2 * Config.DODGE_DIST;
            if (tileSolid(loc, dd, uy))
            {
               dd = ux;
            }
         }
         st.dodgeT = Config.DODGE_TICKS;
         st.dodgeX = dd;
         st.dodgeY = uy;
         if (hop)
         {
            try { u["dy"] = -TdfcMain.num(u, "jumpdy", 15) * Config.DODGE_HOP; }
            catch (e:Error) {}
         }
         TdfcLog.line("dodge", "GROUND " + TdfcMain.tag(u)
            + " hop=" + (hop ? 1 : 0));
      }

      /** 狙击走位：优先掩体点，无则返回 false（由调用方做直线后撤）。 */
      private static function applySniperReposition(u:*, st:TacticalState, loc:*,
         px:Number, py:Number, ux:Number, uy:Number):Boolean
      {
         if (st.dodgeT > 0)
         {
            return false; // 已在走位
         }
         var cp:* = findCoverPoint(loc, u, ux, uy, px, py);
         if (cp != null)
         {
            st.dodgeT = Config.DODGE_TICKS + 12;
            st.dodgeX = cp.x;
            st.dodgeY = cp.y;
            return true;
         }
         return false;
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

      private static function writeCel(u:*, x:Number, y:Number):void
      {
         try
         {
            u["celX"] = x;
            u["celY"] = y;
         }
         catch (e:Error) {}
      }

      private static function pickSafePoint(loc:*, ux:Number, uy:Number,
         dx:Number, dy:Number):Object
      {
         var len:Number = Math.sqrt(dx * dx + dy * dy);
         if (len < 0.001)
         {
            return null;
         }
         dx = dx / len;
         dy = dy / len;
         for (var i:int = 0; i < THREAT_AVOID_DISTS.length; i++)
         {
            var d:Number = THREAT_AVOID_DISTS[i];
            var cx:Number = ux + dx * d;
            var cy:Number = uy + dy * d;
            if (!tileSolid(loc, cx, cy))
            {
               return { x: cx, y: cy };
            }
         }
         return null;
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