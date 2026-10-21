class_name EcoShaders
extends RefCounted
## Общие шейдеры живого мира (issue #279). Рендерер Compatibility на каждый новый шейдер собирает ~5 программ — это
## секунды прогрева на телефоне при первом запуске. Поэтому одинаковый код — один ресурс `Shader` (`shader(code)`),
## а похожие материалы видов и мест — один общий код с числами в uniform: камень с обрастанием (`STONE`), мох
## пятнами (`MOSS`), прозрачное без света (`MIST`), светлая точка лицом к камере со сложением цвета (`SPOT`), растения
## со светом (`PLANT`). Новый материал мира — сначала сюда.
## Сколько шейдеров у мира — `tools/shaders.gd`, потолок — `tests/test_eco_shaders.gd`.

## Камень с обрастанием #67DDEB в альфе цвета вершины: раковина древних, кости левиафана, край отмели, порода
## курильщика. `fill` — подсветка камня, `glow_k` — яркость обрастания, `cut` — сколько альбедо гасит свет,
## `flicker` — мерцание жара (EcoVent.flicker, 0 — ровный свет).
const STONE := """
shader_type spatial;
render_mode cull_back;
uniform vec3 growth : source_color;
uniform float fill = 0.3;
uniform float glow_k = 1.4;
uniform float cut = 0.5;
uniform float rough = 0.95;
uniform float spec = 0.15;
uniform float flicker = 0.0;
varying float lit;
void vertex() {
	lit = COLOR.a;
}
void fragment() {
	float f = 0.8 + 0.1 * sin(TIME * 2.3) + 0.06 * sin(TIME * 5.7 + 1.3) + 0.04 * sin(TIME * 13.1 + 0.4);
	ALBEDO = COLOR.rgb * (1.0 - lit * cut);
	ROUGHNESS = rough;
	SPECULAR = spec;
	EMISSION = growth * lit * glow_k * mix(1.0, f, flicker) + COLOR.rgb * (1.0 - lit) * fill;
}
"""

## Мох пятнами: яркость вершины — в COLOR.r, номер пятна — в UV.x, яркость пятна — glow[номер]. Пятен у одного
## меша не больше MOSS_MAX (массив дополняется нулями — `moss_glow`).
const MOSS_MAX := 32
const MOSS := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;
uniform vec3 moss_color : source_color;
uniform float glow[32];
varying float a;
void vertex() {
	a = COLOR.r * glow[int(UV.x + 0.5)];
}
void fragment() {
	ALBEDO = moss_color;
	ALPHA = clamp(a, 0.0, 1.0);
}
"""

## Светлая точка лицом к камере, сложение цвета, без тумана (иначе сложение светит квадратом) — гаснет сама к
## fade_far м. Размер — из масштаба экземпляра. `halo` 0 — пятно (1 − d)² (споры пузырчатки), 1 — ореол
## гребневика: 1 в центре, 0,45 на трети радиуса, 0 на краю (glowTex в браузере).
const SPOT := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform float fade_far = 60.0;
uniform float halo = 0.0;
varying vec3 tint;
void vertex() {
	float far = length((VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz);
	tint = COLOR.rgb * clamp(1.0 - far / fade_far, 0.0, 1.0);
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s,
		MODEL_MATRIX[3]);
}
void fragment() {
	float d = clamp(length(UV - vec2(0.5)) * 2.0, 0.0, 1.0);
	float spot = (1.0 - d) * (1.0 - d);
	float ring = d < 0.35 ? mix(1.0, 0.45, d / 0.35) : mix(0.45, 0.0, (d - 0.35) / 0.65);
	ALBEDO = tint * mix(spot, ring, halo);
}
"""

