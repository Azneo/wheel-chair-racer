extends Node3D

const SeatingProfile = preload("res://scripts/seating_profile.gd")
const RiderScene = preload("res://assets/rider/man-rigged.glb")
const RiderMesh = preload("res://assets/rider/rider_mesh.res")
@export var idle_enabled: bool = true
@export var seating: Resource = preload("res://assets/wheelchair/seating.tres")

var seat_frame: Transform3D
var usable_size: Vector2
var rear_radius: float
var caster_radius: float = 0.1
var wheel_contacts: Array[Vector3] = []
var sole_offsets: Array[Vector3] = []
var foot_sizes: Array[Vector2] = []
var body_groups: Dictionary = {}
var skin_arrays: Array
var skin_bones: Array[int] = []
var rider_mesh: MeshInstance3D
var fit_error: float = 0.0
var hand_length: float = 0.0
var constraint_failures: int = 0
var fit_conflicts: PackedStringArray = []
var reach_failures: PackedStringArray = []
var manual_offsets: Array[Vector3] = []
var supported_offsets: Array[Vector3] = []
var torso_recline: float = 0.0
var arm_radii: Dictionary = {}
var previous_elbows: Dictionary = {}
var candidate_poses: Dictionary = {}
var elbow_relaxation: float = 0.0
const BLEND_SAMPLES: int = 17
const STROKE_SAMPLES: int = 17
var pose_cache: Array = []
var cached_elbows: Array[Vector3] = []
var cached_clearance: Array[float] = []
var solved_clearance: Array[float] = [0.0, 0.0]
var propulsion_phase: float = 0.0
var pose_skin_queries: int = 0
var bake_elbows: Array[Vector3] = []
var fitting: bool = true
var loaded_baked_pose: bool = false

var chair: Node3D
var rider: Node3D
var skeleton: Skeleton3D
var rear_wheels: Array[Node3D] = []
var front_wheels: Array[Node3D] = []
var front_forks: Array[Node3D] = []
var seat_anchor: Marker3D
var foot_anchors: Array[Marker3D] = []
var hand_anchors: Array[Marker3D] = []
var push_weight: float = 0.0
var manual_pose_weight: float = 1.0
var idle_time: float = 0.0
var rear_angle: float = 0.0
var caster_angle: float = 0.0
var bone_ids: Dictionary = {}
var rest_poses: Array[Transform3D] = []


