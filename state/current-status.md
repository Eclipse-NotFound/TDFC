# TDFC 当前状态

- 更新：2026-08-18（v0.2.2）
- 版本：v0.2.2（Phase 2 生存层，含两轮实测修复）

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
- F9 测试生成：`spawn raider spawned ... weapon=true` ×4+

## 遗留问题（v0.1.1 已处理）

1. **S1 无交战异常 → 判定为设计内行为**：5 敌同房间但均无 LOS、且超出玩家噪声
   听觉半径（耳半径 = 噪声×ear×earMult，默认 earMult=1）。平静单位按原版语义
   无视位置提示（cel 每帧被原版重置）→ 枪声提示对平静单位本就无效，符合设计与
   原版机制。**为可诊断性，心跳已加 `hear`/`los` 交战潜力指标**（可听半径内/有视线
   的敌人数），S1 类情况可直接从 hb 行判读。
2. **UnitTrigger 等非战斗单位被广播 → 已过滤**：加入 `NON_COMBAT` 名单
   （UnitTrigger/UnitDamager/UnitTrap/UnitDestr/UnitMWall/Mine/UnitVortex，
   依据反编译核对均无战术行为；UnitTrain 等真战斗单位保留）。
3. **gg.noise 负值（-10/-15）→ 非 TDFC/原版写入**：UnitPlayer 不写 noise，
   原版仅有 `>0 守卫的 -=20` 与 makeNoise 取 max；负值必然来自其他模组（如
   Sandevistan 回放驱动）。对 listen 无影响（≤0 即静音），运动/开火会自愈，
   仅心跳可见 → 监控即可。
4. **枪声日志量大**：DIAG_CAP=300 够用，长会话可改为摘要。暂不做。

## 下一步

- **Phase 2 实测反馈（2026-08-18）已修复**：
  - v0.2.1：2D 躲避（cel 点 + Y 轴起跳）、威胁回避 cel 化 + PhisBullet 交还原版、
    声源位置冻结（防隔墙追踪）、撤退优先级提到掩体前
  - v0.2.2：瞄准回避重做——几何规则"平射起跳/斜射水平走位"（|sin(弹道角)|<0.5
    起跳）；取消冷却（常驻躲弹意识）；躲避窗口 24 tick 抵消原版方向延迟
  - 实机验证：掩体 PEEK/EXIT 已在用户会话中生效（UnitAlicorn）
- **待复测**：v0.2.2 的瞄准回避形态（平射跳/斜射横移）、无冷却的常驻躲避
- **候选机制 A-D 待用户选定**：视野锥（vAngle 维护）/ 目击确认 / 传播延迟 / 声音歧义
  （声音歧义的"位置冻结"部分已随 v0.2.1 落地）
- Phase 1 参数按实战反馈微调（SIGHT_RANGE/HEAR_RANGE/冷却）

## 关键技术结论（已回馈公共知识）

- 日志通道：`knowledge-validation/facts/mod-log-channel.md`
- 起疑通道唯一性：敌人 aiSpok 只能由 vanilla listen(玩家噪声) 抬升（internal 不可写），
  模组唤醒敌人的唯一杠杆是写 gg.noise（记录在 mod-log-channel.md 与本文档）
