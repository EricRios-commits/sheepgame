class_name BoidVocabulary
extends RefCounted

var species_names: Array[StringName] = []
var state_names: Array[StringName] = []
var _species_ids := {}
var _state_ids := {}

func species_id(n: StringName) -> int:
	if not _species_ids.has(n):
		_species_ids[n] = species_names.size()
		species_names.append(n)
	return _species_ids[n]


func state_id(n: StringName) -> int:
	if not _state_ids.has(n):
		_state_ids[n] = state_names.size()
		state_names.append(n)
	return _state_ids[n]


func species_name(id: int) -> StringName:
	return species_names[id]


func state_name(id: int) -> StringName:
	return state_names[id]
