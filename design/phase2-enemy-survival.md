# TDFC Phase 2 设计：生存层（瞄准回避 / 慢弹回避 / 掩体评估 / 撤退协议）

- 日期：2026-08-17
- 状态：design / 待用户确认
- 前置：`design/brainstorm-01-enemy-ai.md` 第 2 节的设想 1/3；Phase 1 已实测验收
- 版本目标：v0.2.0（在 v0.1.1 基础上增量）

---

## 1. 设计目标

让敌人在实战中从"站着/走着挨打"变成"会规避、会利用地形、会战略性撤退"。
四个行为：

| # | 行为 | 解决的问题 |
|---|------|-----------|
| A | 瞄准回避 | 玩家站着瞄准扫射时敌人是不动的活靶（贴脸输出窗口过长） |
| B | 慢弹回避 | 手雷/榴弹/火箭这类慢速弹敌人闷头挨炸（原版只有 grenade 恐惧） |
| C | 掩体评估 | 暴露在开阔地挨打时不去找遮挡 |
| D | 撤退协议 | 低血还站桩输出，被轻易补死 |

与 Phase 1 的关系：信息层（传播/搜索）已让敌人"知道你在哪"；Phase 2 让敌人
"应对你"。两者正交，Phase 2 完全复用 Phase 1 的框架
（TacticalState/TdfcMain 帧环/Los/日志）。

---

## 2. 硬约束回顾（Phase 1 实测确认）

1. `aiState/aiSpok/aiTCh/maxSpok/tstor/aiNapr` 全部 **internal**——状态机内部不可读写。
2. 原版**每个 step 会重写** celX/celY、walk、dx/dy、maxSpeed、storona（从内部状态推导）。
   模组 ENTER_FRAME 在游戏 step 之后运行 → 模组写什么，只对**下一 step** 生效，
   且下个 step 的 control() 还会再覆盖。
3. 玩家噪声 `gg.noise`（public）是唯一"唤醒/起疑"通道（internal 的 aiSpok 只被
   原版 listen() 抬升）。
4. 敌人是否交战可从 public 观测：`celUnit==gg`、`currentWeapon`（public）、
   Weapon.t_attack/t_reload（public）、UnitX/Y、dx/dy/stay/walk/maxSpeed（public）。
5. `Weapon.attack()` 是 public —— 模组可以**命令敌人开火**（Phase 3 压制的基础）。

### 2.1 移动覆盖的三种候选机制（Phase 2 核心决策）

**实现前新增确认的两个 vanilla 事实（1.02 反编译）**：
- 交战接近逻辑：`aiState 2/3/6/8` 段每 15 tick 检查 `|celDX|>100` 才把
  aiNapr/tstor 指向目标（**100px 水平死区**）——纯 cel 引导的小幅侧移（<100px）
  不会触发走向。
- `forces()` 对 `[-maxSpeed, maxSpeed]` 范围内的 dx **不施加摩擦**
  （walk≠0 时只钳制超出 maxSpeed 的极端值）→ 直接写 dx 的侧移能在多次 step
  中保持，vanilla 不清理。

**机制一：celX/celY 直写（掩体/撤退用，已实现）**
- 直接写 `celX/celY`（public）而非 `setCel(null,x,y)`——后者会把 celUnit 置空
  打断交战；直写保留 `celUnit==gg`，vanilla 每 10 tick 的 findCel→setCel(gg)
  只短暂覆盖，TDFC 每帧重写即在 9/10 帧主导。
- 消费方：水平走向（>100px 死区、15 tick 方向更新）、垂直跳跃（celDY 阈值）、
  武器瞄准（武器朝 celX/celY 转）——掩体 SEEK/HIDE、撤退全部走这条。
- 已知限制：到达判定需含 100px 死区（COVER_ARRIVE=110）；方向更新延迟
  ≤15 tick（掩体起步可能慢半拍，实测评估）。

**机制二：dx 直写（侧移躲避用，已实现）**
- 写 `dx = dir × maxSpeed`（都在 public），vanilla forces() 不清理该范围
  的 dx → 侧移持续生效。仅水平方向（地面单位无垂直速度杠杆）。
- 侧移方向 = 水平离开玩家（-sign(u.X-px)）；躲避期间 cel 保持指向玩家
  （武器仍朝玩家，视觉可读：敌人一边看着你一边横移）。
- 限制：跳跃/飞行中 dx 被 forces() 阻尼（0.7-0.8×）；站立(walk=0)时受
  brake 摩擦——实测观察实际位移量再调 DODGE_TICKS/DODGE_DIST。

**机制三：利用原版既有的"恐惧"状态（放弃）**
- 原版手雷恐惧走 internal aiState=6（跑速 1.5×），模组无法置入该状态 → 不可用。
  但原版 `fearGrenade+findGrenades` 会自己处理手雷 → TDFC 的慢弹回避只补
  "手雷之外"的弹种与更精确的预测。

**朝向**：storona 可写但每步从 tstor(internal) 重算 → 放弃直接控制朝向，
靠 cel 位置自然转向（移动就是朝向的来源）。

---

## 3. 行为设计

