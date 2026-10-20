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


class ReplaceFailureUpgrade extends PlayerUpgradeData:
	var fail_replace: bool = false

	func _replace_selection_file(temporary_path: String) -> Error:
		if fail_replace:
			return ERR_FILE_CANT_WRITE
		return super._replace_selection_file(temporary_path)


func _check_save_recovery() -> void:
	var storage := ReplaceFailureUpgrade.new()
	storage.save_path = test_save_path + ".recovery"
	_check(storage.select_engine("comet"), "Initial upgrade save succeeds")
	var original: String = FileAccess.get_file_as_string(storage.save_path)
	storage.fail_replace = true
	_check(not storage.select_engine("rally") and storage.save_pending, "Failed replacement retains a pending selection")
	_check(FileAccess.get_file_as_string(storage.save_path) == original, "Failed replacement preserves the previous valid save")
	_check(not FileAccess.file_exists(storage.save_path + ".tmp"), "Failed replacement cleans its temporary file")
	_check(not storage.select_engine("rally") and not storage.persistence_error.is_empty(), "Repeated failure does not claim success or clear the error")
	storage.fail_replace = false
	_check(storage.select_engine("rally") and not storage.save_pending and storage.persistence_error.is_empty(), "Identical selection retries and clears the error after success")
	storage.load_selection()
	_check(storage.selected_engine_id == "rally", "Recovered selection survives reload")
	var valid_path: String = storage.save_path
	storage.save_path = valid_path + ".missing/selection.json"
	_check(not storage.select_engine("launch") and storage.save_pending, "Real file-open failure keeps the latest selection pending")
	storage.save_path = valid_path
	_check(storage.select_engine("launch") and storage.persistence_error.is_empty(), "Same selection recovers after a real file-open failure")
	storage.load_selection()
	_check(storage.selected_engine_id == "launch", "File-open recovery replaces the previous valid selection")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(storage.save_path))
	storage.free()


func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--bake-seating"):
		_bake_seating.call_deferred()
	elif OS.get_cmdline_user_args().has("--runtime-profile"):
		_profile_runtime.call_deferred()
	elif OS.get_cmdline_user_args().has("--pose-profile"):
		_profile_pose.call_deferred()
	elif OS.get_cmdline_user_args().has("--seating-only"):
		_run_seating.call_deferred()
	else:
		_run.call_deferred()


func _bake_seating() -> void:
	var visual := preload("res://scripts/racer_visuals.gd").new()
	visual.seating = visual.seating.duplicate()
	visual.seating.baked_pose_path = ""
	root.add_child(visual)
	var result: Error = visual.save_baked_pose("res://assets/wheelchair/seating_pose.tres")
	print("SEATING BAKE: ", error_string(result))
	visual.free()
	quit(0 if result == OK else 1)


func _profile_runtime() -> void:
	upgrades = root.get_node("PlayerUpgrades")
	var saved_path: String = upgrades.save_path
	upgrades.save_path = ""
	upgrades.select_engine("")
	var started: int = Time.get_ticks_usec()
	game = MainScene.instantiate()
	game.best_time_path = ""
	root.add_child(game)
	print("CONFIGURATION BUILD ms=", float(Time.get_ticks_usec() - started) / 1000.0)
	game.main_play_button.pressed.emit()
	await _frames(182)
	for mode in ["idle", "manual", "motor", "switching"]:
		upgrades.select_engine("launch" if mode == "motor" else "")
		await _frames(30)
		game.player.reset_to_start()
		if mode != "idle":
			Input.action_press("accelerate")
			Input.action_press("steer_right")
		var samples: Array[float] = []
		for frame in range(180):
			if mode == "switching" and frame % 30 == 0:
				upgrades.select_engine("launch" if frame % 60 == 0 else "")
			var before: int = Time.get_ticks_usec()
			await process_frame
			if frame >= 60:
				samples.append(float(Time.get_ticks_usec() - before) / 1000.0)
		Input.action_release("accelerate")
		Input.action_release("steer_right")
		samples.sort()
		print("RENDER FRAME ", mode, " median_ms=", samples[60], " p95_ms=", samples[114], " max_ms=", samples[119])
	game.free()
	upgrades.save_path = saved_path
	upgrades.load_selection()
	quit()


