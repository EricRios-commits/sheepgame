class_name BoidSystem
extends Node3D
## Owner of all simulation state for one interacting group
## behaviour is data. Boids are grouped by (species, state) each tick; every influence
## entry of a group runs once over that group's contiguous slot range and adds into a layer
## accumulator. Combine then spends the group's acceleration budget layer by layer in priority
## order.

enum Stage { SNAPSHOT, REBUILD_NEIGHBOURS, GATHER, COMBINE, INTEGRATE, GROUND, TRANSITIONS, COMMIT, PRESENT }
const STAGE_NAMES := ["Snapshot", "Neighbours", "Gather", "Combine", "Integrate", "Ground",
		"Transitions", "Commit", "Present"]
const MAX_STEPS_PER_FRAME := 4
const LUT_N := 16
const LAYER_COUNT := BoidInfluence.LAYER_COUNT

signal spawned(count: int)
signal present_requested
signal ticked(sim_dt: float)

@export var rng_seed := 12345
## Simulation rate, decoupled from the physics rate
@export_range(5, 120) var sim_hz := 30
@export var ground: BoidGround
@export var profiles: Array[BoidSpeciesProfile] = []
## Used by any species that has no profile
@export var default_profile: BoidSpeciesProfile
@export var interactions: BoidInteractionTable
@export var world_bounds := Rect2(-120.0, -120.0, 240.0, 240.0)
@export var use_world_bounds := true
## Transitions are evaluated for 1/stride of the boids per tick
@export_range(1, 10) var transition_stride := 3
@export var auto_spawn := true
@export var run_simulation := true

var store := BoidStore.new()
var vocab := BoidVocabulary.new()
var rng := RandomNumberGenerator.new()
var timer := BoidStageTimer.new(PackedStringArray(STAGE_NAMES))
var neighbours: BoidNeighbourStrategy = BoidNeighbourHash.new()
var table: BoidBehaviourTable
var spawned_total := 0
var removed_total := 0
var tick_count := 0
var cur_dt := 0.0

## Final per-boid acceleration (after Combine), indexed by slot.
var accel := PackedVector2Array()
## Raw per-layer accumulators (before Combine), indexed [layer][slot].
var layer_acc: Array[PackedVector2Array] = []

## Emitters published this tick (flat arrays, indexed 0..em_count-1).
var em_count := 0
var em_pos := PackedVector2Array()
var em_vel := PackedVector2Array()
var em_dir := PackedVector2Array()
var em_radius := PackedFloat32Array()
var em_cos_half := PackedFloat32Array()
var em_strength := PackedFloat32Array()
var em_kind := PackedInt32Array()
var em_lut := PackedFloat32Array()

## Debug tap for one boid (read by BoidDebugOverlay).
var debug_handle := BoidStore.INVALID_HANDLE
var debug_slot := -1
var debug_cohesion := Vector2.ZERO
var debug_alignment := Vector2.ZERO
var debug_separation := Vector2.ZERO
var debug_total := Vector2.ZERO
var debug_layers := PackedVector2Array()
var debug_neighbour_pos := PackedVector2Array()

var _zones: Array[BoidSpawnZone] = []
var _emitters: Array[BoidEmitter] = []
var _accum := 0.0
var _table_version := -1
var _group_of := PackedInt32Array()
var _group_start := PackedInt32Array()
var _group_cursor := PackedInt32Array()
var _group_order := PackedInt32Array()
var _warned_group := false
var _removal_queue := PackedInt64Array()
var _state_handles := PackedInt64Array()
var _state_values := PackedInt32Array()


func _init() -> void:
	for l in LAYER_COUNT:
		layer_acc.append(PackedVector2Array())
	debug_layers.resize(LAYER_COUNT)


func _ready() -> void:
	if ground == null:
		ground = BoidGround.new()
	if default_profile == null:
		default_profile = BoidSpeciesProfile.make_default()
	rng.seed = rng_seed
	if auto_spawn:
		spawn_all.call_deferred()


# public API

