extends Node

signal slots_changed(slots: Array)
signal active_slot_changed(slot: Dictionary)

const SAVE_PATH := "user://ik_saves.dat"
const MAGIC := 0x494B5356 # IKSV
const VERSION := 1
const SLOT_COUNT := 5
const HEADER_SIZE := 32
const RECORD_SIZE := 512

const OFF_OCCUPIED := 0
const OFF_DEAD_ARCHIVE := 1
const OFF_CLEARED := 2
const OFF_SLOT_ID := 4
const OFF_SAVE_NAME := 8
const SAVE_NAME_SIZE := 64
const OFF_FAMILY_ID := 72
const FAMILY_ID_SIZE := 16
const OFF_REINCARNATION := 88
const OFF_GENERATION := 92
const OFF_SEEDS_LEFT := 96
const OFF_CURRENT_ENCOUNTER := 100
const OFF_EMPEROR_MAX_HP := 104
const OFF_EMPEROR_REMAINING_HP := 108
const OFF_STRENGTH := 112
const OFF_AGILITY := 116
const OFF_FOCUS := 120
const OFF_LAST_SCORE := 124
const OFF_LAST_SCORE_GRADE := 128
const SCORE_GRADE_SIZE := 8
const OFF_TOTAL_RUNS := 136
const OFF_TOTAL_DEATHS := 140
const OFF_UPDATED_UNIX_TIME := 144
const OFF_CROWNED_FAMILIES := 152
const CROWNED_FAMILIES_SIZE := 48
const OFF_CURRENT_EMPEROR_FAMILY := 200
const CURRENT_EMPEROR_FAMILY_SIZE := 16
const OFF_ENDING_TYPE := 216
const ENDING_TYPE_SIZE := 32

var active_slot_index: int = -1
var active_slot: Dictionary = {}
var save_path: String = SAVE_PATH

func _ready() -> void:
	_ensure_save_file()

func list_slots() -> Array[Dictionary]:
	_ensure_save_file()
	var slots: Array[Dictionary] = []
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return slots
	for index in range(SLOT_COUNT):
		file.seek(_slot_offset(index))
		slots.append(_read_record_at_current_position(file, index))
	return slots

func create_slot(slot_index: int, save_name: String, family_id: String = "") -> Dictionary:
	if not _is_valid_slot(slot_index):
		return {}
	_ensure_save_file()
	var record := _default_record(slot_index)
	record["occupied"] = true
	record["save_name"] = save_name
	record["family_id"] = family_id
	record["updated_unix_time"] = Time.get_unix_time_from_system()
	_write_full_record(slot_index, record)
	active_slot_index = slot_index
	active_slot = read_slot(slot_index)
	slots_changed.emit(list_slots())
	active_slot_changed.emit(active_slot.duplicate(true))
	return active_slot.duplicate(true)

func delete_slot(slot_index: int) -> void:
	if not _is_valid_slot(slot_index):
		return
	_ensure_save_file()
	_write_full_record(slot_index, _default_record(slot_index))
	if slot_index == active_slot_index:
		active_slot_index = -1
		active_slot = {}
		active_slot_changed.emit({})
	slots_changed.emit(list_slots())

func select_slot(slot_index: int) -> Dictionary:
	var slot := read_slot(slot_index)
	if slot.is_empty() or not bool(slot.get("occupied", false)):
		return {}
	active_slot_index = slot_index
	active_slot = slot.duplicate(true)
	active_slot_changed.emit(active_slot.duplicate(true))
	return active_slot.duplicate(true)

func read_slot(slot_index: int) -> Dictionary:
	if not _is_valid_slot(slot_index):
		return {}
	_ensure_save_file()
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {}
	file.seek(_slot_offset(slot_index))
	return _read_record_at_current_position(file, slot_index)

func get_active_slot() -> Dictionary:
	if active_slot_index >= 0:
		active_slot = read_slot(active_slot_index)
	return active_slot.duplicate(true)

func update_active_slot_patch(patch: Dictionary) -> Dictionary:
	if active_slot_index < 0:
		return {}
	return update_slot_patch(active_slot_index, patch)

