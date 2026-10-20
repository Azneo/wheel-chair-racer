extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const RaceController = preload("res://scripts/race.gd")
const PlayerUpgradeData = preload("res://scripts/player_upgrades.gd")

var game: Node3D
var failures: Array[String] = []
var checks: int = 0
var test_directory: String
var test_path: String


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for frame_index in range(count):
		await physics_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func _key(keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)


func _tap(keycode: int) -> void:
	_key(keycode, true)
	await _frames(1)
	_key(keycode, false)
	await _frames(1)


func _cross(gate: Transform3D, reverse: bool = false, actor: Node3D = null) -> void:
	var offset: Vector3 = gate.basis.z * (0.7 if not reverse else -0.7)
	game.race.check_motion(game.player if actor == null else actor, gate.origin + offset, gate.origin - offset, 0.0)


func _begin() -> void:
	game._start_game()
	await _frames(182)
	_check(game.race.state == RaceController.State.RACING, "Countdown releases a new attempt")


func _at_recovery() -> bool:
	var offset: Vector3 = game.player.global_position - game.player.recovery_transform.origin
	return Vector2(offset.x, offset.z).length() < 0.01 and absf(offset.y) < game.player.floor_snap_length and game.player.is_on_floor()


func _finish_with_time(seconds: float) -> void:
	for checkpoint in game.race.checkpoints:
		_cross(checkpoint)
	game.race.elapsed_seconds = seconds
	_cross(game.race.finish)


func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_check(not image.is_empty() and image.save_png("user://race-" + name + ".png") == OK, "Real graphical capture: " + name)


func _drive_complete_lap() -> void:
	await _begin()
	var route: PackedVector3Array = game.track_points.duplicate()
	route.append(Vector3(12.0, 0.0, 8.0))
	var target_index: int = 1
	var collision_frames: int = 0
	for frame_index in range(2400):
		if game.race.state == RaceController.State.FINISHED:
			break
		var flat_position: Vector3 = game.player.global_position
		flat_position.y = 0.0
		while target_index < route.size() - 1 and flat_position.distance_to(route[target_index]) < 3.0:
			target_index += 1
		var desired_direction: Vector3 = (route[target_index] - flat_position).normalized()
		var desired_yaw: float = atan2(-desired_direction.x, -desired_direction.z)
		var error: float = wrapf(desired_yaw - game.player.rotation.y, -PI, PI)
		Input.action_release("steer_left")
		Input.action_release("steer_right")
		if absf(error) > 0.005:
			Input.action_press("steer_left" if error > 0.0 else "steer_right", clampf(absf(error) * 3.0, 0.0, 1.0))
		if game.player.speed < 9.0:
			Input.action_press("accelerate")
		else:
			Input.action_release("accelerate")
		await _frames(1)
		if game.player.is_on_wall():
			collision_frames += 1
	for action in ["accelerate", "steer_left", "steer_right"]:
		Input.action_release(action)
	_check(game.race.state == RaceController.State.FINISHED and game.race.checkpoint_count == 6, "Real vehicle completes the existing circuit and all checkpoints via InputMap")
	_check(collision_frames == 0, "Automated full lap does not hit any track wall")
	_check(game.race.result_ms > 10000, "Integrated lap has a plausible nonzero elapsed time")
	print("AUTOMATED LAP: " + RaceController.format_time(game.race.result_ms))
	await _capture("completed-lap")


