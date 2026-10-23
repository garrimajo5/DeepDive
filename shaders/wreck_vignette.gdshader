shader_type canvas_item;
render_mode unshaded;
// Виньетка шторки «Корпус разрушен» ART-036: a = 0,58 + 0,35 · clamp(((x−1200)/1200)² + ((y−540)/540)², 0, 1),
// умноженная на долю `k` (время — `Wreck.vignette`). Двойник на CPU — `Wreck.vignette_alpha`.
uniform vec3 tint = vec3(0.0431, 0.1098, 0.1412);   // #0B1C24
uniform float k = 0.0;

void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float a = 0.58 + 0.35 * clamp(dot(d, d), 0.0, 1.0);
	COLOR = vec4(tint, a * k);
}