### A. 瞄准回避（aim-dodge）

- **触发**：玩家有远程武器（`gg.currentWeapon != null` 且 tip>=3，tip 可读）且
  瞄准线指向本敌人（`atan2(weapon.rot) 与 敌人偏移向量 夹角 < 8°`）、
  距离 < 瞄准回避范围（350px）、本敌模组侧冷却已过、随机 < dodgeChance。
- **行为**：朝瞄准线的垂直方向侧移 DODGE_TICKS（约 0.3-0.5 秒，写 cel 侧移点），
  之后恢复原 cel（交战目标）。
- **反制**：① 冷却 1.5-3 秒（连续射击命中率不降）；② 触发率按类配置（敏捷高、
  重装 0）；③ SATS 时停中敌人机动停止（玩家点杀窗口）。
- **可读性**：侧移幅度有限且固定方向序列（垂直+微退），玩家可预判。
- 参数：DODGE_ANGLE_TOL=8°，AIM_DODGE_RANGE=350，DODGE_TICKS=9-15，
  DODGE_DIST=40-60px（侧移步距），dodgeChance 见 §5。

### B. 慢弹回避（slow-projectile dodge）

- **威胁检测**：遍历 `loc.firstObj` 链找 Bullet/PhisBullet/SmartBullet（用
  getQualifiedClassName 分流，弹体移动字段 X/Y/dx/dy 走 bracket 探测 + 继承链），
  过滤：`liv>0`、`explRadius>0 或 speed<阈值(60px/步)`、`owner != 本敌`。
  用相对速度扫掠（shared-knowledge projectile-step-sweep 的 R(t)=O+t·RV 公式）
  计算对敌最近距离 < 命中半径 → 威胁判定。每敌每 15 tick 扫一次（交战条件下），
  带冷却。
- **行为**：朝威胁的垂直方向侧移或向威胁来的反方向拉开，持续到威胁清除
  （弹道不再指向）或 DODGE_TICKS 上限。
- **与原版手雷恐惧的关系**：原版 findGrenades 只认手雷（玩家投掷物/edgren）；
  TDFC 补全所有慢弹（榴弹 aglau、火箭、慢速能量弹），并用预测而非贴脸判断。
- **反制**：慢弹本就可躲（设计初衷）；快弹（>60px/步）不进本行为（交给 A
  的瞄准回避）。
- 参数：SLOW_SPEED_THRESH=60px/步，THREAT_SCAN_CD=15，HIT_RADIUS=28（弹半径+敌半
  径近似），THREAT_DODGE_TICKS=12。

### C. 掩体评估（cover-seeking）

- **触发**：受伤（Phase 1 已有 hp 下降检测）或"被瞄准暴露"
  （玩家瞄准线指向本敌持续 > EXPOSED_TICKS，30 tick），且本类启用掩体。
- **掩体搜索**（v0.2 简化启发式，不建图不寻路）：
  - 在敌人周围 8 个方向、距离 60/120/180px 采样候选点；
  - 对每个候选点：`敌方视野→玩家` 之间被瓦片遮挡（Los.clear 反向判定 +
    tile.phis==1），且候选点本身可达（getAbsTile 非实体）；
  - 取"遮挡分最高、距离最近"者作为 coverPoint，写 cel。
  - **掩体只认瓦片**（用户确认：念力可移动的箱子不挡视线；Box 也不参与采样）。
- **状态机**：HT→SEEK(向掩体移动) → HIDE(掩体后缩着，period 12-20 tick 探头
  一次：cel 指向玩家 3-5 tick，然后缩回；有 currentWeapon 才探头) →
  RECOVER(掩体停留超时或玩家贴近 <150px → 交还会战逻辑)。全程不超过
  COVER_MAX_TICKS（300）防龟缩。
- **防龟缩护栏**：① 探头频率下限（每 12-20 tick 至少出枪一次）；② 掩体停留上限；
  ③ 玩家近距离冲击（<150px）立即解除掩体 loitering；④ 同队至少 1 人进攻位
  （Phase 3 强化，v0.2 先靠玩家冲击解围）。
- 参数：EXPOSED_TICKS=30，COVER_SEARCH_DIRS=8，COVER_MAX_TICKS=300，
  PEEK_PERIOD=12-20，PEEK_WINDOW=3-5，BREACH_RANGE=150。

### D. 撤退协议（retreat）

- **触发**：`hp/maxhp < RETREAT_RATIO`（默认 0.3）且 最近 60 tick 内被击中（有
  Phase 1 受击记忆）且玩家有 LOS（撤才有意义，没看见就不慌）。
- **撤退点选择**（按优先级）：① 当前掩体点（若在 C 状态已有 coverPoint）；
  ② 远离玩家方向 200-260px 且带遮挡的瓦片点；③ 出生/队伍方向（当前未知，
  v0.2 用玩家反方向 + 最近墙）。
- **行为**：按 maxSpeed×1.3 移向撤退点（用机制二写 maxSpeed 瞬时值，每次
  step 后重写）；到达后转 HIDE（复用 C 的 HIDE 行为，只探头不出掩体），
  持续 REGROUP_TICKS（240）后若 hp 回稳或玩家靠近再恢复交战。
