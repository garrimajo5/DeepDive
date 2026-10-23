shader_type spatial;
// РћР±С€РёРІРєР° В«РљРѕРІС‡РµРіР°-7В» РїРѕ ART-024 (docs/concept-art/obshivka.md): С†РІРµС‚, РјР°СЃРєР° Рё РѕР±СЂР°СЃС‚Р°РЅРёРµ вЂ” С‚СЂРёРїР»Р°РЅР°СЂРЅРѕ
// РІ РѕСЃСЏС… РєРѕСЂР°Р±Р»СЏ (РІРµСЂС€РёРЅС‹ РјРµС€Р° вЂ” Р»РѕРєР°Р»СЊРЅС‹Рµ РјРµС‚СЂС‹), РѕРґРЅРё РІРµСЃР° РґР»СЏ РІСЃРµС… С‚СЂС‘С… РєР°СЂС‚, РїР»РёС‚РєР° 2 Рј.
// РњР°СЃРєР° Р»РёРЅРµР№РЅР°СЏ: 0 вЂ” РјРµС‚Р°Р»Р», 128 вЂ” РїСЏС‚РЅР°, 255 вЂ” С€РІС‹ Рё РєСЂРµРїС‘Р¶ (С‚РµРјРЅРµРµ, СЃ Р±Р»РµСЃРєРѕРј).
// РћР±СЂР°СЃС‚Р°РЅРёРµ вЂ” РїРѕ Р»РѕРєР°Р»СЊРЅРѕР№ РІС‹СЃРѕС‚Рµ h (0 Сѓ РєРёР»СЏ, 1 Сѓ РІРµСЂС…Р°), С€РІС‹ РІРёРґРЅС‹ РїРѕРІРµСЂС…. Р§РёСЃР»Р° вЂ” HullMesh.
// РЎР»РµРґС‹ РїРѕРІСЂРµР¶РґРµРЅРёР№ ART-049 (povrezhdeniya.md): РїРѕСЂРѕРі СЃСЂР°РІРЅРёРІР°РµС‚СЃСЏ РЅР° РєР°Р¶РґРѕР№ РїР»РѕСЃРєРѕСЃС‚Рё РѕС‚РґРµР»СЊРЅРѕ (wear вЂ” РїРѕС‚РµСЂСЏ
// РєРѕСЂРїСѓСЃР° 0вЂ¦1, HullMesh.wear), СЃРјРµС€РёРІР°СЋС‚СЃСЏ СѓР¶Рµ РІРёРґРёРјС‹Рµ СЃР»РµРґС‹; РїРѕРІРµСЂС… РѕР±СЂР°СЃС‚Р°РЅРёСЏ, РЅР° С€РІР°С… СЃР»Р°Р±РµРµ.
// РџСЂРѕС‚РёРІ РїРѕРІС‚РѕСЂР° РїР»РёС‚РєРё (#406): РґРІР° СЃР»РѕСЏ СЃР»РµРґРѕРІ вЂ” РєР°Рє РµСЃС‚СЊ Рё РїРѕРІС‘СЂРЅСѓС‚С‹Р№, РєСЂСѓРїРЅРµРµ, СЃРѕ СЃРґРІРёРіРѕРј; СЃР»РѕР№ РІС‹Р±РёСЂР°РµС‚
// РїР»Р°РІРЅС‹Р№ С€СѓРј РїРѕ РїР»РѕСЃРєРѕСЃС‚Рё (HullMesh.damage_gate), СЃР»РѕРё РґРѕРїРѕР»РЅСЏСЋС‚ РґСЂСѓРі РґСЂСѓРіР°.
// Р РµР»СЊРµС„ ART-053 (obshivka-normali.md): РЅРѕСЂРјР°Р»Рё ART-024 Рё СЃР»РµРґРѕРІ ART-049 вЂ” OpenGL (+Y РІРІРµСЂС… РїРѕ РєР°СЂС‚РёРЅРєРµ, Р° v РёРґС‘С‚
// РІРЅРёР·, РїРѕСЌС‚РѕРјСѓ y РјРµРЅСЏРµС‚ Р·РЅР°Рє), РєР°Р¶РґР°СЏ РїР»РѕСЃРєРѕСЃС‚СЊ РІ СЃРІРѕС‘Рј Р±Р°Р·РёСЃРµ (whiteout), СЃР»РµРґ СЃРІРѕРґРёС‚СЃСЏ СЃ РѕСЃРЅРѕРІРѕР№ RNM РїРѕ РІРµСЃСѓ
// С†РІРµС‚Р° СЃР»РµРґР°; С€РµСЂРѕС…РѕРІР°С‚РѕСЃС‚СЊ вЂ” РёР· РєР°СЂС‚С‹. relief = false (В«Р­РєРѕРЅРѕРјРЅРѕВ») вЂ” Р±РµР· РІС‹Р±РѕСЂРѕРє СЂРµР»СЊРµС„Р°, РїСЂРµР¶РЅРёРµ РєРѕРЅСЃС‚Р°РЅС‚С‹.
// РўР° Р¶Рµ РјР°С‚РµРјР°С‚РёРєР° вЂ” HullMesh.decode_normal / plane_normal / rnm / alt_back (С‚РµСЃС‚ test_hull_view).

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

uniform sampler2D arcs : repeat_disable, filter_linear;
uniform float age=0.0;
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

