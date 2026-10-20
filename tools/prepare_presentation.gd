extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for path in ["res://assets/wheelchair/wheelchair_01.gltf", "res://assets/rider/man-rigged.glb"]:
		var scene: PackedScene = load(path)
		assert(scene != null, "Imported asset must load")
		var model: Node = scene.instantiate()
		root.add_child(model)
		print("ASSET ", path)
		for node in model.find_children("*", "MeshInstance3D", true, false):
			var instance := node as MeshInstance3D
			print("MESH ", instance.get_path(), " bounds=", instance.get_aabb(), " transform=", instance.global_transform)
			if path.contains("wheelchair"):
				_prepare_chair(instance.mesh)
			else:
				if not OS.get_cmdline_user_args().has("--inspect-fit"):
					_prepare_rider(instance.mesh)
		for node in model.find_children("*", "Skeleton3D", true, false):
			var skeleton := node as Skeleton3D
			print("SKELETON ", skeleton.get_path(), " transform=", skeleton.global_transform)
			for bone in range(skeleton.get_bone_count()):
				var bone_name: String = skeleton.get_bone_name(bone)
				if "Hand" in bone_name and bone_name != "LeftHand" and bone_name != "RightHand":
					continue
				print(bone_name, " global=", skeleton.get_bone_global_rest(bone), " world=", skeleton.to_global(skeleton.get_bone_global_rest(bone).origin))
		model.free()
	quit()


func _prepare_rider(mesh: Mesh) -> void:
	var material: StandardMaterial3D = mesh.surface_get_material(0).duplicate()
	material.metallic = 0.0
	material.metallic_specular = 0.25
	material.normal_scale = 0.65
	var image: Image = material.albedo_texture.get_image()
	if image.is_compressed():
		image.decompress()
	print("RIDER base color=", image.get_size(), " normal=", material.normal_texture.get_size(), " roughness=", material.roughness_texture.get_size())
	for vertical in range(image.get_height()):
		for horizontal in range(image.get_width()):
			var pixel: Color = image.get_pixel(horizontal, vertical)
			if pixel.h > 0.12 and pixel.h < 0.45 and pixel.s > 0.18:
				pixel = Color.from_hsv(0.065, minf(pixel.s * 1.25, 0.75), pixel.v, pixel.a)
				image.set_pixel(horizontal, vertical, pixel)
	image.generate_mipmaps()
	material.albedo_texture = ImageTexture.create_from_image(image)
	var arrays: Array = mesh.surface_get_arrays(0)
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	result.surface_set_material(0, material)
	assert(result.surface_get_arrays(0)[Mesh.ARRAY_BONES] == arrays[Mesh.ARRAY_BONES])
	assert(result.surface_get_array_index_len(0) == mesh.surface_get_array_index_len(0))
	print("PREPARED RIDER vertices=", result.surface_get_array_len(0), " triangles=", result.surface_get_array_index_len(0) / 3, " source topology preserved")
	assert(ResourceSaver.save(result, "res://assets/rider/rider_mesh.res", ResourceSaver.FLAG_COMPRESS) == OK)


