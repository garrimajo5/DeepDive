class_name EcoShaders
extends RefCounted
## Общие шейдеры живого мира (issue #279). Рендерер Compatibility на каждый новый шейдер собирает ~5 программ — это
## секунды прогрева на телефоне при первом запуске. Поэтому одинаковый код — один ресурс `Shader` (`shader(code)`),
## а похожие материалы видов и мест — один общий код с числами в uniform: камень с обрастанием (`STONE`), мох
## пятнами (`MOSS`), светлая точка лицом к камере со сложением цвета (`SPOT`). Новый материал мира — сначала сюда.
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
