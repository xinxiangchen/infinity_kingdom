extends Node2D

signal defeated

const SWORDSMAN_SCENE := preload("res://actors/enemy/swordsman_enemy.tscn")
const SHIELD_SCENE := preload("res://actors/enemy/shield_enemy.tscn")
const ARCHER_SCENE := preload("res://actors/enemy/archer_enemy.tscn")
const HUNTER_SCENE := preload("res://actors/enemy/hunter_enemy.tscn")
const APPRENTICE_SCENE := preload("res://actors/enemy/apprentice_mage_enemy.tscn")
const ARCANIST_SCENE := preload("res://actors/enemy/arcanist_enemy.tscn")
const TownEnemy := preload("res://actors/enemy/town_enemy.gd")
const SAFE_SPAWN_DISTANCE := 260.0
const SPAWN_CLUSTER_DISTANCE := 88.0

@onready var enemy_layer: Node2D = $EnemyLayer
@onready var spawn_layer: Node2D = $SpawnLayer

var target: Node2D = null
var active_enemies: Array[Node] = []
var wave_index: int = -1
var waiting_for_next_wave: bool = false
var active_waves: Array[Dictionary] = []
var active_modifier: Dictionary = {}
var rng := RandomNumberGenerator.new()

var wave_pool := [
	{
		"title": "Frontline Probe",
		"tags": ["frontline", "shield"],
		"units": [
			{"scene": SWORDSMAN_SCENE, "spawn": 0},
			{"scene": SWORDSMAN_SCENE, "spawn": 1},
			{"scene": SHIELD_SCENE, "spawn": 2},
			{"scene": SHIELD_SCENE, "spawn": 3}
		]
	},
	{
		"title": "Crossfire Patrol",
		"tags": ["ranged", "hunters"],
		"units": [
			{"scene": SWORDSMAN_SCENE, "spawn": 0},
			{"scene": SWORDSMAN_SCENE, "spawn": 1},
			{"scene": ARCHER_SCENE, "spawn": 4},
			{"scene": ARCHER_SCENE, "spawn": 5},
			{"scene": HUNTER_SCENE, "spawn": 6}
		]
	},
	{
		"title": "Shielded Volley",
		"tags": ["ranged", "shield", "arcane"],
		"units": [
			{"scene": SHIELD_SCENE, "spawn": 2},
			{"scene": SHIELD_SCENE, "spawn": 3},
			{"scene": ARCHER_SCENE, "spawn": 4},
			{"scene": ARCHER_SCENE, "spawn": 5},
			{"scene": APPRENTICE_SCENE, "spawn": 8}
		]
	},
	{
		"title": "Hunter Pincer",
		"tags": ["hunters", "ranged"],
		"units": [
			{"scene": SWORDSMAN_SCENE, "spawn": 0},
			{"scene": HUNTER_SCENE, "spawn": 6},
			{"scene": HUNTER_SCENE, "spawn": 7},
			{"scene": ARCHER_SCENE, "spawn": 4},
			{"scene": ARCHER_SCENE, "spawn": 5}
		]
	},
	{
		"title": "Shadow and Spell",
		"tags": ["hunters", "arcane"],
		"units": [
			{"scene": SHIELD_SCENE, "spawn": 2},
			{"scene": HUNTER_SCENE, "spawn": 6},
			{"scene": HUNTER_SCENE, "spawn": 7},
			{"scene": APPRENTICE_SCENE, "spawn": 4},
			{"scene": APPRENTICE_SCENE, "spawn": 5}
		]
	}
]

var final_wave := {
	"title": "Arcane Command",
	"tags": ["final", "ranged", "arcane", "shield"],
	"units": [
		{"scene": SWORDSMAN_SCENE, "spawn": 0, "elite": true},
		{"scene": SHIELD_SCENE, "spawn": 2, "elite": true},
		{"scene": ARCHER_SCENE, "spawn": 4, "elite": true},
		{"scene": HUNTER_SCENE, "spawn": 6, "elite": true},
		{"scene": APPRENTICE_SCENE, "spawn": 5},
		{"scene": ARCANIST_SCENE, "spawn": 8}
	]
}

