extends Node2D

const KNIGHT_SCENE := preload("res://characters/knight/knight.tscn")
const RANGER_SCENE := preload("res://characters/ranger/ranger.tscn")
const MAGE_SCENE := preload("res://characters/mage/mage.tscn")
const RunEffects := preload("res://systems/run/run_effects.gd")
const MapRuntime := preload("res://systems/map/map_runtime.gd")
const AudioRoute := preload("res://systems/run/audio_route.gd")
const DAMAGE_NUMBER_SCENE := preload("res://effects/damage_number.tscn")
const RUN_PICKUP_SCRIPT := preload("res://systems/pickups/run_pickup.gd")
const WORLD_HEALTH_BAR_SCRIPT := preload("res://ui/world_health_bar.gd")
const INVENTORY_PANEL_SCRIPT := preload("res://ui/inventory_panel.gd")
const RANGER_BOSS_SCENE := preload("res://actors/bosses/town/ranger_boss.tscn")
const MAGE_BOSS_SCENE := preload("res://actors/bosses/town/mage_boss.tscn")
const EMPEROR_BOSS_SCENE := preload("res://actors/bosses/town/emperor_boss.tscn")
const ENCOUNTER_SCENES := [
	preload("res://actors/encounters/town_mob_encounter.tscn"),
	preload("res://actors/encounters/town_mob_encounter.tscn"),
	preload("res://actors/encounters/town_mob_encounter.tscn"),
	preload("res://actors/encounters/town_mob_encounter.tscn"),
	preload("res://actors/encounters/town_mob_encounter.tscn"),
	preload("res://actors/bosses/town/judicator_boss.tscn"),
	preload("res://actors/bosses/town/royal_guard_formation.tscn"),
	preload("res://actors/bosses/town/twin_princes_boss.tscn")
]
const FINAL_BOSS_SCENES := [
	EMPEROR_BOSS_SCENE,
	RANGER_BOSS_SCENE,
	MAGE_BOSS_SCENE
]
const RELIC_REROLL_COST := 12
const HIT_FEEDBACK_COOLDOWN_MSEC := 55
const GATE_WALK_FINISH_DISTANCE := 10.0
const LEVEL_UP_FLASH_COLOR := Color(1.0, 0.92, 0.62, 1.0)
const XP_FLASH_COLOR := Color(0.68, 0.86, 1.0, 1.0)
const GOLD_FLASH_COLOR := Color(1.0, 0.88, 0.52, 1.0)
const HEAL_FLASH_COLOR := Color(0.62, 1.0, 0.76, 1.0)
const REPAIR_FLASH_COLOR := Color(0.58, 0.94, 0.96, 1.0)

@onready var spawn_marker: Marker2D = $PlayerSpawn
@onready var encounter_marker: Marker2D = $EncounterSpawn
@onready var encounter_root: Node2D = $EncounterRoot
@onready var character_hud: CanvasLayer = $CharacterHUD
@onready var battle_status: CanvasLayer = $BattleStatus
@onready var character_select: CanvasLayer = $CharacterSelect
@onready var audio_settings_panel: CanvasLayer = $AudioSettingsPanel
@onready var audio_shortcut_hint: CanvasLayer = $AudioShortcutHint
@onready var accessory_choice: CanvasLayer = $AccessoryChoice
@onready var run_event_panel: CanvasLayer = $RunEventPanel
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var result_screen: CanvasLayer = $ResultScreen
@onready var settings_panel: CanvasLayer = $SettingsPanel
@onready var debug_panel: CanvasLayer = $DebugPanel

var player_character: Node = null
var current_encounter: Node = null
var encounter_index: int = -1
var music_request_serial: int = 0
var audio_panel_was_open: bool = false
var waiting_for_accessory_choice: bool = false
var active_accessory_reason: String = ""
var active_accessory_source: String = ""
var active_run_event_kind: String = ""
var active_encounter_prep: Dictionary = {}
var return_pause_after_audio_panel: bool = false
var return_pause_after_settings_panel: bool = false
var last_attack_feedback_msec: int = 0
var reward_rng := RandomNumberGenerator.new()
var map_runtime: Node = null
var gate_walk_active: bool = false
var gate_walk_target: Vector2 = Vector2.ZERO
var gate_walk_callback: Callable = Callable()
var door_transition_layer: CanvasLayer = null
var door_transition_backdrop: ColorRect = null
var inventory_panel: CanvasLayer = null

func _ready() -> void:
	reward_rng.randomize()
	_prepare_map_runtime()
	_build_door_transition_overlay()
	_build_inventory_panel()
	if get_tree() != null and not get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.connect(_on_tree_node_added)
	RunDirector.configure_event_count(maxi(_encounter_count() - 1, 1))
	if character_select != null:
		character_select.character_selected.connect(_on_character_selected)
		if character_select.has_signal("audio_requested"):
			character_select.audio_requested.connect(_on_title_audio_requested)
		if character_select.has_signal("settings_requested"):
			character_select.settings_requested.connect(_on_title_settings_requested)
		if character_select.has_signal("quit_requested"):
			character_select.quit_requested.connect(_on_quit_requested)
	if accessory_choice != null and accessory_choice.has_signal("accessory_choice_made"):
		accessory_choice.accessory_choice_made.connect(_on_accessory_choice_made)
		if accessory_choice.has_signal("reroll_requested"):
			accessory_choice.reroll_requested.connect(_on_accessory_reroll_requested)
	if run_event_panel != null and run_event_panel.has_signal("event_choice_made"):
		run_event_panel.event_choice_made.connect(_on_run_event_choice_made)
	if pause_menu != null:
		if pause_menu.has_method("bind_world"):
			pause_menu.bind_world(self)
		pause_menu.resume_requested.connect(_on_pause_resume_requested)
		pause_menu.audio_requested.connect(_on_pause_audio_requested)
		pause_menu.settings_requested.connect(_on_pause_settings_requested)
		pause_menu.restart_requested.connect(_on_pause_restart_requested)
		pause_menu.quit_requested.connect(_on_quit_requested)
	if result_screen != null and result_screen.has_signal("closed"):
		result_screen.closed.connect(_on_result_closed)
		if result_screen.has_signal("quit_requested"):
			result_screen.quit_requested.connect(_on_quit_requested)
	if audio_settings_panel != null and audio_settings_panel.has_signal("closed"):
		audio_settings_panel.closed.connect(_on_audio_settings_panel_closed)
	if settings_panel != null and settings_panel.has_signal("closed"):
		settings_panel.closed.connect(_on_settings_panel_closed)
	if debug_panel != null and debug_panel.has_method("bind_world"):
		debug_panel.bind_world(self)
	_refresh_battle_status(
		_ui_text("Town Boss Trial", "城镇王战试炼", "城鎮王戰試煉"),
		_ui_text("Pick a champion, then claim relics between encounters.", "先选择角色，再在战斗间隙领取饰品。", "先選擇角色，再在戰鬥間隙領取飾品。"),
		_localized_detail_text("")
	)
	_update_screen_layers()
	if Music != null:
		Music.play_profile(&"title", true)
	if audio_shortcut_hint != null and audio_shortcut_hint.has_method("show_hint"):
		audio_shortcut_hint.show_hint(true)
	call_deferred("_consume_startup_context")

func _process(_delta: float) -> void:
	_process_gate_walk()
	_sync_audio_hint_state()
	_update_map_camera()
	_refresh_battle_status()

func _process_gate_walk() -> void:
	if not gate_walk_active:
		return
	if player_character == null or not is_instance_valid(player_character) or not (player_character is Node2D):
		_clear_player_auto_walk()
		return
	var player_node := player_character as Node2D
	var to_target := gate_walk_target - player_node.global_position
	if to_target.length() <= GATE_WALK_FINISH_DISTANCE:
		var callback := gate_walk_callback
		_clear_player_auto_walk()
		if callback.is_valid():
			callback.call()
		return
	var direction := to_target.normalized()
	if player_character.has_method("set_auto_walk_direction"):
		player_character.set_auto_walk_direction(direction)
	else:
		player_node.global_position += direction * 170.0 * get_process_delta_time()

func _walk_player_to_room_exit(callback: Callable) -> void:
	if player_character == null or not is_instance_valid(player_character) or not (player_character is Node2D):
		if callback.is_valid():
			callback.call()
		return
	var player_node := player_character as Node2D
	var exit_target := _room_exit_target(encounter_index)
	if player_node.global_position.distance_to(exit_target) > 900.0:
		exit_target = player_node.global_position + Vector2(90.0, 0.0)
	_walk_player_to_target(exit_target, callback)

func _walk_player_to_target(target_position: Vector2, callback: Callable) -> void:
	if player_character == null or not is_instance_valid(player_character) or not (player_character is Node2D):
		if callback.is_valid():
			callback.call()
		return
	var player_node := player_character as Node2D
	gate_walk_target = target_position
	gate_walk_callback = callback
	gate_walk_active = true
	if player_character.has_method("clear_control_effects"):
		player_character.clear_control_effects(true, true, true)
	if player_character.has_method("set_auto_walk_direction"):
		player_character.set_auto_walk_direction((gate_walk_target - player_node.global_position).normalized())

func _clear_player_auto_walk() -> void:
	gate_walk_active = false
	gate_walk_target = Vector2.ZERO
	gate_walk_callback = Callable()
	if player_character != null and is_instance_valid(player_character) and player_character.has_method("set_auto_walk_direction"):
		player_character.set_auto_walk_direction(Vector2.ZERO)

func _prepare_map_runtime() -> void:
	_hide_legacy_arena()
	map_runtime = MapRuntime.new()
	map_runtime.setup(self, spawn_marker, encounter_marker, reward_rng)
	add_child(map_runtime)
	map_runtime.build()

func _build_door_transition_overlay() -> void:
	door_transition_layer = CanvasLayer.new()
	door_transition_layer.name = "DoorTransition"
	door_transition_layer.layer = 25
	door_transition_layer.visible = false
	add_child(door_transition_layer)
	door_transition_backdrop = ColorRect.new()
	door_transition_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	door_transition_backdrop.color = Color(0.01, 0.012, 0.018, 0.0)
	door_transition_layer.add_child(door_transition_backdrop)

func _build_inventory_panel() -> void:
	inventory_panel = INVENTORY_PANEL_SCRIPT.new()
	inventory_panel.name = "InventoryPanel"
	add_child(inventory_panel)
	if inventory_panel.has_method("reset_run"):
		inventory_panel.reset_run()

