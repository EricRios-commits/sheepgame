class_name BoidPresenter
extends Node3D
## Draws every alive boid of one BoidSystem. Reads the store, never writes to it.

const STRIDE := 20  # 12 transform + 4 colour + 4 custom data floats per instance

@export var system: BoidSystem
@export var visuals: Array[BoidSpeciesVisual] = []
## Colours for species that have no BoidSpeciesVisual (debug boxes).
@export var fallback_palette := PackedColorArray([Color(0.95, 0.95, 0.9), Color(0.85, 0.6, 0.3),
		Color(0.5, 0.7, 0.95), Color(0.9, 0.5, 0.6)])
## Interpolate between sim ticks. Off shows the latest tick as is
@export var interpolate := true
## Align boids to the ground normal. Skipped automatically on flat ground.
@export var tilt_to_ground := true
## Response rates in 1/s. Higher is snappier.
@export_range(0.5, 40.0, 0.5) var heading_response := 10.0
@export_range(0.5, 40.0, 0.5) var speed_response := 6.0
@export_range(0.5, 40.0, 0.5) var tilt_response := 8.0
## Extra culling margin for vertex-animated meshes.
@export_range(0.0, 20.0, 0.5, "or_greater") var cull_margin := 1.5

var _n_species := 0
var _active: Array[Batch] = []
var _frozen: Array[Batch] = []
var _active_bufs: Array[PackedFloat32Array] = []
var _frozen_bufs: Array[PackedFloat32Array] = []
var _vis_keep: Array[BoidSpeciesVisual] = []
var _cnt_active := PackedInt32Array()
var _cnt_frozen := PackedInt32Array()
var _cursor := PackedInt32Array()

# per species
var _sp_scale := PackedFloat32Array()
var _sp_scale_jitter := PackedFloat32Array()
var _sp_yoff := PackedFloat32Array()
var _sp_yaw := PackedFloat32Array()
var _sp_inv_stride := PackedFloat32Array()
var _sp_tilt := PackedFloat32Array()

# per boid ID
var _cap := 0
var _gen_seen := PackedInt32Array()
var _seed := PackedFloat32Array()
var _scale := PackedFloat32Array()
var _prev_pos := PackedVector2Array()
var _cur_pos := PackedVector2Array()
var _prev_y := PackedFloat32Array()
var _cur_y := PackedFloat32Array()
var _prev_h := PackedFloat32Array()
var _cur_h := PackedFloat32Array()
var _speed := PackedFloat32Array()
var _phase := PackedFloat32Array()
var _phase_step := PackedFloat32Array()
var _normal := PackedVector3Array()

# per slot scratch
var _normals := PackedVector3Array()

var _use_tilt := false
var _synced_active := -1
var _synced_count := -1
var _frozen_key := Vector4i(-1, -1, -1, -1)
var _fb_mesh: Mesh
var _fb_mat: Material


class Batch extends RefCounted:
	var mm := MultiMesh.new()
	var inst := MultiMeshInstance3D.new()
	var buf := PackedFloat32Array()
	var count := 0

	func _init(mesh: Mesh, material: Material, shadows: bool, margin: float, label: String) -> void:
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = mesh
		inst.name = label
		inst.multimesh = mm
		inst.top_level = true
		inst.material_override = material
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		inst.extra_cull_margin = margin

	func resize(n: int) -> void:
		if n == count:
			return
		count = n
		mm.instance_count = n
		buf.resize(n * BoidPresenter.STRIDE)

	func upload() -> void:
		if count > 0:
			mm.buffer = buf


func _ready() -> void:
	if system == null:
		system = get_parent() as BoidSystem
	if system == null:
		push_error("BoidPresenter needs a BoidSystem (assign it or parent it to one).")
		set_process(false)
		return
	system.present_requested.connect(_on_present)
	system.spawned.connect(_on_spawned)

func _on_spawned(_n: int) -> void:
	_synced_count = -1


func _on_present() -> void:
	_capture(true)


func _process(_delta: float) -> void:
	if system == null:
		return
	var s := system.store
	if s.active_count != _synced_active or s.count != _synced_count:
		_capture(false)
	var a := system.interpolation_alpha() if interpolate else 1.0
	_write_region(0, s.active_count, _active_bufs, a, false)
	for sp in _n_species:
		_active[sp].upload()


# per sim tick

