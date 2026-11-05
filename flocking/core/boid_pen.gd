@tool
class_name BoidPen
extends Node3D

@export var system: BoidSystem:
	set(v):
		system = v
		update_configuration_warnings()

## x = width, y = depth (local Z).
@export var size := Vector2(16.0, 12.0):
	set(v):
		size = v
		_redraw()
## How far past the gate line a boid must be before it counts as penned.
@export_range(0.0, 20.0, 0.1) var entry_depth := 1.5:
	set(v):
		entry_depth = v
		_redraw()
## Number of spots that can be occupied
@export_range(1, 2000, 1) var number_of_spots := 100
@export var snap_to_spots := true
@export var show_gizmo_in_game := false

var index := -1

var _gizmo: MeshInstance3D
var _imm: ImmediateMesh


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
	var half := trigger_half()
	var x_lo := -half.x + 0.4
	var x_hi := half.x - 0.4
	var z_lo := trigger_zmin() + 0.4
	var z_hi := half.y - 0.4
	if x_hi < x_lo or z_hi < z_lo:
		return out
	var width := x_hi - x_lo
	var depth := z_hi - z_lo
	var aspect := width / depth
	var nx := maxi(1, roundi(sqrt(number_of_spots * aspect)))
	var nz := ceili(float(number_of_spots) / float(nx))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919
	var items: Array = []
	for iz in nz:
		for ix in nx:
			if items.size() >= number_of_spots:
				break
			var lx := x_lo + (float(ix) + 0.5) * width / nx
			var lz := z_lo + (float(iz) + 0.5) * depth / nz
			lx += rng.randf_range(-0.15, 0.15) * width / nx
			lz += rng.randf_range(-0.15, 0.15) * depth / nz
			items.append([-lz * 1000.0 + absf(lx), Vector2(lx, lz)])
	items.sort_custom(
		func(a: Array, b: Array) -> bool:
			return a[0] < b[0]
	)
	for it in items:
		out.append(world_xz(it[1]))
	return out

func _get_configuration_warnings() -> PackedStringArray:
	var w := PackedStringArray()
	if system == null:
		w.append("No BoidSystem assigned. This pen will not accept boids.")
	if size.y * 0.5 - entry_depth < 1.0:
		w.append("entry_depth leaves almost no room inside the pen.")
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
	mat.vertex_color_use_as_albedo = true
	_gizmo.material_override = mat
	_gizmo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_gizmo, false, Node.INTERNAL_MODE_FRONT)
	_redraw()


func _redraw() -> void:
	if _imm == null:
		return
	_imm.clear_surfaces()
	_imm.surface_begin(Mesh.PRIMITIVE_LINES)
	var trig := Color(0.3, 0.6, 1.0)
	var th := trigger_half()
	var z0 := trigger_zmin()
	_l(Vector2(-th.x, z0), Vector2(th.x, z0), trig)
	_l(Vector2(-th.x, z0), Vector2(-th.x, th.y), trig)
	_l(Vector2(th.x, z0), Vector2(th.x, th.y), trig)
	_l(Vector2(-th.x, th.y), Vector2(th.x, th.y), trig)
	_imm.surface_end()


func _l(a: Vector2, b: Vector2, c: Color) -> void:
	_imm.surface_set_color(c)
	_imm.surface_add_vertex(Vector3(a.x, 0.06, a.y))
	_imm.surface_set_color(c)
	_imm.surface_add_vertex(Vector3(b.x, 0.06, b.y))