func _hide_legacy_arena() -> void:
	for node_name in ["BackdropImage", "Backdrop", "CenterLane", "ThroneDais", "ThroneBanner"]:
		var node := get_node_or_null(node_name)
		if node is CanvasItem:
			(node as CanvasItem).visible = false
	var bounds := get_node_or_null("Bounds")
	if bounds != null:
		for child in bounds.get_children():
			if child is CollisionObject2D:
				(child as CollisionObject2D).collision_layer = 0
				(child as CollisionObject2D).collision_mask = 0
			if child is CanvasItem:
				(child as CanvasItem).visible = false

func _activate_map_room(room_index: int) -> void:
	if map_runtime == null:
		return
	map_runtime.activate_room(room_index, player_character)

func _player_spawn_for_room(room_index: int) -> Vector2:
	if map_runtime == null:
		return spawn_marker.position
	return map_runtime.player_spawn_for_room(room_index)

func _encounter_spawn_for_room(room_index: int) -> Vector2:
	if map_runtime == null:
		return encounter_marker.position
	return map_runtime.encounter_spawn_for_room(room_index)

func _room_exit_target(room_index: int) -> Vector2:
	if map_runtime != null and map_runtime.has_method("room_exit_target"):
		return map_runtime.room_exit_target(room_index)
	return _encounter_spawn_for_room(room_index) + Vector2(260.0, 0.0)

func _room_entrance_target(room_index: int) -> Vector2:
	if map_runtime != null and map_runtime.has_method("room_entrance_target"):
		return map_runtime.room_entrance_target(room_index)
	return _player_spawn_for_room(room_index) - Vector2(48.0, 0.0)

func _update_map_camera(force: bool = false) -> void:
	if map_runtime == null:
		return
	map_runtime.update_camera(encounter_index, player_character, force)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if InputMap.has_action("debug_toggle") and event.is_action_pressed("debug_toggle"):
			if debug_panel != null and debug_panel.has_method("toggle"):
				debug_panel.toggle()
				get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F10:
			if pause_menu != null and pause_menu.has_method("is_open") and bool(pause_menu.is_open()):
				_on_pause_audio_requested()
				get_viewport().set_input_as_handled()
				return
			if audio_settings_panel != null and audio_settings_panel.has_method("toggle_panel"):
				audio_settings_panel.toggle_panel()
				_sync_audio_hint_state()
				get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE:
			if inventory_panel != null and inventory_panel.visible:
				inventory_panel.close()
				_refresh_battle_status()
				get_viewport().set_input_as_handled()
				return
			if audio_settings_panel != null and audio_settings_panel.has_method("is_open") and bool(audio_settings_panel.is_open()):
				audio_settings_panel.hide_panel()
				_sync_audio_hint_state()
				_refresh_battle_status()
				get_viewport().set_input_as_handled()
				return
			if settings_panel != null and settings_panel.visible:
				settings_panel.close()
				_refresh_battle_status()
				get_viewport().set_input_as_handled()
				return
			if pause_menu != null and pause_menu.has_method("is_open") and bool(pause_menu.is_open()):
				pause_menu.close()
				_refresh_battle_status()
				get_viewport().set_input_as_handled()
				return
			if accessory_choice != null and accessory_choice.visible:
				return
			if run_event_panel != null and run_event_panel.visible:
				return
			if pause_menu != null and pause_menu.has_method("open"):
				pause_menu.open()
				_refresh_battle_status()
				get_viewport().set_input_as_handled()
				return
		if event.keycode == KEY_B or event.keycode == KEY_TAB:
			_toggle_inventory_panel()
			get_viewport().set_input_as_handled()
			return

func _on_character_selected(character_id: StringName) -> void:
	_cancel_scheduled_title_music()
	_clear_player_auto_walk()
	RunDirector.configure_event_count(maxi(_encounter_count() - 1, 1))
	if result_screen != null:
		result_screen.visible = false
	if audio_settings_panel != null and audio_settings_panel.has_method("hide_panel"):
		audio_settings_panel.hide_panel()
	if pause_menu != null and pause_menu.has_method("close") and bool(pause_menu.is_open()):
		pause_menu.close()
	if Sfx != null:
		_play_ui_feedback(true)
	AccessoryManager.reset_run()
	RunDirector.reset_run()
	if inventory_panel != null:
		if inventory_panel.has_method("close") and inventory_panel.visible:
			inventory_panel.close()
		if inventory_panel.has_method("reset_run"):
			inventory_panel.reset_run()
	active_encounter_prep.clear()
	if player_character != null and is_instance_valid(player_character):
		player_character.queue_free()
	if current_encounter != null and is_instance_valid(current_encounter):
		current_encounter.queue_free()
		current_encounter = null
	var next_scene: PackedScene = KNIGHT_SCENE
	if character_id == &"ranger":
		next_scene = RANGER_SCENE
	elif character_id == &"mage":
		next_scene = MAGE_SCENE
	player_character = next_scene.instantiate()
	player_character.position = _player_spawn_for_room(0)
	add_child(player_character)
	player_character.z_index = 3
	_update_map_camera(true)
	if character_select != null:
		character_select.visible = false
	_update_screen_layers()
	if character_hud != null and character_hud.has_method("bind_character"):
		character_hud.bind_character(player_character)
	AccessoryManager.apply_to_actor(player_character)
	RunEffects.refresh_persistent_modifiers(player_character)
	_bind_actor_audio(player_character)
	if player_character.has_signal("died"):
		player_character.died.connect(_on_player_died)
	encounter_index = -1
	_offer_accessory(_ui_text("First Relic", "初始饰品", "初始飾品"), "opening")

func _consume_startup_context() -> void:
	var startup := get_node_or_null("/root/StartupContext")
	if startup == null or not startup.has_method("consume_pending_start"):
		return
	var pending: Dictionary = startup.consume_pending_start()
	if StringName(pending.get("mode", &"")) != &"normal":
		return
	var character_id := StringName(pending.get("character_id", &""))
	if character_id == &"":
		return
	_on_character_selected(character_id)

func _start_next_encounter() -> void:
	_clear_player_auto_walk()
	waiting_for_accessory_choice = false
	active_accessory_reason = ""
	active_accessory_source = ""
	active_run_event_kind = ""
	return_pause_after_audio_panel = false
	return_pause_after_settings_panel = false
	active_encounter_prep = RunDirector.consume_pending_encounter_prep()
	encounter_index += 1
	if encounter_index >= _encounter_count():
		active_encounter_prep.clear()
		_complete_run_victory()
		return
	if encounter_index > 0:
		_transition_through_room_door(encounter_index, Callable(self, "_begin_current_encounter"))
		return
	_begin_current_encounter()

func _begin_current_encounter() -> void:
	_activate_map_room(encounter_index)
	_play_audio_profile_for_encounter(encounter_index)
	current_encounter = _encounter_scene_for_index(encounter_index).instantiate()
	current_encounter.position = encounter_marker.position
	encounter_root.add_child(current_encounter)
	if not active_encounter_prep.is_empty():
		RunEffects.activate_encounter_prep(player_character, active_encounter_prep)
	if current_encounter.has_method("bind_player"):
		current_encounter.bind_player(player_character)
	if current_encounter.has_signal("defeated"):
		current_encounter.defeated.connect(_on_encounter_defeated)
	_bind_encounter_actor_if_needed(current_encounter)
	_bind_existing_encounter_actors(current_encounter)
	_refresh_battle_status()

func _transition_through_room_door(room_index: int, callback: Callable) -> void:
	if player_character == null or not is_instance_valid(player_character) or not (player_character is Node2D):
		if callback.is_valid():
			callback.call()
		return
	if door_transition_layer == null or door_transition_backdrop == null:
		if callback.is_valid():
			callback.call()
		return
	door_transition_layer.visible = true
	door_transition_backdrop.color = Color(0.01, 0.012, 0.018, 0.0)
	var tween := create_tween()
	tween.tween_property(door_transition_backdrop, "color:a", 0.86, 0.12)
	tween.tween_callback(func() -> void:
		if not is_instance_valid(self):
			return
		_activate_map_room(room_index)
		if player_character is Node2D and is_instance_valid(player_character):
			(player_character as Node2D).global_position = _room_entrance_target(room_index)
		_update_map_camera(true)
	)
	tween.tween_property(door_transition_backdrop, "color:a", 0.0, 0.18)
	tween.tween_callback(func() -> void:
		if not is_instance_valid(self):
			return
		door_transition_layer.visible = false
		_walk_player_to_target(_player_spawn_for_room(room_index), callback)
	)

func _toggle_inventory_panel() -> void:
	if inventory_panel == null:
		return
	if player_character == null or not is_instance_valid(player_character):
		return
	if accessory_choice != null and accessory_choice.visible:
		return
	if run_event_panel != null and run_event_panel.visible:
		return
	if pause_menu != null and pause_menu.has_method("is_open") and bool(pause_menu.is_open()):
		return
	if audio_settings_panel != null and audio_settings_panel.has_method("is_open") and bool(audio_settings_panel.is_open()):
		return
	if settings_panel != null and settings_panel.visible:
		return
	if inventory_panel.has_method("toggle"):
		inventory_panel.toggle(player_character)
	_refresh_battle_status()

func _on_encounter_defeated() -> void:
	var reward := RunDirector.reward_encounter(encounter_index, player_character)
	var reward_bonus := int(active_encounter_prep.get("reward_bonus", 0))
	if reward_bonus > 0:
		RunDirector.grant_gold(reward_bonus)
		reward += reward_bonus
	if not active_encounter_prep.is_empty() and player_character != null and is_instance_valid(player_character):
		RunEffects.refresh_persistent_modifiers(player_character)
		if bool(active_encounter_prep.get("clear_shield_on_end", false)):
			RunEffects.clear_shield(player_character)
	current_encounter = null
	var defeated_final_encounter := encounter_index >= _encounter_count() - 1
	active_encounter_prep.clear()
	_refresh_battle_status(
		_ui_text("Trial Complete", "试炼阶段完成", "試煉階段完成") if defeated_final_encounter else _ui_text("Encounter Cleared", "遭遇完成", "遭遇完成"),
		_ui_text("+%d gold earned.", "获得 +%d 金币。", "獲得 +%d 金幣。") % reward,
		_localized_detail_text("%s: %d" % [_ui_text("Gold", "金币", "金幣"), int(RunDirector.gold)])
	)
	var timer := get_tree().create_timer(0.65)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self) and player_character != null and is_instance_valid(player_character) and float(player_character.hp) > 0.0:
			_walk_player_to_room_exit(func() -> void:
				if not is_instance_valid(self) or player_character == null or not is_instance_valid(player_character) or float(player_character.hp) <= 0.0:
					return
				if defeated_final_encounter:
					_complete_run_victory()
				else:
					_offer_next_run_event()
			)
	)

