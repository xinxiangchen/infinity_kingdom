# 模块负责人协作与 C++ GDExtension 接入说明

本文给 UI、人物、地图、交互/玩法、整合、C++ GDExtension 几个负责人对齐使用。目标是让每个模块“自己封装自己”，主程序只通过公开 API 和信号交互，后续加入血缘火种与 C++ 重构时不需要重写整条主流程。

参考策划案：`C:\Users\15312\Desktop\infinity_kingdom\specdocs\轮回王国_融合精简策划案.md`

## 一句话目标

`world.gd` 只做流程编排：选人、进房间、开战、结算、进下一房间。人物、地图、UI、交互、音频、数值/轮回系统都通过 facade 脚本暴露接口，不能互相直接钻进内部节点改状态。

## 当前拆分现状

| 模块 | 当前入口 | 负责人应该维护 | 主程序允许调用 |
| --- | --- | --- | --- |
| 主流程/整合 | `world.gd` | 路线推进、战斗开始/结束、奖励/事件入口、模块连接 | 各模块公开 API 和信号 |
| 人物 | `characters/*/*.tscn`、`characters/*/*.gd` | 移动、攻击、技能、动画、生命/防御组件、人物素材 | `setup_player_control()`、`apply_run_effects()`、生命/攻击信号 |
| 敌人与 Boss | `actors/enemy`、`actors/bosses`、`actors/encounters` | 小兵/Boss 行为、刷怪组合、子弹与受击 | encounter 的 `started/completed/failed` 信号 |
| 地图 | `systems/map/map_runtime.gd`、`tools/map_browser_demo.gd`、`assets/maps` | 房间拼接、墙体碰撞、物件碰撞、相机锁房间、出生点/战斗点 | `activate_room()`、`player_spawn_for_room()`、`encounter_spawn_for_room()`、`update_camera()` |
| UI | `ui/*`、各 CanvasLayer 场景 | HUD、选择界面、暂停、设置、奖励、事件、结算 | `show/open/close/bind/update` 类方法，外加信号 |
| 交互/玩法系统 | `systems/run`、`systems/pickups` | 饰品、事件、拾取、商店/教堂/军械库、未来血缘火种 | 统一请求/确认/取消 API |
| 音频 | `audio/music_manager.gd`、`systems/run/audio_route.gd` | BGM 资源、阶段 profile、混音设置 | `play_profile(profile_id)` 或 `AudioRoute` |

## 模块边界规则

1. 人物脚本不能直接访问 HUD、地图、`world.gd` 的子节点。人物只发信号，或暴露查询/设置方法。
2. UI 不能直接修改人物、地图、Boss 血量和奖励数据。UI 只展示数据，并通过信号发出玩家选择。
3. 地图模块不能知道角色职业、技能、奖励逻辑。它只负责房间几何、碰撞、相机、出生点和战斗点。
4. 交互模块不能控制 UI 布局。它只产出“当前可交互对象、交互结果、奖励/消耗数据”。
5. 整合组不能直接改人物内部节点名来完成需求，必须要求人物组补公开 API。
6. 后续 C++ 只迁纯逻辑和数据计算，不迁 UI 场景、不迁素材节点树。

## 人物模块 API

详细人物规范见 `docs/CHARACTER_MODULE_API.md`。角色组后续重构时至少保证这些能力：

```gdscript
signal defeated
signal health_changed(current: float, max_value: float)
signal defense_changed(current: float, max_value: float)
signal attack_performed
signal skill_cast(skill_id: StringName)

func setup_player_control(enabled: bool) -> void
func apply_run_effects(effects: Dictionary) -> void
func receive_damage(amount: float, source: Node = null) -> void
func heal(amount: float) -> void
func get_combat_snapshot() -> Dictionary
```

人物组需要把“素材图、动画、碰撞体、攻击判定、技能冷却”封装在角色场景里。整合组只关心角色能不能移动、能不能攻击、当前血量是多少、角色死亡信号有没有发出。

角色资产建议结构：

```text
characters/
  knight/
    knight.tscn
    knight.gd
    textures/
    animations/
  ranger/
  mage/
```

## 地图模块 API

当前主程序已接入 `systems/map/map_runtime.gd`。地图负责人维护地图数据和碰撞，不需要去改 `world.gd` 的主流程。

```gdscript
func setup(world_root: Node2D, spawn_marker: Marker2D, encounter_marker: Marker2D, rng: RandomNumberGenerator) -> void
func build() -> void
func activate_room(room_index: int, player_character: Node) -> void
func update_camera(room_index: int, player_character: Node, force: bool = false) -> void
func player_spawn_for_room(room_index: int) -> Vector2
func encounter_spawn_for_room(room_index: int) -> Vector2
```

