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

	// микрорельеф: нормаль из градиента шума, в мировых осях → в видовые (у меша нет тангентов для NORMAL_MAP)
	float e = 0.6;
	float b0 = vnoise(p * detail * 2.0);
	float bx = vnoise((p + vec2(e, 0.0)) * detail * 2.0);
	float bz = vnoise((p + vec2(0.0, e)) * detail * 2.0);
	vec3 wn = normalize(w_nrm + vec3(-(bx - b0), 0.0, -(bz - b0)) * bump * fade * 2.0);
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
}
