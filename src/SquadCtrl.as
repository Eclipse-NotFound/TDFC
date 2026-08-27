package
{
   /**
    * Phase 3 配合层 v0.5.0 —— 小队扫描/角色分配 + 压制协议 + 散开间距 + 交叉火力。
    * 设计：design/phase3-cooperation.md。
    *
    * 小队 = 同 fraction、智能层（tier 0）、战斗圈内（活跃且距玩家 ≤ SQUAD_RADIUS）。
    * 扫描每 SQUAD_SCAN_EVERY tick 一次（TdfcMain 单位循环前）：
    *   角色槽 ASSAULT(近战/霰弹) / SUPPRESS(每队≤1，枪械) / HOLD(其余远程)，
    *   交替分配 crossSide（±1），并给每成员一份"最近同伴"快照（防跨帧引用）。
    *
    * 压制协议（技术前提见设计文档 §2，2026-08-27 反编译验证）：
    *   同伴濒死受击 / 换弹且玩家逼近 → 指定压制者开窗：
    *   每帧 cel 锚定目标（有 LOS 跟玩家；无 LOS 盲射 lastSeen，
    *   新鲜度 ≤ POSITION_FREEZE）+ currentWeapon.attack()（public，
    *   敌人侧无玩家门控；原版 dropLoot 临死扫射即此模式）+
    *   weaponSkill 压低（精准接管让位给 ACC_SUPPRESS_MULT 分支）。
    *
    * 散开：同伴过近 → 水平分散冲量（pickDartX 墙体检，短窗口，不写 cel）。
    * 交叉火力：v0.5 最小实现——掩体/走位落点按 crossSide 选边（TacticalCtrl）。
    */
   public class SquadCtrl
   {
      // ---- 角色槽 ----
      public static const ROLE_NONE:int = 0;
      public static const ROLE_ASSAULT:int = 1;
      public static const ROLE_SUPPRESS:int = 2;
      public static const ROLE_HOLD:int = 3;

      private static var lastScanTick:int = -999999;

      // ============ 全局扫描（角色/侧位/同伴快照）============

      public static function scan(units:Array, gg:*, tick:int):void
      {
         if (tick - lastScanTick < Config.SQUAD_SCAN_EVERY)
         {
            return;
         }
         lastScanTick = tick;
         var px:Number = TdfcMain.num(gg, "X", 0);
         var py:Number = TdfcMain.num(gg, "Y", 0);
         var ring2:Number = Config.SQUAD_RADIUS * Config.SQUAD_RADIUS;

         // 1) 收集战斗圈内成员（按 fraction 分组）；圈外/不活跃者清角色
         var groups:Object = {};
         for (var i:int = 0; i < units.length; i++)
         {
            var u:* = units[i];
            var cls:String = TdfcMain.shortClass(u);
            if (!TdfcMain.isEnemy(u, cls))
            {
               continue;
            }
            var st:TacticalState = TdfcMain.state(u);
            if (TdfcMain.intelTier(cls) != 0)
            {
               st.squadRole = ROLE_NONE;
               st.crossSide = 0;
               st.mateNearD2 = 0;
               continue;
            }
            // 活跃 = 交战中 / 刚失去目标 / 近期收到过 TDFC 警报（目击/枪声/
            // 受击传播、自身受击）——只认"见过玩家"会让被警报唤醒的同伴
            // 永远入不了队，班组凑不齐（v0.5.0 实测教训）
            var active:Boolean = (u["celUnit"] === gg)
               || (tick - st.lastSeenTick) < 300
               || (tick - st.lastAlertTick) < 600;
            var dx:Number = TdfcMain.num(u, "X", 0) - px;
            var dy:Number = TdfcMain.num(u, "Y", 0) - py;
            if (!active || dx * dx + dy * dy > ring2)
            {
               st.squadRole = ROLE_NONE;
               st.crossSide = 0;
               st.mateNearD2 = 0;
               continue;
            }
            var fr:int = int(TdfcMain.num(u, "fraction", -1));
            if (groups[fr] == null)
            {
               groups[fr] = [];
            }
            groups[fr].push(u);
         }

         // 2) 每队：按距玩家排序 → 角色/侧位 → 同伴快照
         for (var k:String in groups)
         {
            var m:Array = groups[k];
            var n:int = m.length;
            var d2s:Array = [];
            for (i = 0; i < n; i++)
            {
               dx = TdfcMain.num(m[i], "X", 0) - px;
               dy = TdfcMain.num(m[i], "Y", 0) - py;
               d2s.push(dx * dx + dy * dy);
            }
            // 插入排序（同步 d2s 与 m；n 小，无需 Array.sort 闭包）
            for (i = 1; i < n; i++)
            {
               var uu:* = m[i];
               var dd:Number = d2s[i];
               var j:int = i - 1;
               while (j >= 0 && d2s[j] > dd)
               {
                  m[j + 1] = m[j];
                  d2s[j + 1] = d2s[j];
                  j--;
               }
               m[j + 1] = uu;
               d2s[j + 1] = dd;
            }

            var supTag:String = "-";
            if (n == 1)
            {
               // 单人不成战术队：近战归突击，其余 HOLD，无压制槽无侧位
               var solo:* = m[0];
               var sst:TacticalState = TdfcMain.state(solo);
               sst.squadRole = classify(solo) == ROLE_ASSAULT ? ROLE_ASSAULT : ROLE_HOLD;
               sst.crossSide = 0;
               sst.mateNearD2 = 0;
               continue;
            }
            var supAssigned:Boolean = false;
            var memberInfo:String = "";
            for (i = 0; i < n; i++)
            {
               var mu:* = m[i];
               var mst:TacticalState = TdfcMain.state(mu);
               mst.crossSide = (i % 2 == 0) ? 1 : -1;
               var role:int = classify(mu);
               if (role == ROLE_SUPPRESS)
               {
                  if (!supAssigned && Config.ENABLE_SUPPRESS)
                  {
                     supAssigned = true;
                     supTag = TdfcMain.tag(mu);
                  }
                  else
                  {
                     role = ROLE_HOLD;
                  }
               }
               mst.squadRole = role;
               memberInfo += " m" + i + "=" + roleTag(mu, role);
            }
            // 同伴快照 O(n²)：跨帧只留标量，不留对象引用
            for (i = 0; i < n; i++)
            {
               var a:* = m[i];
               var ast:TacticalState = TdfcMain.state(a);
               var ax:Number = TdfcMain.num(a, "X", 0);
               var ay:Number = TdfcMain.num(a, "Y", 0);
               var bd:Number = -1;
               var bx:Number = 0;
               var by:Number = 0;
               for (var j2:int = 0; j2 < n; j2++)
               {
                  if (j2 == i)
                  {
                     continue;
                  }
                  dx = TdfcMain.num(m[j2], "X", 0) - ax;
                  dy = TdfcMain.num(m[j2], "Y", 0) - ay;
                  var d2:Number = dx * dx + dy * dy;
                  if (bd < 0 || d2 < bd)
                  {
                     bd = d2;
                     bx = TdfcMain.num(m[j2], "X", 0);
                     by = TdfcMain.num(m[j2], "Y", 0);
                  }
               }
               ast.mateNearD2 = bd < 0 ? 0 : bd;
               ast.mateNearX = bx;
               ast.mateNearY = by;
            }
            TdfcLog.line("squad", "f=" + k + " n=" + n + " sup=" + supTag
               + memberInfo);
         }
      }

      /** 诊断：压制触发被挡原因（每单位 150t 一条，防刷屏）。 */
      private static function blockLog(st:TacticalState, tick:int, why:String):void
      {
         if (tick - st.lastBlockLog < 150)
         {
            return;
         }
         st.lastBlockLog = tick;
         TdfcLog.line("supp", "BLOCK " + why);
      }

      /** 诊断用：成员武器角色/血量快照。 */
      private static function roleTag(u:*, role:int):String
      {
         var wr:String = "?";
         var wrole:int = TacticalCtrl.weaponRole(u);
         if (wrole == TacticalCtrl.R_MELEE) wr = "melee";
         else if (wrole == TacticalCtrl.R_GUN) wr = "gun";
         else if (wrole == TacticalCtrl.R_SNIPER) wr = "sniper";
         else if (wrole == TacticalCtrl.R_SHOTGUN) wr = "shotgun";
         else if (wrole == TacticalCtrl.R_THROWER) wr = "thrower";
         else if (wrole == TacticalCtrl.R_MAGIC) wr = "magic";
         var mhp:Number = TdfcMain.num(u, "maxhp", 1);
         var hpR:Number = mhp > 0 ? TdfcMain.num(u, "hp", 0) / mhp : 1;
         var wepId:String = "?";
         try
         {
            if (u["currentWeapon"] != null)
            {
               wepId = String(u["currentWeapon"]["id"]);
            }
         }
         catch (e:Error) {}
         return wr + ":" + int(hpR * 100) + "%:" + wepId + ":r" + role;
      }

      /** 角色分型：近战/霰弹=ASSAULT；步枪/狙击且半血以上=SUPPRESS 候选；其余=HOLD。 */
      private static function classify(u:*):int
      {
         var role:int = TacticalCtrl.weaponRole(u);
         if (role == TacticalCtrl.R_MELEE || role == TacticalCtrl.R_SHOTGUN)
         {
            return ROLE_ASSAULT;
         }
         if (role == TacticalCtrl.R_GUN || role == TacticalCtrl.R_SNIPER)
         {
            var mhp:Number = TdfcMain.num(u, "maxhp", 1);
            var hpR:Number = mhp > 0 ? TdfcMain.num(u, "hp", 0) / mhp : 1;
            if (hpR > 0.5)
            {
               return ROLE_SUPPRESS;
            }
         }
         return ROLE_HOLD;
      }

      // ============ 每单位更新（散开冲量 + 压制状态机）============

      /** 单位循环内、TacticalCtrl.update 之前调用。 */
      public static function update(u:*, st:TacticalState, gg:*, loc:*,
         units:Array, tick:int):void
      {
         if (Config.ENABLE_SPACING)
         {
            spacing(u, st, gg, loc, tick);
         }
         if (Config.ENABLE_SUPPRESS)
         {
            suppressLogic(u, st, gg, loc, units, tick);
         }
      }

      /** 单位循环内、TacticalCtrl.update 之后调用：压制锚点+开火最后写，覆盖既有 cel。 */
      public static function apply(u:*, st:TacticalState, gg:*, loc:*, tick:int):void
      {
         if (!Config.ENABLE_SUPPRESS || st.suppressT <= 0)
         {
            return;
         }
         // 躲避/威胁冲量期间暂停开火（弹道会被身体机动甩飞，且给玩家窗口）
         if (st.dodgeT > 0 || st.threatT > 0)
         {
            return;
         }
         try
         {
            u["celX"] = st.suppressX;
            u["celY"] = st.suppressY;
         }
         catch (e:Error)
         {
            return;
         }
         var w:* = u["currentWeapon"];
         if (w == null)
         {
            return;
         }
         // attack() 只抬冷却/扣弹药，真正 shoot() 在武器下一 step 的 actions() 里
         try
         {
            w["attack"]();
         }
         catch (e:Error) {}
      }

      // ============ 散开间距 ============

      private static function spacing(u:*, st:TacticalState, gg:*, loc:*,
         tick:int):void
      {
         if (st.spacingT > 0)
         {
            st.spacingT--;
            try
            {
               u["dx"] = st.spacingVX;
            }
            catch (e:Error) {}
            return;
         }
         st.spacingCheck--;
         if (st.spacingCheck > 0)
         {
            return;
         }
         st.spacingCheck = Config.SPACING_CHECK;
         // 只对战斗圈内小队成员生效（ASSAULT 贴身群殴是本分，不社交）
         if (st.squadRole == ROLE_NONE || st.squadRole == ROLE_ASSAULT)
         {
            return;
         }
         if (st.mateNearD2 <= 0
            || st.mateNearD2 >= Config.SPACING_MIN * Config.SPACING_MIN)
         {
            return;
         }
         // 行为互斥：任何正在进行的动作优先，不做微调
         if (st.dodgeT > 0 || st.threatT > 0 || st.coverPhase > 0
            || st.retreatT > 0 || st.suppressT > 0 || st.corneredT > 0)
         {
            return;
         }
         // 与玩家 <150 豁免：混战中人挤人是常态，此时强推反而送头
         var gdx:Number = TdfcMain.num(gg, "X", 0) - TdfcMain.num(u, "X", 0);
         var gdy:Number = TdfcMain.num(gg, "Y", 0) - TdfcMain.num(u, "Y", 0);
         if (gdx * gdx + gdy * gdy < 150 * 150)
         {
            return;
         }
         var away:Number = (TdfcMain.num(u, "X", 0) >= st.mateNearX) ? 1 : -1;
         var dart:Number = TacticalCtrl.pickDartX(loc, TdfcMain.num(u, "X", 0),
            TdfcMain.num(u, "Y", 0), away);
         if (dart == 0)
         {
            return;
         }
         var spd:Number = TdfcMain.num(u, "runSpeed", 0);
         if (spd <= 0.5)
         {
            spd = TdfcMain.num(u, "maxSpeed", 10);
         }
         if (spd <= 0.5)
         {
            spd = 10;
         }
         st.spacingVX = dart * spd * Config.SPACING_MULT;
         st.spacingT = Config.SPACING_TICKS;
         TdfcLog.line("space", "SEP " + TdfcMain.tag(u));
      }

      // ============ 压制协议 ============

      private static function suppressLogic(u:*, st:TacticalState, gg:*, loc:*,
         units:Array, tick:int):void
      {
         // 角色被扫描剥夺 → 立即停火（窗口不跨角色残留）
         if (st.squadRole != ROLE_SUPPRESS)
         {
            if (st.suppressT > 0)
            {
               st.suppressT = 0;
            }
            return;
         }

         // ---- 窗口维持：每帧 ----
         if (st.suppressT > 0)
         {
            var mhp:Number = TdfcMain.num(u, "maxhp", 1);
            var hpR:Number = mhp > 0 ? TdfcMain.num(u, "hp", 0) / mhp : 1;
            var w:* = u["currentWeapon"];
            // 自身告危→撤退优先（盲射时长已在 START 时按目标新鲜度封顶）
            if (w == null || hpR < Config.RETREAT_RATIO
               || st.retreatT > 0 || st.corneredT > 0)
            {
               st.suppressT = 0;
               st.lastSuppressTick = tick;
               TdfcLog.line("supp", "END " + TdfcMain.tag(u));
               return;
            }
            // 有视线则实时跟踪玩家弹着点；无视线保持已定目标盲射
            if (Los.toPlayer(u, loc, gg, Config.SIGHT_RANGE))
            {
               st.suppressX = TdfcMain.num(gg, "X", 0);
               st.suppressY = TdfcMain.num(gg, "Y", 0);
            }
            st.suppressT--;
            return;
         }

         // ---- 触发 ----
         if (tick - st.lastSuppressTick < Config.SUPPRESS_CD)
         {
            return;
         }
         if (st.dodgeT > 0 || st.threatT > 0 || st.coverPhase > 0
            || st.retreatT > 0 || st.corneredT > 0)
         {
            blockLog(st, tick, "busy d=" + st.dodgeT + " th=" + st.threatT
               + " cv=" + st.coverPhase + " rt=" + st.retreatT
               + " crn=" + st.corneredT);
            return;
         }
         var wep:* = u["currentWeapon"];
         if (wep == null || int(TdfcMain.num(wep, "tip", 0)) != 3)
         {
            blockLog(st, tick, "weapon");
            return; // 仅枪械（投掷弹道抛物线、法术变量多，v0.5 排除）
         }
         mhp = TdfcMain.num(u, "maxhp", 1);
         hpR = mhp > 0 ? TdfcMain.num(u, "hp", 0) / mhp : 1;
         if (hpR < 0.5)
         {
            blockLog(st, tick, "hp " + int(hpR * 100) + "%");
            return;
         }
         // 活跃门控：交战中 / 刚见目标 / 近期被警报
         if (u["celUnit"] !== gg && tick - st.lastSeenTick >= 300
            && tick - st.lastAlertTick >= 600)
         {
            blockLog(st, tick, "inactive");
            return;
         }
         // 脆弱同伴检查（O(n)，节拍防每帧全表扫描）
         st.suppressCheck--;
         if (st.suppressCheck > 0)
         {
            return;
         }
         st.suppressCheck = Config.SUPPRESS_CHECK;
         var mate:TacticalState = findVulnerableMate(units, u, gg, tick);
         if (mate == null)
         {
            blockLog(st, tick, "no-vuln-mate");
            return;
         }
         // 目标点三级：自身 LOS→玩家实时位；自身 lastSeen 新鲜→盲射；
         // 都没有→用脆弱同伴的报点（队友知道玩家在哪，压制者照打）
         var blind:Boolean = false;
         if (Los.toPlayer(u, loc, gg, Config.SIGHT_RANGE))
         {
            st.suppressX = TdfcMain.num(gg, "X", 0);
            st.suppressY = TdfcMain.num(gg, "Y", 0);
         }
         else if (tick - st.lastSeenTick <= Config.POSITION_FREEZE)
         {
            st.suppressX = st.lastSeenX;
            st.suppressY = st.lastSeenY;
            blind = true;
         }
         else if (tick - mate.lastSeenTick <= Config.POSITION_FREEZE)
         {
            st.suppressX = mate.lastSeenX;
            st.suppressY = mate.lastSeenY;
            blind = true;
         }
         else
         {
            blockLog(st, tick, "no-target los=0 ownSeen=" + (tick - st.lastSeenTick)
               + " mateSeen=" + (tick - mate.lastSeenTick));
            return;
         }
         // 盲射时长按目标新鲜度封顶（无实时修正的压制不超过 POSITION_FREEZE）
         st.suppressT = blind ? Math.min(Config.SUPPRESS_TICKS, Config.POSITION_FREEZE)
            : Config.SUPPRESS_TICKS;
         TdfcLog.line("supp", "START " + TdfcMain.tag(u)
            + " at " + int(st.suppressX) + "," + int(st.suppressY)
            + (blind ? " blind" : ""));
      }

      /** 同伴濒死受击（玩家正在施压）或换弹且玩家逼近 → 返回其状态（供报点），无则 null。 */
      private static function findVulnerableMate(units:Array, u:*, gg:*,
         tick:int):TacticalState
      {
         var fr:int = int(TdfcMain.num(u, "fraction", -1));
         var px:Number = TdfcMain.num(gg, "X", 0);
         var py:Number = TdfcMain.num(gg, "Y", 0);
         var ux:Number = TdfcMain.num(u, "X", 0);
         var uy:Number = TdfcMain.num(u, "Y", 0);
         var ring2:Number = Config.SQUAD_RADIUS * Config.SQUAD_RADIUS;
         var purs2:Number = Config.SUPPRESS_PURSUIT * Config.SUPPRESS_PURSUIT;
         for (var i:int = 0; i < units.length; i++)
         {
            var v:* = units[i];
            if (v === u || !TdfcMain.isEnemy(v))
            {
               continue;
            }
            if (int(TdfcMain.num(v, "fraction", -1)) != fr)
            {
               continue;
            }
            var dx:Number = TdfcMain.num(v, "X", 0) - ux;
            var dy:Number = TdfcMain.num(v, "Y", 0) - uy;
            if (dx * dx + dy * dy > ring2)
            {
               continue;
            }
            var vst:TacticalState = TdfcMain.state(v);
            var vmhp:Number = TdfcMain.num(v, "maxhp", 1);
            var vhpR:Number = vmhp > 0 ? TdfcMain.num(v, "hp", 0) / vmhp : 1;
            if (vhpR < Config.SUPPRESS_MATE_HP
               && tick - vst.lastHitTick < Config.SUPPRESS_MATE_HIT_WINDOW)
            {
               return vst;
            }
            var vw:* = v["currentWeapon"];
            if (vw != null && TdfcMain.num(vw, "t_reload", 0) > 0)
            {
               var pdx:Number = TdfcMain.num(v, "X", 0) - px;
               var pdy:Number = TdfcMain.num(v, "Y", 0) - py;
               if (pdx * pdx + pdy * pdy < purs2)
               {
                  return vst;
               }
            }
         }
         return null;
      }
   }
}