func _on_player_died() -> void:
	_clear_player_auto_walk()
	if not active_encounter_prep.is_empty() and player_character != null and is_instance_valid(player_character):
		RunEffects.refresh_persistent_modifiers(player_character)
		if bool(active_encounter_prep.get("clear_shield_on_end", false)):
			RunEffects.clear_shield(player_character)
	if current_encounter != null and is_instance_valid(current_encounter):
		current_encounter.queue_free()
	current_encounter = null
	active_encounter_prep.clear()
	if Music != null:
		Music.play_profile(&"defeat")
	_schedule_title_music(2.4)
	_refresh_battle_status(
		_ui_text("Defeated", "挑战失败", "挑戰失敗"),
		_ui_text("The town boss rush resets after death.", "阵亡后，本轮城镇王战会重新开始。", "陣亡後，本輪城鎮王戰會重新開始。"),
		_localized_detail_text(_ui_text("Pick a champion to restart.", "重新选择角色后可再次挑战。", "重新選擇角色後可再次挑戰。"))
	)
	if character_select != null:
		character_select.visible = true
	_update_screen_layers()
	if result_screen != null and result_screen.has_method("show_result"):
		result_screen.show_result(
			"defeat",
			_ui_text("Defeated", "挑战失败", "挑戰失敗"),
			_ui_text("The town boss rush resets after death.", "阵亡后，本轮城镇王战会重新开始。", "陣亡後，本輪城鎮王戰會重新開始。"),
			_ui_text("Continue to return to champion selection and try a different relic path.", "继续后回到选角界面，换一条饰品路线重新尝试。", "繼續後回到選角介面，換一條飾品路線重新嘗試。"),
			_build_result_summary()
		)
	_refresh_battle_status()
	waiting_for_accessory_choice = false
	active_accessory_reason = ""
	active_accessory_source = ""
	active_run_event_kind = ""

func _offer_accessory(reason: String, source: String = "route") -> void:
	if accessory_choice == null or not accessory_choice.has_method("open"):
		_start_next_encounter()
		return
	_play_intermission_audio()
	waiting_for_accessory_choice = true
	active_accessory_reason = reason
	active_accessory_source = source
	active_run_event_kind = ""
	var choices := AccessoryManager.generate_choices(3, player_character, {
		"stage": maxi(encounter_index + 1, 0),
		"source": source
	})
	accessory_choice.open(choices, player_character, reason, RELIC_REROLL_COST, int(RunDirector.gold))
	_refresh_battle_status(
		reason,
		_ui_text("Choose a relic before the next fight.", "在下一场战斗前选择一件饰品。", "在下一場戰鬥前選擇一件飾品。"),
		_localized_detail_text("%s: %s" % [
			_ui_text("Current", "当前", "當前"),
			String(AccessoryManager.get_equipped_accessory().get("name", _ui_text("No Accessory", "无饰品", "無飾品")))
		])
	)

func _offer_next_run_event() -> void:
	var kind := RunDirector.next_event_kind()
	if kind == "relic" or run_event_panel == null or not run_event_panel.has_method("open"):
		_offer_accessory(_ui_text("Victory Relic", "胜利饰品", "勝利飾品"), "victory")
		return
	_play_intermission_audio()
	active_run_event_kind = kind
	run_event_panel.open(kind, int(RunDirector.gold))
	_refresh_battle_status(
		_ui_text("Run Event", "流程事件", "流程事件"),
		_ui_text("Choose a reward before the next fight.", "在下一场战斗前选择一项奖励。", "在下一場戰鬥前選擇一項獎勵。"),
		_localized_detail_text("%s: %d" % [_ui_text("Gold", "金币", "金幣"), int(RunDirector.gold)])
	)

func _on_accessory_choice_made(_accessory_id: String, kept_current: bool) -> void:
	waiting_for_accessory_choice = false
	active_accessory_reason = ""
	active_accessory_source = ""
	if player_character != null and is_instance_valid(player_character):
		RunEffects.refresh_persistent_modifiers(player_character)
	if Sfx != null:
		_play_ui_feedback(true)
	var equipped_accessory := AccessoryManager.get_equipped_accessory()
	if inventory_panel != null and inventory_panel.has_method("record_relic_equipped"):
		inventory_panel.record_relic_equipped(equipped_accessory)
	var accessory_name := String(equipped_accessory.get("name", _ui_text("No Accessory", "无饰品", "無飾品")))
	_refresh_battle_status(
		_ui_text("Relic Kept", "保留饰品", "保留飾品") if kept_current else _ui_text("Relic Equipped", "装备饰品", "裝備飾品"),
		accessory_name,
		_localized_detail_text(_ui_text("The next encounter begins now.", "下一场遭遇即将开始。", "下一場遭遇即將開始。"))
	)
	_start_next_encounter()

func _on_accessory_reroll_requested() -> void:
	if not waiting_for_accessory_choice:
		return
	if not RunDirector.spend_gold(RELIC_REROLL_COST):
		if Sfx != null:
			_play_ui_feedback(false)
		return
	if Sfx != null:
		_play_ui_feedback(true)
	var reason := active_accessory_reason if not active_accessory_reason.is_empty() else _ui_text("Relic Offering", "饰品赐予", "飾品賜予")
	var choices := AccessoryManager.generate_choices(3, player_character, {
		"stage": maxi(encounter_index + 1, 0),
		"source": active_accessory_source if not active_accessory_source.is_empty() else "route",
		"reroll": true
	})
	accessory_choice.open(choices, player_character, reason, RELIC_REROLL_COST, int(RunDirector.gold))
	_refresh_battle_status(
		_ui_text("Relic Rerolled", "饰品重抽", "飾品重抽"),
		_ui_text("New relic choices are available.", "新的饰品选项已经出现。", "新的飾品選項已經出現。"),
		_localized_detail_text("%s: %d" % [_ui_text("Gold", "金币", "金幣"), int(RunDirector.gold)])
	)

func _on_run_event_choice_made(choice_id: String) -> void:
	var applied := _apply_run_event_choice(choice_id)
	if Sfx != null:
		_play_ui_feedback(applied)
	if not applied and choice_id != "skip":
		if active_run_event_kind != "" and run_event_panel != null and run_event_panel.has_method("open"):
			run_event_panel.open(active_run_event_kind, int(RunDirector.gold))
		_refresh_battle_status(
			_ui_text("Not Enough Gold", "金币不足", "金幣不足"),
			_ui_text("Choose another reward or skip the event.", "请改选别的奖励，或直接跳过事件。", "請改選別的獎勵，或直接跳過事件。"),
			_localized_detail_text("%s: %d" % [_ui_text("Gold", "金币", "金幣"), int(RunDirector.gold)])
		)
		return
	_refresh_battle_status(
		_ui_text("Event Complete", "事件完成", "事件完成"),
		_run_event_summary(choice_id),
		_localized_detail_text("%s: %d" % [_ui_text("Gold", "金币", "金幣"), int(RunDirector.gold)])
	)
	RunDirector.record_event_choice(
		active_run_event_kind,
		choice_id,
		_run_event_summary(choice_id),
		RunEffects.display_name(choice_id)
	)
	active_run_event_kind = ""
	if choice_id == "shop_relic" and applied:
		_offer_accessory(_ui_text("Purchased Relic", "购买饰品", "購買飾品"), "shop")
	else:
		_start_next_encounter()

func _apply_run_event_choice(choice_id: String) -> bool:
	if player_character == null or not is_instance_valid(player_character):
		return false
	var cost := RunEffects.cost_for(choice_id)
	if cost > 0 and not RunDirector.spend_gold(cost):
		return false
	RunEffects.apply_choice(choice_id, player_character)
	return true

func _run_event_summary(choice_id: String) -> String:
	return RunEffects.summary(choice_id)

func _build_result_summary() -> Dictionary:
	var run_state := RunDirector.get_state()
	var hero_name := _ui_text("No Champion", "未选择角色", "未選擇角色")
	if player_character != null and is_instance_valid(player_character) and player_character.has_method("get_character_name"):
		hero_name = _hero_display_name(String(player_character.get_character_name()))
	var accessory := AccessoryManager.get_equipped_accessory()
	var accessory_name := String(accessory.get("name", _ui_text("No Accessory", "无饰品", "無飾品")))
	var reward_entries := run_state.get("reward_history", []) as Array
	var total_reward_value := 0
	for reward_entry in reward_entries:
		total_reward_value += int(reward_entry)
	var average_reward := int(round(float(total_reward_value) / float(reward_entries.size()))) if not reward_entries.is_empty() else 0
	var event_history := run_state.get("event_history", []) as Array
	var timeline_text := _ui_text("No event choices recorded.", "没有记录到事件选择。", "沒有記錄到事件選擇。")
	if not event_history.is_empty():
		var parts: Array[String] = []
		for entry in event_history:
			if not (entry is Dictionary):
				continue
			var step := entry as Dictionary
			parts.append("%s -> %s" % [
				String(step.get("event_name", _ui_text("Event", "事件", "事件"))),
				String(step.get("choice_name", _ui_text("Choice", "选择", "選擇")))
			])
		if not parts.is_empty():
			timeline_text = "  /  ".join(parts)
	return {
		"stats": _ui_text("Hero", "角色", "角色") + " %s  |  " % hero_name + _ui_text("Relic", "饰品", "飾品") + " %s  |  " % accessory_name + _ui_text("Gold", "金币", "金幣") + " %d  |  " % int(run_state.get("gold", 0)) + _ui_text("Cleared", "完成", "完成") + " %d  |  " % int(run_state.get("cleared_encounters", 0)) + _ui_text("Level", "等级", "等級") + " %d  |  " % int(run_state.get("hero_level", 1)) + _ui_text("Kills", "击杀", "擊殺") + " %d  |  " % int(run_state.get("total_kills", 0)) + _ui_text("Avg reward", "平均奖励", "平均獎勵") + " %d" % average_reward,
		"timeline": timeline_text
	}

func _play_ui_feedback(success: bool) -> void:
	if Sfx == null:
		return
	if success:
		Sfx.play_event(&"ui_confirm")
		return
	if Sfx.has_method("has_event") and bool(Sfx.has_event(&"ui_deny")):
		Sfx.play_event(&"ui_deny")
		return
	Sfx.play_event(&"ui_confirm", null, -7.0, 0.86, "UI")

