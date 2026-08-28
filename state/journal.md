# TDFC —— 开发日志

> 协议见 GOVERNANCE.md §8：只追加不改写，**新条目插在最上面**。

## 2026-08-28 v0.5.4 修复 AutoTest 劫持 RConnect 双开实例（用户反馈）

- 做了什么：用户发现 RConnect 的 second_player.bat 双开工具运行后自动开新档+生成掠夺者。根因：AutoTest 激活条件写成 `applicationID != "pfe"`——RConnect 第二实例 app id 是 `pfe2`，同样命中条件，被 TDFC 的自动开局/拉怪劫持（pfe2 测试存储里留有 tdfc.log 的 squad/supp 活动痕迹）。修复：激活条件改为**精确匹配** `Config.TEST_APP_ID = "pfe-tdfc-test"`；双向验证：探针实例（外国 id pfe-probe-x）有 ver 无 auto ACTIVE ✅，TDFC 描述符正常激活 ✅。
- 关键决定/发现：**多模组共享 release SWF 与共享游戏目录时，测试钩子的身份判定必须精确匹配自己的描述符 id，绝不能用排除法（!= 用户 id）**——游戏目录下任何其他模组的测试实例都会中招。RConnect 仓库文件零改动（git 干净），污染纯行为性；pfe2/pfe3 是纯测试存储，无用户数据风险。
- 遗留/下一步：无。

## 2026-08-28 v0.5.3 AutoTest 接入长游玩存档（用户反馈：测试用白板档血薄图浅）

- 做了什么：用户指出自动化测试用的是全新档（角色白板、开局地形简单）。定位：测试实例存档在 `%APPDATA%\pfe-tdfc-test\Local Store\#SharedObjects\pfe.swf\PFEgame0.sol`（newGame(-1) 每轮重建的白板档）；用户长档 = `D:\Remains\Littlepip.sav`（游戏内置 FileReference 导出格式，AMF 序列化的 saveToObj 对象）+ 实时游玩槽位 `%APPDATA%\pfe\Local Store\#SharedObjects\pfe.swf\PFEgameN.sol`。修复：AutoTest 新增种档流程——读 .sav 字节反序列化 → 走游戏原生外部档通道（`world.loaddata = obj; world.comLoad = 99`，槽 99 = 外部数据，反编译 PipPageOpt.completeHandler/loadGame 证实）→ 等 loc 引用变化+allStat==1 → 清空旧圈养名单 → 交战。实测：seed injected → save loaded → 长档地图上 squad/supp START×3/retreat 全绿。
- 关键决定/发现：
  - **comLoad=99 外部档通道**：游戏原生支持注入存档对象（PipPageOpt 导入功能同款路径），比铺 .sol 文件干净——不碰 SharedObject 内部结构。
  - `mxmlc … | tail` 管道会吞退出码（编译失败照样继续链）→ 长命令前加 `set -o pipefail`。
  - ASC"函数没有返回值"怪癖再次踩中（seedSave try/catch 结尾）——知识库早有记录，写函数时就该用单尾部 return 风格。
- 遗留/下一步：seededAt 日志显示 1970（obj.date 字段语义与预期不符，仅诊断信息，无碍）；若需用最新游玩槽位（PFEgame0.sol 今天刚写过），后续可加"复制 .sol 进测试存储"的备选路径。

## 2026-08-27 v0.5.2 修复"敌人瞄着地面打"（用户实测反馈）

- 做了什么：用户报告敌人枪口经常朝地。根因：TDFC 的瞄准锚定与压制目标写 celX/celY 用的是玩家**脚底 Y**，而原版 setCel 瞄的是**立绘中心**（`Y - scY/2`，另有 `X + scX/4*storona` 朝向前置量）——交战中模组每帧覆盖原版算好的瞄准点 → 枪口被拽向地面。修复：TdfcMain 新增 playerAimPoint(gg)（逐字照抄原版公式），TacticalCtrl 瞄准锚定/掩体探头瞄准、SquadCtrl 压制目标三级获取（LOS 实时位/自身 lastSeen/同伴报点，后两者补 scY/2 抬升）全部接入。回归：隔离实例 squad=47/supp=11/retreat=10 正常，无异常。
- 关键决定/发现：**写 cel 必须区分移动点与瞄准点**——移动目标（掩体/撤退/调查）用脚底 Y 是对的，瞄准点必须用立绘中心。此约定已写进 playerAimPoint 注释。
- 遗留/下一步：待用户真机确认手感（枪口抬起、弹着点在身上）；v0.4.x 手感复测仍欠。

