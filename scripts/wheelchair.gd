extends CharacterBody3D

signal respawned

const MAX_SPEED: float = 18.0
const ACCELERATION: float = 8.0
const BRAKING: float = 24.0
const ROLLING_RESISTANCE: float = 3.0
const STEERING_SPEED: float = 1.8
const WHEEL_RADIUS: float = 0.53

var speed: float = 0.0
var spawn_transform: Transform3D = Transform3D.IDENTITY
var recovery_transform: Transform3D = Transform3D.IDENTITY
var driving_enabled: bool = true
var rear_wheels: Array[Node3D] = []
var front_forks: Array[Node3D] = []
var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))


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
		speed = move_toward(speed, 0.0, BRAKING * delta)
	elif Input.is_action_pressed("accelerate"):
		speed = move_toward(speed, MAX_SPEED, ACCELERATION * delta)
	else:
		speed = move_toward(speed, 0.0, ROLLING_RESISTANCE * delta)

	var steering: float = Input.get_axis("steer_right", "steer_left")
	var turn_scale: float = lerpf(1.0, 0.62, speed / MAX_SPEED)
	if speed > 0.15:
		rotate_y(steering * STEERING_SPEED * turn_scale * delta)

	var forward: Vector3 = -global_basis.z
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= gravity * delta
	move_and_slide()
	speed = clampf(Vector3(velocity.x, 0.0, velocity.z).dot(forward), 0.0, MAX_SPEED)

	for wheel in rear_wheels:
		wheel.rotate_x(-speed * delta / WHEEL_RADIUS)
	for fork in front_forks:
		fork.rotation.y = steering * 0.35


func reset_to_start() -> void:
	_respawn(spawn_transform)


func reset_to_checkpoint() -> void:
	_respawn(recovery_transform)


func _respawn(target: Transform3D) -> void:
	global_transform = target
	velocity = Vector3.ZERO
	speed = 0.0
	for wheel in rear_wheels:
		wheel.rotation = Vector3.ZERO
	for fork in front_forks:
		fork.rotation = Vector3.ZERO
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


func _box(size: Vector3, location: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(self, mesh, location, material)


func _tube(start: Vector3, finish: Vector3, radius: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = start.distance_to(finish)
	mesh.radial_segments = 12
	var instance := _mesh(self, mesh, (start + finish) * 0.5, material)
	instance.quaternion = Quaternion(Vector3.UP, (finish - start).normalized())


func _build_model() -> void:
	var frame := _material(Color("297f7b"), 0.5, 0.3)
	var rubber := _material(Color("15191c"), 0.0, 0.96)
	var cushion := _material(Color("364c52"), 0.0, 0.88)
	var metal := _material(Color("bfcace"), 0.8, 0.27)
	var shirt := _material(Color("c99b48"), 0.0, 0.9)
	var trousers := _material(Color("384653"))
	var skin := _material(Color("b87954"))
	var helmet := _material(Color("dde4da"), 0.0, 0.35)
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

	_box(Vector3(0.87, 0.14, 0.80), Vector3(0.0, 0.87, 0.02), cushion)
	_box(Vector3(0.87, 0.61, 0.12), Vector3(0.0, 1.19, 0.39), cushion)
	_box(Vector3(0.83, 0.08, 0.36), Vector3(0.0, 0.29, -0.70), metal)
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

	_box(Vector3(0.60, 0.59, 0.33), Vector3(0.0, 1.30, 0.06), shirt)
	_tube(Vector3(0.0, 1.54, 0.04), Vector3(0.0, 1.65, 0.04), 0.10, skin)
	var head := SphereMesh.new()
	head.radius = 0.20
	head.height = 0.42
	_mesh(self, head, Vector3(0.0, 1.80, 0.03), skin)
	var helmet_mesh := SphereMesh.new()
	helmet_mesh.radius = 0.215
	helmet_mesh.height = 0.29
	_mesh(self, helmet_mesh, Vector3(0.0, 1.95, 0.04), helmet)
	_box(Vector3(0.27, 0.055, 0.07), Vector3(0.0, 1.86, -0.15), rubber)
	for side in [-1.0, 1.0]:
		var lateral: float = float(side)
		_box(Vector3(0.24, 0.22, 0.54), Vector3(lateral * 0.18, 0.98, -0.21), trousers)
		_tube(Vector3(lateral * 0.18, 0.93, -0.45), Vector3(lateral * 0.18, 0.43, -0.58), 0.105, trousers)
		_box(Vector3(0.23, 0.14, 0.32), Vector3(lateral * 0.18, 0.39, -0.68), rubber)
		_tube(Vector3(lateral * 0.34, 1.49, 0.07), Vector3(lateral * 0.48, 1.14, -0.06), 0.09, shirt)
		_tube(Vector3(lateral * 0.48, 1.14, -0.06), Vector3(lateral * 0.56, 0.98, -0.27), 0.065, skin)