// Лучи света сквозь трещины льда (ART-052, docs/concept-art/luchi.md). Один MultiMesh единичных конусов:
// размеры — INSTANCE_CUSTOM (r_top, r_bot, length, phase), цвет экземпляра — (power, floor_y / −100).
// Числа — LightShafts (scripts/core/light_shafts.gd). Свет складывается с водой, глубина не пишется.
// Туман считаем сами (exp по плотности тумана сцены): встроенный туман подмешал бы цвет воды в сложение.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_default, fog_disabled, shadows_disabled;

uniform sampler2D mask_tex : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec3 shaft_color = vec3(0.604, 0.851, 0.910);   // #9AD9E8
uniform vec3 ice_color = vec3(0.525, 0.737, 0.796);     // #86BCCB
uniform float gain = 1.0;            // общая сила (LightShafts.GAIN): экспозиция, уровни ART-044
uniform float ice_y = 0.0;
uniform float depth_scale = 9.0;     // спад силы по глубине точки, м (LightShafts.DEPTH_SCALE)
uniform float fog_density = 0.02;    // плотность тумана сцены (OceanView.apply_water)
uniform float flow = 0.008;          // течение нитей, UV/с
uniform vec2 far_fade = vec2(45.0, 95.0);
uniform vec2 near_fade = vec2(0.5, 1.5);
uniform float floor_fade = 3.0;
uniform float soft = 1.5;            // мягкое касание дна, льда и корпуса по глубине кадра
uniform mat4 ship_inv;               // мир → оси корабля: внутри корпуса шахты нет
uniform vec4 ship_shape = vec4(6.8, 3.4, -7.4, 29.5);  // полуширина, полувысота, нос, корма
uniform float ship_center_y = 1.6;

varying vec3 v_world;
varying float v_power;
varying float v_floor;
varying float v_phase;

void vertex() {
	float rt = INSTANCE_CUSTOM.r;
	float rb = INSTANCE_CUSTOM.g;
	float len = INSTANCE_CUSTOM.b;
	float t = -VERTEX.y;
	vec2 ring = VERTEX.xz;
	float r = mix(rt, rb, t);
	VERTEX = vec3(ring.x * r, -t * len, ring.y * r);
	NORMAL = normalize(vec3(ring.x * len, rb - rt, ring.y * len));
	v_power = COLOR.r;
	v_floor = -COLOR.g * 100.0;
	v_phase = INSTANCE_CUSTOM.a;
	// дальние шахты сжимаем в точку — не тратим на них растеризацию
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	if (length(origin.xz - cam.xz) > far_fade.y + len) {
		VERTEX = vec3(0.0);
	}
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float depth = max(ice_y - v_world.y, 0.0);
	float dist = length(VERTEX);
	float k = 0.14 * exp(-depth / depth_scale);
	k *= 1.0 - smoothstep(far_fade.x, far_fade.y, dist);
	k *= smoothstep(near_fade.x, near_fade.y, dist);
	k *= smoothstep(v_floor, v_floor + floor_fade, v_world.y);
	k *= exp(-fog_density * dist);

	// поперёк видимой ширины: у силуэта стенка видна с ребра — профиль маски гасит край
	float ndv = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float across = sqrt(1.0 - ndv * ndv);
	float mask = texture(mask_tex, vec2(0.5 + 0.5 * across, UV.y)).r;
	float n1 = texture(noise_tex, vec2(UV.x * 3.0, UV.y * 1.6 - TIME * flow + v_phase)).r;
	float n2 = texture(noise_tex, vec2(UV.x * 5.0 + v_phase, UV.y * 0.7 - TIME * flow * 0.6)).r;
	k *= mask * (0.7 + 0.6 * (n1 + n2) * 0.5);

	// внутри корпуса корабля шахты нет (вид с мостика и из отсеков)
	vec3 sl = (ship_inv * vec4(v_world, 1.0)).xyz;
	vec2 e = vec2(sl.x / ship_shape.x, (sl.y - ship_center_y) / ship_shape.y);
	if (dot(e, e) < 1.0 && sl.z > ship_shape.z && sl.z < ship_shape.w) {
		k = 0.0;
	}

	// мягкое касание с непрозрачным (дно, лёд, корпус)
	float raw = texture(depth_tex, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, raw) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw);
#endif
	vec4 sv = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	sv.xyz /= sv.w;
	k *= smoothstep(0.0, soft, VERTEX.z - sv.z);

	vec3 col = mix(ice_color, shaft_color, smoothstep(0.0, 0.15, UV.y));
	ALBEDO = col * k * v_power * gain;
}
