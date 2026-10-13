extends Node

signal updated
signal state_changed

enum State { READY, COUNTDOWN, RACING, FINISHED }

const CHECKPOINT_INDICES: Array[int] = [6, 28, 50, 60, 72, 84]

var state: State = State.READY
var elapsed_seconds: float = 0.0
var countdown_remaining: float = 3.0
var checkpoint_count: int = 0
var best_ms: int = 0
var previous_best_ms: int = 0
var result_ms: int = 0
var new_record: bool = false
var save_failed: bool = false
var save_path: String = "user://best_time_v1.json"
var checkpoints: Array[Transform3D] = []
var finish: Transform3D
var half_width: float = 4.5
var player: CharacterBody3D
var previous_position: Vector3


func configure(vehicle: CharacterBody3D, points: PackedVector3Array, track_width: float, storage_path: String) -> void:
	player = vehicle
	save_path = storage_path
	half_width = track_width * 0.5
	for point_index in CHECKPOINT_INDICES:
		var direction: Vector3 = (points[point_index + 1] - points[point_index - 1]).normalized()
		checkpoints.append(Transform3D(Basis.looking_at(direction), points[point_index] + Vector3.UP * 0.08))
	finish = Transform3D(Basis.IDENTITY, Vector3(points[0].x, 0.08, 12.0))
	player.driving_enabled = false
	player.respawned.connect(_on_respawn)
	previous_position = player.global_position
	best_ms = _load_best()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 1


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		toggle_pause()
		get_viewport().set_input_as_handled()


func start_attempt() -> void:
	get_tree().paused = false
	state = State.COUNTDOWN
	elapsed_seconds = 0.0
	countdown_remaining = 3.0
	checkpoint_count = 0
	result_ms = 0
	previous_best_ms = 0
	new_record = false
	save_failed = false
	player.driving_enabled = false
	player.recovery_transform = player.spawn_transform
	player.reset_to_start()
	state_changed.emit()
	updated.emit()


func toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	state_changed.emit()


func _physics_process(delta: float) -> void:
	if get_tree().paused or not is_instance_valid(player):
		return
	if state == State.COUNTDOWN:
		countdown_remaining = maxf(0.0, countdown_remaining - delta)
		if countdown_remaining < 0.000001:
			countdown_remaining = 0.0
			state = State.RACING
			player.driving_enabled = true
			previous_position = player.global_position
			state_changed.emit()
	elif state == State.RACING:
		elapsed_seconds += delta
		check_motion(player, previous_position, player.global_position, delta)
		previous_position = player.global_position
	updated.emit()


func _on_respawn() -> void:
	previous_position = player.global_position


func crossing_fraction(gate: Transform3D, from: Vector3, to: Vector3) -> float:
	var local_from: Vector3 = gate.affine_inverse() * from
	var local_to: Vector3 = gate.affine_inverse() * to
	if local_from.z <= 0.0 or local_to.z > 0.0:
		return -1.0
	var fraction: float = local_from.z / (local_from.z - local_to.z)
	var crossing: Vector3 = local_from.lerp(local_to, fraction)
	if absf(crossing.x) > half_width or crossing.y < -0.5 or crossing.y > 1.5:
		return -1.0
	return fraction


func check_motion(body: Node3D, from: Vector3, to: Vector3, delta: float) -> void:
	if body != player or state != State.RACING or get_tree().paused:
		return
	if checkpoint_count < checkpoints.size():
		var checkpoint: Transform3D = checkpoints[checkpoint_count]
		if crossing_fraction(checkpoint, from, to) >= 0.0:
			checkpoint_count += 1
			player.recovery_transform = checkpoint
			player.recovery_transform.origin -= checkpoint.basis.z * 1.5
	else:
		var fraction: float = crossing_fraction(finish, from, to)
		if fraction >= 0.0:
			elapsed_seconds = maxf(0.0, elapsed_seconds - delta * (1.0 - fraction))
			_finish_attempt()


func _finish_attempt() -> void:
	result_ms = maxi(1, roundi(elapsed_seconds * 1000.0))
	state = State.FINISHED
	player.driving_enabled = false
	player.speed = 0.0
	player.velocity = Vector3.ZERO
	previous_best_ms = best_ms
	new_record = best_ms == 0 or result_ms < best_ms
	if new_record:
		best_ms = result_ms
		save_failed = not _save_best()
	state_changed.emit()


func countdown_text() -> String:
	if state == State.COUNTDOWN:
		return str(ceili(countdown_remaining))
	if state == State.RACING and elapsed_seconds < 0.75:
		return "Los!"
	return ""


static func format_time(milliseconds: int) -> String:
	var total: int = maxi(0, milliseconds)
	var minutes: int = int(total / 60000.0)
	var seconds: int = int(total / 1000.0) % 60
	return "%02d:%02d.%03d" % [minutes, seconds, total % 1000]


func _load_best() -> int:
	if save_path.is_empty() or not FileAccess.file_exists(save_path):
		return 0
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null or file.get_length() > 4096:
		return 0
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return 0
	var data: Variant = parser.data
	if not data is Dictionary or data.get("version") != 1:
		return 0
	var value: Variant = data.get("best_ms")
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return 0
	var number: float = float(value)
	if not is_finite(number) or number <= 0.0 or number > 9007199254740991.0 or number != floor(number):
		return 0
	return int(number)


func _save_best() -> bool:
	if save_path.is_empty():
		return false
	var temporary_path: String = save_path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"version": 1, "best_ms": best_ms}))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary_path), ProjectSettings.globalize_path(save_path)) == OK