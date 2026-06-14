# GDScript 模块代码规范

本文先约束当前 GDScript 协作方式。C++/GDExtension 后续单独出规范；在 C++ 接入前，各板块都按这里写 facade、信号和数据结构。

## 总原则

1. 一个模块只暴露一个清晰入口，内部节点和临时变量不让其他模块直接访问。
2. 模块之间用方法、信号、`Dictionary` snapshot 交互，不跨模块 `$SomeChild/DeepNode`。
3. `world.gd` 只做流程编排，不继续承载地图、UI、人物、交互、数值细节。
4. 新功能先写模块 API，再接主流程；不要先把逻辑塞进按钮回调或角色脚本里。
5. 资源路径、平衡数值、掉落表、地图候选点优先集中到数据文件或模块常量，不散落在多个脚本。

## 命名规范

- 文件名：小写蛇形，如 `map_runtime.gd`、`interaction_service.gd`。
- 场景名：模块名 + 类型，如 `KnightCharacter.tscn`、`AccessoryChoicePanel.tscn`。
- 普通变量/函数：小写蛇形，如 `current_room_index`、`activate_room()`。
- 信号：过去式或事件式，如 `character_selected`、`interaction_committed`。
- 常量：全大写蛇形，如 `MAX_FIRE_SEEDS`。
- `StringName` 状态值使用 `&"idle"`、`&"recover"` 这种形式。

## 文件结构顺序

推荐脚本按这个顺序写：

```gdscript
extends Node

signal changed(snapshot: Dictionary)

const CONFIG := {}

@export var enabled := true

@onready var child: Node = $Child

var runtime_state := {}

func _ready() -> void:
	pass

func public_api() -> void:
	pass

func _private_helper() -> void:
	pass
```

对外 API 放在私有 helper 前面，方便整合组快速看入口。

## 类型与返回值

- 公共方法必须标注参数和返回类型。
- 能用 `Node2D`、`CanvasLayer`、`Texture2D` 等明确类型时不要写成裸 `Node`。
- 模块 snapshot 用 `Dictionary`，字段名稳定，不随 UI 文案变化。
- 数值统一用 `float` 或 `int`，不要同一字段有时字符串有时数字。

示例：

```gdscript
func get_run_snapshot() -> Dictionary:
	return {
		"family_id": family_id,
		"fire_seed": fire_seed,
		"emperor_hp": emperor_hp
	}
```

## 信号规范

信号只传必要数据，不传整个模块内部节点。

推荐：

```gdscript
signal fire_seed_changed(current: int, max_value: int)
signal accessory_selected(payload: Dictionary)
```

不推荐：

```gdscript
signal ui_clicked(button_node)
```

原因是接收方会开始依赖 UI 内部结构，后面重构很痛。

## UI 负责人规范

UI 只展示状态和发出玩家选择，不直接改玩法数据。

每个 UI 面板建议提供：

```gdscript
signal confirmed(payload: Dictionary)
signal cancelled
signal closed

func open(payload: Dictionary = {}) -> void
func close() -> void
func refresh(snapshot: Dictionary) -> void
```

UI 不允许：

- 直接扣玩家金币。
- 直接给角色加血。
- 直接切换地图房间。
- 直接播放战斗阶段 BGM。

UI 可以：

- 显示金币、血量、火种、饰品、消耗品。
- 把玩家选择通过 signal 发给整合组。
- 做按钮、动画、提示和布局适配。

## 人物负责人规范

每个角色封装自己的素材、动画、碰撞、攻击、技能和冷却。整合组只调用角色 API。

人物至少提供：

```gdscript
signal defeated
signal health_changed(current: float, max_value: float)
signal defense_changed(current: float, max_value: float)
signal skill_cast(skill_id: StringName)

func setup_player_control(enabled: bool) -> void
func apply_run_effects(effects: Dictionary) -> void
func receive_hit(payload: Dictionary) -> void
func get_combat_snapshot() -> Dictionary
```

人物不允许：

- 直接访问 HUD。
- 直接创建地图物件。
- 直接推进关卡。
- 直接决定奖励。

## 敌人与 Boss 规范

敌人/Boss 对外统一是 damageable actor。

必须满足：

- 加入 `damageable` group。
- 能接收 `receive_hit(payload: Dictionary)`。
- 死亡时发 `defeated`。
- 子弹/近战效果自己管理，但不能直接改玩家 UI。

