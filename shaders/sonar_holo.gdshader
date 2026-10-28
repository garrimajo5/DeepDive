// Голограмма сонара на голостоле (js/sonar.js So.update): круг, на нём рельеф вокруг корабля носом вверх,
// кольца дальности, волна импульса и отметки существ; цвета складываются, как свет над столом.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

uniform sampler2D map_tex : source_color, filter_linear, repeat_disable;
uniform float map_size = 700.0;
uniform vec2 ship_xz = vec2(0.0);
uniform float ship_yaw = 0.0;
uniform float range_m = 110.0;
uniform float ping_age = 99.0;
uniform float disc_r = 1.02;
uniform int blip_count = 0;
uniform vec4 blips[32];       // x, z мира, размер (м на голограмме, доля радиуса), яркость
uniform vec3 blip_cols[32];
uniform float brightness = 1.0;
uniform float noise = 0.0;    // помехи (сонарная тьма): карта гаснет, по столу рябь
uniform float jam = 0.0;      // последний импульс завяз в иле (Sonar.jammed): кольцо тормозит у трети радиуса и рвётся
uniform float jam_time = 4.0; // Silt.JAM_TIME: столько держится сильный след завязшего импульса
uniform float time = 0.0;
uniform vec2 wp_xz = vec2(0.0);  // точка маршрута (Run.waypoint), x, z мира
uniform float wp_on = 0.0;
// брифинг (Briefing, ART-016): карта всей отмели над столом, места и маршруты; brief_k — доля перехода 0…1
uniform float dim = 0.0;      // голосование над столом: рельеф гаснет (VoteHolo.DIM_SONAR)
uniform float brief_k = 0.0;
uniform float brief_scale = 0.0016143;  // Briefing.SCALE: м стола на м мира
uniform float brief_side = 1.13;
uniform vec4 segs[8];         // концы отрезков маршрутов на столе: a.x, a.z, b.x, b.z (м)
uniform vec2 seg_info[8];     // индекс маршрута, путь от начала маршрута до a (м)
uniform int seg_count = 0;
uniform int sel_route = -1;
uniform float route_len = 1.0;
uniform vec2 places[11];       // места на столе (м)
uniform float place_state[11]; // 0 — не на маршруте, 1 — на маршруте, 2 — пройдено, 3 — следующая точка
uniform vec2 ship_t = vec2(0.0);  // корабль на столе (м)

varying vec2 local;

void vertex() {
	local = VERTEX.xz / disc_r;   // −1…1: x вправо (+X корабля), y к корме (+Z корабля)
}

// карта брифинга: lm — точка стола, м (x вправо, y к корме)
vec3 briefing(vec2 lm, float c, float s) {
	vec3 holo = vec3(0.404, 0.867, 0.922);   // #67DDEB
	vec3 soft = vec3(0.604, 0.851, 0.910);   // #9AD9E8
	vec3 pick = vec3(0.835, 0.894, 0.910);   // #D5E4E8
	vec3 col = vec3(0.004, 0.035, 0.047);
	float half_side = brief_side * 0.5;
	if (abs(lm.x) < half_side && abs(lm.y) < half_side)
		col = texture(map_tex, lm / brief_scale / map_size + 0.5).rgb * 0.26;
	float edge = max(abs(lm.x), abs(lm.y));
	col += soft * 0.22 * step(abs(edge - half_side), 0.003);
	float scan = fract(time * 0.22) * half_side * 1.42;   // сканирующее кольцо
	col += holo * 0.14 * step(abs(length(lm) - scan), 0.004) * step(edge, half_side);
	for (int i = 0; i < 8; i++) {
		if (i >= seg_count) break;
		vec2 a = segs[i].xy, b = segs[i].zw;
		vec2 ab = b - a;
		float len = max(length(ab), 1e-4);
		float t = clamp(dot(lm - a, ab) / (len * len), 0.0, 1.0);
		float d = length(lm - a - ab * t);
		float along = seg_info[i].y + t * len;
		int route = int(seg_info[i].x + 0.5);
		bool sel = route == sel_route;
		float w = sel ? 0.007 : 0.0045;
		float m;
		if (route == 2) {   // точки
			float q = (fract(along / 0.024) - 0.5) * 0.024;
			m = step(length(vec2(q, d)), w * 1.25);
		} else {
			m = step(d, w) * (route == 1 ? step(fract(along / 0.05), 0.62) : 1.0);
		}
		vec3 lc = sel ? pick : holo * 0.5;
		if (sel) {
			float run_at = fract(time * 0.3) * route_len;   // бегущая подсветка вдоль выбранного маршрута
			lc += pick * 0.8 * exp(-pow((along - run_at) / 0.035, 2.0));
		}
		col = mix(col, lc, m);
	}
	for (int i = 0; i < 11; i++) {
		float d = length(lm - places[i]);
		float st = place_state[i];
		vec3 pc = st > 0.5 ? pick : soft * 0.55;
		float ring = step(abs(d - 0.024), 0.004);
		float dot_in = step(d, 0.009) + (st > 1.5 && st < 2.5 ? step(d, 0.02) * 0.6 : 0.0);
		col = max(col, pc * min(1.0, ring + dot_in));
		if (st > 2.5) {   // следующая точка: импульс
			float pr = 0.03 + fract(time * 1.2) * 0.03;
			col = max(col, pick * (1.0 - fract(time * 1.2)) * step(abs(d - pr), 0.003));
		}
	}
	vec2 dd = lm - ship_t;   // корабль — треугольник носом по курсу
	vec2 p = vec2(dd.x * c - dd.y * s, dd.x * s + dd.y * c) / 0.45;
	if (p.y > -0.075 && p.y < 0.055 && abs(p.x) < (p.y + 0.075) * 0.35) col = holo;
	return col;
}

