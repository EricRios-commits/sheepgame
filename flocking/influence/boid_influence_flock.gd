class_name BoidInfluenceFlock
extends BoidInfluence
## Cohesion + alignment + separation from one shared neighbour query per boid
## Per-species-pair multipliers come from the system's interaction table.

@export_range(0.5, 50.0, 0.1, "or_greater") var perception_radius := 6.0
@export_range(0.1, 20.0, 0.1, "or_greater") var separation_radius := 1.8
@export_range(1, 512) var max_neighbours := 48
@export var cohesion := 0.8
@export var alignment := 1.5
@export var separation := 5.0


func _init() -> void:
	layer = Layer.SOCIAL


func neighbour_radius() -> float:
	return perception_radius


func create_runtime() -> BoidInfluenceRuntime:
	return Runtime.new(self)


class Runtime extends BoidInfluenceRuntime:
	var r := 6.0
	var sep_r := 1.8
	var w_c := 0.8
	var w_a := 1.5
	var w_s := 5.0
	var _buf := PackedInt32Array()

	func _init(res: BoidInfluenceFlock) -> void:
		r = res.perception_radius
		sep_r = res.separation_radius
		w_c = res.cohesion
		w_a = res.alignment
		w_s = res.separation
		_buf.resize(res.max_neighbours)

	func apply(sys: BoidSystem, order: PackedInt32Array, from: int, to: int, weight: float,
			vmax: float, acc: PackedVector2Array) -> void:
		var st := sys.store
		var pos := st.pos
		var vel := st.vel
		var species := st.species
		var nb := sys.neighbours
		var buf := _buf
		var dslot := sys.debug_slot
		var table := sys.table
		var weighted := table.has_interactions
		var n_sp := table.n_species
		var ixc := table.ix_cohesion
		var ixa := table.ix_alignment
		var ixs := table.ix_separation
		var sep_r2 := sep_r * sep_r
		var inv_sep_r := 1.0 / sep_r
		var inv_r := 1.0 / r
		var inv_vmax := 1.0 / maxf(vmax, 0.01)
		for idx in range(from, to):
			var slot := order[idx]
			var p := pos[slot]
			var v := vel[slot]
			var k := nb.query(p, r, slot, buf)
			if k == 0:
				continue
			var csum := Vector2.ZERO
			var vsum := Vector2.ZERO
			var sep := Vector2.ZERO
			var coh := Vector2.ZERO
			var ali := Vector2.ZERO
			if not weighted:
				for j in k:
					var s := buf[j]
					var q := pos[s]
					csum += q
					vsum += vel[s]
					var d := p - q
					var d2 := d.length_squared()
					if d2 < sep_r2:
						if d2 > 1e-8:
							sep += d * (1.0 / sqrt(d2) - inv_sep_r)
						else:
							sep += Vector2.from_angle(float(slot) * 2.399963)
				var inv_k := 1.0 / float(k)
				coh = (csum * inv_k - p) * inv_r
				ali = (vsum * inv_k - v) * inv_vmax
			else:
				var row := species[slot] * n_sp
				var cw := 0.0
				var aw := 0.0
				for j in k:
					var s := buf[j]
					var q := pos[s]
					var m := row + species[s]
					var mc := ixc[m]
					var ma := ixa[m]
					csum += q * mc
					cw += mc
					vsum += vel[s] * ma
					aw += ma
					var d := p - q
					var d2 := d.length_squared()
					if d2 < sep_r2:
						if d2 > 1e-8:
							sep += d * ((1.0 / sqrt(d2) - inv_sep_r) * ixs[m])
						else:
							sep += Vector2.from_angle(float(slot) * 2.399963) * ixs[m]
				if cw > 1e-6:
					coh = (csum / cw - p) * inv_r
				if aw > 1e-6:
					ali = (vsum / aw - v) * inv_vmax
			acc[slot] += (coh * w_c + ali * w_a + sep * w_s) * weight
			if slot == dslot:
				sys.debug_cohesion = coh * w_c * weight
				sys.debug_alignment = ali * w_a * weight
				sys.debug_separation = sep * w_s * weight
				sys.debug_neighbour_pos.resize(k)
				for j in k:
					sys.debug_neighbour_pos[j] = pos[buf[j]]