extends RefCounted
## Mode-only tuning. Classic resources never reference these rules.
const CRUISE := 7.0
const SPRINT := CRUISE * 2.0
const HALF_WIDTH := 18.0
const FEAR_SECONDS := 3.0
const BOOST_SECONDS := 2.0
const BOOST := 1.6
const TARGET_CAP := 12.6
const SPEED_CAP := 13.0
const RAMP_START := 98.0
const RAMP_END := 104.0
const RAMP_HEIGHT := 1.8
const RAMP_HALF_WIDTH := 6.0
const RAMP_STARTS := [98.0, 258.0]
const PADS := [Vector2(0, 43), Vector2(-8, 181), Vector2(8, 181), Vector2(0, 248)]
const HOOPS := [Vector3(0, 3.3, 110), Vector3(0, 3.3, 270)]

static func terrain_height(p: Vector2) -> float:
	return -p.y * 0.0874886635 + 0.45 * sin(p.y * 0.065) + 0.3 * sin(p.x * 0.17 + p.y * 0.035) + p.x * 0.018 * sin(p.y * 0.04)

static func ramp_height(p: Vector2) -> float:
	for start in RAMP_STARTS:
		if absf(p.x) <= RAMP_HALF_WIDTH and p.y >= start and p.y <= start + 6:
			return RAMP_HEIGHT * (p.y - start) / 6
	return 0.0

static func height(p: Vector2) -> float:
	return terrain_height(p) + ramp_height(p)
