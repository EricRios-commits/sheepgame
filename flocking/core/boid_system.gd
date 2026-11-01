class_name BoidSystem
extends Node3D
## Owner of all simulation state for one interacting group. The class has grown way too large
## should probably be split, but I'm lazy

enum Stage { SNAPSHOT, REBUILD_NEIGHBOURS, GATHER, COMBINE, INTEGRATE, GROUND, TRANSITIONS, COMMIT, PRESENT }
const STAGE_NAMES := ["Snapshot", "Neighbours", "Gather", "Combine", "Integrate", "Ground",
		"Transitions", "Commit", "Present"]
const MAX_STEPS_PER_FRAME := 4
const LUT_N := 16
const LAYER_COUNT := BoidInfluence.LAYER_COUNT

## Special states, registered in every system. PENNED is terminal and frozen; entering DEAD
## removes the boid in the same Commit.
const PENNED_STATE := &"penned"
const DEAD_STATE := &"dead"

signal spawned(count: int)
signal present_requested
signal ticked(sim_dt: float)
signal boid_penned(pen_index: int, species_id: int)
signal boid_died(species_id: int, position: Vector2)

@export var rng_seed := 12345
## Simulation rate, decoupled from the physics rate
@export_range(5, 120) var sim_hz := 30
## The runtime ground
@export var ground: BoidGround
## Where the ground comes from
@export var ground_source: BoidGroundSource
@export var ground_cell := 1.0
## Extra obstacle sources besides BoidObstacle nodes
@export var obstacle_sources: Array[BoidObstacleSource] = []
## On: bake ground and obstacles at startup
## Off: use the `ground` and `obstacles` resources exactly as assigned
@export var bake_on_start := true
@export var profiles: Array[BoidSpeciesProfile] = []
## Used by any species that has no profile
@export var default_profile: BoidSpeciesProfile
@export var interactions: BoidInteractionTable
@export var world_bounds := Rect2(-120.0, -120.0, 240.0, 240.0)
@export var use_world_bounds := true
## Collision radius of a boid against obstacles
@export var boid_radius := 0.5
@export var obstacle_cell := 0.5
@export var obstacle_max_dist := 5.0
## Ground steeper than this counts as unwalkable (0 = off).
@export var slope_limit_degrees := 0.0
@export_range(1, 10) var transition_stride := 3
@export var auto_spawn := true
@export var run_simulation := true

var store := BoidStore.new()
var vocab := BoidVocabulary.new()
var rng := RandomNumberGenerator.new()
var timer := BoidStageTimer.new(PackedStringArray(STAGE_NAMES))
var neighbours: BoidNeighbourStrategy = BoidNeighbourHash.new()
var table: BoidBehaviourTable
## The baked obstacle field (optional)
@export var obstacles: BoidObstacleField
var spawned_total := 0
var removed_total := 0
var killed_total := 0
var deaths_by_species := PackedInt32Array()
var tick_count := 0
var cur_dt := 0.0
var penned_state_id := -1
var dead_state_id := -1

var accel := PackedVector2Array()
var layer_acc: Array[PackedVector2Array] = []

## Emitters published this tick
var em_count := 0
var em_pos := PackedVector2Array()
var em_vel := PackedVector2Array()
var em_dir := PackedVector2Array()
var em_radius := PackedFloat32Array()
var em_cos_half := PackedFloat32Array()
var em_strength := PackedFloat32Array()
var em_kind := PackedInt32Array()
var em_lut := PackedFloat32Array()


var pens: Array[BoidPen] = []
var pen_count := PackedInt32Array()
var pen_capacity := PackedInt32Array()
var pen_center := PackedVector2Array()
var pen_ax := PackedVector2Array()
var pen_az := PackedVector2Array()
var pen_half := PackedVector2Array()
var pen_zmin := PackedFloat32Array()

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
var _pen_spots: Array[PackedVector2Array] = []
var _pen_spot_used: Array[PackedByteArray] = []
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
var _pen_req_handle := PackedInt64Array()
var _pen_req_pen := PackedInt32Array()


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


func register_emitter(e: BoidEmitter) -> void:
	if _emitters.has(e):
		return
	e.kind_id = vocab.emitter_kind_id(e.kind)
	_emitters.append(e)


func unregister_emitter(e: BoidEmitter) -> void:
	_emitters.erase(e)


func register_obstacle(o: BoidObstacle) -> void:
	if not _obstacle_nodes.has(o):
		_obstacle_nodes.append(o)


func register_pen(p: BoidPen) -> void:
	if not pens.has(p):
		pens.append(p)


