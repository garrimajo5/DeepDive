// След винтов и выпуски при всплытии по ART-063 (`Wake`, `docs/concept-art/sled-vintov.md`): один MultiMesh
// `WakeView`. Карточка-билборд с ячейкой атласа 4×4; размер — масштаб экземпляра, INSTANCE_CUSTOM:
// r — ячейка / 16, g — видимость 0…1, b — угол поворота / 2π. Альфа-смешение, без эмиссии и теней; свет — от
// окружающего и прожектора: без света пузыри темнеют. Туман — как у всей сцены.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform, specular_disabled;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(0.835, 0.894, 0.910, 1.0);
uniform float opacity = 0.85;
uniform float lite = 0.0;          // «Экономно»: только ячейки 0–11 (выбирает `Wake`), здесь — запасной предел

varying vec2 v_cell;
varying float v_fade;

void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;
	float size = length(MODEL_MATRIX[0].xyz);
	float ang = INSTANCE_CUSTOM.b * 6.2832;
	float c = cos(ang), s = sin(ang);
	vec2 corner = mat2(vec2(c, s), vec2(-s, c)) * (VERTEX.xy * size);
	vec3 view_center = (VIEW_MATRIX * vec4(center, 1.0)).xyz;
	VERTEX = view_center + vec3(corner, 0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
	int cell = clamp(int(round(INSTANCE_CUSTOM.r * 16.0)), 0, lite > 0.5 ? 11 : 15);
	v_cell = vec2(float(cell % 4), float(cell / 4));
	// у самой камеры гаснут — не лезут в объектив облёта
	v_fade = INSTANCE_CUSTOM.g * smoothstep(0.4, 1.4, length(view_center));
}

void fragment() {
	vec2 uv = (v_cell + clamp(UV, 0.0, 1.0)) * 0.25;
	// mip не выше 3 (ячейка 16²) — соседние ячейки не смешиваются
	vec2 px = uv * vec2(textureSize(atlas, 0));
	float lod = clamp(log2(max(length(dFdx(px)), length(dFdy(px)))), 0.0, 3.0);
	float a = textureLod(atlas, uv, lod).a;
	ALBEDO = tint.rgb;
	ALPHA = a * opacity * v_fade;
	ROUGHNESS = 1.0;
}