func register_zone(zone: BoidSpawnZone) -> void:
	if not _zones.has(zone):
		_zones.append(zone)


func register_emitter(e: BoidEmitter) -> void:
	if _emitters.has(e):
		return
	e.kind_id = vocab.emitter_kind_id(e.kind)
	_emitters.append(e)


func unregister_emitter(e: BoidEmitter) -> void:
	_emitters.erase(e)


## Call after changing profiles, interactions or default_profile at runtime.
func invalidate_table() -> void:
	table = null


func spawn_all() -> int:
	_zones.sort_custom(func(a: BoidSpawnZone, b: BoidSpawnZone) -> bool:
		return str(a.get_path()) < str(b.get_path()))
	rng.seed = rng_seed
	var n := 0
	for zone in _zones:
		n += _spawn_zone(zone)
	spawned_total += n
	spawned.emit(n)
	return n


## Queued; applied in the Commit stage.
func remove_boid(handle: int) -> void:
	_removal_queue.append(handle)


## Queued; applied in the Commit stage. Stale handles are ignored at commit time.
func request_state(handle: int, state_id: int) -> void:
	_state_handles.append(handle)
	_state_values.append(state_id)


func select_debug_boid(handle: int) -> void:
	debug_handle = handle


func alive_count() -> int:
	return store.count


## Pass -1 for "any". Linear scan; fine for game logic polled occasionally.
func count_by(species_id: int = -1, state_id: int = -1) -> int:
	var n := 0
	for i in store.count:
		if (species_id < 0 or store.species[i] == species_id) and (state_id < 0 or store.state[i] == state_id):
			n += 1
	return n


func check_invariants() -> bool:
	return store.count == spawned_total - removed_total and store.check_consistency()


# spawning

func _spawn_zone(zone: BoidSpawnZone) -> int:
	var cfg := zone.config
	if cfg == null or cfg.count <= 0:
		return 0
	var sp := vocab.species_id(cfg.species)
	var st := vocab.state_id(cfg.initial_state)
	var centre := zone.center_xz()
	for i in cfg.count:
		var xz := zone.local_to_world_xz(zone.sample_local(rng))
		var h := _initial_heading(cfg, xz, centre)
		var dir := Vector2(sin(h), cos(h))
		store.add(xz, dir * cfg.initial_speed, h, cfg.initial_speed, sp, st, ground.height_at(xz))
	return cfg.count


func _initial_heading(cfg: BoidSpawnConfig, xz: Vector2, centre: Vector2) -> float:
	match cfg.heading_policy:
		BoidSpawnConfig.HeadingPolicy.FIXED:
			return deg_to_rad(cfg.fixed_heading_degrees)
		BoidSpawnConfig.HeadingPolicy.RADIAL_OUT, BoidSpawnConfig.HeadingPolicy.TOWARD_CENTER:
			var d := xz - centre
			if cfg.heading_policy == BoidSpawnConfig.HeadingPolicy.TOWARD_CENTER:
				d = -d
			if d.length_squared() < 1e-8:
				return rng.randf() * TAU
			return atan2(d.x, d.y)
		_:
			return rng.randf() * TAU


# tick

func _physics_process(delta: float) -> void:
	if not run_simulation:
		return
	var dt := 1.0 / float(sim_hz)
	_accum += delta
	var steps := 0
	while _accum >= dt and steps < MAX_STEPS_PER_FRAME:
		tick(dt)
		_accum -= dt
		steps += 1
	if steps == MAX_STEPS_PER_FRAME:
		_accum = 0.0


