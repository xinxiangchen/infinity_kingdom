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
const ARROW_SCENE := preload("res://effects/projectiles/piercing_arrow.tscn")
const MELEE_UTILS := preload("res://combat/melee_utils.gd")
const TEXTURE_LOADER := preload("res://combat/runtime_texture_loader.gd")
const RANGER_WEAPON_TEXTURE_PATH := "res://art/final_materials/weapons/player_ranger_knife_lv3.png"
const RANGER_DEATH_TEXTURE_PATH := "res://art/final_materials/deaths/player_ranger_dead.png"
const BODY_BASE_SCALE := Vector2(0.78, 0.78)

@export_group("Core Stats")
@export var max_hp: float = 85.0
@export var max_inspiration: float = 30.0
@export var defense: float = 60.0
@export var max_defense: float = 60.0
@export var move_speed: float = 284.0
@export var attack_damage: float = 80.0
@export var attack_interval: float = 0.60
@export_range(0.0, 1.0, 0.01) var crit_rate: float = 0.4
@export var inspiration_gain_on_attack_hit: float = 3.0

@export_group("Normal Attack Timing")
@export var attack_windup: float = 0.22
@export var attack_hit_frame: float = 0.05
@export var attack_recovery: float = 0.32

@export_group("Skill 1: Piercing Arrow")
@export var skill1_cost: float = 10.0
@export var skill1_cooldown: float = 8.0
@export var skill1_damage: float = 100.0
@export var skill1_cast_duration: float = 0.2
@export var skill1_split_shot_upgrade: bool = false
@export var skill1_double_shot_upgrade: bool = false

@export_group("Skill 2: Shadow Step")
@export var skill2_cost: float = 10.0
@export var skill2_cooldown: float = 10.0
@export var shadow_step_duration: float = 5.0
@export var shadow_step_mark_radius: float = 150.0
@export var skill2_residual_mark_upgrade: bool = false
@export var skill2_wind_boost_upgrade: bool = false
@export var shadow_step_speed_multiplier: float = 1.5
@export var shadow_step_speed_decay_per_second: float = 0.1
@export var shadow_step_heal_per_mark: float = 5.0
@export var shadow_step_attack_speed_bonus_per_mark: float = 0.1

@export_group("Dodge")
@export var dodge_cost: float = 5.0
@export var dodge_cooldown: float = 3.0
@export var dodge_duration: float = 0.26
@export var dodge_speed: float = 920.0

@export_group("Skill 3: Assassination Strike")
@export var skill3_cost: float = 20.0
@export var skill3_cooldown: float = 15.0
@export var skill3_damage: float = 120.0
@export var assassination_dash_speed: float = 1100.0
@export var assassination_range: float = 320.0
@export var assassination_stop_distance: float = 52.0
@export var assassination_strike_duration: float = 0.22
@export var skill3_bleed_upgrade: bool = false
@export var bleed_damage_per_second: float = 20.0
@export var bleed_duration: float = 5.0
@export var skill3_execute_upgrade: bool = false
@export var execute_health_threshold: float = 0.2

@export_group("Hit / Combat")
@export var hit_stun_duration: float = 0.22
@export var hit_threshold: float = 1.0
@export var hit_invulnerability_duration: float = 0.32
@export var attack_range: float = 78.0
@export var attack_arc_degrees: float = 92.0

@onready var state_machine: Node = $StateMachine
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Body
@onready var hurtbox: Area2D = $Hurtbox
@onready var health_component: Node = $HealthComponent
@onready var slash_arc: Polygon2D = $SlashArc
@onready var aim_ring: Line2D = $AimRing
@onready var assassination_mark: Line2D = $AssassinationMark
@onready var projectile_spawner: Node2D = $ProjectileSpawner
@onready var afterimage_layer: Node2D = $AfterimageLayer
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
var current_attack_targets: Array[Node] = []
var current_attack_name: StringName = &""
var manual_movement_performed: bool = false
var dash_direction: Vector2 = Vector2.RIGHT
var force_critical: bool = false
var active_dash_invincible: bool = false
var active_skill_target: Node2D = null
var skill3_strike_started: bool = false
var skill3_damage_applied: bool = false
var skill3_strike_elapsed: float = 0.0
var roll_afterimage_timer: float = 0.0
var dodge_direction: Vector2 = Vector2.RIGHT
var dodge_elapsed: float = 0.0
var shadow_step_elapsed: float = 0.0
var shadow_step_active: bool = false
var shadow_step_speed_bonus: float = 0.0
var shadow_step_attack_speed_bonus: float = 0.0
var shadow_step_marked_targets: Dictionary = {}
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
	_setup_visual_shapes()
	_build_animations()
	slash_arc.visible = false
	aim_ring.visible = false
	assassination_mark.visible = false
	emit_stat_signals()
	state_machine.initialize(self)