func update_slot_patch(slot_index: int, patch: Dictionary) -> Dictionary:
	if not _is_valid_slot(slot_index):
		return {}
	var file := FileAccess.open(save_path, FileAccess.READ_WRITE)
	if file == null:
		return {}
	var base := _slot_offset(slot_index)
	for key in patch.keys():
		match String(key):
			"dead_archive":
				file.seek(base + OFF_DEAD_ARCHIVE)
				file.store_8(1 if bool(patch[key]) else 0)
			"cleared":
				file.seek(base + OFF_CLEARED)
				file.store_8(1 if bool(patch[key]) else 0)
			"save_name":
				file.seek(base + OFF_SAVE_NAME)
				file.store_buffer(_fixed_string_bytes(String(patch[key]), SAVE_NAME_SIZE))
			"family_id":
				file.seek(base + OFF_FAMILY_ID)
				file.store_buffer(_fixed_string_bytes(String(patch[key]), FAMILY_ID_SIZE))
			"reincarnation_index":
				file.seek(base + OFF_REINCARNATION)
				file.store_32(int(patch[key]))
			"generation_index":
				file.seek(base + OFF_GENERATION)
				file.store_32(int(patch[key]))
			"seeds_left":
				file.seek(base + OFF_SEEDS_LEFT)
				file.store_32(int(patch[key]))
			"current_encounter_index":
				file.seek(base + OFF_CURRENT_ENCOUNTER)
				file.store_32(int(patch[key]))
			"emperor_max_hp":
				file.seek(base + OFF_EMPEROR_MAX_HP)
				file.store_32(int(round(float(patch[key]))))
			"emperor_remaining_hp":
				file.seek(base + OFF_EMPEROR_REMAINING_HP)
				file.store_32(int(round(float(patch[key]))))
			"strength":
				file.seek(base + OFF_STRENGTH)
				file.store_32(int(patch[key]))
			"agility":
				file.seek(base + OFF_AGILITY)
				file.store_32(int(patch[key]))
			"focus":
				file.seek(base + OFF_FOCUS)
				file.store_32(int(patch[key]))
			"last_score":
				file.seek(base + OFF_LAST_SCORE)
				file.store_32(int(patch[key]))
			"last_score_grade":
				file.seek(base + OFF_LAST_SCORE_GRADE)
				file.store_buffer(_fixed_string_bytes(String(patch[key]), SCORE_GRADE_SIZE))
			"total_runs":
				file.seek(base + OFF_TOTAL_RUNS)
				file.store_32(int(patch[key]))
			"total_deaths":
				file.seek(base + OFF_TOTAL_DEATHS)
				file.store_32(int(patch[key]))
			"crowned_families":
				file.seek(base + OFF_CROWNED_FAMILIES)
				file.store_buffer(_fixed_string_bytes(String(patch[key]), CROWNED_FAMILIES_SIZE))
			"current_emperor_family":
				file.seek(base + OFF_CURRENT_EMPEROR_FAMILY)
				file.store_buffer(_fixed_string_bytes(String(patch[key]), CURRENT_EMPEROR_FAMILY_SIZE))
			"ending_type":
				file.seek(base + OFF_ENDING_TYPE)
				file.store_buffer(_fixed_string_bytes(String(patch[key]), ENDING_TYPE_SIZE))
	file.seek(base + OFF_UPDATED_UNIX_TIME)
	file.store_64(int(Time.get_unix_time_from_system()))
	if slot_index == active_slot_index:
		active_slot = read_slot(slot_index)
		active_slot_changed.emit(active_slot.duplicate(true))
	slots_changed.emit(list_slots())
	return read_slot(slot_index)

func mark_active_dead_archive() -> void:
	update_active_slot_patch({
		"dead_archive": true,
		"seeds_left": 0
	})

func seal_active_ending(ending_type: String) -> void:
	if ending_type.is_empty():
		return
	var current := get_active_slot()
	if not String(current.get("ending_type", "")).is_empty():
		return
	update_active_slot_patch({
		"dead_archive": true,
		"cleared": true,
		"ending_type": ending_type
	})

func _ensure_save_file() -> void:
	if FileAccess.file_exists(save_path):
		var file := FileAccess.open(save_path, FileAccess.READ)
		if file != null and file.get_length() >= HEADER_SIZE + SLOT_COUNT * RECORD_SIZE:
			file.seek(0)
			if int(file.get_32()) == MAGIC:
				return
	var write_file := FileAccess.open(save_path, FileAccess.WRITE)
	if write_file == null:
		return
	write_file.store_32(MAGIC)
	write_file.store_32(VERSION)
	write_file.store_32(SLOT_COUNT)
	write_file.store_32(RECORD_SIZE)
	write_file.store_64(int(Time.get_unix_time_from_system()))
	write_file.store_buffer(PackedByteArray())
	while write_file.get_position() < HEADER_SIZE:
		write_file.store_8(0)
	for index in range(SLOT_COUNT):
		var record := _default_record(index)
		_store_record(write_file, record)

func _write_full_record(slot_index: int, record: Dictionary) -> void:
	var file := FileAccess.open(save_path, FileAccess.READ_WRITE)
	if file == null:
		return
	file.seek(_slot_offset(slot_index))
	_store_record(file, record)

