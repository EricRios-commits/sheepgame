class_name BoidVocabulary
extends RefCounted
## StringName <-> int conversion
## Used at startup only

var species_names: Array[StringName] = []
var state_names: Array[StringName] = []
var emitter_kind_names: Array[StringName] = []
## Bumped whenever a new name is registered
var version := 0
var _species_ids := {}
var _emitter_ids := {}
var _state_ids := {}


func species_id(n: StringName) -> int:
	if not _species_ids.has(n):
		_species_ids[n] = species_names.size()
		species_names.append(n)
		version += 1
	return _species_ids[n]


func state_id(n: StringName) -> int:
	if not _state_ids.has(n):
		_state_ids[n] = state_names.size()
		state_names.append(n)
		version += 1
	return _state_ids[n]


func species_name(id: int) -> StringName:
	return species_names[id]


func state_name(id: int) -> StringName:
	return state_names[id]


func emitter_kind_id(n: StringName) -> int:
	if n == &"":
		return -1
	if not _emitter_ids.has(n):
		_emitter_ids[n] = emitter_kind_names.size()
		emitter_kind_names.append(n)
		version += 1
	return _emitter_ids[n]