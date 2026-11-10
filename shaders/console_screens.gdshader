shader_type spatial;
render_mode unshaded;   // свет экрана свой, плафоны его не гасят — как в принятой пробе ART-061
// Экраны пульта пилота ART-061 (`docs/concept-art/ekrany-pultov.md`): атлас фонов и глифов, слева ход, в середине
// глубина и курс с лентой компаса, справа свет и сонар. Три экрана по x модели — у каждого своя яркость (помехи,
// Vitals.screen_k), граница — edge от центра модели. UV сетки (`BridgeProps.screen_mesh`) — 0…1 по экрану, v вниз.
// Показ — `ConsoleScreen.values`/`status`, пишет `BridgeView.set_readout` только при смене.
uniform sampler2D atlas : source_color, filter_linear, repeat_disable;
uniform vec3 values = vec3(0.0, 0.0, 0.0);   // курс °, глубина м, ход м/с со знаком
uniform vec3 status = vec3(1.0, 1.0, 0.0);   // свет 1/0, сонар 1 — готов / 0 — перезаряд, тревога 1/0
uniform vec3 k = vec3(1.0);
uniform float edge = 0.35;
const vec3 INK = vec3(0.13, 0.72, 0.83);
const vec3 AMBER = vec3(1.0, 0.698, 0.349);   // #FFB259, красного нет (#129)
const vec2 ATLAS = vec2(1024.0, 512.0);
varying float vx;

void vertex() {
	vx = VERTEX.x;
}

// Глиф банка атласа (ячейки 64×64, строка y 384): 0–9, 10 «.», 11 «м», 12 «°», 13 «/», 14 «−», 15 «с».
float glyph(vec2 p, vec2 start, vec2 size, float index) {
	vec2 q = (p - start) / size;
	if (q.x < 0.0 || q.y < 0.0 || q.x > 1.0 || q.y > 1.0) return 0.0;
	vec2 uv = (vec2(index * 64.0 + 12.0, 384.0) + q * vec2(40.0, 64.0)) / ATLAS;
	if (index == 11.0) uv = (vec2(716.0, 397.0) + q * vec2(40.0, 38.0)) / ATLAS;
	if (index == 12.0) uv = (vec2(789.0, 393.0) + q * vec2(22.0, 24.0)) / ATLAS;
	return texture(atlas, uv).a;
}

float ring(vec2 p, vec2 c, float fill) {
	float d = length(p - c);
	float line = smoothstep(13.0, 11.5, d) * smoothstep(8.5, 10.0, d);   // контур — выключено
	return max(line, smoothstep(13.0, 11.0, d) * fill);
}

void fragment() {
	float panel = vx < -edge ? 0.0 : (vx > edge ? 2.0 : 1.0);
	vec2 p = clamp(UV, vec2(0.006), vec2(0.994)) * vec2(320.0, 136.0);
	vec3 col = texture(atlas, (vec2(panel * 352.0, 0.0) + p) / ATLAS).rgb;
	float ink = 0.0;
	if (panel == 0.0) {
		float v = abs(values.z);
		float n = floor(v * 10.0 + 0.5);
		if (values.z < -0.05) ink += glyph(p, vec2(64.0, 40.0), vec2(24.0, 58.0), 14.0);   // задний ход
		ink += glyph(p, vec2(95.0, 40.0), vec2(30.0, 58.0), mod(floor(n / 10.0), 10.0));
		ink += glyph(p, vec2(126.0, 40.0), vec2(14.0, 58.0), 10.0);
		ink += glyph(p, vec2(141.0, 40.0), vec2(30.0, 58.0), mod(n, 10.0));
		ink += glyph(p, vec2(186.0, 56.0), vec2(20.0, 32.0), 11.0);
		ink += glyph(p, vec2(207.0, 56.0), vec2(18.0, 32.0), 13.0);
		ink += glyph(p, vec2(226.0, 56.0), vec2(20.0, 32.0), 15.0);
	} else if (panel == 1.0) {
		float d = values.y;
		float h = values.x;
		ink += glyph(p, vec2(75.0, 4.0), vec2(13.0, 66.0), mod(floor(d / 100.0), 10.0));
		ink += glyph(p, vec2(88.0, 4.0), vec2(13.0, 66.0), mod(floor(d / 10.0), 10.0));
		ink += glyph(p, vec2(101.0, 4.0), vec2(13.0, 66.0), mod(d, 10.0));
		ink += glyph(p, vec2(115.0, 24.0), vec2(11.0, 34.0), 11.0);
		ink += glyph(p, vec2(204.0, 4.0), vec2(13.0, 66.0), mod(floor(h / 100.0), 10.0));
		ink += glyph(p, vec2(217.0, 4.0), vec2(13.0, 66.0), mod(floor(h / 10.0), 10.0));
		ink += glyph(p, vec2(230.0, 4.0), vec2(13.0, 66.0), mod(h, 10.0));
		ink += glyph(p, vec2(244.0, 4.0), vec2(10.0, 34.0), 12.0);
		if (p.x >= 204.0 && p.x <= 254.0) {   // лента компаса: 8 px на 10°
			float tick = mod(p.x - 204.0 + mod(h, 10.0) * 0.8, 8.0);
			float bar = step(tick, 1.0) * step(64.0, p.y) * step(p.y, 73.0);
			float base = step(72.0, p.y) * step(p.y, 73.0);
			float pointer = step(58.0, p.y) * step(p.y, 63.0) * step(abs(p.x - 229.0), (63.0 - p.y) * 0.5);
			ink = max(ink, max(max(bar * 0.6, base * 0.45), pointer));
		}
		// тревога — янтарная рамка по краю, мигает; поле цифр не трогает
		float frame = 1.0 - step(4.0, min(min(p.x, 320.0 - p.x), min(p.y, 136.0 - p.y)));
		float blink = status.z * frame * (0.55 + 0.45 * sin(TIME * 6.0));
		col = mix(col, AMBER, clamp(blink, 0.0, 1.0));
	} else {
		ink += ring(p, vec2(282.0, 28.0), status.x);
		float pulse = 0.25 + 0.2 * sin(TIME * 4.0);   // перезаряд сонара — мягкая пульсация
		ink += ring(p, vec2(282.0, 100.0), status.y > 0.5 ? 1.0 : pulse);
	}
	float kk = panel == 0.0 ? k.x : (panel == 1.0 ? k.y : k.z);
	col = mix(col, INK, clamp(ink, 0.0, 1.0));
	ALBEDO = col * 0.55 * kk;
	EMISSION = col * 0.15 * kk;
}
