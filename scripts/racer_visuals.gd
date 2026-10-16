extends Node3D

const ChairScene = preload("res://assets/wheelchair/chair_prepared.scn")
const RiderScene = preload("res://assets/rider/man-rigged.glb")
const RiderMesh = preload("res://assets/rider/rider_mesh.res")
const CHAIR_SCALE: float = 1.4
const REAR_RADIUS: float = 0.3373 * CHAIR_SCALE
const CASTER_RADIUS: float = 0.0983 * CHAIR_SCALE

@export var idle_enabled: bool = true
@export var seat_position := Vector3(0.0, 0.99, -0.10)
@export var foot_position := Vector3(0.23, 0.35, -0.78)

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
var idle_time: float = 0.0
var rear_angle: float = 0.0
var caster_angle: float = 0.0
var bone_ids: Dictionary = {}
var rest_poses: Array[Transform3D] = []


func _ready() -> void:
	chair = ChairScene.instantiate()
	chair.rotation.y = PI
	chair.scale = Vector3.ONE * CHAIR_SCALE
	chair.position.z = 0.12 - 0.1484 * CHAIR_SCALE
	add_child(chair)
	for part_name in ["RearLeft", "RearRight"]:
		rear_wheels.append(chair.get_node(part_name))
	for part_name in ["CasterLeft", "CasterRight"]:
		var wheel: Node3D = chair.get_node(part_name)
		var fork_mesh: Node3D = chair.get_node(part_name.replace("Caster", "Fork"))
		var fork := Node3D.new()
		fork.name = part_name + "Steering"
		fork.position = fork_mesh.position
		chair.add_child(fork)
		wheel.reparent(fork)
		fork_mesh.reparent(fork)
		front_forks.append(fork)
		front_wheels.append(wheel)
	rider = RiderScene.instantiate()
	rider.name = "Rider"
	rider.rotation.y = PI
	rider.scale = Vector3.ONE * 1.4
	add_child(rider)
	(rider.find_child("char1", true, false) as MeshInstance3D).mesh = RiderMesh
	skeleton = rider.find_child("Skeleton3D", true, false) as Skeleton3D
	assert(skeleton != null, "Rider requires the imported humanoid skeleton")
	for animation in rider.find_children("*", "AnimationPlayer", true, false):
		animation.stop()
		animation.active = false
	for bone in range(skeleton.get_bone_count()):
		bone_ids[skeleton.get_bone_name(bone)] = bone
		rest_poses.append(skeleton.get_bone_global_rest(bone))
	seat_anchor = _anchor("SeatContact", seat_position)
	for side in [-1.0, 1.0]:
		foot_anchors.append(_anchor("FootLeft" if side < 0.0 else "FootRight", Vector3(side * foot_position.x, foot_position.y, foot_position.z)))
		hand_anchors.append(_anchor("HandLeft" if side < 0.0 else "HandRight", Vector3(side * 0.39, 1.36, -0.43)))
		_add_foot_support(side)
	update_pose(0.0, false, false, false)


func _anchor(label: String, location: Vector3) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = label
	marker.position = location
	add_child(marker)
	return marker


func _add_foot_support(side: float) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("303b3e")
	material.metallic = 0.35
	material.roughness = 0.65
	var plate := MeshInstance3D.new()
	plate.name = "FootplateLeft" if side < 0.0 else "FootplateRight"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.29, 0.035, 0.36)
	plate.mesh = mesh
	plate.material_override = material
	plate.position = Vector3(side * foot_position.x, 0.16, foot_position.z - 0.025)
	add_child(plate)
	var start := Vector3(side * 0.37, 0.66, -0.64)
	var finish := Vector3(side * 0.37, 0.18, -0.79)
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
	rear_angle = wrapf(rear_angle + distance / REAR_RADIUS, -PI, PI)
	caster_angle = wrapf(caster_angle + distance / CASTER_RADIUS, -PI, PI)
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


func _limb(upper: String, lower: String, end: String, target: Vector3, pole: Vector3) -> void:
	var origin: Vector3 = bone_position(upper)
	var upper_length: float = origin.distance_to(bone_position(lower))
	var lower_length: float = bone_position(lower).distance_to(bone_position(end))
	var direction: Vector3 = (target - origin).normalized()
	var distance: float = clampf(origin.distance_to(target), absf(upper_length - lower_length) + 0.001, upper_length + lower_length - 0.001)
	var along: float = (upper_length * upper_length - lower_length * lower_length + distance * distance) / (2.0 * distance)
	var height: float = sqrt(maxf(upper_length * upper_length - along * along, 0.0))
	var bend: Vector3 = pole - origin
	bend = (bend - direction * bend.dot(direction)).normalized()
	var joint: Vector3 = origin + direction * along + bend * height
	_aim(upper, lower, joint)
	_aim(lower, end, origin + direction * distance)


func update_pose(delta: float, moving: bool, propelling: bool, motorized: bool) -> void:
	if skeleton == null:
		return
	idle_time += delta if idle_enabled else 0.0
	push_weight = move_toward(push_weight, 1.0 if moving and propelling and not motorized else 0.0, delta / 0.22)
	skeleton.reset_bone_poses()
	var hips: int = bone_ids["Hips"]
	var pelvis: Transform3D = rest_poses[hips]
	pelvis.origin = skeleton.to_local(to_global(seat_anchor.position))
	_set_global_pose(hips, pelvis)
	var breath: float = sin(idle_time * 1.4) * 0.003 if idle_enabled else 0.0
	var chest: Vector3 = bone_position("Spine")
	_aim("Spine02", "Spine01", bone_position("Spine01") + Vector3(0.0, 0.0, breath - 0.025 * push_weight))
	for side_index in range(2):
		var side: float = -1.0 if side_index == 0 else 1.0
		var prefix: String = "Left" if side < 0.0 else "Right"
		_limb(prefix + "UpLeg", prefix + "Leg", prefix + "Foot", foot_anchors[side_index].position, Vector3(side * 0.25, 1.0, -2.0))
		var foot: int = bone_ids[prefix + "Foot"]
		var foot_pose: Transform3D = skeleton.get_bone_global_pose(foot)
		foot_pose.basis = rest_poses[foot].basis
		_set_global_pose(foot, foot_pose)
		var hand_target := Vector3(side * 0.39, 1.36, -0.43)
		if not motorized:
			var phase: float = fposmod(rear_angle, TAU)
			var push: float = sin(phase) * 0.35 * push_weight
			hand_target = Vector3(side * 0.558, 0.5803 + cos(push) * 0.435, 0.12 - sin(push) * 0.435)
			hand_target.y += maxf(0.0, -sin(phase)) * 0.07 * push_weight
		hand_anchors[side_index].position = hand_target
		_limb(prefix + "Arm", prefix + "ForeArm", prefix + "Hand", hand_target, Vector3(side * 0.7, chest.y - 0.2, 0.18))
		var wrist: Vector3 = bone_position(prefix + "Hand")
		var fingers: Vector3 = Vector3(side * 0.01, -0.035, -0.16) if motorized else Vector3(side * 0.025, -0.14, -0.025)
		_aim(prefix + "Hand", prefix + "HandMiddle1", wrist + fingers)
		if motorized:
			var hand: int = bone_ids[prefix + "Hand"]
			var hand_pose: Transform3D = skeleton.get_bone_global_pose(hand)
			var axis: Vector3 = (skeleton.global_basis.inverse() * global_basis * fingers).normalized()
			hand_pose.basis = Basis(axis, -side * PI * 0.5) * hand_pose.basis
			_set_global_pose(hand, hand_pose)