- **禁止无限逃跑**：撤退有最大时长（RETREAT_MAX_TICKS=180）；撤退中若玩家追
  近 <120px 转为"背水一战"（停止撤退，回头交战）——护栏表保留原意。
- 参数：RETREAT_RATIO=0.3，RETREAT_SPEED_MULT=1.3，REGORUP=240，
  RETREAT_MAX=180，BACKS_BREACH=120。

---

## 4. 与既有时序的接口

- TdfcMain 帧环新增 `TacticalCtrl.update(u, st, gg, loc, tick)` 在
  SearchCtrl 之后调用，职责：检测玩家瞄准/暴露、管理 4 个行为状态机
  （每敌每帧只允许一个"移动指令"成为当前 cel 写者，优先级：
  撤退 > 慢弹躲避 > 掩体 > 瞄准回避 > 交战目标）。
- 每个行为写 TacticalState 新字段：`dodgeT/dodgeDir/coverPhase/coverPoint/
  retreatTick/aimExposed` 等。
- 所有写 cel 的操作统一走 `TdfcMain.setCelPoint(u, x, y)` 帮助函数
  （内部就是 `u["setCel"](null, x, y)` + try/catch），便于以后换机制。
- 事件日志特征：`dodge`、`threat`、`cover`、`retreat`，每功能独立计数+上限。

---

## 5. 配置草案（Config.as 扩展）

```
// 行为开关
ENABLE_DODGE_AIM / ENABLE_DODGE_THREAT / ENABLE_COVER / ENABLE_RETREAT
// 通用
AIM_DODGE_RANGE=350, DODGE_TICKS=9, DODGE_DIST=50, DODGE_CD=75(≈2.5s)
SLOW_SPEED_THRESH=60, THREAT_SCAN_CD=15, THREAT_HIT_R=28
EXPOSED_TICKS=30, COVER_MAX_TICKS=300, PEEK_PERIOD=16, PEEK_WINDOW=4, BREACH_RANGE=150
RETREAT_RATIO=0.3, RETREAT_MAX=180, RETREAT_SPEED=1.3, BACKS_BREACH=120, REGROUP=240
// 按类 doctrine（未知类用默认档）：
//   轻装/敏捷(raider 普通, monstr 近战): dodge 0.4, cover=true,  retreat 0.25
//   精兵(merc/encl):                   dodge 0.3, cover=true,  retreat 0.3
//   重装(robot/turret/列车):             dodge 0,   cover=false, retreat 0.1
//   默认:                               dodge 0.2, cover=true,  retreat 0.3
```

**优先验证项**：
- Box 是否挡视线/挡弹（决定掩体采样是否要算 Box）
- Bullet 移动字段的实际属性路径（继承链探测）
- walk 直写（机制二）与 cel 重写（机制一）在实机的视觉差异（抖动程度）

---

## 6. 测试场景（沿用 F9 生成 + 心跳/事件日志）

- A 瞄准回避：玩家用步枪隔 200-300px 瞄一个静立 raider 2 秒 → `dodge` 事件；
  松瞄再瞄 → 冷却内不连续触发；连射 → 命中率正常（伤害日志正常累计）。
- B 慢弹回避：向 raider 投手雷（aglau）→ `threat` 事件，raider 侧移/后撤；
  手雷落点仍炸（原版 grenade 恐惧叠加不冲突）。
- C 掩体：打一只 merc 3 枪 → `cover` 事件，其向装置/墙后移动并周期性探头
  （`cover PEEK` 日志）；玩家贴近 1 秒 → 解除。
- D 撤退：把 raider 打到 30% 血 → `retreat` 事件，其加速后撤到掩体；
  20 秒后 hp 未回 → 仍在掩体探头；玩家追击靠近 → 回头交战。
- 心跳：hb 增加 `dodging/covering/retreat` 计数（每类当前数量）。

## 7. 落地顺序（实现阶段）

1. 机制基础：setCelPoint 帮助函数 + TacticalState 扩展 + 行为优先级仲裁
2. A 瞄准回避（最简单，先立手感样板）
3. C 掩体评估（工作量最大：采样/状态机）
4. D 撤退协议（依赖 C 的 HIDE 复用）
5. B 慢弹回避（依赖威胁扫描）
6. 参数打磨 + 平衡复测（防龟缩/防抽搐护栏）

## 8. 风险与护栏

- **龟缩**：C 的时长/探头上限 + D 的最大撤退时间 + 玩家破点距离 → 战斗不拖沓。
- **抽搐移动**：机制一竞态窗口若抖动明显，改"每 N=4 tick 写一次 cel"或降低
  侧移频率，实测决定。
- **性能**：威胁扫描只在交战敌人上每 15 tick 一次（firstObj 链遍历有界）；
  掩体采样只在触发瞬间做 8×3=24 次 LOS 采样，不做每帧全扫。
- **难度**：四个行为全部按 doctrine 可关可调；默认参数偏保守（dodge 触发率
  ≤40%），实测后再按"至少 30% 伤害命中率"护栏校准。