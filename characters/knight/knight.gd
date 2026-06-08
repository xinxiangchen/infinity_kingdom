extends CharacterBody2D

signal attack_started(attack_name: StringName)
signal attack_hit(attack_name: StringName, target: Node)
signal attack_finished(attack_name: StringName)
signal skill_used(skill_name: StringName)
signal hp_changed(current_hp: float, max_hp_value: float)
signal inspiration_changed(current_inspiration: float, max_inspiration_value: float)
signal took_damage(amount: float, remaining_hp: float)
signal shield_changed(current_shield: float)
signal defense_changed(current_defense: float, max_defense_value: float)
signal upgrades_changed
signal control_status_changed(summary: String)
signal died

@export_group("Core Stats")
@export var max_hp: float = 100.0
@export var max_inspiration: float = 20.0
@export var defense: float = 100.0
@export var max_defense: float = 100.0
@export var move_speed: float = 226.0
@export var attack_damage: float = 100.0
@export var attack_interval: float = 0.68
@export_range(0.0, 1.0, 0.01) var crit_rate: float = 0.2
@export var inspiration_gain_on_attack_hit: float = 2.0

@export_group("Normal Attack Timing")
@export var attack_windup: float = 0.24
@export var attack_hit_frame: float = 0.08
@export var attack_recovery: float = 0.32

@export_group("Skill 1: Charge Slash")
@export var skill1_cost: float = 10.0
@export var skill1_cooldown: float = 5.0
@export var skill1_damage: float = 80.0
@export var charge_duration: float = 1.0
@export var dash_duration: float = 0.3
@export var dash_speed: float = 750.0
@export var dash_hit_radius: float = 48.0
@export var skill1_instant_dash_upgrade: bool = false
@export var skill1_armor_break_upgrade: bool = false
@export var armor_break_multiplier: float = 1.25
@export var armor_break_duration: float = 5.0

@export_group("Skill 2: Shockwave Counter")
@export var skill2_cost: float = 15.0
@export var skill2_cooldown: float = 8.0
@export var skill2_damage: float = 80.0
@export var skill2_duration: float = 0.35
@export var skill2_shield_upgrade: bool = false
@export var guard_duration: float = 10.0
@export var guard_shield_value: float = 100.0
@export var skill2_knock_up_upgrade: bool = false
@export var knock_up_duration: float = 3.0

@export_group("Skill 3: Sanctuary Field")
@export var skill3_cost: float = 20.0
@export var skill3_cooldown: float = 20.0
@export var skill3_duration: float = 0.4
@export var buff_duration: float = 15.0
@export var sanctuary_damage_multiplier: float = 1.1
@export var sanctuary_damage_reduction: float = 0.2
@export var skill3_heal_upgrade: bool = false
@export var skill3_restore_defense_upgrade: bool = false

@export_group("Dodge")
@export var dodge_cost: float = 5.0
@export var dodge_cooldown: float = 3.0
@export var dodge_duration: float = 0.26
@export var dodge_speed: float = 860.0

@export_group("Hit / Combat")
@export var hit_stun_duration: float = 0.25
@export var hit_threshold: float = 1.0
@export var hit_invulnerability_duration: float = 0.34
@export var attack_range: float = 98.0
@export var attack_arc_degrees: float = 108.0
@export var shockwave_radius: float = 120.0
@export var sanctuary_radius: float = 140.0

@onready var state_machine: Node = $StateMachine
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var health_component: Node = $HealthComponent
@onready var slash_arc: Polygon2D = $SlashArc
@onready var shockwave_ring: Line2D = $ShockwaveRing
@onready var sanctuary_ring: Line2D = $SanctuaryRing
@onready var effects_layer: Node2D = $EffectsLayer

const DAMAGE_NUMBER_SCENE := preload("res://effects/damage_number.tscn")
const MELEE_UTILS := preload("res://combat/melee_utils.gd")
const TEXTURE_LOADER := preload("res://combat/runtime_texture_loader.gd")
const KNIGHT_WEAPON_TEXTURE_PATH := "res://art/final_materials/weapons/player_knight_sword_lv3.png"
const KNIGHT_DEATH_TEXTURE_PATH := "res://art/final_materials/deaths/player_knight_dead.png"
const BASE_SPRITE_SCALE := Vector2(0.85, 0.85)

var hp: float = 0.0
var inspiration: float = 0.0
var shield: float = 0.0
var facing: Vector2 = Vector2.RIGHT
var move_input: Vector2 = Vector2.ZERO
var cooldowns := {
	"attack": 0.0,
	"skill1": 0.0,
	"skill2": 0.0,
	"skill3": 0.0,
	"dodge": 0.0
}
var active_damage_multiplier: float = 1.0
var active_damage_reduction: float = 0.0
var guard_active: bool = false
var buff_active: bool = false
var guard_time_remaining: float = 0.0
var sanctuary_time_remaining: float = 0.0
var queued_skill: StringName = &""
var queued_skill_payload: Dictionary = {}
var dash_direction: Vector2 = Vector2.RIGHT
var dash_hit_targets: Array[Node] = []
var current_attack_targets: Array[Node] = []
var current_attack_name: StringName = &""
var manual_movement_performed: bool = false
var dodge_direction: Vector2 = Vector2.RIGHT
var dodge_elapsed: float = 0.0
var dodge_active: bool = false
var dodge_invincible: bool = false
var weapon: Node2D = null
var weapon_sprite: Sprite2D = null
var weapon_swing_rotation: float = 0.0
var weapon_swing_tween: Tween = null
var silenced_time_remaining: float = 0.0
var root_time_remaining: float = 0.0
var slow_time_remaining: float = 0.0
var slow_factor: float = 1.0
var hit_invulnerability_remaining: float = 0.0
var auto_walk_direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	health_component.setup(max_hp, max_defense)
	health_component.damaged.connect(_on_health_component_damaged)
	health_component.healed.connect(_on_health_component_healed)
	health_component.shield_changed.connect(_on_health_component_shield_changed)
	health_component.defense_changed.connect(_on_health_component_defense_changed)
	health_component.died.connect(_on_health_component_died)
	hp = max_hp
	defense = max_defense
	inspiration = 0.0
	add_to_group("player")
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	_setup_weapon_visual()
	_setup_visual_shapes()
	_build_animations()
	slash_arc.visible = false
	shockwave_ring.visible = false
	sanctuary_ring.visible = false
	emit_stat_signals()
	state_machine.initialize(self)

