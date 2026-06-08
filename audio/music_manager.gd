extends Node

const BUS_MUSIC := "Music"
const BUS_AMBIENCE := "Ambience"
const BUS_SFX := "SFX"
const BUS_UI := "UI"
const BUS_MASTER := "Master"
const MASTER_DEFAULT_VOLUME_DB := 0.0

const SETTINGS_PATH := "user://audio_settings.cfg"

const SEARCH_DIRS := [
	"res://audio/music",
	"res://audio/generated",
	"res://audio/ambience"
]

const SUPPORTED_EXTENSIONS := [
	".wav",
	".ogg",
	".mp3"
]

const BUS_DEFAULT_VOLUMES := {
	BUS_MUSIC: -10.5,
	BUS_AMBIENCE: -15.5,
	BUS_SFX: -0.8,
	BUS_UI: -4.0
}

const CUE_LIBRARY := {
	"title": {
		"file": "music_title_loop",
		"volume_db": -4.2,
		"loop": true,
		"fade": 1.1,
		"preview_from": 6.0,
		"preview_length": 1.8
	},
	"town_battle": {
		"file": "music_town_battle_loop",
		"volume_db": -2.8,
		"loop": true,
		"fade": 0.9,
		"preview_from": 4.8,
		"preview_length": 1.7
	},
	"town_boss": {
		"file": "music_town_boss_loop",
		"volume_db": -1.9,
		"loop": true,
		"fade": 0.75,
		"preview_from": 4.2,
		"preview_length": 1.8
	},
	"palace_explore": {
		"file": "music_palace_explore_loop",
		"volume_db": -2.2,
		"loop": true,
		"fade": 0.8,
		"preview_from": 5.0,
		"preview_length": 1.8
	},
	"gate_guard": {
		"file": "music_gate_guard_loop",
		"volume_db": -1.8,
		"loop": true,
		"fade": 0.75,
		"preview_from": 4.8,
		"preview_length": 1.8
	},
	"emperor": {
		"file": "music_emperor_loop",
		"volume_db": -1.5,
		"loop": true,
		"fade": 0.65,
		"preview_from": 5.0,
		"preview_length": 1.8
	},
	"church_intermission": {
		"file": "music_church_intermission_loop",
		"volume_db": -3.0,
		"loop": true,
		"fade": 0.9,
		"preview_from": 6.0,
		"preview_length": 1.8
	},
	"victory": {
		"file": "music_victory_stinger",
		"volume_db": -1.4,
		"loop": false,
		"fade": 0.35,
		"preview_from": 0.0,
		"preview_length": 1.4
	},
	"defeat": {
		"file": "music_defeat_stinger",
		"volume_db": -2.1,
		"loop": false,
		"fade": 0.25,
		"preview_from": 0.0,
		"preview_length": 1.4
	}
}

const AMBIENCE_CUE_LIBRARY := {
	"title": {
		"file": "ambience_town_title_loop",
		"volume_db": -10.0,
		"loop": true,
		"fade": 1.4,
		"preview_from": 7.0,
		"preview_length": 1.9
	},
	"town_battle": {
		"file": "ambience_town_battle_loop",
		"volume_db": -7.6,
		"loop": true,
		"fade": 1.0,
		"preview_from": 5.2,
		"preview_length": 1.7
	},
	"town_boss": {
		"file": "ambience_town_boss_loop",
		"volume_db": -6.2,
		"loop": true,
		"fade": 0.85,
		"preview_from": 6.6,
		"preview_length": 2.0
	}
}

const PROFILE_LIBRARY := {
	"title": {
		"music": &"title",
		"ambience": &"title"
	},
	"town_battle": {
		"music": &"town_battle",
		"ambience": &"town_battle"
	},
	"town_boss": {
		"music": &"town_boss",
		"ambience": &"town_boss"
	},
	"twin_princes": {
		"music": &"town_boss",
		"ambience": &"town_boss"
	},
	"palace_explore": {
		"music": &"palace_explore",
		"ambience": &"town_boss"
	},
	"gate_guard": {
		"music": &"gate_guard",
		"ambience": &"town_boss"
	},
	"emperor": {
		"music": &"emperor",
		"ambience": &"town_boss"
	},
	"church_intermission": {
		"music": &"church_intermission",
		"ambience": &"title"
	},
	"victory": {
		"music": &"victory",
		"ambience": &""
	},
	"defeat": {
		"music": &"defeat",
		"ambience": &""
	}
}

