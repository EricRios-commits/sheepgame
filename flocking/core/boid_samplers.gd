class_name BoidSamplers
extends RefCounted


static func disc(rng: RandomNumberGenerator, radius: float) -> Vector2:
	var r := radius * sqrt(rng.randf())
	var a := rng.randf() * TAU
	return Vector2(cos(a), sin(a)) * r

static func ring(rng: RandomNumberGenerator, inner: float, outer: float) -> Vector2:
	var r := sqrt(lerpf(inner * inner, outer * outer, rng.randf()))
	var a := rng.randf() * TAU
	return Vector2(cos(a), sin(a)) * r


static func rect(rng: RandomNumberGenerator, size: Vector2) -> Vector2:
	return Vector2((rng.randf() - 0.5) * size.x, (rng.randf() - 0.5) * size.y)
