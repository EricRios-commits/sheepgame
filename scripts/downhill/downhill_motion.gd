extends RefCounted
## Sidecar keyed by generation-bearing handles. Never modifies packed store arrays.
const Rules = preload("res://scripts/downhill/downhill_rules.gd")
var body_bounds: AABB = preload("res://assets/meshes/sheep_portable.tres").get_aabb()
var level: Node3D
var states: Dictionary = {}
var dog_boost_left := 0.0
var dog_pad := -1
var hoop_hits := 0
var pad_entries := 0
var launch_count := 0

func state(h: int) -> Dictionary:
	if not states.has(h):
		states[h] = {"fear": 0.0, "stacks": 0, "boost": 0.0, "pad": -1, "arc": -1.0, "spin": 0.0, "spin_duration": 0.45, "bounce": 0.0, "previous_bounce": 0.0, "hits": {}, "prev": Vector3.ZERO, "render_prev": Vector3.ZERO, "previous_spin": 0.0, "seen": false}
	return states[h]

func stacks(h: int) -> int:
	return int(states[h].stacks) if states.has(h) else 0

func target_speed(h: int) -> float:
	if level.outcomes.has(h):
		return Rules.CRUISE
	var s := state(h)
	var fear := [1.0, 1.5, 1.75][int(s.stacks)] as float
	return minf(Rules.TARGET_CAP, Rules.CRUISE * fear * (Rules.BOOST if s.boost > 0 else 1.0))

func bark_at(p: Vector2, radius: float) -> void:
	var frightened := false
	for i in level.system.store.active_count:
		if level.outcomes.has(level.system.store.handle_at(i)):
			continue
		var d: Vector2 = level.system.store.pos[i] - p
		if d.length_squared() <= radius * radius and d.y > absf(d.x):
			var s := state(level.system.store.handle_at(i))
			s.stacks = mini(2, s.stacks + 1)
			s.fear = Rules.FEAR_SECONDS
			frightened = true
	level.feedback("Hurry! Fear capped at two" if frightened else "Flank bark: steer inward", &"bleat")

func boost(h: int) -> void:
	state(h).boost = Rules.BOOST_SECONDS

func pulse_impact(p: Vector2, radius: float, hit: Dictionary) -> void:
	for i in level.system.store.active_count:
		var h: int = level.system.store.handle_at(i)
		if not hit.has(h) and not level.outcomes.has(h) and level.system.store.pos[i].distance_to(p) <= radius:
			hit[h] = true
			state(h).bounce = 0.4

func bounce_height(h: int) -> float:
	return bounce_at(states[h].bounce) if states.has(h) else 0.0

static func bounce_at(remaining: float) -> float:
	var t := clampf(remaining / 0.4, 0.0, 1.0)
	return 0.28 * 4 * t * (1-t)

func presentation_bounce(h: int, alpha: float) -> float:
	if not states.has(h):
		return 0.0
	var s: Dictionary = states[h]
	return lerpf(bounce_at(s.previous_bounce), bounce_at(s.bounce), clampf(alpha, 0.0, 1.0))

func height_offset(h: int) -> float:
	var t: float = states[h].arc if states.has(h) else -1.0
	return maxf(0, Rules.RAMP_HEIGHT + 5.0 * t - 6.0 * t * t) if t >= 0 else 0.0

func spin_angle(h: int) -> float:
	var remaining: float = states[h].spin if states.has(h) else 0.0
	return TAU * (1.0 - remaining / state(h).spin_duration) if remaining > 0 else 0.0

func world_position(h: int, p: Vector2) -> Vector3:
	# Render XZ can still interpolate over the ramp on the first airborne frame.
	# The launch arc already contains the lip height: never add the wedge twice.
	var airborne := states.has(h) and float(states[h].arc) >= 0
	var ground := Rules.terrain_height(p) if airborne else Rules.height(p)
	return Vector3(p.x, ground + height_offset(h), p.y)

func presentation_height(h: int, p: Vector2, alpha: float) -> float:
	if not states.has(h) or not states[h].seen:
		return Rules.height(p)
	var s: Dictionary = states[h]
	return lerpf(s.render_prev.y, s.prev.y, clampf(alpha, 0, 1))

