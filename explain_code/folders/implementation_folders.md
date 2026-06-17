# 实现代码文件夹解读

## 根目录实现文件

`app_entry.gd`：

- 职责：标题入口、存档槽、新档序章、模式选择、设置面板、作弊提示。
- 输入：标题 UI 信号、存档 UI 信号、键盘作弊序列。
- 输出：选择/创建存档，写 `StartupContext`，切换到 `world.tscn` 或 debug world。

`world.gd`：

- 职责：局内总控。负责玩家生成、地图房间、encounter 推进、奖励、死亡、胜利、UI 面板、音频绑定、掉落。
- 输入：StartupContext、UI 信号、encounter defeated、player died、pickup collected。
- 输出：实例化/销毁玩家和 encounter，修改 Manager 状态，打开 UI，写存档，播放音频。
- 风险：文件巨大，职责混合了流程、奖励、地图、UI、结局、掉落。下次重构最应该先拆。

## `systems/`

`systems/run/`：

- `run_director.gd`：单局状态、事件牌堆、金币、经验、击杀、局内 modifier、下一场 prep。
- `run_effects.gd`：事件选择效果表，静态函数修改玩家或 `RunDirector`。
- `save_manager.gd`：固定二进制存档槽，字段 offset 全在文件顶部。
- `lineage_director.gd`：血脉轮回、死亡评分、资质生成、火种、家族禁用、通关后皇帝轮替。
- `ending_director.gd`：结局条件记录。
- `cheat_mode.gd`：标题作弊序列和无限 HP 标记。
- `startup_context.gd`：跨场景传递启动模式、角色、槽位。
- `audio_route.gd`：encounter index 到音乐 profile 的映射。

`systems/accessories/`：

- `accessory_manager.gd`：饰品目录加载、fallback 饰品、稀有度权重、三选一生成、标签契合度、装备、属性应用、命中触发。
- `accessories.json`：外部饰品数据源。

`systems/consumables/`：

- `consumable_manager.gd`：6 格背包，消耗品目录，使用逻辑，部分消耗品写入下一场 prep。

`systems/map/`：

- `map_runtime.gd`：运行时生成地图房间、墙体、门、功能房分支、随机装饰碰撞、相机约束。

`systems/pickups/`：

- `run_pickup.gd`：世界掉落物，靠近玩家后吸附，发 `collected(kind, amount, world_position)`。

`systems/ui/`：

- `ui_settings.gd`：语言等 UI 设置。
- `ui_text.gd`：多语言文本表。

`systems/feedback/`：

- `feedback_manager.gd`：轻量反馈入口。

## `characters/`

三职业结构相同：主脚本 + `state_machine.gd` + 一组 state 脚本。

- `state_machine.gd`：收集子 state，按 priority 转移，支持强制切换和 hit interrupt。
- `states/*.gd`：状态薄封装，调用 owner_actor 的实际行为。

`characters/knight/knight.gd`：

- 定位：高 HP/高护甲近战。
- 技能：蓄力冲锋斩、震地反击、圣所领域。
- 特色：护盾、破甲、击飞、减伤、攻速/移速/伤害 buff。

`characters/ranger/ranger.gd`：

- 定位：高机动/高暴击。
- 技能：穿透箭、影步、刺杀突袭。
- 特色：隐身/不可被检测、残影、流血、处决、标记回血和攻速。

`characters/mage/mage.gd`：

- 定位：高灵感/法术控制。
- 技能：奥术飞刃、奥术爆裂、沉默诏令。
- 特色：环绕刀刃、范围爆炸、连锁爆炸、沉默/减速/定身。

## `combat/`

- `health_component.gd`：伤害核心。负责 HP、护甲、护盾、护甲恢复、治疗、易伤、死亡信号。
- `dodge_state.gd`：闪避状态辅助。
- `melee_utils.gd`：近战角度/范围计算工具。
- `runtime_texture_loader.gd`：运行时加载贴图，供角色/Boss/地图使用。

