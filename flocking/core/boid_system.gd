class_name BoidSystem
extends Node3D
## Owner of all simulation state for one interacting group. The class has grown way too large
## should probably be split, but I'm lazy

## Phases of one simulation tick, in execution order. Used to index per-stage timings.
enum Stage { SNAPSHOT, REBUILD_NEIGHBOURS, GATHER, COMBINE, INTEGRATE, GROUND, TRANSITIONS, COMMIT, PRESENT }
const STAGE_NAMES := ["Snapshot", "Neighbours", "Gather", "Combine", "Integrate", "Ground",
		"Transitions", "Commit", "Present"]

## Cap on simulation ticks per physics frame. If the cap is hit, the leftover time is dropped.
const MAX_STEPS_PER_FRAME := 4
## Number of samples taken from each emitter's strength curve when building its lookup table.
const CURVE_LUT_SAMPLES := 16
const LAYER_COUNT := BoidInfluence.LAYER_COUNT

## Special states, registered in every system. PENNED is terminal and frozen, entering DEAD
## removes the boid in the same Commit.
const PENNED_STATE := &"penned"
const DEAD_STATE := &"dead"

## Emitted after spawn_all() with the number of boids actually placed.
signal spawned(count: int)
## Emitted once per tick, during the Present stage.
signal present_requested
## Emitted at the end of every simulation tick with the tick length in seconds.
signal ticked(sim_dt: float)
## Emitted when a boid is accepted into a pen.
signal boid_penned(pen_index: int, species_id: int)
## Emitted when a boid enters the DEAD state, with its ground position at that moment.
signal boid_died(species_id: int, position: Vector2)

## Seed for the system's random number generator. It is re-applied at the start of every
## spawn_all(), so spawning is deterministic.
@export var rng_seed := 12345
## Simulation rate, decoupled from the physics rate
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
## If true, boids are clamped to world_bounds
@export var use_world_bounds := true
## Collision radius of a boid against obstacles, in world units. Spawn points also need
## 1.5x this much clearance from obstacles.
@export var boid_radius := 0.5
## Cell size of the baked obstacle field, in world units.
@export var obstacle_cell := 0.5
## Maximum distance, in world units, that the baked obstacle field represents.
@export var obstacle_max_dist := 5.0
## Ground steeper than this counts as unwalkable (0 = off).
@export var slope_limit_degrees := 0.0
## Each boid's state transitions are evaluated once every this many ticks (staggered across
## boids). Higher values are cheaper but make transitions react later.
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
## Per-stage timing of the simulation tick (for debugging)
var timer := BoidStageTimer.new(PackedStringArray(STAGE_NAMES))
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

## Final combined acceleration per active boid for this tick.
var combined_accel := PackedVector2Array()
## Accelerations gathered per influence layer, then combined in priority order.
var layer_accels: Array[PackedVector2Array] = []

## Emitters published this tick
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

## Registered pens, sorted by node path when pens are built. Index = BoidPen.pen_index.
var pens: Array[BoidPen] = []
## Per-pen arrays below are indexed by pen index.
var pen_boid_counts := PackedInt32Array()
var pen_capacities := PackedInt32Array()
var pen_centers := PackedVector2Array()
## Pen's local X axis projected onto the ground plane (unit length).
var pen_axes_x := PackedVector2Array()
## Pen's local Z axis projected onto the ground plane (unit length).
var pen_axes_z := PackedVector2Array()
var pen_half_extents := PackedVector2Array()
## Local z of each pen's entry line (see BoidPen.get_entry_line_local_z).
var pen_entry_lines_local_zs := PackedFloat32Array()

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
var _pen_spot_positions: Array[PackedVector2Array] = []
var _pen_spot_occupied: Array[PackedByteArray] = []
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
var _pending_pen_handles := PackedInt64Array()
var _pending_pen_indices := PackedInt32Array()


func _init() -> void:
	for l in LAYER_COUNT:
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
		_build_pens()
	spawn_all()


func register_zone(zone: BoidSpawnZone) -> void:
	if not _zones.has(zone):
		_zones.append(zone)


func register_emitter(emitter: BoidEmitter) -> void:
	if _emitters.has(emitter):
		return
	emitter.kind_id = vocab.emitter_kind_id(emitter.kind)
	_emitters.append(emitter)


func unregister_emitter(emitter: BoidEmitter) -> void:
	_emitters.erase(emitter)