const SILENT_DB := -40.0

var stream_cache: Dictionary = {}
var missing_tracks: Dictionary = {}
var bus_saved_volumes: Dictionary = {}
var bus_muted_state: Dictionary = {}
var master_muted: bool = false
var master_saved_volume_db: float = MASTER_DEFAULT_VOLUME_DB
var players: Array[AudioStreamPlayer] = []
var ambience_players: Array[AudioStreamPlayer] = []
var preview_players: Dictionary = {}
var preview_serials: Dictionary = {}
var current_cue_id: StringName = &""
var current_ambience_id: StringName = &""
var active_player_index: int = -1
var active_ambience_player_index: int = -1
var crossfade_tween: Tween = null
var ambience_tween: Tween = null
var duck_tween: Tween = null
var audio_runtime_available: bool = true

func _ready() -> void:
	_ensure_bus_layout()
	_ensure_master_bus_state()
	_initialize_bus_state()
	load_bus_settings()
	audio_runtime_available = DisplayServer.get_name() != "headless"
	if not audio_runtime_available:
		return
	_build_players()
	_build_ambience_players()
	_build_preview_players()
	play_profile(&"title", true)

func _exit_tree() -> void:
	if crossfade_tween != null:
		crossfade_tween.kill()
		crossfade_tween = null
	if ambience_tween != null:
		ambience_tween.kill()
		ambience_tween = null
	if duck_tween != null:
		duck_tween.kill()
		duck_tween = null
	for player in players:
		if player == null or not is_instance_valid(player):
			continue
		player.stop()
		player.stream = null
	for player in ambience_players:
		if player == null or not is_instance_valid(player):
			continue
		player.stop()
		player.stream = null
	for key in preview_players.keys():
		var preview_player: AudioStreamPlayer = preview_players[key]
		if preview_player == null or not is_instance_valid(preview_player):
			continue
		preview_player.stop()
		preview_player.stream = null
	players.clear()
	ambience_players.clear()
	preview_players.clear()
	preview_serials.clear()
	stream_cache.clear()
	missing_tracks.clear()

func play_profile(profile_id: StringName, instant: bool = false) -> bool:
	if not audio_runtime_available:
		return false
	var profile: Dictionary = PROFILE_LIBRARY.get(String(profile_id), {})
	if profile.is_empty():
		return false
	var played := false
	var music_cue: StringName = profile.get("music", &"")
	var ambience_cue: StringName = profile.get("ambience", &"")
	if music_cue != &"":
		played = play_cue(music_cue, instant) or played
	if ambience_cue != &"":
		played = play_ambience_cue(ambience_cue, instant) or played
	else:
		stop_ambience(instant)
	return played

func play_cue(cue_id: StringName, instant: bool = false) -> bool:
	if not audio_runtime_available or cue_id == &"":
		return false
	var cue: Dictionary = _get_cue_definition(cue_id)
	if cue.is_empty():
		return false
	if current_cue_id == cue_id and active_player_index >= 0 and players[active_player_index].playing:
		return true
	var stream := _get_stream(String(cue.get("file", "")))
	if stream == null:
		return false
	var next_player_index := 0 if active_player_index != 0 else 1
	if active_player_index < 0:
		next_player_index = 0
	var incoming_player := players[next_player_index]
	incoming_player.stop()
	incoming_player.stream = stream
	incoming_player.bus = BUS_MUSIC
	incoming_player.set_meta("cue_id", String(cue_id))
	incoming_player.set_meta("loop_enabled", bool(cue.get("loop", false)))
	incoming_player.volume_db = SILENT_DB if active_player_index >= 0 and not instant else float(cue.get("volume_db", 0.0))
	incoming_player.play()
	if crossfade_tween != null:
		crossfade_tween.kill()
		crossfade_tween = null
	var previous_player_index := active_player_index
	current_cue_id = cue_id
	active_player_index = next_player_index
	if previous_player_index < 0 or instant:
		incoming_player.volume_db = float(cue.get("volume_db", 0.0))
		if previous_player_index >= 0 and previous_player_index < players.size() and previous_player_index != next_player_index:
			players[previous_player_index].stop()
			players[previous_player_index].stream = null
		return true
	var outgoing_player := players[previous_player_index]
	var fade_duration := maxf(float(cue.get("fade", 0.8)), 0.05)
	crossfade_tween = create_tween()
	crossfade_tween.tween_property(incoming_player, "volume_db", float(cue.get("volume_db", 0.0)), fade_duration)
	crossfade_tween.parallel().tween_property(outgoing_player, "volume_db", SILENT_DB, fade_duration)
	crossfade_tween.finished.connect(func() -> void:
		if is_instance_valid(outgoing_player):
			outgoing_player.stop()
			outgoing_player.stream = null
		crossfade_tween = null
	)
	return true

