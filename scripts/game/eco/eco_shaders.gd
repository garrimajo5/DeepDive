class_name EcoShaders
extends RefCounted
## Общие шейдеры живого мира (issue #279). Рендерер Compatibility на каждый новый шейдер собирает ~5 программ — это
## секунды прогрева на телефоне при первом запуске. Поэтому одинаковый код — один ресурс `Shader` (`shader(code)`),
## а похожие материалы видов и мест — один общий код с числами в uniform: камень с обрастанием (`STONE`), мох
## пятнами (`MOSS`), прозрачное без света (`MIST`), светлая точка лицом к камере со сложением цвета (`SPOT`, облако
## планктона — `cloud`), растения со светом (`PLANT`). Новый материал мира — сначала сюда.
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
// cloud — облако планктона (PlanktonView): место клетки — дом + дрейф облака + покачивание по времени мира now,
// INSTANCE_CUSTOM = (фаза облака, номер клетки, время вспышки); клетки выталкиваются из коробки корпуса корабля.
uniform bool cloud = false;
uniform float now = 0.0;
uniform vec3 ship_pos = vec3(0.0, 1e6, 0.0);
uniform float ship_yaw = 0.0;
uniform vec3 box_min = vec3(0.0);
uniform vec3 box_max = vec3(0.0);
varying vec3 tint;
void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	vec3 col = COLOR.rgb;
	if (cloud) {
		float ph = INSTANCE_CUSTOM.x;
		float k = INSTANCE_CUSTOM.y;
		float w = now * 0.3 + k;
		o += vec3(sin(now * 0.03 + ph) * 6.0, sin(now * 0.17 + ph), cos(now * 0.025 + ph) * 6.0);
		o += vec3(sin(w) * 0.4, sin(w * 1.3) * 0.25, cos(w * 0.9) * 0.4);
		vec3 d = o - ship_pos;
		float cy = cos(ship_yaw), sy = sin(ship_yaw);
		vec3 l = vec3(d.x * cy - d.z * sy, d.y, d.x * sy + d.z * cy);
		vec3 lo = l - box_min, hi = box_max - l;
		if (min(min(lo.x, hi.x), min(min(lo.y, hi.y), min(lo.z, hi.z))) > 0.0) {
			// внутри корпуса — к ближней стенке (S.pushOut)
			vec3 pen = min(lo, hi);
			if (pen.x <= pen.y && pen.x <= pen.z) l.x = lo.x < hi.x ? box_min.x - 0.2 : box_max.x + 0.2;
			else if (pen.y <= pen.z) l.y = lo.y < hi.y ? box_min.y - 0.2 : box_max.y + 0.2;
			else l.z = lo.z < hi.z ? box_min.z - 0.2 : box_max.z + 0.2;
			o = ship_pos + vec3(l.x * cy + l.z * sy, l.y, -l.x * sy + l.z * cy);
		}
		float g = clamp(1.0 - (now - INSTANCE_CUSTOM.z) * 0.45, 0.0, 1.0);
		float b = 0.05 + 0.03 * sin(now * 1.1 + k * 1.7);
		col = vec3(b * 0.4 + g * 0.35, b + g, b * 1.1 + g * 0.85);
	}
	float far = length((VIEW_MATRIX * vec4(o, 1.0)).xyz);
	tint = col * clamp(1.0 - far / fade_far, 0.0, 1.0);
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s,
		vec4(o, 1.0));
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

## Колыхание в течении мира — общий кусок шейдера растений (PLANT) и огнецвета (CoralView), двойник
## EcoCurrent.sway: подножие o, доля высоты h (0 — подножие, 1 — верх), высота height в метрах, изгиб bend вида.
## Материалы с этим куском получают поток через follow / set_flow и выключатель «Экономно» set_sway_lite.
const SWAY := """
// колыхание в течении (EcoCurrent.sway — двойник): flow — скорость потока, м/с; bend — (крен, волна, поперёк)
// в долях высоты на полном течении; sway_k — 0 на «Экономно»
uniform vec3 flow = vec3(0.0);
uniform float sway_k = 1.0;
vec3 eco_sway(vec3 o, float h, float height, vec3 bn) {
	float v = length(flow);
	float s = v / 0.3;
	vec3 d = v > 1e-5 ? flow / v : vec3(0.0, 0.0, 1.0);
	vec3 c = vec3(-d.z, 0.0, d.x);
	float ph = o.x * 0.23 + o.z * 0.19;
	float gust = 0.65 + 0.35 * sin(TIME * 0.45 + ph);
	float fl = sin(TIME * 1.6 + ph * 1.3 - h * 2.2);
	float cr = sin(TIME * 1.1 + ph * 0.7 - h * 1.5);
	float w = 0.4 + 0.6 * s;
	float k = h * h * height;
	vec3 off = (d * (bn.x * s * gust + bn.y * w * fl) * k + c * (bn.z * w * cr) * k) * sway_k;
	off.y -= dot(off, off) / (2.0 * max(height, 0.1));
	return off;
}
"""

