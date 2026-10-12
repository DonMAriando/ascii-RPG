shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 fill_color : source_color = vec4(0.035, 0.04, 0.05, 0.78);
uniform vec4 edge_color : source_color = vec4(0.82, 0.66, 0.3, 0.95);
uniform float edge_width : hint_range(0.004, 0.08) = 0.018;


void fragment() {
	vec2 uv = UV;
	float e = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float border = 1.0 - smoothstep(edge_width * 0.45, edge_width, e);
	vec2 from_corner = min(uv, 1.0 - uv);
	float corner = 1.0 - smoothstep(0.045, 0.09, length(from_corner - vec2(0.012)));
	float grain = fract(sin(dot(uv * vec2(240.0, 180.0), vec2(12.9898, 78.233))) * 43758.5453);
	vec3 col = fill_color.rgb + vec3(grain * 0.03);
	col = mix(col, edge_color.rgb, max(border, corner * 0.85));
	float alpha = max(fill_color.a, max(border, corner) * edge_color.a);
	COLOR = vec4(col, alpha);
}