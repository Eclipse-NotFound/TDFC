# TDFC 编译环境总结（模组专属，非游戏机制）

- 更新：2026-08-17
- 用途：记录 TDFC 构建环境的事实，避免后续会话重复踩坑

## 工具链

- 编译器：`C:\Users\micha\Documents\_sandevistan_dev\flexsdk\bin\mxmlc`
  （Apache Flex 4.16.1 build 20171115，JDK 1.8）
- AIR 库：`C:\Users\micha\Documents\_sandevistan_dev\airsdk\frameworks\libs\air\airglobal.swc`
- 编译配置：`build/tdfc-config.xml`；一键构建：`build/build.bat`
- 关键点：flexsdk 内置 flex-config 的 `{flexlib}/{playerglobalHome}/{airHome}` 令牌
  全部失效（SDK 目录被移动过）→ 必须用自建 config 显式指定两个 .swc 绝对路径。
- 目标：`-target-player=14.0`（flexsdk 自带 player14.0/32.0 的 playerglobal）。

## ASC 编译器怪癖（已踩两次）

- **"函数没有返回值"**：当函数以"`try { return ...; } catch (e:Error) { return ...; }`"
  作为**最后一条语句**结构结尾时，Flex 4.16 ASC 的控制流分析不认其中的 return，
  报 `函数没有返回值`。
- 解法：一律改成"函数末尾单一 `return r;`，try/catch 只赋值不 return"（见
  `TdfcMain.num()` 与 `TdfcMain.shortClass()` 的最终形态）。
- 教训：本环境写任何带 try/catch 的工具函数都直接采用"单尾部 return"风格。

## 日志通道（跨模组事实已回馈）

- 完整事实见 `shared-knowledge/knowledge-validation/facts/mod-log-channel.md`。
- 摘要：app:/ 只读；模组日志写 `File.applicationStorageDirectory`（=
  `AppData/Roaming/pfe/Local Store`，**自带 Local Store 后缀，不要再拼一层**）；
  被 Loader 加载的模组 trace() 不进 adl stdout → 文件日志是唯一可观测通道。

## 部署备忘

- pfe.swf loader 合并：工作区 `build/ffdec_work/`（export=全量反编译、import=只含
  修改后的 MainFE.as、pfe_tdfc.swf=合并产物）。备份
  `pfe_1.02_before_tdfc_merge_20260817.swf` 在游戏根目录。
- 换 SWF 后需重启游戏生效（Loader 只在启动时读 release/TDFCMod.swf）。