## `effects/`

- `damage_number.gd`：世界伤害数字。
- `projectiles/arcane_bolt.gd`：玩家/法师类奥术弹，可携带额外 payload。
- `projectiles/enemy_bolt.gd`：敌方弹体，可换色和速度。
- `projectiles/piercing_arrow.gd`：游侠穿透箭。
- `projectiles/royal_bolt.gd`：Boss/皇室弹体。

投射物共同逻辑：

- `setup(owner, direction, damage, ...)`。
- `_physics_process()` 移动和寿命。
- body/area 命中后解析真正 damage target。
- 调 `receive_hit(payload)`。
- 遇 `projectile_blocker` 阻挡。

## `actors/`

`actors/enemy/`：

- `town_enemy.gd`：普通敌人统一实现。枚举包含 swordsman、shield、archer、hunter、apprentice mage、arcanist。
- `swordsman_enemy.gd`：旧/简化剑士敌人。
- 各 `.tscn` 通过导出字段配置不同 enemy type。

`actors/encounters/`：

- `town_mob_encounter.gd`：波次池、最终波、modifier、刷怪点安全检查、敌人死亡聚合。
- `empty_encounter.gd`：空房/功能房占位，通常用于跳过战斗奖励。

`actors/bosses/town/`：

- `ranger_boss.gd`：游侠 Boss，穿透箭、影步、刺杀、流血/处决。
- `mage_boss.gd`：法师 Boss，飞刃、爆裂、控制。
- `judicator_boss.gd`：审判者 Boss，跳劈、直线斩、弹幕，低血狂暴。
- `emperor_boss.gd`：皇帝 Boss，二阶段、影步、冲锋、爆裂、齐射。
- `twin_princes_boss.gd`：双王子 Boss，半血换相、传送、直线斩、弹幕、冲刺失误自眩。
- `royal_guard_formation.gd` / `guard_unit.gd`：守卫阵型和守卫单位。

## `ui/`

UI 多数动态构建。主要输入是 Manager 信号、玩家信号、按钮事件；输出是 UI 信号给 `world.gd`。

- `character_select.gd`：标题菜单、角色选择、图鉴、关于页。
- `save_slot_select.gd`：槽位选择、新建、删除。
- `play_mode_select.gd`：普通/debug 选择。
- `knight_hud.gd`：角色 HUD，实际可绑定三职业。
- `battle_status.gd`：目标/威胁/路线/金币状态。
- `run_event_panel.gd`：事件选择卡。
- `accessory_choice.gd`：饰品选择、保留当前、重掷。
- `stage_reward_panel.gd`：关间奖励。
- `inventory_panel.gd`：局内详情、背包、饰品历史。
- `consumable_bar.gd`：数字槽消耗品。
- `lineage_hud.gd`：血脉状态。
- `heir_select_panel.gd`：死亡后继承者资质调整。
- `result_screen.gd`：死亡/胜利结算。
- `pause_menu.gd`、`settings_panel.gd`、`audio_settings_panel.gd`：暂停、设置、音频。
- `ui_skin.gd`、`ui_card_fx.gd`：UI 样式和卡片动效工具。

## `audio/`

- `music_manager.gd`：音乐 profile、淡入淡出、音量设置。
- `sfx_manager.gd`：UI、攻击、受击、死亡等音效反馈。
- `audio/tools/*.py`：占位音频生成工具，不是运行时核心。

## `tools/`

- `character_debug_world.gd`：debug 模式角色测试世界。
- `map_browser_demo.gd`：地图浏览和地图数据源，`MapRuntime` 依赖它的房间路径、墙体、可走区、prop 生成逻辑。
- `boss_preview_capture.gd`、`capture_map_prop_preview.gd`：预览截图工具。

## `tests/`

测试都是 Godot 脚本 smoke tests，给下个 Codex 的价值很高。详见 `explain_code/tests_and_specs.md`。