func _physics_process(delta: float) -> void:
	manual_movement_performed = false
	var requested_move_input := auto_walk_direction if _is_auto_walking() else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if requested_move_input != Vector2.ZERO:
		facing = requested_move_input.normalized()
	move_input = requested_move_input if _is_auto_walking() else (Vector2.ZERO if root_time_remaining > 0.0 else requested_move_input)
	update_cooldowns(delta)
	_update_shadow_step_bonuses(delta)
	state_machine.physics_update(delta)
	if not manual_movement_performed:
		move_and_slide()
	sync_visuals()

func _process(delta: float) -> void:
	_update_control_effects(delta)
	_update_targeting_visuals(delta)

func emit_stat_signals() -> void:
	hp_changed.emit(hp, max_hp)
	inspiration_changed.emit(inspiration, max_inspiration)
	defense_changed.emit(defense, max_defense)

func get_character_name() -> String:
	return "Ranger"

func get_upgrade_sections() -> Array:
	return [
		{
			"title": "Skill 1: 穿风箭",
			"upgrades": [
				{
					"id": "skill1_split",
					"label": "裂羽",
					"description": "主箭变为三发散射。",
					"fields": ["skill1_split_shot_upgrade"]
				},
				{
					"id": "skill1_double",
					"label": "连矢",
					"description": "主箭连续射出两次。",
					"fields": ["skill1_double_shot_upgrade"]
				}
			]
		},
		{
			"title": "Skill 2: 影步",
			"upgrades": [
				{
					"id": "skill2_mark",
					"label": "残影",
					"description": "结束时按标记敌人数回血并提高攻速。",
					"fields": ["skill2_residual_mark_upgrade"]
				},
				{
					"id": "skill2_wind",
					"label": "追风",
					"description": "灵体期间提高移速，结束后逐秒衰减。",
					"fields": ["skill2_wind_boost_upgrade"]
				}
			]
		},
		{
			"title": "Skill 3: 猎杀突袭",
			"upgrades": [
				{
					"id": "skill3_bleed",
					"label": "放血",
					"description": "命中后施加流血。",
					"fields": ["skill3_bleed_upgrade"]
				},
				{
					"id": "skill3_execute",
					"label": "处决",
					"description": "对低血量敌人直接处决。",
					"fields": ["skill3_execute_upgrade"]
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

func is_detectable() -> bool:
	return not shadow_step_active

func gain_inspiration(amount: float) -> void:
	if amount <= 0.0 or hp <= 0.0:
		return
	var previous := inspiration
	inspiration = clampf(inspiration + amount, 0.0, max_inspiration)
	if not is_equal_approx(previous, inspiration):
		inspiration_changed.emit(inspiration, max_inspiration)

func on_attack_landed(attack_name: StringName, target: Node) -> void:
	gain_inspiration(inspiration_gain_on_attack_hit)
	AccessoryManager.apply_on_hit_effects(self, attack_name, target)

func sync_visuals() -> void:
	if absf(facing.x) > 0.01:
		sprite.flip_h = facing.x < 0.0
	projectile_spawner.position.x = 28.0 if facing.x >= 0.0 else -28.0
	slash_arc.position = _attack_visual_offset()
	if slash_arc.visible:
		slash_arc.rotation = _attack_facing().angle()
	_sync_weapon_visual()
	if hp <= 0.0:
		modulate = Color(0.35, 0.35, 0.35, 1.0)
	elif shadow_step_active:
		modulate = Color(0.72, 0.88, 1.0, 0.34)
	elif active_dash_invincible:
		modulate = Color(0.75, 0.82, 1.0, 0.88)
	elif hit_invulnerability_remaining > 0.0:
		var invulnerability_pulse := 0.76 + 0.18 * sin(Time.get_ticks_msec() * 0.018)
		modulate = Color(1.0, 1.0, 1.0, invulnerability_pulse)
	elif silenced_time_remaining > 0.0:
		modulate = Color(0.84, 0.76, 1.0, 1.0)
	elif force_critical:
		modulate = Color(1.0, 0.85, 0.65, 1.0)
	elif state_machine.get_state_name() == &"Hit":
		modulate = Color(1.0, 0.6, 0.6, 1.0)
	else:
		modulate = Color.WHITE
	sprite.modulate = Color.WHITE

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
			return can_use_skill(skill2_cost) and float(cooldowns["skill2"]) <= 0.0
		&"skill3":
			return can_use_skill(skill3_cost) and float(cooldowns["skill3"]) <= 0.0 and find_assassination_target() != null
		_:
			return false

func get_state_request() -> StringName:
	if hp <= 0.0:
		return &"Dead"
	if _is_auto_walking():
		return &"Move" if move_input != Vector2.ZERO else &"Idle"
	if Input.is_action_just_pressed("dodge") and can_dodge():
		return &"Dodge"
	if Input.is_action_just_pressed("skill_2") and can_cast_skill(&"skill2"):
		prepare_skill_request(&"skill2")
		return &"Skill"
	if Input.is_action_just_pressed("skill_3") and can_cast_skill(&"skill3"):
		prepare_skill_request(&"skill3")
		return &"Skill"
	if Input.is_action_just_pressed("attack") and can_attack():
		return &"Attack"
	if Input.is_action_just_pressed("skill_1") and can_cast_skill(&"skill1"):
		prepare_skill_request(&"skill1")
		return &"Skill"
	if move_input != Vector2.ZERO:
		return &"Move"
	return &"Idle"

func prepare_skill_request(skill_name: StringName) -> void:
	queued_skill = skill_name
	queued_skill_payload.clear()
	match skill_name:
		&"skill1":
			queued_skill_payload["direction"] = facing
		&"skill3":
			var target := find_assassination_target()
			if target != null:
				queued_skill_payload["target"] = target

func get_queued_skill() -> StringName:
	return queued_skill

func consume_queued_skill() -> StringName:
	var skill_name := queued_skill
	queued_skill = &""
	return skill_name

func start_attack() -> void:
	var attack_speed := get_attack_speed_multiplier()
	cooldowns["attack"] = attack_interval / attack_speed
	current_attack_targets.clear()
	current_attack_name = &"attack"
	attack_started.emit(current_attack_name)
	slash_arc.visible = true
	slash_arc.position = _attack_visual_offset()
	slash_arc.rotation = _attack_facing().angle()
	animation_player.speed_scale = attack_speed
	play_animation(&"attack")
	_animate_weapon_swing(-32.0, 18.0, get_attack_windup_duration() + get_attack_hit_frame_duration())
	_flash_body(Color(0.82, 1.0, 0.78, 1.0), 0.08)

func finish_attack() -> void:
	if current_attack_name != &"":
		attack_finished.emit(current_attack_name)
	current_attack_name = &""
	current_attack_targets.clear()
	slash_arc.visible = false
	animation_player.speed_scale = 1.0

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

func trigger_normal_attack_hit() -> void:
	apply_damage_to_targets_in_arc(attack_damage, attack_range, attack_arc_degrees, &"attack")

func fire_piercing_arrow() -> void:
	attack_started.emit(&"skill1")
	_show_piercing_charge_burst()
	_spawn_arrow(facing, skill1_damage)
	if skill1_split_shot_upgrade:
		_spawn_arrow(facing.rotated(deg_to_rad(-14.0)), skill1_damage * 0.5)
		_spawn_arrow(facing.rotated(deg_to_rad(14.0)), skill1_damage * 0.5)
	if skill1_double_shot_upgrade:
		var timer := get_tree().create_timer(0.15)
		timer.timeout.connect(func() -> void:
			if is_instance_valid(self) and hp > 0.0:
				_spawn_arrow(facing, skill1_damage)
		)
	attack_finished.emit(&"skill1")

func start_dodge() -> void:
	consume_inspiration(dodge_cost)
	cooldowns["dodge"] = dodge_cooldown
	dodge_direction = move_input if move_input != Vector2.ZERO else facing
	if dodge_direction == Vector2.ZERO:
		dodge_direction = Vector2.RIGHT
	dodge_direction = dodge_direction.normalized()
	dodge_elapsed = 0.0
	active_dash_invincible = true
	roll_afterimage_timer = 0.0
	play_animation(&"dodge")
	_animate_weapon_swing(-18.0, 14.0, dodge_duration)

func process_dodge(delta: float) -> bool:
	dodge_elapsed += delta
	manual_movement_performed = true
	velocity = dodge_direction * dodge_speed
	global_position += velocity * delta
	roll_afterimage_timer -= delta
	if roll_afterimage_timer <= 0.0:
		roll_afterimage_timer = 0.04
		_spawn_afterimage(0.2)
	return dodge_elapsed >= dodge_duration

func is_dodge_complete() -> bool:
	return active_dash_invincible and dodge_elapsed >= dodge_duration

func finish_dodge() -> void:
	velocity = Vector2.ZERO
	active_dash_invincible = false
	_show_roll_finish_burst()

func start_shadow_step() -> void:
	start_skill(&"skill2")
	current_attack_name = &"skill2"
	shadow_step_active = true
	shadow_step_elapsed = 0.0
	shadow_step_marked_targets.clear()
	roll_afterimage_timer = 0.0
	attack_started.emit(&"skill2")
	play_animation(&"skill2")
	if weapon != null:
		weapon.visible = false

func process_shadow_step(delta: float) -> bool:
	shadow_step_elapsed += delta
	manual_movement_performed = true
	var direction := move_input if move_input != Vector2.ZERO else facing
	if direction != Vector2.ZERO:
		facing = direction.normalized()
	velocity = Vector2.ZERO if direction == Vector2.ZERO else direction.normalized() * move_speed * (shadow_step_speed_multiplier if skill2_wind_boost_upgrade else 1.0)
	global_position += velocity * delta
	roll_afterimage_timer -= delta
	if roll_afterimage_timer <= 0.0:
		roll_afterimage_timer = 0.06
		_spawn_afterimage(0.14)
	if skill2_residual_mark_upgrade:
		_mark_shadow_step_targets()
	return shadow_step_elapsed >= shadow_step_duration

func is_shadow_step_complete() -> bool:
	return shadow_step_active and shadow_step_elapsed >= shadow_step_duration

func finish_shadow_step() -> void:
	velocity = Vector2.ZERO
	shadow_step_active = false
	if skill2_residual_mark_upgrade:
		var marked_enemy_count := shadow_step_marked_targets.size()
		if marked_enemy_count > 0:
			health_component.heal(marked_enemy_count * shadow_step_heal_per_mark)
			shadow_step_attack_speed_bonus = clampf(
				shadow_step_attack_speed_bonus + marked_enemy_count * shadow_step_attack_speed_bonus_per_mark,
				0.0,
				1.0
			)
	if skill2_wind_boost_upgrade:
		shadow_step_speed_bonus = maxf(shadow_step_speed_bonus, shadow_step_speed_multiplier - 1.0)
	if current_attack_name != &"":
		attack_finished.emit(current_attack_name)
	current_attack_name = &""
	if weapon != null:
		weapon.visible = true

func start_assassination_dash() -> void:
	start_skill(&"skill3")
	current_attack_name = &"skill3"
	skill3_strike_started = false
	skill3_damage_applied = false
	skill3_strike_elapsed = 0.0
	active_skill_target = queued_skill_payload.get("target", null)
	_show_assassination_mark()
	play_animation(&"skill3_dash")
	_animate_weapon_swing(-42.0, 14.0, 0.18)

func process_assassination_dash(delta: float) -> bool:
	if active_skill_target == null or not is_instance_valid(active_skill_target):
		return true
	var to_target := active_skill_target.global_position - global_position
	if to_target.length() <= assassination_stop_distance:
		return true
	manual_movement_performed = true
	dash_direction = to_target.normalized()
	facing = dash_direction
	velocity = dash_direction * assassination_dash_speed
	global_position += velocity * delta
	_spawn_afterimage(0.2)
	return false

func begin_assassination_strike() -> void:
	velocity = Vector2.ZERO
	skill3_strike_started = true
	skill3_damage_applied = false
	skill3_strike_elapsed = 0.0
	_show_assassination_impact()
	play_animation(&"skill3_strike")

func process_assassination_strike(delta: float) -> bool:
	skill3_strike_elapsed += delta
	if not skill3_damage_applied and skill3_strike_elapsed >= assassination_strike_duration * 0.4:
		skill3_damage_applied = true
		apply_assassination_damage()
	return skill3_strike_elapsed >= assassination_strike_duration

func finish_assassination() -> void:
	if current_attack_name != &"":
		attack_finished.emit(current_attack_name)
	current_attack_name = &""
	active_skill_target = null
	skill3_strike_started = false
	skill3_damage_applied = false
	skill3_strike_elapsed = 0.0
	assassination_mark.visible = false

func apply_assassination_damage() -> void:
	if active_skill_target == null or not is_instance_valid(active_skill_target):
		return
	var damage := skill3_damage
	if skill3_execute_upgrade and _can_execute_target(active_skill_target):
		damage = 999999.0
	var payload := AccessoryManager.build_hit_payload(
		self,
		&"skill3",
		get_scaled_damage(damage),
		_get_current_crit_rate()
	)
	active_skill_target.receive_hit(payload)
	on_attack_landed(&"skill3", active_skill_target)
	attack_hit.emit(&"skill3", active_skill_target)
	if skill3_bleed_upgrade:
		apply_bleed(active_skill_target)
	_flash_body(Color(1.0, 0.76, 0.72, 1.0), 0.09)

func apply_bleed(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	var ticks := int(floor(bleed_duration))
	for index in range(ticks):
		var timer := get_tree().create_timer(float(index + 1))
		timer.timeout.connect(func() -> void:
			if is_instance_valid(self) and is_instance_valid(target) and target.has_method("receive_hit"):
				target.receive_hit(AccessoryManager.build_hit_payload(
					self,
					&"bleed",
					bleed_damage_per_second,
					0.0
				))
		)

func apply_force_crit(duration: float) -> void:
	force_critical = true
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self):
			force_critical = false
	)

func find_assassination_target() -> Node2D:
	var nearest_target: Node2D = null
	var nearest_distance := assassination_range
	for target in get_tree().get_nodes_in_group("damageable"):
		if target == self:
			continue
		if not (target is Node2D):
			continue
		var node_2d: Node2D = target
		var distance := global_position.distance_to(node_2d.global_position)
		if distance > nearest_distance:
			continue
		nearest_distance = distance
		nearest_target = node_2d
	return nearest_target

func receive_hit(payload: Dictionary) -> void:
	if active_dash_invincible or shadow_step_active or hit_invulnerability_remaining > 0.0:
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

func get_scaled_damage(base_damage: float) -> float:
	return base_damage

func get_attack_speed_multiplier() -> float:
	return 1.0 + shadow_step_attack_speed_bonus

func get_attack_windup_duration() -> float:
	return attack_windup / get_attack_speed_multiplier()

func get_attack_hit_frame_duration() -> float:
	return attack_hit_frame / get_attack_speed_multiplier()

func get_attack_recovery_duration() -> float:
	return attack_recovery / get_attack_speed_multiplier()

func get_current_move_speed() -> float:
	return move_speed * (1.0 + shadow_step_speed_bonus) * slow_factor

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
	for target in get_tree().get_nodes_in_group("damageable"):
		if target == self:
			continue
		if not (target is Node2D):
			continue
		if current_attack_targets.has(target):
			continue
		var node_2d: Node2D = target
		if global_position.distance_to(node_2d.global_position) > radius:
			continue
		if not target.has_method("receive_hit"):
			continue
		current_attack_targets.append(target)
		var payload := AccessoryManager.build_hit_payload(
			self,
			attack_name,
			get_scaled_damage(base_damage),
			_get_current_crit_rate(),
			extra_payload
		)
		target.receive_hit(payload)
		on_attack_landed(attack_name, target)
		attack_hit.emit(attack_name, target)

func apply_damage_to_targets_in_arc(base_damage: float, radius: float, arc_degrees: float, attack_name: StringName, extra_payload: Dictionary = {}) -> void:
	var attack_direction := _attack_facing()
	var attack_origin := _attack_origin()
	for target in get_tree().get_nodes_in_group("damageable"):
		if target == self:
			continue
		if not (target is Node2D):
			continue
		if current_attack_targets.has(target):
			continue
		var node_2d: Node2D = target
		if not MELEE_UTILS.is_point_in_arc(attack_origin, attack_direction, node_2d.global_position, radius, arc_degrees):
			continue
		if not target.has_method("receive_hit"):
			continue
		current_attack_targets.append(target)
		var payload := AccessoryManager.build_hit_payload(
			self,
			attack_name,
			get_scaled_damage(base_damage),
			_get_current_crit_rate(),
			extra_payload
		)
		target.receive_hit(payload)
		on_attack_landed(attack_name, target)
		attack_hit.emit(attack_name, target)

func spawn_damage_number(amount: float, is_critical: bool, world_position: Vector2) -> void:
	var damage_number := DAMAGE_NUMBER_SCENE.instantiate()
	damage_number.position = to_local(world_position) + Vector2(0.0, -32.0)
	damage_number.setup(amount, is_critical)
	effects_layer.add_child(damage_number)

func _setup_visual_shapes() -> void:
	slash_arc.polygon = _build_slash_arc_polygon(attack_range, attack_arc_degrees, 8)
	slash_arc.color = Color(0.84, 1.0, 0.72, 0.62)

func _build_slash_arc_polygon(radius: float, arc_degrees: float, steps: int = 8) -> PackedVector2Array:
	var points := PackedVector2Array()
	var half_arc := deg_to_rad(arc_degrees) * 0.5
	points.append(Vector2.ZERO)
	for index in range(steps + 1):
		var weight := float(index) / float(max(steps, 1))
		var angle := lerpf(-half_arc, half_arc, weight)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points

func _spawn_arrow(direction: Vector2, damage: float) -> void:
	var arrow := ARROW_SCENE.instantiate()
	arrow.global_position = projectile_spawner.global_position
	get_tree().current_scene.add_child(arrow)
	arrow.setup(self, direction, get_scaled_damage(damage), _get_current_crit_rate())

func _get_current_crit_rate() -> float:
	if force_critical:
		return 1.0
	return crit_rate

func _can_execute_target(target: Node) -> bool:
	if target == null:
		return false
	var target_hp := float(target.get("hp"))
	var target_max_hp := float(target.get("max_hp"))
	return target_max_hp > 0.0 and target_hp <= target_max_hp * execute_health_threshold

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
	sprite.texture = TEXTURE_LOADER.load_texture(RANGER_DEATH_TEXTURE_PATH)
	if weapon != null:
		weapon.visible = false
	_spawn_death_burst()
	state_machine.force_change(&"Dead")
	died.emit()

func _update_shadow_step_bonuses(delta: float) -> void:
	if shadow_step_speed_bonus > 0.0:
		shadow_step_speed_bonus = maxf(shadow_step_speed_bonus - shadow_step_speed_decay_per_second * delta, 0.0)

func _mark_shadow_step_targets() -> void:
	for target in get_tree().get_nodes_in_group("damageable"):
		if target == self or not (target is Node2D):
			continue
		var node_2d: Node2D = target
		if global_position.distance_to(node_2d.global_position) > shadow_step_mark_radius:
			continue
		shadow_step_marked_targets[target.get_instance_id()] = true

func _setup_weapon_visual() -> void:
	weapon = Node2D.new()
	weapon.name = "Weapon"
	weapon.z_index = 4
	add_child(weapon)
	weapon_sprite = Sprite2D.new()
	weapon_sprite.texture = TEXTURE_LOADER.load_texture(RANGER_WEAPON_TEXTURE_PATH)
	weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon_sprite.centered = true
	weapon_sprite.scale = Vector2.ONE * 0.56
	weapon.add_child(weapon_sprite)

func _sync_weapon_visual() -> void:
	if weapon == null:
		return
	var side_sign := _get_weapon_side_sign()
	var vertical_bias := clampf(facing.y, -1.0, 1.0)
	var base_right_angle := deg_to_rad(-24.0)
	var base_angle := base_right_angle if side_sign > 0.0 else PI - base_right_angle
	weapon.visible = hp > 0.0 and not shadow_step_active
	weapon.position = Vector2(18.0 * side_sign, 1.0 + vertical_bias * 4.0)
	weapon.rotation = base_angle + deg_to_rad(vertical_bias * 6.0) + weapon_angle_offset * side_sign

func _animate_weapon_swing(start_degrees: float, end_degrees: float, duration: float) -> void:
	weapon_angle_offset = deg_to_rad(start_degrees)
	var tween := create_tween()
	tween.tween_property(self, "weapon_angle_offset", deg_to_rad(end_degrees), maxf(duration * 0.68, 0.01)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "weapon_angle_offset", 0.0, maxf(duration * 0.32, 0.01)).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

func _get_weapon_side_sign() -> float:
	if absf(facing.x) > 0.08:
		return 1.0 if facing.x >= 0.0 else -1.0
	return -1.0 if sprite.flip_h else 1.0

func _attack_facing() -> Vector2:
	return facing.normalized() if facing.length_squared() > 0.0001 else Vector2.RIGHT

func _attack_visual_offset() -> Vector2:
	return _attack_facing() * 13.0 + Vector2(0.0, -3.0)

func _attack_origin() -> Vector2:
	return global_position + _attack_visual_offset()

func set_auto_walk_direction(direction: Vector2) -> void:
	auto_walk_direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector2.ZERO

func _is_auto_walking() -> bool:
	return auto_walk_direction.length_squared() > 0.0001

func _update_targeting_visuals(delta: float) -> void:
	var pulse := 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.008)
	aim_ring.visible = state_machine.get_state_name() == &"Skill" and queued_skill == &"skill1"
	aim_ring.rotation = facing.angle()
	aim_ring.scale = Vector2.ONE * (0.92 + 0.08 * pulse)
	aim_ring.modulate = Color(0.7, 1.0, 0.84, 0.55 + 0.3 * pulse)
	if active_skill_target != null and is_instance_valid(active_skill_target):
		assassination_mark.visible = true
		assassination_mark.global_position = active_skill_target.global_position
		assassination_mark.rotation += delta * 4.5
		assassination_mark.scale = Vector2.ONE * (0.92 + 0.12 * pulse)
		assassination_mark.modulate = Color(1.0, 0.42, 0.36, 0.65 + 0.25 * pulse)
	elif queued_skill == &"skill3":
		var target := find_assassination_target()
		if target != null:
			assassination_mark.visible = true
			assassination_mark.global_position = target.global_position
			assassination_mark.rotation += delta * 4.5
			assassination_mark.scale = Vector2.ONE * (0.92 + 0.12 * pulse)
			assassination_mark.modulate = Color(1.0, 0.42, 0.36, 0.65 + 0.25 * pulse)
		else:
			assassination_mark.visible = false
	else:
		assassination_mark.visible = false

func _show_piercing_charge_burst() -> void:
	aim_ring.visible = true
	aim_ring.rotation = facing.angle()
	aim_ring.scale = Vector2.ONE * 0.4
	aim_ring.modulate = Color(0.74, 1.0, 0.88, 0.9)
	var tween := create_tween()
	tween.tween_property(aim_ring, "scale", Vector2.ONE * 1.2, 0.12)
	tween.parallel().tween_property(aim_ring, "modulate:a", 0.0, 0.12)
	tween.finished.connect(func() -> void:
		if is_instance_valid(aim_ring):
			aim_ring.visible = false
			aim_ring.scale = Vector2.ONE
			aim_ring.modulate.a = 1.0
	)

func _show_roll_finish_burst() -> void:
	var ring := Line2D.new()
	ring.width = 3.0
	ring.closed = true
	ring.default_color = Color(0.7, 0.94, 1.0, 0.9)
	ring.points = PackedVector2Array([
		Vector2(22, 0),
		Vector2(16, 16),
		Vector2(0, 22),
		Vector2(-16, 16),
		Vector2(-22, 0),
		Vector2(-16, -16),
		Vector2(0, -22),
		Vector2(16, -16)
	])
	ring.global_position = global_position
	get_tree().current_scene.add_child(ring)
	var tween := create_tween()
	tween.tween_property(ring, "scale", Vector2.ONE * 1.8, 0.15)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.15)
	tween.finished.connect(ring.queue_free)

func _show_assassination_mark() -> void:
	if active_skill_target == null or not is_instance_valid(active_skill_target):
		return
	assassination_mark.visible = true
	assassination_mark.global_position = active_skill_target.global_position
	assassination_mark.rotation = 0.0
	assassination_mark.scale = Vector2.ONE * 0.7
	assassination_mark.modulate = Color(1.0, 0.48, 0.42, 0.95)

func _show_assassination_impact() -> void:
	var impact := Polygon2D.new()
	impact.color = Color(1.0, 0.74, 0.68, 0.82)
	impact.polygon = PackedVector2Array([
		Vector2(-20, -8),
		Vector2(0, -30),
		Vector2(20, -8),
		Vector2(8, 0),
		Vector2(20, 8),
		Vector2(0, 30),
		Vector2(-20, 8),
		Vector2(-8, 0)
	])
	impact.global_position = global_position + facing * 18.0
	impact.rotation = facing.angle()
	effects_layer.add_child(impact)
	var tween := create_tween()
	tween.tween_property(impact, "scale", Vector2.ONE * 1.7, 0.16)
	tween.parallel().tween_property(impact, "modulate:a", 0.0, 0.16)
	tween.finished.connect(impact.queue_free)

func _spawn_afterimage(alpha: float) -> void:
	var ghost := Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.texture_filter = sprite.texture_filter
	ghost.centered = sprite.centered
	ghost.offset = sprite.offset
	ghost.flip_h = sprite.flip_h
	ghost.modulate = Color(0.55, 1.0, 0.86, alpha)
	afterimage_layer.add_child(ghost)
	# Keep old afterimages in world space so they do not move with the ranger.
	ghost.set_as_top_level(true)
	ghost.z_as_relative = false
	ghost.z_index = max(z_index - 1, 0)
	ghost.global_transform = sprite.global_transform
	var tween := create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.18)
	tween.parallel().tween_property(ghost, "scale", ghost.scale * 0.92, 0.18)
	tween.finished.connect(ghost.queue_free)

