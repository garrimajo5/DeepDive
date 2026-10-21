class_name EcoShell
extends EcoSystem
## Раковина древних — место 3 карты отмели по концепту ART-029 (docs/concept-art/rakovina-drevnih.md): неживой
## фрагмент выращенного архива родства Складчатых (docs/world.md), не существо. Тупая спираль 2,25 оборота стоит
## торцом, лицом к подходу с запада (к старту забега); высота 10 м, ширина 11 м, толщина 5 м, низ утоплен на 0,4 м.
## Трубка спирали растёт в WIDEN раз за оборот, сечение — эллипс (поперёк в плоскости спирали rr, вдоль оси ra).
## Внешний виток справа разломан: передняя стенка снята с рваным краем, за ней — пластина колец с ветвящейся
## линией родства и прямой линией «канон». На трубке — борозды поперёк, контактные гнёзда группами по три,
## у дна — осыпь камней. Сам архив матовый, светится только обрастание (около 10 % граней у дна и в бороздах).
## Форма своя, от зерна мира не зависит. Столкновение корабля — `solid`, подключить — поток А.
##
## Оси раковины (локальные, в метрах): +X — вправо, если смотреть на лицо, +Y — вверх, +Z — лицо (к подходу);
## начало — середина опоры на нижней точке трубки. Спираль в плоскости XY: угол θ растёт против часовой стрелки,
## если смотреть на лицо; конец трубки (самая толстая часть) — внизу слева, лежит на дне.

const ID := "shell"
## Точка на карте отмели (karta-otmeli-mesta.json, место 3) — та же, что Run.PLACES["shell"].
const CENTER := Vector2(162.0, -36.0)
## Размеры по заметке художника, м: высота, ширина, толщина; насколько низ утоплен в дно.
const HEIGHT := 10.0
const WIDTH := 11.0
const THICK := 5.0
const SINK := 0.4
## Спираль: обороты, рост трубки за оборот, нахлёст соседних витков (1 — касаются), угол конца трубки.
const TURNS := 2.25
const WIDEN := 2.5
const OVERLAP := 1.1
const END_ANGLE := 1.3 * PI
## Сечения вдоль спирали и вершин в сечении (бюджет заметки: 48 × 12).
const SECTIONS := 48
const SIDES := 12
## Дрожь вершин (доля радиуса) — грани камня; борозда — каждое BAND-е сечение, вдавлено на GROOVE.
const JITTER := 0.04
const BAND := 4
const GROOVE := 0.06
## Разлом внешней губы: на сколько оборотов от конца трубки начинается и кончается (передняя стенка снята).
## Рваный край: по ряду остаётся внешняя полоса стенки, где cos φ > RIM_LO…RIM_HI.
const BREAK_NEAR := 0.35
const BREAK_FAR := 0.85
const RIM_LO := 0.2
const RIM_HI := 0.75
## Пластина колец: вдавлена от середины трубки к лицу, кольца — дуги вдоль спирали (доли rr), высота рельефа.
const PLATE_Z := 0.25
const PLATE_RINGS: Array[float] = [-0.62, -0.25, 0.45, 0.78]
const RELIEF := 0.12
## Линия родства на пластине: отрезки (s0, u0, s1, u1) — s 0…1 вдоль разлома, u −1…1 поперёк трубки;
## узлы-почки — в концах ветвей. Прямая линия «канон» — поперёк трубки при s = CANON_S.
const KIN: Array[Vector4] = [
	Vector4(0.18, 0.08, 0.40, 0.10), Vector4(0.40, 0.10, 0.58, 0.06), Vector4(0.58, 0.06, 0.70, 0.12),
	Vector4(0.30, 0.09, 0.36, 0.38), Vector4(0.30, 0.09, 0.36, -0.20), Vector4(0.46, 0.09, 0.53, 0.40),
	Vector4(0.46, 0.09, 0.52, -0.22), Vector4(0.60, 0.07, 0.66, 0.34), Vector4(0.64, 0.09, 0.70, -0.16),
]
const CANON_S := 0.86
## Контактные гнёзда: группы по три (θ от конца трубки в оборотах, φ на сечении), лунка радиусом NEST_R.
const NESTS: Array[Vector2] = [Vector2(0.12, 0.9), Vector2(0.2, 1.75), Vector2(1.05, 1.0)]
const NEST_R := 0.17
const NEST_GAP := 0.24
## Обрастание: кустики в бороздах (TUFTS_GROOVE) и у дна (TUFTS_LOW — ниже GLOW_LOW над низом), высота.
const TUFTS_GROOVE := 22
const TUFTS_LOW := 16
const GLOW_LOW := 1.2
const TUFT_H := 0.35
## Осыпь у подножия: камней, размер.
const ROCKS := 14
const ROCK_MIN := 0.35
const ROCK_MAX := 1.1
## Препятствие для проверок: радиус и высота над дном, м (как в браузере — r 9, верх 12).
const OBSTACLE_R := 9.0
const OBSTACLE_TOP := 12.0
## Куда смотрит лицо (старт забега).
const FACE := Vector2(0.0, 0.0)
## Зерно формы — своё, не мира.
const SHAPE_SEED := 2029

