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
	var path := "res://scenes/downhill/downhill_level_01.tscn"
	if not ResourceLoader.exists(path):
		check(false, "Playable downhill scene and lifecycle exist")
		quit(1)
		return
	var packed = load(path)
	# These are real authored-scene physics runs. Only spawn fixtures differ.
	for scenario in ["saved", "lost", "mixed", "straggler"]:
		var level = packed.instantiate()
		level.flock_count = 3
		level.countdown_seconds = 0.0
		level.manual_simulation = true
		level.spawn_center = Vector2(0, 297)
		level.spawn_size = Vector2(0.01, 0.01)
		if scenario == "lost":
			level.spawn_center = Vector2(Rules.HALF_WIDTH - 0.05, 20)
			level.spawn_heading = 90.0
		if scenario == "straggler":
			level.spawn_center = Vector2(0, 20)
			level.round_limit = 0.1
		root.add_child(level)
		check(level.initial == 3, "Actual spawned count establishes population")
		var handles: Array[int] = []
		for i in level.system.store.count:
			handles.append(level.system.store.handle_at(i))
		if scenario == "mixed":
			level.system.request_state(handles[0], level.system.vocab.state_id(BoidSystem.DEAD_STATE))
			level.system.request_state(handles[0], level.system.vocab.state_id(BoidSystem.DEAD_STATE))
		for i in 180:
			level.simulate_step(1.0 / 30.0)
			check(level.saved + level.lost + level.remaining() == level.initial, "Population invariant")
		check(level.phase == level.Phase.RESULTS, "Round terminates: " + scenario)
		if scenario == "saved":
			check(level.saved == 3 and level.stars() == 3, "All saved, three stars")
		if scenario == "lost" or scenario == "straggler":
			check(level.lost == 3 and level.saved == 0, "All lost / timeout cleanup")
		if scenario == "mixed":
			check(level.saved == 2 and level.lost == 1, "Swap removal preserves identities and death dedup")
			check(not level.system.store.is_valid(handles[0]), "Dead identity becomes stale after swap removal")
			check(level.outcomes[handles[1]] == &"saved" and level.outcomes[handles[2]] == &"saved", "Survivor handles remain correct")
		check(level.system.check_invariants(), "BoidSystem invariants after terminal events")
		var ticks: int = level.system.tick_count
		level.simulate_step(1.0)
		check(ticks == level.system.tick_count, "Results freezes simulation")
		level.free()
	print("LIFECYCLE failures=%d" % failures)
	quit(1 if failures else 0)
