class_name BoidSystem
extends Node3D
## Owner of all simulation state for one interacting group. The class has grown way too large
## should probably be split, but I'm lazy. This should 100% be split into like 6 classes, but works for now

## Phases of one simulation tick, in execution order. Used to index per-stage timings.
enum Stage { SNAPSHOT, REBUILD_NEIGHBOURS, GATHER, COMBINE, INTEGRATE, GROUND, TRANSITIONS, COMMIT, PRESENT }
## State of one spot in a BoidPenStorage.
enum SpotState {
	## Nobody is using the spot.
	FREE,
	## Claimed by a boid that has not arrived yet. Unused for now (instant snap claims and
	## finalizes in the same step) it exists so a walk-in entry can reserve a spot.
	RESERVED,
	## A boid is penned on the spot.
	OCCUPIED,
}
const STAGE_NAMES := ["Snapshot", "Neighbours", "Gather", "Combine", "Integrate", "Ground",
		"Transitions", "Commit", "Present"]
## Cap on simulation ticks per physics frame. If the cap is hit, the leftover time is dropped.
const MAX_STEPS_PER_FRAME := 4
## Number of samples taken from each emitter's strength curve when building its lookup table.
const CURVE_LUT_SAMPLES := 16
const LAYER_COUNT := BoidInfluence.LAYER_COUNT
## Capacity of a storage that does not snap to spots.
const UNLIMITED_CAPACITY := 1 << 30
## Distance to its spot, in world units, over which a walking boid fades out obstacle
## avoidance, so spots close to a wall can still be reached.
const WALK_AVOIDANCE_FADE_DISTANCE := 2.0
## A walking boid is snapped onto its spot if it takes longer than its straight-line travel
## time times this factor, plus WALK_TIMEOUT_SECONDS. Safety net for boids that get stuck.
const WALK_TIMEOUT_FACTOR := 3.0
const WALK_TIMEOUT_SECONDS := 2.0

## Special states, registered in every system. PENNED is terminal and frozen, entering DEAD
## removes the boid in the same Commit.
const PENNED_STATE := &"penned"
const DEAD_STATE := &"dead"
## State of a boid walking from a walking BoidPenEntrance to its spot in a storage. Normal
## steering is bypassed while in it: the system walks the boid toward its spot at constant
## speed, deflected around obstacles. Only DEAD can be requested for a boid in this state.
const ENTERING_STATE := &"entering"

## Emitted after spawn_all() with the number of boids actually placed.
signal spawned(count: int)
## Emitted once per tick, during the Present stage.
signal present_requested
## Emitted at the end of every simulation tick with the tick length in seconds.
signal ticked(sim_dt: float)
## Emitted when a boid is accepted into a storage.
signal boid_penned(storage_index: int, species_id: int)
## Emitted when a boid enters the DEAD state, with its ground position at that moment.
signal boid_died(species_id: int, position: Vector2)

## Seed for the system's random number generator. It is re-applied at the start of every
## spawn_all(), so spawning is deterministic.
@export var rng_seed := 12345
## Simulation rate in ticks per second, decoupled from the physics rate
@export_range(5, 120) var sim_hz := 30
## The runtime ground. If unset, a default BoidGround is created on _ready.
@export var ground: BoidGround
## Where the ground comes from. If set and baking runs, it produces a heightfield that
## replaces `ground`.
@export var ground_source: BoidGroundSource
## Cell size of the baked ground, in world units.
@export var ground_cell := 1.0
## Extra obstacle sources besides BoidObstacle nodes
@export var obstacle_sources: Array[BoidObstacleSource] = []
## Obstacle source baked into a separate field used only while ENTERING. If unset, walkers
## avoid the normal `obstacles` field.
@export var entering_obstacle_source: BoidObstacleSource
var entering_obstacles: BoidObstacleField
## On: bake ground and obstacles at startup
## Off: use the `ground` and `obstacles` resources exactly as assigned
@export var bake_on_start := true
## Behaviour profiles, one per species.
@export var profiles: Array[BoidSpeciesProfile] = []
## Used by any species that has no profile. If unset, BoidSpeciesProfile.make_default() is
## used.
@export var default_profile: BoidSpeciesProfile
## Per-species-pair cohesion, alignment and separation weights.
@export var interactions: BoidInteractionTable
## Region of the ground plane (x, z) the simulation takes place in, in world units.
@export var world_bounds := Rect2(-120.0, -120.0, 240.0, 240.0)
## If true, boids are clamped to world_bounds and cannot spawn outside it.
@export var use_world_bounds := true
## Collision radius of a boid against obstacles, in world units. Spawn points also need
## 1.5x this much clearance from obstacles.
@export var boid_radius := 0.5
## Cell size of the baked obstacle field, in world units.
@export var obstacle_cell := 0.5
## Maximum distance, in world units, that the baked obstacle field represents.
@export var obstacle_max_dist := 5.0
## Ground steeper than this counts as unwalkable, in degrees (0 = off).
@export var slope_limit_degrees := 0.0
## Each boid's state transitions are evaluated once every this many ticks (staggered across
## boids). Higher values are cheaper but make transitions react later. Pen entrance checks
## use the same stride.
@export_range(1, 10) var transition_stride := 3
## If true, the system bakes (if enabled) and spawns all registered zones on startup.
@export var auto_spawn := true
## If false, the simulation does not tick and interpolation_alpha() returns 1.0.
@export var run_simulation := true

