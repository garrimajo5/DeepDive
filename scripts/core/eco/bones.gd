class_name EcoBones
extends EcoSystem
## Кости левиафана — место 4 карты отмели по концепту ART-030 (docs/concept-art/kosti-leviafana.md): скелет
## огромного существа, лежащий на склоне. Клетка из 8 пар гнутых шестигранных рёбер (26 м вдоль оси, наружная
## ширина 18 м, высота 9 м) с позвоночником поверх вершин, хвост за последним ребром уходит дугой вбок, череп
## (≈ 8 × 6 × 5 м, с окнами) лежит на боку в 13 м от оси у переднего торца, рядом — нижняя челюсть.
## Внутри клетки — чистый проход 14 × 7 м по всей длине: корабль проходит прямо. Ось клетки — к Каменному
## цветку (место 1 маршрута «Рифовый сад»), подходы ≥ 32 м с обоих торцов свободны. Статика; кость матовая,
## светятся только пятна обрастания. Форма своя, от зерна мира не зависит. Столкновение — `solid` по сегментам
## костей (не выпуклая оболочка: та закрыла бы туннель), подключить — поток А.
##
## Оси скелета (локальные, в метрах): +Z — вдоль оси к Каменному цветку (голова), +X — вправо, если смотреть
## на голову из клетки, y — мировой (высота как есть). Начало — центр клетки на карте.

const ID := "bones"
## Точка на карте отмели (karta-otmeli-mesta.json, место 4) — та же, что Run.PLACES["bones"].
const CENTER := Vector2(-30.0, -148.0)
## Откуда ось: Каменный цветок (место 1 маршрута «Рифовый сад»).
const FROM := Vector2(40.0, -50.0)
## Клетка: пар рёбер, длина вдоль оси, чистый проход (ширина, высота), м.
const PAIRS := 8
const CAGE_LEN := 26.0
const PASS_W := 14.0
const PASS_H := 7.0
## Ребро: полуширина осевой линии арки, подъём осевой линии над низом прохода, показатель суперэллипса
## (7 — бока почти отвесные, вершина уплощена), толщина у ноги и у вершины, наклон вершины к хвосту,
## насколько нога уходит в дно. Бочка — средние рёбра шире на BARREL.
const HALF_W := 8.45
const RISE := 8.5
const ARCH_N := 7.0
const RIB_R0 := 0.55
const RIB_R1 := 0.42
const LEAN := 0.6
const SINK := 0.4
const BARREL := 0.03
## Сегменты ребра: 1 — нога в дне, ARCH_SEGS — дуга арки; шестигранное сечение (ART-030: ≈ 96 треуг. на ребро).
const ARCH_SEGS := 7
const RIB_SIDES := 6
## Позвоночник над клеткой: позвонков, радиус тела позвонка. Хвост: позвонков, длина вдоль оси, вбок, радиус
## у основания и на конце; сначала уходит вбок поверх прохода (TAIL_TURN — доля хвоста), потом опускается на дно.
const SPINE_N := 15
const VERT_R := 0.55
const TAIL_N := 11
const TAIL_LEN := 10.0
const TAIL_SIDE := 10.0
const TAIL_R0 := 0.45
const TAIL_R1 := 0.14
const TAIL_TURN := 0.45
## Череп: центр (x вбок, z вдоль оси), длина, поперёк по дну и в высоту; поворот (рад) вокруг вертикали;
## насколько утоплен; колец вдоль и вершин по кругу (≤ 1200 треуг. вместе с изнанкой и окнами).
const SKULL_X := 13.5
const SKULL_Z := 17.5
const SKULL_LEN := 8.0
const SKULL_W := 6.0
const SKULL_H := 5.0
const SKULL_YAW := 0.22
const SKULL_SINK := 0.6
const SKULL_RINGS := 14
const SKULL_SIDES := 16
## Изнанка черепа (доля радиуса) — видна сквозь окна.
const SKULL_INNER := 0.8
## Окна черепа: (кольцо от, кольцо до, сторона от, сторона до) включительно; сторона 4 — вверх, 0 — наружу.
const WINDOWS: Array[Vector4i] = [
	Vector4i(5, 6, 3, 5),    # глазница
	Vector4i(2, 3, 2, 3),    # височное окно
	Vector4i(2, 3, 5, 6),    # второе височное
	Vector4i(8, 10, 4, 4),   # ноздря
	Vector4i(8, 9, 1, 1),    # предглазничное
	Vector4i(3, 4, 7, 7),    # окно к клетке
]
## Нижняя челюсть: дуга у черепа снаружи, точек, радиус.
const JAW_N := 10
const JAW_R := 0.38
## Обрастание: кустиков на ребре, на каждом JAW_EVERY-м позвонке, на черепе; высота кустика.
const TUFTS_RIB := 2
const TUFT_EVERY := 3
const TUFTS_SKULL := 8
const TUFT_H := 0.4
## Мох у рёбер (ART-030: «рёбра обросли мхом»): пятна светящегося мха EcoMoss у ног рёбер — пары MOSS_PAIRS,
## сторона чередуется; середина пятна на MOSS_IN ближе к оси, чем нога, — пятно обнимает ногу и заходит в проход
## (мох плоский, по дну, проходу не мешает). Мох свой у костей: скребуны рифа его не объедают.
const MOSS_PAIRS: Array[int] = [1, 2, 3, 4, 5, 6]
const MOSS_IN := 1.2
## Препятствие для проверок: радиус от центра клетки, м (вся фигура с хвостом и черепом).
const OBSTACLE_R := 26.0
## Зерно формы — своё, не мира.
const SHAPE_SEED := 2030

