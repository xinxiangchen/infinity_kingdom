extends Node2D

const KNIGHT_SCENE := preload("res://characters/knight/knight.tscn")
const RANGER_SCENE := preload("res://characters/ranger/ranger.tscn")
const MAGE_SCENE := preload("res://characters/mage/mage.tscn")
const RunEffects := preload("res://systems/run/run_effects.gd")
const ENCOUNTER_SCENES := [
	preload("res://actors/encounters/town_mob_encounter.tscn"),
	preload("res://actors/bosses/town/judicator_boss.tscn"),
	preload("res://actors/bosses/town/royal_guard_formation.tscn"),
	preload("res://actors/bosses/town/twin_princes_boss.tscn")
]
const CONTROL_HINT := "Controls: WASD move, J attack, K / L / I skills. F10 audio mix."
const RELIC_REROLL_COST := 20

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

func _ready() -> void:
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
		pause_menu.resume_requested.connect(_on_pause_resume_requested)
		pause_menu.audio_requested.connect(_on_pause_audio_requested)
		pause_menu.settings_requested.connect(_on_pause_settings_requested)
		pause_menu.restart_requested.connect(_on_pause_restart_requested)
		pause_menu.quit_requested.connect(_on_quit_requested)
	if result_screen != null and result_screen.has_signal("closed"):
		result_screen.closed.connect(_on_result_closed)
	if debug_panel != null and debug_panel.has_method("bind_world"):
		debug_panel.bind_world(self)
	if battle_status != null and battle_status.has_method("set_message"):
		battle_status.set_message(
			"Town Boss Trial",
			"Pick a champion, then claim relics between encounters.",
			_detail_text("")
		)
	if Music != null:
		Music.play_profile(&"title", true)
	if audio_shortcut_hint != null and audio_shortcut_hint.has_method("show_hint"):
		audio_shortcut_hint.show_hint(true)

func _process(_delta: float) -> void:
	if battle_status == null or not battle_status.has_method("set_message"):
		return
	_sync_audio_hint_state()
	if current_encounter != null and is_instance_valid(current_encounter) and current_encounter.has_method("get_status_title") and current_encounter.has_method("get_status_text"):
		battle_status.set_message(
			current_encounter.get_status_title(),
			current_encounter.get_status_text(),
			_detail_text("Encounter order: Town Enemies -> Judicator -> Guard Formation -> Twin Princes")
		)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if InputMap.has_action("debug_toggle") and event.is_action_pressed("debug_toggle"):
			if debug_panel != null and debug_panel.has_method("toggle"):
				debug_panel.toggle()
				get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F10:
			if audio_settings_panel != null and audio_settings_panel.has_method("toggle_panel"):
				audio_settings_panel.toggle_panel()
				_sync_audio_hint_state()
				get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE:
			if audio_settings_panel != null and audio_settings_panel.has_method("is_open") and bool(audio_settings_panel.is_open()):
				audio_settings_panel.hide_panel()
				_sync_audio_hint_state()
				get_viewport().set_input_as_handled()
				return
			if settings_panel != null and settings_panel.visible:
				settings_panel.close()
				get_viewport().set_input_as_handled()
				return
			if pause_menu != null and pause_menu.has_method("is_open") and bool(pause_menu.is_open()):
				pause_menu.close()
				get_viewport().set_input_as_handled()
				return
			if accessory_choice != null and accessory_choice.visible:
				return
			if run_event_panel != null and run_event_panel.visible:
				return
			if pause_menu != null and pause_menu.has_method("open"):
				pause_menu.open()
				get_viewport().set_input_as_handled()
				return

func _on_character_selected(character_id: StringName) -> void:
	_cancel_scheduled_title_music()
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
	player_character.position = spawn_marker.position
	add_child(player_character)
	player_character.z_index = 3
	if character_select != null:
		character_select.visible = false
	if character_hud != null and character_hud.has_method("bind_character"):
		character_hud.bind_character(player_character)
	AccessoryManager.apply_to_actor(player_character)
	RunEffects.refresh_persistent_modifiers(player_character)
	_bind_actor_audio(player_character)
	if player_character.has_signal("died"):
		player_character.died.connect(_on_player_died)
	encounter_index = -1
	_offer_accessory("First Relic")

