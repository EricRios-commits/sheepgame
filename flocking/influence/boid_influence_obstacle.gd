class_name BoidInfluenceObstacle
extends BoidInfluence
## Steers away from baked obstacles (walls, rocks, unwalkable ground). SAFETY layer, so it
## wins the acceleration budget over threats and flocking

## Distance, in world units, from a boid's edge to an obstacle at which the push starts.
## The push is zero at this distance and grows quadratically as the boid gets closer.
## Capped at the obstacle field's max distance minus the boid radius.
@export_range(0.5, 10.0, 0.1, "or_greater") var margin := 3.0
## Strength of the sideways push along the obstacle surface. The side is whichever way the
## boid is already moving along the surface, so boids slide past instead of stalling.
@export var slide := 0.6
## Extra outward push per unit of speed the boid is moving toward the obstacle. Higher values
## stop fast approaches harder.
@export var brake := 0.25


func _init() -> void:
	layer = Layer.SAFETY


func create_runtime() -> BoidInfluenceRuntime:
	return Runtime.new(self)


## Applies the obstacle avoidance each tick, using the system's baked obstacle field.
class Runtime extends BoidInfluenceRuntime:
	var margin := 3.0
	var slide := 0.6
	var brake := 0.25
	var field_override: BoidObstacleField

	func _init(source_influence: BoidInfluenceObstacle) -> void:
		margin = source_influence.margin
		slide = source_influence.slide
		brake = source_influence.brake

	func apply(system: BoidSystem, boid_order: PackedInt32Array, from_index: int, to_index: int, weight: float,
			_max_speed: float, layer_accel: PackedVector2Array) -> void:
		var field := field_override if field_override != null else system.obstacles
		if field == null:
			return
		var positions := system.store.pos
		var velocities := system.store.vel
		var boid_radius := system.boid_radius
		var effective_margin := minf(margin, field.max_dist - boid_radius)
		var reach := boid_radius + effective_margin + field.cell
		var field_dist := field.dist
		var field_width := field.width
		var field_depth := field.depth
		var field_origin_x := field.origin.x
		var field_origin_z := field.origin.y
		var inverse_cell := 1.0 / field.cell
		for order_index in range(from_index, to_index):
			var slot := boid_order[order_index]
			var boid_position := positions[slot]
			var cell_x := clampi(int((boid_position.x - field_origin_x) * inverse_cell), 0, field_width - 1)
			var cell_z := clampi(int((boid_position.y - field_origin_z) * inverse_cell), 0, field_depth - 1)
			if field_dist[cell_z * field_width + cell_x] >= reach:
				continue
			var field_sample := field.sample(boid_position)
			var gap := field_sample.x - boid_radius
			if gap >= effective_margin:
				continue
			var surface_normal := Vector2(field_sample.y, field_sample.z)
			if surface_normal.length_squared() < 1e-8:
				continue
			var closeness := 1.0 - maxf(gap, 0.0) / effective_margin
			closeness *= closeness
			var boid_velocity := velocities[slot]
			var tangent := Vector2(-surface_normal.y, surface_normal.x)
			var slide_side := 1.0 if boid_velocity.dot(tangent) >= 0.0 else -1.0
			layer_accel[slot] += (surface_normal * (1.0 + maxf(-boid_velocity.dot(surface_normal), 0.0) * brake) + tangent * (slide_side * slide)) * (closeness * weight)