func tick(dt: float) -> void:
	cur_dt = dt
	timer.begin_tick()
	timer.begin(Stage.SNAPSHOT)
	_stage_snapshot()
	timer.end(Stage.SNAPSHOT)
	timer.begin(Stage.REBUILD_NEIGHBOURS)
	_stage_rebuild_neighbours()
	timer.end(Stage.REBUILD_NEIGHBOURS)
	timer.begin(Stage.GATHER)
	_stage_gather()
	timer.end(Stage.GATHER)
	timer.begin(Stage.COMBINE)
	_stage_combine()
	timer.end(Stage.COMBINE)
	timer.begin(Stage.INTEGRATE)
	_stage_integrate(dt)
	timer.end(Stage.INTEGRATE)
	timer.begin(Stage.GROUND)
	_stage_ground()
	timer.end(Stage.GROUND)
	timer.begin(Stage.TRANSITIONS)
	_stage_transitions()
	timer.end(Stage.TRANSITIONS)
	timer.begin(Stage.COMMIT)
	_stage_commit()
	timer.end(Stage.COMMIT)
	timer.begin(Stage.PRESENT)
	present_requested.emit()
	timer.end(Stage.PRESENT)
	timer.end_tick()
	tick_count += 1
	ticked.emit(dt)



func _stage_snapshot() -> void:
	if table == null or _table_version != vocab.version:
		table = BoidBehaviourTable.build(self)
		_table_version = vocab.version
	_publish_emitters()
	_sort_groups()


func _publish_emitters() -> void:
	var count := 0
	for e in _emitters:
		if e.active:
			count += 1
	em_count = count
	em_pos.resize(count)
	em_vel.resize(count)
	em_dir.resize(count)
	em_radius.resize(count)
	em_cos_half.resize(count)
	em_strength.resize(count)
	em_kind.resize(count)
	em_lut.resize(count * LUT_N)
	var k := 0
	for e in _emitters:
		if not e.active:
			continue
		em_pos[k] = e.xz()
		em_vel[k] = e.vel
		em_dir[k] = e.dir_xz()
		em_radius[k] = maxf(e.radius, 0.01)
		em_cos_half[k] = cos(deg_to_rad(e.cone_half_angle_degrees))
		em_strength[k] = e.strength
		em_kind[k] = e.kind_id
		var base := k * LUT_N
		for j in LUT_N:
			var u := float(j) / float(LUT_N - 1)
			em_lut[base + j] = e.curve.sample_baked(u) if e.curve != null else 1.0 - u
		k += 1


func _sort_groups() -> void:
	var n := store.count
	var ng := table.group_count
	var n_states := table.n_states
	_group_start.resize(ng + 1)
	_group_start.fill(0)
	_group_cursor.resize(ng)
	_group_of.resize(n)
	_group_order.resize(n)
	var species := store.species
	var state := store.state
	for i in n:
		var g := species[i] * n_states + state[i]
		if g < 0 or g >= ng:
			if not _warned_group:
				push_error("BoidSystem: boid with species/state id outside the vocabulary. Register names via vocab first.")
				_warned_group = true
			g = 0
		_group_of[i] = g
		_group_start[g + 1] += 1
	for g in ng:
		_group_start[g + 1] += _group_start[g]
		_group_cursor[g] = _group_start[g]
	for i in n:
		var g := _group_of[i]
		var at := _group_cursor[g]
		_group_order[at] = i
		_group_cursor[g] = at + 1


func _stage_rebuild_neighbours() -> void:
	neighbours.rebuild(store, table.max_query_radius)


## Influence-major dispatch: one virtual call per (group, entry) over a contiguous slot range.
func _stage_gather() -> void:
	var n := store.count
	for l in LAYER_COUNT:
		var a := layer_acc[l]
		a.resize(n)
		a.fill(Vector2.ZERO)
	debug_slot = store.slot_of(debug_handle)
	debug_cohesion = Vector2.ZERO
	debug_alignment = Vector2.ZERO
	debug_separation = Vector2.ZERO
	debug_neighbour_pos.clear()
	if n == 0:
		return
	var t := table
	for g in t.group_count:
		var from := _group_start[g]
		var to := _group_start[g + 1]
		if from == to:
			continue
		var vmax := t.max_speed[g]
		for e in range(t.entry_start[g], t.entry_start[g + 1]):
			t.entry_runtime[e].apply(self, _group_order, from, to, t.entry_weight[e], vmax,
					layer_acc[t.entry_layer[e]])