func _complete_run_victory() -> void:
	if Music != null:
		Music.play_profile(&"victory")
	_schedule_title_music(2.8)
	_refresh_battle_status(
		_ui_text("Town Cleared", "城镇试炼完成", "城鎮試煉完成"),
		_ui_text("All enemy waves and town boss encounters are defeated.", "所有敌军波次与城镇 Boss 都已击破。", "所有敵軍波次與城鎮 Boss 都已擊破。"),
		_localized_detail_text(_ui_text("Pick another champion to restart the sequence.", "重新选择角色即可再次开始这一轮试炼。", "重新選擇角色即可再次開始這一輪試煉。"))
	)
	if character_select != null:
		character_select.visible = true
	_update_screen_layers()
	if result_screen != null and result_screen.has_method("show_result"):
		result_screen.show_result(
			"victory",
			_ui_text("Town Cleared", "城镇试炼完成", "城鎮試煉完成"),
			_ui_text("All enemy waves and bosses are defeated.", "所有敌军波次与 Boss 都已击破。", "所有敵軍波次與 Boss 都已擊破。"),
			_ui_text("Your relic build survived the trial. Continue to select a new champion.", "你的饰品构筑撑过了整场试炼。继续后可重新选择角色。", "你的飾品構築撐過了整場試煉。繼續後可重新選擇角色。"),
			_build_result_summary()
		)
	_refresh_battle_status()

func _bind_actor_audio(actor: Node) -> void:
	if actor == null:
		return
	if actor.has_signal("attack_started") and not actor.attack_started.is_connected(_on_actor_attack_started):
		actor.attack_started.connect(_on_actor_attack_started.bind(actor))
	if actor.has_signal("attack_hit") and not actor.attack_hit.is_connected(_on_actor_attack_hit):
		actor.attack_hit.connect(_on_actor_attack_hit.bind(actor))
	if actor.has_signal("took_damage") and not actor.took_damage.is_connected(_on_actor_took_damage):
		actor.took_damage.connect(_on_actor_took_damage.bind(actor))
	if actor.has_signal("died") and not actor.died.is_connected(_on_actor_died):
		actor.died.connect(_on_actor_died.bind(actor))

func _on_actor_attack_started(attack_name: StringName, actor: Node) -> void:
	if actor == null or not actor.has_method("get_character_name"):
		return
	var actor_name := String(actor.get_character_name()).to_lower()
	var event_id := "%s_attack" % actor_name
	match actor_name:
		"knight":
			match attack_name:
				&"skill1":
					event_id = "knight_skill1_charge"
				&"skill2":
					event_id = "knight_skill2_shockwave"
				&"skill3":
					event_id = "knight_skill3_sanctuary"
		"ranger":
			match attack_name:
				&"skill1":
					event_id = "ranger_skill1_arrow"
				&"skill2":
					event_id = "ranger_skill2_roll"
				&"skill3":
					event_id = "ranger_skill3_assassinate"
		"mage":
			match attack_name:
				&"skill1":
					event_id = "mage_skill1_blades"
				&"skill2":
					event_id = "mage_skill2_burst"
				&"skill3":
					event_id = "mage_skill3_enchant"
	if Sfx != null:
		Sfx.play_event(StringName(event_id), actor.global_position)

func _on_actor_took_damage(_amount: float, _remaining_hp: float, actor: Node) -> void:
	if actor == null or not actor.has_method("get_character_name") or Sfx == null:
		return
	var event_id := "%s_hit" % String(actor.get_character_name()).to_lower()
	Sfx.play_event(StringName(event_id), actor.global_position, -2.0)
	if Feedback != null:
		Feedback.hitstop(0.035)

func _on_actor_attack_hit(attack_name: StringName, target: Node, _actor: Node) -> void:
	if not (target is Node2D):
		return
	var now := Time.get_ticks_msec()
	var target_defeated := _is_target_defeated(target)
	var skill_hit := attack_name != &"attack"
	if not target_defeated and now - last_attack_feedback_msec < HIT_FEEDBACK_COOLDOWN_MSEC:
		return
	last_attack_feedback_msec = now
	if Feedback != null and (skill_hit or target_defeated):
		Feedback.hitstop(0.028 if target_defeated else 0.018)
	_spawn_attack_hit_feedback((target as Node2D).global_position, skill_hit, target_defeated)

func _on_actor_died(actor: Node) -> void:
	if actor == null or not actor.has_method("get_character_name") or Sfx == null:
		return
	var event_id := "%s_dead" % String(actor.get_character_name()).to_lower()
	Sfx.play_event(StringName(event_id), actor.global_position)

func _on_tree_node_added(node: Node) -> void:
	call_deferred("_bind_encounter_actor_if_needed", node)

func _bind_existing_encounter_actors(root: Node) -> void:
	if root == null or not is_instance_valid(root):
		return
	_bind_encounter_actor_if_needed(root)
	for child in root.get_children():
		if child is Node:
			_bind_existing_encounter_actors(child)

