---
domain: knowledge-validation
type: experiments
game-version: ["1.02"]
confidence: high
verified: true
discovered-by: TDFC
evidence:
  - kind: runtime-experiment
    summary: "真实 AIR 逻辑测试、隔离游戏读档与战斗、真实地形掩体专项；包含失败与修复记录。"
date-updated: 2026-09-10
---

# TDFC 重构与后期存档验证

被测技能：remains-auto-testing / remains-mod-build / remains-runtime-debug / remains-swf-patching
技能归属：D:/Program Files/Steam/steamapps/common/Remains/.agents/skills
测试工作区：D:/Program Files/Steam/steamapps/common/Remains/mods/TDFC

## 输入与隔离

用户要求全面重构现有主线和观察工具，按敌人等级/精英/训练确定思维，并先修复已有后期存档无法被测试启动加载的问题。原档只读；测试使用精确身份 `pfe-tdfc-test` 和独立文件/存储。原版游戏 SWF、描述符和其他模组项目没有修改。

原档：`%APPDATA%/pfe/Local Store/#SharedObjects/pfe.swf/PFEgame0.sol`，208433 字节，2026-09-07 保存。原版游戏读取的元数据为 Littlepip、29 级、1.0.2、`random_mane`。SHA256：`E47361389DD2081900C694C3B9222B3F83E334DEB54FA4DB51AEC956DC28DDCA`。

游戏 `Game.init` 将随机地点恢复为基地 `rbl`。`newGame(99)` 会先建立 GUI/SATS 再从 loaddata 读取，能直接导入而不清除任何测试槽位。核验同时保留原地点、预期恢复地点和实际地点。

工具：Flex 4.16.1、Animate 2024 JRE 17、工作区自带 AIR、FFDec 26.2.1。编译配置显式提供 playerglobal 与 airglobal；不含游戏存根类。

## 已观测结果

| 项目 | 证据与结果 |
|---|---|
| 旧压制冷却问题 | 4201b3c 的真实 AS3 基线退出 1，正常结束仍为 lastSuppressTick=-999999；新版对应检查通过 |
| 逻辑回归 | 当前 30 项真实 AS3 检查通过，见 evidence/logic-result.txt |
| 后期存档载入 | run `1811752ae32a49f3b697e2be556733db`，Littlepip / 29 / rbl 核验通过 |
| 存档副本基地战斗 | run `a959bb58393d4489abafe6fb42fde4e5`，实际移动、发射信号、压制、暂停计时通过 |
| 随机马哈顿战斗 | run `0325b9ca602142d6bb7799923d1afb67`，同上，并观察到撤退、避线与搜索 |
| 0.6.0 马哈顿回归 | run `cad1750b1eab484db03b311982e3593b`，同上；后续掩体/界面修正仍须核对最终产物 |
| 掩体早期复测 | run `6b55927e29f44c5d9c3d70a150fbda42` 一次通过；后续重复失败，因此不当作稳定完成 |

最后构建的验证、部署和回滚信息见本报告末尾的最终结果节；上表保留开发过程，不能代替最终产物证据。

## 失败与归因

1. **存档未进入测试**：旧配置使用不存在的 `D:/Remains/Littlepip.sav`，新场景最初始终新建角色。启动器现在复制全部原版槽位，显式选择槽位/导出档；空档报错，不回退新档。
2. **背包初始化 #1009**：隔离目录缺少技能武器模组的物品定义。补入已部署依赖后确认另一干扰：该依赖对所有非 pfe 身份自动开新档，删除了测试槽位 0。仅在 TDFC 的 build 副本定向改为 `id == "pfe-msw-test"`，编译后反编译核验。原依赖 SHA256 `BEF4D857B6B78D6CCB1F9E012B8BF33CD1E9892B7347892DA984176789DE648F` 未改。
3. **地图 XML 未完成**：只等 landData 非空就启动会出现 Land.prepareRooms #1009。改等 allLandsLoaded；这细化了既有启动门槛，不据此改写正式技能。
4. **探头窗口吃掉走路时间**：敌人进入过 peek 分支但未恢复射线。改为抵达探头点后开始射击窗口，并统一候选与实测使用的体型/射线高度。
5. **测试输入顺序不一致**：固定测试目标在候选计算之后才写入，导致控制目标与断言目标不同。调整到候选之前，并固定测试玩家位置；专项排除慢弹干扰。该项属于夹具问题，不冒充游戏算法缺陷。
6. **原版起跳/爬梯与掩体冲突**：后续重复实测仍失败，轨迹显示单位在 hide 中离开地面。原版 Unit.step 在同帧先 control 后 run，单纯事后写 dx 不能阻止原生 jump。掩体承诺期间临时关闭公开的 jumpdy/mostLaz，结束和换图归还；相关逻辑断言通过，真实地形复测单独记录。
   关闭原版移动冲突后仍发现“到达位置后的少量漂移”被旧进度时钟误报卡住；到达时重置进度时钟后，run `18873b49e7794007b9c8752e61d420c4` 通过。不能把先前仅修复起跳的构建描述为稳定通过。
