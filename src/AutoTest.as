package
{
   import flash.desktop.NativeApplication;

   /**
    * 自动化测试钩子（remains-auto-testing 技能 §3 可测试性设计）。
    *
    * 激活条件：运行时 applicationID != "pfe"——只有用临时描述符
    * （app_tdfc_test_pfe.xml，改 <id>）起的隔离测试实例才激活；
    * 用户实例（id=pfe）永不激活、零影响。存储/日志随 app id 天然隔离
    * （%APPDATA%\pfe_tdfc_test\Local Store\tdfc.log）。
    *
    * 序列（技能 §2 四步驱动）：放行主菜单 → newGame → 稳定等待 →
    * 交战期循环：补充带枪掠夺者（高血，TdfcMain.spawnRaider 圈养）/
    * 周期打残一只（触发压制协议）/ 玩家低频回血延长交战窗口。
    * 每个可验证现象一行 "auto" 日志；跑完由脚本按描述符特征杀进程。
    */
   public class AutoTest
   {
      public static var active:Boolean = false;

      private static var phase:int = 0;    // 0=放行菜单 1=自动开局 2=稳定 3=交战
      private static var waitT:int = 0;
      private static var combatT0:int = -1;
      private static var newGameT:int = -999999;
      private static var newGameFails:int = 0;
      private static var spawned:Array = [];
      private static var lastSpawnTick:int = -999999;
      private static var lastWoundTick:int = -999999;
      private static var lastHealTick:int = -999999;
      private static var doneLogged:Boolean = false;

      private static const COMBAT_TICKS:int = 3600;  // 交战观测窗（~60s）后打 done 标记
      private static const WOUND_EVERY:int = 450;    // 打残周期（触发压制/撤退链）
      private static const HEAL_EVERY:int = 240;     // 玩家回血周期
      private static const RESPAWN_EVERY:int = 300;  // 圈养补怪周期

      /** 探测 app id，非用户实例才激活。 */
      public static function init():void
      {
         try
         {
            var id:String = NativeApplication.nativeApplication.applicationID;
            if (id != "pfe")
            {
               active = true;
               TdfcLog.line("auto", "ACTIVE appid=" + id);
            }
         }
         catch (e:Error)
         {
            TdfcLog.line("auto", "probe failed: " + e.message);
         }
      }

      /** 每帧最早调用（TdfcMain 各门控之前）：放行菜单 + 自动开局。 */
      public static function frame(world:*, tick:int):void
      {
         if (!active)
         {
            return;
         }
         // 兜底：开局阶段之后主菜单重新弹出都放行
         var mm:* = world["mm"];
         if (phase > 0 && mm != null && mm["active"] == true)
         {
            try
            {
               mm["active"] = false;
               TdfcLog.line("auto", "menu re-released");
            }
            catch (e:Error) {}
         }
         // phase 0：等开机 stage-2 完成（landData 就绪）才放菜单——
         // 过早放行会打断开机链，导致 later newGame 时 landData 为 null
         //（Game 构造器访问 World.w.landData[x] 直接 #1009，实测教训）
         if (phase == 0)
         {
            if (world["landData"] != null)
            {
               try
               {
                  if (mm != null && mm["active"] == true)
                  {
                     mm["active"] = false;
                  }
                  TdfcLog.line("auto", "boot ready, menu released");
                  phase = 1;
               }
               catch (e4:Error) {}
            }
            return;
         }
         if (phase == 1)
         {
            var loc:* = world["loc"];
            if (loc != null && loc["gg"] != null)
            {
               phase = 2;
               waitT = 120;
               TdfcLog.line("auto", "game ready, stabilize");
               return;
            }
            // newGame 是异步建世界流程，重复调用会不断打断重来（实测教训）——
            // 只在长超时（30s）仍无世界时才重试，最多 3 次后放弃
            if (tick - newGameT >= 1800)
            {
               newGameT = tick;
               newGameFails++;
               if (newGameFails > 3)
               {
                  phase = 99;
                  TdfcLog.line("auto", "GIVE UP: world never appeared");
                  return;
               }
               // 停滞诊断：错误对话框（step 首行 verror.visible 即冻结）
               // + 异步链各阶段对象存在性（World.step: ng_wait 1→newGame1→2→newGame2）
               diagnose(world);
               try
               {
                  // 反编译锚点：ng = nload < 0 才走新档分支——传 0 会去读
                  // 空档位（测试存储无存档），世界永远开不出来
                  world["newGame"](-1, "LP", null);
                  TdfcLog.line("auto", "newGame called (try " + newGameFails + ")");
               }
               catch (e2:Error)
               {
                  TdfcLog.line("auto", "newGame FAILED: " + e2.message);
               }
            }
         }
         else if (phase == 2)
         {
            waitT--;
            if (waitT <= 0)
            {
               phase = 3;
               combatT0 = tick;
               TdfcLog.line("auto", "combat phase");
            }
         }
      }

      /** 玩家存活时每帧调用：回血 / 补怪 / 打残。 */
      public static function combat(loc:*, gg:*, units:Array, tick:int):void
      {
         if (!active || phase != 3)
         {
            return;
         }
         if (!doneLogged && combatT0 > 0 && tick - combatT0 > COMBAT_TICKS)
         {
            doneLogged = true;
            TdfcLog.line("auto", "done (observation window complete)");
         }

         // 1) 玩家保活：低血低频回血（pers.healAll，兜底直写 hp）
         var gmhp:Number = TdfcMain.num(gg, "maxhp", 1);
         var ghp:Number = TdfcMain.num(gg, "hp", 0);
         if (gmhp > 0 && ghp / gmhp < 0.6 && tick - lastHealTick >= HEAL_EVERY)
         {
            lastHealTick = tick;
            var healed:Boolean = false;
            try
            {
               gg["pers"]["healAll"]();
               healed = true;
            }
            catch (e:Error) {}
            if (!healed)
            {
               try
               {
                  gg["hp"] = gmhp;
                  healed = true;
               }
               catch (e2:Error) {}
            }
            if (healed)
            {
               TdfcLog.line("auto", "healed player");
            }
         }

         // 2) 圈养存活统计 + 清尸 + 补怪
         for (var i:int = spawned.length - 1; i >= 0; i--)
         {
            if (TdfcMain.num(spawned[i], "sost", 0) != 1)
            {
               spawned.splice(i, 1);
            }
         }
         if (spawned.length < 2 && tick - lastSpawnTick >= RESPAWN_EVERY)
         {
            lastSpawnTick = tick;
            spawnOne(loc, gg, 140, 30);
            spawnOne(loc, gg, 170, 45);
         }

         // 3) 周期照料"靶机"（spawned[0]）：首刀压到 25%；此后小刀刷新受击戳
         //    （压制触发依赖"同伴 90t 内受过击"），血量过低则回补——形成
         //    可持续的压制触发周期；另一成员保持健康（压制者须 >50% 血）
         if (spawned.length >= 2 && tick - lastWoundTick >= WOUND_EVERY)
         {
            lastWoundTick = tick;
            var victim:* = spawned[0];
            var vmhp:Number = TdfcMain.num(victim, "maxhp", 1);
            var vhp:Number = TdfcMain.num(victim, "hp", 0);
            if (vmhp > 0)
            {
               var ratio:Number = vhp / vmhp;
               try
               {
                  if (ratio > 0.3)
                  {
                     var dmg:Number = vhp - vmhp * 0.25;
                     victim["damage"](dmg, 0, null, false);
                     TdfcLog.line("auto", "wounded " + TdfcMain.tag(victim)
                        + " hp " + int(vhp) + "->" + int(vhp - dmg));
                  }
                  else if (ratio < 0.2)
                  {
                     victim["hp"] = vmhp * 0.32;
                     TdfcLog.line("auto", "victim topup 32%");
                  }
                  else
                  {
                     victim["damage"](4, 0, null, false);
                     TdfcLog.line("auto", "victim nick (refresh hit)");
                  }
               }
               catch (e3:Error)
               {
                  TdfcLog.line("auto", "wound FAILED: " + e3.message);
               }
            }
         }
      }

      /** 开局停滞诊断：verrror 文本（可读）+ 自动解冻 + ng_wait 链位置。 */
      private static function diagnose(world:*):void
      {
         var st:String = "";
         try
         {
            var vr:* = world["verror"];
            if (vr != null && vr["visible"] == true)
            {
               var msg:String = "?";
               try
               {
                  msg = String(vr["txt"]["text"]);
               }
               catch (e0:Error) {}
               st = "VERRER_VISIBLE text=" + msg + " | ";
               vr["visible"] = false; // 模拟关闭按钮，解冻 World.step
            }
         }
         catch (e1:Error) {}
         try
         {
            st = st + "ng_wait=" + TdfcMain.num(world, "ng_wait", -1)
               + " allStat=" + TdfcMain.num(world, "allStat", -1)
               + " game=" + (world["game"] != null ? 1 : 0)
               + " gui=" + (world["gui"] != null ? 1 : 0)
               + " pers=" + (world["pers"] != null ? 1 : 0)
               + " gg=" + (world["gg"] != null ? 1 : 0)
               + " loc=" + (world["loc"] != null ? 1 : 0)
               + " landData=" + (world["landData"] != null ? 1 : 0)
               + " landsLoaded=" + (world["allLandsLoaded"] == true ? 1 : 0)
               + " testMode=" + (world["testMode"] == true ? 1 : 0);
         }
         catch (e2:Error)
         {
            st = st + "(diag failed)";
         }
         TdfcLog.line("auto", "stall: " + st);
      }

      private static function spawnOne(loc:*, gg:*, ox:Number, oy:Number):void
      {
         var r:* = TdfcMain.spawnRaider(loc, gg, ox, oy);
         if (r != null)
         {
            spawned.push(r);
         }
      }
   }
}
