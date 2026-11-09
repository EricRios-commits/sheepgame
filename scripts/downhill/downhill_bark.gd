extends BoidEmitter

@export var duration := 0.3
@export var cooldown := 0.7
var cooldown_left := 0.0
var pulse_left := 0.0
var ring: MeshInstance3D
var voice: AudioStreamPlayer3D

func _ready() -> void:
	kind = &"bark"
	radius = 7.0
	strength = 30.0
	active = false
	super._ready()
	ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.94
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 6
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("ffe392")
	mat.emission_enabled = true
	mat.emission = Color("ffd377")
	ring.material_override = mat
	ring.position.y = 0.3
	ring.visible = false
	add_child(ring)
	voice = AudioStreamPlayer3D.new()
	voice.max_distance = 100.0
	voice.volume_db = -6
	voice.stream = make_bark()
	add_child(voice)

func trigger() -> bool:
	if cooldown_left > 0.0:
		return false
	cooldown_left = cooldown
	pulse_left = duration
	active = true
	ring.visible = true
	voice.play()
	return true

func advance(delta: float) -> void:
	cooldown_left = maxf(0, cooldown_left - delta)
	pulse_left = maxf(0, pulse_left - delta)
	active = pulse_left > 0.0
	ring.visible = active
	if active:
		var size := lerpf(0.6, radius, 1.0 - pulse_left / duration)
		ring.scale = Vector3(size, 1, size)

func cancel() -> void:
	active = false
	pulse_left = 0.0
	ring.visible = false
	voice.stop()

func make_bark() -> AudioStreamWAV:
	# Two short, rough voiced bursts. Generated locally; no new audio dependency.
	var bytes := PackedByteArray()
	var rate := 22050
	var rng := RandomNumberGenerator.new()
	rng.seed = 27
	for i in int(rate * 0.26):
		var t := float(i) / rate
		var local_t := fmod(t, 0.13)
		var envelope := sin(PI * minf(local_t / 0.105, 1.0)) * exp(-local_t * 14)
		var wave := sin(TAU * (160 * t - 100 * t * t)) * 0.6 + rng.randf_range(-0.4, 0.4)
		var value := int(clampf(wave * envelope, -1, 1) * 24000)
		bytes.append(value & 255)
		bytes.append((value >> 8) & 255)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	return stream
