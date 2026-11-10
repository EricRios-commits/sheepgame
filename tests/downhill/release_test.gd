extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void:
	call_deferred("run")
func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
func click_control(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion,true)
	await process_frame
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event,true)
		await process_frame
func run() -> void:
	var quiet = load("res://scenes/downhill/downhill_level_01.tscn").instantiate()
	quiet.manual_simulation = true
	root.add_child(quiet)
	check(not quiet.music.playing, "Fast manual fixtures do not start asynchronous MP3 playback")
	quiet.free()
	await process_frame
	var menu = load("res://scenes/main_menu/main_menu_3d.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	var start = menu.find_child("StartButton", true, false)
	check(start.text == "Puzzle Game" and start.has_focus(), "Puzzle is primary and focused")
	check(root.get_node("Global").audio_manager.bgm.playing, "Latest main title-screen music is retained")
	check(start.get_parent().get_child(1).text == "Downhill Challenge", "Downhill is second")
	key(KEY_ENTER)
	await process_frame
	var enter_release := InputEventKey.new()
	enter_release.keycode = KEY_ENTER
	enter_release.physical_keycode = KEY_ENTER
	enter_release.pressed = false
	root.push_input(enter_release,true)
	await process_frame
	await process_frame
	check(current_scene.scene_file_path.ends_with("level_1.tscn"), "Real keyboard Enter launches Puzzle")
	current_scene.free()
	var level = load("res://scenes/downhill/downhill_level_01.tscn").instantiate()
	level.manual_simulation = true
	level.fixture_audio = true
	level.countdown_seconds = 0
	root.add_child(level)
	current_scene = level
	await process_frame
	var camera = root.get_camera_3d()
	check(camera.dog_only, "Dog-only default")
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Gameplay captures cursor")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(500, 0)
	root.push_input(motion, true)
	check(absf(camera.yaw) > 0.8, "No-button look rotates beyond old yaw limit")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	root.push_input(click, true)
	check(not camera.dog_only, "RMB press switches view")
	click.pressed = false
	root.push_input(click, true)
	check(not camera.dog_only, "RMB release does not switch twice")
	key(KEY_ESCAPE)
	check(paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Esc pauses and releases")
	key(KEY_ESCAPE)
	check(not paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Explicit resume captures")
	level._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and level.music.stream_paused, "Focus loss pauses/releases cursor and audio")
	level._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Focus return never silently recaptures")
	var safe_mode: bool = camera.dog_only
	click.pressed = true
	root.push_input(click, true)
	check(camera.dog_only == safe_mode and level.dog.bark.cooldown_left == 0, "Reacquisition click cannot toggle or bark")
	key(KEY_ESCAPE)
	check(not paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not level.music.stream_paused, "Explicit focus resume restores music and capture")
	check(level.get("music") != null, "Scoped music player exists")
	if level.get("music") != null:
		check(level.music.playing and level.music.stream != null, "Actual background audio playing with Dummy backend")
	check(level.hud.counters.text == "Saved 0/35", "Only Saved counter remains")
	check(level.hud.get("camera_icon") != null, "Pictorial camera indicator exists")
	level.update_groups(PackedVector2Array([Vector2.ZERO,Vector2(1,0),Vector2(2,0),Vector2(20,0),Vector2(21,0),Vector2(22,0)]), 0.6)
	check(level.notice == "HERD SPLIT!" and level.notice_left > 0, "Brief joined-to-split alert")
	level.notice_left = 0
	level.update_groups(PackedVector2Array([Vector2.ZERO,Vector2(1,0),Vector2(2,0),Vector2(20,0),Vector2(21,0),Vector2(22,0)]), 1)
	check(level.notice_left == 0, "Continuing split cannot retrigger alert")
	level.update_groups(PackedVector2Array([Vector2.ZERO,Vector2(1,0),Vector2(2,0)]), 0.6)
	level.update_groups(PackedVector2Array([Vector2.ZERO,Vector2(1,0),Vector2(2,0),Vector2(20,0),Vector2(21,0),Vector2(22,0)]), 0.6)
	check(level.notice_left > 0, "Rejoin rearms split alert")
	level.finish()
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Results releases cursor")
	check(not level.music.playing, "Results stops background music")
	var old_music: WeakRef = weakref(level.music)
	var old_ghosts: WeakRef = weakref(level.farewells)
	level.hud.update_display()
	check(level.hud.title.is_visible_in_tree(), "Zero-save downhill results keep their mode-specific heading after main UI update")
	await process_frame
	await click_control(level.hud.classic.get_node("Results Screen/VBoxContainer/Buttons/Restart Level"))
	await process_frame
	check(old_music.get_ref() == null and old_ghosts.get_ref() == null, "Real GUI retry frees music and ghost batch")
	check(current_scene.phase == current_scene.Phase.COUNTDOWN and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and current_scene.music.playing, "Real GUI retry resets countdown/camera/music/capture")
	key(KEY_ESCAPE)
	current_scene.hud.update_display()
	await process_frame
	var retry_music: WeakRef = weakref(current_scene.music)
	await click_control(current_scene.hud.classic.get_node("Results Screen/VBoxContainer/Buttons/Main Menu"))
	await process_frame

	check(current_scene.scene_file_path.ends_with("main_menu_3d.tscn") and retry_music.get_ref() == null and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Real GUI menu exit releases cursor and frees owned music")
	current_scene.free()
	check(not root.get_node("Global").audio_manager.bgm.playing
		and root.get_node("Global").audio_manager.bgm.stream == null,
		"Leaving the title screen releases its owned global music stream")
	await process_frame
	await create_timer(0.3).timeout
	print("RELEASE failures=%d" % failures)
	quit(1 if failures else 0)
