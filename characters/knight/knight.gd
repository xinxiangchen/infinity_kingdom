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
signal control_status_changed(summary: String)
signal died

@export_group("Core Stats")
@export var max_hp: float = 100.0
@export var max_inspiration: float = 20.0
@export var defense: float = 100.0
@export var max_defense: float = 100.0
@export var move_speed: float = 200.0
@export var attack_damage: float = 100.0
@export var attack_interval: float = 0.8
@export_range(0.0, 1.0, 0.01) var crit_rate: float = 0.2
@export var inspiration_gain_on_attack_hit: float = 2.0

@export_group("Normal Attack Timing")
@export var attack_windup: float = 0.3
@export var attack_hit_frame: float = 0.1
@export var attack_recovery: float = 0.4

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

@export_group("Hit / Combat")
@export var hit_stun_duration: float = 0.25
@export var hit_threshold: float = 1.0
@export var attack_range: float = 90.0
@export var shockwave_radius: float = 120.0
@export var sanctuary_radius: float = 140.0

@onready var state_machine: Node = $StateMachine
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Node2D = $Sprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var health_component: Node = $HealthComponent
@onready var slash_arc: Polygon2D = $SlashArc
@onready var shockwave_ring: Line2D = $ShockwaveRing
@onready var sanctuary_ring: Line2D = $SanctuaryRing
@onready var effects_layer: Node2D = $EffectsLayer

const DAMAGE_NUMBER_SCENE := preload("res://effects/damage_number.tscn")

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
var silenced_time_remaining: float = 0.0
var root_time_remaining: float = 0.0
var slow_time_remaining: float = 0.0
var slow_factor: float = 1.0
var control_ring: Line2D = null
var last_control_summary: String = ""

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
	_setup_visual_shapes()
	_build_animations()
	slash_arc.visible = false
	shockwave_ring.visible = false
	sanctuary_ring.visible = false
	_setup_control_ring()
	emit_stat_signals()
	_emit_control_status_changed()
	state_machine.initialize(self)

func _physics_process(delta: float) -> void:
	manual_movement_performed = false
	_update_control_status(delta)
	move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if is_rooted():
		move_input = Vector2.ZERO
	if move_input != Vector2.ZERO:
		facing = move_input.normalized()
	update_cooldowns(delta)
	process_instant_skills()
	state_machine.physics_update(delta)
	if not manual_movement_performed:
		move_and_slide()
	sync_visuals()

func _process(delta: float) -> void:
	_update_guard(delta)
	_update_sanctuary(delta)
	_update_control_visual(delta)

func emit_stat_signals() -> void:
	hp_changed.emit(hp, max_hp)
	inspiration_changed.emit(inspiration, max_inspiration)
	defense_changed.emit(defense, max_defense)

func get_character_name() -> String:
	return "Knight"

func on_attack_landed(attack_name: StringName, target: Node) -> void:
	gain_inspiration(inspiration_gain_on_attack_hit)
	AccessoryManager.apply_on_hit_effects(self, attack_name, target)

func sync_visuals() -> void:
	if absf(facing.x) > 0.01:
		if sprite is Sprite2D:
			(sprite as Sprite2D).flip_h = facing.x < 0.0
		else:
			sprite.scale.x = -absf(sprite.scale.x) if facing.x < 0.0 else absf(sprite.scale.x)
	if hp <= 0.0:
		modulate = Color(0.35, 0.35, 0.35, 1.0)
	elif state_machine.get_state_name() == &"Hit":
		modulate = Color(1.0, 0.65, 0.65, 1.0)
	elif is_rooted():
		modulate = Color(0.72, 0.86, 1.0, 1.0)
	elif is_silenced():
		modulate = Color(0.82, 0.72, 1.0, 1.0)
	elif is_slowed():
		modulate = Color(0.78, 0.94, 1.0, 1.0)
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

func can_cast_skill(skill_name: StringName) -> bool:
	if is_silenced():
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
	slash_arc.rotation = facing.angle()
	play_animation(&"attack")

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
	apply_damage_to_overlapping_targets(attack_damage, attack_range, &"attack")

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
	clear_control_effects(false, true, true)
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
	clear_control_effects(true, true, true)
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

