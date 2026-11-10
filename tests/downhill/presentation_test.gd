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
	level.countdown_seconds = 0
	level.flock_count = 1
	level.spawn_center = Vector2(0, 96)
	level.spawn_size = Vector2(0.001, 0.001)
	root.add_child(level)
	var dog_xz := Vector2(level.dog.position.x, level.dog.position.z)
	check(absf(level.dog.position.y - Rules.height(dog_xz)) < 0.12, "Countdown dog starts grounded rather than hovering")
	var presenter: Node3D
	for child in level.system.get_children():
		if child is BoidPresenter:
			presenter = child
	var h: int = level.system.store.handle_at(0)
	var tested_height := false
	var tested_spin := false
	for i in 150:
		var old_position: Vector3 = level.motion.world_position(h, level.system.store.pos[0])
		var old_spin: float = level.motion.spin_angle(h)
		level.simulate_step(1.0 / 30.0)
		var new_position: Vector3 = level.motion.world_position(h, level.system.store.pos[0])
		presenter._write_region(0, 1, presenter._active_bufs, 0.0, false)
		var start: PackedFloat32Array = presenter._active_bufs[0].duplicate()
		presenter._write_region(0, 1, presenter._active_bufs, 1.0, false)
		var end: PackedFloat32Array = presenter._active_bufs[0].duplicate()
		if not tested_height and level.motion.height_offset(h) > 1.0 and new_position.y - old_position.y > 0.05:
			tested_height = true
			check(absf(start[7] - old_position.y) < 0.02 and absf(end[7] - new_position.y) < 0.02, "Uploaded launch pose interpolates previous and current physical heights")
		var new_spin: float = level.motion.spin_angle(h)
		if not tested_spin and old_spin > 0.1 and new_spin > old_spin and new_spin < 5.5:
			tested_spin = true
			var old_basis := Basis(Vector3(start[0], start[4], start[8]), Vector3(start[1], start[5], start[9]), Vector3(start[2], start[6], start[10]))
			var new_basis := Basis(Vector3(end[0], end[4], end[8]), Vector3(end[1], end[5], end[9]), Vector3(end[2], end[6], end[10]))
			check(old_basis.orthonormalized().get_rotation_quaternion().angle_to(new_basis.orthonormalized().get_rotation_quaternion()) > 0.1, "Somersault pose interpolates across render frames rather than stepping at 30 Hz")
	check(tested_height and tested_spin, "Natural authored jump and hoop reached by interpolation test")
	# Bark bounce must interpolate too, without presentation creating lifecycle state.
	level.motion.state(h).bounce = 0.4
	level.simulate_step(1.0 / 30.0)
	presenter._write_region(0, 1, presenter._active_bufs, 0.0, false)
	var bounce_start: PackedFloat32Array = presenter._active_bufs[0].duplicate()
	presenter._write_region(0, 1, presenter._active_bufs, 1.0, false)
	var bounce_end: PackedFloat32Array = presenter._active_bufs[0].duplicate()
	var p: Vector2 = level.system.store.pos[0]
	check(absf(bounce_start[7] - level.motion.presentation_height(h, p, 0.0)) < 0.001, "Bark hop begins at previous rendered bounce height, not next tick's height")
	check(bounce_end[7] - level.motion.presentation_height(h, p, 1.0) > 0.05, "Bark hop advances across render interpolation endpoints")
	level.motion.remove(h)
	presenter._write_region(0, 1, presenter._active_bufs, 1.0, false)
	check(not level.motion.states.has(h), "Presentation reads cannot recreate removed stable-handle state")
	level.free()
	level = load("res://scenes/downhill/downhill_level_01.tscn").instantiate()
	level.manual_simulation = true
	level.countdown_seconds = 0
	level.flock_count = 1
	level.spawn_center = Vector2(0, 297)
	level.spawn_size = Vector2(0.001, 0.001)
	root.add_child(level)
	for i in 100:
		level.simulate_step(1.0 / 30.0)
	for child in level.system.get_children():
		if child is BoidPresenter:
			child._process(0.0)
	check(level.saved == 1 and level.motion.states.is_empty(), "Rendering saved sheep cannot resurrect cleaned motion state")
	level.free()
	print("PRESENTATION failures=%d" % failures)
	quit(1 if failures else 0)
