# 原版回归基线

`LegacyBaseline.as` 仅供旧代码基线 `4201b3c` 使用：需要把该提交的 `src` 导出到临时目录，再与本文件一起编译。不要加入 v0.6 的正常测试路径。

2026-09-10 在真实 AIR 上运行的结果：`TDFC_BASELINE FAIL normal suppression end did not start cooldown: -999999`，进程退出 1。新版对应断言位于 `tests/LogicTests.as`，正常结束必须记录结束帧并启动 300 帧冷却。
