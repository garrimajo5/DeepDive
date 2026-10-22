// Взвесь за бортом по ART-058 (`MarineSnow`, `docs/concept-art/vzves.md`): частицы CPUParticles3D «Морской снег».
// Одна частица — карточка-билборд с ячейкой атласа 4×4. Случайное r = INSTANCE_CUSTOM.z (смещение анимации 0…1)
// выбирает ячейку по долям (cdf), размер, скорость и вращение; INSTANCE_CUSTOM.y — доля жизни.
// Свет — только отражённый (прожектор, свет сквозь лёд): без света взвесь темнеет. Своего свечения нет.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform, specular_disabled;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(0.835, 0.894, 0.910, 1.0);
uniform float opacity = 0.9;
uniform float cdf[15];
uniform float lifetime = 15.0;
uniform float spin_k = 1.0;       // «Экономно» — 0: без вращения
uniform vec2 near_fade = vec2(0.5, 1.5);
uniform float screen_h = 720.0;    // высота кадра, px (VIEWPORT_SIZE в вершинах Compatibility пустой) — ставит OceanView
uniform float min_px = 2.0;       // карточка не мельче 2 px: дальняя частица — бледная точка, а не пропавший треугольник
uniform mat4 ship_inv;            // мир → оси корабля: внутри корпуса взвеси нет
uniform vec4 ship_shape = vec4(6.8, 3.4, -7.4, 29.5);
uniform float ship_center_y = 1.6;

varying vec2 v_cell;
varying float v_fade;

float hash(float x) {
	return fract(sin(x * 91.3458) * 47453.5453);
}

void vertex() {
	float r = INSTANCE_CUSTOM.z;
	int cell = 14;
	for (int i = 0; i < 15; i++) {
		if (r < cdf[i]) {
			cell = i;
			break;
		}
	}
	float h1 = hash(r + 0.17);
	float h2 = hash(r + 3.71);
	float h3 = hash(r + 7.29);
	float h4 = hash(r + 11.53);
	float phase = INSTANCE_CUSTOM.y;
	float age = phase * lifetime;

	// семья: форма (м), доля формы в карточке, скорость по вертикали, вращение
	vec2 form; float card; vec2 vy; vec2 spin; float sway = 0.0;
	vec3 drift = vec3(0.0);
	if (cell <= 5) {          // хлопья: оседают, медленно вращаются
		form = vec2(0.025, 0.07); card = 0.78; vy = vec2(-0.06, -0.02); spin = vec2(2.0, 8.0);
	} else if (cell <= 8) {   // нити: почти висят, качаются
		form = vec2(0.05, 0.12); card = 0.84; vy = vec2(-0.03, 0.0); spin = vec2(0.0); sway = mix(4.0, 10.0, h3);
	} else if (cell <= 11) {  // пыль: дрейф в любую сторону 0,01…0,06 м/с
		form = vec2(0.008, 0.018); card = 0.55; vy = vec2(0.0); spin = vec2(0.0);
		float a = h3 * 6.2832;
		float s = mix(0.01, 0.06, h4);
		drift = vec3(cos(a) * s, (h2 - 0.5) * 2.0 * s, sin(a) * s);
	} else {                  // пузыри: всплывают
		form = vec2(0.015, 0.05); card = 0.78; vy = vec2(0.10, 0.25); spin = vec2(0.0);
	}
	float size = mix(form.x, form.y, h1) / card;
	vec3 vel = vec3(0.0, mix(vy.x, vy.y, h2), 0.0) + drift;
	vec3 center = MODEL_MATRIX[3].xyz + vel * age;

	float ang = h4 * 6.2832 + radians(mix(spin.x, spin.y, h3)) * age * spin_k * sign(h1 - 0.5);
	ang += radians(sway) * sin(age * 1.3 + h4 * 6.2832) * spin_k;
	float c = cos(ang), s = sin(ang);
	vec2 corner = mat2(vec2(c, s), vec2(-s, c)) * (VERTEX.xy * size);

	vec3 view_center = (VIEW_MATRIX * vec4(center, 1.0)).xyz;
	// мельче min_px карточка выпала бы между пикселями: держим размер, а прозрачность гасим по площади
	vec4 c0 = PROJECTION_MATRIX * vec4(view_center, 1.0);
	vec4 c1 = PROJECTION_MATRIX * vec4(view_center + vec3(0.0, size, 0.0), 1.0);
	float px = abs(c1.y / max(c1.w, 1e-4) - c0.y / max(c0.w, 1e-4)) * 0.5 * screen_h;
	float grow = clamp(min_px / max(px, 1e-4), 1.0, 12.0);   // предел: дальние не раздувать в пятна
	corner *= grow;
	VERTEX = view_center + vec3(corner, 0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);

	v_cell = vec2(float(cell % 4), float(cell / 4));
	float life = smoothstep(0.0, 0.12, phase) * (1.0 - smoothstep(0.85, 1.0, phase));
	v_fade = life * smoothstep(near_fade.x, near_fade.y, length(view_center)) / grow;
	vec3 sl = (ship_inv * vec4(center, 1.0)).xyz;
	vec2 e = vec2(sl.x / ship_shape.x, (sl.y - ship_center_y) / ship_shape.y);
	if (dot(e, e) < 1.0 && sl.z > ship_shape.z && sl.z < ship_shape.w) {
		v_fade = 0.0;
	}
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