func _ready() -> void:
	assert(seating.validate(), "Chair requires a valid seating profile")
	chair = seating.model.instantiate()
	chair.transform = seating.model_transform
	add_child(chair)
	seat_frame = seating.resolve_seat(chair)
	usable_size = seating.resolve_size(chair)
	for part_name in seating.rear_wheels:
		rear_wheels.append(chair.get_node(part_name))
	rear_radius = _wheel_radius(rear_wheels[0])
	for index in range(seating.casters.size()):
		var wheel: Node3D = chair.get_node(seating.casters[index])
		var fork_mesh: Node3D = chair.get_node(seating.forks[index])
		var fork := Node3D.new()
		fork.name = str(wheel.name) + "Steering"
		fork.position = fork_mesh.position
		chair.add_child(fork)
		wheel.reparent(fork)
		fork_mesh.reparent(fork)
		front_forks.append(fork)
		front_wheels.append(wheel)
		caster_radius = _wheel_radius(wheel)
	rider = RiderScene.instantiate()
	rider.name = "Rider"
	rider.basis = seat_frame.basis * Basis(Vector3.UP, PI).scaled(Vector3.ONE * seating.rider_scale)
	add_child(rider)
	rider_mesh = rider.find_child("char1", true, false) as MeshInstance3D
	rider_mesh.mesh = RiderMesh
	skeleton = rider.find_child("Skeleton3D", true, false) as Skeleton3D
	assert(skeleton != null, "Rider requires the imported humanoid skeleton")
	for animation in rider.find_children("*", "AnimationPlayer", true, false):
		animation.stop()
		animation.active = false
	for bone in range(skeleton.get_bone_count()):
		bone_ids[skeleton.get_bone_name(bone)] = bone
		rest_poses.append(skeleton.get_bone_global_rest(bone))
	_measure_rider()
	seat_anchor = _anchor("PelvisTarget", seat_frame * Vector3(0.0, usable_size.y * 0.35, 0.0))
	for index in range(2):
		foot_anchors.append(_anchor("FootLeft" if index == 0 else "FootRight", seat_frame * (seating.foot_supports[index] + sole_offsets[index])))
		hand_anchors.append(_anchor("HandLeft" if index == 0 else "HandRight", Vector3.ZERO))
		var wheel: MeshInstance3D = rear_wheels[index]
		var bounds: AABB = wheel.get_aabb()
		var wheel_bounds: AABB = seat_frame.affine_inverse() * (global_transform.affine_inverse() * wheel.global_transform) * bounds
		var contact: Vector3 = wheel_bounds.get_center()
		contact.x = wheel_bounds.position.x if index == 0 else wheel_bounds.end.x
		wheel_contacts.append(contact)
		manual_offsets.append(Vector3.ZERO)
		supported_offsets.append(Vector3.ZERO)
		if seating.generate_footplates:
			_add_foot_support(index)
	if _load_baked_pose():
		return
	update_pose(0.0, false, false, false)
	for index in range(2):
		var prefix: String = "Left" if index == 0 else "Right"
		var side: float = -1.0 if index == 0 else 1.0
		var wrist: Vector3 = seat_frame.affine_inverse() * bone_position(prefix + "Hand")
		var inward: float = INF
		var bottom: float = INF
		for point in body_points(prefix + "Hand"):
			inward = minf(inward, side * (point.x - wrist.x))
			bottom = minf(bottom, point.y - wrist.y)
		manual_offsets[index] = Vector3(side * (seating.clearance - inward), -bottom + seating.clearance, 0.0)
	manual_pose_weight = 0.0
	update_pose(0.0, false, false, true)
	for index in range(2):
		var prefix: String = "Left" if index == 0 else "Right"
		var wrist: Vector3 = seat_frame.affine_inverse() * bone_position(prefix + "Hand")
		var points: PackedVector3Array = body_points(prefix + "Hand")
		var bounds := AABB(points[0] - wrist, Vector3.ZERO)
		for point in points:
			bounds = bounds.expand(point - wrist)
		supported_offsets[index] = Vector3(-bounds.get_center().x, seating.clearance - bounds.position.y, -bounds.get_center().z)
	manual_pose_weight = 1.0
	fit_seating()
	if not fit_conflicts.is_empty():
		push_warning("Incompatible seating constraints: " + "; ".join(fit_conflicts))


func _pose_signature() -> String:
	var values: Array = []
	for property in seating.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.usage & PROPERTY_USAGE_STORAGE and property.name != "baked_pose_path":
			var value: Variant = seating.get(property.name)
			values.append(value.resource_path if value is Resource else value)
	for path in [get_script().resource_path, seating.get_script().resource_path, seating.model.resource_path, RiderScene.resource_path, RiderMesh.resource_path]:
		values.append(FileAccess.get_sha256(path))
	return var_to_str(values).sha256_text()


func save_baked_pose(path: String) -> Error:
	if not fit_conflicts.is_empty() or pose_cache.is_empty():
		return ERR_INVALID_DATA
	var resource := Resource.new()
	resource.set_meta("signature", _pose_signature())
	resource.set_meta("pose_cache", pose_cache)
	resource.set_meta("pelvis", seat_anchor.position)
	resource.set_meta("torso_recline", torso_recline)
	resource.set_meta("manual_offsets", manual_offsets)
	resource.set_meta("supported_offsets", supported_offsets)
	resource.set_meta("fit_error", fit_error)
	return ResourceSaver.save(resource, path)


func _load_baked_pose() -> bool:
	if seating.baked_pose_path.is_empty() or not FileAccess.file_exists(seating.baked_pose_path):
		return false
	var resource: Resource = load(seating.baked_pose_path)
	if resource == null or resource.get_meta("signature", "") != _pose_signature():
		return false
	var samples: Array = resource.get_meta("pose_cache", [])
	if samples.size() != BLEND_SAMPLES * STROKE_SAMPLES:
		return false
	pose_cache = samples
	seat_anchor.position = resource.get_meta("pelvis")
	torso_recline = resource.get_meta("torso_recline")
	manual_offsets.assign(resource.get_meta("manual_offsets"))
	supported_offsets.assign(resource.get_meta("supported_offsets"))
	fit_error = resource.get_meta("fit_error")
	fitting = false
	loaded_baked_pose = true
	update_pose(0.0, false, false, false)
	return true


