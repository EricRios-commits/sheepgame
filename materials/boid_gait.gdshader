shader_type spatial;
// INSTANCE_CUSTOM.x = speed (m/s)
// INSTANCE_CUSTOM.y = gait phase (sin() handles negatives)
// INSTANCE_CUSTOM.z = per-boid random 0..1
// INSTANCE_CUSTOM.w = state id (unused here. Could be used to choose state anim)

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;

uniform float speed_for_full_gait = 2.0;
uniform float sway = 0.10;
uniform float pitch = 0.05;
uniform float bob = 0.05;
uniform float breath = 0.012;

void vertex() {
	float spd = INSTANCE_CUSTOM.x;
	float a = INSTANCE_CUSTOM.y * TAU;
	float k = clamp(spd / speed_for_full_gait, 0.0, 1.0);
	float h = max(VERTEX.y, 0.0);

	VERTEX.x += sin(a) * sway * k * h;
	VERTEX.z += sin(a * 2.0) * pitch * k * h;
	VERTEX.y += (0.5 - 0.5 * cos(a * 2.0)) * bob * k;
	VERTEX.y += sin(TIME * 2.0 + INSTANCE_CUSTOM.z * TAU) * breath * h * (1.0 - k);
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = albedo.rgb * tex.rgb;
	ROUGHNESS = roughness;
}