## Storage for all boid data (positions, velocities, species, state, etc.).
var store := BoidStore.new()
## Name <-> id registry for species, states and emitter kinds.
var vocab := BoidVocabulary.new()
## Random number generator used for spawning. Seeded from rng_seed.
var rng := RandomNumberGenerator.new()
## Per-stage timing of the simulation tick (used for debug displays).
var stage_timer := BoidStageTimer.new(PackedStringArray(STAGE_NAMES))
## Spatial structure used to find neighbours.
var neighbours: BoidNeighbourStrategy = BoidNeighbourHash.new()
## Compiled per-(species, state) behaviour data. Rebuilt when the vocabulary changes.
var behaviour_table: BoidBehaviourTable
## The baked obstacle field (optional)
@export var obstacles: BoidObstacleField
var spawned_total := 0
var removed_total := 0
var killed_total := 0
var deaths_by_species := PackedInt32Array()
var tick_count := 0
## Length in seconds of the tick currently being processed.
var current_sim_dt := 0.0
var penned_state_id := -1
var dead_state_id := -1
var entering_state_id := -1

## Final combined acceleration per active boid for this tick.
var combined_accel := PackedVector2Array()
## Accelerations gathered per influence layer, then combined in priority order.
var layer_accels: Array[PackedVector2Array] = []

## Emitters published this tick (active emitters only. all arrays below are parallel)
var active_emitter_count := 0
var emitter_positions := PackedVector2Array()
var emitter_velocities := PackedVector2Array()
var emitter_directions := PackedVector2Array()
var emitter_radii := PackedFloat32Array()
var emitter_cos_half_angles := PackedFloat32Array()
var emitter_strengths := PackedFloat32Array()
var emitter_kind_ids := PackedInt32Array()
## Strength-curve lookup tables, CURVE_LUT_SAMPLES entries per emitter, stored back to back.
var emitter_curve_luts := PackedFloat32Array()


## Registered storages, sorted by node path when they are built. Index = BoidPenStorage.storage_index.
var storages: Array[BoidPenStorage] = []
## Per-storage arrays below are indexed by storage index.
## Boids held per storage, including boids still walking in.
var storage_boid_counts := PackedInt32Array()
var storage_capacities := PackedInt32Array()
var _storage_centers := PackedVector2Array()
var _entering_phases := PackedByteArray()

## Registered entrances that have a valid storage, sorted by node path when they are built.
var entrances: Array[BoidPenEntrance] = []
## Per-entrance arrays below are indexed by entrance index.
var entrance_centers := PackedVector2Array()
## Entrance's local X axis projected onto the ground plane (unit length).
var entrance_axes_x := PackedVector2Array()
## Entrance's local Z axis projected onto the ground plane (unit length).
var entrance_axes_z := PackedVector2Array()
var entrance_half_extents := PackedVector2Array()
## Index (into storages) of the storage each entrance sends boids to.
var entrance_storage_indices := PackedInt32Array()
## Walk speed of each entrance in world units per second, or 0 if it places boids instantly.
var entrance_walk_speeds := PackedFloat32Array()

## Debug tap for one boid
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
var _obstacle_nodes: Array[BoidObstacle] = []
var _storage_spot_positions: Array[PackedVector2Array] = []
var _storage_spot_states: Array[PackedByteArray] = []
var _time_accumulator := 0.0
var _behaviour_table_version := -1
var _group_of_boid := PackedInt32Array()
var _group_start_offsets := PackedInt32Array()
var _group_write_cursors := PackedInt32Array()
var _boids_sorted_by_group := PackedInt32Array()
var _warned_invalid_group := false
var _removal_queue := PackedInt64Array()
var _pending_state_handles := PackedInt64Array()
var _pending_state_ids := PackedInt32Array()
var _pending_entry_handles := PackedInt64Array()
var _pending_entry_entrance_indices := PackedInt32Array()
## Boids currently walking into a storage, with their walk speeds and time limits
## (parallel arrays).
var _entering_handles := PackedInt64Array()
var _entering_speeds := PackedFloat32Array()
var _entering_time_limits := PackedFloat32Array()
var _pending_arrival_handles := PackedInt64Array()
## Scratch list of the slots of this tick's walkers, and the obstacle influence that steers them.
var _walk_slots := PackedInt32Array()
var _walk_avoidance: BoidInfluenceRuntime


func _init() -> void:
	for layer in LAYER_COUNT:
		layer_accels.append(PackedVector2Array())
	debug_layers.resize(LAYER_COUNT)


func _ready() -> void:
	if ground == null:
		ground = BoidGround.new()
	if default_profile == null:
		default_profile = BoidSpeciesProfile.make_default()
	rng.seed = rng_seed
	if auto_spawn:
		_start.call_deferred()


func _start() -> void:
	if bake_on_start:
		await get_tree().physics_frame
		bake_environment()
	else:
		_build_storages_and_entrances()
	spawn_all()


## Called by BoidSpawnZone on _ready.
func register_zone(zone: BoidSpawnZone) -> void:
	if not _zones.has(zone):
		_zones.append(zone)


## Called by BoidEmitter on _ready. Also assigns the emitter's emitter_kind_id.
func register_emitter(emitter: BoidEmitter) -> void:
	if _emitters.has(emitter):
		return
	emitter.emitter_kind_id = vocab.emitter_kind_id(emitter.kind)
	_emitters.append(emitter)


func unregister_emitter(emitter: BoidEmitter) -> void:
	_emitters.erase(emitter)


func register_obstacle(obstacle: BoidObstacle) -> void:
	if not _obstacle_nodes.has(obstacle):
		_obstacle_nodes.append(obstacle)