func _profile_pose() -> void:
	var visual := preload("res://scripts/racer_visuals.gd").new()
	root.add_child(visual)
	for name in ["Spine", "Spine01", "Spine02", "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand"]:
		var bone: int = visual.bone_ids[name]
		print("RIG ", name, " parent=", visual.skeleton.get_bone_name(visual.skeleton.get_bone_parent(bone)))
	for mode in ["idle", "manual", "motor", "switching"]:
		var samples: Array[float] = []
		for frame in range(120):
			visual.update_wheels(18.0 / 60.0 if mode != "idle" else 0.0, 0.25)
			var started: int = Time.get_ticks_usec()
			visual.update_pose(1.0 / 60.0, mode != "idle", true, mode == "motor" or (mode == "switching" and frame % 60 < 30))
			samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
		samples.sort()
		print("POSE TIMING ", mode, " median_ms=", samples[60], " p95_ms=", samples[114], " max_ms=", samples[119])
		print("POSE BONES ", mode, " shoulder=", visual.bone_position("LeftArm"), " elbow=", visual.bone_position("LeftForeArm"), " wrist=", visual.bone_position("LeftHand"))
	visual.free()
	quit()


func _run_seating() -> void:
	var visual := preload("res://scripts/racer_visuals.gd").new()
	root.add_child(visual)
	_check_seating_fit(visual)
	_check_animation_playback(visual)
	_check_hand_geometry(visual, visual.rider_mesh)
	_check_seating_variants(visual)
	visual.free()
	print("SEATING CHECKS: %d passed, %d failed" % [checks - failures.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)


func _check_animation_playback(visual: Node3D) -> void:
	var query_count: int = visual.pose_skin_queries
	visual.update_pose(0.5, false, false, false)
	var minimum: Vector3 = visual.bone_position("LeftHand")
	var maximum: Vector3 = minimum
	var anatomical: bool = true
	var coordinated: bool = true
	for frame in range(120):
		visual.update_wheels(18.0 / 60.0, 0.3)
		visual.update_pose(1.0 / 60.0, true, true, false)
		var left: Vector3 = visual.bone_position("LeftHand")
		var right: Vector3 = visual.bone_position("RightHand")
		minimum = minimum.min(left)
		maximum = maximum.max(left)
		coordinated = coordinated and absf(left.z - right.z) < 0.025
		for index in range(2):
			var prefix: String = "Left" if index == 0 else "Right"
			var side: float = -1.0 if index == 0 else 1.0
			var elbow: Vector3 = visual.seat_frame.affine_inverse() * visual.bone_position(prefix + "ForeArm")
			var shoulder: Vector3 = visual.seat_frame.affine_inverse() * visual.bone_position(prefix + "Arm")
			anatomical = anatomical and side * elbow.x >= side * shoulder.x - 0.005 and elbow.y < shoulder.y
	_check(maximum.z - minimum.z > 0.14, "Manual propulsion produces visible hand travel at racing speed")
	_check(coordinated, "Manual hands remain coordinated throughout the stroke")
	_check(anatomical, "Propulsion elbows stay outside the torso and below shoulders")
	visual.update_pose(0.5, true, false, false)
	var idle: Vector3 = visual.bone_position("LeftHand")
	visual.update_wheels(3.0, 0.4)
	visual.update_pose(0.2, true, false, false)
	_check(idle.distance_to(visual.bone_position("LeftHand")) < 0.002, "Coasting wheels do not drive the hand stroke")
	visual.update_pose(0.5, true, true, true)
	var motor: Vector3 = visual.bone_position("LeftHand")
	for frame in range(60):
		visual.update_wheels(18.0 / 60.0, -0.3)
		visual.update_pose(1.0 / 60.0, true, true, true)
	_check(motor.distance_to(visual.bone_position("LeftHand")) < 0.002 and visual.push_weight == 0.0, "Motor driving retains its supported pose without propulsion")
	_check(visual.pose_skin_queries == query_count, "Runtime animation performs no CPU skin queries or fitting")
	visual.update_pose(0.5, false, false, false)


func _check_seating_fit(visual: Node3D) -> void:
	print("SEATING FIT pelvis=", visual.seat_anchor.position, " error=", visual.fit_error, " conflicts=", visual.fit_conflicts)
	_check(visual.fit_conflicts.is_empty(), "Seating constraints are jointly feasible")
	_check(visual.fit_error < 0.005, "Pelvis support remains on the seat")
	_check(visual.leg_intersections() == 0, "All skinned leg vertices clear seat and frame")
	var bones: PackedInt32Array = visual.skin_arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = visual.skin_arrays[Mesh.ARRAY_WEIGHTS]
	var influences: int = bones.size() / visual.skin_arrays[Mesh.ARRAY_VERTEX].size()
	var excludes_distal: bool = true
	for vertex in visual.body_groups["seat"]:
		var strongest: int = vertex * influences
		for influence in range(1, influences):
			var offset: int = vertex * influences + influence
			if weights[offset] > weights[strongest]:
				strongest = offset
		var bone_name: String = visual.skeleton.get_bone_name(visual.skin_bones[bones[strongest]])
		excludes_distal = excludes_distal and (bone_name == "Hips" or bone_name.ends_with("UpLeg"))
	_check(excludes_distal, "Shin and foot vertices never drive pelvis support fitting")
	var pelvis: Vector3 = visual.seat_anchor.position
	for motorized in [false, true, false, true]:
		visual.update_pose(0.5, true, true, motorized)
		_check(visual.seat_anchor.position == pelvis and absf(visual._lowest_seated_skin() - visual.seating.clearance) < 0.005, "Motor changes preserve pelvis support")
		_check(visual.reach_failures.is_empty(), "Motor changes preserve anatomical reach: " + str(visual.reach_failures))
		_check(_body_clear(visual), "Motor changes preserve body clearance")
		for index in range(2):
			var prefix: String = "Left" if index == 0 else "Right"
			_check(visual.bone_position(prefix + "Foot").distance_to(visual.foot_anchors[index].position) < 0.002, prefix + " foot stays on its support")
			var points: PackedVector3Array = visual.body_points(prefix + "Foot")
			var bounds := AABB(points[0], Vector3.ZERO)
			for point in points:
				bounds = bounds.expand(point)
			var support: Vector3 = visual.seating.foot_supports[index]
			var size: Vector2 = visual.foot_sizes[index]
			_check(absf(bounds.position.y - support.y) < 0.005 and bounds.position.x >= support.x - size.x * 0.5 and bounds.end.x <= support.x + size.x * 0.5 and bounds.position.z >= support.z - size.y * 0.5 and bounds.end.z <= support.z + size.y * 0.5, prefix + " sole fits the footplate surface")
			if motorized:
				var wrist: Vector3 = visual.seat_frame.affine_inverse() * visual.bone_position(prefix + "Hand")
				var elbow: Vector3 = visual.seat_frame.affine_inverse() * visual.bone_position(prefix + "ForeArm")
				_check(wrist.z < elbow.z, prefix + " motor forearm points forward instead of folding backward")
				var bottom: float = INF
				for point in visual.body_points(prefix + "Hand"):
					var armrest: AABB = visual.seating.armrests[index]
					if point.x >= armrest.position.x and point.x <= armrest.end.x and point.z >= armrest.position.z and point.z <= armrest.end.z:
						bottom = minf(bottom, point.y)
				_check(absf(bottom - visual.seating.armrests[index].end.y - visual.seating.clearance) < 0.003, prefix + " relaxed hand rests above the armrest footprint")


func _body_clear(visual: Node3D) -> bool:
	var seat_box := AABB(Vector3(-visual.usable_size.x * 0.5, -visual.seating.seat_thickness, -visual.usable_size.y * 0.5), Vector3(visual.usable_size.x, visual.seating.seat_thickness, visual.usable_size.y))
	var solids: Array[AABB] = visual.seating.armrests.duplicate()
	solids.append_array(visual.seating.frame_solids)
	solids.append(seat_box)
	if visual.seating.back.has_volume():
		solids.append(visual.seating.back)
	for point in visual.body_points("body"):
		for solid in solids:
			if solid.grow(-0.005).has_point(point):
				print("BODY INTERSECTION point=", point, " solid=", solid, " blend=", visual.manual_pose_weight)
				return false
	return true


func _check_seating_variants(original: Node3D) -> void:
	var invalid: Resource = original.seating.duplicate()
	var missing_mounts: Array[Vector3] = []
	invalid.foot_mounts = missing_mounts
	_check(not invalid.validate(), "Generated footplates require two attachment mounts")
	invalid = original.seating.duplicate()
	invalid.seat = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 2.0), Vector3.ZERO)
	_check(not invalid.validate(), "Seat metadata rejects scaled support frames")
	var variant := preload("res://scripts/racer_visuals.gd").new()
	variant.seating = original.seating.duplicate()
	var transform := Transform3D(Basis(Vector3.UP, 0.6), Vector3(1.0, 0.3, -2.0))
	variant.seating.model_transform = transform * variant.seating.model_transform
	variant.seating.seat = transform * variant.seating.seat
	root.add_child(variant)
	_check(variant.fit_conflicts.is_empty(), "Rotated and translated chair configuration fits without solver offsets")
	_check((variant.seat_frame.affine_inverse() * variant.seat_anchor.position).distance_to(original.seat_frame.affine_inverse() * original.seat_anchor.position) < 0.003, "Seat fitting is invariant under model placement")
	var supported_pelvis: Vector3 = variant.seat_anchor.position
	for anchor in variant.foot_anchors:
		anchor.position -= variant.seat_frame.basis.y * 2.0
	variant.fit_seating()
	_check(not variant.fit_conflicts.is_empty() and ";".join(variant.fit_conflicts).contains("Foot"), "Impossible foot targets report an explicit reach conflict")
	_check(absf((variant.seat_frame.affine_inverse() * variant.seat_anchor.position).y - (variant.seat_frame.affine_inverse() * supported_pelvis).y) < 0.005, "Unreachable shins cannot lift the supported pelvis")
	variant.free()