地图数据暂时集中在 `tools/map_browser_demo.gd`：

- `ROOM_PATHS`：每张房间图。
- `ROOM_WALL_COLLISIONS`：只围墙体/不可走边界的碰撞框。
- `ROOM_PROP_LAYER_PATHS`：每张房间对应的小物件图层。
- `PROP_CANDIDATES`：可随机生成的掩体物件候选。
- `calculate_prop_collision_rect()`：按素材 alpha 的最高、最低、最左、最右有效像素生成物件碰撞框。

后续建议把这些常量迁到 `data/maps/*.tres` 或 JSON，避免工具脚本和主程序共享同一个大常量文件。

## UI 模块 API

UI 负责人维护界面，不直接改玩法状态。推荐每个 UI 场景只保留以下形式：

```gdscript
signal confirmed(payload: Dictionary)
signal cancelled
signal closed

func bind_context(context: Dictionary) -> void
func open(payload: Dictionary = {}) -> void
func close() -> void
func refresh(snapshot: Dictionary) -> void
```

HUD 需要覆盖策划案里的 MVP 信息：

- 玩家生命、防御/护盾。
- 当前家族/职业/角色名。
- 血缘火种剩余数量。
- 主动技能冷却。
- 消耗品槽位和数量。
- 饰品图标/简短状态。
- 金币。
- 皇帝战显示皇帝剩余 HP 和本轮已累积伤害。

## 交互模块 API

交互系统负责“当前按交互键应该触发什么”。策划案要求交互优先级为：

1. 固定关键节点：教堂、军械库、祭坛、皇帝战前准备。
2. 饰品或特殊掉落。
3. 商店。
4. 消耗品拾取。
5. 环境提示。

推荐新增 facade：`systems/interaction/interaction_service.gd`

```gdscript
signal interaction_available(target: Dictionary)
signal interaction_cleared
signal interaction_committed(result: Dictionary)
signal interaction_cancelled

func register_target(target: Node, data: Dictionary) -> void
func unregister_target(target: Node) -> void
func get_best_target(actor: Node2D) -> Dictionary
func request_interact(actor: Node2D) -> void
func confirm(payload: Dictionary = {}) -> void
func cancel() -> void
```

交互目标数据建议：

```gdscript
{
	"id": "church_heal_01",
	"type": "church|armory|altar|shop|pickup|environment",
	"priority": 100,
	"prompt": "Pray",
	"cost": {"gold": 20},
	"effect": "scene_interaction_effect",
	"payload": {}
}
```

## 血缘火种与轮回 API

策划案核心约束：

- 大轮回开始时血缘火种为 `5`。
- 每次角色死亡消耗 `1` 个火种。
- 火种耗尽且皇帝未死，则本次大轮回失败。
- 同一个大轮回内，皇帝 HP 持久，不随玩家死亡回复。
- MVP 只持久化皇帝 HP，不持久化阶段临时状态。
- 家族等于职业：Knight、Ranger、Mage；同一大轮回不跨家族继承。

推荐新增 facade：`systems/run/bloodline_run_state.gd`

```gdscript
signal fire_seed_changed(current: int, max_value: int)
signal emperor_hp_changed(current: float, max_value: float)
signal generation_started(snapshot: Dictionary)
signal grand_run_failed(reason: StringName)
signal grand_run_completed

func start_grand_run(family_id: StringName) -> void
func start_generation() -> Dictionary
func record_generation_death(snapshot: Dictionary) -> bool
func record_emperor_damage(amount: float) -> void
func get_fire_seed_count() -> int
func get_emperor_remaining_hp() -> float
func get_run_snapshot() -> Dictionary
```

继承资质建议由纯逻辑函数生成，便于未来迁 C++：

```gdscript
func generate_child_aptitude(parent: Dictionary, run_progress: Dictionary, rng_seed: int) -> Dictionary
```

输出字段：

```gdscript
{
	"family_id": &"knight",
	"generation": 3,
	"fire_seed": 3,
	"strength": 5,
	"agility": 4,
	"focus": 3,
	"adjust_points": 1,
	"emperor_hp_remaining": 720.0
}
```

## 数据表建议

饰品、消耗品、场景节点不要散在脚本分支里。建议放到 `data/`：

```text
data/
  accessories/
  consumables/
  scene_nodes/
  balance/
```

效果字段统一命名：

- `passive_effect`
- `active_use_effect`
- `scene_interaction_effect`

触发器统一命名：

- `on_pick`
- `on_use`
- `on_hit`
- `on_crit`
- `on_kill`
- `on_low_hp`
- `on_enter_room`
- `on_first_hit`

