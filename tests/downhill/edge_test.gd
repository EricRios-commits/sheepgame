extends SceneTree

var failures := 0
var deaths := 0
var last_death := Vector2.ZERO

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var level = load("res://scenes/downhill/downhill_level_01.tscn").instantiate()
	level.manual_simulation = true
	level.countdown_seconds = 0
	level.flock_count = 1
	level.spawn_center = Vector2(11.95, 30)
	level.spawn_size = Vector2(0.001, 0.001)
	level.spawn_heading = 90
	root.add_child(level)
	var sys: BoidSystem = level.system
	sys.boid_died.connect(func(_species: int, at: Vector2):
		deaths += 1
		last_death = at)
	var handle := sys.store.handle_at(0)
	for i in 60:
		level.simulate_step(1.0 / 30.0)
	check(absf(last_death.x) > 12, "Actual physics crosses visible rim before death")
	check(deaths == 1 and level.lost == 1, "Edge emits and counts exactly one death")
	check(not sys.store.is_valid(handle) and sys.store.count == 0, "Dead stable handle removed")
	sys.request_state(handle, sys.vocab.state_id(BoidSystem.DEAD_STATE))
	sys.request_state(handle, sys.vocab.state_id(BoidSystem.DEAD_STATE))
	sys.tick(1.0 / 30.0)
	check(deaths == 1 and level.lost == 1, "Stale duplicate death requests cannot farm losses")
	check(sys.obstacles != null and not sys.use_world_bounds, "Rocks baked while bounds permit falls")
	level.free()
	print("EDGE failures=%d deaths=%d rim_x=%.3f" % [failures, deaths, last_death.x])
	quit(1 if failures else 0)
