shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 color_a : source_color = vec3(0.20, 0.24, 0.18);
uniform vec3 color_b : source_color = vec3(0.12, 0.15, 0.11);
uniform float roughness_value = 0.82;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float checker = mod(floor(world_pos.x) + floor(world_pos.z), 2.0);
	ALBEDO = mix(color_a, color_b, checker);
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
}