func play_ambience_cue(cue_id: StringName, instant: bool = false) -> bool:
	if not audio_runtime_available or cue_id == &"":
		return false
	var cue: Dictionary = _get_ambience_cue_definition(cue_id)
	if cue.is_empty():
		return false
	if current_ambience_id == cue_id and active_ambience_player_index >= 0 and ambience_players[active_ambience_player_index].playing:
		return true
	var stream := _get_stream(String(cue.get("file", "")))
	if stream == null:
		return false
	var next_player_index := 0 if active_ambience_player_index != 0 else 1
	if active_ambience_player_index < 0:
		next_player_index = 0
	var incoming_player := ambience_players[next_player_index]
	incoming_player.stop()
	incoming_player.stream = stream
	incoming_player.bus = BUS_AMBIENCE
	incoming_player.set_meta("cue_id", String(cue_id))
	incoming_player.set_meta("loop_enabled", bool(cue.get("loop", false)))
	incoming_player.volume_db = SILENT_DB if active_ambience_player_index >= 0 and not instant else float(cue.get("volume_db", 0.0))
	incoming_player.play()
	if ambience_tween != null:
		ambience_tween.kill()
		ambience_tween = null
	var previous_player_index := active_ambience_player_index
	current_ambience_id = cue_id
	active_ambience_player_index = next_player_index
	if previous_player_index < 0 or instant:
		incoming_player.volume_db = float(cue.get("volume_db", 0.0))
		if previous_player_index >= 0 and previous_player_index < ambience_players.size() and previous_player_index != next_player_index:
			ambience_players[previous_player_index].stop()
			ambience_players[previous_player_index].stream = null
		return true
	var outgoing_player := ambience_players[previous_player_index]
	var fade_duration := maxf(float(cue.get("fade", 1.0)), 0.05)
	ambience_tween = create_tween()
	ambience_tween.tween_property(incoming_player, "volume_db", float(cue.get("volume_db", 0.0)), fade_duration)
	ambience_tween.parallel().tween_property(outgoing_player, "volume_db", SILENT_DB, fade_duration)
	ambience_tween.finished.connect(func() -> void:
		if is_instance_valid(outgoing_player):
			outgoing_player.stop()
			outgoing_player.stream = null
		ambience_tween = null
	)
	return true

func stop_ambience(instant: bool = false) -> void:
	current_ambience_id = &""
	if not audio_runtime_available or active_ambience_player_index < 0 or active_ambience_player_index >= ambience_players.size():
		active_ambience_player_index = -1
		return
	if ambience_tween != null:
		ambience_tween.kill()
		ambience_tween = null
	var active_player := ambience_players[active_ambience_player_index]
	if active_player == null or not is_instance_valid(active_player):
		active_ambience_player_index = -1
		return
	if instant:
		active_player.stop()
		active_player.stream = null
		active_ambience_player_index = -1
		return
	ambience_tween = create_tween()
	ambience_tween.tween_property(active_player, "volume_db", SILENT_DB, 0.55)
	ambience_tween.finished.connect(func() -> void:
		if is_instance_valid(active_player):
			active_player.stop()
			active_player.stream = null
		active_ambience_player_index = -1
		ambience_tween = null
	)