## 2026-08-27 v0.5.1 测试生成改造 + AutoTest 自动化实测（配合层首次实机验证）

- 做了什么：①F9 测试生成改造（spawnRaider：UnitRaider 构造器 opts.weap 直接发指定枪，枪械池 lmg/autor/aglau/mlau/bel 轮换 + maxhp/hp=200 + tr 随机外观——模板 'raider' 无 <w> 条目，原实现永远徒手）；②新增 AutoTest.as 自动化测试钩子（applicationID != "pfe" 才激活，用户实例零影响）：自动等开机→放菜单→newGame→圈养带枪掠夺者→周期照料靶机→玩家回血，一切可验证现象落日志；③测试描述符 app_tdfc_test_pfe.xml 收进 build/（id=pfe-tdfc-test）；④隔离实例实测 11 轮迭代，配合层全绿：squad 编队/压制者分配、supp START 多轮循环、心跳 supp=1、retreat GO/背水 ABORT 带冷却、space SEP、零崩溃。
- 关键决定/发现（前三条已回填 remains-auto-testing 技能）：
  - **newGame(-1) 才是新档**：nload<0 走 ng 分支；传 0 是读档分支，空存储永远开不出世界（RConnect 文档的 newGame(0) 依赖预置存档模板）。
  - **boot 时序**：landData 未就绪就放主菜单 → Game 构造器访问 World.w.landData 直接 #1009；必须等 landData != null 再放菜单。
  - **verror 对话框冻结 World.step**（step 首行 return）：读 verror.txt.text 可诊断，visible=false 可解冻。
  - **配合层修复**：小队"活跃"判定纳入 lastAlertTick（被警报/受击唤醒即算，否则凑不齐 n≥2）；狙击型（R_SNIPER）纳入压制候选（lmg 被判 sniper 型曾被排除→sup=-）；压制目标三级获取（自身 LOS→玩家实时位 / 自身 lastSeen / **脆弱同伴报点**），盲射时长按目标新鲜度封顶 POSITION_FREEZE；retreat 背水中止加 180t 冷却（防 GO/ABORT 每帧抖动循环）。
  - 玩家挂机会被后坐力逐渐推走（gg 坐标漂移数百 px）——自动化测试注意重锚定。
- 遗留/下一步：瞄准回避/掩体/交叉火力落点需要玩家主动瞄准射击，无法挂机断言——待用户实测；压制盲射路径（压制者无 LOS 场景）已实现未断言；v0.4.x 手感复测仍欠。

## 2026-08-27 v0.5.0 Phase 3 配合层（设计+实现+构建+门禁）

