extends Node

const BUS_SFX := "SFX"
const BUS_UI := "UI"

const SEARCH_DIRS := [
	"res://audio/generated",
	"res://audio/sfx"
]

const SUPPORTED_EXTENSIONS := [
	".wav",
	".ogg",
	".mp3"
]

const EVENT_PROFILES := {
	"ui_confirm": {
		"bus": BUS_UI,
		"volume_db": -1.5,
		"pitch_min": 0.98,
		"pitch_max": 1.02
	},
	"enemy_generic_hit": {
		"volume_db": -2.0,
		"pitch_min": 0.96,
		"pitch_max": 1.04
	},
	"enemy_generic_dead": {
		"volume_db": -1.5,
		"pitch_min": 0.97,
		"pitch_max": 1.03
	},
	"knight_attack": {
		"pitch_min": 0.98,
		"pitch_max": 1.02
	},
	"knight_skill1_charge": {
		"duck_music_db": -4.0,
		"duck_hold": 0.2
	},
	"knight_skill2_shockwave": {
		"duck_music_db": -6.0,
		"duck_hold": 0.24,
		"duck_release": 0.7
	},
	"knight_skill3_sanctuary": {
		"duck_music_db": -4.5,
		"duck_hold": 0.22
	},
	"ranger_attack": {
		"pitch_min": 1.0,
		"pitch_max": 1.04
	},
	"ranger_skill3_assassinate": {
		"duck_music_db": -3.0,
		"duck_hold": 0.16
	},
	"mage_attack": {
		"pitch_min": 0.99,
		"pitch_max": 1.03
	},
	"mage_skill1_blades": {
		"duck_music_db": -3.2,
		"duck_hold": 0.18
	},
	"mage_skill2_burst": {
		"duck_music_db": -5.5,
		"duck_hold": 0.22,
		"duck_release": 0.68
	},
	"mage_skill3_enchant": {
		"duck_music_db": -2.5,
		"duck_hold": 0.14
	},
	"player_knight_attack": {
		"volume_db": -2.0,
		"pitch_min": 0.96,
		"pitch_max": 1.03
	},
	"player_knight_skill1_dash": {
		"volume_db": -1.0,
		"pitch_min": 0.97,
		"pitch_max": 1.02
	},
	"player_knight_skill2_shockwave": {
		"volume_db": -3.5,
		"pitch_min": 0.96,
		"pitch_max": 1.02,
		"duck_music_db": -4.5,
		"duck_hold": 0.2
	},
	"player_knight_skill3_sanctuary": {
		"volume_db": -4.5,
		"pitch_min": 0.98,
		"pitch_max": 1.02,
		"duck_music_db": -3.0,
		"duck_hold": 0.18
	},
	"player_ranger_attack": {
		"volume_db": -3.0,
		"pitch_min": 1.0,
		"pitch_max": 1.06
	},
	"player_ranger_skill1_arrow": {
		"volume_db": -2.0,
		"pitch_min": 0.98,
		"pitch_max": 1.04
	},
	"player_ranger_skill2_shadow": {
		"volume_db": -5.0,
		"pitch_min": 0.98,
		"pitch_max": 1.03,
		"duck_music_db": -2.4,
		"duck_hold": 0.12
	},
	"player_ranger_skill3_assassinate": {
		"volume_db": -1.5,
		"pitch_min": 0.98,
		"pitch_max": 1.03,
		"duck_music_db": -3.0,
		"duck_hold": 0.16
	},
	"player_mage_attack": {
		"volume_db": -7.0,
		"pitch_min": 0.99,
		"pitch_max": 1.04
	},
	"player_mage_skill1_blades": {
		"volume_db": -2.5,
		"pitch_min": 0.98,
		"pitch_max": 1.04
	},
	"player_mage_skill2_burst": {
		"volume_db": -5.0,
		"pitch_min": 0.96,
		"pitch_max": 1.02,
		"duck_music_db": -4.5,
		"duck_hold": 0.18
	},
	"player_mage_skill3_thunder": {
		"volume_db": -4.0,
		"pitch_min": 0.96,
		"pitch_max": 1.02,
		"duck_music_db": -3.2,
		"duck_hold": 0.16
	},
	"boss_judicator_attack": {
		"duck_music_db": -3.2,
		"duck_hold": 0.16
	},
	"boss_judicator_skill1": {
		"duck_music_db": -6.5,
		"duck_hold": 0.28,
		"duck_release": 0.8
	},
	"boss_judicator_skill2": {
		"duck_music_db": -6.8,
		"duck_hold": 0.3,
		"duck_release": 0.8
	},
	"boss_guard_immune_break": {
		"duck_music_db": -5.0,
		"duck_hold": 0.24
	},
	"boss_twin_teleport": {
		"duck_music_db": -3.5,
		"duck_hold": 0.16
	},
	"boss_twin_charge": {
		"duck_music_db": -5.2,
		"duck_hold": 0.24
	},
	"boss_twin_barrage": {
		"duck_music_db": -4.2,
		"duck_hold": 0.3,
		"duck_release": 0.72
	},
	"boss_generic_dead": {
		"duck_music_db": -6.0,
		"duck_hold": 0.35,
		"duck_release": 0.9
	}
}