## Поворот осей скелета; начало — центр клетки на высоте 0.
var base := Vector3.ZERO
var basis := Basis.IDENTITY
## Высота дна (мир передаёт при сбросе; без дна — ровно −46 м).
var ground: Callable
## Рёбра: z каждой пары и низ прохода у пары (самое высокое дно поперёк прохода).
var rib_z := PackedFloat32Array()
var rib_floor := PackedFloat32Array()
## Осевые линии рёбер (локально): ребро r = пара·2 + сторона (0 — слева), RIB_PTS точек на ребро; толщины.
var rib_pts := PackedVector3Array()
var rib_r := PackedFloat32Array()
## Центр арки каждого ребра (локально) — откуда «наружу».
var rib_mid := PackedVector3Array()
## Позвонки (локально): центр, радиус и направление хребта; первые SPINE_N — над клеткой, дальше хвост.
var vert_c := PackedVector3Array()
var vert_r := PackedFloat32Array()
var vert_dir := PackedVector3Array()
## Череп: оси (локально: x — длина к носу, y — поперёк к клетке… см. skull_point), центр; профиль по кольцам.
var skull := Transform3D.IDENTITY
## Нижняя челюсть (локально): точки дуги.
var jaw := PackedVector3Array()
## Обрастание (локально): корни кустиков и нормаль поверхности.
var tuft_c := PackedVector3Array()
var tuft_n := PackedVector3Array()
## Капсулы костей для столкновения (локально): концы и радиус.
var cap_a := PackedVector3Array()
var cap_b := PackedVector3Array()
var cap_r := PackedFloat32Array()
## Мох у ног рёбер (свои пятна, MossView рисует их у BonesView).
var moss: EcoMoss

var _center: Vector2
var _skull_inv := Transform3D.IDENTITY


## center — своё место (для тестов), по умолчанию — с карты отмели.
func _init(center: Vector2 = CENTER) -> void:
	_center = center


func reset(world: EcoWorld) -> void:
	ground = world.ground
	_build()
	moss = EcoMoss.new(moss_spots())
	moss.reset(world)


func step(world: EcoWorld, dt: float) -> void:
	if moss:
		moss.step(world, dt)


## Места пятен мха (мир, y — дно): у ноги ребра пары MOSS_PAIRS[i], сторона чередуется (чётные — слева).
func moss_spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in MOSS_PAIRS.size():
		var k := MOSS_PAIRS[i]
		var foot := rib_point(k * 2 + i % 2, 0)
		var x := foot.x - signf(foot.x) * MOSS_IN
		var w := to_world(Vector3(x, 0.0, rib_z[k]))
		w.y = floor_y(w.x, w.z)
		out.append(w)
	return out


## Точек на осевой линии ребра: нога в дне + дуга.
static func rib_points() -> int:
	return ARCH_SEGS + 2


