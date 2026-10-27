class_name EcoFarLife
extends RefCounted
## Жизнь вдали (`docs/grafika-plan-eco.md`, Б5 «Плотнее фоновая жизнь вдали»): тёмные силуэты рыб в мути за
## 40…125 м от корабля — отмель обитаема и там, куда не достаёт ни прожектор, ни подробные виды. Это фон, не вид
## мира: в EcoWorld их нет, сонар, сканер и хищники их не видят, на поведение не влияют. Где силуэт и куда плывёт —
## формула от времени мира и места (хеш EcoVary), поэтому у гостя сети картина та же, что у хоста.
## Стайки живут в плитке TILE × TILE, повторённой по всей отмели: из копий стайки берётся ближайшая к кораблю
## (`near_copy`), так что идёшь — навстречу выплывают новые, а сами стайки стоят в мире, а не едут за кораблём.
## Ближе NEAR_IN и дальше FAR_OUT силуэт сжат в точку (`fade`) — не путается с настоящими видами и не мигает на краю.
## Цвет — тёмный, без света: дальше гасит туман воды (OceanView.apply_water), поэтому глубина читается сама.

## Сторона плитки, м: больше 2 · FAR_OUT — в кольце видимости не бывает двух копий одной стайки.
const TILE := 280.0
## Кольцо видимости по горизонтали от корабля, м: растёт NEAR_IN → NEAR_FULL, гаснет FAR_FULL → FAR_OUT.
const NEAR_IN := 40.0
const NEAR_FULL := 55.0
const FAR_FULL := 100.0
const FAR_OUT := 125.0
## Стайки: SMALL мелких (по FISH рыбок 0,45…0,8 м) и BIG пар крупных (2,2…3,2 м).
const SMALL := 9
const BIG := 3
const FISH := 10
const PAIR := 2
## Высота над дном, м, и потолок (подо льдом не выше), м.
const LOW := 5.0
const HIGH := 18.0
const CEIL := -7.0
## Ниже этого над дном силуэт не опускается, м.
const ABOVE := 1.5
## Без дна (мир ещё не встал) — эта глубина дна.
const NO_GROUND := -24.0
## Цвет силуэта (почти чёрная вода) и разброс тона стайки.
const COLOR := Color(0.025, 0.05, 0.065)
const SHADE := 0.35

const _BASE_X := 11
const _BASE_Z := 12
const _H := 13
const _R := 14
const _SPEED := 15
const _DIR := 16
const _OFF := 20
const _PHASE := 30


static func count() -> int:
	return SMALL * FISH + BIG * PAIR


## Стайка i большая (пара крупных)?
static func is_big(i: int) -> bool:
	return i >= SMALL


static func schools() -> int:
	return SMALL + BIG


## Сколько силуэтов в стайке i.
static func size_of(i: int) -> int:
	return PAIR if is_big(i) else FISH


## Номер первого силуэта стайки i в общем буфере.
static func first(i: int) -> int:
	return i * FISH if i <= SMALL else SMALL * FISH + (i - SMALL) * PAIR


## Середина круга стайки в плитке (x, z), м.
static func base(i: int) -> Vector2:
	return Vector2(EcoVary.unit(i, _BASE_X) * TILE, EcoVary.unit(i, _BASE_Z) * TILE)


## Ближайшая к кораблю копия точки p плитки (по x и z).
static func near_copy(p: Vector2, ship: Vector2) -> Vector2:
	return Vector2(ship.x + wrapf(p.x - ship.x, -TILE * 0.5, TILE * 0.5),
		ship.y + wrapf(p.y - ship.y, -TILE * 0.5, TILE * 0.5))


## Радиус круга, м; скорость по кругу, м/с; знак обхода.
static func circle(i: int) -> Vector3:
	var big := is_big(i)
	var r := lerpf(14.0, 30.0, EcoVary.unit(i, _R)) if big else lerpf(8.0, 22.0, EcoVary.unit(i, _R))
	var sp := lerpf(0.9, 1.6, EcoVary.unit(i, _SPEED)) if big else lerpf(0.8, 1.9, EcoVary.unit(i, _SPEED))
	var dir := 1.0 if EcoVary.unit(i, _DIR) < 0.5 else -1.0
	return Vector3(r, sp, dir)


## Центр стайки (x, z) в плитке и курс по кругу (рад, yaw: нос в (−sin, 0, −cos)) во время t.
static func center(i: int, t: float) -> Vector3:
	var c := circle(i)
	var a := t * c.y / c.x * c.z + EcoVary.unit(i, _PHASE) * TAU
	var b := base(i)
	var p := b + Vector2(cos(a), sin(a)) * c.x
	# касательная к кругу: d(p)/da · знак обхода
	var v := Vector2(-sin(a), cos(a)) * c.z
	return Vector3(p.x, atan2(-v.x, -v.y), p.y)


