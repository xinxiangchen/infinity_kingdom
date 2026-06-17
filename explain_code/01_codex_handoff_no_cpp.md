# Codex 交接抓手：仅实现代码，不含 C++

本文档只基于项目自己的实现代码整理，重点是 GDScript、场景脚本绑定、运行时系统、测试与工具脚本。刻意不解释 `src/*.cpp`、`src/*.h`、`thirdparty/godot-cpp/`。

## 一句话架构

这是一个 Godot 动作 Roguelite 原型：`app_entry.gd` 负责标题、存档槽、开场序章和模式选择；`world.gd` 是局内总控；玩家、敌人、Boss 都是 Godot 节点脚本；局内数值与流程由一组 autoload Manager 维护；UI 通过信号和 Manager 状态刷新。

## 启动链路

1. `project.godot` 的主场景是 `res://app_entry.tscn`。
2. `app_entry.gd` 创建 `SaveSlotSelect`、`OpeningPrologue`、作弊提示，接收标题 UI 的角色选择与存档选择。
3. 普通模式调用 `StartupContext.set_pending_start("normal", character_id, slot_index)`，然后切到 `world.tscn`。
4. `world.gd` 在 `_ready()` 里构建地图、库存栏、消耗品栏、阶段奖励、血脉 HUD、继承者选择面板，并连接所有 UI 信号。
5. `world.gd._consume_startup_context()` 取出待启动数据，选择存档槽，然后走 `_on_character_selected()`。
6. `_on_character_selected()` 重置 `AccessoryManager / ConsumableManager / RunDirector / EndingDirector`，初始化或恢复 `LineageDirector`，实例化玩家，绑定 HUD，然后 `_start_next_encounter()`。

## Autoload 抓手

- `AccessoryManager`：饰品目录、三选一生成、装备饰品、应用属性、命中触发效果、战斗 payload 增强。
- `ConsumableManager`：6 格消耗品背包，使用后恢复 HP/护甲/灵感，或把下一场临时效果写进 `RunDirector.pending_encounter_prep`。
- `RunDirector`：单局状态，包括金币、已清 encounter、事件牌堆、奖励历史、经验等级、击杀数、局内 modifier。
- `SaveManager`：固定槽位二进制存档，路径 `user://ik_saves.dat`，每槽 512 字节，随机访问 patch 字段。
- `LineageDirector`：血脉/轮回/继承者逻辑，死亡评分、火种消耗、资质生成、家族禁用、通关后皇帝轮替。
- `EndingDirector`：结局条件记录，如最终 Boss、受伤、洗礼、开发者技能标记等。
- `CheatMode`：标题页按键序列开启无限 HP，`HealthComponent` 会检查玩家是否受保护。
- `Music` / `Sfx`：音频 profile、UI/战斗反馈。
- `UISettings` / `UIText`：语言、显示文本与 UI 设置。

## 核心数据流

伤害流：

```text
角色/Boss/投射物构造 Dictionary payload
  -> target.receive_hit(payload)
  -> HealthComponent.receive_hit(payload)
  -> 先扣 defense，再扣 shield，再扣 hp
  -> 发 damaged / defense_changed / shield_changed / died
  -> 角色或敌人同步 hp/defense/shield 字段，生成伤害数字
```

常见 payload 字段：

- `source`：攻击来源节点。
- `damage`：基础伤害。
- `crit_rate`：暴击率。
- `damage_multiplier` / `damage_multiplier_duration`：破甲易伤。
- `knock_up_duration`：击飞或控制提示。
- `silence_duration`：沉默。
- `slow_duration` / `slow_multiplier`：减速。
- `root_duration`：定身。

局内奖励流：

```text
encounter.defeated
  -> world._on_encounter_defeated()
  -> RunDirector.reward_encounter()
  -> 掉落 pickup / 打开 stage_reward_panel / 打开 run_event_panel / 打开 accessory_choice
  -> 玩家选择
  -> RunEffects 或 AccessoryManager 或 ConsumableManager 修改玩家/局内状态
  -> 进入下一 encounter
```

死亡与血脉流：

```text
player.died
  -> world._on_player_died()
  -> world._build_death_summary()
  -> LineageDirector.consume_death()
  -> 有火种：result_screen 显示下一代，heir_select_panel 调整资质后复活
  -> 无火种：SaveManager 标记 dead_archive，进入封存结局
```

胜利流：

```text
最后 encounter 结束
  -> world._complete_run_victory()
  -> EndingDirector.record_final_boss_defeated()
  -> 根据结局条件生成 ending_kind
  -> 普通胜利：LineageDirector.complete_reincarnation()
  -> 最终结局：SaveManager.seal_active_ending()
  -> result_screen 展示结算
```

## 最值得先读的文件

按接手收益排序：

1. `world.gd`：局内总控，所有系统都在这里汇合。
2. `project.godot`：autoload 和输入映射。
3. `app_entry.gd`：标题、存档、启动上下文。
4. `systems/run/run_director.gd`：单局状态和事件牌堆。
5. `systems/run/run_effects.gd`：事件选择如何改数值。
6. `systems/run/lineage_director.gd`：死亡、继承、轮回。
7. `systems/run/save_manager.gd`：存档布局。
8. `systems/accessories/accessory_manager.gd`：饰品、build 倾向、命中触发。
9. `characters/*/*.gd`：玩家三职业。
10. `actors/enemy/town_enemy.gd` 和 `actors/encounters/town_mob_encounter.gd`：普通敌人与波次。
11. `actors/bosses/town/*.gd`：Boss 独立状态机。
12. `ui/run_event_panel.gd`、`ui/accessory_choice.gd`、`ui/knight_hud.gd`、`ui/character_select.gd`：核心 UI。

## 下一个 Codex 动手建议

- 改流程先看 `world.gd`，再看对应 Manager。
- 改数值奖励先看 `RunEffects.apply_choice()` 和 `RunDirector.add_run_modifier()`。
- 改饰品先看 `systems/accessories/accessories.json` 和 `AccessoryManager._apply_effects()`。
- 改伤害先看 `HealthComponent.receive_hit()`，再看角色/Boss 的 `receive_hit()` 包装。
- 改玩家技能先在对应角色主脚本里找 `get_state_request()`、`prepare_skill_request()`、`start_skill()`、`finish_skill()`、`perform_*`。
- 改敌人 AI 先看 `town_enemy.gd` 的 `EnemyType` 分支；Boss 则各自维护字符串状态。
- 改 UI 不要只看 `.tscn`，很多 UI 是脚本动态创建的，入口函数通常是 `_build_ui()`、`open()`、`refresh()`。
- 乱码中文很多是编码损坏或历史文本问题，逻辑判断不要依赖这些字符串内容。