func register_obstacle(obstacle: BoidObstacle) -> void:
	if not _obstacle_nodes.has(obstacle):
		_obstacle_nodes.append(obstacle)


func register_pen(pen: BoidPen) -> void:
	if not pens.has(pen):
		pens.append(pen)


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
	_build_pens()
	var is_heightfield := ground is BoidHeightfield
	if _obstacle_nodes.is_empty() and obstacle_sources.is_empty() and not is_heightfield:
		return
	var obstacle_field := BoidObstacleField.new()
	obstacle_field.setup(world_bounds, obstacle_cell, obstacle_max_dist)
	for obstacle in _obstacle_nodes:
		obstacle.bake_into(obstacle_field)
	if is_heightfield:
		obstacle_field.apply_walkable(ground, slope_limit_degrees)
	for source in obstacle_sources:
		if source != null:
			source.bake_obstacles(self, obstacle_field)
	obstacle_field.compute_normals()
	obstacles = obstacle_field


func save_baked(ground_path: String, obstacles_path: String) -> Error:
	var err := OK
	if ground is BoidHeightfield and ground_path != "":
		err = ResourceSaver.save(ground, ground_path)
	if err == OK and obstacles != null and obstacles_path != "":
		err = ResourceSaver.save(obstacles, obstacles_path)
	return err


func _build_pens() -> void:
	pens.sort_custom(func(a: BoidPen, b: BoidPen) -> bool: return str(a.get_path()) < str(b.get_path()))
	pen_boid_counts.resize(pens.size())
	pen_boid_counts.fill(0)
	pen_capacities.resize(pens.size())
	pen_centers.resize(pens.size())
	pen_axes_x.resize(pens.size())
	pen_axes_z.resize(pens.size())
	pen_half_extents.resize(pens.size())
	pen_entry_lines_local_zs.resize(pens.size())
	_pen_spot_positions.clear()
	_pen_spot_occupied.clear()
	for i in pens.size():
		var pen := pens[i]
		pen.index = i
		var basis := pen.global_transform.basis
		pen_centers[i] = pen.xz()
		pen_axes_x[i] = Vector2(basis.x.x, basis.x.z).normalized()
		pen_axes_z[i] = Vector2(basis.z.x, basis.z.z).normalized()
		pen_half_extents[i] = pen.trigger_half()
		pen_entry_lines_local_zs[i] = pen.trigger_zmin()
		var spots := pen.compute_spots()
		var used := PackedByteArray()
		used.resize(spots.size())
		_pen_spot_positions.append(spots)
		_pen_spot_occupied.append(used)
		pen_capacities[i] = spots.size() if pen.snap_to_spots else (1 << 30)


# public API

func spawn_all() -> int:
	_zones.sort_custom(func(a: BoidSpawnZone, b: BoidSpawnZone) -> bool:
		return str(a.get_path()) < str(b.get_path()))
	rng.seed = rng_seed
	var spawned_count := 0
	for zone in _zones:
		spawned_count += _spawn_zone(zone)
	spawned_total += spawned_count
	spawned.emit(spawned_count)
	return spawned_count


func request_state(handle: int, state_id: int) -> void:
	_pending_state_handles.append(handle)
	_pending_state_ids.append(state_id)


func select_debug_boid(handle: int) -> void:
	debug_handle = handle


func alive_count() -> int:
	return store.count


func penned_count() -> int:
	return store.count - store.active_count


func pen_count_of(pen_index: int) -> int:
	return pen_boid_counts[pen_index]


func deaths_of(species_id: int) -> int:
	return deaths_by_species[species_id] if species_id < deaths_by_species.size() else 0


func count_by(species_id: int = -1, state_id: int = -1) -> int:
	var n := 0
	for i in store.count:
		if (species_id < 0 or store.species[i] == species_id) and (state_id < 0 or store.state[i] == state_id):
			n += 1
	return n


func check_invariants() -> bool:
	if store.count != spawned_total - removed_total or not store.check_consistency():
		return false
	var in_pens := 0
	for count in pen_boid_counts:
		in_pens += count
	if in_pens > store.count - store.active_count:
		return false
	var in_pens_scan := 0
	for i in range(store.active_count, store.count):
		if store.pen_id[i] >= 0:
			in_pens_scan += 1
	return in_pens_scan == in_pens

func interpolation_alpha() -> float:
	if not run_simulation:
		return 1.0
	var since := _time_accumulator + Engine.get_physics_interpolation_fraction() / float(Engine.physics_ticks_per_second)
	return clampf(since * float(sim_hz), 0.0, 1.0)

