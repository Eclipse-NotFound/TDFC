# TDFC —— 开发记忆入口

> 新会话从这里开始。协议见工作区 GOVERNANCE.md §8；本模组参数见 ../AGENT_SCOPE.md。

## 1. 这个模组是什么

TDFC 增强《FOE REMAINS》敌人 AI 的战术意识：**信息层**（目击/枪声/受击传播 + 记忆搜索）+ **生存层**（瞄准回避/掩体/撤退）+ **感知层**（噪声治理/锥形视野/背后盲区）+ **配合层**（小队角色/压制/散开/交叉火力），让敌人"知道你在哪、会应对、有弱点、会协作"。全程不写 internal、不 hook 原型（纯 public API + 帧窗驱动）。入口类 `TDFCMod`。

## 2. 用户偏好与协作约定

- **不要自动启停游戏**（AIR 单实例转交会误杀用户会话——历次教训）。
- 测试模式：F9 面板生成掠夺者（`spawn raider ... weapon=true`）→ 用户实测 → 读日志判读。
- 日志：`AppData/Roaming/pfe/Local Store/tdfc.log`（mod 的 trace 不进 adl stdout）。

## 3. 当前状态

- **v0.5.0**（2026-08-27），git 仓库独立，工作树随本轮提交干净。
- loader 已合并进 pfe.swf（合并前备份 `pfe_1.02_before_tdfc_merge_20260817.swf`）；换 SWF 需重启游戏。
- v0.5.0 新增配合层（SquadCtrl）：小队角色/压制协议/散开/交叉火力，全部独立开关（Config.ENABLE_*），编译+FFDec 离线验证过，**运行时未验证**。

## 4. 正在进行与卡点

- **v0.4.x 与 v0.5.0 均待用户实测**：v0.4 手感项（噪声/锥形/目击确认/传播延迟/墙角固守/躲避残留）+ v0.5 场景（设计 §6：双敌散开、压制触发/盲射/上限、换弹掩护、交叉火力落点、单敌回归）。
- 发布门禁第 8 项（重启冒烟：日志出现 `TDFC v0.5.0 ... squad=1` 标记行）待用户重启游戏完成。

## 5. 已知问题

- `gg.noise` 出现负值（-10/-15）——非 TDFC 写入，监控中。
- 枪声日志量大（DIAG_CAP=300 当前够用）。
- 压制协议依赖压制者 lastSeen 新鲜度；玩家彻底脱离 120t 后盲射自动停止（设计内，非 bug）。

## 6. 下一步（优先级排序）

1. 用户实测 v0.4.2 + v0.5.0（先冒烟确认加载，再按 design/phase3-cooperation.md §6 场景走）；
2. 按实测反馈调参（压制精度/时长/冷却、散开阈值最可能要调）；
3. Phase 4 士气层（保留后备）、Phase 5 打磨（侧翼包抄/难度参数/性能）；
4. 待补：design/phase2-enemy-survival.md 补 v0.3-v0.4 决策记录（目前只在代码注释与 journal）。

## 7. 深入了解

- **开发历程**：state/journal.md（v0.1.0→v0.5.0 全程带日期，每条=一个实机反馈闭环）
- **决策速查**：journal 顶部"关键技术决策速查"；历史决策多在代码注释（decisions/ 为后补）
- **设计**：design/phase2-enemy-survival.md（生存层）、design/phase3-cooperation.md（配合层，含命令开火链路的反编译证据 §2）、design/brainstorm-01-enemy-ai.md
- **实证**：knowledge/facts/build-environment.md（本机工具链：D:\RemainsMod\mods\Sandevistan\build\tools + Animate 2024 JRE）
- **共享知识贡献**：shared-knowledge 的 mod-log-channel / enemy-ai-drive-interfaces / frame-diff-event-detection
- **构建**：build/build.bat（JAVA_HOME=Animate JRE → mxmlc -load-config build/tdfc-config.xml）
- **技能**：remains-mod-build、remains-runtime-debug、remains-auto-testing