func _flash_body(color: Color, duration: float) -> void:
	if not is_instance_valid(sprite):
		return
	sprite.modulate = color
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self) and is_instance_valid(sprite) and hp > 0.0:
			sync_visuals()
	)

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
	_add_skill1_animation(library)
	_add_skill2_animation(library)
	_add_skill3_dash_animation(library)
	_add_skill3_strike_animation(library)
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
	animation.length = 0.75
	animation.loop_mode = Animation.LOOP_LINEAR
	_add_value_track(animation, "Body:scale", [[0.0, _body_scale()], [0.375, _body_scale(1.03, 0.97)], [0.75, _body_scale()]])
	_store_animation(library, &"idle", animation)

func _add_move_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = 0.3
	animation.loop_mode = Animation.LOOP_LINEAR
	_add_value_track(animation, "Body:rotation", [[0.0, -0.05], [0.15, 0.08], [0.3, -0.05]])
	_store_animation(library, &"move", animation)

func _add_attack_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = attack_windup + attack_hit_frame + attack_recovery
	_add_value_track(animation, "Body:rotation", [[0.0, -0.2], [attack_windup, 0.16], [animation.length, 0.0]])
	_add_value_track(animation, "SlashArc:scale", [[0.0, Vector2(0.15, 0.15)], [attack_windup, Vector2(1.0, 1.0)], [animation.length, Vector2(0.4, 0.4)]])
	_store_animation(library, &"attack", animation)

