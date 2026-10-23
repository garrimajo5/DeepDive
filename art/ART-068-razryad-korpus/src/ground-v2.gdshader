shader_type spatial;
// Дно отмели (OceanView.seabed, Seabed): база — цвет вершин (Seabed.color_at), поверх — процедурная «текстура»
// мельче сетки 5 м: пятна осадка, зерно, рябь песка на плоском дне, скальные прожилки на склонах, лёгкий
// микрорельеф под светом сквозь лёд; вблизи — грунты ART-060 (песок, ил, галька: цвет, нормали, ORM по world.xz / 2,
// веса и затухания — Seabed.Ground); декали ART-066 — Seabed.Marks. 1 вызов отрисовки (тот же меш).
render_mode cull_back;

uniform float detail = 0.5;    // частота мелкого рисунка, 1/м
uniform float mottle = 0.16;   // сила пятен осадка
uniform float bump = 0.12;     // сила процедурного микрорельефа (ART-060: карты грунтов дают мелкое, этот — ослаблен)
uniform float fade_m = 85.0;   // дальность, за которой крупный процедурный рисунок гаснет

// Грунты ART-060: карты — данные без sRGB (цвет — отклонение от 50 % серого). Числа — Seabed.Ground.
uniform sampler2D sand_tsvet : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_normali : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_orm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D silt_tsvet : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D silt_normali : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D silt_orm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pebble_tsvet : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pebble_normali : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pebble_orm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float ground = 0.0;              // 0 — без карт грунтов (до загрузки), 1 — с картами
uniform float relief = 1.0;              // нормали и ORM грунтов; «Экономно» — 0 (только цвет)
uniform float tile = 2.0;                // м на плитку
uniform vec2 off_silt = vec2(0.37, 0.71);
uniform vec2 off_pebble = vec2(0.63, 0.19);
uniform vec3 normal_k = vec3(0.42, 0.25, 0.55);   // песок, ил, галька
uniform vec2 normal_fade = vec2(8.0, 35.0);
uniform vec2 color_fade = vec2(12.0, 55.0);
uniform float silt_scale = 0.075;
uniform vec2 silt_edge = vec2(0.48, 0.62);
uniform float pebble_scale = 0.11;
uniform vec2 pebble_edge = vec2(0.45, 0.62);
uniform vec2 steep = vec2(0.42, 0.65);

// Каустики: движущийся узор преломлённого света сквозь лёд. Силу и свет по глубине ставит OceanView.
uniform float caustic = 0.0;            // общая сила (0 — выкл; уровень графики/OceanView)
uniform float light = 1.0;              // сколько света сквозь лёд дошло до дна (по глубине, с учётом ила)
uniform float caustic_scale = 0.16;     // 1/м, крупные ячейки света
uniform float caustic_speed = 0.32;     // скорость дрожания узора
uniform vec3 caustic_tint : source_color = vec3(0.60, 0.85, 0.91);  // холодный свет сквозь лёд (#9AD9E8)

// Каустики под трещинами льда (ART-056): та же маска трещин, что у «Льда», сверху — размытая и подвижная,
// и тот же крупный шум открытости сети (IceSheet.gate). Числа — IceSheet.
uniform sampler2D crack_tex : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float ice_tile = 16.0;
uniform float ice_y = 0.0;
uniform float gate_scale = 60.0;
uniform vec2 gate_edge = vec2(0.48, 0.62);
uniform float crack_caustic = 0.06;   // IceSheet.CAUSTIC: свет под трещиной 0,06·exp(−глубина дна / 12)
uniform float crack_depth = 12.0;

// Декали дна ART-066: атлас 4×4 (данные без sRGB, цвет — множитель вокруг серого, альфа — форма), штампы по клеткам
// world.xz в двух слоях; места, категории и затухания — Seabed.Marks (тот же хеш HashNoise.hash2).
uniform sampler2D decal_atlas : hint_default_white, filter_linear_mipmap, repeat_disable;   // без анизотропии: её след под углом залезает в соседнюю ячейку
uniform float decals = 0.0;                  // 0 — без декалей (до загрузки атласа)
uniform float decal_cell = 4.0;
uniform float decal_layers = 2.0;
uniform float decal_accept = 0.72;
uniform vec2 decal_size = vec2(1.55, 2.4);
uniform float decal_jitter = 0.2;
uniform float decal_k = 0.85;
uniform vec2 decal_fade = vec2(10.0, 45.0);
uniform vec2 decal_slope = vec2(0.30, 0.48);
uniform vec2 decal_track_ny = vec2(0.82, 0.96);
uniform vec2 decal_moss = vec2(0.48, 0.68);
uniform float decal_edge = 0.07;           // Seabed.Marks.EDGE