func _physics_process(delta: float) -> void:
	manual_movement_performed = false
	var requested_move_input := auto_walk_direction if _is_auto_walking() else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if requested_move_input != Vector2.ZERO:
		facing = requested_move_input.normalized()
	move_input = requested_move_input if _is_auto_walking() else (Vector2.ZERO if root_time_remaining > 0.0 else requested_move_input)
	update_cooldowns(delta)
	if not _is_auto_walking():
		process_instant_skills()
	state_machine.physics_update(delta)
	if not manual_movement_performed:
		move_and_slide()
	sync_visuals()

func _process(delta: float) -> void:
	_update_control_effects(delta)
	_update_guard(delta)
	_update_sanctuary(delta)

func emit_stat_signals() -> void:
	hp_changed.emit(hp, max_hp)
	inspiration_changed.emit(inspiration, max_inspiration)
	defense_changed.emit(defense, max_defense)

func get_character_name() -> String:
	return "Knight"

func get_upgrade_sections() -> Array:
	return [
		{
			"title": "Skill 1: 冲锋斩",
			"upgrades": [
				{
					"id": "skill1_fast_charge",
					"label": "疾突",
					"description": "取消蓄力时间。",
					"fields": ["skill1_instant_dash_upgrade"]
				},
				{
					"id": "skill1_armor_break",
					"label": "裂甲冲锋",
					"description": "命中后 5 秒内受到伤害增加 25%。",
					"fields": ["skill1_armor_break_upgrade"]
				}
			]
		},
		{
			"title": "Skill 2: 震地反击",
			"upgrades": [
				{
					"id": "skill2_shield",
					"label": "铁壁",
					"description": "生成 10 秒临时护盾。",
					"fields": ["skill2_shield_upgrade"]
				},
				{
					"id": "skill2_knock_up",
					"label": "反震",
					"description": "技能后额外击飞敌人。",
					"fields": ["skill2_knock_up_upgrade"]
				}
			]
		},
		{
			"title": "Skill 3: 圣佑领域",
			"upgrades": [
				{
					"id": "skill3_heal",
					"label": "祝圣",
					"description": "回复 10% 已损失生命值。",
					"fields": ["skill3_heal_upgrade"]
				},
				{
					"id": "skill3_restore_defense",
					"label": "庇护",
					"description": "恢复全部防御值。",
					"fields": ["skill3_restore_defense_upgrade"]
				}
			]
		}
	]

func is_upgrade_enabled(upgrade_id: String) -> bool:
	var upgrade := _find_upgrade_definition(upgrade_id)
	if upgrade.is_empty():
		return false
	for field_name_variant in upgrade.get("fields", []):
		if not bool(get(String(field_name_variant))):
			return false
	return true

func set_upgrade_enabled(upgrade_id: String, enabled: bool) -> void:
	var upgrade := _find_upgrade_definition(upgrade_id)
	if upgrade.is_empty():
		return
	for field_name_variant in upgrade.get("fields", []):
		set(String(field_name_variant), enabled)
	upgrades_changed.emit()

func clear_all_upgrades() -> void:
	for section in get_upgrade_sections():
		for upgrade_variant in section.get("upgrades", []):
			var upgrade: Dictionary = upgrade_variant
			for field_name_variant in upgrade.get("fields", []):
				set(String(field_name_variant), false)
	upgrades_changed.emit()

func _find_upgrade_definition(upgrade_id: String) -> Dictionary:
	for section_variant in get_upgrade_sections():
		var section: Dictionary = section_variant
		for upgrade_variant in section.get("upgrades", []):
			var upgrade: Dictionary = upgrade_variant
			if String(upgrade.get("id", "")) == upgrade_id:
				return upgrade
	return {}

func on_attack_landed(attack_name: StringName, target: Node) -> void:
	gain_inspiration(inspiration_gain_on_attack_hit)
	AccessoryManager.apply_on_hit_effects(self, attack_name, target)

func sync_visuals() -> void:
	if absf(facing.x) > 0.01:
		sprite.flip_h = facing.x < 0.0
	_sync_weapon_visual()
	slash_arc.position = _attack_visual_offset()
	if slash_arc.visible:
		slash_arc.rotation = _attack_facing().angle()
	if hp <= 0.0:
		modulate = Color(0.35, 0.35, 0.35, 1.0)
	elif dodge_invincible:
		modulate = Color(0.8, 0.88, 1.0, 0.9)
	elif hit_invulnerability_remaining > 0.0:
		var invulnerability_pulse := 0.76 + 0.18 * sin(Time.get_ticks_msec() * 0.018)
		modulate = Color(1.0, 1.0, 1.0, invulnerability_pulse)
	elif state_machine.get_state_name() == &"Hit":
		modulate = Color(1.0, 0.65, 0.65, 1.0)
	elif silenced_time_remaining > 0.0:
		modulate = Color(0.84, 0.76, 1.0, 1.0)
	elif guard_active:
		modulate = Color(0.65, 0.95, 1.0, 1.0)
	elif buff_active:
		modulate = Color(1.0, 0.95, 0.65, 1.0)
	else:
		modulate = Color.WHITE

