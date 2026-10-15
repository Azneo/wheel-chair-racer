extends CharacterBody3D

signal respawned

const EngineVisualFactory = preload("res://scripts/engine_visuals.gd")
const BRAKING: float = 24.0
const ROLLING_RESISTANCE: float = 3.0
const STEERING_SPEED: float = 1.8
const WHEEL_RADIUS: float = 0.53
const PUSH_STROKE_ANGLE: float = 0.68
const PUSH_HAND_ANGLE: float = -0.12

var MAX_SPEED: float:
	get:
		return float(get_node("/root/PlayerUpgrades").get("max_speed_kmh")) / 3.6
var ACCELERATION: float:
	get:
		return float(get_node("/root/PlayerUpgrades").get("acceleration_kmh_per_second")) / 3.6
var speed: float = 0.0
var spawn_transform: Transform3D = Transform3D.IDENTITY
var recovery_transform: Transform3D = Transform3D.IDENTITY
var driving_enabled: bool = true
var rear_wheels: Array[Node3D] = []
var front_forks: Array[Node3D] = []
var engine_mount: Node3D
var installed_engine: Node3D
var installed_engine_id: String = ""
var pending_engine_visual_id: String = ""
var engine_change_tween: Tween
var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var wheel_roll_angle: float = 0.0
var rider_root: Node3D
var rider_upper_body: Node3D
var rider_pelvis: MeshInstance3D
var seat_cushion: MeshInstance3D
var footrest: MeshInstance3D
var foot_nodes: Array[MeshInstance3D] = []
var thigh_segments: Array[MeshInstance3D] = []
var lower_leg_segments: Array[MeshInstance3D] = []
var arm_segments: Array[Array] = []
var arm_hand_nodes: Array[MeshInstance3D] = []
var arm_sides: Array[float] = []
var drive_pose_weight: float = 0.0


func _ready() -> void:
	spawn_transform = global_transform
	recovery_transform = spawn_transform
	floor_snap_length = 0.3
	safe_margin = 0.02
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.42, 1.95, 1.55)
	collider.shape = shape
	collider.position = Vector3(0.0, 1.0, -0.10)
	add_child(collider)
	_build_model()


func _physics_process(delta: float) -> void:
	if not driving_enabled:
		velocity = Vector3.ZERO
		speed = 0.0
		return
	if Input.is_action_just_pressed("reset") or global_position.y < -8.0:
		reset_to_checkpoint()
		return

	if Input.is_action_pressed("brake"):
		if speed > 0.0:
			speed = move_toward(speed, 0.0, BRAKING * delta)
		else:
			speed = move_toward(speed, -MAX_SPEED * 0.25, ACCELERATION * delta)
	elif Input.is_action_pressed("accelerate"):
		speed = move_toward(speed, MAX_SPEED, ACCELERATION * delta)
	else:
		speed = move_toward(speed, 0.0, ROLLING_RESISTANCE * delta)

	var steering: float = Input.get_axis("steer_right", "steer_left")
	var turn_scale: float = lerpf(1.0, 0.62, absf(speed) / MAX_SPEED)
	if absf(speed) > 0.15:
		rotate_y(steering * STEERING_SPEED * turn_scale * signf(speed) * delta)

	var forward: Vector3 = -global_basis.z
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= gravity * delta
	move_and_slide()
	speed = clampf(
		Vector3(velocity.x, 0.0, velocity.z).dot(forward),
		-MAX_SPEED * 0.25,
		MAX_SPEED
	)

	var wheel_delta: float = -speed * delta / WHEEL_RADIUS
	wheel_roll_angle += wheel_delta
	for wheel in rear_wheels:
		wheel.rotate_x(wheel_delta)
	for fork in front_forks:
		fork.rotation.y = steering * 0.35


func _process(delta: float) -> void:
	if not is_instance_valid(rider_upper_body):
		return
	var target_weight: float = 1.0 if driving_enabled and absf(speed) > 0.15 else 0.0
	drive_pose_weight = move_toward(drive_pose_weight, target_weight, delta / 0.22)
	var blend: float = smoothstep(0.0, 1.0, drive_pose_weight)
	var phase: float = fposmod(absf(wheel_roll_angle), TAU)
	var breathing: float = sin(float(Time.get_ticks_msec()) * 0.0014) * 0.0025
	var push_bob: float = sin(phase) * 0.006 * blend
	rider_upper_body.position = Vector3(0.0, breathing + push_bob, 0.12 - 0.015 * blend)
	_update_rider_pose()