## Дно под (x, z) мира: мир передаёт Seabed.height; без него — −46 м.
func floor_y(x: float, z: float) -> float:
	return float(ground.call(x, z)) if ground.is_valid() else -46.0


## Дно под локальной точкой (x, z).
func floor_local(x: float, z: float) -> float:
	var w := to_world(Vector3(x, 0.0, z))
	return floor_y(w.x, w.z)


## Поворот: локальная +Z — к FROM.
static func make_basis(center: Vector2) -> Basis:
	var to := FROM - center
	return Basis(Vector3.UP, atan2(to.x, to.y))


func to_world(local: Vector3) -> Vector3:
	return base + basis * local


func to_local(p: Vector3) -> Vector3:
	return basis.inverse() * (p - base)


## Ось клетки в мире (к голове).
func axis() -> Vector3:
	return basis * Vector3.BACK


## Низ прохода на длине z (локально): между парами — по прямой, за клеткой — у крайней пары.
func pass_floor(z: float) -> float:
	if z <= rib_z[0]:
		return rib_floor[0]
	for k in PAIRS - 1:
		if z <= rib_z[k + 1]:
			return lerpf(rib_floor[k], rib_floor[k + 1], (z - rib_z[k]) / (rib_z[k + 1] - rib_z[k]))
	return rib_floor[PAIRS - 1]


## Самое высокое дно поперёк прохода на длине z (локально).
func strip_floor(z: float) -> float:
	var top := -INF
	for q in 15:
		top = maxf(top, floor_local(lerpf(-PASS_W * 0.5, PASS_W * 0.5, q / 14.0), z))
	return top


## Единичный суперэллипс в направлении θ: |x|^n + |y|^n = 1.
static func superellipse(th: float) -> Vector2:
	var c := cos(th)
	var s := sin(th)
	var rho := 1.0 / pow(pow(absf(c), ARCH_N) + pow(absf(s), ARCH_N), 1.0 / ARCH_N)
	return Vector2(c, s) * rho


## Точка осевой линии ребра r, номер i (0 — нога в дне, rib_points() − 1 — вершина у хребта).
func rib_point(r: int, i: int) -> Vector3:
	return rib_pts[r * rib_points() + i]


func rib_radius(r: int, i: int) -> float:
	return rib_r[r * rib_points() + i]


## Точка поверхности черепа: u 0…1 от затылка к носу, φ по кругу (0 — наружу от клетки, π/2 — вверх),
## f — доля радиуса. Локальные оси скелета.
func skull_point(u: float, ph: float, f: float = 1.0) -> Vector3:
	var r := skull_profile(u) * f
	return skull * Vector3((u - 0.5) * SKULL_LEN, sin(ph) * SKULL_H * 0.5 * r, cos(ph) * SKULL_W * 0.5 * r)


## Профиль черепа: круглый затылок, к носу сужается.
static func skull_profile(u: float) -> float:
	if u < 0.3:
		return maxf(0.08, sqrt(1.0 - pow((0.3 - u) / 0.3, 2.0)))
	return 1.0 - 0.86 * pow((u - 0.3) / 0.7, 1.25)


## Кольцо черепа i → u.
static func skull_u(i: int) -> float:
	return float(i) / (SKULL_RINGS - 1)


## Клетка черепа (кольца i…i + 1, стороны j…j + 1) — окно.
static func window(i: int, j: int) -> bool:
	for w in WINDOWS:
		if i >= w.x and i <= w.y and j >= w.z and j <= w.w:
			return true
	return false