func _store_record(file: FileAccess, record: Dictionary) -> void:
	var start := file.get_position()
	file.store_8(1 if bool(record.get("occupied", false)) else 0)
	file.store_8(1 if bool(record.get("dead_archive", false)) else 0)
	file.store_8(1 if bool(record.get("cleared", false)) else 0)
	file.store_8(0)
	file.store_32(int(record.get("slot_id", 0)))
	file.store_buffer(_fixed_string_bytes(String(record.get("save_name", "")), SAVE_NAME_SIZE))
	file.store_buffer(_fixed_string_bytes(String(record.get("family_id", "")), FAMILY_ID_SIZE))
	file.store_32(int(record.get("reincarnation_index", 1)))
	file.store_32(int(record.get("generation_index", 1)))
	file.store_32(int(record.get("seeds_left", 5)))
	file.store_32(int(record.get("current_encounter_index", 0)))
	file.store_32(int(round(float(record.get("emperor_max_hp", 5000.0)))))
	file.store_32(int(round(float(record.get("emperor_remaining_hp", 5000.0)))))
	file.store_32(int(record.get("strength", 3)))
	file.store_32(int(record.get("agility", 3)))
	file.store_32(int(record.get("focus", 3)))
	file.store_32(int(record.get("last_score", 0)))
	file.store_buffer(_fixed_string_bytes(String(record.get("last_score_grade", "")), SCORE_GRADE_SIZE))
	file.store_32(int(record.get("total_runs", 1)))
	file.store_32(int(record.get("total_deaths", 0)))
	file.store_64(int(record.get("updated_unix_time", Time.get_unix_time_from_system())))
	file.seek(start + OFF_CROWNED_FAMILIES)
	file.store_buffer(_fixed_string_bytes(String(record.get("crowned_families", "")), CROWNED_FAMILIES_SIZE))
	file.seek(start + OFF_CURRENT_EMPEROR_FAMILY)
	file.store_buffer(_fixed_string_bytes(String(record.get("current_emperor_family", "")), CURRENT_EMPEROR_FAMILY_SIZE))
	file.seek(start + OFF_ENDING_TYPE)
	file.store_buffer(_fixed_string_bytes(String(record.get("ending_type", "")), ENDING_TYPE_SIZE))
	while file.get_position() < start + RECORD_SIZE:
		file.store_8(0)

func _read_record_at_current_position(file: FileAccess, fallback_slot_id: int) -> Dictionary:
	var start := file.get_position()
	var occupied := file.get_8() != 0
	var dead_archive := file.get_8() != 0
	var cleared := file.get_8() != 0
	file.get_8()
	var slot_id := int(file.get_32())
	var save_name := _read_fixed_string(file, SAVE_NAME_SIZE)
	var family_id := _read_fixed_string(file, FAMILY_ID_SIZE)
	var record := {
		"occupied": occupied,
		"dead_archive": dead_archive,
		"cleared": cleared,
		"slot_id": slot_id if slot_id >= 0 else fallback_slot_id,
		"save_name": save_name,
		"family_id": family_id,
		"reincarnation_index": int(file.get_32()),
		"generation_index": int(file.get_32()),
		"seeds_left": int(file.get_32()),
		"current_encounter_index": int(file.get_32()),
		"emperor_max_hp": float(file.get_32()),
		"emperor_remaining_hp": float(file.get_32()),
		"strength": int(file.get_32()),
		"agility": int(file.get_32()),
		"focus": int(file.get_32()),
		"last_score": int(file.get_32()),
		"last_score_grade": _read_fixed_string(file, SCORE_GRADE_SIZE),
		"total_runs": int(file.get_32()),
		"total_deaths": int(file.get_32()),
		"updated_unix_time": int(file.get_64()),
		"crowned_families": "",
		"current_emperor_family": "",
		"ending_type": ""
	}
	file.seek(start + OFF_CROWNED_FAMILIES)
	record["crowned_families"] = _read_fixed_string(file, CROWNED_FAMILIES_SIZE)
	file.seek(start + OFF_CURRENT_EMPEROR_FAMILY)
	record["current_emperor_family"] = _read_fixed_string(file, CURRENT_EMPEROR_FAMILY_SIZE)
	file.seek(start + OFF_ENDING_TYPE)
	record["ending_type"] = _read_fixed_string(file, ENDING_TYPE_SIZE)
	file.seek(start + RECORD_SIZE)
	if not occupied:
		record["slot_id"] = fallback_slot_id
	return record

func _default_record(slot_index: int) -> Dictionary:
	return {
		"occupied": false,
		"dead_archive": false,
		"cleared": false,
		"slot_id": slot_index,
		"save_name": "",
		"family_id": "",
		"reincarnation_index": 1,
		"generation_index": 1,
		"seeds_left": 5,
		"current_encounter_index": 0,
		"emperor_max_hp": 5000.0,
		"emperor_remaining_hp": 5000.0,
		"strength": 3,
		"agility": 3,
		"focus": 3,
		"last_score": 0,
		"last_score_grade": "",
		"total_runs": 1,
		"total_deaths": 0,
		"crowned_families": "",
		"current_emperor_family": "",
		"ending_type": "",
		"updated_unix_time": 0
	}

func _fixed_string_bytes(value: String, size: int) -> PackedByteArray:
	var source := value.to_utf8_buffer()
	var result := PackedByteArray()
	result.resize(size)
	for index in range(mini(source.size(), size - 1)):
		result[index] = source[index]
	return result

func _read_fixed_string(file: FileAccess, size: int) -> String:
	var bytes := file.get_buffer(size)
	var end := 0
	while end < bytes.size() and bytes[end] != 0:
		end += 1
	return bytes.slice(0, end).get_string_from_utf8()

func _slot_offset(slot_index: int) -> int:
	return HEADER_SIZE + slot_index * RECORD_SIZE

func _is_valid_slot(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < SLOT_COUNT
