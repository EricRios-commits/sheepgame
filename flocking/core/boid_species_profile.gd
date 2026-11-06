class_name BoidSpeciesProfile
extends Resource
## Behaviour of one species across its states. A species without a profile uses the system's
## default_profile.

## Species this profile applies to
@export var species: StringName = &"sheep"
## Behaviour for each state this species can be in. If several entries share a
## state name, only the first match is used.
@export var states: Array[BoidStateBehaviour] = []


func find_state(state_name: StringName) -> BoidStateBehaviour:
	for state_behaviour in states:
		if state_behaviour != null and state_behaviour.state == state_name:
			return state_behaviour
	return null


static func make_default(species_name: StringName = &"sheep", max_neighbours: int = 48) -> BoidSpeciesProfile:
	var profile := BoidSpeciesProfile.new()
	profile.species = species_name
	var state_behaviour := BoidStateBehaviour.new()
	state_behaviour.state = &"idle"
	state_behaviour.max_speed = 4.0
	state_behaviour.max_accel = 6.0
	var flock := BoidInfluenceFlock.new()
	flock.max_neighbours = max_neighbours
	var cruise := BoidInfluenceCruise.new()
	cruise.speed = 1.2
	var bounds := BoidInfluenceBounds.new()
	for pair in [[flock, 1.0], [cruise, 1.0], [bounds, 6.0]]:
		var entry := BoidInfluenceEntry.new()
		entry.influence = pair[0]
		entry.weight = pair[1]
		state_behaviour.influences.append(entry)
	profile.states.append(state_behaviour)
	return profile