func _build() -> void:
	basis = make_basis(_center)
	base = Vector3(_center.x, 0.0, _center.y)
	var rng := EcoRandom.new(SHAPE_SEED)
	# пары рёбер и низ прохода у каждой
	rib_z.clear()
	rib_floor.clear()
	for k in PAIRS:
		var z := -CAGE_LEN * 0.5 + CAGE_LEN * k / (PAIRS - 1)
		rib_z.append(z)
		rib_floor.append(strip_floor(z))
	# рёбра: нога уходит в дно, дальше арка суперэллипса от низа прохода до вершины у хребта
	rib_pts.clear()
	rib_r.clear()
	rib_mid.clear()
	cap_a.clear()
	cap_b.clear()
	cap_r.clear()
	for k in PAIRS:
		var w := 1.0 + BARREL * sin(PI * k / (PAIRS - 1))
		var b := rib_floor[k] - SINK
		for side in 2:
			var sx := -1.0 if side == 0 else 1.0
			var x0 := sx * HALF_W * w
			var foot := minf(floor_local(x0, rib_z[k]), b + SINK) - SINK - 0.6
			rib_pts.append(Vector3(x0, foot, rib_z[k]))
			rib_r.append(RIB_R0)
			for i in ARCH_SEGS + 1:
				var th := PI * 0.5 * i / ARCH_SEGS
				var e := superellipse(th)
				var up := e.y
				var p := Vector3(sx * HALF_W * w * e.x, b + (RISE + SINK) * up, rib_z[k] - LEAN * up)
				p.x += sx * rng.range_f(0.0, 0.08) * (1.0 - up)   # кость не по линейке
				rib_pts.append(p)
				rib_r.append(lerpf(RIB_R0, RIB_R1, up))
			rib_mid.append(Vector3(0.0, b, rib_z[k]))
	var n := rib_points()
	for r in PAIRS * 2:
		for i in n - 1:
			_capsule(rib_point(r, i), rib_point(r, i + 1), maxf(rib_radius(r, i), rib_radius(r, i + 1)))
	# позвоночник поверх вершин рёбер: от первой пары до последней
	vert_c.clear()
	vert_r.clear()
	vert_dir.clear()
	var z0 := rib_z[0] - LEAN
	var z1 := rib_z[PAIRS - 1] - LEAN
	for v in SPINE_N:
		var z := lerpf(z0, z1, float(v) / (SPINE_N - 1))
		var top := pass_floor(z + LEAN) - SINK + RISE + SINK + RIB_R1 + VERT_R * 0.55
		vert_c.append(Vector3(0.0, top, z))
		vert_r.append(VERT_R * (1.0 - 0.15 * absf(float(v) / (SPINE_N - 1) - 0.6)))
	# хвост: сначала вбок поверх прохода (к низкому склону справа), потом опускается на дно
	var start := vert_c[0]
	for m in range(1, TAIL_N + 1):
		var s := float(m) / TAIL_N
		var side := minf(1.0, s / TAIL_TURN)
		var x := TAIL_SIDE * (1.0 - pow(1.0 - side, 2.0)) * (1.0 - 0.25 * maxf(0.0, s - TAIL_TURN))
		var z := start.z - TAIL_LEN * s
		var drop := pow(maxf(0.0, (s - TAIL_TURN) / (1.0 - TAIL_TURN)), 0.8)
		var rr := lerpf(TAIL_R0, TAIL_R1, s)
		var y := lerpf(start.y, floor_local(x, z) + rr * 0.4, drop)
		vert_c.append(Vector3(x, y, z))
		vert_r.append(rr)
	for v in vert_c.size():
		var d: Vector3
		if v < SPINE_N:
			d = vert_c[mini(v + 1, SPINE_N - 1)] - vert_c[maxi(v - 1, 0)]
		else:
			d = vert_c[v] - vert_c[0 if v == SPINE_N else v - 1]
		vert_dir.append(d.normalized())
	for v in vert_c.size() - 1:
		if v == SPINE_N - 1:
			continue   # хвост растёт от первого позвонка (у хвостового торца), не от головного
		_capsule(vert_c[v], vert_c[v + 1], maxf(vert_r[v], vert_r[v + 1]))
	_capsule(vert_c[0], vert_c[SPINE_N], maxf(vert_r[0], vert_r[SPINE_N]))
	# череп: лежит на боку у головного торца, в SKULL_X от оси, длинной осью вдоль клетки, нос — от клетки
	var sc := Vector3(SKULL_X, 0.0, SKULL_Z)
	var g := INF
	for q in 9:
		var a := TAU * q / 8.0
		var p := sc + Vector3(cos(a) * SKULL_W * 0.4, 0.0, sin(a) * SKULL_LEN * 0.4) * (0.0 if q == 8 else 1.0)
		g = minf(g, floor_local(p.x, p.z))
	sc.y = g + SKULL_H * 0.5 - SKULL_SINK
	# оси черепа: x — длина (к носу, вдоль +Z с поворотом), y — высота черепа (лежит на боку: вверх), z — ширина
	var along := Vector3(sin(SKULL_YAW), 0.0, cos(SKULL_YAW))
	var tilt := Basis(along, 0.12)   # чуть завален к клетке
	var bx := tilt * along
	var by := tilt * Vector3.UP
	var bz := bx.cross(by).normalized()
	if bz.x < 0.0:
		bz = -bz   # φ = 0 — наружу от клетки (+X)
	skull = Transform3D(Basis(bx, by, bz), sc)
	_skull_inv = skull.affine_inverse()
	# нижняя челюсть: дуга снаружи черепа, на дне
	jaw.clear()
	for q in JAW_N:
		var t := float(q) / (JAW_N - 1)
		var p := skull * Vector3((t - 0.45) * SKULL_LEN * 0.95, 0.0, SKULL_W * 0.5 + 1.0 + 0.6 * sin(PI * t))
		p.y = floor_local(p.x, p.z) + JAW_R * 0.5 + 0.25 * sin(PI * t)
		jaw.append(p)
	for q in JAW_N - 1:
		_capsule(jaw[q], jaw[q + 1], JAW_R)
	# обрастание: на рёбрах (у ноги и выше), на позвонках, на черепе у окон и у дна
	tuft_c.clear()
	tuft_n.clear()
	for r in PAIRS * 2:
		for q in TUFTS_RIB:
			var i := 2 if q == 0 else 2 + rng.index(n - 4)
			var c := rib_point(r, i)
			var out := c - rib_mid[r]
			out = Vector3(out.x, out.y, 0.0).normalized()
			var tw := out.rotated(Vector3(0, 0, 1), rng.range_f(-0.6, 0.6))
			_tuft(c + tw * rib_radius(r, i), tw)
	for v in range(0, vert_c.size(), TUFT_EVERY):
		var up := Vector3(rng.range_f(-0.5, 0.5), 1.0, 0.0).normalized()
		_tuft(vert_c[v] + up * vert_r[v], up)
	var tries := 0
	var placed := 0
	while placed < TUFTS_SKULL and tries < 400:
		tries += 1
		var u := rng.range_f(0.15, 0.8)
		var ph := rng.range_f(-0.3, PI + 0.3)
		var p := skull_point(u, ph)
		var e := 0.02
		var nrm := (skull_point(u, ph + e) - skull_point(u, ph - e)).cross(
			skull_point(u + e, ph) - skull_point(u - e, ph)).normalized()
		if nrm.dot(p - skull.origin) < 0.0:
			nrm = -nrm
		if window(int(u * (SKULL_RINGS - 1)), int(fposmod(ph, TAU) / TAU * SKULL_SIDES)):
			continue
		_tuft(p, nrm)
		placed += 1


