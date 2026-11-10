extends Node3D
const Rules = preload("res://scripts/downhill/downhill_rules.gd")
const SCENERY = preload("res://scripts/downhill/downhill_scenery.gd")
## Fixed authored footprints, shared by dog collision and boid obstacle baking.

const ROCKS := [Vector3(-7, 76, 2.4), Vector3(0, 145, 6.0),
	Vector3(8.0, 220, 3.8), Vector3(-8.0, 239, 4.2)]

func build(system: BoidSystem) -> void:
	var scenery := SCENERY.new()
	add_child(scenery)
	scenery.build(self)
	for side in [-1.0, 1.0]:
		# Rim markings are visual only: sheep and dog can leave the edge.
		for z in range(0, 301, 20):
			box(Vector3(0.22, 1.5, 0.22), Vector3(side * (Rules.HALF_WIDTH - 0.2), Rules.height(Vector2(side * Rules.HALF_WIDTH, z)) + 0.7, z), Color("f4dfaa"))
	for rock in ROCKS:
		var obstacle := BoidObstacle.new()
		obstacle.system = system
		obstacle.radius = rock.z
		obstacle.position = Vector3(rock.x, Rules.height(Vector2(rock.x, rock.y)), rock.y)
		add_child(obstacle)
		var body := StaticBody3D.new()
		body.position = obstacle.position
		add_child(body)
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = rock.z
		cylinder.height = 6.0
		shape.shape = cylinder
		shape.position.y = 1.2
		body.add_child(shape)
		var mesh := MeshInstance3D.new()
		var stone := SphereMesh.new()
		stone.radius = rock.z
		stone.height = rock.z * 1.6
		stone.radial_segments = 9
		stone.rings = 4
		mesh.mesh = stone
		mesh.position.y = 0.6
		mesh.material_override = material(Color("777981"))
		body.add_child(mesh)
	# Broad capture mouth and a recognizable farm building beyond the gate.
	var barn = load("res://assets/environment/farmbuilding_f_004.tscn").instantiate()
	barn.name = "GroundedBarn"
	barn.position = Vector3(0, 0, 314)
	# Preserve the imported handedness; assigning positive scale flips this asset.
	barn.basis = Basis(Vector3.UP,PI * 1.5) * barn.basis.scaled(Vector3.ONE * 2.2)
	add_child(barn)
	ground_barn(barn)
	for z in [20.0, 65.0, 130.0, 208.0, 282.0]:
		var sign_label := Label3D.new()
		sign_label.text = "BARN  %dm" % (300 - z)
		if z == 20:
			sign_label.text = "SPRINT TO A FLANK\nBARK TO STEER"
		if z == 130:
			sign_label.text = "TWO PATHS\nONE HERD"
		sign_label.position = Vector3(-7.8, -z * 0.0874886635 + 3.5, z)
		sign_label.rotation.y = PI
		sign_label.font_size = 40
		sign_label.pixel_size = 0.018
		add_child(sign_label)

func mesh_bounds(node: Node3D, relative: Transform3D = Transform3D.IDENTITY) -> AABB:
	var bounds := AABB()
	var first := true
	for child in node.get_children():
		if child is Node3D:
			var pose: Transform3D = relative * child.transform
			if child is MeshInstance3D:
				var box: AABB = pose * child.mesh.get_aabb()
				bounds = box if first else bounds.merge(box)
				first = false
			var nested := mesh_bounds(child, pose)
			if nested.size != Vector3.ZERO:
				bounds = nested if first else bounds.merge(nested)
				first = false
	return bounds

func ground_barn(barn: Node3D) -> void:
	# Transform the asset's real mesh bounds, including nested authoring transforms.
	var bounds := barn.transform * mesh_bounds(barn)
	var top := -INF
	var low := INF
	for x in [bounds.position.x, bounds.get_center().x, bounds.end.x]:
		for z in [bounds.position.z, bounds.get_center().z, bounds.end.z]:
			var y := Rules.terrain_height(Vector2(x,z))
			top = maxf(top,y)
			low = minf(low,y)
	var base := top + 0.12
	barn.position.y += base - bounds.position.y
	barn.set_meta("footprint", AABB(Vector3(bounds.position.x,base,bounds.position.z), bounds.size))
	# A grounded foundation closes the downhill gap; an approach bridges to the gate.
	box(Vector3(bounds.size.x + 0.5, base-low+0.3, bounds.size.z+0.5), Vector3(bounds.get_center().x, (base+low-0.3)*0.5, bounds.get_center().z), Color("8b8872"))
	var approach := SurfaceTool.new()
	approach.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(297,ceili(bounds.position.z)):
		for x in range(-17,18):
			for p in [Vector2(x,z),Vector2(x+1,z),Vector2(x,z+1),Vector2(x+1,z),Vector2(x+1,z+1),Vector2(x,z+1)]:
				var end_z := minf(p.y,bounds.position.z)
				var t := clampf(inverse_lerp(301,bounds.position.z,end_z),0,1)
				var px: float = p.x * lerpf(1.0,(bounds.size.x*0.5+0.3)/18.0,t)
				var y := maxf(Rules.height(Vector2(px,end_z))+0.14,lerpf(Rules.height(Vector2(px,301))+0.14,base+0.02,t))
				approach.set_color(Color("f3d37a") if end_z <= 301 else Color("c1b58a"))
				approach.add_vertex(Vector3(px,y,end_z))
	approach.generate_normals()
	var path_material := material(Color.WHITE)
	path_material.vertex_color_use_as_albedo = true
	approach.set_material(path_material)
	var path := MeshInstance3D.new()
	path.name = "BarnApproach"
	path.mesh = approach.commit()
	add_child(path)

func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	return mat

func box(size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material(color)
	node.position = at
	add_child(node)
	return node

func solid_box(size: Vector3, at: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	add_child(body)
	var mesh := box(size, Vector3.ZERO, color)
	mesh.reparent(body, false)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body
