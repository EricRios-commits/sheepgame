extends SceneTree

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void:
	call_deferred("run")
func pose(b: PackedFloat32Array) -> Transform3D:
	return Transform3D(Basis(Vector3(b[0],b[4],b[8]), Vector3(b[1],b[5],b[9]), Vector3(b[2],b[6],b[10])), Vector3(b[3],b[7],b[11]))
func run() -> void:
	if not ResourceLoader.exists("res://scripts/downhill/downhill_motion.gd"):
		check(false, "Continuous launch and swept hoop service exists")
		quit(1)
		return
	var script = load("res://scripts/downhill/downhill_motion.gd")
	check(script.hoop_pass(Vector3(0, 3, -1), Vector3(0, 3, 1), Vector3(0, 3, 0), 2), "Swept 3D hoop center hit")
	check(not script.hoop_pass(Vector3(3, 3, -1), Vector3(3, 3, 1), Vector3(0, 3, 0), 2), "Outside radius miss")
	check(not script.hoop_pass(Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(0, 3, 0), 2), "Off height miss")
	check(not script.hoop_pass(Vector3(0, 3, 1), Vector3(0, 3, 2), Vector3(0, 3, 0), 2), "No plane crossing miss")
	var level = load("res://scenes/downhill/downhill_level_01.tscn").instantiate()
	level.manual_simulation = true
	level.countdown_seconds = 0
	level.flock_count = 1
	level.spawn_center = Vector2(0, 96)
	level.spawn_size = Vector2(0.001, 0.001)
	root.add_child(level)
	level.dog.position = Vector3(0, level.system.ground.height_at(Vector2(0,90)), 90)
	var h: int = level.system.store.handle_at(0)
	level.motion.state(h).arc = 0.0
	var lip := Vector2(0,103.99)
	check(absf(level.motion.world_position(h, lip).y - level.motion.Rules.terrain_height(lip) - 1.8) < 0.001, "First interpolated airborne frame does not double ramp height")
	level.motion.state(h).arc = -1.0
	var airborne := false
	var spin := false
	var pose_changed := false
	for i in 180:
		level.simulate_step(1.0 / 30)
		airborne = airborne or level.motion.height_offset(h) > 1
		spin = spin or level.motion.spin_angle(h) > 0.1
		if i == 45:
			var before: float = level.motion.height_offset(h)
			level.toggle_pause()
			level.simulate_step(1)
			check(level.motion.height_offset(h) == before, "Pause freezes actual airborne arc")
			level.toggle_pause()
		if level.motion.spin_angle(h) > 0.2 and not pose_changed:
			for child in level.system.get_children():
				if child is BoidPresenter:
					child._process(0)
					var spun := pose(child._active[0].buf)
					if DisplayServer.get_name() != "headless":
						check(child._active[0].mm.get_instance_transform(0).is_equal_approx(spun), "Rendering server receives airborne pose")
					var remaining: float = level.motion.state(h).spin
					level.motion.state(h).spin = 0
					child._process(0)
					var normal := pose(child._active[0].buf)
					pose_changed = not spun.basis.is_equal_approx(normal.basis)
					check(spun.origin.y > level.system.ground.height_at(Vector2(spun.origin.x, spun.origin.z)) + 1, "Uploaded pose is airborne")
					level.motion.state(h).spin = remaining
					if pose_changed and DisplayServer.get_name() != "headless":
						await RenderingServer.frame_post_draw
						var directory := OS.get_environment("DOWNHILL_OUTPUT_DIR")
						if not directory.is_empty():
							root.get_texture().get_image().save_png(directory.path_join("downhill-v3-pose-rendered.png"))
	check(airborne and spin and level.motion.hoop_hits == 1, "Natural ramp arc passes hoop once and spins")
	check(pose_changed, "Actual uploaded MultiMesh transform spins")
	check(level.motion.spin_angle(h) == 0 and level.motion.height_offset(h) == 0, "Finite arc and spin restore pose")
	# Exercise the same production swept award path with two later crossings.
	var center := Vector3(0, 3.3 + level.motion.Rules.terrain_height(Vector2(0,270)), 270)
	level.motion.state(h).arc = 0.6
	level.motion.check_hoops(h, center - Vector3(0,0,1), center + Vector3(0,0,1))
	level.motion.check_hoops(h, center - Vector3(0,0,1), center + Vector3(0,0,1))
	check(level.motion.hoop_hits == 2, "Same handle can pass later hoop, each only once")
	level.finish()
	var spin_before: float = level.motion.state(h).spin
	level.simulate_step(1)
	check(level.motion.state(h).spin == spin_before, "Results freeze motion")
	level.free()
	print("AIRBORNE failures=%d" % failures)
	quit(1 if failures else 0)
