extends SceneTree

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	if not ResourceLoader.exists("res://scripts/downhill/downhill_motion.gd"):
		check(false, "Stable handle fear/pad motion service exists")
		quit(1)
		return
	var level = load("res://scenes/downhill/downhill_level_01.tscn").instantiate()
	level.manual_simulation = true
	level.countdown_seconds = 0
	level.flock_count = 1
	level.spawn_center = Vector2(0, 30)
	level.spawn_size = Vector2(0.001, 0.001)
	root.add_child(level)
	var motion = level.motion
	check(level.system.profiles[0].states[0].max_speed == motion.Rules.SPEED_CAP, "Behavior absolute cap matches shared rule")
	var h: int = level.system.store.handle_at(0)
	var p: Vector2 = level.system.store.pos[0]
	check(level.dog.speed_for(false) == 7 and level.dog.speed_for(true) == 14, "Shared walk7 sprint14")
	motion.bark_at(p - Vector2(3, 0), 7)
	check(motion.stacks(h) == 0, "Sideways bark does not frighten whole herd")
	motion.bark_at(p - Vector2(0, 20), 7)
	check(motion.stacks(h) == 0, "Rear bark outside range has no fear")
	motion.bark_at(p - Vector2(0, 3), 7)
	check(motion.stacks(h) == 1 and is_equal_approx(motion.target_speed(h), 10.5), "First fear 1.5x")
	for i in 30:
		level.simulate_step(1.0 / 30)
	check(level.system.store.vel[0].y > 9, "Actual tick velocity gains speed")
	p = level.system.store.pos[0]
	motion.bark_at(p - Vector2(0, 3), 7)
	motion.bark_at(p - Vector2(0, 3), 7)
	check(motion.stacks(h) == 2 and is_equal_approx(motion.target_speed(h), 12.25), "Second stack capped, third refreshes")
	motion.boost(h)
	check(motion.target_speed(h) <= 12.6, "Combined target cap")
	for i in 110:
		level.simulate_step(1.0 / 30)
		check(level.system.store.speed[0] <= 13.001, "Actual sheep slower than unboosted sprint")
	check(motion.stacks(h) == 0 and is_equal_approx(motion.target_speed(h), 7), "Finite effects expire")
	motion.dog_boost_left = 2
	check(level.dog.speed_for(true) == level.dog.speed_for(false) * 2, "Pad retains dog 1:2 ratio")
	level.queue_loss(h)
	level.simulate_step(1.0 / 30)
	check(not motion.states.has(h), "Death cleans stable state")
	level.free()
	level = load("res://scenes/downhill/downhill_level_01.tscn").instantiate()
	level.manual_simulation = true
	level.countdown_seconds = 0
	level.flock_count = 1
	level.spawn_center = Vector2(0, 43)
	level.spawn_size = Vector2(0.001,0.001)
	root.add_child(level)
	for i in 6:
		level.simulate_step(1.0 / 30)
	check(level.motion.pad_entries == 1, "Pad entry debounces across actual ticks inside")
	check(level.motion.target_speed(level.system.store.handle_at(0)) > 9, "Pad increases actual steering target")
	level.dog.position = Vector3(0, 0, 43)
	level.motion.advance(0.1)
	check(level.motion.dog_boost_left == 2, "Dog gets pad on entry")
	level.motion.advance(0.5)
	check(is_equal_approx(level.motion.dog_boost_left, 1.5), "Dog inside pad does not refresh timer")
	level.dog.position.z = 50
	level.motion.advance(0.1)
	level.dog.position.z = 43
	level.motion.advance(0.1)
	check(level.motion.dog_boost_left == 2, "Dog may reenter after leaving")
	level.free()
	level = load("res://scenes/downhill/downhill_level_01.tscn").instantiate()
	level.manual_simulation = true
	level.countdown_seconds = 0
	level.flock_count = 1
	level.spawn_center = Vector2(0, 297)
	level.spawn_size = Vector2(0.001,0.001)
	root.add_child(level)
	for i in 120:
		level.simulate_step(1.0 / 30)
	check(level.saved == 1 and level.motion.states.is_empty(), "Pen commits clean mode state saved=%d states=%s" % [level.saved, level.motion.states.keys()])
	level.free()
	print("EFFECTS failures=%d" % failures)
	quit(1 if failures else 0)
