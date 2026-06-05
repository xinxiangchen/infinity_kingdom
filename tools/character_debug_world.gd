extends Node2D

const KNIGHT_SCENE := preload("res://characters/knight/knight.tscn")
const RANGER_SCENE := preload("res://characters/ranger/ranger.tscn")
const MAGE_SCENE := preload("res://characters/mage/mage.tscn")
const TRAINING_DUMMY_SCENE := preload("res://actors/training_dummy.tscn")
const SWORDSMAN_SCENE := preload("res://actors/enemy/swordsman_enemy.tscn")
const SHIELD_SCENE := preload("res://actors/enemy/shield_enemy.tscn")
const ARCHER_SCENE := preload("res://actors/enemy/archer_enemy.tscn")
const HUNTER_SCENE := preload("res://actors/enemy/hunter_enemy.tscn")
const APPRENTICE_SCENE := preload("res://actors/enemy/apprentice_mage_enemy.tscn")
const ARCANIST_SCENE := preload("res://actors/enemy/arcanist_enemy.tscn")
const JUDICATOR_BOSS_SCENE := preload("res://actors/bosses/town/judicator_boss.tscn")
const TWIN_PRINCES_BOSS_SCENE := preload("res://actors/bosses/town/twin_princes_boss.tscn")
const RANGER_BOSS_SCENE := preload("res://actors/bosses/town/ranger_boss.tscn")
const MAGE_BOSS_SCENE := preload("res://actors/bosses/town/mage_boss.tscn")
const EMPEROR_BOSS_SCENE := preload("res://actors/bosses/town/emperor_boss.tscn")

const PLAYER_SCENES := {
	&"knight": KNIGHT_SCENE,
	&"ranger": RANGER_SCENE,
	&"mage": MAGE_SCENE
}
const ENEMY_SCENES := {
	&"dummy": TRAINING_DUMMY_SCENE,
	&"swordsman": SWORDSMAN_SCENE,
	&"shield": SHIELD_SCENE,
	&"archer": ARCHER_SCENE,
	&"hunter": HUNTER_SCENE,
	&"apprentice": APPRENTICE_SCENE,
	&"arcanist": ARCANIST_SCENE,
	&"judicator_boss": JUDICATOR_BOSS_SCENE,
	&"twin_princes_boss": TWIN_PRINCES_BOSS_SCENE,
	&"ranger_boss": RANGER_BOSS_SCENE,
	&"mage_boss": MAGE_BOSS_SCENE,
	&"emperor_boss": EMPEROR_BOSS_SCENE
}

@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var target_spawn: Marker2D = $DummySpawn
@onready var target_root: Node2D = $DummyRoot
@onready var character_select: CanvasLayer = $CharacterSelect
@onready var enemy_select: CanvasLayer = $DebugEnemySelect
@onready var debug_status: CanvasLayer = $CharacterDebugStatus
@onready var help_label: Label = $DebugOverlay/Panel/Margin/HelpLabel
@onready var camera: Camera2D = $Camera2D

var player_character: Node2D = null
var active_target: Node2D = null
var active_enemy_id: StringName = &"dummy"
var active_enemy_elite: bool = false


func _ready() -> void:
	if AccessoryManager != null:
		AccessoryManager.reset_run()
	if character_select != null:
		character_select.character_selected.connect(_on_character_selected)
		if character_select.has_signal("quit_requested"):
			character_select.quit_requested.connect(_on_quit_requested)
	if enemy_select != null:
		enemy_select.enemy_selected.connect(_on_enemy_selected)
		enemy_select.visible = false
	if debug_status != null:
		debug_status.visible = false
	_refresh_help_text()
	if Music != null:
		Music.play_profile(&"title", true)
	var startup := get_node_or_null("/root/StartupContext")
	if startup != null and startup.has_method("consume_pending_start"):
		var pending: Dictionary = startup.consume_pending_start()
		if StringName(pending.get("mode", &"")) == &"debug" and StringName(pending.get("character_id", &"")) != &"":
			call_deferred("_on_character_selected", StringName(pending["character_id"]))


