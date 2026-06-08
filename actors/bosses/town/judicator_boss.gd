extends Node2D

signal defeated

const DAMAGE_NUMBER_SCENE := preload("res://effects/damage_number.tscn")
const ENEMY_BOLT_SCENE := preload("res://effects/projectiles/enemy_bolt.tscn")
const TEXTURE_LOADER := preload("res://combat/runtime_texture_loader.gd")
const JUDICATOR_BODY_TEXTURE_PATH := "res://actors/bosses/textures/judicator_boss.png"
const JUDICATOR_WEAPON_TEXTURE_PATH := "res://art/final_materials/weapons/boss_weapon_judicator_sword.png"

@export var max_hp: float = 1500.0
@export var defense_value: float = 180.0
@export var move_speed: float = 96.0
@export var attack_damage: float = 50.0
@export var attack_range: float = 92.0
@export var attack_interval: float = 2.0
@export var skill1_damage: float = 30.0
@export var skill1_cooldown: float = 6.0
@export var skill1_jump_start_duration: float = 0.45
@export var skill1_travel_duration: float = 0.42
@export var skill1_recover_duration: float = 2.0
@export var skill1_radius: float = 96.0
@export var skill2_damage: float = 50.0
@export var skill2_cooldown: float = 8.0
@export var skill2_charge_duration: float = 1.0
@export var skill2_recover_duration: float = 2.0
@export var skill2_length: float = 310.0
@export var skill2_width: float = 34.0
@export var skill3_damage: float = 18.0
@export var skill3_cooldown: float = 7.5
@export var skill3_telegraph_duration: float = 0.74
@export var skill3_wave_interval: float = 0.20
@export var skill3_wave_count: int = 5
@export var skill3_projectile_speed: float = 390.0
@export_range(0.1, 0.9, 0.05) var enrage_threshold_ratio: float = 0.45
@export var enrage_damage_multiplier: float = 1.12
@export var enrage_speed_multiplier: float = 1.15
@export var enrage_cooldown_multiplier: float = 0.82
@export var enrage_aftershock_multiplier: float = 0.55
@export var enrage_aftershock_bonus_radius: float = 38.0

@onready var body: Polygon2D = $Body
@onready var sword: Polygon2D = $Sword
@onready var landing_ring: Line2D = $LandingRing
@onready var slash_line: Line2D = $SlashLine
@onready var hurtbox: Area2D = $Hurtbox
@onready var health_component: Node = $HealthComponent
@onready var effects_layer: Node2D = $EffectsLayer

var target: Node2D = null
var hp: float = 0.0
var state: StringName = &"idle"
var state_time: float = 0.0
var attack_cooldown: float = 0.0
var skill1_cooldown_remaining: float = 0.0
var skill2_cooldown_remaining: float = 0.0
var skill3_cooldown_remaining: float = 0.0
var recover_duration: float = 0.0
var leap_start_position: Vector2 = Vector2.ZERO
var leap_target_position: Vector2 = Vector2.ZERO
var line_direction: Vector2 = Vector2.RIGHT
var action_committed: bool = false
var silenced_time_remaining: float = 0.0
var root_time_remaining: float = 0.0
var slow_time_remaining: float = 0.0
var slow_factor: float = 1.0
var body_sprite: Sprite2D = null
var sword_sprite: Sprite2D = null
var sword_angle_offset: float = 0.0
var enraged: bool = false
var slam_aftershock_committed: bool = false
var barrage_wave_index: int = 0
var barrage_next_wave_time: float = 0.0
var visual_last_position: Vector2 = Vector2.ZERO
var visual_bob_time: float = 0.0

func _ready() -> void:
	add_to_group("damageable")
	health_component.setup(max_hp, defense_value)
	health_component.damaged.connect(_on_damaged)
	health_component.defense_changed.connect(_on_defense_changed)
	health_component.died.connect(_on_died)
	hp = max_hp
	visual_last_position = global_position
	_setup_body_visual()
	_setup_weapon_visual()
	landing_ring.visible = false
	slash_line.visible = false
	_update_visuals()

func bind_player(player: Node2D) -> void:
	target = player