func duck_music(amount_db: float = -5.0, attack: float = 0.04, hold: float = 0.18, release: float = 0.55) -> void:
	if not audio_runtime_available:
		return
	if is_bus_muted(BUS_MUSIC):
		return
	var bus_index := AudioServer.get_bus_index(BUS_MUSIC)
	if bus_index < 0:
		return
	if duck_tween != null:
		duck_tween.kill()
	var base_volume := get_bus_volume(BUS_MUSIC)
	var ducked_volume := base_volume + minf(amount_db, 0.0)
	duck_tween = create_tween()
	duck_tween.tween_method(_set_music_bus_volume, AudioServer.get_bus_volume_db(bus_index), ducked_volume, maxf(attack, 0.01))
	duck_tween.tween_interval(maxf(hold, 0.0))
	duck_tween.tween_method(_set_music_bus_volume, ducked_volume, base_volume, maxf(release, 0.01))
	duck_tween.finished.connect(func() -> void:
		_set_music_bus_volume(base_volume)
		duck_tween = null
	)

func set_bus_volume(bus_name: StringName, volume_db: float, persist: bool = true) -> void:
	var bus_index := AudioServer.get_bus_index(String(bus_name))
	if bus_index < 0:
		return
	var bus_key := String(bus_name)
	var clamped_volume := maxf(volume_db, SILENT_DB)
	var was_muted := bool(bus_muted_state.get(bus_key, false))
	if clamped_volume <= SILENT_DB + 0.01:
		bus_muted_state[bus_key] = true
		bus_saved_volumes[bus_key] = SILENT_DB
		AudioServer.set_bus_volume_db(bus_index, SILENT_DB)
	else:
		bus_saved_volumes[bus_key] = clamped_volume
		if was_muted:
			bus_muted_state[bus_key] = true
			AudioServer.set_bus_volume_db(bus_index, SILENT_DB)
		else:
			bus_muted_state[bus_key] = false
			AudioServer.set_bus_volume_db(bus_index, clamped_volume)
	if persist:
		save_bus_settings()

func get_bus_volume(bus_name: StringName) -> float:
	var bus_index := AudioServer.get_bus_index(String(bus_name))
	if bus_index < 0:
		return float(BUS_DEFAULT_VOLUMES.get(String(bus_name), 0.0))
	return AudioServer.get_bus_volume_db(bus_index)

func get_bus_display_volume(bus_name: StringName) -> float:
	var bus_key := String(bus_name)
	if bool(bus_muted_state.get(bus_key, false)):
		return float(bus_saved_volumes.get(bus_key, float(BUS_DEFAULT_VOLUMES.get(bus_key, 0.0))))
	return get_bus_volume(bus_name)

func get_default_bus_volume(bus_name: StringName) -> float:
	return float(BUS_DEFAULT_VOLUMES.get(String(bus_name), 0.0))

func get_master_volume() -> float:
	var master_bus_index := AudioServer.get_bus_index(BUS_MASTER)
	if master_bus_index < 0:
		return MASTER_DEFAULT_VOLUME_DB
	return AudioServer.get_bus_volume_db(master_bus_index)

func get_master_display_volume() -> float:
	return master_saved_volume_db if master_muted else get_master_volume()

func get_default_master_volume() -> float:
	return MASTER_DEFAULT_VOLUME_DB

func set_master_volume(volume_db: float, persist: bool = true) -> void:
	var master_bus_index := AudioServer.get_bus_index(BUS_MASTER)
	if master_bus_index < 0:
		return
	var clamped_volume := maxf(volume_db, SILENT_DB)
	master_saved_volume_db = clamped_volume
	AudioServer.set_bus_volume_db(master_bus_index, clamped_volume)
	if persist:
		save_bus_settings()

func is_master_muted() -> bool:
	return master_muted

func set_master_muted(muted: bool, persist: bool = true) -> void:
	master_muted = muted
	var master_bus_index := AudioServer.get_bus_index(BUS_MASTER)
	if master_bus_index >= 0:
		AudioServer.set_bus_mute(master_bus_index, muted)
	if persist:
		save_bus_settings()

func toggle_master_muted() -> void:
	set_master_muted(not master_muted)

func is_bus_muted(bus_name: StringName) -> bool:
	return bool(bus_muted_state.get(String(bus_name), false))

