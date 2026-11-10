extends MultiMeshInstance3D
## One capped batch for animal boost wakes and short contact sparkles.
const CAPACITY := 384
var level: Node3D
var sparks: Array[Dictionary] = []
var clock := 0.0
var burst_cooldown := 0.0
var visible_trails := 0
func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	var mesh := SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	mesh.radial_segments = 6
	mesh.rings = 3
	multimesh.mesh = mesh
	multimesh.instance_count = CAPACITY
	multimesh.visible_instance_count = 0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.emission_enabled = true
	mat.emission = Color("62dfdc")
	mat.emission_energy_multiplier = 0.6
	material_override = mat
func burst(at: Vector3) -> void:
	if burst_cooldown > 0:
		return
	burst_cooldown = 0.06
	for i in 16:
		if sparks.size() >= 128:
			break
		var angle := i * TAU / 16
		sparks.append({"p":at,"v":Vector3(cos(angle)*2,sin(angle)*2,0.7*sin(i*2.4)),"left":0.45})
func advance(dt: float) -> void:
	clock += dt
	burst_cooldown = maxf(0,burst_cooldown-dt)
	var count := 0
	visible_trails = 0
	for h in level.motion.states:
		var s: Dictionary = level.motion.states[h]
		if s.boost <= 0 or not s.seen:
			continue
		for side in [-1,1]:
			var p: Vector3 = s.prev + Vector3(side*0.35,0.4,-0.65)
			multimesh.set_instance_transform(count,Transform3D(Basis.IDENTITY.scaled(Vector3(0.8,0.8,7+2*sin(clock*25+h))),p))
			multimesh.set_instance_color(count,Color("70fff0"))
			count += 1
			visible_trails += 1
	for i in range(sparks.size()-1,-1,-1):
		sparks[i].left -= dt
		if sparks[i].left <= 0:
			sparks.remove_at(i)
			continue
		sparks[i].p += sparks[i].v*dt
		var sparkle_basis := Basis(Vector3.BACK,clock*8+i).scaled(Vector3(0.8,2.5,0.8)*(sparks[i].left/0.45))
		multimesh.set_instance_transform(count,Transform3D(sparkle_basis,sparks[i].p))
		multimesh.set_instance_color(count,Color("ffdf72"))
		count += 1
	multimesh.visible_instance_count = count
func clear() -> void:
	sparks.clear()
	multimesh.visible_instance_count = 0
	visible_trails = 0
