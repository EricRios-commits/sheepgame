extends Node3D
## Fixed authored footprints, shared by dog collision and boid obstacle baking.

const ROCKS := [Vector3(-4, 76, 2.4), Vector3(0, 145, 4.3),
	Vector3(5.8, 220, 2.5), Vector3(-5.0, 239, 2.6)]

func build(system: BoidSystem) -> void:
	var terrain := solid_box(Vector3(24, 2.5, 338), Vector3(0, -16.0, 156), Color("526c3b"))
	terrain.rotation.x = deg_to_rad(5)
	# Top surface passes through y=-tan(5 degrees)*z.
	terrain.position.y = -156.0 * 0.0874886635 - 1.25 / cos(deg_to_rad(5))
	for side in [-1.0, 1.0]:
		var rim := box(Vector3(0.3, 0.12, 338), Vector3(side * 11.85, -13.65, 156), Color("d7b879"))
		rim.rotation.x = deg_to_rad(5)
		# Rim markings are visual only: sheep and dog can leave the edge.
		for z in range(0, 301, 20):
			box(Vector3(0.22, 1.5, 0.22), Vector3(side * 11.8, -z * 0.0874886635 + 0.7, z), Color("f4dfaa"))
	for rock in ROCKS:
		var obstacle := BoidObstacle.new()
		obstacle.system = system
		obstacle.radius = rock.z
		obstacle.position = Vector3(rock.x, -rock.y * 0.0874886635, rock.y)
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
	box(Vector3(23, 0.15, 5), Vector3(0, -26.25, 300), Color("f3d37a"))
	var barn = load("res://assets/environment/farmbuilding_f_004.tscn").instantiate()
	barn.position = Vector3(0, -27.3, 314)
	barn.scale = Vector3(2.2, 2.2, 2.2)
	add_child(barn)
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
