class_name EcoIris
## Переливы (iridescence) на чешуе живого мира (Б2, `docs/grafika-plan-eco.md`): тонкая плёнка чешуи меняет оттенок
## по углу к взгляду — у светляка-полосника бок в луче отливает то синим, то зелёным, то медью, у гребневика-радужника
## по краю тела бежит радуга. Приём — кусок GLSL `glsl()` (плёнка `iris_film` и вес `iris_weight`), который вставляют
## в свои шейдеры видов (FishView, RaduzhView); сила — uniform `iris`, сдвиг оттенка особи — от её фазы, поэтому
## соседи по стае переливаются вразнобой. Новых шейдеров не прибавляет (код вида один, пестрянки берут тот же шейдер
## с `iris` = 0). У освещаемой рыбки перелив прибавлен к цвету тела — в темноте не виден, под лучом и светом сквозь
## лёд играет; у гребневика (свет свой) — доля его яркости. «Экономно» — `set_lite(true)`: сила в ноль, шейдер тот же.
## Двойники шейдера — `film`/`weight`, проверяет `tests/test_eco_iris.gd`.

## Сколько оборотов оттенка проходит плёнка от взгляда в лоб (ndv = 1) до края по касательной (ndv = 0).
const SPAN := 0.9
## Вес перелива: в лоб — BASE, к краю растёт до BASE + EDGE.
const BASE := 0.35
const EDGE := 0.65
## Разброс сдвига оттенка по фазе особи (доля оборота).
const SHIFT := 0.5
## Сила у видов: доля цвета тела рыбки (прибавка к альбедо) и доля яркости гребневика.
const FISH := 0.22
const RADUZH := 0.55

static var lite := false
## Тронутые материалы: [слабая ссылка, сила без «Экономно»].
static var _mats: Array = []


## Кусок GLSL для шейдера вида: vec3 iris_film(ndv, shift) и float iris_weight(ndv). Двойники — film/weight.
static func glsl() -> String:
	return """
vec3 iris_film(float ndv, float shift) {
	float h = shift + (1.0 - ndv) * %s;
	return 0.5 + 0.5 * cos(6.2831853 * (h + vec3(0.0, 0.33333, 0.66667)));
}
float iris_weight(float ndv) {
	return %s + %s * (1.0 - ndv);
}
""" % [_f(SPAN), _f(BASE), _f(EDGE)]


static func _f(x: float) -> String:
	return "%.5f" % x


## Цвет плёнки под углом: ndv — косинус угла нормали к взгляду (1 — в лоб), shift — сдвиг оттенка особи.
## Двойник iris_film в шейдере; каналы 0…1, три канала сдвинуты на треть оборота.
static func film(ndv: float, shift: float) -> Color:
	var h := shift + (1.0 - ndv) * SPAN
	return Color(0.5 + 0.5 * cos(TAU * h), 0.5 + 0.5 * cos(TAU * (h + 0.33333)),
			0.5 + 0.5 * cos(TAU * (h + 0.66667)))


## Вес перелива под углом (двойник iris_weight): к краю тела сильнее.
static func weight(ndv: float) -> float:
	return BASE + EDGE * (1.0 - clampf(ndv, 0.0, 1.0))


## Сдвиг оттенка особи по её фазе 0…1 (двойник в шейдерах видов).
static func shift_of(phase: float) -> float:
	return fposmod(phase, 1.0) * SHIFT


## Есть ли у шейдера материала uniform перелива.
static func has_uniform(m: ShaderMaterial) -> bool:
	return m.shader != null and m.shader.code.contains("uniform float iris")


## Дать материалу вида перелив силой k (и запомнить для «Экономно»). Без uniform iris — не трогает.
static func apply(m: ShaderMaterial, k: float) -> bool:
	if not has_uniform(m):
		return false
	m.set_shader_parameter("iris", 0.0 if lite else k)
	_mats = _mats.filter(func(e: Array) -> bool: return e[0].get_ref() != null and e[0].get_ref() != m)
	_mats.append([weakref(m), k])
	return true


## «Экономно»: погасить (или вернуть) переливы — меняются только числа.
static func set_lite(on: bool) -> void:
	lite = on
	var alive: Array = []
	for e in _mats:
		var m: ShaderMaterial = e[0].get_ref()
		if m == null:
			continue
		alive.append(e)
		m.set_shader_parameter("iris", 0.0 if on else float(e[1]))
	_mats = alive


## Сколько живых материалов с переливом (для тестов).
static func count() -> int:
	var n := 0
	for e in _mats:
		if e[0].get_ref():
			n += 1
	return n