func _bind_encounter_actor_if_needed(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if current_encounter == null or not is_instance_valid(current_encounter):
		return
	if node == player_character or not (node is Node2D):
		return
	var within_active_encounter := node == current_encounter or current_encounter.is_ancestor_of(node)
	if not within_active_encounter:
		return
	if not node.has_method("receive_hit") or not node.has_signal("defeated"):
		return
	if not node.has_meta("world_reward_bound"):
		node.set_meta("world_reward_bound", true)
		node.defeated.connect(_on_encounter_actor_defeated.bind(node))
	if not node.has_meta("world_health_bar_bound"):
		node.set_meta("world_health_bar_bound", true)
		var health_bar := WORLD_HEALTH_BAR_SCRIPT.new()
		node.add_child(health_bar)
		health_bar.setup(node, _health_bar_options(node))

func _health_bar_options(actor: Node) -> Dictionary:
	var script_path := _script_path(actor)
	var max_hp_value := _actor_max_hp(actor)
	var boss := script_path.contains("actors/bosses/")
	var elite := boss or (_has_property(actor, "elite") and bool(actor.get("elite")))
	var bar_width := 66.0
	var y_offset := -50.0
	if elite:
		bar_width = 86.0
		y_offset = -60.0
	if boss:
		bar_width = 116.0 if max_hp_value < 5000.0 else 132.0
		y_offset = -76.0
	return {
		"always_visible": true,
		"elite": elite,
		"boss": boss,
		"bar_width": bar_width,
		"y_offset": y_offset,
		"hp_height": 9.0 if boss else (8.0 if elite else 8.0),
		"defense_height": 4.0 if boss else 4.0
	}

func _on_encounter_actor_defeated(actor: Node) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	if actor.has_meta("world_reward_claimed"):
		return
	actor.set_meta("world_reward_claimed", true)
	if player_character == null or not is_instance_valid(player_character):
		return
	if _has_property(player_character, "hp") and float(player_character.get("hp")) <= 0.0:
		return
	RunDirector.record_kill()
	var reward := _build_defeat_rewards(actor)
	var xp_amount := int(reward.get("xp", 0))
	var reward_position := (actor as Node2D).global_position
	if xp_amount > 0:
		var xp_result := RunDirector.grant_experience(xp_amount)
		_spawn_world_text(
			reward_position + Vector2(0.0, -20.0),
			_ui_text("+%d XP", "+%d 经验", "+%d 經驗") % xp_amount,
			XP_FLASH_COLOR,
			0.8
		)
		_push_hud_feed(
			_ui_text("+%d XP secured", "获得 +%d 经验", "獲得 +%d 經驗") % xp_amount,
			XP_FLASH_COLOR,
			1.03
		)
		var levels_gained := int(xp_result.get("levels_gained", 0))
		if levels_gained > 0:
			_apply_level_up_rewards(player_character, levels_gained)
			var level_value := int(xp_result.get("current_level", 1))
			_spawn_world_text(
				player_character.global_position + Vector2(0.0, -54.0),
				_ui_text("Level %d", "等级 %d", "等級 %d") % level_value,
				LEVEL_UP_FLASH_COLOR,
				0.96
			)
			_push_hud_feed(
				_ui_text("Level %d reached", "达到等级 %d", "達到等級 %d") % level_value,
				LEVEL_UP_FLASH_COLOR,
				1.08
			)
	_spawn_reward_pickups(reward_position, reward.get("drops", []) as Array)

func _build_defeat_rewards(actor: Node) -> Dictionary:
	var script_path := _script_path(actor)
	var boss := script_path.contains("actors/bosses/")
	var elite := boss or (_has_property(actor, "elite") and bool(actor.get("elite")))
	var max_hp_value := _actor_max_hp(actor)
	var max_defense_value := _actor_max_defense(actor)
	var attack_value := _actor_attack_damage(actor)
	var power_score := max_hp_value * 0.022 + max_defense_value * 0.028 + attack_value * 0.42
	var xp_amount := int(round(8.0 + power_score * (2.2 if boss else (1.38 if elite else 1.0))))
	if boss:
		xp_amount = maxi(xp_amount, 90)
	elif elite:
		xp_amount = maxi(xp_amount, 20)
	else:
		xp_amount = maxi(xp_amount, 10)
	var gold_total := int(round(1.0 + power_score * (0.28 if boss else (0.20 if elite else 0.10))))
	if boss:
		gold_total = maxi(gold_total, 14)
	elif elite:
		gold_total = maxi(gold_total, 4)
	else:
		gold_total = maxi(gold_total, 1)
	gold_total = mini(gold_total, 42 if boss else (14 if elite else 5))
	var drops: Array[Dictionary] = []
	var gold_chunks := 1 if gold_total <= 6 else (2 if gold_total <= 16 else 3)
	for gold_amount in _split_drop_amount(gold_total, gold_chunks):
		drops.append(_drop_entry("gold", float(gold_amount)))
	var is_shield := script_path.contains("shield") or script_path.contains("guard")
	var is_arcane := script_path.contains("mage") or script_path.contains("arcanist") or script_path.contains("judicator")
	var is_hunter := script_path.contains("hunter") or script_path.contains("twin")
	if boss:
		drops.append(_drop_entry("repair", maxf(22.0, _player_stat_value("max_defense") * 0.28)))
		drops.append(_drop_entry("inspiration", maxf(8.0, _player_stat_value("max_inspiration") * 0.40)))
		drops.append(_drop_entry("heal", maxf(12.0, _player_stat_value("max_hp") * 0.14)))
	else:
		if is_shield or max_defense_value >= 90.0 or reward_rng.randf() < (0.18 + (0.16 if elite else 0.0)):
			drops.append(_drop_entry("repair", clampf(10.0 + max_defense_value * 0.09, 10.0, 28.0)))
		if is_arcane or reward_rng.randf() < (0.20 + (0.14 if elite else 0.0)):
			drops.append(_drop_entry("inspiration", clampf(4.0 + attack_value * 0.08, 4.0, 12.0)))
		if is_hunter or reward_rng.randf() < (0.12 + (0.12 if elite else 0.0)):
			drops.append(_drop_entry("heal", clampf(6.0 + max_hp_value * 0.025, 6.0, 18.0)))
		if elite and drops.size() < 3:
			drops.append(_drop_entry("inspiration", 8.0))
	return {
		"xp": xp_amount,
		"drops": drops
	}

func _spawn_reward_pickups(world_position: Vector2, drops: Array) -> void:
	if drops.is_empty():
		return
	for index in range(drops.size()):
		var drop := drops[index] as Dictionary
		var pickup := RUN_PICKUP_SCRIPT.new()
		pickup.global_position = world_position
		var angle := TAU * float(index) / float(max(drops.size(), 1)) + reward_rng.randf_range(-0.22, 0.22)
		pickup.setup(
			String(drop.get("kind", "gold")),
			float(drop.get("amount", 0.0)),
			{
				"tint": _pickup_tint(String(drop.get("kind", "gold"))),
				"launch_speed": 34.0 + float(index) * 8.0,
				"launch_angle": angle
			}
		)
		pickup.collected.connect(_on_run_pickup_collected)
		add_child(pickup)

func _on_run_pickup_collected(kind: String, amount: float, world_position: Vector2) -> void:
	if player_character == null or not is_instance_valid(player_character):
		return
	if inventory_panel != null and inventory_panel.has_method("record_pickup"):
		inventory_panel.record_pickup(kind, amount)
	match kind:
		"gold":
			var gold_amount := int(round(amount))
			RunDirector.grant_gold(gold_amount)
			_spawn_world_text(world_position, _ui_text("+%d Gold", "+%d 金币", "+%d 金幣") % gold_amount, GOLD_FLASH_COLOR, 0.78)
			_push_hud_feed(_ui_text("+%d gold picked up", "拾取 +%d 金币", "拾取 +%d 金幣") % gold_amount, GOLD_FLASH_COLOR, 1.02)
		"inspiration":
			_grant_actor_inspiration(player_character, amount)
			_spawn_world_text(world_position, _ui_text("+%d Insp", "+%d 灵感", "+%d 靈感") % int(round(amount)), XP_FLASH_COLOR, 0.76)
			_push_hud_feed(_ui_text("Inspiration +%d", "灵感 +%d", "靈感 +%d") % int(round(amount)), XP_FLASH_COLOR, 1.02)
		"repair":
			_restore_actor_defense(player_character, amount)
			_spawn_world_text(world_position, _ui_text("+%d DEF", "+%d 护甲", "+%d 護甲") % int(round(amount)), REPAIR_FLASH_COLOR, 0.76)
			_push_hud_feed(_ui_text("Defense +%d", "护甲 +%d", "護甲 +%d") % int(round(amount)), REPAIR_FLASH_COLOR, 1.02)
		"heal":
			_heal_actor(player_character, amount)
			_spawn_world_text(world_position, _ui_text("+%d HP", "+%d 生命", "+%d 生命") % int(round(amount)), HEAL_FLASH_COLOR, 0.76)
			_push_hud_feed(_ui_text("Recovered +%d HP", "恢复 +%d 生命", "恢復 +%d 生命") % int(round(amount)), HEAL_FLASH_COLOR, 1.02)

func _apply_level_up_rewards(actor: Node, levels_gained: int) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	for _level_index in range(levels_gained):
		_apply_single_level_bonus(actor)
	_sync_actor_progression(actor)

func _apply_single_level_bonus(actor: Node) -> void:
	if _has_property(actor, "max_hp"):
		var hp_gain := maxf(float(actor.get("max_hp")) * 0.10, 12.0)
		actor.set("max_hp", float(actor.get("max_hp")) + hp_gain)
		if _has_property(actor, "hp"):
			actor.set("hp", minf(float(actor.get("hp")) + hp_gain, float(actor.get("max_hp"))))
	if _has_property(actor, "max_defense"):
		var defense_gain := maxf(float(actor.get("max_defense")) * 0.10, 10.0)
		actor.set("max_defense", float(actor.get("max_defense")) + defense_gain)
		if _has_property(actor, "defense"):
			actor.set("defense", float(actor.get("max_defense")))
	if _has_property(actor, "max_inspiration"):
		var inspiration_gain := maxf(float(actor.get("max_inspiration")) * 0.06, 3.0)
		actor.set("max_inspiration", float(actor.get("max_inspiration")) + inspiration_gain)
		if _has_property(actor, "inspiration"):
			actor.set("inspiration", minf(float(actor.get("inspiration")) + inspiration_gain + 4.0, float(actor.get("max_inspiration"))))
	if _has_property(actor, "attack_damage"):
		actor.set("attack_damage", float(actor.get("attack_damage")) * 1.06)
	if _has_property(actor, "crit_rate"):
		actor.set("crit_rate", clampf(float(actor.get("crit_rate")) + 0.02, 0.0, 0.85))
	if _has_property(actor, "attack_interval"):
		actor.set("attack_interval", maxf(float(actor.get("attack_interval")) * 0.985, 0.22))

func _sync_actor_progression(actor: Node) -> void:
	var health_component := _health_component(actor)
	if health_component != null:
		if _has_property(actor, "max_hp"):
			health_component.max_hp = float(actor.get("max_hp"))
		if _has_property(actor, "hp"):
			health_component.hp = clampf(float(actor.get("hp")), 0.0, float(actor.get("max_hp")))
		if _has_property(actor, "max_defense"):
			health_component.max_defense = float(actor.get("max_defense"))
		if _has_property(actor, "defense"):
			health_component.defense = clampf(float(actor.get("defense")), 0.0, float(actor.get("max_defense")))
		if health_component.has_signal("defense_changed"):
			health_component.defense_changed.emit(float(health_component.defense), float(health_component.max_defense))
	if actor.has_method("emit_stat_signals"):
		actor.emit_stat_signals()

func _health_component(actor: Node) -> Node:
	if actor == null:
		return null
	if _has_property(actor, "health_component"):
		return actor.get("health_component") as Node
	return actor.get_node_or_null("HealthComponent")

func _heal_actor(actor: Node, amount: float) -> void:
	if actor == null or not is_instance_valid(actor) or amount <= 0.0:
		return
	var health_component := _health_component(actor)
	if health_component != null and health_component.has_method("heal"):
		health_component.heal(amount)
	elif _has_property(actor, "hp") and _has_property(actor, "max_hp"):
		actor.set("hp", minf(float(actor.get("hp")) + amount, float(actor.get("max_hp"))))
		if actor.has_method("emit_stat_signals"):
			actor.emit_stat_signals()

func _restore_actor_defense(actor: Node, amount: float) -> void:
	if actor == null or not is_instance_valid(actor) or amount <= 0.0:
		return
	var health_component := _health_component(actor)
	if health_component == null:
		return
	var next_defense := minf(float(health_component.defense) + amount, float(health_component.max_defense))
	health_component.defense = next_defense
	if _has_property(actor, "defense"):
		actor.set("defense", next_defense)
	if health_component.has_signal("defense_changed"):
		health_component.defense_changed.emit(next_defense, float(health_component.max_defense))

func _grant_actor_inspiration(actor: Node, amount: float) -> void:
	if actor == null or not is_instance_valid(actor) or amount <= 0.0:
		return
	if actor.has_method("gain_inspiration"):
		actor.gain_inspiration(amount)
		return
	if _has_property(actor, "inspiration") and _has_property(actor, "max_inspiration"):
		actor.set("inspiration", minf(float(actor.get("inspiration")) + amount, float(actor.get("max_inspiration"))))
		if actor.has_method("emit_stat_signals"):
			actor.emit_stat_signals()

func _spawn_world_text(world_position: Vector2, label_text: String, color_value: Color, scale_value: float = 0.8) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var popup := DAMAGE_NUMBER_SCENE.instantiate()
	popup.position = world_position
	if popup.has_method("setup_text"):
		popup.setup_text(label_text, color_value, scale_value)
	scene_root.add_child(popup)

func _push_hud_feed(text: String, color_value: Color, scale_value: float = 1.0) -> void:
	if character_hud != null and character_hud.has_method("push_feed_message"):
		character_hud.push_feed_message(text, color_value, scale_value)

func _drop_entry(kind: String, amount: float) -> Dictionary:
	return {
		"kind": kind,
		"amount": amount
	}

func _split_drop_amount(total_amount: int, parts: int) -> Array[int]:
	var result: Array[int] = []
	var safe_parts := maxi(parts, 1)
	var remaining := maxi(total_amount, 0)
	for part_index in range(safe_parts):
		var slots_left := safe_parts - part_index
		var share := maxi(int(round(float(remaining) / float(slots_left))), 1)
		if part_index == safe_parts - 1:
			share = remaining
		result.append(share)
		remaining = maxi(remaining - share, 0)
	return result

func _pickup_tint(kind: String) -> Color:
	match kind:
		"inspiration":
			return XP_FLASH_COLOR
		"repair":
			return REPAIR_FLASH_COLOR
		"heal":
			return HEAL_FLASH_COLOR
		_:
			return GOLD_FLASH_COLOR

func _player_stat_value(field: String) -> float:
	if player_character == null or not is_instance_valid(player_character) or not _has_property(player_character, field):
		return 0.0
	return float(player_character.get(field))

func _actor_max_hp(actor: Node) -> float:
	var health_component := _health_component(actor)
	if health_component != null and _has_property(health_component, "max_hp"):
		return float(health_component.max_hp)
	if _has_property(actor, "max_hp"):
		return float(actor.get("max_hp"))
	return 100.0

func _actor_max_defense(actor: Node) -> float:
	var health_component := _health_component(actor)
	if health_component != null and _has_property(health_component, "max_defense"):
		return float(health_component.max_defense)
	if _has_property(actor, "max_defense"):
		return float(actor.get("max_defense"))
	if _has_property(actor, "defense_value"):
		return float(actor.get("defense_value"))
	if _has_property(actor, "defense"):
		return float(actor.get("defense"))
	return 0.0

func _actor_attack_damage(actor: Node) -> float:
	if _has_property(actor, "attack_damage"):
		return float(actor.get("attack_damage"))
	return 10.0

func _play_audio_profile_for_encounter(next_encounter_index: int) -> void:
	AudioRoute.play_for_encounter(Music, next_encounter_index)

func _play_intermission_audio() -> void:
	AudioRoute.play_intermission(Music)

func _cancel_scheduled_title_music() -> void:
	music_request_serial += 1

func _schedule_title_music(delay: float) -> void:
	_cancel_scheduled_title_music()
	var request_id := music_request_serial
	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(self) or request_id != music_request_serial:
			return
		if character_select != null and character_select.visible and Music != null:
			Music.play_profile(&"title")
	)

func _detail_text(extra: String) -> String:
	var control_hint := _ui_text(
		"Controls: WASD move, J attack, K / L / I skills. F10 audio mix.",
		"操作：WASD 移动，J 普攻，K / L / I 技能，F10 音频混音。",
		"操作：WASD 移動，J 普攻，K / L / I 技能，F10 音訊混音。"
	)
	if extra.is_empty():
		return control_hint
	return "%s\n%s" % [extra, control_hint]