func _fit_support() -> void:
	for iteration in range(8):
		if "LeftFoot target exceeds anatomical reach" in reach_failures or "RightFoot target exceeds anatomical reach" in reach_failures:
			fit_error = INF
			return
		var lowest: float = _lowest_seated_skin()
		if not is_finite(lowest):
			break
		var correction: float = seating.clearance - lowest
		if absf(correction) < 0.002:
			break
		seat_anchor.position += seat_frame.basis.y * clampf(correction, -0.05, 0.05)
		update_pose(0.0, false, false, false)
	fit_error = absf(_lowest_seated_skin() - seating.clearance)


func fit_seating() -> void:
	fitting = true
	pose_cache.clear()
	fit_conflicts.clear()
	var initial: Vector3 = seat_anchor.position
	var best: Vector3 = initial
	var best_penalty: float = INF
	for step in range(17):
		var depth: float = (1.0 - float(step) / 8.0) * usable_size.y * 0.3
		seat_anchor.position = seat_frame * Vector3(0.0, (seat_frame.affine_inverse() * initial).y, depth)
		update_pose(0.0, false, false, false)
		_fit_support()
		var collisions: int = leg_intersections()
		var penalty: float = float(collisions) * 100.0 + (1000.0 if fit_error >= 0.005 else 0.0) + absf(depth)
		if penalty < best_penalty:
			best_penalty = penalty
			best = seat_anchor.position
		if collisions == 0 and fit_error < 0.005 and _fit_upper_reach():
			best = seat_anchor.position
			break
	seat_anchor.position = best
	update_pose(0.0, false, false, false)
	fit_error = absf(_lowest_seated_skin() - seating.clearance)
	if fit_error >= 0.005:
		fit_conflicts.append("Pelvis/thigh support cannot meet the seat surface")
	if leg_intersections() > 0:
		fit_conflicts.append("Legs intersect the seat or frame within the usable seat depth")
	for prefix in ["Left", "Right"]:
		var index: int = 0 if prefix == "Left" else 1
		if bone_position(prefix + "Foot").distance_to(foot_anchors[index].position) > seating.clearance:
			fit_conflicts.append(prefix + " foot support exceeds anatomical reach")
	fit_conflicts.append_array(reach_failures)
	if constraint_failures > 0:
		fit_conflicts.append("No armrest-clear elbow pose within the joint limits")
	if fit_conflicts.is_empty():
		_bake_pose_cache()
	fitting = false


func _bake_pose_cache() -> void:
	var samples: Array = []
	samples.resize(BLEND_SAMPLES * STROKE_SAMPLES)
	var saved_idle: bool = idle_enabled
	idle_enabled = false
	for blend_index in range(BLEND_SAMPLES):
		for stroke_index in range(STROKE_SAMPLES):
			bake_elbows.clear()
			if blend_index > 0:
				var neighbor: Array = samples[(blend_index - 1) * STROKE_SAMPLES + stroke_index]
				bake_elbows.assign([neighbor[0], neighbor[1]])
			manual_pose_weight = float(blend_index) / float(BLEND_SAMPLES - 1)
			push_weight = 1.0
			var stroke: float = lerpf(-1.0, 1.0, float(stroke_index) / float(STROKE_SAMPLES - 1))
			propulsion_phase = asin(stroke)
			update_pose(0.0, true, true, false)
			if constraint_failures > 0 or not reach_failures.is_empty():
				fit_conflicts.append("Animation sample cannot satisfy arm clearance/reach: %d/%d" % [blend_index, stroke_index])
				bake_elbows.clear()
				idle_enabled = saved_idle
				return
			samples[blend_index * STROKE_SAMPLES + stroke_index] = [bone_position("LeftForeArm"), bone_position("RightForeArm"), solved_clearance.duplicate()]
	pose_cache = samples
	bake_elbows.clear()
	idle_enabled = saved_idle
	manual_pose_weight = 1.0
	push_weight = 0.0
	propulsion_phase = 0.0
	update_pose(0.0, false, false, false)


func _sample_pose_cache(stroke: float) -> void:
	var blend_coord: float = manual_pose_weight * float(BLEND_SAMPLES - 1)
	var stroke_coord: float = (stroke + 1.0) * 0.5 * float(STROKE_SAMPLES - 1)
	var blend_index: int = mini(int(blend_coord), BLEND_SAMPLES - 2)
	var stroke_index: int = mini(int(stroke_coord), STROKE_SAMPLES - 2)
	var blend_fraction: float = blend_coord - float(blend_index)
	var stroke_fraction: float = stroke_coord - float(stroke_index)
	var first: Array = pose_cache[blend_index * STROKE_SAMPLES + stroke_index]
	var second: Array = pose_cache[blend_index * STROKE_SAMPLES + stroke_index + 1]
	var third: Array = pose_cache[(blend_index + 1) * STROKE_SAMPLES + stroke_index]
	var fourth: Array = pose_cache[(blend_index + 1) * STROKE_SAMPLES + stroke_index + 1]
	cached_elbows.clear()
	cached_clearance.clear()
	for index in range(2):
		cached_elbows.append(first[index].lerp(second[index], stroke_fraction).lerp(third[index].lerp(fourth[index], stroke_fraction), blend_fraction))
		cached_clearance.append(lerpf(maxf(first[2][index], second[2][index]), maxf(third[2][index], fourth[2][index]), blend_fraction))


