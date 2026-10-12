shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform vec3 shallow_color : source_color = vec3(0.18, 0.48, 0.58);
uniform vec3 deep_color : source_color = vec3(0.04, 0.16, 0.28);
uniform vec3 foam_color : source_color = vec3(0.95, 0.99, 1.0);
uniform sampler2D ripples : filter_linear, repeat_disable;
uniform float wave_strength = 0.28;
uniform float ripple_normal = 4.2;
uniform float alpha = 0.82;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = texture(ripples, UV).r * 2.0 - 1.0;
	VERTEX.y += h * wave_strength;
}

void fragment() {
	vec2 px = vec2(1.0 / 128.0);
	float h = texture(ripples, UV).r * 2.0 - 1.0;
	float hx = texture(ripples, UV + vec2(px.x, 0.0)).r - texture(ripples, UV - vec2(px.x, 0.0)).r;
	float hz = texture(ripples, UV + vec2(0.0, px.y)).r - texture(ripples, UV - vec2(0.0, px.y)).r;
	NORMAL = normalize(NORMAL + vec3(-hx, 0.0, -hz) * ripple_normal);

	float ambient = sin(world_pos.x * 2.2 + TIME * 1.4) * 0.5 + sin(world_pos.z * 1.7 - TIME * 1.1) * 0.5;
	float depth_mix = clamp(0.45 + ambient * 0.12 + h * 0.25, 0.0, 1.0);
	float foam = smoothstep(0.08, 0.28, abs(h));
	vec3 water = mix(deep_color, shallow_color, depth_mix);
	ALBEDO = mix(water, foam_color, foam);
	ROUGHNESS = mix(0.06, 0.45, foam);
	METALLIC = 0.12;
	ALPHA = mix(alpha, 0.92, foam);
	EMISSION = shallow_color * (0.06 + foam * 0.12);
}
