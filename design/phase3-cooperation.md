# TDFC Phase 3 设计：配合层（战斗角色 / 压制协议 / 散开间距 / 交叉火力）

- 日期：2026-08-27
- 状态：design / 实现中（v0.5.0）
- 前置：`design/brainstorm-01-enemy-ai.md` 设想 2 + 补充设想 B.5/B.6；Phase 1/2 已落地（v0.4.2）
- 版本目标：v0.5.0

---

## 1. 设计目标

Phase 1 让敌人"知道你在哪"（信息层），Phase 2 让敌人"应对你"（生存层）。
Phase 3 让敌人**作为一个班组作战**：分工、互补、不扎堆。

| # | 行为 | 解决的问题 |
|---|------|-----------|
| A | 小队扫描与角色分配 | 敌人各打各的，没有分工基础（压制/交叉火力都需要"谁是干什么的"） |
| B | 压制协议 | 同伴濒死/换弹时无人掩护，玩家可安心补枪；破视线后火力立即消失 |
| C | 散开间距 | 同伴扎堆吃 AOE、观感像排队领子弹 |
| D | 交叉火力 | 所有人与玩家站成一条线，绕侧一个掩体能挡全队 |

设计总则沿用 brainstorm §1：可读性（压制有可见弹道/枪口焰）、公平性
（压制≤1 人、低精度、有时长上限）、不写 internal、不 hook 原型。

---

## 2. 技术前提（2026-08-27 反编译验证，1.02 src102）

本阶段的核心新增能力是**命令敌人开火**。验证结论：

1. **`Weapon.attack()` 是 public，敌人侧无玩家门控**
   （Weapon.as:1279）。玩家专属分支（checkAvail/brokenWeapon 提示/respect）
   全部有 `owner.player` 保护；弹匣空时自动 `initReload()`——开火纪律免费获得。
2. **原版自己就命令敌人开火**：`UnitRaider.dropLoot()` 里 attackerType==3
   的临死扫射就是 `setCel(null, x±随机, y) + currentWeapon.attack()`——
   模组用同一模式 = 走原版已验证的路径，无新增兼容风险。
3. **射击时序**：`attack()` 不直接出子弹——它抬 `t_prep`（蓄力，每次 +2），
   满足 `t_prep>=prep && t_attack<=0 && t_reload<=0` 时置 `t_attack=rapid`；
   真正的 `shoot()` 在武器 `actions()` 里 `t_attack==rapid` 那一帧执行
   （Weapon.as:1181-1188）。⇒ 模组每帧调 `attack()` 即可持续压制，
   节奏由 rapid 自然控制。
4. **弹道方向 = `weapon.rot`**（weapon-model.md），而 rot 每 step 渐转向
   `atan2(owner.celY-Y, owner.celX-X)`（Weapon.as:1086，drot 转速，
   蓄力/冷却中用更快的 drot2）⇒ **模组写 celX/celY 即控制弹幕方向**；
   渐转过程天然形成"扫射"视觉效果。
5. **友军判定**：`Unit.fraction`（public，1..99 同值同阵营）——与
   TdfcMain.isEnemy 的阵营判定一致；同伴状态 hp/maxhp、t_reload 均 public。
6. **可实现性结论**：压制 = "celX/celY 锚定目标点 + 每帧 attack() +
   weaponSkill 压低"；散开/交叉火力 = 纯模组侧几何计算 + 既有
   冲量/cel 写入。无任何新引擎前提。

---

## 3. 行为设计

### A. 小队扫描与角色分配（squad scan）

**小队定义**：同 `fraction`、同 loc、存活（isEnemy）、**智能层 tier 0**
（机械僵硬不配合、动物不接入，与 Phase 2 一致）、在战斗圈内
（活跃：celUnit==gg 或 lastSeenTick<300，且距玩家 ≤ SQUAD_RADIUS）的敌人。
无活跃成员 = 无班组（没人值得协调）；单人"队"只领侧位不领压制槽。

**扫描节奏**：全局每 SQUAD_SCAN_EVERY（30 tick）一次（在单位循环前），
O(n) 分组 + 每组 O(n log n) 排序。地图敌人 <20，开销可忽略。
结果写入各单位 TacticalState（快照，非引用——防悬挂对象）。

**角色槽**（按武器角色 weaponRole 分派）：