func get_status_title() -> String:
	return _locale_text("Judicator", "审判官", "審判官")

func get_status_text() -> String:
	return _locale_text("HP %d / %d%s\nState: %s", "生命 %d / %d%s\n状态：%s", "生命 %d / %d%s\n狀態：%s") % [
		int(round(hp)),
		int(round(max_hp)),
		_locale_text("  ENRAGED", "  暴怒", "  暴怒") if enraged else "",
		_localized_state_name(String(state))
	]

func _current_locale() -> String:
	var ui_settings := get_node_or_null("/root/UISettings")
	if ui_settings != null and ui_settings.has_method("get_locale"):
		return String(ui_settings.get_locale())
	return "en"

func _locale_text(en_text: String, zh_hans_text: String, zh_hant_text: String) -> String:
	match _current_locale():
		"zh_Hant":
			return zh_hant_text
		"zh_Hans":
			return zh_hans_text
		_:
			return en_text

func _localized_state_name(state_name: String) -> String:
	match state_name:
		"idle":
			return _locale_text("Idle", "待机", "待機")
		"basic_attack":
			return _locale_text("Basic Attack", "普攻", "普攻")
		"skill_1_jump_start":
			return _locale_text("Leap Windup", "跃击蓄势", "躍擊蓄勢")
		"skill_1_slam":
			return _locale_text("Leap Slam", "跃击重砸", "躍擊重砸")
		"skill_2_charge":
			return _locale_text("Line Verdict", "裁决冲锋", "裁決衝鋒")
		"recover":
			return _locale_text("Recover", "恢复", "恢復")
		"dead":
			return _locale_text("Defeated", "倒下", "倒下")
		_:
			return state_name.capitalize()

func _physics_process(delta: float) -> void:
	if hp <= 0.0:
		return
	_update_status_timers(delta)
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	skill1_cooldown_remaining = maxf(skill1_cooldown_remaining - delta, 0.0)
	skill2_cooldown_remaining = maxf(skill2_cooldown_remaining - delta, 0.0)
	skill3_cooldown_remaining = maxf(skill3_cooldown_remaining - delta, 0.0)
	state_time += delta
	if target == null or not is_instance_valid(target):
		_find_target()
	_update_enrage_state()
	_update_state(delta)
	_update_visuals()

func receive_hit(payload: Dictionary) -> void:
	if hp <= 0.0:
		return
	var result: Dictionary = health_component.receive_hit(payload)
	var final_damage := float(result.get("damage", 0.0))
	if final_damage > 0.0:
		apply_control_effects(payload)
		_spawn_damage_number(final_damage, bool(result.get("is_critical", false)))

func apply_control_effects(payload: Dictionary) -> void:
	if payload.has("silence_duration"):
		silenced_time_remaining = maxf(silenced_time_remaining, float(payload["silence_duration"]))
	if payload.has("root_duration"):
		root_time_remaining = maxf(root_time_remaining, float(payload["root_duration"]))
	if payload.has("slow_duration"):
		slow_time_remaining = maxf(slow_time_remaining, float(payload["slow_duration"]))
		slow_factor = minf(slow_factor, float(payload.get("slow_multiplier", 1.0)))

func _find_target() -> void:
	var players := get_tree().get_nodes_in_group("player")
	target = players[0] if not players.is_empty() else null

func _update_status_timers(delta: float) -> void:
	silenced_time_remaining = maxf(silenced_time_remaining - delta, 0.0)
	root_time_remaining = maxf(root_time_remaining - delta, 0.0)
	if slow_time_remaining > 0.0:
		slow_time_remaining = maxf(slow_time_remaining - delta, 0.0)
	else:
		slow_factor = 1.0

func _update_state(delta: float) -> void:
	match state:
		&"idle":
			_process_idle(delta)
		&"basic_attack":
			_process_basic_attack()
		&"skill_1_jump_start":
			_process_skill1_jump_start()
		&"skill_1_slam":
			_process_skill1_slam()
		&"skill_2_charge":
			_process_skill2_charge()
		&"skill_3_barrage_mark":
			_process_skill3_barrage_mark()
		&"skill_3_barrage":
			_process_skill3_barrage()
		&"recover":
			_process_recover()
		&"dead":
			return

