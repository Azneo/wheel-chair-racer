extends CharacterBody3D

signal respawned

const EngineVisualFactory = preload("res://scripts/engine_visuals.gd")
const RacerVisuals = preload("res://scripts/racer_visuals.gd")
const BRAKING: float = 24.0
const ROLLING_RESISTANCE: float = 3.0
const STEERING_SPEED: float = 1.8
const WHEEL_RADIUS: float = 0.53

@export var seating_profile: Resource = preload("res://assets/wheelchair/seating.tres")

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
var drive_pose_weight: float = 0.0
var visuals: Node3D


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
	visuals.update_wheels(speed * delta, steering)


func _process(delta: float) -> void:
	var propelling: bool = Input.is_action_pressed("accelerate") or (Input.is_action_pressed("brake") and speed < 0.0)
	visuals.update_pose(delta, driving_enabled and absf(speed) > 0.15, propelling, not pending_engine_visual_id.is_empty())
	drive_pose_weight = visuals.push_weight


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
	visuals.reset_wheels()
	visuals.update_pose(0.0, false, false, not pending_engine_visual_id.is_empty())
	respawned.emit()


func _build_model() -> void:
	visuals = RacerVisuals.new()
	visuals.name = "Presentation"
	visuals.seating = seating_profile
	add_child(visuals)
	rear_wheels = visuals.rear_wheels
	front_forks = visuals.front_forks
	engine_mount = Node3D.new()
	engine_mount.name = "EngineMount"
	engine_mount.position = Vector3(0.0, 0.40, 0.15)
	engine_mount.scale = Vector3.ONE * 1.15
	add_child(engine_mount)