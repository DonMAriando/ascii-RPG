shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 grass_a : source_color = vec3(0.22, 0.38, 0.16);
uniform vec3 grass_b : source_color = vec3(0.14, 0.26, 0.11);
uniform vec3 dirt : source_color = vec3(0.28, 0.22, 0.14);
uniform float roughness_value = 0.9;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float n = sin(p.x * 0.35) * cos(p.y * 0.28) + sin(p.x * 1.1 + p.y * 0.7) * 0.35;
	float patch = smoothstep(-0.15, 0.35, n);
	vec3 grass = mix(grass_a, grass_b, fract(sin(dot(floor(p * 0.5), vec2(12.9898, 78.233))) * 43758.5453));
	ALBEDO = mix(dirt, grass, patch);
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
}
