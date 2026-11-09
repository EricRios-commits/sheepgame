extends Node3D
## One scene owns the run. Simulation callbacks only read stores or queue states.

enum Phase { COUNTDOWN, RUNNING, RESOLVING, RESULTS }
const GROUND = preload("res://scripts/downhill/downhill_ground.gd")
const TRACK = preload("res://scripts/downhill/downhill_track.gd")
const DOG = preload("res://scripts/downhill/downhill_dog.gd")
const BARK = preload("res://scripts/downhill/downhill_bark.gd")
const CAMERA = preload("res://scripts/downhill/downhill_camera.gd")
const HUD = preload("res://scripts/downhill/downhill_hud.gd")

@export_range(1, 100) var flock_count := 35
@export var countdown_seconds := 2.0
@export var goal_grace := 6.0
@export var round_limit := 95.0
## Deterministic fixture controls also support the profiling harness.
@export var manual_simulation := false
@export var spawn_center := Vector2(0, 14)
@export var spawn_size := Vector2(10, 7)
@export var spawn_heading := 0.0

var system: BoidSystem
var dog: CharacterBody3D
var hud: CanvasLayer
var phase := Phase.COUNTDOWN
var initial := 0
var saved := 0
var lost := 0
var countdown_left := 2.0
var elapsed := 0.0
var grace_left := -1.0
var progress_z := 0.0
var outcomes: Dictionary = {}
var pending_losses: Dictionary = {}
var population: Dictionary = {}
var split := false
var ever_split := false
var reunited := false
var notice := ""
var notice_left := 0.0
var _group_clock := 0.0
var _split_candidate := false
var _candidate_time := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	countdown_left = countdown_seconds
	system = BoidSystem.new()
	system.name = "BoidSystem"
	system.process_mode = Node.PROCESS_MODE_PAUSABLE
	system.auto_spawn = false
	system.run_simulation = false
	system.use_world_bounds = false
	system.world_bounds = Rect2(-20, -16, 40, 348)
	system.ground = GROUND.new()
	system.profiles.append(preload("res://assets/boids_resources/downhill_sheep_behaviour.tres"))
	add_child(system)
	system.spawned.connect(_on_spawned)
	system.boid_died_identified.connect(_on_died)
	system.boid_penned_identified.connect(_on_penned)
	system.ticked.connect(_on_tick)
	var track := TRACK.new()
	track.name = "Track"
	add_child(track)
	track.build(system)
	var storage := BoidPenStorage.new()
	storage.system = system
	storage.snap_to_spots = false
	storage.position = Vector3(0, -26.5, 307)
	add_child(storage)
	var gate := BoidPenEntrance.new()
	gate.storage = storage
	gate.size = Vector2(23, 6)
	gate.position = Vector3(0, -26.2, 301)
	add_child(gate)
	var zone := BoidSpawnZone.new()
	zone.system = system
	zone.shape = BoidSpawnZone.Shape.RECTANGLE
	zone.size = spawn_size
	zone.position = Vector3(spawn_center.x, 0, spawn_center.y)
	zone.config = BoidSpawnConfig.new()
	zone.config.count = flock_count
	zone.config.heading_policy = BoidSpawnConfig.HeadingPolicy.FIXED
	zone.config.fixed_heading_degrees = spawn_heading
	zone.config.initial_speed = 5.0
	add_child(zone)
	var presenter := BoidPresenter.new()
	# The presenter already interpolates its buffers; avoid double interpolation.
	presenter.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	presenter.system = system
	presenter.visuals.append(preload("res://assets/boids_resources/sheep_visual.tres"))
	system.add_child(presenter)
	dog = DOG.new()
	dog.name = "Dog"
	dog.level = self
	dog.position = Vector3(0, 1, 6)
	dog.bark = BARK.new()
	dog.bark.system = system
	dog.add_child(dog.bark)
	add_child(dog)
	var camera := CAMERA.new()
	camera.level = self
	add_child(camera)
	var environment := WorldEnvironment.new()
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color("6899b7")
	sky.sky_horizon_color = Color("c4d5d1")
	sky.ground_bottom_color = Color("304952")
	sky.ground_horizon_color = Color("93b1b7")
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_SKY
	environment.environment.sky = Sky.new()
	environment.environment.sky.sky_material = sky
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d8e7ef")
	environment.environment.ambient_light_energy = 0.55
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_color = Color("fff1cf")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	add_child(sun)
	hud = HUD.new()
	hud.level = self
	add_child(hud)
	# Only solid BoidObstacle nodes are baked. Analytic voids never form walls.
	system.bake_environment()
	system.spawn_all()
	if countdown_left <= 0:
		start_run()

func _on_spawned(_count: int) -> void:
	for i in system.store.count:
		population[system.store.handle_at(i)] = true
	initial = population.size()
	if initial == 0:
		finish()

func start_run() -> void:
	if phase == Phase.RESULTS:
		return
	phase = Phase.RUNNING
	system.run_simulation = not manual_simulation
	dog.enabled = not manual_simulation

func _physics_process(delta: float) -> void:
	if manual_simulation or get_tree().paused:
		return
	if phase == Phase.COUNTDOWN:
		countdown_left -= delta
		if countdown_left <= 0:
			start_run()

