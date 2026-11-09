extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func capture_frame(label: String) -> void:
	var directory := OS.get_environment("DOWNHILL_OUTPUT_DIR")
	if directory.is_empty():
		directory = OS.get_user_data_dir().path_join("downhill-captures")
	DirAccess.make_dir_recursive_absolute(directory)
	root.get_texture().get_image().save_png(directory.path_join("downhill-%s.png" % label))

func run() -> void:
	var menu = load("res://scenes/main_menu/main_menu_3d.tscn").instantiate()
	root.add_child(menu)
	var buttons: Array[Node] = menu.find_children("*", "Button", true, false)
	var labels: Array[String] = []
	for button in buttons:
		labels.append(button.text)
	check(labels.has("Downhill Herd") and labels.has("Classic Puzzle"), "Menu exposes both modes")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		capture_frame("menu")
	menu.free()
	# The old standalone main.tscn contains a baseline undefined CapsuleShape
	# override. Leave it intact per contract; normal launch now uses the menu.
	check(FileAccess.file_exists("res://scenes/main.tscn"), "Original sandbox scene retained")
	for path in ["res://scenes/Levels/level_1.tscn", "res://scenes/Levels/level_2.tscn",
		"res://scenes/Levels/level_3.tscn", "res://scenes/Levels/level_4.tscn"]:
		var classic = load(path).instantiate()
		root.add_child(classic)
		await physics_frame
		await physics_frame
		await physics_frame
		var systems: Array[Node] = classic.find_children("*", "BoidSystem", true, false)
		# Find custom script nodes by their actual type (not engine class name).
		if systems.is_empty():
			for node in classic.find_children("*", "Node3D", true, false):
				if node is BoidSystem:
					systems.append(node)
		check(not systems.is_empty(), "Classic BoidSystem loads: " + path)
		for sys in systems:
			check(sys.use_world_bounds, "Classic bounds policy unchanged")
			check(sys.store.count > 0 and sys.check_invariants(), "Classic spawns real flock consistently")
		check(classic.get_viewport().get_camera_3d().projection == Camera3D.PROJECTION_ORTHOGONAL, "Classic camera preserved")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			capture_frame("classic")
		classic.free()
	# Exercise actual scene reload and pause, with old scene references proving cleanup.
	change_scene_to_file("res://scenes/downhill/downhill_level_01.tscn")
	await process_frame
	await process_frame
	var level = current_scene
	level.countdown_left = 0
	level.start_run()
	check(level.dog.speed_for(false) == 5 and level.dog.speed_for(true) == 10, "Dog exact walk/sprint speeds")
	check(level.dog.bark.trigger(), "Bark starts")
	check(level.dog.bark.voice.playing and level.dog.bark.ring.visible, "Bark schedules sound and shows pulse")
	check(not level.dog.bark.trigger(), "Bark cooldown rejects repeated input")
	var ticks: int = level.system.tick_count
	level.toggle_pause()
	for i in 5:
		await physics_frame
	check(level.system.tick_count == ticks and paused, "Pause halts real boid ticks")
	level.toggle_pause()
	for i in 5:
		await physics_frame
	check(level.system.tick_count > ticks and not paused, "Resume restarts real boid ticks")
	var old_emitter: WeakRef = weakref(level.dog.bark)
	level.toggle_pause()
	level.retry()
	await process_frame
	await process_frame
	check(old_emitter.get_ref() == null, "Retry frees old emitter/audio/scene")
	check(not paused, "Retry from pause resumes new scene")
	check(current_scene.initial == 35 and current_scene.saved == 0 and current_scene.lost == 0,
		"Retry starts a fresh population and score")
	var count: int = current_scene.initial
	current_scene.dog.position = Vector3(18, -20, 20)
	current_scene.dog.respawn()
	check(current_scene.dog.position.x == 0 and current_scene.initial == count and current_scene.lost == 0,
		"Dog rescue preserves flock and score")
	current_scene.back_to_menu()
	await process_frame
	await process_frame
	check(not paused and current_scene.scene_file_path.ends_with("main_menu_3d.tscn"), "Menu exit clears pause")
	var classic_button: Button = current_scene.find_children("StartButton", "Button", true, false)[0]
	classic_button.pressed.emit()
	await process_frame
	await process_frame
	check(current_scene.scene_file_path.ends_with("level_1.tscn"), "Classic menu button launches original level")
	var classic_ui: UI = current_scene.find_children("UI", "Control", true, false)[0]
	classic_ui.on_main_menu()
	await process_frame
	await process_frame
	var downhill_button: Button = current_scene.find_children("DownhillButton", "Button", true, false)[0]
	downhill_button.pressed.emit()
	await process_frame
	await process_frame
	check(current_scene.scene_file_path.ends_with("downhill_level_01.tscn"), "Downhill menu button launches new mode")
	# Drain Classic's autoload MP3 playback before engine teardown (Dummy backend).
	root.get_node("Global").audio_manager.stop_bgm()
	root.get_node("Global").audio_manager.bgm.stream = null
	current_scene.free()
	await process_frame
	await process_frame
	await create_timer(0.2).timeout
	print("REGRESSION failures=%d" % failures)
	quit(1 if failures else 0)
