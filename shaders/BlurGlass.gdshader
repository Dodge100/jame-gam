shader_type canvas_item;
render_mode unshaded;

// Soft "seen through rain-covered glass" pass: blurs the world behind,
// cools the color slightly and adds a vignette.
uniform sampler2D screen_tex : hint_screen_texture;
uniform float blur_amount : hint_range(0.0, 6.0) = 1.5;  // inner blur radius in pixels
uniform float darken : hint_range(0.5, 1.0) = 0.92;
uniform vec3 tint_boost = vec3(0.0, 0.012, 0.035);
uniform float vignette : hint_range(0.0, 1.0) = 0.28;

void fragment() {
	vec2 ps = SCREEN_PIXEL_SIZE * blur_amount;

	vec3 acc = texture(screen_tex, SCREEN_UV).rgb * 2.4;

	// Tight ring.
	acc += texture(screen_tex, SCREEN_UV + ps).rgb;
	acc += texture(screen_tex, SCREEN_UV - ps).rgb;
	acc += texture(screen_tex, SCREEN_UV + ps * vec2(1.0, -1.0)).rgb;
	acc += texture(screen_tex, SCREEN_UV + ps * vec2(-1.0, 1.0)).rgb;
	acc += texture(screen_tex, SCREEN_UV + ps * vec2(1.0, 0.0)).rgb;
	acc += texture(screen_tex, SCREEN_UV + ps * vec2(-1.0, 0.0)).rgb;
	acc += texture(screen_tex, SCREEN_UV + ps * vec2(0.0, 1.0)).rgb;
	acc += texture(screen_tex, SCREEN_UV + ps * vec2(0.0, -1.0)).rgb;

	// Wide ring for a silkier falloff.
	vec2 p2 = ps * 2.4;
	float w2 = 0.55;
	acc += texture(screen_tex, SCREEN_UV + p2).rgb * w2;
	acc += texture(screen_tex, SCREEN_UV - p2).rgb * w2;
	acc += texture(screen_tex, SCREEN_UV + p2 * vec2(1.0, -1.0)).rgb * w2;
	acc += texture(screen_tex, SCREEN_UV + p2 * vec2(-1.0, 1.0)).rgb * w2;
	acc += texture(screen_tex, SCREEN_UV + p2 * vec2(1.0, 0.0)).rgb * w2;
	acc += texture(screen_tex, SCREEN_UV + p2 * vec2(-1.0, 0.0)).rgb * w2;
	acc += texture(screen_tex, SCREEN_UV + p2 * vec2(0.0, 1.0)).rgb * w2;
	acc += texture(screen_tex, SCREEN_UV + p2 * vec2(0.0, -1.0)).rgb * w2;

	vec3 col = acc / (2.4 + 8.0 + 8.0 * w2);
	col += tint_boost;
	col *= darken;

	float dst = length(SCREEN_UV - vec2(0.5)) * 1.4142;
	col *= 1.0 - vignette * smoothstep(0.5, 1.0, dst);

	COLOR = vec4(col, 1.0);
}