func update_cooldowns(delta: float) -> void:
	for key in cooldowns.keys():
		cooldowns[key] = update_cooldown(float(cooldowns[key]), delta)

func can_use_skill(cost: float) -> bool:
	return inspiration >= cost

func consume_inspiration(cost: float) -> void:
	inspiration = clampf(inspiration - cost, 0.0, max_inspiration)
	inspiration_changed.emit(inspiration, max_inspiration)

func gain_inspiration(amount: float) -> void:
	if amount <= 0.0 or hp <= 0.0:
		return
	var previous := inspiration
	inspiration = clampf(inspiration + amount, 0.0, max_inspiration)
	if not is_equal_approx(previous, inspiration):
		inspiration_changed.emit(inspiration, max_inspiration)

func update_cooldown(cd: float, delta: float) -> float:
	return maxf(cd - delta, 0.0)

func can_attack() -> bool:
	return float(cooldowns["attack"]) <= 0.0

func can_dodge() -> bool:
	return can_use_skill(dodge_cost) and float(cooldowns["dodge"]) <= 0.0

func can_cast_skill(skill_name: StringName) -> bool:
	if silenced_time_remaining > 0.0:
		return false
	match skill_name:
		&"skill1":
			return can_use_skill(skill1_cost) and float(cooldowns["skill1"]) <= 0.0
		&"skill2":
			return can_use_skill(skill2_cost) and float(cooldowns["skill2"]) <= 0.0
		&"skill3":
			return can_use_skill(skill3_cost) and float(cooldowns["skill3"]) <= 0.0
		_:
			return false

func get_state_request() -> StringName:
	if hp <= 0.0:
		return &"Dead"
	if _is_auto_walking():
		return &"Move" if move_input != Vector2.ZERO else &"Idle"
	if Input.is_action_just_pressed("dodge") and can_dodge():
		return &"Dodge"
	if Input.is_action_just_pressed("attack") and can_attack():
		return &"Attack"
	if Input.is_action_just_pressed("skill_1") and can_cast_skill(&"skill1"):
		prepare_skill_request(&"skill1")
		if skill1_instant_dash_upgrade:
			return &"Dash"
		return &"Charge"
	if move_input != Vector2.ZERO:
		return &"Move"
	return &"Idle"

func process_instant_skills() -> void:
	if hp <= 0.0:
		return
	if _is_auto_walking():
		return
	if state_machine != null and not state_machine.is_current_state_interruptible():
		return
	if Input.is_action_just_pressed("skill_2") and can_cast_skill(&"skill2"):
		cast_skill2()
	if Input.is_action_just_pressed("skill_3") and can_cast_skill(&"skill3"):
		cast_skill3()

func prepare_skill_request(skill_name: StringName) -> void:
	queued_skill = skill_name
	queued_skill_payload.clear()
	if skill_name == &"skill1":
		queued_skill_payload["dash_direction"] = facing

func get_queued_skill() -> StringName:
	return queued_skill

func consume_queued_skill() -> StringName:
	var skill_name := queued_skill
	queued_skill = &""
	return skill_name

func start_attack() -> void:
	cooldowns["attack"] = attack_interval
	current_attack_targets.clear()
	current_attack_name = &"attack"
	attack_started.emit(current_attack_name)
	slash_arc.visible = true
	slash_arc.position = _attack_visual_offset()
	slash_arc.rotation = _attack_facing().angle()
	play_animation(&"attack")
	_animate_weapon_swing(-34.0, 20.0, 0.12, 0.18)

func finish_attack() -> void:
	if current_attack_name != &"":
		attack_finished.emit(current_attack_name)
	slash_arc.visible = false
	current_attack_name = &""
	current_attack_targets.clear()

func start_skill(skill_name: StringName) -> void:
	match skill_name:
		&"skill1":
			consume_inspiration(skill1_cost)
			cooldowns["skill1"] = skill1_cooldown
		&"skill2":
			consume_inspiration(skill2_cost)
			cooldowns["skill2"] = skill2_cooldown
		&"skill3":
			consume_inspiration(skill3_cost)
			cooldowns["skill3"] = skill3_cooldown
	skill_used.emit(skill_name)

func ensure_skill1_started() -> void:
	if float(cooldowns["skill1"]) <= 0.0:
		start_skill(&"skill1")

func start_charge() -> void:
	start_skill(&"skill1")
	dash_direction = facing if facing != Vector2.ZERO else Vector2.RIGHT
	play_animation(&"charge")

func start_dash_from_skill() -> void:
	dash_hit_targets.clear()
	current_attack_name = &"skill1"
	if queued_skill_payload.has("dash_direction"):
		dash_direction = queued_skill_payload["dash_direction"]
	if dash_direction == Vector2.ZERO:
		dash_direction = facing if facing != Vector2.ZERO else Vector2.RIGHT
	dash_direction = dash_direction.normalized()
	play_animation(&"dash")
	_animate_weapon_swing(-36.0, 16.0, 0.08, 0.12)

func process_dash(delta: float) -> bool:
	manual_movement_performed = true
	velocity = dash_direction * dash_speed
	var start_position := global_position
	global_position += velocity * delta
	try_hit_dash_targets_along_segment(start_position, global_position)
	return false

func try_hit_dash_targets_along_segment(start_position: Vector2, end_position: Vector2) -> void:
	for target in get_tree().get_nodes_in_group("damageable"):
		if target == self:
			continue
		if not (target is Node2D):
			continue
		if dash_hit_targets.has(target):
			continue
		if not target.has_method("receive_hit"):
			continue
		var node_2d: Node2D = target
		if _distance_to_segment(node_2d.global_position, start_position, end_position) > dash_hit_radius:
			continue
		try_hit_dash_target(target)

