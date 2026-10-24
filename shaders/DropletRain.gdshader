shader_type canvas_item;
render_mode unshaded;

// Droplets crawling down the camera glass: each bead refracts and locally
// blurs the world behind it, like a wet lens.
uniform sampler2D screen_tex : hint_screen_texture;

uniform float cols = 56.0;
uniform float density = 0.35;
uniform float speed = 0.05;
uniform float length : hint_range(0.05, 1.0) = 0.45;
uniform float width : hint_range(0.01, 1.0) = 0.1;
uniform float head_scale : hint_range(0.002, 0.05) = 0.01; // head bead radius (fraction of height)
uniform vec3 tint = vec3(0.78, 0.9, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.3;
uniform float magnify : hint_range(0.3, 1.0) = 0.82;       // <1 zooms in (lens effect)
uniform float soft_blur = 2.0;                             // in-droplet blur radius (pixels)
uniform vec2 pixel_size = vec2(0.00078125, 0.00138889); // 1 / viewport resolution (1280x720)

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 blurred_screen(vec2 uv, float radius) {
	vec2 r = radius * pixel_size;
	vec3 c = texture(screen_tex, uv).rgb;
	c += texture(screen_tex, uv + vec2(r.x, 0.0)).rgb;
	c += texture(screen_tex, uv - vec2(r.x, 0.0)).rgb;
	c += texture(screen_tex, uv + vec2(0.0, r.y)).rgb;
	c += texture(screen_tex, uv - vec2(0.0, r.y)).rgb;
	return c / 5.0;
}

void fragment() {
	float col = UV.x * cols;
	float cx = floor(col);
	float fx = col - cx;

	float r1 = hash(vec2(cx, 1.71));
	float r2 = hash(vec2(cx, 5.33));
	float r3 = hash(vec2(cx, 9.27));

	float cover = 0.0;
	vec3 acc = vec3(0.0);
	float acc_w = 0.0;

	if (r1 <= density) {
		float wobble = 0.06 * sin(UV.y * 14.0 + r2 * 6.28);

		for (int k = 0; k < 2; k++) {
			float head = fract(r2 + float(k) * 0.5 + TIME * speed * (0.6 + 0.8 * r3));
			float d = head - UV.y;

			// Wet smear above the head: locally blurred world, faint.
			if (d > 0.0 && d <= length) {
				float t = d / length;
				float wx = abs(fx - (0.5 + wobble + 0.1 * sin(t * 9.0 + r3 * 3.0)));
				float m = 1.0 - smoothstep(width * 0.4, width * 0.7, wx);
				float wet = (1.0 - t) * (0.22 + 0.3 * smoothstep(0.3, 0.75, 0.5 + 0.5 * sin(UV.y * 90.0 + r1 * 40.0)));
				vec3 s = blurred_screen(SCREEN_UV, soft_blur * (0.6 + 0.4 * (1.0 - t)));
				float w = m * wet;
				acc += s * w;
				acc_w += w;
				cover = max(cover, m * wet * 0.8);
			}

			// Head bead: a tiny lens over the world.
			float wx_h = abs(fx - (0.5 + wobble));
			float hv = abs(d) / head_scale;
			float wv = wx_h / (width * 0.55);
			float rr = length(vec2(min(wv, 4.0), min(hv * 0.9, 4.0)));
			float head_mask = smoothstep(1.0, 0.45, rr);
			if (head_mask > 0.02) {
				float cx_screen = (cx + 0.5 + wobble) / cols;
				vec2 center = vec2(cx_screen, head);
				vec2 off = (SCREEN_UV - center) * magnify;
				vec3 s = blurred_screen(center + off, soft_blur * 1.2);
				float w = head_mask;
				acc += (s + tint * 0.22) * w;
				acc_w += w;
				cover = max(cover, head_mask);
			}
		}
	}

	vec3 out_col = acc_w > 0.001 ? acc / acc_w : vec3(0.0);
	COLOR = vec4(out_col + tint * 0.05, clamp(cover, 0.0, 1.0) * intensity);
}