func _capsule(a: Vector3, b: Vector3, r: float) -> void:
	cap_a.append(a)
	cap_b.append(b)
	cap_r.append(r)


func _tuft(c: Vector3, n: Vector3) -> void:
	tuft_c.append(c)
	tuft_n.append(n)


## Расстояние от p до отрезка a–b.
static func seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Внутри черепа (локальная точка скелета).
func in_skull(q: Vector3) -> bool:
	var s := _skull_inv * q
	var u := s.x / SKULL_LEN + 0.5
	if u < 0.0 or u > 1.0:
		return false
	var r := skull_profile(u)
	return pow(s.y / (SKULL_H * 0.5 * r), 2.0) + pow(s.z / (SKULL_W * 0.5 * r), 2.0) < 1.0


## Точка (в мире) внутри кости — для существ и столкновения корабля (подключает поток А).
func solid(p: Vector3) -> bool:
	var q := to_local(p)
	if Vector2(q.x, q.z).length() > OBSTACLE_R:
		return false
	if in_skull(q):
		return true
	for c in cap_a.size():
		if seg_dist(q, cap_a[c], cap_b[c]) < cap_r[c]:
			return true
	return false


## Верхняя точка (мир).
func top() -> Vector3:
	var best := vert_c[0]
	for v in vert_c:
		if v.y > best.y:
			best = v
	return to_world(best + Vector3(0, VERT_R, 0))
