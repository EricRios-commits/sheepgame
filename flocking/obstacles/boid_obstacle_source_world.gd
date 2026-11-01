class_name BoidObstacleSourceWorld
extends BoidObstacleSource

@export_flags_3d_physics var collision_mask := 2
@export_range(0.05, 2.0, 0.05) var probe_radius := 0.25
## Height of the probe above the local ground. Obstacles lower than this are ignored.
@export var probe_height := 0.6


func needs_physics() -> bool:
	return true


func bake_obstacles(sys: BoidSystem, field: BoidObstacleField) -> void:
	var state := sys.get_world_3d().direct_space_state
	if state == null:
		push_error("BoidObstacleSourceWorld: no physics space available.")
		return
	var shape := SphereShape3D.new()
	shape.radius = probe_radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape_rid = shape.get_rid()
	q.collision_mask = collision_mask
	var blocked := PackedByteArray()
	blocked.resize(field.width * field.depth)
	var any := false
	for iz in field.depth:
		for ix in field.width:
			var p := field.origin + (Vector2(ix, iz) + Vector2(0.5, 0.5)) * field.cell
			if not sys.ground.is_over_ground(p):
				continue
			q.transform = Transform3D(Basis(), Vector3(p.x, sys.ground.height_at(p) + probe_height, p.y))
			if not state.intersect_shape(q, 1).is_empty():
				blocked[iz * field.width + ix] = 1
				any = true
	if any:
		field.add_blocked_cells(blocked)