func _fit_upper_reach() -> bool:
	var saved_idle_time: float = idle_time
	for step in range(16):
		torso_recline = deg_to_rad(float(step))
		var feasible: bool = true
		for breath_phase in [-PI * 0.5, PI * 0.5]:
			idle_time = breath_phase / 1.4
			for phase_index in range(32):
				propulsion_phase = TAU * float(phase_index) / 32.0
				push_weight = 1.0
				manual_pose_weight = 1.0
				update_pose(0.0, true, true, false)
				feasible = feasible and reach_failures.is_empty() and constraint_failures == 0
			manual_pose_weight = 0.0
			push_weight = 0.0
			update_pose(0.0, false, false, true)
			feasible = feasible and reach_failures.is_empty() and constraint_failures == 0
		idle_time = saved_idle_time
		manual_pose_weight = 1.0
		propulsion_phase = 0.0
		update_pose(0.0, false, false, false)
		if feasible and reach_failures.is_empty() and constraint_failures == 0:
			return true
	return false


func leg_intersections() -> int:
	var seat_box := AABB(Vector3(-usable_size.x * 0.5, -seating.seat_thickness, -usable_size.y * 0.5), Vector3(usable_size.x, seating.seat_thickness, usable_size.y))
	var count: int = 0
	for point in body_points("legs"):
		if seat_box.grow(-0.001).has_point(point):
			count += 1
		for solid in seating.frame_solids:
			if solid.has_point(point):
				count += 1
	return count


func _wheel_radius(wheel: MeshInstance3D) -> float:
	var size: Vector3 = wheel.get_aabb().size * wheel.global_basis.get_scale().abs()
	return maxf(size.y, size.z) * 0.5


func _measure_rider() -> void:
	skin_arrays = rider_mesh.mesh.surface_get_arrays(0)
	for bind in range(rider_mesh.skin.get_bind_count()):
		var bone: int = rider_mesh.skin.get_bind_bone(bind)
		if bone < 0:
			bone = skeleton.find_bone(rider_mesh.skin.get_bind_name(bind))
		skin_bones.append(bone)
	for group in ["seat", "legs", "LeftFoot", "RightFoot", "LeftHand", "RightHand", "LeftArm", "RightArm", "LeftForeArm", "RightForeArm", "LeftArmSkin", "RightArmSkin", "body"]:
		body_groups[group] = []
	var vertices: PackedVector3Array = skin_arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = skin_arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = skin_arrays[Mesh.ARRAY_WEIGHTS]
	var influences: int = bones.size() / vertices.size()
	for vertex in range(vertices.size()):
		var strongest: float = 0.0
		var name: String = ""
		for influence in range(influences):
			var offset: int = vertex * influences + influence
			if weights[offset] > strongest:
				strongest = weights[offset]
				name = skeleton.get_bone_name(skin_bones[bones[offset]])
		if name == "Hips" or name.ends_with("UpLeg"):
			body_groups["seat"].append(vertex)
		if name.ends_with("Leg"):
			body_groups["legs"].append(vertex)
		for prefix in ["Left", "Right"]:
			if vertex % 8 == 0 and (name == prefix + "Arm" or name == prefix + "ForeArm" or name.begins_with(prefix + "Hand")):
				body_groups[prefix + "ArmSkin"].append(vertex)
			if name == prefix + "Arm" or name == prefix + "ForeArm":
				body_groups[name].append(vertex)
			if name.begins_with(prefix + "Foot") or name.begins_with(prefix + "Toe"):
				body_groups[prefix + "Foot"].append(vertex)
			if name.begins_with(prefix + "Hand"):
				body_groups[prefix + "Hand"].append(vertex)
		if vertex % 8 == 0:
			body_groups["body"].append(vertex)
	for prefix in ["Left", "Right"]:
		for segment in ["Arm", "ForeArm"]:
			var start: Vector3 = seat_frame.affine_inverse() * bone_position(prefix + segment)
			var finish: Vector3 = seat_frame.affine_inverse() * bone_position(prefix + ("ForeArm" if segment == "Arm" else "Hand"))
			var direction: Vector3 = finish - start
			var radii := PackedFloat32Array()
			radii.resize(9)
			radii.fill(seating.clearance)
			for point in body_points(prefix + segment):
				var fraction: float = clampf((point - start).dot(direction) / direction.length_squared(), 0.0, 1.0)
				var radius: float = point.distance_to(start + direction * fraction) + seating.clearance
				var lower: int = clampi(int(fraction * 8.0), 0, 8)
				radii[lower] = maxf(radii[lower], radius)
				var higher: int = mini(lower + 1, 8)
				radii[higher] = maxf(radii[higher], radius)
			arm_radii[prefix + segment] = radii
		var points: PackedVector3Array = body_points(prefix + "Foot")
		assert(not points.is_empty(), "Rider needs skinned foot geometry")
		var bounds := AABB(points[0], Vector3.ZERO)
		for point in points:
			bounds = bounds.expand(point)
		var sole := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
		sole_offsets.append(seat_frame.affine_inverse() * bone_position(prefix + "Foot") - sole)
		var index: int = 0 if prefix == "Left" else 1
		var size: Vector2 = seating.foot_sizes[index]
		if seating.generate_footplates:
			size = size.max(Vector2(bounds.size.x, bounds.size.z) + Vector2.ONE * seating.clearance * 2.0)
		foot_sizes.append(size)
		var wrist: Vector3 = seat_frame.affine_inverse() * bone_position(prefix + "Hand")
		for point in body_points(prefix + "Hand"):
			hand_length = maxf(hand_length, point.distance_to(wrist))