func finish_dash() -> void:
	velocity = Vector2.ZERO
	if current_attack_name != &"":
		attack_finished.emit(current_attack_name)
	current_attack_name = &""
	dash_hit_targets.clear()

func try_hit_dash_target(target: Variant) -> void:
	if target == null:
		return
	if not target.has_method("receive_hit"):
		return
	if dash_hit_targets.has(target):
		return
	dash_hit_targets.append(target)
	var extra_payload := {}
	if skill1_armor_break_upgrade:
		extra_payload["damage_multiplier"] = armor_break_multiplier
		extra_payload["damage_multiplier_duration"] = armor_break_duration
	var payload := AccessoryManager.build_hit_payload(
		self,
		&"skill1",
		get_scaled_damage(skill1_damage),
		crit_rate,
		extra_payload
	)
	target.receive_hit(payload)
	on_attack_landed(&"skill1", target)
	attack_hit.emit(&"skill1", target)

func _distance_to_segment(point: Vector2, start_position: Vector2, end_position: Vector2) -> float:
	var segment := end_position - start_position
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.0001:
		return point.distance_to(start_position)
	var weight := clampf((point - start_position).dot(segment) / segment_length_squared, 0.0, 1.0)
	var closest_point := start_position + segment * weight
	return point.distance_to(closest_point)

func trigger_normal_attack_hit() -> void:
	apply_damage_to_targets_in_arc(attack_damage, attack_range, attack_arc_degrees, &"attack")
	_show_melee_slash_effect(attack_range, attack_arc_degrees)
	_flash_melee_impact()

func start_dodge() -> void:
	consume_inspiration(dodge_cost)
	cooldowns["dodge"] = dodge_cooldown
	dodge_active = true
	dodge_invincible = true
	dodge_elapsed = 0.0
	dodge_direction = move_input if move_input != Vector2.ZERO else facing
	if dodge_direction == Vector2.ZERO:
		dodge_direction = Vector2.RIGHT
	dodge_direction = dodge_direction.normalized()
	play_animation(&"dodge")
	_animate_weapon_swing(-24.0, 12.0, 0.08, 0.1)

func process_dodge(delta: float) -> bool:
	dodge_elapsed += delta
	manual_movement_performed = true
	velocity = dodge_direction * dodge_speed
	global_position += velocity * delta
	return dodge_elapsed >= dodge_duration

func is_dodge_complete() -> bool:
	return dodge_active and dodge_elapsed >= dodge_duration

func finish_dodge() -> void:
	velocity = Vector2.ZERO
	dodge_active = false
	dodge_invincible = false

func trigger_shockwave() -> void:
	var shockwave_targets: Array[Node] = []
	attack_started.emit(&"skill2")
	_show_shockwave()
	var payload := {}
	if skill2_knock_up_upgrade:
		payload["knock_up_duration"] = knock_up_duration
	apply_damage_to_targets(skill2_damage, shockwave_radius, &"skill2", shockwave_targets, payload)
	if skill2_shield_upgrade:
		activate_guard()
	attack_finished.emit(&"skill2")

func cast_skill2() -> void:
	start_skill(&"skill2")
	trigger_shockwave()

func activate_guard() -> void:
	guard_active = true
	guard_time_remaining = guard_duration
	health_component.set_shield(guard_shield_value)
	shield = health_component.shield
	shield_changed.emit(shield)

func end_guard() -> void:
	if not guard_active and shield <= 0.0:
		return
	guard_active = false
	guard_time_remaining = 0.0
	health_component.clear_shield()
	shield = 0.0
	shield_changed.emit(shield)

func apply_sanctuary() -> void:
	if skill3_heal_upgrade:
		heal((max_hp - hp) * 0.1)
	if skill3_restore_defense_upgrade:
		if health_component.has_method("restore_defense_full"):
			health_component.restore_defense_full()
		else:
			health_component.defense = health_component.max_defense
			health_component.defense_changed.emit(health_component.defense, health_component.max_defense)
	active_damage_multiplier = sanctuary_damage_multiplier
	active_damage_reduction = sanctuary_damage_reduction
	health_component.set_damage_reduction(active_damage_reduction)
	buff_active = true
	sanctuary_time_remaining = buff_duration
	attack_started.emit(&"skill3")
	_show_sanctuary_activation()
	attack_finished.emit(&"skill3")

func clear_sanctuary() -> void:
	if not buff_active and sanctuary_time_remaining <= 0.0:
		return
	active_damage_multiplier = 1.0
	active_damage_reduction = 0.0
	health_component.set_damage_reduction(0.0)
	buff_active = false
	sanctuary_time_remaining = 0.0
	sanctuary_ring.visible = false
	sanctuary_ring.rotation = 0.0
	sanctuary_ring.scale = Vector2.ONE
	sanctuary_ring.modulate = Color.WHITE

func cast_skill3() -> void:
	start_skill(&"skill3")
	apply_sanctuary()

func heal(amount: float) -> void:
	health_component.heal(amount)

func get_scaled_damage(base_damage: float) -> float:
	return base_damage * active_damage_multiplier

func get_current_move_speed() -> float:
	return move_speed * slow_factor

func get_effective_move_speed() -> float:
	return get_current_move_speed()

func is_silenced() -> bool:
	return silenced_time_remaining > 0.0

func is_rooted() -> bool:
	return root_time_remaining > 0.0

func is_slowed() -> bool:
	return slow_time_remaining > 0.0 and slow_factor < 0.999