## Прозрачное без света (смешение по альфе, без записи глубины, обе стороны): один код на купола и щупальца вуалей,
## чернила подушечника, пузыри и марево курильщика, трещину и столб света колодца. Что рисовать — `mode` (Mist), числа
## каждого вида — в своих uniform; формулы — прежние формулы видов. Ветка по uniform одна на весь вызов отрисовки.
enum Mist { BELL, TENTACLE, INK, BUBBLE, HAZE, CRACK, COLUMN }
const MIST := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform int mode = 0;
uniform vec4 tint : source_color = vec4(1.0);
// щупальца: время и пульс купола
uniform float t = 0.0;
uniform float swell = 1.0;
// пузыри
uniform float drift = 0.0;
uniform float size_low = 0.1;
uniform float size_high = 0.2;
// марево
uniform vec3 water : source_color;
uniform vec3 heat : source_color;
// колодец: дыхание яркости и плотность столба
uniform float pulse = 0.0;
uniform float period = 10.0;
uniform float strength = 1.0;
varying vec4 tone;
varying float fade;
varying vec3 wp;
void vertex() {
	tone = COLOR;
	fade = 1.0;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (mode == 1) {
		// щупальца вуали (EcoVeil.tentacle_point): в VERTEX — точка без колыхания, в UV — (щупальце k, точка j)
		float k = UV.x;
		float j = UV.y;
		vec3 p = vec3(VERTEX.x * swell, VERTEX.y, VERTEX.z * swell);
		if (j > 0.5) {
			p.x += sin(t * 0.9 + (j - 1.0) * 0.45 + k) * j * 0.12;
			p.z += cos(t * 0.7 + (j - 1.0) * 0.4 + k * 1.3) * j * 0.12;
		}
		VERTEX = p;
	} else if (mode == 2) {
		// чернила: пятно лицом к камере, размер — из масштаба экземпляра
		float s = length(MODEL_MATRIX[0].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s,
			MODEL_MATRIX[3]);
	} else if (mode == 3) {
		// EcoVent.bubble_pos: скорость, фаза, высота столба, своё число — в INSTANCE_CUSTOM, выход — в экземпляре
		float h = INSTANCE_CUSTOM.b;
		float f = fract(INSTANCE_CUSTOM.g + TIME * INSTANCE_CUSTOM.r / h);
		float sd = INSTANCE_CUSTOM.a * 6.2831853;
		vec3 o = MODEL_MATRIX[3].xyz;
		vec3 p = vec3(o.x + sin(TIME * 0.9 + sd) * drift * f, o.y + f * h, o.z + cos(TIME * 0.7 + sd) * drift * f);
		float size = mix(size_low, size_high, f);
		fade = 0.85 * (1.0 - 0.6 * f) * smoothstep(0.0, 0.03, f) * (1.0 - smoothstep(0.9, 1.0, f));
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * size, INV_VIEW_MATRIX[1] * size,
			INV_VIEW_MATRIX[2] * size, vec4(p, 1.0));
	}
}
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float k = 1.0 + pulse * sin(TAU * TIME / period);
	if (mode == 0) {
		// купол: кромка ярче — по углу к взгляду
		float edge = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
		ALBEDO = tone.rgb;
		ALPHA = clamp(tone.a * (0.55 + 1.3 * edge * edge), 0.0, 1.0);
	} else if (mode == 1) {
		ALBEDO = tint.rgb;
		ALPHA = tint.a;
	} else if (mode == 2) {
		float a = clamp(1.0 - d, 0.0, 1.0);
		ALBEDO = tone.rgb;
		ALPHA = tone.a * a * a;
	} else if (mode == 3) {
		// пузырь: светлый ободок и прозрачная середина
		float ring = (1.0 - smoothstep(0.8, 1.0, d)) * (0.35 + 0.65 * smoothstep(0.45, 0.9, d));
		ALBEDO = tint.rgb;
		ALPHA = fade * ring;
	} else if (mode == 4) {
		// марево: шум из синусов бежит вверх, слабеет вверх и к краям полосы
		float v = 1.0 - UV.y;
		float n = 0.5 + 0.25 * sin(UV.x * 9.0 + UV.y * 23.0 - TIME * 1.3) + 0.25 * sin(UV.x * 17.0 - UV.y * 41.0 - TIME * 2.1);
		float side = smoothstep(0.0, 0.3, UV.x) * smoothstep(1.0, 0.7, UV.x);
		ALBEDO = mix(water, heat, 0.35 * (1.0 - v));
		ALPHA = 0.11 * n * side * pow(1.0 - v, 1.4) * smoothstep(0.0, 0.04, v);
	} else if (mode == 5) {
		// трещина: светлые полосы медленно ползут вдоль неё
		float dr = 0.94 + 0.06 * sin(TIME * 0.35 + dot(wp.xz, vec2(0.45, 0.2)));
		ALBEDO = tone.rgb * k * dr;
		ALPHA = clamp(tone.a, 0.0, 1.0);
	} else {
		// столб света: грань под острым углом к взгляду почти прозрачна, без яркого контура
		float face = abs(dot(normalize(NORMAL), normalize(VIEW)));
		ALBEDO = tone.rgb * k;
		ALPHA = clamp(tone.a * face * face * strength * k, 0.0, 1.0);
	}
}
"""

## Растения на дне со светом (обе стороны): ленты ленточника, листья волнолиста, кружево веерника, трубы органа. Что
## рисовать — `mode` (Plant), краски и числа каждого вида — в своих uniform; формулы — прежние формулы видов.
## Общее: шероховатость `rough`, блик `spec`, своё свечение `glow` (линейный цвет) плюс волна `glow_wave` · sin(TIME · 1,7).
enum Plant { KELP, LEAF, FAN, ORGAN }
const PLANT := """
shader_type spatial;
render_mode cull_disabled;
uniform int mode = 0;
uniform vec3 paint : source_color = vec3(1.0);
uniform vec3 edge : source_color = vec3(1.0);
// веерник: размер прямоугольника, м
uniform vec2 size = vec2(1.0);
// лента и орган: цвет экземпляра или вершины, гуще в shade раз
uniform float shade = 1.0;
uniform float rough = 0.9;
uniform float spec = 0.5;
uniform vec3 glow = vec3(0.0);
uniform vec3 glow_wave = vec3(0.0);
void vertex() {
	if (mode == 0) {
		// лента качается как G.sway: размах 0,9 к верху, фаза — от места экземпляра
		float ph = MODEL_MATRIX[3].x * 0.23 + MODEL_MATRIX[3].z * 0.19;
		float k = clamp(VERTEX.y, 0.0, 1.0);
		VERTEX.x += sin(TIME * 1.2 + ph + VERTEX.y * 2.0) * k * k * 0.9;
		VERTEX.z += cos(TIME * 0.9 + ph * 1.3) * k * k * 0.54;
	}
}
void fragment() {
	if (mode == 1) {
		// лист: UV.x поперёк (0,5 — жилка), UV.y — от кончика (0) к основанию (1)
		float e = smoothstep(0.25, 0.5, abs(UV.x - 0.5)) * 0.8 + smoothstep(0.45, 0.0, UV.y) * 0.5;
		float vein = 1.0 - smoothstep(0.0, 0.04, abs(UV.x - 0.5));
		ALBEDO = mix(paint, edge, clamp(e + vein * 0.3, 0.0, 1.0)) * mix(0.55, 1.0, 1.0 - UV.y * 0.6);
	} else if (mode == 2) {
		// веерник (fanTex): метры от подножия, лучи расходятся из точки на высоте 0,35 м
		vec2 p = vec2((UV.x - 0.5) * size.x, (1.0 - UV.y) * size.y);
		vec2 d = p - vec2(0.0, 0.35);
		float r = length(d);
		float a = atan(d.x, max(d.y, 1e-4));
		float w = 0.0;
		// ствол
		if (p.y < 0.4) {
			w = step(abs(p.x), 0.09);
		}
		float el = length(vec2(d.x / 0.55, d.y / 0.95));
		// лучи: 13 от −1,25 до 1,25 рад, тоньше к краю; дуги-эллипсы между ними; край веера — эллипс
		float k = (a + 1.25) / 2.5 * 12.0;
		float ray = abs(k - round(k)) * 2.5 / 12.0 * r;
		if (d.y > 0.0 && abs(a) < 1.3) {
			w = max(w, step(ray, 0.05 - r * 0.008));
			float ring = abs(fract(el / 0.22) - 0.5) * 0.22;
			w = max(w, step(ring, 0.024) * step(0.3, el));
			w *= step(el, 2.6);
		}
		if (w < 0.5) {
			discard;
		}
		ALBEDO = mix(paint, edge, smoothstep(1.6, 2.6, el));
	} else {
		// лента (цвет экземпляра) и труба органа (цвет вершины)
		ALBEDO = COLOR.rgb * shade;
	}
	ROUGHNESS = rough;
	SPECULAR = spec;
	EMISSION = glow + glow_wave * sin(TIME * 1.7);
}
"""


## Код → слабая ссылка на Shader: пока его держит хоть один материал, тот же код получает тот же ресурс. Слабая —
## чтобы при выходе не оставалось ресурсов в статике.
static var _made := {}


## Один ресурс Shader на одинаковый код.
static func shader(code: String) -> Shader:
	var ref: WeakRef = _made.get(code)
	var sh: Shader = ref.get_ref() if ref else null
	if sh == null:
		sh = Shader.new()
		sh.code = code
		_made[code] = weakref(sh)
	return sh


## Материал на общем шейдере с параметрами.
static func material(code: String, params: Dictionary = {}) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader(code)
	for k in params:
		mat.set_shader_parameter(k, params[k])
	return mat


## Камень с обрастанием (STONE).
static func stone(growth: Color, fill: float, rough: float, spec: float) -> ShaderMaterial:
	return material(STONE, {"growth": growth, "fill": fill, "glow_k": 1.4, "cut": 0.5, "rough": rough,
		"spec": spec, "flicker": 0.0})


## Яркости пятен мха для массива glow[MOSS_MAX]: дополнить нулями.
static func moss_glow(glows: PackedFloat32Array) -> PackedFloat32Array:
	assert(glows.size() <= MOSS_MAX, "пятен мха больше MOSS_MAX")
	var out := glows.duplicate()
	out.resize(MOSS_MAX)
	for i in range(glows.size(), MOSS_MAX):
		out[i] = 0.0
	return out


## Прозрачное без света (MIST): что рисовать — kind, числа вида — params.
static func mist(kind: Mist, params: Dictionary = {}) -> ShaderMaterial:
	var mat := material(MIST, params)
	mat.set_shader_parameter("mode", int(kind))
	return mat


## Растение со светом (PLANT): что рисовать — kind, числа вида — params.
static func plant(kind: Plant, params: Dictionary = {}) -> ShaderMaterial:
	var mat := material(PLANT, params)
	mat.set_shader_parameter("mode", int(kind))
	return mat