## Called by BoidPenStorage on _ready. Storages only get their index once they are built.
func register_storage(storage: BoidPenStorage) -> void:
	if not storages.has(storage):
		storages.append(storage)


## Called by BoidPenEntrance on _ready. Entrances only get used once they are built.
func register_entrance(entrance: BoidPenEntrance) -> void:
	if not entrances.has(entrance):
		entrances.append(entrance)


## Forces the behaviour table to be rebuilt on the next tick.
func invalidate_table() -> void:
	behaviour_table = null


# baking

func bake_environment() -> void:
	if ground == null:
		ground = BoidGround.new()
	if ground_source != null:
		var baked_ground := ground_source.bake_ground(self, world_bounds, ground_cell)
		if baked_ground != null:
			ground = baked_ground
		else:
			push_error("BoidSystem: ground_source failed to bake; keeping the existing ground.")
	_build_storages_and_entrances()
	entering_obstacles = null
	if entering_obstacle_source != null:
		var entering_field := BoidObstacleField.new()
		entering_field.setup(world_bounds, obstacle_cell, obstacle_max_dist)
		entering_obstacle_source.bake_obstacles(self, entering_field)
		entering_field.compute_normals()
		entering_obstacles = entering_field
	var ground_is_heightfield := ground is BoidHeightfield
	if _obstacle_nodes.is_empty() and obstacle_sources.is_empty() and not ground_is_heightfield:
		return
	var obstacle_field := BoidObstacleField.new()
	obstacle_field.setup(world_bounds, obstacle_cell, obstacle_max_dist)
	for obstacle_node in _obstacle_nodes:
		obstacle_node.bake_into(obstacle_field)
	if ground_is_heightfield:
		obstacle_field.apply_walkable(ground, slope_limit_degrees)
	for obstacle_source in obstacle_sources:
		if obstacle_source != null:
			obstacle_source.bake_obstacles(self, obstacle_field)
	obstacle_field.compute_normals()
	obstacles = obstacle_field


func save_baked(ground_path: String, obstacles_path: String) -> Error:
	var err := OK
	if ground is BoidHeightfield and ground_path != "":
		err = ResourceSaver.save(ground, ground_path)
	if err == OK and obstacles != null and obstacles_path != "":
		err = ResourceSaver.save(obstacles, obstacles_path)
	return err


## Builds storages first (sorted by node path, indexed, spots laid out), then entrances
## (sorted by node path, resolved to a storage index, geometry cached). Entrances whose
## storage is missing or not registered with this system are dropped with a warning.
func _build_storages_and_entrances() -> void:
	storages.sort_custom(func(storage_a: BoidPenStorage, storage_b: BoidPenStorage) -> bool: return str(storage_a.get_path()) < str(storage_b.get_path()))
	var storage_total := storages.size()
	storage_boid_counts.resize(storage_total)
	storage_boid_counts.fill(0)
	storage_capacities.resize(storage_total)
	_storage_spot_positions.clear()
	_storage_spot_states.clear()
	_storage_centers.resize(storage_total)
	for i in storage_total:
		var storage := storages[i]
		storage.storage_index = i
		var spot_positions := storage.compute_world_spot_positions()
		var spot_states := PackedByteArray()
		spot_states.resize(spot_positions.size())
		_storage_spot_positions.append(spot_positions)
		_storage_spot_states.append(spot_states)
		_storage_centers[i] = Vector2(storage.global_position.x, storage.global_position.z)
		storage_capacities[i] = spot_positions.size() if storage.snap_to_spots else UNLIMITED_CAPACITY

	entrances.sort_custom(func(entrance_a: BoidPenEntrance, entrance_b: BoidPenEntrance) -> bool: return str(entrance_a.get_path()) < str(entrance_b.get_path()))
	var usable_entrances: Array[BoidPenEntrance] = []
	for entrance in entrances:
		if entrance.storage == null or not storages.has(entrance.storage):
			push_warning("BoidSystem: entrance '%s' points at a storage that is not registered with this system; it will be ignored." % entrance.name)
			continue
		usable_entrances.append(entrance)
	entrances = usable_entrances
	var entrance_total := entrances.size()
	entrance_centers.resize(entrance_total)
	entrance_axes_x.resize(entrance_total)
	entrance_axes_z.resize(entrance_total)
	entrance_half_extents.resize(entrance_total)
	entrance_storage_indices.resize(entrance_total)
	entrance_walk_speeds.resize(entrance_total)
	var entrances_per_storage := PackedInt32Array()
	entrances_per_storage.resize(storage_total)
	for i in entrance_total:
		var entrance := entrances[i]
		var entrance_basis := entrance.global_transform.basis
		entrance_centers[i] = entrance.get_ground_position()
		entrance_axes_x[i] = Vector2(entrance_basis.x.x, entrance_basis.x.z).normalized()
		entrance_axes_z[i] = Vector2(entrance_basis.z.x, entrance_basis.z.z).normalized()
		entrance_half_extents[i] = entrance.get_half_extents()
		entrance_walk_speeds[i] = entrance.walk_speed if entrance.entry_mode == BoidPenEntrance.EntryMode.WALK else 0.0
		var storage_index := storages.find(entrance.storage)
		entrance_storage_indices[i] = storage_index
		entrances_per_storage[storage_index] += 1
	for i in storage_total:
		if entrances_per_storage[i] == 0:
			push_warning("BoidSystem: storage '%s' has no entrances; nothing can enter it." % storages[i].name)


# public API

