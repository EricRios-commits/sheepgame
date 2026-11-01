extends CharacterBody3D

@export_range(0.1, 20.0, 0.1) var move_speed: float = 3.5
@export_range(0.1, 50.0, 0.1) var acceleration: float = 18.0
@export_range(0.1, 30.0, 0.1) var turn_speed: float = 12.0
@export_range(1.0, 15.0, 0.1) var jump_speed: float = 5.0

var _model: Node3D
var _jump_requested := false

# Passthrough
@export var boid_system: BoidSystem = null
@export var boid_emitter: BoidEmitter

func _ready() -> void:
	_model = get_node_or_null("goose2") as Node3D
	if boid_system != null: 
		# By default the emitter cannot have a reference to the system because it's outside the scene of the player
		boid_emitter.system = boid_system
		# so we force a restart on the boid manually
		boid_emitter._ready()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.physical_keycode == KEY_SPACE and key_event.pressed and not key_event.echo:
			_jump_requested = true
			get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	var input_direction := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A):
		input_direction.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		input_direction.x += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		input_direction.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		input_direction.y += 1.0
	input_direction = input_direction.normalized()

	var move_direction := Vector3.ZERO
	var camera := get_viewport().get_camera_3d()
	if camera:
		var camera_right := camera.global_basis.x
		var camera_forward := -camera.global_basis.z
		camera_right.y = 0.0
		camera_forward.y = 0.0
		move_direction = (camera_right.normalized() * input_direction.x
			- camera_forward.normalized() * input_direction.y).normalized()

	velocity.x = move_toward(velocity.x, move_direction.x * move_speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, move_direction.z * move_speed, acceleration * delta)
	if is_on_floor():
		velocity.y = jump_speed if _jump_requested else 0.0
	else:
		velocity.y -= 9.8 * delta
	_jump_requested = false
	move_and_slide()

	if _model and move_direction.length_squared() > 0.0:
		var facing := atan2(move_direction.x, move_direction.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, facing, minf(turn_speed * delta, 1.0))
