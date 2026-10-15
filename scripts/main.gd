extends Node3D

const WheelchairController = preload("res://scripts/wheelchair.gd")
const RaceController = preload("res://scripts/race.gd")
const PlayerUpgradeData = preload("res://scripts/player_upgrades.gd")
const TRACK_RADIUS: float = 12.0
const HALF_STRAIGHT: float = 18.0
const TRACK_WIDTH: float = 9.0
const PARK_GREEN := Color("4f6948")
const TRACK_CHARCOAL := Color("303b40")
const WARM_WHITE := Color("d9dfd5")
const RACE_CORAL := Color("b95343")
const PARK_TEAL := Color("205654")

var player: CharacterBody3D
var follow_camera: Camera3D
var menu_camera: Camera3D
var upgrade_camera: Camera3D
var speed_label: Label
var track_points: PackedVector3Array = PackedVector3Array()
var park_decoration: Node3D
var showcase_stage: Node3D
var garage_dressing: Node3D
var garage_key_light: OmniLight3D
var garage_rim_light: OmniLight3D
var garage_environment: Environment
var sun_light: DirectionalLight3D
var showcase_pedestal: MeshInstance3D
var showcase_ring: MeshInstance3D
var frontend_shade: ColorRect
var garage_mode: bool = false
var race: Node
var upgrade_data: Node
@export var best_time_path: String = "user://best_time_v1.json"
var hud_root: Control
var frontend_root: Control
var stats_overlay_root: Control
var main_page: Control
var upgrade_page: Control
var engine_page: Control
var placeholder_page: Control
var frontend_title: Label
var frontend_subtitle: Label
var main_engine_label: Label
var placeholder_title: Label
var placeholder_status_label: Label
var stats_speed_label: Label
var stats_acceleration_label: Label
var stats_engine_label: Label
var upgrade_message_label: Label
var engine_buttons: Array[Button] = []
var engine_category_button: Button
var wheel_category_button: Button
var aerodynamics_category_button: Button
var main_play_button: Button
var main_upgrade_button: Button
var main_exit_button: Button
var category_back_button: Button
var engine_back_button: Button
var placeholder_back_button: Button
var gameplay_hud_nodes: Array[Control] = []
var frontend_page_name: String = "main"
var time_label: Label
var progress_label: Label
var countdown_label: Label
var race_menu: Control
var menu_title: Label
var menu_details: Label
var record_label: Label
var play_button: Button
var primary_button: Button
var restart_button: Button
var return_button: Button
var exit_button: Button


func _ready() -> void:
	upgrade_data = get_tree().root.get_node_or_null("PlayerUpgrades")
	if upgrade_data == null:
		upgrade_data = PlayerUpgradeData.new()
		upgrade_data.name = "PlayerUpgrades"
		get_tree().root.add_child(upgrade_data)
	_build_lighting()
	park_decoration = Node3D.new()
	park_decoration.name = "ParkDecoration"
	add_child(park_decoration)
	_build_track()
	_build_park()
	player = WheelchairController.new()
	player.name = "Wheelchair"
	player.position = Vector3(TRACK_RADIUS, 0.08, 16.0)
	add_child(player)
	follow_camera = Camera3D.new()
	follow_camera.name = "FollowCamera"
	follow_camera.fov = 68.0
	follow_camera.near = 0.1
	follow_camera.far = 250.0
	add_child(follow_camera)
	follow_camera.make_current()
	player.respawned.connect(_reset_camera)
	_reset_camera()
	_build_hud()
	race = RaceController.new()
	race.name = "Race"
	add_child(race)
	race.configure(player, track_points, TRACK_WIDTH, best_time_path)
	_build_frontend_presentation()
	_build_race_hud()
	_build_frontend_menu()
	upgrade_data.connect("stats_changed", _refresh_upgrade_ui)
	_refresh_upgrade_ui()
	race.updated.connect(_update_race_hud)
	race.state_changed.connect(_show_race_menu)
	_show_race_menu()


func _process(delta: float) -> void:
	if is_instance_valid(frontend_root) and frontend_root.visible:
		player.rotate_y(delta * 0.12)
		return
	var desired_position: Vector3 = player.global_position + player.global_basis.z * 7.5 + Vector3.UP * 4.5
	follow_camera.global_position = follow_camera.global_position.lerp(desired_position, 1.0 - exp(-7.0 * delta))
	follow_camera.look_at(player.global_position + Vector3.UP * 1.1 - player.global_basis.z * 1.5)
	speed_label.text = "%02d km/h" % roundi(player.speed * 3.6)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and race.state == RaceController.State.READY and frontend_page_name != "main":
		_set_frontend_page("main")
		get_viewport().set_input_as_handled()


func _reset_camera() -> void:
	follow_camera.global_position = player.global_position + player.global_basis.z * 7.5 + Vector3.UP * 4.5
	follow_camera.look_at(player.global_position + Vector3.UP * 1.1 - player.global_basis.z * 1.5)


func _material(color: Color, roughness: float = 0.9, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _ground_material(color: Color, scale: float, variation: float) -> StandardMaterial3D:
	var material := _material(color, 0.98)
	var noise := FastNoiseLite.new()
	noise.seed = 27
	noise.frequency = 0.065
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1.0 - variation, 1.0 - variation, 1.0 - variation), Color.WHITE])
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.generate_mipmaps = true
	texture.noise = noise
	texture.color_ramp = gradient
	material.albedo_texture = texture
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * scale
	return material


func _box(size: Vector3, location: Vector3, material: Material, solid: bool = false) -> Node3D:
	var body: Node3D = StaticBody3D.new() if solid else Node3D.new()
	body.position = location
	add_child(body)
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	body.add_child(instance)
	if solid:
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		body.add_child(collider)
	return body


func _detail_box(size: Vector3, location: Vector3, material: Material) -> Node3D:
	var detail: Node3D = _box(size, location, material)
	detail.reparent(park_decoration)
	return detail


