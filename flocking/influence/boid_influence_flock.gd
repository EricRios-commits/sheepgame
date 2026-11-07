class_name BoidInfluenceFlock
extends BoidInfluence
## Cohesion + alignment + separation from one shared neighbour query per boid
## Per-species-pair multipliers come from the system's interaction table.

## Radius, in world units, within which a boid sees neighbours for cohesion and alignment.
## Also the neighbour query radius reported to the system.
@export_range(0.5, 50.0, 0.1, "or_greater") var perception_radius := 6.0
## Neighbours closer than this, in world units, push the boid away. The push grows as the
## neighbour gets closer. Should be smaller than perception_radius.
@export_range(0.1, 20.0, 0.1, "or_greater") var separation_radius := 1.8
## Maximum number of neighbours considered per boid per tick (size of the query buffer).
@export_range(1, 512) var max_neighbours := 48
## Strength of the pull toward the average position of neighbours. Scaled by the entry weight
## and by the species-pair cohesion multiplier, if interactions are configured.
@export var cohesion := 0.8
## Strength of the steering toward the average velocity of neighbours. Scaled by the entry
## weight and by the species-pair alignment multiplier, if interactions are configured.
@export var alignment := 1.5
## Strength of the push away from neighbours inside separation_radius. Scaled by the entry
## weight and by the species-pair separation multiplier, if interactions are configured.
@export var separation := 5.0


func _init() -> void:
	layer = Layer.SOCIAL


func neighbour_radius() -> float:
	return perception_radius


func create_runtime() -> BoidInfluenceRuntime:
	return Runtime.new(self)


## Applies the flocking influence each tick, using one neighbour query per boid.
class Runtime extends BoidInfluenceRuntime:
	var perception_radius := 6.0
	var separation_radius := 1.8
	var cohesion_weight := 0.8
	var alignment_weight := 1.5
	var separation_weight := 5.0
	var _neighbour_buffer := PackedInt32Array()

	func _init(source_influence: BoidInfluenceFlock) -> void:
		perception_radius = source_influence.perception_radius
		separation_radius = source_influence.separation_radius
		cohesion_weight = source_influence.cohesion
		alignment_weight = source_influence.alignment
		separation_weight = source_influence.separation
		_neighbour_buffer.resize(source_influence.max_neighbours)

	func apply(system: BoidSystem, boid_order: PackedInt32Array, from_index: int, to_index: int, weight: float,
			max_speed: float, layer_accel: PackedVector2Array) -> void:
		var store := system.store
		var positions := store.pos
		var velocities := store.vel
		var species_ids := store.species
		var neighbour_strategy := system.neighbours
		var neighbour_buffer := _neighbour_buffer
		var debug_slot := system.debug_slot
		var table := system.behaviour_table
		var uses_interactions := table.has_interactions
		var species_count := table.n_species
		var cohesion_multipliers := table.ix_cohesion
		var alignment_multipliers := table.ix_alignment
		var separation_multipliers := table.ix_separation
		var separation_radius_squared := separation_radius * separation_radius
		var inverse_separation_radius := 1.0 / separation_radius
		var inverse_perception_radius := 1.0 / perception_radius
		var inverse_max_speed := 1.0 / maxf(max_speed, 0.01)
		for order_index in range(from_index, to_index):
			var slot := boid_order[order_index]
			var boid_position := positions[slot]
			var boid_velocity := velocities[slot]
			var neighbour_count := neighbour_strategy.query(boid_position, perception_radius, slot, neighbour_buffer)
			if neighbour_count == 0:
				continue
			var position_sum := Vector2.ZERO
			var velocity_sum := Vector2.ZERO
			var separation_accel := Vector2.ZERO
			var cohesion_accel := Vector2.ZERO
			var alignment_accel := Vector2.ZERO
			if not uses_interactions:
				for j in neighbour_count:
					var neighbour_slot := neighbour_buffer[j]
					var neighbour_position := positions[neighbour_slot]
					position_sum += neighbour_position
					velocity_sum += velocities[neighbour_slot]
					var offset := boid_position - neighbour_position
					var distance_squared := offset.length_squared()
					if distance_squared < separation_radius_squared:
						if distance_squared > 1e-8:
							separation_accel += offset * (1.0 / sqrt(distance_squared) - inverse_separation_radius)
						else:
							separation_accel += Vector2.from_angle(float(slot) * 2.399963)
				var inverse_neighbour_count := 1.0 / float(neighbour_count)
				cohesion_accel = (position_sum * inverse_neighbour_count - boid_position) * inverse_perception_radius
				alignment_accel = (velocity_sum * inverse_neighbour_count - boid_velocity) * inverse_max_speed
			else:
				var species_row := species_ids[slot] * species_count
				var cohesion_multiplier_sum := 0.0
				var alignment_multiplier_sum := 0.0
				for j in neighbour_count:
					var neighbour_slot := neighbour_buffer[j]
					var neighbour_position := positions[neighbour_slot]
					var pair_index := species_row + species_ids[neighbour_slot]
					var cohesion_multiplier := cohesion_multipliers[pair_index]
					var alignment_multiplier := alignment_multipliers[pair_index]
					position_sum += neighbour_position * cohesion_multiplier
					cohesion_multiplier_sum += cohesion_multiplier
					velocity_sum += velocities[neighbour_slot] * alignment_multiplier
					alignment_multiplier_sum += alignment_multiplier
					var offset := boid_position - neighbour_position
					var distance_squared := offset.length_squared()
					if distance_squared < separation_radius_squared:
						if distance_squared > 1e-8:
							separation_accel += offset * ((1.0 / sqrt(distance_squared) - inverse_separation_radius) * separation_multipliers[pair_index])
						else:
							separation_accel += Vector2.from_angle(float(slot) * 2.399963) * separation_multipliers[pair_index]
				if cohesion_multiplier_sum > 1e-6:
					cohesion_accel = (position_sum / cohesion_multiplier_sum - boid_position) * inverse_perception_radius
				if alignment_multiplier_sum > 1e-6:
					alignment_accel = (velocity_sum / alignment_multiplier_sum - boid_velocity) * inverse_max_speed
			layer_accel[slot] += (cohesion_accel * cohesion_weight + alignment_accel * alignment_weight + separation_accel * separation_weight) * weight
			if slot == debug_slot:
				system.debug_cohesion = cohesion_accel * cohesion_weight * weight
				system.debug_alignment = alignment_accel * alignment_weight * weight
				system.debug_separation = separation_accel * separation_weight * weight
				system.debug_neighbour_pos.resize(neighbour_count)
				for j in neighbour_count:
					system.debug_neighbour_pos[j] = positions[neighbour_buffer[j]]