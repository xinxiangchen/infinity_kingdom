class_name UISkin
extends RefCounted

const FONT_LATIN := "res://assets/fonts/fusion_pixel_latin.ttf"
const FONT_ZH_HANS := "res://assets/fonts/fusion_pixel_zh_hans.ttf"
const FONT_ZH_HANT := "res://assets/fonts/fusion_pixel_zh_hant.ttf"

const COLOR_BG := Color(0.06, 0.07, 0.09, 0.96)
const COLOR_BG_ALT := Color(0.10, 0.11, 0.14, 0.96)
const COLOR_PANEL := Color(0.12, 0.13, 0.16, 0.96)
const COLOR_PANEL_ALT := Color(0.15, 0.16, 0.19, 0.98)
const COLOR_BORDER := Color(0.76, 0.74, 0.62, 0.92)
const COLOR_BORDER_ALT := Color(0.48, 0.56, 0.68, 0.9)
const COLOR_ACCENT := Color(0.92, 0.88, 0.64, 1.0)
const COLOR_TEXT := Color(0.92, 0.94, 0.98, 1.0)
const COLOR_MUTED := Color(0.72, 0.76, 0.84, 1.0)
const COLOR_WARN := Color(0.96, 0.72, 0.62, 1.0)

static var _font_cache: Dictionary = {}

static func asset(path: String) -> String:
	return "res://assets/ui/%s" % path

static func tex(path: String) -> Texture2D:
	return load(path) as Texture2D

static func texture_style(_path: String, _margin: int = 32, _content: int = 12) -> StyleBox:
	return flat_style(COLOR_PANEL_ALT, COLOR_BORDER_ALT, 1, 3)

static func active_font() -> FontFile:
	var locale := "zh_Hans"
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		var ui_settings := tree.root.get_node_or_null("/root/UISettings")
		if ui_settings != null and ui_settings.has_method("get_locale"):
			locale = String(ui_settings.get_locale())
	var path := FONT_ZH_HANS
	if locale == "en":
		path = FONT_LATIN
	elif locale == "zh_Hant":
		path = FONT_ZH_HANT
	if not _font_cache.has(path):
		_font_cache[path] = load(path)
	return _font_cache[path] as FontFile

static func font_for_locale(locale: String) -> FontFile:
	var path := FONT_ZH_HANS
	if locale == "en":
		path = FONT_LATIN
	elif locale == "zh_Hant":
		path = FONT_ZH_HANT
	if not _font_cache.has(path):
		_font_cache[path] = load(path)
	return _font_cache[path] as FontFile

static func flat_style(bg: Color, border: Color, border_width: int = 2, radius: int = 4, margins: Vector4 = Vector4(12, 10, 12, 10)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margins.x
	style.content_margin_top = margins.y
	style.content_margin_right = margins.z
	style.content_margin_bottom = margins.w
	style.shadow_color = Color(0, 0, 0, 0.24)
	style.shadow_size = 2
	return style

static func panel_style() -> StyleBox:
	return flat_style(COLOR_BG, COLOR_BORDER, 2, 4, Vector4(14, 12, 14, 12))

static func menu_panel_style() -> StyleBox:
	return flat_style(COLOR_PANEL, COLOR_BORDER, 2, 4, Vector4(16, 14, 16, 14))

static func content_panel_style() -> StyleBox:
	return flat_style(COLOR_PANEL_ALT, COLOR_BORDER_ALT, 1, 3, Vector4(12, 10, 12, 10))

static func choice_panel_style() -> StyleBox:
	return flat_style(COLOR_PANEL, COLOR_BORDER_ALT, 2, 4, Vector4(16, 14, 16, 14))

static func icon_slot_style() -> StyleBox:
	return flat_style(COLOR_BG_ALT, COLOR_BORDER, 2, 3, Vector4(6, 6, 6, 6))

static func placeholder_box_style() -> StyleBox:
	return flat_style(Color(0.18, 0.19, 0.22, 0.92), Color(0.56, 0.58, 0.66, 0.9), 1, 2, Vector4(10, 10, 10, 10))

static func placeholder_box(min_size: Vector2, caption: String, tint: Color = COLOR_MUTED) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	panel.add_theme_stylebox_override("panel", placeholder_box_style())
	var label_value := Label.new()
	label_value.text = caption
	label_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label(label_value, 12, tint)
	panel.add_child(label_value)
	return panel

static func button_styles(button: Button, size: String = "medium") -> void:
	var min_height := 42.0
	if size == "large":
		min_height = 54.0
	elif size == "small":
		min_height = 34.0
	elif size == "thin":
		min_height = 34.0
	button.custom_minimum_size.y = min_height
	button.add_theme_stylebox_override("normal", flat_style(COLOR_PANEL_ALT, COLOR_BORDER, 2, 3, Vector4(12, 8, 12, 8)))
	button.add_theme_stylebox_override("hover", flat_style(Color(0.20, 0.22, 0.26, 0.98), COLOR_ACCENT, 2, 3, Vector4(12, 8, 12, 8)))
	button.add_theme_stylebox_override("pressed", flat_style(Color(0.10, 0.11, 0.14, 1.0), COLOR_ACCENT.darkened(0.2), 2, 3, Vector4(12, 8, 12, 8)))
	button.add_theme_stylebox_override("disabled", flat_style(Color(0.12, 0.13, 0.15, 0.72), Color(0.34, 0.36, 0.40, 0.8), 1, 3, Vector4(12, 8, 12, 8)))
	_apply_button_text(button)

static func label(label_value: Label, size: int, color: Color = COLOR_TEXT) -> void:
	label_value.remove_theme_font_override("font")
	label_value.add_theme_font_size_override("font_size", size)
	label_value.add_theme_color_override("font_color", color)
	label_value.add_theme_constant_override("line_spacing", 2)

static func texture_bar(bar: TextureProgressBar, meter: String) -> void:
	bar.texture_under = null
	bar.texture_progress = null
	bar.texture_over = null
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 1.0
	bar.add_theme_stylebox_override("background", flat_style(Color(0.08, 0.09, 0.12, 1.0), COLOR_BORDER_ALT, 1, 2, Vector4(0, 0, 0, 0)))
	var fill_color := Color(0.82, 0.28, 0.26)
	if meter == "defense":
		fill_color = Color(0.36, 0.68, 0.86)
	elif meter == "inspiration" or meter == "mana":
		fill_color = Color(0.38, 0.56, 0.98)
	bar.tint_progress = fill_color
	bar.tint_under = Color(0.10, 0.11, 0.14)

static func ignore_mouse_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		ignore_mouse_recursive(child)

static func _apply_button_text(button: Button) -> void:
	button.remove_theme_font_override("font")
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", COLOR_ACCENT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", COLOR_ACCENT.darkened(0.2))
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
