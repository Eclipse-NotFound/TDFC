# TDFC 当前状态（交接文档）

> 新对话恢复项目的唯一权威入口。启动流程：读 AGENT_SCOPE.md → 读本文件 →
> 读相关 design/ → 搜索 shared-knowledge（已贡献 3 条）→ 再动代码。
> 更新：2026-08-21 | 版本：v0.4.2 | 日志：`AppData/Roaming/pfe/Local Store/tdfc.log`

---

## 1. 项目一句话

TDFC 增强《FOE REMAINS》敌人 AI 的战术意识：信息层（传播/搜索）+ 生存层
（躲避/掩体/撤退）+ 感知层（潜行与声音），让敌人"知道你在哪、会应对、有
弱点"。全程不写 internal、不 hook 原型（纯 public API + 帧窗驱动）。

## 2. 已完成并部署（git 15 提交，工作树干净）

### Phase 1 信息层（v0.1.x，已实测验收）
- 目击传播（LOS→setCel 直接交战 / 听觉→alarma 模糊指路，冻结位置防隔墙追踪）
- 枪声事件（半径随武器 noise）、受击传播、记忆搜索（REACQ/RESUME/TIMEOUT）
- F9 测试生成（`spawn raider ... weapon=true` 可用）；心跳诊断（foes/engaged/
  hear/los/dodge/cover/retreat + ggN）

### Phase 2 生存层（v0.2.x～v0.3.3，多轮实测迭代）
- **瞄准回避**（核心，v0.3.2 根本性解耦）：根因=cel 同时驱动移动+瞄准会导致
  翻转抽搐——现为 **躲避/威胁=纯冲量**（dx/dy 每帧写几下，不写 cel）；
  **cel 只用于瞄准锚定（LOS 门控）+ 正经位移（掩体/撤退/狙击走位）**
- **智能分层 intelTier**（TdfcMain）：0=人形+亡灵（raider/merc/slaver/zebra/
  encl/pon/msp/necros/boss/天角兽）全战术；1=机械（gutsy/robobrain/dron/
  sentinel）僵硬公式化（触发 0.15）；2=动物（slime/ant/bat/monstrik/hellhound/
  spectre 等）**完全不接入**（含传播联动豁免）
- **移动形态**：isFly→弹线真垂直向量空中机动；isPlav→2D；地面→平射跳/斜射横移
- **五档武器角色 weaponRole**（读 tip/kol/rapid/precision/sniper）：狙击→掩体/
  后撤不跳（reloc cel）；霰弹/近战→前冲+跳；步枪→标准躲；投掷→躲
- **墙角固守 v0.4.2**：无可动方向→锁位 60tick 不跳不躲（角落即掩体）
- 慢弹回避（Bullet/SmartBullet；PhisBullet 交还原版 findGrenades）、掩体
  SEEK/HIDE/PEEK、撤退（打断掩体复用其点）

### 感知层 v0.4.0（用户专项要求）
- **噪声治理**：TDFC 接管 gg.noise——跑150>走80>慢走25>趴行/坐姿0（isSit 判定），
  武器噪声封顶 500（原版可达 1000+），远距自然衰减
- **背后盲区**：全敌人 overLook=false（vanilla 默认 true 旁路了盲区判定）
- **锥形视野**：智能层 vAngle=朝向角+vKonus=2.4（±68.7°），vKonus/vAngle 原版
  零赋值，锥形判定从未启用过
- **隔墙不瞄**：瞄准锚定全加 LOS 门控

### 候选机制 B+C v0.4.1（四候选至此全部落地）
- **B 目击确认**：目击入队列 12tick，期间持续核验目击者 LOS，断线取消
  （confirm OK/CANCEL 日志）；确认后才正式传播
- **C 传播延迟**：目击/受击按 距离/20px每tick 送达（上限 60tick），远处队友波次觉醒
  （SCHEDULE→DELIVER 两阶段日志）
- A（视野锥）D（声音歧义）已在 v0.4.0

## 3. 待验证/已知问题

- **v0.4.x 整体待用户复测**（噪声/锥形/确认/延迟手感、墙角固守、躲避残留）
- 历轮已修问题（抽搐/枪口歪/墙边乱跳/只走不跑/墙角原地跳）均在本版本已含修复，
  但用户尚未完整复测 v0.4.2
- 已知：gg.noise 负值（-10/-15）非 TDFC 写入（原版 UnitPlayer 不写 noise），监控
- 枪声日志量大（DIAG_CAP=300 够用）

## 4. 关键技术决策速查（详情在 design/phase2-enemy-survival.md 与代码注释）

- 起疑通道唯一性：aiSpok 只能被 vanilla listen(玩家噪声) 抬升 → 写 gg.noise 是
  唯一唤醒杠杆（→ shared-knowledge/entities/facts/enemy-ai-drive-interfaces.md）
- mazil 被原版 attack() 每发重写不可作精准杠杆 → **weaponSkill**（public 不被
  逐发覆盖）做移动精准惩罚（仅智能层，站桩窗口恢复精准）
- 冲量方向必须做墙体检（pickDartX：被挡翻侧/全挡锁位）
- **pfe.swf 部署**：loader 已合并（备份 pfe_1.02_before_tdfc_merge_20260817.swf）；
  换 SWF 需重启游戏（Loader 只在启动时读）

## 5. 环境操作要点（新对话必读）

- 构建：`build/build.bat` 或 mxmlc + `build/tdfc-config.xml`（自建 config，flexsdk
  内置令牌失效）；ASC 怪癖"try/catch 返回值"→ 单尾部 return（knowledge/facts/
  build-environment.md）
- 日志：`AppData/Roaming/pfe/Local Store/tdfc.log`（app:/ 只读，applicationStorage
  Directory 自带 Local Store 后缀勿再拼）；mod 的 trace 不进 adl stdout
- 测试：F9 生成掠夺者；用户实测 + 读日志判读的模式
- **不要自动启停游戏**（多实例 AIR 单实例转交会误杀用户会话——历次教训）
- shared-knowledge 已贡献 3 条：mod-log-channel / enemy-ai-drive-interfaces /
  frame-diff-event-detection

## 6. 下一步（计划）

1. 用户复测 v0.4.2（潜行链路 + 墙角 + 躲避）
2. **Phase 3 配合层**设计启动：战斗角色分配/压制协议/散开间距/交叉火力
   （design/brainstorm-01 的设想 2 深化；基础已有：Weapon.attack() public 可
   命令开火、道 doctrine 按类参数）
3. Phase 4 士气层（保留后备）、Phase 5 打磨（侧翼/难度参数/性能）
4. 待补任务：design/phase2-enemy-survival.md 补 v0.3-v0.4 决策记录
   （intel 分层/武器角色/感知层/墙角固守——目前只在代码注释与本文档）