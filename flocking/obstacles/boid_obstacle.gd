@tool
class_name BoidObstacle
extends Node3D
## Static obstacle that boids steer around. Registers with its BoidSystem at runtime and is
## baked into the system's obstacle field when the system bakes its environment.

## Footprint type of the obstacle, on the ground plane.
enum Shape {
	## Circle of the given radius, centered on the node.
	DISC,
	## Rectangle of the given size, centered on the node and rotated with its yaw.
	BOX,
	## Wall of the given length and thickness, centered on the node and running along its local X.
	SEGMENT,
}

## BoidSystem this obstacle registers with at runtime. If unset, boids will not avoid it
## (a configuration warning is shown in the editor).
@export var system: BoidSystem:
	set(new_value):
		system = new_value
		update_configuration_warnings()
## Shape of the obstacle. DISC uses radius, BOX uses size, and SEGMENT uses length and thickness.
@export var shape: Shape = Shape.DISC:
	set(new_value):
		shape = new_value
		_redraw_gizmo()
## DISC only: radius of the obstacle, in world units.
@export_range(0.1, 100.0, 0.1, "or_greater") var radius := 2.0:
	set(new_value):
		radius = new_value
		_redraw_gizmo()
## BOX only: full width (x) and depth (z) of the obstacle, in world units.
@export var size := Vector2(4.0, 4.0):
	set(new_value):
		size = new_value
		_redraw_gizmo()
## SEGMENT only: length of the wall along the node's local X axis, in world units.
@export_range(0.1, 200.0, 0.1, "or_greater") var length := 10.0:
	set(new_value):
		length = new_value
		_redraw_gizmo()
## SEGMENT only: full thickness of the wall, in world units.
@export_range(0.1, 10.0, 0.1, "or_greater") var thickness := 0.6:
	set(new_value):
		thickness = new_value
		_redraw_gizmo()
## Whether the debug outline of the obstacle is visible while the game is running.
## The outline is always visible in the editor.
@export var show_gizmo_in_game := false

var _gizmo_instance: MeshInstance3D
var _gizmo_immediate_mesh: ImmediateMesh


func _ready() -> void:
	_build_gizmo()
	if Engine.is_editor_hint():
		return
	_gizmo_instance.visible = show_gizmo_in_game
	if system == null:
		push_warning("BoidObstacle '%s' has no system assigned; boids will not avoid it." % name)
		return
	system.register_obstacle(self)


## Writes this obstacle's shape into the obstacle field, using the node's current global
## position and yaw. Called by BoidSystem.bake_environment.
func bake_into(field: BoidObstacleField) -> void:
	var world_basis := global_transform.basis
	var axis_x := Vector2(world_basis.x.x, world_basis.x.z).normalized()
	var axis_z := Vector2(world_basis.z.x, world_basis.z.z).normalized()
	var center := Vector2(global_position.x, global_position.z)
	match shape:
		Shape.DISC:
			field.add_disc(center, radius)
		Shape.BOX:
			field.add_box(center, size * 0.5, axis_x, axis_z)
		Shape.SEGMENT:
			field.add_segment(center - axis_x * length * 0.5, center + axis_x * length * 0.5, thickness * 0.5)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if system == null:
		warnings.append("No BoidSystem assigned. Boids will not avoid this obstacle.")
	return warnings


func _build_gizmo() -> void:
	if _gizmo_instance != null:
		return
	_gizmo_immediate_mesh = ImmediateMesh.new()
	_gizmo_instance = MeshInstance3D.new()
	_gizmo_instance.name = "_Gizmo"
	_gizmo_instance.mesh = _gizmo_immediate_mesh
	var gizmo_material := StandardMaterial3D.new()
	gizmo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gizmo_material.albedo_color = Color(1.0, 0.3, 0.3)
	_gizmo_instance.material_override = gizmo_material
	_gizmo_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_gizmo_instance, false, Node.INTERNAL_MODE_FRONT)
	_redraw_gizmo()


func _redraw_gizmo() -> void:
	if _gizmo_immediate_mesh == null:
		return
	_gizmo_immediate_mesh.clear_surfaces()
	_gizmo_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	match shape:
		Shape.BOX:
			var half_size := size * 0.5
			for corner in [Vector2(-half_size.x, -half_size.y), Vector2(half_size.x, -half_size.y), Vector2(half_size.x, half_size.y), Vector2(-half_size.x, half_size.y), Vector2(-half_size.x, -half_size.y)]:
				_gizmo_immediate_mesh.surface_add_vertex(Vector3(corner.x, 0.05, corner.y))
		Shape.SEGMENT:
			var half_length := length * 0.5
			var half_thickness := thickness * 0.5
			for corner in [Vector2(-half_length, -half_thickness), Vector2(half_length, -half_thickness), Vector2(half_length, half_thickness), Vector2(-half_length, half_thickness), Vector2(-half_length, -half_thickness)]:
				_gizmo_immediate_mesh.surface_add_vertex(Vector3(corner.x, 0.05, corner.y))
		_:
			for i in 49:
				var angle := TAU * float(i) / 48.0
				_gizmo_immediate_mesh.surface_add_vertex(Vector3(cos(angle) * radius, 0.05, sin(angle) * radius))
	_gizmo_immediate_mesh.surface_end()