func _localized_detail_text(extra: String) -> String:
	var control_hint := _ui_text(
		"Controls: WASD move, J attack, K / L / I skills. F10 audio mix.",
		"操作：WASD 移动，J 普攻，K / L / I 技能。F10 混音。",
		"操作：WASD 移動，J 普攻，K / L / I 技能。F10 混音。"
	)
	if extra.is_empty():
		return control_hint
	return "%s\n%s" % [extra, control_hint]

func _encounter_count() -> int:
	return ENCOUNTER_SCENES.size() + (1 if not FINAL_BOSS_SCENES.is_empty() else 0)

func _encounter_scene_for_index(index: int) -> PackedScene:
	if index < ENCOUNTER_SCENES.size():
		return ENCOUNTER_SCENES[index]
	return FINAL_BOSS_SCENES[randi() % FINAL_BOSS_SCENES.size()]

func _refresh_battle_status(override_title: String = "", override_subtitle: String = "", override_detail: String = "") -> void:
	if battle_status == null or not battle_status.has_method("set_message"):
		return
	if not override_title.is_empty():
		battle_status.set_message(override_title, override_subtitle, override_detail)
	elif current_encounter != null and is_instance_valid(current_encounter) and current_encounter.has_method("get_status_title") and current_encounter.has_method("get_status_text"):
		battle_status.set_message(
			current_encounter.get_status_title(),
			current_encounter.get_status_text(),
			_localized_detail_text(_ui_text(
				"Route: outer rooms use soldiers, Palace Hall uses early bosses, King Gate uses Twin Princes, and the final chamber pulls one of three final bosses.",
				"路线：宫外地图为小兵战，皇宫前厅放第一个 Boss，王门前放双子 Boss。",
				"路線：宮外地圖為小兵戰，皇宮前廳放第一個 Boss，王門前放雙子 Boss。"
			))
		)
	if battle_status.has_method("set_context"):
		battle_status.set_context(_build_battle_status_context())

func _build_battle_status_context() -> Dictionary:
	return {
		"objective": _objective_status_text(),
		"threat": _threat_status_text(),
		"hero": _hero_status_text(),
		"relic": _relic_status_text()
	}

func _objective_status_text() -> String:
	if result_screen != null and result_screen.visible:
		return _ui_text("Review the result and return to champion select.", "查看结算后回到选角界面。", "查看結算後回到選角介面。")
	if pause_menu != null and pause_menu.visible:
		return _ui_text("Resume, tune options, restart, or quit cleanly.", "可以继续、调整设置、重开本局或退出游戏。", "可以繼續、調整設定、重開本局或退出遊戲。")
	if audio_settings_panel != null and audio_settings_panel.has_method("is_open") and bool(audio_settings_panel.is_open()):
		return _ui_text("Adjust the mix without leaving the current run.", "无需离开本局即可调整混音。", "無需離開本局即可調整混音。")
	if settings_panel != null and settings_panel.visible:
		return _ui_text("Adjust display options, then return to the run.", "调整显示选项后返回本局。", "調整顯示選項後返回本局。")
	if accessory_choice != null and accessory_choice.visible:
		var accessory_title := active_accessory_reason if not active_accessory_reason.is_empty() else _ui_text("Relic Offering", "饰品赐予", "飾品賜予")
		return _ui_text("%s: choose one relic before the next fight.", "%s：在下一场战斗前选择一件饰品。", "%s：在下一場戰鬥前選擇一件飾品。") % accessory_title
	if run_event_panel != null and run_event_panel.visible:
		var event_name := RunDirector.describe_event_kind(active_run_event_kind if not active_run_event_kind.is_empty() else RunDirector.peek_next_event_kind())
		return _ui_text("%s: choose one reward.", "%s：选择一项奖励。", "%s：選擇一項獎勵。") % event_name
	if character_select != null and character_select.visible and player_character == null:
		return _ui_text("Select a champion to begin the town trial.", "选择角色，开始城镇试炼。", "選擇角色，開始城鎮試煉。")
	if current_encounter != null and is_instance_valid(current_encounter):
		var objective_text := _ui_text("Encounter %d / %d: clear the arena.", "第 %d / %d 场：清空战场。", "第 %d / %d 場：清空戰場。") % [encounter_index + 1, _encounter_count()]
		if not active_encounter_prep.is_empty():
			objective_text += _ui_text(" Prep %s is active.", " 已生效准备：%s。", " 已生效準備：%s。") % _prep_title(active_encounter_prep)
		return objective_text
	if player_character != null and is_instance_valid(player_character):
		var pending_prep := RunDirector.peek_pending_encounter_prep()
		if not pending_prep.is_empty():
			return _ui_text("Prepare for the next encounter. Prep %s is queued.", "准备下一场战斗，已排队准备：%s。", "準備下一場戰鬥，已排隊準備：%s。") % _prep_title(pending_prep)
		return _ui_text("Prepare for the next encounter. Next event: %s.", "准备下一场战斗。下一事件：%s。", "準備下一場戰鬥。下一事件：%s。") % RunDirector.describe_event_kind(RunDirector.peek_next_event_kind())
	return _ui_text("Pick a champion, then shape the run with relics.", "先选择角色，再用饰品塑造本局路线。", "先選擇角色，再用飾品塑造本局路線。")

func _threat_status_text() -> String:
	if result_screen != null and result_screen.visible:
		return _ui_text("Try a different relic route or hero opener on the next run.", "下次可以换一条饰品路线或改用别的角色开局。", "下次可以換一條飾品路線或改用別的角色開局。")
	if pause_menu != null and pause_menu.visible:
		return _ui_text("Run state is frozen while paused.", "暂停期间，本局状态会被冻结。", "暫停期間，本局狀態會被凍結。")
	if audio_settings_panel != null and audio_settings_panel.has_method("is_open") and bool(audio_settings_panel.is_open()):
		return _ui_text("Audio changes save locally and do not affect combat pacing.", "音频修改只保存在本地，不会影响战斗节奏。", "音訊修改只保存在本地，不會影響戰鬥節奏。")
	if settings_panel != null and settings_panel.visible:
		return _ui_text("Fullscreen and VSync change immediately once selected.", "全屏和垂直同步会在切换后立即生效。", "全螢幕和垂直同步會在切換後立即生效。")
	if accessory_choice != null and accessory_choice.visible:
		return _ui_text("Relic swaps are permanent. Cover a weakness or double down on your build.", "饰品替换是永久性的，优先补短板或继续放大当前构筑。", "飾品替換是永久性的，優先補短板或繼續放大當前構築。")
	if run_event_panel != null and run_event_panel.visible:
		return _event_status_hint(active_run_event_kind)
	if character_select != null and character_select.visible and player_character == null:
		return _ui_text("Knight is safest, Ranger snowballs tempo, Mage controls space and range.", "骑士最稳，游侠滚节奏最快，法师最擅长控场和拉扯。", "騎士最穩，遊俠滾節奏最快，法師最擅長控場和拉扯。")
	if current_encounter != null and is_instance_valid(current_encounter):
		if _current_locale() != "en":
			var pending_text := ""
			if not active_encounter_prep.is_empty():
				pending_text = _ui_text(" 当前准备：%s。", " 当前准备：%s。", " 當前準備：%s。") % _prep_title(active_encounter_prep)
			return _ui_text("Arena pressure is rising. Prioritize ranged and control threats.", "当前战斗压力正在上升，优先处理远程与控制目标。", "當前戰鬥壓力正在上升，優先處理遠程與控制目標。") + pending_text
		var threat_text := _encounter_threat_hint(current_encounter)
		if not active_encounter_prep.is_empty():
			threat_text += " Prep %s." % _prep_summary(active_encounter_prep)
		return threat_text
	if player_character != null and is_instance_valid(player_character):
		var pending_prep := RunDirector.peek_pending_encounter_prep()
		var hp_ratio := _property_ratio(player_character, "hp", "max_hp")
		var defense_ratio := _property_ratio(player_character, "defense", "max_defense")
		if hp_ratio <= 0.40:
			var low_hp_text := _ui_text("Low health. Safe relics or recovery events are worth more than greed here.", "血量偏低，稳健饰品和恢复事件的价值已经高于贪收益。", "血量偏低，穩健飾品和恢復事件的價值已經高於貪收益。")
			if not pending_prep.is_empty():
				low_hp_text += _ui_text(" Queued prep: %s.", " 已排队准备：%s。", " 已排隊準備：%s。") % _prep_title(pending_prep)
			return low_hp_text
		if defense_ratio <= 0.25:
			var low_defense_text := _ui_text("Defense is low. Clean dodges matter until armor is rebuilt.", "护甲偏低，在回稳之前要更重视走位和闪避。", "護甲偏低，在回穩之前要更重視走位和閃避。")
			if not pending_prep.is_empty():
				low_defense_text += _ui_text(" Queued prep: %s.", " 已排队准备：%s。", " 已排隊準備：%s。") % _prep_title(pending_prep)
			return low_defense_text
		if not pending_prep.is_empty():
			return _ui_text("Queued prep: %s.", "已排队准备：%s。", "已排隊準備：%s。") % _prep_summary(pending_prep)
	return _ui_text("The route ramps from mixed enemy waves into four boss checks, ending with a random final boss.", "路线会从普通敌群逐步推进到四场 Boss 检定，并以随机终局 Boss 收尾。", "路線會從普通敵群逐步推進到四場 Boss 檢定，並以隨機終局 Boss 收尾。")

func _hero_status_text() -> String:
	if player_character == null or not is_instance_valid(player_character):
		return _ui_text("No champion selected.", "未选择角色。", "未選擇角色。")
	var hero_name := _hero_display_name(String(player_character.get_character_name())) if player_character.has_method("get_character_name") else _ui_text("Champion", "角色", "角色")
	var run_state := RunDirector.get_state()
	var stats: Array[String] = []
	stats.append("%s %d" % [_ui_text("Lv", "等级", "等級"), int(run_state.get("hero_level", 1))])
	if _has_property(player_character, "hp") and _has_property(player_character, "max_hp"):
		stats.append("%s %d/%d" % [_ui_text("HP", "生命", "生命"), int(round(float(player_character.get("hp")))), int(round(float(player_character.get("max_hp"))))])
	if _has_property(player_character, "defense") and _has_property(player_character, "max_defense"):
		stats.append("%s %d/%d" % [_ui_text("DEF", "护甲", "護甲"), int(round(float(player_character.get("defense")))), int(round(float(player_character.get("max_defense"))))])
	if _has_property(player_character, "inspiration") and _has_property(player_character, "max_inspiration"):
		stats.append("%s %d/%d" % [_ui_text("Insp", "灵感", "靈感"), int(round(float(player_character.get("inspiration")))), int(round(float(player_character.get("max_inspiration"))))])
	stats.append("%s %d/%d" % [_ui_text("XP", "经验", "經驗"), int(run_state.get("hero_xp", 0)), int(run_state.get("hero_xp_to_next", 45))])
	stats.append("%s %d" % [_ui_text("Kills", "击杀", "擊殺"), int(run_state.get("total_kills", 0))])
	return "%s\n%s" % [hero_name, "  |  ".join(stats)] if not stats.is_empty() else hero_name