- 做了什么：设计并实现配合层四件套——①小队扫描/角色分配（SquadCtrl.scan：同 fraction 智能层、战斗圈内；ASSAULT/SUPPRESS≤1/HOLD 三槽 + crossSide 交替侧位 + 同伴位置快照防跨帧引用）②压制协议（同伴濒死受击或换弹且玩家逼近 → 指定压制者 cel 锚定 + attack() 命令开火，无 LOS 盲射 lastSeen，精度 0.45×，窗口 150t/冷却 300t/每队 1 人）③散开间距（<70px 分散冲量，ASSAULT 与贴身混战豁免）④交叉火力（findCoverPoint 按 crossSide 选边，掩体/狙击走位落点生效）。TdfcMain 挂接：扫描在单位循环前，update/apply 双调用点（apply 最后写 cel 覆盖锚点），心跳加 supp 计数。
- 关键决定/发现：
  - **命令开火链路反编译验证**（design/phase3-cooperation.md §2 全证据）：Weapon.attack() public 且敌人侧无玩家门控——原版 UnitRaider.dropLoot() 临死扫射就是 setCel+attack() 模式；shoot() 在武器 actions() 的 t_attack==rapid 帧执行，方向=rot（每 step 渐转向 atan2(celY-Y,celX-X)）→ 写 cel 即控制弹幕方向，drot 渐转天然形成扫射。
  - **本机工具链定位**：完整 Flex/AIR SDK 在 `D:\RemainsMod\mods\Sandevistan\build\tools\`，mxmlc 需配 Adobe Animate 2024 自带 JRE 17（本机无独立 JDK）；FFDec 用 `java -jar ffdec-cli.jar`。tdfc-config.xml/build.bat 已改路径并验证编译（knowledge/facts/build-environment.md 与 remains-mod-build 技能已更新）。
- 遗留/下一步：v0.5.0 与 v0.4.x 均待用户实测（F9 场景清单见 design §6）；发布门禁第 8 项重启冒烟由用户执行（换 SWF 须重启游戏）；gg.noise 负值持续监控。

## 2026-08-27 外置记忆迁移

- 由 state/current-status.md（交接文档，原文在 git 历史）拆分迁移：现行状态 → state\MEMORY.md；技术决策速查收编入本文件下方；decisions\ 目录同步建立（历史决策暂在代码注释与本日志，今后按 ADR 补）。

---

## 关键技术决策速查（详情在 design/phase2-enemy-survival.md 与代码注释）

- 起疑通道唯一性：aiSpok 只能被 vanilla listen(玩家噪声) 抬升 → 写 gg.noise 是唯一唤醒杠杆（→ shared-knowledge/entities/facts/enemy-ai-drive-interfaces.md）
- mazil 被原版 attack() 每发重写不可作精准杠杆 → **weaponSkill**（public 不被逐发覆盖）做移动精准惩罚（仅智能层，站桩窗口恢复精准）
- 冲量方向必须做墙体检（pickDartX：被挡翻侧/全挡锁位）
- 躲避/威胁=纯冲量（不写 cel）；cel 只用于瞄准锚定（LOS 门控）+ 正经位移——v0.3.2 根本解耦
- 部署：loader 已合并进 pfe.swf；换 SWF 需重启游戏

---

## 开发历程（按 git 提交日期，新在上）

### 2026-08-21 v0.4.0–v0.4.2 感知层 + 候选机制收尾
- v0.4.0 感知层（用户专项要求）：噪声治理（跑150>走80>慢走25>趴行/坐姿0，武器封顶 500）、背后盲区（overLook=false）、锥形视野（vAngle+vKonus，原版锥形判定从未启用过）、隔墙不瞄（瞄准锚定 LOS 门控）
- v0.4.1 候选 B+C：目击确认（12tick 持续 LOS 才报信，断线取消）+ 传播延迟（距离/20px每tick，上限 60tick，波次觉醒）；四候选机制（A 视野锥/D 声音歧义在 v0.4.0）至此全部落地
- v0.4.2 墙角固守：无可动方向→锁位 60tick 不跳不躲（角落即掩体）；修墙角原地跳
- 遗留：v0.4.x 整体待用户复测

### 2026-08-20 v0.3.0–v0.3.3 瞄准回避三维重做（多轮实测迭代）
- v0.3.0：智能分层 intelTier（0 人形+亡灵全战术 / 1 机械僵硬公式化 / 2 动物完全不接入）、移动形态（飞行垂直机动/游泳 2D/地面跳跑）、五档武器角色（狙击避/霰弹冲/步枪躲射/投掷走/近战追）
- v0.3.1：修抽搐/枪口歪（短躲避窗口 + 空闲瞄准锚定）
- v0.3.2：**根本解耦**——cel 同时驱动移动+瞄准是翻转抽搐根因；躲避改纯冲量，cel 只管瞄准锚定与正经位移
- v0.3.3：修墙边原地乱跳 + 步枪狙击只走不跑（冲量墙体检 + 起跳节拍 + 冲量读 runSpeed）

### 2026-08-18 v0.2.1–v0.2.2 瞄准回避首版与重做
- v0.2.1：修复实测反馈四项问题
- v0.2.2：几何规则重做——平射起跳、斜射水平走位；取消冷却；躲避窗口 24tick 抵消原版方向延迟

### 2026-08-17 v0.1.0–v0.2.0 信息层落地 + 生存层启动
- v0.1.0 Phase 1 信息层实测验收：目击传播（LOS→setCel / 听觉→alarma）、枪声事件、受击传播、记忆搜索（REACQ/RESUME/TIMEOUT）
- v0.1.1：非战斗单位过滤（UnitTrigger 等 7 类）+ 心跳增加 hear/los 指标；S1 判定为设计内行为
- Phase 2 设计 + v0.2.0 生存层首版（瞄准回避/慢弹回避/掩体评估/撤退协议）；knowledge 记录 ASC 编译怪癖；loader 合并进 pfe.swf
