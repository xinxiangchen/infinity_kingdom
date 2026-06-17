# 后续重构抓手

## 最高优先级拆分点

`world.gd` 现在承担了太多职责：

- encounter 流程。
- 地图房间切换。
- UI 面板协调。
- 奖励掉落。
- 事件选择。
- 死亡/血脉/结局。
- 音频和血条绑定。

建议下次先按职责拆成：

- `RunFlowController`：encounter index、开始/结束、胜利/死亡。
- `RewardController`：金币、经验、pickup、stage reward。
- `RoomFlowController`：地图房间、功能房分支、门过渡。
- `UiFlowController`：打开/关闭面板和暂停返回。
- `ActorBindingService`：音频、血条、敌人 defeated 聚合。

## 最适合抽接口的隐式约定

现在大量代码靠 `has_method()`、`get_property_list()` 和字符串字段连接。可以先明确这些接口：

- `Damageable`：`receive_hit(payload)`。
- `Controllable`：`apply_control_effects(payload)`、`clear_control_effects()`。
- `CombatActor`：`hp/max_hp/defense/max_defense/shield`、`died/took_damage`。
- `PlayerActor`：`inspiration/max_inspiration/cooldowns/get_character_name/emit_stat_signals`。
- `Encounter`：`bind_player(player)`、`defeated`、`get_status_title()`、`get_status_text()`。
- `RunPanel`：`open()`、`close()`、选择信号。

## 最值得数据化的区域

- 玩家技能导出字段和升级定义。
- Boss 技能参数与状态转移。
- 普通敌人 `EnemyType` 行为参数。
- `RunEffects` 事件选择效果。
- `AccessoryManager` fallback 饰品和本地化。
- `world.gd` 中 encounter 路线、功能房映射、最终 Boss 映射。

## 高风险点

- `world.gd` 中大量状态 flag：`waiting_for_accessory_choice`、`active_run_event_kind`、`active_encounter_prep`、`pending_stage_reward_next_encounter_index`、`function_room_choice_pending`。
- 玩家三职业有大量重复代码，但技能差异混在同一主脚本里，直接合并容易破坏行为。
- Boss 没有共同父类，状态名和字段相似但不完全一致。
- `SaveManager` 是固定 offset 二进制布局，改字段必须同步 offset、record size 和测试。
- UI 文本存在乱码，逻辑和测试更多依赖节点/信号/状态，不要用乱码文本判断真实需求。
- Manager 修改角色字段时大量使用字符串字段名，字段重命名会连锁破坏饰品、事件、消耗品、血脉加成、HUD。

## 不要优先碰的区域

- `thirdparty/` 和 `src/`：这次交接范围不含 C++。
- `.godot/`：编辑器缓存。
- `.import` 文件：资源导入产物。
- 生成预览图片：除非任务是视觉资源。

