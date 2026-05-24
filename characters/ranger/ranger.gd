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
signal died

const DAMAGE_NUMBER_SCENE := preload("res://effects/damage_number.tscn")
const ARROW_SCENE := preload("res://effects/projectiles/piercing_arrow.tscn")

@export_group("Core Stats")
@export var max_hp: float = 85.0
@export var max_inspiration: float = 30.0
@export var defense: float = 60.0
@export var max_defense: float = 60.0
@export var move_speed: float = 280.0
@export var attack_damage: float = 80.0
@export var attack_interval: float = 0.6
@export_range(0.0, 1.0, 0.01) var crit_rate: float = 0.4
@export var inspiration_gain_on_attack_hit: float = 3.0

@export_group("Normal Attack Timing")
@export var attack_windup: float = 0.25
@export var attack_hit_frame: float = 0.05
@export var attack_recovery: float = 0.3

@export_group("Skill 1: Piercing Arrow")
@export var skill1_cost: float = 10.0
@export var skill1_cooldown: float = 8.0
@export var skill1_damage: float = 100.0
@export var skill1_cast_duration: float = 0.2
@export var skill1_split_shot_upgrade: bool = false
@export var skill1_double_shot_upgrade: bool = false

@export_group("Skill 2: Shadow Roll")
@export var skill2_cost: float = 5.0
@export var skill2_cooldown: float = 1.0
@export var dash_duration: float = 0.18
@export var dash_speed: float = 900.0
@export var skill2_invincible_upgrade: bool = false
@export var skill2_critical_boost_upgrade: bool = false
@export var force_critical_duration: float = 3.0

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
@export var attack_range: float = 88.0

@onready var state_machine: Node = $StateMachine
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Polygon2D = $Body
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
	"skill3": 0.0
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
	_build_animations()
	slash_arc.visible = false
	aim_ring.visible = false
	assassination_mark.visible = false
	emit_stat_signals()
	state_machine.initialize(self)

func _physics_process(delta: float) -> void:
	manual_movement_performed = false
	move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if move_input != Vector2.ZERO:
		facing = move_input.normalized()
	update_cooldowns(delta)
	state_machine.physics_update(delta)
	if not manual_movement_performed:
		move_and_slide()
	sync_visuals()

func _process(delta: float) -> void:
	_update_targeting_visuals(delta)

func emit_stat_signals() -> void:
	hp_changed.emit(hp, max_hp)
	inspiration_changed.emit(inspiration, max_inspiration)
	defense_changed.emit(defense, max_defense)

func get_character_name() -> String:
	return "Ranger"

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
		sprite.scale.x = -1.0 if facing.x < 0.0 else 1.0
	projectile_spawner.position.x = 28.0 if facing.x >= 0.0 else -28.0
	slash_arc.position.x = 24.0 if facing.x >= 0.0 else -24.0
	var body_color := Color(0.36, 0.86, 0.62, 1.0)
	if hp <= 0.0:
		modulate = Color(0.35, 0.35, 0.35, 1.0)
	elif active_dash_invincible:
		modulate = Color(0.75, 0.82, 1.0, 0.88)
		body_color = Color(0.72, 0.98, 1.0, 1.0)
	elif force_critical:
		modulate = Color(1.0, 0.85, 0.65, 1.0)
		body_color = Color(0.5, 1.0, 0.72, 1.0)
	elif state_machine.get_state_name() == &"Hit":
		modulate = Color(1.0, 0.6, 0.6, 1.0)
		body_color = Color(0.95, 0.58, 0.58, 1.0)
	else:
		modulate = Color.WHITE
	sprite.color = body_color

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

func can_cast_skill(skill_name: StringName) -> bool:
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
	if Input.is_action_just_pressed("skill_2") and can_cast_skill(&"skill2"):
		prepare_skill_request(&"skill2")
		return &"Dash"
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
		&"skill2":
			var roll_direction := move_input if move_input != Vector2.ZERO else facing
			queued_skill_payload["direction"] = roll_direction.normalized() if roll_direction != Vector2.ZERO else Vector2.RIGHT
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
	cooldowns["attack"] = attack_interval
	current_attack_targets.clear()
	current_attack_name = &"attack"
	attack_started.emit(current_attack_name)
	slash_arc.visible = true
	slash_arc.rotation = facing.angle()
	play_animation(&"attack")
	_flash_body(Color(0.82, 1.0, 0.78, 1.0), 0.08)

func finish_attack() -> void:
	if current_attack_name != &"":
		attack_finished.emit(current_attack_name)
	current_attack_name = &""
	current_attack_targets.clear()
	slash_arc.visible = false

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
	apply_damage_to_overlapping_targets(attack_damage, attack_range, &"attack")

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

