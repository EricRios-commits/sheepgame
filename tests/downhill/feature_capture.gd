extends SceneTree
## Rendered feature fixture; real natural sheep ticks, explicit camera shots.
var level: Node3D
var failures := 0
var output := ""
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: "+message)
func fixture(p: Vector2) -> void:
	level = load("res://scenes/downhill/downhill_level_01.tscn").instantiate()
	level.manual_simulation = true
	level.countdown_seconds = 0
	level.flock_count = 1
	level.spawn_center = p
	level.spawn_size = Vector2(0.001,0.001)
	root.add_child(level)
	level.dog.position = Vector3(p.x,level.motion.Rules.height(p-Vector2(0,5)),p.y-5)
func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path := output.path_join("downhill-v3-"+label+".png")
	check(root.get_texture().get_image().save_png(path) == OK,"Save "+label)
	print("CAPTURE "+path)
func run() -> void:
	output = OS.get_environment("DOWNHILL_OUTPUT_DIR")
	root.content_scale_size = Vector2i(1280,720)
	root.size = Vector2i(1280,720)
	fixture(Vector2(0,43))
	level.simulate_step(1.0/30)
	level.dog.position.z = 43
	level.motion.advance(0.01)
	level.dog.position.x = 2
	var pad_camera := root.get_camera_3d()
	pad_camera.set_process(false)
	pad_camera.position = Vector3(6,level.motion.Rules.height(Vector2(0,43))+7,33)
	pad_camera.look_at(Vector3(0,level.motion.Rules.height(Vector2(0,43))+0.5,43))
	level.dog.animate_gait(0.125,true,true,11.2)
	level.dog.bark.trigger()
	level.dog.bark.advance(0.08)
	level.dog.animate_gait(0.05,true,true,11.2)
	level.hud.wind._process(0.1)
	print("PAD sheep=%s effect=%s" % [level.motion.state(level.system.store.handle_at(0)).prev,level.effects.multimesh.get_instance_transform(0)])
	await capture("pad-wind-waddle")
	level.dog.bark.advance(0.1)
	level.simulate_step(0.1)
	check(level.motion.bounce_height(level.system.store.handle_at(0)) > 0,"Rendered sheep hop advances from real pulse impact")
	await capture("bark-impact-hop")
	level.free()
	await process_frame
	fixture(Vector2(0,96))
	var h: int = level.system.store.handle_at(0)
	var shot := false
	var saw_leading := false
	for i in 110:
		level.simulate_step(1.0/30)
		if level.motion.state(h).spin > 0:
			saw_leading = saw_leading or level.system.store.pos[0].y < 110
			if not shot and level.motion.spin_angle(h) > 1:
				var camera := root.get_camera_3d()
				camera.set_process(false)
				camera.position = Vector3(7,level.motion.Rules.height(Vector2(0,108))+6,100)
				camera.look_at(level.motion.state(h).prev+Vector3.UP*0.5)
				check(not level.effects.sparks.is_empty(),"Natural hoop capture includes live contact burst")
				await capture("hoop-barrel-sparkles")
				shot = true
	check(shot and saw_leading,"Natural hoop leading entry and visible barrel roll captured")
	var camera := root.get_camera_3d()
	camera.set_process(false)
	var barn: Node3D = level.get_node("Track/GroundedBarn")
	var bounds: AABB = barn.get_meta("footprint")
	camera.position = Vector3(13,bounds.position.y+9,291)
	camera.look_at(Vector3(0,bounds.position.y+3,312))
	level.hud.hide()
	await capture("finish-barn")
	level.free()
	await process_frame
	fixture(Vector2(0,297))
	for i in 100:
		level.simulate_step(1.0/30)
	level.hud.update_display()
	check(level.saved == 1 and level.phase == level.Phase.RESULTS,"Natural delivery reaches filled-star results")
	await capture("filled-star-results")
	level.free()
	await process_frame
	print("FEATURE CAPTURE failures=%d" % failures)
	quit(1 if failures else 0)
