class_name BoidObstacleSourceWorld
extends BoidObstacleSource
## Bakes obstacles by probing the 3D physics world. Each cell of the obstacle field is tested
## with a small sphere placed above the ground, and cells where it overlaps a collider are
## marked as blocked.

## Physics layers the probe tests against. Colliders on other layers are ignored.
@export_flags_3d_physics var collision_mask := 2
## Radius of the probe sphere, in world units. Larger values catch thinner or more distant
## obstacles but also block cells next to them.
@export_range(0.05, 2.0, 0.05) var probe_radius := 0.25
## Height of the probe above the local ground, in world units. Obstacles lower than this are
## ignored.
@export var probe_height := 0.6


func needs_physics() -> bool:
	return true


## Marks every obstacle field cell whose centre probe overlaps a physics body as blocked.
## Cells that are not over ground are skipped. Needs the physics space to be ready.
func bake_obstacles(system: BoidSystem, field: BoidObstacleField) -> void:
	var space_state := system.get_world_3d().direct_space_state
	if space_state == null:
		push_error("BoidObstacleSourceWorld: no physics space available.")
		return
	var probe_shape := SphereShape3D.new()
	probe_shape.radius = probe_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape_rid = probe_shape.get_rid()
	query.collision_mask = collision_mask
	var blocked_cells := PackedByteArray()
	blocked_cells.resize(field.width * field.depth)
	var any_blocked := false
	for cell_z in field.depth:
		for cell_x in field.width:
			var cell_center := field.origin + (Vector2(cell_x, cell_z) + Vector2(0.5, 0.5)) * field.cell
			if not system.ground.is_over_ground(cell_center):
				continue
			query.transform = Transform3D(Basis(), Vector3(cell_center.x, system.ground.height_at(cell_center) + probe_height, cell_center.y))
			if not space_state.intersect_shape(query, 1).is_empty():
				blocked_cells[cell_z * field.width + cell_x] = 1
				any_blocked = true
	if any_blocked:
		field.add_blocked_cells(blocked_cells)