func _process(_delta: float) -> void:
	if hud:
		hud.update_display()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			toggle_pause()
		elif event.physical_keycode == KEY_R and (phase == Phase.RESULTS or get_tree().paused):
			retry()

func simulate_step(delta: float) -> void:
	if get_tree().paused or phase == Phase.RESULTS:
		return
	if phase == Phase.COUNTDOWN:
		countdown_left -= delta
		if countdown_left <= 0:
			start_run()
		return
	system.tick(delta)

func _on_tick(delta: float) -> void:
	if phase == Phase.RESULTS:
		return
	dog.bark.advance(delta)
	elapsed += delta
	notice_left = maxf(0, notice_left - delta)
	var positions := living_positions()
	for i in system.store.count:
		var handle := system.store.handle_at(i)
		if outcomes.has(handle) or pending_losses.has(handle):
			continue
		if not system.ground.is_over_ground(system.store.pos[i]):
			queue_loss(handle)
	var center := flock_center()
	progress_z = maxf(progress_z, minf(center.z, 300))
	# First arrival starts a bounded grace window; hard deadline resolves stalled runs.
	if saved > 0 and grace_left < 0:
		grace_left = goal_grace
	if grace_left >= 0:
		grace_left -= delta
	if elapsed >= round_limit or (grace_left <= 0 and grace_left > -1):
		phase = Phase.RESOLVING
		for handle in population:
			if not outcomes.has(handle):
				queue_loss(handle)
	_group_clock += delta
	if _group_clock >= 0.25:
		update_groups(positions, _group_clock)
		_group_clock = 0.0
	if remaining() == 0:
		finish()

func queue_loss(handle: int) -> void:
	if outcomes.has(handle) or pending_losses.has(handle):
		return
	pending_losses[handle] = true
	system.request_state(handle, system.vocab.state_id(BoidSystem.DEAD_STATE))

func _on_died(handle: int, _species: int, _at: Vector2) -> void:
	if not population.has(handle) or outcomes.has(handle):
		return
	outcomes[handle] = &"lost"
	pending_losses.erase(handle)
	lost += 1

func _on_penned(handle: int, _storage: int, _species: int) -> void:
	if not population.has(handle) or outcomes.has(handle):
		return
	outcomes[handle] = &"saved"
	pending_losses.erase(handle)
	saved += 1

func remaining() -> int:
	return initial - saved - lost

func survival() -> float:
	return float(saved) / initial if initial > 0 else 0.0

func stars() -> int:
	var fraction := survival()
	return int(fraction >= 0.6) + int(fraction >= 0.8) + int(fraction >= 0.95)

func living_positions() -> PackedVector2Array:
	var positions := PackedVector2Array()
	for i in system.store.count:
		if not outcomes.has(system.store.handle_at(i)):
			positions.append(system.store.pos[i])
	return positions

func flock_center() -> Vector3:
	var positions := living_positions()
	var center := Vector2(0, progress_z)
	if not positions.is_empty():
		center = Vector2.ZERO
		for p in positions:
			center += p
		center /= positions.size()
	return Vector3(center.x, system.ground.height_at(center), center.y)

func flock_extent(center: Vector3) -> float:
	var distances: Array[float] = []
	for p in living_positions():
		distances.append(p.distance_to(Vector2(center.x, center.z)))
	if distances.is_empty():
		return 0
	distances.sort()
	return distances[int((distances.size() - 1) * 0.9)]

func update_groups(positions: PackedVector2Array, delta: float) -> void:
	var unvisited: Array[int] = []
	for i in positions.size():
		unvisited.append(i)
	var substantial := 0
	while not unvisited.is_empty():
		var queue: Array[int] = [unvisited.pop_back()]
		var size := 0
		while not queue.is_empty():
			var index: int = queue.pop_back()
			size += 1
			for j in range(unvisited.size() - 1, -1, -1):
				if positions[index].distance_squared_to(positions[unvisited[j]]) < 16.0:
					queue.append(unvisited[j])
					unvisited.remove_at(j)
		if size >= 3:
			substantial += 1
	var candidate := substantial >= 2
	if candidate != _split_candidate:
		_split_candidate = candidate
		_candidate_time = 0
	_candidate_time += delta
	if _candidate_time >= 0.75 and split != candidate:
		split = candidate
		if split:
			ever_split = true
			notice = "Flock split! Sprint to the outer flank."
		elif ever_split:
			reunited = true
			notice = "Reunited! Keep them together."
		notice_left = 2.5

func finish() -> void:
	phase = Phase.RESULTS
	system.run_simulation = false
	dog.enabled = false
	dog.bark.cancel()

func rescue_position(preferred_z: float) -> Vector3:
	var z := clampf(preferred_z, 0, 295)
	# Search on solid safe ground; a flank checkpoint may sit beside a central rock.
	while z > 0:
		var xz := Vector2(0, z)
		if system.ground.is_over_ground(xz) and (system.obstacles == null or system.obstacles.sample(xz).x > 1.2):
			break
		z = maxf(0, z - 1.0)
	return Vector3(0, system.ground.height_at(Vector2(0, z)) + 1.0, z)

func toggle_pause() -> void:
	if phase != Phase.RESULTS:
		get_tree().paused = not get_tree().paused

func retry() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func back_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu_3d.tscn")

func _exit_tree() -> void:
	get_tree().paused = false