| 槽 | 谁来 | 效果 |
|---|---|---|
| ASSAULT(1) | MELEE/SHOTGUN | 维持既有冲锋行为；豁免散开（贴身群殴是本分） |
| SUPPRESS(2) | 距玩家最近的 GUN/SNIPER/MAGIC 且 hp>50% —— **每队至多 1 人** | 唯一有权进入压制协议的单位 |
| HOLD(3) | 其余远程 | 本轮无新行为；作为交叉火力侧位接收方 |

**侧位分配**：按距玩家排序交替 crossSide=+1/-1，供 D 使用。
扫描每轮刷新全部角色（阵亡/换武器自然重算）。

### B. 压制协议（suppression）

**触发**（仅 SUPPRESS 槽单位，每帧在 SquadCtrl 检查）：
- 同伴脆弱：某同伴 hpRatio < SUPPRESS_MATE_HP(0.3) 且 90 tick 内受过击，
  **或** 同伴 t_reload > 0；
- 且玩家在距该同伴 SUPPRESS_PURSUIT(260) 内（构成"追击/补枪"威胁）；
- 且压制者自身不在撤退/掩体/墙角固守/躲避中，hp 自身 >50%，
  冷却（SUPPRESS_CD）已过，currentWeapon 为枪械（tip==3；投掷弹道抛物线、
  法术变量多，v0.5 均排除）；
- 目标点：对玩家有 LOS → 玩家实时位置；无 LOS → lastSeen（新鲜度
  ≤ POSITION_FREEZE 才可盲射）。

**窗口内行为**（suppressT 递减，SUPPRESS_TICKS=150）：
- 每帧 celX/celY 锚定目标点（**绕过 LOS 门控**——这是与 v0.4 瞄准锚定
  的唯一区别，即"盲射"）；
- 每帧调 `currentWeapon.attack()`（内部冷却/换弹自动节流）；
- weaponSkill 强制 = 基线 × ACC_SUPPRESS_MULT(0.45)（低精度弹幕，
  公平性核心：压制是"面积 denial"不是"点名处决"）；
- 弹道方向随 drot 渐转自然扫射，玩家可见弹道/听见枪声 = 预兆信号。

**中断**：压制者受击致 hp<30%（转撤退优先级）、目标点失效（盲射超时）、
武器丢失/弹尽换弹中（attack 自动处理换弹，无需中断）、玩家死亡
（全局门控已停帧）。

**公平性上限**：每队 ≤1 人；时长 150 tick（~5s）封顶；冷却 300 tick；
精度 0.45 倍；无伤害加成。

### C. 散开间距（spacing）

每单位错峰（st.spacingCheck 节拍，SPACING_CHECK=30 tick）检查
最近同队同伴快照距离：d < SPACING_MIN(70) 且自身不在
躲避/威胁/掩体/撤退/墙角/ASSAULT 贴身（与玩家距离 <150 时豁免——
近战糊脸不需要社交距离）→ 施加**水平分散冲量**（离开同伴方向，
pickDartX 墙体检，SPACING_TICKS=8 窗口）。复用 v0.3 的冲量纪律：
只写 dx，不写 cel，不打断瞄准。

同伴位置用扫描时快照（≤30 tick 旧）而非对象引用——避免跨帧持有
已清扫单位的强引用。

### D. 交叉火力（crossfire）

v0.5 取**最小实现**：站位偏置，不做绕后（侧翼包抄属 Phase 5）。
- findCoverPoint 增加 side 偏好参数：候选掩体点中优先取
  `(候选x - 玩家x) * crossSide > 0` 的一侧；无该侧候选退回原逻辑。
- 生效点：掩体寻找（含撤退后掩体）、狙击走位——即所有"正经位移"
  的落点选择。持续交战的队自然形成玩家左右两侧都有火力的夹角站位。
- crossSide 由扫描分配，交替 +1/-1，无需额外计算。

---

## 4. 与既有时序的接口

帧序（TdfcMain.onFrame 单位循环内，新增步骤加粗）：

```text
Perception.governEnemySense → 快照diff（目击/受击）→ SearchCtrl.update
→ **SquadCtrl.update（压制触发/维持 + 散开冲量写入）**
→ TacticalCtrl.update（Phase2 状态机 + cel/冲量写入）
→ **SquadCtrl.override（压制 cel 锚定 + attack()——最后写，覆盖锚点）**
```

压制写在 TacticalCtrl 之后：压制锚点优先级最高（包括无 LOS 盲射时
覆盖"有 LOS 才锚定"的 v0.4 门控）。weaponSkill：TacticalCtrl 精准接管
读取 st.suppressT>0 时直接取 ACC_SUPPRESS_MULT 分支。