func set_bus_muted(bus_name: StringName, muted: bool, persist: bool = true) -> void:
	var bus_key := String(bus_name)
	var bus_index := AudioServer.get_bus_index(bus_key)
	if bus_index < 0:
		return
	if muted:
		if not bool(bus_muted_state.get(bus_key, false)):
			var current_volume := AudioServer.get_bus_volume_db(bus_index)
			if current_volume > SILENT_DB + 0.01:
				bus_saved_volumes[bus_key] = current_volume
		bus_muted_state[bus_key] = true
		AudioServer.set_bus_volume_db(bus_index, SILENT_DB)
	else:
		bus_muted_state[bus_key] = false
		var restored_volume := float(bus_saved_volumes.get(bus_key, float(BUS_DEFAULT_VOLUMES.get(bus_key, 0.0))))
		AudioServer.set_bus_volume_db(bus_index, restored_volume)
	if persist:
		save_bus_settings()

func toggle_bus_muted(bus_name: StringName) -> void:
	set_bus_muted(bus_name, not is_bus_muted(bus_name))

func reset_bus_settings() -> void:
	set_master_muted(false, false)
	set_master_volume(MASTER_DEFAULT_VOLUME_DB, false)
	for bus_name in _get_bus_names():
		bus_saved_volumes[bus_name] = float(BUS_DEFAULT_VOLUMES[bus_name])
		bus_muted_state[bus_name] = false
		set_bus_volume(StringName(bus_name), float(BUS_DEFAULT_VOLUMES[bus_name]), false)
	save_bus_settings()

func save_bus_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("master", "muted", master_muted)
	config.set_value("master", "volume_db", get_master_display_volume())
	for bus_name in _get_bus_names():
		config.set_value("bus", bus_name, get_bus_display_volume(StringName(bus_name)))
		config.set_value("mute", bus_name, is_bus_muted(StringName(bus_name)))
	config.save(SETTINGS_PATH)

func load_bus_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	var master_volume_db := float(config.get_value("master", "volume_db", MASTER_DEFAULT_VOLUME_DB))
	master_saved_volume_db = master_volume_db
	set_master_volume(master_volume_db, false)
	set_master_muted(bool(config.get_value("master", "muted", false)), false)
	for bus_name in _get_bus_names():
		var volume_db := float(config.get_value("bus", bus_name, float(BUS_DEFAULT_VOLUMES[bus_name])))
		bus_saved_volumes[bus_name] = volume_db
		var is_muted := bool(config.get_value("mute", bus_name, false))
		if is_muted:
			bus_muted_state[bus_name] = true
			set_bus_muted(StringName(bus_name), true, false)
		else:
			bus_muted_state[bus_name] = false
			set_bus_volume(StringName(bus_name), volume_db, false)

func _build_players() -> void:
	if not players.is_empty():
		return
	for index in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "MusicPlayer%d" % index
		player.bus = BUS_MUSIC
		player.finished.connect(_on_player_finished.bind(index))
		add_child(player)
		players.append(player)

func _build_ambience_players() -> void:
	if not ambience_players.is_empty():
		return
	for index in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "AmbiencePlayer%d" % index
		player.bus = BUS_AMBIENCE
		player.finished.connect(_on_ambience_player_finished.bind(index))
		add_child(player)
		ambience_players.append(player)

func _build_preview_players() -> void:
	if not preview_players.is_empty():
		return
	for bus_name in [BUS_MUSIC, BUS_AMBIENCE]:
		var player := AudioStreamPlayer.new()
		player.name = "%sPreviewPlayer" % bus_name
		player.bus = bus_name
		add_child(player)
		preview_players[bus_name] = player
		preview_serials[bus_name] = 0

func _ensure_bus_layout() -> void:
	for bus_name in _get_bus_names():
		_ensure_bus(bus_name, float(BUS_DEFAULT_VOLUMES[bus_name]))

func _ensure_master_bus_state() -> void:
	var master_bus_index := AudioServer.get_bus_index(BUS_MASTER)
	if master_bus_index < 0:
		return
	AudioServer.set_bus_volume_db(master_bus_index, MASTER_DEFAULT_VOLUME_DB)
	AudioServer.set_bus_mute(master_bus_index, false)

func _initialize_bus_state() -> void:
	for bus_name in _get_bus_names():
		if not bus_saved_volumes.has(bus_name):
			bus_saved_volumes[bus_name] = float(BUS_DEFAULT_VOLUMES[bus_name])
		if not bus_muted_state.has(bus_name):
			bus_muted_state[bus_name] = false
	master_saved_volume_db = MASTER_DEFAULT_VOLUME_DB

