# TDFC 编译环境总结（模组专属，非游戏机制）

- 更新：2026-08-27（本机工具链定位并验证编译）
- 用途：记录 TDFC 构建环境的事实，避免后续会话重复踩坑

## 工具链（当前机器实测可用）

- **完整 SDK 位置**：`D:\RemainsMod\mods\Sandevistan\build\tools\`
  （flexsdk = Flex 4.16.1 + AIR SDK 51.3.3 合并包、airsdk、ffdec——
  即旧 `_sandevistan_dev` 工具链整体迁入 Sandevistan 源仓库随行）
- 编译器：`D:\RemainsMod\mods\Sandevistan\build\tools\flexsdk\bin\mxmlc`
- Java：本机无独立 JDK；用 **Adobe Animate 2024 自带 JRE 17**
  （`D:\Program Files\Adobe Animate 2024\jre`）——实测 mxmlc 4.16.1 可正常运行；
  FFDec 同样用该 JRE（`java -jar ffdec-cli.jar`，ffdec-cli.exe 自身找不到 Java）
- AIR 库：`D:\RemainsMod\mods\Sandevistan\build\tools\airsdk\frameworks\libs\air\airglobal.swc`
- playerglobal：同树 `libs\player\14.0\playerglobal.swc`
- 编译配置：`build/tdfc-config.xml`（显式 .swc 绝对路径，2026-08-27 已改新路径）；
  一键构建：`build/build.bat`（设 JAVA_HOME 后调 mxmlc.bat，ASCII+CRLF）
- 目标：`-target-player=14.0`
- 验证：2026-08-27 编译 v0.5.0 一次通过；`ffdec -dumpAS3` 确认 SWF 恰含
  11 个 TDFC 类、零 fe.* 类定义（ABC 里的 "fe.World" 字符串是
  getDefinition 字面量，属动态访问正当用法，不是嵌入泄漏）。

## 旧机器路径（已作废，勿再引用）

- `C:\Users\micha\Documents\_sandevistan_dev\...`（flexsdk/airsdk/ffdec 旧位置）——
  当前机器不存在该目录。2026-08-17 版记录的"flex-config 令牌失效"问题源于
  旧机器 SDK 目录被移动；现 SDK 目录完整，问题不再出现，但自建 config
  显式路径的惯例保留（防再迁移）。

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
