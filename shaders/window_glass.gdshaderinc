// Общее тело стекла носовых окон ART-057 + конденсат ART-077 (подключают window_glass и window_glass_wet).
// С `#define WET_REFRACT` (только `window_glass_wet.gdshader`, уровень «Красиво») — полный вариант ART-077: нормали
// капель из производных высоты маски и слабое экранное преломление (`hint_screen_texture` — копия экрана каждый кадр
// на Forward Mobile, поэтому отдельный ресурс шейдера: в «Экономно»/«Обычно» его нет совсем). Числа —
// `docs/concept-art/kondensat-okon.md`, двойники — `WindowFog.wet_*`.
render_mode blend_mix, cull_disabled, depth_draw_never, fog_disabled;

uniform vec3 tint : source_color = vec3(0.6, 0.85, 0.9);
uniform sampler2D mask : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_disable;
uniform vec2 split = vec2(0.328947, 0.671053);
uniform float normal_depth = 0.12;
uniform bool relief = true;
uniform sampler2D condensation : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform float humidity = 0.0;
uniform float ice_k = 0.0;
uniform vec3 ice_color = vec3(0.38, 0.62, 0.7);
#ifdef WET_REFRACT
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap, repeat_disable;
#endif

void fragment() {
	float u = UV.x;
	vec2 uv;
	vec2 flip = vec2(1.0);
	if (u < split.x) {
		uv = vec2(u / split.x, UV.y);
	} else if (u < split.y) {
		uv = vec2(1.0 - (u - split.x) / (split.y - split.x), UV.y);
		flip.x = -1.0;
	} else {
		uv = vec2((u - split.y) / (1.0 - split.y), 1.0 - UV.y);
		flip.y = -1.0;
	}
	// производные непрерывного UV: на стыках участков (под стойками) mipmap не рвётся
	vec2 dx = dFdx(UV) * vec2(1.0 / split.x, 1.0);
	vec2 dy = dFdy(UV) * vec2(1.0 / split.x, 1.0);
	vec4 m = textureGrad(mask, uv, dx, dy);
	ALBEDO = tint;
	METALLIC = 0.0;
	// блики плафонов в чистом центре окна слабее (ART-057: не ложиться на существ), у рамы — полные
	SPECULAR = 0.55 * mix(0.3, 1.0, smoothstep(0.0, 0.15, m.a));
	vec3 n = vec3(0.0, 0.0, 1.0);
	if (relief) {
		ALPHA = 0.07 + 0.26 * m.a;
		ROUGHNESS = clamp(0.12 + 0.50 * m.r + 0.14 * m.g, 0.12, 0.70);
		n = textureGrad(normal_map, uv, dx, dy).rgb * 2.0 - 1.0;
		n.xy *= flip;
		NORMAL_MAP = n * 0.5 + 0.5;
		NORMAL_MAP_DEPTH = normal_depth;
	} else {
		ALPHA = 0.07 + 0.12 * m.a;
		ROUGHNESS = 0.6;
	}
	if (humidity > 0.001) {
		vec4 c = textureGrad(condensation, uv, dx, dy);
		float gate = smoothstep(c.a, c.a + 0.18, humidity);
		float drops = max(c.r, c.g * 0.65) * gate;
		float frost = c.b * ice_k * gate;
#ifdef WET_REFRACT
		// Полный вариант ART-077: высота капли (м) → наклон по производным, без соседних выборок маски.
		float h = 0.0006 * c.r + 0.00025 * c.g;
		vec2 qx = dx * flip;
		vec2 qy = dy * flip;
		float det = qx.x * qy.y - qx.y * qy.x;
		float hx = dFdx(h);   // производные — вне ветвления по пикселю
		float hy = dFdy(h);
		vec2 slope = vec2(0.0);
		if (abs(det) > 1e-12) {
			vec2 dh = vec2(hx * qy.y - hy * qx.y, qx.x * hy - qy.x * hx) / det;
			slope = clamp(dh / vec2(2.5, 1.9), vec2(-0.35), vec2(0.35)) * flip * gate;
		}
		if (relief && (slope.x != 0.0 || slope.y != 0.0)) {
			NORMAL_MAP = normalize(n + vec3(-slope.x, slope.y, 0.0) / max(normal_depth, 0.01)) * 0.5 + 0.5;
		}
		// Веса слоёв поверх исходного стекла (WindowFog.wet_weights): иней и мениск у края капли закрывают вид,
		// сама капля — только лёгкой плёнкой, как в «Обычно» (0,16): копия экрана без поздних прозрачных (дальняя вода, лучи, взвесь) темнее настоящего фона,
		// поэтому капля не подменяет фон копией, а только добавляет сдвиг преломления (светлее там, где сдвинутый
		// вид ярче). Не свечение капли — возврат уже освещённого мира за стеклом.
		float bead = smoothstep(0.08, 0.3, c.r) * (1.0 - smoothstep(0.3, 0.75, c.r)) * gate;
		float base_a = ALPHA;
		float dc = 0.6 * drops * (1.0 - frost);
		float fc = 0.72 * frost;
		float bc = 0.09 * bead;
		float ff = 0.16 * drops;
		float a = 1.0 - (1.0 - base_a) * (1.0 - fc) * (1.0 - bc) * (1.0 - ff);
		float w_cold = (1.0 - base_a) * (fc + (1.0 - fc) * bc);
		float w_film = (1.0 - base_a) * (1.0 - fc) * (1.0 - bc) * ff;
		float w_drop = (1.0 - base_a) * (1.0 - fc) * (1.0 - bc) * (1.0 - ff) * dc;
		vec3 bend = TANGENT * (-slope.x) + BINORMAL * slope.y;
		vec2 suv = clamp(SCREEN_UV + clamp(bend.xy * vec2(1.0, -1.0) * 0.009, vec2(-0.002), vec2(0.002)),
			vec2(0.001), vec2(0.999));
		ALPHA = a;
		ALBEDO = ((base_a + w_film) * tint + w_cold * ice_color) / a;
		vec3 shift = vec3(0.0);
		if (w_drop > 0.002) {
			shift = max(textureLod(screen, suv, 0.0).rgb - textureLod(screen, SCREEN_UV, 0.0).rgb, vec3(0.0));
		}
		EMISSION = shift * (w_drop / a);
		ROUGHNESS = mix(mix(ROUGHNESS, 0.08, drops), 0.86, frost);
		SPECULAR = SPECULAR * base_a / a + 0.25 * drops;
#else
		ALPHA = 1.0 - (1.0 - ALPHA) * (1.0 - 0.16 * drops - 0.42 * frost);
		ALBEDO = mix(tint, ice_color, frost);
		ROUGHNESS = mix(ROUGHNESS, 0.85, frost);
#endif
	}
}
