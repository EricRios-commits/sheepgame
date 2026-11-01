class_name BoidInfluenceEmitter
extends BoidInfluence
## Reacts to emitters of one kind (dog, predator, lure...)
## FLEE pushes away, ATTRACT pulls in

enum Mode { FLEE, ATTRACT }

@export var emitter_kind: StringName = &"dog"
@export var mode: Mode = Mode.FLEE
@export var gain := 1.0
## ATTRACT only: the pull fades linearly to zero inside this distance (0 = no arrival).
@export var arrive_radius := 0.0


func _init() -> void:
	layer = Layer.THREAT


func create_runtime() -> BoidInfluenceRuntime:
	return Runtime.new(self)


class Runtime extends BoidInfluenceRuntime:
	var kind: StringName = &""
	var kind_id := -1
	var flee := true
	var gain := 1.0
	var arrive_inv := 0.0
	var _idx := PackedInt32Array()

	func _init(res: BoidInfluenceEmitter) -> void:
		kind = res.emitter_kind
		flee = res.mode == Mode.FLEE
		gain = res.gain
		arrive_inv = 1.0 / res.arrive_radius if res.arrive_radius > 0.0 else 0.0

	func setup(sys: BoidSystem) -> void:
		kind_id = sys.vocab.emitter_kind_id(kind)

	func apply(sys: BoidSystem, order: PackedInt32Array, from: int, to: int, weight: float,
			_vmax: float, acc: PackedVector2Array) -> void:
		_idx.clear()
		for e in sys.em_count:
			if sys.em_kind[e] == kind_id:
				_idx.append(e)
		var m := _idx.size()
		if m == 0:
			return
		var pos := sys.store.pos
		var ep := sys.em_pos
		var er := sys.em_radius
		var edir := sys.em_dir
		var ecos := sys.em_cos_half
		var estr := sys.em_strength
		var elut := sys.em_lut
		var lut_n := BoidSystem.LUT_N
		var scale := weight * gain
		for k in range(from, to):
			var slot := order[k]
			var p := pos[slot]
			var a := Vector2.ZERO
			for q in m:
				var e := _idx[q]
				var d := p - ep[e]
				var d2 := d.length_squared()
				var rad := er[e]
				if d2 >= rad * rad:
					continue
				var dist := sqrt(d2)
				var dir := d / dist if dist > 1e-4 else Vector2.from_angle(float(slot) * 2.399963)
				var fade := 1.0
				var cone := ecos[e]
				if cone > -0.999:
					fade = clampf((edir[e].dot(dir) - cone) / 0.15 + 1.0, 0.0, 1.0)
					if fade <= 0.0:
						continue
				var u := dist / rad * float(lut_n - 1)
				var i0 := mini(int(u), lut_n - 2)
				var base := e * lut_n + i0
				var s := lerpf(elut[base], elut[base + 1], u - float(i0)) * estr[e] * fade
				if flee:
					a += dir * s
				else:
					if arrive_inv > 0.0:
						s *= minf(dist * arrive_inv, 1.0)
					a -= dir * s
			acc[slot] += a * scale