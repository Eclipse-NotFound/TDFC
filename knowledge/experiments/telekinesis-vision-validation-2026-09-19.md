被测技能：remains-runtime-debug、remains-auto-testing、remains-mod-build、remains-release-gate；test-report 2026-09-16.1（自然使用、新的输入拦截场景）
技能归属：Remains/.agents/skills；test-report 位于 C:/Users/hello/.agents/skills/test-report，维护驻地 D:/活/笔记/写作
测试工作区：D:/Program Files/Steam/steamapps/common/Remains/mods/TDFC

# 2026-09-19 念力输入拦截调查、验证与正式部署

## 结论与边界

用户报告右键与 Q 都不能抓取敌人。现场日志确认大量事件被拦截；进一步稳定复现了 **RealisticVision v0.28.0 原版显示模式仍拦截念力** 的缺陷。修复副本通过三模式回归；随后用户回答“允许”，已将一行修复合入视觉源码并正式部署 v0.28.0-grabfix.1。部署文件独立启动后12次抓取与2次基础遮挡检查通过。TDFC 0.6.2 的诊断改进也已部署；正在运行的旧游戏需正常重启。授权前准备过程保留如下，最终回执见文末。

不能把这次已证缺陷直接等同于用户所有失败现场的唯一根因：用户不确定当时视野模式，旧诊断没有记录模式；原始日志还包含两次天角兽抓取成功。新诊断补齐正在运行的视野模式，后续对原目标验收时可核对。源码配置 `mode=current` 不能证明运行中没有用 F12 或设置页切过模式；旧视觉配置写回已有 `fileWriteResource` 错误记录。

## 现场证据

证据均在 [evidence/telekinesis-2026-09-19](evidence/telekinesis-2026-09-19/)。

- `user-grab.log`：本地 21:37–21:38 的 50 条操作。其中 28 条非暂停事件被截断，25 条指向绿色天角兽，3 条无悬停目标；另外有 2 次天角兽、2 次箱子/盒子抓取成功、4 次释放、5 次空选、9 次暂停。不是“50 次全部失败”。
- 多条天角兽失败记录同时满足 `levitPoss=true`、`onCursor=1`、质量 2.2≤12、魔力充足、距离在范围内、`routed=false`。旧诊断的 `line=true` 包含透墙天赋豁免，不能单凭该字段断言物理直线无遮挡。
- `user-report.txt`：用户保存时有两只 alicorn3，等级 31/25，TDFC 明确为“原版接管”。最后一次空选覆盖了单个 Grab 字段；因此 0.6.2 导出保留最近 12 次操作。
- 正式游戏 PID 45036 加载 0.6.1，未重启或受程序控制。所有程序化输入仅发生于精确身份 `pfe-tdfc-test` 的独立副本。

## 原因与最小修复

部署 SWF 反编译到 TDFC/build 后核对：`RealisticVisionMod.blockInvisibleGrab()` 对 Q/右键调用 `stopImmediatePropagation()`，但只检查 enabled/black/房间引用，没有检查渲染器的原版显示/安全房间透传条件。

`resetRoom()` 把 FOV 初始化为全零；原版显示走 `normalMode()` 并停止更新 FOV。抓取拦截仍使用这份 FOV，于是正常可选敌人被判不可见。它还无条件做“光标 50px 最近对象”搜索，因此不是原生悬停选择的完整等价实现；本轮只修复已最小化的透传条件缺失，未扩修其余目标选择取舍。

修复将抓取入口的透传条件与渲染器对齐：vanilla、基地、配置安全房间不再进行该项拦截；已有关总开关/游戏黑暗关闭条件不变。原版玩家控制、距离、重量、天赋及目标条件仍照常执行。

- 调查开始时的正式视觉部署：v0.28.0，SHA `57FA90F813C267C1BB0BC4B4AAB536257CF10EDCD20E7E38BDA93E9B3AA9B6E0`。
- 已编译热修复副本：`build/out/vision-grab-fix/RealisticVisionMod.swf`，标记 v0.28.0-grabfix.1，SHA `E4E5ED82D5E65201A57A712F7BEBC6FDB499E7822C131B414A67700107401969`。
- 可重复构建：`build/prepare-vision-grab-fix.ps1`。核对原部署 SHA，导出单类、修改抓取守卫与版本、定向编译、反编译回读；不写其他模组。
- 准备阶段的视觉源码另有未部署 v0.28.1 阴影候选，SHA `3B7F1D43B22DCB14B304D19E0584E6D2C7B8A0867279A0A70C0D1E24A157FD6E`。前向补丁 `RealisticVision-forward-fix.patch` 仅改一行守卫，`git apply --check` 通过；当时尚未应用。授权后发现并发墙边修改，只合入该行，没有覆盖或部署阴影工作。

