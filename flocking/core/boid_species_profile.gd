class_name BoidSpeciesProfile
extends Resource
## Behaviour of one species across its states. A species without a profile uses the system's
## default_profile.

@export var species: StringName = &"sheep"
@export var states: Array[BoidStateBehaviour] = []


func find_state(state_name: StringName) -> BoidStateBehaviour:
	for s in states:
		if s != null and s.state == state_name:
			return s
	return null


static func make_default(species_name: StringName = &"sheep", max_neighbours: int = 48) -> BoidSpeciesProfile:
	var p := BoidSpeciesProfile.new()
	p.species = species_name
	var sb := BoidStateBehaviour.new()
	sb.state = &"idle"
	sb.max_speed = 4.0
	sb.max_accel = 6.0
	var flock := BoidInfluenceFlock.new()
	flock.max_neighbours = max_neighbours
	var cruise := BoidInfluenceCruise.new()
	cruise.speed = 1.2
	var bounds := BoidInfluenceBounds.new()
	for pair in [[flock, 1.0], [cruise, 1.0], [bounds, 6.0]]:
		var e := BoidInfluenceEntry.new()
		e.influence = pair[0]
		e.weight = pair[1]
		sb.influences.append(e)
	p.states.append(sb)
	return p