func _add_dodge_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = dodge_duration
	_add_value_track(animation, "Body:scale", [[0.0, _body_scale(1.2, 0.8)], [dodge_duration, _body_scale()]])
	_add_value_track(animation, "Body:modulate", [[0.0, Color(0.84, 0.92, 1.0, 0.72)], [dodge_duration, Color.WHITE]])
	_store_animation(library, &"dodge", animation)

func _add_skill1_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = skill1_cast_duration
	_add_value_track(animation, "Body:rotation", [[0.0, -0.14], [skill1_cast_duration, 0.18]])
	_store_animation(library, &"skill1", animation)

func _add_skill2_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = shadow_step_duration
	animation.loop_mode = Animation.LOOP_LINEAR
	_add_value_track(animation, "Body:scale", [[0.0, _body_scale(0.92, 1.08)], [shadow_step_duration * 0.5, _body_scale(0.84, 1.14)], [shadow_step_duration, _body_scale(0.92, 1.08)]])
	_store_animation(library, &"skill2", animation)

func _add_skill3_dash_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = 0.18
	_add_value_track(animation, "Body:scale", [[0.0, _body_scale(1.18, 0.82)], [0.18, _body_scale()]])
	_store_animation(library, &"skill3_dash", animation)

func _add_skill3_strike_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = assassination_strike_duration
	_add_value_track(animation, "Body:rotation", [[0.0, -0.35], [assassination_strike_duration * 0.5, 0.28], [assassination_strike_duration, 0.0]])
	_store_animation(library, &"skill3_strike", animation)

