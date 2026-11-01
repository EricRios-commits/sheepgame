class_name BoidStore
extends RefCounted
## Flat typed storage for all boids of one system

const ID_BITS := 32
const ID_MASK := 0xFFFFFFFF
const INVALID_HANDLE := -1

var count := 0
var active_count := 0

var pos := PackedVector2Array()
var vel := PackedVector2Array()
var ground_h := PackedFloat32Array()
var heading := PackedFloat32Array()
var speed := PackedFloat32Array()
var species := PackedInt32Array()
var state := PackedInt32Array()
var state_timer := PackedFloat32Array()
var scratch := PackedFloat32Array()
var pen_id := PackedInt32Array()
var pen_spot := PackedInt32Array()

var _id_of_slot := PackedInt32Array()
var _slot_of_id := PackedInt32Array()
var _gen_of_id := PackedInt32Array()
var _free_ids := PackedInt32Array()


## New boids always join the ACTIVE region.
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
	pen_id.append(-1)
	pen_spot.append(-1)
	_id_of_slot.append(id)
	_slot_of_id[id] = count
	count += 1
	if count - 1 != active_count:
		_swap_slots(count - 1, active_count)
	active_count += 1
	return (_gen_of_id[id] << ID_BITS) | id


## Returns the current slot for a handle, or -1 if the handle is stale or invalid.
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


func is_active_slot(slot: int) -> bool:
	return slot >= 0 and slot < active_count


func handle_at(slot: int) -> int:
	var id := _id_of_slot[slot]
	return (_gen_of_id[id] << ID_BITS) | id


## Move an active boid into the frozen region. Returns its new slot. Freezing is one-way.
func freeze(slot: int) -> int:
	if slot < 0 or slot >= active_count:
		return slot
	var last := active_count - 1
	_swap_slots(slot, last)
	active_count -= 1
	return last


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
	if slot < active_count:
		var last_active := active_count - 1
		_swap_slots(slot, last_active)
		slot = last_active
		active_count -= 1
	var last := count - 1
	_swap_slots(slot, last)
	pos.resize(last)
	vel.resize(last)
	ground_h.resize(last)
	heading.resize(last)
	speed.resize(last)
	species.resize(last)
	state.resize(last)
	state_timer.resize(last)
	scratch.resize(last)
	pen_id.resize(last)
	pen_spot.resize(last)
	_id_of_slot.resize(last)
	_slot_of_id[id] = -1
	_gen_of_id[id] += 1
	_free_ids.append(id)
	count = last


func _swap_slots(a: int, b: int) -> void:
	if a == b:
		return
	_swap_v2(pos, a, b)
	_swap_v2(vel, a, b)
	_swap_f(ground_h, a, b)
	_swap_f(heading, a, b)
	_swap_f(speed, a, b)
	_swap_f(state_timer, a, b)
	_swap_f(scratch, a, b)
	_swap_i(species, a, b)
	_swap_i(state, a, b)
	_swap_i(pen_id, a, b)
	_swap_i(pen_spot, a, b)
	_swap_i(_id_of_slot, a, b)
	_slot_of_id[_id_of_slot[a]] = a
	_slot_of_id[_id_of_slot[b]] = b


func _swap_v2(arr: PackedVector2Array, a: int, b: int) -> void:
	var t := arr[a]
	arr[a] = arr[b]
	arr[b] = t


func _swap_f(arr: PackedFloat32Array, a: int, b: int) -> void:
	var t := arr[a]
	arr[a] = arr[b]
	arr[b] = t


func _swap_i(arr: PackedInt32Array, a: int, b: int) -> void:
	var t := arr[a]
	arr[a] = arr[b]
	arr[b] = t


## Hash of the simulation-relevant state, for determinism checks (section 10).
func state_hash() -> int:
	var h := hash(pos)
	h = (h * 31 + hash(vel)) & 0xFFFFFFFF
	h = (h * 31 + hash(heading)) & 0xFFFFFFFF
	h = (h * 31 + hash(species)) & 0xFFFFFFFF
	h = (h * 31 + hash(state)) & 0xFFFFFFFF
	h = (h * 31 + hash(pen_id)) & 0xFFFFFFFF
	h = (h * 31 + hash(_id_of_slot)) & 0xFFFFFFFF
	h = (h * 31 + active_count) & 0xFFFFFFFF
	return (h * 31 + count) & 0xFFFFFFFF


## Structural self-check used by tests and the invariant checker.
func check_consistency() -> bool:
	if pos.size() != count or vel.size() != count or ground_h.size() != count \
			or heading.size() != count or speed.size() != count or species.size() != count \
			or state.size() != count or state_timer.size() != count \
			or scratch.size() != count or pen_id.size() != count or pen_spot.size() != count \
			or _id_of_slot.size() != count:
		return false
	if active_count < 0 or active_count > count:
		return false
	for slot in count:
		if _slot_of_id[_id_of_slot[slot]] != slot:
			return false
	var live := 0
	for id in _slot_of_id.size():
		if _slot_of_id[id] >= 0:
			live += 1
	return live == count