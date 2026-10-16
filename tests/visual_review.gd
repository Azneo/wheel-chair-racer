extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const OUTPUT: String = "res://docs/visual-review/"
const SAMPLE_COUNT: int = 240

var game: Node3D
var failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
	else:
		print("PASS: " + message)


func _collision_data(node: Node, entries: Array) -> void:
	if node is CollisionShape3D:
		var geometry: String = ""
		if node.shape is BoxShape3D:
			geometry = var_to_str(node.shape.size)
		elif node.shape is ConvexPolygonShape3D:
			geometry = var_to_str(node.shape.points)
		else:
			_check(false, "Unexpected collision shape in visual review")
		entries.append(var_to_str(node.global_transform) + geometry)
	for child in node.get_children():
		_collision_data(child, entries)


func _fingerprint() -> Dictionary:
	var colliders: Array = []
	_collision_data(game, colliders)
	var bindings: Array = []
	for action in ["accelerate", "brake", "steer_left", "steer_right", "reset"]:
		for event in InputMap.action_get_events(action):
			bindings.append(action + ":" + var_to_str(event))
	var controller: String = FileAccess.get_file_as_string("res://scripts/wheelchair.gd")
	return {
		"collider_count": colliders.size(),
		"collision_hash": JSON.stringify(colliders).sha256_text(),
		"input_hash": JSON.stringify(bindings).sha256_text(),
		"controller_hash": controller.get_slice("\nfunc _material", 0).sha256_text(),
	}


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_check(image.get_size() == Vector2i(1920, 1080), "Actual rendered image is 1920x1080")
	_check(not image.is_empty(), "Rendered image is nonempty")
	if not image.is_empty():
		var reference: Color = image.get_pixel(960, 540)
		var varied: int = 0
		for horizontal in range(20, image.get_width(), 80):
			for vertical in range(20, image.get_height(), 80):
				var pixel: Color = image.get_pixel(horizontal, vertical)
				if absf(pixel.r - reference.r) + absf(pixel.g - reference.g) + absf(pixel.b - reference.b) > 0.15:
					varied += 1
		_check(varied > 40, "Scene has varied rendered pixels")
		_check(image.save_png(path) == OK, "Screenshot: " + path)


