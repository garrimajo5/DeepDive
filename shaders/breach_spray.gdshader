// Частицы пробоины по ART-072 (`BreachSpray`, `docs/concept-art/proboina-chastitsy.md`): три MultiMesh `BreachView`
// (струя, брызги, искры с электродом) с этим общим материалом. Карточка вытянута по экранной проекции вектора
// MODEL_MATRIX[1] (направление и длина — скорость частицы или «вверх» у брызг), ширина — длина MODEL_MATRIX[0].
// Смотрит на камеру торцом (струя с поста) — короче и шире, чтобы не рассыпаться пунктиром.
// INSTANCE_CUSTOM: r — дробный кадр, g — альфа, b — последний кадр группы, a — 0 вода, 1…2 — искра (1 + остывание),
// 3 — вспышка электрода. Искры — тон от `core` к `cool`, яркость `BreachSpray.spark_lit` (по issue #530).
// Соседние кадры смешаны в премультиплированном виде, выход — прямая альфа. Неосвещённый, без mipmap.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform, fog_disabled, shadows_disabled;

uniform sampler2D atlas : source_color, filter_linear, repeat_disable;
uniform vec4 water : source_color = vec4(0.753, 0.882, 0.922, 1.0);   // BreachSpray.WATER × свет отсека
uniform vec4 hot : source_color = vec4(1.0, 0.949, 0.835, 1.0);       // BreachSpray.HOT — вспышка электрода
uniform vec4 core : source_color = vec4(1.0, 0.659, 0.302, 1.0);      // BreachSpray.CORE
uniform float cap = 1.25;                                             // BreachSpray.SPARK_CAP
uniform vec4 cool : source_color = vec4(0.945, 0.541, 0.239, 1.0);    // BreachSpray.COOL
uniform float glow = 1.5;                                             // BreachSpray.GLOW

varying vec4 v_data;

void vertex() {
	vec3 center = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	float width = length(MODEL_MATRIX[0].xyz);
	vec3 dv = (VIEW_MATRIX * vec4(MODEL_MATRIX[1].xyz, 0.0)).xyz;
	float len = max(length(dv), 1e-5);
	float side = length(dv.xy) / len;   // 1 — сбоку, 0 — торцом к камере
	vec3 up = side > 1e-3 ? vec3(normalize(dv.xy), 0.0) : vec3(0.0, 1.0, 0.0);
	vec3 right = vec3(up.y, -up.x, 0.0);
	float w = width * (1.0 + 3.0 * (1.0 - side));
	float h = len * max(side, 0.35);
	VERTEX = center + right * VERTEX.x * w + up * VERTEX.y * h;
	NORMAL = vec3(0.0, 0.0, 1.0);
	v_data = INSTANCE_CUSTOM;
}

vec4 cell(float f, vec2 uv) {
	vec2 c = vec2(mod(f, 4.0), floor(f / 4.0));
	return texture(atlas, (c + clamp(uv, 0.008, 0.992)) * 0.25);
}

void fragment() {
	float f0 = floor(v_data.r + 1e-4);
	float f1 = min(f0 + 1.0, v_data.b);
	float w = smoothstep(0.0, 1.0, v_data.r - f0);
	vec4 a = cell(f0, UV);
	vec4 b = cell(f1, UV);
	vec3 pm = mix(a.rgb * a.a, b.rgb * b.a, w);
	float al = mix(a.a, b.a, w);
	vec3 base = pm / max(al, 1e-4);
	vec3 col = water.rgb;
	if (v_data.a > 2.5) {
		col = hot.rgb * glow;
	} else if (v_data.a > 0.5) {
		vec3 c = mix(core.rgb, cool.rgb, clamp(v_data.a - 1.0, 0.0, 1.0));
		col = c * min(glow, cap / max(max(c.r, c.g), max(c.b, 1e-4)));
	}
	ALBEDO = col * base;
	ALPHA = al * v_data.g;
}
