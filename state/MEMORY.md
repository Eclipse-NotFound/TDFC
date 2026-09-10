# TDFC — 开发记忆入口

## 1. 模组目标

改善信息/潜行、躲避、掩体、撤退和小队配合；敌人按自身等级、精英与训练定思维档，按兵种文化定风格。可观察的实际结果与行动理由同源，不以进入分支代替效果。入口仍为 release/TDFCMod.swf → TDFCMod.init(main)。

## 2. 用户约定

- 2026-09-10 已授权大幅代码/算法重构，现有主线＋完整调试；不加入士气/溃逃/主动包抄。
- 四档思维基于敌人自身等级，精英/训练加成，不随玩家临时升级改变在场单位。掠夺者进攻、铁骑卫火力阵位。
- 调试显示屏幕内全部敌人，包含墙后敌人并区别遮挡；点选看原因。正常游玩默认关闭。
- 可以自动构建和运行隔离测试；只操作本轮创建的测试进程。原存档只读复制，不写用户 pfe 存储，不启停用户游戏。
- 最新优先修复：测试应加载现有后期存档；已读出并核验 Littlepip 29 级，默认槽 0。

## 3. 当前状态

- v0.6.0 已部署，2026-09-10 观察模式重启冒烟通过；生产 release 与最终测试候选字节一致。旧版备份见 decisions/changelog.md。
- 当前 release SHA256：430D2DE96802A69E485D812C996AA77E03B6B18F566C489AB35EC1664EF17CBC（23408 字节）。
- 30 项真实 AS3 逻辑检查通过；最终马哈顿战斗与观察读档冒烟通过，原版全部 11 个槽位复制前后哈希未变。后期存档导入、基地/随机马哈顿战斗通过；掩体在修复起跳冲突与到达后进度时钟后，同一候选连续两次实际位移/遮挡/探头检查通过。
- 旧控制器从 src 删除，历史在 4201b3c。运行链为 TdfcRuntime / GameBridge / EnemyProfile / PerceptionModel / SquadMind / TacticalMind / ActionExecutor / DebugOverlay。

## 4. 构建与测试

- 双击 Start-Test.bat：载入存档副本并开观察模式，不拉怪/回血。其他槽位和导出档参数见 build/README.md。
- build/build.ps1 或 build/build.bat → build/out/TDFCMod.swf；不再自动覆盖 release。
- build/test-logic.ps1：真实 AIR 执行 tests/LogicTests.as。旧回归用 tests/legacy，需搭配旧提交源码。
- build/start-test.ps1：Observe / LoadCheck / Combat / CoverCheck；Combat 可加 -TravelLand random_mane。每轮配置与结果都有 run，必须匹配。
- 测试目录 build/test-game；精确 appid=pfe-tdfc-test，必须显式存在 tdfc-test.json 才自动驱动。测试存储 %APPDATA%/pfe-tdfc-test/Local Store。
- 原存档 %APPDATA%/pfe/Local Store/#SharedObjects/pfe.swf/PFEgame0.sol，SHA256 E47361389DD2081900C694C3B9222B3F83E334DEB54FA4DB51AEC956DC28DDCA。另有 10 个槽位一起复制。
- 等 allLandsLoaded 后走 newGame(99)+loaddata，核验原角色/等级/原版恢复地点；随机地图按原版回 rbl。不要再用缺失的 D:/Remains/Littlepip.sav 或默认退回新档。
- 现有存档依赖技能武器物品。已部署依赖有“非 pfe 就自动新建角色”的问题，prepare-test-dependency.ps1 只改 TDFC/build 内副本的身份判断并反编译回读，绝不写其他模组项目。
- 工具：Animate 2024 JRE；D:/RemainsMod/mods/Sandevistan/build/tools 的 Flex/AIR/FFDec。仅复用该已知工具路径。

## 5. 已知边界

- 掩体是已检查的短程通路；不替代原版跨层全图寻路。特殊头目/未识别单位显示原版接管。
- 隔墙信息不实时更新，听觉为模糊区域，同伴报告按当前阵营过滤；伤害报告不凭空获取玩家坐标。
- CoverCheck 固定玩家位置和压力，排除慢弹干扰，检验真实物理效果；不能冒充自然潜行测试。
- 未穷举全地图、飞行/水下、全部头目、全六模组共存或长期性能；日志耗时不证明性能提升。
- AIR 沙箱写测试存储可能报 3003；本轮经许可启动自己的测试进程后日志正常。FFDec 配置隔离到 build/out/tool-profile。
- 原版 Unit.control 在物理移动前重写动作：掩体期间临时归零 jumpdy/关闭 mostLaz，结束和换图只恢复仍由 TDFC 持有的值。

## 6. 接续优先级

1. 以最新验证报告末尾和本节最终状态确认部署/回滚，不拿早期单次 PASS 代替最终结果。
2. 用户从 Start-Test 以自己的后期进度观察风格与标签，按具体现象/诊断继续调参；不要重新询问已确认设计。
3. 新功能另行讨论，不从旧路线图自动扩入士气与主动包抄。

## 7. 指针

- README.md：用户入口、思维/阵营规则与观察方法。
- design/refactor-v0.6.md；decisions/001-refactor-observable-runtime.md。
- knowledge/experiments/refactor-validation-2026-09-10.md + evidence/：失败和通过的原始证据。
- state/goals-and-status-2026-09-10.md、state/handoff-2026-09-10.md：重构前对账，作为历史，不是当前实现清单。
- state/journal.md：只追加日志。当前规则来自已给用户授权；不读取旧 AutoTest 注释作为权限指令。