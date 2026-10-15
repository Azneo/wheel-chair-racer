extends RefCounted


static func create_engine(visual_id: String) -> Node3D:
	var assembly := Node3D.new()
	assembly.name = visual_id.to_pascal_case() + "Engine"
	match visual_id:
		"comet":
			_build_comet(assembly)
		"rally":
			_build_rally(assembly)
		"launch":
			_build_launch(assembly)
		_:
			push_error("Unknown engine visual: " + visual_id)
			assembly.free()
			return null
	return assembly


static func _material(color: Color, metallic: float = 0.0, roughness: float = 0.55) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


static func _emissive_material(color: Color) -> StandardMaterial3D:
	var material := _material(color, 0.15, 0.25)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.6
	return material


static func _mesh(parent: Node3D, mesh: Mesh, location: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = location
	parent.add_child(instance)
	return instance


static func _box(parent: Node3D, size: Vector3, location: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, location, material)


static func _cylinder(
	parent: Node3D,
	location: Vector3,
	radius: float,
	height: float,
	material: Material,
	axis: Vector3 = Vector3.UP,
	taper: float = 0.0
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = maxf(0.01, radius - taper)
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	var instance := _mesh(parent, mesh, location, material)
	instance.quaternion = Quaternion(Vector3.UP, axis.normalized())
	return instance


static func _beam(parent: Node3D, start: Vector3, finish: Vector3, radius: float, material: Material) -> void:
	var direction: Vector3 = finish - start
	_cylinder(parent, (start + finish) * 0.5, radius, direction.length(), material, direction.normalized())


static func _sphere(
	parent: Node3D,
	location: Vector3,
	radius: float,
	scale: Vector3,
	material: Material
) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 20
	mesh.rings = 10
	var instance := _mesh(parent, mesh, location, material)
	instance.scale = scale
	return instance


static func _ring(
	parent: Node3D,
	location: Vector3,
	inner_radius: float,
	outer_radius: float,
	material: Material,
	axis: Vector3 = Vector3.UP
) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 32
	mesh.ring_segments = 10
	var instance := _mesh(parent, mesh, location, material)
	instance.quaternion = Quaternion(Vector3.UP, axis.normalized())
	return instance


static func _mount_brackets(parent: Node3D, material: Material) -> void:
	for side in [-1.0, 1.0]:
		var x: float = float(side)
		_beam(parent, Vector3(x * 0.22, 0.13, 0.0), Vector3(x * 0.37, 0.20, 0.02), 0.025, material)
		_beam(parent, Vector3(x * 0.37, 0.20, 0.02), Vector3(x * 0.38, -0.16, 0.02), 0.025, material)


static func _build_comet(parent: Node3D) -> void:
	var casing := _material(Color("25333a"), 0.65, 0.34)
	var steel := _material(Color("a8b4b2"), 0.78, 0.28)
	var teal := _material(Color("38a79b"), 0.45, 0.28)
	var rubber := _material(Color("141b20"), 0.1, 0.72)
	var copper := _material(Color("c07c43"), 0.65, 0.32)
	_mount_brackets(parent, steel)
	_box(parent, Vector3(0.30, 0.15, 0.22), Vector3(0.0, 0.12, -0.06), casing)
	_box(parent, Vector3(0.19, 0.035, 0.17), Vector3(0.0, 0.215, -0.06), teal)
	_cylinder(parent, Vector3(0.0, -0.015, 0.055), 0.145, 0.46, casing, Vector3.RIGHT)
	_cylinder(parent, Vector3(0.245, -0.015, 0.055), 0.122, 0.045, steel, Vector3.RIGHT)
	_ring(parent, Vector3(0.272, -0.015, 0.055), 0.095, 0.124, teal, Vector3.RIGHT)
	_cylinder(parent, Vector3(-0.245, -0.015, 0.055), 0.122, 0.045, steel, Vector3.RIGHT)
	_ring(parent, Vector3(-0.272, -0.015, 0.055), 0.095, 0.124, teal, Vector3.RIGHT)
	_cylinder(parent, Vector3(0.294, -0.015, 0.055), 0.035, 0.025, copper, Vector3.RIGHT)
	_cylinder(parent, Vector3(-0.294, -0.015, 0.055), 0.035, 0.025, copper, Vector3.RIGHT)
	_cylinder(parent, Vector3(0.0, -0.015, 0.29), 0.065, 0.11, steel, Vector3.FORWARD)
	_beam(parent, Vector3(-0.08, 0.12, -0.16), Vector3(-0.20, 0.03, 0.02), 0.018, copper)
	_beam(parent, Vector3(0.08, 0.12, -0.16), Vector3(0.20, 0.03, 0.02), 0.018, copper)
	for bolt_index in range(4):
		var angle: float = TAU * float(bolt_index) / 4.0
		_sphere(
			parent,
			Vector3(0.313, -0.015 + cos(angle) * 0.085, 0.055 + sin(angle) * 0.085),
			0.014,
			Vector3.ONE,
			steel
		)
	_sphere(parent, Vector3(0.0, 0.218, -0.06), 0.025, Vector3.ONE, copper)
	_sphere(parent, Vector3(0.0, 0.218, -0.12), 0.025, Vector3.ONE, steel)


static func _build_rally(parent: Node3D) -> void:
	var casing := _material(Color("252b31"), 0.7, 0.3)
	var steel := _material(Color("b9c4c0"), 0.85, 0.22)
	var bronze := _material(Color("bb7540"), 0.7, 0.28)
	var orange := _material(Color("d25a36"), 0.28, 0.34)
	var dark := _material(Color("11181c"), 0.25, 0.65)
	_mount_brackets(parent, steel)
	_box(parent, Vector3(0.39, 0.18, 0.28), Vector3(0.0, 0.04, -0.015), casing)
	_box(parent, Vector3(0.30, 0.035, 0.20), Vector3(0.0, 0.15, -0.015), bronze)
	_cylinder(parent, Vector3(-0.19, -0.025, 0.045), 0.145, 0.22, dark, Vector3.RIGHT)
	_cylinder(parent, Vector3(0.19, -0.025, 0.045), 0.145, 0.22, dark, Vector3.RIGHT)
	for side in [-1.0, 1.0]:
		var x: float = float(side)
		var cap_x: float = x * 0.315
		_cylinder(parent, Vector3(cap_x, -0.025, 0.045), 0.125, 0.04, steel, Vector3.RIGHT)
		_ring(parent, Vector3(x * 0.34, -0.025, 0.045), 0.085, 0.125, orange, Vector3.RIGHT)
		_cylinder(parent, Vector3(x * 0.37, -0.025, 0.045), 0.045, 0.035, bronze, Vector3.RIGHT)
		for tooth_index in range(10):
			var angle: float = TAU * float(tooth_index) / 10.0
			var tooth_position := Vector3(
				x * 0.345,
				-0.025 + cos(angle) * 0.142,
				0.045 + sin(angle) * 0.142
			)
			var tooth := _box(parent, Vector3(0.045, 0.045, 0.055), tooth_position, steel)
			tooth.rotation.x = angle
	for fin_index in range(4):
		var fin_z: float = -0.10 + float(fin_index) * 0.06
		_box(
			parent,
			Vector3(0.46, 0.018, 0.025),
			Vector3(0.0, 0.165 + float(fin_index % 2) * 0.018, fin_z),
			steel if fin_index % 2 == 0 else bronze
		)
	_beam(parent, Vector3(-0.25, 0.03, -0.18), Vector3(-0.29, -0.07, 0.18), 0.022, bronze)
	_beam(parent, Vector3(0.25, 0.03, -0.18), Vector3(0.29, -0.07, 0.18), 0.022, bronze)
	_sphere(parent, Vector3(0.0, 0.17, -0.015), 0.035, Vector3(1.2, 0.55, 0.7), orange)


static func _build_launch(parent: Node3D) -> void:
	var casing := _material(Color("18343a"), 0.7, 0.24)
	var steel := _material(Color("a7bbb9"), 0.8, 0.22)
	var teal := _material(Color("27a99b"), 0.42, 0.24)
	var dark := _material(Color("10191d"), 0.35, 0.45)
	var glow := _emissive_material(Color("ed8650"))
	var core_glow := _emissive_material(Color("60d8c4"))
	_mount_brackets(parent, steel)
	_box(parent, Vector3(0.28, 0.15, 0.30), Vector3(0.0, 0.015, 0.015), casing)
	_box(parent, Vector3(0.16, 0.035, 0.19), Vector3(0.0, 0.105, -0.015), teal)
	for side in [-1.0, 1.0]:
		var x: float = float(side) * 0.18
		_cylinder(parent, Vector3(x, 0.0, 0.015), 0.13, 0.37, casing, Vector3.BACK, 0.025)
		_ring(parent, Vector3(x, 0.0, 0.22), 0.092, 0.135, teal, Vector3.BACK)
		_cylinder(parent, Vector3(x, 0.0, 0.235), 0.092, 0.035, dark, Vector3.BACK)
		_cylinder(parent, Vector3(x, 0.0, 0.257), 0.054, 0.015, glow, Vector3.BACK)
		_sphere(parent, Vector3(x, 0.0, 0.268), 0.034, Vector3.ONE, core_glow)
		_box(parent, Vector3(0.025, 0.26, 0.11), Vector3(x + side * 0.12, 0.0, -0.015), steel)
		_box(parent, Vector3(0.025, 0.17, 0.12), Vector3(x, 0.15, 0.015), teal)
		for fin_index in range(3):
			_box(
				parent,
				Vector3(0.022, 0.12, 0.055),
				Vector3(x, -0.11 + float(fin_index) * 0.095, -0.06),
				steel
			)
	_beam(parent, Vector3(-0.27, 0.12, -0.17), Vector3(0.27, 0.12, -0.17), 0.018, teal)
	_sphere(parent, Vector3(0.0, 0.145, -0.015), 0.045, Vector3(1.2, 0.65, 1.0), core_glow)
