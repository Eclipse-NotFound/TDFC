package
{
   /**
    * 模组侧每单位战术状态。
    * 原版 aiState/aiSpok/aiTCh 均为 internal（模组不可读写），
    * 因此所有跨帧记忆保存在这里（Dictionary<Unit, TacticalState>）。
    */
   public class TacticalState
   {
      // ---- 帧间快照（事件检测用 diff）----
      public var prevCelGG:Boolean = false;  // 上一帧 celUnit == 玩家
      public var prevHp:Number = NaN;        // 上一帧 hp（受击检测）

      // ---- 记忆 ----
      public var lastSeenX:Number = 0;       // 最后目击玩家位置
      public var lastSeenY:Number = 0;
      public var lastSeenTick:int = -999999; // 最后目击的世界帧号

      // ---- 搜索 ----
      public var searchPhase:int = 0;        // 0=无 1=搜索中 2=已放弃
      public var searchTick:int = 0;         // 搜索剩余时长
      public var recheckTick:int = 0;        // 视线复查倒计时
      public var refreshTick:int = 0;        // 调查点刷新倒计时
      public var searchX:Number = 0;         // 调查目标点
      public var searchY:Number = 0;

      // ---- 传播冷却 ----
      public var cdVision:int = -999999;     // 目击传播冷却（世界帧号）
      public var cdGunshot:int = -999999;
      public var cdDamage:int = -999999;

      // ---- 受击记忆（Phase 2 用）----
      public var lastHitTick:int = -999999;  // 最近受击世界帧号

      // ---- Phase 2：瞄准回避 ----
      public var lastDodgeTick:int = -999999;// 最近一次躲避开始帧
      public var dodgeT:int = 0;             // 剩余躲避冲量窗口 tick（>0 活动）
      public var dodgeVX:Number = 0;         // 躲避冲量速度分量（每帧写 dx）
      public var dodgeVY:Number = 0;         // 垂直分量（飞行/游泳用，地面=0）
      public var aimExposed:int = 0;         // 被玩家瞄准累计 tick

      // ---- Phase 2：慢弹回避 ----
      public var threatScan:int = 0;         // 威胁扫描节拍
      public var threatT:int = 0;            // 剩余威胁躲避冲量窗口
      public var threatVX:Number = 0;        // 威胁躲避冲量速度分量
      public var threatVY:Number = 0;

      // ---- 声源位置冻结（问题 3：防无 LOS 隔墙实时追踪）----
      public var nudgeTick:int = -999999;    // 最近一次声源位置更新时间
      public var nudgeX:Number = 0;          // 冻结的声源位置
      public var nudgeY:Number = 0;

      // ---- Phase 2：掩体 ----
      public var coverPhase:int = 0;         // 0=无 1=SEEK 2=HIDE
      public var coverT:int = 0;             // 掩体剩余总时长
      public var peekT:int = 0;              // 探头节拍
      public var peekOn:Boolean = false;     // 当前是否探头
      public var coverX:Number = 0;          // 掩体点
      public var coverY:Number = 0;
      public var lastCoverTick:int = -999999;

      // ---- Phase 2：撤退 ----
      public var retreatT:int = 0;           // 剩余撤退 tick
      public var retreatX:Number = 0;        // 撤退点
      public var retreatY:Number = 0;

      // ---- cel 位移（狙击走位等需要真的移动到某点）----
      public var relocT:int = 0;             // 剩余 cel 位移 tick
      public var relocX:Number = 0;          // 位移目标点
      public var relocY:Number = 0;

      // ---- v0.3：开火窗口与精准接管 ----
      public var settleT:int = 0;            // 站桩开火窗口剩余 tick
      public var aimIdle:int = 0;            // 未被瞄准累计 tick
      public var baseSkill:Number = 0;       // 原版 weaponSkill 基线（首次记录）
      public var lastSniperTick:int = -999999; // 狙击走位冷却
      public var lastHopTick:int = -999999;  // 起跳节奏节拍（防墙边/连续起跳乱跳）

      public function TacticalState()
      {
      }
   }
}