func _detail_mesh(mesh: Mesh, location: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = location
	instance.scale = size
	instance.material_override = material
	park_decoration.add_child(instance)
	return instance


func _park_label(text: String, location: Vector3, pixel_size: float = 0.006) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = pixel_size
	label.modulate = WARM_WHITE
	label.outline_size = 0
	label.no_depth_test = false
	label.position = location
	park_decoration.add_child(label)
	return label


func _build_park() -> void:
	var leaf := _material(Color("476b50"))
	var light_leaf := _material(Color("547254"))
	var bark := _material(Color("635346"))
	var stone := _material(Color("a4b0a5"), 0.95)
	var teal := _material(PARK_TEAL, 0.55)
	var coral := _material(RACE_CORAL, 0.82)
	var trim := _material(WARM_WHITE, 0.5, 0.15)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.16
	trunk.bottom_radius = 0.26
	trunk.height = 3.5
	trunk.radial_segments = 8
	var crown := SphereMesh.new()
	crown.radius = 1.0
	crown.height = 2.0
	crown.radial_segments = 9
	crown.rings = 5
	var tree_positions: Array[Vector3] = [
		Vector3(25.0, 0.0, 15.0), Vector3(26.0, 0.0, -1.0),
		Vector3(25.0, 0.0, -18.0), Vector3(18.0, 0.0, -39.0),
		Vector3(3.0, 0.0, -43.0), Vector3(-14.0, 0.0, -40.0),
		Vector3(-24.0, 0.0, -28.0), Vector3(-1.0, 0.0, 6.0),
		Vector3(-1.5, 0.0, -14.0),
	]
	for tree_index in range(tree_positions.size()):
		var location: Vector3 = tree_positions[tree_index]
		var height_scale: float = 0.9 + float(tree_index % 3) * 0.12
		_detail_mesh(trunk, location + Vector3.UP * 1.75 * height_scale, Vector3(1.0, height_scale, 1.0), bark)
		_detail_mesh(crown, location + Vector3(0.0, 4.1, 0.0) * height_scale, Vector3(2.1, 2.35, 1.9) * height_scale, leaf)
		_detail_mesh(crown, location + Vector3(-1.1, 3.7, 0.3) * height_scale, Vector3(1.6, 1.45, 1.5) * height_scale, light_leaf)
		_detail_mesh(crown, location + Vector3(1.0, 4.5, -0.3) * height_scale, Vector3(1.35, 1.6, 1.4) * height_scale, leaf)
	for location in [Vector3(20.0, 0.0, 6.0), Vector3(21.5, 0.0, -10.0), Vector3(12.0, 0.0, -40.0), Vector3(-8.0, 0.0, -40.0), Vector3(1.0, 0.0, -18.0)]:
		for cluster_index in range(3):
			_detail_mesh(crown, location + Vector3(float(cluster_index) * 1.0, 0.55, 0.0), Vector3(0.8, 0.65, 0.75), leaf if cluster_index % 2 == 0 else light_leaf)
	_detail_box(Vector3(3.0, 0.015, 51.0), Vector3(23.0, 0.008, -3.0), stone)
	for crossing_index in range(17):
		_detail_box(Vector3(2.95, 0.006, 0.025), Vector3(23.0, 0.02, -27.0 + float(crossing_index) * 3.0), teal)
	for bench_z in [8.0, -10.0]:
		for slat_index in range(3):
			_detail_box(Vector3(0.18, 0.10, 2.2), Vector3(26.4 + float(slat_index) * 0.22, 0.55, bench_z), bark)
		_detail_box(Vector3(0.12, 0.5, 2.2), Vector3(27.0, 0.95, bench_z), bark)
		for leg_z in [-0.8, 0.8]:
			_detail_box(Vector3(0.6, 0.5, 0.10), Vector3(26.6, 0.25, bench_z + leg_z), teal)
	for banner_position in [Vector3(19.8, 0.0, 8.0), Vector3(19.8, 0.0, -8.0), Vector3(8.0, 0.0, -38.0)]:
		_detail_box(Vector3(0.09, 3.7, 0.09), banner_position + Vector3.UP * 1.85, trim)
		_detail_box(Vector3(1.25, 2.0, 0.055), banner_position + Vector3(0.62, 2.65, 0.0), teal)
		_detail_box(Vector3(1.25, 0.12, 0.06), banner_position + Vector3(0.62, 1.71, 0.0), coral)
		_park_label("PARK\nCIRCUIT", banner_position + Vector3(0.62, 2.7, 0.04), 0.0032)
	_detail_box(Vector3(0.12, 2.8, 0.12), Vector3(21.0, 1.4, -22.5), teal)
	_detail_box(Vector3(3.3, 0.65, 0.12), Vector3(21.0, 2.6, -22.5), teal)
	_park_label("<  PARKRUNDE", Vector3(21.0, 2.6, -22.42), 0.0045)
	_detail_box(Vector3(2.3, 0.5, 0.12), Vector3(21.0, 1.9, -22.5), stone)
	var promenade_label: Label3D = _park_label("PROMENADE  >", Vector3(21.0, 1.9, -22.42), 0.003)
	promenade_label.modulate = PARK_TEAL
	for chevron_index in range(3):
		var angle: float = -PI * (0.25 + float(chevron_index) * 0.18)
		var location := Vector3(cos(angle) * 19.5, 1.65, -HALF_STRAIGHT + sin(angle) * 19.5)
		var sign_board: Node3D = _detail_box(Vector3(1.6, 0.9, 0.12), location, teal)
		sign_board.rotation.y = -angle - PI * 0.5
		var sign_label: Label3D = _park_label("<<", location + sign_board.basis.z * 0.075, 0.008)
		sign_label.rotation.y = sign_board.rotation.y
		_detail_box(Vector3(0.10, 1.25, 0.10), location - Vector3.UP * 1.0, trim)
	var skyline := _material(Color("82999b"))
	skyline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var windows := _material(Color("728d94"))
	windows.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for building_index in range(7):
		var height: float = 3.5 + float(building_index % 3) * 1.5
		var width: float = 5.0 + float(building_index % 2) * 3.0
		var horizontal: float = -42.0 + float(building_index) * 13.0
		var building: Node3D = _detail_box(Vector3(width, height, 4.0), Vector3(horizontal, height * 0.5, -73.0), skyline)
		var instance := building.get_child(0) as MeshInstance3D
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for floor_index in range(1, int(height / 1.3)):
			var window_band: Node3D = _detail_box(Vector3(width - 0.7, 0.35, 0.02), Vector3(horizontal, float(floor_index) * 1.3, -70.98), windows)
			var window_mesh := window_band.get_child(0) as MeshInstance3D
			window_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _barrier(start: Vector3, finish: Vector3, side: float, material: Material) -> void:
	var start_normal := Vector3(start.x, 0.0, start.z - clampf(start.z, -HALF_STRAIGHT, HALF_STRAIGHT)).normalized()
	var finish_normal := Vector3(finish.x, 0.0, finish.z - clampf(finish.z, -HALF_STRAIGHT, HALF_STRAIGHT)).normalized()
	var inner_offset: float = side * TRACK_WIDTH * 0.5
	var outer_offset: float = side * (TRACK_WIDTH * 0.5 + 0.32)
	var corners := PackedVector3Array([
		start + start_normal * inner_offset,
		finish + finish_normal * inner_offset,
		finish + finish_normal * outer_offset,
		start + start_normal * outer_offset,
	])
	for corner_index in range(4):
		corners.append(corners[corner_index] + Vector3.UP * 0.9)
	var center: Vector3 = (corners[0] + corners[1] + corners[2] + corners[3]) * 0.25 + Vector3.UP * 0.45
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in [[0, 1, 2, 3], [4, 7, 6, 5], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]]:
		var first: Vector3 = corners[face[0]]
		var second: Vector3 = corners[face[1]]
		var third: Vector3 = corners[face[2]]
		var normal: Vector3 = (second - first).cross(third - first).normalized()
		var outward: bool = normal.dot((first + second + third) / 3.0 - center) > 0.0
		surface.set_normal(normal if outward else -normal)
		var triangle_order: Array = [0, 2, 1, 0, 3, 2] if outward else [0, 1, 2, 0, 2, 3]
		for vertex_index in triangle_order:
			surface.add_vertex(corners[face[vertex_index]])
	var body := StaticBody3D.new()
	body.name = "Barrier"
	add_child(body)
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = material
	body.add_child(instance)
	var collision := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = corners
	collision.shape = shape
	body.add_child(collision)


