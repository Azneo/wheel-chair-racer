extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const RaceController = preload("res://scripts/race.gd")
const PlayerUpgradeData = preload("res://scripts/player_upgrades.gd")

var game: Node3D
var upgrades: Node
var failures: Array[String] = []
var checks: int = 0
var test_save_path: String
var screenshot_path: String
var original_save_path: String
var keep_captures: bool = false
var capture_stages: Array[String] = []


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


func _is_connected_to(button: Button, method_name: String) -> bool:
	for connection in button.get_signal_connection_list("pressed"):
		var callback: Callable = connection["callable"]
		if callback.get_object() == game and callback.get_method() == method_name:
			return true
	return false


func _gameplay_hud_is_hidden() -> bool:
	for control in game.gameplay_hud_nodes:
		if control.visible:
			return false
	return true


func _hands_are_on_handrims(vehicle: Node3D) -> bool:
	if vehicle.arm_hand_nodes.size() != 2:
		return false
	for arm_index in range(vehicle.arm_hand_nodes.size()):
		var side: float = vehicle.arm_sides[arm_index]
		var hand_position: Vector3 = (
			vehicle.rider_upper_body.position + vehicle.arm_hand_nodes[arm_index].position
		)
		var radial_distance: float = Vector2(
			hand_position.y - 0.55,
			hand_position.z - 0.12
		).length()
		if absf(radial_distance - 0.415) > 0.03 or absf(hand_position.x - side * 0.685) > 0.03:
			return false
	return true


