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
	root.add_child(level)
	var camera = root.get_camera_3d()
	check(camera.get("dog_only") != null,"Camera exposes second follow mode")
	check(level.hud.get("classic") != null,"HUD instantiates Classic scene adapter")
	check(level.hud.get("wind") != null,"Pad event drives actual screen streak control")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	var release := press.duplicate()
	release.pressed = false
	camera._process(1)
	var herd_focus: Vector3 = camera.focus
	camera._unhandled_input(press)
	camera._unhandled_input(release)
	check(not camera.dog_only,"RMB press selects herd follow")
	camera._process(0.016)
	check(not camera.focus.is_equal_approx(herd_focus) and not camera.focus.is_equal_approx(level.dog.position+Vector3(0,1.2,3)),"Camera transition damps smoothly between modes")
	camera._unhandled_input(press)
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	motion.relative = Vector2(10,0)
	camera._unhandled_input(motion)
	camera._unhandled_input(release)
	check(camera.dog_only and camera.yaw != 0,"Next press returns dog mode and motion orbits")
	camera._unhandled_input(press)
	camera._unhandled_input(release)
	check(not camera.dog_only,"Each press switches once regardless of hold")
	camera._unhandled_input(press)
	camera._unhandled_input(release)
	camera._process(5)
	var before: Vector3 = camera.focus
	var distance: float = camera.desired_distance
	var zone := BoidSpawnZone.new()
	zone.system = level.system
	zone.position.z = 270
	zone.config = BoidSpawnConfig.new()
	zone.config.count = 35
	level.add_child(zone)
	level.system.spawn_all()
	camera._process(5)
	check(before.is_equal_approx(camera.focus) and distance == camera.desired_distance,"Distant herd cannot change dog-only focus or distance")
	level.toggle_pause()
	camera._unhandled_input(press)
	camera._unhandled_input(release)
	check(camera.dog_only,"Paused RMB cannot change mode")
	level.toggle_pause()
	level.motion.dog_boost_left = 2
	level.hud.wind._process(0.1)
	check(level.hud.wind.intensity > 0,"Pad timer drives screen wind")
	var wind_clock: float = level.hud.wind.clock
	level.toggle_pause()
	level.hud.wind._process(1)
	check(level.hud.wind.clock == wind_clock,"Paused wind freezes phase")
	level.toggle_pause()
	level.motion.dog_boost_left = 0
	level.dog.velocity.z = 22
	level.hud.wind._process(0.1)
	check(level.hud.wind.intensity == 0,"Unrelated dog speed cannot trigger wind")
	level.dog.enabled = true
	level.dog.set_physics_process(false)
	for resolution in [Vector2i(1280,720),Vector2i(960,540)]:
		root.content_scale_size = resolution
		root.size = resolution
		await process_frame
		await process_frame
		level.hud.update_display()
		var hud = level.hud
		check(hud.classic.star_indicators.size() == 3,"Classic progress star assets instantiated")
		check(not hud.classic.get_node("Button").visible and not hud.classic.get_node("Results Screen/VBoxContainer/Buttons/Next Level").visible,"No Classic finish/next controls leak")
		check(root.get_visible_rect().encloses(hud.pause_button.get_global_rect()) and root.get_visible_rect().encloses(hud.retry_button.get_global_rect()),"Bottom-right controls fit resolution")
		check(hud.counters.get_global_rect().end.x < 400,"HUD counters remain compact")
		check(not hud.progress.visible and not hud.status.visible and not hud.arrows.visible,"Removed course/status counters stay hidden")
		check(hud.classic.get_node("ProgressBar").size.y <= 14,"Saved progress bar stays slim")
		var hints: Label = hud.camera_icon.get_parent().get_node("ActionHints")
		check(hints.text == "Bark: LMB | Sprint: Shift | Switch view: RMB | Wheel: Zoom", "Exact single-row hint")
		check(hints.get_global_rect().position.x >= 120 and hints.get_global_rect().end.x < hud.pause_button.get_global_rect().position.x,"Hints clear keys and buttons")
		check(root.get_visible_rect().encloses(hud.camera_icon.get_global_rect()),"Camera icon inside safe margin")
		var key_hint: Control = hud.classic.get_node("Control")
		var key_bottom := key_hint.get_global_transform() * Vector2(159,92)
		check(key_bottom.y <= root.get_visible_rect().end.y - 8,"Drawn jump key clears lower safe margin")
		# Captured gameplay uses Esc to reach real GUI controls.
		var esc := InputEventKey.new()
		esc.physical_keycode = KEY_ESCAPE
		esc.pressed = true
		root.push_input(esc,true)
		await process_frame
		check(paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"Esc releases mouse for GUI")
		# Resume button receives the physical click, without barking.
		level.hud.update_display()
		await process_frame
		var at: Vector2 = hud.resume.get_global_rect().get_center()
		var mouse_motion := InputEventMouseMotion.new()
		mouse_motion.position = at
		root.push_input(mouse_motion,true)
		await process_frame
		print("GUI resolution=%s at=%s rect=%s hovered=%s" % [resolution,at,hud.pause_button.get_global_rect(),root.gui_get_hovered_control()])
		for down in [true,false]:
			var click := InputEventMouseButton.new()
			click.position = at
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = down
			root.push_input(click,true)
			await process_frame
		check(not paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and level.dog.bark.cooldown_left == 0,"Real Resume GUI click captures without barking")
		level.toggle_pause()
		level.hud.update_display()
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("DOWNHILL_OUTPUT_DIR").path_join("downhill-v4-ui-%d.png" % resolution.x))
		level.hud.update_display()
		# RMB on a GUI control must not reach the camera gesture.
		var mode: bool = camera.dog_only
		for down in [true,false]:
			var click := InputEventMouseButton.new()
			click.position = at
			click.button_index = MOUSE_BUTTON_RIGHT
			click.pressed = down
			root.push_input(click,true)
			await process_frame
		check(camera.dog_only == mode,"GUI RMB has no camera clickthrough")
		level.toggle_pause()
	level.finish()
	level.hud.update_display()
	level.hud.wind._process(0)
	check(level.hud.wind.intensity == 0,"Results clears screen wind")
	check(level.hud.classic.results_star_container.get_child_count() == 3,"Classic results star assets reused")
	await process_frame
	await process_frame
	for star in level.hud.classic.results_star_container.get_children():
		check(level.hud.modal.get_global_rect().encloses(star.get_global_rect()),"Result star geometry fits inside modal")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("DOWNHILL_OUTPUT_DIR").path_join("downhill-v3-results-ui-960.png"))
	camera._unhandled_input(press)
	camera._unhandled_input(release)
	check(camera.dog_only,"Results RMB cannot change mode")
	level.free()
	print("INTERFACE failures=%d" % failures)
	quit(1 if failures else 0)