func _frames(count: int) -> void:
	for frame_index in range(count):
		await physics_frame
	await process_frame


func _tap(keycode: int) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(2)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func _drag_showcase(relative: Vector2) -> void:
	var position: Vector2 = game.orbit_surface.get_global_rect().get_center()
	var button := InputEventMouseButton.new()
	button.position = position
	button.global_position = position
	button.button_index = MOUSE_BUTTON_LEFT
	button.button_mask = MOUSE_BUTTON_MASK_LEFT
	button.pressed = true
	root.push_input(button, true)
	var motion := InputEventMouseMotion.new()
	motion.position = position + relative
	motion.global_position = motion.position
	motion.relative = relative
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	button = InputEventMouseButton.new()
	button.position = motion.position
	button.global_position = motion.position
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = false
	root.push_input(button, true)
	await _frames(2)


func _check_orbit_controls(label: String) -> void:
	var player_transform: Transform3D = game.player.global_transform
	var follow_transform: Transform3D = game.follow_camera.global_transform
	var yaw: float = game.showcase_yaw
	await _drag_showcase(Vector2(120.0, -30.0))
	_check(not is_equal_approx(game.showcase_yaw, yaw) and not game.orbit_dragging, label + " mouse drag rotates the camera and releases cleanly")
	_check(game.player.global_transform.is_equal_approx(player_transform) and game.follow_camera.global_transform.is_equal_approx(follow_transform), label + " orbit does not rotate the vehicle or gameplay camera")
	game.orbit_front_button.grab_focus()
	await _tap(KEY_ENTER)
	var camera_position: Vector3 = game.player.to_local(game.upgrade_camera.global_position)
	_check(is_zero_approx(game.showcase_yaw) and camera_position.z < -4.0, label + " FRONT key activation faces the rider")
	await _capture_screenshot(label + "-orbit-front")
	game.orbit_right_button.grab_focus()
	await _tap(KEY_ENTER)
	await _tap(KEY_ENTER)
	camera_position = game.player.to_local(game.upgrade_camera.global_position)
	_check(camera_position.x > 4.0 and absf(camera_position.z) < 0.01, label + " rotation buttons reach the side")
	await _capture_screenshot(label + "-orbit-side")
	await _tap(KEY_ENTER)
	await _tap(KEY_ENTER)
	_check(game.player.to_local(game.upgrade_camera.global_position).z > 4.0, label + " rotation buttons reach the rear")
	await _capture_screenshot(label + "-orbit-rear")
	game.orbit_left_button.grab_focus()
	await _tap(KEY_ENTER)
	_check(not is_equal_approx(absf(game.showcase_yaw), PI), label + " left rotation button reverses the view")
	game._orbit_showcase(0.0, 10.0)
	_check(is_equal_approx(game.showcase_pitch, 0.45), label + " elevation is clamped above")
	game._orbit_showcase(0.0, -10.0)
	_check(is_equal_approx(game.showcase_pitch, 0.08), label + " elevation stays above the floor")
	game.orbit_front_button.grab_focus()
	await _tap(KEY_ENTER)
	_check(root.get_visible_rect().encloses(game.orbit_right_button.get_global_rect()), label + " camera buttons fit in the viewport")


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



