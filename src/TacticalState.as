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

      public function TacticalState()
      {
      }
   }
}