func body_points(group: String) -> PackedVector3Array:
	pose_skin_queries += 1
	var palette: Array[Transform3D] = []
	for bind in range(skin_bones.size()):
		palette.append(skeleton.get_bone_global_pose(skin_bones[bind]) * rider_mesh.skin.get_bind_pose(bind))
	var vertices: PackedVector3Array = skin_arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = skin_arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = skin_arrays[Mesh.ARRAY_WEIGHTS]
	var influences: int = bones.size() / vertices.size()
	var points := PackedVector3Array()
	var transform_to_seat: Transform3D = seat_frame.affine_inverse() * global_transform.affine_inverse() * skeleton.global_transform
	for vertex in body_groups[group]:
		var point := Vector3.ZERO
		for influence in range(influences):
			var offset: int = vertex * influences + influence
			point += (palette[bones[offset]] * vertices[vertex]) * weights[offset]
		points.append(transform_to_seat * point)
	return points


func _lowest_seated_skin() -> float:
	var lowest: float = INF
	for point in body_points("seat"):
		if absf(point.x) < usable_size.x * 0.5 and absf(point.z) < usable_size.y * 0.5:
			lowest = minf(lowest, point.y)
	return lowest


func _anchor(label: String, location: Vector3) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = label
	marker.position = location
	add_child(marker)
	return marker


func _add_foot_support(index: int) -> void:
	var side: float = -1.0 if index == 0 else 1.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("303b3e")
	material.metallic = 0.35
	material.roughness = 0.65
	var plate := MeshInstance3D.new()
	plate.name = "FootplateLeft" if side < 0.0 else "FootplateRight"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(foot_sizes[index].x, 0.035, foot_sizes[index].y)
	plate.mesh = mesh
	plate.material_override = material
	plate.position = seat_frame * (seating.foot_supports[index] - Vector3.UP * 0.0175)
	plate.basis = seat_frame.basis
	add_child(plate)
	var start: Vector3 = seat_frame * seating.foot_mounts[index]
	var finish: Vector3 = seat_frame * (seating.foot_supports[index] + Vector3(side * foot_sizes[index].x * 0.48, 0.0, 0.0))
	var tube := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.018
	cylinder.bottom_radius = 0.018
	cylinder.height = start.distance_to(finish)
	cylinder.radial_segments = 12
	tube.mesh = cylinder
	tube.material_override = material
	tube.position = (start + finish) * 0.5
	tube.quaternion = Quaternion(Vector3.UP, (finish - start).normalized())
	add_child(tube)