## 回归结果

命令入口为 `build/start-test.ps1 -Mode TelekinesisCheck -TravelLand random_mane`，配合 `-ExtraMod`、`-TestVisionMode` 和 `-TestVisionSwf`。每轮 JSON 结果与 manifest 的 run 对齐，均载入 Littlepip 29 级存档副本。原档由用户持续游玩自动保存，各轮 SHA 会变化，不把这些变化归因于 agent 写入。

| 轮次 | 条件 | 结果 |
|---|---|---|
| 164b7ee6 | 未扩展的旧测试，六模组、当前配置 | 4 个原有右键正例通过；不作为当前失败根因证明 |
| 227c14a0 | 新事件链，六模组、旧视觉 vanilla | 12 次全部被截断、`keyTele=false`、未持握 |
| 03720381 | 六模组、旧视觉 current | 12 次成功 |
| 058aab39 | 仅视觉＋TDFC＋存档依赖，旧 vanilla | 12 次仍全部失败；移除时停、联机、随机房间不消失 |
| d201da8e | 六模组、修复副本 vanilla | 12 次成功 |
| eaf8671d | 修复副本 current、新模式诊断 | 12 次成功；实际模式读为平滑阴影 |
| a31b92ea | 最终 TDFC/视觉候选，vanilla | 12 正例＋2 基础 LOS 负例通过 |
| 280c25df | 同一最终候选，classic | 12 正例＋2 基础 LOS 负例通过 |
| a0bbc73d | 同一最终候选，current | 12 正例＋2 基础 LOS 负例通过 |
| de17815a | 已部署 TDFC，与原正式视觉共存 | 0.6.2 标记及原角色读档冒烟通过 |
| cff44575 | 授权后正式视觉热修复，无候选路径覆盖，六模组vanilla | 原角色副本核验；12正例＋2基础LOS负例通过，新版本与心跳正常 |

正例为 31 级绿色天角兽、掠夺者、已发现地雷 × 右键/Q × 观察开/关。事件从 Stage 子对象发送，经过真实捕获、冒泡与原生 Ctr/player.control；不再仅向 Stage 自身发送事件。目标仍由 `Location.step()` 选择，未直接注入 celObj/onCursor。检查真实 teleObj/levit，并检查被抓掠夺者的 TDFC 控制退出。

**保留的失败**：8160cf24 的隔墙子检查首次失败，基础对照漏掉原档 `telemaster=1 && portOn=true` 的合法透墙条件。最终负例明确仅临时关闭副本角色的该天赋，结束立即恢复；`selected=UnitAlicorn`、物理 `line=false`、输入到达、`heldAny=false`，右键/Q 都通过。它证明原版基础 LOS 仍有效，不声称所有天赋状态都禁止隔墙抓取，也不声称已穷举视觉模组暗区策略。

45 项 AS3 检查通过（`logic-green.txt`），包括实际公开设置回调只读采集、Q 被吞时模式记录、空选不覆盖之前失败。新增测试首次因测试玩家漏设活跃状态 sost=1 而失败，修正测试数据后通过，生产逻辑未为通过测试而放宽。

## 授权前的产物与发布状态（历史）

- **TDFC 正式 0.6.2**：SHA `8A60C06D51E16C14C4B28AE8BC1005F92545A3F85EA50CF98D2C8467DE8A4A92`，28320 字节。仅增加诊断与专项回归，不替代视觉补丁。
- TDFC 回滚副本：`build/backups/TDFCMod-v0.6.1-before-v0.6.2-20260919.swf`，SHA `CC05DDFCB2B34320E67331F0F0CC3927792B055172057EF75CA52141C64AA820`。
- 视觉回滚副本已只读复制到 TDFC：`build/backups/RealisticVisionMod-v0.28.0-before-grabfix-20260919.swf`，SHA 与原视觉部署相同。**正式视觉尚未替换**。
- 其他模组 7 个部署文件/配置前后哈希相同，见 `other-mod-integrity.json`；视觉源码哈希亦保持原值。用户游戏及另一个项目的测试进程未控制，自建测试全部自动退出。
- TDFC 0.6.2 需要用户下次正常重启才加载；没有重启正在游玩的旧进程。

## 授权前的权限停点（下节已完成）