## Combination policy: prioritised acceleration allocation. Layers are visited in
## priority order (SAFETY, THREAT, SOCIAL, AMBIENT). Each layer's vector is added only as far
## as the group's max_accel budget allows; the budget is spent by vector LENGTH, so a high
## priority layer that is large leaves nothing for the layers below it, even if directions
## would partly cancel. A boid fleeing a predator therefore stops caring about cohesion.
func _stage_combine() -> void:
	var n := store.count
	accel.resize(n)
	var layers := layer_acc
	var max_accel := table.max_accel
	for i in n:
		var max_a := max_accel[_group_of[i]]
		var total := Vector2.ZERO
		var used := 0.0
		for l in LAYER_COUNT:
			var v := layers[l][i]
			var len2 := v.length_squared()
			if len2 < 1e-12:
				continue
			var room := max_a - used
			if room <= 0.0:
				break
			var len := sqrt(len2)
			if len > room:
				v *= room / len
				len = room
			total += v
			used += len
		accel[i] = total
	if debug_slot >= 0 and debug_slot < n:
		debug_total = accel[debug_slot]
		for l in LAYER_COUNT:
			debug_layers[l] = layers[l][debug_slot]
	else:
		debug_total = Vector2.ZERO
		debug_layers.fill(Vector2.ZERO)


func _stage_integrate(dt: float) -> void:
	var n := store.count
	if accel.size() != n:
		return
	var pos := store.pos
	var vel := store.vel
	var spd := store.speed
	var hdg := store.heading
	var max_speed := table.max_speed
	var clamp_pos := use_world_bounds
	var b_min := world_bounds.position
	var b_max := world_bounds.end
	for i in n:
		var max_s := max_speed[_group_of[i]]
		var v := vel[i] + accel[i] * dt
		var s := v.length()
		if s > max_s:
			v *= max_s / s
			s = max_s
		vel[i] = v
		spd[i] = s
		if s > 0.001:
			hdg[i] = atan2(v.x, v.y)
		var p := pos[i] + v * dt
		if clamp_pos:
			p = p.clamp(b_min, b_max)
		pos[i] = p


func _stage_ground() -> void:
	var pos := store.pos
	var gh := store.ground_h
	for i in store.count:
		gh[i] = ground.height_at(pos[i])


func _stage_transitions() -> void:
	var n := store.count
	if n == 0:
		return
	var t := table
	var timers := store.state_timer
	var pos := store.pos
	var dt := cur_dt
	var stride := transition_stride
	var phase := tick_count % stride
	for i in n:
		timers[i] += dt
		if (i + phase) % stride != 0:
			continue
		var g := _group_of[i]
		var first := t.tr_start[g]
		var last := t.tr_start[g + 1]
		for k in range(first, last):
			var trig := t.tr_trigger[k]
			var hit := false
			if trig == BoidTransition.Trigger.TIMER:
				hit = timers[i] >= t.tr_seconds[k]
			elif timers[i] >= t.tr_min_time[k]:
				var any := em_count > 0 and _emitter_within(pos[i], t.tr_emitter_kind[k], t.tr_dist2[k])
				hit = any if trig == BoidTransition.Trigger.EMITTER_NEAR else not any
			if hit:
				request_state(store.handle_at(i), t.tr_to[k])
				break


func _emitter_within(p: Vector2, kind: int, dist2: float) -> bool:
	for e in em_count:
		if kind >= 0 and em_kind[e] != kind:
			continue
		if (em_pos[e] - p).length_squared() <= dist2:
			return true
	return false


func _stage_commit() -> void:
	for i in _state_handles.size():
		var slot := store.slot_of(_state_handles[i])
		if slot >= 0 and store.state[slot] != _state_values[i]:
			store.state[slot] = _state_values[i]
			store.state_timer[slot] = 0.0
	_state_handles.clear()
	_state_values.clear()
	if not _removal_queue.is_empty():
		removed_total += store.remove_many(_removal_queue)
		_removal_queue.clear()
