package
{
   /**
    * Phase 2 生存层控制器（瞄准回避 / 慢弹回避 / 掩体评估 / 撤退协议）。
    *
    * 机制（见 design/phase2-enemy-survival.md §2）：
    *  - celX/celY 直写（保留 celUnit=gg，不打断交战）：驱动原版"走向目标点"
    *    逻辑（|celDX|>100 死区、每 15 tick 更新方向、跳跃爬坡）——用于
    *    掩体与撤退；
    *  - dx 直写：原版 forces() 对 [-maxSpeed, maxSpeed] 内的 dx 不施加摩擦，
    *    vanilla 每步不清理 → 用于侧移躲避（横向离开玩家/威胁）。
    *  - 行为互斥 + 固定优先级：撤退 > 掩体 > 威胁躲避 > 瞄准躲避。
    *
    * 全 public API，不读写 internal。
    */
   public class TacticalCtrl
   {
      // ---- 按类 doctrine（d=躲避概率 c=掩体 r=撤退血量比例；缺省档 0.2/true/0.3）----
      private static const DOCTRINE:Object = {
         UnitRaider:    { d: 0.4,  c: 1, r: 0.25 },
         UnitMerc:      { d: 0.3,  c: 1, r: 0.3  },
         UnitSlaver:    { d: 0.35, c: 1, r: 0.3  },
         UnitZebra:     { d: 0.35, c: 1, r: 0.3  },
         UnitEncl:      { d: 0.25, c: 1, r: 0.3  },
         UnitPon:       { d: 0.3,  c: 1, r: 0.3  },
         UnitMsp:       { d: 0.3,  c: 1, r: 0.3  },
         UnitMonstrik:  { d: 0.5,  c: 0, r: 0.15 },
         UnitHellhound: { d: 0.5,  c: 0, r: 0.15 },
         UnitBat:       { d: 0.5,  c: 0, r: 0.15 },
         UnitAnt:       { d: 0.5,  c: 0, r: 0.15 },
         UnitSpectre:   { d: 0.5,  c: 0, r: 0.1  },
         UnitNecros:    { d: 0.3,  c: 0, r: 0.2  },
         UnitSlime:     { d: 0.2,  c: 0, r: 0.1  },
         UnitGutsy:     { d: 0,    c: 0, r: 0.05 },
         UnitBloat:     { d: 0,    c: 0, r: 0.05 },
         UnitAIRobot:   { d: 0,    c: 0, r: 0.1  },
         UnitRobobrain: { d: 0,    c: 0, r: 0.1  },
         UnitDron:      { d: 0,    c: 0, r: 0.1  },
         UnitSentinel:  { d: 0,    c: 0, r: 0.1  },
         UnitThunderHead:    { d: 0, c: 0, r: 0.1 },
         UnitThunderTurret:  { d: 0, c: 0, r: 0.1 },
         UnitTurret:    { d: 0,    c: 0, r: 0.1  },
         UnitTrain:     { d: 0,    c: 0, r: 0.1  }
      };

      private static const TOL_RAD:Number = Config.AIM_TOL_DEG * Math.PI / 180;
      private static const COVER_DISTS:Array = [60, 120, 180];

      /** 每帧更新单个单位的 Phase 2 行为。返回 true 表示本帧 TDFC 发出了移动指令。 */
      public static function update(u:*, st:TacticalState, gg:*, loc:*, tick:int):Boolean
      {
         var px:Number = TdfcMain.num(gg, "X", 0);
         var py:Number = TdfcMain.num(gg, "Y", 0);
         var ux:Number = TdfcMain.num(u, "X", 0);
         var uy:Number = TdfcMain.num(u, "Y", 0);
         var ucls:String = TdfcMain.shortClass(u);

         // ---- 活跃门控：交战 / 最近目击 / 最近受击，否则清空临时状态 ----
         var active:Boolean = (u["celUnit"] === gg)
            || (tick - st.lastHitTick) < 300
            || (tick - st.lastSeenTick) < 300;
         if (!active)
         {
            st.dodgeT = 0; st.threatT = 0; st.coverPhase = 0;
            st.retreatT = 0; st.aimExposed = 0;
            return false;
         }

         // ---- 触发条件互斥判断 ----
         var inCover:Boolean = st.coverPhase > 0;
         var inRetreat:Boolean = st.retreatT > 0;

         // ===== A. 瞄准回避 =====
         if (Config.ENABLE_DODGE_AIM && !inCover && !inRetreat && st.threatT <= 0)
         {
            var aimed:Boolean = playerAimingAt(u, gg, loc, ux, uy, px, py);
            if (aimed)
            {
               st.aimExposed++;
            }
            else
            {
               st.aimExposed = 0;
            }
            if (st.dodgeT <= 0 && aimed
               && tick - st.lastDodgeTick >= Config.DODGE_CD
               && Math.random() < doct(ucls, "d"))
            {
               st.dodgeT = Config.DODGE_TICKS;
               st.dodgeDir = (ux >= px) ? 1 : -1; // 水平离开玩家方向
               st.lastDodgeTick = tick;
               TdfcLog.line("dodge", "AIM " + TdfcMain.tag(u));
            }
            if (st.dodgeT > 0)
            {
               st.dodgeT--;
            }
         }

         // ===== B. 慢弹威胁躲避 =====
         if (Config.ENABLE_DODGE_THREAT && !inCover && !inRetreat)
         {
            st.threatScan--;
            if (st.threatScan <= 0)
            {
               st.threatScan = Config.THREAT_SCAN_CD;
               if (st.threatT <= 0)
               {
                  var t:* = findThreat(loc, u, ux, uy);
                  if (t != null)
                  {
                     st.threatT = Config.THREAT_DODGE_TICKS;
                     st.threatDir = (ux >= TdfcMain.num(t, "X", ux)) ? 1 : -1;
                     st.lastDodgeTick = tick;
                     TdfcLog.line("threat", "PROJ " + TdfcMain.tag(u));
                  }
               }
            }
            if (st.threatT > 0)
            {
               st.threatT--;
            }
         }

         // ===== C. 掩体 =====
         if (Config.ENABLE_COVER && !inRetreat && st.threatT <= 0 && st.dodgeT <= 0
            && doct(ucls, "c") > 0)
         {
            var hitRecently:Boolean = (tick - st.lastHitTick) < 90;
            if (st.coverPhase == 0
               && (hitRecently || st.aimExposed >= Config.EXPOSED_TICKS)
               && tick - st.lastCoverTick >= Config.COVER_CD)
            {
               var cp:* = findCoverPoint(loc, u, ux, uy, px, py);
               if (cp != null)
               {
                  st.coverPhase = 1; // SEEK
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
               // 到达判定：原版接近死区约 100px
               var ddx:Number = st.coverX - ux;
               var ddy:Number = st.coverY - uy;
               if (ddx * ddx + ddy * ddy < Config.COVER_ARRIVE * Config.COVER_ARRIVE
                  || st.coverT <= 0)
               {
                  st.coverPhase = 2; // HIDE
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
               // 破点：玩家逼近或超时 → 解除
               if (dist2(u, gg) < Config.BREACH_RANGE * Config.BREACH_RANGE
                  || st.coverT <= 0)
               {
                  st.coverPhase = 0;
                  st.lastCoverTick = tick;
                  TdfcLog.line("cover", "EXIT " + TdfcMain.tag(u));
               }
            }
         }

         // ===== D. 撤退 =====
         if (Config.ENABLE_RETREAT && !inCover && st.threatT <= 0 && st.dodgeT <= 0
            && doct(ucls, "r") > 0)
         {
            var hp:Number = TdfcMain.num(u, "hp", 0);
            var mhp:Number = TdfcMain.num(u, "maxhp", 1);
            if (st.retreatT <= 0 && mhp > 0
               && hp / mhp < Config.RETREAT_RATIO
               && (tick - st.lastHitTick) < 120
               && Los.toPlayer(u, loc, gg, 900))
            {
               var rx:Number = ux + (ux - px > 0 ? 1 : -1) * Config.RETREAT_DIST;
               var ry:Number = uy;
               // 简单可达性：目标瓦片非实体，否则缩短
               if (tileSolid(loc, rx, ry))
               {
                  rx = ux + (ux - px > 0 ? 1 : -1) * 140;
                  if (tileSolid(loc, rx, ry))
                  {
                     rx = ux - (ux - px > 0 ? 1 : -1) * 120; // 反方向兜底
                  }
               }
               st.retreatT = Config.RETREAT_MAX;
               st.retreatX = rx;
               st.retreatY = ry;
               TdfcLog.line("retreat", "GO " + TdfcMain.tag(u)
                  + " hp=" + int(hp) + "/" + int(mhp)
                  + " to " + int(rx) + "," + int(ry));
            }
            if (st.retreatT > 0)
            {
               st.retreatT--;
               // 玩家逼近 → 背水一战
               if (dist2(u, gg) < Config.BACKS_BREACH * Config.BACKS_BREACH)
               {
                  st.retreatT = 0;
                  TdfcLog.line("retreat", "ABORT breach " + TdfcMain.tag(u));
               }
               else if (st.retreatT <= 0)
               {
                  TdfcLog.line("retreat", "END " + TdfcMain.tag(u));
               }
            }
         }

         // ===== 写入仲裁：撤退 > 掩体 > 威胁躲避 > 瞄准躲避 =====
         var acted:Boolean = false;
         if (st.retreatT > 0)
         {
            writeCel(u, st.retreatX, st.retreatY);
            acted = true;
         }
         else if (st.coverPhase > 0)
         {
            if (st.coverPhase == 2 && st.peekOn && u["currentWeapon"] != null)
            {
               writeCel(u, px, py); // 探头：指向玩家开火
            }
            else
            {
               writeCel(u, st.coverX, st.coverY); // 缩回/移动
            }
            acted = true;
         }
         else if (st.threatT > 0)
         {
            writeDx(u, st.threatDir);
            acted = true;
         }
         else if (st.dodgeT > 0)
         {
            writeDx(u, st.dodgeDir);
            acted = true;
         }
         return acted;
      }

      // ============ 玩家瞄准检测 ============

      /** 玩家武器瞄准线是否指向本敌人（武器 rot、距离、LOS）。 */
      private static function playerAimingAt(u:*, gg:*, loc:*,
         ux:Number, uy:Number, px:Number, py:Number):Boolean
      {
         var w:* = gg["currentWeapon"];
         if (w == null)
         {
            return false;
         }
         var tip:Number = TdfcMain.num(w, "tip", 0);
         if (tip < 3)
         {
            return false; // 近战/空手
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
         var rot:Number = TdfcMain.num(w, "rot", 0);
         var aim:Number = Math.atan2(dy, dx);
         var diff:Number = rot - aim;
         while (diff > Math.PI) diff -= Math.PI * 2;
         while (diff < -Math.PI) diff += Math.PI * 2;
         if (Math.abs(diff) > TOL_RAD)
         {
            return false;
         }
         return Los.toPlayer(u, loc, gg, Config.AIM_DODGE_RANGE);
      }

      // ============ 慢弹威胁扫描 ============

      /**
       * 在 firstObj 链上找威胁弹体：慢速（vel<阈值）且相对运动扫掠会命中本敌。
       * 相对速度扫掠（shared-knowledge projectile-step-sweep）：
       * O=弹-敌起点差，RV=弹速-敌速，最近点 t*∈[0,1] 距离 < 命中半径 → 威胁。
       */
      private static function findThreat(loc:*, u:*, ux:Number, uy:Number):Object
      {
         var uvx:Number = TdfcMain.num(u, "dx", 0);
         var uvy:Number = TdfcMain.num(u, "dy", 0);
         var hitR:Number = Config.THREAT_HIT_R;
         var proj:* = loc["firstObj"];
         var nodes:int = 0;
         while (proj != null && nodes < 256)
         {
            nodes++;
            var cls:String = TdfcMain.shortClass(proj);
            if (cls == "Bullet" || cls == "PhisBullet" || cls == "SmartBullet")
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
                     var t:Number = 0;
                     if (len2 > 0)
                     {
                        var dot:Number = ox * rvx + oy * rvy;
                        t = Math.max(0, Math.min(1, -dot / len2));
                     }
                     var cx:Number = ox + t * rvx;
                     var cy:Number = oy + t * rvy;
                     var dmin:Number = Math.sqrt(cx * cx + cy * cy);
                     var rr:Number = hitR + TdfcMain.num(proj, "explRadius", 0);
                     if (dmin < rr)
                     {
                        return proj;
                     }
                  }
               }
            }
            proj = proj["nobj"];
         }
         return null;
      }

      // ============ 掩体点搜索 ============

      /**
       * 8 方向 × 3 距离采样候选点；候选点自身非实体，且候选→玩家线段被瓦片遮挡
       * （掩体语义）。返回最近者。仅瓦片（用户确认：念力箱不挡视线）。
       */
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
               // 候选→玩家被遮挡 = 该点可作为掩体
               if (!Los.clear(loc, dx, dy, px, py))
               {
                  if (bestD < 0 || COVER_DISTS[di] < bestD)
                  {
                     bestD = COVER_DISTS[di];
                     bestX = dx;
                     bestY = dy;
                  }
                  break; // 同方向取最近距离即可
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

      /** dx 直写侧移（原版 forces() 不清理 [-maxSpeed,maxSpeed] 内的 dx）。 */
      private static function writeDx(u:*, dir:int):void
      {
         try
         {
            var sp:Number = TdfcMain.num(u, "maxSpeed", 10);
            u["dx"] = dir * sp;
         }
         catch (e:Error) {}
      }

      private static function tileSolid(loc:*, x:Number, y:Number):Boolean
      {
         var solid:Boolean = true; // 保守：探测失败按实体处理
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

      /** doctrine 取值：d=躲避概率 c=掩体开关 r=撤退血量比例。 */
      private static function doct(cls:String, key:String):Number
      {
         var e:Object = DOCTRINE[cls];
         if (e == null)
         {
            e = { d: 0.2, c: 1, r: 0.3 }; // 缺省档
         }
         return e[key];
      }
   }
}