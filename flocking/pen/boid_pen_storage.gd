@tool
class_name BoidPenStorage
extends Node3D
## Where penned boids are kept. One or more BoidPenEntrance nodes point at a storage and send
## boids into it. With snap_to_spots on, each penned boid is moved onto a free spot inside the
## rectangle. With it off, the storage is only a counter and boids stay where they entered.

## Margin, in world units, kept between the rectangle's edge and any spot.
const SPOT_EDGE_MARGIN := 0.4
## Random offset applied to each spot, as a fraction of the grid cell size (+/-).
const SPOT_JITTER_FRACTION := 0.15
## Weight of local z in the fill order. Large, so z always dominates and |x| only breaks ties.
const FILL_ORDER_Z_WEIGHT := 1000.0
## Seed for the spot jitter, so the layout is identical on every run.
const SPOT_JITTER_SEED := 7919
const GIZMO_HEIGHT := 0.06
const ARROW_HEAD_SIZE := 0.6
const SNAPPING_COLOR := Color(0.3, 1.0, 0.5)
const COUNTER_ONLY_COLOR := Color(0.6, 0.6, 0.6)

## BoidSystem this storage registers with at runtime. If unset, the storage will not accept
## boids (a configuration warning is shown in the editor).
@export var system: BoidSystem:
	set(new_value):
		system = new_value
		update_configuration_warnings()

## Footprint of the storage in local space, in world units. x = width, y = depth (local Z).
## Only used when snap_to_spots is on.
@export var size := Vector2(16.0, 12.0):
	set(new_value):
		size = new_value
		_redraw_gizmo()
		update_configuration_warnings()
## Number of spots that can be occupied. Spots are laid out in a jittered grid inside the
## rectangle. Only used when snap_to_spots is on. The actual count can be lower if the
## rectangle is too small.
@export_range(1, 2000, 1) var number_of_spots := 100
## If true, boids that enter are moved onto free spots and the storage holds at most
## number_of_spots boids. Spots fill from the +Z end of the rectangle (the gizmo arrow points
## that way). If false, boids stay where they entered and capacity is unlimited.
@export var snap_to_spots := true:
	set(new_value):
		snap_to_spots = new_value
		_redraw_gizmo()
		update_configuration_warnings()
## Whether the debug outline of the storage is visible while the game is running.
## The outline is always visible in the editor.
@export var show_gizmo_in_game := false

## Index of this storage in the BoidSystem's storage list (storages are sorted by node path).
## Assigned when the system builds its storages; -1 until then.
var storage_index := -1

var _gizmo_instance: MeshInstance3D
var _gizmo_immediate_mesh: ImmediateMesh


func _ready() -> void:
	_build_gizmo()
	if Engine.is_editor_hint():
		return
	_gizmo_instance.visible = show_gizmo_in_game
	if system == null:
		push_warning("BoidPenStorage '%s' has no system assigned; it will not accept boids." % name)
		return
	system.register_storage(self)


## Converts a storage-local ground position (local x, local z) to a world ground position.
func local_to_world_ground(local_ground_position: Vector2) -> Vector2:
	var world_position := global_transform * Vector3(local_ground_position.x, 0.0, local_ground_position.y)
	return Vector2(world_position.x, world_position.z)