var modifier_pool := [
	{
		"id": "fortified",
		"title": "Fortified Line",
		"summary": "Shield carriers reinforce every wave with heavier front-loaded pressure.",
		"hint": "Break shield carriers first or kite until the frontline opens.",
		"preferred_tags": ["shield", "frontline"],
		"global_hp_scale": 1.18,
		"shield_defense_scale": 1.35,
		"shield_elite": true
	},
	{
		"id": "relentless",
		"title": "Relentless March",
		"summary": "All enemies rotate back in faster and give you shorter recovery windows.",
		"hint": "Do not spend movement too early. The next engage comes back faster than normal.",
		"preferred_tags": ["frontline", "hunters"],
		"global_move_speed_scale": 1.12,
		"global_attack_interval_scale": 0.86,
		"global_detection_scale": 1.08
	},
	{
		"id": "crossfire",
		"title": "Crossfire Lanes",
		"summary": "Archers and casters hold lanes longer and punish loose positioning.",
		"hint": "The backline is the timer. Collapse on ranged units before flankers arrive.",
		"preferred_tags": ["ranged", "arcane"],
		"ranged_attack_damage_scale": 1.15,
		"ranged_attack_interval_scale": 0.78,
		"ranged_attack_range_scale": 1.12,
		"ranged_detection_scale": 1.18
	},
	{
		"id": "hunt_pack",
		"title": "Hunt Pack",
		"summary": "Hunters and skirmishers surge forward to punish stalled footwork.",
		"hint": "Expect harder flanks. Reposition early so hunters cannot pin you into volleys.",
		"preferred_tags": ["hunters", "ranged"],
		"swordsman_move_speed_scale": 1.18,
		"swordsman_attack_damage_scale": 1.10,
		"hunter_move_speed_scale": 1.30,
		"hunter_attack_interval_scale": 0.78,
		"hunter_attack_damage_scale": 1.14
	}
]

func _ready() -> void:
	rng.randomize()
	_build_spawn_markers()

func bind_player(player: Node2D) -> void:
	target = player
	active_modifier = _roll_modifier()
	active_waves = _build_active_waves()
	_start_next_wave()

func get_status_title() -> String:
	return _locale_text("Town Enemy Sweep", "城镇敌军清剿", "城鎮敵軍清剿")

func get_status_text() -> String:
	if active_waves.is_empty():
		return _locale_text("Scouts are forming up.", "敌军正在集结。", "敵軍正在集結。")
	if wave_index >= active_waves.size():
		return _locale_text("All enemy waves cleared.", "敌军波次已清空。", "敵軍波次已清空。")
	var wave_name: String = _localized_wave_title(String(active_waves[wave_index]["title"])) if wave_index >= 0 and wave_index < active_waves.size() else _locale_text("Preparing", "准备中", "準備中")
	var modifier_title := get_modifier_title()
	return _locale_text(
		"Wave %d / %d\n%s\nModifier: %s\nEnemies remaining %d",
		"波次 %d / %d\n%s\n词缀：%s\n剩余敌人 %d",
		"波次 %d / %d\n%s\n詞綴：%s\n剩餘敵人 %d"
	) % [
		max(wave_index + 1, 1),
		active_waves.size(),
		String(wave_name),
		modifier_title if not modifier_title.is_empty() else _locale_text("Standard Patrol", "常规巡逻", "常規巡邏"),
		active_enemies.size()
	]

func get_modifier_title() -> String:
	return _localized_modifier_text(String(active_modifier.get("id", "")), "title", String(active_modifier.get("title", "")))

func get_modifier_hint() -> String:
	return _localized_modifier_text(String(active_modifier.get("id", "")), "hint", String(active_modifier.get("hint", "")))

func get_modifier_summary() -> String:
	return _localized_modifier_text(String(active_modifier.get("id", "")), "summary", String(active_modifier.get("summary", "")))

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

func _localized_wave_title(title: String) -> String:
	match title:
		"Frontline Probe":
			return _locale_text("Frontline Probe", "前线试探", "前線試探")
		"Crossfire Patrol":
			return _locale_text("Crossfire Patrol", "交叉火力巡队", "交叉火力巡隊")
		"Shielded Volley":
			return _locale_text("Shielded Volley", "盾阵齐射", "盾陣齊射")
		"Hunter Pincer":
			return _locale_text("Hunter Pincer", "猎手钳击", "獵手鉗擊")
		"Shadow and Spell":
			return _locale_text("Shadow and Spell", "暗影与秘术", "暗影與秘術")
		"Arcane Command":
			return _locale_text("Arcane Command", "奥术统御", "奧術統御")
		_:
			return title