func _process_idle(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var to_target := target.global_position - global_position
	if to_target != Vector2.ZERO:
		line_direction = to_target.normalized()
	var distance := to_target.length()
	if _can_use_skills() and skill3_cooldown_remaining <= 0.0 and distance >= 130.0 and distance <= 430.0:
		_start_skill3()
		return
	if _can_use_skills() and skill2_cooldown_remaining <= 0.0 and distance >= 120.0 and distance <= skill2_length:
		_start_skill2()
		return
	if _can_use_skills() and skill1_cooldown_remaining <= 0.0 and distance <= 220.0:
		_start_skill1()
		return
	if attack_cooldown <= 0.0 and distance <= attack_range:
		_start_basic_attack()
		return
	if distance > attack_range * 0.8 and root_time_remaining <= 0.0:
		global_position += line_direction * move_speed * slow_factor * delta

func _start_basic_attack() -> void:
	state = &"basic_attack"
	state_time = 0.0
	action_committed = false
	attack_cooldown = attack_interval
	Sfx.play_event(&"boss_judicator_attack", global_position)

func _process_basic_attack() -> void:
	if not action_committed and state_time >= 0.45:
		action_committed = true
		_hit_target_in_radius(attack_range, attack_damage, false)
	if state_time >= 0.9:
		_enter_recover(0.45)

func _start_skill1() -> void:
	state = &"skill_1_jump_start"
	state_time = 0.0
	action_committed = false
	slam_aftershock_committed = false
	skill1_cooldown_remaining = skill1_cooldown
	leap_start_position = global_position
	leap_target_position = target.global_position if target != null else global_position
	landing_ring.visible = true
	landing_ring.points = _build_ring_points(skill1_radius, 16)
	landing_ring.global_position = leap_target_position
	_show_intent_text("Leap Slam", Color(1.0, 0.84, 0.62, 1.0), leap_target_position, 0.88)
	Sfx.play_event(&"boss_judicator_skill1", global_position)

func _process_skill1_jump_start() -> void:
	if state_time >= skill1_jump_start_duration:
		state = &"skill_1_slam"
		state_time = 0.0
		action_committed = false

func _process_skill1_slam() -> void:
	var progress := clampf(state_time / maxf(skill1_travel_duration, 0.001), 0.0, 1.0)
	global_position = leap_start_position.lerp(leap_target_position, progress) + Vector2(0.0, -sin(progress * PI) * 120.0)
	if not action_committed and progress >= 1.0:
		action_committed = true
		global_position = leap_target_position
		landing_ring.visible = false
		_hit_target_in_radius(skill1_radius, skill1_damage, true)
	if enraged and action_committed and not slam_aftershock_committed and state_time >= skill1_travel_duration + 0.05:
		slam_aftershock_committed = true
		_spawn_aftershock()
		_hit_target_in_radius(skill1_radius + enrage_aftershock_bonus_radius, skill1_damage * enrage_aftershock_multiplier, false)
	if state_time >= skill1_travel_duration + (0.18 if enraged else 0.08):
		_enter_recover(skill1_recover_duration)

func _start_skill2() -> void:
	state = &"skill_2_charge"
	state_time = 0.0
	action_committed = false
	skill2_cooldown_remaining = skill2_cooldown
	line_direction = (target.global_position - global_position).normalized() if target != null else line_direction
	if line_direction == Vector2.ZERO:
		line_direction = Vector2.RIGHT
	slash_line.visible = true
	slash_line.global_position = global_position
	slash_line.rotation = line_direction.angle()
	_show_intent_text("Line Verdict", Color(1.0, 0.74, 0.54, 1.0), global_position, 0.88)
	Sfx.play_event(&"boss_judicator_skill2", global_position)

func _process_skill2_charge() -> void:
	slash_line.global_position = global_position
	if not action_committed and state_time >= skill2_charge_duration:
		action_committed = true
		_hit_target_in_line(skill2_damage, skill2_length + (28.0 if enraged else 0.0), skill2_width + (10.0 if enraged else 0.0))
		slash_line.default_color = Color(1.0, 0.74, 0.4, 0.95)
	if state_time >= skill2_charge_duration + 0.18:
		slash_line.visible = false
		slash_line.default_color = Color(1.0, 0.52, 0.4, 0.8)
		_enter_recover(skill2_recover_duration)

func _start_skill3() -> void:
	state = &"skill_3_barrage_mark"
	state_time = 0.0
	action_committed = false
	barrage_wave_index = 0
	barrage_next_wave_time = 0.0
	skill3_cooldown_remaining = skill3_cooldown
	if target != null and is_instance_valid(target):
		var to_target := target.global_position - global_position
		if to_target.length_squared() > 0.0001:
			line_direction = to_target.normalized()
	landing_ring.visible = true
	landing_ring.global_position = global_position
	landing_ring.points = _build_ring_points(126.0 if not enraged else 154.0, 16)
	_show_intent_text("Bullet Edict", Color(1.0, 0.78, 0.48, 1.0), global_position, 0.88)
	Sfx.play_event(&"boss_judicator_skill2", global_position, -2.0, 1.08)

func _process_skill3_barrage_mark() -> void:
	landing_ring.global_position = global_position
	if target != null and is_instance_valid(target):
		var to_target := target.global_position - global_position
		if to_target.length_squared() > 0.0001:
			line_direction = to_target.normalized()
	if state_time >= skill3_telegraph_duration:
		state = &"skill_3_barrage"
		state_time = 0.0
		barrage_wave_index = 0
		barrage_next_wave_time = 0.0

func _process_skill3_barrage() -> void:
	landing_ring.global_position = global_position
	if barrage_wave_index < skill3_wave_count and state_time >= barrage_next_wave_time:
		_fire_barrage_wave(barrage_wave_index)
		barrage_wave_index += 1
		barrage_next_wave_time += skill3_wave_interval
	if barrage_wave_index >= skill3_wave_count and state_time >= barrage_next_wave_time + 0.22:
		landing_ring.visible = false
		_enter_recover(1.05 if enraged else 1.25)

func _enter_recover(duration: float) -> void:
	state = &"recover"
	state_time = 0.0
	recover_duration = duration
	landing_ring.visible = false
	slash_line.visible = false

func _process_recover() -> void:
	if state_time >= recover_duration:
		state = &"idle"
		state_time = 0.0

func _hit_target_in_radius(radius: float, damage: float, knockback: bool) -> void:
	if target == null or not is_instance_valid(target):
		return
	if global_position.distance_to(target.global_position) > radius:
		return
	target.receive_hit({
		"source": self,
		"damage": damage,
		"crit_rate": 0.0,
		"silence_duration": 0.8 if not enraged else 1.1
	})
	if knockback and target is CharacterBody2D:
		var actor: CharacterBody2D = target
		var direction := (actor.global_position - global_position).normalized()
		actor.velocity = direction * 320.0

func _hit_target_in_line(damage: float, length: float = -1.0, width: float = -1.0) -> void:
	if target == null or not is_instance_valid(target):
		return
	if length <= 0.0:
		length = skill2_length
	if width <= 0.0:
		width = skill2_width
	var start_position := global_position
	var end_position := global_position + line_direction * length
	if _distance_to_segment(target.global_position, start_position, end_position) > width:
		return
	target.receive_hit({
		"source": self,
		"damage": damage,
		"crit_rate": 0.0
	})

func _distance_to_segment(point: Vector2, start_position: Vector2, end_position: Vector2) -> float:
	var segment := end_position - start_position
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.0001:
		return point.distance_to(start_position)
	var weight := clampf((point - start_position).dot(segment) / segment_length_squared, 0.0, 1.0)
	var closest_point := start_position + segment * weight
	return point.distance_to(closest_point)

func _can_use_skills() -> bool:
	return silenced_time_remaining <= 0.0

func _update_enrage_state() -> void:
	if enraged or hp > max_hp * enrage_threshold_ratio:
		return
	enraged = true
	move_speed *= enrage_speed_multiplier
	attack_damage *= enrage_damage_multiplier
	skill1_damage *= enrage_damage_multiplier
	skill2_damage *= enrage_damage_multiplier
	attack_interval *= enrage_cooldown_multiplier
	skill1_cooldown *= enrage_cooldown_multiplier
	skill2_cooldown *= enrage_cooldown_multiplier
	skill3_cooldown *= enrage_cooldown_multiplier
	landing_ring.default_color = Color(1.0, 0.74, 0.38, 0.9)
	slash_line.default_color = Color(1.0, 0.62, 0.4, 0.85)
	_show_intent_text("Enraged", Color(1.0, 0.70, 0.48, 1.0), global_position, 0.94)
	Sfx.play_event(&"boss_judicator_skill2", global_position, 2.0)

func _setup_body_visual() -> void:
	body_sprite = Sprite2D.new()
	body_sprite.texture = TEXTURE_LOADER.load_texture(JUDICATOR_BODY_TEXTURE_PATH)
	body_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body_sprite.centered = true
	body_sprite.scale = Vector2.ONE * 0.36
	body.add_child(body_sprite)
	body.color = Color(1.0, 1.0, 1.0, 0.0)

func _set_body_tint(color: Color) -> void:
	if body_sprite != null:
		body_sprite.self_modulate = color
	else:
		body.color = color

func _setup_weapon_visual() -> void:
	sword_sprite = Sprite2D.new()
	sword_sprite.texture = TEXTURE_LOADER.load_texture(JUDICATOR_WEAPON_TEXTURE_PATH)
	sword_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sword_sprite.centered = true
	sword_sprite.scale = Vector2.ONE * 0.68
	sword_sprite.position = Vector2(-62.0, 4.0)
	sword.add_child(sword_sprite)
	sword.color = Color(1.0, 1.0, 1.0, 0.0)

func _update_visuals() -> void:
	var body_color := Color(0.68, 0.7, 0.78, 1.0)
	if state == &"skill_1_jump_start" or state == &"skill_2_charge" or state == &"skill_3_barrage_mark":
		body_color = Color(0.9, 0.74, 0.52, 1.0)
	elif state == &"skill_3_barrage":
		body_color = Color(0.98, 0.72, 0.42, 1.0)
	elif silenced_time_remaining > 0.0:
		body_color = Color(0.72, 0.64, 0.92, 1.0)
	elif enraged:
		body_color = Color(0.92, 0.62, 0.42, 1.0)
	_set_body_tint(body_color)
	if sword_sprite == null:
		sword.color = Color(0.92, 0.84, 0.72, 1.0)
	var sword_direction := line_direction if line_direction != Vector2.ZERO else Vector2.RIGHT
	if target != null and is_instance_valid(target):
		var to_target := target.global_position - global_position
		if to_target != Vector2.ZERO:
			sword_direction = to_target.normalized()
	sword.position = sword_direction * 18.0 + Vector2(0.0, 2.0)
	sword.rotation = _weapon_guard_rotation(sword_direction, -46.0) + sword_angle_offset
	_apply_heavy_body_motion()
	var pulse := 0.82 + 0.18 * sin(Time.get_ticks_msec() * 0.01)
	if landing_ring.visible:
		landing_ring.scale = Vector2.ONE * (0.94 + 0.08 * pulse)
		landing_ring.width = 3.4 + 1.2 * pulse
		landing_ring.modulate = Color(1.0, 1.0, 1.0, 0.76 + 0.16 * pulse)
	if slash_line.visible:
		slash_line.width = 4.0 + 1.2 * pulse
		slash_line.modulate = Color(1.0, 1.0, 1.0, 0.74 + 0.16 * pulse)
	visual_last_position = global_position

func _weapon_guard_rotation(direction: Vector2, guard_degrees: float) -> float:
	var facing := direction.normalized() if direction.length_squared() > 0.0001 else Vector2.RIGHT
	var side_sign := -1.0 if facing.x < -0.05 else 1.0
	return facing.angle() + deg_to_rad(guard_degrees * side_sign)

func _apply_heavy_body_motion() -> void:
	var movement := global_position - visual_last_position
	var motion_ratio := clampf(movement.length() / maxf(move_speed * get_physics_process_delta_time(), 1.0), 0.0, 1.0)
	visual_bob_time += 0.06 + motion_ratio * 0.17
	var facing := -1.0 if line_direction.x < -0.05 else 1.0
	if body_sprite != null:
		body_sprite.flip_h = facing < 0.0
	var stomp := absf(sin(visual_bob_time))
	body.position = Vector2(0.0, stomp * (1.2 + motion_ratio * 3.8))
	body.rotation = sin(visual_bob_time * 0.5) * (0.01 + motion_ratio * 0.018) * facing
	body.scale = Vector2(1.0 + stomp * motion_ratio * 0.018, 1.0 - stomp * motion_ratio * 0.012)

func _spawn_aftershock() -> void:
	var ring := Line2D.new()
	ring.width = 5.0
	ring.closed = true
	ring.default_color = Color(1.0, 0.74, 0.42, 0.92)
	ring.points = _build_ring_points(skill1_radius + enrage_aftershock_bonus_radius, 18)
	ring.global_position = global_position
	get_tree().current_scene.add_child(ring)
	var tween := create_tween()
	tween.tween_property(ring, "scale", Vector2.ONE * 1.12, 0.14)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.14)
	tween.finished.connect(ring.queue_free)