func apply_control_effects(payload: Dictionary) -> void:
	var changed := false
	var popup_text := ""
	var popup_color := Color.WHITE
	if payload.has("silence_duration"):
		var duration := float(payload["silence_duration"])
		if duration > silenced_time_remaining + 0.05:
			changed = true
			popup_text = "Silenced"
			popup_color = Color(0.84, 0.70, 1.0, 1.0)
		silenced_time_remaining = maxf(silenced_time_remaining, duration)
	if payload.has("root_duration"):
		var duration := float(payload["root_duration"])
		if duration > root_time_remaining + 0.05:
			changed = true
			popup_text = "Rooted"
			popup_color = Color(0.72, 0.86, 1.0, 1.0)
		root_time_remaining = maxf(root_time_remaining, duration)
	if payload.has("slow_duration"):
		var duration := float(payload["slow_duration"])
		var multiplier := clampf(float(payload.get("slow_multiplier", 1.0)), 0.25, 1.0)
		if duration > slow_time_remaining + 0.05 or multiplier < slow_factor - 0.01:
			changed = true
			if popup_text.is_empty():
				popup_text = "Slowed"
				popup_color = Color(0.66, 0.94, 1.0, 1.0)
		slow_time_remaining = maxf(slow_time_remaining, duration)
		slow_factor = minf(slow_factor, multiplier)
	if changed:
		_emit_control_status_changed()
		if not popup_text.is_empty():
			_spawn_control_text(popup_text, popup_color)

func clear_control_effects(clear_silence: bool = false, clear_root: bool = true, clear_slow: bool = true) -> void:
	var previous_summary := get_control_status_text()
	if clear_silence:
		silenced_time_remaining = 0.0
	if clear_root:
		root_time_remaining = 0.0
	if clear_slow:
		slow_time_remaining = 0.0
		slow_factor = 1.0
	if previous_summary == get_control_status_text():
		return
	_emit_control_status_changed()
	_spawn_control_text("Steady", Color(0.98, 0.90, 0.68, 1.0))

func get_scaled_damage(base_damage: float) -> float:
	return base_damage * active_damage_multiplier

func get_effective_move_speed() -> float:
	return move_speed * slow_factor

func get_control_status_text() -> String:
	var effects: Array[String] = []
	if is_rooted():
		effects.append("Rooted")
	if is_silenced():
		effects.append("Silenced")
	if is_slowed():
		effects.append("Slowed")
	return ", ".join(effects)

func is_silenced() -> bool:
	return silenced_time_remaining > 0.0

func is_rooted() -> bool:
	return root_time_remaining > 0.0

func is_slowed() -> bool:
	return slow_time_remaining > 0.0 and slow_factor < 0.999

func apply_damage_to_overlapping_targets(base_damage: float, radius: float, attack_name: StringName, extra_payload: Dictionary = {}) -> void:
	apply_damage_to_targets(base_damage, radius, attack_name, current_attack_targets, extra_payload)

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
	var result: Dictionary = health_component.receive_hit(payload)
	var final_damage := float(result.get("damage", 0.0))
	var is_critical := bool(result.get("is_critical", false))
	var displayed_damage := float(result.get("total_damage", final_damage))
	if final_damage > 0.0:
		spawn_damage_number(final_damage, is_critical, global_position)
	if displayed_damage > 0.0:
		apply_control_effects(payload)
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
	state_machine.force_change(&"Dead")
	died.emit()

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

func _setup_control_ring() -> void:
	control_ring = Line2D.new()
	control_ring.width = 3.0
	control_ring.closed = true
	control_ring.visible = false
	control_ring.default_color = Color(0.74, 0.86, 1.0, 0.9)
	control_ring.points = _build_ring_points(34.0, 18)
	effects_layer.add_child(control_ring)

func _update_control_status(delta: float) -> void:
	var previous_summary := get_control_status_text()
	silenced_time_remaining = maxf(silenced_time_remaining - delta, 0.0)
	root_time_remaining = maxf(root_time_remaining - delta, 0.0)
	if slow_time_remaining > 0.0:
		slow_time_remaining = maxf(slow_time_remaining - delta, 0.0)
	else:
		slow_factor = 1.0
	if slow_time_remaining <= 0.0:
		slow_factor = 1.0
	if previous_summary != get_control_status_text():
		_emit_control_status_changed()

func _update_control_visual(delta: float) -> void:
	if control_ring == null:
		return
	var pulse := 0.78 + 0.22 * sin(Time.get_ticks_msec() * 0.01)
	control_ring.visible = not get_control_status_text().is_empty() and hp > 0.0
	if not control_ring.visible:
		return
	control_ring.rotation += delta * 1.8
	control_ring.scale = Vector2.ONE * pulse
	if is_rooted():
		control_ring.default_color = Color(0.72, 0.86, 1.0, 0.92)
	elif is_silenced():
		control_ring.default_color = Color(0.84, 0.70, 1.0, 0.92)
	else:
		control_ring.default_color = Color(0.66, 0.94, 1.0, 0.88)