func _prepare_chair(mesh: Mesh) -> void:
	var material: StandardMaterial3D = mesh.surface_get_material(0).duplicate()
	material.metallic = 0.75
	material.normal_scale = 0.7
	var roughness: Image = material.roughness_texture.get_image()
	if roughness.is_compressed():
		roughness.decompress()
	for vertical in range(roughness.get_height()):
		for horizontal in range(roughness.get_width()):
			var pixel: Color = roughness.get_pixel(horizontal, vertical)
			pixel.g = maxf(pixel.g, 0.42)
			roughness.set_pixel(horizontal, vertical, pixel)
	roughness.generate_mipmaps()
	material.roughness_texture = ImageTexture.create_from_image(roughness)
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var parents: Array[int] = []
	var welded: Dictionary = {}
	for vertex_index in range(vertices.size()):
		var key: Vector3i = Vector3i((vertices[vertex_index] * 100000.0).round())
		if not welded.has(key):
			welded[key] = vertex_index
		parents.append(welded[key])
	for index in range(0, indices.size(), 3):
		var first: int = _root(parents, indices[index])
		parents[_root(parents, indices[index + 1])] = first
		parents[_root(parents, indices[index + 2])] = first
	var components: Dictionary = {}
	for index in range(0, indices.size(), 3):
		var component: int = _root(parents, indices[index])
		if not components.has(component):
			components[component] = {"triangles": 0, "bounds": AABB(vertices[indices[index]], Vector3.ZERO)}
		components[component]["triangles"] += 1
		for corner in range(3):
			components[component]["bounds"] = components[component]["bounds"].expand(vertices[indices[index + corner]])
	if OS.get_cmdline_user_args().has("--inspect-fit"):
		for component in components.values():
			if component["triangles"] > 100:
				print("FIT COMPONENT triangles=", component["triangles"], " bounds=", component["bounds"])
		return
	var pivots: Array[Vector3] = [
		Vector3.ZERO,
		Vector3(-0.3637, 0.3431, -0.1484),
		Vector3(0.3611, 0.3431, -0.1484),
		Vector3(-0.278, 0.1095, 0.5069),
		Vector3(0.276, 0.1095, 0.5069),
		Vector3(-0.278, 0.22, 0.465),
		Vector3(0.276, 0.22, 0.465),
	]
	var labels: Array[String] = ["Frame", "RearLeft", "RearRight", "CasterLeft", "CasterRight", "ForkLeft", "ForkRight"]
	var tools: Array[SurfaceTool] = []
	var counts: Array[int] = [0, 0, 0, 0, 0, 0, 0]
	for part in range(labels.size()):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(material)
		tools.append(surface)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	for index in range(0, indices.size(), 3):
		var component: Dictionary = components[_root(parents, indices[index])]
		var bounds: AABB = component["bounds"]
		var center: Vector3 = bounds.get_center()
		var part: int = 0
		if absf(center.x) > 0.33 and bounds.end.z < 0.21 and bounds.end.y < 0.71:
			part = 1 if center.x < 0.0 else 2
		elif absf(center.x) > 0.24 and bounds.position.z > 0.40 and bounds.end.y < 0.211:
			part = 3 if center.x < 0.0 else 4
		elif absf(center.x) > 0.24 and bounds.position.z > 0.40 and bounds.end.y < 0.25:
			part = 5 if center.x < 0.0 else 6
		counts[part] += 1
		for corner in range(3):
			var vertex: int = indices[index + corner]
			tools[part].set_normal(normals[vertex])
			tools[part].set_uv(uvs[vertex])
			if not tangents.is_empty():
				tools[part].set_tangent(Plane(tangents[vertex * 4], tangents[vertex * 4 + 1], tangents[vertex * 4 + 2], tangents[vertex * 4 + 3]))
			tools[part].add_vertex(vertices[vertex] - pivots[part])
	var chair := Node3D.new()
	chair.name = "ChairModel"
	for part in range(labels.size()):
		assert(counts[part] > 200, "Every movable assembly must contain geometry")
		tools[part].index()
		var part_mesh: ArrayMesh = tools[part].commit()
		var importer := ImporterMesh.new()
		importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, part_mesh.surface_get_arrays(0), [], {}, part_mesh.surface_get_material(0))
		importer.generate_lods(60.0, 15.0, [])
		var instance := MeshInstance3D.new()
		instance.name = labels[part]
		instance.mesh = importer.get_mesh()
		instance.position = pivots[part]
		chair.add_child(instance)
		instance.owner = chair
		print("PREPARED ", labels[part], " triangles=", counts[part], " pivot=", pivots[part])
	assert(counts.reduce(func(total: int, count: int) -> int: return total + count, 0) == 40252, "Split preserves every source triangle")
	var packed := PackedScene.new()
	assert(packed.pack(chair) == OK)
	assert(ResourceSaver.save(packed, "res://assets/wheelchair/chair_prepared.scn") == OK)
	chair.free()


func _root(parents: Array[int], index: int) -> int:
	while parents[index] != index:
		parents[index] = parents[parents[index]]
		index = parents[index]
	return index