func _measure() -> Dictionary:
	for warmup_frame in range(60):
		await RenderingServer.frame_post_draw
	var samples: Array[float] = []
	var started: int = Time.get_ticks_usec()
	var previous: int = started
	for sample_index in range(SAMPLE_COUNT):
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		samples.append(float(now - previous) / 1000.0)
		previous = now
	var elapsed_ms: float = float(previous - started) / 1000.0
	samples.sort()
	return {
		"frames": SAMPLE_COUNT,
		"mean_frame_ms": elapsed_ms / float(SAMPLE_COUNT),
		"mean_fps": float(SAMPLE_COUNT) * 1000.0 / elapsed_ms,
		"p95_frame_ms": samples[int(SAMPLE_COUNT * 0.95) - 1],
	}


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Visual review requires a real graphical display, not --headless.")
		quit(1)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--presentation-"):
			await _presentation_review(argument.trim_prefix("--presentation-"))
			return
	var stage: String = "race"
	var capture_only: bool = false
	for argument in OS.get_cmdline_user_args():
		if argument == "--before":
			stage = "before"
		elif argument == "--capture-only":
			capture_only = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	game = MainScene.instantiate()
	game.best_time_path = ""
	root.add_child(game)
	current_scene = game
	game._start_game()
	game.set_process(false)
	game.player.set_physics_process(false)
	game.race.set_physics_process(false)
	game.race_menu.hide()
	game.frontend_root.hide()
	game.follow_camera.make_current()
	game.speed_label.text = "00 km/h"
	var fingerprint: Dictionary = _fingerprint()
	if stage != "before":
		var baseline: Variant = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT + "before.json"))
		_check(baseline is Dictionary, "Before-review baseline exists")
		if baseline is Dictionary:
			for key in ["collider_count", "collision_hash", "input_hash"]:
				_check(fingerprint[key] == baseline["fingerprint"][key], "Unchanged: " + key)
		print("Controller fingerprint recorded; race gating and recovery are covered by smoke_test.gd and race_test.gd.")
	var report: Dictionary = {
		"stage": stage,
		"engine": Engine.get_version_info()["string"],
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"resolution": "1920x1080",
		"vsync": "disabled",
		"method": "Screenshots only; no performance measurement" if capture_only else "240 wall-clock inter-frame samples after 60 warmup frames per static view; not GPU timings or a gameplay benchmark",
		"fingerprint": fingerprint,
		"measurements": [],
	}
	var poses: Array[Dictionary] = [
		{"name": "start", "position": Vector3(12.0, 0.08, 16.0), "yaw": 0.0},
		{"name": "curve", "position": Vector3(8.485281, 0.08, -26.485281), "yaw": PI * 0.25},
	]
	for multisampling in [Viewport.MSAA_2X, Viewport.MSAA_4X]:
		root.msaa_3d = multisampling
		var label: String = "2x" if multisampling == Viewport.MSAA_2X else "4x"
		for pose in poses:
			game.player.global_position = pose["position"]
			game.player.rotation.y = pose["yaw"]
			game._reset_camera()
			var measurement: Dictionary = {}
			if capture_only:
				for warmup_frame in range(60):
					await RenderingServer.frame_post_draw
			else:
				measurement = await _measure()
			measurement["view"] = pose["name"]
			measurement["msaa"] = label
			measurement["camera_transform"] = var_to_str(game.follow_camera.global_transform)
			report["measurements"].append(measurement)
			if not capture_only:
				print("MEASURED " + stage + " " + pose["name"] + " " + label + ": " + JSON.stringify(measurement))
			await _capture(OUTPUT + stage + "-" + pose["name"] + "-" + label + ".png")
	var output := FileAccess.open(OUTPUT + stage + ".json", FileAccess.WRITE)
	_check(output != null, "Measurement report is writable")
	if output != null:
		output.store_string(JSON.stringify(report, "\t"))
		output.close()
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _presentation_review(stage: String) -> void:
	_check(stage in ["before", "after"], "Known presentation comparison stage")
	if failed:
		quit(1)
		return
	var directory: String = OUTPUT + "presentation/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.content_scale_size = Vector2i(1920, 1080)
	root.msaa_3d = Viewport.MSAA_2X
	game = MainScene.instantiate()
	game.best_time_path = ""
	root.add_child(game)
	current_scene = game
	game.upgrade_data.selected_engine_id = "rally"
	game._refresh_upgrade_ui()
	game._open_engine_upgrades()
	game.player._process(0.0)
	game.set_process(false)
	game.player.set_process(false)
	game.player.set_physics_process(false)
	game.race.set_physics_process(false)
	game.player.rotation.y = PI - 0.9
	var report: Dictionary = {
		"stage": stage,
		"engine": Engine.get_version_info()["string"],
		"adapter": RenderingServer.get_video_adapter_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"resolution": "1920x1080 native viewport, 2x MSAA",
		"method": "Standalone local Godot; VSync off; 60 warmup + 240 wall-clock frame intervals per static view; not GPU timing or driving benchmark",
		"views": [],
	}
	var comparison_camera := Camera3D.new()
	game.add_child(comparison_camera)
	comparison_camera.environment = game.garage_environment
	var views: Array[String] = ["workshop", "chair", "side", "front", "rear", "race"]
	for view in views:
		game.frontend_root.visible = view == "workshop"
		game.stats_overlay_root.visible = view == "workshop"
		if view == "workshop":
			game.upgrade_camera.make_current()
		elif view == "race":
			game._start_game()
			_check(game.sun_light.visible and not game.garage_dressing.visible, "Race restores outdoor lighting when started from the workshop")
			game.set_process(false)
			game.player.set_physics_process(false)
			game.race.set_physics_process(false)
			game.race_menu.hide()
			game.countdown_label.hide()
			game.follow_camera.make_current()
			game._reset_camera()
		else:
			var offset := Vector3(2.6, 1.15, -2.9)
			var target := Vector3(0.0, 0.8, -0.05)
			if view == "side":
				offset = Vector3(3.5, 1.25, 0.0)
				target.y = 1.05
			elif view == "front":
				offset = Vector3(0.0, 1.3, -3.7)
				target.y = 1.05
			elif view == "rear":
				offset = Vector3(0.0, 1.3, 3.7)
				target.y = 1.05
			comparison_camera.fov = 40.0
			comparison_camera.global_position = game.player.to_global(offset)
			comparison_camera.look_at(game.player.to_global(target))
			comparison_camera.make_current()
		var measurement: Dictionary = await _measure()
		measurement["view"] = view
		measurement["camera"] = var_to_str(root.get_camera_3d().global_transform)
		measurement["fov"] = root.get_camera_3d().fov
		report["views"].append(measurement)
		await _capture(directory + stage + "-" + view + ".png")
		print("PRESENTATION " + view + ": " + JSON.stringify(measurement))
	var output := FileAccess.open(directory + stage + ".json", FileAccess.WRITE)
	_check(output != null, "Presentation report is writable")
	if output != null:
		output.store_string(JSON.stringify(report, "\t"))
		output.close()
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)