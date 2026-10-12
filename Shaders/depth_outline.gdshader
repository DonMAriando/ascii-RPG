shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled, blend_mix;

// Lee el Depth Buffer 3D (solo disponible en shaders spatial) y quema
// siluetas en el framebuffer para que el filtro ASCII del ColorRect
// conserve profundidades relativas entre jugador, enemigos y props.
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform float outline_gain = 90.0;
uniform float outline_alpha = 0.55;


void fragment() {
	vec2 pixel = 1.0 / VIEWPORT_SIZE;
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	float depth_x = textureLod(depth_tex, SCREEN_UV + vec2(pixel.x, 0.0), 0.0).r;
	float depth_y = textureLod(depth_tex, SCREEN_UV + vec2(0.0, pixel.y), 0.0).r;
	float edge = abs(depth - depth_x) + abs(depth - depth_y);

	ALBEDO = vec3(0.0);
	ALPHA = clamp(edge * outline_gain, 0.0, outline_alpha);
}
