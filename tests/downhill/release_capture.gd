extends SceneTree
var level: Node3D
var output := ""
func _initialize() -> void:
	call_deferred("run")
func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path := output.path_join("downhill-v4-" + label + ".png")
	var result := root.get_texture().get_image().save_png(path)
	print("CAPTURE %s error=%d" % [path,result])
func run() -> void:
	output = OS.get_environment("DOWNHILL_OUTPUT_DIR")
	root.size = Vector2i(1280,720)
	var menu = load("res://scenes/main_menu/main_menu_3d.tscn").instantiate()
	root.add_child(menu)
	await create_timer(0.3).timeout
	await capture("puzzle-first-menu")
	menu.free()
	level = load("res://scenes/downhill/downhill_level_01.tscn").instantiate()
	root.add_child(level)
	# Ordinary player scene: live ticks, default countdown/camera, no dog driver.
	await create_timer(2.3).timeout
	var camera := root.get_camera_3d()
	for resolution in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = resolution
		root.content_scale_size = resolution
		await process_frame
		level.hud.update_display()
		await capture("dog-hud-%d" % resolution.x)
	camera.dog_only = false
	await create_timer(0.3).timeout
	await capture("herd-icon-960")
	level.update_groups(PackedVector2Array([Vector2.ZERO,Vector2(1,0),Vector2(2,0),Vector2(20,0),Vector2(21,0),Vector2(22,0)]),0.6)
	await capture("split-alert")
	level.free()
	await process_frame
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	for side in [-1,1]:
		level = load("res://scenes/downhill/downhill_level_01.tscn").instantiate()
		level.manual_simulation = true
		level.countdown_seconds = 0
		# Keep a second sheep alive so the gameplay HUD remains in the shot.
		level.flock_count = 2
		level.spawn_center = Vector2(side*15,40)
		level.spawn_size = Vector2(0.001,0.001)
		root.add_child(level)
		camera = root.get_camera_3d()
		camera.set_process(false)
		camera.position = Vector3(side*24,1,33)
		camera.look_at(Vector3(side*18,-3,40))
		level.farewells.set_process(false)
		level.system.store.pos[0].x = side*18.5
		level.simulate_step(0.033)
		level.simulate_step(0.033)
		level.farewells.advance(0.25)
		await capture("tumble-%s" % ("left" if side < 0 else "right"))
		level.free()
		await process_frame
	await create_timer(0.3).timeout
	quit()
