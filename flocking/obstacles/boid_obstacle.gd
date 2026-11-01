@tool
class_name BoidObstacle
extends Node3D
## static obstacle 

enum Shape { DISC, BOX, SEGMENT }

@export var system: BoidSystem:
	set(v):
		system = v
		update_configuration_warnings()
@export var shape: Shape = Shape.DISC:
	set(v):
		shape = v
		_redraw()
@export_range(0.1, 100.0, 0.1, "or_greater") var radius := 2.0:
	set(v):
		radius = v
		_redraw()
## BOX: full width (x) and depth (z).
@export var size := Vector2(4.0, 4.0):
	set(v):
		size = v
		_redraw()
## SEGMENT: length along local X and wall thickness.
@export_range(0.1, 200.0, 0.1, "or_greater") var length := 10.0:
	set(v):
		length = v
		_redraw()
@export_range(0.1, 10.0, 0.1, "or_greater") var thickness := 0.6:
	set(v):
		thickness = v
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
		push_warning("BoidObstacle '%s' has no system assigned; boids will not avoid it." % name)
		return
	system.register_obstacle(self)


func bake_into(field: BoidObstacleField) -> void:
	var b := global_transform.basis
	var ax := Vector2(b.x.x, b.x.z).normalized()
	var az := Vector2(b.z.x, b.z.z).normalized()
	var c := Vector2(global_position.x, global_position.z)
	match shape:
		Shape.DISC:
			field.add_disc(c, radius)
		Shape.BOX:
			field.add_box(c, size * 0.5, ax, az)
		Shape.SEGMENT:
			field.add_segment(c - ax * length * 0.5, c + ax * length * 0.5, thickness * 0.5)


func _get_configuration_warnings() -> PackedStringArray:
	var w := PackedStringArray()
	if system == null:
		w.append("No BoidSystem assigned. Boids will not avoid this obstacle.")
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
	mat.albedo_color = Color(1.0, 0.3, 0.3)
	_gizmo.material_override = mat
	_gizmo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_gizmo, false, Node.INTERNAL_MODE_FRONT)
	_redraw()


func _redraw() -> void:
	if _imm == null:
		return
	_imm.clear_surfaces()
	_imm.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	match shape:
		Shape.BOX:
			var h := size * 0.5
			for c in [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y), Vector2(-h.x, -h.y)]:
				_imm.surface_add_vertex(Vector3(c.x, 0.05, c.y))
		Shape.SEGMENT:
			var hl := length * 0.5
			var ht := thickness * 0.5
			for c in [Vector2(-hl, -ht), Vector2(hl, -ht), Vector2(hl, ht), Vector2(-hl, ht), Vector2(-hl, -ht)]:
				_imm.surface_add_vertex(Vector3(c.x, 0.05, c.y))
		_:
			for i in 49:
				var a := TAU * float(i) / 48.0
				_imm.surface_add_vertex(Vector3(cos(a) * radius, 0.05, sin(a) * radius))
	_imm.surface_end()