func get_control_status_text() -> String:
	var effects: Array[String] = []
	if is_rooted():
		effects.append("Rooted")
	if is_silenced():
		effects.append("Silenced")
	if is_slowed():
		effects.append("Slowed")
	return ", ".join(effects)

func clear_control_effects(clear_silence: bool = false, clear_root: bool = true, clear_slow: bool = true) -> void:
	if clear_silence:
		silenced_time_remaining = 0.0
	if clear_root:
		root_time_remaining = 0.0
	if clear_slow:
		slow_time_remaining = 0.0
		slow_factor = 1.0
	control_status_changed.emit(get_control_status_text())

func apply_control_effects(payload: Dictionary) -> void:
	if payload.has("silence_duration"):
		silenced_time_remaining = maxf(silenced_time_remaining, float(payload["silence_duration"]))
	if payload.has("root_duration"):
		root_time_remaining = maxf(root_time_remaining, float(payload["root_duration"]))
	if payload.has("slow_duration"):
		slow_time_remaining = maxf(slow_time_remaining, float(payload["slow_duration"]))
		slow_factor = minf(slow_factor, float(payload.get("slow_multiplier", 1.0)))
	control_status_changed.emit(get_control_status_text())

func _update_control_effects(delta: float) -> void:
	hit_invulnerability_remaining = maxf(hit_invulnerability_remaining - delta, 0.0)
	silenced_time_remaining = maxf(silenced_time_remaining - delta, 0.0)
	root_time_remaining = maxf(root_time_remaining - delta, 0.0)
	if slow_time_remaining > 0.0:
		slow_time_remaining = maxf(slow_time_remaining - delta, 0.0)
	else:
		slow_factor = 1.0

func apply_damage_to_overlapping_targets(base_damage: float, radius: float, attack_name: StringName, extra_payload: Dictionary = {}) -> void:
	apply_damage_to_targets(base_damage, radius, attack_name, current_attack_targets, extra_payload)

func apply_damage_to_targets_in_arc(base_damage: float, radius: float, arc_degrees: float, attack_name: StringName, extra_payload: Dictionary = {}) -> void:
	var facing_direction := _attack_facing()
	var attack_origin := _attack_origin()
	for target in get_tree().get_nodes_in_group("damageable"):
		if target == self:
			continue
		if not (target is Node2D):
			continue
		if current_attack_targets.has(target):
			continue
		var node_2d: Node2D = target
		if not MELEE_UTILS.is_point_in_arc(attack_origin, facing_direction, node_2d.global_position, radius, arc_degrees):
			continue
		if not target.has_method("receive_hit"):
			continue
		current_attack_targets.append(target)
		var payload := AccessoryManager.build_hit_payload(
			self,
			attack_name,
			get_scaled_damage(base_damage),
			crit_rate,
			extra_payload
		)
		target.receive_hit(payload)
		on_attack_landed(attack_name, target)
		attack_hit.emit(attack_name, target)

func apply_damage_to_targets(base_damage: float, radius: float, attack_name: StringName, hit_targets: Array[Node], extra_payload: Dictionary = {}) -> void:
	for target in get_tree().get_nodes_in_group("damageable"):
		if target == self:
			continue
		if not (target is Node2D):
			continue
		if hit_targets.has(target):
			continue
		var node_2d: Node2D = target
		if global_position.distance_to(node_2d.global_position) > radius:
			continue
		if not target.has_method("receive_hit"):
			continue
		hit_targets.append(target)
		var payload := AccessoryManager.build_hit_payload(
			self,
			attack_name,
			get_scaled_damage(base_damage),
			crit_rate,
			extra_payload
		)
		target.receive_hit(payload)
		on_attack_landed(attack_name, target)
		attack_hit.emit(attack_name, target)

func receive_hit(payload: Dictionary) -> void:
	if dodge_invincible or hit_invulnerability_remaining > 0.0:
		return
	var result: Dictionary = health_component.receive_hit(payload)
	var final_damage := float(result.get("damage", 0.0))
	var is_critical := bool(result.get("is_critical", false))
	if final_damage > 0.0:
		spawn_damage_number(final_damage, is_critical, global_position)
	if final_damage > 0.0:
		apply_control_effects(payload)
		hit_invulnerability_remaining = hit_invulnerability_duration
	if hp <= 0.0:
		return
	if final_damage >= hit_threshold:
		state_machine.request_hit()

func play_animation(animation_name: StringName) -> void:
	if animation_player.has_animation(animation_name):
		animation_player.play(animation_name)

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area != null and area.has_method("build_damage_payload"):
		receive_hit(area.build_damage_payload())

func _on_health_component_damaged(amount: float, remaining_hp: float, _source: Node) -> void:
	hp = remaining_hp
	shield = health_component.shield
	hp_changed.emit(hp, max_hp)
	shield_changed.emit(shield)
	took_damage.emit(amount, hp)

func _on_health_component_healed(_amount: float, current_hp: float) -> void:
	hp = current_hp
	hp_changed.emit(hp, max_hp)

func _on_health_component_shield_changed(current_shield: float) -> void:
	shield = current_shield
	shield_changed.emit(shield)

func _on_health_component_defense_changed(current_defense: float, max_defense_value: float) -> void:
	defense = current_defense
	max_defense = max_defense_value
	defense_changed.emit(defense, max_defense)

func _on_health_component_died() -> void:
	hp = 0.0
	hp_changed.emit(hp, max_hp)
	sprite.texture = TEXTURE_LOADER.load_texture(KNIGHT_DEATH_TEXTURE_PATH)
	if weapon != null:
		weapon.visible = false
	_spawn_death_burst()
	state_machine.force_change(&"Dead")
	died.emit()