func _start_next_encounter() -> void:
	waiting_for_accessory_choice = false
	active_accessory_reason = ""
	encounter_index += 1
	if encounter_index >= ENCOUNTER_SCENES.size():
		_complete_run_victory()
		return
	_play_audio_profile_for_encounter(encounter_index)
	current_encounter = ENCOUNTER_SCENES[encounter_index].instantiate()
	current_encounter.position = encounter_marker.position
	encounter_root.add_child(current_encounter)
	if current_encounter.has_method("bind_player"):
		current_encounter.bind_player(player_character)
	if current_encounter.has_signal("defeated"):
		current_encounter.defeated.connect(_on_encounter_defeated)

func _on_encounter_defeated() -> void:
	var reward := RunDirector.reward_encounter(encounter_index, player_character)
	current_encounter = null
	var defeated_final_encounter := encounter_index >= ENCOUNTER_SCENES.size() - 1
	if battle_status != null and battle_status.has_method("set_message"):
		battle_status.set_message(
			"Trial Complete" if defeated_final_encounter else "Encounter Cleared",
			"+%d gold earned." % reward,
			_detail_text("Gold: %d" % int(RunDirector.gold))
		)
	var timer := get_tree().create_timer(1.1)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self) and player_character != null and is_instance_valid(player_character) and float(player_character.hp) > 0.0:
			if defeated_final_encounter:
				_complete_run_victory()
			else:
				_offer_next_run_event()
	)

func _on_player_died() -> void:
	if current_encounter != null and is_instance_valid(current_encounter):
		current_encounter.queue_free()
	current_encounter = null
	if Music != null:
		Music.play_profile(&"defeat")
	_schedule_title_music(2.4)
	if battle_status != null and battle_status.has_method("set_message"):
		battle_status.set_message(
			"Defeated",
			"The town boss rush resets after death.",
			_detail_text("Pick a champion to restart.")
		)
	if character_select != null:
		character_select.visible = true
	if result_screen != null and result_screen.has_method("show_result"):
		result_screen.show_result(
			"defeat",
			"Defeated",
			"The town boss rush resets after death.",
			"Continue to return to champion selection and try a different relic path."
		)
	waiting_for_accessory_choice = false
	active_accessory_reason = ""

func _offer_accessory(reason: String) -> void:
	if accessory_choice == null or not accessory_choice.has_method("open"):
		_start_next_encounter()
		return
	waiting_for_accessory_choice = true
	active_accessory_reason = reason
	var choices := AccessoryManager.generate_choices(3)
	accessory_choice.open(choices, player_character, reason, RELIC_REROLL_COST, int(RunDirector.gold))
	if battle_status != null and battle_status.has_method("set_message"):
		battle_status.set_message(
			reason,
			"Choose a relic before the next fight.",
			_detail_text("Current: %s" % String(AccessoryManager.get_equipped_accessory().get("name", "No Accessory")))
		)

func _offer_next_run_event() -> void:
	var kind := RunDirector.next_event_kind()
	if kind == "relic" or run_event_panel == null or not run_event_panel.has_method("open"):
		_offer_accessory("Victory Relic")
		return
	run_event_panel.open(kind, int(RunDirector.gold))
	if battle_status != null and battle_status.has_method("set_message"):
		battle_status.set_message(
			"Run Event",
			"Choose a reward before the next fight.",
			_detail_text("Gold: %d" % int(RunDirector.gold))
		)

