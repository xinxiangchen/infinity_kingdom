extends Node2D

const PREVIEW_SIZE := Vector2i(960, 960)
const PREVIEW_BG := Color(0.08, 0.09, 0.11, 1.0)
const OUTPUT_DIR := "res://tools/generated_previews"
const CAMERA_ZOOM := Vector2.ONE * 0.12
const BOSS_SPECS := [
	{"id": "judicator", "scene": preload("res://actors/bosses/town/judicator_boss.tscn"), "target_offset": Vector2(220.0, -40.0)},
	{"id": "twin_princes", "scene": preload("res://actors/bosses/town/twin_princes_boss.tscn"), "target_offset": Vector2(220.0, -30.0)},
	{"id": "emperor", "scene": preload("res://actors/bosses/town/emperor_boss.tscn"), "target_offset": Vector2(220.0, -20.0)},
	{"id": "ranger", "scene": preload("res://actors/bosses/town/ranger_boss.tscn"), "target_offset": Vector2(220.0, -20.0)},
	{"id": "mage", "scene": preload("res://actors/bosses/town/mage_boss.tscn"), "target_offset": Vector2(220.0, -20.0)}
]

class PreviewTarget:
	extends Node2D

	var hp: float = 100.0
	var max_hp: float = 100.0

	func is_detectable() -> bool:
		return true

	func receive_hit(_payload: Dictionary) -> void:
		pass

var capture_root: Node2D
var background: ColorRect
var camera: Camera2D

func _ready() -> void:
	_setup_view()
	await get_tree().process_frame
	await _capture_all()

func _setup_view() -> void:
	background = ColorRect.new()
	background.color = PREVIEW_BG
	background.size = Vector2(PREVIEW_SIZE)
	add_child(background)

	capture_root = Node2D.new()
	capture_root.position = Vector2(PREVIEW_SIZE) * 0.5 + Vector2(0.0, 72.0)
	add_child(capture_root)

	camera = Camera2D.new()
	camera.enabled = true
	camera.position = Vector2(PREVIEW_SIZE) * 0.5
	camera.zoom = CAMERA_ZOOM
	add_child(camera)

func _capture_all() -> void:
	var absolute_output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	print("Boss preview output: ", absolute_output_dir)
	DirAccess.make_dir_recursive_absolute(absolute_output_dir)
	for spec in BOSS_SPECS:
		await _capture_spec(spec)
	get_tree().quit()

func _capture_spec(spec: Dictionary) -> void:
	for child in capture_root.get_children():
		child.queue_free()
	await get_tree().process_frame

	var boss := (spec["scene"] as PackedScene).instantiate()
	var target := PreviewTarget.new()
	target.position = Vector2(spec.get("target_offset", Vector2(220.0, -20.0)))
	target.add_to_group("player")
	capture_root.add_child(target)
	capture_root.add_child(boss)

	if boss.has_method("bind_player"):
		boss.bind_player(target)
	if boss.has_method("_update_visuals"):
		boss.call("_update_visuals")

	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	_save_capture(String(spec["id"]))
	_configure_weapon_debug(boss)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save_capture("%s_weapon_debug" % String(spec["id"]))

func _save_capture(name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var output_path := "%s/%s.png" % [OUTPUT_DIR, name]
	var absolute_output_path := ProjectSettings.globalize_path(output_path)
	print("Saving boss preview: ", absolute_output_path)
	image.save_png(absolute_output_path)

func _configure_weapon_debug(boss: Node) -> void:
	var body_node := boss.get_node_or_null("Body")
	if body_node is CanvasItem:
		(body_node as CanvasItem).modulate = Color(1.0, 1.0, 1.0, 0.18)
		for child in body_node.get_children():
			if child is CanvasItem:
				(child as CanvasItem).modulate = Color(1.0, 1.0, 1.0, 0.18)

	for weapon_name in ["Weapon", "Sword", "Spear"]:
		var weapon_node := boss.get_node_or_null(weapon_name)
		if weapon_node == null:
			continue
		if weapon_node is CanvasItem:
			(weapon_node as CanvasItem).modulate = Color(1.0, 0.34, 0.34, 1.0)
		for child in weapon_node.get_children():
			if child is CanvasItem:
				(child as CanvasItem).modulate = Color(1.0, 0.34, 0.34, 1.0)
		_add_pivot_cross(weapon_node)

func _add_pivot_cross(parent_node: Node) -> void:
	if not (parent_node is Node2D):
		return
	var cross_a := Line2D.new()
	cross_a.default_color = Color(0.42, 1.0, 1.0, 1.0)
	cross_a.width = 2.0
	cross_a.points = PackedVector2Array([Vector2(-10.0, 0.0), Vector2(10.0, 0.0)])
	parent_node.add_child(cross_a)

	var cross_b := Line2D.new()
	cross_b.default_color = Color(0.42, 1.0, 1.0, 1.0)
	cross_b.width = 2.0
	cross_b.points = PackedVector2Array([Vector2(0.0, -10.0), Vector2(0.0, 10.0)])
	parent_node.add_child(cross_b)
