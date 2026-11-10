extends Node3D
## Generated once. Visual cliffs have no collision: running off the rim is fatal.
const Rules = preload("res://scripts/downhill/downhill_rules.gd")
var track: Node3D
var valley_noise := FastNoiseLite.new()

func _init() -> void:
	valley_noise.seed = 67231
	valley_noise.frequency = 0.009
	valley_noise.fractal_octaves = 4

func valley_height(p: Vector2) -> float:
	var distance := maxf(0, absf(p.x) - Rules.HALF_WIDTH)
	var drop := 32.0 * (1.0 - exp(-distance / 8.0))
	var noise_height := 0.5 + 0.5 * valley_noise.get_noise_2d(p.x, p.y)
	var massif := smoothstep(26, 140, distance) * (30 + 55 * noise_height)
	return Rules.terrain_height(p) - drop + massif

func build_valley() -> void:
	# Continuous seeded landforms provide depth/parallax below the real cliff.
	# Deliberately no collider or BoidGround coverage: falling is still a loss.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		for z in range(-120, 720, 10):
			for distance in range(0, 288, 8):
				var x: float = side * (Rules.HALF_WIDTH + distance)
				var a := Vector2(x, z)
				var b := Vector2(x + side * 8, z)
				var c := Vector2(x, z + 10)
				var d := Vector2(x + side * 8, z + 10)
				var points := [a, b, c, b, d, c] if side > 0 else [a, c, b, b, c, d]
				for p in points:
					var y := valley_height(p)
					var ridge := smoothstep(-18, 25, y - Rules.terrain_height(p))
					surface.set_color(Color("344c3c").lerp(Color("899080"), ridge))
					surface.add_vertex(Vector3(p.x, y, p.y))
	surface.index()
	surface.generate_normals()
	var material: StandardMaterial3D = track.material(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.set_material(material)
	var terrain := MeshInstance3D.new()
	terrain.name = "ProceduralValley"
	terrain.mesh = surface.commit()
	add_child(terrain)

func vertex(p: Vector2, ramp := false) -> Vector3:
	return Vector3(p.x, Rules.height(p) if ramp else Rules.terrain_height(p), p.y)

func build(owner_track: Node3D) -> void:
	track = owner_track
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-12, 324):
		for x in range(-int(Rules.HALF_WIDTH), int(Rules.HALF_WIDTH)):
			var a := vertex(Vector2(x, z))
			var b := vertex(Vector2(x + 1, z))
			var c := vertex(Vector2(x, z + 1))
			var d := vertex(Vector2(x + 1, z + 1))
			for v in [a, b, c, b, d, c]:
				var shade := 0.035 * sin(v.z * 0.11 + sin(v.x * 0.17))
				var path := 1.0 - smoothstep(4, 10, absf(v.x - 1.5 * sin(v.z * 0.027)))
				surface.set_color(Color(0.27 + shade, 0.38 + shade, 0.19 + shade).lerp(Color(0.48 + shade, 0.46 + shade, 0.28 + shade), path * 0.7))
				surface.add_vertex(v)
	surface.index()
	surface.generate_normals()
	var mat: StandardMaterial3D = track.material(Color.WHITE)
	mat.vertex_color_use_as_albedo = true
	surface.set_material(mat)
	var ground_mesh := surface.commit()
	var ground := MeshInstance3D.new()
	ground.name = "SampledMountainGround"
	ground.mesh = ground_mesh
	add_child(ground)
	ground.create_trimesh_collision()
	# A separate wedge leaves a real launch lip rather than smoothing it flat.
	var ramp := SurfaceTool.new()
	ramp.begin(Mesh.PRIMITIVE_TRIANGLES)
	for start in Rules.RAMP_STARTS:
		for z in range(int(start), int(start + 6)):
			for x in range(-int(Rules.RAMP_HALF_WIDTH), int(Rules.RAMP_HALF_WIDTH)):
				for p in [Vector2(x,z), Vector2(x+1,z), Vector2(x,z+1), Vector2(x+1,z), Vector2(x+1,z+1), Vector2(x,z+1)]:
					ramp.add_vertex(vertex(p, true))
	ramp.generate_normals()
	ramp.set_material(track.material(Color("cb9253")))
	var launch := MeshInstance3D.new()
	launch.name = "LaunchRamp"
	launch.mesh = ramp.commit()
	add_child(launch)
	launch.create_trimesh_collision()
	for p in Rules.PADS:
		var pad: MeshInstance3D = track.box(Vector3(8, 0.1, 6), vertex(p) + Vector3.UP * 0.1, Color("287f91"))
		pad.rotation.x = 0.087
		for z in [-1.5, 0.0, 1.5]:
			for side in [-1, 1]:
				var stripe: MeshInstance3D = track.box(Vector3(2.3, 0.06, 0.35), vertex(p + Vector2(side * 0.8, z)) + Vector3.UP * 0.22, Color("8dffe7"))
				stripe.rotation.y = side * 0.55
				var glow := stripe.material_override as StandardMaterial3D
				glow.emission_enabled = true
				glow.emission = Color("4fdfca")
	for h in Rules.HOOPS:
		var hoop := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 2.6
		torus.outer_radius = 2.85
		torus.rings = 48
		torus.ring_segments = 8
		hoop.mesh = torus
		hoop.position = h + Vector3.UP * Rules.terrain_height(Vector2(h.x, h.z))
		hoop.rotation.x = PI / 2
		hoop.material_override = track.material(Color("ffcc55"))
		add_child(hoop)
	# Cliff strips follow the actual rim; far scenery remains well below it.
	var cliffs := SurfaceTool.new()
	cliffs.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1, 1]:
		for z in range(-12, 324, 4):
			var a := vertex(Vector2(side * Rules.HALF_WIDTH, z))
			var b := vertex(Vector2(side * Rules.HALF_WIDTH, z + 4))
			var c := a + Vector3(side * 6, -32, 0)
			var d := b + Vector3(side * 6, -32, 0)
			for v in [a,b,c,b,d,c,c,b,a,c,d,b]:
				cliffs.add_vertex(v)
	cliffs.generate_normals()
	cliffs.set_material(track.material(Color("6e7263")))
	var cliff_mesh := MeshInstance3D.new()
	cliff_mesh.mesh = cliffs.commit()
	add_child(cliff_mesh)
	build_valley()
	seeded_details()

