# TDFC — 开发记忆入口

## 1. 模组目标

改善信息/潜行、躲避、掩体、撤退和小队配合；敌人按自身等级、精英与训练定思维档，按兵种文化定风格。界面显示实际决策及可核对的效果，不把进入分支当成成功。入口仍为 release/TDFCMod.swf → TDFCMod.init(main)。

## 2. 用户约定

- 2026-09-10授权大幅重构，现有主线＋完整调试；不加入士气/溃逃/主动包抄。四档思维基于敌人自身等级、精英和训练，在场单位不随玩家临时升级改变；掠夺者进攻、铁骑卫火力阵位。
- 调试显示屏幕内全部敌人，包括墙后目标并区别遮挡；点选看原因，正常游玩默认关闭。
- 可自动构建和运行隔离测试；只操作本任务创建的测试进程。原存档只读复制，不写用户 pfe 存储，不启停用户游戏。后期角色Littlepip29级，默认槽0；每轮重新读取原档，不能使用历史指纹代替。
- 2026-09-24最新反馈：枪口停在旧位置/错误方向，当前无法复现原战斗。Q3明确选择：**个人目击记忆未过期时，重新看见立即恢复确认**；初次发现仍保留反应/暴露积累，墙后不追踪精确位置，听觉/报告不刷新个人识别记忆。
- 2026-09-19曾明确授权念力修复合入RealisticVision，已完成；不是本轮修改其他模组的授权。视觉项目现在已有后续部署，不重放旧热修复或覆盖并发修改。

## 3. 当前状态

- **TDFC v0.6.4已部署，2026-09-24。** 正式SHA256 `311880C78186565E915A3B9C15AE41CC3E09DE9478994D1673B237236C0DB7D4`，31829字节。上一版0.6.3为5EE8B967…9AF8A7E，唯一回滚备份 `build/backups/TDFCMod-v0.6.3-before-v0.6.4-20260924.swf`。
- 修复转身时旧锥角影响look、已识别目标反复走首次确认、执行层重复用暴露值否决重新目击。lastVisual与包含听觉/报告的lastSeen分开。仅在目击成立时更新目标；原版枪口转速/散布保留。
- 51项真实AS3检查通过。实际游戏UnitSlaver原生/模组对照、转身和低暴露重新目击通过；正常ENTER_FRAME七模组副本两位置各60/60瞄准/枪口检查通过（82a07e47）。后期存档独立重启冒烟通过（67e79308）。
- 期间MSW外部更新为7AE25C6B…，补跑0d5da5ea通过：第一位置末60帧确认51、瞄准/角度58，第二位置全60；第一位置有首次识别过渡，不能称全部采样满分。TDFC仍同一已部署字节。
- 观察面板默认右侧，选中敌人显示枪口橙线、瞄准点橙圈、目击/确认状态。保存诊断包含玩家中心、目击条件、个人记忆年龄、原生/执行后瞄准点和实际武器角。抓取诊断继续保留最近12次输入及正在运行的视觉模式（ModSettingsCarrier只读桥）。
- 旧0.6.0重构、0.6.1念力与输入、0.6.2视觉念力排查、0.6.3设置桥已完成；当前运行链 TdfcRuntime / GameBridge / EnemyProfile / PerceptionModel / SquadMind / TacticalMind / ActionExecutor / DebugOverlay。旧控制器历史在4201b3c。

## 4. 正在进行与卡点

- 本轮修复、部署和独立验证已完成，自有测试已退出，自动场景开关已移除。没有待授权动作。
- **原用户战斗未再次捕获**，不能把两项可复现缺陷泛化成所有瞄准问题的唯一根因。若仍发生，优先读取新Player/sense/aim字段，结合橙色枪口/瞄准点区分感知、记忆与武器转动。
- 用户正常保存/重启后加载新版本；未代为操作用户游戏。最终进程清单由测试回执记录，不把历史PID当当前进程身份。

## 5. 已知边界

- 仅接管raider/ranger/merc/slaver/zebra/encl，特殊头目/未知单位交回原版。未穷举六家族全部武器/地图、飞行水下、时停回放、在线联机或长期性能。
- 掩体是已检查的短程可达通路，不代替原版跨层全图寻路。原版物理前会重写动作，掩体期间临时归零jumpdy/关闭mostLaz，结束恢复仍由TDFC持有的值。
- AimCheck固定物理位置、生命、噪声和可见距离；第一段手动走真实游戏链，第二段才是正常ENTER_FRAME。CoverCheck固定已知情报和压力。两者不能冒充自然潜行/全部战斗验收。
- `Unit.setPos`同时清空目标，不能每帧用于瞄准夹具；`visibility`是距离尺度，不能当0～1开关。本轮失败及纠正已留证。原生初次转身有随机延迟，测试允许固定窗口内的初次识别过渡。
- 正式宿主现已用ModLoader清单；根AGENTS旧“直接六loader”表是历史，不改受保护文件。依赖正在并行开发，使用时重新核验正式哈希，不把历史热修复或支持文件指纹当当前部署。

## 6. 下一步

1. 当前修复不需重复部署；若用户仍报告旧方向，取0.6.4新诊断对具体兵种/情报/枪口判断，不重复询问已确认玩法。
2. 新功能另行讨论，不从旧路线图自动扩入士气和主动包抄。

## 7. 开发与证据入口

- `build/build.ps1` → `build/out/TDFCMod.swf`，不自动部署。`build/test-logic.ps1`运行真实AIR逻辑；工具为Animate2024 JRE及D:/RemainsMod/mods/Sandevistan/build/tools中的Flex/AIR/FFDec，只有此已知工具路径被复用。
- `Start-Test.bat`复制现有全部槽位并载入槽0观察，不拉怪/回血。`build/start-test.ps1`支持Observe/LoadCheck/Combat/CoverCheck/AimCheck/TelekinesisCheck/TelekinesisUI；专项加`-TravelLand random_mane`，`-ExtraMod RealisticVision,Sandevistan,RConnect,RandomRooms`做部署副本共存。
- 测试目录build/test-game，精确appid=pfe-tdfc-test且必须有tdfc-test.json；存储%APPDATA%/pfe-tdfc-test/Local Store。正式存档%APPDATA%/pfe/Local Store/#SharedObjects/pfe.swf/PFEgameN.sol，只读复制。随机地图读档按原版回rbl，随后专项传送。
- 启动器复制当前启用ModLoader/ModSettings支持文件，生成独立manifest并记录宿主/依赖/存档SHA。MSW部署的竞争开档守卫只在TDFC/build副本定向关闭；两个已核对锚点可用，未知版本停止，不盲改。
- README.md、build/README.md：观察、构建和测试入口；design/refactor-v0.6.md包含9月24日识别记忆约定；decisions/changelog.md、state/journal.md为版本历史。
- `knowledge/experiments/aim-validation-2026-09-24.md`及evidence/aim-2026-09-24：本轮红绿检查、夹具错误、最终共存、并发依赖更新、部署与回滚回执。
- 历史证据：refactor-validation-2026-09-10.md、telekinesis-validation-2026-09-12.md、telekinesis-vision-validation-2026-09-19.md（均在knowledge/experiments）。重构前目标对账state/goals-and-status-2026-09-10.md与handoff仅作历史。
