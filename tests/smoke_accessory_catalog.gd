extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager := root.get_node_or_null("/root/AccessoryManager")
	if manager == null:
		push_error("AccessoryManager missing")
		quit(1)
		return
	manager.reload_catalog()
	var catalog: Array = manager.get_catalog()
	if catalog.size() < 8:
		push_error("Accessory catalog is unexpectedly small")
		quit(1)
		return
	var seen := {}
	for accessory in catalog:
		var id := String(accessory.get("id", ""))
		if id.is_empty():
			push_error("Accessory has empty id")
			quit(1)
			return
		if seen.has(id):
			push_error("Duplicate accessory id: %s" % id)
			quit(1)
			return
		seen[id] = true
		if not ResourceLoader.exists(String(accessory.get("icon", ""))):
			push_error("Missing accessory icon: %s" % id)
			quit(1)
			return
	var choices: Array = manager.generate_choices(3)
	if choices.size() != 3:
		push_error("Accessory choice generation failed")
		quit(1)
		return
	quit(0)
