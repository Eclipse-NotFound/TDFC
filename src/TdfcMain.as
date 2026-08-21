package
{
   import flash.display.Stage;
   import flash.events.Event;
   import flash.events.KeyboardEvent;
   import flash.system.ApplicationDomain;
   import flash.utils.Dictionary;
   import flash.utils.getDefinitionByName;
   import flash.utils.getQualifiedClassName;

   /**
    * TDFC 帧窗驱动。
    *
    * 运行时序：模组 ENTER_FRAME 晚于游戏 World.step（输入系统事实，
    * shared-knowledge/ui-systems/facts/input-system.md）——
    * 本层读取本步已生效的公开状态，写入的决策在下一世界步生效（~1 帧延迟）。
    *
    * 门控：World 存在、非菜单（mm.active）、玩家在场（loc.gg 且 sost==1）。
    *
    * 全部游戏对象按动态访问（public 成员 bracket + try/catch 探测），
    * 不依赖任何 internal 字段。
    */
   public class TdfcMain
   {
      private static var stage:Stage = null;
      private static var tick:int = 0;
      private static var booted:Boolean = false;
      private static var worldCls:Class = null;
      private static var raiderCls:Class = null;

      private static var states:Dictionary = new Dictionary(); // Unit -> TacticalState
      private static var live:Dictionary = new Dictionary();   // 每帧在场集合（内存清扫）

      // 枪声检测状态
      private static var prevTA:Number = 0;
      private static var prevTWeap:Object = null;
      private static var prevGgNoise:int = 0;
      private static var lastGunshotTick:int = -999999;

      private static var lastSpawnTick:int = -999999;

      public static function init(main:*):void
      {
         if (booted)
         {
            return;
         }
         booted = true;
         try
         {
            stage = main["stage"];
         }
         catch (e:Error) {}
         if (stage == null)
         {
            TdfcLog.line("boot", "stage unavailable");
            return;
         }
         try
         {
            var ad:ApplicationDomain = ApplicationDomain.currentDomain;
            worldCls = ad.getDefinition("fe.World") as Class;
            if (worldCls != null)
            {
               raiderCls = ad.getDefinition("fe.unit.UnitRaider") as Class;
            }
         }
         catch (e:Error)
         {
            TdfcLog.line("boot", "reflection error: " + e.message);
         }
         stage.addEventListener(Event.ENTER_FRAME, onFrame);
         if (Config.ENABLE_TEST_SPAWN)
         {
            stage.addEventListener(KeyboardEvent.KEY_DOWN, onKey);
         }
      }

      // ============ 每帧 ============

      private static function onFrame(e:Event):void
      {
         tick++;
         if (tick >= 2000000000)
         {
            tick = 1;
         }

         var world:* = worldCls == null ? null : worldCls["w"];
         if (world == null)
         {
            return;
         }
         // 主菜单打开时 World.step 不运行（菜单门控事实），本层同样暂停
         var mm:* = world["mm"];
         if (mm != null && mm["active"] == true)
         {
            return;
         }
         var loc:* = world["loc"];
         if (loc == null)
         {
            return;
         }
         var gg:* = loc["gg"];
         if (gg == null)
         {
            return;
         }
         if (num(gg, "sost", 0) != 1)
         {
            return;
         }
         var units:Array = loc["units"];
         if (units == null)
         {
            return;
         }

         // ---- 感知层：玩家噪声治理（跑>走>慢>趴行无声，武器封顶）----
         Perception.governPlayerNoise(gg);

         // ---- 枪声事件（全局，先于单位循环）----
         if (Config.ENABLE_PROP_GUNSHOT)
         {
            detectGunshot(gg, loc, units);
         }

         // ---- 单位循环：事件检测 + 搜索 + 快照 ----
         live = new Dictionary();
         for (var i:int = 0; i < units.length; i++)
         {
            var u:* = units[i];
            live[u] = true;
            var ucls:String = shortClass(u); // 每帧每单位算一次，事件循环复用
            if (!isEnemy(u, ucls))
            {
               continue;
            }
            // 感知层：背后盲区（overLook=false）+ 智能层锥形视野
            Perception.governEnemySense(u, ucls);
            var st:TacticalState = state(u);
            var nowCelGG:Boolean = (u["celUnit"] === gg);

            // 目击传播：celUnit 由非玩家变为玩家 = 刚发现
            if (Config.ENABLE_PROP_VISION && !st.prevCelGG && nowCelGG)
            {
               Propagation.vision(units, u, gg, loc, tick);
            }

            // 受击传播：hp 下降
            if (!isNaN(st.prevHp) && num(u, "hp", 0) < st.prevHp)
            {
               st.lastHitTick = tick; // 受击记忆（Phase 2 掩体/撤退触发用）
               if (Config.ENABLE_PROP_DAMAGE)
               {
                  Propagation.damage(units, u, gg, loc, tick);
               }
            }

            // 记忆与搜索
            if (Config.ENABLE_SEARCH)
            {
               SearchCtrl.update(u, st, gg, loc, tick);
            }

            // Phase 2 生存层（瞄准回避/慢弹回避/掩体/撤退）
            if (Config.ENABLE_DODGE_AIM || Config.ENABLE_DODGE_THREAT
               || Config.ENABLE_COVER || Config.ENABLE_RETREAT)
            {
               TacticalCtrl.update(u, st, gg, loc, tick);
            }

            // 快照
            st.prevCelGG = nowCelGG;
            st.prevHp = num(u, "hp", 0);
         }

         // ---- 心跳 + 内存清扫 ----
         if (tick % Config.HEARTBEAT_EVERY == 0)
         {
            heartbeat(units, gg, loc);
            sweepStates();
         }
      }

      // ============ 枪声检测 ============

      private static function detectGunshot(gg:*, loc:*, units:Array):void
      {
         var w:* = gg["currentWeapon"];
         var fired:Boolean = false;
         if (w != null)
         {
            if (w !== prevTWeap)
            {
               prevTWeap = w;
               prevTA = num(w, "t_attack", 0);
            }
            else
            {
               var ta:Number = num(w, "t_attack", 0);
               if (ta > prevTA + 2)
               {
                  fired = true;
               }
               prevTA = ta;
            }
         }
         else
         {
            prevTWeap = null;
            prevTA = 0;
         }
         // 噪声抬升兜底（投掷/法术等非 currentWeapon 路径）
         var nz:int = int(num(gg, "noise", 0));
         if (nz > prevGgNoise + 20)
         {
            fired = true;
         }
         prevGgNoise = nz;

         if (fired && tick - lastGunshotTick >= Config.GUNSHOT_THROTTLE)
         {
            lastGunshotTick = tick;
            var radius:Number = Config.HEAR_RANGE;
            if (w != null)
            {
               var wn:Number = num(w, "noise", 0);
               if (wn > 0)
               {
                  radius = wn * 2;
               }
            }
            Propagation.gunshot(units, gg, loc, tick, radius);
         }
      }

      // ============ 工具 ============

      /** 安全读取数值成员（密封类 bracket 陷阱防护）。 */
      public static function num(o:*, n:String, d:Number):Number
      {
         var r:Number = d;
         try
         {
            var v:* = o[n];
            if (v is Number || v is int || v is uint)
            {
               r = Number(v);
            }
         }
         catch (e:Error) {}
         return r;
      }

      public static function jitter(err:Number):Number
      {
         return (Math.random() * 2 - 1) * err;
      }

      /** 非战斗单位名单：环境/脚本对象（无战术行为，不参与警戒传播）。
       *  依据 1.02 反编译核对：UnitTrigger/UnitTrap/UnitDestr/UnitMWall/Mine
       *  无武器无索敌；UnitDamager 是环境激光器、UnitVortex 是环境漩涡
       *  （有自己的 findCel 索敌但属机关，不应接收小队警报）。
       *  注意：UnitTrain 等真战斗单位不在名单内。 */
      private static const NON_COMBAT:Object = {
         UnitTrigger: 1, UnitDamager: 1, UnitTrap: 1, UnitDestr: 1,
         UnitMWall: 1, Mine: 1, UnitVortex: 1
      };

      /** 智能视觉层（v0.3）：0=人形/亡灵等智能，1=机械（僵硬），2=动物/无智能（不接入）。 */
      private static const INTEL_SAPS:Object = {
         UnitRaider: 1, UnitMerc: 1, UnitSlaver: 1, UnitZebra: 1,
         UnitEncl: 1, UnitPon: 1, UnitMsp: 1, UnitNecros: 1,
         UnitAlicorn: 1, UnitBossAlicorn: 1, UnitBossRaider: 1,
         UnitBossEncl: 1, UnitBossNecr: 1, UnitBossUltra: 1
      };
      private static const INTEL_DRONE:Object = {
         UnitGutsy: 1, UnitRobobrain: 1, UnitDron: 1, UnitSentinel: 1
      };

      /** 智能层判定：0=智能人形/亡灵，1=机械（僵硬公式化），2=动物（无智能，不接入）。 */
      public static function intelTier(cls:String):int
      {
         if (INTEL_SAPS[cls] === 1)
         {
            return 0;
         }
         if (INTEL_DRONE[cls] === 1)
         {
            return 1;
         }
         return 2;
      }

      /** 短类名（fe.unit::UnitRaider → UnitRaider）。 */
      public static function shortClass(u:*):String
      {
         var r:String = "?";
         try
         {
            r = getQualifiedClassName(u).split("::").pop().split(".").pop();
         }
         catch (e:Error) {}
         return r;
      }

      /** 敌性判定：非玩家/非NPC/非环境对象、阵营 1..99、存活、可被锁、有耳朵。 */
      public static function isEnemy(u:*, cls:String = null):Boolean
      {
         if (u == null)
         {
            return false;
         }
         if (cls == null)
         {
            cls = shortClass(u);
         }
         if (NON_COMBAT[cls] === 1)
         {
            return false;
         }
         if (u["player"] == true || u["npc"] == true)
         {
            return false;
         }
         var fr:int = int(num(u, "fraction", -1));
         if (fr < 1 || fr > 99)
         {
            return false;
         }
         if (num(u, "sost", 0) != 1)
         {
            return false;
         }
         if (u["disabled"] == true || u["unres"] == true)
         {
            return false;
         }
         if (num(u, "ear", 0) <= 0)
         {
            return false;
         }
         return true;
      }

      public static function state(u:*):TacticalState
      {
         var st:TacticalState = states[u];
         if (st == null)
         {
            st = new TacticalState();
            states[u] = st;
         }
         return st;
      }

      public static function tag(u:*):String
      {
         // getQualifiedClassName 返回 "fe.unit::UnitRaider"，转成 "UnitRaider"
         var q:String = "?";
         try
         {
            q = getQualifiedClassName(u);
         }
         catch (e:Error) {}
         q = q.split("::").pop().split(".").pop();
         return q + "@" + int(u["X"]) + "," + int(u["Y"]);
      }

      private static function heartbeat(units:Array, gg:*, loc:*):void
      {
         var searching:int = 0;
         var engaged:int = 0;
         var foes:int = 0;
         var hear:int = 0;  // 玩家听觉半径内（噪声×ear 判定）——"为什么没交战"诊断用
         var los:int = 0;   // 对玩家有视线（SIGHT_RANGE 内）
         var dodging:int = 0;
         var covering:int = 0;
         var retreating:int = 0;
         var px:Number = gg["X"];
         var py:Number = gg["Y"];
         for (var i:int = 0; i < units.length; i++)
         {
            var u:* = units[i];
            var ucls:String = shortClass(u);
            if (!isEnemy(u, ucls))
            {
               continue;
            }
            foes++;
            var st:TacticalState = states[u];
            if (st != null)
            {
               if (st.searchPhase == SearchCtrl.PHASE_SEARCH)
               {
                  searching++;
               }
               if (st.dodgeT > 0 || st.threatT > 0)
               {
                  dodging++;
               }
               if (st.coverPhase > 0)
               {
                  covering++;
               }
               if (st.retreatT > 0)
               {
                  retreating++;
               }
            }
            if (u["celUnit"] === gg)
            {
               engaged++;
            }
            var ear:Number = num(u, "ear", 1);
            var dx:Number = u["X"] - px;
            var dy:Number = u["Y"] - py;
            var d2:Number = dx * dx + dy * dy;
            if (d2 < (Config.HEAR_RANGE * ear) * (Config.HEAR_RANGE * ear))
            {
               hear++;
            }
            if (d2 < Config.SIGHT_RANGE * Config.SIGHT_RANGE && Los.toPlayer(u, loc, gg, Config.SIGHT_RANGE))
            {
               los++;
            }
         }
         TdfcLog.line("hb", "t=" + tick + " foes=" + foes + " engaged=" + engaged
            + " searching=" + searching + " hear=" + hear + " los=" + los
            + " dodge=" + dodging + " cover=" + covering + " retreat=" + retreating
            + " ggN=" + int(num(gg, "noise", 0)));
      }

      /** 清扫已离场单位的模组侧状态（防 Dictionary 强引用泄漏）。 */
      private static function sweepStates():void
      {
         var dead:Array = [];
         for (var key:Object in states)
         {
            if (live[key] !== true)
            {
               dead.push(key);
            }
         }
         for (var i:int = 0; i < dead.length; i++)
         {
            delete states[dead[i]];
         }
      }

      // ============ F9 测试生成（实验性）============

      private static function onKey(e:KeyboardEvent):void
      {
         if (e.keyCode != 120)
         {
            return; // F9
         }
         if (tick - lastSpawnTick < 60)
         {
            return;
         }
         lastSpawnTick = tick;
         spawnTestRaider();
      }

      private static function spawnTestRaider():void
      {
         if (raiderCls == null)
         {
            TdfcLog.line("spawn", "no raider class");
            return;
         }
         try
         {
            var world:* = worldCls["w"];
            var loc:* = world["loc"];
            var gg:* = loc["gg"];
            var r:* = new raiderCls("raider", 100, null, null);
            if (r == null)
            {
               TdfcLog.line("spawn", "ctor returned null");
               return;
            }
            r["fraction"] = 1; // 显式敌性（XML 节点缺失时兜底）
            r["putLoc"](loc, gg["X"] + 260, gg["Y"] + 40);
            loc["addObj"](r);
            (loc["units"] as Array).push(r);
            var hasWep:* = r["currentWeapon"] != null;
            TdfcLog.line("spawn", "raider spawned at "
               + int(r["X"]) + "," + int(r["Y"]) + " weapon=" + hasWep);
         }
         catch (e:Error)
         {
            TdfcLog.line("spawn", "FAILED: " + e.message);
         }
      }
   }
}