func _setup_weapon_visual() -> void:
	weapon = Node2D.new()
	weapon.name = "Weapon"
	weapon.z_index = 4
	add_child(weapon)
	weapon_sprite = Sprite2D.new()
	weapon_sprite.texture = TEXTURE_LOADER.load_texture(KNIGHT_WEAPON_TEXTURE_PATH)
	weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon_sprite.centered = true
	weapon_sprite.scale = Vector2.ONE * 0.68
	weapon_sprite.position = Vector2(27.0, 0.0)
	weapon.add_child(weapon_sprite)

func _sync_weapon_visual() -> void:
	if weapon == null:
		return
	var side_sign := _get_weapon_side_sign()
	var vertical_bias := clampf(facing.y, -1.0, 1.0)
	var attack_direction := _attack_facing()
	var guard_angle := deg_to_rad(-42.0 * side_sign + vertical_bias * 5.0)
	weapon.visible = hp > 0.0
	weapon.position = Vector2(24.0 * side_sign, -18.0 + vertical_bias * 6.0)
	weapon.rotation = attack_direction.angle() + guard_angle + weapon_swing_rotation * side_sign

func _animate_weapon_swing(windup_degrees: float, strike_degrees: float, windup_duration: float, recover_duration: float = 0.12) -> void:
	if weapon_swing_tween != null:
		weapon_swing_tween.kill()
	weapon_swing_rotation = deg_to_rad(windup_degrees)
	weapon_swing_tween = create_tween()
	weapon_swing_tween.set_parallel(false)
	weapon_swing_tween.tween_property(self, "weapon_swing_rotation", deg_to_rad(strike_degrees), maxf(windup_duration, 0.01)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	weapon_swing_tween.tween_property(self, "weapon_swing_rotation", 0.0, maxf(recover_duration, 0.01)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

func _get_weapon_side_sign() -> float:
	if absf(facing.x) > 0.08:
		return 1.0 if facing.x >= 0.0 else -1.0
	return -1.0 if sprite.flip_h else 1.0

func _attack_facing() -> Vector2:
	return facing.normalized() if facing.length_squared() > 0.0001 else Vector2.RIGHT

func _attack_visual_offset() -> Vector2:
	return _attack_facing() * 16.0 + Vector2(0.0, -4.0)

func _attack_origin() -> Vector2:
	return global_position + _attack_visual_offset()

func set_auto_walk_direction(direction: Vector2) -> void:
	auto_walk_direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector2.ZERO

func _is_auto_walking() -> bool:
	return auto_walk_direction.length_squared() > 0.0001

func _flash_melee_impact() -> void:
	sprite.modulate = Color(1.0, 0.96, 0.82, 1.0)
	var timer := get_tree().create_timer(0.08)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self) and hp > 0.0:
			sprite.modulate = Color.WHITE
	)

func _show_melee_slash_effect(radius: float, arc_degrees: float) -> void:
	var attack_direction := _attack_facing()
	var arc := Line2D.new()
	arc.width = 14.0
	arc.antialiased = false
	arc.default_color = Color(1.0, 0.9, 0.62, 0.96)
	arc.position = _attack_visual_offset()
	arc.rotation = attack_direction.angle()
	arc.points = _build_sweep_points(radius, arc_degrees, 9)
	effects_layer.add_child(arc)

	var burst := Polygon2D.new()
	burst.color = Color(1.0, 0.82, 0.54, 0.9)
	burst.position = attack_direction * (radius * 0.82)
	burst.rotation = attack_direction.angle()
	burst.polygon = PackedVector2Array([
		Vector2(-18.0, -6.0),
		Vector2(6.0, -14.0),
		Vector2(28.0, 0.0),
		Vector2(6.0, 14.0),
		Vector2(-18.0, 6.0),
		Vector2(-2.0, 0.0)
	])
	effects_layer.add_child(burst)

	var shock := Line2D.new()
	shock.width = 5.0
	shock.antialiased = false
	shock.default_color = Color(1.0, 0.98, 0.86, 0.75)
	shock.position = attack_direction * (radius * 0.55)
	shock.rotation = attack_direction.angle()
	shock.points = PackedVector2Array([
		Vector2(-14.0, 0.0),
		Vector2(0.0, 0.0),
		Vector2(36.0, 0.0)
	])
	effects_layer.add_child(shock)

	var arc_tween := arc.create_tween()
	arc_tween.tween_property(arc, "scale", Vector2(1.14, 1.22), 0.14)
	arc_tween.parallel().tween_property(arc, "modulate:a", 0.0, 0.14)
	arc_tween.finished.connect(arc.queue_free)

	var burst_tween := burst.create_tween()
	burst_tween.tween_property(burst, "scale", Vector2.ONE * 1.24, 0.12)
	burst_tween.parallel().tween_property(burst, "modulate:a", 0.0, 0.12)
	burst_tween.finished.connect(burst.queue_free)

	var shock_tween := shock.create_tween()
	shock_tween.tween_property(shock, "scale", Vector2(1.2, 1.0), 0.1)
	shock_tween.parallel().tween_property(shock, "modulate:a", 0.0, 0.1)
	shock_tween.finished.connect(shock.queue_free)

func _show_shockwave() -> void:
	shockwave_ring.visible = true
	shockwave_ring.scale = Vector2.ONE * 0.2
	shockwave_ring.modulate.a = 1.0
	var duration := maxf(skill2_duration, 0.05)
	var tween := create_tween()
	tween.tween_property(shockwave_ring, "scale", Vector2.ONE, duration)
	tween.parallel().tween_property(shockwave_ring, "modulate:a", 0.0, duration)
	tween.finished.connect(func() -> void:
		shockwave_ring.visible = false
		shockwave_ring.scale = Vector2.ONE
		shockwave_ring.modulate.a = 1.0
	)

