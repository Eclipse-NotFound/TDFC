# TDFC —— Agent 工作范围

> 完整治理规则见工作区根目录 `GOVERNANCE.md`（权限模型、知识库、参考区、游戏文件修改、外置记忆协议、同步与镜像）。
> 本文件只记录本模组的参数与特例。开始开发：读本文件 → 读 `state\MEMORY.md`（记忆入口）。

## 项目参数

| 项 | 值 |
|---|---|
| project | TDFC |
| workspace | mods/TDFC/ |
| repository | 本目录为独立 git 仓库 |
| 运行时入口 | release/TDFCMod.swf（入口类 `TDFCMod`，`public static init(main)`） |
| 记忆入口 | state/MEMORY.md |

## 本模组特例（相对 GOVERNANCE 的偏离/补充）

- `decisions\` 目录为后补（历史决策记录在代码注释与 journal 中，见 MEMORY.md）；今后的重要决策按 ADR 补入。
- 构建用 Apache Flex mxmlc + 自建 config（`build\tdfc-config.xml` 显式写 .swc 绝对路径），细节见 `remains-mod-build` 技能。