func _emit_control_status_changed() -> void:
	var summary := get_control_status_text()
	if summary == last_control_summary:
		return
	last_control_summary = summary
	control_status_changed.emit(summary)

func _spawn_control_text(label_text: String, color_value: Color) -> void:
	var popup := DAMAGE_NUMBER_SCENE.instantiate()
	popup.position = Vector2(-34.0, -54.0)
	if popup.has_method("setup_text"):
		popup.setup_text(label_text, color_value, 0.72)
	effects_layer.add_child(popup)

func spawn_damage_number(amount: float, is_critical: bool, world_position: Vector2) -> void:
	var damage_number := DAMAGE_NUMBER_SCENE.instantiate()
	damage_number.position = to_local(world_position) + Vector2(0.0, -32.0)
	damage_number.setup(amount, is_critical)
	effects_layer.add_child(damage_number)

func _setup_visual_shapes() -> void:
	slash_arc.position = facing * attack_range * 0.35
	shockwave_ring.points = _build_ring_points(shockwave_radius)
	sanctuary_ring.points = _build_ring_points(sanctuary_radius)

func _build_ring_points(radius: float, steps: int = 16) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(steps):
		var angle := TAU * float(index) / float(steps)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points

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
	_add_value_track(animation, "Sprite2D:scale", [[0.0, Vector2(0.25, 0.25)], [0.4, Vector2(0.255, 0.245)], [0.8, Vector2(0.25, 0.25)]])
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
	_add_value_track(animation, "Sprite2D:rotation", [[0.0, -0.15], [attack_windup, 0.1], [animation.length, 0.0]])
	_add_value_track(animation, "Sprite2D:scale", [[0.0, Vector2(0.25, 0.25)], [attack_windup, Vector2(0.3, 0.23)], [animation.length, Vector2(0.25, 0.25)]])
	_add_value_track(animation, "SlashArc:scale", [[0.0, Vector2(0.2, 0.2)], [attack_windup, Vector2(1.1, 1.0)], [animation.length, Vector2(0.6, 0.6)]])
	_store_animation(library, &"attack", animation)

func _add_charge_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = charge_duration
	_add_value_track(animation, "Sprite2D:scale", [[0.0, Vector2(0.25, 0.25)], [charge_duration, Vector2(0.34, 0.22)]])
	_add_value_track(animation, "Sprite2D:modulate", [[0.0, Color(0.75, 0.85, 1.0, 1.0)], [charge_duration, Color(1.0, 0.85, 0.35, 1.0)]])
	_store_animation(library, &"charge", animation)

func _add_dash_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = dash_duration
	_add_value_track(animation, "Sprite2D:scale", [[0.0, Vector2(0.35, 0.18)], [dash_duration, Vector2(0.25, 0.25)]])
	_add_value_track(animation, "Sprite2D:modulate", [[0.0, Color(1.0, 1.0, 1.0, 0.7)], [dash_duration, Color.WHITE]])
	_store_animation(library, &"dash", animation)

func _add_skill2_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = skill2_duration
	_add_value_track(animation, "Sprite2D:scale", [[0.0, Vector2(0.25, 0.25)], [skill2_duration * 0.5, Vector2(0.22, 0.32)], [skill2_duration, Vector2(0.25, 0.25)]])
	_add_value_track(animation, "Sprite2D:rotation", [[0.0, -0.05], [skill2_duration, 0.05]])
	_store_animation(library, &"skill2", animation)

func _add_skill3_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = skill3_duration
	_add_value_track(animation, "Sprite2D:scale", [[0.0, Vector2(0.22, 0.22)], [skill3_duration * 0.5, Vector2(0.32, 0.32)], [skill3_duration, Vector2(0.25, 0.25)]])
	_add_value_track(animation, "SanctuaryRing:modulate", [[0.0, Color(1.0, 0.92, 0.55, 0.1)], [skill3_duration, Color(1.0, 0.92, 0.55, 0.95)]])
	_store_animation(library, &"skill3", animation)

func _add_guard_animation(library: AnimationLibrary) -> void:
	var animation := Animation.new()
	animation.length = 0.5
	animation.loop_mode = Animation.LOOP_LINEAR
	_add_value_track(animation, "Sprite2D:scale", [[0.0, Vector2(0.24, 0.26)], [0.25, Vector2(0.27, 0.24)], [0.5, Vector2(0.24, 0.26)]])
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
	_add_value_track(animation, "Sprite2D:modulate", [[0.0, Color.WHITE], [0.7, Color(0.45, 0.45, 0.45, 1.0)]])
	_store_animation(library, &"dead", animation)