## Spawns boids for every registered zone (in node-path order) and returns how many were placed.
func spawn_all() -> int:
	_zones.sort_custom(func(zone_a: BoidSpawnZone, zone_b: BoidSpawnZone) -> bool:
		return str(zone_a.get_path()) < str(zone_b.get_path()))
	rng.seed = rng_seed
	var spawned_count := 0
	for zone in _zones:
		spawned_count += _spawn_zone(zone)
	spawned_total += spawned_count
	spawned.emit(spawned_count)
	return spawned_count


## Queues a state change for a boid. Applied during the Commit stage of the current tick.
func request_state(handle: int, state_id: int) -> void:
	_pending_state_handles.append(handle)
	_pending_state_ids.append(state_id)


func select_debug_boid(handle: int) -> void:
	debug_handle = handle


func alive_count() -> int:
	return store.count


func penned_count() -> int:
	return store.count - store.active_count


func storage_count_of(storage_index: int) -> int:
	return storage_boid_counts[storage_index]


func deaths_of(species_id: int) -> int:
	return deaths_by_species[species_id] if species_id < deaths_by_species.size() else 0


## Counts boids matching the given species and state ids (-1 matches any).
func count_by(species_id: int = -1, state_id: int = -1) -> int:
	var matching_count := 0
	for i in store.count:
		if (species_id < 0 or store.species[i] == species_id) and (state_id < 0 or store.state[i] == state_id):
			matching_count += 1
	return matching_count


func check_invariants() -> bool:
	if store.count != spawned_total - removed_total or not store.check_consistency():
		return false
	var counted_in_storages := 0
	for boid_count_in_storage in storage_boid_counts:
		counted_in_storages += boid_count_in_storage
	var counted_in_storages_by_scan := 0
	for i in store.count:
		if store.storage_id[i] >= 0:
			counted_in_storages_by_scan += 1
	return counted_in_storages_by_scan == counted_in_storages


## Fraction (0..1) of the way from the previous simulation tick to the next, for smoothing
## rendering between ticks.
func interpolation_alpha() -> float:
	if not run_simulation:
		return 1.0
	var seconds_since_last_tick := _time_accumulator + Engine.get_physics_interpolation_fraction() / float(Engine.physics_ticks_per_second)
	return clampf(seconds_since_last_tick * float(sim_hz), 0.0, 1.0)

# spawning

func _spawn_zone(zone: BoidSpawnZone) -> int:
	var spawn_config := zone.config
	if spawn_config == null or spawn_config.count <= 0:
		return 0
	var species_id := vocab.species_id(spawn_config.species)
	var state_id := vocab.state_id(spawn_config.initial_state)
	var zone_center := zone.get_ground_position()
	var placed := 0
	for boid_index in spawn_config.count:
		var ground_position := Vector2.ZERO
		var found_position := false
		for attempt in 20:
			ground_position = zone.local_to_world_ground(zone.sample_local_ground_position(rng))
			if _spawn_ok(ground_position):
				found_position = true
				break
		if not found_position:
			continue
		var heading := _initial_heading(spawn_config, ground_position, zone_center)
		var direction := Vector2(sin(heading), cos(heading))
		store.add(ground_position, direction * spawn_config.initial_speed, heading, spawn_config.initial_speed, species_id, state_id, ground.height_at(ground_position))
		placed += 1
	if placed < spawn_config.count:
		push_warning("BoidSpawnZone '%s': only %d of %d boids found a legal position (off ground, in an obstacle or out of bounds)." % [zone.name, placed, spawn_config.count])
	return placed


func _spawn_ok(ground_position: Vector2) -> bool:
	if use_world_bounds and not world_bounds.has_point(ground_position):
		return false
	if not ground.is_over_ground(ground_position):
		return false
	if obstacles != null and obstacles.sample(ground_position).x < boid_radius * 1.5:
		return false
	return true


func _initial_heading(spawn_config: BoidSpawnConfig, ground_position: Vector2, zone_center: Vector2) -> float:
	match spawn_config.heading_policy:
		BoidSpawnConfig.HeadingPolicy.FIXED:
			return deg_to_rad(spawn_config.fixed_heading_degrees)
		BoidSpawnConfig.HeadingPolicy.RADIAL_OUT, BoidSpawnConfig.HeadingPolicy.TOWARD_CENTER:
			var offset_from_center := ground_position - zone_center
			if spawn_config.heading_policy == BoidSpawnConfig.HeadingPolicy.TOWARD_CENTER:
				offset_from_center = -offset_from_center
			if offset_from_center.length_squared() < 1e-8:
				return rng.randf() * TAU
			return atan2(offset_from_center.x, offset_from_center.y)
		_:
			return rng.randf() * TAU



func _physics_process(delta: float) -> void:
	if not run_simulation:
		return
	var sim_dt := 1.0 / float(sim_hz)
	_time_accumulator += delta
	var steps_taken := 0
	while _time_accumulator >= sim_dt and steps_taken < MAX_STEPS_PER_FRAME:
		tick(sim_dt)
		_time_accumulator -= sim_dt
		steps_taken += 1
	if steps_taken == MAX_STEPS_PER_FRAME:
		_time_accumulator = 0.0