uniform sampler2D event_burn : repeat_disable,filter_linear;
uniform vec2 event_point=vec2(0.0);
varying vec3 w_pos;
varying vec3 w_nrm;

float hash(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.5);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {   // две октавы — дёшево для телефона
	return vnoise(p) * 0.65 + vnoise(p * 2.7 + 7.0) * 0.35;
}

float ice_hash2(int ix, int iz) {   // HashNoise.hash2 (как в ice.gdshader)
	uint h = uint(ix) * 374761393u + uint(iz) * 668265263u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h ^= h >> 16u;
	return float(h) / 4294967295.0;
}

float ice_value(vec2 p) {   // HashNoise.value
	vec2 f0 = floor(p);
	ivec2 i = ivec2(f0);
	vec2 f = p - f0;
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = ice_hash2(i.x, i.y);
	float b = ice_hash2(i.x + 1, i.y);
	float c = ice_hash2(i.x, i.y + 1);
	float d = ice_hash2(i.x + 1, i.y + 1);
	return a + (b - a) * u.x + (c - a) * u.y + (a - b - c + d) * u.x * u.y;
}

float ice_gate(vec2 xz) {   // IceSheet.gate
	vec2 q = xz / gate_scale;
	float n = (0.5 * ice_value(q) + 0.25 * ice_value(q * 2.0 + vec2(17.3, -9.1))) / 0.75;
	return smoothstep(gate_edge.x, gate_edge.y, n);
}

float ice_fbm2(vec2 p) {   // HashNoise.fbm(x, z, 2)
	return (0.5 * ice_value(p) + 0.25 * ice_value(p * 2.0 + vec2(17.3, -9.1))) / 0.75;
}

vec3 ground_weights(vec2 xz, float ny, float depth) {   // Seabed.Ground.weights: песок, ил, галька
	float s = 1.0 - ny;
	float n_silt = ice_fbm2(xz * silt_scale + 7.0);
	float band = smoothstep(10.0, 18.0, depth) * (1.0 - smoothstep(55.0, 75.0, depth));
	float silt = smoothstep(silt_edge.x, silt_edge.y, n_silt) * (0.35 + 0.65 * band) * smoothstep(0.80, 0.98, ny);
	float spot = ice_value(xz * pebble_scale + vec2(31.0, -5.0));
	float slope_band = smoothstep(0.08, 0.16, s) * (1.0 - smoothstep(0.36, 0.46, s));
	float pebble = max(slope_band * smoothstep(0.25, 0.45, spot), 0.7 * smoothstep(pebble_edge.x, pebble_edge.y, spot));
	silt *= 1.0 - pebble;
	return vec3(1.0 - silt - pebble, silt, pebble);
}

float dhash(ivec2 c, int k) {   // Seabed.Marks.h
	return ice_hash2(c.x + 9973 * k, c.y - 7919 * k);
}

