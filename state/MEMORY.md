# TDFC —— 开发记忆入口

> 新会话从这里开始。协议见工作区 GOVERNANCE.md §8；本模组参数见 ../AGENT_SCOPE.md。

## 1. 这个模组是什么

TDFC 增强《FOE REMAINS》敌人 AI 的战术意识：**信息层**（目击/枪声/受击传播 + 记忆搜索）+ **生存层**（瞄准回避/掩体/撤退）+ **感知层**（噪声治理/锥形视野/背后盲区），让敌人"知道你在哪、会应对、有弱点"。全程不写 internal、不 hook 原型（纯 public API + 帧窗驱动）。入口类 `TDFCMod`。

## 2. 用户偏好与协作约定

- **不要自动启停游戏**（AIR 单实例转交会误杀用户会话——历次教训）。
- 测试模式：F9 面板生成掠夺者（`spawn raider ... weapon=true`）→ 用户实测 → 读日志判读。
- 日志：`AppData/Roaming/pfe/Local Store/tdfc.log`（mod 的 trace 不进 adl stdout）。

## 3. 当前状态

- **v0.4.2**（2026-08-21），git 仓库 15+ 提交，工作树干净。
- loader 已合并进 pfe.swf（合并前备份 `pfe_1.02_before_tdfc_merge_20260817.swf`）；换 SWF 需重启游戏。

## 4. 正在进行与卡点

- **v0.4.x 整体待用户复测**（噪声/锥形/目击确认/传播延迟手感、墙角固守、躲避残留）。历轮已修问题（抽搐/枪口歪/墙边乱跳/只走不跑/墙角原地跳）都含在本版本，但用户尚未完整复测 v0.4.2。

## 5. 已知问题

- `gg.noise` 出现负值（-10/-15）——非 TDFC 写入，监控中。
- 枪声日志量大（DIAG_CAP=300 当前够用）。

## 6. 下一步（优先级排序）

1. 用户复测 v0.4.2（潜行链路 + 墙角 + 躲避）；
2. **Phase 3 配合层**设计启动：战斗角色分配 / 压制协议 / 散开间距 / 交叉火力（design/brainstorm-01 设想 2 深化；基础已有：`Weapon.attack()` public 可命令开火）；
3. Phase 4 士气层（保留后备）、Phase 5 打磨（侧翼/难度参数/性能）；
4. 待补：design/phase2-enemy-survival.md 补 v0.3-v0.4 决策记录（目前只在代码注释与 journal）。

## 7. 深入了解

- **开发历程**：state/journal.md（v0.1.0→v0.4.2 全程带日期，每条=一个实机反馈闭环）
- **决策速查**：journal 顶部"关键技术决策速查"；历史决策多在代码注释（decisions/ 为后补）
- **设计**：design/phase2-enemy-survival.md（生存层 8 节）、design/brainstorm-01-enemy-ai.md（含 Phase 3 设想）
- **实证**：knowledge/facts/build-environment.md（编译环境与 ASC 怪癖）
- **共享知识贡献**：shared-knowledge 的 mod-log-channel / enemy-ai-drive-interfaces / frame-diff-event-detection
- **构建**：build/build.bat（mxmlc -load-config build/tdfc-config.xml；flexsdk 内置令牌失效须自建 config）
- **技能**：remains-mod-build、remains-runtime-debug、remains-auto-testing
