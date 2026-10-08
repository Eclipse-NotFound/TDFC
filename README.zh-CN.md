# TDFC — 敌人战术增强

[English](README.md) · **简体中文**

让敌人根据看见、听见和队友报告的信息选择瞄准、掩体、压制与推进。想让交火更有变化，可以从这个模组开始；敌人的生命和伤害仍沿用原版。

**[下载 v0.6.4 — TDFC_v0.6.4.zip](https://github.com/Eclipse-NotFound/TDFC/releases/download/v0.6.4/TDFC_v0.6.4.zip)** · [发布说明 / 其他版本](https://github.com/Eclipse-NotFound/TDFC/releases)

点击上方链接下载成品。也可以打开发布页，展开 **Assets（下载文件）**，选择同名文件；**Source code** 和绿色 **Code → Download ZIP** 是源码，不能直接安装。

## 会带来什么变化

- 第一次识别玩家需要观察；在记忆有效时再次目击，能够更快重新确认。
- 敌人依等级、训练和精英身份采用不同反应与决策水平。
- 不同阵营有不同作战倾向，例如掠夺者更主动逼近，铁骑卫更重视阵位与掩护。
- 普通游玩自动生效；需要观察时，可打开面板查看敌人正在做什么。

## 安装

适用于 **Windows / Remains 1.02**。

1. 保存并退出游戏。Steam 库中右键 Remains → **管理 → 浏览本地文件**，打开含 `pfe.swf` 和 `application.xml` 的游戏文件夹。
2. 第一次装本系列模组，先完成 [ModLoader 首次安装](https://github.com/Eclipse-NotFound/ModLoader/blob/master/docs/INSTALL.zh-CN.md#first-install)；它包含一次性游戏补丁和模组扫描器。已装好的玩家可跳过。
3. 解压下载的 ZIP，把里面的 **`mods` 文件夹合并到游戏文件夹**，不要套成 `mods/mods`。
4. 双击游戏目录下的 **`mods/ModLoader/RemainsModScanner.exe`**，等待完成后关闭提示，再按平常方式启动游戏。

放对后应能找到：`mods/TDFC/release/TDFCMod.swf`。与支持的敌人交战时自动生效；右上角 TDFC 按钮可打开观察面板。

[图示文件结构、更新与恢复方法](https://github.com/Eclipse-NotFound/ModLoader/blob/master/docs/INSTALL.zh-CN.md)

## 第一次怎么玩

正常进入游戏、探索和战斗即可，不需要按键激活。

想确认它在工作，点击右上角 **TDFC**，再点选敌人标签查看其观察与行动。橙线表示实际枪口方向，橙圈表示当前瞄准点。看完关闭面板即可；普通游玩默认不显示调试信息。

## 更新、停用与适用范围

更新前保存退出，备份 `mods/TDFC`，再合并新版文件、运行扫描器并重启；保留自己的配置。临时停用时，可把该模组文件夹移到 `mods` 之外备份，再扫描并重启。

本指引对应 v0.6.4 / Remains 1.02。主要接管掠夺者、铁骑卫、雇佣兵、奴隶贩子、斑马和英克雷；特殊首领和未识别单位保留原版行为。本版没有士气溃逃或主动包抄，也未全面认证联机。

## 遇到问题

先检查：文件夹是否放对、是否运行过扫描器、是否完全退出并重启。通用问题见[安装与排错指南](https://github.com/Eclipse-NotFound/ModLoader/blob/master/docs/INSTALL.zh-CN.md#troubleshooting)。

仍有问题，请到[问题反馈](https://github.com/Eclipse-NotFound/TDFC/issues)说明：游戏版本、本模组版本、其他已装模组、操作步骤、预期结果与实际结果；能附截图或报错原文更好。不要上传个人存档，除非排查时确有需要。

<details>
<summary>开发资料（普通安装无需阅读）</summary>

本页按可下载的发布包编写，仓库源码可能更靠前。实现见 [src](src/)；历史设计、验证和版本记录保留在项目目录中。

</details>

[查看全部模组及玩法介绍](https://github.com/Eclipse-NotFound/ModLoader/blob/master/README.zh-CN.md#choose-mods) · [首次安装指南](https://github.com/Eclipse-NotFound/ModLoader/blob/master/docs/INSTALL.zh-CN.md)

这是玩家制作的非官方模组项目，需要自行拥有游戏。