## Подножие (мир): середина опоры на нижней точке трубки; поворот (локальная +Z — лицо).
var base := Vector3.ZERO
var basis := Basis.IDENTITY
## Высота дна (мир передаёт при сбросе; без дна — ровно −40 м).
var ground: Callable
## Сечения: угол θ и вершины (локальные метры, SECTIONS × SIDES, ряд за рядом).
var theta := PackedFloat32Array()
var ring := PackedVector3Array()
## Ряды разлома [break_from, break_to) — между сечениями i и i + 1; рваный край ряда (порог cos φ).
var break_from := 0
var break_to := 0
var rim := PackedFloat32Array()
## Гнёзда: лунки (локальные) и нормаль поверхности у каждой.
var nest_c := PackedVector3Array()
var nest_n := PackedVector3Array()
## Обрастание (локально): корни кустиков и нормаль поверхности.
var tuft_c := PackedVector3Array()
var tuft_n := PackedVector3Array()
## Осыпь (мир): центры и размеры камней.
var rock_c := PackedVector3Array()
var rock_r := PackedFloat32Array()

var _center: Vector2
var _b := 0.0         # рост ρ = e^(b·(θ − END_ANGLE))
var _k := 0.0         # rr = k·ρ (в осях спирали до растяжения)
var _a := 0.0         # ra = a·ρ (м)
var _sx := 1.0        # растяжение плоскости спирали до ширины и высоты
var _sy := 1.0
var _x_mid := 0.0
var _y_min := 0.0
var _jit := PackedFloat32Array()


## center — своё место (для тестов), по умолчанию — с карты отмели.
func _init(center: Vector2 = CENTER) -> void:
	_center = center


func reset(world: EcoWorld) -> void:
	ground = world.ground
	_build()


## Дно под (x, z): мир передаёт Seabed.height; без него — −40 м.
func floor_y(x: float, z: float) -> float:
	return float(ground.call(x, z)) if ground.is_valid() else -40.0


## Поворот: лицо (+Z) — к FACE.
static func make_basis(center: Vector2) -> Basis:
	var to := FACE - center
	return Basis(Vector3.UP, atan2(to.x, to.y))


func to_world(local: Vector3) -> Vector3:
	return base + basis * local


func to_local(p: Vector3) -> Vector3:
	return basis.inverse() * (p - base)


## Лицо в мире.
func face() -> Vector3:
	return basis * Vector3.BACK


## Угол сечения i (0 — середина спирали, SECTIONS − 1 — конец трубки).
static func section_theta(i: float) -> float:
	return END_ANGLE - TURNS * TAU * (1.0 - i / (SECTIONS - 1))


## Ось трубки при θ: центр в осях спирали (до растяжения), радиальное направление, rr и ra.
func _rho(th: float) -> float:
	return exp(_b * (th - END_ANGLE))


## Точка поверхности трубки при θ, φ (локальные метры), f — доля радиуса (1 — поверхность, 0 — ось).
func surface(th: float, phi: float, f: float = 1.0) -> Vector3:
	var r := _rho(th)
	var d := Vector2(cos(th), sin(th))
	var p := d * r + d * cos(phi) * _k * r * f
	return Vector3((p.x - _x_mid) * _sx, (p.y - _y_min) * _sy, sin(phi) * _a * r * f)