func reset_to_start() -> void:
	_respawn(spawn_transform)


func reset_to_checkpoint() -> void:
	_respawn(recovery_transform)


func install_engine(visual_id: String, animate: bool = true) -> void:
	if visual_id == installed_engine_id and (engine_change_tween == null or not engine_change_tween.is_running()):
		return
	if visual_id == pending_engine_visual_id and engine_change_tween != null and engine_change_tween.is_running():
		return
	pending_engine_visual_id = visual_id
	if engine_change_tween != null and engine_change_tween.is_running():
		engine_change_tween.kill()
	if is_instance_valid(installed_engine) and animate:
		engine_change_tween = create_tween()
		engine_change_tween.set_trans(Tween.TRANS_CUBIC)
		engine_change_tween.set_ease(Tween.EASE_IN)
		engine_change_tween.set_parallel(true)
		engine_change_tween.tween_property(installed_engine, "scale", Vector3.ZERO, 0.14)
		engine_change_tween.tween_property(installed_engine, "position", Vector3(0.0, -0.08, 0.0), 0.14)
		engine_change_tween.set_parallel(false)
		engine_change_tween.tween_callback(_replace_installed_engine)
		return
	if is_instance_valid(installed_engine):
		installed_engine.free()
	installed_engine = null
	installed_engine_id = ""
	_spawn_pending_engine(animate)


func _replace_installed_engine() -> void:
	if is_instance_valid(installed_engine):
		installed_engine.free()
	installed_engine = null
	installed_engine_id = ""
	_spawn_pending_engine(true)


func _spawn_pending_engine(animate: bool) -> void:
	if pending_engine_visual_id.is_empty():
		return
	var engine: Node3D = EngineVisualFactory.create_engine(pending_engine_visual_id)
	if engine == null:
		return
	engine_mount.add_child(engine)
	installed_engine = engine
	installed_engine_id = pending_engine_visual_id
	if animate:
		engine.position = Vector3(0.0, -0.08, 0.0)
		engine.scale = Vector3.ONE * 0.82
		engine_change_tween = create_tween()
		engine_change_tween.set_trans(Tween.TRANS_BACK)
		engine_change_tween.set_ease(Tween.EASE_OUT)
		engine_change_tween.set_parallel(true)
		engine_change_tween.tween_property(engine, "scale", Vector3.ONE, 0.18)
		engine_change_tween.tween_property(engine, "position", Vector3.ZERO, 0.18)
		engine_change_tween.set_parallel(false)
	else:
		engine.scale = Vector3.ONE


func _respawn(target: Transform3D) -> void:
	global_transform = target
	velocity = Vector3.ZERO
	speed = 0.0
	wheel_roll_angle = 0.0
	for wheel in rear_wheels:
		wheel.rotation = Vector3.ZERO
	for fork in front_forks:
		fork.rotation = Vector3.ZERO
	_update_rider_pose()
	respawned.emit()


