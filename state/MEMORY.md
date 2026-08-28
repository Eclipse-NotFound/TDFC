# TDFC —— 开发记忆入口

> 新会话从这里开始。协议见工作区 GOVERNANCE.md §8；本模组参数见 ../AGENT_SCOPE.md。

## 1. 这个模组是什么

TDFC 增强《FOE REMAINS》敌人 AI 的战术意识：**信息层**（目击/枪声/受击传播 + 记忆搜索）+ **生存层**（瞄准回避/掩体/撤退）+ **感知层**（噪声治理/锥形视野/背后盲区）+ **配合层**（小队角色/压制/散开/交叉火力），让敌人"知道你在哪、会应对、有弱点、会协作"。全程不写 internal、不 hook 原型（纯 public API + 帧窗驱动）。入口类 `TDFCMod`。

## 2. 用户偏好与协作约定

- ~~不要自动启停游戏~~（2026-08-27 用户放行"改动同时顺便完成测试"）→ **用隔离测试实例**（`build/app_tdfc_test_pfe.xml`，id=pfe-tdfc-test），**绝不碰用户实例/存档**。
- 测试模式：F9 生成带枪高血掠夺者（枪械池轮换）；或跑 AutoTest 全自动。
- 日志：测试实例 `%APPDATA%\pfe-tdfc-test\Local Store\tdfc.log`；用户实例在 `...\pfe\Local Store\tdfc.log`。

## 3. 当前状态

- **v0.5.4**（2026-08-28），git 独立仓库。
- loader 已合并进 pfe.swf（备份 `pfe_1.02_before_tdfc_merge_20260817.swf`）；换 SWF 需重启游戏。
- 配合层（SquadCtrl）**已过自动化实机验证**（长游玩存档上）：小队编队/压制者分配/压制触发/撤退全绿；瞄准回避/掩体/交叉火力落点待用户实测（需玩家主动行为）。
- v0.5.2 修复"敌人瞄地面"：模组写 cel 的瞄准点必须用原版立绘中心公式（`TdfcMain.playerAimPoint`：`Y - scY/2` + 朝向前置量），移动点仍用脚底 Y。
- v0.5.3 AutoTest 种入长档：`D:\Remains\Littlepip.sav`（只读）走原生 `comLoad=99 + loaddata` 通道，测试角色不再是白板。

## 4. 自动化测试（AutoTest，v0.5.1 新增 / v0.5.3 种档）

- 激活：运行时 `applicationID == Config.TEST_APP_ID`（"pfe-tdfc-test" 精确匹配；v0.5.4 前曾是"≠pfe"排除法，误劫持过 RConnect pfe2 双开实例——教训：测试钩子身份判定严禁排除法）。
- 存档位置：测试实例 `%APPDATA%\pfe-tdfc-test\Local Store\#SharedObjects\pfe.swf\PFEgame0.sol`；用户真实槽位 `%APPDATA%\pfe\...\#SharedObjects\pfe.swf\PFEgameN.sol`；`D:\Remains\Littlepip.sav` = 游戏导出的长游玩档（AutoTest 种入源，**只读**）。
- 流程：等 landData→放菜单→newGame(-1) 建骨架→种档（readObject→loaddata+comLoad=99→等 loc 重建）→圈养 2 只带枪掠夺者（hp200）→每 450t 照料靶机→玩家 <60% 血回血。
- 断言关键词：`squad f=`、`supp START/END`、`retreat GO`、`space SEP`、`hb ... supp=N`。
- 复跑：描述符复制到游戏根 → `adl64.exe -runtime runtimes/air/win64 app_tdfc_test_pfe.xml`（后台，记得 `set -o pipefail`）→ 等 ~120s → grep 日志 → 按 `*app_tdfc_test*` 命令行杀实例（只匹配 adl64.exe）→ 删 `%APPDATA%\pfe-tdfc-test`。

## 5. 已知问题

- `gg.noise` 出现负值（-10/-15）——非 TDFC 写入，监控中。
- 玩家挂机被后坐力推走会漂移数百 px（AutoTest 圈养坐标跟着玩家走，无碍）。
- 压制盲射路径已实现未断言（本轮压制者都有 LOS）。

## 6. 下一步（优先级排序）

1. 用户实测 v0.5.1（压制观感/精度/时长手感）+ v0.4.x 手感项（噪声/锥形/墙角固守/躲避）；
2. 按反馈调参（Config.as v0.5 段：SUPPRESS_*/SPACING_*）；
3. Phase 4 士气层、Phase 5 打磨（侧翼包抄/难度参数/性能）；
4. 待补：design/phase2-enemy-survival.md 补 v0.3-v0.4 决策记录。

## 7. 深入了解

- **开发历程**：state/journal.md（v0.1.0→v0.5.1 全程；2026-08-27 三条=配合层设计/实现/自动化验证）
- **设计**：design/phase2-enemy-survival.md、design/phase3-cooperation.md（配合层，命令开火链路反编译证据 §2）、design/brainstorm-01-enemy-ai.md
- **实证**：knowledge/facts/build-environment.md（本机工具链：D:\RemainsMod\mods\Sandevistan\build\tools + Animate 2024 JRE）
- **共享知识贡献**：mod-log-channel / enemy-ai-drive-interfaces / frame-diff-event-detection；remains-auto-testing 技能（newGame(-1)/boot 时序/verror 冻结/app id 字符集，2026-08-27 回填）
- **构建**：build/build.bat（JAVA_HOME=Animate JRE → mxmlc -load-config build/tdfc-config.xml）
- **技能**：remains-mod-build、remains-runtime-debug、remains-auto-testing