func _run() -> void:
	test_directory = "user://race-tests-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	test_path = test_directory + "/best.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(test_directory))
	var upgrades: Node = root.get_node_or_null("PlayerUpgrades")
	if upgrades == null:
		upgrades = PlayerUpgradeData.new()
		upgrades.name = "PlayerUpgrades"
		upgrades.save_path = ""
		root.add_child(upgrades)
	upgrades.save_path = ""
	upgrades.load_selection()
	_check(upgrades.max_speed_kmh == 65.0 and upgrades.acceleration_kmh_per_second == 35.0, "Race tests use isolated STOCK stats")
	game = MainScene.instantiate()
	game.best_time_path = test_path
	root.add_child(game)
	current_scene = game
	await _frames(2)
	_check(game.race.state == RaceController.State.READY, "Initial state is READY")
	_check(game.primary_button.has_focus(), "Start button has keyboard focus")
	_check(game.race.best_ms == 0, "Missing best-time file is harmless")
	_check(RaceController.format_time(65432) == "01:05.432", "Time format is MM:SS.mmm")
	await _capture("ready")
	var showcase_position: Vector3 = game.player.global_position
	_key(KEY_W, true)
	await _frames(30)
	_check(game.player.global_position == showcase_position and game.player.speed == 0.0, "Showcase player remains still in READY")
	await _tap(KEY_ENTER)
	_check(game.race.state == RaceController.State.COUNTDOWN and game.race.countdown_text() == "3", "Enter starts the countdown at 3")
	var spawn: Vector3 = game.player.spawn_transform.origin
	await _capture("countdown")
	await _frames(60)
	_check(game.race.countdown_text() == "2", "Countdown displays 2")
	await _tap(KEY_ESCAPE)
	var countdown: float = game.race.countdown_remaining
	await _frames(45)
	_check(paused and game.race.countdown_remaining == countdown, "Escape freezes the countdown")
	_check(game.primary_button.has_focus() and game.primary_button.text == "Resume", "Pause menu is keyboard focused")
	await _tap(KEY_ENTER)
	_check(not paused, "Keyboard pause-menu button resumes")
	await _frames(60)
	_check(game.race.countdown_text() == "1", "Countdown displays 1")
	_check(game.player.global_position == spawn and game.race.elapsed_seconds == 0.0, "Before Los there is neither movement nor race time")
	for frame_index in range(65):
		if game.race.state == RaceController.State.RACING:
			break
		await _frames(1)
	_check(game.race.state == RaceController.State.RACING and game.race.elapsed_seconds == 0.0, "Clock and vehicle unlock together at Los")
	_check(game.race.countdown_text() == "Los!", "Release displays Los")
	await _frames(20)
	_key(KEY_W, false)
	_check(game.race.elapsed_seconds > 0.0 and game.player.speed > 0.0, "Clock and driving advance during RACING")
	await _capture("racing")
	_cross(game.race.finish)
	_check(game.race.state == RaceController.State.RACING, "Initial finish crossing cannot finish the race")
	_check(not FileAccess.file_exists(test_path), "Incomplete attempts do not save a best time")
	_cross(game.race.checkpoints[1])
	_check(game.race.checkpoint_count == 0, "Skipped first checkpoint is rejected")
	var other := Node3D.new()
	_cross(game.race.checkpoints[0], false, other)
	other.free()
	_check(game.race.checkpoint_count == 0, "Only the player can trigger checkpoints")
	_cross(game.race.checkpoints[0], true)
	_check(game.race.checkpoint_count == 0, "Wrong-way checkpoint crossing is rejected")
	_cross(game.race.checkpoints[0])
	_check(game.race.checkpoint_count == 1, "First checkpoint is accepted")
	_cross(game.race.checkpoints[0])
	_check(game.race.checkpoint_count == 1, "Duplicate crossing gives no additional progress")
	_cross(game.race.checkpoints[2])
	_check(game.race.checkpoint_count == 1, "Later checkpoint cannot skip the next required checkpoint")
	await _tap(KEY_ESCAPE)
	var paused_time: float = game.race.elapsed_seconds
	var paused_position: Vector3 = game.player.global_position
	_cross(game.race.checkpoints[1])
	await _tap(KEY_R)
	await _frames(45)
	_check(game.race.elapsed_seconds == paused_time and game.player.global_position == paused_position, "Pause freezes race time and player, including R")
	_check(game.race.checkpoint_count == 1, "Pause freezes checkpoint progress")
	await _capture("paused")
	await _tap(KEY_ESCAPE)
	await _frames(3)
	_check(not paused and game.race.elapsed_seconds > paused_time, "Escape resumes the original attempt")
	var before_reset: float = game.race.elapsed_seconds
	await _tap(KEY_R)
	_check(_at_recovery(), "R restores the last valid checkpoint with ground contact")
	_check(game.player.global_basis.is_equal_approx(game.player.recovery_transform.basis), "Checkpoint recovery faces the correct direction")
	_check(game.race.checkpoint_count == 1 and game.race.elapsed_seconds >= before_reset, "R neither gains progress nor rewinds the clock")
	await _tap(KEY_R)
	_check(game.race.checkpoint_count == 1, "Repeated R does not collect checkpoints")
	game.player.global_position.y = -9.0
	await _frames(2)
	_check(_at_recovery() and game.race.checkpoint_count == 1, "Fall recovery also preserves progress")
	for checkpoint_index in range(1, 6):
		_cross(game.race.checkpoints[checkpoint_index])
		_check(game.race.checkpoint_count == checkpoint_index + 1, "Ordered checkpoint %d accepted" % (checkpoint_index + 1))
	_cross(game.race.finish, true)
	_check(game.race.state == RaceController.State.RACING, "Wrong-way finish is rejected even after all checkpoints")
	var outside: Transform3D = game.race.finish
	outside.origin.x += 8.0
	_cross(outside)
	_check(game.race.state == RaceController.State.RACING, "Crossing outside the track width does not finish")
	game.race.elapsed_seconds = 65.432
	_cross(game.race.finish)
	_check(game.race.state == RaceController.State.FINISHED and game.race.result_ms == 65432, "Valid forward finish records the result")
	_check(game.race.new_record and game.race.best_ms == 65432 and not game.race.save_failed, "First valid finish saves a new record")
	_check(game.primary_button.has_focus() and game.record_label.text == "New record!", "Result and record message are keyboard accessible")
	var result: float = game.race.elapsed_seconds
	await _frames(30)
	_cross(game.race.finish)
	_check(game.race.elapsed_seconds == result and game.player.speed == 0.0, "Finish freezes time and movement and ignores duplicate finishes")
	await _capture("result")
	var loader := RaceController.new()
	loader.save_path = test_path
	_check(loader._load_best() == 65432, "Saved best time loads in a fresh controller")
	await _tap(KEY_ENTER)
	_check(game.race.state == RaceController.State.COUNTDOWN and game.race.result_ms == 0, "Result restarts using Enter")
	for restart_index in range(3):
		game._start_game()
		_check(game.race.elapsed_seconds == 0.0 and game.race.checkpoint_count == 0 and game.player.global_transform.is_equal_approx(game.player.spawn_transform), "Restart %d clears time, progress and position" % (restart_index + 1))
		_check(game.player.speed == 0.0 and game.player.velocity == Vector3.ZERO and not game.race.new_record and game.record_label.text.is_empty(), "Restart %d clears velocity and result UI" % (restart_index + 1))
	_check(game.race.best_ms == 65432, "Repeated restarts preserve the best time")
	await _tap(KEY_ESCAPE)
	await _tap(KEY_DOWN)
	_check(game.restart_button.has_focus(), "Pause restart button is reachable with the keyboard")
	await _tap(KEY_ENTER)
	_check(not paused and game.race.state == RaceController.State.COUNTDOWN and game.race.elapsed_seconds == 0.0, "New attempt from pause unpauses and resets")
	await _begin()
	_finish_with_time(70.0)
	_check(not game.race.new_record and loader._load_best() == 65432, "Slower valid attempt does not overwrite the record")
	await _begin()
	_finish_with_time(60.0)
	_check(game.race.new_record and game.race.previous_best_ms == 65432 and loader._load_best() == 60000, "Faster attempt replaces the stored best time")
	for invalid in ["", "{broken", "[]", '{"version":2,"best_ms":100}', '{"version":1,"best_ms":-1}', '{"version":1,"best_ms":true}', '{"version":1,"best_ms":1.5}', '{"version":1,"best_ms":"fast"}']:
		var file := FileAccess.open(test_path, FileAccess.WRITE)
		file.store_string(invalid)
		file.close()
		_check(loader._load_best() == 0, "Invalid save safely ignored: " + invalid)
	await _begin()
	game.race.save_path = test_directory + "/missing/best.json"
	_finish_with_time(50.0)
	_check(game.race.state == RaceController.State.FINISHED and game.race.save_failed, "Unwritable save does not prevent a valid result")
	await _begin()
	_check(game.race.save_failed and game.race.save_pending, "Restart retains an unsaved record and failed status")
	_finish_with_time(55.0)
	_check(game.race.best_ms == 50000 and game.race.save_pending, "A slower finish retains the faster unsaved record")
	game.race.save_path = test_path
	await _begin()
	_check(not game.race.save_failed and not game.race.save_pending and loader._load_best() == 50000, "Restart retries the same record after storage recovers")
	game.race.save_path = test_directory + "/missing/best.json"
	_finish_with_time(45.0)
	await _begin()
	game.race.save_path = test_path
	_finish_with_time(48.0)
	_check(not game.race.new_record and not game.race.save_pending and loader._load_best() == 45000, "A slower finish also retries the faster pending record")
	loader.free()
	await _drive_complete_lap()
	paused = false
	game.queue_free()
	await process_frame
	for filename in [test_path, test_path + ".tmp"]:
		if FileAccess.file_exists(filename):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(filename))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_directory))
	print("RACE CHECKS: %d passed, %d failed (%s)" % [checks - failures.size(), failures.size(), DisplayServer.get_name()])
	quit(0 if failures.is_empty() else 1)