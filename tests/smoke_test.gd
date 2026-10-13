extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

var game: Node3D
var failures: Array[String] = []
var visual: bool = false


func _initialize() -> void:
	visual = DisplayServer.get_name() != "headless"
	_run.call_deferred()


func _frames(count: int) -> void:
	for frame_index in range(count):
		await physics_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures.append(description)
		push_error("FAIL: " + description)


func _key(keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)


func _release_keys() -> void:
	for keycode in [KEY_W, KEY_S, KEY_A, KEY_D, KEY_R]:
		_key(keycode, false)


func _capture(filename: String) -> void:
	if not visual:
		return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_check(not image.is_empty(), "Rendered viewport is not empty: " + filename)
	if image.is_empty():
		return
	var reference: Color = image.get_pixel(image.get_width() / 2, image.get_height() / 2)
	var changed_pixels: int = 0
	for horizontal in range(10, image.get_width(), 40):
		for vertical in range(10, image.get_height(), 40):
			var pixel: Color = image.get_pixel(horizontal, vertical)
			if absf(pixel.r - reference.r) + absf(pixel.g - reference.g) + absf(pixel.b - reference.b) > 0.1:
				changed_pixels += 1
	_check(changed_pixels > 30, "Rendered viewport contains varied pixels: " + filename)
	var path: String = "user://" + filename
	_check(image.save_png(path) == OK, "Screenshot saved: " + ProjectSettings.globalize_path(path))


func _run() -> void:
	_check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/main.tscn", "Main scene configured")
	_check(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "gl_compatibility", "Compatibility renderer preserved")
	var bindings := {"accelerate": KEY_W, "brake": KEY_S, "steer_left": KEY_A, "steer_right": KEY_D, "reset": KEY_R}
	for action in bindings:
		var mapped: bool = false
		for event in InputMap.action_get_events(action):
			if event is InputEventKey and event.physical_keycode == bindings[action]:
				mapped = true
		_check(mapped, "Physical key mapping: " + action)

	game = MainScene.instantiate()
	game.best_time_path = ""
	root.add_child(game)
	current_scene = game
	game.race.start_attempt()
	await _frames(182)
	game.race.set_physics_process(false)
	await _frames(12)
	var player: CharacterBody3D = game.player
	_check(player.is_on_floor(), "CharacterBody3D settles on solid ground")
	_check(game.track_points[0].distance_to(game.track_points[-1]) < 0.01, "Track loop is closed")
	_check(player.rear_wheels.size() == 2 and player.front_forks.size() == 2, "Two rear wheels and two casters exist")
	_check(game.follow_camera.is_current(), "Third-person camera is active")
	var blocked_sections: int = 0
	for section in range(game.track_points.size() - 1):
		var start_point: Vector3 = game.track_points[section]
		var finish_point: Vector3 = game.track_points[section + 1]
		var direction: Vector3 = (finish_point - start_point).normalized()
		var right := Vector3(-direction.z, 0.0, direction.x)
		for lane in [-2.0, 0.0, 2.0]:
			var probe := Transform3D(Basis.looking_at(direction), start_point + right * float(lane) + Vector3.UP * 0.08)
			if player.test_move(probe, finish_point - start_point):
				blocked_sections += 1
	_check(blocked_sections == 0, "Complete circuit has three unobstructed vehicle-width driving lines")
	await _capture("prototype-start.png")

	var start: Vector3 = player.global_position
	_key(KEY_W, true)
	await _frames(160)
	_check(player.speed > 17.0 and player.speed <= player.MAX_SPEED, "W accelerates to capped maximum speed")
	_check(player.global_position.z < start.z - 15.0, "Acceleration moves the vehicle forward")
	_key(KEY_W, false)
	_key(KEY_S, true)
	await _frames(60)
	_check(player.speed < 0.01, "S brakes to a full stop")
	await _frames(15)
	_check(player.speed >= 0.0, "Braking does not reverse")
	_release_keys()

	player.reset_to_start()
	_key(KEY_W, true)
	await _frames(60)
	_key(KEY_W, false)
	var powered_speed: float = player.speed
	await _frames(30)
	_check(player.speed > 0.0 and player.speed < powered_speed, "Releasing W causes rolling deceleration")

	player.reset_to_start()
	_key(KEY_W, true)
	_key(KEY_A, true)
	await _frames(45)
	_check(player.rotation.y > 0.3, "A steers left while moving")
	_check(player.global_position.x < player.spawn_transform.origin.x - 0.3, "Left steering changes travel direction")
	await _capture("prototype-turn.png")
	_release_keys()
	player.reset_to_start()
	_key(KEY_W, true)
	_key(KEY_D, true)
	await _frames(45)
	_check(player.rotation.y < -0.3, "D steers right while moving")
	_release_keys()

	player.reset_to_start()
	_key(KEY_W, true)
	_key(KEY_S, true)
	await _frames(30)
	_check(player.speed == 0.0, "Braking takes priority over acceleration")
	_release_keys()

	player.reset_to_start()
	player.global_position = Vector3(12.0, 0.08, 0.0)
	player.rotation.y = -PI * 0.5
	_key(KEY_W, true)
	await _frames(120)
	_check(player.global_position.x < 16.0, "Outer straight barrier blocks the vehicle")
	_check(player.get_slide_collision_count() > 0 and player.speed < 1.0, "Wall collision removes blocked forward speed")
	_release_keys()

	player.reset_to_start()
	player.global_position = Vector3(0.0, 0.08, -30.0)
	_key(KEY_W, true)
	await _frames(120)
	_check(player.global_position.z > -34.1 and player.speed < 1.0, "Outer curve barrier blocks the vehicle")
	_release_keys()

	player.reset_to_start()
	player.global_position = Vector3(0.0, 0.08, -30.0)
	player.rotation.y = PI
	_key(KEY_W, true)
	await _frames(120)
	_check(player.global_position.z < -26.0 and player.speed < 1.0, "Inner curve barrier blocks the vehicle")
	_release_keys()

	_key(KEY_R, true)
	await _frames(2)
	_key(KEY_R, false)
	_check(player.global_position.distance_to(player.spawn_transform.origin) < 0.2, "R restores spawn position")
	_check(player.velocity.length() < 1.0 and player.speed == 0.0 and absf(player.rotation.y) < 0.01, "R clears speed and heading")
	var camera_target: Vector3 = player.global_position + player.global_basis.z * 7.5 + Vector3.UP * 4.5
	_check(game.follow_camera.global_position.distance_to(camera_target) < 0.2, "R immediately resets follow camera")
	player.global_position.y = -9.0
	await _frames(2)
	_check(player.global_position.distance_to(player.spawn_transform.origin) < 0.2, "Falling out of the world resets the vehicle")

	_release_keys()
	if failures.is_empty():
		print("ALL PROTOTYPE CHECKS PASSED (" + ("graphical" if visual else "headless") + ")")
	else:
		print("FAILED CHECKS: " + str(failures.size()))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)