func _hands_reach_targets(vehicle: Node3D) -> bool:
	for side_index in range(2):
		var prefix: String = "Left" if side_index == 0 else "Right"
		var hand_position: Vector3 = vehicle.visuals.bone_position(prefix + "Hand")
		if hand_position.distance_to(vehicle.visuals.hand_anchors[side_index].position) > 0.045:
			print("FIT REACH ", prefix, " wrist=", hand_position, " target=", vehicle.visuals.hand_anchors[side_index].position, " shoulder=", vehicle.visuals.bone_position(prefix + "Arm"), " pelvis=", vehicle.visuals.seat_anchor.position)
			return false
	return true


func _hands_clear_of_wheels(visual: Node3D, mesh: MeshInstance3D, arrays: Array, hand_vertices: Array[int], bind_bones: Array[int]) -> bool:
	var palette: Array[Transform3D] = []
	for bind in range(bind_bones.size()):
		palette.append(visual.skeleton.get_bone_global_pose(bind_bones[bind]) * mesh.skin.get_bind_pose(bind))
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var influences: int = bones.size() / vertices.size()
	for vertex in hand_vertices:
		var skinned := Vector3.ZERO
		for influence in range(influences):
			var offset: int = vertex * influences + influence
			skinned += (palette[bones[offset]] * vertices[vertex]) * weights[offset]
		var world: Vector3 = visual.skeleton.to_global(skinned)
		var point: Vector3 = visual.to_local(world)
		if minf(point.distance_to(visual.bone_position("LeftHand")), point.distance_to(visual.bone_position("RightHand"))) > 0.4:
			print("Invalid hand skin transform: ", point)
			return false
		for wheel in visual.rear_wheels:
			var wheel_point: Vector3 = wheel.to_local(world)
			var bounds: AABB = wheel.get_aabb()
			if wheel_point.x >= bounds.position.x - 0.004 and wheel_point.x <= bounds.end.x + 0.004 and Vector2(wheel_point.y, wheel_point.z).length() < 0.342:
				print("Hand vertex inside rear-wheel clearance envelope: ", point, " blend=", visual.manual_pose_weight, " phase=", visual.rear_angle)
				return false
	return true


