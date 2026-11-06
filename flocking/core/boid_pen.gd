@tool
class_name BoidPen
extends Node3D

## BoidSystem this pen registers with at runtime. If unset, the pen will not accept boids
@export var system: BoidSystem:
	set(v):
		system = v
		update_configuration_warnings()

## Footprint of the pen in local space, in world units. x = width, y = depth (local Z).
## The front edge (the gate) is at local z = -y / 2.
@export var size := Vector2(16.0, 12.0):
	set(v):
		size = v
		_redraw()
## How far past the gate line a boid must be before it counts as penned.
## Larger values shrink the region where boids count as inside.
@export_range(0.0, 20.0, 0.1) var entry_depth := 1.5:
	set(v):
		entry_depth = v
		_redraw()
## Number of spots that can be occupied. Spots are laid out in a jittered grid inside the
## penned region.
@export_range(1, 2000, 1) var number_of_spots := 100
## Whether penned boids snap to the pen's spots (see compute_world_spot_positions).
@export var correct_species: StringName = &"sheep"
@export var snap_to_spots := true
## Whether the debug outline of the penned region is visible while the game is running.
## The outline is always visible in the editor.
@export var show_gizmo_in_game := false

var index := -1

var _gizmo: MeshInstance3D
var _gizmo_immediate_mesh: ImmediateMesh


func _ready() -> void:
	_build_gizmo()
	if Engine.is_editor_hint():
		return
	_gizmo.visible = show_gizmo_in_game
	if system == null:
		push_warning("BoidPen '%s' has no system assigned; it will not accept boids." % name)
		return
	system.register_pen(self)


func xz() -> Vector2:
	return Vector2(global_position.x, global_position.z)


func world_xz(local: Vector2) -> Vector2:
	var p := global_transform * Vector3(local.x, 0.0, local.y)
	return Vector2(p.x, p.z)


## Half extents of the region where a boid counts as inside (local x, local z).
func trigger_half() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.5 )


## Local z beyond which a boid counts as past the gate.
func trigger_zmin() -> float:
	return -size.y * 0.5 + entry_depth


## World-space spots inside the trigger region, deepest first
func compute_spots() -> PackedVector2Array:
	var out := PackedVector2Array()
	if number_of_spots <= 0:
		return out
	var half_extents := trigger_half()
	var min_x := -half_extents.x + 0.4
	var max_x := half_extents.x - 0.4
	var min_z := trigger_zmin() + 0.4
	var max_z := half_extents.y - 0.4
	if max_x < min_x or max_z < min_z:
		return out
	var width := max_x - min_x
	var depth := max_z - min_z
	var aspect_ratio := width / depth
	var cols := maxi(1, roundi(sqrt(number_of_spots * aspect_ratio)))
	var rows := ceili(float(number_of_spots) / float(cols))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919
	var scored_spots: Array = []
	for row in rows:
		for col in cols:
			if scored_spots.size() >= number_of_spots:
				break
			var local_x := min_x + (float(col) + 0.5) * width / cols
			var local_z := min_z + (float(row) + 0.5) * depth / rows
			local_x += rng.randf_range(-0.15, 0.15) * width / cols
			local_z += rng.randf_range(-0.15, 0.15) * depth / rows
			scored_spots.append([-local_z * 1000.0 + absf(local_x), Vector2(local_x, local_z)])
	scored_spots.sort_custom(
		func(a: Array, b: Array) -> bool:
			return a[0] < b[0]
	)
	for spot in scored_spots:
		out.append(world_xz(spot[1]))
	return out

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if system == null:
		warnings.append("No BoidSystem assigned. This pen will not accept boids.")
	if size.y * 0.5 - entry_depth < 1.0:
		warnings.append("entry_depth leaves almost no room inside the pen.")
	return warnings


func _build_gizmo() -> void:
	if _gizmo != null:
		return
	_gizmo_immediate_mesh = ImmediateMesh.new()
	_gizmo = MeshInstance3D.new()
	_gizmo.name = "_Gizmo"
	_gizmo.mesh = _gizmo_immediate_mesh
	var gizmo_material := StandardMaterial3D.new()
	gizmo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gizmo_material.vertex_color_use_as_albedo = true
	_gizmo.material_override = gizmo_material
	_gizmo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_gizmo, false, Node.INTERNAL_MODE_FRONT)
	_redraw()


func _redraw() -> void:
	if _gizmo_immediate_mesh == null:
		return
	_gizmo_immediate_mesh.clear_surfaces()
	_gizmo_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var trigger_color := Color(0.3, 0.6, 1.0)
	var half_extents := trigger_half()
	var entry_line_z := trigger_zmin()
	_add_gizmo_line(Vector2(-half_extents.x, entry_line_z), Vector2(half_extents.x, entry_line_z), trigger_color)
	_add_gizmo_line(Vector2(-half_extents.x, entry_line_z), Vector2(-half_extents.x, half_extents.y), trigger_color)
	_add_gizmo_line(Vector2(half_extents.x, entry_line_z), Vector2(half_extents.x, half_extents.y), trigger_color)
	_add_gizmo_line(Vector2(-half_extents.x, half_extents.y), Vector2(half_extents.x, half_extents.y), trigger_color)
	_gizmo_immediate_mesh.surface_end()


func _add_gizmo_line(line_start: Vector2, line_end: Vector2, color: Color) -> void:
	_gizmo_immediate_mesh.surface_set_color(color)
	_gizmo_immediate_mesh.surface_add_vertex(Vector3(line_start.x, 0.06, line_start.y))
	_gizmo_immediate_mesh.surface_set_color(color)
	_gizmo_immediate_mesh.surface_add_vertex(Vector3(line_end.x, 0.06, line_end.y))
