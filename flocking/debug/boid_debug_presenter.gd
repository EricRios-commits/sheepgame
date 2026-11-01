class_name BoidDebugPresenter
extends Node3D

const STRIDE := 16  # 12 transform floats + 4 colour floats

@export var system: BoidSystem
@export var mesh: Mesh
@export var palette := PackedColorArray([Color(0.95, 0.95, 0.9), Color(0.85, 0.6, 0.3),
		Color(0.5, 0.7, 0.95), Color(0.9, 0.5, 0.6)])

var _mm: MultiMesh
var _buf := PackedFloat32Array()


func _ready() -> void:
	if system == null:
		system = get_parent() as BoidSystem
	if system == null:
		push_error("BoidDebugPresenter needs a BoidSystem (assign it or parent it to one).")
		return
	system.spawned.connect(_on_spawned)
	system.present_requested.connect(_present)
	if system.store.count > 0:
		_on_spawned(system.store.count)


func _on_spawned(_n: int) -> void:
	var cap := system.store.count
	if cap == 0:
		return
	var m := mesh
	if m == null:
		var box := BoxMesh.new()
		box.size = Vector3(0.6, 0.6, 1.0)
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		box.material = mat
		m = box
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = m
	_mm.instance_count = cap
	_buf.resize(cap * STRIDE)
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = _mm
	add_child(inst)
	_present()


func _present() -> void:
	if _mm == null:
		return
	var s := system.store
	var n := s.count
	var b := _buf
	for i in n:
		var h := s.heading[i]
		var c := cos(h)
		var sn := sin(h)
		var p := s.pos[i]
		var o := i * STRIDE
		b[o] = c
		b[o + 1] = 0.0
		b[o + 2] = sn
		b[o + 3] = p.x
		b[o + 4] = 0.0
		b[o + 5] = 1.0
		b[o + 6] = 0.0
		b[o + 7] = s.ground_h[i] + 0.3
		b[o + 8] = -sn
		b[o + 9] = 0.0
		b[o + 10] = c
		b[o + 11] = p.y
		var col := palette[s.species[i] % palette.size()]
		b[o + 12] = col.r
		b[o + 13] = col.g
		b[o + 14] = col.b
		b[o + 15] = 1.0
	_mm.visible_instance_count = n
	_mm.buffer = b
