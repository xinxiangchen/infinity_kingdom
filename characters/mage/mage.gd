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

const DAMAGE_NUMBER_SCENE := preload("res://effects/damage_number.tscn")
const ARCANE_BOLT_SCENE := preload("res://effects/projectiles/arcane_bolt.tscn")
const TEXTURE_LOADER := preload("res://combat/runtime_texture_loader.gd")
const MAGE_WEAPON_TEXTURE_PATH := "res://art/final_materials/weapons/player_mage_staff_lv3.png"
const MAGE_DEATH_TEXTURE_PATH := "res://art/final_materials/deaths/player_mage_dead.png"
const BODY_BASE_SCALE := Vector2(0.85, 0.85)

@export_group("Core Stats")
@export var max_hp: float = 70.0
@export var max_inspiration: float = 80.0
@export var defense: float = 60.0
@export var max_defense: float = 60.0
@export var move_speed: float = 232.0
@export var attack_damage: float = 90.0
@export var attack_interval: float = 0.98
@export_range(0.0, 1.0, 0.01) var crit_rate: float = 0.3
@export var inspiration_gain_on_attack_hit: float = 8.0

@export_group("Normal Attack Timing")
@export var attack_windup: float = 0.27
@export var attack_hit_frame: float = 0.08
@export var attack_recovery: float = 0.36
@export var attack_targeting_range: float = 560.0

@export_group("Skill 1: Arcane Blades")
@export var skill1_cost: float = 35.0
@export var skill1_cooldown: float = 12.0
@export var skill1_damage: float = 50.0
@export var skill1_cast_duration: float = 0.35
@export var blade_duration: float = 10.0
@export var blade_radius: float = 90.0
@export var blade_tick_interval: float = 1.0
@export var skill1_shield_upgrade: bool = false
@export var skill1_shield_value: float = 50.0
@export var skill1_attack_blades_upgrade: bool = false
@export var skill1_attack_blades_damage: float = 50.0
@export var skill1_attack_blades_hits: int = 3

@export_group("Skill 2: Arcane Burst")
@export var skill2_cost: float = 40.0
@export var skill2_cooldown: float = 0.0
@export var skill2_damage: float = 100.0
@export var skill2_cast_duration: float = 0.38
@export var burst_radius: float = 120.0
@export var burst_targeting_range: float = 540.0
@export var skill2_range_upgrade: bool = false
@export var skill2_extra_damage_upgrade: bool = false
@export var skill2_bonus_damage: float = 20.0
@export var skill2_chain_burst_upgrade: bool = false
@export var skill2_chain_damage: float = 60.0

@export_group("Skill 3: Silence Decree")
@export var skill3_cost: float = 25.0
@export var skill3_cooldown: float = 8.0
@export var skill3_cast_duration: float = 0.28
@export var silence_duration: float = 3.0
@export var skill3_slow_upgrade: bool = false
@export var slow_duration: float = 8.0
@export var slow_multiplier: float = 0.5
@export var skill3_root_upgrade: bool = false
@export var root_duration: float = 3.0

@export_group("Dodge")
@export var dodge_cost: float = 5.0
@export var dodge_cooldown: float = 3.0
@export var dodge_duration: float = 0.28
@export var dodge_speed: float = 820.0

@export_group("Hit / Combat")
@export var hit_stun_duration: float = 0.25
@export var hit_threshold: float = 1.0
@export var hit_invulnerability_duration: float = 0.34

