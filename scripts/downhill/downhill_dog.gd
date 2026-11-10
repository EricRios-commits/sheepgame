extends CharacterBody3D

const Rules = preload("res://scripts/downhill/downhill_rules.gd")
const WALK_SPEED := Rules.CRUISE
var enabled := false
var level: Node3D
var bark: BoidEmitter
var visual: Node3D
var model: Node3D
var safe_z := 6.0
var respawns := 0
var hop_clock := 0.0
var hop_blend := 0.0
var bark_hop_left := 0.0

func _ready() -> void:
	floor_snap_length = 0.6
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.2
	collision.shape = capsule
	collision.position.y = 0.6
	add_child(collision)
	visual = Node3D.new()
	add_child(visual)
	model = load("res://assets/dog/german_shepherd.glb").instantiate()
	model.scale = Vector3.ONE * 1.4
	visual.add_child(model)

func _physics_process(delta: float) -> void:
	if not enabled:
		return
	var direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S)))
	move_with_input(direction, Input.is_physical_key_pressed(KEY_SHIFT), delta,
		Input.is_physical_key_pressed(KEY_SPACE))
	if Input.is_physical_key_pressed(KEY_E):
		bark.trigger()

func _unhandled_input(event: InputEvent) -> void:
	if enabled and not get_tree().paused and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		bark.trigger()

func bark_hop() -> void:
	bark_hop_left = 0.3

func animate_gait(delta: float, moving: bool, grounded: bool, speed: float) -> void:
	hop_blend = move_toward(hop_blend,1.0 if moving and grounded else 0.0,delta*8)
	if moving and grounded:
		hop_clock = fposmod(hop_clock+delta*clampf(speed/7,0.5,2.5),0.5)
	var phase := hop_clock/0.25
	var t := fposmod(phase,1)
	var side := 1.0 if phase < 1 else -1.0
	var arc := 4*t*(1-t)*hop_blend
	bark_hop_left = maxf(0,bark_hop_left-delta)
	var bt := bark_hop_left/0.3
	model.position = Vector3(side*arc*0.12,arc*0.2+0.18*4*bt*(1-bt),0)
	model.rotation.z = side*arc*deg_to_rad(13)

func speed_for(sprint: bool) -> float:
	return WALK_SPEED * (2.0 if sprint else 1.0) * (Rules.BOOST if level.motion.dog_boost_left > 0 else 1.0)

func move_with_input(input: Vector2, sprint: bool, delta: float, jump := false) -> void:
	var camera := get_viewport().get_camera_3d()
	var right := camera.global_basis.x if camera else Vector3.LEFT
	var forward := -camera.global_basis.z if camera else Vector3.BACK
	right.y = 0
	forward.y = 0
	var direction := (right.normalized() * input.x + forward.normalized() * input.y).limit_length()
	velocity.x = direction.x * speed_for(sprint)
	velocity.z = direction.z * speed_for(sprint)
	velocity.y = 5.0 if jump and is_on_floor() else velocity.y - 18.0 * delta
	move_and_slide()
	if direction.length_squared() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), 1 - exp(-12 * delta))
	animate_gait(delta,direction.length_squared()>0.01,is_on_floor(),speed_for(sprint))
	if absf(position.x) < Rules.HALF_WIDTH - 1.5 and is_on_floor():
		safe_z = clampf(position.z, 0, 295)
	if position.y < level.system.ground.height_at(Vector2(position.x, position.z)) - 5.0 or position.z < -15:
		respawn()

func respawn() -> void:
	respawns += 1
	var z := safe_z
	# A fallback lets the player recover even after the herd has run far ahead.
	z = maxf(z, minf(level.flock_center().z - 12.0, 292.0))
	position = level.rescue_position(z)
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	bark.cancel()
	level.notice = "Dog rescued! Sprint to catch the herd."
	level.notice_left = 3.0
