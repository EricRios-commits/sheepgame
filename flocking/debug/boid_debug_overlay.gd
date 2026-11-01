class_name BoidDebugOverlay
extends Node3D
## Debug drawing for a selected boid 
## Left-click near a boid (on the y=0 plane) to select it. Defaults to slot 0.
##   yellow = neighbour links   r/g/b = cohesion/alignment/separation   white = total
##   magenta/orange/grey = SAFETY/THREAT/AMBIENT layers   orange circles = emitter radii

@export var system: BoidSystem
@export var show_neighbours := true
@export var show_forces := true
@export var show_radii := true
@export var show_cells := true
@export var show_emitters := true
@export var force_scale := 1.5
@export var pick_radius := 6.0

var _imm := ImmediateMesh.new()


func _ready() -> void:
	top_level = true
	if system == null:
		system = get_parent() as BoidSystem
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	var mi := MeshInstance3D.new()
	mi.mesh = _imm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _unhandled_input(event: InputEvent) -> void:
	if system == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return
		var o := cam.project_ray_origin(event.position)
		var d := cam.project_ray_normal(event.position)
		if absf(d.y) < 1e-4:
			return
		var hit := o + d * (-o.y / d.y)
		var hxz := Vector2(hit.x, hit.z)
		var best := -1
		var best_d2 := pick_radius * pick_radius
		for i in system.store.count:
			var d2 := system.store.pos[i].distance_squared_to(hxz)
			if d2 < best_d2:
				best_d2 = d2
				best = i
		if best >= 0:
			system.select_debug_boid(system.store.handle_at(best))


func _process(_delta: float) -> void:
	if system == null:
		return
	var st := system.store
	if st.count == 0:
		_imm.clear_surfaces()
		return
	if not st.is_valid(system.debug_handle):
		system.select_debug_boid(st.handle_at(0))
	var slot := st.slot_of(system.debug_handle)
	var p := st.pos[slot]
	var y := st.ground_h[slot] + 0.9
	var p3 := Vector3(p.x, y, p.y)
	_imm.clear_surfaces()
	_imm.surface_begin(Mesh.PRIMITIVE_LINES)
	_line(p3 + Vector3(-0.6, 0, 0), p3 + Vector3(0.6, 0, 0), Color.WHITE)
	_line(p3 + Vector3(0, 0, -0.6), p3 + Vector3(0, 0, 0.6), Color.WHITE)
	if show_neighbours:
		for q in system.debug_neighbour_pos:
			_line(p3, Vector3(q.x, y, q.y), Color(1.0, 0.9, 0.2, 0.8))
	if show_forces:
		_arrow(p3, system.debug_cohesion, Color(0.2, 1.0, 0.3))
		_arrow(p3, system.debug_alignment, Color(0.3, 0.5, 1.0))
		_arrow(p3, system.debug_separation, Color(1.0, 0.25, 0.25))
		_arrow(p3, system.debug_layers[BoidInfluence.Layer.SAFETY], Color(1.0, 0.2, 0.9))
		_arrow(p3, system.debug_layers[BoidInfluence.Layer.THREAT], Color(1.0, 0.6, 0.1))
		_arrow(p3, system.debug_layers[BoidInfluence.Layer.AMBIENT], Color(0.7, 0.7, 0.7))
		_arrow(p3, system.debug_total, Color.WHITE)
	if show_emitters:
		for e in system.em_count:
			var ep := system.em_pos[e]
			_circle(Vector3(ep.x, y, ep.y), system.em_radius[e], Color(1.0, 0.5, 0.0, 0.6), 64)
	if show_radii:
		_circle(p3, system.table.max_query_radius, Color(1, 1, 1, 0.35))
	if show_cells and system.neighbours is BoidNeighbourHash:
		var h := system.neighbours as BoidNeighbourHash
		var w := h.cell_window(p, system.table.max_query_radius)
		for cz in range(w.position.y, w.end.y):
			for cx in range(w.position.x, w.end.x):
				var x0 := h.origin.x + cx * h.cell
				var z0 := h.origin.y + cz * h.cell
				var c := Color(0.5, 0.5, 0.5, 0.5)
				var yy := y - 0.8
				_line(Vector3(x0, yy, z0), Vector3(x0 + h.cell, yy, z0), c)
				_line(Vector3(x0 + h.cell, yy, z0), Vector3(x0 + h.cell, yy, z0 + h.cell), c)
				_line(Vector3(x0 + h.cell, yy, z0 + h.cell), Vector3(x0, yy, z0 + h.cell), c)
				_line(Vector3(x0, yy, z0 + h.cell), Vector3(x0, yy, z0), c)
	_imm.surface_end()


func _line(a: Vector3, b: Vector3, c: Color) -> void:
	_imm.surface_set_color(c)
	_imm.surface_add_vertex(a)
	_imm.surface_set_color(c)
	_imm.surface_add_vertex(b)


func _arrow(from: Vector3, accel: Vector2, c: Color) -> void:
	if accel.length_squared() < 1e-6:
		return
	var to := from + Vector3(accel.x, 0.0, accel.y) * force_scale
	_line(from, to, c)
	var back := -Vector3(accel.x, 0.0, accel.y).normalized() * 0.3
	var side := Vector3(-back.z, 0.0, back.x) * 0.5
	_line(to, to + back + side, c)
	_line(to, to + back - side, c)


func _circle(center: Vector3, r: float, c: Color, segments: int = 40) -> void:
	for i in segments:
		var a0 := TAU * float(i) / segments
		var a1 := TAU * float(i + 1) / segments
		_line(center + Vector3(cos(a0), 0, sin(a0)) * r, center + Vector3(cos(a1), 0, sin(a1)) * r, c)