## C++ GDExtension 接入操作

先不要把整个项目迁 C++。第一阶段只迁纯逻辑模块，GDScript 保留 Godot 场景 facade。

推荐目录：

```text
cpp/
  SConstruct
  src/
    register_types.cpp
    infinity_run_state.cpp
    infinity_run_state.h
    bloodline_system.cpp
    bloodline_system.h
    combat_formula.cpp
    combat_formula.h
  godot-cpp/
addons/
  infinity_core/
    infinity_core.gdextension
    bin/
```

一次性准备：

```powershell
cd F:\无尽王国\infinity_kingdom\infinity_kingdom\infinity_kingdom
git submodule add https://github.com/godotengine/godot-cpp.git cpp/godot-cpp
cd cpp\godot-cpp
scons platform=windows target=template_debug -j8
cd ..
scons platform=windows target=template_debug -j8
```

`.gdextension` 示例：

```ini
[configuration]
entry_symbol = "infinity_core_library_init"
compatibility_minimum = "4.4"
reloadable = true

[libraries]
windows.debug.x86_64 = "res://addons/infinity_core/bin/infinity_core.windows.template_debug.x86_64.dll"
windows.release.x86_64 = "res://addons/infinity_core/bin/infinity_core.windows.template_release.x86_64.dll"
```

优先迁移顺序：

1. `BloodlineSystem`：火种消耗、世代生成、皇帝 HP 持久化。
2. `CombatFormula`：属性到伤害/防御/暴击/冷却的公式。
3. `WeightedPicker`：奖励、事件、物件随机候选抽取。
4. 可选：AI 决策或地图碰撞候选生成。

暂时不要迁：

- UI 控件和 CanvasLayer。
- 角色素材节点树、AnimationPlayer、Sprite2D 结构。
- 地图图片拼接显示。
- 音频播放节点。

GDScript facade 调 C++ 的方式：

```gdscript
var core := InfinityRunState.new()
core.start_grand_run(&"knight")
core.record_emperor_damage(120.0)
var snapshot := core.get_run_snapshot()
```

## 协作流程

整合组：

- 只在 `world.gd` 和 facade 间连线。
- 发现需要人物/地图/UI 新能力时，提 API 需求，不直接改别人内部节点。
- 每次接入后跑 smoke 测试。

人物组：

- 每个角色一个独立场景，素材、动画、碰撞、攻击、技能都在场景内部。
- 对外只暴露人物 API 和信号。
- 不引用 HUD、地图、奖励、BGM。

地图组：

- 每张图维护墙体碰撞和物件候选。
- 房间左右入口/出口、相机锁房间、出生点/战斗点由地图模块给出。
- 新图先在地图 demo 里可视化验证，再接主流程。

UI 组：

- UI 只接 snapshot，不持有玩法真状态。
- 玩家选择通过 signal 发回整合组。
- 血缘火种、皇帝 HP、消耗品、饰品状态按 snapshot 刷新。

C++ 组：

- 先写纯逻辑类，保持可从 GDScript 创建和调用。
- 每迁一个逻辑模块，保留 GDScript facade 名称，避免主流程大改。
- C++ 类输出 Dictionary/Array/StringName 等 Godot 友好类型，方便 UI 和脚本消费。

## 最低测试要求

每次整合提交至少跑：

```powershell
F:\无尽王国\infinity_kingdom\infinity_kingdom\_tools\godot_4_6_3\Godot_v4.6.3-stable_win64_console.exe --path F:\无尽王国\infinity_kingdom\infinity_kingdom\infinity_kingdom --headless --quit
F:\无尽王国\infinity_kingdom\infinity_kingdom\_tools\godot_4_6_3\Godot_v4.6.3-stable_win64_console.exe --path F:\无尽王国\infinity_kingdom\infinity_kingdom\infinity_kingdom --headless --script res://tests/smoke_run_flow.gd
F:\无尽王国\infinity_kingdom\infinity_kingdom\_tools\godot_4_6_3\Godot_v4.6.3-stable_win64_console.exe --path F:\无尽王国\infinity_kingdom\infinity_kingdom\infinity_kingdom --headless --script res://tests/smoke_player_control.gd
```

模块负责人自测重点：

- 人物：能选中、能移动、能攻击、会死亡、信号正确。
- 地图：每房间碰撞只围不可走墙体；随机物件碰撞包住可见像素；相机只锁当前房间。
- UI：打开/关闭不阻塞主流程；选择信号只发一次；文字不溢出。
- 交互：同一位置多个对象时按优先级触发。
- 轮回：死亡消耗火种；火种为 0 且皇帝未死时失败；皇帝 HP 在同一大轮回内不回复。