func _localized_modifier_text(modifier_id: String, field: String, fallback: String) -> String:
	match modifier_id:
		"fortified":
			match field:
				"title":
					return _locale_text("Fortified Line", "固守阵线", "固守陣線")
				"summary":
					return _locale_text("Shield carriers reinforce every wave with heavier front-loaded pressure.", "盾卫会让每一波的前排压力都更重。", "盾衛會讓每一波的前排壓力都更重。")
				"hint":
					return _locale_text("Break shield carriers first or kite until the frontline opens.", "优先拆盾卫，或拉扯到前排松动为止。", "優先拆盾衛，或拉扯到前排鬆動為止。")
		"relentless":
			match field:
				"title":
					return _locale_text("Relentless March", "无休行军", "無休行軍")
				"summary":
					return _locale_text("All enemies rotate back in faster and give you shorter recovery windows.", "所有敌人的回转更快，你的喘息窗口会更短。", "所有敵人的回轉更快，你的喘息窗口會更短。")
				"hint":
					return _locale_text("Do not spend movement too early. The next engage comes back faster than normal.", "不要太早交位移，下一轮贴脸会比平时更快回来。", "不要太早交位移，下一輪貼臉會比平時更快回來。")
		"crossfire":
			match field:
				"title":
					return _locale_text("Crossfire Lanes", "交叉火力线", "交叉火力線")
				"summary":
					return _locale_text("Archers and casters hold lanes longer and punish loose positioning.", "弓手与施法者会更久地压住走位线，站位松散就会被惩罚。", "弓手與施法者會更久地壓住走位線，站位鬆散就會被懲罰。")
				"hint":
					return _locale_text("The backline is the timer. Collapse on ranged units before flankers arrive.", "后排就是倒计时，在侧翼近身前先压掉远程。", "後排就是倒計時，在側翼近身前先壓掉遠程。")
		"hunt_pack":
			match field:
				"title":
					return _locale_text("Hunt Pack", "猎群围猎", "獵群圍獵")
				"summary":
					return _locale_text("Hunters and skirmishers surge forward to punish stalled footwork.", "猎手与游击兵会更凶地前压，专抓停顿和失误走位。", "獵手與遊擊兵會更兇地前壓，專抓停頓和失誤走位。")
				"hint":
					return _locale_text("Expect harder flanks. Reposition early so hunters cannot pin you into volleys.", "侧翼会更难处理，尽早换位，别让猎手把你钉进齐射区。", "側翼會更難處理，盡早換位，別讓獵手把你釘進齊射區。")
	return fallback

func _physics_process(_delta: float) -> void:
	if active_enemies.is_empty() and not waiting_for_next_wave and wave_index >= 0:
		waiting_for_next_wave = true
		var timer := get_tree().create_timer(1.1)
		timer.timeout.connect(func() -> void:
			if is_instance_valid(self):
				_start_next_wave()
		)

func _start_next_wave() -> void:
	waiting_for_next_wave = false
	wave_index += 1
	if wave_index >= active_waves.size():
		defeated.emit()
		queue_free()
		return
	active_enemies.clear()
	var wave: Dictionary = active_waves[wave_index]
	var final_wave_active := wave_index >= active_waves.size() - 1
	var used_spawn_indices: Array[int] = []
	for unit_def in wave["units"]:
		var scene: PackedScene = unit_def["scene"] as PackedScene
		var enemy: Node = scene.instantiate()
		enemy.set("elite", bool(unit_def.get("elite", false)))
		_apply_modifier_to_enemy(enemy, final_wave_active)
		var spawn_index := _pick_spawn_marker_index(int(unit_def["spawn"]), used_spawn_indices)
		used_spawn_indices.append(spawn_index)
		enemy_layer.add_child(enemy)
		enemy.global_position = _safe_spawn_position(spawn_index)
		if enemy.has_method("bind_player"):
			enemy.bind_player(target)
		if enemy.has_signal("defeated"):
			enemy.defeated.connect(_on_enemy_defeated.bind(enemy))
		active_enemies.append(enemy)

func _on_enemy_defeated(enemy: Node) -> void:
	active_enemies.erase(enemy)