## Растения на дне со светом (обе стороны): ленты ленточника, листья волнолиста, кружево веерника, трубы органа,
## щупальца хватней (тело со светом, к кончикам светится само — `tip_glow`, доля длины — в COLOR.a). Что
## рисовать — `mode` (Plant), краски и числа каждого вида — в своих uniform; формулы — прежние формулы видов.
## Общее: шероховатость `rough`, блик `spec`, своё свечение `glow` (линейный цвет) плюс волна `glow_wave` · sin(TIME · 1,7);
## колыхание в течении мира — `bend`/`reach` вида и общий поток `flow` (`set_flow`), формула — EcoCurrent.sway;
## `phase_axis` — сдвиг фазы по углу оси экземпляра вокруг вертикали (щупальца одного диска вразнобой, у растений 0).
enum Plant { KELP, LEAF, FAN, ORGAN, TENTACLE }
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
// bend — изгиб вида, reach — высота растения в осях меша; поток и выключатель — в SWAY
uniform vec3 bend = vec3(0.0);
uniform float reach = 1.0;
uniform float phase_axis = 0.0;
// щупальце: свечение у основания и у кончика (доля длины — COLOR.a, по квадрату)
uniform vec2 tip_glow = vec2(0.0);
""" + SWAY + """
void vertex() {
	if (sway_k > 0.0 && dot(bend, bend) > 0.0) {
		vec3 o = MODEL_MATRIX[3].xyz;
		vec3 ax = MODEL_MATRIX[0].xyz;
		vec3 ay = MODEL_MATRIX[1].xyz;
		vec3 az = MODEL_MATRIX[2].xyz;
		float h = clamp(VERTEX.y / reach, 0.0, 1.0);
		// щупальца: фаза ещё и по углу оси вокруг вертикали (у растений phase_axis = 0 — без atan)
		vec3 po = o;
		if (phase_axis != 0.0) {
			po.x += atan(ay.z, ay.x) * phase_axis;
		}
		vec3 off = eco_sway(po, h, reach * length(ay), bend);
		// мировое смещение — в оси меша (у растений оси ортогональны: поворот и масштаб)
		VERTEX += vec3(dot(off, ax) / max(dot(ax, ax), 1e-6), dot(off, ay) / max(dot(ay, ay), 1e-6),
			dot(off, az) / max(dot(az, az), 1e-6));
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
		// цвет экземпляра — разброс веерников (FanView.fan_tint), без него белый
		ALBEDO = mix(paint, edge, smoothstep(1.6, 2.6, el)) * COLOR.rgb;
	} else {
		// лента (цвет экземпляра), труба органа и щупальце (цвет вершины)
		ALBEDO = COLOR.rgb * shade;
	}
	ROUGHNESS = rough;
	SPECULAR = spec;
	vec3 e = glow + glow_wave * sin(TIME * 1.7);
	if (mode == 4) {
		e += COLOR.rgb * mix(tip_glow.x, tip_glow.y, COLOR.a * COLOR.a);
	}
	EMISSION = e;
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


## Растение со светом (PLANT): что рисовать — kind, числа вида — params. Материал получает поток set_flow.
static func plant(kind: Plant, params: Dictionary = {}) -> ShaderMaterial:
	var mat := material(PLANT, params)
	mat.set_shader_parameter("mode", int(kind))
	return follow(mat)


## Материал с куском SWAY (растения, огнецвет) — получает текущий поток и выключатель «Экономно» сразу и дальше.
static func follow(mat: ShaderMaterial) -> ShaderMaterial:
	mat.set_shader_parameter("flow", flow)
	mat.set_shader_parameter("sway_k", 0.0 if sway_lite else 1.0)
	_plants = _plants.filter(func(r: WeakRef) -> bool: return r.get_ref() != null)
	_plants.append(weakref(mat))
	return mat


## Поток течения мира для колыхания растений (EcoView каждый шаг: EcoCurrent.vel()).
static var flow := Vector3.ZERO
## «Экономно»: растения не колышутся в шейдере (sway_k = 0). Включает уровень графики — set_sway_lite.
static var sway_lite := false
## Материалы растений — слабые ссылки, чтобы при выходе не оставалось ресурсов в статике.
static var _plants: Array[WeakRef] = []


## Отдать поток всем живым материалам растений; меняется заметно — только тогда пишем uniform.
static func set_flow(v: Vector3) -> void:
	if v.distance_to(flow) < 1e-4:
		return
	flow = v
	for r in _plants:
		var mat: ShaderMaterial = r.get_ref()
		if mat:
			mat.set_shader_parameter("flow", v)


## Выключатель колыхания для «Экономно» (ART-044): true — растения стоят (только качание листьев и вееров на CPU).
static func set_sway_lite(on: bool) -> void:
	sway_lite = on
	for r in _plants:
		var mat: ShaderMaterial = r.get_ref()
		if mat:
			mat.set_shader_parameter("sway_k", 0.0 if on else 1.0)


## Сколько живых материалов растений получает поток (для тестов).
static func plant_count() -> int:
	var n := 0
	for r in _plants:
		if r.get_ref():
			n += 1
	return n