## Runs one full simulation step of length sim_dt seconds.
func tick(sim_dt: float) -> void:
	current_sim_dt = sim_dt
	stage_timer.begin_tick()
	stage_timer.begin(Stage.SNAPSHOT)
	_stage_snapshot()
	stage_timer.end(Stage.SNAPSHOT)
	stage_timer.begin(Stage.REBUILD_NEIGHBOURS)
	_stage_rebuild_neighbours()
	stage_timer.end(Stage.REBUILD_NEIGHBOURS)
	stage_timer.begin(Stage.GATHER)
	_stage_gather()
	stage_timer.end(Stage.GATHER)
	stage_timer.begin(Stage.COMBINE)
	_stage_combine()
	stage_timer.end(Stage.COMBINE)
	stage_timer.begin(Stage.INTEGRATE)
	_stage_integrate(sim_dt)
	stage_timer.end(Stage.INTEGRATE)
	stage_timer.begin(Stage.GROUND)
	_stage_ground()
	stage_timer.end(Stage.GROUND)
	stage_timer.begin(Stage.TRANSITIONS)
	_stage_transitions()
	stage_timer.end(Stage.TRANSITIONS)
	stage_timer.begin(Stage.COMMIT)
	_stage_commit()
	stage_timer.end(Stage.COMMIT)
	stage_timer.begin(Stage.PRESENT)
	present_requested.emit()
	stage_timer.end(Stage.PRESENT)
	stage_timer.end_tick()
	tick_count += 1
	ticked.emit(sim_dt)



func _stage_snapshot() -> void:
	if behaviour_table == null or _behaviour_table_version != vocab.version:
		behaviour_table = BoidBehaviourTable.build(self)
		_behaviour_table_version = vocab.version
		penned_state_id = vocab.state_id(PENNED_STATE)
		dead_state_id = vocab.state_id(DEAD_STATE)
		entering_state_id = vocab.state_id(ENTERING_STATE)
	_publish_emitters()
	_sort_groups()


## Copies the active emitters into flat arrays and bakes each strength curve into a lookup table.
func _publish_emitters() -> void:
	var active_count := 0
	for emitter in _emitters:
		if emitter.active:
			active_count += 1
	active_emitter_count = active_count
	emitter_positions.resize(active_count)
	emitter_velocities.resize(active_count)
	emitter_directions.resize(active_count)
	emitter_radii.resize(active_count)
	emitter_cos_half_angles.resize(active_count)
	emitter_strengths.resize(active_count)
	emitter_kind_ids.resize(active_count)
	emitter_curve_luts.resize(active_count * CURVE_LUT_SAMPLES)
	var write_index := 0
	for emitter in _emitters:
		if not emitter.active:
			continue
		emitter_positions[write_index] = emitter.get_ground_position()
		emitter_velocities[write_index] = emitter.ground_velocity
		emitter_directions[write_index] = emitter.get_ground_facing_direction()
		emitter_radii[write_index] = maxf(emitter.radius, 0.01)
		emitter_cos_half_angles[write_index] = cos(deg_to_rad(emitter.cone_half_angle_degrees))
		emitter_strengths[write_index] = emitter.strength
		emitter_kind_ids[write_index] = emitter.emitter_kind_id
		var lut_base := write_index * CURVE_LUT_SAMPLES
		for sample_index in CURVE_LUT_SAMPLES:
			var curve_position := float(sample_index) / float(CURVE_LUT_SAMPLES - 1)
			emitter_curve_luts[lut_base + sample_index] = emitter.curve.sample_baked(curve_position) if emitter.curve != null else 1.0 - curve_position
		write_index += 1


## Counting sort of active boids by (species, state) group, so each group can be processed
## as one contiguous run.
func _sort_groups() -> void:
	var boid_count := store.active_count
	var group_count := behaviour_table.group_count
	var state_count := behaviour_table.n_states
	_group_start_offsets.resize(group_count + 1)
	_group_start_offsets.fill(0)
	_group_write_cursors.resize(group_count)
	_group_of_boid.resize(boid_count)
	_boids_sorted_by_group.resize(boid_count)
	var species_ids := store.species
	var state_ids := store.state
	for i in boid_count:
		var group := species_ids[i] * state_count + state_ids[i]
		if group < 0 or group >= group_count:
			if not _warned_invalid_group:
				push_error("BoidSystem: boid with species/state id outside the vocabulary. Register names via vocab first.")
				_warned_invalid_group = true
			group = 0
		_group_of_boid[i] = group
		_group_start_offsets[group + 1] += 1
	for group in group_count:
		_group_start_offsets[group + 1] += _group_start_offsets[group]
		_group_write_cursors[group] = _group_start_offsets[group]
	for i in boid_count:
		var group := _group_of_boid[i]
		var write_index := _group_write_cursors[group]
		_boids_sorted_by_group[write_index] = i
		_group_write_cursors[group] = write_index + 1


func _stage_rebuild_neighbours() -> void:
	neighbours.rebuild(store, behaviour_table.max_query_radius)


func _stage_gather() -> void:
	var boid_count := store.active_count
	for layer in LAYER_COUNT:
		var layer_accel_array := layer_accels[layer]
		layer_accel_array.resize(boid_count)
		layer_accel_array.fill(Vector2.ZERO)
	debug_slot = store.slot_of(debug_handle)
	if debug_slot >= boid_count:
		debug_slot = -1
	debug_cohesion = Vector2.ZERO
	debug_alignment = Vector2.ZERO
	debug_separation = Vector2.ZERO
	debug_neighbour_pos.clear()
	if boid_count == 0:
		return
	var table := behaviour_table
	for group in table.group_count:
		var group_begin := _group_start_offsets[group]
		var group_end := _group_start_offsets[group + 1]
		if group_begin == group_end:
			continue
		var group_max_speed := table.max_speed[group]
		for entry_index in range(table.entry_start[group], table.entry_start[group + 1]):
			table.entry_runtime[entry_index].apply(self, _boids_sorted_by_group, group_begin, group_end, table.entry_weight[entry_index], group_max_speed,
					layer_accels[table.entry_layer[entry_index]])


