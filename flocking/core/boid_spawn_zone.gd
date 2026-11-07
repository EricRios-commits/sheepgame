@tool
class_name BoidSpawnZone
extends Node3D

## Shape of the spawn area.
enum Shape {
	## Filled circle of the given radius.
	DISC,
	## Axis-aligned (in local space) rectangle of the given size, centered on the node.
	RECTANGLE,
	## Annulus between inner_radius and radius.
	RING,
}

## BoidSystem this zone registers with at runtime. If unset, the zone will not spawn anything
@export var system: BoidSystem:
	set(v):
		system = v
		update_configuration_warnings()
## What to spawn here: species, count, initial state, heading and speed.
@export var config: BoidSpawnConfig:
	set(v):
		config = v
		update_configuration_warnings()
## Shape of the spawn area. DISC uses radius, RING uses inner_radius and radius, and
## RECTANGLE uses size.
@export var shape: Shape = Shape.DISC:
	set(v):
		shape = v
		_redraw()
		update_configuration_warnings()
## Outer radius of the spawn area, in world units. Used by DISC and RING shapes.
@export_range(0.1, 500.0, 0.1, "or_greater") var radius := 10.0:
	set(v):
		radius = v
		_redraw()
		update_configuration_warnings()
## Inner radius of the spawn area, in world units. Only used by the RING shape, and must be
## smaller than radius.
@export_range(0.0, 500.0, 0.1, "or_greater") var inner_radius := 5.0:
	set(v):
		inner_radius = v
		_redraw()
		update_configuration_warnings()
## Width (x) and depth (y, local Z) of the spawn area, in world units. Only used by the
## RECTANGLE shape.
@export var size := Vector2(20.0, 20.0):
	set(v):
		size = v
		_redraw()
## Whether the debug outline of the spawn area is visible while the game is running.
## The outline is always visible in the editor.
@export var show_gizmo_in_game := false

var _gizmo: MeshInstance3D
var _gizmo_immediate_mesh: ImmediateMesh


func _ready() -> void:
	_build_gizmo()
	if Engine.is_editor_hint():
		return
	_gizmo.visible = show_gizmo_in_game
	if system == null:
		push_warning("BoidSpawnZone '%s' has no system assigned; it will not spawn." % name)
		return
	system.register_zone(self)

## Returns a random point inside the zone's shape, in zone-local ground coordinates
## (local x, local z).
func sample_local_ground_position(rng: RandomNumberGenerator) -> Vector2:
	match shape:
		Shape.RING:
			return BoidSamplers.ring(rng, inner_radius, radius)
		Shape.RECTANGLE:
			return BoidSamplers.rect(rng, size)
		_:
			return BoidSamplers.disc(rng, radius)


## Converts a zone-local ground position (local x, local z) to a world ground position.
func local_to_world_ground(local_ground_position: Vector2) -> Vector2:
	var world_position := global_transform * Vector3(local_ground_position.x, 0.0, local_ground_position.y)
	return Vector2(world_position.x, world_position.z)


## Global position projected onto the ground plane (x -> x, z -> y).
func get_ground_position() -> Vector2:
	return Vector2(global_position.x, global_position.z)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if system == null:
		warnings.append("No BoidSystem assigned. This zone will not spawn anything.")
	if config == null:
		warnings.append("No BoidSpawnConfig assigned.")
	elif config.count <= 0:
		warnings.append("Spawn count is zero.")
	if shape == Shape.RING and inner_radius >= radius:
		warnings.append("Ring inner radius must be smaller than the outer radius.")
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
	gizmo_material.albedo_color = Color(1.0, 0.8, 0.2)
	_gizmo.material_override = gizmo_material
	_gizmo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_gizmo, false, Node.INTERNAL_MODE_FRONT)
	_redraw()


func _redraw() -> void:
	if _gizmo_immediate_mesh == null:
		return
	_gizmo_immediate_mesh.clear_surfaces()
	match shape:
		Shape.RING:
			_circle(radius)
			_circle(inner_radius)
		Shape.RECTANGLE:
			var half_width := size.x * 0.5
			var half_depth := size.y * 0.5
			_gizmo_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
			for c in [Vector3(-half_width, 0.05, -half_depth), Vector3(half_width, 0.05, -half_depth), Vector3(half_width, 0.05, half_depth),
					Vector3(-half_width, 0.05, half_depth), Vector3(-half_width, 0.05, -half_depth)]:
				_gizmo_immediate_mesh.surface_add_vertex(c)
			_gizmo_immediate_mesh.surface_end()
		_:
			_circle(radius)


func _circle(r: float, segments: int = 48) -> void:
	_gizmo_immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in segments + 1:
		var angle := TAU * float(i) / float(segments)
		_gizmo_immediate_mesh.surface_add_vertex(Vector3(cos(angle) * r, 0.05, sin(angle) * r))
	_gizmo_immediate_mesh.surface_end()
