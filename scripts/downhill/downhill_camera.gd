extends Camera3D

const DEFAULT_PITCH := 0.46
var level: Node3D
var focus := Vector3.ZERO
var initialized := false
var yaw := 0.0
var pitch := DEFAULT_PITCH
var zoom := 18.0
var dog_only := true
var desired_distance := 18.0

func _ready() -> void:
	current = true
	fov = 70.0
	far = 900.0
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

func _process(delta: float) -> void:
	if level == null or level.dog == null or get_tree().paused:
		return
	if level.phase == level.Phase.RESULTS and initialized:
		return
	var dog: Vector3 = level.dog.global_position
	var herd: Vector3 = level.flock_center()
	# Bound a detached actor's influence, keeping the main flock readable.
	var offset := (dog - herd).limit_length(28.0)
	var target := herd + offset * 0.35 + Vector3(0, 1.2, 6)
	if dog_only:
		target = dog + Vector3(0,1.2,3)
	if not initialized:
		focus = target
	focus = focus.lerp(target, 1 - exp(-6 * delta))
	var spread: float = level.flock_extent(herd)
	var distance := clampf(zoom + maxf(0, maxf(spread, offset.length()) - 7) * 0.75, 12, 36)
	if dog_only:
		distance = zoom
	desired_distance = distance
	var desired := focus + Vector3(sin(yaw) * distance, tan(pitch) * distance, -cos(yaw) * distance)
	# Stay above the analytic terrain and solid camera obstructions.
	desired.y = maxf(desired.y, level.system.ground.height_at(Vector2(desired.x, desired.z)) + 5)
	var query := PhysicsRayQueryParameters3D.create(focus + Vector3.UP * 2, desired, 1, [level.dog.get_rid()])
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		desired = hit.position + hit.normal * 0.6
	var proposed := global_position.lerp(desired, 1 - exp(-7 * delta)) if initialized else desired
	# Damping must not carry the lens through an obstruction when yaw changes.
	query.to = proposed
	hit = space.intersect_ray(query)
	if not hit.is_empty():
		proposed = hit.position + hit.normal * 0.6
	proposed.y = maxf(proposed.y, level.system.ground.height_at(Vector2(proposed.x,proposed.z)) + 0.8)
	global_position = proposed
	look_at(focus)
	initialized = true

func reset_view() -> void:
	yaw = 0
	pitch = DEFAULT_PITCH
	zoom = 18
	initialized = false

func orbit(relative: Vector2) -> void:
	yaw = wrapf(yaw - relative.x * 0.004, -PI, PI)
	pitch = clampf(pitch + relative.y * 0.003, 0.4, 0.95)

func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or level.phase == level.Phase.RESULTS or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		orbit(event.relative)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			dog_only = not dog_only
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = clampf(zoom - 2, 12, 32)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = clampf(zoom + 2, 12, 32)
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_C:
		reset_view()