func _show_sanctuary_activation() -> void:
	sanctuary_ring.visible = true
	sanctuary_ring.rotation = 0.0
	sanctuary_ring.scale = Vector2.ONE * 0.78
	sanctuary_ring.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween := create_tween()
	tween.tween_property(sanctuary_ring, "scale", Vector2.ONE, 0.2)
	tween.parallel().tween_property(sanctuary_ring, "modulate:a", 1.0, 0.2)

func _update_guard(delta: float) -> void:
	if not guard_active:
		return
	guard_time_remaining = maxf(guard_time_remaining - delta, 0.0)
	if guard_time_remaining <= 0.0 or shield <= 0.0:
		end_guard()

func _update_sanctuary(delta: float) -> void:
	if not buff_active:
		return
	sanctuary_time_remaining = maxf(sanctuary_time_remaining - delta, 0.0)
	_spawn_sanctuary_visual(delta)
	if sanctuary_time_remaining <= 0.0:
		clear_sanctuary()

func _spawn_sanctuary_visual(delta: float) -> void:
	sanctuary_ring.rotation += delta * 2.5

func spawn_damage_number(amount: float, is_critical: bool, world_position: Vector2) -> void:
	var damage_number := DAMAGE_NUMBER_SCENE.instantiate()
	damage_number.position = to_local(world_position) + Vector2(0.0, -32.0)
	damage_number.setup(amount, is_critical)
	effects_layer.add_child(damage_number)

func _setup_visual_shapes() -> void:
	slash_arc.position = Vector2(14.0, -4.0)
	slash_arc.polygon = _build_slash_arc_polygon(attack_range, attack_arc_degrees, 12)
	slash_arc.color = Color(1.0, 0.88, 0.54, 0.72)
	shockwave_ring.points = _build_ring_points(shockwave_radius)
	sanctuary_ring.points = _build_ring_points(sanctuary_radius)

func _build_ring_points(radius: float, steps: int = 16) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(steps):
		var angle := TAU * float(index) / float(steps)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points

func _build_slash_arc_polygon(radius: float, arc_degrees: float, steps: int = 12) -> PackedVector2Array:
	var points := PackedVector2Array()
	var half_arc := deg_to_rad(arc_degrees) * 0.5
	points.append(Vector2.ZERO)
	for index in range(steps + 1):
		var weight := float(index) / float(steps)
		var angle := lerpf(-half_arc, half_arc, weight)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points

func _build_sweep_points(radius: float, arc_degrees: float, steps: int = 8) -> PackedVector2Array:
	var points := PackedVector2Array()
	var half_arc := deg_to_rad(arc_degrees) * 0.5
	for index in range(steps + 1):
		var weight := float(index) / float(steps)
		var angle := lerpf(-half_arc, half_arc, weight)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points

func _sprite_scale(x_scale: float = 1.0, y_scale: float = 1.0) -> Vector2:
	return Vector2(BASE_SPRITE_SCALE.x * x_scale, BASE_SPRITE_SCALE.y * y_scale)

func _build_animations() -> void:
	animation_player.root_node = NodePath("..")
	var library: AnimationLibrary = animation_player.get_animation_library(&"") if animation_player.has_animation_library(&"") else null
	if library == null:
		library = AnimationLibrary.new()
		animation_player.add_animation_library(&"", library)
	_add_idle_animation(library)
	_add_move_animation(library)
	_add_attack_animation(library)
	_add_charge_animation(library)
	_add_dash_animation(library)
	_add_dodge_animation(library)
	_add_skill2_animation(library)
	_add_skill3_animation(library)
	_add_guard_animation(library)
	_add_buff_animation(library)
	_add_hit_animation(library)
	_add_dead_animation(library)

func _store_animation(library: AnimationLibrary, name: StringName, animation: Animation) -> void:
	if library.has_animation(name):
		library.remove_animation(name)
	library.add_animation(name, animation)

func _add_value_track(animation: Animation, path: String, keys: Array) -> void:
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(path))
	for key in keys:
		animation.track_insert_key(track, float(key[0]), key[1])

func _add_idle_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = 0.8
	animation.loop_mode = Animation.LOOP_LINEAR
	_add_value_track(animation, "Sprite2D:scale", [[0.0, _sprite_scale()], [0.4, _sprite_scale(1.02, 0.98)], [0.8, _sprite_scale()]])
	_add_value_track(animation, "Sprite2D:position", [[0.0, Vector2.ZERO], [0.4, Vector2(0.0, -2.0)], [0.8, Vector2.ZERO]])
	_store_animation(library, &"idle", animation)

func _add_move_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = 0.35
	animation.loop_mode = Animation.LOOP_LINEAR
	_add_value_track(animation, "Sprite2D:position", [[0.0, Vector2(0.0, 0.0)], [0.175, Vector2(0.0, -6.0)], [0.35, Vector2(0.0, 0.0)]])
	_add_value_track(animation, "Sprite2D:rotation", [[0.0, -0.08], [0.175, 0.08], [0.35, -0.08]])
	_store_animation(library, &"move", animation)

func _add_attack_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = attack_windup + attack_hit_frame + attack_recovery
	_add_value_track(animation, "Sprite2D:rotation", [[0.0, -0.22], [attack_windup * 0.75, -0.12], [attack_windup + attack_hit_frame * 0.6, 0.22], [animation.length, 0.0]])
	_add_value_track(animation, "Sprite2D:scale", [[0.0, _sprite_scale(0.92, 1.08)], [attack_windup * 0.85, _sprite_scale(1.28, 0.86)], [animation.length, _sprite_scale()]])
	_add_value_track(animation, "Sprite2D:position", [[0.0, Vector2(-4.0, 0.0)], [attack_windup, Vector2(6.0, -4.0)], [animation.length, Vector2.ZERO]])
	_add_value_track(animation, "SlashArc:scale", [[0.0, Vector2(0.12, 0.12)], [attack_windup, Vector2(1.18, 1.08)], [animation.length, Vector2(0.42, 0.42)]])
	_add_value_track(animation, "SlashArc:modulate", [[0.0, Color(1.0, 0.96, 0.8, 0.0)], [attack_windup * 0.65, Color(1.0, 0.92, 0.66, 0.84)], [animation.length, Color(1.0, 0.92, 0.66, 0.0)]])
	_store_animation(library, &"attack", animation)

