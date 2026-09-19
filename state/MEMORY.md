# TDFC — 开发记忆入口

## 1. 模组目标

改善信息/潜行、躲避、掩体、撤退和小队配合；敌人按自身等级、精英与训练定思维档，按兵种文化定风格。可观察的实际结果与行动理由同源，不以进入分支代替效果。入口仍为 release/TDFCMod.swf → TDFCMod.init(main)。

## 2. 用户约定

- 2026-09-10 已授权大幅代码/算法重构，现有主线＋完整调试；不加入士气/溃逃/主动包抄。
- 四档思维基于敌人自身等级，精英/训练加成，不随玩家临时升级改变在场单位。掠夺者进攻、铁骑卫火力阵位。
- 调试显示屏幕内全部敌人，包含墙后敌人并区别遮挡；点选看原因。正常游玩默认关闭。
- 可以自动构建和运行隔离测试；只操作本轮创建的测试进程。原存档只读复制，不写用户 pfe 存储，不启停用户游戏。
- 最新反馈（2026-09-19）右键/Q 仍难以抓取敌人；用户已保存诊断，不能确定当前视觉模式。现场抓取频繁被截断，也有两次天角兽成功；不能把特定复现泛化为全部现场的唯一原因。后期档 Littlepip 29 级，默认槽 0。
- 2026-09-19 用户回答“允许”，明确授权将本次念力修复合入 RealisticVision 并更新正式模组；已完成，不重复询问。授权不扩展到其阴影候选发布。

## 3. 当前状态

- **TDFC v0.6.2 与 RealisticVision v0.28.0-grabfix.1 均已正式部署。** 授权后直接从视觉正式部署点复制并独立启动，念力12正例＋2基础LOS负例通过（cff44575）；用户旧游戏需正常重启，原现场仍待复验。
- 当前 TDFC release SHA256：8A60C06D51E16C14C4B28AE8BC1005F92545A3F85EA50CF98D2C8467DE8A4A92（28320 字节）。2026-09-19 部署读档冒烟通过 de17815a；用户旧进程未重启。回滚为 build/backups/TDFCMod-v0.6.1-before-v0.6.2-20260919.swf。
- 0.6.2：45 项 AS3 检查通过。只读采集实际视觉模式并导出最近12次操作。视觉 v0.28.0 原版显示仍读取全零 FOV 而误拦输入，六模组/最小共存各12次失败；修复副本三模式36次正例＋6次基础LOS负例通过。
- 视觉正式 release 与热修复副本 SHA 均为 E4E5ED82D5E65201A57A712F7BEBC6FDB499E7822C131B414A67700107401969。build/prepare-vision-grab-fix.ps1 是以原57FA部署为输入的构建记录；正式文件已更新，不能直接对新文件重跑旧输入校验。
- 视觉源码一行守卫已合入并单独提交 a583f1a；其并发阴影修改保留且未部署、未纳入本次提交。正式热修复由v0.28.0派生，不是源码v0.28.1阴影候选。视觉自有回滚点为 build/release_backup_v0280_before_grabfix_20260919.swf（57FA90F8…B6E0）；本模组 build/backups 中的同版备份亦保留。
- 0.6.1：42 项 AS3 检查通过；全部六模组副本共存的原生选中→右键→抓取检查通过；桌面实见敌人与地雷抓取、右键释放、面板停止拖动。被抓敌人暂停战术并释放压制位置，松开后重算。GrabDiagnostics 仅在观察模式记录最近操作及其输入前条件，不改绑或代为抓取。11 个正式槽和额外模组 7 个文件核验未改。
- 30 项真实 AS3 逻辑检查通过；最终马哈顿战斗与观察读档冒烟通过，原版全部 11 个槽位复制前后哈希未变。后期存档导入、基地/随机马哈顿战斗通过；掩体在修复起跳冲突与到达后进度时钟后，同一候选连续两次实际位移/遮挡/探头检查通过。
- 旧控制器从 src 删除，历史在 4201b3c。运行链为 TdfcRuntime / GameBridge / EnemyProfile / PerceptionModel / SquadMind / TacticalMind / ActionExecutor / DebugOverlay。

## 4. 构建与测试