func _build_lighting() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("559ac5")
	sky_material.sky_horizon_color = Color("bfdae5")
	sky_material.ground_bottom_color = Color("667c69")
	sky_material.ground_horizon_color = Color("b7cfc9")
	sky_material.sky_energy_multiplier = 1.0
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("ccd9df")
	environment.ambient_light_energy = 0.3
	environment_node.environment = environment
	add_child(environment_node)
	sun_light = DirectionalLight3D.new()
	sun_light.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	sun_light.light_color = Color("fff4df")
	sun_light.light_energy = 0.8
	sun_light.shadow_enabled = true
	sun_light.directional_shadow_max_distance = 75.0
	add_child(sun_light)


func _build_track() -> void:
	var grass := _ground_material(PARK_GREEN, 0.065, 0.12)
	var asphalt := _ground_material(TRACK_CHARCOAL, 1.8, 0.24)
	var white := _material(WARM_WHITE, 0.72)
	var red := _material(RACE_CORAL, 0.72)
	var teal := _material(PARK_TEAL, 0.45, 0.15)
	var dark := _material(Color("253236"), 0.4, 0.55)
	_box(Vector3(160.0, 0.4, 160.0), Vector3(0.0, -0.2, 0.0), grass, true).name = "Ground"
	track_points.append(Vector3(TRACK_RADIUS, 0.0, HALF_STRAIGHT))
	for segment in range(1, 13):
		track_points.append(Vector3(TRACK_RADIUS, 0.0, lerpf(HALF_STRAIGHT, -HALF_STRAIGHT, float(segment) / 12.0)))
	for segment in range(1, 33):
		var angle: float = -PI * float(segment) / 32.0
		track_points.append(Vector3(cos(angle) * TRACK_RADIUS, 0.0, -HALF_STRAIGHT + sin(angle) * TRACK_RADIUS))
	for segment in range(1, 13):
		track_points.append(Vector3(-TRACK_RADIUS, 0.0, lerpf(-HALF_STRAIGHT, HALF_STRAIGHT, float(segment) / 12.0)))
	for segment in range(1, 33):
		var angle: float = PI - PI * float(segment) / 32.0
		track_points.append(Vector3(cos(angle) * TRACK_RADIUS, 0.0, HALF_STRAIGHT + sin(angle) * TRACK_RADIUS))

	for segment in range(track_points.size() - 1):
		var start: Vector3 = track_points[segment]
		var finish: Vector3 = track_points[segment + 1]
		var midpoint: Vector3 = (start + finish) * 0.5
		var direction: Vector3 = (finish - start).normalized()
		var length: float = start.distance_to(finish)
		var road: Node3D = _box(Vector3(TRACK_WIDTH, 0.012, length + 0.6), midpoint + Vector3.UP * 0.006, asphalt)
		road.look_at(road.position + direction)
		for side in [-1.0, 1.0]:
			_barrier(start, finish, float(side), red if segment % 8 < 2 else white)
			var edge_normal := Vector3(-direction.z, 0.0, direction.x)
			var edge: Node3D = _detail_box(Vector3(0.10, 0.008, length + 0.03), midpoint + edge_normal * float(side) * 4.17 + Vector3.UP * 0.021, white)
			edge.look_at(edge.position + direction)
			var edge_mesh := edge.get_child(0) as MeshInstance3D
			edge_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if segment % 3 == 0:
			var dash: Node3D = _box(Vector3(0.12, 0.015, 0.8), midpoint + Vector3.UP * 0.02, white)
			dash.look_at(dash.position + direction)

	for column in range(8):
		for row in range(2):
			var location := Vector3(TRACK_RADIUS - TRACK_WIDTH * 0.5 + (float(column) + 0.5) * TRACK_WIDTH / 8.0, 0.025, 12.0 + float(row) * 0.5)
			_box(Vector3(TRACK_WIDTH / 8.0, 0.02, 0.5), location, white if (column + row) % 2 == 0 else dark)
	for side in [-1.0, 1.0]:
		_box(Vector3(0.3, 3.8, 0.3), Vector3(TRACK_RADIUS + float(side) * 5.1, 1.9, 12.0), dark, true)
		_detail_box(Vector3(0.32, 0.16, 0.32), Vector3(TRACK_RADIUS + float(side) * 5.1, 3.2, 12.0), red)
	_detail_box(Vector3(10.5, 0.55, 0.4), Vector3(TRACK_RADIUS, 3.8, 12.0), teal)
	_detail_box(Vector3(10.5, 0.055, 0.43), Vector3(TRACK_RADIUS, 4.1, 12.0), white)
	_detail_box(Vector3(4.0, 0.055, 0.43), Vector3(TRACK_RADIUS, 3.5, 12.0), red)
	_park_label("START / ZIEL", Vector3(TRACK_RADIUS, 3.8, 12.22), 0.005)
	for side in [-1.0, 1.0]:
		for column in range(3):
			for row in range(2):
				var tile_location := Vector3(TRACK_RADIUS + float(side) * 4.2 + float(column) * 0.16, 3.71 + float(row) * 0.16, 12.21)
				_detail_box(Vector3(0.16, 0.16, 0.02), tile_location, white if (column + row) % 2 == 0 else dark)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var root := Control.new()
	hud_root = root
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Bahnschrift", "sans-serif"])
	var theme := Theme.new()
	theme.default_font = font
	root.theme = theme
	var top_band := ColorRect.new()
	root.add_child(top_band)
	top_band.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_band.offset_bottom = 76.0
	top_band.color = Color(0.045, 0.095, 0.10, 0.94)
	top_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay_hud_nodes.append(top_band)
	var heading := Label.new()
	heading.text = "WHEELCHAIR RACER"
	heading.position = Vector2(28.0, 12.0)
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", WARM_WHITE)
	root.add_child(heading)
	gameplay_hud_nodes.append(heading)
	var subtitle := Label.new()
	subtitle.text = "TESTSTRECKE 01"
	subtitle.position = Vector2(29.0, 43.0)
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color("9dbdb5"))
	root.add_child(subtitle)
	gameplay_hud_nodes.append(subtitle)
	speed_label = Label.new()
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	speed_label.add_theme_font_size_override("font_size", 30)
	speed_label.add_theme_color_override("font_color", WARM_WHITE)
	root.add_child(speed_label)
	gameplay_hud_nodes.append(speed_label)
	speed_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	speed_label.offset_left = -210.0
	speed_label.offset_right = -28.0
	speed_label.offset_top = 17.0
	speed_label.offset_bottom = 60.0
	var panel := PanelContainer.new()
	root.add_child(panel)
	gameplay_hud_nodes.append(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -52.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.095, 0.10, 0.96)
	style.border_width_top = 2
	style.border_color = PARK_TEAL
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)
	var controls := Label.new()
	controls.text = "W  Beschleunigen    |    S  Bremsen / Rueckwaerts    |    A / D  Lenken    |    R  Zuruecksetzen    |    Esc  Pause"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_theme_font_size_override("font_size", 17)
	controls.add_theme_color_override("font_color", WARM_WHITE)
	panel.add_child(controls)