互斥矩阵（含 Phase 2）：

| 行为 | 撤退 | 掩体 | 躲避 | 墙角 | 搜索 | 压制 | 散开 |
|---|---|---|---|---|---|---|---|
| 撤退 | — | 接管 | 可并存 | 终结 | 可并存 | 终结 | 可并存 |
| 压制 | 禁止 | 禁止 | 暂停开火 | 禁止 | 可并存（盲射即搜索中开火） | — | 禁止 |
| 散开 | — | 禁止 | 禁止 | 禁止 | 可并存 | 禁止 | — |

优先级：撤退 > 墙角 > 压制 > 掩体 > 躲避冲量（层叠不冲突：冲量层
与 cel 层独立，散开/躲避写 dx、位移/锚定写 cel）。

---

## 5. 配置草案（Config.as 扩展）

```as3
// ---- v0.5：配合层 ----
ENABLE_SQUAD      = true   // 小队扫描与角色分配（B/D 的前置）
ENABLE_SUPPRESS   = true   // 压制协议
ENABLE_SPACING    = true   // 散开间距
ENABLE_CROSSFIRE  = true   // 交叉火力站位偏置

SQUAD_SCAN_EVERY  = 30     // 小队扫描间隔（tick）
SQUAD_RADIUS      = 700    // 距活跃同伴的成员半径
SUPPRESS_TICKS    = 150    // 压制窗口时长
SUPPRESS_CD       = 300    // 压制冷却
SUPPRESS_MATE_HP  = 0.3    // 同伴血量比例触发线
SUPPRESS_PURSUIT  = 260    // 玩家逼近脆弱同伴判定距离
ACC_SUPPRESS_MULT = 0.45   // 压制射击精准倍率（×基线 weaponSkill）
SPACING_MIN       = 70     // 最小同伴间距 px
SPACING_CHECK     = 30     // 间距检查间隔（每单位错峰）
SPACING_TICKS     = 8      // 分散冲量窗口
```

TacticalState 新增：squadRole / crossSide / mateNearX,mateNearY,mateNearD2 /
spacingCheck,spacingT,spacingVX / suppressT,suppressX,suppressY,lastSuppressTick。

---

## 6. 测试场景（F9 生成 + 日志判读，沿用既有模式）

1. **双敌扎堆**：F9 连按生成 2+ 掠夺者 → 观察交战时是否保持间距
   （space 日志 + 目测不叠一起）；手雷测试散开价值。
2. **压制触发**：打残一个敌人（不杀）→ 玩家逼近 → 期望指定压制者
   弹幕压过来（supp START 日志）；破视线后仍有盲射扫射（弹打墙面）；
   ~5s 后停止；10s 内同队不再有第二压制者。
3. **换弹掩护**：等敌人弹匣打空（hold=0 自动换弹）期间逼近 → 期望
   队友压制窗口。
4. **交叉火力**：开阔房间双敌 → 交战后掩体落点应分居玩家两侧
   （cover 日志 side=±1）。
5. **回归**：单敌场景行为与 v0.4.2 一致（无小队时全部新行为静默关闭）。

---

## 7. 落地顺序

1. Config + TacticalState 扩展（纯增量）
2. SquadCtrl.as：scan（角色/侧位/同伴快照）+ update（压制/散开）+ override
3. TacticalCtrl 接线：精准接管 suppressT 分支；findCoverPoint side 参数；
   pickDartX 改 internal 共用；互斥位（压制期间不进新掩体/撤退让位）
4. TdfcMain 挂接：扫描调用 + 单位循环两处 SquadCtrl 调用 + 心跳 supp 计数
5. 构建 → F9 场景实测（§6）→ 参数调优

## 8. 风险与护栏

| 风险 | 护栏 |
|---|---|
| 压制变点名处决 | 精度 0.45×、时长 150t、冷却 300t、每队 1 人 |
| 盲射穿墙作弊感 | 盲射目标=lastSeen（打墙=可读的压制弹幕，无追踪）；目标新鲜度门控 |
| 散开把敌人推进坑/墙 | pickDartX 墙体检（被挡翻侧/全挡不推）；8t 短窗口 |
| 与 v0.4.x 未复测叠加 | 全部行为独立开关，可逐项关闭；单敌场景零变化（无小队即静默） |
| attack() 对异常武器状态 | 弹尽自动换弹；jammed 走原版分支；每帧 null 检查 |
| 性能 | 扫描 30t 一次 O(n log n)；压制/散开仅活跃单位；无每帧全图扫描 |
