shader_type spatial;
// Обшивка «Ковчега-7» по ART-024 (docs/concept-art/obshivka.md): цвет, маска и обрастание — трипланарно
// в осях корабля (вершины меша — локальные метры), одни веса для всех трёх карт, плитка 2 м.
// Маска линейная: 0 — металл, 128 — пятна, 255 — швы и крепёж (темнее, с блеском).
// Обрастание — по локальной высоте h (0 у киля, 1 у верха), швы видны поверх. Числа — HullMesh.
// Следы повреждений ART-049 (povrezhdeniya.md): порог сравнивается на каждой плоскости отдельно (wear — потеря
// корпуса 0…1, HullMesh.wear), смешиваются уже видимые следы; поверх обрастания, на швах слабее.
// Против повтора плитки (#406): два слоя следов — как есть и повёрнутый, крупнее, со сдвигом; слой выбирает
// плавный шум по плоскости (HullMesh.damage_gate), слои дополняют друг друга.
// Рельеф ART-053 (obshivka-normali.md): нормали ART-024 и следов ART-049 — OpenGL (+Y вверх по картинке, а v идёт
// вниз, поэтому y меняет знак), каждая плоскость в своём базисе (whiteout), след сводится с основой RNM по весу
// цвета следа; шероховатость — из карты. relief = false («Экономно») — без выборок рельефа, прежние константы.
// Та же математика — HullMesh.decode_normal / plane_normal / rnm / alt_back (тест test_hull_view).
// Разряд ART-068 (razryad-korpus.md): zap_t — время с начала разряда (−1 — нет). Фронт от носа к корме, огибающая
// и кадр атласа — как Zap.arc_k / arc_frame; атлас 4×2 плиткой 8 × 2 м бежит к корме, U сдвигается по полосам и
// кадрам, чтобы прямые концы путей не стояли столбцом. Швы светятся по маске. zap_lite — один кадр («Экономно»).
// Ободок и затенение щелей ART-076 (obodok-korpusa.md): кромка из LUT rim_tex по e = 1 − N·V геометрической нормали
// (не рельефа — царапины не блестят) и строке глубины rim_row, в EMISSION; rim_k — с CPU (жив, ил, «Экономно»).
// AO — шов по маске и поля примыканий в метрах корабля (max); ao_contacts = false («Экономно») — только шов.
// Та же математика — HullMesh.rim_row / rim_zap / contact / occlusion (тест test_hull_rim).

uniform sampler2D color_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D mask_tex : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D growth_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D damage_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D damage_lvl : hint_default_white, filter_nearest, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rough_tex : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform sampler2D damage_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool relief = true;
uniform sampler2D arc_tex : hint_default_black, filter_linear, repeat_enable;
uniform float zap_t = -1.0;
uniform bool zap_lite = false;
uniform float zap_dur = 0.8;
uniform float zap_from = -7.2;
uniform float zap_speed = 50.0;
uniform float zap_width = 7.0;
uniform float zap_fps = 10.0;
uniform vec2 zap_tile = vec2(8.0, 2.0);
uniform float zap_flow = 12.0;
uniform vec3 zap_core_color : source_color = vec3(0.37, 0.95, 0.84);
uniform vec3 zap_halo_color : source_color = vec3(0.4, 0.87, 0.92);
uniform float zap_core = 3.0;
uniform float zap_seam = 0.2;
uniform sampler2D rim_tex : hint_default_black, filter_linear, repeat_disable;
uniform float rim_row = 0.0;
uniform float rim_k = 1.0;
uniform float rim_contact = 0.55;
uniform float rim_zap = 0.55;
uniform bool ao_contacts = true;
uniform float ao_seam = 0.18;
uniform float ao_contact = 0.34;
uniform float ao_min = 0.55;
uniform float ao_albedo = 0.55;
uniform float ao_light = 0.15;
uniform float ao_protect = 0.8;
uniform vec3 ao_mount = vec3(3.45, 1.0, 26.3);
uniform vec3 ao_mount_half = vec3(0.75, 0.225, 0.7);
uniform float ao_mount_feather = 0.18;
uniform vec3 ao_recess = vec3(5.4, 1.0, 26.5);
uniform vec2 ao_recess_r = vec2(1.0, 1.29);
uniform float ao_recess_z = 0.72;
uniform vec3 ao_rudder = vec3(3.95, 2.6, 24.6);
uniform vec3 ao_rudder_r = vec3(0.28, 0.3, 1.0);
uniform vec3 ao_stab_up = vec3(0.0, 3.42, 25.0);
uniform vec3 ao_stab_up_r = vec3(0.28, 0.25, 1.3);
uniform vec3 ao_stab_down = vec3(0.0, -0.2, 25.0);
uniform vec3 ao_stab_down_r = vec3(0.25, 0.24, 1.1);
uniform float normal_depth = 1.0;
uniform float damage_depth = 0.85;
uniform float wear = 0.0;
uniform float damage_seam = 0.55;
uniform float alt_scale = 0.83;
uniform vec2 alt_shift = vec2(0.37, 0.61);
uniform float gate_cell = 1.37;
uniform vec2 gate_edge = vec2(0.46, 0.54);
uniform float tile = 2.0;
uniform float seam_dark = 0.7;
uniform float stain_dark = 0.9;
uniform float keel_y = -1.6;
uniform float hull_h = 6.4;
uniform float growth_max = 0.65;
uniform float growth_from = 0.15;
uniform float growth_to = 0.5;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

