extends Node

const SAVE_SLOT_SELECT_SCRIPT := preload("res://ui/save_slot_select.gd")
const OPENING_PROLOGUE_SCRIPT := preload("res://ui/opening_prologue.gd")
const UISkin := preload("res://ui/ui_skin.gd")

@onready var character_select: CanvasLayer = $CharacterSelect
@onready var play_mode_select: CanvasLayer = $PlayModeSelect
@onready var settings_panel: CanvasLayer = $SettingsPanel

var selected_character_id: StringName = &""
var selected_slot_index: int = -1
var save_slot_select: CanvasLayer = null
var opening_prologue: CanvasLayer = null
var cheat_notice_layer: CanvasLayer = null
var cheat_notice_panel: PanelContainer = null
var cheat_notice_label: Label = null
var cheat_notice_tween: Tween = null


func _ready() -> void:
	_build_save_slot_select()
	_build_opening_prologue()
	_build_cheat_notice()
	if character_select != null:
		character_select.character_selected.connect(_on_character_selected)
		if character_select.has_signal("settings_requested"):
			character_select.settings_requested.connect(_on_settings_requested)
		if character_select.has_signal("quit_requested"):
			character_select.quit_requested.connect(_on_quit_requested)
	if play_mode_select != null:
		play_mode_select.normal_requested.connect(_on_normal_requested)
		play_mode_select.debug_requested.connect(_on_debug_requested)
		play_mode_select.back_requested.connect(_on_mode_back_requested)
	if Music != null:
		Music.play_profile(&"title", true)
	_show_save_slots()

func _build_save_slot_select() -> void:
	save_slot_select = SAVE_SLOT_SELECT_SCRIPT.new()
	save_slot_select.name = "SaveSlotSelect"
	add_child(save_slot_select)
	save_slot_select.slot_selected.connect(_on_save_slot_selected)
	save_slot_select.new_slot_requested.connect(_on_new_slot_requested)
	save_slot_select.quit_requested.connect(_on_quit_requested)

func _build_opening_prologue() -> void:
	opening_prologue = OPENING_PROLOGUE_SCRIPT.new()
	opening_prologue.name = "OpeningPrologue"
	add_child(opening_prologue)
	opening_prologue.finished.connect(_on_opening_prologue_finished)

func _build_cheat_notice() -> void:
	cheat_notice_layer = CanvasLayer.new()
	cheat_notice_layer.name = "CheatNotice"
	cheat_notice_layer.layer = 40
	add_child(cheat_notice_layer)

	var margin := MarginContainer.new()
	margin.anchor_left = 0.0
	margin.anchor_top = 0.0
	margin.anchor_right = 1.0
	margin.anchor_bottom = 0.0
	margin.offset_left = 36.0
	margin.offset_top = 30.0
	margin.offset_right = -36.0
	margin.offset_bottom = 96.0
	cheat_notice_layer.add_child(margin)

	cheat_notice_panel = PanelContainer.new()
	cheat_notice_panel.visible = false
	cheat_notice_panel.modulate = Color(1, 1, 1, 0)
	cheat_notice_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	cheat_notice_panel.add_theme_stylebox_override(
		"panel",
		UISkin.flat_style(Color(0.08, 0.11, 0.12, 0.94), Color(0.56, 0.94, 1.0, 0.95), 2, 6, Vector4(18, 10, 18, 10))
	)
	margin.add_child(cheat_notice_panel)

	cheat_notice_label = Label.new()
	cheat_notice_label.text = ""
	cheat_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UISkin.label(cheat_notice_label, 15, Color(0.86, 0.98, 1.0))
	cheat_notice_panel.add_child(cheat_notice_label)

func _show_save_slots() -> void:
	selected_slot_index = -1
	selected_character_id = &""
	if save_slot_select != null:
		save_slot_select.visible = true
	if character_select != null:
		character_select.visible = false
	if play_mode_select != null and play_mode_select.has_method("close"):
		play_mode_select.close()

func _on_save_slot_selected(slot_index: int) -> void:
	selected_slot_index = slot_index
	var slot := {}
	if SaveManager != null:
		slot = SaveManager.select_slot(slot_index)
	if save_slot_select != null:
		save_slot_select.visible = false
	var family_id := String(slot.get("family_id", ""))
	if not family_id.is_empty():
		selected_character_id = _character_id_for_family_id(family_id)
		_on_normal_requested()
		return
	if character_select != null:
		character_select.visible = true

func _on_new_slot_requested(slot_index: int) -> void:
	selected_slot_index = slot_index
	if SaveManager != null:
		SaveManager.create_slot(slot_index, "Archive %d" % (slot_index + 1))
	if save_slot_select != null:
		save_slot_select.visible = false
	if opening_prologue != null and opening_prologue.has_method("open"):
		opening_prologue.open()
		return
	if character_select != null:
		character_select.visible = true

func _on_opening_prologue_finished() -> void:
	if character_select != null:
		character_select.visible = true

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var title_visible := (save_slot_select != null and save_slot_select.visible) or (character_select != null and character_select.visible)
	if title_visible and CheatMode != null and CheatMode.input_event_key(event):
		_show_cheat_notice()
		get_viewport().set_input_as_handled()

func _show_cheat_notice() -> void:
	if cheat_notice_panel == null or cheat_notice_label == null:
		return
	cheat_notice_label.text = _locale_text(
		"Cheat Mode Active - Infinite HP enabled",
		"作弊模式已启用 - 无限生命生效",
		"作弊模式已啟用 - 無限生命生效"
	)
	cheat_notice_panel.visible = true
	cheat_notice_panel.modulate = Color(1, 1, 1, 0)
	if cheat_notice_tween != null and cheat_notice_tween.is_valid():
		cheat_notice_tween.kill()
	cheat_notice_tween = create_tween()
	cheat_notice_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	cheat_notice_tween.tween_property(cheat_notice_panel, "modulate:a", 1.0, 0.12)
	cheat_notice_tween.tween_interval(2.4)
	cheat_notice_tween.tween_property(cheat_notice_panel, "modulate:a", 0.0, 0.24)
	cheat_notice_tween.tween_callback(func() -> void:
		if cheat_notice_panel != null:
			cheat_notice_panel.visible = false
	)

func _on_character_selected(character_id: StringName) -> void:
	selected_character_id = character_id
	if character_select != null:
		character_select.visible = false
	_on_normal_requested()


func _on_normal_requested() -> void:
	StartupContext.set_pending_start(&"normal", selected_character_id, selected_slot_index)
	get_tree().change_scene_to_file("res://world.tscn")


func _on_debug_requested() -> void:
	StartupContext.set_pending_start(&"debug", selected_character_id, selected_slot_index)
	get_tree().change_scene_to_file("res://tools/character_debug_world.tscn")


func _on_mode_back_requested() -> void:
	selected_character_id = &""
	if play_mode_select != null and play_mode_select.has_method("close"):
		play_mode_select.close()
	if character_select != null:
		character_select.visible = true


func _on_settings_requested() -> void:
	if settings_panel != null and settings_panel.has_method("open"):
		settings_panel.open()


func _on_quit_requested() -> void:
	get_tree().quit()

func _locale_text(en_text: String, zh_hans_text: String, zh_hant_text: String) -> String:
	if UISettings != null and UISettings.has_method("get_locale"):
		match String(UISettings.get_locale()):
			"zh_Hant":
				return zh_hant_text
			"zh_Hans":
				return zh_hans_text
	return en_text

func _character_id_for_family_id(family_id: String) -> StringName:
	match family_id:
		"ranger":
			return &"ranger"
		"mage":
			return &"mage"
		_:
			return &"knight"