## Нормаль поверхности при θ, φ (локально).
func surface_normal(th: float, phi: float) -> Vector3:
	var e := 0.01
	var du := surface(th, phi + e) - surface(th, phi - e)
	var dv := surface(th + e, phi) - surface(th - e, phi)
	var n := du.cross(dv).normalized()
	var out := surface(th, phi) - surface(th, phi, 0.0)
	return n if n.dot(out) > 0.0 else -n


## Вершина j сечения i (с дрожью и бороздами).
func vertex(i: int, j: int) -> Vector3:
	return ring[i * SIDES + j]


func phi(j: int) -> float:
	return TAU * j / SIDES


## Ряд i (между сечениями i и i + 1) в разломе.
func in_break(i: int) -> bool:
	return i >= break_from and i < break_to


## Грань (ряд i, столбец j — между φ_j и φ_j+1) снята разломом: передняя половина, кроме рваной внешней полосы.
func broken(i: int, j: int) -> bool:
	if not in_break(i):
		return false
	var m := (j + 0.5) * TAU / SIDES
	return sin(m) > 0.0 and cos(m) < rim[i]


## Сечение i — борозда.
static func groove(i: int) -> bool:
	return i % BAND == 0 and i > 0 and i < SECTIONS - 1


## Точка пластины: s 0…1 вдоль разлома, u −1…1 поперёк трубки, h — над пластиной (к лицу), м.
func plate_point(s: float, u: float, h: float = 0.0) -> Vector3:
	var th := section_theta(lerpf(break_from, break_to, s))
	var p := surface(th, 0.0, u)
	p.z = _a * _rho(th) * PLATE_Z + h
	return p


## Полуширина пластины в сечении θ (на высоте PLATE_Z эллипс уже).
static func plate_half() -> float:
	return sqrt(1.0 - PLATE_Z * PLATE_Z)