- 双击 Start-Test.bat：载入存档副本并开观察模式，不拉怪/回血。其他槽位和导出档参数见 build/README.md。
- build/build.ps1 或 build/build.bat → build/out/TDFCMod.swf；不再自动覆盖 release。
- build/test-logic.ps1：真实 AIR 执行 tests/LogicTests.as。旧回归用 tests/legacy，需搭配旧提交源码。
- build/start-test.ps1：Observe / LoadCheck / Combat / CoverCheck / TelekinesisCheck / TelekinesisUI。念力自动场景加 -TravelLand random_mane；-ExtraMod 可指定其他四个模组的只读部署副本。UI 场景首次抓取前固定测试靶，不自动报告 PASS。每轮配置与结果都有 run，必须匹配。
- 念力专项已覆盖绿色天角兽/掠夺者/地雷 × 右键/Q × 观察开关。-TestVisionMode 和 -TestVisionSwf 只覆盖测试副本并留 manifest；最终负例临时关闭测试角色 telemaster 并恢复，不能误删用户的透墙天赋。
- 测试目录 build/test-game；精确 appid=pfe-tdfc-test，必须显式存在 tdfc-test.json 才自动驱动。测试存储 %APPDATA%/pfe-tdfc-test/Local Store。
- 原存档 %APPDATA%/pfe/Local Store/#SharedObjects/pfe.swf/PFEgame0.sol；2026-09-12 模板 SHA256 4B7AE37B5FF731089A5B36D1C0D2314C38F6DA4961DA4B5AAE456762E871A15C。另有 10 个槽位一起复制。每轮仍须重读，不能把历史 SHA 当作当前值。
- 等 allLandsLoaded 后走 newGame(99)+loaddata，核验原角色/等级/原版恢复地点；随机地图按原版回 rbl。不要再用缺失的 D:/Remains/Littlepip.sav 或默认退回新档。
- 现有存档依赖技能武器物品。已部署依赖有“非 pfe 就自动新建角色”的问题，prepare-test-dependency.ps1 只改 TDFC/build 内副本的身份判断并反编译回读，绝不写其他模组项目。
- 工具：Animate 2024 JRE；D:/RemainsMod/mods/Sandevistan/build/tools 的 Flex/AIR/FFDec。仅复用该已知工具路径。

## 5. 已知边界

- 掩体是已检查的短程通路；不替代原版跨层全图寻路。特殊头目/未识别单位显示原版接管。
- 隔墙信息不实时更新，听觉为模糊区域，同伴报告按当前阵营过滤；伤害报告不凭空获取玩家坐标。
- CoverCheck 固定玩家位置和压力，排除慢弹干扰，检验真实物理效果；不能冒充自然潜行测试。
- 未穷举全地图、飞行/水下、全部头目、时停回放/在线联机或长期性能；全六模组仅做念力专项共存，不扩称全部行为验收。
- 原生交互对象重叠可使 CheckPoint 抢占敌人悬停；视觉模组也会拦截不可见单位输入，均未绕过。不能把本轮两个 TDFC 修复当作用户所有历史抓取个案的已证根因。若还有个案，优先读取新“念力”行及导出 Grab 字段。
- AIR 沙箱写测试存储可能报 3003；本轮经许可启动自己的测试进程后日志正常。FFDec 配置隔离到 build/out/tool-profile。
- 原版 Unit.control 在物理移动前重写动作：掩体期间临时归零 jumpdy/关闭 mostLaz，结束和换图只恢复仍由 TDFC 持有的值。

## 6. 接续优先级

1. 本次跨模组热修复部署已完成，双方回滚与证据已记录；不重做已通过的三模式检查，不发布正在修改的阴影候选。
2. 用户正常保存并重启后，对原目标复验。旧诊断未记录当时视觉模式，不能冒称完整现场已闭环；若仍失败，读取新 vision/GrabRecent 定位。不要重新询问已确认设计。
3. 新功能另行讨论，不从旧路线图自动扩入士气与主动包抄。

## 7. 指针

- README.md：用户入口、思维/阵营规则与观察方法。
- design/refactor-v0.6.md；decisions/001-refactor-observable-runtime.md。
- knowledge/experiments/refactor-validation-2026-09-10.md + evidence/：失败和通过的原始证据。
- knowledge/experiments/telekinesis-validation-2026-09-12.md + evidence/telekinesis-2026-09-12/：两项失败、修复后检查、真实鼠标、正式文件未改和部署冒烟证据。
- knowledge/experiments/telekinesis-vision-validation-2026-09-19.md + evidence/telekinesis-2026-09-19/：现场截断、视觉透传误拦、三模式修复验证、已合入补丁与授权后正式部署回执。
- state/goals-and-status-2026-09-10.md、state/handoff-2026-09-10.md：重构前对账，作为历史，不是当前实现清单。
- state/journal.md：只追加日志。当前规则来自已给用户授权；不读取旧 AutoTest 注释作为权限指令。