func _relic_status_text() -> String:
	var equipped_accessory: Dictionary = AccessoryManager.get_equipped_accessory()
	var accessory_name := String(equipped_accessory.get("name", _ui_text("No Accessory", "无饰品", "無飾品")))
	var tags_text := AccessoryManager.describe_tags(equipped_accessory.get("tags", []))
	var summary := String(equipped_accessory.get("summary", ""))
	if accessory_name == _ui_text("No Accessory", "无饰品", "無飾品"):
		return _ui_text("No Accessory\nChoose a relic to shape this run.", "无饰品\n选择一件饰品来决定这一局的构筑方向。", "無飾品\n選擇一件飾品來決定這一局的構築方向。")
	var detail_parts: Array[String] = []
	if not tags_text.is_empty():
		detail_parts.append(tags_text)
	if not summary.is_empty():
		detail_parts.append(summary)
	return "%s\n%s" % [accessory_name, "  |  ".join(detail_parts)] if not detail_parts.is_empty() else accessory_name

func _event_status_hint(kind: String) -> String:
	match kind:
		"services":
			return _ui_text(
				"This crossroads appears once after the town stretch. Church stabilizes, armory sharpens the build, and shop spends gold for a stronger route.",
				"这个岔路只会在城镇段后出现一次。教堂偏恢复，军需库偏长期强化，商店则把金币换成更锋利的路线。",
				"這個岔路只會在城鎮段後出現一次。教堂偏恢復，軍需庫偏長期強化，商店則把金幣換成更鋒利的路線。"
			)
		"shop":
			return _ui_text("Spend gold only where it sharpens the next boss check or patches a real weakness.", "只在能改善下一场 Boss 检定，或能补真实短板的地方花金币。", "只在能改善下一場 Boss 檢定，或能補真實短板的地方花金幣。")
		"bounty":
			return _ui_text("Cash now is best before rerolls or shop buys. Contracts are strongest while multiple fights remain.", "如果后面要重抽或购物，现钱最值；剩余战斗越多，长期契约越强。", "如果後面要重抽或購物，現錢最值；剩餘戰鬥越多，長期契約越強。")
		"rest":
			return _ui_text("Recovery is immediate. Heal if survival is shaky, or refill defense and inspiration if stable.", "恢复会立刻生效。生存吃紧就补血，稳定时就回护甲和灵感。", "恢復會立刻生效。生存吃緊就補血，穩定時就回護甲和靈感。")
		"training":
			return _ui_text("Training is permanent. Reinforce the lane your hero and relic already reward.", "训练是永久收益，优先强化角色与饰品已经在奖励的方向。", "訓練是永久收益，優先強化角色與飾品已經在獎勵的方向。")
		"forge":
			return _ui_text("Forge upgrades are mixed permanents. Use them to lock in a build or repair a real weakness.", "锻造是复合永久强化，适合把构筑定型，或把明显短板补平。", "鍛造是複合永久強化，適合把構築定型，或把明顯短板補平。")
		"pact":
			return _ui_text("Pacts are permanent tradeoffs. Take only the drawback your current hero can absorb.", "契约是永久交换，只拿当前角色扛得住的代价。", "契約是永久交換，只拿當前角色扛得住的代價。")
		"attunement":
			return _ui_text("Attunement is the cleanest way to reinforce the relic identity you already built.", "共鸣最适合继续放大你已经成型的饰品路线。", "共鳴最適合繼續放大你已經成型的飾品路線。")
		"scout":
			return _ui_text("Scout routes are one-fight spikes. Pick the opener that solves the next encounter best.", "侦查路线只强化下一战，优先选择最能解决眼前战局的开局。", "偵查路線只強化下一戰，優先選擇最能解決眼前戰局的開局。")
		_:
			return _ui_text("Choose the cleanest upgrade and keep the route moving.", "选择最顺手的强化，继续推进路线。", "選擇最順手的強化，繼續推進路線。")

func _prep_title(prep: Dictionary) -> String:
	return RunEffects.prep_title(prep)

func _prep_summary(prep: Dictionary) -> String:
	return RunEffects.prep_summary(prep)

func _encounter_threat_hint(encounter: Node) -> String:
	var script_path := _script_path(encounter)
	if script_path.ends_with("town_mob_encounter.gd"):
		var modifier_hint := String(encounter.call("get_modifier_hint")) if encounter.has_method("get_modifier_hint") else ""
		var wave_index := int(encounter.get("wave_index")) if _has_property(encounter, "wave_index") else -1
		var wave_total := 0
		if _has_property(encounter, "active_waves"):
			var active_waves_value: Variant = encounter.get("active_waves")
			if active_waves_value is Array:
				wave_total = (active_waves_value as Array).size()
		if _has_property(encounter, "waiting_for_next_wave") and bool(encounter.get("waiting_for_next_wave")):
			var reset_hint := _ui_text(
				"Wave %d cleared. Reposition before the next pack lands.",
				"第 %d 波已清空，在下一队落位前重新站好位置。",
				"第 %d 波已清空，在下一隊落位前重新站好位置。"
			) % max(wave_index + 1, 1)
			return "%s %s" % [modifier_hint, reset_hint] if not modifier_hint.is_empty() else reset_hint
		if wave_total > 0 and wave_index >= wave_total - 1:
			var final_hint := _ui_text(
				"Final wave mixes elites with arcanist control. Remove ranged pressure first.",
				"最后一波会把精英和奥术控制混在一起，先拆远程压力。",
				"最後一波會把精英和奧術控制混在一起，先拆遠程壓力。"
			)
			return "%s %s" % [modifier_hint, final_hint] if not modifier_hint.is_empty() else final_hint
		var active_enemy_count := 0
		if _has_property(encounter, "active_enemies"):
			var active_enemies_value: Variant = encounter.get("active_enemies")
			if active_enemies_value is Array:
				active_enemy_count = (active_enemies_value as Array).size()
		if active_enemy_count >= 5:
			var crowd_hint := _ui_text(
				"Mixed melee and ranged pressure. Thin archers and mages before hunters collapse.",
				"近战和远程会一起压上来，先削弓手和法师，再处理扑脸的猎手。",
				"近戰和遠程會一起壓上來，先削弓手和法師，再處理撲臉的獵手。"
			)
			return "%s %s" % [modifier_hint, crowd_hint] if not modifier_hint.is_empty() else crowd_hint
		var baseline_hint := _ui_text(
			"Keep space from flankers and do not stand still against ranged telegraphs.",
			"和侧翼单位保持距离，面对远程预警时不要原地站桩。",
			"和側翼單位保持距離，面對遠程預警時不要原地站樁。"
		)
		return "%s %s" % [modifier_hint, baseline_hint] if not modifier_hint.is_empty() else baseline_hint
	if script_path.ends_with("judicator_boss.gd"):
		var state_name := String(encounter.get("state")) if _has_property(encounter, "state") else ""
		var enraged := bool(encounter.get("enraged")) if _has_property(encounter, "enraged") else false
		if enraged:
			if state_name == "skill_1_jump_start" or state_name == "skill_1_slam":
				return _ui_text(
					"Enraged leap adds an aftershock. Leave the landing ring early.",
					"暴怒后的跃击会追加余震，提前离开落点圈。",
					"暴怒後的躍擊會追加餘震，提前離開落點圈。"
				)
			if state_name == "skill_2_charge":
				return _ui_text(
					"Enraged line verdict is wider and longer. Exit the lane immediately.",
					"暴怒后的直线裁决更宽更长，看到线就立刻离开。",
					"暴怒後的直線裁決更寬更長，看到線就立刻離開。"
				)
			return _ui_text(
				"Below 45% HP he enrages, hits harder, and chains leap aftershocks.",
				"血量低于 45% 后会暴怒，伤害更高，还会连带跃击余震。",
				"血量低於 45% 後會暴怒，傷害更高，還會連帶躍擊餘震。"
			)
		if state_name == "skill_1_jump_start" or state_name == "skill_1_slam":
			return _ui_text(
				"Leap slam is committed. Move off the landing ring before impact.",
				"他已经锁定跃击重砸，落地前离开圈内。",
				"他已經鎖定躍擊重砸，落地前離開圈內。"
			)
		if state_name == "skill_2_charge":
			return _ui_text(
				"Line verdict is charging. Side-step the telegraph before the slash fires.",
				"直线裁决正在蓄势，斩出前侧移离线。",
				"直線裁決正在蓄勢，斬出前側移離線。"
			)
		return _ui_text(
			"Respect his cooldowns and save movement for leap or line verdict.",
			"盯住他的技能冷却，把位移留给跃击和直线裁决。",
			"盯住他的技能冷卻，把位移留給躍擊和直線裁決。"
		)
	if script_path.ends_with("royal_guard_formation.gd"):
		var coverage := float(encounter.get("coverage_progress")) if _has_property(encounter, "coverage_progress") else 0.0
		var guard_count := 0
		if _has_property(encounter, "all_guards"):
			var guards_value: Variant = encounter.get("all_guards")
			if guards_value is Array:
				guard_count = (guards_value as Array).size()
		if coverage < 1.0:
			return _ui_text(
				"The formation stays immune until coverage fills. Survive and isolate exposed guards.",
				"覆盖条填满前阵列都处于免疫，先活下来并单抓露头的近卫。",
				"覆蓋條填滿前陣列都處於免疫，先活下來並單抓露頭的近衛。"
			)
		if guard_count > 2:
			return _ui_text(
				"Coverage is broken. Collapse the mobile guards before the crossfire settles.",
				"覆盖已被打破，在交叉火力重新站稳前先收掉机动近卫。",
				"覆蓋已被打破，在交叉火力重新站穩前先收掉機動近衛。"
			)
		return _ui_text(
			"The formation is vulnerable. Clean up the remaining guards quickly.",
			"阵列已经可破，尽快清掉剩余近卫。",
			"陣列已經可破，盡快清掉剩餘近衛。"
		)
	if script_path.ends_with("twin_princes_boss.gd"):
		var phase := int(encounter.get("current_phase")) if _has_property(encounter, "current_phase") else 1
		var state_name := String(encounter.get("state")) if _has_property(encounter, "state") else ""
		var desperate := bool(encounter.get("desperation_active")) if _has_property(encounter, "desperation_active") else false
		if phase == 1:
			if state_name == "teleport_mark" or state_name == "teleport_slash":
				return _ui_text(
					"Blink slash lands beside you. Keep moving so the follow-up whiffs.",
					"跃迁斩会贴身落下，持续移动让后手斩空掉。",
					"躍遷斬會貼身落下，持續移動讓後手斬空掉。"
				)
			if state_name == "spear_charge":
				return _ui_text(
					"Spear charge owns a straight lane. Step off the line early.",
					"枪阵突袭会吃满一整条直线，提前离线。",
					"槍陣突襲會吃滿一整條直線，提前離線。"
				)
			return _ui_text(
				"Phase one alternates blink slash and spear charge with short rests.",
				"一阶段会在跃迁斩和枪阵突袭之间切换，间歇很短。",
				"一階段會在躍遷斬和槍陣突襲之間切換，間歇很短。"
			)
		if state_name == "phase_change":
			return _ui_text(
				"Phase two is arming up. Re-center before barrage patterns start.",
				"二阶段正在起势，在弹幕开始前回到好走位的位置。",
				"二階段正在起勢，在彈幕開始前回到好走位的位置。"
			)
		if desperate:
			if state_name == "barrage_cast":
				return _ui_text(
					"Desperate barrage fires extra bolts and a second wave. Keep distance, then sidestep.",
					"殊死弹幕会多打一轮追加弹，先拉开，再横移躲散射。",
					"殊死彈幕會多打一輪追加彈，先拉開，再橫移躲散射。"
				)
			return _ui_text(
				"Desperate phase speeds up teleports and adds heavier barrage pressure.",
				"殊死阶段会加快跃迁并叠高弹幕压力。",
				"殊死階段會加快躍遷並疊高彈幕壓力。"
			)
		if state_name == "barrage_cast":
			return _ui_text(
				"Royal barrage is casting. Create angle before the bolt spread fans out.",
				"王室弹幕正在施放，先拉出角度再躲散开的弹群。",
				"王室彈幕正在施放，先拉出角度再躲散開的彈群。"
			)
		return _ui_text(
			"Phase two adds barrage pressure and shorter recovery windows.",
			"二阶段会加入弹幕压制，而且留给你的喘息更短。",
			"二階段會加入彈幕壓制，而且留給你的喘息更短。"
		)
	return _ui_text(
		"Read telegraphs, preserve space, and do not spend movement too early.",
		"先看预警、留住空间，不要太早把位移交掉。",
		"先看預警、留住空間，不要太早把位移交掉。"
	)

