# 非 C++ 实现代码清单

范围：项目自己的 `.gd` 实现代码。排除 `.godot/`、`.git/`、`thirdparty/`、`src/*.cpp`、`src/*.h`。

## 根入口

- `app_entry.gd`：标题入口、存档槽、序章、模式选择。
- `world.gd`：局内总控。

## 系统脚本

- `systems/accessories/accessory_manager.gd`
- `systems/consumables/consumable_manager.gd`
- `systems/feedback/feedback_manager.gd`
- `systems/map/map_runtime.gd`
- `systems/pickups/run_pickup.gd`
- `systems/run/audio_route.gd`
- `systems/run/cheat_mode.gd`
- `systems/run/ending_director.gd`
- `systems/run/lineage_director.gd`
- `systems/run/run_director.gd`
- `systems/run/run_effects.gd`
- `systems/run/save_manager.gd`
- `systems/run/startup_context.gd`
- `systems/ui/ui_settings.gd`
- `systems/ui/ui_text.gd`

## 战斗公共脚本

- `combat/dodge_state.gd`
- `combat/health_component.gd`
- `combat/melee_utils.gd`
- `combat/runtime_texture_loader.gd`

## 玩家角色

- `characters/knight/knight.gd`
- `characters/knight/state_machine.gd`
- `characters/knight/states/attack_state.gd`
- `characters/knight/states/buff_state.gd`
- `characters/knight/states/charge_state.gd`
- `characters/knight/states/dash_state.gd`
- `characters/knight/states/dead_state.gd`
- `characters/knight/states/guard_state.gd`
- `characters/knight/states/hit_state.gd`
- `characters/knight/states/idle_state.gd`
- `characters/knight/states/move_state.gd`
- `characters/knight/states/skill_state.gd`
- `characters/mage/mage.gd`
- `characters/mage/state_machine.gd`
- `characters/mage/states/attack_state.gd`
- `characters/mage/states/dead_state.gd`
- `characters/mage/states/hit_state.gd`
- `characters/mage/states/idle_state.gd`
- `characters/mage/states/move_state.gd`
- `characters/mage/states/skill_state.gd`
- `characters/ranger/ranger.gd`
- `characters/ranger/state_machine.gd`
- `characters/ranger/states/attack_state.gd`
- `characters/ranger/states/dash_state.gd`
- `characters/ranger/states/dead_state.gd`
- `characters/ranger/states/hit_state.gd`
- `characters/ranger/states/idle_state.gd`
- `characters/ranger/states/move_state.gd`
- `characters/ranger/states/skill_state.gd`

## 敌人与 Encounter

- `actors/training_dummy.gd`
- `actors/enemy/swordsman_enemy.gd`
- `actors/enemy/town_enemy.gd`
- `actors/encounters/empty_encounter.gd`
- `actors/encounters/town_mob_encounter.gd`
- `actors/bosses/town/emperor_boss.gd`
- `actors/bosses/town/judicator_boss.gd`
- `actors/bosses/town/mage_boss.gd`
- `actors/bosses/town/ranger_boss.gd`
- `actors/bosses/town/twin_princes_boss.gd`

## 效果与投射物

- `effects/damage_number.gd`
- `effects/projectiles/arcane_bolt.gd`
- `effects/projectiles/enemy_bolt.gd`
- `effects/projectiles/piercing_arrow.gd`
- `effects/projectiles/royal_bolt.gd`

## UI

- `ui/accessory_choice.gd`
- `ui/audio_settings_panel.gd`
- `ui/audio_shortcut_hint.gd`
- `ui/battle_status.gd`
- `ui/character_debug_status.gd`
- `ui/character_select.gd`
- `ui/consumable_bar.gd`
- `ui/cooldown_skill_icon.gd`
- `ui/debug_enemy_select.gd`
- `ui/debug_panel.gd`
- `ui/heir_select_panel.gd`
- `ui/hud_meter_bar.gd`
- `ui/inventory_panel.gd`
- `ui/knight_hud.gd`
- `ui/lineage_hud.gd`
- `ui/opening_prologue.gd`
- `ui/pause_menu.gd`
- `ui/play_mode_select.gd`
- `ui/result_screen.gd`
- `ui/run_event_panel.gd`
- `ui/save_slot_select.gd`
- `ui/settings_panel.gd`
- `ui/stage_reward_panel.gd`
- `ui/ui_card_fx.gd`
- `ui/ui_skin.gd`
- `ui/world_health_bar.gd`

## 音频运行时

- `audio/music_manager.gd`
- `audio/sfx_manager.gd`

## 测试脚本

- `tests/capture_ui_layouts.gd`
- `tests/smoke_accessory_catalog.gd`
- `tests/smoke_accessory_flow.gd`
- `tests/smoke_boss_visuals.gd`
- `tests/smoke_cheat_entry_input.gd`
- `tests/smoke_function_room_flow.gd`
- `tests/smoke_lineage_save.gd`
- `tests/smoke_locale_zh_hans.gd`
- `tests/smoke_map_random_props.gd`
- `tests/smoke_player_control.gd`
- `tests/smoke_run_effects.gd`
- `tests/smoke_run_flow.gd`
- `tests/smoke_story_endings.gd`
- `tests/smoke_ui_screens.gd`

## 工具脚本

- `tools/boss_preview_capture.gd`
- `tools/capture_map_prop_preview.gd`
- `tools/character_debug_world.gd`
- `tools/map_browser_demo.gd`

## Python 工具

这些不是运行时核心，但属于项目自有工具：

- `audio/tools/generate_placeholder_ambience.py`
- `audio/tools/generate_placeholder_bgm.py`
- `audio/tools/generate_placeholder_sfx.py`
- `tools/extract_map_props.py`