## Доля размера по горизонтальному расстоянию d от корабля: 0 вне кольца, 1 внутри.
static func fade(d: float) -> float:
	return smoothstep(NEAR_IN, NEAR_FULL, d) * (1.0 - smoothstep(FAR_FULL, FAR_OUT, d))


## Длина силуэта j стайки i, м.
static func length_of(i: int, j: int) -> float:
	var u := EcoVary.unit(i * 16 + j, EcoVary.SIZE)
	return lerpf(2.2, 3.2, u) if is_big(i) else lerpf(0.45, 0.8, u)


## Цвет стайки i: COLOR темнее-светлее на SHADE.
static func tint(i: int) -> Color:
	var k := EcoVary.spread(i, EcoVary.SHADE, SHADE)
	return Color(COLOR.r * k, COLOR.g * k, COLOR.b * k)


## Числа силуэтов, что не меняются (хеш EcoVary): считаются раз — шаг вида не хеширует каждый кадр.
static var _fish := PackedFloat32Array()
const _FN := 7   ## на силуэт: место в стайке x y z, фаза, длина, ритм виляния, фаза виляния


static func _consts() -> PackedFloat32Array:
	if _fish.is_empty():
		var out := PackedFloat32Array()
		out.resize(count() * _FN)
		for i in schools():
			for j in size_of(i):
				var k := i * 16 + j
				var spread := 7.0 if is_big(i) else 3.2
				var at := (first(i) + j) * _FN
				out[at] = (EcoVary.unit(k, _OFF) * 2.0 - 1.0) * spread
				out[at + 1] = (EcoVary.unit(k, _OFF + 1) * 2.0 - 1.0) * 0.5 * spread
				out[at + 2] = (EcoVary.unit(k, _OFF + 2) * 2.0 - 1.0) * spread
				out[at + 3] = EcoVary.unit(k, _PHASE) * TAU
				out[at + 4] = length_of(i, j)
				out[at + 5] = (1.6 if is_big(i) else 3.2) * EcoVary.spread(k, EcoVary.RATE, 0.25)
				out[at + 6] = EcoVary.unit(k, _PHASE) * TAU
		_fish = out
	return _fish


## Стайка i во время t у корабля ship: [x, y, z — середина, yaw — курс, k — доля размера (0 — не видна),
## дно под серединой]. Дно спрашивается раз на стайку и только у видимой.
static func school_at(i: int, t: float, ship: Vector3, ground: Callable) -> PackedFloat32Array:
	var c := center(i, t)
	var at := near_copy(Vector2(c.x, c.z), Vector2(ship.x, ship.z))
	var k := fade(at.distance_to(Vector2(ship.x, ship.z)))
	if k <= 0.0:
		return PackedFloat32Array([at.x, NO_GROUND, at.y, c.y, 0.0, NO_GROUND])
	var floor_y := float(ground.call(at.x, at.y)) if ground.is_valid() else NO_GROUND
	var h := lerpf(LOW, HIGH, EcoVary.unit(i, _H)) + sin(t * 0.13 + float(i)) * 1.5
	return PackedFloat32Array([at.x, floor_y + h, at.y, c.y, k, floor_y])


## Трансформ силуэта j стайки s = school_at(i, …) во время t (меш — длина 1, нос в −Z). Не видна — сжат в точку.
static func fish(i: int, j: int, t: float, s: PackedFloat32Array) -> Transform3D:
	if s[4] <= 0.0:
		return Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(s[0], s[1], s[2]))
	var f := _consts()
	var a := (first(i) + j) * _FN
	var ph := f[a + 3]
	var o := Vector3(f[a] + sin(t * 0.55 + ph) * 0.6, f[a + 1] + sin(t * 0.4 + ph * 1.7) * 0.3,
		f[a + 2] + cos(t * 0.47 + ph) * 0.6)
	var yaw := s[3]
	var pos := Vector3(s[0], s[1], s[2]) + Basis(Vector3.UP, yaw) * o
	pos.y = maxf(minf(pos.y, CEIL), s[5] + ABOVE)
	var wag := sin(t * f[a + 5] + f[a + 6]) * 0.12
	return Transform3D(Basis(Vector3.UP, yaw + wag).scaled(Vector3.ONE * f[a + 4] * s[4]), pos)


## Трансформ силуэта j стайки i во время t у корабля ship (для проверки; вид берёт school_at + fish).
static func xform(i: int, j: int, t: float, ship: Vector3, ground: Callable) -> Transform3D:
	return fish(i, j, t, school_at(i, t, ship, ground))