func _on_accessory_choice_made(_accessory_id: String, kept_current: bool) -> void:
	waiting_for_accessory_choice = false
	active_accessory_reason = ""
	if player_character != null and is_instance_valid(player_character):
		RunEffects.refresh_persistent_modifiers(player_character)
	if Sfx != null:
		_play_ui_feedback(true)
	var accessory_name := String(AccessoryManager.get_equipped_accessory().get("name", "No Accessory"))
	if battle_status != null and battle_status.has_method("set_message"):
		battle_status.set_message(
			"Relic Kept" if kept_current else "Relic Equipped",
			accessory_name,
			_detail_text("The next encounter begins now.")
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
	var reason := active_accessory_reason if not active_accessory_reason.is_empty() else "Relic Offering"
	var choices := AccessoryManager.generate_choices(3)
	accessory_choice.open(choices, player_character, reason, RELIC_REROLL_COST, int(RunDirector.gold))
	if battle_status != null and battle_status.has_method("set_message"):
		battle_status.set_message(
			"Relic Rerolled",
			"New relic choices are available.",
			_detail_text("Gold: %d" % int(RunDirector.gold))
		)

func _on_run_event_choice_made(choice_id: String) -> void:
	var applied := _apply_run_event_choice(choice_id)
	if Sfx != null:
		_play_ui_feedback(applied)
	if battle_status != null and battle_status.has_method("set_message"):
		battle_status.set_message(
			"Event Complete" if applied else "Not Enough Gold",
			_run_event_summary(choice_id) if applied else "Choose another reward next time.",
			_detail_text("Gold: %d" % int(RunDirector.gold))
		)
	if choice_id == "shop_relic" and applied:
		_offer_accessory("Purchased Relic")
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
	if battle_status != null and battle_status.has_method("set_message"):
		battle_status.set_message(
			"Town Cleared",
			"All enemy waves and town boss encounters are defeated.",
			_detail_text("Pick another champion to restart the sequence.")
		)
	if character_select != null:
		character_select.visible = true
	if result_screen != null and result_screen.has_method("show_result"):
		result_screen.show_result(
			"victory",
			"Town Cleared",
			"All enemy waves and bosses are defeated.",
			"Your relic build survived the trial. Continue to select a new champion."
		)

func _bind_actor_audio(actor: Node) -> void:
	if actor == null:
		return
	if actor.has_signal("attack_started") and not actor.attack_started.is_connected(_on_actor_attack_started):
		actor.attack_started.connect(_on_actor_attack_started.bind(actor))
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

func _on_actor_died(actor: Node) -> void:
	if actor == null or not actor.has_method("get_character_name") or Sfx == null:
		return
	var event_id := "%s_dead" % String(actor.get_character_name()).to_lower()
	Sfx.play_event(StringName(event_id), actor.global_position)

func _play_audio_profile_for_encounter(next_encounter_index: int) -> void:
	if Music == null:
		return
	if next_encounter_index <= 0:
		Music.play_profile(&"town_battle")
	else:
		Music.play_profile(&"town_boss")

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
	if extra.is_empty():
		return CONTROL_HINT
	return "%s\n%s" % [extra, CONTROL_HINT]

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
	if pause_menu != null and pause_menu.has_method("close"):
		pause_menu.close()

func _on_pause_audio_requested() -> void:
	if pause_menu != null and pause_menu.has_method("close"):
		pause_menu.close()
	if audio_settings_panel != null and audio_settings_panel.has_method("show_panel"):
		audio_settings_panel.show_panel()
	_sync_audio_hint_state()

func _on_pause_settings_requested() -> void:
	if pause_menu != null and pause_menu.has_method("close"):
		pause_menu.close()
	if settings_panel != null and settings_panel.has_method("open"):
		settings_panel.open()

func _on_pause_restart_requested() -> void:
	if pause_menu != null and pause_menu.has_method("close"):
		pause_menu.close()
	_reset_to_character_select()

func _on_title_audio_requested() -> void:
	if audio_settings_panel != null and audio_settings_panel.has_method("show_panel"):
		audio_settings_panel.show_panel()
	_sync_audio_hint_state()

func _on_title_settings_requested() -> void:
	if settings_panel != null and settings_panel.has_method("open"):
		settings_panel.open()

func _on_quit_requested() -> void:
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
	AccessoryManager.reset_run()
	RunDirector.reset_run()
	if character_select != null:
		character_select.visible = true
	if battle_status != null and battle_status.has_method("set_message"):
		battle_status.set_message(
			"Town Boss Trial",
			"Pick a champion, then claim relics between encounters.",
			_detail_text("")
		)
	if Music != null:
		Music.play_profile(&"title")
