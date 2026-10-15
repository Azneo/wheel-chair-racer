extends Node

signal stats_changed

const BASE_MAX_SPEED_KMH: float = 65.0
const BASE_ACCELERATION_KMH_PER_SECOND: float = 35.0
const SAVE_VERSION: int = 1
const DEFAULT_SAVE_PATH: String = "user://player_upgrades_v1.json"
const ENGINE_CHOICES: Array[Dictionary] = [
	{
		"id": "comet",
		"name": "COMET",
		"visual_id": "comet",
		"description": "Higher top speed for the long straights.",
		"max_speed_bonus_kmh": 10.0,
		"acceleration_bonus_kmh_per_second": 0.0,
	},
	{
		"id": "rally",
		"name": "RALLY",
		"visual_id": "rally",
		"description": "A balanced boost to pace and pickup.",
		"max_speed_bonus_kmh": 5.0,
		"acceleration_bonus_kmh_per_second": 10.0,
	},
	{
		"id": "launch",
		"name": "LAUNCH",
		"visual_id": "launch",
		"description": "Fast acceleration off the line.",
		"max_speed_bonus_kmh": 0.0,
		"acceleration_bonus_kmh_per_second": 20.0,
	},
]

@export var save_path: String = DEFAULT_SAVE_PATH
var selected_engine_id: String = ""
var persistence_error: String = ""

var max_speed_kmh: float:
	get:
		return BASE_MAX_SPEED_KMH + float(get_selected_engine().get("max_speed_bonus_kmh", 0.0))

var acceleration_kmh_per_second: float:
	get:
		return BASE_ACCELERATION_KMH_PER_SECOND + float(get_selected_engine().get("acceleration_bonus_kmh_per_second", 0.0))


func _ready() -> void:
	load_selection()


func get_engine_choices() -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	for choice in ENGINE_CHOICES:
		choices.append(choice.duplicate(true))
	return choices


func get_selected_engine() -> Dictionary:
	for choice in ENGINE_CHOICES:
		if choice["id"] == selected_engine_id:
			return choice.duplicate(true)
	return {"id": "", "name": "STOCK"}


func select_engine(engine_id: String) -> bool:
	if engine_id != "" and not _has_engine(engine_id):
		persistence_error = "Unknown engine upgrade: " + engine_id
		push_error(persistence_error)
		return false
	if selected_engine_id == engine_id:
		return true
	selected_engine_id = engine_id
	var saved: bool = _save_selection()
	stats_changed.emit()
	return saved


func load_selection() -> void:
	selected_engine_id = ""
	persistence_error = ""
	if save_path.is_empty() or not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		_set_load_error("Could not open the player upgrade save.")
		return
	if file.get_length() > 4096:
		file.close()
		_set_load_error("The player upgrade save is too large.")
		return
	var parser := JSON.new()
	var parse_result: Error = parser.parse(file.get_as_text())
	file.close()
	if parse_result != OK:
		_set_load_error("The player upgrade save is not valid JSON.")
		return
	var data: Variant = parser.data
	if not data is Dictionary or data.get("version") != SAVE_VERSION:
		_set_load_error("The player upgrade save has an unsupported format.")
		return
	var value: Variant = data.get("selected_engine_id", "")
	if typeof(value) != TYPE_STRING or (value != "" and not _has_engine(value)):
		_set_load_error("The saved engine selection is invalid.")
		return
	selected_engine_id = value


func _save_selection() -> bool:
	persistence_error = ""
	if save_path.is_empty():
		persistence_error = "Player upgrade save path is empty."
		push_warning(persistence_error)
		return false
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		persistence_error = "Could not write the player upgrade save."
		push_warning(persistence_error)
		return false
	file.store_string(JSON.stringify({
		"version": SAVE_VERSION,
		"selected_engine_id": selected_engine_id,
	}))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		persistence_error = "Could not finish writing the player upgrade save."
		push_warning(persistence_error)
		return false
	return true


func _has_engine(engine_id: String) -> bool:
	for choice in ENGINE_CHOICES:
		if choice["id"] == engine_id:
			return true
	return false


func _set_load_error(message: String) -> void:
	persistence_error = message
	push_warning(message + " Using the stock setup.")
