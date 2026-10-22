shader_type spatial;
// Обшивка «Ковчега-7» по ART-024 (docs/concept-art/obshivka.md): цвет, маска и обрастание — трипланарно
// в осях корабля (вершины меша — локальные метры), одни веса для всех трёх карт, плитка 2 м.
// Маска линейная: 0 — металл, 128 — пятна, 255 — швы и крепёж (темнее, с блеском).
// Обрастание — по локальной высоте h (0 у киля, 1 у верха), швы видны поверх. Числа — HullMesh.
// Следы повреждений ART-049 (povrezhdeniya.md): порог сравнивается на каждой плоскости отдельно (wear — потеря
// корпуса 0…1, HullMesh.wear), смешиваются уже видимые следы; поверх обрастания, на швах слабее.

uniform sampler2D color_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D mask_tex : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D growth_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D damage_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D damage_lvl : hint_default_white, filter_nearest, repeat_enable;
uniform float wear = 0.0;
uniform float damage_seam = 0.55;
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
		vec4 d = damage(p.zy) * w.x + damage(p.xz) * w.y + damage(p.xy) * w.z;
		if (d.a > 0.001) {
			col = mix(col, d.rgb / d.a, d.a * (1.0 - damage_seam * seam));
		}
	}
	ALBEDO = col;
	ROUGHNESS = mix(mix(0.75, 0.45, seam), 0.9, g);
	METALLIC = 0.3 * (1.0 - g);
}