@onready var state_machine: Node = $StateMachine
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var body: Sprite2D = $Body
@onready var focus_ring: Line2D = $FocusRing
@onready var burst_ring: Line2D = $BurstRing
@onready var enchant_sigil: Line2D = $EnchantSigil
@onready var blade_orbit: Node2D = $BladeOrbit
@onready var projectile_spawner: Node2D = $ProjectileSpawner
@onready var hurtbox: Area2D = $Hurtbox
@onready var health_component: Node = $HealthComponent
@onready var effects_layer: Node2D = $EffectsLayer

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
var queued_skill: StringName = &""
var queued_skill_payload: Dictionary = {}
var current_attack_name: StringName = &""
var manual_movement_performed: bool = false
var blades_active: bool = false
var blade_time_remaining: float = 0.0
var blade_hit_cooldowns: Dictionary = {}
var attack_blade_bonus_hits_remaining: int = 0
var enchant_active: bool = false
var current_skill_target: Node2D = null
var blade_nodes: Array[Polygon2D] = []
var dodge_direction: Vector2 = Vector2.RIGHT
var dodge_elapsed: float = 0.0
var dodge_active: bool = false
var dodge_invincible: bool = false
var weapon: Node2D = null
var weapon_sprite: Sprite2D = null
var weapon_angle_offset: float = 0.0
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
	for child in blade_orbit.get_children():
		if child is Polygon2D:
			blade_nodes.append(child)
	_build_animations()
	focus_ring.visible = false
	burst_ring.visible = false
	enchant_sigil.visible = false
	blade_orbit.visible = false
	emit_stat_signals()
	state_machine.initialize(self)

func _physics_process(delta: float) -> void:
	manual_movement_performed = false
	var requested_move_input := auto_walk_direction if _is_auto_walking() else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if requested_move_input != Vector2.ZERO:
		facing = requested_move_input.normalized()
	move_input = requested_move_input if _is_auto_walking() else (Vector2.ZERO if root_time_remaining > 0.0 else requested_move_input)
	update_cooldowns(delta)
	state_machine.physics_update(delta)
	if not manual_movement_performed:
		move_and_slide()
	sync_visuals()

func _process(delta: float) -> void:
	_update_control_effects(delta)
	_update_blades(delta)
	_update_targeting_visuals(delta)

func emit_stat_signals() -> void:
	hp_changed.emit(hp, max_hp)
	inspiration_changed.emit(inspiration, max_inspiration)
	defense_changed.emit(defense, max_defense)

func get_character_name() -> String:
	return "Mage"

