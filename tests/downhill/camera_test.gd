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
	var level = load("res://scenes/downhill/downhill_level_01.tscn").instantiate()
	level.manual_simulation = true
	root.add_child(level)
	await physics_frame
	var camera = root.get_camera_3d()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	camera._unhandled_input(press)
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_RIGHT
	drag.relative = Vector2(-10000, 10000)
	camera._unhandled_input(drag)
	check(absf(camera.yaw) > 0.8 and camera.pitch == 0.95, "Mouse look wraps full yaw and clamps pitch")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	for i in 30:
		camera._unhandled_input(wheel)
	check(camera.zoom == 12, "Wheel zoom clamps")
	var reset := InputEventKey.new()
	reset.physical_keycode = KEY_C
	reset.pressed = true
	camera._unhandled_input(reset)
	check(camera.zoom == 18 and camera.yaw == 0 and camera.pitch == camera.DEFAULT_PITCH, "C resets camera")
	camera.orbit(Vector2(-100, 0))
	camera._process(1)
	var right: Vector3 = camera.global_basis.x
	for i in 20:
		await physics_frame
		level.dog.move_with_input(Vector2(1,0), false, 1.0 / 60)
	check(level.dog.velocity.dot(right) > 6, "D follows actual orbit camera right")
	for p in [Vector2(-16,30), Vector2(16,80), Vector2(0,101), Vector2(0,261)]:
		var y := Rules.height(p)
		var query := PhysicsRayQueryParameters3D.create(Vector3(p.x,y+5,p.y), Vector3(p.x,y-3,p.y), 1, [level.dog.get_rid()])
		var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and absf(hit.position.y - y) < 0.02, "Dog collision matches analytic ground/ramp at %s" % p)
	for child in level.system.get_children():
		if child is BoidPresenter:
			child._capture(false)
			for batch in child._active + child._frozen:
				check(batch.inst.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF, "Actual batch engine interpolation disabled")
	# A tall obstruction on the orbit ray must never remain between dog and lens.
	camera.reset_view()
	camera._process(1)
	var blocker := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8,40,2)
	shape.shape = box
	blocker.add_child(shape)
	blocker.position = camera.focus + Vector3(0,5,-8)
	level.add_child(blocker)
	await physics_frame
	camera._process(1)
	var sight := PhysicsRayQueryParameters3D.create(camera.focus+Vector3.UP*2,camera.global_position,1,[level.dog.get_rid()])
	check(level.get_world_3d().direct_space_state.intersect_ray(sight).is_empty(), "Tall obstacle cannot occlude camera after orbit correction")
	level.free()
	print("CAMERA failures=%d rendered=%s" % [failures, DisplayServer.get_name()])
	quit(1 if failures else 0)