func _capture(advance: bool) -> void:
	var s := system.store
	var n := s.active_count
	var ids := s.slot_ids()
	var gens := s.id_generations()
	_ensure_ids(gens.size())
	_sync_species()
	_use_tilt = tilt_to_ground and system.ground != null and system.ground.get_script() != BoidGround
	if _use_tilt:
		_normals.resize(s.count)
		system.ground.sample_normals(s.pos, _normals, 0, n)
	var dt := maxf(system.current_sim_dt, 1e-4)
	var kh := 1.0 - exp(-heading_response * dt)
	var ks := 1.0 - exp(-speed_response * dt)
	var kt := 1.0 - exp(-tilt_response * dt)
	var pos := s.pos
	var hdg := s.heading
	var gh := s.ground_h
	var spd := s.speed
	var sps := s.species
	_cnt_active.fill(0)
	for i in n:
		var id := ids[i]
		var sp := sps[i]
		_cnt_active[sp] += 1
		if _gen_seen[id] != gens[id]:
			_init_id(id, gens[id], i, sp, _normals[i] if _use_tilt else Vector3.UP)
			continue
		if not advance:
			continue
		_prev_pos[id] = _cur_pos[id]
		_cur_pos[id] = pos[i]
		_prev_y[id] = _cur_y[id]
		_cur_y[id] = gh[i]
		var ch := _cur_h[id]
		_prev_h[id] = ch
		_cur_h[id] = lerp_angle(ch, hdg[i], kh)
		var v := lerpf(_speed[id], spd[i], ks)
		_speed[id] = v
		var step := v * dt * _sp_inv_stride[sp]
		_phase_step[id] = step
		_phase[id] = fposmod(_phase[id] + step, 1.0)
		if _use_tilt:
			var target := Vector3.UP.lerp(_normals[i], _sp_tilt[sp])
			_normal[id] = _normal[id].lerp(target, kt).normalized()
	for sp in _n_species:
		_active[sp].resize(_cnt_active[sp])
		_active_bufs[sp] = _active[sp].buf
	var key := Vector4i(s.count, n, system.removed_total, system.spawned_total)
	if key != _frozen_key:
		_frozen_key = key
		_rebuild_frozen()
	_synced_active = n
	_synced_count = s.count


## Penned boids never move, so their MultiMeshes are written once per layout change.
func _rebuild_frozen() -> void:
	var s := system.store
	var from := s.active_count
	var total := s.count
	var ids := s.slot_ids()
	var gens := s.id_generations()
	var sps := s.species
	_cnt_frozen.fill(0)
	for i in range(from, total):
		_cnt_frozen[sps[i]] += 1
	for sp in _n_species:
		_frozen[sp].resize(_cnt_frozen[sp])
		_frozen_bufs[sp] = _frozen[sp].buf
	if total == from:
		return
	if _use_tilt:
		_normals.resize(total)
		system.ground.sample_normals(s.pos, _normals, from, total)
	for i in range(from, total):
		var id := ids[i]
		var sp := sps[i]
		if _gen_seen[id] != gens[id]:
			_init_id(id, gens[id], i, sp, Vector3.UP)
		if _use_tilt:
			_normal[id] = Vector3.UP.lerp(_normals[i], _sp_tilt[sp]).normalized()
	_write_region(from, total, _frozen_bufs, 1.0, true)
	for sp in _n_species:
		_frozen[sp].upload()


func _init_id(id: int, gen: int, slot: int, sp: int, nrm: Vector3) -> void:
	var s := system.store
	var rnd := fposmod(sin(float(id) * 12.9898 + float(gen) * 78.233) * 43758.5453, 1.0)
	_gen_seen[id] = gen
	_seed[id] = rnd
	_scale[id] = 1.0 + (rnd - 0.5) * 2.0 * _sp_scale_jitter[sp]
	var p := s.pos[slot]
	_prev_pos[id] = p
	_cur_pos[id] = p
	var y := s.ground_h[slot]
	_prev_y[id] = y
	_cur_y[id] = y
	var h := s.heading[slot]
	_prev_h[id] = h
	_cur_h[id] = h
	_speed[id] = s.speed[slot]
	_phase[id] = fposmod(rnd * 13.7, 1.0)
	_phase_step[id] = 0.0
	_normal[id] = Vector3.UP.lerp(nrm, _sp_tilt[sp]).normalized()


# per render frame