func _script_path(target: Object) -> String:
	if target == null:
		return ""
	var script_value: Variant = target.get_script()
	if script_value is Script:
		return String((script_value as Script).resource_path)
	return ""

func _property_ratio(target: Object, current_field: String, max_field: String) -> float:
	if not _has_property(target, current_field) or not _has_property(target, max_field):
		return 1.0
	var max_value := float(target.get(max_field))
	if max_value <= 0.0:
		return 1.0
	return clampf(float(target.get(current_field)) / max_value, 0.0, 1.0)

func _has_property(target: Object, field: String) -> bool:
	if target == null:
		return false
	for property in target.get_property_list():
		if String(property.get("name", "")) == field:
			return true
	return false

func _sync_audio_hint_state() -> void:
	if audio_shortcut_hint == null or not audio_shortcut_hint.has_method("set_panel_open"):
		return
	var panel_open := false
	if audio_settings_panel != null and audio_settings_panel.has_method("is_open"):
		panel_open = bool(audio_settings_panel.is_open())
	if panel_open == audio_panel_was_open:
		return
	audio_panel_was_open = panel_open
	audio_shortcut_hint.set_panel_open(panel_open)

func _on_pause_resume_requested() -> void:
	return_pause_after_audio_panel = false
	return_pause_after_settings_panel = false
	if pause_menu != null and pause_menu.has_method("close"):
		pause_menu.close()
	_refresh_battle_status()

func _on_pause_audio_requested() -> void:
	return_pause_after_audio_panel = true
	if pause_menu != null:
		if pause_menu.has_method("suspend"):
			pause_menu.suspend()
		else:
			pause_menu.visible = false
	if audio_settings_panel != null and audio_settings_panel.has_method("show_panel"):
		audio_settings_panel.show_panel()
	_sync_audio_hint_state()
	_refresh_battle_status()

func _on_pause_settings_requested() -> void:
	return_pause_after_settings_panel = true
	if pause_menu != null:
		if pause_menu.has_method("suspend"):
			pause_menu.suspend()
		else:
			pause_menu.visible = false
	if settings_panel != null and settings_panel.has_method("open"):
		settings_panel.open()
	_refresh_battle_status()

func _on_pause_restart_requested() -> void:
	if pause_menu != null and pause_menu.has_method("close"):
		pause_menu.close()
	_reset_to_character_select()

func _on_title_audio_requested() -> void:
	return_pause_after_audio_panel = false
	if audio_settings_panel != null and audio_settings_panel.has_method("show_panel"):
		audio_settings_panel.show_panel()
	_sync_audio_hint_state()
	_refresh_battle_status()

func _on_title_settings_requested() -> void:
	return_pause_after_settings_panel = false
	if settings_panel != null and settings_panel.has_method("open"):
		settings_panel.open()
	_refresh_battle_status()

func _on_audio_settings_panel_closed() -> void:
	if return_pause_after_audio_panel:
		return_pause_after_audio_panel = false
		if pause_menu != null and pause_menu.has_method("resume_from_submenu"):
			pause_menu.resume_from_submenu()
		elif pause_menu != null and pause_menu.has_method("open"):
			pause_menu.open()
	_sync_audio_hint_state()
	_refresh_battle_status()

func _on_settings_panel_closed() -> void:
	if return_pause_after_settings_panel:
		return_pause_after_settings_panel = false
		if pause_menu != null and pause_menu.has_method("resume_from_submenu"):
			pause_menu.resume_from_submenu()
		elif pause_menu != null and pause_menu.has_method("open"):
			pause_menu.open()
	_refresh_battle_status()

func _on_quit_requested() -> void:
	return_pause_after_audio_panel = false
	return_pause_after_settings_panel = false
	if pause_menu != null and pause_menu.has_method("close") and bool(pause_menu.is_open()):
		pause_menu.close()
	get_tree().paused = false
	get_tree().quit()

func _on_result_closed() -> void:
	_reset_to_character_select()

func _reset_to_character_select() -> void:
	_cancel_scheduled_title_music()
	if audio_settings_panel != null and audio_settings_panel.has_method("hide_panel"):
		audio_settings_panel.hide_panel()
	if accessory_choice != null and accessory_choice.has_method("close") and accessory_choice.visible:
		accessory_choice.close()
	if run_event_panel != null and run_event_panel.has_method("close") and run_event_panel.visible:
		run_event_panel.close()
	if current_encounter != null and is_instance_valid(current_encounter):
		current_encounter.queue_free()
	current_encounter = null
	if player_character != null and is_instance_valid(player_character):
		player_character.queue_free()
	player_character = null
	encounter_index = -1
	waiting_for_accessory_choice = false
	active_accessory_reason = ""
	active_accessory_source = ""
	active_run_event_kind = ""
	active_encounter_prep.clear()
	return_pause_after_audio_panel = false
	return_pause_after_settings_panel = false
	AccessoryManager.reset_run()
	RunDirector.reset_run()
	if character_select != null:
		character_select.visible = true
	_update_screen_layers()
	_refresh_battle_status(
		_ui_text("Town Boss Trial", "城镇王战试炼", "城鎮王戰試煉"),
		_ui_text("Pick a champion, then claim relics between encounters.", "先选择角色，再在战斗间隙领取饰品。", "先選擇角色，再在戰鬥間隙領取飾品。"),
		_localized_detail_text("")
	)
	if Music != null:
		Music.play_profile(&"title")

func _update_screen_layers() -> void:
	var in_title_menu := character_select != null and character_select.visible and player_character == null and (result_screen == null or not result_screen.visible)
	if character_hud != null:
		character_hud.visible = not in_title_menu
	if battle_status != null:
		battle_status.visible = not in_title_menu
	if pause_menu != null and in_title_menu and pause_menu.visible:
		pause_menu.close()

func _current_locale() -> String:
	if UISettings != null and UISettings.has_method("get_locale"):
		return String(UISettings.get_locale())
	return "zh_Hans"

func _ui_text(en_text: String, zh_hans_text: String, zh_hant_text: String) -> String:
	match _current_locale():
		"zh_Hant":
			return zh_hant_text
		"zh_Hans":
			return zh_hans_text
		_:
			return en_text

func _hero_display_name(hero_name: String) -> String:
	match hero_name:
		"Knight":
			return _ui_text("Knight", "骑士", "騎士")
		"Ranger":
			return _ui_text("Ranger", "游侠", "遊俠")
		"Mage":
			return _ui_text("Mage", "法师", "法師")
		_:
			return hero_name

func _spawn_attack_hit_feedback(world_position: Vector2, strong: bool, defeated: bool) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var ring := Line2D.new()
	ring.width = 3.0 if strong else 2.0
	ring.closed = true
	ring.default_color = Color(1.0, 0.82, 0.64, 0.92) if strong else Color(0.82, 0.96, 1.0, 0.86)
	ring.points = _build_feedback_ring_points(18.0 if strong else 14.0, 10)
	ring.global_position = world_position
	scene_root.add_child(ring)
	var ring_tween := create_tween()
	ring_tween.tween_property(ring, "scale", Vector2.ONE * (1.45 if strong else 1.22), 0.14)
	ring_tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.14)
	ring_tween.finished.connect(ring.queue_free)
	if not defeated:
		return
	var burst := Line2D.new()
	burst.width = 2.5
	burst.closed = true
	burst.default_color = Color(1.0, 0.88, 0.56, 0.95)
	burst.points = _build_feedback_burst_points(10.0, 22.0, 8)
	burst.global_position = world_position
	scene_root.add_child(burst)
	var burst_tween := create_tween()
	burst_tween.tween_property(burst, "rotation", TAU * 0.22, 0.18)
	burst_tween.parallel().tween_property(burst, "scale", Vector2.ONE * 1.34, 0.18)
	burst_tween.parallel().tween_property(burst, "modulate:a", 0.0, 0.18)
	burst_tween.finished.connect(burst.queue_free)

func _build_feedback_ring_points(radius: float, point_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(point_count):
		var angle := TAU * float(index) / float(max(point_count, 1))
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points

func _build_feedback_burst_points(inner_radius: float, outer_radius: float, point_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(point_count * 2):
		var angle := TAU * float(index) / float(max(point_count * 2, 1))
		var radius := outer_radius if index % 2 == 0 else inner_radius
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points

func _is_target_defeated(target: Node) -> bool:
	for property in target.get_property_list():
		if String(property.get("name", "")) == "hp":
			return float(target.get("hp")) <= 0.0
	return false
