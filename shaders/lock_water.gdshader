// Вода в шахте нижнего шлюза по ART-073 (`LockWater`, `docs/concept-art/shlyuz-voda.md`): одна плоскость 2,2 × 2,2 м
// в осях узла (центр — LockWater.CENTER, ось y — вверх корабля). Рябь — две встречные выборки карты нормалей, кольца
// и всплеск троса — атлас 4×4 (R — гребень, A — маска), блик полосы плафона трюма — мягкой маской по отражённому лучу,
// френель Шлика. Неосвещённый, без тумана: сквозь остаток альфы видна уже отрисованная отмель.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

uniform sampler2D ripple : filter_linear_mipmap, repeat_enable;   // данные, не цвет
uniform sampler2D rings : filter_linear, repeat_disable;          // данные, не цвет
uniform vec3 water_color : source_color = vec3(0.06, 0.15, 0.22); // LockWater.color
uniform vec3 lamp_color : source_color = vec3(0.776, 0.839, 0.871);
uniform vec3 lamp_pos = vec3(0.0, 4.10, -0.25);   // полоса плафона в осях узла (LockWater.lamp − CENTER)
uniform vec2 lamp_extent = vec2(0.72, 2.15);
uniform float clock = 0.0;
uniform float amplitude = 1.2;      // LockWater.amplitude
uniform float event_age = -1.0;     // с от события троса; < 0 — нет
uniform float event_kind = 0.0;     // 0 — вход (кольца), 1 — выход (всплеск)
uniform float event_k = 1.0;
uniform vec2 rope_uv = vec2(0.5);
uniform float ambient = 0.36;       // Seabed.Water.ambient
uniform float deepness = 0.0;       // Seabed.Water.k
uniform float lamp_k = 1.0;         // мигание Vitals.lamp_k
uniform float shown = 1.0;          // LockWater.shown — открытие крышки

varying vec3 local_pos;
varying vec3 local_cam;
varying vec2 water_uv;

void vertex() {
	local_pos = VERTEX;
	water_uv = (VERTEX.xz + vec2(1.1)) / 2.2;
	local_cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}

vec2 stamp(float frame, vec2 uv) {
	vec2 cell = vec2(mod(frame, 4.0), floor(frame / 4.0));
	vec4 s = texture(rings, (cell + clamp(uv, vec2(0.008), vec2(0.992))) / 4.0);
	return vec2(s.r, s.a);
}

vec2 animated(float n, float last, vec2 uv) {
	return mix(stamp(floor(n), uv), stamp(min(floor(n) + 1.0, last), uv), smoothstep(0.0, 1.0, fract(n)));
}

vec2 rope_event(vec2 uv) {
	if (event_age < 0.0 || event_age > 1.4) {
		return vec2(0.0);
	}
	float extent = event_kind > 0.5 ? 1.8 : 1.25;
	vec2 e = (uv - rope_uv) * 2.2 / extent + 0.5;
	float inside = step(0.0, e.x) * step(e.x, 1.0) * step(0.0, e.y) * step(e.y, 1.0);
	float n = clamp(event_age / 1.4, 0.0, 1.0) * 7.0;
	float last = 7.0;
	if (event_kind > 0.5) {
		n = 8.0 + clamp(event_age / 0.8, 0.0, 1.0) * 3.0;
		last = 11.0;
	}
	vec2 wave = animated(n, last, e);
	vec2 bubble = animated(12.0 + clamp(event_age / 1.1, 0.0, 1.0) * 3.0, 15.0, e);
	return (wave + 0.25 * bubble) * smoothstep(0.0, 0.06, event_age) * (1.0 - smoothstep(1.0, 1.4, event_age))
		* inside * event_k;
}

void fragment() {
	vec3 a = texture(ripple, water_uv * 2.75 + clock * vec2(0.018, 0.012)).rgb * 2.0 - 1.0;
	vec3 b = texture(ripple, water_uv * 4.125 - clock * vec2(0.012, 0.015)).rgb * 2.0 - 1.0;
	vec2 nxy = (a.xy + b.xy) * 0.5 * amplitude;   // как в примерке ART-073: сила прямо множит XY
	vec2 ev = rope_event(water_uv);
	float dx = rope_event(water_uv + vec2(0.008, 0.0)).x - rope_event(water_uv - vec2(0.008, 0.0)).x;
	float dz = rope_event(water_uv + vec2(0.0, 0.008)).x - rope_event(water_uv - vec2(0.0, 0.008)).x;
	vec3 n = normalize(vec3(nxy.x + dx * 0.5, 1.0, nxy.y + dz * 0.5));   // касательные (x, z) → оси (x, z), y — вверх
	vec3 v = normalize(local_cam - local_pos);
	float f = 0.02 + 0.98 * pow(1.0 - clamp(abs(dot(n, v)), 0.0, 1.0), 5.0);
	vec3 r = reflect(-v, n);
	float lamp = 0.0;
	if (r.y > 0.01) {
		vec3 q = local_pos + r * ((lamp_pos.y - local_pos.y) / r.y);
		vec2 d = (q.xz - lamp_pos.xz) / lamp_extent;
		lamp = exp(-d.x * d.x - pow(abs(d.y), 4.0));
	}
	float center = 1.0 - smoothstep(0.0, 0.67, length(water_uv - vec2(0.5)));
	vec3 base = water_color * (1.0 - 0.42 * center);
	vec3 sky = vec3(0.035, 0.065, 0.085);
	vec3 c = mix(base, sky, f * 0.75);
	c += lamp_color * lamp * lamp_k * (0.24 + f * 0.6);
	c += vec3(0.08, 0.16, 0.20) * ambient * 0.12 * (1.0 - center * 0.5);
	c += vec3(0.07, 0.13, 0.16) * pow(clamp(ev.x, 0.0, 1.0), 4.0) * ev.y * 0.6;
	ALBEDO = c;
	ALPHA = clamp(0.80 + 0.13 * center + f * 0.06 + 0.08 * deepness, 0.0, 0.98) * shown;
}
