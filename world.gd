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
const HIT_FEEDBACK_COOLDOWN_MSEC := 55

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
var active_run_event_kind: String = ""
var return_pause_after_audio_panel: bool = false
var return_pause_after_settings_panel: bool = false
var last_attack_feedback_msec: int = 0

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
		"Town Boss Trial",
		"Pick a champion, then claim relics between encounters.",
		_detail_text("")
	)
	if Music != null:
		Music.play_profile(&"title", true)
	if audio_shortcut_hint != null and audio_shortcut_hint.has_method("show_hint"):
		audio_shortcut_hint.show_hint(true)

func _process(_delta: float) -> void:
	_sync_audio_hint_state()
	_refresh_battle_status()

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
	active_run_event_kind = ""
	return_pause_after_audio_panel = false
	return_pause_after_settings_panel = false
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
	_refresh_battle_status()

func _on_encounter_defeated() -> void:
	var reward := RunDirector.reward_encounter(encounter_index, player_character)
	current_encounter = null
	var defeated_final_encounter := encounter_index >= ENCOUNTER_SCENES.size() - 1
	_refresh_battle_status(
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
	_refresh_battle_status(
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
	_refresh_battle_status()
	waiting_for_accessory_choice = false
	active_accessory_reason = ""

func _offer_accessory(reason: String) -> void:
	if accessory_choice == null or not accessory_choice.has_method("open"):
		_start_next_encounter()
		return
	waiting_for_accessory_choice = true
	active_accessory_reason = reason
	active_run_event_kind = ""
	var choices := AccessoryManager.generate_choices(3)
	accessory_choice.open(choices, player_character, reason, RELIC_REROLL_COST, int(RunDirector.gold))
	_refresh_battle_status(
		reason,
		"Choose a relic before the next fight.",
		_detail_text("Current: %s" % String(AccessoryManager.get_equipped_accessory().get("name", "No Accessory")))
	)

func _offer_next_run_event() -> void:
	var kind := RunDirector.next_event_kind()
	if kind == "relic" or run_event_panel == null or not run_event_panel.has_method("open"):
		_offer_accessory("Victory Relic")
		return
	active_run_event_kind = kind
	run_event_panel.open(kind, int(RunDirector.gold))
	_refresh_battle_status(
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
	_refresh_battle_status(
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
	_refresh_battle_status(
		"Relic Rerolled",
		"New relic choices are available.",
		_detail_text("Gold: %d" % int(RunDirector.gold))
	)

func _on_run_event_choice_made(choice_id: String) -> void:
	var applied := _apply_run_event_choice(choice_id)
	if Sfx != null:
		_play_ui_feedback(applied)
	if not applied and choice_id != "skip":
		if active_run_event_kind != "" and run_event_panel != null and run_event_panel.has_method("open"):
			run_event_panel.open(active_run_event_kind, int(RunDirector.gold))
		_refresh_battle_status(
			"Not Enough Gold",
			"Choose another reward or skip the event.",
			_detail_text("Gold: %d" % int(RunDirector.gold))
		)
		return
	_refresh_battle_status(
		"Event Complete",
		_run_event_summary(choice_id),
		_detail_text("Gold: %d" % int(RunDirector.gold))
	)
	active_run_event_kind = ""
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
	_refresh_battle_status(
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

func _refresh_battle_status(override_title: String = "", override_subtitle: String = "", override_detail: String = "") -> void:
	if battle_status == null or not battle_status.has_method("set_message"):
		return
	if not override_title.is_empty():
		battle_status.set_message(override_title, override_subtitle, override_detail)
	elif current_encounter != null and is_instance_valid(current_encounter) and current_encounter.has_method("get_status_title") and current_encounter.has_method("get_status_text"):
		battle_status.set_message(
			current_encounter.get_status_title(),
			current_encounter.get_status_text(),
			_detail_text("Encounter order: Town Enemies -> Judicator -> Guard Formation -> Twin Princes")
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
		return "Review the result and return to champion select."
	if pause_menu != null and pause_menu.visible:
		return "Resume, tune options, restart, or quit cleanly."
	if audio_settings_panel != null and audio_settings_panel.has_method("is_open") and bool(audio_settings_panel.is_open()):
		return "Adjust the mix without leaving the current run."
	if settings_panel != null and settings_panel.visible:
		return "Adjust display options, then return to the run."
	if accessory_choice != null and accessory_choice.visible:
		var accessory_title := active_accessory_reason if not active_accessory_reason.is_empty() else "Relic Offering"
		return "%s: choose one relic before the next fight." % accessory_title
	if run_event_panel != null and run_event_panel.visible:
		var event_name := RunDirector.describe_event_kind(active_run_event_kind if not active_run_event_kind.is_empty() else RunDirector.peek_next_event_kind())
		return "%s: choose one reward." % event_name
	if character_select != null and character_select.visible and player_character == null:
		return "Select a champion to begin the town trial."
	if current_encounter != null and is_instance_valid(current_encounter):
		return "Encounter %d / %d: clear the arena." % [encounter_index + 1, ENCOUNTER_SCENES.size()]
	if player_character != null and is_instance_valid(player_character):
		return "Prepare for the next encounter. Next event: %s." % RunDirector.describe_event_kind(RunDirector.peek_next_event_kind())
	return "Pick a champion, then shape the run with relics."

func _threat_status_text() -> String:
	if result_screen != null and result_screen.visible:
		return "Try a different relic route or hero opener on the next run."
	if pause_menu != null and pause_menu.visible:
		return "Run state is frozen while paused."
	if audio_settings_panel != null and audio_settings_panel.has_method("is_open") and bool(audio_settings_panel.is_open()):
		return "Audio changes save locally and do not affect combat pacing."
	if settings_panel != null and settings_panel.visible:
		return "Fullscreen and VSync change immediately once selected."
	if accessory_choice != null and accessory_choice.visible:
		return "Relic swaps are permanent. Cover a weakness or double down on your build."
	if run_event_panel != null and run_event_panel.visible:
		return _event_status_hint(active_run_event_kind)
	if character_select != null and character_select.visible and player_character == null:
		return "Knight is safest, Ranger snowballs tempo, Mage controls space and range."
	if current_encounter != null and is_instance_valid(current_encounter):
		return _encounter_threat_hint(current_encounter)
	if player_character != null and is_instance_valid(player_character):
		var hp_ratio := _property_ratio(player_character, "hp", "max_hp")
		var defense_ratio := _property_ratio(player_character, "defense", "max_defense")
		if hp_ratio <= 0.40:
			return "Low health. Safe relics or recovery events are worth more than greed here."
		if defense_ratio <= 0.25:
			return "Defense is low. Clean dodges matter until armor is rebuilt."
	return "The route ramps from mixed enemy waves into three boss checks."

func _hero_status_text() -> String:
	if player_character == null or not is_instance_valid(player_character):
		return "No champion selected."
	var hero_name := String(player_character.get_character_name()) if player_character.has_method("get_character_name") else "Champion"
	var stats: Array[String] = []
	if _has_property(player_character, "hp") and _has_property(player_character, "max_hp"):
		stats.append("HP %d/%d" % [int(round(float(player_character.get("hp")))), int(round(float(player_character.get("max_hp"))))])
	if _has_property(player_character, "defense") and _has_property(player_character, "max_defense"):
		stats.append("DEF %d/%d" % [int(round(float(player_character.get("defense")))), int(round(float(player_character.get("max_defense"))))])
	if _has_property(player_character, "inspiration") and _has_property(player_character, "max_inspiration"):
		stats.append("Insp %d/%d" % [int(round(float(player_character.get("inspiration")))), int(round(float(player_character.get("max_inspiration"))))])
	return "%s\n%s" % [hero_name, "  |  ".join(stats)] if not stats.is_empty() else hero_name

func _relic_status_text() -> String:
	var equipped_accessory: Dictionary = AccessoryManager.get_equipped_accessory()
	var accessory_name := String(equipped_accessory.get("name", "No Accessory"))
	var tags_text := AccessoryManager.describe_tags(equipped_accessory.get("tags", []))
	var summary := String(equipped_accessory.get("summary", ""))
	if accessory_name == "No Accessory":
		return "No Accessory\nChoose a relic to shape this run."
	var detail_parts: Array[String] = []
	if not tags_text.is_empty():
		detail_parts.append(tags_text)
	if not summary.is_empty():
		detail_parts.append(summary)
	return "%s\n%s" % [accessory_name, "  |  ".join(detail_parts)] if not detail_parts.is_empty() else accessory_name

func _event_status_hint(kind: String) -> String:
	match kind:
		"shop":
			return "Spend gold only where it sharpens the next boss check or patches a real weakness."
		"bounty":
			return "Cash now is best before rerolls or shop buys. Contracts are strongest while multiple fights remain."
		"rest":
			return "Recovery is immediate. Heal if survival is shaky, or refill defense and inspiration if stable."
		"training":
			return "Training is permanent. Reinforce the lane your hero and relic already reward."
		"pact":
			return "Pacts are permanent tradeoffs. Take only the drawback your current hero can absorb."
		"attunement":
			return "Attunement is the cleanest way to reinforce the relic identity you already built."
		_:
			return "Choose the cleanest upgrade and keep the route moving."

func _encounter_threat_hint(encounter: Node) -> String:
	var script_path := _script_path(encounter)
	if script_path.ends_with("town_mob_encounter.gd"):
		var wave_index := int(encounter.get("wave_index")) if _has_property(encounter, "wave_index") else -1
		var wave_total := 0
		if _has_property(encounter, "active_waves"):
			var active_waves_value: Variant = encounter.get("active_waves")
			if active_waves_value is Array:
				wave_total = (active_waves_value as Array).size()
		if _has_property(encounter, "waiting_for_next_wave") and bool(encounter.get("waiting_for_next_wave")):
			return "Wave %d cleared. Reposition before the next pack lands." % max(wave_index + 1, 1)
		if wave_total > 0 and wave_index >= wave_total - 1:
			return "Final wave mixes elites with arcanist control. Remove ranged pressure first."
		var active_enemy_count := 0
		if _has_property(encounter, "active_enemies"):
			var active_enemies_value: Variant = encounter.get("active_enemies")
			if active_enemies_value is Array:
				active_enemy_count = (active_enemies_value as Array).size()
		if active_enemy_count >= 5:
			return "Mixed melee and ranged pressure. Thin archers and mages before hunters collapse."
		return "Keep space from flankers and do not stand still against ranged telegraphs."
	if script_path.ends_with("judicator_boss.gd"):
		var state_name := String(encounter.get("state")) if _has_property(encounter, "state") else ""
		var enraged := bool(encounter.get("enraged")) if _has_property(encounter, "enraged") else false
		if enraged:
			if state_name == "skill_1_jump_start" or state_name == "skill_1_slam":
				return "Enraged leap adds an aftershock. Leave the landing ring early."
			if state_name == "skill_2_charge":
				return "Enraged line verdict is wider and longer. Exit the lane immediately."
			return "Below 45% HP he enrages, hits harder, and chains leap aftershocks."
		if state_name == "skill_1_jump_start" or state_name == "skill_1_slam":
			return "Leap slam is committed. Move off the landing ring before impact."
		if state_name == "skill_2_charge":
			return "Line verdict is charging. Side-step the telegraph before the slash fires."
		return "Respect his cooldowns and save movement for leap or line verdict."
	if script_path.ends_with("royal_guard_formation.gd"):
		var coverage := float(encounter.get("coverage_progress")) if _has_property(encounter, "coverage_progress") else 0.0
		var guard_count := 0
		if _has_property(encounter, "all_guards"):
			var guards_value: Variant = encounter.get("all_guards")
			if guards_value is Array:
				guard_count = (guards_value as Array).size()
		if coverage < 1.0:
			return "The formation stays immune until coverage fills. Survive and isolate exposed guards."
		if guard_count > 2:
			return "Coverage is broken. Collapse the mobile guards before the crossfire settles."
		return "The formation is vulnerable. Clean up the remaining guards quickly."
	if script_path.ends_with("twin_princes_boss.gd"):
		var phase := int(encounter.get("current_phase")) if _has_property(encounter, "current_phase") else 1
		var state_name := String(encounter.get("state")) if _has_property(encounter, "state") else ""
		var desperate := bool(encounter.get("desperation_active")) if _has_property(encounter, "desperation_active") else false
		if phase == 1:
			if state_name == "teleport_mark" or state_name == "teleport_slash":
				return "Blink slash lands beside you. Keep moving so the follow-up whiffs."
			if state_name == "spear_charge":
				return "Spear charge owns a straight lane. Step off the line early."
			return "Phase one alternates blink slash and spear charge with short rests."
		if state_name == "phase_change":
			return "Phase two is arming up. Re-center before barrage patterns start."
		if desperate:
			if state_name == "barrage_cast":
				return "Desperate barrage fires extra bolts and a second wave. Keep distance, then sidestep."
			return "Desperate phase speeds up teleports and adds heavier barrage pressure."
		if state_name == "barrage_cast":
			return "Royal barrage is casting. Create angle before the bolt spread fans out."
		return "Phase two adds barrage pressure and shorter recovery windows."
	return "Read telegraphs, preserve space, and do not spend movement too early."

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
	active_run_event_kind = ""
	return_pause_after_audio_panel = false
	return_pause_after_settings_panel = false
	AccessoryManager.reset_run()
	RunDirector.reset_run()
	if character_select != null:
		character_select.visible = true
	_refresh_battle_status(
		"Town Boss Trial",
		"Pick a champion, then claim relics between encounters.",
		_detail_text("")
	)
	if Music != null:
		Music.play_profile(&"title")

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
