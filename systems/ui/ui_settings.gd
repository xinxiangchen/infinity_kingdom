extends Node

signal locale_changed(locale: String)

const SETTINGS_PATH := "user://ui_settings.cfg"
const SECTION_UI := "ui"
const KEY_LOCALE := "locale"
const FONT_LATIN := "res://assets/fonts/fusion_pixel_latin.ttf"
const FONT_ZH_HANS := "res://assets/fonts/fusion_pixel_zh_hans.ttf"
const FONT_ZH_HANT := "res://assets/fonts/fusion_pixel_zh_hant.ttf"

const LOCALE_ZH_HANS := "zh_Hans"
const LOCALE_EN := "en"
const LOCALE_ZH_HANT := "zh_Hant"
const LOCALES := [LOCALE_ZH_HANS, LOCALE_EN, LOCALE_ZH_HANT]

const LANGUAGE_LABELS := {
	LOCALE_ZH_HANS: "简体中文",
	LOCALE_EN: "English",
	LOCALE_ZH_HANT: "繁體中文"
}

var current_locale: String = LOCALE_ZH_HANS

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		current_locale = String(config.get_value(SECTION_UI, KEY_LOCALE, LOCALE_ZH_HANS))
	if not LOCALES.has(current_locale):
		current_locale = LOCALE_ZH_HANS
	_apply_theme_font()
	locale_changed.emit(current_locale)

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION_UI, KEY_LOCALE, current_locale)
	config.save(SETTINGS_PATH)

func set_locale(locale: String, persist: bool = true) -> void:
	if not LOCALES.has(locale):
		return
	if current_locale == locale:
		return
	current_locale = locale
	_apply_theme_font()
	if persist:
		save_settings()
	locale_changed.emit(current_locale)

func get_locale() -> String:
	return current_locale

func get_language_label(locale: String = current_locale) -> String:
	return String(LANGUAGE_LABELS.get(locale, locale))

func _apply_theme_font() -> void:
	var font_path := FONT_ZH_HANS
	if current_locale == LOCALE_EN:
		font_path = FONT_LATIN
	elif current_locale == LOCALE_ZH_HANT:
		font_path = FONT_ZH_HANT
	var font_file := load(font_path) as FontFile
	if font_file == null:
		return
	ThemeDB.fallback_font = font_file
	ThemeDB.fallback_font_size = 16