func get_upgrade_sections() -> Array:
	return [
		{
			"title": "Skill 1: 法刃回旋",
			"upgrades": [
				{
					"id": "skill1_shield",
					"label": "护体",
					"description": "生成临时护盾。",
					"fields": ["skill1_shield_upgrade"]
				},
				{
					"id": "skill1_attack_blades",
					"label": "刃环",
					"description": "前三次攻击附带法刃伤害。",
					"fields": ["skill1_attack_blades_upgrade"]
				}
			]
		},
		{
			"title": "Skill 2: 奥术爆裂",
			"upgrades": [
				{
					"id": "skill2_amp",
					"label": "扩能",
					"description": "同时提高爆炸范围与伤害。",
					"fields": ["skill2_range_upgrade", "skill2_extra_damage_upgrade"]
				},
				{
					"id": "skill2_chain",
					"label": "连爆",
					"description": "第一次爆炸后追加一次小爆炸。",
					"fields": ["skill2_chain_burst_upgrade"]
				}
			]
		},
		{
			"title": "Skill 3: 沉默诏令",
			"upgrades": [
				{
					"id": "skill3_slow",
					"label": "迟滞",
					"description": "附加减速效果。",
					"fields": ["skill3_slow_upgrade"]
				},
				{
					"id": "skill3_root",
					"label": "禁制",
					"description": "附加禁锢效果。",
					"fields": ["skill3_root_upgrade"]
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

func gain_inspiration(amount: float) -> void:
	if amount <= 0.0 or hp <= 0.0:
		return
	var previous := inspiration
	inspiration = clampf(inspiration + amount, 0.0, max_inspiration)
	if not is_equal_approx(previous, inspiration):
		inspiration_changed.emit(inspiration, max_inspiration)

func on_attack_landed(attack_name: StringName, target: Node) -> void:
	gain_inspiration(inspiration_gain_on_attack_hit)
	if enchant_active and target != null and target.has_method("apply_control_effects"):
		target.apply_control_effects(_build_control_payload())
		clear_skill3_enchant()
	if skill1_attack_blades_upgrade and attack_blade_bonus_hits_remaining > 0 and target != null and target.has_method("receive_hit"):
		attack_blade_bonus_hits_remaining -= 1
		target.receive_hit(AccessoryManager.build_hit_payload(
			self,
			&"skill1_bonus",
			skill1_attack_blades_damage,
			crit_rate
		))
	AccessoryManager.apply_on_hit_effects(self, attack_name, target)

func sync_visuals() -> void:
	if absf(facing.x) > 0.01:
		body.flip_h = facing.x < 0.0
	projectile_spawner.position.x = 26.0 if facing.x >= 0.0 else -26.0
	_sync_weapon_visual()
	if hp <= 0.0:
		modulate = Color(0.35, 0.35, 0.35, 1.0)
	elif dodge_invincible:
		modulate = Color(0.84, 0.92, 1.0, 0.9)
	elif hit_invulnerability_remaining > 0.0:
		var invulnerability_pulse := 0.76 + 0.18 * sin(Time.get_ticks_msec() * 0.018)
		modulate = Color(1.0, 1.0, 1.0, invulnerability_pulse)
	elif state_machine.get_state_name() == &"Hit":
		modulate = Color(1.0, 0.7, 0.7, 1.0)
	elif silenced_time_remaining > 0.0:
		modulate = Color(0.84, 0.76, 1.0, 1.0)
	elif enchant_active:
		modulate = Color(1.0, 0.92, 0.72, 1.0)
	elif blades_active:
		modulate = Color(0.78, 0.88, 1.0, 1.0)
	else:
		modulate = Color.WHITE
	body.modulate = Color.WHITE

func update_cooldowns(delta: float) -> void:
	for key in cooldowns.keys():
		cooldowns[key] = maxf(float(cooldowns[key]) - delta, 0.0)

func can_use_skill(cost: float) -> bool:
	return inspiration >= cost

func consume_inspiration(cost: float) -> void:
	inspiration = clampf(inspiration - cost, 0.0, max_inspiration)
	inspiration_changed.emit(inspiration, max_inspiration)

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
			return can_use_skill(skill2_cost) and float(cooldowns["skill2"]) <= 0.0 and find_primary_target(burst_targeting_range) != null
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
		return &"Skill"
	if Input.is_action_just_pressed("skill_2") and can_cast_skill(&"skill2"):
		prepare_skill_request(&"skill2")
		return &"Skill"
	if Input.is_action_just_pressed("skill_3") and can_cast_skill(&"skill3"):
		prepare_skill_request(&"skill3")
		return &"Skill"
	if move_input != Vector2.ZERO:
		return &"Move"
	return &"Idle"

func prepare_skill_request(skill_name: StringName) -> void:
	queued_skill = skill_name
	queued_skill_payload.clear()
	if skill_name == &"skill2":
		var target := find_primary_target(burst_targeting_range)
		if target != null:
			queued_skill_payload["target"] = target

func get_queued_skill() -> StringName:
	return queued_skill

func consume_queued_skill() -> StringName:
	var skill_name := queued_skill
	queued_skill = &""
	return skill_name

func start_attack() -> void:
	cooldowns["attack"] = attack_interval
	current_attack_name = &"attack"
	attack_started.emit(current_attack_name)
	play_animation(&"attack")
	_animate_weapon_swing(-12.0, 8.0, attack_windup + attack_hit_frame)

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
	_animate_weapon_swing(-18.0, 12.0, dodge_duration)

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

func trigger_normal_attack_hit() -> void:
	var direction := _get_attack_direction()
	_spawn_arcane_bolt(direction, attack_damage, _get_current_crit_rate(), &"attack")

func finish_attack() -> void:
	if current_attack_name != &"":
		attack_finished.emit(current_attack_name)
	current_attack_name = &""

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

func start_skill1_cast() -> void:
	start_skill(&"skill1")
	current_attack_name = &"skill1"
	play_animation(&"skill1")
	_animate_weapon_swing(-10.0, 7.0, skill1_cast_duration)

func cast_skill1_blades() -> void:
	if skill1_shield_upgrade:
		health_component.set_shield(skill1_shield_value)
	attack_started.emit(&"skill1")
	blades_active = true
	blade_time_remaining = blade_duration
	blade_hit_cooldowns.clear()
	if skill1_attack_blades_upgrade:
		attack_blade_bonus_hits_remaining = skill1_attack_blades_hits
	blade_orbit.visible = true
	attack_finished.emit(&"skill1")

func start_skill2_cast() -> void:
	start_skill(&"skill2")
	current_attack_name = &"skill2"
	current_skill_target = queued_skill_payload.get("target", null)
	play_animation(&"skill2")
	_animate_weapon_swing(-8.0, 6.0, skill2_cast_duration)

func release_skill2_burst() -> void:
	attack_started.emit(&"skill2")
	var radius := burst_radius + (32.0 if skill2_range_upgrade else 0.0)
	var damage := skill2_damage + (skill2_bonus_damage if skill2_extra_damage_upgrade else 0.0)
	var burst_center := global_position + facing * 120.0
	if current_skill_target != null and is_instance_valid(current_skill_target):
		burst_center = current_skill_target.global_position
	_show_burst_ring(burst_center, radius)
	_apply_area_damage(burst_center, radius, damage, &"skill2")
	if skill2_chain_burst_upgrade:
		var timer := get_tree().create_timer(0.18)
		timer.timeout.connect(func() -> void:
			if is_instance_valid(self):
				_show_burst_ring(burst_center, radius * 0.7)
				_apply_area_damage(burst_center, radius * 0.7, skill2_chain_damage, &"skill2")
		)
	attack_finished.emit(&"skill2")

func start_skill3_cast() -> void:
	start_skill(&"skill3")
	current_attack_name = &"skill3"
	play_animation(&"skill3")
	_animate_weapon_swing(-10.0, 8.0, skill3_cast_duration)

func apply_skill3_enchant() -> void:
	attack_started.emit(&"skill3")
	enchant_active = true
	enchant_sigil.visible = true
	enchant_sigil.rotation = 0.0
	enchant_sigil.scale = Vector2.ONE
	attack_finished.emit(&"skill3")

func finish_skill_cast(skill_name: StringName) -> void:
	if current_attack_name == skill_name:
		current_attack_name = &""
	if skill_name == &"skill2":
		current_skill_target = null

func clear_arcane_blades() -> void:
	blades_active = false
	blade_time_remaining = 0.0
	blade_hit_cooldowns.clear()
	blade_orbit.visible = false

func clear_skill3_enchant() -> void:
	enchant_active = false
	enchant_sigil.visible = false

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

func find_primary_target(max_range: float) -> Node2D:
	var nearest_target: Node2D = null
	var nearest_distance := max_range
	for target in get_tree().get_nodes_in_group("damageable"):
		if target == self or not (target is Node2D):
			continue
		var node_2d: Node2D = target
		var distance := global_position.distance_to(node_2d.global_position)
		if distance > nearest_distance:
			continue
		nearest_distance = distance
		nearest_target = node_2d
	return nearest_target

func heal(amount: float) -> void:
	health_component.heal(amount)

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

func _get_attack_direction() -> Vector2:
	var target := find_primary_target(attack_targeting_range)
	if target != null:
		var direction := (target.global_position - global_position).normalized()
		if direction != Vector2.ZERO:
			facing = direction
			return direction
	return facing if facing != Vector2.ZERO else Vector2.RIGHT

func _get_current_crit_rate() -> float:
	return crit_rate

func _spawn_arcane_bolt(direction: Vector2, damage: float, hit_crit_rate: float, attack_label: StringName) -> void:
	var bolt := ARCANE_BOLT_SCENE.instantiate()
	bolt.global_position = projectile_spawner.global_position
	get_tree().current_scene.add_child(bolt)
	bolt.setup(self, direction, damage, hit_crit_rate, attack_label)

func _apply_area_damage(center: Vector2, radius: float, damage: float, attack_name: StringName) -> void:
	for target in get_tree().get_nodes_in_group("damageable"):
		if target == self or not (target is Node2D):
			continue
		var node_2d: Node2D = target
		if center.distance_to(node_2d.global_position) > radius:
			continue
		if not target.has_method("receive_hit"):
			continue
		target.receive_hit(AccessoryManager.build_hit_payload(
			self,
			attack_name,
			damage,
			_get_current_crit_rate()
		))
		on_attack_landed(attack_name, target)
		attack_hit.emit(attack_name, target)

func _build_control_payload() -> Dictionary:
	var payload := {
		"silence_duration": silence_duration
	}
	if skill3_slow_upgrade:
		payload["slow_duration"] = slow_duration
		payload["slow_multiplier"] = slow_multiplier
	if skill3_root_upgrade:
		payload["root_duration"] = root_duration
	return payload

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

func _update_blades(delta: float) -> void:
	if not blades_active:
		return
	blade_time_remaining = maxf(blade_time_remaining - delta, 0.0)
	blade_orbit.visible = true
	blade_orbit.rotation += delta * 2.8
	for key in blade_hit_cooldowns.keys():
		blade_hit_cooldowns[key] = maxf(float(blade_hit_cooldowns[key]) - delta, 0.0)
	for index in range(blade_nodes.size()):
		var angle := blade_orbit.rotation + TAU * float(index) / float(max(blade_nodes.size(), 1))
		blade_nodes[index].position = Vector2.RIGHT.rotated(angle) * 34.0
	for target in get_tree().get_nodes_in_group("damageable"):
		if target == self or not (target is Node2D):
			continue
		if not target.has_method("receive_hit"):
			continue
		var node_2d: Node2D = target
		if global_position.distance_to(node_2d.global_position) > blade_radius:
			continue
		var key := target.get_instance_id()
		if float(blade_hit_cooldowns.get(key, 0.0)) > 0.0:
			continue
		blade_hit_cooldowns[key] = blade_tick_interval
		target.receive_hit(AccessoryManager.build_hit_payload(
			self,
			&"skill1",
			skill1_damage,
			_get_current_crit_rate()
		))
		on_attack_landed(&"skill1", target)
		attack_hit.emit(&"skill1", target)
	if blade_time_remaining <= 0.0:
		clear_arcane_blades()

func _update_targeting_visuals(delta: float) -> void:
	var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.008)
	if state_machine.get_state_name() == &"Attack":
		focus_ring.visible = true
		focus_ring.rotation = facing.angle()
		focus_ring.scale = Vector2.ONE * (0.9 + 0.08 * pulse)
		focus_ring.modulate = Color(0.74, 0.88, 1.0, 0.45 + 0.25 * pulse)
	else:
		focus_ring.visible = false
	if enchant_active:
		enchant_sigil.visible = true
		enchant_sigil.rotation += delta * 2.4
		enchant_sigil.scale = Vector2.ONE * (0.94 + 0.08 * pulse)
	else:
		enchant_sigil.visible = false

func _show_burst_ring(center: Vector2, radius: float) -> void:
	var ring := Line2D.new()
	ring.width = 3.0
	ring.closed = true
	ring.default_color = Color(0.76, 0.88, 1.0, 0.88)
	ring.points = _build_ring_points(radius, 18)
	ring.global_position = center
	get_tree().current_scene.add_child(ring)
	var tween := create_tween()
	tween.tween_property(ring, "scale", Vector2.ONE * 1.18, 0.16)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.16)
	tween.finished.connect(ring.queue_free)

func spawn_damage_number(amount: float, is_critical: bool, world_position: Vector2) -> void:
	var damage_number := DAMAGE_NUMBER_SCENE.instantiate()
	damage_number.position = to_local(world_position) + Vector2(0.0, -32.0)
	damage_number.setup(amount, is_critical)
	effects_layer.add_child(damage_number)

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
	body.texture = TEXTURE_LOADER.load_texture(MAGE_DEATH_TEXTURE_PATH)
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
	weapon_sprite.texture = TEXTURE_LOADER.load_texture(MAGE_WEAPON_TEXTURE_PATH)
	weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon_sprite.centered = true
	weapon_sprite.scale = Vector2.ONE * 0.5
	weapon_sprite.flip_h = true
	weapon.add_child(weapon_sprite)

func _sync_weapon_visual() -> void:
	if weapon == null:
		return
	var side_sign := _get_weapon_side_sign()
	var vertical_bias := clampf(facing.y, -1.0, 1.0)
	var base_right_angle := deg_to_rad(78.0)
	var base_angle := base_right_angle if side_sign > 0.0 else PI - base_right_angle
	weapon.visible = hp > 0.0
	weapon.position = Vector2(17.0 * side_sign, -16.0 + vertical_bias * 5.0)
	weapon.rotation = base_angle + deg_to_rad(vertical_bias * 5.0) + weapon_angle_offset * side_sign
	if weapon_sprite != null:
		weapon_sprite.rotation = deg_to_rad(30.0 * side_sign)

func _animate_weapon_swing(start_degrees: float, end_degrees: float, duration: float) -> void:
	weapon_angle_offset = deg_to_rad(start_degrees)
	var tween := create_tween()
	tween.tween_property(self, "weapon_angle_offset", deg_to_rad(end_degrees), maxf(duration * 0.66, 0.01)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "weapon_angle_offset", 0.0, maxf(duration * 0.34, 0.01)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

func _get_weapon_side_sign() -> float:
	if absf(facing.x) > 0.08:
		return 1.0 if facing.x >= 0.0 else -1.0
	return -1.0 if body.flip_h else 1.0

func set_auto_walk_direction(direction: Vector2) -> void:
	auto_walk_direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector2.ZERO

func _is_auto_walking() -> bool:
	return auto_walk_direction.length_squared() > 0.0001

func _build_ring_points(radius: float, steps: int = 16) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(steps):
		var angle := TAU * float(index) / float(steps)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points

func _body_scale(x_scale: float = 1.0, y_scale: float = 1.0) -> Vector2:
	return Vector2(BODY_BASE_SCALE.x * x_scale, BODY_BASE_SCALE.y * y_scale)

func _build_animations() -> void:
	animation_player.root_node = NodePath("..")
	var library: AnimationLibrary = animation_player.get_animation_library(&"") if animation_player.has_animation_library(&"") else null
	if library == null:
		library = AnimationLibrary.new()
		animation_player.add_animation_library(&"", library)
	_add_idle_animation(library)
	_add_move_animation(library)
	_add_attack_animation(library)
	_add_dodge_animation(library)
	_add_skill_animation(library, &"skill1", skill1_cast_duration, -0.12, 0.1)
	_add_skill_animation(library, &"skill2", skill2_cast_duration, -0.08, 0.08)
	_add_skill_animation(library, &"skill3", skill3_cast_duration, -0.04, 0.04)
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
	animation.length = 0.85
	animation.loop_mode = Animation.LOOP_LINEAR
	_add_value_track(animation, "Body:position", [[0.0, Vector2.ZERO], [0.425, Vector2(0.0, -3.0)], [0.85, Vector2.ZERO]])
	_add_value_track(animation, "Body:scale", [[0.0, _body_scale()], [0.425, _body_scale(1.03, 0.97)], [0.85, _body_scale()]])
	_store_animation(library, &"idle", animation)

func _add_move_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = 0.32
	animation.loop_mode = Animation.LOOP_LINEAR
	_add_value_track(animation, "Body:rotation", [[0.0, -0.05], [0.16, 0.08], [0.32, -0.05]])
	_store_animation(library, &"move", animation)

func _add_attack_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = attack_windup + attack_hit_frame + attack_recovery
	_add_value_track(animation, "Body:rotation", [[0.0, -0.14], [attack_windup, 0.12], [animation.length, 0.0]])
	_add_value_track(animation, "FocusRing:scale", [[0.0, Vector2.ONE * 0.7], [attack_windup, Vector2.ONE * 1.18], [animation.length, Vector2.ONE]])
	_store_animation(library, &"attack", animation)

func _add_dodge_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = dodge_duration
	_add_value_track(animation, "Body:scale", [[0.0, _body_scale(1.14, 0.86)], [dodge_duration, _body_scale()]])
	_add_value_track(animation, "Body:modulate", [[0.0, Color(0.86, 0.94, 1.0, 0.72)], [dodge_duration, Color.WHITE]])
	_store_animation(library, &"dodge", animation)

func _add_skill_animation(library: AnimationLibrary, name: StringName, duration: float, start_rotation: float, end_rotation: float) -> void:
	var animation := Animation.new()
	animation.length = duration
	_add_value_track(animation, "Body:rotation", [[0.0, start_rotation], [duration, end_rotation]])
	_add_value_track(animation, "Body:scale", [[0.0, _body_scale(0.96, 1.04)], [duration, _body_scale(1.02, 0.98)]])
	_store_animation(library, name, animation)

func _add_hit_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = hit_stun_duration
	_add_value_track(animation, "Body:position", [[0.0, Vector2(-4.0, 0.0)], [hit_stun_duration * 0.5, Vector2(4.0, 0.0)], [hit_stun_duration, Vector2.ZERO]])
	_store_animation(library, &"hit", animation)

func _add_dead_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = 0.7
	_add_value_track(animation, "Body:rotation", [[0.0, 0.0], [0.7, PI * 0.5]])
	_add_value_track(animation, "Body:position", [[0.0, Vector2.ZERO], [0.24, Vector2(-6.0, 8.0)], [0.7, Vector2(-10.0, 14.0)]])
	_add_value_track(animation, "Body:scale", [[0.0, _body_scale()], [0.24, _body_scale(1.06, 0.82)], [0.7, _body_scale(1.0, 0.74)]])
	_add_value_track(animation, "Body:modulate", [[0.0, Color.WHITE], [0.7, Color(0.46, 0.46, 0.46, 1.0)]])
	_store_animation(library, &"dead", animation)

func _spawn_death_burst() -> void:
	if effects_layer == null:
		return
	for index in range(6):
		var glyph := Polygon2D.new()
		glyph.color = Color(0.78, 0.88, 1.0, 0.84)
		glyph.polygon = PackedVector2Array([
			Vector2(-4.0, -6.0),
			Vector2(4.0, -6.0),
			Vector2(6.0, 0.0),
			Vector2(4.0, 6.0),
			Vector2(-4.0, 6.0),
			Vector2(-6.0, 0.0)
		])
		effects_layer.add_child(glyph)
		var direction := Vector2.RIGHT.rotated(TAU * float(index) / 6.0)
		var tween := glyph.create_tween()
		tween.tween_property(glyph, "position", direction * 24.0 + Vector2(0.0, -8.0), 0.22)
		tween.parallel().tween_property(glyph, "modulate:a", 0.0, 0.22)
		tween.finished.connect(glyph.queue_free)