void fragment() {
	float r = length(local);
	if (r > 1.0) discard;
	// точка голограммы → мир: оси корабля повёрнуты на курс
	vec2 l = local * range_m;
	float c = cos(ship_yaw), s = sin(ship_yaw);
	vec2 w = ship_xz + vec2(l.x * c + l.y * s, -l.x * s + l.y * c);
	vec3 col = vec3(0.008, 0.07, 0.094);
	vec2 uv = w / map_size + 0.5;
	if (uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0)
		col = texture(map_tex, uv).rgb * 0.45 * (0.3 + 0.7 * max(0.0, 1.0 - ping_age / 12.0));
	vec3 teal = vec3(0.37, 0.95, 0.84);
	if (noise > 0.0) {   // ил (ART-048): карта гаснет, по столу плавные полосы ряби — без мельтешения
		float th = atan(local.x, local.y);
		float strong = jam * (1.0 - smoothstep(jam_time - 1.0, jam_time, ping_age));
		float band = 0.5 + 0.5 * sin(r * 34.0 - time * 1.2 + 0.5 * sin(th * 3.0 + time * 0.3));
		col = mix(col, vec3(0.008, 0.07, 0.094), noise * 0.8);
		col += teal * (0.025 * noise + 0.07 * strong) * smoothstep(0.7, 1.0, band) * (1.0 - r * 0.6);
	}
	col += teal * 0.18 * (step(abs(r - 0.33), 0.006) + step(abs(r - 0.66), 0.006));
	col += teal * 0.5 * step(0.985, r);
	if (jam > 0.5) {
		// завязший импульс: за 0,4 с доходит до трети радиуса, тормозит, рвётся на 4 неровные дуги
		// и к ~1,1 с распадается в рябь — знак, а не дальность
		float a = ping_age;
		float rr = 0.34 * (1.0 - pow(1.0 - min(a / 0.42, 1.0), 2.0));
		float th = atan(local.x, local.y);
		float tear = smoothstep(0.3, 0.6, a);
		float arcs = 0.5 + 0.5 * sin(th * 4.0 + 1.2 * sin(th * 2.0 + 0.7));
		float fade = 1.0 - smoothstep(0.42, 1.15, a);
		float wdt = 0.018 + 0.03 * smoothstep(0.42, 1.15, a);
		col += teal * 0.6 * fade * step(abs(r - rr), wdt) * mix(1.0, step(0.3, arcs), tear);
	} else if (ping_age < 2.5)
		col += teal * 0.6 * (1.0 - ping_age / 2.5) * step(abs(r - ping_age / 2.2), 0.02);
	for (int i = 0; i < 32; i++) {
		if (i >= blip_count) break;
		vec2 d = blips[i].xy - w;
		float k = 1.0 - smoothstep(0.6, 1.0, length(d) / (blips[i].z * range_m));
		col = mix(col, blip_cols[i], k * blips[i].w);
	}
	if (wp_on > 0.5) {   // точка маршрута: светлое кольцо, дальше дальности — на краю круга в её сторону
		vec2 d = wp_xz - ship_xz;
		vec2 lp = vec2(d.x * c - d.y * s, d.x * s + d.y * c) / range_m;
		float far = step(0.9, length(lp));
		lp *= mix(1.0, 0.9 / max(length(lp), 1e-4), far);
		float ring = step(abs(length(local - lp) - 0.07), 0.018) + step(length(local - lp), 0.022);
		float pulse = 0.65 + 0.35 * sin(time * 4.0);
		col = mix(col, vec3(0.84, 0.89, 0.91), ring * pulse);
	}
	// корабль в центре — треугольник носом вверх (к −Z, local.y < 0)
	if (local.y > -0.075 && local.y < 0.055 && abs(local.x) < (local.y + 0.075) * 0.35) col = teal;
	if (brief_k > 0.0)
		col = mix(col, briefing(local * disc_r, c, s), brief_k);
	ALBEDO = col * brightness * (1.0 - dim);
}