func _build() -> void:
	basis = make_basis(_center)
	_b = log(WIDEN) / TAU
	_k = (WIDEN - 1.0) / (WIDEN + 1.0) * OVERLAP
	# охват спирали в плоскости до растяжения: силуэт — отрезки c ± d·rr
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for n in 600:
		var th := section_theta(n * (SECTIONS - 1) / 599.0)
		var r := exp(_b * (th - END_ANGLE))
		var d := Vector2(cos(th), sin(th))
		for s in [-1.0, 1.0]:
			var p: Vector2 = d * r * (1.0 + s * _k)
			lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
			hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	_sx = WIDTH / (hi.x - lo.x)
	_sy = HEIGHT / (hi.y - lo.y)
	_x_mid = (lo.x + hi.x) * 0.5
	_y_min = lo.y
	_a = THICK * 0.5   # ra на конце трубки (ρ = 1)
	var rng := EcoRandom.new(SHAPE_SEED)
	theta.clear()
	ring.clear()
	for i in SECTIONS:
		var th := section_theta(i)
		theta.append(th)
		var c := surface(th, 0.0, 0.0)
		for j in SIDES:
			var f := 1.0 + rng.range_f(-JITTER, JITTER)
			if groove(i):
				f -= GROOVE
			if i == 0:
				f = 0.6
			ring.append(c + (surface(th, phi(j)) - c) * f)
	# разлом: ряды, где конец трубки ближе BREAK_FAR и дальше BREAK_NEAR оборота
	break_from = -1
	break_to = -1
	for i in SECTIONS - 1:
		var turns_left := (END_ANGLE - section_theta(i + 0.5)) / TAU
		if turns_left <= BREAK_FAR and turns_left >= BREAK_NEAR:
			if break_from < 0:
				break_from = i
			break_to = i + 1
	rim.clear()
	for i in SECTIONS - 1:
		rim.append(rng.range_f(RIM_LO, RIM_HI))
	# гнёзда: по три лунки треугольником в касательной плоскости
	nest_c.clear()
	nest_n.clear()
	for g in NESTS:
		var th := END_ANGLE - g.x * TAU
		var n := surface_normal(th, g.y)
		var c := surface(th, g.y)
		var t1 := (surface(th, g.y + 0.05) - surface(th, g.y - 0.05)).normalized()
		var t2 := n.cross(t1)
		for q in 3:
			var a := TAU * q / 3.0 + 0.3
			nest_c.append(c + (t1 * cos(a) + t2 * sin(a)) * NEST_GAP)
			nest_n.append(n)
	# обрастание: в бороздах (не на тыле и не в разломе) и у низа трубки
	tuft_c.clear()
	tuft_n.clear()
	var tries := 0
	while tuft_c.size() < TUFTS_GROOVE and tries < 1000:
		tries += 1
		var gi := BAND * (1 + rng.index((SECTIONS - 2) / BAND))
		var ph := rng.range_f(-0.4, PI + 0.4)
		if in_break(gi) and sin(ph) > 0.0 and cos(ph) < RIM_HI:
			continue
		_tuft(theta[gi], ph, 1.0 - GROOVE)
	tries = 0
	while tuft_c.size() < TUFTS_GROOVE + TUFTS_LOW and tries < 12000:
		tries += 1
		var th := section_theta(rng.range_f(0.0, SECTIONS - 1))
		var ph := rng.range_f(0.0, TAU)
		if surface(th, ph).y < GLOW_LOW and surface(th, ph).y > 0.05:
			_tuft(th, ph, 1.0)
	# опора: середина нижней точки на самом низком дне под трубкой, утоплена на SINK
	var bottom: Array[Vector3] = []
	for i in SECTIONS:
		for j in SIDES:
			if ring[i * SIDES + j].y < 1.0:
				bottom.append(ring[i * SIDES + j])
	var g_min := INF
	for p in bottom:
		var w := Vector3(_center.x, 0.0, _center.y) + basis * p
		g_min = minf(g_min, floor_y(w.x, w.z))
	base = Vector3(_center.x, g_min - SINK, _center.y)
	# осыпь вокруг подножия: вдоль лица, тыла и по бокам
	rock_c.clear()
	rock_r.clear()
	for q in ROCKS:
		var side := q % 3
		var lx := rng.range_f(-WIDTH * 0.45, WIDTH * 0.45)
		var lz := rng.range_f(2.0, 3.6) * (1.0 if side == 0 else -1.0)
		if side == 2:
			lx = (WIDTH * 0.5 + rng.range_f(0.2, 1.2)) * (1.0 if q % 2 == 0 else -1.0)
			lz = rng.range_f(-2.0, 2.0)
		var r := rng.range_f(ROCK_MIN, ROCK_MAX)
		var w := to_world(Vector3(lx, 0.0, lz))
		w.y = floor_y(w.x, w.z) - r * 0.35
		rock_c.append(w)
		rock_r.append(r)


func _tuft(th: float, ph: float, f: float) -> void:
	tuft_c.append(surface(th, ph, f))
	tuft_n.append(surface_normal(th, ph))


## Верхняя точка (мир).
func top() -> Vector3:
	var best := base
	for p in ring:
		var w := to_world(p)
		if w.y > best.y:
			best = w
	return best


## Нижняя точка (мир).
func lowest() -> Vector3:
	var best := to_world(ring[0])
	for p in ring:
		var w := to_world(p)
		if w.y < best.y:
			best = w
	return best


## Точка (в мире) внутри трубки — для существ и столкновения корабля (подключает поток А).
func solid(p: Vector3) -> bool:
	var q := to_local(p)
	if q.y < -1.0 or q.y > HEIGHT + 1.0 or absf(q.x) > WIDTH * 0.5 + 1.0 or absf(q.z) > THICK * 0.5 + 1.0:
		return false
	var u := Vector2(q.x / _sx + _x_mid, q.y / _sy + _y_min)
	for n in 240:
		var th := section_theta(n * (SECTIONS - 1) / 239.0)
		var r := _rho(th)
		var d := Vector2(cos(th), sin(th))
		var t := Vector2(-d.y, d.x)
		var v := u - d * r
		var rr := _k * r
		var ra := _a * r
		var e := pow(v.dot(d) / rr, 2) + pow(v.dot(t) / rr, 2) + pow(q.z / ra, 2)
		if e < 1.0:
			return true
	return false