## Writes slots [from, to) into the per-species buffers
func _write_region(from: int, to: int, bufs: Array[PackedFloat32Array], a: float, frozen: bool) -> void:
	var s := system.store
	var ids := s.slot_ids()
	var pos := s.pos
	var gh := s.ground_h
	var sps := s.species
	var sts := s.state
	var cursor := _cursor
	cursor.fill(0)
	var tilt := _use_tilt
	var ia := 1.0 - a
	for i in range(from, to):
		var id := ids[i]
		var sp := sps[i]
		var b: PackedFloat32Array = bufs[sp]
		var o := cursor[sp] * STRIDE
		cursor[sp] += 1
		if o + STRIDE > b.size():
			continue
		var px := 0.0
		var py := 0.0
		var pz := 0.0
		var h := 0.0
		var spd := 0.0
		var ph := 0.0
		if frozen:
			var q := pos[i]
			px = q.x
			pz = q.y
			py = gh[i]
			h = _cur_h[id]
			ph = _phase[id]
		else:
			var q0 := _prev_pos[id]
			var q1 := _cur_pos[id]
			px = q0.x + (q1.x - q0.x) * a
			pz = q0.y + (q1.y - q0.y) * a
			py = _prev_y[id] + (_cur_y[id] - _prev_y[id]) * a
			h = lerp_angle(_prev_h[id], _cur_h[id], a)
			spd = _speed[id]
			ph = _phase[id] - ia * _phase_step[id]
		py += _sp_yoff[sp]
		h += _sp_yaw[sp]
		var sn := sin(h)
		var cs := cos(h)
		var sc := _scale[id] * _sp_scale[sp]
		var ux := 0.0
		var uy := 1.0
		var uz := 0.0
		var zx := sn
		var zy := 0.0
		var zz := cs
		var xx := cs
		var xy := 0.0
		var xz := -sn
		if tilt:
			var nrm := _normal[id]
			ux = nrm.x
			uy = nrm.y
			uz = nrm.z
			var d := sn * ux + cs * uz
			zx = sn - ux * d
			zy = -uy * d
			zz = cs - uz * d
			var il := 1.0 / maxf(sqrt(zx * zx + zy * zy + zz * zz), 1e-6)
			zx *= il
			zy *= il
			zz *= il
			xx = uy * zz - uz * zy
			xy = uz * zx - ux * zz
			xz = ux * zy - uy * zx
		b[o] = xx * sc
		b[o + 1] = ux * sc
		b[o + 2] = zx * sc
		b[o + 3] = px
		b[o + 4] = xy * sc
		b[o + 5] = uy * sc
		b[o + 6] = zy * sc
		b[o + 7] = py
		b[o + 8] = xz * sc
		b[o + 9] = uz * sc
		b[o + 10] = zz * sc
		b[o + 11] = pz
		# INSTANCE_CUSTOM data assigned here
		b[o + 16] = spd
		b[o + 17] = ph
		b[o + 18] = _seed[id]
		b[o + 19] = float(sts[i])


# setup

func _ensure_ids(n: int) -> void:
	if n <= _cap:
		return
	_cap = n
	_gen_seen.resize(n)
	_seed.resize(n)
	_scale.resize(n)
	_prev_pos.resize(n)
	_cur_pos.resize(n)
	_prev_y.resize(n)
	_cur_y.resize(n)
	_prev_h.resize(n)
	_cur_h.resize(n)
	_speed.resize(n)
	_phase.resize(n)
	_phase_step.resize(n)
	_normal.resize(n)


## Creates batches for species registered since the last call.
func _sync_species() -> void:
	var n := system.vocab.species_names.size()
	if n == _n_species:
		return
	var old := _n_species
	_sp_scale.resize(n)
	_sp_scale_jitter.resize(n)
	_sp_yoff.resize(n)
	_sp_yaw.resize(n)
	_sp_inv_stride.resize(n)
	_sp_tilt.resize(n)
	_cnt_active.resize(n)
	_cnt_frozen.resize(n)
	_cursor.resize(n)
	for sp in range(old, n):
		var sname := system.vocab.species_names[sp]
		var vis := _visual_for(sname)
		_vis_keep.append(vis)
		var mesh := vis.mesh if vis.mesh != null else _fallback_mesh()
		_sp_scale[sp] = vis.base_scale
		_sp_scale_jitter[sp] = vis.scale_jitter
		_sp_yoff[sp] = vis.y_offset
		_sp_yaw[sp] = deg_to_rad(vis.yaw_offset_degrees)
		_sp_inv_stride[sp] = 1.0 / maxf(vis.stride_length, 0.01)
		_sp_tilt[sp] = vis.ground_tilt
		var a := Batch.new(mesh, vis.material, vis.cast_shadow, cull_margin, "%s_active" % sname)
		var f := Batch.new(mesh, vis.material, vis.cast_shadow, cull_margin, "%s_frozen" % sname)
		add_child(a.inst)
		add_child(f.inst)
		_active.append(a)
		_frozen.append(f)
		_active_bufs.append(a.buf)
		_frozen_bufs.append(f.buf)
	_n_species = n
	_frozen_key = Vector4i(-1, -1, -1, -1)


func _visual_for(sname: StringName) -> BoidSpeciesVisual:
	for v in visuals:
		if v != null and v.species == sname:
			return v
	var fb := BoidSpeciesVisual.new()
	fb.species = sname
	fb.mesh = _fallback_mesh()
	fb.material = _fb_mat
	fb.y_offset = 0.3
	return fb


func _fallback_mesh() -> Mesh:
	if _fb_mesh == null:
		var box := BoxMesh.new()
		box.size = Vector3(0.6, 0.6, 1.0)
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		_fb_mesh = box
		_fb_mat = m
	return _fb_mesh
