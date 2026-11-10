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
	root.size = Vector2i(1280, 720)
	var level = load("res://scenes/downhill/downhill_level_01.tscn").instantiate()
	level.manual_simulation = true
	root.add_child(level)
	await physics_frame
	var camera = root.get_camera_3d()
	camera._process(1.0)
	check(camera.pitch <= 0.52, "Default closer camera reveals a mountain horizon")
	var environment: Environment = level.find_children("*", "WorldEnvironment", true, false)[0].environment
	check(environment.fog_sky_affect <= 0.35, "Fog does not erase procedural ridges and clouds")
	var ground: MeshInstance3D = level.find_children("SampledMountainGround", "MeshInstance3D", true, false)[0]
	var scenery := ground.get_parent()
	check(scenery.has_method("valley_height"), "Seeded continuous mountain valley exists beyond cliff strips")
	if scenery.has_method("valley_height"):
		var p := Vector2(Rules.HALF_WIDTH + 8, 40)
		var h: float = scenery.valley_height(p)
		check(h < Rules.terrain_height(p) - 12, "Decorative valley remains below fatal rim")
		check(is_equal_approx(h, scenery.valley_height(p)), "Noise terrain is deterministic")
		var ray := PhysicsRayQueryParameters3D.create(Vector3(p.x, Rules.height(p) + 5, p.y), Vector3(p.x, h - 10, p.y), 1, [level.dog.get_rid()])
		check(level.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "Background valley does not turn falls into safe ground")
	if DisplayServer.get_name() != "headless":
		level.hud.hide()
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var minimum := INF
		var maximum := -INF
		for x in range(100, 1180, 30):
			var color := image.get_pixel(x, 10)
			var brightness := color.r + color.g + color.b
			minimum = minf(minimum, brightness)
			maximum = maxf(maximum, brightness)
		print("SKY horizontal variation=%.4f" % (maximum - minimum))
		check(maximum - minimum > 0.01, "Rendered procedural sky is not a flat fog-colored void")
		var output := OS.get_environment("DOWNHILL_OUTPUT_DIR")
		if not output.is_empty():
			image.save_png(output.path_join("downhill-v3-scenery-proof.png"))
	level.free()
	await process_frame
	print("SCENERY failures=%d renderer=%s" % [failures, DisplayServer.get_name()])
	quit(1 if failures else 0)