func _fire_barrage_wave(wave_index: int) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var radial_count := 8 + (2 if enraged else 0)
	var offset := float(wave_index) * (TAU / float(radial_count) * 0.5)
	for index in range(radial_count):
		var direction := Vector2.RIGHT.rotated(offset + TAU * float(index) / float(radial_count))
		_spawn_barrage_bolt(direction, skill3_damage * (1.12 if enraged else 1.0), Color(1.0, 0.74, 0.45, 1.0))
	if target != null and is_instance_valid(target):
		var aim_direction := (target.global_position - global_position).normalized()
		if aim_direction == Vector2.ZERO:
			aim_direction = line_direction
		for spread in [-10.0, 0.0, 10.0]:
			_spawn_barrage_bolt(
				aim_direction.rotated(deg_to_rad(spread + float(wave_index % 2) * 6.0)),
				skill3_damage * 0.82,
				Color(1.0, 0.88, 0.58, 1.0),
				0.92
			)

func _spawn_barrage_bolt(direction: Vector2, damage: float, color_value: Color, speed_multiplier: float = 1.0) -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var bolt := ENEMY_BOLT_SCENE.instantiate()
	bolt.global_position = global_position + direction.normalized() * 28.0
	scene_root.add_child(bolt)
	var payload := {
		"slow_duration": 0.55 if not enraged else 0.8,
		"slow_multiplier": 0.86 if not enraged else 0.80
	}
	bolt.setup(self, direction, damage, color_value, skill3_projectile_speed * speed_multiplier, payload)

