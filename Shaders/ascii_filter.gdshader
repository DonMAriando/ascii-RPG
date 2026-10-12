shader_type canvas_item;
render_mode unshaded;

// Post-proceso ASCII en screen-space.
// Godot 4.7 no permite hint_depth_texture en canvas_item: este ColorRect lee
// la textura de pantalla (color + sombras de la DirectionalLight) y el
// silueteado de profundidad que aporta depth_outline.gdshader.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D ascii_atlas : filter_nearest, repeat_disable;

uniform float cell_px = 10.0;
uniform int glyph_count = 10;
uniform float contrast = 1.22;
uniform float brightness = 0.02;
uniform vec3 background_color = vec3(0.015, 0.02, 0.025);
uniform float edge_boost = 2.8;
uniform float color_boost = 1.28;


float luminance(vec3 color) {
	return dot(color, vec3(0.2126, 0.7152, 0.0722));
}


float sobel_luma(vec2 uv, vec2 pixel_size) {
	float n = luminance(textureLod(screen_tex, uv + vec2(0.0, -pixel_size.y), 0.0).rgb);
	float s = luminance(textureLod(screen_tex, uv + vec2(0.0, pixel_size.y), 0.0).rgb);
	float e = luminance(textureLod(screen_tex, uv + vec2(pixel_size.x, 0.0), 0.0).rgb);
	float w = luminance(textureLod(screen_tex, uv + vec2(-pixel_size.x, 0.0), 0.0).rgb);
	return abs(e - w) + abs(n - s);
}


void fragment() {
	vec2 pixel_size = SCREEN_PIXEL_SIZE;
	vec2 frag_px = SCREEN_UV / pixel_size;
	vec2 cell = vec2(cell_px);
	vec2 cell_origin = floor(frag_px / cell) * cell;
	vec2 cell_center_uv = (cell_origin + cell * 0.5) * pixel_size;

	vec3 accum = vec3(0.0);
	for (int y = 0; y < 3; y++) {
		for (int x = 0; x < 3; x++) {
			vec2 sample_uv = (cell_origin + (vec2(float(x), float(y)) + 0.5) * cell / 3.0) * pixel_size;
			accum += textureLod(screen_tex, sample_uv, 0.0).rgb;
		}
	}

	vec3 avg_color = accum / 9.0;
	float lum = clamp(luminance(avg_color) * contrast + brightness, 0.0, 1.0);
	float edge = clamp(sobel_luma(cell_center_uv, pixel_size) * edge_boost, 0.0, 1.0);
	float density = clamp(lum + edge * 0.4, 0.0, 1.0);

	float max_index = float(max(glyph_count - 1, 1));
	float glyph_index = floor(density * max_index + 0.0001);

	vec2 local_uv = (frag_px - cell_origin) / cell;
	vec2 atlas_uv = vec2((glyph_index + local_uv.x) / float(glyph_count), local_uv.y);
	float glyph = texture(ascii_atlas, atlas_uv).r;

	COLOR = vec4(mix(background_color, avg_color * color_boost, glyph), 1.0);
}
