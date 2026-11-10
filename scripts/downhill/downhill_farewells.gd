extends MultiMeshInstance3D
## Cosmetic only. Never owns a boid or participates in collision or scoring.
const CAPACITY := 100
const DURATION := 0.7
var ghosts: Array[Dictionary] = []
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var visual = preload("res://assets/boids_resources/sheep_visual.tres")
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = visual.mesh
	multimesh.instance_count = CAPACITY
	multimesh.visible_instance_count = 0
	var material := StandardMaterial3D.new()
	material.albedo_texture = visual.material.get_shader_parameter("albedo_texture")
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.9
	material_override = material
func snapshot(handle: int, species: int, pose: Transform3D, outward: Vector3) -> void:
	if ghosts.size() >= CAPACITY:
		return
	# Rotation about mesh LENGTH local Z. Project outward onto the posed local X:
	# local up rotates towards -X for positive roll.
	var roll_sign := -signf(pose.basis.x.dot(outward))
	if roll_sign == 0:
		roll_sign = 1
	ghosts.append({"handle": handle, "species": species, "pose": pose, "outward": outward,
		"sign": roll_sign, "age": 0.0})
	_upload()
func _process(delta: float) -> void:
	if not get_tree().paused:
		advance(delta)
func advance(delta: float) -> void:
	for i in range(ghosts.size() - 1, -1, -1):
		ghosts[i].age += delta
		if ghosts[i].age >= DURATION:
			ghosts.remove_at(i)
	_upload()
func _upload() -> void:
	var center := multimesh.mesh.get_aabb().get_center()
	for i in ghosts.size():
		var ghost := ghosts[i]
		var age: float = ghost.age
		var pose: Transform3D = ghost.pose
		var basis := pose.basis * Basis(Vector3.BACK, ghost.sign * age / DURATION * 2.8)
		var origin := pose.origin + pose.basis * center - basis * center
		origin += ghost.outward * age * 2.0 + Vector3.DOWN * (age * 0.6 + age * age * 6)
		multimesh.set_instance_transform(i, Transform3D(basis, origin))
		multimesh.set_instance_color(i, Color(1,1,1,clampf((DURATION-age)/0.25,0,1)))
	multimesh.visible_instance_count = ghosts.size()
func clear() -> void:
	ghosts.clear()
	multimesh.visible_instance_count = 0

func _exit_tree() -> void:
	clear()
	# Release instance buffers while the rendering server is still running.
	multimesh.instance_count = 0
	multimesh = null
	material_override = null
