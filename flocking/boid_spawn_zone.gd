@tool
class_name BoidSpawnZone
extends Node3D

enum Shape { DISC, RECTANGLE, RING }

@export var system: BoidSystem:
	set(v):
		system = v
		update_configuration_warnings()
@export var config: BoidSpawnConfig:
	set(v):
		config = v
		update_configuration_warnings()
@export var shape: Shape = Shape.DISC:
	set(v):
		shape = v
		_redraw()
		update_configuration_warnings()
@export_range(0.1, 500.0, 0.1, "or_greater") var radius := 10.0:
	set(v):
		radius = v
		_redraw()
		update_configuration_warnings()

@export_range(0.0, 500.0, 0.1, "or_greater") var inner_radius := 5.0:
	set(v):
		inner_radius = v
		_redraw()
		update_configuration_warnings()

@export var size := Vector2(20.0, 20.0):
	set(v):
		size = v
		_redraw()
@export var show_gizmo_in_game := false

var _gizmo: MeshInstance3D
var _imm: ImmediateMesh


func _ready() -> void:
	_build_gizmo()
	if Engine.is_editor_hint():
		return
	_gizmo.visible = show_gizmo_in_game
	if system == null:
		push_warning("BoidSpawnZone '%s' has no system assigned; it will not spawn." % name)
		return
	system.register_zone(self)

func sample_local(rng: RandomNumberGenerator) -> Vector2:
	match shape:
		Shape.RING:
			return BoidSamplers.ring(rng, inner_radius, radius)
		Shape.RECTANGLE:
			return BoidSamplers.rect(rng, size)
		_:
			return BoidSamplers.disc(rng, radius)


func local_to_world_xz(local: Vector2) -> Vector2:
	var p := global_transform * Vector3(local.x, 0.0, local.y)
	return Vector2(p.x, p.z)


func center_xz() -> Vector2:
	return Vector2(global_position.x, global_position.z)

func _get_configuration_warnings() -> PackedStringArray:
	var w := PackedStringArray()
	if system == null:
		w.append("No BoidSystem assigned. This zone will not spawn anything.")
	if config == null:
		w.append("No BoidSpawnConfig assigned.")
	elif config.count <= 0:
		w.append("Spawn count is zero.")
	if shape == Shape.RING and inner_radius >= radius:
		w.append("Ring inner radius must be smaller than the outer radius.")
	return w


func _build_gizmo() -> void:
	if _gizmo != null:
		return
	_imm = ImmediateMesh.new()
	_gizmo = MeshInstance3D.new()
	_gizmo.name = "_Gizmo"
	_gizmo.mesh = _imm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.8, 0.2)
	_gizmo.material_override = mat
	_gizmo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Internal child: not saved into the scene, hidden from the scene tree dock.
	add_child(_gizmo, false, Node.INTERNAL_MODE_FRONT)
	_redraw()


func _redraw() -> void:
	if _imm == null:
		return
	_imm.clear_surfaces()
	match shape:
		Shape.RING:
			_circle(radius)
			_circle(inner_radius)
		Shape.RECTANGLE:
			var hx := size.x * 0.5
			var hz := size.y * 0.5
			_imm.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
			for c in [Vector3(-hx, 0.05, -hz), Vector3(hx, 0.05, -hz), Vector3(hx, 0.05, hz),
					Vector3(-hx, 0.05, hz), Vector3(-hx, 0.05, -hz)]:
				_imm.surface_add_vertex(c)
			_imm.surface_end()
		_:
			_circle(radius)


func _circle(r: float, segments: int = 48) -> void:
	_imm.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in segments + 1:
		var a := TAU * float(i) / float(segments)
		_imm.surface_add_vertex(Vector3(cos(a) * r, 0.05, sin(a) * r))
	_imm.surface_end()
