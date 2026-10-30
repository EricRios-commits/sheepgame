class_name BoidSystem
extends Node3D

enum Stage { SNAPSHOT, REBUILD_NEIGHBOURS, GATHER, COMBINE, INTEGRATE, GROUND, TRANSITIONS, COMMIT, PRESENT }
const STAGE_NAMES := ["Snapshot", "Neighbours", "Gather", "Combine", "Integrate", "Ground",
		"Transitions", "Commit", "Present"]
const MAX_STEPS_PER_FRAME := 4

signal spawned(count: int)
signal present_requested
signal ticked(sim_dt: float)

@export var rng_seed := 12345

@export_range(5, 120) var sim_hz := 30
@export var ground: BoidGround
@export var max_speed := 6.0
@export var auto_spawn := true
@export var run_simulation := true

var store := BoidStore.new()
var vocab := BoidVocabulary.new()
var rng := RandomNumberGenerator.new()
var timer := BoidStageTimer.new(PackedStringArray(STAGE_NAMES))
var spawned_total := 0
var removed_total := 0
var tick_count := 0

var _zones: Array[BoidSpawnZone] = []
var _accum := 0.0
var _removal_queue := PackedInt64Array()
var _state_handles := PackedInt64Array()
var _state_values := PackedInt32Array()


func _ready() -> void:
	if ground == null:
		ground = BoidGround.new()
	rng.seed = rng_seed
	if auto_spawn:
		spawn_all.call_deferred()


# public API
func register_zone(zone: BoidSpawnZone) -> void:
	if not _zones.has(zone):
		_zones.append(zone)


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



func remove_boid(handle: int) -> void:
	_removal_queue.append(handle)



func request_state(handle: int, state_id: int) -> void:
	_state_handles.append(handle)
	_state_values.append(state_id)


func alive_count() -> int:
	return store.count



func count_by(species_id: int = -1, state_id: int = -1) -> int:
	var n := 0
	for i in store.count:
		if (species_id < 0 or store.species[i] == species_id) and (state_id < 0 or store.state[i] == state_id):
			n += 1
	return n



func check_invariants() -> bool:
	return store.count == spawned_total - removed_total and store.check_consistency()


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
	timer.begin(Stage.PRESENT);
	present_requested.emit()
	timer.end(Stage.PRESENT)
	timer.end_tick()
	tick_count += 1
	ticked.emit(dt)


func _stage_snapshot() -> void:
	pass


func _stage_rebuild_neighbours() -> void:
	pass


func _stage_gather() -> void:
	pass


func _stage_combine() -> void:
	pass


func _stage_integrate(dt: float) -> void:
	var pos := store.pos
	var vel := store.vel
	var spd := store.speed
	var hdg := store.heading
	for i in store.count:
		var v := vel[i]
		var s := v.length()
		if s > max_speed:
			v *= max_speed / s
			s = max_speed
			vel[i] = v
		spd[i] = s
		if s > 0.001:
			hdg[i] = atan2(v.x, v.y)
		pos[i] += v * dt


func _stage_ground() -> void:
	var pos := store.pos
	var gh := store.ground_h
	for i in store.count:
		gh[i] = ground.height_at(pos[i])



func _stage_transitions() -> void:
	pass


func _stage_commit() -> void:
	for i in _state_handles.size():
		var slot := store.slot_of(_state_handles[i])
		if slot >= 0:
			store.state[slot] = _state_values[i]
			store.state_timer[slot] = 0.0
	_state_handles.clear()
	_state_values.clear()
	if not _removal_queue.is_empty():
		removed_total += store.remove_many(_removal_queue)
		_removal_queue.clear()