## World-space spots inside the rectangle, in fill order (highest local z first, then closest
## to the centre line).
func compute_world_spot_positions() -> PackedVector2Array:
	var spot_positions := PackedVector2Array()
	if number_of_spots <= 0:
		return spot_positions
	var half_extents := size * 0.5
	var min_x := -half_extents.x + SPOT_EDGE_MARGIN
	var max_x := half_extents.x - SPOT_EDGE_MARGIN
	var min_z := -half_extents.y + SPOT_EDGE_MARGIN
	var max_z := half_extents.y - SPOT_EDGE_MARGIN
	if max_x < min_x or max_z < min_z:
		return spot_positions
	var width := max_x - min_x
	var depth := max_z - min_z
	var aspect_ratio := width / depth
	var columns := maxi(1, roundi(sqrt(number_of_spots * aspect_ratio)))
	var rows := ceili(float(number_of_spots) / float(columns))
	var jitter_rng := RandomNumberGenerator.new()
	jitter_rng.seed = SPOT_JITTER_SEED
	# Each entry is [sort_key, local_position]
	var scored_spots: Array = []
	for row in rows:
		for column in columns:
			if scored_spots.size() >= number_of_spots:
				break
			var local_x := min_x + (float(column) + 0.5) * width / columns
			var local_z := min_z + (float(row) + 0.5) * depth / rows
			local_x += jitter_rng.randf_range(-SPOT_JITTER_FRACTION, SPOT_JITTER_FRACTION) * width / columns
			local_z += jitter_rng.randf_range(-SPOT_JITTER_FRACTION, SPOT_JITTER_FRACTION) * depth / rows
			scored_spots.append([-local_z * FILL_ORDER_Z_WEIGHT + absf(local_x), Vector2(local_x, local_z)])
	scored_spots.sort_custom(
		func(spot_a: Array, spot_b: Array) -> bool:
			return spot_a[0] < spot_b[0]
	)
	for scored_spot in scored_spots:
		spot_positions.append(local_to_world_ground(scored_spot[1]))
	return spot_positions


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if system == null:
		warnings.append("No BoidSystem assigned. This storage will not accept boids.")
	if snap_to_spots and (size.x - 2.0 * SPOT_EDGE_MARGIN <= 0.0 or size.y - 2.0 * SPOT_EDGE_MARGIN <= 0.0):
		warnings.append("size is too small to hold any spots.")
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


## Draws the rectangle. When snapping, also draws an arrow along local +Z showing which end
## fills first. A grey outline with no arrow means the storage is only a counter.
func _redraw_gizmo() -> void:
	if _gizmo_immediate_mesh == null:
		return
	_gizmo_immediate_mesh.clear_surfaces()
	_gizmo_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var half_extents := size * 0.5
	var outline_color := SNAPPING_COLOR if snap_to_spots else COUNTER_ONLY_COLOR
	_add_gizmo_line(Vector2(-half_extents.x, -half_extents.y), Vector2(half_extents.x, -half_extents.y), outline_color)
	_add_gizmo_line(Vector2(half_extents.x, -half_extents.y), Vector2(half_extents.x, half_extents.y), outline_color)
	_add_gizmo_line(Vector2(half_extents.x, half_extents.y), Vector2(-half_extents.x, half_extents.y), outline_color)
	_add_gizmo_line(Vector2(-half_extents.x, half_extents.y), Vector2(-half_extents.x, -half_extents.y), outline_color)
	if snap_to_spots:
		var arrow_start := Vector2(0.0, -half_extents.y * 0.5)
		var arrow_tip := Vector2(0.0, half_extents.y * 0.5)
		_add_gizmo_line(arrow_start, arrow_tip, outline_color)
		_add_gizmo_line(arrow_tip, arrow_tip + Vector2(-ARROW_HEAD_SIZE, -ARROW_HEAD_SIZE), outline_color)
		_add_gizmo_line(arrow_tip, arrow_tip + Vector2(ARROW_HEAD_SIZE, -ARROW_HEAD_SIZE), outline_color)
	_gizmo_immediate_mesh.surface_end()


## Adds one line segment between two storage-local ground positions, slightly above the ground.
func _add_gizmo_line(line_start: Vector2, line_end: Vector2, color: Color) -> void:
	_gizmo_immediate_mesh.surface_set_color(color)
	_gizmo_immediate_mesh.surface_add_vertex(Vector3(line_start.x, GIZMO_HEIGHT, line_start.y))
	_gizmo_immediate_mesh.surface_set_color(color)
	_gizmo_immediate_mesh.surface_add_vertex(Vector3(line_end.x, GIZMO_HEIGHT, line_end.y))