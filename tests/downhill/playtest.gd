extends SceneTree
## Rendered, reproducible full-course driver and profiler. Not a human playtest.
## --script res://tests/downhill/playtest.gd -- 35 (or 100)

var level: Node3D
var frame_ms: Array[float] = []
var last_frame := 0
var sampled_seconds := 0.0
var draw_calls := 0.0
var captures: Dictionary = {}
var output := ""
var started := false
var finishing := false
var camera_samples := 0
var dog_visible_samples := 0
var flock_visible_fraction := 0.0
var camera_clock := 0.0

func _initialize() -> void:
	call_deferred("start")

func start() -> void:
	var directory := OS.get_environment("DOWNHILL_OUTPUT_DIR")
	if directory.is_empty():
		directory = OS.get_user_data_dir().path_join("downhill-captures")
	DirAccess.make_dir_recursive_absolute(directory)
	output = directory.path_join("downhill")
	root.size = Vector2i(1280, 720)
	level = load("res://scenes/downhill/downhill_level_01.tscn").instantiate()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		level.flock_count = clampi(int(args[0]), 1, 100)
	root.add_child(level)
	current_scene = level
	print("HARDWARE CPU=%s GPU=%s renderer=%s sheep=%d" % [OS.get_processor_name(),
		RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_method(), level.initial])
	last_frame = Time.get_ticks_usec()
	started = true

func _physics_process(delta: float) -> bool:
	if not started or finishing or level.phase != level.Phase.RUNNING:
		return false
	# Move a real CharacterBody dog; no sheep position/velocity overrides.
	level.dog.enabled = false
	var center: Vector3 = level.flock_center()
	var target := Vector2(center.x, center.z - 7.0)
	if center.z > 170 and center.z < 217:
		target.x = 9.0
		target.y = center.z + 3.0
	var at := Vector2(level.dog.position.x, level.dog.position.z)
	var direction := target - at
	if direction.length() < 0.2:
		direction = Vector2.ZERO
	else:
		direction = direction.normalized()
	# Camera looks along +Z, so its screen-right is world -X.
	level.dog.move_with_input(Vector2(-direction.x, direction.y), at.distance_to(target) > 3, delta)
	if center.z > 190 and center.z < 217 and absf(at.x - 9) < 0.3:
		level.dog.bark.trigger()
	return false

func _process(delta: float) -> bool:
	if not started or finishing:
		return false
	var now := Time.get_ticks_usec()
	var ms := (now - last_frame) / 1000.0
	last_frame = now
	if level.elapsed > 3 and level.phase == level.Phase.RUNNING:
		frame_ms.append(ms)
		sampled_seconds += ms / 1000
		draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		camera_clock += delta
		if camera_clock >= 0.25:
			camera_clock = 0.0
			var camera := root.get_camera_3d()
			var viewport := root.get_visible_rect()
			camera_samples += 1
			var dog_world: Vector3 = level.dog.global_position + Vector3.UP * 0.6
			if not camera.is_position_behind(dog_world) and viewport.has_point(camera.unproject_position(dog_world)):
				dog_visible_samples += 1
			var visible := 0
			var positions: PackedVector2Array = level.living_positions()
			for p in positions:
				var world := Vector3(p.x, level.system.ground.height_at(p) + 0.5, p.y)
				if not camera.is_position_behind(world) and viewport.has_point(camera.unproject_position(world)):
					visible += 1
			flock_visible_fraction += float(visible) / maxi(1, positions.size())
	var capture := ""
	if level.elapsed > 2 and not captures.has("start"):
		capture = "start"
	elif level.split and level.flock_center().z > 138 and not captures.has("split"):
		capture = "split"
	elif level.flock_center().z > 198 and level.dog.bark.active and not captures.has("bark"):
		capture = "bark"
	elif level.phase == level.Phase.RESULTS and not captures.has("results"):
		capture = "results"
	if capture != "":
		captures[capture] = true
		capture_frame.call_deferred(capture)
	if level.phase == level.Phase.RESULTS:
		finishing = true
		end_run.call_deferred()
	return false

func capture_frame(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("%s-%d-%s.png" % [output, level.initial, label])
	print("CAPTURE %s error=%d" % [label, error])

func end_run() -> void:
	await process_frame
	await process_frame
	frame_ms.sort()
	if not frame_ms.is_empty():
		var slow_count := maxi(1, ceili(frame_ms.size() * 0.01))
		var slow_sum := 0.0
		for i in range(frame_ms.size() - slow_count, frame_ms.size()):
			slow_sum += frame_ms[i]
		print("PROFILE frames=%d wall_s=%.2f fps=%.2f one_percent_low_fps=%.2f p99_ms=%.2f max_ms=%.2f draw_calls_avg=%.1f" % [
			frame_ms.size(), sampled_seconds, frame_ms.size() / sampled_seconds, 1000 * slow_count / slow_sum,
			frame_ms[int((frame_ms.size() - 1) * 0.99)], frame_ms.back(), draw_calls / frame_ms.size()])
	print("PLAYTEST saved=%d lost=%d elapsed=%.2f split=%s reunited=%s dog_rescues=%d" % [level.saved,
		level.lost, level.elapsed, level.ever_split, level.reunited, level.dog.respawns])
	print("CAMERA samples=%d dog_visible_pct=%.2f flock_visible_pct=%.2f" % [camera_samples,
		100.0 * dog_visible_samples / maxi(1, camera_samples),
		100.0 * flock_visible_fraction / maxi(1, camera_samples)])
	print(level.system.stage_timer.summary())
	level.free()
	quit()