# spawingn

func _spawn_zone(zone: BoidSpawnZone) -> int:
	var spawn_config := zone.config
	if spawn_config == null or spawn_config.count <= 0:
		return 0
	var species_id := vocab.species_id(spawn_config.species)
	var state_id := vocab.state_id(spawn_config.initial_state)
	var centre := zone.center_xz()
	var placed := 0
	for boid_index in spawn_config.count:
		var ground_position := Vector2.ZERO
		var found_position := false
		for attempt in 20:
			ground_position = zone.local_to_world_xz(zone.sample_local(rng))
			if _spawn_ok(ground_position):
				found_position = true
				break
		if not found_position:
			continue
		var h := _initial_heading(spawn_config, ground_position, centre)
		var dir := Vector2(sin(h), cos(h))
		store.add(ground_position, dir * spawn_config.initial_speed, h, 
			spawn_config.initial_speed, species_id, state_id, ground.height_at(ground_position))
		placed += 1
	if placed < spawn_config.count:
		push_warning("BoidSpawnZone '%s': only %d of %d boids found a legal position (off ground, in an obstacle or out of bounds)." 
			% [zone.name, placed, spawn_config.count])
	return placed


func _spawn_ok(xz: Vector2) -> bool:
	if use_world_bounds and not world_bounds.has_point(xz):
		return false
	if not ground.is_over_ground(xz):
		return false
	if obstacles != null and obstacles.sample(xz).x < boid_radius * 1.5:
		return false
	return true


func _initial_heading(spawn_config: BoidSpawnConfig, ground_position: Vector2, zone_centre: Vector2) -> float:
	match spawn_config.heading_policy:
		BoidSpawnConfig.HeadingPolicy.FIXED:
			return deg_to_rad(spawn_config.fixed_heading_degrees)
		BoidSpawnConfig.HeadingPolicy.RADIAL_OUT, BoidSpawnConfig.HeadingPolicy.TOWARD_CENTER:
			var offset_from_centre := ground_position - zone_centre
			if spawn_config.heading_policy == BoidSpawnConfig.HeadingPolicy.TOWARD_CENTER:
				offset_from_centre = -offset_from_centre
			if offset_from_centre.length_squared() < 1e-8:
				return rng.randf() * TAU
			return atan2(offset_from_centre.x, offset_from_centre.y)
		_:
			return rng.randf() * TAU



func _physics_process(delta: float) -> void:
	if not run_simulation:
		return
	var sim_dt := 1.0 / float(sim_hz)
	_time_accumulator += delta
	var steps := 0
	while _time_accumulator >= sim_dt and steps < MAX_STEPS_PER_FRAME:
		tick(sim_dt)
		_time_accumulator -= sim_dt
		steps += 1
	if steps == MAX_STEPS_PER_FRAME:
		_time_accumulator = 0.0


func tick(sim_dt: float) -> void:
	current_sim_dt = sim_dt
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
	_stage_integrate(sim_dt)
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
	ticked.emit(sim_dt)



func _stage_snapshot() -> void:
	if behaviour_table == null or _behaviour_table_version != vocab.version:
		behaviour_table = BoidBehaviourTable.build(self)
		_behaviour_table_version = vocab.version
		penned_state_id = vocab.state_id(PENNED_STATE)
		dead_state_id = vocab.state_id(DEAD_STATE)
	_publish_emitters()
	_sort_groups()


func _publish_emitters() -> void:
	var count := 0
	for emitter in _emitters:
		if emitter.active:
			count += 1
	active_emitter_count = count
	emitter_positions.resize(count)
	emitter_velocities.resize(count)
	emitter_directions.resize(count)
	emitter_radii.resize(count)
	emitter_cos_half_angles.resize(count)
	emitter_strengths.resize(count)
	emitter_kind_ids.resize(count)
	emitter_curve_luts.resize(count * CURVE_LUT_SAMPLES)
	var write_index := 0
	for emitter in _emitters:
		if not emitter.active:
			continue
		emitter_positions[write_index] = emitter.xz()
		emitter_velocities[write_index] = emitter.ground_velocity
		emitter_directions[write_index] = emitter.dir_xz()
		emitter_radii[write_index] = maxf(emitter.radius, 0.01)
		emitter_cos_half_angles[write_index] = cos(deg_to_rad(emitter.cone_half_angle_degrees))
		emitter_strengths[write_index] = emitter.strength
		emitter_kind_ids[write_index] = emitter.kind_id
		var base := write_index * CURVE_LUT_SAMPLES
		for sample_index in CURVE_LUT_SAMPLES:
			var curve_position := float(sample_index) / float(CURVE_LUT_SAMPLES - 1)
			emitter_curve_luts[base + sample_index] = emitter.curve.sample_baked(curve_position) if emitter.curve != null else 1.0 - curve_position
		write_index += 1