func update_wheels(distance: float, steering: float) -> void:
	rear_angle = wrapf(rear_angle + distance / rear_radius, -PI, PI)
	caster_angle = wrapf(caster_angle + distance / caster_radius, -PI, PI)
	for wheel in rear_wheels:
		wheel.rotation.x = rear_angle
	for wheel in front_wheels:
		wheel.rotation.x = caster_angle
	for fork in front_forks:
		fork.rotation.y = steering * 0.35


func reset_wheels() -> void:
	rear_angle = 0.0
	caster_angle = 0.0
	update_wheels(0.0, 0.0)


func bone_position(bone_name: String) -> Vector3:
	return to_local(skeleton.to_global(skeleton.get_bone_global_pose(bone_ids[bone_name]).origin))


func _set_global_pose(bone: int, pose: Transform3D) -> void:
	skeleton.set_bone_global_pose(bone, pose)


func _aim(bone_name: String, child_name: String, target: Vector3) -> void:
	var bone: int = bone_ids[bone_name]
	var pose: Transform3D = skeleton.get_bone_global_pose(bone)
	var child: Vector3 = skeleton.get_bone_global_pose(bone_ids[child_name]).origin
	var desired: Vector3 = skeleton.to_local(to_global(target)) - pose.origin
	var rotation := Quaternion((child - pose.origin).normalized(), desired.normalized())
	pose.basis = Basis(rotation) * pose.basis
	_set_global_pose(bone, pose)


func _arm_clear(prefix: String, origin: Vector3, joint: Vector3, length: float) -> bool:
	var inverse: Transform3D = seat_frame.affine_inverse()
	var shoulder: Vector3 = inverse * origin
	var elbow: Vector3 = inverse * joint
	var side: float = -1.0 if prefix == "Left" else 1.0
	if side * elbow.x < side * shoulder.x or elbow.y > shoulder.y - length * 0.35:
		return false
	if absf(elbow.x - shoulder.x) > length * sin(deg_to_rad(45.0)):
		return false
	var solids: Array[AABB] = seating.armrests.duplicate()
	solids.append_array(seating.frame_solids)
	if seating.back.has_volume():
		solids.append(seating.back)
	for point in body_points(prefix + "ArmSkin"):
		for solid in solids:
			if solid.grow(seating.clearance).has_point(point):
				return false
	return true


func _pose_arm_candidate(prefix: String, origin: Vector3, joint: Vector3, target: Vector3, length: float, fingers: Vector3, normal: Vector3) -> bool:
	_set_global_pose(bone_ids[prefix + "Arm"], candidate_poses[prefix + "Arm"])
	_set_global_pose(bone_ids[prefix + "ForeArm"], candidate_poses[prefix + "ForeArm"])
	_aim(prefix + "Arm", prefix + "ForeArm", joint)
	_aim(prefix + "ForeArm", prefix + "Hand", target)
	_orient_hand(prefix, bone_position(prefix + "Hand"), fingers, normal)
	return true if not pose_cache.is_empty() else _arm_clear(prefix, origin, joint, length)


func _limb(upper: String, lower: String, end: String, target: Vector3, pole: Vector3, fingers: Vector3 = Vector3.ZERO, normal: Vector3 = Vector3.ZERO) -> void:
	var origin: Vector3 = bone_position(upper)
	var upper_length: float = origin.distance_to(bone_position(lower))
	var lower_length: float = bone_position(lower).distance_to(bone_position(end))
	var direction: Vector3 = (target - origin).normalized()
	var minimum: float = sqrt(upper_length * upper_length + lower_length * lower_length + 2.0 * upper_length * lower_length * cos(deg_to_rad(145.0)))
	var maximum: float = sqrt(upper_length * upper_length + lower_length * lower_length + 2.0 * upper_length * lower_length * cos(deg_to_rad(8.0)))
	var distance: float = clampf(origin.distance_to(target), minimum, maximum)
	if absf(distance - origin.distance_to(target)) > seating.clearance:
		reach_failures.append(end + " target exceeds anatomical reach")
	var along: float = (upper_length * upper_length - lower_length * lower_length + distance * distance) / (2.0 * distance)
	var height: float = sqrt(maxf(upper_length * upper_length - along * along, 0.0))
	var prefix: String = upper.trim_suffix("Arm")
	var reference_bend: Vector3 = pole - origin
	reference_bend = (reference_bend - direction * reference_bend.dot(direction)).normalized()
	if not fingers.is_zero_approx():
		candidate_poses[upper] = skeleton.get_bone_global_pose(bone_ids[upper])
		candidate_poses[lower] = skeleton.get_bone_global_pose(bone_ids[lower])
		if not pose_cache.is_empty():
			pole = cached_elbows[0 if prefix == "Left" else 1]
		elif not bake_elbows.is_empty():
			pole = bake_elbows[0 if prefix == "Left" else 1]
		elif previous_elbows.has(prefix):
			pole = previous_elbows[prefix].lerp(pole, elbow_relaxation)
	var bend: Vector3 = pole - origin
	bend = (bend - direction * bend.dot(direction)).normalized()
	var joint: Vector3 = origin + direction * along + bend * height
	var end_target: Vector3 = origin + direction * distance
	if not fingers.is_zero_approx() and not _pose_arm_candidate(prefix, origin, joint, end_target, upper_length, fingers, normal):
		var found: bool = false
		var candidates: Array[Vector3] = []
		for step in range(72):
			var angle: float = float(step) * TAU / 72.0
			candidates.append(origin + direction * along + (Basis(direction, angle) * reference_bend) * height)
		candidates.sort_custom(func(first: Vector3, second: Vector3) -> bool: return first.distance_squared_to(joint) < second.distance_squared_to(joint))
		for candidate in candidates:
			if _pose_arm_candidate(prefix, origin, candidate, end_target, upper_length, fingers, normal):
				joint = candidate
				found = true
				break
		if not found:
			constraint_failures += 1
	if not fingers.is_zero_approx():
		_pose_arm_candidate(prefix, origin, joint, end_target, upper_length, fingers, normal)
	else:
		_aim(upper, lower, joint)
		_aim(lower, end, end_target)


