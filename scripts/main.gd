extends Node3D

const WheelchairController = preload("res://scripts/wheelchair.gd")
const RaceController = preload("res://scripts/race.gd")
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
var speed_label: Label
var track_points: PackedVector3Array = PackedVector3Array()
var park_decoration: Node3D
var race: Node
@export var best_time_path: String = "user://best_time_v1.json"
var hud_root: Control
var time_label: Label
var progress_label: Label
var countdown_label: Label
var race_menu: Control
var menu_title: Label
var menu_details: Label
var record_label: Label
var primary_button: Button
var restart_button: Button


func _ready() -> void:
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
	_build_race_hud()
	race.updated.connect(_update_race_hud)
	race.state_changed.connect(_show_race_menu)
	_show_race_menu()


func _process(delta: float) -> void:
	var desired_position: Vector3 = player.global_position + player.global_basis.z * 7.5 + Vector3.UP * 4.5
	follow_camera.global_position = follow_camera.global_position.lerp(desired_position, 1.0 - exp(-7.0 * delta))
	follow_camera.look_at(player.global_position + Vector3.UP * 1.1 - player.global_basis.z * 1.5)
	speed_label.text = "%02d km/h" % roundi(player.speed * 3.6)


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
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	sun.light_color = Color("fff4df")
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 75.0
	add_child(sun)


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
	var heading := Label.new()
	heading.text = "WHEELCHAIR RACER"
	heading.position = Vector2(28.0, 12.0)
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", WARM_WHITE)
	root.add_child(heading)
	var subtitle := Label.new()
	subtitle.text = "TESTSTRECKE 01"
	subtitle.position = Vector2(29.0, 43.0)
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color("9dbdb5"))
	root.add_child(subtitle)
	speed_label = Label.new()
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	speed_label.add_theme_font_size_override("font_size", 30)
	speed_label.add_theme_color_override("font_color", WARM_WHITE)
	root.add_child(speed_label)
	speed_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	speed_label.offset_left = -210.0
	speed_label.offset_right = -28.0
	speed_label.offset_top = 17.0
	speed_label.offset_bottom = 60.0
	var panel := PanelContainer.new()
	root.add_child(panel)
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
	controls.text = "W  Beschleunigen    |    S  Bremsen    |    A / D  Lenken    |    R  Zuruecksetzen    |    Esc  Pause"
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


func _build_race_hud() -> void:
	time_label = _race_label(28)
	hud_root.add_child(time_label)
	time_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	time_label.offset_left = -140.0
	time_label.offset_right = 140.0
	time_label.offset_top = 8.0
	time_label.offset_bottom = 43.0
	progress_label = _race_label(14)
	hud_root.add_child(progress_label)
	progress_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	progress_label.offset_left = -160.0
	progress_label.offset_right = 160.0
	progress_label.offset_top = 46.0
	progress_label.offset_bottom = 68.0
	countdown_label = _race_label(80)
	hud_root.add_child(countdown_label)
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
	primary_button = _race_button("Rennen starten")
	primary_button.pressed.connect(_activate_primary)
	contents.add_child(primary_button)
	restart_button = _race_button("Neuer Versuch")
	restart_button.pressed.connect(race.start_attempt)
	contents.add_child(restart_button)


func _activate_primary() -> void:
	if get_tree().paused:
		race.toggle_pause()
	else:
		race.start_attempt()


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
	race_menu.visible = paused or race.state in [RaceController.State.READY, RaceController.State.FINISHED]
	restart_button.visible = paused
	record_label.text = ""
	if paused:
		menu_title.text = "Pause"
		menu_details.text = time_label.text
		primary_button.text = "Fortsetzen"
	elif race.state == RaceController.State.READY:
		menu_title.text = "Zeitrennen"
		menu_details.text = "Eine Runde\nBestzeit: " + (RaceController.format_time(race.best_ms) if race.best_ms > 0 else "--:--.---")
		primary_button.text = "Rennen starten"
	elif race.state == RaceController.State.FINISHED:
		menu_title.text = "Ergebnis"
		menu_details.text = "Rundenzeit: " + RaceController.format_time(race.result_ms)
		menu_details.text += "\nBisherige Bestzeit: " + (RaceController.format_time(race.previous_best_ms) if race.previous_best_ms > 0 else "--:--.---")
		record_label.text = "Neuer Rekord!" if race.new_record else ""
		if race.save_failed:
			record_label.text += "\nBestzeit konnte nicht gespeichert werden."
		primary_button.text = "Erneut starten"
	record_label.visible = not record_label.text.is_empty()
	if race_menu.visible:
		primary_button.grab_focus()