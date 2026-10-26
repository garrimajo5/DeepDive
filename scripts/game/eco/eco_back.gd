class_name EcoBack
## Просвет (translucency) живого мира (Б2, `docs/grafika-plan-eco.md`): тонкие ленты ленточника, листья волнолиста,
## кружево веерника и щупальца хватней пропускают свет насквозь — с обратной стороны, против света сквозь лёд или
## прожектора, они светятся своим цветом, а не стоят чёрным силуэтом. Приём — встроенный просвет света Godot
## (`BACKLIGHT`): считается от каждого огня, в темноте его нет. Пишет его общий шейдер растений `EcoShaders.PLANT`
## (`BACKLIGHT = ALBEDO · back · back_k`) — новых шейдеров нет, доля просвета вида — uniform `back` (по каналам: свет
## сквозь живую ткань желтеет), щупальце к кончику тоньше — просвет растёт по доле длины (COLOR.a). Трубы органа
## толстые — без просвета. «Экономно» — `set_lite(true)`: `back_k` = 0, шейдер тот же. Проверяет `tests/test_eco_back.gd`.

## Доля просвета по видам растений — по порядку `EcoShaders.Plant` (KELP, LEAF, FAN, ORGAN, TENTACLE).
const BACK: Array[Vector3] = [
	Vector3(0.55, 0.6, 0.4),    # лента ленточника — тонкая, желто-зелёный просвет
	Vector3(0.5, 0.55, 0.35),   # лист волнолиста
	Vector3(0.35, 0.3, 0.25),   # кружево веерника — плотнее, известковое
	Vector3.ZERO,               # труба органа — толстая
	Vector3(0.5, 0.4, 0.45),    # щупальце хватня — студенистое
]
## Щупальце: просвет у основания и у кончика (доля длины — COLOR.a, линейно).
const TENTACLE_FOOT := 0.6
const TENTACLE_TIP := 1.3

static var lite := false
## Материалы с просветом — слабые ссылки, чтобы при выходе не оставалось ресурсов в статике.
static var _mats: Array[WeakRef] = []


## Доля просвета вида растения kind (EcoShaders.Plant).
static func of(kind: int) -> Vector3:
	return BACK[kind] if kind >= 0 and kind < BACK.size() else Vector3.ZERO


## Дать материалу растения просвет его вида (если в params вида нет своего `back`) и выключатель «Экономно».
static func apply(mat: ShaderMaterial, kind: int, params: Dictionary = {}) -> ShaderMaterial:
	if not params.has("back"):
		mat.set_shader_parameter("back", of(kind))
	mat.set_shader_parameter("back_k", 0.0 if lite else 1.0)
	_mats = _mats.filter(func(r: WeakRef) -> bool: return r.get_ref() != null)
	_mats.append(weakref(mat))
	return mat


## Двойник шейдера: цвет просвета при альбедо albedo; h — доля длины щупальца (у растений не важна).
static func through(albedo: Color, kind: int, h := 0.0) -> Color:
	var b := of(kind) * (0.0 if lite else 1.0)
	if kind == EcoShaders.Plant.TENTACLE:
		b *= lerpf(TENTACLE_FOOT, TENTACLE_TIP, h)
	return Color(albedo.r * b.x, albedo.g * b.y, albedo.b * b.z)


## «Экономно» (ART-044): погасить (или вернуть) просвет у всех растений — меняется только число.
static func set_lite(on: bool) -> void:
	lite = on
	for r in _mats:
		var mat: ShaderMaterial = r.get_ref()
		if mat:
			mat.set_shader_parameter("back_k", 0.0 if on else 1.0)


## Сколько живых материалов с просветом (для тестов).
static func count() -> int:
	var n := 0
	for r in _mats:
		if r.get_ref():
			n += 1
	return n
