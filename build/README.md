# TDFC 构建与测试

## 使用后期存档手动观察

双击模组根目录的 `Start-Test.bat`。它启动独立的 TDFC 测试窗口，复制原版 1.02 的全部现有槽位，默认载入自动存档（槽位 0），并打开观察面板。手动观察不会自动生成敌人、回血或关闭背包。关闭窗口即结束；测试中的保存仅影响副本。

选择其他槽位：

```powershell
.\build\start-test.ps1 -Mode Observe -SaveSlot 5
```

导入游戏导出的文件：`-SaveFile 'D:\某处\Littlepip.sav'`。只有显式传 `-Fresh` 才创建新档；空档/损坏档不会回退新档。已打开测试窗口时启动器会停止并提示先关闭该测试窗口，不会关闭其他游戏。

## 构建与自动检查

```powershell
.\build\build.ps1
.\build\start-test.ps1 -Mode LoadCheck -Hidden
.\build\start-test.ps1 -Mode Combat -Hidden -Ticks 1200
.\build\start-test.ps1 -Mode Combat -TravelLand random_mane -Hidden
.\build\start-test.ps1 -Mode CoverCheck -Hidden
.\build\start-test.ps1 -Mode TelekinesisCheck -TravelLand random_mane -Hidden
.\build\start-test.ps1 -Mode TelekinesisCheck -TravelLand random_mane -ExtraMod RealisticVision,Sandevistan,RConnect,RandomRooms -Hidden
.\build\test-logic.ps1
```

编译输出到 `build/out/TDFCMod.swf`，不部署到生产 `release/`。自动场景会运行完后退出，启动器返回 PID 和每轮唯一编号。读取 `build/test-game/tdfc-test-result.json` 时必须核对 `run` 与本轮一致，旧结果不能算新一轮通过。

- `tdfc-test-manifest.json`：原存档路径、复制前 SHA256、构建 SHA256、依赖版本。
- `tdfc-test-result.json`：通过/失败、原档角色/等级/地点、实际角色/等级/地点。
- `tdfc-test-status.json`：加载阶段、战术帧、暂停原因、日志状态。
- `tdfc-test-screen.png`：运行时画面快照。
- `%APPDATA%/pfe-tdfc-test/Local Store/tdfc.log`：测试日志。

`CoverCheck` 在真实地图中寻找可达的掩体/探头位置，固定测试玩家位置和已知情报，持续给敌人“受压”输入；在这个专项中排除慢弹干扰。通过条件是观察到实际位移、遮挡、探头恢复射线。它验证行动执行，不冒充对自然感知和所有地图的验证。

`TelekinesisCheck` 生成可见掠夺者与已发现地雷，选择不与其他交互对象重叠的位置，经过原生对象选中、右键事件、玩家控制，断言成功抓取；另验证被抓敌人的战术控制已交还。它覆盖观察开/关两种状态。若要亲自点鼠标，改为 `-Mode TelekinesisUI`：目标第一次被抓取前固定在出生位置，敌人伤害为零、地雷感应禁用；抓取后停止固定，窗口须手动关闭。此模式不自动给出 PASS。

`-ExtraMod` 仅复制指定模组的已部署文件和配置到 TDFC 测试目录，用于共存排查。下一轮不传此参数会移除测试目录内这些额外 SWF，避免污染基线；不会编辑其他模组项目。联机模组保持离线，不点击 Host/Join。

## 原存档与依赖

当前原档在 `%APPDATA%/pfe/Local Store/#SharedObjects/pfe.swf/PFEgameN.sol`，测试副本在相同尾路径的 `pfe-tdfc-test` 存储中；不同游戏 SWF 的槽位目录不同。TDFC 启动器不改原目录，也不修改根目录 `application.xml` 或 `pfe.swf`。

已有存档含技能武器模组物品，所以必须带上它的已部署 SWF。该版本自带的自动测试会误判所有非 `pfe` 窗口、抢先新建角色。`prepare-test-dependency.ps1` 只在 TDFC 的 `build/out/` 中生成依赖副本，将其自动测试限定为 `pfe-msw-test`，定向编译并反编译回读验证，再复制到测试目录；不改其他模组项目。源 SWF 变化后重新核对锚点，失败即停止启动。

随机地图不会随原版存档恢复：原版 `Game.init` 将这类读档送回基地 `rbl`。测试报告同时保留原存档地点和预期恢复地点，不把正常回基地当成载入失败。