func _race_label(font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", WARM_WHITE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _race_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 48.0)
	button.add_theme_font_size_override("font_size", 20)
	var normal := StyleBoxFlat.new()
	normal.bg_color = PARK_TEAL
	normal.content_margin_left = 20.0
	normal.content_margin_right = 20.0
	normal.content_margin_top = 10.0
	normal.content_margin_bottom = 10.0
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("32736a")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_border_width_all(2)
	focus.border_color = WARM_WHITE
	button.add_theme_stylebox_override("focus", focus)
	return button


func _build_frontend_presentation() -> void:
	showcase_stage = Node3D.new()
	showcase_stage.name = "MenuShowcase"
	showcase_stage.position = Vector3(40.0, 0.0, 0.0)
	add_child(showcase_stage)
	showcase_pedestal = MeshInstance3D.new()
	showcase_pedestal.name = "ShowcasePlatform"
	var pedestal_mesh := CylinderMesh.new()
	pedestal_mesh.top_radius = 2.3
	pedestal_mesh.bottom_radius = 2.3
	pedestal_mesh.height = 0.08
	pedestal_mesh.radial_segments = 48
	showcase_pedestal.mesh = pedestal_mesh
	showcase_pedestal.material_override = _material(PARK_TEAL, 0.58, 0.2)
	showcase_pedestal.position.y = 0.04
	showcase_stage.add_child(showcase_pedestal)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 2.22
	ring_mesh.outer_radius = 2.25
	ring_mesh.rings = 48
	ring_mesh.ring_segments = 10
	showcase_ring = MeshInstance3D.new()
	showcase_ring.name = "ShowcaseAccent"
	showcase_ring.mesh = ring_mesh
	var ring_material := _material(Color("e26c42"), 0.4, 0.3)
	ring_material.emission_enabled = true
	ring_material.emission = Color("b4462e")
	ring_material.emission_energy_multiplier = 0.35
	showcase_ring.material_override = ring_material
	showcase_ring.position.y = 0.083
	showcase_ring.visible = false
	showcase_stage.add_child(showcase_ring)
	_build_garage_dressing()
	player.reparent(showcase_stage)
	player.position = Vector3(0.0, 0.08, 0.0)
	player.rotation = Vector3(0.0, PI, 0.0)
	player.driving_enabled = false
	player.set_physics_process(false)
	player.collision_layer = 0
	player.collision_mask = 0
	menu_camera = Camera3D.new()
	menu_camera.name = "MenuCamera"
	menu_camera.position = Vector3(0.0, 2.7, 6.8)
	showcase_stage.add_child(menu_camera)
	menu_camera.look_at(showcase_stage.to_global(Vector3(-2.5, 1.0, 0.0)))
	menu_camera.make_current()
	upgrade_camera = Camera3D.new()
	upgrade_camera.name = "UpgradeShowcaseCamera"
	upgrade_camera.fov = 50.0
	upgrade_camera.near = 0.1
	upgrade_camera.far = 100.0
	upgrade_camera.position = Vector3(2.1, 1.35, -5.35)
	showcase_stage.add_child(upgrade_camera)
	upgrade_camera.look_at(showcase_stage.to_global(Vector3(0.2, 0.98, 0.0)))
	garage_environment = Environment.new()
	garage_environment.background_mode = Environment.BG_COLOR
	garage_environment.background_color = Color("111619")
	garage_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	garage_environment.ambient_light_color = Color("899397")
	garage_environment.ambient_light_energy = 0.5
	garage_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	upgrade_camera.environment = garage_environment


func _showcase_box(parent: Node3D, size: Vector3, location: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = location
	parent.add_child(instance)
	return instance


func _build_garage_dressing() -> void:
	garage_dressing = Node3D.new()
	garage_dressing.name = "UpgradeGarage"
	garage_dressing.visible = false
	showcase_stage.add_child(garage_dressing)
	var floor_material := _material(Color("202628"), 0.55, 0.55)
	var wall_material := _material(Color("252a2c"), 0.42, 0.72)
	var beam_material := _material(Color("596264"), 0.76, 0.32)
	var floor := _showcase_box(garage_dressing, Vector3(50.0, 0.18, 40.0), Vector3(0.0, -0.04, 0.0), floor_material)
	floor.name = "GarageFloor"
	var rear_wall := _showcase_box(garage_dressing, Vector3(50.0, 8.0, 0.28), Vector3(0.0, 3.9, 5.8), wall_material)
	rear_wall.name = "RearWall"
	_showcase_box(garage_dressing, Vector3(48.0, 0.12, 0.18), Vector3(0.0, 0.28, 5.58), beam_material)
	_showcase_box(garage_dressing, Vector3(48.0, 0.18, 0.2), Vector3(0.0, 3.15, 5.58), beam_material)
	for index in range(25):
		var lateral: float = -24.0 + float(index) * 2.0
		_showcase_box(
			garage_dressing,
			Vector3(0.065, 7.5, 0.12),
			Vector3(lateral, 3.8, 5.57),
			beam_material
		)
	for index in range(24):
		var lateral: float = -23.0 + float(index) * 2.0
		var panel_color: Color = Color("303638") if index % 2 == 0 else Color("292f31")
		_showcase_box(
			garage_dressing,
			Vector3(1.65, 2.65, 0.06),
			Vector3(lateral, 1.75, 5.51),
			_material(panel_color, 0.4, 0.74)
		)
		_showcase_box(
			garage_dressing,
			Vector3(1.65, 2.25, 0.06),
			Vector3(lateral, 4.25, 5.51),
			_material(panel_color.darkened(0.13), 0.42, 0.72)
		)
	_showcase_box(garage_dressing, Vector3(16.0, 0.12, 0.16), Vector3(0.0, 5.85, -3.2), beam_material)
	var warm_strip := _material(Color("ed8650"), 0.15, 0.3)
	warm_strip.emission_enabled = true
	warm_strip.emission = Color("ba4931")
	warm_strip.emission_energy_multiplier = 1.1
	_showcase_box(garage_dressing, Vector3(4.3, 0.055, 0.09), Vector3(-3.1, 5.74, -3.2), warm_strip)
	var cool_strip := _material(Color("45b9ad"), 0.15, 0.3)
	cool_strip.emission_enabled = true
	cool_strip.emission = Color("287e7a")
	cool_strip.emission_energy_multiplier = 1.1
	_showcase_box(garage_dressing, Vector3(4.3, 0.055, 0.09), Vector3(3.1, 5.74, -3.2), cool_strip)
	for side in [-1.0, 1.0]:
		var lateral: float = float(side)
		_showcase_box(
			garage_dressing,
			Vector3(0.055, 0.025, 13.0),
			Vector3(lateral * 5.5, -0.027, -0.5),
			warm_strip if side < 0.0 else cool_strip
		)
	garage_key_light = OmniLight3D.new()
	garage_key_light.name = "WarmKeyLight"
	garage_key_light.position = Vector3(2.4, 3.5, -2.6)
	garage_key_light.light_color = Color("f3c99a")
	garage_key_light.light_energy = 3.8
	garage_key_light.omni_range = 12.0
	garage_key_light.shadow_enabled = false
	garage_dressing.add_child(garage_key_light)
	garage_rim_light = OmniLight3D.new()
	garage_rim_light.name = "CoolRimLight"
	garage_rim_light.position = Vector3(-3.4, 3.0, 2.4)
	garage_rim_light.light_color = Color("64bac2")
	garage_rim_light.light_energy = 2.4
	garage_rim_light.omni_range = 10.0
	garage_rim_light.shadow_enabled = false
	garage_dressing.add_child(garage_rim_light)


func _menu_label(parent: Node, text: String, font_size: int, color: Color = WARM_WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _menu_panel(parent: Control, anchors: Vector4) -> PanelContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	panel.anchor_left = anchors.x
	panel.anchor_top = anchors.y
	panel.anchor_right = anchors.z
	panel.anchor_bottom = anchors.w
	var style := StyleBoxFlat.new()
	style.bg_color = Color("151b1e")
	style.set_border_width_all(1)
	style.border_color = Color("596568")
	style.set_corner_radius_all(2)
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 18.0
	style.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _category_button(text: String) -> Button:
	var button := _race_button(text)
	button.custom_minimum_size = Vector2(0.0, 94.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 17)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("1a2022")
	normal.set_border_width_all(1)
	normal.border_color = Color("485255")
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 16.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("272d2f")
	hover.border_color = Color("a7664b")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	return button


func _engine_card(choice: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0.0, 112.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", WARM_WHITE)
	button.pressed.connect(_select_engine.bind(str(choice["id"])))
	engine_buttons.append(button)
	return button


func _style_engine_card(button: Button, equipped: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("35251f") if equipped else Color("191f21")
	normal.set_border_width_all(2)
	normal.border_color = Color("e17b53") if equipped else Color("566164")
	normal.set_corner_radius_all(2)
	normal.content_margin_left = 12.0
	normal.content_margin_right = 12.0
	normal.content_margin_top = 8.0
	normal.content_margin_bottom = 8.0
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("30393b") if not equipped else Color("4a3127")
	hover.border_color = Color("eaa47d")
	button.add_theme_stylebox_override("hover", hover)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("243f3f")
	button.add_theme_stylebox_override("pressed", pressed)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_border_width_all(3)
	focus.border_color = WARM_WHITE
	button.add_theme_stylebox_override("focus", focus)


func _build_frontend_menu() -> void:
	frontend_root = Control.new()
	frontend_root.name = "FrontEndMenu"
	frontend_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frontend_root.mouse_filter = Control.MOUSE_FILTER_STOP
	hud_root.add_child(frontend_root)
	frontend_shade = ColorRect.new()
	frontend_shade.color = Color(0.025, 0.055, 0.06, 0.38)
	frontend_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frontend_root.add_child(frontend_shade)
	frontend_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frontend_title = _menu_label(frontend_root, "WHEELCHAIR RACER", 36)
	frontend_title.anchor_left = 0.055
	frontend_title.anchor_top = 0.045
	frontend_title.anchor_right = 0.55
	frontend_title.anchor_bottom = 0.11
	frontend_subtitle = _menu_label(frontend_root, "PARK CIRCUIT  /  ONE-LAP TIME TRIAL", 13, Color("9dbdb5"))
	frontend_subtitle.anchor_left = 0.058
	frontend_subtitle.anchor_top = 0.12
	frontend_subtitle.anchor_right = 0.55
	frontend_subtitle.anchor_bottom = 0.16

	var stats_layer := CanvasLayer.new()
	stats_layer.layer = 1
	stats_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(stats_layer)
	stats_overlay_root = Control.new()
	stats_overlay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stats_overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_layer.add_child(stats_overlay_root)
	var stats_panel := _menu_panel(stats_overlay_root, Vector4(0.755, 0.045, 0.97, 0.265))
	stats_panel.z_index = 10
	stats_panel.z_as_relative = false
	stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stats_column := VBoxContainer.new()
	stats_column.add_theme_constant_override("separation", 8)
	stats_panel.add_child(stats_column)
	_menu_label(stats_column, "CURRENT SETUP", 13, Color("9dbdb5"))
	var stat_row := HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", 32)
	stats_column.add_child(stat_row)
	var speed_column := VBoxContainer.new()
	speed_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_row.add_child(speed_column)
	_menu_label(speed_column, "MAX SPEED", 12, Color("9dbdb5"))
	stats_speed_label = _menu_label(speed_column, "65 km/h", 25)
	var acceleration_column := VBoxContainer.new()
	acceleration_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_row.add_child(acceleration_column)
	_menu_label(acceleration_column, "ACCELERATION", 12, Color("9dbdb5"))
	stats_acceleration_label = _menu_label(acceleration_column, "35 km/h/s", 25)
	stats_engine_label = _menu_label(stats_column, "ENGINE  STOCK", 13, Color("edb777"))

	main_page = Control.new()
	frontend_root.add_child(main_page)
	main_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var main_panel := _menu_panel(main_page, Vector4(0.055, 0.235, 0.455, 0.90))
	var main_contents := VBoxContainer.new()
	main_contents.add_theme_constant_override("separation", 14)
	main_panel.add_child(main_contents)
	_menu_label(main_contents, "ONE LAP.\nYOUR BEST.", 30)
	_menu_label(main_contents, "Build your setup. Chase a faster time.", 16, Color("b4c7c1"))
	main_engine_label = _menu_label(main_contents, "INSTALLED ENGINE  STOCK", 14, Color("edb777"))
	main_play_button = _race_button("PLAY")
	main_play_button.custom_minimum_size.y = 58.0
	main_play_button.add_theme_font_size_override("font_size", 22)
	main_play_button.pressed.connect(_start_game)
	main_contents.add_child(main_play_button)
	var upgrade_button := _race_button("UPGRADE")
	upgrade_button.custom_minimum_size.y = 54.0
	upgrade_button.add_theme_font_size_override("font_size", 19)
	upgrade_button.pressed.connect(_open_upgrade_categories)
	main_contents.add_child(upgrade_button)
	main_upgrade_button = upgrade_button
	var frontend_exit_button := _race_button("EXIT")
	frontend_exit_button.custom_minimum_size.y = 54.0
	frontend_exit_button.add_theme_font_size_override("font_size", 19)
	frontend_exit_button.pressed.connect(_quit_game)
	main_contents.add_child(frontend_exit_button)
	main_exit_button = frontend_exit_button

	upgrade_page = Control.new()
	frontend_root.add_child(upgrade_page)
	upgrade_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var categories_panel := _menu_panel(upgrade_page, Vector4(0.035, 0.20, 0.315, 0.96))
	var categories_contents := VBoxContainer.new()
	categories_contents.add_theme_constant_override("separation", 10)
	categories_panel.add_child(categories_contents)
	_menu_label(categories_contents, "WORKSHOP / SYSTEMS", 19)
	_menu_label(categories_contents, "SELECT A CATEGORY TO TUNE", 12, Color("b4c7c1"))
	var category_row := VBoxContainer.new()
	category_row.add_theme_constant_override("separation", 8)
	category_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	categories_contents.add_child(category_row)
	engine_category_button = _category_button("ENGINE\nACTIVE  /  SPEED + ACCELERATION")
	engine_category_button.pressed.connect(_open_engine_upgrades)
	category_row.add_child(engine_category_button)
	wheel_category_button = _category_button("WHEEL\nCOMING SOON  /  GRIP + HANDLING")
	wheel_category_button.pressed.connect(_open_wheel_placeholder)
	category_row.add_child(wheel_category_button)
	aerodynamics_category_button = _category_button("AERODYNAMICS\nCOMING SOON  /  AIRFLOW")
	aerodynamics_category_button.pressed.connect(_open_aerodynamics_placeholder)
	category_row.add_child(aerodynamics_category_button)
	category_back_button = _race_button("BACK / MAIN MENU")
	category_back_button.pressed.connect(_return_to_frontend)
	categories_contents.add_child(category_back_button)

	engine_page = Control.new()
	frontend_root.add_child(engine_page)
	engine_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var engines_panel := _menu_panel(engine_page, Vector4(0.035, 0.18, 0.315, 0.96))
	var engines_contents := VBoxContainer.new()
	engines_contents.add_theme_constant_override("separation", 9)
	engines_panel.add_child(engines_contents)
	_menu_label(engines_contents, "ENGINE / POWERTRAIN", 18)
	_menu_label(engines_contents, "SELECT ONE MOTOR", 12, Color("b4c7c1"))
	var engine_row := VBoxContainer.new()
	engine_row.add_theme_constant_override("separation", 7)
	engine_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	engines_contents.add_child(engine_row)
	for choice in upgrade_data.call("get_engine_choices"):
		engine_row.add_child(_engine_card(choice))
	upgrade_message_label = _menu_label(engines_contents, "", 14, Color("edb777"))
	engine_back_button = _race_button("BACK / SYSTEMS")
	engine_back_button.pressed.connect(_open_upgrade_categories)
	engines_contents.add_child(engine_back_button)

	placeholder_page = Control.new()
	frontend_root.add_child(placeholder_page)
	placeholder_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var placeholder_panel := _menu_panel(placeholder_page, Vector4(0.035, 0.37, 0.315, 0.76))
	var placeholder_contents := VBoxContainer.new()
	placeholder_contents.alignment = BoxContainer.ALIGNMENT_CENTER
	placeholder_contents.add_theme_constant_override("separation", 18)
	placeholder_panel.add_child(placeholder_contents)
	placeholder_title = _menu_label(placeholder_contents, "WHEEL", 28)
	placeholder_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder_status_label = _menu_label(placeholder_contents, "COMING SOON", 22, Color("edb777"))
	placeholder_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder_back_button = _race_button("BACK TO UPGRADES")
	placeholder_back_button.pressed.connect(_open_upgrade_categories)
	placeholder_contents.add_child(placeholder_back_button)
	_set_frontend_page("main")


func _set_frontend_page(page_name: String) -> void:
	frontend_page_name = page_name
	main_page.visible = page_name == "main"
	upgrade_page.visible = page_name == "upgrades"
	engine_page.visible = page_name == "engine"
	placeholder_page.visible = page_name == "placeholder"
	_set_showcase_mode(page_name != "main")
	match page_name:
		"main":
			frontend_title.text = "WHEELCHAIR RACER"
			frontend_subtitle.text = "PARK CIRCUIT  /  ONE-LAP TIME TRIAL"
			primary_button = main_play_button
			main_play_button.grab_focus()
		"upgrades":
			frontend_title.text = "WORKSHOP"
			frontend_subtitle.text = "CUSTOMIZE YOUR CHAIR  /  GARAGE 01"
			engine_category_button.grab_focus()
		"engine":
			frontend_title.text = "ENGINE BAY"
			frontend_subtitle.text = "POWERTRAIN  /  CHOOSE ONE MOTOR"
			engine_buttons[0].grab_focus()
		"placeholder":
			frontend_title.text = placeholder_title.text
			frontend_subtitle.text = "WORKSHOP  /  SYSTEM IN DEVELOPMENT"
			placeholder_back_button.grab_focus()
	_refresh_gameplay_hud_visibility()


func _set_showcase_mode(is_garage: bool) -> void:
	if garage_mode == is_garage:
		return
	garage_mode = is_garage
	garage_dressing.visible = is_garage
	garage_key_light.visible = is_garage
	garage_rim_light.visible = is_garage
	sun_light.visible = not is_garage
	showcase_ring.visible = is_garage
	showcase_pedestal.material_override = _material(
		Color("242a2c") if is_garage else PARK_TEAL,
		0.58,
		0.2
	)
	frontend_shade.color = Color(0.025, 0.055, 0.06, 0.12 if is_garage else 0.38)
	if is_garage:
		player.rotation.y = PI - 0.9
		upgrade_camera.make_current()
	else:
		player.rotation.y = PI
		menu_camera.make_current()


func _open_upgrade_categories() -> void:
	_set_frontend_page("upgrades")


func _open_engine_upgrades() -> void:
	_refresh_upgrade_ui()
	_set_frontend_page("engine")


func _open_wheel_placeholder() -> void:
	_show_placeholder("WHEEL")


func _open_aerodynamics_placeholder() -> void:
	_show_placeholder("AERODYNAMICS")


func _show_placeholder(category: String) -> void:
	placeholder_title.text = category
	placeholder_status_label.text = "COMING SOON"
	_set_frontend_page("placeholder")


func _return_to_frontend() -> void:
	_set_frontend_page("main")


func _start_game() -> void:
	if player.get_parent() == showcase_stage:
		player.reparent(self)
	player.set_physics_process(true)
	player.collision_layer = 1
	player.collision_mask = 1
	follow_camera.make_current()
	race.start_attempt()


func _select_engine(engine_id: String) -> void:
	upgrade_data.call("select_engine", engine_id)
	var save_error: String = str(upgrade_data.get("persistence_error"))
	upgrade_message_label.text = save_error if not save_error.is_empty() else "ENGINE EQUIPPED"


func _refresh_upgrade_ui() -> void:
	if not is_instance_valid(stats_speed_label):
		return
	var selected_engine: Dictionary = upgrade_data.call("get_selected_engine")
	stats_speed_label.text = "%d km/h" % roundi(float(upgrade_data.get("max_speed_kmh")))
	stats_acceleration_label.text = "%d km/h/s" % roundi(float(upgrade_data.get("acceleration_kmh_per_second")))
	stats_engine_label.text = "ENGINE  " + str(selected_engine.get("name", "STOCK"))
	main_engine_label.text = "INSTALLED ENGINE  " + str(selected_engine.get("name", "STOCK"))
	player.install_engine(str(selected_engine.get("visual_id", "")))
	var choices: Variant = upgrade_data.call("get_engine_choices")
	for choice_index in range(mini(engine_buttons.size(), choices.size())):
		var choice: Dictionary = choices[choice_index]
		var equipped: bool = choice["id"] == upgrade_data.get("selected_engine_id")
		var max_bonus: int = roundi(float(choice["max_speed_bonus_kmh"]))
		var acceleration_bonus: int = roundi(float(choice["acceleration_bonus_kmh_per_second"]))
		var status: String = "EQUIPPED" if equipped else "SELECT ENGINE"
		engine_buttons[choice_index].text = "%s\n%s\n%+d km/h TOP SPEED\n%+d km/h/s ACCELERATION\n%s" % [
			choice["name"],
			choice["description"],
			max_bonus,
			acceleration_bonus,
			status,
		]
		_style_engine_card(engine_buttons[choice_index], equipped)


func _refresh_gameplay_hud_visibility() -> void:
	var gameplay_visible: bool = not frontend_root.visible
	for control in gameplay_hud_nodes:
		control.visible = gameplay_visible


func _build_race_hud() -> void:
	time_label = _race_label(28)
	hud_root.add_child(time_label)
	gameplay_hud_nodes.append(time_label)
	time_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	time_label.offset_left = -140.0
	time_label.offset_right = 140.0
	time_label.offset_top = 8.0
	time_label.offset_bottom = 43.0
	progress_label = _race_label(14)
	hud_root.add_child(progress_label)
	gameplay_hud_nodes.append(progress_label)
	progress_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	progress_label.offset_left = -160.0
	progress_label.offset_right = 160.0
	progress_label.offset_top = 46.0
	progress_label.offset_bottom = 68.0
	countdown_label = _race_label(80)
	hud_root.add_child(countdown_label)
	gameplay_hud_nodes.append(countdown_label)
	countdown_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.add_theme_constant_override("outline_size", 8)
	countdown_label.add_theme_color_override("font_outline_color", Color("17302e"))
	race_menu = Control.new()
	hud_root.add_child(race_menu)
	race_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.055, 0.06, 0.55)
	race_menu.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	race_menu.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 480.0
	center.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("142b2b")
	style.content_margin_left = 32.0
	style.content_margin_right = 32.0
	style.content_margin_top = 28.0
	style.content_margin_bottom = 28.0
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 18)
	panel.add_child(contents)
	menu_title = _race_label(30)
	contents.add_child(menu_title)
	menu_details = _race_label(21)
	contents.add_child(menu_details)
	record_label = _race_label(20)
	record_label.add_theme_color_override("font_color", Color("edb777"))
	contents.add_child(record_label)
	play_button = _race_button("Play")
	play_button.pressed.connect(_activate_primary)
	contents.add_child(play_button)
	primary_button = play_button
	restart_button = _race_button("New run")
	restart_button.pressed.connect(_restart_attempt)
	contents.add_child(restart_button)
	return_button = _race_button("Main menu")
	return_button.pressed.connect(_return_to_main_menu)
	contents.add_child(return_button)
	exit_button = _race_button("Exit")
	exit_button.pressed.connect(_quit_game)
	contents.add_child(exit_button)


func _activate_primary() -> void:
	if get_tree().paused:
		race.toggle_pause()
	else:
		race.start_attempt()


func _restart_attempt() -> void:
	race.start_attempt()


func _return_to_main_menu() -> void:
	get_tree().paused = false
	player.driving_enabled = false
	player.speed = 0.0
	player.velocity = Vector3.ZERO
	player.set_physics_process(false)
	player.collision_layer = 0
	player.collision_mask = 0
	player.reset_to_start()
	if player.get_parent() != showcase_stage:
		player.reparent(showcase_stage)
	player.position = Vector3(0.0, 0.08, 0.0)
	player.rotation = Vector3(0.0, PI, 0.0)
	menu_camera.make_current()
	_set_frontend_page("main")
	race.return_to_ready()


func _quit_game() -> void:
	get_tree().quit()


func _update_race_hud() -> void:
	var milliseconds: int = race.result_ms if race.state == RaceController.State.FINISHED else roundi(race.elapsed_seconds * 1000.0)
	time_label.text = RaceController.format_time(milliseconds)
	progress_label.text = "Kontrollpunkt %d / %d" % [race.checkpoint_count, race.checkpoints.size()]
	if race.checkpoint_count == race.checkpoints.size():
		progress_label.text += "  |  Ziel"
	countdown_label.text = race.countdown_text() if not get_tree().paused else ""
	countdown_label.visible = not countdown_label.text.is_empty()


func _show_race_menu() -> void:
	_update_race_hud()
	var paused: bool = get_tree().paused
	var is_frontend: bool = race.state == RaceController.State.READY and not paused
	frontend_root.visible = is_frontend
	stats_overlay_root.visible = is_frontend
	race_menu.visible = paused or race.state == RaceController.State.FINISHED
	_refresh_gameplay_hud_visibility()
	if is_frontend:
		primary_button = main_play_button
		menu_camera.make_current()
		return
	primary_button = play_button
	record_label.text = ""
	if paused:
		menu_title.text = "Paused"
		menu_details.text = time_label.text
		play_button.text = "Resume"
	elif race.state == RaceController.State.READY:
		menu_title.text = "Wheelchair Racer"
		menu_details.text = "Start the run"
		play_button.text = "Play"
	elif race.state == RaceController.State.FINISHED:
		menu_title.text = "Result"
		menu_details.text = "Lap time: " + RaceController.format_time(race.result_ms)
		menu_details.text += "\nBest time: " + (RaceController.format_time(race.previous_best_ms) if race.previous_best_ms > 0 else "--:--.---")
		record_label.text = "New record!" if race.new_record else ""
		if race.save_failed:
			record_label.text += "\nBest time could not be saved."
		play_button.text = "Play again"
	restart_button.visible = paused or race.state == RaceController.State.FINISHED
	return_button.visible = paused or race.state == RaceController.State.FINISHED
	record_label.visible = not record_label.text.is_empty()
	if race_menu.visible:
		play_button.grab_focus()