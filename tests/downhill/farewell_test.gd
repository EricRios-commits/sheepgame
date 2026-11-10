extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func run() -> void:
	for side in [-1, 1]:
		var level = load("res://scenes/downhill/downhill_level_01.tscn").instantiate()
		level.manual_simulation = true
		level.countdown_seconds = 0
		level.flock_count = 1
		level.spawn_center = Vector2(side * 15, 40)
		level.spawn_size = Vector2(0.001, 0.001)
		root.add_child(level)
		var h: int = level.system.store.handle_at(0)
		level.system.store.pos[0].x = side * 18.5
		level.simulate_step(0.033)
		level.simulate_step(0.033)
		check(level.lost == 1 and level.system.store.count == 0, "Real boid removed and loss counted immediately")
		check(level.get("farewells") != null, "Cosmetic farewell batch exists")
		if level.get("farewells") != null:
			var ghosts = level.farewells
			check(ghosts.ghosts.size() == 1, "Last lost sheep survives visually into results")
			var initial: Transform3D = ghosts.multimesh.get_instance_transform(0)
			ghosts.advance(0.25)
			var turned: Transform3D = ghosts.multimesh.get_instance_transform(0)
			print("FALL side=%d initial=%s turned=%s" % [side,initial,turned])
			check(turned.origin.x * side > initial.origin.x * side and turned.origin.y < initial.origin.y, "Outward falling translation")
			check(turned.basis.y.x * side > 0.2, "Opposite signed local-Z tumble at opposite rims")
			level._on_died(h, 0, Vector2.ZERO)
			level._on_penned(h, 0, 0)
			check(level.lost == 1 and level.saved == 0 and ghosts.ghosts.size() == 1, "No duplicate loss, ghost, or late save")
			level.toggle_pause()
			paused = true
			ghosts._process(0.2)
			check(ghosts.multimesh.get_instance_transform(0).is_equal_approx(turned), "Pause freezes farewell")
			paused = false
			ghosts.advance(0.3)
			var alpha: float = ghosts.multimesh.get_instance_color(0).a
			check(alpha > 0 and alpha < 1, "Uploaded material alpha fades during final quarter second")
			ghosts.advance(1)
			check(ghosts.ghosts.is_empty() and ghosts.multimesh.visible_instance_count == 0, "Finite ghost expiry")
			# Reversed heading must still lean toward the same world-space rim.
			var pose := Transform3D(Basis(Vector3.UP,PI),Vector3.ZERO)
			ghosts.snapshot(999,0,pose,Vector3(side,0,0))
			ghosts.advance(0.2)
			check(ghosts.multimesh.get_instance_transform(0).basis.y.x * side > 0.2, "Reversed heading preserves outward tumble direction")
			for i in 150:
				ghosts.snapshot(1000+i,0,pose,Vector3.RIGHT)
			check(ghosts.ghosts.size() == ghosts.CAPACITY and ghosts.multimesh.visible_instance_count == ghosts.CAPACITY, "Cosmetic storage and GPU instances bounded")
			await process_frame
			await RenderingServer.frame_post_draw
			ghosts.clear()
			check(ghosts.ghosts.is_empty() and ghosts.multimesh.visible_instance_count == 0, "Explicit cleanup empties bounded batch")
		level.free()
		await process_frame
		await process_frame
	await process_frame
	await create_timer(0.3).timeout
	print("FAREWELL failures=%d" % failures)
	quit(1 if failures else 0)