var stream_cache: Dictionary = {}
var missing_events: Dictionary = {}
var rng := RandomNumberGenerator.new()
var audio_runtime_available: bool = true

func _ready() -> void:
	rng.randomize()
	audio_runtime_available = DisplayServer.get_name() != "headless"

func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D:
			child.stop()
			child.stream = null
			child.queue_free()
	stream_cache.clear()
	missing_events.clear()

func play_event(event_id: StringName, world_position: Variant = null, volume_db: float = 0.0, pitch_scale: float = 1.0, bus: String = "") -> bool:
	if not audio_runtime_available or event_id == &"":
		return false
	var profile := _get_event_profile(String(event_id))
	var stream := _get_stream(String(event_id))
	if stream == null:
		return false
	var player: Node = null
	if world_position is Vector2:
		var spatial_player := AudioStreamPlayer2D.new()
		spatial_player.global_position = world_position
		player = spatial_player
	else:
		player = AudioStreamPlayer.new()
	player.name = "Sfx_%s" % String(event_id)
	var resolved_bus := String(profile.get("bus", BUS_SFX))
	if not bus.is_empty():
		resolved_bus = bus
	if AudioServer.get_bus_index(resolved_bus) < 0:
		resolved_bus = "Master"
	var pitch_min := float(profile.get("pitch_min", 1.0))
	var pitch_max := float(profile.get("pitch_max", 1.0))
	var resolved_pitch := pitch_scale * rng.randf_range(minf(pitch_min, pitch_max), maxf(pitch_min, pitch_max))
	player.set("stream", stream)
	player.set("volume_db", volume_db + float(profile.get("volume_db", 0.0)))
	player.set("pitch_scale", resolved_pitch)
	player.set("bus", resolved_bus)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.call_deferred("play")
	_duck_music_for_profile(profile)
	return true

func has_event(event_id: StringName) -> bool:
	return _get_stream(String(event_id)) != null

func _get_event_profile(event_id: String) -> Dictionary:
	var profile := {
		"bus": BUS_UI if event_id.begins_with("ui_") else BUS_SFX,
		"volume_db": 0.0,
		"pitch_min": 1.0,
		"pitch_max": 1.0,
		"duck_music_db": 0.0,
		"duck_attack": 0.04,
		"duck_hold": 0.16,
		"duck_release": 0.55
	}
	if EVENT_PROFILES.has(event_id):
		var override_profile: Dictionary = EVENT_PROFILES[event_id]
		for key in override_profile.keys():
			profile[key] = override_profile[key]
	return profile

func _duck_music_for_profile(profile: Dictionary) -> void:
	var duck_amount := float(profile.get("duck_music_db", 0.0))
	if duck_amount >= 0.0:
		return
	var music_node := get_tree().root.get_node_or_null("Music")
	if music_node == null or not music_node.has_method("duck_music"):
		return
	music_node.duck_music(
		duck_amount,
		float(profile.get("duck_attack", 0.04)),
		float(profile.get("duck_hold", 0.16)),
		float(profile.get("duck_release", 0.55))
	)

func _get_stream(event_id: String) -> AudioStream:
	if stream_cache.has(event_id):
		return stream_cache[event_id]
	for base_dir in SEARCH_DIRS:
		for extension in SUPPORTED_EXTENSIONS:
			var path := "%s/%s%s" % [base_dir, event_id, extension]
			if not ResourceLoader.exists(path):
				continue
			var stream := load(path)
			if stream is AudioStream:
				stream_cache[event_id] = stream
				return stream
	if not missing_events.has(event_id):
		missing_events[event_id] = true
	return null