func _sort_groups() -> void:
	var boid_count := store.active_count
	var group_count := behaviour_table.group_count
	var state_count := behaviour_table.n_states
	_group_start_offsets.resize(group_count + 1)
	_group_start_offsets.fill(0)
	_group_write_cursors.resize(group_count)
	_group_of_boid.resize(boid_count)
	_boids_sorted_by_group.resize(boid_count)
	var species := store.species
	var state := store.state
	for i in boid_count:
		var group := species[i] * state_count + state[i]
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
		var from := _group_start_offsets[group]
		var to := _group_start_offsets[group + 1]
		if from == to:
			continue
		var vmax := table.max_speed[group]
		for e in range(table.entry_start[group], table.entry_start[group + 1]):
			table.entry_runtime[e].apply(self, _boids_sorted_by_group, from, to, table.entry_weight[e], vmax,
					layer_accels[table.entry_layer[e]])


## Combination policy: prioritised acceleration allocation. Layers are visited in
## priority order
func _stage_combine() -> void:
	var boid_count := store.active_count
	combined_accel.resize(boid_count)
	var layers := layer_accels
	var group_max_accel := behaviour_table.max_accel
	for i in boid_count:
		var max_acceleration := group_max_accel[_group_of_boid[i]]
		var total := Vector2.ZERO
		var used := 0.0
		for layer in LAYER_COUNT:
			var layer_accel := layers[layer][i]
			var length_squared := layer_accel.length_squared()
			if length_squared < 1e-12:
				continue
			var room := max_acceleration - used
			if room <= 0.0:
				break
			var length := sqrt(length_squared)
			if length > room:
				layer_accel *= room / length
				length = room
			total += layer_accel
			used += length
		combined_accel[i] = total
	if debug_slot >= 0 and debug_slot < boid_count:
		debug_total = combined_accel[debug_slot]
		for layer in LAYER_COUNT:
			debug_layers[layer] = layers[layer][debug_slot]
	else:
		debug_total = Vector2.ZERO
		debug_layers.fill(Vector2.ZERO)


func _stage_integrate(dt: float) -> void:
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
	var radius := boid_radius
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
		field_near_threshold = radius + field.cell
	for i in boid_count:
		var boid_max_speed := group_max_speed[_group_of_boid[i]]
		var new_velocity := velocities[i] + combined_accel[i] * dt
		var new_speed := new_velocity.length()
		if new_speed > boid_max_speed:
			new_velocity *= boid_max_speed / new_speed
			new_speed = boid_max_speed
		var new_position := positions[i] + new_velocity * dt
		if has_field:
			var cx := clampi(int((new_position.x - field_origin_x) * field_inv_cell), 0, field_width - 1)
			var cz := clampi(int((new_position.y - field_origin_z) * field_inv_cell), 0, field_depth - 1)
			if field_dist[cz * field_width + cx] < field_near_threshold:
				var sm := field.sample(new_position)
				var gap := sm.x - radius
				if gap < 0.0:
					var nrm := Vector2(sm.y, sm.z)
					new_position -= nrm * gap
					var vn := new_velocity.dot(nrm)
					if vn < 0.0:
						new_velocity -= nrm * vn
						new_speed = new_velocity.length()
		velocities[i] = new_velocity
		speeds[i] = new_speed
		if new_speed > 0.001:
			headings[i] = atan2(new_velocity.x, new_velocity.y)
		if clamp_to_bounds:
			new_position = new_position.clamp(bounds_min, bounds_max)
		positions[i] = new_position


func _stage_ground() -> void:
	ground.sample_batch(store.pos, store.ground_h, store.active_count)