func update_pose(delta: float, moving: bool, propelling: bool, motorized: bool) -> void:
	if skeleton == null or (not fitting and pose_cache.is_empty()):
		return
	previous_elbows.clear()
	elbow_relaxation = 1.0 - exp(-6.0 * delta)
	if delta > 0.0:
		for prefix in ["Left", "Right"]:
			previous_elbows[prefix] = bone_position(prefix + "ForeArm")
	constraint_failures = 0
	reach_failures.clear()
	idle_time += delta if idle_enabled else 0.0
	manual_pose_weight = move_toward(manual_pose_weight, 0.0 if motorized else 1.0, delta / 0.4)
	if manual_pose_weight > 0.0 and manual_pose_weight < 1.0:
		elbow_relaxation = 0.0
	var pose_blend: float = smoothstep(0.0, 1.0, manual_pose_weight)
	push_weight = move_toward(push_weight, 1.0 if moving and propelling and not motorized else 0.0, delta / 0.22)
	if moving and propelling and not motorized:
		propulsion_phase = wrapf(propulsion_phase + delta * TAU * 1.1, -PI, PI)
	var stroke: float = sin(propulsion_phase) * push_weight
	if not pose_cache.is_empty():
		_sample_pose_cache(stroke)
	skeleton.reset_bone_poses()
	var hips: int = bone_ids["Hips"]
	var pelvis: Transform3D = rest_poses[hips]
	pelvis.origin = skeleton.to_local(to_global(seat_anchor.position))
	_set_global_pose(hips, pelvis)
	var breath: float = 0.0
	var spine: Vector3 = bone_position("Spine02")
	var spine_direction: Vector3 = bone_position("Spine01") - spine
	_aim("Spine02", "Spine01", spine + Basis(seat_frame.basis.x, torso_recline * pose_blend) * spine_direction + seat_frame.basis * Vector3(0.0, 0.0, breath))
	for side_index in range(2):
		var side: float = -1.0 if side_index == 0 else 1.0
		var prefix: String = "Left" if side < 0.0 else "Right"
		var hip: Vector3 = seat_frame.affine_inverse() * bone_position(prefix + "UpLeg")
		_limb(prefix + "UpLeg", prefix + "Leg", prefix + "Foot", foot_anchors[side_index].position, seat_frame * (hip + Vector3(0.0, 0.0, -2.0)))
		var foot: int = bone_ids[prefix + "Foot"]
		var foot_pose: Transform3D = skeleton.get_bone_global_pose(foot)
		foot_pose.basis = rest_poses[foot].basis
		_set_global_pose(foot, foot_pose)
		var shoulder: Vector3 = seat_frame.affine_inverse() * bone_position(prefix + "Arm")
		var hand_target := Vector3(side * usable_size.x * 0.3, 0.20, -usable_size.y * 0.2)
		if not seating.armrests.is_empty():
			var support: AABB = seating.armrests[side_index]
			hand_target = Vector3(support.get_center().x, support.end.y, support.get_center().z) + supported_offsets[side_index]
		if not seating.controls.is_empty():
			hand_target = seating.controls[side_index].origin
		var push: float = 0.30 + stroke * 0.22
		var radius: float = seating.handrim_radius if seating.handrim_radius > 0.0 else rear_radius * 0.92
		var manual_target: Vector3 = wheel_contacts[side_index] + Vector3(0.0, cos(push) * radius, -sin(push) * radius) + manual_offsets[side_index]
		manual_target.y += maxf(0.0, -stroke) * 0.035
		hand_target = hand_target.lerp(manual_target, pose_blend)
		hand_target.y += sin(PI * pose_blend) * hand_length
		for solid in seating.frame_solids:
			hand_target = SeatingProfile.outside_box(hand_target, solid, 0.055, 1)
		var supported_direction := Vector3(0.0, -0.035, -0.16)
		if not seating.controls.is_empty():
			supported_direction = -seating.controls[side_index].basis.z * 0.16
		var fingers: Vector3 = seat_frame.basis * supported_direction.lerp(Vector3(side * 0.01, -0.18, -0.025), pose_blend)
		var normal: Vector3 = Vector3.DOWN.lerp(Vector3(-side, 0.0, 0.0), pose_blend)
		if not seating.controls.is_empty():
			normal = (-seating.controls[side_index].basis.y).lerp(Vector3(-side, 0.0, 0.0), pose_blend)
		var lateral_correction: float = 0.0
		if not pose_cache.is_empty():
			lateral_correction = cached_clearance[side_index]
		else:
			_orient_hand(prefix, bone_position(prefix + "Hand"), fingers, seat_frame.basis * normal)
			var wrist_in_seat: Vector3 = seat_frame.affine_inverse() * bone_position(prefix + "Hand")
			for point in body_points(prefix + "Hand"):
				var relative: Vector3 = point - wrist_in_seat + hand_target - wheel_contacts[side_index]
				if Vector2(relative.y, relative.z).length() < rear_radius + seating.clearance:
					lateral_correction = maxf(lateral_correction, seating.clearance - side * relative.x)
		solved_clearance[side_index] = lateral_correction
		hand_target.x += side * lateral_correction
		hand_anchors[side_index].position = seat_frame * hand_target
		_limb(prefix + "Arm", prefix + "ForeArm", prefix + "Hand", hand_anchors[side_index].position, seat_frame * (shoulder + Vector3(side * 0.03, -0.65, -0.08)), fingers, seat_frame.basis * normal)
		if pose_cache.is_empty():
			for correction_step in range(2):
				var surface_correction: float = 0.0
				for point in body_points(prefix + "Hand"):
					var relative: Vector3 = point - wheel_contacts[side_index]
					if Vector2(relative.y, relative.z).length() < rear_radius + seating.clearance:
						surface_correction = maxf(surface_correction, seating.clearance - side * relative.x)
				if surface_correction < 0.0001:
					break
				solved_clearance[side_index] += surface_correction
				hand_target.x += side * surface_correction
				hand_anchors[side_index].position = seat_frame * hand_target
				_limb(prefix + "Arm", prefix + "ForeArm", prefix + "Hand", hand_anchors[side_index].position, seat_frame * (shoulder + Vector3(side * 0.03, -0.65, -0.08)), fingers, seat_frame.basis * normal)


func _orient_hand(prefix: String, wrist: Vector3, fingers: Vector3, normal: Vector3) -> void:
	var hand: int = bone_ids[prefix + "Hand"]
	var hand_pose: Transform3D = skeleton.get_bone_global_pose(hand)
	hand_pose.basis = rest_poses[hand].basis
	_set_global_pose(hand, hand_pose)
	_aim(prefix + "Hand", prefix + "HandMiddle1", wrist + fingers)
	var palm: Vector3 = (bone_position(prefix + "HandIndex1") - wrist).cross(bone_position(prefix + "HandPinky1") - wrist)
	if prefix == "Left":
		palm = -palm
	var direction: Vector3 = fingers.normalized()
	palm = (palm - direction * palm.dot(direction)).normalized()
	var desired: Vector3 = (normal - direction * normal.dot(direction)).normalized()
	var angle: float = palm.signed_angle_to(desired, direction)
	var axis: Vector3 = (skeleton.global_basis.inverse() * global_basis * direction).normalized()
	hand_pose = skeleton.get_bone_global_pose(hand)
	hand_pose.basis = Basis(axis, angle) * hand_pose.basis
	_set_global_pose(hand, hand_pose)