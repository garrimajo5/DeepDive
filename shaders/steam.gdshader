// Пар вентиля по ART-071 (`ValveSteam`, `docs/concept-art/par-ventilya.md`): один MultiMesh `SteamView`; тем же
// шейдером — капли, искры и пар износа ART-074 (`WearDrops`, `WearDropsView`, свой атлас). Карточка —
// стоячий билборд (верх кадра — вверх экрана, острый конец к соплу), ширина и высота — масштаб экземпляра по x/y.
// INSTANCE_CUSTOM: r — доля жизни a, g — альфа, b — первый кадр, a — число шагов span + свечение (дробная часть,
// цвет × (1 + доля)). Кадры floor(b + a·span) и следующий (не дальше b + span — не переходя в чужую группу) смешаны
// по возрасту в премультиплированном виде (двойник — ValveSteam.frames), выход — прямая альфа. Неосвещённый, без mipmap.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform, fog_disabled, shadows_disabled;

uniform sampler2D atlas : source_color, filter_linear, repeat_disable;
uniform vec4 tint : source_color = vec4(0.776, 0.839, 0.871, 1.0);   // ValveSteam.tint

varying float v_age;
varying float v_alpha;
varying float v_first;
varying float v_span;
varying float v_glow;

void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;
	vec2 size = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
	vec3 view_center = (VIEW_MATRIX * vec4(center, 1.0)).xyz;
	vec3 up = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	vec3 right = normalize(cross(up, vec3(0.0, 0.0, 1.0)));
	if (length(cross(up, vec3(0.0, 0.0, 1.0))) < 0.05) {   // смотрим отвесно — экранные оси
		right = vec3(1.0, 0.0, 0.0);
		up = vec3(0.0, 1.0, 0.0);
	} else {
		up = cross(vec3(0.0, 0.0, 1.0), right);
	}
	VERTEX = view_center + right * VERTEX.x * size.x + up * VERTEX.y * size.y;
	NORMAL = vec3(0.0, 0.0, 1.0);
	v_age = INSTANCE_CUSTOM.r;
	v_alpha = INSTANCE_CUSTOM.g;
	v_first = INSTANCE_CUSTOM.b;
	v_span = floor(INSTANCE_CUSTOM.a + 1e-3);
	v_glow = max(INSTANCE_CUSTOM.a - v_span, 0.0);
}

vec4 cell(float f, vec2 uv) {
	vec2 c = vec2(mod(f, 4.0), floor(f / 4.0));
	return texture(atlas, (c + clamp(uv, 0.008, 0.992)) * 0.25);
}

void fragment() {
	float last = min(v_first + v_span, 15.0);
	float n = v_first + clamp(v_age, 0.0, 1.0) * v_span;
	float f0 = min(floor(n), last);
	float f1 = min(f0 + 1.0, last);
	float w = smoothstep(0.0, 1.0, fract(n));
	vec4 a = cell(f0, UV);
	vec4 b = cell(f1, UV);
	vec3 pm = mix(a.rgb * a.a, b.rgb * b.a, w);
	float al = mix(a.a, b.a, w);
	ALBEDO = tint.rgb * pm / max(al, 1e-4) * (1.0 + v_glow);
	ALPHA = al * v_alpha;
}
