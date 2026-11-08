@tool
class_name BoidPenEntrance
extends Node3D
## Gate that sends boids into a BoidPenStorage. Any boid inside the rectangle (centred on the
## node, rotated with its yaw) is sent to the storage, unless the storage is full. Several
## entrances can point at the same storage.

const GIZMO_HEIGHT := 0.06
const ENTRANCE_COLOR := Color(0.3, 0.6, 1.0)
const LINK_COLOR := Color(0.3, 0.6, 1.0, 0.5)

## Storage that boids entering this zone are sent to. The entrance registers with that
## storage's BoidSystem, so it has no system of its own. If unset, the entrance does nothing.
@export var storage: BoidPenStorage:
	set(new_value):
		storage = new_value
		update_configuration_warnings()
		_redraw_gizmo()
## Footprint of the entrance zone in local space, in world units. x = width, y = depth
## (local Z). Boids anywhere inside it count as entering.
@export var size := Vector2(8.0, 4.0):
	set(new_value):
		size = new_value
		_redraw_gizmo()
## Whether the debug outline of the entrance is visible while the game is running.
## The outline is always visible in the editor.
@export var show_gizmo_in_game := false

var _gizmo_instance: MeshInstance3D
var _gizmo_immediate_mesh: ImmediateMesh
var _last_storage_offset := Vector3.ZERO


func _ready() -> void:
	_build_gizmo()
	set_process(Engine.is_editor_hint())
	if Engine.is_editor_hint():
		return
	_gizmo_instance.visible = show_gizmo_in_game
	if storage == null:
		push_warning("BoidPenEntrance '%s' has no storage assigned; it will not send boids anywhere." % name)
		return
	if storage.system == null:
		push_warning("BoidPenEntrance '%s': its storage has no system assigned; it will not send boids anywhere." % name)
		return
	storage.system.register_entrance(self)


## Editor only: redraws the link line when the entrance or its storage is moved.
func _process(_delta: float) -> void:
	if storage == null or not storage.is_inside_tree() or not is_inside_tree():
		return
	var storage_offset := global_transform.affine_inverse() * storage.global_position
	if not storage_offset.is_equal_approx(_last_storage_offset):
		_redraw_gizmo()


## Global position projected onto the ground plane (x -> x, z -> y).
func get_ground_position() -> Vector2:
	return Vector2(global_position.x, global_position.z)


## Half extents of the entrance zone (local x, local z).
func get_half_extents() -> Vector2:
	return size * 0.5


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if storage == null:
		warnings.append("No BoidPenStorage assigned. This entrance will not send boids anywhere.")
	elif storage.system == null:
		warnings.append("The assigned storage has no BoidSystem, so this entrance will not register.")
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
	gizmo_material.vertex_color_use_as_albedo = true
	_gizmo_instance.material_override = gizmo_material
	_gizmo_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_gizmo_instance, false, Node.INTERNAL_MODE_FRONT)
	_redraw_gizmo()


## Draws the zone rectangle, plus a line from the entrance to its storage when one is assigned.
func _redraw_gizmo() -> void:
	if _gizmo_immediate_mesh == null:
		return
	_gizmo_immediate_mesh.clear_surfaces()
	_gizmo_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var half_extents := get_half_extents()
	_add_gizmo_line(Vector2(-half_extents.x, -half_extents.y), Vector2(half_extents.x, -half_extents.y), ENTRANCE_COLOR)
	_add_gizmo_line(Vector2(half_extents.x, -half_extents.y), Vector2(half_extents.x, half_extents.y), ENTRANCE_COLOR)
	_add_gizmo_line(Vector2(half_extents.x, half_extents.y), Vector2(-half_extents.x, half_extents.y), ENTRANCE_COLOR)
	_add_gizmo_line(Vector2(-half_extents.x, half_extents.y), Vector2(-half_extents.x, -half_extents.y), ENTRANCE_COLOR)
	if storage != null and storage.is_inside_tree() and is_inside_tree():
		var storage_offset := global_transform.affine_inverse() * storage.global_position
		_last_storage_offset = storage_offset
		_add_gizmo_line(Vector2.ZERO, Vector2(storage_offset.x, storage_offset.z), LINK_COLOR)
	_gizmo_immediate_mesh.surface_end()


## Adds one line segment between two entrance-local ground positions, slightly above the ground.
func _add_gizmo_line(line_start: Vector2, line_end: Vector2, color: Color) -> void:
	_gizmo_immediate_mesh.surface_set_color(color)
	_gizmo_immediate_mesh.surface_add_vertex(Vector3(line_start.x, GIZMO_HEIGHT, line_start.y))
	_gizmo_immediate_mesh.surface_set_color(color)
	_gizmo_immediate_mesh.surface_add_vertex(Vector3(line_end.x, GIZMO_HEIGHT, line_end.y))