func _stage_transitions() -> void:
	var n := store.active_count
	if n == 0:
		return
	var t := behaviour_table
	var timers := store.state_timer
	var pos := store.pos
	var dt := current_sim_dt
	var stride := transition_stride
	var phase := tick_count % stride
	var n_pens := pens.size()
	for i in n:
		timers[i] += dt
		if (i + phase) % stride != 0:
			continue
		var g := _group_of_boid[i]
		var requested := false
		for k in range(t.tr_start[g], t.tr_start[g + 1]):
			var trig := t.tr_trigger[k]
			var hit := false
			if trig == BoidTransition.Trigger.TIMER:
				hit = timers[i] >= t.tr_seconds[k]
			elif timers[i] >= t.tr_min_time[k]:
				var any := active_emitter_count > 0 and _emitter_within(pos[i], t.tr_emitter_kind[k], t.tr_dist2[k])
				hit = any if trig == BoidTransition.Trigger.EMITTER_NEAR else not any
			if hit:
				request_state(store.handle_at(i), t.tr_to[k])
				requested = true
				break
		if requested or n_pens == 0:
			continue
		var p := pos[i]
		for pi in n_pens:
			if pen_boid_counts[pi] >= pen_capacities[pi]:
				continue
			var local := p - pen_centers[pi]
			var lz := local.dot(pen_axes_z[pi])
			if lz < pen_entry_lines_local_zs[pi] or lz > pen_half_extents[pi].y:
				continue
			if absf(local.dot(pen_axes_x[pi])) > pen_half_extents[pi].x:
				continue
			_pending_pen_handles.append(store.handle_at(i))
			_pending_pen_indices.append(pi)
			break


func _emitter_within(p: Vector2, kind: int, dist2: float) -> bool:
	for e in active_emitter_count:
		if kind >= 0 and emitter_kind_ids[e] != kind:
			continue
		if (emitter_positions[e] - p).length_squared() <= dist2:
			return true
	return false


func _stage_commit() -> void:
	for i in _pending_state_handles.size():
		_apply_state(_pending_state_handles[i], _pending_state_ids[i])
	_pending_state_handles.clear()
	_pending_state_ids.clear()
	for i in _pending_pen_handles.size():
		_apply_pen(_pending_pen_handles[i], _pending_pen_indices[i])
	_pending_pen_handles.clear()
	_pending_pen_indices.clear()
	if not _removal_queue.is_empty():
		_release_pen_spots(_removal_queue)
		removed_total += store.remove_many(_removal_queue)
		_removal_queue.clear()


func _apply_state(handle: int, new_state: int) -> void:
	var slot := store.slot_of(handle)
	if not store.is_active_slot(slot):
		return
	if store.state[slot] == new_state:
		return
	if new_state == dead_state_id:
		var sp := store.species[slot]
		if sp >= deaths_by_species.size():
			deaths_by_species.resize(sp + 1)
		deaths_by_species[sp] += 1
		killed_total += 1
		store.state[slot] = new_state
		_removal_queue.append(handle)
		boid_died.emit(sp, store.pos[slot])
		return
	store.state[slot] = new_state
	store.state_timer[slot] = 0.0
	if new_state == penned_state_id:
		store.freeze(slot)
		

func _apply_pen(handle: int, pen_index: int) -> void:
	var slot := store.slot_of(handle)
	if not store.is_active_slot(slot):
		return
	if store.state[slot] == dead_state_id or pen_boid_counts[pen_index] >= pen_capacities[pen_index]:
		return
	var spot := -1
	if pens[pen_index].snap_to_spots:
		var used := _pen_spot_occupied[pen_index]
		for k in used.size():
			if used[k] == 0:
				spot = k
				break
		if spot < 0:
			return
		used[spot] = 1
		var p := _pen_spot_positions[pen_index][spot]
		store.pos[slot] = p
		store.ground_h[slot] = ground.height_at(p)
	store.vel[slot] = Vector2.ZERO
	store.speed[slot] = 0.0
	store.state[slot] = penned_state_id
	store.state_timer[slot] = 0.0
	store.pen_id[slot] = pen_index
	store.pen_spot[slot] = spot
	pen_boid_counts[pen_index] += 1
	var sp := store.species[slot]
	store.freeze(slot)
	boid_penned.emit(pen_index, sp)


func _release_pen_spots(handles: PackedInt64Array) -> void:
	for h in handles:
		var slot := store.slot_of(h)
		if slot < store.active_count:
			continue
		var pi := store.pen_id[slot]
		if pi < 0:
			continue
		var sp := store.pen_spot[slot]
		if sp >= 0:
			_pen_spot_occupied[pi][sp] = 0
		pen_boid_counts[pi] -= 1
		store.pen_id[slot] = -1