func _capture_screenshot(stage: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	capture_stages.append(stage)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_check(not image.is_empty() and image.get_width() >= 1280, "Rendered " + stage + " scene is visible")
	if not image.is_empty():
		_check(image.save_png(screenshot_path + "-" + stage + ".png") == OK, "Captured " + stage + " menu")


func _capture_driving_view(stage: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var previous_fov: float = game.follow_camera.fov
	var previous_camera_transform: Transform3D = game.follow_camera.global_transform
	var countdown_was_visible: bool = game.countdown_label.visible
	var main_was_processing: bool = game.is_processing()
	game.set_process(false)
	game.follow_camera.fov = 36.0
	game.follow_camera.global_position = (
		game.player.global_position + game.player.global_basis.x * 4.0 + Vector3.UP * 1.5
	)
	game.follow_camera.look_at(game.player.global_position + Vector3.UP * 1.08)
	game.countdown_label.hide()
	await _capture_screenshot(stage)
	game.countdown_label.visible = countdown_was_visible
	game.follow_camera.fov = previous_fov
	game.follow_camera.global_transform = previous_camera_transform
	game.set_process(main_was_processing)


func _run() -> void:
	keep_captures = OS.get_cmdline_user_args().has("--keep-captures")
	upgrades = root.get_node_or_null("PlayerUpgrades")
	if upgrades == null:
		upgrades = PlayerUpgradeData.new()
		upgrades.name = "PlayerUpgrades"
		root.add_child(upgrades)
	original_save_path = str(upgrades.get("save_path"))
	test_save_path = "user://upgrade-tests-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	screenshot_path = "user://upgrade-menu-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	upgrades.set("save_path", test_save_path)
	upgrades.call("load_selection")

	game = MainScene.instantiate()
	game.best_time_path = ""
	root.add_child(game)
	current_scene = game
	await _frames(2)
	await _capture_screenshot("main")
	_check(game.race.state == RaceController.State.READY, "Main menu opens in READY")
	_check(game.frontend_root.visible and game.frontend_page_name == "main", "Main menu is the initial screen")
	_check(game.stats_overlay_root.visible, "Current stats have a dedicated always-on-top menu display")
	_check(_gameplay_hud_is_hidden(), "Gameplay HUD is hidden in the Main Menu")
	_check(game.menu_camera.is_current(), "Menu has a dedicated showcase camera")
	_check(game.player.get_parent() == game.showcase_stage and not game.player.is_physics_processing(), "Showcase reuses a static, non-playable player")
	_check(game.engine_buttons.size() == 3, "Engine screen has exactly three engine choices")
	_check(game.stats_speed_label.text == "65 km/h" and game.stats_acceleration_label.text == "35 km/h/s", "Stock stats come from the upgrade data")
	_check(game.main_play_button.text == "PLAY" and game.main_upgrade_button.text == "UPGRADE" and game.main_exit_button.text == "EXIT", "Main menu presents PLAY, UPGRADE, and EXIT")
	_check(_is_connected_to(game.main_exit_button, "_quit_game"), "Main menu EXIT retains its quit action")
	_check(game.player.engine_mount.get_child_count() == 0, "Stock setup has no upgrade motor installed")

	game.main_upgrade_button.pressed.emit()
	_check(game.frontend_page_name == "upgrades", "UPGRADE opens category selection")
	_check(game.upgrade_camera.is_current() and game.garage_dressing.visible, "Upgrade screens switch to the garage showcase")
	_check(game.player.rotation.y != PI, "Garage camera presents the player at a three-quarter angle")
	var seat_mesh := game.player.seat_cushion.mesh as BoxMesh
	var seat_top: float = game.player.seat_cushion.position.y + seat_mesh.size.y * 0.5
	var pelvis_mesh := game.player.rider_pelvis.mesh as SphereMesh
	var pelvis_bottom: float = (
		game.player.rider_pelvis.position.y
		- pelvis_mesh.height * game.player.rider_pelvis.scale.y * 0.5
	)
	_check(absf(pelvis_bottom - seat_top) < 0.02, "Pelvis sits directly on the cushion")
	var thighs_clear_seat: bool = game.player.thigh_segments.size() == 2
	for thigh in game.player.thigh_segments:
		var thigh_mesh := thigh.mesh as CapsuleMesh
		thighs_clear_seat = thighs_clear_seat and thigh.position.y - thigh_mesh.radius > seat_top
	_check(thighs_clear_seat, "Thighs rest above the seat instead of clipping through it")
	var shins_angle_forward: bool = game.player.lower_leg_segments.size() == 2
	for leg_index in range(game.player.lower_leg_segments.size()):
		var shin: MeshInstance3D = game.player.lower_leg_segments[leg_index]
		var thigh: MeshInstance3D = game.player.thigh_segments[leg_index]
		shins_angle_forward = shins_angle_forward and shin.position.y < thigh.position.y and shin.position.z < thigh.position.z
	_check(shins_angle_forward, "Bent lower legs extend down and forward")
	_check(_hands_are_on_handrims(game.player), "Resting hands sit on the handrims")
	await _capture_screenshot("categories")
	game.player.rotation.y = 0.0
	await _frames(2)
	await _capture_screenshot("workshop-front")
	game.player.rotation.y = PI * 0.5
	await _frames(2)
	await _capture_screenshot("workshop-side")
	game.player.rotation.y = PI - 0.9
	game.wheel_category_button.pressed.emit()
	_check(game.frontend_page_name == "placeholder" and game.placeholder_title.text == "WHEEL" and game.placeholder_status_label.text == "COMING SOON", "WHEEL opens its placeholder")
	await _capture_screenshot("wheel-placeholder")
	game.placeholder_back_button.pressed.emit()
	game.aerodynamics_category_button.pressed.emit()
	_check(game.frontend_page_name == "placeholder" and game.placeholder_title.text == "AERODYNAMICS" and game.placeholder_status_label.text == "COMING SOON", "AERODYNAMICS opens its placeholder")
	await _capture_screenshot("aerodynamics-placeholder")
	game.placeholder_back_button.pressed.emit()
	game.engine_category_button.pressed.emit()
	_check(game.frontend_page_name == "engine", "ENGINE opens the engine choices")
	_check(_gameplay_hud_is_hidden(), "Gameplay HUD stays hidden in upgrade screens")
	_check(game.stats_speed_label.visible and game.stats_acceleration_label.visible, "Player stats remain visible in upgrade screens")
	await _frames(2)
	await _capture_screenshot("engine")

	var expected: Array[Dictionary] = [
		{"id": "comet", "visual_name": "CometEngine", "speed": 75, "acceleration": 35},
		{"id": "rally", "visual_name": "RallyEngine", "speed": 70, "acceleration": 45},
		{"id": "launch", "visual_name": "LaunchEngine", "speed": 65, "acceleration": 55},
	]
	var engine_part_counts: Array[int] = []
	for engine_index in range(expected.size()):
		var upgrade: Dictionary = expected[engine_index]
		game.engine_buttons[engine_index].pressed.emit()
		await _frames(26)
		_check(upgrades.get("selected_engine_id") == upgrade["id"], "Engine choice %d is selected" % (engine_index + 1))
		_check(roundi(float(upgrades.get("max_speed_kmh"))) == upgrade["speed"], "Engine choice %d updates max speed" % (engine_index + 1))
		_check(roundi(float(upgrades.get("acceleration_kmh_per_second"))) == upgrade["acceleration"], "Engine choice %d updates acceleration" % (engine_index + 1))
		_check(game.stats_speed_label.text == "%d km/h" % upgrade["speed"], "Engine choice %d refreshes the visible speed stat" % (engine_index + 1))
		_check(game.stats_acceleration_label.text == "%d km/h/s" % upgrade["acceleration"], "Engine choice %d refreshes the visible acceleration stat" % (engine_index + 1))
		_check(game.engine_buttons[engine_index].text.contains("EQUIPPED"), "Engine choice %d is visibly equipped" % (engine_index + 1))
		_check(game.player.installed_engine_id == upgrade["id"], "Engine choice %d installs its matching motor" % (engine_index + 1))
		_check(game.player.installed_engine.name == upgrade["visual_name"], "Engine choice %d uses a distinct model design" % (engine_index + 1))
		_check(game.player.installed_engine.get_parent() == game.player.engine_mount, "Engine choice %d is attached to the wheelchair" % (engine_index + 1))
		_check(game.player.engine_mount.get_child_count() == 1, "Only one engine model is mounted at a time")
		engine_part_counts.append(game.player.installed_engine.get_child_count())
		upgrades.call("load_selection")
		_check(upgrades.get("selected_engine_id") == upgrade["id"], "Engine choice %d persists to disk" % (engine_index + 1))
		_check(is_equal_approx(game.player.MAX_SPEED, float(upgrade["speed"]) / 3.6), "Engine choice %d reaches the player speed property" % (engine_index + 1))
		_check(is_equal_approx(game.player.ACCELERATION, float(upgrade["acceleration"]) / 3.6), "Engine choice %d reaches the player acceleration property" % (engine_index + 1))
		await _capture_screenshot("installed-" + str(upgrade["id"]))
	_check(
		engine_part_counts[0] != engine_part_counts[1]
		and engine_part_counts[1] != engine_part_counts[2]
		and engine_part_counts[0] != engine_part_counts[2],
		"Each engine uses a different mechanical assembly"
	)

	game.engine_back_button.pressed.emit()
	_check(upgrades.get("selected_engine_id") == "launch", "Engine selection survives navigation to categories")
	game.category_back_button.pressed.emit()
	_check(game.frontend_page_name == "main", "Category menu returns to the main menu")
	_check(game.main_engine_label.text == "INSTALLED ENGINE  LAUNCH", "Main menu shows the equipped engine")
	_check(game.stats_speed_label.text == "65 km/h" and game.stats_acceleration_label.text == "55 km/h/s", "Main menu shows the equipped engine stats")
	_check(game.menu_camera.is_current() and not game.garage_dressing.visible, "Returning to the Main Menu restores its presentation")
	_check(game.player.installed_engine_id == "launch" and game.player.engine_mount.get_child_count() == 1, "Installed engine remains on the wheelchair after navigation")

	game.main_play_button.pressed.emit()
	_check(game.race.state == RaceController.State.COUNTDOWN, "PLAY starts the existing race countdown")
	_check(game.player.get_parent() == game and game.follow_camera.is_current(), "PLAY returns the same player to gameplay and switches cameras")
	_check(is_equal_approx(game.player.MAX_SPEED, 65.0 / 3.6) and is_equal_approx(game.player.ACCELERATION, 55.0 / 3.6), "Gameplay receives the selected engine stats")
	await _frames(182)
	_check(game.race.state == RaceController.State.RACING, "Upgraded player becomes controllable when the countdown ends")
	var resting_hands: Array[Vector3] = []
	for hand in game.player.arm_hand_nodes:
		resting_hands.append(game.player.rider_upper_body.position + hand.position)
	Input.action_press("accelerate")
	await _frames(30)
	Input.action_release("accelerate")
	_check(game.player.speed > 7.4, "Upgraded acceleration affects actual vehicle movement")
	_check(game.player.drive_pose_weight > 0.9, "Driving smoothly blends the rider into the push pose")
	_check(absf(game.player.wheel_roll_angle) > 0.5, "Driving rotates both wheelchair wheels")
	var hands_moved: bool = false
	for arm_index in range(game.player.arm_hand_nodes.size()):
		var hand_position: Vector3 = (
			game.player.rider_upper_body.position + game.player.arm_hand_nodes[arm_index].position
		)
		hands_moved = hands_moved or hand_position.distance_to(resting_hands[arm_index]) > 0.04
	_check(hands_moved, "Arms stroke with the rotating wheels")
	var push_contact_seen: bool = false
	for frame_index in range(120):
		if _hands_are_on_handrims(game.player):
			push_contact_seen = true
			break
		await _frames(1)
	_check(push_contact_seen, "Hands return to the handrim during the synchronized push phase")
	await _capture_driving_view("driving-push")
	var heading_before_steering: float = game.player.rotation.y
	Input.action_press("accelerate")
	Input.action_press("steer_left")
	await _frames(20)
	Input.action_release("steer_left")
	Input.action_release("accelerate")
	_check(not is_equal_approx(game.player.rotation.y, heading_before_steering), "Wheelchair steering remains active while pushing")
	Input.action_press("brake")
	var stopped_with_brake: bool = false
	for frame_index in range(60):
		await _frames(1)
		if game.player.speed == 0.0:
			stopped_with_brake = true
			break
	Input.action_release("brake")
	_check(stopped_with_brake, "Braking brings the wheelchair to a stop before reverse")
	await _frames(15)
	_check(game.player.speed == 0.0, "Releasing brake keeps the wheelchair stopped")
	_check(game.player.drive_pose_weight < 0.02, "Rider smoothly returns to the resting pose when stopped")
	var wheel_roll_before_reverse: float = game.player.wheel_roll_angle
	Input.action_press("brake")
	await _frames(30)
	Input.action_release("brake")
	_check(game.player.speed < -0.5, "Holding brake from rest drives the wheelchair backward")
	_check(game.player.wheel_roll_angle > wheel_roll_before_reverse, "Reverse movement rotates the wheels backward")
	_check(game.player.drive_pose_weight > 0.9, "The rider animates during reverse propulsion")
	await _capture_driving_view("driving-reverse")
	await _frames(105)
	_check(game.player.speed > -0.1 and game.player.speed < 0.1, "Rolling resistance stops reverse movement")
	_check(game.player.drive_pose_weight < 0.02, "Rider returns to rest after reverse movement stops")
	_check(game.player.installed_engine_id == "launch", "Engine remains attached throughout driving animation")
	game._return_to_main_menu()
	_check(game.race.state == RaceController.State.READY and game.frontend_page_name == "main", "Gameplay can return to the main menu")
	_check(upgrades.get("selected_engine_id") == "launch", "Selected engine remains active after gameplay navigation")

	game.queue_free()
	await process_frame
	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save_path))
	if keep_captures:
		print("UPGRADE SCREENSHOTS: " + screenshot_path)
	else:
		for stage in ["main", "engine"] + capture_stages:
			var image_path: String = screenshot_path + "-" + stage + ".png"
			if FileAccess.file_exists(image_path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(image_path))
	upgrades.set("save_path", original_save_path)
	upgrades.call("load_selection")
	if failures.is_empty():
		print("UPGRADE CHECKS: %d passed (%s)" % [checks, DisplayServer.get_name()])
	else:
		print("UPGRADE CHECKS: %d passed, %d failed (%s)" % [checks - failures.size(), failures.size(), DisplayServer.get_name()])
	quit(0 if failures.is_empty() else 1)
