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

uniform sampler2D color_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D mask_tex : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D growth_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D damage_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D damage_lvl : hint_default_white, filter_nearest, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rough_tex : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform sampler2D damage_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool relief = true;
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
	if (wear > 0.0) {
		vec4 d = damage2(p.zy) * w.x + damage2(p.xz) * w.y + damage2(p.xy) * w.z;
		if (d.a > 0.001) {
			col = mix(col, d.rgb / d.a, d.a * (1.0 - damage_seam * seam));
		}
	}
	ALBEDO = col;
	float r = mix(0.75, 0.45, seam);
	if (relief) {
		r = tri(rough_tex, p, w).r;
		vec3 nl = tri_normal(normalize(ln), p, w, seam);
		NORMAL = normalize((VIEW_MATRIX * (MODEL_MATRIX * vec4(nl, 0.0))).xyz);
	}
	ROUGHNESS = mix(r, 0.9, g);
	METALLIC = 0.3 * (1.0 - g);
}
