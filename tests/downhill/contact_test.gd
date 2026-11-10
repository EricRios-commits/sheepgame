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
	level.manual_simulation = true
	level.countdown_seconds = 0
	level.flock_count = 1
	level.spawn_center = Vector2(0,107)
	root.add_child(level)
	var h: int = level.system.store.handle_at(0)
	var c := Vector3(0,3.3+level.motion.Rules.terrain_height(Vector2(0,110)),110)
	level.motion.check_hoops(h,c-Vector3(0,0,2),c-Vector3(0,0,0.3))
	check(level.motion.hoop_hits == 0,"Grounded passage cannot win hoop")
	level.motion.state(h).arc = 0.6
	level.motion.check_hoops(h,c-Vector3(0,0,2),c-Vector3(0,0,0.3))
	check(level.motion.hoop_hits == 1,"Leading body contact awards before center crosses")
	check(level.motion.spin_angle(h) > 0,"Contact immediately starts roll")
	check(level.motion.has_method("pulse_impact"),"Soundwave impact presentation path exists")
	check(level.get("effects") != null,"Bounded world effects service exists")
	level.motion.check_hoops(h,c-Vector3(0,0,5),c+Vector3(0,0,5))
	check(level.motion.hoop_hits == 1,"Repeated fast crossing cannot award same hoop twice")
	var c2 := Vector3(0,3.3+level.motion.Rules.terrain_height(Vector2(0,270)),270)
	level.motion.check_hoops(h,c2+Vector3(4,0,-5),c2+Vector3(4,0,5))
	level.motion.check_hoops(h,c2+Vector3(0,5,-5),c2+Vector3(0,5,5))
	check(level.motion.hoop_hits == 1,"Fast outside-radius and off-height misses")
	level.motion.check_hoops(h,c2-Vector3(0,0,20),c2+Vector3(0,0,20))
	check(level.motion.hoop_hits == 2,"High-speed sweep permits later hoop on same handle")
	var presenter: Node3D
	for child in level.system.get_children():
		if child is BoidPresenter:
			presenter = child
	presenter._process(0)
	print("SHEEP mesh bounds=%s" % presenter._active[0].mm.mesh.get_aabb())
	var saw_roll := false
	for i in 110:
		level.simulate_step(1.0/60)
		var s: Dictionary = level.motion.state(h)
		if s.spin > 0:
			presenter._write_region(0,1,presenter._active_bufs,1,false)
			var b: PackedFloat32Array = presenter._active_bufs[0].duplicate()
			var spun := Basis(Vector3(b[0],b[4],b[8]),Vector3(b[1],b[5],b[9]),Vector3(b[2],b[6],b[10]))
			var origin := Vector3(b[3],b[7],b[11])
			var remaining: float = s.spin
			s.spin = 0.0
			presenter._write_region(0,1,presenter._active_bufs,1,false)
			var normal: PackedFloat32Array = presenter._active_bufs[0]
			var forward := Vector3(normal[2],normal[6],normal[10])
			check(spun.z.is_equal_approx(forward),"Lengthwise roll preserves mesh local Z forward axis")
			s.spin = remaining
			var bounds: AABB = presenter._active[0].mm.mesh.get_aabb()
			for corner in 8:
				var p := origin+spun*bounds.get_endpoint(corner)
				check(p.y >= level.motion.Rules.height(Vector2(p.x,p.z))+0.1,"Rotated mesh corners clear sampled ground")
			saw_roll = true
	check(saw_roll,"Inspected actual rolled upload geometry")
	# Pulse impacts are radial, including lateral barks; fear remains rear-only.
	var p: Vector2 = level.system.store.pos[0]
	level.dog.position = Vector3(p.x-4,level.motion.Rules.height(p),p.y)
	var bark = level.dog.bark
	check(bark.trigger(),"Successful bark starts once")
	check(not bark.trigger(),"Cooldown rejects spam")
	check(level.dog.bark_hop_left > 0,"Successful bark starts dog hop")
	bark.advance(0.05)
	check(level.motion.state(h).bounce == 0,"No sheep hop before soundwave reaches lateral target")
	bark.advance(0.1)
	check(level.motion.state(h).bounce > 0,"Lateral sheep hops on radial wave impact")
	level.motion.state(h).bounce = 0.1
	bark.advance(0.03)
	check(level.motion.state(h).bounce == 0.1,"Impact ledger prevents repeated hop per pulse")
	bark.cancel()
	bark.cooldown_left = 0
	level.dog.position.x = p.x-12
	bark.trigger()
	level.motion.state(h).bounce = 0
	bark.advance(0.3)
	check(level.motion.state(h).bounce == 0,"Outside bark radius never hops")
	level.dog.animate_gait(0.125,true,true,7)
	check(level.dog.model.position.y > 0.15 and absf(level.dog.model.rotation.z) > 0.15,"Classic parabolic waddle geometry at apex")
	var positive: float = level.dog.model.position.x
	level.dog.animate_gait(0.25,true,true,7)
	check(positive*level.dog.model.position.x < 0,"Alternating gait side sway")
	level.dog.animate_gait(1,false,false,7)
	check(level.dog.model.position.is_zero_approx() and is_zero_approx(level.dog.model.rotation.z),"Idle/airborne gait settles")
	level.motion.boost(h)
	level.effects.advance(0.01)
	check(level.effects.visible_trails == 2,"Actual boosted animal has immediate cyan wake")
	level.effects.burst(presenter.global_position)
	level.effects.advance(0.01)
	check(level.effects.multimesh.visible_instance_count > 2,"Actual contact sparkle transforms uploaded")
	var count: int = level.effects.multimesh.visible_instance_count
	level.toggle_pause()
	level.simulate_step(1)
	check(level.effects.multimesh.visible_instance_count == count,"Pause freezes world effects")
	level.toggle_pause()
	for i in 90:
		level.simulate_step(1.0/30)
	check(level.effects.visible_trails == 0 and level.effects.sparks.is_empty(),"Boost wake and sparkle lifetimes expire")
	check(level.effects.multimesh.instance_count == 384,"Effects pool remains bounded")
	level.finish()
	check(level.effects.multimesh.visible_instance_count == 0,"Results clears world effects")
	level.free()
	print("CONTACT failures=%d" % failures)
	quit(1 if failures else 0)
