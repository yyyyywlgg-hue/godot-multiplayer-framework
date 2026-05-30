class_name SaveSystem
extends Node

signal save_completed(section: String)
signal load_completed(section: String)

var _data: Dictionary = {}
var _save_path: String = "user://save_data.json"
var _auto_save_timer: Timer
var _auto_save_interval: float = 60.0
var _dirty: bool = false
var _current_slot: int = 0

func _ready() -> void:
	_load_from_disk()
	_auto_save_timer = Timer.new()
	_auto_save_timer.wait_time = _auto_save_interval
	_auto_save_timer.timeout.connect(_on_auto_save)
	add_child(_auto_save_timer)
	_auto_save_timer.start()

func set_value(section: String, key: String, value: Variant) -> void:
	if not _is_json_serializable(value):
		push_error("SaveSystem: value of type '%s' is not JSON-serializable (section=%s, key=%s)" % [typeof(value), section, key])
		return
	if not _data.has(section):
		_data[section] = {}
	_data[section][key] = value
	_dirty = true

func get_value(section: String, key: String, default: Variant = null) -> Variant:
	if not _data.has(section):
		return default
	if not _data[section].has(key):
		return default
	return _data[section][key]

func has_section(section: String) -> bool:
	return _data.has(section)

func has_section_key(section: String, key: String) -> bool:
	return _data.has(section) and _data[section].has(key)

func erase_section(section: String) -> void:
	_data.erase(section)
	_dirty = true

func erase_section_key(section: String, key: String) -> void:
	if _data.has(section):
		_data[section].erase(key)
		_dirty = true

func get_section_keys(section: String) -> Array:
	if not _data.has(section):
		return []
	return _data[section].keys()

func save() -> void:
	_write_to_disk()
	_dirty = false
	for section in _data:
		save_completed.emit(section)

func load_from_disk() -> bool:
	return _load_from_disk()

func clear_all() -> void:
	_data = {}
	_dirty = true
	_write_to_disk()

func clear_section(section: String) -> void:
	_data.erase(section)
	_dirty = true

func is_dirty() -> bool:
	return _dirty

func set_slot(slot: int) -> void:
	_current_slot = slot
	_save_path = "user://save_data_slot_%d.json" % slot
	_load_from_disk()

func get_slot() -> int:
	return _current_slot

func get_available_slots(max_slots: int = 5) -> Array:
	var slots := []
	for i in range(max_slots):
		var path = "user://save_data_slot_%d.json" % i
		slots.append({
			"slot": i,
			"exists": FileAccess.file_exists(path),
		})
	return slots

func delete_slot(slot: int) -> bool:
	var path = "user://save_data_slot_%d.json" % slot
	if FileAccess.file_exists(path):
		var err = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return err == OK
	return false

func _is_json_serializable(value: Variant) -> bool:
	var t = typeof(value)
	return t == TYPE_NIL or t == TYPE_BOOL or t == TYPE_INT or t == TYPE_FLOAT or t == TYPE_STRING or t == TYPE_ARRAY or t == TYPE_DICTIONARY

func _load_from_disk() -> bool:
	if not FileAccess.file_exists(_save_path):
		_data = {}
		return false
	var file = FileAccess.open(_save_path, FileAccess.READ)
	if file == null:
		push_error("SaveSystem: failed to open save file")
		return false
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file = null
	if err != OK:
		push_error("SaveSystem: failed to parse save file at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		_data = {}
		return false
	var parsed = json.data
	if not parsed is Dictionary:
		push_error("SaveSystem: save file is not a dictionary")
		_data = {}
		return false
	_data = parsed
	_dirty = false
	for section in _data:
		load_completed.emit(section)
	return true

func _write_to_disk() -> bool:
	var file = FileAccess.open(_save_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: failed to write save file")
		return false
	file.store_string(JSON.stringify(_data, "\t"))
	file = null
	return true

func _on_auto_save() -> void:
	if _dirty:
		save()
