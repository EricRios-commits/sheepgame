class_name BoidStore
extends RefCounted

const ID_BITS := 32
const ID_MASK := 0xFFFFFFFF
const INVALID_HANDLE := -1

var count := 0

var pos := PackedVector2Array()         
var vel := PackedVector2Array()         
var ground_h := PackedFloat32Array()    
var heading := PackedFloat32Array()     
var speed := PackedFloat32Array()
var species := PackedInt32Array()
var state := PackedInt32Array()
var state_timer := PackedFloat32Array()
var scratch := PackedFloat32Array()      

var _id_of_slot := PackedInt32Array()
var _slot_of_id := PackedInt32Array()    
var _gen_of_id := PackedInt32Array()
var _free_ids := PackedInt32Array()


func add(p: Vector2, v: Vector2, h: float, spd: float, species_id: int, state_id: int, ground: float = 0.0) -> int:
	var id: int
	if _free_ids.is_empty():
		id = _gen_of_id.size()
		_gen_of_id.append(1)
		_slot_of_id.append(-1)
	else:
		id = _free_ids[_free_ids.size() - 1]
		_free_ids.resize(_free_ids.size() - 1)
	pos.append(p)
	vel.append(v)
	ground_h.append(ground)
	heading.append(h)
	speed.append(spd)
	species.append(species_id)
	state.append(state_id)
	state_timer.append(0.0)
	scratch.append(0.0)
	_id_of_slot.append(id)
	_slot_of_id[id] = count
	count += 1
	return (_gen_of_id[id] << ID_BITS) | id



func slot_of(handle: int) -> int:
	if handle <= 0:
		return -1
	var id := handle & ID_MASK
	if id >= _gen_of_id.size():
		return -1
	if _gen_of_id[id] != (handle >> ID_BITS):
		return -1
	return _slot_of_id[id]


func is_valid(handle: int) -> bool:
	return slot_of(handle) >= 0


func handle_at(slot: int) -> int:
	var id := _id_of_slot[slot]
	return (_gen_of_id[id] << ID_BITS) | id


func remove(handle: int) -> bool:
	var slot := slot_of(handle)
	if slot < 0:
		return false
	_remove_slot(slot)
	return true

func remove_many(handles: PackedInt64Array) -> int:
	var slots := PackedInt32Array()
	for h in handles:
		var s := slot_of(h)
		if s >= 0:
			slots.append(s)
	slots.sort()
	var removed := 0
	var prev := -1
	for k in range(slots.size() - 1, -1, -1):
		var slot := slots[k]
		if slot == prev:
			continue
		_remove_slot(slot)
		prev = slot
		removed += 1
	return removed

func _remove_slot(slot: int) -> void:
	var id := _id_of_slot[slot]
	var last := count - 1
	if slot != last:
		pos[slot] = pos[last]
		vel[slot] = vel[last]
		ground_h[slot] = ground_h[last]
		heading[slot] = heading[last]
		speed[slot] = speed[last]
		species[slot] = species[last]
		state[slot] = state[last]
		state_timer[slot] = state_timer[last]
		scratch[slot] = scratch[last]
		var moved := _id_of_slot[last]
		_id_of_slot[slot] = moved
		_slot_of_id[moved] = slot
	pos.resize(last)
	vel.resize(last)
	ground_h.resize(last)
	heading.resize(last)
	speed.resize(last)
	species.resize(last)
	state.resize(last)
	state_timer.resize(last)
	scratch.resize(last)
	_id_of_slot.resize(last)
	_slot_of_id[id] = -1
	_gen_of_id[id] += 1
	_free_ids.append(id)
	count = last


func state_hash() -> int:
	var h := hash(pos)
	h = (h * 31 + hash(vel)) & 0xFFFFFFFF
	h = (h * 31 + hash(heading)) & 0xFFFFFFFF
	h = (h * 31 + hash(species)) & 0xFFFFFFFF
	h = (h * 31 + hash(state)) & 0xFFFFFFFF
	h = (h * 31 + hash(_id_of_slot)) & 0xFFFFFFFF
	return (h * 31 + count) & 0xFFFFFFFF


func check_consistency() -> bool:
	if pos.size() != count or vel.size() != count or ground_h.size() != count \
			or heading.size() != count or speed.size() != count or species.size() != count \
			or state.size() != count or state_timer.size() != count \
			or scratch.size() != count or _id_of_slot.size() != count:
		return false
	for slot in count:
		if _slot_of_id[_id_of_slot[slot]] != slot:
			return false
	var live := 0
	for id in _slot_of_id.size():
		if _slot_of_id[id] >= 0:
			live += 1
	return live == count