func batch(mesh: Mesh, color: Color, poses: Array[Transform3D], label: String) -> void:
	var inst := MultiMeshInstance3D.new()
	inst.name = label
	inst.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	inst.multimesh = MultiMesh.new()
	inst.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	inst.multimesh.mesh = mesh
	inst.multimesh.instance_count = poses.size()
	inst.material_override = track.material(color)
	for i in poses.size():
		inst.multimesh.set_instance_transform(i, poses[i])
	add_child(inst)

func seeded_details() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 67231
	var mountains: Array[Transform3D] = []
	var trees: Array[Transform3D] = []
	var stones: Array[Transform3D] = []
	var grass: Array[Transform3D] = []
	for i in 38:
		var side := -1 if i % 2 else 1
		var x := side * rng.randf_range(110, 280)
		var z := rng.randf_range(-80, 650)
		var scale := Vector3(rng.randf_range(65, 110), rng.randf_range(35, 65), rng.randf_range(65, 115))
		mountains.append(Transform3D(Basis.IDENTITY.scaled(scale), Vector3(x, -95 - z * 0.07, z)))
	for i in 180:
		var x := (-1 if i % 2 else 1) * rng.randf_range(24, 37)
		var z := rng.randf_range(-10, 330)
		var size := rng.randf_range(2, 4)
		var p := Vector3(x, valley_height(Vector2(x,z)) + size * 1.8, z)
		trees.append(Transform3D(Basis.IDENTITY.scaled(Vector3(size, size * 1.8, size)), p))
	for i in 1100:
		var x := (-1 if i % 2 else 1) * rng.randf_range(15.8, 17.6)
		var z := rng.randf_range(-10, 320)
		var size := rng.randf_range(0.15, 0.4)
		var p := vertex(Vector2(x,z)) + Vector3.UP * size * 0.3
		var pose := Transform3D(Basis.IDENTITY.scaled(Vector3(size, size * 1.4, size)), p)
		if i % 4 == 0:
			stones.append(pose)
		else:
			grass.append(pose)
	var cone := CylinderMesh.new()
	cone.top_radius = 0
	cone.bottom_radius = 1
	cone.height = 2
	cone.radial_segments = 7
	batch(cone, Color("68796f"), mountains, "MountainParallax")
	# Replaceable placeholder canopy mesh, outside the running lanes and below rim.
	batch(cone, Color("315b44"), trees, "ReplaceablePines")
	var pebble := SphereMesh.new()
	pebble.radial_segments = 6
	pebble.rings = 3
	batch(pebble, Color("a6a08a"), stones, "RimPebbles")
	batch(cone, Color("91a05b"), grass, "RimGrass")