小怪资源要求：

- 身体贴图在 `actors/enemy/textures`。
- 武器贴图在 `art/final_materials/weapons`。
- 场景里可以有临时 `Weapon` 节点，但最终显示由脚本或 Sprite 资源统一维护。

## 地图负责人规范

地图模块只负责房间几何和相机，不负责战斗胜负。

当前入口是：

```gdscript
systems/map/map_runtime.gd
```

公开方法：

```gdscript
func setup(world_root: Node2D, spawn_marker: Marker2D, encounter_marker: Marker2D, rng: RandomNumberGenerator) -> void
func build() -> void
func activate_room(room_index: int, player_character: Node) -> void
func update_camera(room_index: int, player_character: Node, force: bool = false) -> void
func player_spawn_for_room(room_index: int) -> Vector2
func encounter_spawn_for_room(room_index: int) -> Vector2
```

地图不允许：

- 直接生成奖励。
- 直接改角色血量。
- 直接决定是否战斗结束。

地图必须保证：

- 房间左右入口/出口位置清楚。
- 相机只锁当前房间。
- 墙体碰撞只围不可走区域。
- 随机物件碰撞包住可见像素，能挡子弹/攻击。

## 交互负责人规范

交互模块负责“玩家按交互键时优先触发谁”。

推荐优先级：

1. 关键场景节点。
2. 饰品或特殊掉落。
3. 商店。
4. 消耗品拾取。
5. 环境提示。

推荐 API：

```gdscript
signal interaction_available(target: Dictionary)
signal interaction_committed(result: Dictionary)
signal interaction_cancelled

func register_target(target: Node, data: Dictionary) -> void
func unregister_target(target: Node) -> void
func get_best_target(actor: Node2D) -> Dictionary
func request_interact(actor: Node2D) -> void
func confirm(payload: Dictionary = {}) -> void
func cancel() -> void
```

## 轮回/火种负责人规范

血缘火种和皇帝持久 HP 是 run state，不属于 UI，也不属于角色。

推荐 API：

```gdscript
signal fire_seed_changed(current: int, max_value: int)
signal emperor_hp_changed(current: float, max_value: float)
signal generation_started(snapshot: Dictionary)
signal grand_run_failed(reason: StringName)

func start_grand_run(family_id: StringName) -> void
func start_generation() -> Dictionary
func record_generation_death(snapshot: Dictionary) -> bool
func record_emperor_damage(amount: float) -> void
func get_run_snapshot() -> Dictionary
```

逻辑要求：

- 初始火种为 `5`。
- 每次死亡消耗 `1`。
- 火种耗尽且皇帝未死，大轮回失败。
- 同一大轮回内皇帝 HP 不回复。

## 整合负责人规范

整合组负责连线，不负责替其他组实现内部细节。

整合组可以改：

- `world.gd`
- 模块 facade 的连接逻辑
- 流程顺序
- smoke 测试

整合组不应该改：

- 人物内部动画节点。
- UI 内部按钮布局。
- 地图碰撞细节。
- C++ 内部算法。

如果主流程需要新能力，先写成明确需求：

```text
人物模块需要新增 get_combat_snapshot() 字段 "active_skill_cooldowns"。
地图模块需要新增 get_room_exit_position(room_index)。
UI 模块需要新增 refresh_bloodline(snapshot)。
```

## 提交前检查

每次提交至少跑：

```powershell
F:\无尽王国\infinity_kingdom\infinity_kingdom\_tools\godot_4_6_3\Godot_v4.6.3-stable_win64_console.exe --path F:\无尽王国\infinity_kingdom\infinity_kingdom\infinity_kingdom --headless --quit
F:\无尽王国\infinity_kingdom\infinity_kingdom\_tools\godot_4_6_3\Godot_v4.6.3-stable_win64_console.exe --path F:\无尽王国\infinity_kingdom\infinity_kingdom\infinity_kingdom --headless --script res://tests/smoke_run_flow.gd
F:\无尽王国\infinity_kingdom\infinity_kingdom\_tools\godot_4_6_3\Godot_v4.6.3-stable_win64_console.exe --path F:\无尽王国\infinity_kingdom\infinity_kingdom\infinity_kingdom --headless --script res://tests/smoke_player_control.gd
```

如果没跑，提交说明里必须写清楚原因。
