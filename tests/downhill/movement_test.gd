extends SceneTree
const Rules = preload("res://scripts/downhill/downhill_rules.gd")

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var path := "res://assets/boids_resources/downhill_sheep_behaviour.tres"
	if not ResourceLoader.exists(path):
		check(false, "Downhill profile exists and can drive real BoidSystem")
		quit(1)
		return
	var profile = load(path)
	for flank in [0.0, -3.0, 3.0]:
		var sys := BoidSystem.new()
		sys.auto_spawn = false
		sys.run_simulation = false
		sys.bake_on_start = false
		sys.use_world_bounds = false
		sys.profiles.append(profile)
		root.add_child(sys)
		var zone := BoidSpawnZone.new()
		zone.system = sys
		zone.radius = 0.01
		zone.config = BoidSpawnConfig.new()
		zone.config.count = 1
		zone.config.heading_policy = BoidSpawnConfig.HeadingPolicy.FIXED
		zone.config.initial_speed = Rules.CRUISE
		sys.add_child(zone)
		sys.spawn_all()
		var start := sys.store.pos[0]
		var bark := BoidEmitter.new()
		bark.system = sys
		bark.kind = &"bark"
		bark.radius = 7.0
		bark.strength = 30.0
		bark.position = Vector3(flank, 0, 0)
		bark.active = flank != 0.0
		sys.add_child(bark)
		for i in 10:
			sys.tick(1.0 / 30.0)
		var travel := sys.store.pos[0] - start
		if flank == 0.0:
			check(travel.y > 1.5, "Real boid advances without input")
			check(absf(sys.store.speed[0] - Rules.CRUISE) < 0.05, "Sheep cruise uses shared rules")
		else:
			check(travel.x * -signf(flank) > 0.15, "Flank bark pushes away within 0.33s: %s" % flank)
		sys.free()
	print("MOVEMENT failures=%d" % failures)
	quit(1 if failures else 0)