7. **截图与日志环境**：原生 PNG encode 最初返回空文件，改用 BitmapData 的 PNG 编码器后得到可目检画面。沙箱下日志出现 3003，允许测试应用写自己的存储后正常。FFDec 的配置读取受目录权限影响时，进程 APPDATA 指向 TDFC build/out 的工具配置目录后正常。

观察均发生于本会话；不是跨会话复现。通用启动与技能身份判断的经验建议由技能维护读侧吸收；此前技能已写有精确测试隔离原则，但另有过时的排除式范例。[未落盘至正式技能]。本轮的实现与验证报告是新产物，不冒充既有知识。

## 范围与限制

- 发射证据来自弹药/发射计数，不等于命中或伤害统计。行为分支被观察到也不等于每次动作成功。
- CoverCheck 固定玩家位置、目标信息和压力，在真实地图验证位移/遮挡/探头；不是自然潜行测试。自然感知限制由独立逻辑检查与常规战斗日志交叉核对。
- 未穷举所有地图、特殊头目、飞行/游泳情形、全六模组组合和长时间游玩性能。采样日志中的更新用时不用于声称相对旧版性能提升。
- 文本技能规定的旧工具/身份范例按当前能力转译，未修改技能正本。本轮事实调查曾使用两个子代理，代码、构建和游戏驱动由主代理执行；未使用 parallel-delegate 技能。

## 证据与复现

`evidence/` 保存本轮结果、失败案例、日志和画面。可重复命令见 `build/README.md`。每轮结果必须与 manifest 的 run 匹配；启动器会先写 pending，避免旧 PASS 混入新结果。

## 回执要求

核对 allLandsLoaded 与 newGame(99) 的适用版本、竞争自动测试的案例和仅测试副本补丁方法。不要据本报告直接晋升技能；需要独立场景与既有通过场景回归。

## 最终结果与部署

- 最终 SWF：23408 字节，SHA256 `430D2DE96802A69E485D812C996AA77E03B6B18F566C489AB35EC1664EF17CBC`；release 与候选相同。
- 30 项真实 AS3 检查通过：`evidence/logic-result.txt`。包括压制冷却、连续目击/阵营、暂停、等级/风格、失去情报、实际移动恢复、噪声、读档拒绝、探头时序和移动能力归还。
- 同一最终候选的掩体专项连续两次通过：`18873b49e7794007b9c8752e61d420c4`、`4d9c71138b44445e93bf73bb5d0ea08d`，见 final-cover-result-1/2.json。属于本会话重复验证，不是跨会话证明。
- 最终马哈顿战斗 run `ad3b891e0792496b9c0e15d1c7cf4c2c` 通过，见 `evidence/release-combat-result.json`；候选/原档/依赖对应哈希在 `evidence/release-manifest.json`。截图 `overlay-combat.png` 已目检。
- 部署后的字节相同观察模式冒烟 run `94f3009113134a52af151767749d84fc` 通过：Littlepip 29 级、rbl，未注入战斗单位，HP 保持正常 966 而非自动战斗的 10000。见 `release-observe-result.json`、`observe-mode.png` 和 `observe-diagnostic.txt`。
- 本轮原版全部 11 个槽位复制前后哈希一致，见 `evidence/original-save-integrity.json`。仅关闭本轮创建且按 PID+完整描述符命令行核实的观察窗口 35144；自动场景自行退出。未结束用户游戏。
- 旧版备份：`build/backups/TDFCMod-v0.5.4-before-v0.6.0-20260910.swf`，SHA256 `71CA2540457166B8A2EDB037D9C80D71172CB52333EC2DEAC269177BFB38E5E1`。复制回 `release/TDFCMod.swf` 并重启即回滚。
- 发布门禁：构建/版本/自动验证通过；只部署自己模组的 release，游戏本体补丁项不适用；备份、部署、隔离观察重启、回滚路径已核对。记忆、版本记录与 git 提交同步收尾。
- 原始 TDFC 日志在 `evidence/tdfc-runtime.txt`，涵盖本轮多次失败和通过；周期性 status 文件可能早于最终结果，以同 run 的 result 为终态。