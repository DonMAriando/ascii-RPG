shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform vec4 liquid : source_color = vec4(0.78, 0.12, 0.18, 1.0);
uniform vec4 liquid_deep : source_color = vec4(0.22, 0.02, 0.06, 1.0);
uniform vec4 glass : source_color = vec4(0.07, 0.08, 0.1, 0.72);
uniform vec4 rim : source_color = vec4(0.86, 0.7, 0.34, 1.0);
uniform vec4 glow : source_color = vec4(1.0, 0.28, 0.2, 0.7);
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform float sparkle : hint_range(0.0, 1.0) = 0.35;
uniform float flash : hint_range(0.0, 1.0) = 0.0;


float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	if (r > 1.12) {
		COLOR = vec4(0.0);
	} else {
	float nfill = clamp(fill, 0.0, 1.0);
	float wave = sin(uv.x * 8.5 + TIME * 2.15) * 0.032 * (0.4 + nfill);
	wave += sin(uv.x * 19.0 - TIME * 1.4) * 0.012;
	float surface = 1.0 - 2.0 * nfill + wave;
	float in_liquid = smoothstep(surface + 0.02, surface - 0.012, uv.y);

	vec3 deep = mix(liquid_deep.rgb, liquid.rgb * 1.15, clamp((1.0 - uv.y) * 0.62, 0.0, 1.0));
	vec3 glass_col = glass.rgb * 0.65;
	vec3 body = mix(glass_col, deep, in_liquid);

	float foam = 1.0 - smoothstep(0.0, 0.045, abs(uv.y - surface));
	body += liquid.rgb * foam * in_liquid * 0.55;

	float caustic = sin((uv.x + uv.y) * 14.0 + TIME * 1.8) * 0.5 + 0.5;
	body += liquid.rgb * caustic * in_liquid * 0.08;

	float bubbles = 0.0;
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		vec2 seed = vec2(fi * 1.7, fi * 3.1);
		float bx = hash(seed) * 1.4 - 0.7;
		float speed = 0.18 + hash(seed + 2.2) * 0.22;
		float by = fract(hash(seed + 4.4) + TIME * speed) * 2.0 - 1.0;
		float br = 0.018 + hash(seed + 8.1) * 0.016;
		bubbles += (1.0 - smoothstep(br * 0.3, br, length(uv - vec2(bx, by)))) * sparkle;
	}
	body += vec3(0.85, 0.95, 1.0) * bubbles * in_liquid * 0.45;

	float sphere = pow(clamp(1.0 - r * r, 0.0, 1.0), 0.55);
	vec2 light_dir = normalize(vec2(-0.35, -0.62));
	float diffuse = clamp(dot(normalize(vec3(uv, sphere)), vec3(light_dir, 0.65)), 0.0, 1.0);
	body *= 0.42 + sphere * 0.7 + diffuse * 0.35;

	vec2 spec_pos = uv - vec2(-0.28, -0.38);
	float spec = exp(-dot(spec_pos, spec_pos) * 18.0);
	body += vec3(1.0) * spec * 0.38;

	float ring = smoothstep(0.08, 0.0, abs(r - 0.86));
	float inner_ring = smoothstep(0.035, 0.0, abs(r - 0.78));
	body = mix(body, rim.rgb, ring * 0.95);
	body = mix(body, rim.rgb * 0.45, inner_ring * 0.55);

	float ticks = 0.0;
	float ang = atan(uv.y, uv.x);
	float spoke = abs(fract((ang / 6.283185 + 0.5) * 12.0) - 0.5);
	ticks = (1.0 - smoothstep(0.04, 0.12, spoke)) * smoothstep(0.08, 0.0, abs(r - 0.93));
	body = mix(body, rim.rgb, ticks * 0.75);

	float pulse_lit = pulse * (0.55 + 0.45 * sin(TIME * 6.5));
	body += glow.rgb * pulse_lit * (0.18 + in_liquid * 0.22);
	body = mix(body, vec3(1.0, 0.92, 0.88), flash * 0.55);

	float inner_alpha = smoothstep(1.0, 0.9, r);
	float halo = smoothstep(1.12, 0.86, r) * (0.22 + pulse_lit * 0.28);
	vec3 halo_col = mix(rim.rgb, glow.rgb, 0.45);
	vec3 out_col = mix(halo_col, body, inner_alpha);
	float alpha = max(inner_alpha * 0.96, halo * glow.a);
	COLOR = vec4(out_col, alpha);
	}
}