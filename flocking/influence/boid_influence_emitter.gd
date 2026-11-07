class_name BoidInfluenceEmitter
extends BoidInfluence
## Reacts to emitters of one kind (dog, predator, lure...)
## FLEE pushes away, ATTRACT pulls in

## How the boid reacts to a matching emitter.
enum Mode {
	## Accelerate directly away from the emitter.
	FLEE,
	## Accelerate toward the emitter.
	ATTRACT,
}

## Kind of emitter to react to. Must match BoidEmitter.kind. Emitters of other kinds are ignored.
@export var emitter_kind: StringName = &"dog"
## Whether boids move away from (FLEE) or toward (ATTRACT) the emitter.
@export var mode: Mode = Mode.FLEE
## Multiplier on this influence's strength, applied on top of the entry weight.
@export var gain := 1.0
## ATTRACT only: the pull fades linearly to zero inside this distance (0 = no arrival).
@export var arrive_radius := 0.0


func _init() -> void:
	layer = Layer.THREAT


func create_runtime() -> BoidInfluenceRuntime:
	return Runtime.new(self)


## Applies the influence each tick. Only emitters within their own radius affect a boid.
class Runtime extends BoidInfluenceRuntime:
	var emitter_kind: StringName = &""
	var emitter_kind_id := -1
	var is_flee := true
	var gain := 1.0
	var inverse_arrive_radius := 0.0
	var _matching_emitter_indices := PackedInt32Array()

	func _init(source_influence: BoidInfluenceEmitter) -> void:
		emitter_kind = source_influence.emitter_kind
		is_flee = source_influence.mode == Mode.FLEE
		gain = source_influence.gain
		inverse_arrive_radius = 1.0 / source_influence.arrive_radius if source_influence.arrive_radius > 0.0 else 0.0

	func setup(system: BoidSystem) -> void:
		emitter_kind_id = system.vocab.emitter_kind_id(emitter_kind)

	func apply(system: BoidSystem, boid_order: PackedInt32Array, from_index: int, to_index: int, weight: float,
			_max_speed: float, layer_accel: PackedVector2Array) -> void:
		_matching_emitter_indices.clear()
		for emitter_index in system.active_emitter_count:
			if system.emitter_kind_ids[emitter_index] == emitter_kind_id:
				_matching_emitter_indices.append(emitter_index)
		var matching_count := _matching_emitter_indices.size()
		if matching_count == 0:
			return
		var positions := system.store.pos
		var emitter_positions := system.emitter_positions
		var emitter_radii := system.emitter_radii
		var emitter_directions := system.emitter_directions
		var emitter_cos_half_angles := system.emitter_cos_half_angles
		var emitter_strengths := system.emitter_strengths
		var emitter_curve_luts := system.emitter_curve_luts
		var lut_samples := BoidSystem.CURVE_LUT_SAMPLES
		var total_scale := weight * gain
		for order_index in range(from_index, to_index):
			var slot := boid_order[order_index]
			var boid_position := positions[slot]
			var accel_sum := Vector2.ZERO
			for matching_index in matching_count:
				var emitter_index := _matching_emitter_indices[matching_index]
				var offset := boid_position - emitter_positions[emitter_index]
				var distance_squared := offset.length_squared()
				var emitter_radius := emitter_radii[emitter_index]
				if distance_squared >= emitter_radius * emitter_radius:
					continue
				var distance := sqrt(distance_squared)
				var direction_away := offset / distance if distance > 1e-4 else Vector2.from_angle(float(slot) * 2.399963)
				var cone_fade := 1.0
				var cos_half_angle := emitter_cos_half_angles[emitter_index]
				if cos_half_angle > -0.999:
					cone_fade = clampf((emitter_directions[emitter_index].dot(direction_away) - cos_half_angle) / 0.15 + 1.0, 0.0, 1.0)
					if cone_fade <= 0.0:
						continue
				var lut_position := distance / emitter_radius * float(lut_samples - 1)
				var lut_index := mini(int(lut_position), lut_samples - 2)
				var lut_base := emitter_index * lut_samples + lut_index
				var strength := lerpf(emitter_curve_luts[lut_base], emitter_curve_luts[lut_base + 1], lut_position - float(lut_index)) * emitter_strengths[emitter_index] * cone_fade
				if is_flee:
					accel_sum += direction_away * strength
				else:
					if inverse_arrive_radius > 0.0:
						strength *= minf(distance * inverse_arrive_radius, 1.0)
					accel_sum -= direction_away * strength
			layer_accel[slot] += accel_sum * total_scale