func _add_charge_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = charge_duration
	_add_value_track(animation, "Sprite2D:scale", [[0.0, _sprite_scale()], [charge_duration, _sprite_scale(1.36, 0.88)]])
	_add_value_track(animation, "Sprite2D:modulate", [[0.0, Color(0.75, 0.85, 1.0, 1.0)], [charge_duration, Color(1.0, 0.85, 0.35, 1.0)]])
	_store_animation(library, &"charge", animation)

func _add_dash_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = dash_duration
	_add_value_track(animation, "Sprite2D:scale", [[0.0, _sprite_scale(1.4, 0.72)], [dash_duration, _sprite_scale()]])
	_add_value_track(animation, "Sprite2D:modulate", [[0.0, Color(1.0, 1.0, 1.0, 0.7)], [dash_duration, Color.WHITE]])
	_store_animation(library, &"dash", animation)

func _add_dodge_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = dodge_duration
	_add_value_track(animation, "Sprite2D:scale", [[0.0, _sprite_scale(1.22, 0.82)], [dodge_duration, _sprite_scale()]])
	_add_value_track(animation, "Sprite2D:modulate", [[0.0, Color(0.88, 0.94, 1.0, 0.72)], [dodge_duration, Color.WHITE]])
	_store_animation(library, &"dodge", animation)

func _add_skill2_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = skill2_duration
	_add_value_track(animation, "Sprite2D:scale", [[0.0, _sprite_scale()], [skill2_duration * 0.5, _sprite_scale(0.88, 1.28)], [skill2_duration, _sprite_scale()]])
	_add_value_track(animation, "Sprite2D:rotation", [[0.0, -0.05], [skill2_duration, 0.05]])
	_store_animation(library, &"skill2", animation)

func _add_skill3_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = skill3_duration
	_add_value_track(animation, "Sprite2D:scale", [[0.0, _sprite_scale(0.88, 0.88)], [skill3_duration * 0.5, _sprite_scale(1.28, 1.28)], [skill3_duration, _sprite_scale()]])
	_add_value_track(animation, "SanctuaryRing:modulate", [[0.0, Color(1.0, 0.92, 0.55, 0.1)], [skill3_duration, Color(1.0, 0.92, 0.55, 0.95)]])
	_store_animation(library, &"skill3", animation)

func _add_guard_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = 0.5
	animation.loop_mode = Animation.LOOP_LINEAR
	_add_value_track(animation, "Sprite2D:scale", [[0.0, _sprite_scale(0.96, 1.04)], [0.25, _sprite_scale(1.08, 0.96)], [0.5, _sprite_scale(0.96, 1.04)]])
	_store_animation(library, &"guard", animation)

func _add_buff_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = 0.75
	animation.loop_mode = Animation.LOOP_LINEAR
	_add_value_track(animation, "SanctuaryRing:rotation", [[0.0, 0.0], [0.75, 0.45]])
	_add_value_track(animation, "Sprite2D:modulate", [[0.0, Color(1.0, 0.95, 0.7, 1.0)], [0.375, Color(1.0, 1.0, 0.92, 1.0)], [0.75, Color(1.0, 0.95, 0.7, 1.0)]])
	_store_animation(library, &"buff", animation)

func _add_hit_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = hit_stun_duration
	_add_value_track(animation, "Sprite2D:position", [[0.0, Vector2(-4.0, 0.0)], [hit_stun_duration * 0.5, Vector2(4.0, 0.0)], [hit_stun_duration, Vector2.ZERO]])
	_store_animation(library, &"hit", animation)

func _add_dead_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = 0.7
	_add_value_track(animation, "Sprite2D:rotation", [[0.0, 0.0], [0.7, PI * 0.5]])
	_add_value_track(animation, "Sprite2D:position", [[0.0, Vector2.ZERO], [0.28, Vector2(-8.0, 8.0)], [0.7, Vector2(-12.0, 14.0)]])
	_add_value_track(animation, "Sprite2D:scale", [[0.0, _sprite_scale()], [0.28, _sprite_scale(1.08, 0.82)], [0.7, _sprite_scale(1.02, 0.76)]])
	_add_value_track(animation, "Sprite2D:modulate", [[0.0, Color.WHITE], [0.7, Color(0.45, 0.45, 0.45, 1.0)]])
	_store_animation(library, &"dead", animation)

func _spawn_death_burst() -> void:
	if effects_layer == null:
		return
	for index in range(6):
		var chip := Polygon2D.new()
		chip.color = Color(1.0, 0.86, 0.62, 0.86)
		chip.polygon = PackedVector2Array([
			Vector2(-4.0, -4.0),
			Vector2(4.0, -4.0),
			Vector2(4.0, 4.0),
			Vector2(-4.0, 4.0)
		])
		effects_layer.add_child(chip)
		var direction := Vector2.RIGHT.rotated(TAU * float(index) / 6.0)
		var tween := chip.create_tween()
		tween.tween_property(chip, "position", direction * 24.0 + Vector2(0.0, -6.0), 0.2)
		tween.parallel().tween_property(chip, "modulate:a", 0.0, 0.2)
		tween.finished.connect(chip.queue_free)
