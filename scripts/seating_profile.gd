extends Resource

@export var model: PackedScene
@export var model_transform := Transform3D.IDENTITY
@export var rider_scale: float = 1.0
@export var seat := Transform3D.IDENTITY
@export var seat_size := Vector2(0.45, 0.45)
@export var seat_mesh: NodePath
@export var seat_thickness: float = 0.06
@export var back: AABB
@export var foot_supports: Array[Vector3] = []
@export var foot_sizes: Array[Vector2] = []
@export var generate_footplates: bool = false
@export var foot_mounts: Array[Vector3] = []
@export var armrests: Array[AABB] = []
@export var controls: Array[Transform3D] = []
@export var frame_solids: Array[AABB] = []
@export var rear_wheels: Array[NodePath] = []
@export var casters: Array[NodePath] = []
@export var forks: Array[NodePath] = []
@export var handrim_radius: float = 0.0
@export var clearance: float = 0.008
@export_file("*.tres") var baked_pose_path: String = ""


func resolve_seat(chair: Node3D) -> Transform3D:
	if seat_mesh.is_empty():
		return seat
	var mesh: MeshInstance3D = chair.get_node(seat_mesh)
	var relative: Transform3D = chair.get_parent().global_transform.affine_inverse() * mesh.global_transform
	var bounds: AABB = mesh.get_aabb()
	return Transform3D(relative.basis.orthonormalized(), relative * Vector3(bounds.get_center().x, bounds.end.y, bounds.get_center().z))


func resolve_size(chair: Node3D) -> Vector2:
	if seat_mesh.is_empty():
		return seat_size
	var mesh: MeshInstance3D = chair.get_node(seat_mesh)
	var relative: Transform3D = chair.get_parent().global_transform.affine_inverse() * mesh.global_transform
	var size: Vector3 = mesh.get_aabb().size * relative.basis.get_scale().abs()
	return Vector2(size.x, size.z)


func validate() -> bool:
	if model == null or not is_finite(rider_scale) or rider_scale <= 0.0 or clearance <= 0.0 or seat_thickness <= 0.0:
		return false
	if not seat.is_finite() or not seat.basis.is_equal_approx(seat.basis.orthonormalized()) or not model_transform.is_finite() or is_zero_approx(model_transform.basis.determinant()):
		return false
	if seat_size.x <= 0.0 or seat_size.y <= 0.0 or foot_supports.size() != 2 or foot_sizes.size() != 2 or rear_wheels.size() != 2:
		return false
	if casters.size() != forks.size() or (generate_footplates and foot_mounts.size() != 2):
		return false
	if (not armrests.is_empty() and armrests.size() != 2) or (not controls.is_empty() and controls.size() != 2):
		return false
	for size in foot_sizes:
		if not size.is_finite() or size.x <= 0.0 or size.y <= 0.0:
			return false
	for path in rear_wheels + casters + forks:
		if path.is_empty():
			return false
	return true


static func outside_box(point: Vector3, box: AABB, radius: float, preferred_axis: int) -> Vector3:
	var expanded: AABB = box.grow(radius)
	if not expanded.has_point(point):
		return point
	var result: Vector3 = point
	if preferred_axis == 1:
		result.y = expanded.end.y
	else:
		result.x = expanded.position.x if point.x < box.get_center().x else expanded.end.x
	return result