## Combination policy: prioritised acceleration allocation. Layers are visited in
## priority order
func _stage_combine() -> void:
	var boid_count := store.active_count
	combined_accel.resize(boid_count)
	var layers := layer_accels
	var group_max_accel := behaviour_table.max_accel
	for i in boid_count:
		var boid_max_accel := group_max_accel[_group_of_boid[i]]
		var total_accel := Vector2.ZERO
		var used_budget := 0.0
		for layer in LAYER_COUNT:
			var layer_accel := layers[layer][i]
			var length_squared := layer_accel.length_squared()
			if length_squared < 1e-12:
				continue
			var remaining_budget := boid_max_accel - used_budget
			if remaining_budget <= 0.0:
				break
			var length := sqrt(length_squared)
			if length > remaining_budget:
				layer_accel *= remaining_budget / length
				length = remaining_budget
			total_accel += layer_accel
			used_budget += length
		combined_accel[i] = total_accel
	if debug_slot >= 0 and debug_slot < boid_count:
		debug_total = combined_accel[debug_slot]
		for layer in LAYER_COUNT:
			debug_layers[layer] = layers[layer][debug_slot]
	else:
		debug_total = Vector2.ZERO
		debug_layers.fill(Vector2.ZERO)


func _stage_integrate(sim_dt: float) -> void:
	var boid_count := store.active_count
	if combined_accel.size() != boid_count:
		return
	var positions := store.pos
	var velocities := store.vel
	var speeds := store.speed
	var headings := store.heading
	var group_max_speed := behaviour_table.max_speed
	var clamp_to_bounds := use_world_bounds
	var bounds_min := world_bounds.position
	var bounds_max := world_bounds.end
	var field := obstacles
	var has_field := field != null
	var collision_radius := boid_radius
	var field_dist := PackedFloat32Array()
	var field_width := 0
	var field_depth := 0
	var field_origin_x := 0.0
	var field_origin_z := 0.0
	var field_inv_cell := 1.0
	var field_near_threshold := 0.0
	if has_field:
		field_dist = field.dist
		field_width = field.width
		field_depth = field.depth
		field_origin_x = field.origin.x
		field_origin_z = field.origin.y
		field_inv_cell = 1.0 / field.cell
		field_near_threshold = collision_radius + field.cell
	var state_ids := store.state
	for i in boid_count:
		if state_ids[i] == entering_state_id:
			continue
		var boid_max_speed := group_max_speed[_group_of_boid[i]]
		var new_velocity := velocities[i] + combined_accel[i] * sim_dt
		var new_speed := new_velocity.length()
		if new_speed > boid_max_speed:
			new_velocity *= boid_max_speed / new_speed
			new_speed = boid_max_speed
		var new_position := positions[i] + new_velocity * sim_dt
		if has_field:
			var cell_x := clampi(int((new_position.x - field_origin_x) * field_inv_cell), 0, field_width - 1)
			var cell_z := clampi(int((new_position.y - field_origin_z) * field_inv_cell), 0, field_depth - 1)
			if field_dist[cell_z * field_width + cell_x] < field_near_threshold:
				var field_sample := field.sample(new_position)
				var penetration_gap := field_sample.x - collision_radius
				if penetration_gap < 0.0:
					var surface_normal := Vector2(field_sample.y, field_sample.z)
					new_position -= surface_normal * penetration_gap
					var normal_speed := new_velocity.dot(surface_normal)
					if normal_speed < 0.0:
						new_velocity -= surface_normal * normal_speed
						new_speed = new_velocity.length()
		velocities[i] = new_velocity
		speeds[i] = new_speed
		if new_speed > 0.001:
			headings[i] = atan2(new_velocity.x, new_velocity.y)
		if clamp_to_bounds:
			new_position = new_position.clamp(bounds_min, bounds_max)
		positions[i] = new_position
	_walk_entering_boids(sim_dt)


func _stage_ground() -> void:
	ground.sample_batch(store.pos, store.ground_h, store.active_count)


func _stage_transitions() -> void:
	var boid_count := store.active_count
	if boid_count == 0:
		return
	var table := behaviour_table
	var state_timers := store.state_timer
	var positions := store.pos
	var sim_dt := current_sim_dt
	var stride := transition_stride
	var phase := tick_count % stride
	var entrance_total := entrances.size()
	var storage_ids := store.storage_id
	for i in boid_count:
		state_timers[i] += sim_dt
		if (i + phase) % stride != 0:
			continue
		var group := _group_of_boid[i]
		var transition_requested := false
		for transition_index in range(table.tr_start[group], table.tr_start[group + 1]):
			var trigger := table.tr_trigger[transition_index]
			var hit := false
			if trigger == BoidTransition.Trigger.TIMER:
				hit = state_timers[i] >= table.tr_seconds[transition_index]
			elif state_timers[i] >= table.tr_min_time[transition_index]:
				var emitter_in_range := active_emitter_count > 0 and _emitter_within(positions[i], table.tr_emitter_kind[transition_index], table.tr_dist2[transition_index])
				hit = emitter_in_range if trigger == BoidTransition.Trigger.EMITTER_NEAR else not emitter_in_range
			if hit:
				request_state(store.handle_at(i), table.tr_to[transition_index])
				transition_requested = true
				break
		if transition_requested or entrance_total == 0 or storage_ids[i] >= 0:
			continue
		var boid_position := positions[i]
		for entrance_index in entrance_total:
			var storage_index := entrance_storage_indices[entrance_index]
			if storage_boid_counts[storage_index] >= storage_capacities[storage_index]:
				continue
			var offset_from_entrance := boid_position - entrance_centers[entrance_index]
			if absf(offset_from_entrance.dot(entrance_axes_z[entrance_index])) > entrance_half_extents[entrance_index].y:
				continue
			if absf(offset_from_entrance.dot(entrance_axes_x[entrance_index])) > entrance_half_extents[entrance_index].x:
				continue
			_pending_entry_handles.append(store.handle_at(i))
			_pending_entry_entrance_indices.append(entrance_index)
			break


