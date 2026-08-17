package
{
   import flash.utils.Dictionary;

   /**
    * 分级传播引擎（Phase 1 信息层）。
    *
    * 通道说明（原版机制，见 design/brainstorm-01-enemy-ai.md 调研记录）：
    *  - 起疑通道：玩家噪声 gg.noise（public，每世界步衰减 20）。
    *    敌人 findCel→listen(gg) 听到噪声才把 aiSpok 抬到 maxSpok-1（internal 内部逻辑）。
    *    因此"唤醒"只能通过向 gg.noise 写入战斗噪声脉冲实现；该通道无阵营过滤，
    *    半径 = noise×ear×earMult（现实语义：战斗声很大）。
    *  - 位置通道：u.alarma(x,y) / u.setCel(null,x,y)（public）。只在敌人 aiSpok>0
    *    时有效（平静单位 cel 每帧被原版重置回自身）。用于给已起疑/已交战的盟友
    *    指路。
    *  - 交战通道：u.setCel(gg)（public）——直接指定玩家为目标，绕过察觉条累积。
    *    仅对 LOS 清晰的盟友使用（"看见即通知"）。
    */
   public class Propagation
   {
      /**
       * 目击传播：单位 source 刚发现玩家。
       * 对同阵营盟友分级：
       *  A. LOS 清晰 → setCel(gg) 直接交战；
       *  B. 无 LOS 但在听觉半径 → alarma(±HEAR_ERR)；
       *  C. 之外 → 无效果。
       * 同时向 gg.noise 写 SPREAD_NOISE 战斗噪声脉冲（唤醒听觉半径内全体）。
       */
      public static function vision(units:Array, source:*, gg:*, loc:*, tick:int):void
      {
         var sx:Number = source["X"];
         var sy:Number = source["Y"];
         var px:Number = gg["X"];
         var py:Number = gg["Y"];

         for (var i:int = 0; i < units.length; i++)
         {
            var u:* = units[i];
            if (!TdfcMain.isEnemy(u))
            {
               continue;
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
            if (dist2 < Config.SIGHT_RANGE * Config.SIGHT_RANGE)
            {
               if (Los.toPlayer(u, loc, gg, Config.SIGHT_RANGE))
               {
                  // A. 有视线：直接交战
                  try
                  {
                     u["setCel"](gg);
                  }
                  catch (e:Error) {}
                  TdfcLog.line("prop", "vision LOS engage " + TdfcMain.tag(u));
                  st.cdVision = tick;
               }
               else if (dist2 < (Config.HEAR_RANGE * ear) * (Config.HEAR_RANGE * ear))
               {
                  // B. 听觉半径：模糊位置
                  var ex:Number = px + TdfcMain.jitter(Config.HEAR_ERR);
                  var ey:Number = py + TdfcMain.jitter(Config.HEAR_ERR);
                  try
                  {
                     u["alarma"](ex, ey);
                  }
                  catch (e:Error) {}
                  TdfcLog.line("prop", "vision HEAR nudge " + TdfcMain.tag(u));
                  st.cdVision = tick;
               }
            }
         }

         // 战斗噪声脉冲：唤醒听觉半径内的敌人（起疑通道）
         noisePulse(gg, Config.SPREAD_NOISE);
      }

      /**
       * 枪声事件：玩家开火。
       * vanilla 已通过 weapon.makeNoise 覆盖"听觉唤醒"，TDFC 在此补充：
       *  - 对已起疑/已交战的同阵营盟友做位置提示（分级）；
       *  - 诊断记录（Phase 2 的躲避钩子在此挂接）。
       * 注意：枪声不做噪声脉冲放大——保持消音武器的潜行语义。
       */
      public static function gunshot(units:Array, gg:*, loc:*, tick:int, radius:Number):void
      {
         var px:Number = gg["X"];
         var py:Number = gg["Y"];
         var nudged:int = 0;

         for (var i:int = 0; i < units.length; i++)
         {
            var u:* = units[i];
            if (!TdfcMain.isEnemy(u))
            {
               continue;
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
               try { u["alarma"](px + TdfcMain.jitter(Config.PRECISE_ERR), py + TdfcMain.jitter(Config.PRECISE_ERR)); } catch (e:Error) {}
               nudged++;
            }
            else if (dist2 < (Config.HEAR_RANGE * ear) * (Config.HEAR_RANGE * ear))
            {
               try { u["alarma"](px + TdfcMain.jitter(Config.HEAR_ERR), py + TdfcMain.jitter(Config.HEAR_ERR)); } catch (e:Error) {}
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
       * 受击传播：单位 victim 被击中。
       * 受害者知道玩家位置 → 对附近同阵营盟友：
       *  A. LOS 清晰 → setCel(gg) 直接交战；
       *  B. 无 LOS 但在受击半径 → alarma(±HEAR_ERR)。
       * 同时发战斗噪声脉冲（"挨打会喊"）。
       */
      public static function damage(units:Array, victim:*, gg:*, loc:*, tick:int):void
      {
         var px:Number = gg["X"];
         var py:Number = gg["Y"];

         for (var i:int = 0; i < units.length; i++)
         {
            var u:* = units[i];
            if (!TdfcMain.isEnemy(u))
            {
               continue;
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
            if (Los.toPlayer(u, loc, gg, Config.DAMAGE_RANGE))
            {
               try { u["setCel"](gg); } catch (e:Error) {}
               TdfcLog.line("damage", "hit->LOS engage " + TdfcMain.tag(u));
            }
            else if (dist2 < (Config.HEAR_RANGE * ear) * (Config.HEAR_RANGE * ear))
            {
               try { u["alarma"](px + TdfcMain.jitter(Config.HEAR_ERR), py + TdfcMain.jitter(Config.HEAR_ERR)); } catch (e:Error) {}
               TdfcLog.line("damage", "hit->HEAR nudge " + TdfcMain.tag(u));
            }
            st.cdDamage = tick;
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
   }
}
