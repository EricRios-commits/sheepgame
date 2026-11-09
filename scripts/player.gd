extends CharacterBody3D

@export_range(0.1, 20.0, 0.1) var move_speed: float = 3.5
@export_range(0.1, 50.0, 0.1) var acceleration: float = 18.0
@export_range(0.1, 30.0, 0.1) var turn_speed: float = 12.0
@export_range(1.0, 15.0, 0.1) var jump_speed: float = 5.0

@export_range(0.1, 2.0, 0.05) var hop_duration: float = 0.25
@export_range(0.0, 0.5, 0.01) var hop_height: float = 0.2
@export_range(0.0, 0.3, 0.01) var hop_sideways: float = 0.12
@export_range(0.0, 30.0, 1.0) var hop_roll_degrees: float = 13.0

var _model: Node3D
var _dog: Node3D
var _hop_time := 0.0
var _hop_blend := 0.0
var _jump_requested := false

# Passthrough
@export var boid_system: BoidSystem = null
@export var boid_emitter: BoidEmitter
@export var initial_camera_spin: float = -90.0

func _ready() -> void:
	_model = get_node_or_null("Visuals") as Node3D
	_dog = get_node_or_null("Visuals/DogModel") as Node3D
	var camera_tilt = get_node("CameraPivot/CameraTilt") as Node3D
	camera_tilt.rotation.y = (initial_camera_spin / 180) * PI
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
	var speed_multiplier := 1
	if Input.is_physical_key_pressed(KEY_A):
		input_direction.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		input_direction.x += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		input_direction.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		input_direction.y += 1.0
	if Input.is_physical_key_pressed(KEY_SHIFT):
		speed_multiplier = 2
		
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

	velocity.x = move_toward(velocity.x, move_direction.x * move_speed * speed_multiplier, acceleration * delta)
	velocity.z = move_toward(velocity.z, move_direction.z * move_speed * speed_multiplier, acceleration * delta)
	if is_on_floor():
		velocity.y = jump_speed if _jump_requested else -0.1
	else:
		velocity.y -= 9.8 * delta
	_jump_requested = false
	move_and_slide()

	if _model and move_direction.length_squared() > 0.0:
		var facing := atan2(move_direction.x, move_direction.z)
		_model.rotation.y = lerp_angle(_model.rotation.y, facing, minf(turn_speed * delta, 1.0))

	# Roll around the dog's forward (lengthwise) axis, with alternating hops.
	# The visual offset never affects collisions or the direction of travel.
	if _dog:
		var moving := Vector2(velocity.x, velocity.z).length() > 0.1
		var target_blend := 1.0 if is_on_floor() and moving else 0.0
		_hop_blend = move_toward(_hop_blend, target_blend, delta * 8.0)
		if target_blend > 0.0:
			_hop_time = fposmod(_hop_time + delta, hop_duration * 2.0)
		var hop_phase := _hop_time / hop_duration
		var progress := fposmod(hop_phase, 1.0)
		var side := 1.0 if hop_phase < 1.0 else -1.0
		# A parabolic arc has a brisk takeoff and a decisive landing.
		var arc := 4.0 * progress * (1.0 - progress)
		_dog.position.x = side * arc * hop_sideways * _hop_blend
		_dog.position.y = arc * hop_height * _hop_blend
		_dog.rotation.z = side * arc * deg_to_rad(hop_roll_degrees) * _hop_blend
