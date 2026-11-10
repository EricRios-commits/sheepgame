extends SceneTree
## Difficulty regression: the safest play must involve herding, not doing nothing.

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var baseline_saved := 0
	for guided in [false, true]:
		var level = load("res://scenes/downhill/downhill_level_01.tscn").instantiate()
		level.manual_simulation = true
		level.countdown_seconds = 0.0
		root.add_child(level)
		level.system.boid_died_identified.connect(func(_h: int, _species: int, at: Vector2): print("GUIDANCE loss guided=%s at=%s" % [guided,at]))
		var pulses := 0
		for tick in 3000:
			var center: Vector3 = level.flock_center()
			if guided and (center.z > 170 and center.z < 230):
				# A flank-emitter fixture isolates bark steering. No sheep transform,
				# velocity, state, or grouping is overridden. The rendered driver
				# separately gets the real dog here through CharacterBody movement.
				var outer := 0.0
				for p in level.living_positions():
					outer = maxf(outer, p.x) if center.z < 235 else minf(outer, p.x)
				level.dog.position = Vector3(clampf(outer + (3 if center.z < 235 else -3), -17, 17), center.y, center.z)
				if level.dog.bark.trigger():
					pulses += 1
			level.simulate_step(1.0 / 30.0)
			check(level.saved + level.lost + level.remaining() == level.initial,
				"Population invariant under guidance")
			if level.phase == level.Phase.RESULTS:
				break
		print("GUIDANCE guided=%s pulses=%d saved=%d lost=%d" % [guided, pulses, level.saved, level.lost])
		check(level.phase == level.Phase.RESULTS, "Guidance scenario terminates")
		if guided:
			check(pulses > 0 and level.saved > baseline_saved, "Timely inward barking improves survival")
			check(level.survival() >= 0.95, "Correct flank guidance can earn three stars")
		else:
			baseline_saved = level.saved
			check(level.saved > 0 and level.saved < level.initial, "No-input run is survivable but not automatically perfect")
		level.free()
	print("GUIDANCE failures=%d" % failures)
	quit(1 if failures else 0)