func presentation_spin(h: int, alpha: float) -> float:
	if not states.has(h):
		return 0.0
	var s: Dictionary = states[h]
	var previous: float = s.previous_spin
	var before: float = TAU * (1.0 - previous / s.spin_duration) if previous > 0 else 0.0
	# A completed full turn is TAU, not a backwards interpolation toward zero.
	var after := spin_angle(h) if s.spin > 0 else (TAU if previous > 0 else 0.0)
	return lerpf(before, after, clampf(alpha, 0, 1))

static func hoop_pass(a: Vector3, b: Vector3, center: Vector3, radius: float) -> bool:
	if a.z >= center.z or b.z < center.z or b.z <= a.z:
		return false
	var at := a.lerp(b, (center.z - a.z) / (b.z - a.z))
	return Vector2(at.x - center.x, at.y - center.y).length_squared() <= radius * radius

func pad_at(p: Vector2) -> int:
	for j in Rules.PADS.size():
		if absf(p.x - Rules.PADS[j].x) <= 4 and absf(p.y - Rules.PADS[j].y) <= 3:
			return j
	return -1

func advance(dt: float) -> void:
	dog_boost_left = maxf(0, dog_boost_left - dt)
	var dp := Vector2(level.dog.position.x, level.dog.position.z)
	var new_pad := pad_at(dp)
	if new_pad >= 0 and new_pad != dog_pad:
		dog_boost_left = Rules.BOOST_SECONDS
		level.feedback("BOOST!", &"pad")
	dog_pad = new_pad
	for i in level.system.store.active_count:
		var h: int = level.system.store.handle_at(i)
		if level.outcomes.has(h):
			continue
		var s := state(h)
		var p: Vector2 = level.system.store.pos[i]
		s.render_prev = s.prev
		s.previous_spin = s.spin
		s.previous_bounce = s.bounce
		s.fear = maxf(0, s.fear - dt)
		if s.fear <= 0:
			s.stacks = 0
		s.boost = maxf(0, s.boost - dt)
		s.bounce = maxf(0, s.bounce - dt)
		s.spin = maxf(0, s.spin - dt)
		if s.arc >= 0:
			s.arc += dt
			if height_offset(h) <= 0:
				s.arc = -1.0
		var pad := pad_at(p)
		if pad >= 0 and pad != s.pad:
			boost(h)
			pad_entries += 1
			level.feedback("Herd boost!", &"pad")
		s.pad = pad
		for start in Rules.RAMP_STARTS:
			var lip: float = start + 6
			if s.seen and s.prev.z <= lip and p.y > lip and absf(p.x) < Rules.RAMP_HALF_WIDTH:
				s.arc = (p.y - lip) / maxf(1, level.system.store.speed[i])
				launch_count += 1
		var world := world_position(h, p)
		if s.seen:
			check_hoops(h, s.prev, world)
		else:
			s.render_prev = world
		s.prev = world
		s.seen = true

func remove(h: int) -> void:
	states.erase(h)

func check_hoops(h: int, a: Vector3, b: Vector3) -> void:
	var s := state(h)
	if s.arc < 0:
		return
	for j in Rules.HOOPS.size():
		var hoop: Vector3 = Rules.HOOPS[j]
		hoop.y += Rules.terrain_height(Vector2(hoop.x, hoop.z))
		# +Z is the mesh's length axis. Test its leading body at the plane,
		# then verify circular clearance using the swept body center height.
		var slot: int = level.system.store.slot_of(h)
		var heading: float = level.system.store.heading[slot] if slot >= 0 else 0.0
		var leading := maxf(body_bounds.position.z*cos(heading),body_bounds.end.z*cos(heading)) + absf(sin(heading))*body_bounds.size.x*0.5
		var body_offset := Vector3(0,body_bounds.get_center().y,leading)
		if not s.hits.has(j) and hoop_pass(a + body_offset, b + body_offset, hoop, 2.1):
			s.hits[j] = true
			s.spin_duration = clampf(1.1-s.arc,0.12,0.45)
			s.spin = s.spin_duration - 0.001
			hoop_hits += 1
			level.effects.burst(Vector3(b.x,b.y+body_bounds.get_center().y,hoop.z))
			level.feedback("HOOP! Barrel roll", &"hoop")
