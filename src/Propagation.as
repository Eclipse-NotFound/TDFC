package
{
   import flash.utils.Dictionary;

   /**
    * 分级传播引擎 v0.4.1（Phase 1 信息层 + 感知层补完）。
    *
    * v0.4.1 新增（候选机制 B+C）：
    *  - B 目击确认：目击事件先进确认队列（SPOT_CONFIRM_TICKS），期间持续核验
    *    目击者对玩家的 LOS；断线即取消——玩家有"处理目击者/断视线"的窗口。
    *  - C 传播延迟：确认后的目击/受击传播不再瞬间送达，按
    *    距离/PROP_DELAY_SPEED 计算每个盟友的延迟（上限 PROP_DELAY_MAX），
    *    远处队友"一波波"觉醒。
    *
    * 通道说明（原版机制）：
    *  - 起疑通道：玩家噪声 gg.noise（见 Perception）；位置通道 alarma/setCel；
    *    交战通道 setCel(gg)（仅 LOS 清晰者，见 enemy-ai-drive-interfaces）。
    */
   public class Propagation
   {
      /** 目击确认队列：{u, x, y, t}，帧内衰减，t<=0 且仍 LOS 才传播。 */
      private static var spots:Array = [];

      /**
       * 目击事件入队（TdfcMain 检测到 celUnit false→true 时调用）。
       */
      public static function queueSpot(u:*, x:Number, y:Number):void
      {
         spots.push({ u: u, x: x, y: y, t: Config.SPOT_CONFIRM_TICKS });
         if (spots.length > 8)
         {
            spots.shift(); // 队列上限，防刷
         }
      }

      /**
       * 每帧处理：确认队列 + 待送达警报（TdfcMain 单位循环后调用）。
       */
      public static function frameTick(units:Array, gg:*, loc:*, tick:int):void
      {
         // ---- 目击确认 ----
         for (var i:int = spots.length - 1; i >= 0; i--)
         {
            var s:Object = spots[i];
            s.t--;
            if (s.t <= 0)
            {
               spots.splice(i, 1);
               var sp:* = s.u;
               if (sp != null && TdfcMain.num(sp, "sost", 0) == 1
                  && Los.toPlayer(sp, loc, gg, Config.SIGHT_RANGE))
               {
                  // 确认通过：目击者仍看着玩家 → 正式传播（内部按距离延迟）
                  vision(units, sp, gg, loc, tick);
                  TdfcLog.line("confirm", "OK " + TdfcMain.tag(sp));
               }
               else
               {
                  TdfcLog.line("confirm", "CANCEL "
                     + (sp != null ? TdfcMain.tag(sp) : "?"));
               }
            }
         }

         // ---- 待送达警报 ----
         for (var j:int = 0; j < units.length; j++)
         {
            var u:* = units[j];
            var st:TacticalState = TdfcMain.state(u);
            if (st.pendT > 0)
            {
               st.pendT--;
               if (st.pendT <= 0)
               {
                  deliverPending(u, st, gg, loc, tick);
               }
            }
         }
      }

      /** 送达待定警报：送达时按当前 LOS 分级（有视线→直接交战；否则模糊位置）。 */
      private static function deliverPending(u:*, st:TacticalState, gg:*, loc:*, tick:int):void
      {
         if (Los.toPlayer(u, loc, gg, Config.SIGHT_RANGE))
         {
            try { u["setCel"](gg); } catch (e:Error) {}
            TdfcLog.line("prop", "DELIVER LOS " + TdfcMain.tag(u));
         }
         else
         {
            var np:* = frozenNudge(st, tick, st.pendX, st.pendY, Config.HEAR_ERR);
            try { u["alarma"](np.x, np.y); } catch (e:Error) {}
            TdfcLog.line("prop", "DELIVER HEAR " + TdfcMain.tag(u));
         }
      }

      /** 按距离计算传播延迟 tick（距离/速度，钳制上限）。 */
      private static function propDelay(ux:Number, uy:Number, px:Number, py:Number):int
      {
         var dx:Number = ux - px;
         var dy:Number = uy - py;
         var d:Number = Math.sqrt(dx * dx + dy * dy);
         var t:int = int(d / Config.PROP_DELAY_SPEED);
         if (t > Config.PROP_DELAY_MAX)
         {
            t = Config.PROP_DELAY_MAX;
         }
         return t;
      }

      /**
       * 目击传播（确认后调用）：对同阵营盟友分级调度（延迟送达）：
       *  A. LOS 清晰 → 送达时 setCel(gg) 直接交战；
       *  B. 无 LOS 但在听觉半径 → 送达时 alarma(±HEAR_ERR)；
       *  C. 之外 → 无效果。
       * 同时发战斗噪声脉冲（唤醒听觉半径内全体）。
       */
      public static function vision(units:Array, source:*, gg:*, loc:*, tick:int):void
      {
         var px:Number = gg["X"];
         var py:Number = gg["Y"];

         for (var i:int = 0; i < units.length; i++)
         {
            var u:* = units[i];
            var ucls:String = TdfcMain.shortClass(u);
            if (!TdfcMain.isEnemy(u, ucls))
            {
               continue;
            }
            if (TdfcMain.intelTier(ucls) == 2)
            {
               continue; // v0.3：动物不接入警戒联动（保留自身原版感知）
            }
            if (u === source)
            {
               continue;
            }
            var st:TacticalState = TdfcMain.state(u);
            if (tick - st.cdVision < Config.PROP_CD_VISION)
            {
               continue;
            }
            var dx:Number = u["X"] - px;
            var dy:Number = u["Y"] - py;
            var dist2:Number = dx * dx + dy * dy;
            var ear:Number = TdfcMain.num(u, "ear", 1);
            if (dist2 < Config.SIGHT_RANGE * Config.SIGHT_RANGE
               && (Los.toPlayer(u, loc, gg, Config.SIGHT_RANGE)
                  || dist2 < (Config.HEAR_RANGE * ear) * (Config.HEAR_RANGE * ear)))
            {
               st.pendT = propDelay(u["X"], u["Y"], px, py);
               st.pendX = px;
               st.pendY = py;
               st.cdVision = tick;
               TdfcLog.line("prop", "vision SCHEDULE " + TdfcMain.tag(u)
                  + " delay=" + st.pendT);
            }
         }

         // 战斗噪声脉冲：唤醒听觉半径内的敌人（起疑通道）
         noisePulse(gg, Config.SPREAD_NOISE);
      }

      /**
       * 枪声事件：玩家开火。
       * vanilla 已通过 weapon.makeNoise 覆盖"听觉唤醒"，TDFC 在此补充：
       *  - 对已起疑/已交战的同阵营盟友做位置提示（立即，带冻结位置）；
       *  - 诊断记录（Phase 2 的躲避钩子在此挂接）。
       * 枪声不做噪声脉冲放大——保持消音武器的潜行语义。
       */
      public static function gunshot(units:Array, gg:*, loc:*, tick:int, radius:Number):void
      {
         var px:Number = gg["X"];
         var py:Number = gg["Y"];
         var nudged:int = 0;

         for (var i:int = 0; i < units.length; i++)
         {
            var u:* = units[i];
            var ucls:String = TdfcMain.shortClass(u);
            if (!TdfcMain.isEnemy(u, ucls))
            {
               continue;
            }
            if (TdfcMain.intelTier(ucls) == 2)
            {
               continue; // v0.3：动物不接入警戒联动
            }
            if (u["celUnit"] === gg)
            {
               continue; // 已交战者不需要枪声提示
            }
            var st:TacticalState = TdfcMain.state(u);
            if (tick - st.cdGunshot < Config.PROP_CD_GUNSHOT)
            {
               continue;
            }
            var dx:Number = u["X"] - px;
            var dy:Number = u["Y"] - py;
            var dist2:Number = dx * dx + dy * dy;
            if (dist2 > Config.GUNSHOT_RANGE * Config.GUNSHOT_RANGE)
            {
               continue;
            }
            var ear:Number = TdfcMain.num(u, "ear", 1);
            if (Los.toPlayer(u, loc, gg, Config.GUNSHOT_RANGE))
            {
               var npL:* = frozenNudge(st, tick, px, py, Config.PRECISE_ERR);
               try { u["alarma"](npL.x, npL.y); } catch (e:Error) {}
               nudged++;
            }
            else if (dist2 < (Config.HEAR_RANGE * ear) * (Config.HEAR_RANGE * ear))
            {
               var npH:* = frozenNudge(st, tick, px, py, Config.HEAR_ERR);
               try { u["alarma"](npH.x, npH.y); } catch (e:Error) {}
               nudged++;
            }
            st.cdGunshot = tick;
         }

         if (nudged > 0)
         {
            TdfcLog.line("gunshot", "fired r=" + int(radius) + " nudged=" + nudged);
         }
      }

      /**
       * 受击传播：单位 victim 被击中 → 对附近同阵营盟友按距离延迟调度。
       * 受害者知道玩家位置；送达时 LOS 清晰→直接交战，否则模糊位置。
       * 同时发战斗噪声脉冲（"挨打会喊"，立即）。
       */
      public static function damage(units:Array, victim:*, gg:*, loc:*, tick:int):void
      {
         var px:Number = gg["X"];
         var py:Number = gg["Y"];

         for (var i:int = 0; i < units.length; i++)
         {
            var u:* = units[i];
            var ucls:String = TdfcMain.shortClass(u);
            if (!TdfcMain.isEnemy(u, ucls))
            {
               continue;
            }
            if (TdfcMain.intelTier(ucls) == 2)
            {
               continue; // v0.3：动物不接入警戒联动
            }
            if (u === victim)
            {
               continue;
            }
            var st:TacticalState = TdfcMain.state(u);
            if (tick - st.cdDamage < Config.PROP_CD_DAMAGE)
            {
               continue;
            }
            var dx:Number = u["X"] - px;
            var dy:Number = u["Y"] - py;
            var dist2:Number = dx * dx + dy * dy;
            if (dist2 > Config.DAMAGE_RANGE * Config.DAMAGE_RANGE)
            {
               continue;
            }
            var ear:Number = TdfcMain.num(u, "ear", 1);
            if (Los.toPlayer(u, loc, gg, Config.DAMAGE_RANGE)
               || dist2 < (Config.HEAR_RANGE * ear) * (Config.HEAR_RANGE * ear))
            {
               st.pendT = propDelay(u["X"], u["Y"], px, py);
               st.pendX = px;
               st.pendY = py;
               st.cdDamage = tick;
               TdfcLog.line("damage", "hit->SCHEDULE " + TdfcMain.tag(u)
                  + " delay=" + st.pendT);
            }
         }

         noisePulse(gg, Config.SPREAD_NOISE);
      }

      /**
       * 战斗噪声脉冲：写入玩家噪声（public，每步衰减 20，自然短时）。
       * 这是原版唯一的"起疑"通道（敌人 listen(gg) 判定），无法按阵营过滤——
       * 与 vanilla budilo（Location.budilo 同样无阵营过滤）语义一致。
       */
      public static function noisePulse(gg:*, n:Number):void
      {
         try
         {
            if (TdfcMain.num(gg, "noise", 0) < n)
            {
               gg["noise"] = n;
            }
         }
         catch (e:Error) {}
      }

      /**
       * 冻结声源位置（问题 3 修复）：无 LOS 单位在 POSITION_FREEZE 窗口内
       * 保持上一次声源位置，不随玩家实时移动——听到的是"声音的方向区域"，
       * 不是玩家的实时坐标。
       */
      private static function frozenNudge(st:TacticalState, tick:int,
         px:Number, py:Number, err:Number):Object
      {
         if (tick - st.nudgeTick < Config.POSITION_FREEZE)
         {
            return { x: st.nudgeX, y: st.nudgeY };
         }
         var nx:Number = px + TdfcMain.jitter(err);
         var ny:Number = py + TdfcMain.jitter(err);
         st.nudgeX = nx;
         st.nudgeY = ny;
         st.nudgeTick = tick;
         return { x: nx, y: ny };
      }
   }
}