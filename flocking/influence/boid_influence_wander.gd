class_name BoidInfluenceWander
extends BoidInfluence
## Slow random steering for grazing / idle movement

## How quickly the wander angle drifts, in radians per square root of a second. Each tick the
## angle changes by a random amount of up to jitter * sqrt(tick length) in either direction.
## Higher values give twitchier, less predictable paths.
@export var jitter := 2.0
## Largest angle, in degrees, that the wander direction can deviate from the boid's current
## heading, to either side. Lower values keep boids closer to straight-line travel.
@export_range(5.0, 180.0) var max_angle_degrees := 60.0


func create_runtime() -> BoidInfluenceRuntime:
	return Runtime.new(self)


## Applies the wander influence each tick. The per-boid wander angle is kept in the boid
## store's scratch array.
class Runtime extends BoidInfluenceRuntime:
	var jitter := 2.0
	var max_angle_radians := 1.0

	func _init(source_influence: BoidInfluenceWander) -> void:
		jitter = source_influence.jitter
		max_angle_radians = deg_to_rad(source_influence.max_angle_degrees)

	func apply(system: BoidSystem, boid_order: PackedInt32Array, from_index: int, to_index: int, weight: float,
			_max_speed: float, layer_accel: PackedVector2Array) -> void:
		var store := system.store
		var wander_angles := store.scratch
		var headings := store.heading
		var rng := system.rng
		var angle_step := 2.0 * jitter * sqrt(system.current_sim_dt)
		for order_index in range(from_index, to_index):
			var slot := boid_order[order_index]
			var wander_angle := clampf(wander_angles[slot] + (rng.randf() - 0.5) * angle_step, -max_angle_radians, max_angle_radians)
			wander_angles[slot] = wander_angle
			var wander_heading := headings[slot] + wander_angle
			layer_accel[slot] += Vector2(sin(wander_heading), cos(wander_heading)) * weight