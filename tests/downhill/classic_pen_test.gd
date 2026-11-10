extends SceneTree
var failures := 0
var fills := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func run() -> void:
	var level = load("res://scenes/Levels/level_1.tscn").instantiate()
	root.add_child(level)
	await physics_frame
	await physics_frame
	var system: BoidSystem
	var building: PenBuilding
	for node in level.find_children("*", "Node3D", true, false):
		if node is BoidSystem:
			system = node
		if node is PenBuilding:
			building = node
	system.run_simulation = false
	system.tick(1.0/30) # compile vocabulary/state IDs before exercising entry
	var storage := building.storage
	var index := storage.storage_index
	var gate := 0
	for i in system.entrances.size():
		if system.entrances[i].storage == storage:
			gate = i
	storage.filled.connect(func(): fills += 1)
	var left_start := building.left_door.rotation_degrees.y
	var right_start := building.right_door.rotation_degrees.y
	# Use real Classic flock, real authored WALK gate, and capacity reservations.
	var handles: Array[int] = []
	for i in system.store.active_count:
		handles.append(system.store.handle_at(i))
	check(handles.size() == system.storage_capacities[index], "Classic flock matches authored pen capacity")
	var original_state := system.store.state[0]
	for handle in handles:
		system._apply_entry(handle, gate)
	check(fills == 1 and system.storage_boid_counts[index] == handles.size(), "Full signal fires once on reserved capacity")
	check(system.store.state[system.store.slot_of(handles[0])] == system.entering_state_id, "Two-phase entering retained")
	var extra := system.store.add(system.entrance_centers[gate],Vector2.ZERO,0,0,0,original_state)
	system.spawned_total += 1 # fixture addition participates in the system accounting
	system._apply_entry(extra, gate)
	check(system.store.storage_id[system.store.slot_of(extra)] == -1 and fills == 1, "Full pen rejects extra sheep")
	var saw_spot_phase := false
	for frame in 3600:
		system.tick(1.0/30)
		saw_spot_phase = saw_spot_phase or system._entering_phases.has(1)
		if system._entering_handles.is_empty():
			break
	check(saw_spot_phase, "Real walkers pass through center waypoint to final spot phase")
	check(system.store.storage_id[system.store.slot_of(extra)] == -1, "Actual simulation skips full gate for extra sheep")
	var penned := 0
	for handle in handles:
		penned += int(system.store.state[system.store.slot_of(handle)] == system.penned_state_id)
	check(penned == handles.size() and system.storage_boid_counts[index] == handles.size() and system.check_invariants(), "Two-phase arrivals retain capacity and valid state")
	await create_timer(building.swing_delay_seconds + building.swing_seconds + 0.2).timeout
	check(is_equal_approx(building.left_door.rotation_degrees.y,left_start+building.swing_degrees), "Full pen opens actual left door")
	check(is_equal_approx(building.right_door.rotation_degrees.y,right_start-building.swing_degrees), "Full pen opens actual opposite door")
	level.free()
	root.get_node("Global").audio_manager.stop_bgm()
	root.get_node("Global").audio_manager.bgm.stream = null
	# Accelerated arrivals fire star cues faster than realtime. Drain the fixture's
	# persistent autoload SFX players as well as its background player.
	for descriptor in root.get_node("Global").audio_manager.sfx_descriptions:
		descriptor.player.stop()
		descriptor.player.stream = null
	await create_timer(0.3).timeout
	print("CLASSIC PEN failures=%d" % failures)
	quit(1 if failures else 0)