func invalidate_table() -> void:
	table = null


# baking

func bake_environment() -> void:
	if ground == null:
		ground = BoidGround.new()
	if ground_source != null:
		var hf := ground_source.bake_ground(self, world_bounds, ground_cell)
		if hf != null:
			ground = hf
		else:
			push_error("BoidSystem: ground_source failed to bake; keeping the existing ground.")
	_build_pens()
	var has_mask := ground is BoidHeightfield
	if _obstacle_nodes.is_empty() and obstacle_sources.is_empty() and not has_mask:
		return
	var obstacle_field := BoidObstacleField.new()
	obstacle_field.setup(world_bounds, obstacle_cell, obstacle_max_dist)
	for o in _obstacle_nodes:
		o.bake_into(obstacle_field)
	if has_mask:
		obstacle_field.apply_walkable(ground, slope_limit_degrees)
	for src in obstacle_sources:
		if src != null:
			src.bake_obstacles(self, obstacle_field)
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
	pen_count.resize(pens.size())
	pen_count.fill(0)
	pen_capacity.resize(pens.size())
	pen_center.resize(pens.size())
	pen_ax.resize(pens.size())
	pen_az.resize(pens.size())
	pen_half.resize(pens.size())
	pen_zmin.resize(pens.size())
	_pen_spots.clear()
	_pen_spot_used.clear()
	for i in pens.size():
		var pen := pens[i]
		pen.index = i
		var b := pen.global_transform.basis
		pen_center[i] = pen.xz()
		pen_ax[i] = Vector2(b.x.x, b.x.z).normalized()
		pen_az[i] = Vector2(b.z.x, b.z.z).normalized()
		pen_half[i] = pen.trigger_half()
		pen_zmin[i] = pen.trigger_zmin()
		var spots := pen.compute_spots()
		var used := PackedByteArray()
		used.resize(spots.size())
		_pen_spots.append(spots)
		_pen_spot_used.append(used)
		pen_capacity[i] = spots.size() if pen.snap_to_spots else (1 << 30)


# public API

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


func request_state(handle: int, state_id: int) -> void:
	_state_handles.append(handle)
	_state_values.append(state_id)


func select_debug_boid(handle: int) -> void:
	debug_handle = handle


func alive_count() -> int:
	return store.count


func penned_count() -> int:
	return store.count - store.active_count


func pen_count_of(pen_index: int) -> int:
	return pen_count[pen_index]


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
	for c in pen_count:
		in_pens += c
	if in_pens > store.count - store.active_count:
		return false
	var in_pens_scan := 0
	for i in range(store.active_count, store.count):
		if store.pen_id[i] >= 0:
			in_pens_scan += 1
	return in_pens_scan == in_pens


# spawingn

func _spawn_zone(zone: BoidSpawnZone) -> int:
	var cfg := zone.config
	if cfg == null or cfg.count <= 0:
		return 0
	var sp := vocab.species_id(cfg.species)
	var st := vocab.state_id(cfg.initial_state)
	var centre := zone.center_xz()
	var placed := 0
	for i in cfg.count:
		var xz := Vector2.ZERO
		var ok := false
		for attempt in 20:
			xz = zone.local_to_world_xz(zone.sample_local(rng))
			if _spawn_ok(xz):
				ok = true
				break
		if not ok:
			continue
		var h := _initial_heading(cfg, xz, centre)
		var dir := Vector2(sin(h), cos(h))
		store.add(xz, dir * cfg.initial_speed, h, cfg.initial_speed, sp, st, ground.height_at(xz))
		placed += 1
	if placed < cfg.count:
		push_warning("BoidSpawnZone '%s': only %d of %d boids found a legal position (off ground, in an obstacle or out of bounds)." % [zone.name, placed, cfg.count])
	return placed


func _spawn_ok(xz: Vector2) -> bool:
	if use_world_bounds and not world_bounds.has_point(xz):
		return false
	if not ground.is_over_ground(xz):
		return false
	if obstacles != null and obstacles.sample(xz).x < boid_radius * 1.5:
		return false
	return true


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
		penned_state_id = vocab.state_id(PENNED_STATE)
		dead_state_id = vocab.state_id(DEAD_STATE)
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
	var n := store.active_count
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