func _material(color: Color, metallic: float = 0.0, roughness: float = 0.65) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _mesh(parent: Node3D, mesh: Mesh, location: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = location
	parent.add_child(instance)
	return instance


func _box(size: Vector3, location: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent if parent != null else self, mesh, location, material)


func _tube(start: Vector3, finish: Vector3, radius: float, material: Material, parent: Node3D = null) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = start.distance_to(finish)
	mesh.radial_segments = 12
	var instance := _mesh(parent if parent != null else self, mesh, (start + finish) * 0.5, material)
	instance.quaternion = Quaternion(Vector3.UP, (finish - start).normalized())


func _oval(
	location: Vector3,
	radius: float,
	height: float,
	scale: Vector3,
	material: Material,
	parent: Node3D = null
) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 12
	var instance := _mesh(parent if parent != null else self, mesh, location, material)
	instance.scale = scale
	return instance


func _capsule_between(
	start: Vector3,
	finish: Vector3,
	radius: float,
	material: Material,
	parent: Node3D = null
) -> MeshInstance3D:
	var direction: Vector3 = finish - start
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(direction.length(), radius * 2.0)
	mesh.radial_segments = 20
	mesh.rings = 8
	var instance := _mesh(parent if parent != null else self, mesh, (start + finish) * 0.5, material)
	instance.quaternion = Quaternion(Vector3.UP, direction.normalized())
	return instance


func _move_capsule_between(instance: MeshInstance3D, start: Vector3, finish: Vector3) -> void:
	var direction: Vector3 = finish - start
	var mesh := instance.mesh as CapsuleMesh
	var base_height: float = float(instance.get_meta("pose_base_height", mesh.height))
	instance.position = (start + finish) * 0.5
	instance.quaternion = Quaternion(Vector3.UP, direction.normalized())
	instance.scale.y = direction.length() / base_height


func _handrim_position(side: float, angle: float) -> Vector3:
	var radius: float = 0.415
	var wheel_center := Vector3(side * 0.61, 0.55, 0.12)
	var position := Vector3(
		side * 0.665,
		wheel_center.y + cos(angle) * radius,
		wheel_center.z + sin(angle) * radius
	)
	return position - rider_upper_body.position


func _solve_elbow(shoulder: Vector3, wrist: Vector3, side: float) -> Vector3:
	const UPPER_ARM_LENGTH: float = 0.40
	const FOREARM_LENGTH: float = 0.44
	var arm_direction: Vector3 = wrist - shoulder
	var distance: float = clampf(
		arm_direction.length(),
		absf(UPPER_ARM_LENGTH - FOREARM_LENGTH) + 0.001,
		UPPER_ARM_LENGTH + FOREARM_LENGTH - 0.001
	)
	arm_direction /= maxf(arm_direction.length(), 0.001)
	var bend_axis := Vector3(0.0, 0.0, 1.0)
	var bend_direction: Vector3 = bend_axis - arm_direction * bend_axis.dot(arm_direction)
	if bend_direction.length_squared() < 0.001:
		bend_axis = Vector3(side, 0.0, 0.0)
		bend_direction = bend_axis - arm_direction * bend_axis.dot(arm_direction)
	bend_direction = bend_direction.normalized()
	var along: float = (
		UPPER_ARM_LENGTH * UPPER_ARM_LENGTH
		- FOREARM_LENGTH * FOREARM_LENGTH
		+ distance * distance
	) / (2.0 * distance)
	var bend: float = sqrt(maxf(UPPER_ARM_LENGTH * UPPER_ARM_LENGTH - along * along, 0.0))
	return shoulder + arm_direction * along + bend_direction * bend


func _update_rider_pose() -> void:
	if arm_segments.is_empty() or not is_instance_valid(rider_upper_body):
		return
	var phase: float = fposmod(absf(wheel_roll_angle), TAU)
	var contact_fraction: float = PUSH_STROKE_ANGLE / TAU
	var stroke_direction: float = 1.0 if wheel_roll_angle > 0.0 else -1.0
	var blend: float = smoothstep(0.0, 1.0, drive_pose_weight)
	for arm_index in range(arm_segments.size()):
		var side: float = arm_sides[arm_index]
		var rest_hand: Vector3 = _handrim_position(side, PUSH_HAND_ANGLE)
		var moving_hand: Vector3
		if phase / TAU < contact_fraction:
			moving_hand = _handrim_position(
				side,
				PUSH_HAND_ANGLE + stroke_direction * phase
			)
		else:
			var return_progress: float = (phase / TAU - contact_fraction) / (1.0 - contact_fraction)
			var stroke_end: Vector3 = _handrim_position(
				side,
				PUSH_HAND_ANGLE + stroke_direction * PUSH_STROKE_ANGLE
			)
			var lift_position := Vector3(side * 0.665, 1.08, -0.02) - rider_upper_body.position
			if return_progress < 0.5:
				moving_hand = stroke_end.lerp(lift_position, smoothstep(0.0, 1.0, return_progress * 2.0))
			else:
				moving_hand = lift_position.lerp(
					rest_hand,
					smoothstep(0.0, 1.0, (return_progress - 0.5) * 2.0)
				)
		var hand: Vector3 = rest_hand.lerp(moving_hand, blend)
		var shoulder := Vector3(side * 0.235, 1.47, 0.015)
		var elbow: Vector3 = _solve_elbow(shoulder, hand, side)
		_move_capsule_between(arm_segments[arm_index][0], shoulder, elbow)
		_move_capsule_between(arm_segments[arm_index][1], elbow, hand)
		arm_hand_nodes[arm_index].position = hand


func _build_model() -> void:
	var frame := _material(Color("297f7b"), 0.5, 0.3)
	var rubber := _material(Color("15191c"), 0.0, 0.96)
	var cushion := _material(Color("364c52"), 0.0, 0.88)
	var metal := _material(Color("bfcace"), 0.8, 0.27)
	var shirt := _material(Color("c77e3d"), 0.0, 0.9)
	var shirt_trim := _material(Color("efd5a1"), 0.0, 0.78)
	var trousers := _material(Color("303f4b"))
	var skin := _material(Color("b87954"))
	var face_detail := _material(Color("422d29"))
	var eyes := _material(Color("f0e7d8"))
	var helmet := _material(Color("e3e9df"), 0.0, 0.32)
	var helmet_trim := _material(Color("297f7b"), 0.25, 0.3)
	var glasses := _material(Color("214149"), 0.35, 0.2)
	var badge := _material(Color("e7d9b6"), 0.0, 0.78)
	var shoes := _material(Color("29353a"), 0.0, 0.82)
	var fabric_noise := FastNoiseLite.new()
	fabric_noise.seed = 11
	fabric_noise.frequency = 0.4
	var fabric := NoiseTexture2D.new()
	fabric.width = 128
	fabric.height = 128
	fabric.seamless = true
	fabric.noise = fabric_noise
	var fabric_ramp := Gradient.new()
	fabric_ramp.colors = PackedColorArray([Color(0.55, 0.55, 0.55), Color.WHITE])
	fabric.color_ramp = fabric_ramp
	cushion.albedo_texture = fabric
	cushion.uv1_scale = Vector3(3.0, 3.0, 3.0)

	rider_root = Node3D.new()
	rider_root.name = "Rider"
	add_child(rider_root)
	rider_upper_body = Node3D.new()
	rider_upper_body.name = "UpperBody"
	rider_upper_body.position = Vector3(0.0, 0.0, 0.12)
	rider_root.add_child(rider_upper_body)

	seat_cushion = _box(Vector3(0.87, 0.14, 0.80), Vector3(0.0, 0.87, 0.02), cushion)
	_box(Vector3(0.87, 0.61, 0.12), Vector3(0.0, 1.19, 0.39), cushion)
	footrest = _box(Vector3(0.83, 0.08, 0.36), Vector3(0.0, 0.29, -0.70), metal)
	_tube(Vector3(-0.62, 0.55, 0.12), Vector3(0.62, 0.55, 0.12), 0.045, metal)

	for side in [-1.0, 1.0]:
		var lateral: float = float(side)
		_tube(Vector3(lateral * 0.43, 0.52, 0.36), Vector3(lateral * 0.43, 1.50, 0.42), 0.035, frame)
		_tube(Vector3(lateral * 0.43, 0.55, 0.28), Vector3(lateral * 0.43, 0.55, -0.56), 0.04, frame)
		_tube(Vector3(lateral * 0.43, 0.90, 0.32), Vector3(lateral * 0.43, 0.32, -0.68), 0.04, frame)
		_tube(Vector3(lateral * 0.43, 1.45, 0.42), Vector3(lateral * 0.43, 1.45, 0.65), 0.045, rubber)

		var wheel := Node3D.new()
		wheel.position = Vector3(lateral * 0.61, 0.55, 0.12)
		add_child(wheel)
		rear_wheels.append(wheel)
		var tire := TorusMesh.new()
		tire.inner_radius = 0.43
		tire.outer_radius = WHEEL_RADIUS
		tire.rings = 32
		tire.ring_segments = 12
		_mesh(wheel, tire, Vector3.ZERO, rubber).rotation.z = PI * 0.5
		var rim := TorusMesh.new()
		rim.inner_radius = 0.405
		rim.outer_radius = 0.425
		rim.rings = 32
		rim.ring_segments = 8
		_mesh(wheel, rim, Vector3(lateral * 0.075, 0.0, 0.0), metal).rotation.z = PI * 0.5
		var hub := CylinderMesh.new()
		hub.top_radius = 0.08
		hub.bottom_radius = 0.08
		hub.height = 0.18
		_mesh(wheel, hub, Vector3.ZERO, frame).rotation.z = PI * 0.5
		for spoke_index in range(8):
			var angle: float = TAU * float(spoke_index) / 8.0
			var spoke := BoxMesh.new()
			spoke.size = Vector3(0.02, 0.82, 0.02)
			_mesh(wheel, spoke, Vector3.ZERO, metal).rotation.x = angle

		var fork := Node3D.new()
		fork.position = Vector3(lateral * 0.42, 0.18, -0.57)
		add_child(fork)
		front_forks.append(fork)
		var caster := CylinderMesh.new()
		caster.top_radius = 0.16
		caster.bottom_radius = 0.16
		caster.height = 0.10
		caster.radial_segments = 20
		_mesh(fork, caster, Vector3.ZERO, rubber).rotation.z = PI * 0.5
		_tube(Vector3(lateral * 0.42, 0.24, -0.57), Vector3(lateral * 0.42, 0.55, -0.57), 0.025, metal)

	rider_pelvis = _oval(
		Vector3(0.0, 1.075, 0.17),
		0.18,
		0.34,
		Vector3(1.2, 0.8, 1.15),
		trousers,
		rider_root
	)
	for side in [-1.0, 1.0]:
		var lateral: float = float(side)
		var hip := Vector3(lateral * 0.14, 1.10, 0.18)
		var knee := Vector3(lateral * 0.16, 1.04, -0.35)
		thigh_segments.append(_capsule_between(hip, knee, 0.085, trousers, rider_root))
		var ankle := Vector3(lateral * 0.17, 0.47, -0.57)
		lower_leg_segments.append(_capsule_between(knee, ankle, 0.065, trousers, rider_root))
		foot_nodes.append(_oval(
			Vector3(lateral * 0.17, 0.385, -0.66),
			0.12,
			0.15,
			Vector3(1.0, 0.72, 1.5),
			shoes,
			rider_root
		))
		_box(Vector3(0.23, 0.025, 0.29), Vector3(lateral * 0.17, 0.32, -0.66), rubber, rider_root)
		_box(Vector3(0.10, 0.012, 0.025), Vector3(lateral * 0.17, 0.43, -0.74), shirt_trim, rider_root)

	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.25
	torso_mesh.height = 0.68
	torso_mesh.radial_segments = 24
	torso_mesh.rings = 10
	var torso := _mesh(rider_upper_body, torso_mesh, Vector3(0.0, 1.31, 0.07), shirt)
	torso.scale = Vector3(1.14, 1.0, 0.86)
	torso.quaternion = Quaternion(Vector3.UP, Vector3(0.0, 1.0, 0.20).normalized())
	_capsule_between(
		Vector3(0.0, 1.53, 0.02),
		Vector3(0.0, 1.64, 0.02),
		0.075,
		skin,
		rider_upper_body
	)

	for side in [-1.0, 1.0]:
		var lateral: float = float(side)
		var shoulder := Vector3(lateral * 0.235, 1.47, 0.015)
		_oval(shoulder, 0.12, 0.25, Vector3(1.1, 1.0, 0.9), shirt, rider_upper_body)
		var hand: Vector3 = _handrim_position(lateral, PUSH_HAND_ANGLE)
		var elbow: Vector3 = _solve_elbow(shoulder, hand, lateral)
		var upper_arm := _capsule_between(
			shoulder,
			elbow,
			0.082,
			shirt,
			rider_upper_body
		)
		upper_arm.set_meta("pose_base_height", (upper_arm.mesh as CapsuleMesh).height)
		var forearm := _capsule_between(
			elbow,
			hand,
			0.053,
			skin,
			rider_upper_body
		)
		forearm.set_meta("pose_base_height", (forearm.mesh as CapsuleMesh).height)
		var palm := _oval(
			hand,
			0.055,
			0.10,
			Vector3(1.0, 0.78, 1.25),
			skin,
			rider_upper_body
		)
		arm_segments.append([upper_arm, forearm])
		arm_hand_nodes.append(palm)
		arm_sides.append(lateral)

	_oval(Vector3(0.0, 1.80, 0.005), 0.15, 0.37, Vector3(1.0, 1.0, 0.9), skin, rider_upper_body)
	for side in [-1.0, 1.0]:
		var lateral: float = float(side)
		_oval(
			Vector3(lateral * 0.145, 1.79, 0.005),
			0.043,
			0.07,
			Vector3(0.8, 1.0, 0.65),
			skin,
			rider_upper_body
		)
		_oval(Vector3(lateral * 0.062, 1.84, -0.124), 0.022, 0.03, Vector3(1.0, 1.0, 0.45), eyes, rider_upper_body)
		_oval(Vector3(lateral * 0.062, 1.84, -0.14), 0.011, 0.016, Vector3(1.0, 1.0, 0.5), face_detail, rider_upper_body)
		_oval(Vector3(lateral * 0.065, 1.835, -0.15), 0.004, 0.006, Vector3.ONE, eyes, rider_upper_body)
		_oval(Vector3(lateral * 0.066, 1.84, -0.165), 0.071, 0.052, Vector3(1.0, 1.0, 0.33), glasses, rider_upper_body)
		_tube(
			Vector3(lateral * 0.12, 1.85, -0.14),
			Vector3(lateral * 0.17, 1.82, 0.005),
			0.012,
			glasses,
			rider_upper_body
		)
		_capsule_between(
			Vector3(lateral * 0.02, 1.715, -0.134),
			Vector3(lateral * 0.047, 1.705, -0.137),
			0.006,
			face_detail,
			rider_upper_body
		)
	_oval(Vector3(0.0, 1.785, -0.143), 0.025, 0.035, Vector3(0.85, 1.0, 0.8), skin, rider_upper_body)
	_oval(Vector3(0.0, 1.705, -0.127), 0.018, 0.012, Vector3(2.2, 1.0, 0.4), face_detail, rider_upper_body)

	var helmet_mesh := SphereMesh.new()
	helmet_mesh.radius = 0.205
	helmet_mesh.height = 0.30
	helmet_mesh.radial_segments = 32
	helmet_mesh.rings = 16
	_mesh(rider_upper_body, helmet_mesh, Vector3(0.0, 1.96, 0.025), helmet)
	var helmet_band := TorusMesh.new()
	helmet_band.inner_radius = 0.195
	helmet_band.outer_radius = 0.207
	helmet_band.rings = 32
	helmet_band.ring_segments = 10
	_mesh(rider_upper_body, helmet_band, Vector3(0.0, 1.91, 0.025), helmet_trim)

	_oval(Vector3(0.0, 1.34, -0.17), 0.075, 0.105, Vector3(1.0, 1.0, 0.18), badge, rider_upper_body)
	_capsule_between(
		Vector3(-0.025, 1.35, -0.187),
		Vector3(0.025, 1.35, -0.187),
		0.009,
		helmet_trim,
		rider_upper_body
	)
	for side in [-1.0, 1.0]:
		var lateral: float = float(side)
		_capsule_between(
			Vector3(lateral * 0.12, 1.53, -0.09),
			Vector3(0.0, 1.445, -0.178),
			0.014,
			shirt_trim,
			rider_upper_body
		)
		_capsule_between(
			Vector3(lateral * 0.12, 1.91, -0.045),
			Vector3(lateral * 0.105, 1.70, -0.045),
			0.012,
			helmet_trim,
			rider_upper_body
		)

	engine_mount = Node3D.new()
	engine_mount.name = "EngineMount"
	engine_mount.position = Vector3(0.0, 0.40, 0.15)
	engine_mount.scale = Vector3.ONE * 1.15
	add_child(engine_mount)

	for side in [-1.0, 1.0]:
		var lateral: float = float(side)
		_capsule_between(
			Vector3(lateral * 0.12, 1.50, 0.24),
			Vector3(lateral * 0.12, 1.13, 0.255),
			0.012,
			shirt_trim
		)