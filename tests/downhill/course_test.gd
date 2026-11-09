extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var level = load("res://scenes/downhill/downhill_level_01.tscn").instantiate()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		level.flock_count = int(args[0])
	level.manual_simulation = true
	level.countdown_seconds = 0
	root.add_child(level)
	var left_stream := false
	var right_stream := false
	var central_passed := false
	var penetration := 0
	for frame in 3000:
		level.simulate_step(1.0 / 30.0)
		for p in level.living_positions():
			if p.y > 140 and p.y < 154:
				left_stream = left_stream or p.x < -4.5
				right_stream = right_stream or p.x > 4.5
			if p.y > 167:
				central_passed = true
			for rock in level.get_node("Track").ROCKS:
				if p.distance_to(Vector2(rock.x, rock.y)) < rock.z + 0.25:
					penetration += 1
		if level.phase == level.Phase.RESULTS:
			break
	print("COURSE saved=%d lost=%d seconds=%.2f left=%s right=%s split=%s reunited=%s penetration=%d" % [
		level.saved, level.lost, level.elapsed, left_stream, right_stream, level.ever_split, level.reunited, penetration])
	print(level.system.stage_timer.summary())
	check(central_passed and (left_stream or right_stream), "Flock physically traverses the central rock")
	check(penetration == 0, "Sheep do not pass through solid rock")
	# Split/rejoin acceptance is for the authored 35-sheep mode and stress flocks.
	# Smaller optional populations can legitimately choose a single physical path.
	if level.initial >= 35:
		check(left_stream and right_stream, "Central rock physically produces two traversable streams")
		check(level.ever_split and level.reunited, "Physical split and rejoin detected without teleporting")
	check(level.saved > 0 and level.phase == level.Phase.RESULTS, "Authored course completes with delivered sheep")
	check(level.saved + level.lost == level.initial and level.remaining() == 0, "Course resolves the entire actual population")
	level.free()
	print("COURSE failures=%d" % failures)
	quit(1 if failures else 0)
