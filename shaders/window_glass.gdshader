shader_type spatial;
// Стекло носовых окон по ART-057 (docs/concept-art/steklo-okon.md): один квад на три окна, одна карта на окно.
// Маска (данные, не sRGB): R — муть у рамы, G — капли и разводы, B — царапины, A — общая сила.
// Нормали — OpenGL (+Y), волна толстого стекла и царапины. Освещается только плафонами (слой корабля): мигание
// Vitals.lamp_k гасит отражение, а альфа (грязь) остаётся. Своей эмиссии нет, туман не нужен — стекло внутри мостика.
// Участки u по стойкам (BridgeView.glass_uv — то же на GDScript, тест test_bridge_glass): левый как есть,
// средний отражён по U, правый — по V; на отражённых нормали инвертируются по той же оси.
// relief = false («Экономно», ART-044) — без нормалей, альфа 0,07 + 0,12·A, шероховатость 0,6.
render_mode blend_mix, cull_disabled, depth_draw_never, fog_disabled;

uniform vec3 tint : source_color = vec3(0.6, 0.85, 0.9);
uniform sampler2D mask : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_disable;
uniform vec2 split = vec2(0.328947, 0.671053);
uniform float normal_depth = 0.12;
uniform bool relief = true;

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
	if (relief) {
		ALPHA = 0.07 + 0.26 * m.a;
		ROUGHNESS = clamp(0.12 + 0.50 * m.r + 0.14 * m.g, 0.12, 0.70);
		vec3 n = textureGrad(normal_map, uv, dx, dy).rgb * 2.0 - 1.0;
		n.xy *= flip;
		NORMAL_MAP = n * 0.5 + 0.5;
		NORMAL_MAP_DEPTH = normal_depth;
	} else {
		ALPHA = 0.07 + 0.12 * m.a;
		ROUGHNESS = 0.6;
	}
}