func _ensure_bus(bus_name: String, volume_db: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		AudioServer.add_bus(AudioServer.get_bus_count())
		bus_index = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_send(bus_index, "Master")
	AudioServer.set_bus_volume_db(bus_index, volume_db)

func _get_bus_names() -> Array:
	return [BUS_MUSIC, BUS_AMBIENCE, BUS_SFX, BUS_UI]

func _get_cue_definition(cue_id: StringName) -> Dictionary:
	return CUE_LIBRARY.get(String(cue_id), {})

func _get_ambience_cue_definition(cue_id: StringName) -> Dictionary:
	return AMBIENCE_CUE_LIBRARY.get(String(cue_id), {})

func preview_bus(bus_name: StringName) -> bool:
	if not audio_runtime_available or master_muted:
		return false
	match String(bus_name):
		BUS_MUSIC:
			var cue_id := current_cue_id if current_cue_id != &"" else &"title"
			return _preview_cue(cue_id, false)
		BUS_AMBIENCE:
			var ambience_id := current_ambience_id if current_ambience_id != &"" else &"title"
			return _preview_cue(ambience_id, true)
		BUS_SFX:
			return Sfx != null and Sfx.play_event(&"knight_attack", null, -4.0, 1.0, BUS_SFX)
		BUS_UI:
			return Sfx != null and Sfx.play_event(&"ui_confirm", null, -1.0, 1.0, BUS_UI)
		_:
			return false

func _get_stream(track_id: String) -> AudioStream:
	if track_id.is_empty():
		return null
	if stream_cache.has(track_id):
		return stream_cache[track_id]
	for base_dir in SEARCH_DIRS:
		for extension in SUPPORTED_EXTENSIONS:
			var path := "%s/%s%s" % [base_dir, track_id, extension]
			if not ResourceLoader.exists(path):
				continue
			var stream := load(path)
			if stream is AudioStream:
				stream_cache[track_id] = stream
				return stream
	if not missing_tracks.has(track_id):
		missing_tracks[track_id] = true
	return null

func _set_music_bus_volume(volume_db: float) -> void:
	var bus_index := AudioServer.get_bus_index(BUS_MUSIC)
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, volume_db)

func _preview_cue(cue_id: StringName, ambience: bool) -> bool:
	var cue: Dictionary = _get_ambience_cue_definition(cue_id) if ambience else _get_cue_definition(cue_id)
	if cue.is_empty():
		return false
	var stream := _get_stream(String(cue.get("file", "")))
	if stream == null:
		return false
	var bus_name := BUS_AMBIENCE if ambience else BUS_MUSIC
	if not preview_players.has(bus_name):
		return false
	var preview_player: AudioStreamPlayer = preview_players[bus_name]
	if preview_player == null or not is_instance_valid(preview_player):
		return false
	preview_player.stop()
	preview_player.stream = stream
	preview_player.bus = bus_name
	preview_player.volume_db = float(cue.get("volume_db", 0.0)) - (5.0 if ambience else 7.0)
	var start_position := float(cue.get("preview_from", 0.0))
	var preview_length := maxf(float(cue.get("preview_length", 1.5)), 0.2)
	preview_player.play(start_position)
	var request_id := int(preview_serials.get(bus_name, 0)) + 1
	preview_serials[bus_name] = request_id
	var timer := get_tree().create_timer(preview_length)
	timer.timeout.connect(func() -> void:
		if int(preview_serials.get(bus_name, -1)) != request_id:
			return
		if is_instance_valid(preview_player):
			preview_player.stop()
	)
	return true

func _on_player_finished(player_index: int) -> void:
	if player_index < 0 or player_index >= players.size():
		return
	var player := players[player_index]
	if player == null or not is_instance_valid(player) or player_index != active_player_index:
		return
	if bool(player.get_meta("loop_enabled", false)):
		player.play()
	else:
		current_cue_id = &""

func _on_ambience_player_finished(player_index: int) -> void:
	if player_index < 0 or player_index >= ambience_players.size():
		return
	var player := ambience_players[player_index]
	if player == null or not is_instance_valid(player) or player_index != active_ambience_player_index:
		return
	if bool(player.get_meta("loop_enabled", false)):
		player.play()
	else:
		current_ambience_id = &""
