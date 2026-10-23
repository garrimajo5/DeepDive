// Пар вентиля по ART-071 (`ValveSteam`, `docs/concept-art/par-ventilya.md`): один MultiMesh `SteamView`. Карточка —
// стоячий билборд (верх кадра — вверх экрана, острый конец к соплу), ширина и высота — масштаб экземпляра по x/y.
// INSTANCE_CUSTOM: r — доля жизни a, g — альфа. Кадры floor(a·15) и следующий смешаны по возрасту в
// премультиплированном виде (двойник — ValveSteam.frames), выход — прямая альфа. Неосвещённый, без mipmap.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform, fog_disabled, shadows_disabled;

uniform sampler2D atlas : source_color, filter_linear, repeat_disable;
uniform vec4 tint : source_color = vec4(0.776, 0.839, 0.871, 1.0);   // ValveSteam.tint

varying float v_age;
varying float v_alpha;

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
}

vec4 cell(float f, vec2 uv) {
	vec2 c = vec2(mod(f, 4.0), floor(f / 4.0));
	return texture(atlas, (c + clamp(uv, 0.008, 0.992)) * 0.25);
}

void fragment() {
	float n = clamp(v_age, 0.0, 1.0) * 15.0;
	float f0 = min(floor(n), 15.0);
	float f1 = min(f0 + 1.0, 15.0);
	float w = smoothstep(0.0, 1.0, fract(n));
	vec4 a = cell(f0, UV);
	vec4 b = cell(f1, UV);
	vec3 pm = mix(a.rgb * a.a, b.rgb * b.a, w);
	float al = mix(a.a, b.a, w);
	ALBEDO = tint.rgb * pm / max(al, 1e-4);
	ALPHA = al * v_alpha;
}
