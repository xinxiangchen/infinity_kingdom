extends SceneTree

const BOSS_SCENES := [
	"res://actors/bosses/town/judicator_boss.tscn",
	"res://actors/bosses/town/emperor_boss.tscn",
	"res://actors/bosses/town/ranger_boss.tscn",
	"res://actors/bosses/town/mage_boss.tscn",
	"res://actors/bosses/town/twin_princes_boss.tscn"
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for scene_path in BOSS_SCENES:
		var scene := load(scene_path) as PackedScene
		if scene == null:
			push_error("Boss scene did not load: %s" % scene_path)
			quit(1)
			return
		var boss := scene.instantiate()
		root.add_child(boss)
		await process_frame
		var sprites := boss.find_children("*", "Sprite2D", true, false)
		if sprites.is_empty():
			push_error("Boss scene has no sprite visuals: %s" % scene_path)
			quit(1)
			return
		var textured_sprite_count := 0
		for sprite in sprites:
			if sprite is Sprite2D and (sprite as Sprite2D).texture != null:
				textured_sprite_count += 1
		if textured_sprite_count <= 0:
			push_error("Boss sprite textures did not load: %s" % scene_path)
			quit(1)
			return
		boss.queue_free()
		await process_frame
	quit(0)
