被测技能：remains-runtime-debug / remains-auto-testing / diagnosing-bugs（用于 TDFC 业务排障）
技能归属：Remains 工作区 .agents/skills；用户级 diagnosing-bugs
测试工作区：D:\Program Files\Steam\steamapps\common\Remains

# 2026-09-12 TDFC 0.6.1 念力与鼠标输入验证

## 请求、结论与边界

用户反馈“右键不能用念力抓起敌人和地雷等”，中断桌面操作后又要求继续。定位并修复了两个 TDFC 缺陷：拖动结束事件被自身按钮吞掉；敌人已经被念力抓住时，战术执行仍改写能力并可调用开火。42 项 AS3 检查通过，原生抓取检查和实际鼠标操作均通过。

没有复现“所有敌人、地雷在所有位置都无法抓取”。初次原生目标识别检查另复现了敌人与 CheckPoint 重叠时，游戏选中 CheckPoint 而抓取失败；这是原版目标优先级，不将其冒充 TDFC 回归。视觉模组确有拦截不可见单位输入的逻辑，但本轮可见目标测试中未触发，未修改或绕过该规则。

新增 GrabDiagnostics 只读观察：开启 TDFC 观察模式后记录最近右键/默认 Q 的传播、输入之前的原版悬停对象和限制，以及两帧后的实际持有对象。UI 显示最近操作结果，导出包含原始条件。它不是精确追踪原版内部每一处分支；输入前的 celObj 可能尚未随鼠标移动刷新，报告保留这一事实。不会伪造成功、改绑按键或自动抓取。

## 环境与隔离

- 根目录游戏 1.02，实际 SWF pfe.swf；AIR、Flex、Java 使用本机已验证工具链。
- 从正式槽 0 只读复制 Littlepip 29 级，源 SHA256 `4B7AE37B5FF731089A5B36D1C0D2314C38F6DA4961DA4B5AAE456762E871A15C`。11 个正式槽位均不写入。
- 精确测试身份 `pfe-tdfc-test`，专用 build/test-game；使用已修正自动开档身份的技能武器依赖副本。
- 共存轮仅复制其他四个模组的已部署 SWF/配置；联机保持 offline。四个模组均产生本轮日志，桌面画面也确认其 UI/效果存在。配置、副本来源和 SHA 见 final-manifest.json。
- 核对 11 个正式槽位、额外模组的 7 个二进制/配置文件，共 18 个源文件均未改变，见 source-integrity.json。只关闭了本轮创建且重新核验身份的测试 PID 14900；自动场景自行退出。
- 本轮不委托子代理：排障依赖同一游戏实例的输入、状态和证据，串行控制更便于归因。

## 可复查结果

证据目录：[evidence/telekinesis-2026-09-12](evidence/telekinesis-2026-09-12)。所有判断核对本轮 run，不接受旧 PASS。

| 检查 | 结果与证据 |
|---|---|
| 直接右键事件→玩家控制，观察开/关 | 原版能力和键位正常，4 次抓取通过。telekinesis-baseline-20260912.json；只作初筛，未覆盖原生选中链。 |
| 原生 Location/Unit 目标识别 | CheckPoint 抢占敌人目标，敌人失败/地雷成功。telekinesis-native-overlap-20260912.json。换无重叠位置后与视觉模组共存的 4 次抓取通过。 |
| 修复前 AS3 回归 | 2 项 FAIL：在拖动手柄上松开未结束拖动；念力单位仍被改写/下令。telekinesis-logic-red-20260912.txt。 |
| 修复前游戏原生对象与全部模组 | 实际抓取成功，但两个敌人检查 yielded=false。telekinesis-allmods-red-20260912.json，run 72bda599410f4dd1b44d2fa6bebb17bf。 |
| 修复后逻辑 | 42 项 PASS，包括释放事件传递、失焦取消拖动、念力接管/释放恢复、归还已有能力覆盖、诊断原因。logic-green.txt。 |
| 最终待部署文件 | 4 次实际对象抓取通过，敌人两项 yielded=true，观察开/关均覆盖。final-result.json，run 57b98338247049d88d7295130f86a884。 |
| 真实桌面鼠标 | 掠夺者与地雷均被右键抓取，第二次右键释放地雷。ui-runtime.txt 有三条 grab 结果。界面实见“念力控制中”，结束后恢复正常战术；拖动面板松开后位置不再跟随鼠标。 |

桌面检查的 TelekinesisUI 为固定测试靶：首次抓取前固定出生位置，掠夺者无伤害、地雷感应关闭；抓取后停止固定。不能等同于任意自然战斗场景。敌人的 PNG 留存较晚，显示的是最近一次“已抓取”结果及恢复后的战术，不能用这一张 PNG 单独证明正在持握；持握瞬间在桌面工具返回画面中已直接观察。地雷 PNG 显示原版丢下提示与成功结果。

Q 的桌面尝试进入中文输入法组合状态，不计为 Q 成功验收；本轮实际操作通过的是右键。没有改变用户输入法设置。

## 修复与部署

- DebugOverlay 的拖动结束改用先于子控件的事件监听，失焦/离窗/隐藏时也取消；按钮放行鼠标释放，让原版控制器清除按住状态。
- ActionExecutor 检测原版 levit，归还此前持有的移动能力/射击/视野设置，撤销旧目标与掩体。TdfcRuntime 同步释放小队压制位置。释放念力后重新决策。
- 添加念力结果/失败条件观察、遮挡文字标签。保留原版与其他模组的抓取规则。
- 发布文件 release/TDFCMod.swf，26894 字节，SHA256 `CC05DDFCB2B34320E67331F0F0CC3927792B055172057EF75CA52141C64AA820`，与最终测试文件一致。只替换本模组 release，未改游戏 SWF/描述符或其他模组项目。
- 备份 build/backups/TDFCMod-v0.6.0-before-v0.6.1-20260912.swf，SHA256 `430D2DE96802A69E485D812C996AA77E03B6B18F566C489AB35EC1664EF17CBC`。回滚时复制回 release/TDFCMod.swf 并重启。
- 部署后隔离重启读档冒烟通过，run `1892a97a1504474385d14cc846b88ed9`，Littlepip 29 级恢复至原版预期 rbl；deployed-smoke-result.json 与 deployed-smoke-manifest.json 可核验，测试 SWF 与 release 哈希相同。

## 发现归属与未测项

输入、念力控制争用归属 TDFC 实现，以上新证据为本轮产物；未改技能正本。已有抓取规则见 shared-knowledge/entities/facts/telekinesis-grab-rules.md。原版目标重叠个案留在本实验记录，不提升为跨地图定论。

本轮不是全地图、所有头目、时停回放、联机在线或长期压力验收；未对用户此前具体失败现场作一一回放。若正常游戏仍有个案，可直接用新观察行及“保存诊断”继续定位。

## 回执要求

需要时核对原生选中链与直接事件注入的证据层次，避免把最早的 4 次 PASS 当成整条鼠标链的充分证明。无需据此自动修订技能。
