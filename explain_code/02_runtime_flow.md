# 运行流程解读

## 标题到开局

`app_entry.gd` 是标题入口控制器。它持有 `CharacterSelect`、`PlayModeSelect`、`SettingsPanel`，并动态创建：

- `SaveSlotSelect`：选择已有存档或新建槽。
- `OpeningPrologue`：新档开场序章。
- `CheatNotice`：作弊模式提示。

输入：

- 标题 UI 信号：`character_selected`、`new_game_requested`、`settings_requested`、`quit_requested`。
- 存档 UI 信号：`slot_selected`、`new_slot_requested`。
- 按键输入：标题页作弊序列。

输出：

- 调 `SaveManager.create_slot()` / `SaveManager.select_slot()`。
- 调 `StartupContext.set_pending_start()`。
- `get_tree().change_scene_to_file("res://world.tscn")` 或 debug world。

## World 初始化

`world.gd._ready()` 做的事情非常多，是第一接手点：

- 构建运行时地图 `MapRuntime`。
- 构建门过渡遮罩。
- 动态挂载 `InventoryPanel`、`ConsumableBar`、`StageRewardPanel`、`LineageHUD`、`HeirSelectPanel`。
- 连接 `character_select`、`accessory_choice`、`run_event_panel`、`stage_reward_panel`、`pause_menu`、`result_screen`、`settings_panel` 等信号。
- 监听 `SceneTree.node_added`，给后续动态出现的敌人绑定音效和世界血条。
- 调 `RunDirector.configure_event_count()`。
- 消费 `StartupContext`，进入角色选择后的开局流程。

## 开局实例化玩家

`world._on_character_selected(character_id)`：

- 清标题音乐和自动行走状态。
- 重置 Manager：饰品、消耗品、单局、结局。
- 根据存档决定 `LineageDirector.begin_new_lineage()`、`start_or_resume_from_slot()` 或 `begin_reincarnation_family()`。
- 关闭/重置库存和消耗品 UI。
- 根据 `character_id` 实例化 `KNIGHT_SCENE / RANGER_SCENE / MAGE_SCENE`。
- 应用血脉资质 `LineageDirector.apply_aptitude_to_actor()`。
- 应用局内 modifier 和饰品。
- 绑定 HUD、角色死亡信号、战斗音效。
- 切第一张地图房间，开始 encounter。

## Encounter 推进

关键函数：

- `_start_next_encounter()`：进入下一个 index。
- `_enter_encounter_index(next_index)`：消费下一场准备效果、判断是否胜利、切房间。
- `_begin_current_encounter()`：实例化 encounter scene，应用临时准备效果，bind player，连接 defeated。
- `_next_encounter_index()`：功能房 4/5/6 会汇合到 7。

输入：

- 当前 `encounter_index`。
- `RunDirector.pending_encounter_prep`。
- 地图房间选择。

输出：

- 实例化 encounter。
- 给 player 应用临时效果。
- 刷新 battle status。
- 绑定敌人血条和音频。

## Encounter 结束

`world._on_encounter_defeated()`：

- 清敌方投射物。
- 如果 encounter 标记 `skip_rewards`，说明是空房/功能房占位，直接进入功能事件或下一房间。
- 普通战斗会调用 `RunDirector.reward_encounter()` 给金币。
- 若本场有 prep 的 `reward_bonus`，额外发金币。
- 若 prep 有 `clear_shield_on_end`，战后清盾。
- 后续根据位置决定：
  - 打开功能房事件。
  - 打开 stage reward。
  - 打开 run event。
  - 打开饰品选择。
  - 进入下一 encounter。

## 奖励与事件

`RunDirector` 维护事件牌堆和局内数值。`RunEffects` 是具体事件效果表。

典型选择：

- 商店/训练/休息/锻造/契约/共鸣/侦查。
- 直接回血、恢复护甲、恢复灵感。
- 改 `RunDirector.run_modifiers`。
- 给下一场写 `pending_encounter_prep`。
- 触发饰品选择。

`StageRewardPanel` 发的是关间奖励：

- 状态奖励：通常是一场临时效果。
- 消耗品奖励：进入 `ConsumableManager` 的 6 格背包。

## 地图和功能房

`systems/map/map_runtime.gd` 根据 `tools/map_browser_demo.gd` 的房间路径、可走区域、墙体、随机装饰数据，在运行时生成横向房间地图。

功能房特殊点：

- 房间 4/5/6 共用一个分支槽。
- 玩家在第 4 个来源房间门口根据 y 位置选择教堂/军需库/商店。
- `MapRuntime.select_function_room()` 只加载被选中的功能房视觉和碰撞。
- 世界流程从 4/5/6 汇合到 encounter 7。

## 死亡与复活

`world._on_player_died()`：

- 清当前 encounter。
- 构造 death summary。
- 调 `LineageDirector.consume_death()`。
- 如果还有 `seeds_left`，显示下一代结果，并等待 `HeirSelectPanel` 做一次资质点调整。
- `_respawn_lineage_heir()` 会重新创建当前家族角色并从 checkpoint 继续。
- 如果没有火种，存档封存。

## 胜利与结局

`world._complete_run_victory()`：

- 标记最终 Boss 击败。
- 根据 `EndingDirector` 和血脉状态判断结局类型。
- 普通胜利会 `LineageDirector.complete_reincarnation()`，当前家族加入 crowned，下一轮皇帝家族更新。
- 最终结局会 `SaveManager.seal_active_ending()`，封存 archive。
- 打开 `ResultScreen`。