// РЎР»РµРґ РѕРґРЅРѕР№ РїР»РѕСЃРєРѕСЃС‚Рё: rgb вЂ” С†РІРµС‚ В· Р°Р»СЊС„Р°, a вЂ” Р°Р»СЊС„Р° (0, РµСЃР»Рё РїРѕСЂРѕРі РµС‰С‘ РЅРµ РїСЂРѕР№РґРµРЅ).
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

// РЎР»РµРґС‹ РѕРґРЅРѕР№ РїР»РѕСЃРєРѕСЃС‚Рё РёР· РґРІСѓС… СЃР»РѕС‘РІ: СЃР»РѕР№ РїРѕ С€СѓРјСѓ, РІС‚РѕСЂРѕР№ вЂ” РїРѕРІС‘СЂРЅСѓС‚С‹Р№, РєСЂСѓРїРЅРµРµ Рё СЃРѕ СЃРґРІРёРіРѕРј.
vec4 damage2(vec2 uv) {
	float k = smoothstep(gate_edge.x, gate_edge.y, gate_noise(uv));
	return damage(uv) * k + damage(vec2(-uv.y, uv.x) * alt_scale + alt_shift) * (1.0 - k);
}

// РќРѕСЂРјР°Р»СЊ РєР°СЂС‚С‹ РІ РѕСЃСЏС… РїР»РёС‚РєРё: x вЂ” РІРґРѕР»СЊ u, y вЂ” РІРґРѕР»СЊ v, z вЂ” РѕС‚ РїРѕРІРµСЂС…РЅРѕСЃС‚Рё.
vec3 decode_n(vec4 c) {
	vec3 d = c.rgb * 2.0 - 1.0;
	return vec3(d.x, -d.y, d.z);
}

// РќРѕСЂРјР°Р»СЊ РІС‚РѕСЂРѕРіРѕ СЃР»РѕСЏ СЃР»РµРґРѕРІ (РєРѕРѕСЂРґРёРЅР°С‚С‹ РїРѕРІС‘СЂРЅСѓС‚С‹ РЅР° 90В°) вЂ” РѕР±СЂР°С‚РЅРѕ РІ РѕСЃРё РїР»РёС‚РєРё.
vec3 alt_back(vec3 t) {
	return vec3(t.y, -t.x, t.z);
}

// РЎРІРµСЃС‚Рё РґРµС‚Р°Р»СЊ d СЃ РѕСЃРЅРѕРІРѕР№ b (reoriented normal mapping), РѕР±Рµ вЂ” РІ РѕСЃСЏС… РїР»РёС‚РєРё.
vec3 rnm(vec3 b, vec3 d) {
	vec3 t = b + vec3(0.0, 0.0, 1.0);
	vec3 u = d * vec3(-1.0, -1.0, 1.0);
	return normalize(t * dot(t, u) / t.z - u);
}

// РќРѕСЂРјР°Р»СЊ СЃР»РµРґРѕРІ РѕРґРЅРѕР№ РїР»РѕСЃРєРѕСЃС‚Рё (РґРІР° СЃР»РѕСЏ, РєР°Рє damage2), xyz вЂ” РЅРѕСЂРјР°Р»СЊ, w вЂ” РІРµСЃ.
vec4 damage_n(vec2 uv) {
	float k = smoothstep(gate_edge.x, gate_edge.y, gate_noise(uv));
	vec2 uv2 = vec2(-uv.y, uv.x) * alt_scale + alt_shift;
	float a1 = damage(uv).a * k;
	float a2 = damage(uv2).a * (1.0 - k);
	vec3 n = vec3(0.0, 0.0, 1.0) * max(0.0, 1.0 - a1 - a2)
		+ decode_n(texture(damage_nrm, uv)) * a1 + alt_back(decode_n(texture(damage_nrm, uv2))) * a2;
	return vec4(normalize(n), a1 + a2);
}

// РќРѕСЂРјР°Р»СЊ РїР»РёС‚РєРё РїР»РѕСЃРєРѕСЃС‚Рё uv: РѕСЃРЅРѕРІР°, СЃРёР»Р°, СЃР»РµРґ РїРѕРІРµСЂС… РїРѕ РІРµСЃСѓ (РЅР° С€РІР°С… СЃР»Р°Р±РµРµ).
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

// РўСЂРёРїР»Р°РЅР°СЂРЅР°СЏ РЅРѕСЂРјР°Р»СЊ РІ РѕСЃСЏС… РєРѕСЂР°Р±Р»СЏ (whiteout): РїР»РѕСЃРєРѕСЃС‚СЊ zy вЂ” u РїРѕ z, v РїРѕ y; xz вЂ” u РїРѕ x, v РїРѕ z; xy.
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
float on=step(0.0,age)*(1.0-step(0.8,age));
 float frame=min(floor(age*10.0),7.0);
 vec2 q=vec2(fract((lp.z+7.2)/8.0-age*1.5),fract((lp.y+lp.x*0.3)/2.0));
 float arc=texture(arcs,(vec2(mod(frame,4.0),floor(frame/4.0))+q)/vec2(4.0,2.0)).r;
 float front=-7.2+50.0*age;
 float envelope=exp(-pow((lp.z-front)/7.0,2.0))*(1.0-age/0.8)*on;
 EMISSION+=mix(vec3(0.13,0.72,0.83),vec3(0.11,0.89,0.68),arc)*envelope*(arc*3.0+seam*0.20);
}