## True if any published emitter (of the given kind id, or any kind if negative) is within
## the given squared distance of query_position.
func _emitter_within(query_position: Vector2, required_kind_id: int, max_distance_squared: float) -> bool:
	for emitter_index in active_emitter_count:
		if required_kind_id >= 0 and emitter_kind_ids[emitter_index] != required_kind_id:
			continue
		if (emitter_positions[emitter_index] - query_position).length_squared() <= max_distance_squared:
			return true
	return false


## Applies queued state changes, then queued storage entries, then walkers that arrived,
## then removes dead boids.
func _stage_commit() -> void:
	for i in _pending_state_handles.size():
		_apply_state(_pending_state_handles[i], _pending_state_ids[i])
	_pending_state_handles.clear()
	_pending_state_ids.clear()
	for i in _pending_entry_handles.size():
		_apply_entry(_pending_entry_handles[i], _pending_entry_entrance_indices[i])
	_pending_entry_handles.clear()
	_pending_entry_entrance_indices.clear()
	for handle in _pending_arrival_handles:
		_apply_arrival(handle)
	_pending_arrival_handles.clear()
	if not _removal_queue.is_empty():
		_release_storage_spots(_removal_queue)
		removed_total += store.remove_many(_removal_queue)
		_removal_queue.clear()


func _apply_state(handle: int, new_state_id: int) -> void:
	var slot := store.slot_of(handle)
	if not store.is_active_slot(slot):
		return
	if store.state[slot] == new_state_id:
		return
	if store.state[slot] == entering_state_id and new_state_id != dead_state_id:
		return
	if new_state_id == dead_state_id:
		var species_id := store.species[slot]
		if species_id >= deaths_by_species.size():
			deaths_by_species.resize(species_id + 1)
		deaths_by_species[species_id] += 1
		killed_total += 1
		store.state[slot] = new_state_id
		_removal_queue.append(handle)
		boid_died.emit(species_id, store.pos[slot])
		return
	store.state[slot] = new_state_id
	store.state_timer[slot] = 0.0
	if new_state_id == penned_state_id:
		store.freeze(slot)


## Handles one queued entry: checks the boid and the storage are still eligible, reserves a
## spot if the storage snaps, records the boid's place in the storage, then either finalizes
## the entry at once or, for a walking entrance, starts the walk.
func _apply_entry(handle: int, entrance_index: int) -> void:
	var slot := store.slot_of(handle)
	if not store.is_active_slot(slot):
		return
	var storage_index := entrance_storage_indices[entrance_index]
	if store.storage_id[slot] >= 0 or store.state[slot] == dead_state_id or storage_boid_counts[storage_index] >= storage_capacities[storage_index]:
		return
	var spot_index := -1
	if storages[storage_index].snap_to_spots:
		spot_index = _claim_spot(storage_index)
		if spot_index < 0:
			return
	store.storage_id[slot] = storage_index
	store.storage_spot[slot] = spot_index
	storage_boid_counts[storage_index] += 1
	if spot_index >= 0 and entrance_walk_speeds[entrance_index] > 0.0:
		if storages[storage_index].snap_to_spots and storage_boid_counts[storage_index] == storage_capacities[storage_index]:
			storages[storage_index].filled.emit()
		_begin_walk(slot, handle, entrance_walk_speeds[entrance_index])
	else:
		_finalize_storage_entry(slot, storage_index, spot_index)


## Reserves the first free spot in a storage (spots are in fill order). Returns -1 if none.
func _claim_spot(storage_index: int) -> int:
	var spot_states := _storage_spot_states[storage_index]
	for spot_index in spot_states.size():
		if spot_states[spot_index] == SpotState.FREE:
			spot_states[spot_index] = SpotState.RESERVED
			return spot_index
	return -1


## Puts a boid into the ENTERING state. From now on _walk_entering_boids moves it. It first
## walks to the center of its storage, then to its spot. The boid gets a time limit
## proportional to the full path length (via the center), as a safety net.
func _begin_walk(slot: int, handle: int, walk_speed: float) -> void:
	var storage_index := store.storage_id[slot]
	var spot := _storage_spot_positions[storage_index][store.storage_spot[slot]]
	var center := _storage_centers[storage_index]
	var path_length := store.pos[slot].distance_to(center) + center.distance_to(spot)
	store.state[slot] = entering_state_id
	store.state_timer[slot] = 0.0
	store.vel[slot] = Vector2.ZERO
	store.speed[slot] = 0.0
	_entering_handles.append(handle)
	_entering_speeds.append(walk_speed)
	_entering_phases.append(0)
	_entering_time_limits.append(path_length / walk_speed * WALK_TIMEOUT_FACTOR + WALK_TIMEOUT_SECONDS)


