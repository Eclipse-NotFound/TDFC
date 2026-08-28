package
{
   /**
    * TDFC Phase 1 参数表。
    * 所有阈值/半径/冷却集中在当前模组（mods/TDFC/），不做公共知识。
    * v0.1 以常量形式存在；后续版本再考虑运行时配置。
    */
   public class Config
   {
      public static const VER:String = "0.5.2";

      // ---- 行为开关（逐个验证用）----
      public static const ENABLE_PROP_VISION:Boolean  = true; // 目击传播（分级：LOS 精确 / 听觉模糊）
      public static const ENABLE_PROP_GUNSHOT:Boolean = true; // 枪声事件（位置提示 + 诊断）
      public static const ENABLE_PROP_DAMAGE:Boolean  = true; // 受击传播（全队收敛）
      public static const ENABLE_SEARCH:Boolean       = true; // 记忆与搜索
      public static const ENABLE_TEST_SPAWN:Boolean   = true; // F9 生成测试敌人（实验性）
      // Phase 2 生存层
      public static const ENABLE_DODGE_AIM:Boolean    = true; // 瞄准回避
      public static const ENABLE_DODGE_THREAT:Boolean = true; // 慢弹回避
      public static const ENABLE_COVER:Boolean        = true; // 掩体评估
      public static const ENABLE_RETREAT:Boolean      = true; // 撤退协议

      // ---- 传播参数 ----
      public static const SIGHT_RANGE:Number = 700;      // 目击传播判定半径（LOS 检查上限）
      public static const HEAR_RANGE:Number  = 500;      // 听觉模糊传播半径（乘以单位 ear）
      public static const DAMAGE_RANGE:Number = 450;     // 受击传播半径
      public static const GUNSHOT_RANGE:Number = 800;    // 枪声位置提示半径
      public static const PRECISE_ERR:Number = 30;       // LOS 精确传播位置误差 px
      public static const HEAR_ERR:Number    = 100;      // 听觉传播位置误差 px
      public static const SPREAD_NOISE:Number = 400;     // 战斗噪声脉冲（写入 gg.noise，起疑通道）
      public static const PROP_CD_VISION:int  = 90;      // 目击传播每单位冷却（tick）
      public static const PROP_CD_GUNSHOT:int = 60;      // 枪声传播每单位冷却
      public static const PROP_CD_DAMAGE:int  = 90;      // 受击传播每单位冷却
      public static const GUNSHOT_THROTTLE:int = 8;      // 枪声事件全局最小间隔（防连射刷屏）

      // ---- 搜索参数 ----
      public static const SEARCH_TIMEOUT:int  = 300;     // 搜索总时长（tick）
      public static const SEARCH_RECHECK:int  = 10;      // 复查玩家视线间隔
      public static const SEARCH_REFRESH:int  = 90;      // 重设调查点间隔
      public static const SEARCH_REACQ_RANGE:Number = 900; // 复查视线最大距离

      // ---- Phase 2：瞄准回避 ----
      public static const AIM_DODGE_RANGE:Number = 350;  // 玩家瞄准线判定半径
      public static const AIM_TOL_DEG:Number = 8;        // 瞄准夹角容差（度）
      public static const DODGE_TICKS:int = 10;          // 短促躲避冲量窗口（<原版10tick findCel周期）
      public static const DODGE_HOP:Number = 0.8;        // 起跳力度系数（×jumpdy，每跳随机 ±）
      public static const DODGE_FLAT_SIN:Number = 0.5;   // |sin(弹道角)|<此值=平射→跳跃；否则水平走位

      // ---- Phase 2：慢弹回避 ----
      public static const SLOW_SPEED_THRESH:Number = 60; // 低于此速度的弹体才预测（快弹归瞄准回避）
      public static const THREAT_SCAN_CD:int = 15;       // 每敌威胁扫描间隔
      public static const THREAT_HIT_R:Number = 24;      // 命中判定半径（敌半径近似）
      public static const THREAT_DODGE_TICKS:int = 8;    // 短促威胁躲避窗口

      // ---- Phase 2：掩体 ----
      public static const EXPOSED_TICKS:int = 30;        // 被瞄准暴露累计触发掩体
      public static const COVER_CD:int = 150;            // 掩体行为冷却（~5s）
      public static const COVER_MAX_TICKS:int = 300;     // 掩体停留上限（防龟缩）
      public static const PEEK_MIN:int = 12;             // 探头周期下限
      public static const PEEK_MAX:int = 20;             // 探头周期上限
      public static const PEEK_WINDOW:int = 4;           // 探头持续时间
      public static const BREACH_RANGE:Number = 150;     // 玩家逼近解除掩体距离
      public static const COVER_ARRIVE:Number = 110;     // 到达判定（含原版100px死区）

      // ---- Phase 2：撤退 ----
      public static const RETREAT_RATIO:Number = 0.3;    // hp 比例阈值
      public static const RETREAT_MAX:int = 180;         // 最大撤退时长
      public static const RETREAT_DIST:Number = 240;     // 撤退距离
      public static const BACKS_BREACH:Number = 120;     // 玩家逼近改背水一战

      // ---- 声源位置冻结（问题 3 修复）----
      public static const POSITION_FREEZE:int = 120;     // 无 LOS 声源位置冻结时长（tick）

      // ---- v0.3：精准接管（仅智能层）----
      public static const ACC_MOVE_MULT:Number = 0.35;   // 移动/躲时 weaponSkill 倍率（散布反比）
      public static const ACC_SETTLE_TICKS:int = 8;      // 站桩开火窗口长度（tick）
      public static const ACC_SETTLE_IDLE:int = 20;      // 未被瞄准多久可进入站桩
      public static const SETTLE_FORCE_CHANCE:Number = 0.02; // 顶着瞄准放冷枪概率（每帧）

      // ---- v0.4：感知层（噪声治理 + 视野）----
      public static const NOISE_RUN:Number = 150;        // 跑动噪声（原版 200 下调）
      public static const NOISE_WALK:Number = 80;        // 行走噪声（原版 100 下调）
      public static const NOISE_SLOW:Number = 25;        // 慢走噪声（原版 50 下调）
      public static const NOISE_SNEAK:Number = 0;        // 趴行/坐姿：无声
      public static const NOISE_WEAPON_CAP:Number = 500; // 武器噪声封顶（原版可达 1000+）
      public static const VISION_CONE:Number = 2.4;      // 智能层视野锥（弧度，±68.7° 正面）

      // ---- v0.4.1：目击确认 + 传播延迟 ----
      public static const SPOT_CONFIRM_TICKS:int = 12;   // 目击确认窗口（~0.4s，持续目击才报信）
      public static const PROP_DELAY_SPEED:Number = 20;  // 传播速度 px/tick（距离/速度=延迟）
      public static const PROP_DELAY_MAX:int = 60;       // 传播延迟上限 tick

      // ---- v0.4.2：墙角固守 ----
      public static const CORNERED_LOCK:int = 60;        // 墙角锁位时长（tick），期间不躲不跳

      // ---- v0.5：配合层（小队/压制/散开/交叉火力）----
      public static const ENABLE_SQUAD:Boolean     = true; // 小队扫描与角色分配（压制/散开/交叉火力的前置）
      public static const ENABLE_SUPPRESS:Boolean  = true; // 压制协议（命令开火，需 ENABLE_SQUAD）
      public static const ENABLE_SPACING:Boolean   = true; // 散开间距
      public static const ENABLE_CROSSFIRE:Boolean = true; // 交叉火力站位偏置（掩体/走位落点选边）

      public static const SQUAD_SCAN_EVERY:int = 30;     // 小队扫描间隔（tick）
      public static const SQUAD_RADIUS:Number  = 700;    // 战斗圈半径（距玩家；成员须在圈内）
      public static const SUPPRESS_TICKS:int   = 150;    // 压制窗口时长（~5s 封顶）
      public static const SUPPRESS_CD:int      = 300;    // 压制冷却（每压制者）
      public static const SUPPRESS_MATE_HP:Number = 0.3;   // 同伴血量比例触发线
      public static const SUPPRESS_MATE_HIT_WINDOW:int = 90; // 同伴最近受击窗口
      public static const SUPPRESS_PURSUIT:Number = 260;   // 玩家逼近换弹同伴的判定距离
      public static const SUPPRESS_CHECK:int   = 15;     // 压制触发检查节拍（每压制者）
      public static const ACC_SUPPRESS_MULT:Number = 0.45; // 压制射击精准倍率（×weaponSkill 基线）
      public static const SPACING_MIN:Number   = 70;     // 最小同伴间距 px
      public static const SPACING_CHECK:int    = 30;     // 间距检查间隔（每单位错峰）
      public static const SPACING_TICKS:int    = 8;      // 分散冲量窗口
      public static const SPACING_MULT:Number  = 0.8;    // 分散冲量速度系数（×runSpeed）

      // ---- 诊断 ----
      public static const LOG_PATH:String = "mods/TDFC/state/logs/tdfc.log";
      public static const LOG_MAX_BYTES:Number = 2 * 1024 * 1024; // 超限重建
      public static const DIAG_CAP:int = 300;            // 每功能诊断行上限
      public static const HEARTBEAT_EVERY:int = 600;     // 心跳日志间隔
   }
}
