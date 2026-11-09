extends SceneTree
## Rendered edge-death proof using ordinary scene ticks, not store overrides.

var level: Node3D
var deaths := 0
var output := ""
var captured_start := false
var finishing := false

func _initialize() -> void:
	call_deferred("start")

func start() -> void:
	output = OS.get_environment("DOWNHILL_OUTPUT_DIR")
	if output.is_empty():
		output = OS.get_user_data_dir().path_join("downhill-captures")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	level = load("res://scenes/downhill/downhill_level_01.tscn").instantiate()
	level.flock_count = 1
	level.spawn_center = Vector2(11.8, 20)
	level.spawn_size = Vector2(0.001, 0.001)
	level.spawn_heading = 90.0
	root.add_child(level)
	current_scene = level
	level.system.boid_died.connect(func(_species: int, _at: Vector2): deaths += 1)

func _process(_delta: float) -> bool:
	if level == null or finishing:
		return false
	if not captured_start and level.countdown_left < 1.5:
		captured_start = true
		capture.call_deferred("before")
	if level.phase == level.Phase.RESULTS:
		finishing = true
		finish.call_deferred()
	return false

func capture(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("downhill-fall-%s.png" % label))

func finish() -> void:
	await create_timer(0.3).timeout
	await capture("after")
	var ok: bool = deaths == 1 and level.lost == 1 and level.saved == 0 and level.remaining() == 0 and level.system.store.count == 0
	print("FALL_DEMO passed=%s deaths=%d saved=%d lost=%d remaining=%d store=%d" % [ok, deaths, level.saved, level.lost, level.remaining(), level.system.store.count])
	level.free()
	quit(0 if ok else 1)
