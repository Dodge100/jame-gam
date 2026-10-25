shader_type canvas_item;
render_mode unshaded;

// transient blur patches on the lens: appear, linger, dissolve
uniform sampler2D screen_tex : hint_screen_texture;

uniform vec2 grid = vec2(7.0, 4.0);              // patch cells across the screen
uniform float density : hint_range(0.0, 1.0) = 0.45;
uniform float min_radius = 0.05;                 // patch radius, fraction of screen height
uniform float max_radius = 0.14;
uniform float life = 7.0;                        // seconds for one appear/linger/dissolve cycle
uniform float blur_radius = 12.0;                // in-patch softness in pixels @720p
uniform vec2 pixel_size = vec2(0.00078125, 0.00138889);
uniform float darken : hint_range(0.5, 1.0) = 0.94;
uniform vec3 tint_boost = vec3(0.0, 0.008, 0.028);
uniform vec3 sheen = vec3(0.045, 0.065, 0.1);    // faint cool glow so patches read on flat areas
uniform vec2 parallax = vec2(0.0, 0.0);          // field shift in UV units, driven by camera motion

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 blur_taps(vec2 uv, vec2 r) {
	vec2 r2 = r * 2.2;
	vec3 c = texture(screen_tex, uv).rgb * 2.0;
	c += (texture(screen_tex, uv + r).rgb
		+ texture(screen_tex, uv - r).rgb
		+ texture(screen_tex, uv + vec2(r.x, -r.y)).rgb
		+ texture(screen_tex, uv + vec2(-r.x, r.y)).rgb
		+ texture(screen_tex, uv + vec2(r.x, 0.0)).rgb
		+ texture(screen_tex, uv + vec2(-r.x, 0.0)).rgb
		+ texture(screen_tex, uv + vec2(0.0, r.y)).rgb
		+ texture(screen_tex, uv + vec2(0.0, -r.y)).rgb) * 0.8;
	c += (texture(screen_tex, uv + r2).rgb
		+ texture(screen_tex, uv - r2).rgb
		+ texture(screen_tex, uv + vec2(r2.x, 0.0)).rgb
		+ texture(screen_tex, uv + vec2(-r2.x, 0.0)).rgb
		+ texture(screen_tex, uv + vec2(0.0, r2.y)).rgb
		+ texture(screen_tex, uv + vec2(0.0, -r2.y)).rgb) * 0.55;
	return c / 11.7;
}

void fragment() {
	vec3 base = texture(screen_tex, SCREEN_UV).rgb;
	// gentle gloom on the bare lens, patches blend in on top of it
	vec3 col = base * darken + tint_boost;

	// union the patches from this cell and its neighbours for seamless panes
	vec2 patch_uv = UV + parallax;
	vec2 base_cell = floor(patch_uv * grid);
	vec2 aspect = vec2(pixel_size.y / pixel_size.x, 1.0);
	float mask = 0.0;

	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			vec2 cell = base_cell + vec2(float(dx), float(dy));
			// wrap cell ids by a huge period so the endless scroll never runs dry
			vec2 cw = mod(cell, vec2(1024.0));
			float r1 = hash(cw * 1.71 + vec2(1.3, 7.1));
			if (r1 <= density) {
				float r2 = hash(cw * 1.71 + vec2(5.7, 3.9));
				float r3 = hash(cw * 1.71 + vec2(9.1, 2.3));
				float r4 = hash(cw * 1.71 + vec2(4.3, 8.7));

				// fade in, hold, dissolve
				float tc = fract((TIME / life) * (0.6 + 0.8 * r2) + r3);
				float grow = smoothstep(0.0, 0.12, tc);
				float dissolve = smoothstep(0.72, 1.0, tc);
				float env = grow * (1.0 - dissolve) * (0.75 + 0.25 * r4);

				if (env > 0.001) {
					// patch center inside the cell, creeping slowly downward
					vec2 center = vec2(0.2 + 0.6 * r3, 0.2 + 0.6 * r4);
					center += vec2(0.03, 0.06) * tc;
					vec2 cell_uv = (cell + center) / grid;

					float radius = mix(min_radius, max_radius, r2);
					radius *= mix(0.55, 1.0, grow) * mix(1.0, 0.35, dissolve);

					float d = length((patch_uv - cell_uv) * aspect);
					float m = smoothstep(1.0, 0.35, d / radius) * env;
					mask = max(mask, m);
				}
			}
		}
	}

	if (mask > 0.001) {
		vec3 blurred = blur_taps(SCREEN_UV, vec2(blur_radius, blur_radius) * pixel_size);
		col = mix(col, blurred * darken + tint_boost, mask);
		col += sheen * mask * mask;
	}

	COLOR = vec4(col, 1.0);
}