func _build_spawn_markers() -> void:
	var positions := [
		Vector2(-250.0, -110.0),
		Vector2(250.0, -110.0),
		Vector2(-200.0, -10.0),
		Vector2(200.0, -10.0),
		Vector2(-260.0, -210.0),
		Vector2(260.0, -210.0),
		Vector2(-320.0, 120.0),
		Vector2(320.0, 120.0),
		Vector2(0.0, -240.0)
	]
	for index in range(positions.size()):
		var marker := Marker2D.new()
		marker.name = "Spawn%d" % index
		marker.position = positions[index]
		spawn_layer.add_child(marker)

func _pick_spawn_marker_index(preferred_index: int, used_indices: Array[int]) -> int:
	var marker_count := spawn_layer.get_child_count()
	if marker_count <= 0:
		return 0
	var clamped_preferred := clampi(preferred_index, 0, marker_count - 1)
	if _spawn_marker_is_safe(clamped_preferred, used_indices):
		return clamped_preferred
	var best_index := clamped_preferred
	var best_score := -INF
	for index in range(marker_count):
		var marker := spawn_layer.get_child(index) as Marker2D
		if marker == null:
			continue
		var score := 0.0
		if target != null and is_instance_valid(target):
			var distance_to_player := marker.global_position.distance_to(target.global_position)
			score += distance_to_player
			if distance_to_player < SAFE_SPAWN_DISTANCE:
				score -= 1000.0
		if used_indices.has(index):
			score -= 180.0
		for used_index in used_indices:
			if used_index < 0 or used_index >= marker_count:
				continue
			var used_marker := spawn_layer.get_child(used_index) as Marker2D
			if used_marker != null and marker.global_position.distance_to(used_marker.global_position) < SPAWN_CLUSTER_DISTANCE:
				score -= 120.0
		if abs(index - clamped_preferred) <= 1:
			score += 12.0
		if score > best_score:
			best_score = score
			best_index = index
	return best_index

func _spawn_marker_is_safe(marker_index: int, used_indices: Array[int]) -> bool:
	if used_indices.has(marker_index):
		return false
	var marker := spawn_layer.get_child(marker_index) as Marker2D
	if marker == null:
		return false
	if target != null and is_instance_valid(target) and marker.global_position.distance_to(target.global_position) < SAFE_SPAWN_DISTANCE:
		return false
	return true

func _safe_spawn_position(marker_index: int) -> Vector2:
	var marker := spawn_layer.get_child(clampi(marker_index, 0, max(spawn_layer.get_child_count() - 1, 0))) as Marker2D
	if marker == null:
		return global_position
	var marker_position := marker.global_position
	var spawn_position := marker_position + Vector2(rng.randf_range(-14.0, 14.0), rng.randf_range(-10.0, 10.0))
	if target == null or not is_instance_valid(target):
		return spawn_position
	var best_position := spawn_position
	var best_score := -INF
	var samples := [
		Vector2.ZERO,
		Vector2(72.0, 0.0),
		Vector2(-72.0, 0.0),
		Vector2(0.0, 72.0),
		Vector2(0.0, -72.0),
		Vector2(128.0, 48.0),
		Vector2(-128.0, 48.0),
		Vector2(128.0, -48.0),
		Vector2(-128.0, -48.0)
	]
	for offset in samples:
		var offset_value := offset as Vector2
		var candidate := marker_position + offset_value + Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-8.0, 8.0))
		var distance_to_player := candidate.distance_to(target.global_position)
		var score := distance_to_player
		if distance_to_player < SAFE_SPAWN_DISTANCE:
			score -= 2000.0
		if _spawn_point_is_blocked(candidate):
			score -= 1400.0
		if score > best_score:
			best_score = score
			best_position = candidate
		if distance_to_player >= SAFE_SPAWN_DISTANCE and not _spawn_point_is_blocked(candidate):
			return candidate
	spawn_position = best_position
	var away := spawn_position - target.global_position
	if away.length() >= SAFE_SPAWN_DISTANCE and not _spawn_point_is_blocked(spawn_position):
		return spawn_position
	if away.length_squared() <= 0.001:
		away = Vector2.RIGHT
	var fallback := target.global_position + away.normalized() * SAFE_SPAWN_DISTANCE
	return fallback if not _spawn_point_is_blocked(fallback) else best_position

func _spawn_point_is_blocked(world_position: Vector2) -> bool:
	var space_state := get_world_2d().direct_space_state
	if space_state == null:
		return false
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_position
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return not space_state.intersect_point(query, 1).is_empty()

