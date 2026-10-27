shader_type canvas_item;
render_mode unshaded;
// Виньетка и цветокоррекция по глубине ART-065 (`docs/concept-art/vinyetka.md`). Один проход поверх 3D, под интерфейсом.
// Кадр — display-referred (после ACES и экспозиции ART-059). LUT аффинная: одна выборка + поправка синего по столбцу M.
// Двойник на CPU — `Grade.shade`.
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D lut_tex : repeat_disable, filter_linear;
uniform vec3 blue_column = vec3(0.005, 0.012, 0.98);
uniform float strength = 0.18;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	const vec3 Y = vec3(0.2126, 0.7152, 0.0722);
	float old_y = dot(c, Y);
	float peak = max(c.r, max(c.g, c.b));
	float cold = smoothstep(0.08, 0.22, min(c.g, c.b) - c.r) * smoothstep(0.16, 0.38, peak);
	float protect = max(smoothstep(0.38, 0.72, peak), cold);
	vec3 g = c;
	{   // «Экономно» — свой шейдер без копии экрана, `grade_lite.gdshader` (#842)
		float z = floor(clamp(c.b, 0.0, 1.0) * 15.0 + 0.5);
		vec2 uv = vec2((16.0 * z + clamp(c.r, 0.0, 1.0) * 15.0 + 0.5) / 256.0, (clamp(c.g, 0.0, 1.0) * 15.0 + 0.5) / 16.0);
		g = clamp(texture(lut_tex, uv).rgb + blue_column * (c.b - z / 15.0), vec3(0.0), vec3(1.0));
		g *= max(1.0, old_y / max(dot(g, Y), 0.00001));   // не темнее исходной яркости
		g = mix(g, c, protect);
	}
	vec2 p = (SCREEN_UV - vec2(0.5)) * 2.0;
	float edge = smoothstep(0.36, 1.28, length(p * vec2(0.90, 1.0)));
	float amount = strength * edge * (1.0 - protect) * smoothstep(0.015, 0.09, old_y);
	g *= vec3(1.0 - amount, 1.0 - amount * 0.88, 1.0 - amount * 0.65);
	COLOR = vec4(clamp(g, vec3(0.0), vec3(1.0)), 1.0);
}