func start_roll() -> void:
	start_skill(&"skill2")
	current_attack_name = &"skill2"
	dash_direction = queued_skill_payload.get("direction", facing)
	if dash_direction == Vector2.ZERO:
		dash_direction = facing if facing != Vector2.ZERO else Vector2.RIGHT
	dash_direction = dash_direction.normalized()
	active_dash_invincible = skill2_invincible_upgrade
	roll_afterimage_timer = 0.0
	_spawn_afterimage(0.32)
	play_animation(&"dash")

func process_roll(delta: float) -> bool:
	manual_movement_performed = true
	velocity = dash_direction * dash_speed
	global_position += velocity * delta
	roll_afterimage_timer -= delta
	if roll_afterimage_timer <= 0.0:
		roll_afterimage_timer = 0.03
		_spawn_afterimage(0.18)
	return false

func finish_roll() -> void:
	velocity = Vector2.ZERO
	active_dash_invincible = false
	_show_roll_finish_burst()
	if skill2_critical_boost_upgrade:
		apply_force_crit(force_critical_duration)
	if current_attack_name != &"":
		attack_finished.emit(current_attack_name)
	current_attack_name = &""

func start_assassination_dash() -> void:
	start_skill(&"skill3")
	current_attack_name = &"skill3"
	skill3_strike_started = false
	skill3_damage_applied = false
	skill3_strike_elapsed = 0.0
	active_skill_target = queued_skill_payload.get("target", null)
	_show_assassination_mark()
	play_animation(&"skill3_dash")

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
				target.receive_hit({
					"source": self,
					"damage": bleed_damage_per_second,
					"crit_rate": 0.0
				})
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
	if active_dash_invincible:
		return
	var result: Dictionary = health_component.receive_hit(payload)
	var final_damage := float(result.get("damage", 0.0))
	var is_critical := bool(result.get("is_critical", false))
	if final_damage > 0.0:
		spawn_damage_number(final_damage, is_critical, global_position)
	if hp <= 0.0:
		return
	if final_damage >= hit_threshold:
		state_machine.request_hit()

func play_animation(animation_name: StringName) -> void:
	if animation_player.has_animation(animation_name):
		animation_player.play(animation_name)

func get_scaled_damage(base_damage: float) -> float:
	return base_damage

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

func spawn_damage_number(amount: float, is_critical: bool, world_position: Vector2) -> void:
	var damage_number := DAMAGE_NUMBER_SCENE.instantiate()
	damage_number.position = to_local(world_position) + Vector2(0.0, -32.0)
	damage_number.setup(amount, is_critical)
	effects_layer.add_child(damage_number)

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
	state_machine.force_change(&"Dead")
	died.emit()

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
	var ghost := Polygon2D.new()
	ghost.polygon = sprite.polygon
	ghost.color = Color(0.55, 1.0, 0.86, alpha)
	ghost.global_position = global_position
	ghost.rotation = sprite.rotation
	ghost.scale = sprite.scale
	afterimage_layer.add_child(ghost)
	var tween := create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.18)
	tween.parallel().tween_property(ghost, "scale", ghost.scale * 0.92, 0.18)
	tween.finished.connect(ghost.queue_free)

func _flash_body(color: Color, duration: float) -> void:
	if not is_instance_valid(sprite):
		return
	sprite.color = color
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(self) and is_instance_valid(sprite) and hp > 0.0:
			sync_visuals()
	)

func _build_animations() -> void:
	animation_player.root_node = NodePath("..")
	var library: AnimationLibrary = animation_player.get_animation_library(&"") if animation_player.has_animation_library(&"") else null
	if library == null:
		library = AnimationLibrary.new()
		animation_player.add_animation_library(&"", library)
	_add_idle_animation(library)
	_add_move_animation(library)
	_add_attack_animation(library)
	_add_dash_animation(library)
	_add_skill1_animation(library)
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
	_add_value_track(animation, "Body:scale", [[0.0, Vector2.ONE], [0.375, Vector2(1.03, 0.97)], [0.75, Vector2.ONE]])
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

func _add_dash_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = dash_duration
	_add_value_track(animation, "Body:scale", [[0.0, Vector2(1.2, 0.8)], [dash_duration, Vector2.ONE]])
	_store_animation(library, &"dash", animation)

func _add_skill1_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = skill1_cast_duration
	_add_value_track(animation, "Body:rotation", [[0.0, -0.14], [skill1_cast_duration, 0.18]])
	_store_animation(library, &"skill1", animation)

func _add_skill3_dash_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = 0.18
	_add_value_track(animation, "Body:scale", [[0.0, Vector2(1.18, 0.82)], [0.18, Vector2.ONE]])
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
	_store_animation(library, &"dead", animation)