func _build_active_waves() -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for wave in wave_pool:
		pool.append((wave as Dictionary).duplicate(true))
	var selection: Array[Dictionary] = []
	var preferred_tags: Array = active_modifier.get("preferred_tags", [])
	while selection.is_empty() and not pool.is_empty() and not preferred_tags.is_empty():
		var matching_indices: Array[int] = []
		for wave_index_value in range(pool.size()):
			if _wave_matches_modifier(pool[wave_index_value], preferred_tags):
				matching_indices.append(wave_index_value)
		if matching_indices.is_empty():
			break
		var preferred_index := matching_indices[rng.randi_range(0, matching_indices.size() - 1)]
		selection.append(pool[preferred_index])
		pool.remove_at(preferred_index)
	while selection.is_empty() and not pool.is_empty():
		var next_index := rng.randi_range(0, pool.size() - 1)
		selection.append(pool[next_index])
		pool.remove_at(next_index)
	return selection

func _roll_modifier() -> Dictionary:
	if modifier_pool.is_empty():
		return {}
	var modifier_index := rng.randi_range(0, modifier_pool.size() - 1)
	return (modifier_pool[modifier_index] as Dictionary).duplicate(true)

func _apply_modifier_to_enemy(enemy: Object, final_wave_active: bool) -> void:
	if enemy == null or active_modifier.is_empty():
		return
	_scale_property(enemy, "max_hp", float(active_modifier.get("global_hp_scale", 1.0)))
	_scale_property(enemy, "move_speed", float(active_modifier.get("global_move_speed_scale", 1.0)))
	_scale_property(enemy, "attack_interval", float(active_modifier.get("global_attack_interval_scale", 1.0)))
	_scale_property(enemy, "detection_range", float(active_modifier.get("global_detection_scale", 1.0)))

	if _unit_is_type(enemy, TownEnemy.EnemyType.SHIELD):
		_scale_property(enemy, "defense_value", float(active_modifier.get("shield_defense_scale", 1.0)))
		if bool(active_modifier.get("shield_elite", false)):
			enemy.set("elite", true)

	if _unit_is_type(enemy, TownEnemy.EnemyType.ARCHER) or _unit_is_type(enemy, TownEnemy.EnemyType.APPRENTICE_MAGE) or _unit_is_type(enemy, TownEnemy.EnemyType.ARCANIST):
		_scale_property(enemy, "attack_damage", float(active_modifier.get("ranged_attack_damage_scale", 1.0)))
		_scale_property(enemy, "attack_interval", float(active_modifier.get("ranged_attack_interval_scale", 1.0)))
		_scale_property(enemy, "attack_range", float(active_modifier.get("ranged_attack_range_scale", 1.0)))
		_scale_property(enemy, "detection_range", float(active_modifier.get("ranged_detection_scale", 1.0)))
		if final_wave_active and bool(active_modifier.get("ranged_elite_final_wave", false)):
			enemy.set("elite", true)

	if _unit_is_type(enemy, TownEnemy.EnemyType.SWORDSMAN):
		_scale_property(enemy, "move_speed", float(active_modifier.get("swordsman_move_speed_scale", 1.0)))
		_scale_property(enemy, "attack_damage", float(active_modifier.get("swordsman_attack_damage_scale", 1.0)))

	if _unit_is_type(enemy, TownEnemy.EnemyType.HUNTER):
		_scale_property(enemy, "move_speed", float(active_modifier.get("hunter_move_speed_scale", 1.0)))
		_scale_property(enemy, "attack_interval", float(active_modifier.get("hunter_attack_interval_scale", 1.0)))
		_scale_property(enemy, "attack_damage", float(active_modifier.get("hunter_attack_damage_scale", 1.0)))

func _wave_matches_modifier(wave: Dictionary, preferred_tags: Array) -> bool:
	var tags_value: Variant = wave.get("tags", [])
	if not (tags_value is Array):
		return false
	for tag in preferred_tags:
		if (tags_value as Array).has(tag):
			return true
	return false

func _unit_is_type(enemy: Object, enemy_type: int) -> bool:
	return _has_property(enemy, "enemy_type") and int(enemy.get("enemy_type")) == enemy_type

func _scale_property(target: Object, field: String, scale: float) -> void:
	if target == null or is_equal_approx(scale, 1.0) or not _has_property(target, field):
		return
	target.set(field, float(target.get(field)) * scale)

func _has_property(target: Object, field: String) -> bool:
	if target == null:
		return false
	for property in target.get_property_list():
		if String(property.get("name", "")) == field:
			return true
	return false
