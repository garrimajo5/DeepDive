shader_type spatial;
// Дно отмели (OceanView.seabed, Seabed): база — цвет вершин (Seabed.color_at), поверх — процедурная «текстура»
// мельче сетки 5 м: пятна осадка, зерно, рябь песка на плоском дне, скальные прожилки на склонах, лёгкий
// микрорельеф под светом сквозь лёд. Без текстурных файлов, Compatibility (ES3), 1 вызов отрисовки (тот же меш).
render_mode cull_back;

uniform float detail = 0.5;    // частота мелкого рисунка, 1/м
uniform float mottle = 0.16;   // сила пятен осадка
uniform float grain = 0.08;    // сила зерна
uniform float ripple = 0.55;   // рябь песка на плоском дне
uniform float bump = 0.5;      // сила микрорельефа (возмущение нормали)
uniform float fade_m = 85.0;   // дальность, за которой мелкий рисунок гаснет (против ряби пикселей вдали)

// Каустики: движущийся узор преломлённого света сквозь лёд. Силу и свет по глубине ставит OceanView.
uniform float caustic = 0.0;            // общая сила (0 — выкл; уровень графики/OceanView)
uniform float light = 1.0;              // сколько света сквозь лёд дошло до дна (по глубине, с учётом ила)
uniform float caustic_scale = 0.16;     // 1/м, крупные ячейки света
uniform float caustic_speed = 0.32;     // скорость дрожания узора
uniform vec3 caustic_tint : source_color = vec3(0.60, 0.85, 0.91);  // холодный свет сквозь лёд (#9AD9E8)

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

	float mo = fbm(p * detail) - 0.5;                                              // пятна осадка
	float gr = (vnoise(p * detail * 7.0) - 0.5) * fade;                            // зерно (гаснет вдали)
	float rip = sin(p.x * detail * 3.0 + fbm(p * 0.25) * 6.2832) * flat_k * fade;  // рябь на плоском
	float streak = (fbm(vec2(p.x * 0.35, p.y * 1.1)) - 0.5) * slope;               // прожилки на склоне

	float shade = 1.0 + mo * mottle + gr * grain + rip * ripple * 0.12 + streak * 0.2;
	ALBEDO = base * clamp(shade, 0.55, 1.35);
	ROUGHNESS = 1.0;   // матовый песок
	SPECULAR = 0.1;

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
		ALBEDO += caustic_tint * c * cmask * 0.45;
		EMISSION += caustic_tint * c * cmask * 0.22;         // ядра нитей ловят bloom, но мягко
	}

	// микрорельеф: нормаль из градиента шума, в мировых осях → в видовые (у меша нет тангентов для NORMAL_MAP)
	float e = 0.6;
	float b0 = vnoise(p * detail * 2.0);
	float bx = vnoise((p + vec2(e, 0.0)) * detail * 2.0);
	float bz = vnoise((p + vec2(0.0, e)) * detail * 2.0);
	vec3 wn = normalize(w_nrm + vec3(-(bx - b0), 0.0, -(bz - b0)) * bump * fade * 2.0);
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
}
