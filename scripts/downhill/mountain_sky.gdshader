shader_type sky;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i), hash(i+vec2(1,0)), f.x), mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x), f.y);
}
void sky() {
	vec3 d = EYEDIR;
	if (AT_CUBEMAP_PASS) {
		COLOR = mix(vec3(0.65, 0.77, 0.82), vec3(0.22, 0.48, 0.65), max(d.y, 0.0));
	} else {
	float az = atan(d.x, d.z);
	vec3 col = mix(vec3(0.83,0.84,0.72), vec3(0.22,0.48,0.65), smoothstep(-0.08,0.8,d.y));
	float ridge = 0.025 + 0.055*sin(az*7.0) + 0.025*sin(az*19.0+2.0);
	col = mix(col, vec3(0.43,0.56,0.61), 1.0-smoothstep(ridge-0.008,ridge+0.008,d.y));
	float near_ridge = -0.06 + 0.05*sin(az*11.0+1.0) + 0.03*sin(az*23.0);
	col = mix(col, vec3(0.32,0.45,0.48), 1.0-smoothstep(near_ridge-0.006,near_ridge+0.006,d.y));
	vec2 uv = d.xz / max(0.15, d.y + 0.2) * 2.8 + vec2(TIME*0.008,0.0);
	float clouds = noise(uv) * 0.6 + noise(uv*2.1) * 0.28 + noise(uv*4.1) * 0.12;
	float cloud = smoothstep(0.5,0.74,clouds) * smoothstep(0.005,0.16,d.y);
	col = mix(col, vec3(1.0,0.94,0.8), cloud*0.8);
	COLOR = col;
	}
}
