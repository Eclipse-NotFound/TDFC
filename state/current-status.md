# TDFC 当前状态

- 更新：2026-08-17
- 版本：v0.1.0（Phase 1 信息层，已实测验证）

## 已完成

- [x] 头脑风暴定稿：`design/brainstorm-01-enemy-ai.md`（用户已确认：先做 Phase 1；士气保留后置；护栏表通过）
- [x] Phase 1 四个行为实现（`src/`，8 文件）
  - 目击传播（LOS→setCel 直接交战 / 听觉→alarma 模糊指路）
  - 枪声事件（半径随武器 noise；不做噪声放大，保留消音语义）
  - 受击传播（受害者传精确位置 + 战斗噪声脉冲）
  - 记忆搜索（lastSeen → 调查 → REACQ/RESUME/TIMEOUT 全链路）
- [x] 部署：pfe.swf loader 已合并（备份 `pfe_1.02_before_tdfc_merge_20260817.swf` 在游戏根目录）
- [x] 构建：`build/build.bat` + `build/tdfc-config.xml`
- [x] git 仓库：mods/TDFC（初始提交 424a812）

## 实机验证（2026-08-17，6 次会话）

日志：`AppData/Roaming/pfe/Local Store/tdfc.log`

全部通过：
- 目击传播：`prop vision LOS engage`（4 单位 1 帧内参战）+ `HEAR nudge`
- 受击传播：`damage hit->LOS engage` / `hit->HEAR nudge`
- 枪声：`gunshot fired r=500..3400`（武器噪声半径正确区分）
- 搜索：`search START at <lastSeen>` / `REACQ` / `RESUME` / `TIMEOUT`
- F9 测试生成：`spawn raider spawned ... weapon=true` ×4

## 遗留问题（待复现/决定）

1. **S1 异常**：某图 5 敌同房间、玩家开枪（噪声 680）但全程 engaged=0，无传播无交战。
   推测：距离过远或该图敌人类型不主动索敌（如列车炮）。需复现定位。
2. **UnitTrigger 被广播**：非战斗单位（trigger）收到 HEAR nudge。无实际影响，
   后续可在 isEnemy 增加"非战斗单位"过滤（如 currentWeapon==null 且非怪物类）。
3. **gg.noise 负值**（-10/-15）：非 TDFC 写入，疑似原版/其他模组行为。无害，留意即可。
4. **枪声日志量大**（80 行/次测试）：DIAG_CAP=300 够用，长会话可考虑仅记摘要。

## 下一步

- 处理遗留问题（复现 S1；isEnemy 过滤非战斗单位）
- Phase 2 设计启动：瞄准回避 + 慢弹回避 + 掩体评估 + 撤退协议（用户已确认 Phase 1 完成后进入）
- Phase 1 的传播机制参数平衡（SIGHT_RANGE/HEAR_RANGE/冷却）按实战反馈微调

## 关键技术结论（已回馈公共知识）

- 日志通道：`knowledge-validation/facts/mod-log-channel.md`
- 起疑通道唯一性：敌人 aiSpok 只能由 vanilla listen(玩家噪声) 抬升（internal 不可写），
  模组唤醒敌人的唯一杠杆是写 gg.noise（记录在 mod-log-channel.md 与本文档）