func _spawn_damage_number(amount: float, is_critical: bool) -> void:
	var damage_number := DAMAGE_NUMBER_SCENE.instantiate()
	damage_number.position = Vector2(0.0, -42.0)
	damage_number.setup(amount, is_critical)
	effects_layer.add_child(damage_number)

func _show_intent_text(label_text: String, color_value: Color, world_position: Vector2, scale_value: float = 0.86) -> void:
	var popup := DAMAGE_NUMBER_SCENE.instantiate()
	popup.position = to_local(world_position) + Vector2(-42.0, -54.0)
	if popup.has_method("setup_text"):
		popup.setup_text(label_text, color_value, scale_value)
	effects_layer.add_child(popup)

func _on_damaged(_amount: float, remaining_hp: float, _source: Node) -> void:
	hp = remaining_hp
	_set_body_tint(Color(1.0, 0.8, 0.8, 1.0))
	var timer := get_tree().create_timer(0.14)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self) and hp > 0.0:
			_update_visuals()
	)

func _on_defense_changed(_current_defense: float, _max_defense: float) -> void:
	pass

func _on_died() -> void:
	hp = 0.0
	state = &"dead"
	landing_ring.visible = false
	slash_line.visible = false
	Sfx.play_event(&"boss_generic_dead", global_position)
	var timer := get_tree().create_timer(0.5)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self):
			defeated.emit()
			queue_free()
	)

func _build_ring_points(radius: float, steps: int = 16) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(steps):
		var angle := TAU * float(index) / float(steps)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points
