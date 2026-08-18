package
{
   /**
    * Phase 2 生存层控制器（瞄准回避 / 慢弹回避 / 掩体评估 / 撤退协议）。
    *
    * v0.2.1 修复（用户实测反馈）：
    *  1. 瞄准回避：弃用 dx 直写（与 brake 摩擦互搏 → 原地抽搐），改为
    *     cel 躲避点（原版平滑走位）+ Y 轴起跳（dy=-jumpdy×系数，玩家平射时）。
    *  2. 慢弹回避：弃用 dx 直写（撞墙触发原版自动跳墙 → 惊慌乱跳），改为
    *     cel 方向性回避点（弹速垂直方向采样非实体点）；PhisBullet（投掷手雷）
    *     交还原版 findGrenades 恐惧（loc.grenades 数组，1.02 反编译确认），
    *     TDFC 只处理 Bullet/SmartBullet（榴弹/火箭/导弹）——消除双重惊慌。
    *  3. 隔墙瞄准：无 LOS 声源位置按单位冻结（POSITION_FREEZE），不再实时
    *     追踪玩家（配合 2026-08-18 候选机制 D 的冻结部分）。
    *  4. 撤退：优先级提到掩体之前；低血（<RETREAT_RATIO）时掩体不抢占；
    *     撤退可打断掩体并复用其掩体点；受击窗口放宽到 300 tick。
    *
    * 机制（见 design/phase2-enemy-survival.md §2）：
    *  - celX/celY 直写（保留 celUnit=gg，不打断交战）：驱动原版"走向目标点"
    *    逻辑（|celDX|>100 死区、每 15 tick 更新方向、跳跃爬坡）。
    *  - dy 直写起跳：jumpdy public，dy=-jumpdy×系数后原版重力自然回落。
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
      private static const THREAT_AVOID_DISTS:Array = [90, 160];
      private static const LEVEL_AIM_DY:Number = 60;   // 平射判定（|玩家-敌|高度差）
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

         // ===== D. 撤退（优先于掩体：低血时离开而不是就近躲）=====
         if (Config.ENABLE_RETREAT && st.threatT <= 0 && st.dodgeT <= 0
            && doct(ucls, "r") > 0)
         {
            if (!inRetreat && hpRatio < Config.RETREAT_RATIO
               && (tick - st.lastHitTick) < HIT_WINDOW
               && Los.toPlayer(u, loc, gg, 900))
            {
               // 打断掩体并复用掩体点；无掩体点则朝远离玩家方向
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
                        rx = ux - side * 120; // 反方向兜底
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
               // 玩家逼近 → 背水一战
               if (dist2(u, gg) < Config.BACKS_BREACH * Config.BACKS_BREACH)
               {
                  st.retreatT = 0;
                  TdfcLog.line("retreat", "ABORT breach " + TdfcMain.tag(u));
               }
               else if (st.retreatT <= 0)
               {
                  TdfcLog.line("retreat", "END " + TdfcMain.tag(u));
                  // 撤退结束仍低血且可掩体 → 转入掩体固守
                  if (Config.ENABLE_COVER && doct(ucls, "c") > 0
                     && hpRatio < Config.RETREAT_RATIO * 1.4
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
                        TdfcLog.line("cover", "SEEK(after retreat) " + TdfcMain.tag(u));
                     }
                  }
               }
            }
         }

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
               // 2D 躲避：水平躲避点（避开实体瓦片）+ Y 轴起跳（平射时越过弹线）
               var hop:Boolean = false;
               if (Math.abs(py - uy) < LEVEL_AIM_DY && u["stay"] == true)
               {
                  hop = true;
               }
               var ddx:Number = ux + st.dodgeDir * Config.DODGE_DIST;
               if (tileSolid(loc, ddx, uy))
               {
                  ddx = ux - st.dodgeDir * Config.DODGE_DIST;
                  st.dodgeDir = -st.dodgeDir;
                  if (tileSolid(loc, ddx, uy))
                  {
                     ddx = ux; // 两侧都被挡：只起跳（或原地）
                  }
               }
               st.dodgeX = ddx;
               st.dodgeY = uy;
               if (hop)
               {
                  try
                  {
                     u["dy"] = -TdfcMain.num(u, "jumpdy", 15) * Config.DODGE_HOP;
                  }
                  catch (e:Error) {}
               }
               TdfcLog.line("dodge", "AIM " + TdfcMain.tag(u)
                  + " hop=" + (hop ? 1 : 0) + " to " + int(ddx));
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
                     st.lastDodgeTick = tick;
                     // 垂直弹速方向采样躲避点（cel 引导，原版平滑绕行）
                     var rot:Number = TdfcMain.num(t, "rot", 0);
                     var pvx:Number = Math.cos(rot);
                     var pvy:Number = Math.sin(rot);
                     var pt:* = pickSafePoint(loc, ux, uy, pvy, -pvx); // 垂直一侧
                     if (pt == null)
                     {
                        pt = pickSafePoint(loc, ux, uy, -pvy, pvx);    // 另一侧
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
                     // 平射威胁 + 在地面 → 起跳
                     if (Math.abs(pvy) < 0.5 && u["stay"] == true)
                     {
                        try
                        {
                           u["dy"] = -TdfcMain.num(u, "jumpdy", 15) * Config.DODGE_HOP;
                        }
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
            && doct(ucls, "c") > 0)
         {
            var hitRecently:Boolean = (tick - st.lastHitTick) < 90;
            if (st.coverPhase == 0
               && hpRatio >= Config.RETREAT_RATIO // 低血不抢占（留给撤退）
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
       * 只处理 Bullet（榴弹/火箭直射）与 SmartBullet（导弹）——PhisBullet
       * （投掷手雷）交还原版 findGrenades 恐惧，避免双重反应。
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

      /** 沿 (dx,dy) 方向采样躲避点：多个距离取第一个非实体瓦片点。 */
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