// Лёд снизу по ART-056 (docs/concept-art/led-snizu.md): плоскость «Лёд» OceanView лицом вниз. Карты textures/ice/
// по world.xz / 16 (цвет sRGB, нормали OpenGL и маска трещин — линейные), сеть трещин светит только там, где её
// открывает крупный мировой шум (как IceSheet.gate — тот же хеш HashNoise), свечение гаснет по глубине наблюдателя.
// Окно Снелля и отражение воды ART-075 (docs/concept-art/led-otrazhenie.md): LUT по косинусу взгляда и глубине, маска
// гладкости по плитке; отражение — в EMISSION, трещины пропускают, ил гасит (≤ 2 выборки, «Экономно» — 1).
// Числа — IceSheet (scripts/core/ice_sheet.gd). Один вызов, тот же меш.
shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

uniform sampler2D color_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D crack_tex : hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 glow_color : source_color = vec3(0.604, 0.851, 0.910);  // #9AD9E8
uniform vec3 water : source_color = vec3(0.1, 0.4, 0.46);            // цвет воды на глубине наблюдателя
uniform float tile = 16.0;
uniform float glow_base = 0.02;
uniform float glow_crack = 0.08;
uniform float glow_gain = 1.0;      // общая сила (уровни ART-044, экспозиция)
uniform float glow_k = 1.0;         // exp(−depth/9) по глубине наблюдателя — ставит OceanView
uniform float contrast = 1.0;       // IceSheet.contrast(depth)
uniform float relief = 0.35;        // IceSheet.relief(depth); 0 — «Экономно», без выборки нормалей
uniform float roughness = 0.62;
uniform float gate_scale = 60.0;
uniform vec2 gate_edge = vec2(0.48, 0.62);
uniform sampler2D reflect_lut : hint_default_black, filter_linear, repeat_disable;   // линейные данные, без mipmap
uniform sampler2D smooth_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float reflect_row = 0.0;    // IceSheet.row(глубина корабля), 0…15
uniform float reflect_gain = 1.0;
uniform float silt_k = 0.0;         // облако ила (Silt.k) — отражения нет
uniform float reflect_lite = 0.0;   // 1 — «Экономно»: маску не читать, гладкость 0,55, доля × 0,55
uniform float crit_cos = 0.6614378; // IceSheet.CRIT_COS
uniform vec2 open_edge = vec2(0.10, 0.55);

#include "res://shaders/water_layers.gdshaderinc"

varying vec3 w_pos;

float hash2(int ix, int iz) {   // HashNoise.hash2: 32-битная арифметика
	uint h = uint(ix) * 374761393u + uint(iz) * 668265263u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h ^= h >> 16u;
	return float(h) / 4294967295.0;
}

float value(vec2 p) {   // HashNoise.value
	vec2 f0 = floor(p);
	ivec2 i = ivec2(f0);
	vec2 f = p - f0;
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash2(i.x, i.y);
	float b = hash2(i.x + 1, i.y);
	float c = hash2(i.x, i.y + 1);
	float d = hash2(i.x + 1, i.y + 1);
	return a + (b - a) * u.x + (c - a) * u.y + (a - b - c + d) * u.x * u.y;
}

float gate(vec2 xz) {   // IceSheet.gate: две октавы HashNoise.fbm
	vec2 p = xz / gate_scale;
	float n = (0.5 * value(p) + 0.25 * value(p * 2.0 + vec2(17.3, -9.1))) / 0.75;
	return smoothstep(gate_edge.x, gate_edge.y, n);
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	FOG = water_layers_fog(CAMERA_POSITION_WORLD, w_pos, -1.0, TIME);   // слои воды ART-069
	vec2 uv = w_pos.xz / tile;
	vec3 c = texture(color_tex, uv).rgb;
	ALBEDO = mix(water, c, contrast);
	ROUGHNESS = roughness;
	METALLIC = 0.0;

	float crack = texture(crack_tex, uv).r;
	float g = gate(w_pos.xz);

	vec3 wn = vec3(0.0, -1.0, 0.0);
	if (relief > 0.001) {
		// мировой базис нижней стороны: T = +X (растёт u), B = −Z (верх картинки), N = −Y (лицом вниз)
		vec3 n = texture(normal_tex, uv).rgb * 2.0 - 1.0;
		n.xy *= relief;
		wn = normalize(n.x * vec3(1.0, 0.0, 0.0) + n.y * vec3(0.0, 0.0, -1.0) + n.z * vec3(0.0, -1.0, 0.0));
		NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	}

	// ART-075: окно Снелля и отражение воды (IceSheet.lookup / mirror)
	float mu = clamp(dot(wn, normalize(CAMERA_POSITION_WORLD - w_pos)), 0.0, 1.0);
	float smooth_k = reflect_lite > 0.5 ? 0.55 : texture(smooth_tex, uv).r;
	float lookup = clamp(crit_cos + (mu - crit_cos) * mix(0.35, 1.0, smooth_k), 0.0, 1.0);
	vec4 mirror = texture(reflect_lut, vec2((255.0 * lookup + 0.5) / 256.0, (reflect_row + 0.5) / 16.0));
	float open = smoothstep(open_edge.x, open_edge.y, crack * g);
	float a = mirror.a * (0.30 + 0.70 * smooth_k) * (1.0 - open) * reflect_gain * (1.0 - clamp(silt_k, 0.0, 1.0));
	if (reflect_lite > 0.5) {
		a *= 0.55;
	}
	ALBEDO *= 1.0 - a;
	EMISSION = glow_color * (glow_base * (1.0 - a) + glow_crack * crack * g) * glow_k * glow_gain + mirror.rgb * a;
	ROUGHNESS = mix(roughness, 0.20, a * smooth_k);
}
