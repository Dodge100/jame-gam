shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float cols = 150.0;      // number of streak columns across the screen
uniform float speed = 0.5;       // screen-heights per second
uniform float density = 0.35;    // fraction of columns with a streak (0..1)
uniform float length : hint_range(0.01, 1.0) = 0.3;   // streak length (fraction of height)
uniform float width : hint_range(0.01, 1.0) = 0.3;    // streak thickness (fraction of column spacing)
uniform float slant = 0.06;      // diagonal shear: columns shifted per screen height
uniform vec3 tint = vec3(0.72, 0.86, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.25;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// Sheared sampling so streaks fall at an angle.
	float sx = UV.x - UV.y * slant;
	float col = sx * cols;
	float cx = floor(col);
	float fx = col - cx;

	float r1 = hash(vec2(cx, 3.17));
	float streak = 0.0;
	if (r1 <= density) {
		float r2 = hash(vec2(cx, 7.31));
		float r3 = hash(vec2(cx, 13.7));

		// Falling streak head; wraps back to the top when it leaves the screen.
		float head = fract(r3 + TIME * speed * (0.7 + 0.6 * r2));
		float d = head - UV.y;

		if (d >= 0.0 && d <= length) {
			float t = d / length;
			// Very soft, low-contrast body — long diffuse sheets, no crisp head.
			float body = pow(1.0 - t, 2.2) * 0.26;
			float head_glow = smoothstep(0.2, 0.0, t) * 0.22;
			streak = body + head_glow;
		}
	}

	// Wide, hazy cross-section so streak borders melt into the background.
	float line = 1.0 - smoothstep(0.12, width, abs(fx - 0.5));
	line = sqrt(line);

	COLOR = vec4(tint, streak * line * intensity);
}
