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
	level.spawn_center = Vector2(0,43)
	level.spawn_size = Vector2(0.001,0.001)
	root.add_child(level)
	check(is_equal_approx(Rules.BOOST, 1.6), "Punchy 1.6x pad tuning")
	var stripes := 0
	for node in level.get_node("Track").get_children():
		if node is MeshInstance3D and node.mesh is BoxMesh and is_equal_approx(node.mesh.size.x, 2.3):
			stripes += 1
			var inner: Vector3 = node.transform * Vector3(-signf(node.position.x - Rules.PADS[level.motion.pad_at(Vector2(node.position.x,node.position.z))].x) * 1.15,0,0)
			var outer: Vector3 = node.transform * Vector3(signf(node.position.x - Rules.PADS[level.motion.pad_at(Vector2(node.position.x,node.position.z))].x) * 1.15,0,0)
			check(inner.z > outer.z, "Actual chevron inner tip points +Z")
	check(stripes == 24, "Every authored arrow exercised")
	var h: int = level.system.store.handle_at(0)
	for i in 15:
		level.simulate_step(1.0/30)
	check(level.system.store.speed[0] > 9.8, "Normal boosted sheep accelerates materially within 0.5s")
	check(is_equal_approx(level.dog.speed_for(false),7),"Unboosted dog remains walk7")
	level.motion.dog_boost_left = 2
	check(is_equal_approx(level.dog.speed_for(false),11.2) and is_equal_approx(level.dog.speed_for(true),22.4),"Both boosted dog speeds materially stronger, ratio 1:2")
	var barn: Node3D = level.get_node("Track/GroundedBarn")
	var bounds: AABB = level.get_node("Track").mesh_bounds(barn)
	var world: AABB = barn.transform*bounds
	for x in [world.position.x,world.end.x]:
		for z in [world.position.z,world.end.z]:
			check(world.position.y >= Rules.height(Vector2(x,z)),"Transformed barn base clears sampled footprint ground")
	print("BARN world bounds=%s" % world)
	level.free()
	print("POLISH failures=%d" % failures)
	quit(1 if failures else 0)
