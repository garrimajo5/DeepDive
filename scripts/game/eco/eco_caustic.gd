class_name EcoCaustic
## Каустики на местах-ориентирах (Б1, `docs/grafika-plan-eco.md`: «свет прожектора и каустики играют по телам»):
## раковина древних, кости левиафана, край отмели, порода курильщика и друзы у 10 ловят ту же сеть света сквозь
## лёд, что и дно (`shaders/seabed.gdshader`), — камень не выпадает из подводного света. Приём живёт в общем шейдере
## камня `EcoShaders.STONE` (uniform `caustic`), нового шейдера нет: узор по мировым x/z, только на гранях, что
## смотрят вверх, и не поверх светящегося обрастания. Сила — по глубине корабля той же кривой, что у дна
## (`Seabed.Water.caustic`), ставит `EcoView._sync`; «Экономно» — 0 (`set_lite`, в `EcoView.set_lite`).
## Проверяет `tests/test_eco_caustic.gd`.

## Доля силы каустик дна: у дна `caustic` 0,6 × сеть 0,6 — камень берёт столько же.
const GAIN := 0.36
## Числа узора — как у дна (`OceanView`: `caustic_scale`, `caustic_speed`).
const SCALE := 0.16
const SPEED := 0.32
## Меньше этого изменения силы uniform не переписываем.
const STEP := 0.005

static var lite := false
## Сила сейчас (без «Экономно»).
static var strength := 0.0
static var _mats: Array[WeakRef] = []


## Материал камня под каустики: сразу получает текущую силу.
static func track(mat: ShaderMaterial) -> void:
	_mats = _mats.filter(func(r: WeakRef) -> bool: return r.get_ref() != null)
	_mats.append(weakref(mat))
	mat.set_shader_parameter("caustic", applied())


## Сила для глубины корабля (м, вниз — больше).
static func for_depth(depth: float) -> float:
	return GAIN * clampf(Seabed.Water.caustic(maxf(depth, 0.0)), 0.0, 1.0)


## Что сейчас стоит в uniform.
static func applied() -> float:
	return 0.0 if lite else strength


## Глубина корабля сменилась — новая сила всем камням (заметно изменилась — только тогда пишем uniform).
static func set_depth(depth: float) -> void:
	var k := for_depth(depth)
	if absf(k - strength) < STEP:
		return
	strength = k
	_push()


## «Экономно»: каустики на камне погашены числом, шейдер тот же.
static func set_lite(on: bool) -> void:
	lite = on
	_push()


static func _push() -> void:
	var v := applied()
	for r in _mats:
		var m: ShaderMaterial = r.get_ref()
		if m:
			m.set_shader_parameter("caustic", v)


## Двойник узора шейдера: яркость сети 0…1 в точке дна (x, z) в момент t (мир, с).
static func pattern(x: float, z: float, t: float) -> float:
	var cp := Vector2(x, z) * SCALE
	var tt := t * SPEED
	var l1 := _noise(cp + Vector2(tt, tt * 0.6))
	var l2 := _noise(cp * 1.6 + Vector2(-tt * 0.8, tt * 0.5))
	var l3 := _noise(cp * 2.3 + Vector2(tt * 0.4, -tt * 0.9))
	var c := absf(l1 - l2) * 0.6 + absf(l2 - l3) * 0.4
	return pow(1.0 - smoothstep(0.0, 0.16, c), 1.6)


## Доля на грани с вертикалью нормали up (только верх камня).
static func facing(up: float) -> float:
	return smoothstep(0.15, 0.85, up)


static func _hash(p: Vector2) -> float:
	p = Vector2(_fract(p.x * 127.1), _fract(p.y * 311.7))
	var d := p.dot(p + Vector2(34.5, 34.5))
	p += Vector2(d, d)
	return _fract(p.x * p.y)


static func _noise(p: Vector2) -> float:
	var i := p.floor()
	var f := p - i
	f = f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	var a := _hash(i)
	var b := _hash(i + Vector2(1, 0))
	var c := _hash(i + Vector2(0, 1))
	var d := _hash(i + Vector2(1, 1))
	return lerpf(lerpf(a, b, f.x), lerpf(c, d, f.x), f.y)


static func _fract(v: float) -> float:
	return v - floorf(v)