## Moves every entering boid at a constant speed, overriding this tick's steering result. Each
## boid first walks to the center of its storage, then to its spot.
func _walk_entering_boids(sim_dt: float) -> void:
	if _entering_handles.is_empty():
		return
	var positions := store.pos
	var velocities := store.vel
	var speeds := store.speed
	var headings := store.heading
	var state_timers := store.state_timer
	_walk_slots.clear()
	var keep_count := 0
	for read_index in _entering_handles.size():
		var handle := _entering_handles[read_index]
		var slot := store.slot_of(handle)
		if not store.is_active_slot(slot) or store.state[slot] != entering_state_id:
			continue
		if state_timers[slot] > _entering_time_limits[read_index]:
			positions[slot] = _storage_spot_positions[store.storage_id[slot]][store.storage_spot[slot]]
			velocities[slot] = Vector2.ZERO
			speeds[slot] = 0.0
			_pending_arrival_handles.append(handle)
			continue
		_entering_handles[keep_count] = handle
		_entering_speeds[keep_count] = _entering_speeds[read_index]
		_entering_time_limits[keep_count] = _entering_time_limits[read_index]
		_entering_phases[keep_count] = _entering_phases[read_index]
		_walk_slots.append(slot)
		keep_count += 1
	_entering_handles.resize(keep_count)
	_entering_speeds.resize(keep_count)
	_entering_time_limits.resize(keep_count)
	_entering_phases.resize(keep_count)
	var avoidance := layer_accels[BoidInfluence.Layer.SAFETY]
	for slot in _walk_slots:
		avoidance[slot] = Vector2.ZERO
	var walk_avoidance := _get_walk_avoidance() as BoidInfluenceObstacle.Runtime
	walk_avoidance.field_override = entering_obstacles
	walk_avoidance.apply(self, _walk_slots, 0, keep_count, 1.0, 0.0, avoidance)
	for i in keep_count:
		var slot := _walk_slots[i]
		var storage_index := store.storage_id[slot]
		var spot := _storage_spot_positions[storage_index][store.storage_spot[slot]]
		var heads_to_center := _entering_phases[i] == 0
		var target := _storage_centers[storage_index] if heads_to_center else spot
		var walk_speed := _entering_speeds[i]
		var to_target := target - positions[slot]
		var distance := to_target.length()
		var step := walk_speed * sim_dt
		if distance <= step:
			positions[slot] = target
			if heads_to_center:
				_entering_phases[i] = 1
			else:
				velocities[slot] = Vector2.ZERO
				speeds[slot] = 0.0
				_pending_arrival_handles.append(_entering_handles[i])
			continue
		var direction := to_target / distance
		# Fade is based on the distance to the final spot, so the center waypoint does not
		# weaken avoidance.
		var avoidance_fade := clampf(positions[slot].distance_to(spot) / WALK_AVOIDANCE_FADE_DISTANCE, 0.0, 1.0)
		var steered := direction * walk_speed + avoidance[slot] * (walk_speed * avoidance_fade)
		var steered_length := steered.length()
		if steered_length > 1e-4:
			direction = steered / steered_length
		positions[slot] = positions[slot] + direction * step
		velocities[slot] = direction * walk_speed
		speeds[slot] = walk_speed
		headings[slot] = atan2(direction.x, direction.y)


## The obstacle influence used to steer walkers, with default settings. Created on first use.
func _get_walk_avoidance() -> BoidInfluenceRuntime:
	if _walk_avoidance == null:
		_walk_avoidance = BoidInfluenceObstacle.new().create_runtime()
		_walk_avoidance.setup(self)
	return _walk_avoidance


## Finalizes a walking boid that reached its spot, unless it left the ENTERING state
## (for example it was killed) in the meantime.
func _apply_arrival(handle: int) -> void:
	var slot := store.slot_of(handle)
	if not store.is_active_slot(slot) or store.state[slot] != entering_state_id:
		return
	_finalize_storage_entry(slot, store.storage_id[slot], store.storage_spot[slot])


## Completes an entry: moves the boid onto its reserved spot (if any), marks the spot
## occupied, stops the boid, marks it penned and frozen, and announces it. The boid's place
## in the storage (storage_id, storage_spot, count) was recorded when the spot was claimed.
func _finalize_storage_entry(slot: int, storage_index: int, spot_index: int) -> void:
	if spot_index >= 0:
		_storage_spot_states[storage_index][spot_index] = SpotState.OCCUPIED
		var spot_position := _storage_spot_positions[storage_index][spot_index]
		store.pos[slot] = spot_position
		store.ground_h[slot] = ground.height_at(spot_position)
	store.vel[slot] = Vector2.ZERO
	store.speed[slot] = 0.0
	store.state[slot] = penned_state_id
	store.state_timer[slot] = 0.0
	var species_id := store.species[slot]
#	store.freeze(slot)
	boid_penned.emit(storage_index, species_id)


## Frees the spot and count held by each boid in handles that is stored. Keyed on the
## boid's storage_id (not on it being frozen), so a boid removed before it finishes entering
## would not leak its spot.
func _release_storage_spots(handles: PackedInt64Array) -> void:
	for handle in handles:
		var slot := store.slot_of(handle)
		if slot < 0:
			continue
		var storage_index := store.storage_id[slot]
		if storage_index < 0:
			continue
		var spot_index := store.storage_spot[slot]
		if spot_index >= 0:
			_storage_spot_states[storage_index][spot_index] = SpotState.FREE
		storage_boid_counts[storage_index] -= 1
		store.storage_id[slot] = -1