func _stage_gather() -> void:
	var n := store.active_count
	for l in LAYER_COUNT:
		var a := layer_acc[l]
		a.resize(n)
		a.fill(Vector2.ZERO)
	debug_slot = store.slot_of(debug_handle)
	if debug_slot >= n:
		debug_slot = -1
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
## priority order
func _stage_combine() -> void:
	var n := store.active_count
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
	var n := store.active_count
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
	var f := obstacles
	var have_f := f != null
	var r := boid_radius
	var f_dist := PackedFloat32Array()
	var f_w := 0
	var f_d := 0
	var f_ox := 0.0
	var f_oz := 0.0
	var f_inv := 1.0
	var f_near := 0.0
	if have_f:
		f_dist = f.dist
		f_w = f.width
		f_d = f.depth
		f_ox = f.origin.x
		f_oz = f.origin.y
		f_inv = 1.0 / f.cell
		f_near = r + f.cell
	for i in n:
		var max_s := max_speed[_group_of[i]]
		var v := vel[i] + accel[i] * dt
		var s := v.length()
		if s > max_s:
			v *= max_s / s
			s = max_s
		var p := pos[i] + v * dt
		if have_f:
			var cx := clampi(int((p.x - f_ox) * f_inv), 0, f_w - 1)
			var cz := clampi(int((p.y - f_oz) * f_inv), 0, f_d - 1)
			if f_dist[cz * f_w + cx] < f_near:
				var sm := f.sample(p)
				var gap := sm.x - r
				if gap < 0.0:
					var nrm := Vector2(sm.y, sm.z)
					p -= nrm * gap
					var vn := v.dot(nrm)
					if vn < 0.0:
						v -= nrm * vn
						s = v.length()
		vel[i] = v
		spd[i] = s
		if s > 0.001:
			hdg[i] = atan2(v.x, v.y)
		if clamp_pos:
			p = p.clamp(b_min, b_max)
		pos[i] = p


func _stage_ground() -> void:
	ground.sample_batch(store.pos, store.ground_h, store.active_count)


func _stage_transitions() -> void:
	var n := store.active_count
	if n == 0:
		return
	var t := table
	var timers := store.state_timer
	var pos := store.pos
	var dt := cur_dt
	var stride := transition_stride
	var phase := tick_count % stride
	var n_pens := pens.size()
	for i in n:
		timers[i] += dt
		if (i + phase) % stride != 0:
			continue
		var g := _group_of[i]
		var requested := false
		for k in range(t.tr_start[g], t.tr_start[g + 1]):
			var trig := t.tr_trigger[k]
			var hit := false
			if trig == BoidTransition.Trigger.TIMER:
				hit = timers[i] >= t.tr_seconds[k]
			elif timers[i] >= t.tr_min_time[k]:
				var any := em_count > 0 and _emitter_within(pos[i], t.tr_emitter_kind[k], t.tr_dist2[k])
				hit = any if trig == BoidTransition.Trigger.EMITTER_NEAR else not any
			if hit:
				request_state(store.handle_at(i), t.tr_to[k])
				requested = true
				break
		if requested or n_pens == 0:
			continue
		var p := pos[i]
		for pi in n_pens:
			if pen_count[pi] >= pen_capacity[pi]:
				continue
			var local := p - pen_center[pi]
			var lz := local.dot(pen_az[pi])
			if lz < pen_zmin[pi] or lz > pen_half[pi].y:
				continue
			if absf(local.dot(pen_ax[pi])) > pen_half[pi].x:
				continue
			_pen_req_handle.append(store.handle_at(i))
			_pen_req_pen.append(pi)
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
		_apply_state(_state_handles[i], _state_values[i])
	_state_handles.clear()
	_state_values.clear()
	for i in _pen_req_handle.size():
		_apply_pen(_pen_req_handle[i], _pen_req_pen[i])
	_pen_req_handle.clear()
	_pen_req_pen.clear()
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
	if store.state[slot] == dead_state_id or pen_count[pen_index] >= pen_capacity[pen_index]:
		return
	var spot := -1
	if pens[pen_index].snap_to_spots:
		var used := _pen_spot_used[pen_index]
		for k in used.size():
			if used[k] == 0:
				spot = k
				break
		if spot < 0:
			return
		used[spot] = 1
		var p := _pen_spots[pen_index][spot]
		store.pos[slot] = p
		store.ground_h[slot] = ground.height_at(p)
	store.vel[slot] = Vector2.ZERO
	store.speed[slot] = 0.0
	store.state[slot] = penned_state_id
	store.state_timer[slot] = 0.0
	store.pen_id[slot] = pen_index
	store.pen_spot[slot] = spot
	pen_count[pen_index] += 1
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
			_pen_spot_used[pi][sp] = 0
		pen_count[pi] -= 1
		store.pen_id[slot] = -1
