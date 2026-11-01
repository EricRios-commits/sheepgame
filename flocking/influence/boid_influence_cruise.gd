class_name BoidInfluenceCruise
extends BoidInfluence
## Holds a preferred speed along the current direction of travel

@export var speed := 1.2


func create_runtime() -> BoidInfluenceRuntime:
	return Runtime.new(self)


class Runtime extends BoidInfluenceRuntime:
	var target := 1.2

	func _init(res: BoidInfluenceCruise) -> void:
		target = res.speed

	func apply(sys: BoidSystem, order: PackedInt32Array, from: int, to: int, weight: float,
			_vmax: float, acc: PackedVector2Array) -> void:
		var st := sys.store
		var vel := st.vel
		var spd := st.speed
		var hdg := st.heading
		for k in range(from, to):
			var slot := order[k]
			var s := spd[slot]
			var dir := vel[slot] / s if s > 0.01 else Vector2(sin(hdg[slot]), cos(hdg[slot]))
			acc[slot] += dir * ((target - s) * weight)