工作区 GOVERNANCE §7/§11 要求跨模组修改先明确授权；已完成可独立执行的调查、源码补丁准备、热修复编译、回归和回滚准备。下一步需用户允许修改 RealisticVision 正式源码/部署点，再把已验的一行修复合入当前源码，并部署独立 v0.28.0 热修复；不要顺带发布 v0.28.1 阴影候选。部署前重核三份视觉文件与补丁 SHA，保留其他项目工作树改动，走独立启动冒烟。之后仍需对用户原来的失败目标验收；若仍被拦截，优先读新 vision 与 GrabRecent 字段。

## 技能实战回流

采用运行时文件日志取证→可失败的原生事件链→删除共存模组最小化→单条件修复→同路径回归；按发布门禁只部署本项目诊断。未使用 Ghost、未操作正式游戏输入、未修改原始游戏 SWF/描述符。Skill 指纹：runtime-debug `68E12632…0C5740`；auto-testing `AB251815…639D0C`；test-report 2026-09-16.1 `CDE4695F…6FEBF5`。

[已落盘→shared-knowledge/entities/facts/telekinesis-grab-rules.md] 原抓取摘要是既有入口；本次另明确补正空悬停回退、透墙天赋条件与平方距离。模组私有模式缺陷、候选和权限停点保留在本报告，未写成游戏本体规则。技能行为没有改写。本报告已追加到 C:/Users/hello/.agents/测试报告台账.md 并回读，状态为待吸收；登记不等同于维护已吸收。

## 用户授权后的正式部署（2026-09-19 22:18 CST）

用户回答“允许”，授权上一轮已经准备好的RealisticVision源码修复与正式部署。按照发布门禁重新核对原文件、候选与配置，先建立唯一备份，再复制已经通过三模式回归的同一二进制。

- **正式视觉**：`mods/RealisticVision/release/RealisticVisionMod.swf`，v0.28.0-grabfix.1，SHA `E4E5ED82D5E65201A57A712F7BEBC6FDB499E7822C131B414A67700107401969`。
- **视觉自有回滚点**：`mods/RealisticVision/build/release_backup_v0280_before_grabfix_20260919.swf`，SHA `57FA90F813C267C1BB0BC4B4AAB536257CF10EDCD20E7E38BDA93E9B3AA9B6E0`。复制回视觉release并重启即可回滚。TDFC内旧备份及视觉原v0.27.1备份均保留。
- **源码**：单行守卫提交`a583f1a`。接续时视觉源码已出现另一任务的墙边修改；仅应用/暂存这一行，其余源码变化保留。正式文件仍由v0.28.0派生，没有编译或发布v0.28.1阴影候选。之前3B7F源码指纹是准备阶段的历史基线，不是现工作树指纹。
- **配置**：正式视觉config仍current，SHA `5136EE1923A77F5F10EAB1B3994B64CBD67B09D687A7E829FB1E81D2E79A3C7F`。没有修改用户的模式偏好。TDFC仍0.6.2与原8A60指纹；其他正式模组文件未改。

正式路径检查使用`start-test.ps1 -Mode TelekinesisCheck -TravelLand random_mane -ExtraMod RealisticVision,Sandevistan,RConnect,RandomRooms -TestVisionMode vanilla -Hidden`，**没有传TestVisionSwf**。manifest确认从正式视觉release复制E4E文件，只有测试配置切换到故障复现模式。run=`cff445759b4d4e67bda26e3cfd090a60`，测试真实读取模式0“原版”，核验Littlepip 29级槽0副本后进入随机马哈顿。

结果：天角兽/掠夺者/地雷×右键/Q×观察开关12次抓取全部成功；2次临时关闭并恢复副本透墙天赋的基础遮挡检查通过。日志最新启动段包含`init ok v0.28.0-grabfix.1`、`msw settings registered`、tick181/361。证据：`deployed-cff44575-result.json`、`-manifest.json`、`-status.json`、`-vision-log.txt`；文件回执为`deployment-receipt.json`和`deployed-integrity.json`。

自有测试PID49036已自动退出，随后移除该测试临时描述符。用户45036仍运行原来的游戏；视觉项目同期自建测试也未被控制。原存档只读复制，没有写入正式pfe存储。视觉工作树仍有原任务的阴影修改，因此仅提交本次拥有的守卫和记录，不为满足“干净仓库”而提交或还原他人工作。双方MEMORY/journal已接续；同一报告补记不重复登记台账。

用户需正常保存并重启游戏使两个更新生效。原失败目标的现场视觉模式未知，专项通过不替代该现场验收；若仍失败，优先读取新诊断的vision和GrabRecent。基地/自定义安全房间的透传守卫已与渲染路径对齐，但本轮专项只对三种显示模式做行为回归，未另建安全房间输入夹具。