func _add_hit_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = hit_stun_duration
	_add_value_track(animation, "Body:position", [[0.0, Vector2(-4.0, 0.0)], [hit_stun_duration * 0.5, Vector2(5.0, 0.0)], [hit_stun_duration, Vector2.ZERO]])
	_store_animation(library, &"hit", animation)

func _add_dead_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = 0.7
	_add_value_track(animation, "Body:rotation", [[0.0, 0.0], [0.7, PI * 0.5]])
	_add_value_track(animation, "Body:position", [[0.0, Vector2.ZERO], [0.25, Vector2(-8.0, 8.0)], [0.7, Vector2(-12.0, 12.0)]])
	_add_value_track(animation, "Body:scale", [[0.0, _body_scale()], [0.25, _body_scale(1.10, 0.78)], [0.7, _body_scale(1.0, 0.72)]])
	_add_value_track(animation, "Body:modulate", [[0.0, Color.WHITE], [0.7, Color(0.48, 0.48, 0.48, 1.0)]])
	_store_animation(library, &"dead", animation)

func _spawn_death_burst() -> void:
	if effects_layer == null:
		return
	for index in range(5):
		var chip := Polygon2D.new()
		chip.color = Color(0.74, 1.0, 0.86, 0.82)
		chip.polygon = PackedVector2Array([
			Vector2(-3.0, -3.0),
			Vector2(3.0, -3.0),
			Vector2(3.0, 3.0),
			Vector2(-3.0, 3.0)
		])
		effects_layer.add_child(chip)
		var direction := Vector2.RIGHT.rotated(TAU * float(index) / 5.0 + 0.24)
		var tween := chip.create_tween()
		tween.tween_property(chip, "position", direction * 22.0 + Vector2(0.0, -5.0), 0.18)
		tween.parallel().tween_property(chip, "modulate:a", 0.0, 0.18)
		tween.finished.connect(chip.queue_free)