func _process(_delta: float) -> void:
	_refresh_help_text()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_reset_debug_room()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			_return_to_character_select()
			get_viewport().set_input_as_handled()


func _on_character_selected(character_id: StringName) -> void:
	_spawn_player(character_id)
	if character_select != null:
		character_select.visible = false
	if enemy_select != null and enemy_select.has_method("open"):
		enemy_select.open()
	if debug_status != null and debug_status.has_method("bind_character"):
		debug_status.bind_character(player_character)
	_spawn_debug_target(active_enemy_id, active_enemy_elite)
	_refresh_help_text()


func _spawn_player(character_id: StringName) -> void:
	if player_character != null and is_instance_valid(player_character):
		player_character.queue_free()
	var scene: PackedScene = PLAYER_SCENES.get(character_id, KNIGHT_SCENE)
	player_character = scene.instantiate() as Node2D
	player_character.position = player_spawn.position
	player_character.z_index = 4
	add_child(player_character)
	if player_character.has_signal("died"):
		player_character.died.connect(_on_player_died)
	if camera != null:
		camera.global_position = Vector2(700.0, 420.0)


func _on_enemy_selected(enemy_id: StringName, elite: bool) -> void:
	active_enemy_id = enemy_id
	active_enemy_elite = elite and enemy_id != &"dummy"
	_spawn_debug_target(active_enemy_id, active_enemy_elite)


func _spawn_debug_target(enemy_id: StringName, elite: bool) -> void:
	if active_target != null and is_instance_valid(active_target):
		active_target.queue_free()
	active_target = null
	var scene: PackedScene = ENEMY_SCENES.get(enemy_id, TRAINING_DUMMY_SCENE)
	active_target = scene.instantiate() as Node2D
	active_target.position = target_spawn.position
	active_target.z_index = 3
	if active_target.get("elite") != null:
		active_target.set("elite", elite)
	target_root.add_child(active_target)
	if active_target.has_method("bind_player") and player_character != null:
		active_target.bind_player(player_character)
	if active_target.has_signal("defeated"):
		active_target.defeated.connect(_on_debug_target_defeated)


func _on_debug_target_defeated() -> void:
	active_target = null
	var timer := get_tree().create_timer(0.45)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self):
			_spawn_debug_target(active_enemy_id, active_enemy_elite)
	)


func _on_player_died() -> void:
	var timer := get_tree().create_timer(0.65)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self):
			_return_to_character_select()
	)


func _reset_debug_room() -> void:
	if player_character != null and is_instance_valid(player_character):
		player_character.global_position = player_spawn.global_position
		if player_character.has_method("emit_stat_signals"):
			player_character.emit_stat_signals()
	_spawn_debug_target(active_enemy_id, active_enemy_elite)


func _return_to_character_select() -> void:
	if player_character != null and is_instance_valid(player_character):
		player_character.queue_free()
	player_character = null
	if active_target != null and is_instance_valid(active_target):
		active_target.queue_free()
	active_target = null
	if enemy_select != null and enemy_select.has_method("close"):
		enemy_select.close()
	if debug_status != null and debug_status.has_method("clear"):
		debug_status.clear()
	if character_select != null:
		character_select.visible = true
	_refresh_help_text()


func _on_quit_requested() -> void:
	get_tree().quit()


func _refresh_help_text() -> void:
	if help_label == null:
		return
	if player_character == null or not is_instance_valid(player_character):
		help_label.text = "角色调试入口：选择角色后进入无地图测试场。"
		return
	var hp_text := ""
	if player_character.get("hp") != null and player_character.get("max_hp") != null:
		hp_text = " HP %d/%d" % [int(round(float(player_character.get("hp")))), int(round(float(player_character.get("max_hp"))))]
	help_label.text = "角色调试：WASD 移动，J 普攻，K/L/I 技能，空格闪避，R 重置目标，Esc 返回选人。%s" % hp_text
