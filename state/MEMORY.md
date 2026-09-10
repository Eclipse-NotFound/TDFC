# TDFC —— 开发记忆入口

> 新会话从这里开始。协议见工作区 GOVERNANCE.md §8；本模组参数见 ../AGENT_SCOPE.md。

## 1. 这个模组是什么

TDFC 增强《FOE REMAINS》敌人 AI 的战术意识：**信息层**（目击/枪声/受击传播 + 记忆搜索）+ **生存层**（瞄准回避/掩体/撤退）+ **感知层**（噪声治理/锥形视野/背后盲区）+ **配合层**（小队角色/压制/散开/交叉火力），让敌人"知道你在哪、会应对、有弱点、会协作"。全程不写 internal、不 hook 原型（纯 public API + 帧窗驱动）。入口类 `TDFCMod`。

## 2. 用户偏好与协作约定

- ~~不要自动启停游戏~~（2026-08-27 用户放行"改动同时顺便完成测试"）→ **用隔离测试实例**（`build/app_tdfc_test_pfe.xml`，id=pfe-tdfc-test），**绝不碰用户实例/存档**。
- 测试模式：F9 生成带枪高血掠夺者（枪械池轮换）；或跑 AutoTest 全自动。
- 日志：测试实例 `%APPDATA%\pfe-tdfc-test\Local Store\tdfc.log`；用户实例在 `...\pfe\Local Store\tdfc.log`。

## 3. 当前状态

- **v0.5.4**（2026-08-28），git 独立仓库；2026-09-10 接手时代码基线 `4201b3c`，工作树干净。本次仅静态核对，未重新运行游戏或构建。
- loader 已合并进 pfe.swf（备份 `pfe_1.02_before_tdfc_merge_20260817.swf`）；换 SWF 需重启游戏。
- 配合层（SquadCtrl）有**历史自动化实机验证记录**（长游玩存档上）：小队编队/压制者分配/压制触发/撤退通过；瞄准回避/掩体/交叉火力落点仍待验证，不能把历史结果当作当前环境复跑结果。
- v0.5.2 修复"敌人瞄地面"：模组写 cel 的瞄准点必须用原版立绘中心公式（`TdfcMain.playerAimPoint`：`Y - scY/2` + 朝向前置量），移动点仍用脚底 Y。
- v0.5.3 AutoTest 支持种入长档：`D:\Remains\Littlepip.sav`（只读）走原生 `comLoad=99 + loaddata` 通道。**2026-09-10 此路径不存在**；代码会回退新档，因此当前不能复现历史长档场景。

## 4. 自动化测试（AutoTest，v0.5.1 新增 / v0.5.3 种档）

- 激活：运行时 `applicationID == Config.TEST_APP_ID`（"pfe-tdfc-test" 精确匹配；v0.5.4 前曾是"≠pfe"排除法，误劫持过 RConnect pfe2 双开实例——教训：测试钩子身份判定严禁排除法）。
- 存档位置：测试实例 `%APPDATA%\pfe-tdfc-test\Local Store\#SharedObjects\pfe.swf\PFEgame0.sol`；用户真实槽位 `%APPDATA%\pfe\...\#SharedObjects\pfe.swf\PFEgameN.sol`；`D:\Remains\Littlepip.sav` = 游戏导出的长游玩档（AutoTest 种入源，**只读**）。
- 流程：等 landData→放菜单→newGame(-1) 建骨架→种档（readObject→loaddata+comLoad=99→等 loc 重建）→圈养 2 只带枪掠夺者（hp200）→每 450t 照料靶机→玩家 <60% 血回血。
- 断言关键词：`squad f=`、`supp START/END`、`retreat GO`、`space SEP`、`hb ... supp=N`。
- 复跑前读 remains-auto-testing 技能，确认精确应用 ID、描述符 content 相对位置、种档成功日志与隔离存储；只结束本轮创建的测试进程。清理须核实绝对路径与隔离归属，不能照旧日志泛删。当前缺少配置中的长档。
- 构建依赖路径（Java、mxmlc、两份 SWC）于 2026-09-10 检查存在，未验证可执行性。`build/build.bat` 直接输出到 release，不能作为无部署影响的探测命令。

## 5. 已知问题

- `gg.noise` 出现负值（-10/-15）——非 TDFC 写入，监控中。
- 玩家挂机被后坐力推走会漂移数百 px（AutoTest 圈养坐标跟着玩家走，无碍）。
- 压制盲射路径已实现未断言（本轮压制者都有 LOS）。
- 暂停一致性待验：TdfcMain.onFrame 检查主菜单，却未对齐原版 World.step 的 allStat/onPause/catPause/verror 条件；背包、战术暂停等状态下可能仍推进战术计时或写入指令。当前是静态风险，未实测确认表现。
- 感知假设待复核：Perception 的“噪声是唯一路径”“全游戏不写 vAngle”注释不成立；原版还有 alarma 等入口，炮塔会写 vAngle。需检查模组覆盖这些字段的实际后果。
- SearchCtrl 重获目标只用距离和射线通畅检查，未复用视野角/隐蔽条件；需核对其与后加感知层的设计是否一致，尚未判定应如何调整。

## 6. 下一步（优先级排序）

1. 后续涉及行为修改时，先补当前隔离测试基线：确认可用的授权长档来源，验证暂停一致性与感知/搜索衔接；未有种档成功证据不得声称长档验证通过。
2. 验证当前 v0.5.4 的瞄准回避、掩体、交叉火力、失去视线后压制，以及噪声/锥形/墙角固守的游玩表现。
3. 按证据和用户反馈调参；补 phase2 设计历史以及过时注释。Phase 4 士气与 Phase 5 侧翼/性能仍是候选方向，本次接手没有启动新功能。

## 7. 深入了解

- **本次接手基线**：state/handoff-2026-09-10.md（调用顺序、证据位置、环境缺口与验证边界）
- **开发历程**：state/journal.md（v0.1.0→v0.5.1 全程；2026-08-27 三条=配合层设计/实现/自动化验证）
- **设计**：design/phase2-enemy-survival.md、design/phase3-cooperation.md（配合层，命令开火链路反编译证据 §2）、design/brainstorm-01-enemy-ai.md
- **实证**：knowledge/facts/build-environment.md（本机工具链：D:\RemainsMod\mods\Sandevistan\build\tools + Animate 2024 JRE）
- **共享知识贡献**：mod-log-channel / enemy-ai-drive-interfaces / frame-diff-event-detection；remains-auto-testing 技能（newGame(-1)/boot 时序/verror 冻结/app id 字符集，2026-08-27 回填）
- **构建**：build/build.bat（JAVA_HOME=Animate JRE → mxmlc -load-config build/tdfc-config.xml）
- **技能**：remains-mod-build、remains-runtime-debug、remains-auto-testing