func _check_hand_geometry(visual: Node3D, mesh: MeshInstance3D) -> void:
	var arrays: Array = mesh.mesh.surface_get_arrays(0)
	var bind_bones: Array[int] = []
	for bind in range(mesh.skin.get_bind_count()):
		var bone: int = mesh.skin.get_bind_bone(bind)
		if bone < 0:
			bone = visual.skeleton.find_bone(mesh.skin.get_bind_name(bind))
		bind_bones.append(bone)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var influences: int = bones.size() / vertices.size()
	var hand_vertices: Array[int] = []
	for vertex in range(vertices.size()):
		var hand_weight: float = 0.0
		for influence in range(influences):
			var offset: int = vertex * influences + influence
			if visual.skeleton.get_bone_name(bind_bones[bones[offset]]).contains("Hand"):
				hand_weight += weights[offset]
		if hand_weight > 0.5:
			hand_vertices.append(vertex)
	_check(hand_vertices.size() > 100, "Clearance regression includes skinned palm and finger vertices")
	var transitions: Array[Dictionary] = [
		{"motorized": true, "moving": false, "steps": 12},
		{"motorized": false, "moving": false, "steps": 12},
		{"motorized": true, "moving": true, "steps": 12},
		{"motorized": false, "moving": true, "steps": 12},
		{"motorized": true, "moving": true, "steps": 3},
		{"motorized": false, "moving": true, "steps": 12},
	]
	for transition in transitions:
		var clear: bool = true
		var smooth: bool = true
		for step in range(transition["steps"]):
			var previous: Vector3 = visual.bone_position("LeftHand")
			var previous_elbow: Vector3 = visual.bone_position("LeftForeArm")
			var previous_right_hand: Vector3 = visual.bone_position("RightHand")
			var previous_right_elbow: Vector3 = visual.bone_position("RightForeArm")
			if transition["moving"]:
				visual.update_wheels(0.1, 0.0)
			visual.update_pose(1.0 / 30.0, transition["moving"], transition["moving"], transition["motorized"])
			var wrist_step: float = previous.distance_to(visual.bone_position("LeftHand"))
			var elbow_step: float = previous_elbow.distance_to(visual.bone_position("LeftForeArm"))
			var right_elbow_step: float = previous_right_elbow.distance_to(visual.bone_position("RightForeArm"))
			if right_elbow_step >= 0.12:
				print("RIGHT TRANSITION step=", step, " blend=", visual.manual_pose_weight, " elbow_delta=", right_elbow_step)
			if wrist_step >= 0.12 or elbow_step >= 0.12 or not visual.reach_failures.is_empty() or visual.constraint_failures > 0:
				print("TRANSITION step=", step, " blend=", visual.manual_pose_weight, " wrist_delta=", wrist_step, " elbow_delta=", elbow_step, " reach=", visual.reach_failures, " blocked=", visual.constraint_failures)
			smooth = smooth and previous.distance_to(visual.bone_position("LeftHand")) < 0.12
			smooth = smooth and previous_elbow.distance_to(visual.bone_position("LeftForeArm")) < 0.12
			smooth = smooth and previous_right_hand.distance_to(visual.bone_position("RightHand")) < 0.12
			smooth = smooth and previous_right_elbow.distance_to(visual.bone_position("RightForeArm")) < 0.12
			clear = _hands_clear_of_wheels(visual, mesh, arrays, hand_vertices, bind_bones) and clear
			clear = _body_clear(visual) and visual.reach_failures.is_empty() and visual.constraint_failures == 0 and clear
		_check(clear and smooth, "Motor transition keeps skinned hands clear without snapping: " + str(transition))
	for direction in [-1.0, 1.0]:
		var clear: bool = true
		for step in range(16):
			visual.rear_angle = direction * TAU * float(step) / 16.0
			visual.propulsion_phase = direction * TAU * float(step) / 16.0
			visual.push_weight = 1.0
			visual.manual_pose_weight = 1.0
			visual.update_pose(0.0, true, true, false)
			if not visual.reach_failures.is_empty():
				print("STROKE REACH ", visual.reach_failures, " phase=", visual.propulsion_phase)
			clear = _hands_clear_of_wheels(visual, mesh, arrays, hand_vertices, bind_bones) and clear
			clear = _body_clear(visual) and visual.reach_failures.is_empty() and visual.constraint_failures == 0 and clear
		_check(clear, "Full manual stroke keeps skinned fingers clear in direction " + str(direction))
	visual.reset_wheels()
	visual.update_pose(0.5, false, false, false)
	_check(_hands_clear_of_wheels(visual, mesh, arrays, hand_vertices, bind_bones), "Stock resting and coasting hands remain outside the wheels")


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

	_check_save_recovery()
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
	var visual: Node3D = game.player.visuals
	_check(visual.skeleton.get_bone_count() == 54, "Imported rider retains the 54-bone skinned rig")
	var rider_mesh: MeshInstance3D = visual.rider.find_child("char1", true, false)
	_check_seating_fit(visual)
	_check_animation_playback(visual)
	_check_seating_variants(visual)
	_check(visual.fit_error < 0.005, "Posed pelvis and thigh skin is fitted to the seat surface")
	for motorized in [false, true]:
		visual.update_pose(0.5, false, false, motorized)
		var collisions: Dictionary = {"seat": 0, "back": 0, "armrests": 0}
		for point in visual.body_points("body"):
			if absf(point.x) < visual.usable_size.x * 0.5 and absf(point.z) < visual.usable_size.y * 0.5 and point.y < -0.005 and point.y > -visual.seating.seat_thickness:
				collisions["seat"] += 1
			if visual.seating.back.grow(-0.005).has_point(point):
				collisions["back"] += 1
			for support in visual.seating.armrests:
				if support.grow(-0.005).has_point(point):
					collisions["armrests"] += 1
		_check(collisions["seat"] == 0 and collisions["back"] == 0 and collisions["armrests"] == 0, "Body clears seat, back and armrests: " + str(motorized) + " " + str(collisions))
		_check(visual.constraint_failures == 0, "Chair has a feasible bounded elbow pose: " + str(motorized))
		for side_index in range(2):
			var prefix: String = "Left" if side_index == 0 else "Right"
			var gap: float = INF
			for point in visual.body_points(prefix + "Hand"):
				if motorized:
					var support: AABB = visual.seating.armrests[side_index]
					if point.x > support.position.x and point.x < support.end.x and point.z > support.position.z and point.z < support.end.z:
						gap = minf(gap, point.y - support.end.y)
				else:
					var relative: Vector3 = point - visual.wheel_contacts[side_index]
					gap = minf(gap, Vector2(relative.x, Vector2(relative.y, relative.z).length() - visual.seating.handrim_radius).length())
			print("SUPPORT GAP motor=", motorized, " side=", prefix, " gap=", gap, " wrist=", visual.bone_position(prefix + "Hand"), " elbow=", visual.bone_position(prefix + "ForeArm"))
	visual.update_pose(0.5, false, false, false)
	_check(rider_mesh.mesh.surface_get_array_index_len(0) / 3 == 244257, "Runtime rider preserves the verified source topology")
	_check(visual.bone_position("Hips").distance_to(visual.seat_anchor.position) < 0.002, "Pelvis bone is aligned to the authored seated target")
	for side_index in range(2):
		var prefix: String = "Left" if side_index == 0 else "Right"
		var hip: Vector3 = visual.bone_position(prefix + "UpLeg")
		var knee: Vector3 = visual.bone_position(prefix + "Leg")
		var ankle: Vector3 = visual.bone_position(prefix + "Foot")
		_check(knee.z < hip.z - 0.30 and absf(knee.y - hip.y) < 0.15, prefix + " thigh follows a seated pose")
		_check(ankle.y < knee.y - 0.3 and ankle.distance_to(visual.foot_anchors[side_index].position) < 0.02, prefix + " ankle reaches the foot-support target")
	_check(_hands_reach_targets(game.player), "Actual wrist bones reach the resting hand targets")
	var wheel_origin: Vector3 = visual.rear_wheels[0].position
	visual.reset_wheels()
	visual.update_wheels(0.10, 0.4)
	_check(visual.rear_wheels[0].rotation.x > 0.1 and visual.front_wheels[0].rotation.x > 0.1, "Both wheel sizes rotate about their local axle")
	_check(visual.rear_wheels[0].position == wheel_origin, "Rotation does not translate the wheel pivot")
	_check(visual.front_forks[0].has_node("ForkLeft") and visual.front_forks[1].has_node("ForkRight"), "Visible caster forks share their wheels' steering parents")
	_check(is_equal_approx(visual.front_forks[0].rotation.y, 0.14) and is_zero_approx(visual.front_forks[0].get_node("ForkLeft").rotation.x), "Caster forks steer without spinning around the wheel axle")
	visual.update_wheels(-0.10, 0.0)
	_check(absf(visual.rear_angle) < 0.001 and absf(visual.caster_angle) < 0.001, "Reverse distance exactly reverses wheel rotation")
	visual.idle_enabled = false
	visual.update_pose(0.5, false, false, false)
	var still_pose: Transform3D = visual.skeleton.get_bone_global_pose(visual.bone_ids["Spine"])
	visual.update_pose(0.5, false, false, false)
	_check(still_pose.is_equal_approx(visual.skeleton.get_bone_global_pose(visual.bone_ids["Spine"])), "Workshop idle can be disabled")
	_check_hand_geometry(visual, rider_mesh)
	visual.idle_enabled = true
	await _capture_screenshot("categories")
	_check(game.player.to_local(game.upgrade_camera.global_position).z < 0.0, "Workshop opens with the face side visible")
	await _check_orbit_controls("stock")
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
		var view_before: Transform3D = game.upgrade_camera.global_transform
		game.engine_buttons[engine_index].pressed.emit()
		await _frames(4)
		if engine_index == 0:
			await _capture_screenshot("motor-transition")
		await _frames(22)
		_check(game.upgrade_camera.global_transform.is_equal_approx(view_before), "Engine change preserves the chosen camera angle")
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

	await _check_orbit_controls("motor")
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
	var parked_camera: Transform3D = game.upgrade_camera.global_transform
	await _drag_showcase(Vector2(120.0, -30.0))
	game._orbit_showcase(1.0, 0.1)
	game._front_showcase()
	_check(not game.orbit_controls.visible and game.upgrade_camera.global_transform.is_equal_approx(parked_camera) and game.follow_camera.is_current(), "Gameplay ignores workshop orbit input and retains its follow camera")
	var resting_hand: Vector3 = visual.bone_position("LeftHand")
	Input.action_press("accelerate")
	await _frames(30)
	Input.action_release("accelerate")
	_check(game.player.speed > 7.4, "Upgraded acceleration affects actual vehicle movement")
	_check(game.player.drive_pose_weight < 0.01, "Motorized driving does not force a manual push animation")
	_check(absf(game.player.wheel_roll_angle) > 0.5, "Driving rotates both wheelchair wheels")
	_check(visual.bone_position("LeftHand").distance_to(resting_hand) < 0.01, "Motorized rider keeps a stable hand position")
	_check(_hands_reach_targets(game.player), "Motorized wrists remain on their support targets")
	await _capture_driving_view("driving-motorized")
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
	_check(game.player.drive_pose_weight < 0.01, "Motorized reverse keeps the supported seated pose")
	await _capture_driving_view("driving-reverse")
	await _frames(105)
	_check(game.player.speed > -0.1 and game.player.speed < 0.1, "Rolling resistance stops reverse movement")
	_check(game.player.drive_pose_weight < 0.02, "Rider returns to rest after reverse movement stops")
	_check(game.player.installed_engine_id == "launch", "Engine remains attached throughout driving animation")
	upgrades.call("select_engine", "")
	await _frames(26)
	game.player.reset_to_start()
	Input.action_press("accelerate")
	await _frames(30)
	_check(game.player.drive_pose_weight > 0.9, "Stock rider pushes while accelerating")
	await _capture_driving_view("driving-push")
	Input.action_release("accelerate")
	await _frames(20)
	_check(game.player.speed > 0.1 and game.player.drive_pose_weight < 0.01, "Coasting releases the push pose while wheels keep rolling")
	upgrades.call("select_engine", "launch")
	await _frames(26)
	game._return_to_main_menu()
	_check(game.race.state == RaceController.State.READY and game.frontend_page_name == "main", "Gameplay can return to the main menu")
	_check(upgrades.get("selected_engine_id") == "launch", "Selected engine remains active after gameplay navigation")

	_check(game.main_play_button.has_focus(), "Returning to the menu focuses PLAY")
	await _tap(KEY_TAB)
	_check(game.main_upgrade_button.has_focus(), "Tab reaches UPGRADE")
	await _tap(KEY_ENTER)
	_check(game.frontend_page_name == "upgrades" and game.engine_category_button.has_focus(), "Enter opens the keyboard-focused category menu")
	await _tap(KEY_ENTER)
	_check(game.frontend_page_name == "engine" and game.engine_buttons[0].has_focus(), "Enter opens the keyboard-focused engine menu")
	await _tap(KEY_ENTER)
	await _frames(26)
	_check(upgrades.selected_engine_id == "comet", "Keyboard activation selects an engine card")
	for step in range(3):
		await _tap(KEY_TAB)
	_check(game.stock_button.has_focus(), "Tab reaches STOCK after the three engine choices")
	var stock_view: Transform3D = game.upgrade_camera.global_transform
	await _tap(KEY_ENTER)
	await _capture_screenshot("stock-transition")
	await _frames(26)
	_check(game.upgrade_camera.global_transform.is_equal_approx(stock_view), "Removing the motor preserves the camera view")
	_check(upgrades.selected_engine_id == "" and game.player.engine_mount.get_child_count() == 0, "Keyboard STOCK action removes the mounted motor")
	_check(game.stats_speed_label.text == "65 km/h" and game.stats_acceleration_label.text == "35 km/h/s", "STOCK restores the displayed base stats")
	_check(game.stock_button.text == "STOCK / EQUIPPED" and game.upgrade_message_label.text == "STOCK EQUIPPED", "STOCK selection has visible feedback")
	var reloaded := PlayerUpgradeData.new()
	reloaded.save_path = test_save_path
	reloaded.load_selection()
	_check(reloaded.selected_engine_id == "" and reloaded.max_speed_kmh == 65.0 and reloaded.acceleration_kmh_per_second == 35.0, "STOCK persists in a fresh upgrade instance")
	reloaded.free()
	var viewport_bounds: Rect2 = root.get_visible_rect()
	_check(viewport_bounds.encloses(game.stock_button.get_global_rect()) and viewport_bounds.encloses(game.engine_back_button.get_global_rect()), "STOCK and BACK fit within the viewport")
	await _capture_screenshot("stock-keyboard")
	await _tap(KEY_TAB)
	await _tap(KEY_ENTER)
	_check(game.frontend_page_name == "upgrades", "Keyboard BACK returns to categories")

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
