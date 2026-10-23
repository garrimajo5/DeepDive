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

uniform sampler2D rim_lut : filter_linear,repeat_disable;
uniform float rim_depth=12.0;
uniform float rim_silt=0.0;
uniform float rim_alive=1.0;
uniform float rim_gain=1.0;
uniform float ao_gain=1.0;
uniform bool rim_eco=false;
uniform bool ao_debug=false;
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

float sd_box(vec3 p, vec3 half_size){
 vec3 q=abs(p)-half_size;
 return length(max(q,vec3(0.0)))+min(max(q.x,max(q.y,q.z)),0.0);
}
float ellipsoid_patch(vec3 p,vec3 center,vec3 radius){
 vec3 q=(p-center)/radius;
 return exp(-dot(q,q));
}
float contact_ao(vec3 p){
 float contact=0.0;
 for(int i=0;i<2;i++){
  float side=i==0 ? -1.0 : 1.0;
  // Engine mount edge, rotor recess, horizontal rudder root.
  float mount=exp(-max(sd_box(p-vec3(side*3.45,1.0,26.3),vec3(.75,.225,.7)),0.0)/.18);
  float rho=length(p.xy-vec2(side*5.4,1.0));
  float recess=(1.0-smoothstep(1.0,1.29,rho))*exp(-pow((p.z-26.5)/.72,2.0));
  float root=ellipsoid_patch(p,vec3(side*3.95,2.6,24.6),vec3(.28,.3,1.0));
  contact=max(contact,max(mount,max(recess,root)));
 }
 contact=max(contact,ellipsoid_patch(p,vec3(0,3.42,25),vec3(.28,.25,1.3)));
 contact=max(contact,ellipsoid_patch(p,vec3(0,-.2,25),vec3(.25,.24,1.1)));
 return clamp(contact,0.0,1.0);
}
float rim_row(float d){
 if(d<8.0)return mix(0.0,1.0,clamp(d/8.0,0.0,1.0));
 if(d<20.0)return mix(1.0,3.0,(d-8.0)/12.0);
 if(d<45.0)return mix(3.0,5.0,(d-20.0)/25.0);
 return mix(5.0,6.0,clamp((d-45.0)/45.0,0.0,1.0));
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
	float damage_cover=0.0;
	if (wear > 0.0) {
		vec4 d = damage2(p.zy) * w.x + damage2(p.xz) * w.y + damage2(p.xy) * w.z;
		damage_cover=d.a*(1.0-damage_seam*seam);
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
	if (zap_t >= 0.0 && zap_t < zap_dur) {
		float d = (lp.z - (zap_from + zap_speed * zap_t)) / zap_width;
		float env = exp(-d * d) * (1.0 - zap_t / zap_dur);
		if (env > 0.002) {
			float f = zap_lite ? 0.0 : min(floor(zap_t * zap_fps), 7.0);
			float a = arc_at(lp.z, lp.y, zap_t, f) * (w.x + w.z) + arc_at(lp.z, lp.x, zap_t, f) * w.y;
			float core = smoothstep(0.55, 0.95, a);
			float halo = smoothstep(0.03, 0.45, a);
			EMISSION = (zap_core_color * core * zap_core + zap_halo_color * (halo * 1.2 + seam * zap_seam)) * env;
		}
	}
	METALLIC = 0.3 * (1.0 - g);

 // ART-076: one new texture sample; AO reuses the existing plate seam mask.
 float contact=0.0;
 if(!rim_eco) contact=contact_ao(lp);
 float occ=clamp(1.0-ao_gain*(0.18*seam+0.34*contact)*(1.0-0.8*damage_cover),0.55,1.0);
 ALBEDO*=mix(1.0,occ,0.55);
 AO=occ;
 AO_LIGHT_AFFECT=0.15;
 // Smooth GEOMETRIC normal, deliberately independent of plate/damage relief.
 vec3 ng=normalize((VIEW_MATRIX*MODEL_MATRIX*vec4(normalize(ln),0.0)).xyz);
 float edge=1.0-clamp(dot(ng,VIEW),0.0,1.0);
 float row=rim_silt>=0.9999 ? 7.0 : rim_row(rim_depth);
 vec4 rim=texture(rim_lut,vec2((255.0*edge+0.5)/256.0,(row+0.5)/8.0));
 float strength=rim.a*rim_gain*rim_alive*(1.0-clamp(rim_silt,0.0,1.0));
 strength*=1.0-0.55*contact;
 if(rim_eco) strength*=0.65;
 float zap_soft=0.0;
 if(zap_t>=0.0 && zap_t<zap_dur) zap_soft=pow(sin(3.14159265*zap_t/zap_dur),2.0);
 strength*=1.0-0.55*zap_soft;
 EMISSION+=rim.rgb*strength;
 if(ao_debug){ALBEDO=vec3(0.0);EMISSION=vec3((occ-0.55)/0.45*0.2);}
}