// Множитель цвета от штампа клетки слоя (1 — штампа нет). dpx/dpy — производные world.xz (вне ветвлений).
vec3 decal_mul(vec2 p, int layer, vec3 gw, float ny, vec2 dpx, vec2 dpy) {
	float o = layer == 1 ? decal_cell * 0.5 : 0.0;
	vec2 cf = floor((p - o) / decal_cell);
	ivec2 c = ivec2(cf);
	int b = layer * 8;
	if (dhash(c, b) >= decal_accept) {
		return vec3(1.0);
	}
	vec2 centre = (cf + 0.5) * decal_cell + o + (vec2(dhash(c, b + 1), dhash(c, b + 2)) - 0.5) * 2.0 * decal_jitter;
	float rot = dhash(c, b + 3) * 6.2831853;
	float size = mix(decal_size.x, decal_size.y, dhash(c, b + 4));
	mat2 r = mat2(vec2(cos(rot), -sin(rot)), vec2(sin(rot), cos(rot)));
	vec2 st = r * (p - centre) / size + 0.5;
	if (st.x <= 0.0 || st.y <= 0.0 || st.x >= 1.0 || st.y >= 1.0) {
		return vec3(1.0);
	}
	float pick = dhash(c, b + 5);
	float v = dhash(c, b + 6);
	float index;
	float hab;
	if (pick < 0.27) {          // следы — на ровном песке и иле
		index = min(floor(v * 4.0), 3.0);
		hab = (gw.x + gw.y) * smoothstep(decal_track_ny.x, decal_track_ny.y, ny);
	} else if (pick < 0.40) {   // вмятины
		index = 4.0 + min(floor(v * 2.0), 1.0);
		hab = gw.x + gw.y;
	} else if (pick < 0.67) {   // ил
		index = 6.0 + min(floor(v * 3.0), 2.0);
		hab = min(0.3 * gw.x + gw.y, 1.0);
	} else if (pick < 0.85) {   // ракушечник
		index = 9.0 + min(floor(v * 2.0), 1.0);
		hab = min(0.35 * gw.x + gw.z, 1.0);
	} else {                    // выеденный мох — по маске мха
		index = 11.0 + min(floor(v * 2.0), 1.0);
		hab = smoothstep(decal_moss.x, decal_moss.y, ice_value(p * 0.03 + vec2(7.0, 0.0)));
	}
	vec2 uv = (vec2(mod(index, 4.0), floor(index / 4.0)) + st) / 4.0;
	vec4 a = textureGrad(decal_atlas, uv, r * dpx / (size * 4.0), r * dpy / (size * 4.0));
	vec2 e = min(st, 1.0 - st);   // края квадрата гаснут в пустом поле ячейки (20 px из 256): не видно рамки
	float edge = smoothstep(0.0, decal_edge, min(e.x, e.y));
	return mix(vec3(1.0), clamp(2.0 * a.rgb, vec3(0.5), vec3(1.3)), a.a * hab * decal_k * edge);
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = COLOR.rgb;
	vec2 p = w_pos.xz;
	float dist = length(w_pos - CAMERA_POSITION_WORLD);
	float fade = clamp(1.0 - dist / fade_m, 0.0, 1.0);

	float flat_k = smoothstep(0.80, 0.97, w_nrm.y);   // плоское дно (нормаль вверх)
	float slope = 1.0 - flat_k;
	float slope_raw = 1.0 - w_nrm.y;

	float mo = fbm(p * detail) - 0.5;                                              // пятна осадка
	float streak = (fbm(vec2(p.x * 0.35, p.y * 1.1)) - 0.5) * slope;               // прожилки на склоне

	float shade = 1.0 + mo * mottle + streak * 0.2;
	ALBEDO = base * clamp(shade, 0.55, 1.35);
	ROUGHNESS = 1.0;   // матовый песок
	SPECULAR = 0.1;

	// Грунты ART-060: цвет — множитель вокруг серого, гаснет 12…55 м; нормали и ORM — 8…35 м (Seabed.Ground)
	vec3 gn = vec3(0.0);   // смещение нормали в базисе поверхности (x — к +X, y — к −Z)
	float cf = (1.0 - smoothstep(color_fade.x, color_fade.y, dist)) * ground;
	float df = (1.0 - smoothstep(decal_fade.x, decal_fade.y, dist)) * decals
			* (1.0 - smoothstep(decal_slope.x, decal_slope.y, slope_raw));
	vec2 dpx = dFdx(p);
	vec2 dpy = dFdy(p);
	vec3 w = vec3(1.0, 0.0, 0.0);
	if (cf > 0.001 || df > 0.001) {
		w = ground_weights(p, w_nrm.y, max(ice_y - w_pos.y, 0.0));
	}
	if (cf > 0.001) {
		float dk = 1.0 - smoothstep(steep.x, steep.y, slope_raw);
		vec2 uv0 = p / tile;
		vec2 uv1 = uv0 + off_silt;
		vec2 uv2 = uv0 + off_pebble;
		vec3 det = texture(sand_tsvet, uv0).rgb * w.x + texture(silt_tsvet, uv1).rgb * w.y
				+ texture(pebble_tsvet, uv2).rgb * w.z;
		ALBEDO *= mix(vec3(1.0), 2.0 * det, cf * dk);
		float nf = (1.0 - smoothstep(normal_fade.x, normal_fade.y, dist)) * relief * dk * ground;
		if (nf > 0.001) {
			vec2 n0 = texture(sand_normali, uv0).rg * 2.0 - 1.0;
			vec2 n1 = texture(silt_normali, uv1).rg * 2.0 - 1.0;
			vec2 n2 = texture(pebble_normali, uv2).rg * 2.0 - 1.0;
			gn.xy = (n0 * normal_k.x * w.x + n1 * normal_k.y * w.y + n2 * normal_k.z * w.z) * nf;
			vec3 orm = texture(sand_orm, uv0).rgb * w.x + texture(silt_orm, uv1).rgb * w.y
					+ texture(pebble_orm, uv2).rgb * w.z;
			ROUGHNESS = mix(1.0, orm.g, nf);
			AO = mix(1.0, orm.r, nf);
			AO_LIGHT_AFFECT = 0.5;
		}
	}

	// Декали ART-066: следы, вмятины, ил, ракушечник, мох — до каустик, гаснут 10…45 м и на уклоне (Seabed.Marks)
	if (df > 0.001) {
		vec3 dm = decal_mul(p, 0, w, w_nrm.y, dpx, dpy);
		if (decal_layers > 1.5) {
			dm *= decal_mul(p, 1, w, w_nrm.y, dpx, dpy);
		}
		ALBEDO *= mix(vec3(1.0), dm, df);
	}

	// Каустики: две бегущие волны шума дают тонкие яркие нити, фокусируются на плоском дне,
	// гаснут по глубине (light) и вдали (fade). Ядра нитей светятся — ловят bloom.
	if (caustic > 0.001) {
		vec2 cp = p * caustic_scale;
		float t = TIME * caustic_speed;
		float l1 = vnoise(cp + vec2(t, t * 0.6));
		float l2 = vnoise(cp * 1.6 + vec2(-t * 0.8, t * 0.5));
		float l3 = vnoise(cp * 2.3 + vec2(t * 0.4, -t * 0.9));
		float c = abs(l1 - l2) * 0.6 + abs(l2 - l3) * 0.4;   // пересечение волн — тонкая сеть
		c = 1.0 - smoothstep(0.0, 0.16, c);                  // яркие тонкие нити
		c = pow(c, 1.6);
		float cmask = caustic * light * flat_k * fade;
		// под открытыми трещинами льда света больше: маска сверху, размытая (мелкий mip) и дрожащая
		vec2 drift = vec2(sin(t * 0.7), cos(t * 0.53)) * 0.35;
		float under = clamp(textureLod(crack_tex, (p + drift) / ice_tile, 5.0).r * 4.0, 0.0, 1.0) * ice_gate(p);
		cmask *= 0.6 + 0.8 * under;
		float crack_light = crack_caustic * exp(-max(ice_y - w_pos.y, 0.0) / crack_depth) * under * caustic / 0.6;
		ALBEDO += caustic_tint * crack_light * light;
		ALBEDO += caustic_tint * c * cmask * 0.45;
		EMISSION += caustic_tint * c * cmask * 0.22;         // ядра нитей ловят bloom, но мягко
	}

	// микрорельеф: нормаль из градиента шума, в мировых осях → в видовые (у меша нет тангентов для NORMAL_MAP)
	float e = 0.6;
	float b0 = vnoise(p * detail * 2.0);
	float bx = vnoise((p + vec2(e, 0.0)) * detail * 2.0);
	float bz = vnoise((p + vec2(0.0, e)) * detail * 2.0);
	vec3 wn = normalize(w_nrm + vec3(-(bx - b0), 0.0, -(bz - b0)) * bump * fade * 2.0);
	// грунты: мировой базис T = +X на поверхность, B = N × T (на ровном дне к −Z), +Y карты — к −Z мира
	vec3 tn = normalize(vec3(1.0, 0.0, 0.0) - wn * wn.x);
	vec3 bn = cross(wn, tn);
	wn = normalize(wn + tn * gn.x + bn * gn.y);
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
vec2 buv=(w_pos.xz-event_point)/2.4+0.5;
 if(min(buv.x,buv.y)>0.0 && max(buv.x,buv.y)<1.0){
 vec4 b=texture(event_burn,(vec2(1.0,3.0)+buv)/4.0);
 ALBEDO*=mix(vec3(1.0),clamp(2.0*b.rgb,vec3(0.35),vec3(0.65)),b.a*0.95);
 }
}
