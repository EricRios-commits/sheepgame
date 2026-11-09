extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var packed = load("res://scenes/downhill/downhill_level_01.tscn")
	var level = packed.instantiate()
	level.manual_simulation = true
	root.add_child(level)
	var start: Vector2 = level.system.store.pos[0]
	for i in 30:
		level.simulate_step(1.0 / 30.0)
	check(level.system.tick_count == 0 and level.system.store.pos[0] == start, "Countdown freezes real sheep")
	for i in 36:
		level.simulate_step(1.0 / 30.0)
	check(level.system.tick_count > 0, "Countdown releases the flock")
	level.free()
	# One original sheep starts at the barn; a second fixture zone adds a straggler.
	# spawn_all also repeats the original zone, so the actual population must be 3.
	level = packed.instantiate()
	level.manual_simulation = true
	level.countdown_seconds = 0
	level.flock_count = 1
	level.spawn_center = Vector2(0, 297)
	level.spawn_size = Vector2(0.001, 0.001)
	level.goal_grace = 0.25
	root.add_child(level)
	var zone := BoidSpawnZone.new()
	zone.system = level.system
	zone.position.z = 20
	zone.radius = 0.001
	zone.config = BoidSpawnConfig.new()
	zone.config.count = 1
	zone.config.initial_speed = 5
	zone.config.heading_policy = BoidSpawnConfig.HeadingPolicy.FIXED
	level.add_child(zone)
	level.system.spawn_all()
	check(level.initial == 3, "Population uses actual spawned handles after additional spawn")
	for i in 120:
		level.simulate_step(1.0 / 30.0)
	check(level.saved == 2 and level.lost == 1 and level.phase == level.Phase.RESULTS, "First delivery grace resolves straggler once")
	level.free()
	# Real CharacterBody movement on the actual sloping collision surface.
	level = packed.instantiate()
	level.manual_simulation = true
	root.add_child(level)
	for i in 30:
		await physics_frame
		level.dog.move_with_input(Vector2.ZERO, false, 1.0 / 60.0)
	for sprint in [false, true]:
		var before: Vector3 = level.dog.position
		for i in 60:
			await physics_frame
			level.dog.move_with_input(Vector2(0, 1), sprint, 1.0 / 60.0)
		var after: Vector3 = level.dog.position
		var distance := Vector2(after.x - before.x, after.z - before.z).length()
		print("DOG actual horizontal travel in 1s sprint=%s distance=%.4f" % [sprint, distance])
		check(absf(distance - (10.0 if sprint else 5.0)) < 0.08, "Dog's actual physical walk/sprint distance")
	var lost_before: int = level.lost
	level.dog.position = Vector3(14, -10, 20)
	level.dog.move_with_input(Vector2.ZERO, false, 1.0 / 60.0)
	check(level.dog.respawns == 1 and level.lost == lost_before, "Physical dog fall triggers rescue without sheep loss")
	level.dog.safe_z = 145.0
	level.dog.respawn()
	var rescue_xz := Vector2(level.dog.position.x, level.dog.position.z)
	check(level.system.obstacles.sample(rescue_xz).x > 1.0, "Rescue checkpoint cannot place dog inside central rock")
	level.free()
	print("TIMING failures=%d" % failures)
	quit(1 if failures else 0)
