extends Camera3D

var level: Node3D
var focus := Vector3.ZERO
var initialized := false

func _ready() -> void:
	current = true
	fov = 62.0
	far = 450.0
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
	var target := herd + offset * 0.35 + Vector3(0, 1.2, 10)
	if not initialized:
		focus = target
	focus = focus.lerp(target, 1 - exp(-6 * delta))
	var spread: float = level.flock_extent(herd)
	var distance := clampf(27 + maxf(spread, offset.length()) * 0.4, 27, 44)
	var desired := focus + Vector3(0, distance * 1.15, -distance)
	# Stay above the analytic terrain and solid camera obstructions.
	desired.y = maxf(desired.y, level.system.ground.height_at(Vector2(desired.x, desired.z)) + 9)
	var query := PhysicsRayQueryParameters3D.create(focus + Vector3.UP * 2, desired, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		desired.y = maxf(desired.y, hit.position.y + 10)
	global_position = global_position.lerp(desired, 1 - exp(-7 * delta)) if initialized else desired
	look_at(focus)
	initialized = true