vec3 tri_w() {
	vec3 w = pow(abs(normalize(ln)), vec3(4.0));
	return w / (w.x + w.y + w.z);
}

vec4 tri(sampler2D t, vec3 p, vec3 w) {
	return texture(t, p.zy) * w.x + texture(t, p.xz) * w.y + texture(t, p.xy) * w.z;
}

// След одной плоскости: rgb — цвет · альфа, a — альфа (0, если порог ещё не пройден).
vec4 damage(vec2 uv) {
	vec4 c = texture(damage_tex, uv);
	float on = step(texture(damage_lvl, uv).r, wear);
	return vec4(c.rgb * c.a, c.a) * on;
}

float cell_hash(vec2 c) {
	return fract(sin(dot(c, vec2(127.1, 311.7))) * 43758.5453);
}

float gate_noise(vec2 uv) {
	vec2 q = uv / gate_cell;
	vec2 i = floor(q);
	vec2 f = q - i;
	f = f * f * (3.0 - 2.0 * f);
	float a = cell_hash(i);
	float b = cell_hash(i + vec2(1.0, 0.0));
	float c = cell_hash(i + vec2(0.0, 1.0));
	float d = cell_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Следы одной плоскости из двух слоёв: слой по шуму, второй — повёрнутый, крупнее и со сдвигом.
vec4 damage2(vec2 uv) {
	float k = smoothstep(gate_edge.x, gate_edge.y, gate_noise(uv));
	return damage(uv) * k + damage(vec2(-uv.y, uv.x) * alt_scale + alt_shift) * (1.0 - k);
}

// Нормаль карты в осях плитки: x — вдоль u, y — вдоль v, z — от поверхности.
vec3 decode_n(vec4 c) {
	vec3 d = c.rgb * 2.0 - 1.0;
	return vec3(d.x, -d.y, d.z);
}

// Нормаль второго слоя следов (координаты повёрнуты на 90°) — обратно в оси плитки.
vec3 alt_back(vec3 t) {
	return vec3(t.y, -t.x, t.z);
}

// Свести деталь d с основой b (reoriented normal mapping), обе — в осях плитки.
vec3 rnm(vec3 b, vec3 d) {
	vec3 t = b + vec3(0.0, 0.0, 1.0);
	vec3 u = d * vec3(-1.0, -1.0, 1.0);
	return normalize(t * dot(t, u) / t.z - u);
}

// Нормаль следов одной плоскости (два слоя, как damage2), xyz — нормаль, w — вес.
vec4 damage_n(vec2 uv) {
	float k = smoothstep(gate_edge.x, gate_edge.y, gate_noise(uv));
	vec2 uv2 = vec2(-uv.y, uv.x) * alt_scale + alt_shift;
	float a1 = damage(uv).a * k;
	float a2 = damage(uv2).a * (1.0 - k);
	vec3 n = vec3(0.0, 0.0, 1.0) * max(0.0, 1.0 - a1 - a2)
		+ decode_n(texture(damage_nrm, uv)) * a1 + alt_back(decode_n(texture(damage_nrm, uv2))) * a2;
	return vec4(normalize(n), a1 + a2);
}

// Нормаль плитки плоскости uv: основа, сила, след поверх по весу (на швах слабее).
vec3 plane_t(vec2 uv, float seam) {
	vec3 t = decode_n(texture(normal_tex, uv));
	t = normalize(vec3(t.xy * normal_depth, t.z));
	if (wear > 0.0) {
		vec4 d = damage_n(uv);
		float wd = d.w * (1.0 - damage_seam * seam);
		if (wd > 0.001) {
			vec3 dn = normalize(vec3(d.xy * damage_depth, d.z));
			t = rnm(t, normalize(mix(vec3(0.0, 0.0, 1.0), dn, wd)));
		}
	}
	return t;
}

// Трипланарная нормаль в осях корабля (whiteout): плоскость zy — u по z, v по y; xz — u по x, v по z; xy.
vec3 tri_normal(vec3 n, vec3 p, vec3 w, float seam) {
	vec3 tx = plane_t(p.zy, seam);
	vec3 ty = plane_t(p.xz, seam);
	vec3 tz = plane_t(p.xy, seam);
	vec3 ax = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	vec3 ay = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	vec3 az = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	return normalize(ax.zyx * w.x + ay.xzy * w.y + az.xyz * w.z);
}

// Яркость атласа дуг на плоскости: u — вдоль корабля (z), v — поперёк, кадр f.
float arc_at(float z, float v, float t, float f) {
	float row = floor(v / zap_tile.y);
	float u = (z - zap_flow * t) / zap_tile.x + cell_hash(vec2(row, f)) + f * 0.29;
	vec2 cell = vec2(mod(f, 4.0), floor(f / 4.0));
	vec2 uv = (cell + vec2(fract(u), fract(v / zap_tile.y))) / vec2(4.0, 2.0);
	return texture(arc_tex, uv).r;
}

float ao_patch(vec3 p, vec3 c, vec3 r) {
	vec3 q = (p - c) / r;
	return exp(-dot(q, q));
}

// Примыкание 0…1 в точке p (оси корабля): крепления, ниши роторов, корни рулей и стабилизаторов — max.
float contact(vec3 p) {
	vec3 a = vec3(abs(p.x), p.y, p.z);
	vec3 q = abs(a - ao_mount) - ao_mount_half;
	float box = length(max(q, vec3(0.0))) + min(max(q.x, max(q.y, q.z)), 0.0);
	float c = exp(-max(box, 0.0) / ao_mount_feather);
	float rho = length(a.xy - ao_recess.xy);
	float dz = (a.z - ao_recess.z) / ao_recess_z;
	c = max(c, (1.0 - smoothstep(ao_recess_r.x, ao_recess_r.y, rho)) * exp(-dz * dz));
	c = max(c, ao_patch(a, ao_rudder, ao_rudder_r));
	c = max(c, ao_patch(p, ao_stab_up, ao_stab_up_r));
	c = max(c, ao_patch(p, ao_stab_down, ao_stab_down_r));
	return c;
}

void fragment() {
	vec3 w = tri_w();
	vec3 p = lp / tile;
	vec3 col = tri(color_tex, p, w).rgb;
	float m = tri(mask_tex, p, w).r;
	float seam = smoothstep(0.75, 0.95, m);
	float stain = smoothstep(0.3, 0.5, m) * (1.0 - seam);
	col *= mix(1.0, seam_dark, seam) * mix(1.0, stain_dark, stain);
	float h = clamp((lp.y - keel_y) / hull_h, 0.0, 1.0);
	float g = growth_max * (1.0 - smoothstep(growth_from, growth_to, h));
	if (g > 0.001) {
		vec3 gc = tri(growth_tex, p, w).rgb;
		col = mix(col, gc * mix(1.0, seam_dark, seam), g * (1.0 - 0.5 * seam));
	}
	float cover = 0.0;
	if (wear > 0.0) {
		vec4 d = damage2(p.zy) * w.x + damage2(p.xz) * w.y + damage2(p.xy) * w.z;
		if (d.a > 0.001) {
			col = mix(col, d.rgb / d.a, d.a * (1.0 - damage_seam * seam));
		}
		cover = d.a;
	}
	float ct = ao_contacts ? contact(lp) : 0.0;
	float occ = clamp(1.0 - (ao_seam * seam + ao_contact * ct) * (1.0 - ao_protect * cover), ao_min, 1.0);
	ALBEDO = col * mix(1.0, occ, ao_albedo);
	AO = occ;
	AO_LIGHT_AFFECT = ao_light;
	float r = mix(0.75, 0.45, seam);
	if (relief) {
		r = tri(rough_tex, p, w).r;
		vec3 nl = tri_normal(normalize(ln), p, w, seam);
		NORMAL = normalize((VIEW_MATRIX * (MODEL_MATRIX * vec4(nl, 0.0))).xyz);
	}
	ROUGHNESS = mix(r, 0.9, g);
	vec3 ng = normalize((VIEW_MATRIX * (MODEL_MATRIX * vec4(normalize(ln), 0.0))).xyz);
	float e = 1.0 - clamp(dot(ng, VIEW), 0.0, 1.0);
	vec4 rim = texture(rim_tex, vec2((255.0 * e + 0.5) / 256.0, (rim_row + 0.5) / 8.0));
	float rk = rim.a * rim_k * (1.0 - rim_contact * ct);
	if (zap_t >= 0.0 && zap_t < zap_dur) {
		float zs = sin(PI * zap_t / zap_dur);
		rk *= 1.0 - rim_zap * zs * zs;
	}
	vec3 emit = rim.rgb * rk;
	if (zap_t >= 0.0 && zap_t < zap_dur) {
		float d = (lp.z - (zap_from + zap_speed * zap_t)) / zap_width;
		float env = exp(-d * d) * (1.0 - zap_t / zap_dur);
		if (env > 0.002) {
			float f = zap_lite ? 0.0 : min(floor(zap_t * zap_fps), 7.0);
			float a = arc_at(lp.z, lp.y, zap_t, f) * (w.x + w.z) + arc_at(lp.z, lp.x, zap_t, f) * w.y;
			float core = smoothstep(0.55, 0.95, a);
			float halo = smoothstep(0.03, 0.45, a);
			emit += (zap_core_color * core * zap_core + zap_halo_color * (halo * 1.2 + seam * zap_seam)) * env;
		}
	}
	EMISSION = emit;
	METALLIC = 0.3 * (1.0 - g);
}
