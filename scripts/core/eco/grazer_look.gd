class_name EcoGrazerLook
extends RefCounted
## Как выглядит скребун по концепту ART-006 (`docs/concept-art/stekloust-skrebun-rakursy.png`, Unity
## `Core/EcoGrazerLook.cs`): донный панцирник 1,5 м — купол панциря (полуэллипсоид 1,1 × 0,32 × 1,5 м, кромка светлее),
## мягкий нижний корпус, скребок спереди внизу и ровно шесть лап из двух сегментов и плоской стопы. Своего света нет.
## На ходу лапы шагают двумя тройками (опора всегда на трёх), пока пасётся — скребок ходит короткими циклами. Съеденный
## скребун стягивается в точку. Форма одна на всех — в сцене один MultiMesh (GrazerView): каждому скребуну своя
## расстановка basis() и поза custom() — её разбирает шейдер так же, как place() здесь.
## Оси формы: x — бок, y — вверх от стоп, z — нос (как у рыбки EcoFishLook). Части выпуклые, грани — по правилу Godot:
## обход по часовой, если смотреть снаружи ((b − a) × (c − a) смотрит внутрь части).

## Купол панциря: полуоси по x, y, z и высота его основания над стопами (м).
const SHELL_X := 0.55
const SHELL_Y := 0.32
const SHELL_Z := 0.75
const SHELL_BASE := 0.32
## Шаг лап: размах поворота у бедра (рад), подъём стопы (м), частота (рад/с).
const SWING := 0.3
const STEP_LIFT := 0.06
const STEP_RATE := 5.0
## Скребок пасущегося: ход вниз (м) и частота (рад/с).
const SCRAPE_DEPTH := 0.05
const SCRAPE_RATE := 7.0

## Краски по палитре ART-006.
const SHELL := Color("344D54")
const RIM := Color("819799")
const UNDER := Color("23333A")
const LEG := Color("2E4148")

## Разброс особей (Б4, EcoVary): размер ±10 %, светлее-темнее ±12 %, оттенок — к ржавому или к холодному на 6 %.
const SIZE_SPREAD := 0.1
const SHADE_SPREAD := 0.12
const HUE_SPREAD := 0.06

## Часть, к которой относится вершина: лапа 0–5, скребок или корпус.
const BODY := -1
const SCRAPER := 6

## Вершины скребуна в его осях, краски, части и треугольники.
static var rest := PackedVector3Array()
static var paint := PackedColorArray()
static var part := PackedInt32Array()
static var tris := PackedInt32Array()
## Бёдра шести лап: 0–2 борт −x спереди назад, 3–5 борт +x.
static var hips := PackedVector3Array()
## Форма на «Экономно» (Б6, GrazerView.set_lite): купол 8 долек × 2 кольца вместо 12 × 3, лапы без подушек стоп —
## 312 → 200 треугольников; те же части, бёдра и краски, лапы и скребок двигает тот же шейдер.
const AROUND := 12
const RINGS := 3
const LITE_AROUND := 8
const LITE_RINGS := 2
static var lite_rest := PackedVector3Array()
static var lite_paint := PackedColorArray()
static var lite_part := PackedInt32Array()
static var lite_tris := PackedInt32Array()


static func _static_init() -> void:
	_build(true)
	lite_rest = rest.duplicate()
	lite_paint = paint.duplicate()
	lite_part = part.duplicate()
	lite_tris = tris.duplicate()
	_build()


static func verts_per_grazer() -> int:
	return rest.size()


static func _add(p: Vector3, c: Color, pt: int) -> int:
	rest.append(p)
	paint.append(c)
	part.append(pt)
	return rest.size() - 1


## Треугольник по правилу Godot: (b − a) × (c − a) смотрит к center (внутрь выпуклой части).
static func _tri(a: int, b: int, c: int, center: Vector3) -> void:
	var n := (rest[b] - rest[a]).cross(rest[c] - rest[a])
	var mid := (rest[a] + rest[b] + rest[c]) / 3.0 - center
	if n.dot(mid) > 0.0:
		var s := b
		b = c
		c = s
	tris.append_array([a, b, c])


static func _quad(a: int, b: int, c: int, d: int, center: Vector3) -> void:
	_tri(a, b, c, center)
	_tri(a, c, d, center)


static func _build(lite := false) -> void:
	rest.clear()
	paint.clear()
	part.clear()
	tris.clear()
	hips.clear()
	_build_shell(LITE_AROUND if lite else AROUND, LITE_RINGS if lite else RINGS)
	_add_box(Vector3(0, (0.15 + SHELL_BASE) / 2.0, 0), Vector3(0.4, (SHELL_BASE - 0.15) / 2.0, 0.55), UNDER, BODY)
	_add_box(Vector3(0, 0.13, 0.66), Vector3(0.18, 0.08, 0.1), RIM, SCRAPER)
	for side in 2:
		for k in 3:
			var leg := side * 3 + k
			var s := -1.0 if side == 0 else 1.0
			var z := 0.4 - k * 0.4
			var hip := Vector3(s * 0.38, 0.28, z)
			var knee := Vector3(s * 0.75, 0.42, z + (1 - k) * 0.08)
			var foot := Vector3(s * 0.95, 0.03, z + (1 - k) * 0.12)
			hips.append(hip)
			_add_beam(hip, knee, 0.04, LEG, leg)
			_add_beam(knee, foot, 0.035, LEG, leg)
			if not lite:
				_add_box(Vector3(foot.x, 0.015, foot.z), Vector3(0.1, 0.015, 0.1), LEG, leg)


## Купол: around долек × rings колец (12 × 3, на «Экономно» 8 × 2) и макушка, снизу закрыт плоским дном.
static func _build_shell(around: int, rings: int) -> void:
	var center := Vector3(0, SHELL_BASE + SHELL_Y * 0.35, 0)
	var first := rest.size()
	for r in rings:
		var phi := r * (PI / 2.0) / rings
		for i in around:
			var th := i * TAU / around
			var p := Vector3(SHELL_X * cos(phi) * sin(th), SHELL_BASE + SHELL_Y * sin(phi), SHELL_Z * cos(phi) * cos(th))
			_add(p, RIM if r == 0 else SHELL, BODY)
	var top := _add(Vector3(0, SHELL_BASE + SHELL_Y, 0), SHELL, BODY)
	var bottom := _add(Vector3(0, SHELL_BASE, 0), UNDER, BODY)
	for r in rings - 1:
		for i in around:
			var j := (i + 1) % around
			_quad(first + r * around + i, first + r * around + j, first + (r + 1) * around + j,
				first + (r + 1) * around + i, center)
	for i in around:
		var j := (i + 1) % around
		_tri(first + (rings - 1) * around + i, first + (rings - 1) * around + j, top, center)
		_tri(first + i, first + j, bottom, center)


## Брусок с серединой c и полуразмерами h по осям.
static func _add_box(c: Vector3, h: Vector3, color: Color, pt: int) -> void:
	var b := rest.size()
	for i in 8:
		_add(Vector3(c.x + (h.x if i & 1 else -h.x), c.y + (h.y if i & 2 else -h.y), c.z + (h.z if i & 4 else -h.z)), color, pt)
	_box_faces(b, c)


## Сегмент лапы: четырёхгранный брусок толщиной 2w от p0 до p1.
static func _add_beam(p0: Vector3, p1: Vector3, w: float, color: Color, pt: int) -> void:
	var d := (p1 - p0).normalized()
	var u := Vector3(d.z, 0, -d.x)  # поперёк, горизонтально
	u = u.normalized() if u.length_squared() > 1e-6 else Vector3(1, 0, 0)
	var n := d.cross(u)
	var b := rest.size()
	for i in 8:
		var o := (p1 if i & 4 else p0) + u * (w if i & 1 else -w) + n * (w if i & 2 else -w)
		_add(o, color, pt)
	_box_faces(b, (p0 + p1) * 0.5)


## Шесть граней бруска из 8 вершин (бит 0 — первая ось, бит 1 — вторая, бит 2 — третья).
static func _box_faces(b: int, center: Vector3) -> void:
	_quad(b + 0, b + 1, b + 3, b + 2, center)
	_quad(b + 4, b + 5, b + 7, b + 6, center)
	_quad(b + 0, b + 1, b + 5, b + 4, center)
	_quad(b + 2, b + 3, b + 7, b + 6, center)
	_quad(b + 0, b + 2, b + 6, b + 4, center)
	_quad(b + 1, b + 3, b + 7, b + 5, center)


## Идёт ли скребун (лапы шагают): жив, не пасётся и движется.
static func walking(g: EcoGrazer.Grazer) -> bool:
	return g.agent.alive and g.agent.state != EcoAgent.State.GRAZE and g.agent.v.length_squared() > 0.01


## Тройка лапы: передняя и задняя одного борта и средняя другого — +1, остальные — −1.
static func tripod(leg: int) -> int:
	return 1 if ((leg / 3) + (leg % 3)) % 2 == 0 else -1


## Фаза шага скребуна в момент t: −1…1, у стоящего — 0. Поза лапы — фаза × tripod(leg). Размах — по доле шага
## (EcoGrazer.WALK_SPEED): трогаясь и тормозя, лапы шагают мельче, а не замирают посреди шага.
static func stride(g: EcoGrazer.Grazer, t: float) -> float:
	if not walking(g):
		return 0.0
	return sin(t * STEP_RATE + g.index * 1.3) * clampf(g.agent.v.length() / EcoGrazer.WALK_SPEED, 0.0, 1.0)


## Поворот лапы у бедра вокруг вертикали (рад) и подъём стопы (м) в момент t: [angle, lift].
static func leg_pose(g: EcoGrazer.Grazer, leg: int, t: float) -> Vector2:
	var s := stride(g, t) * tripod(leg)
	return Vector2(SWING * s, STEP_LIFT * maxf(0.0, s))


## Насколько опущен скребок (м): ходит, только пока скребун пасётся.
static func scrape(g: EcoGrazer.Grazer, t: float) -> float:
	return SCRAPE_DEPTH * 0.5 * (1.0 + sin(t * SCRAPE_RATE + g.index)) if g.grazing() else 0.0


## Вперёд по курсу: (sin dir, 0, cos dir).
static func forward(g: EcoGrazer.Grazer) -> Vector3:
	return Vector3(sin(g.dir), 0, cos(g.dir))


## Расстановка формы в мире: столбцы — бок, вверх, нос; съеденный — нулевой basis (стянут в точку).
static func basis(g: EcoGrazer.Grazer) -> Basis:
	if not g.agent.alive:
		return Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
	var fw := forward(g)
	var k := scale(g)
	return Basis(Vector3(fw.z, 0, -fw.x) * k, Vector3.UP * k, fw * k)


## Размер скребуна: свой у каждой особи (EcoVary); стопы остаются на дне — начало формы под ними.
static func scale(g: EcoGrazer.Grazer) -> float:
	return EcoVary.spread(g.index, EcoVary.SIZE, SIZE_SPREAD)


## Множитель красок особи — цвет экземпляра MultiMesh (GrazerView): светлее или темнее, теплее или холоднее.
static func tint(g: EcoGrazer.Grazer) -> Color:
	var k := EcoVary.spread(g.index, EcoVary.SHADE, SHADE_SPREAD)
	var h := (EcoVary.unit(g.index, EcoVary.HUE) * 2.0 - 1.0) * HUE_SPREAD
	return Color(k * (1.0 + h), k, k * (1.0 - h))


## Начало формы: стопы на дне под скребуном (agent.p на EcoGrazer.LIFT выше дна).
static func origin(g: EcoGrazer.Grazer) -> Vector3:
	return g.agent.p - Vector3(0, EcoGrazer.LIFT, 0)


## Поза для шейдера: (фаза шага, ход скребка) — то, что идёт в INSTANCE_CUSTOM.
static func custom(g: EcoGrazer.Grazer, t: float) -> Vector2:
	return Vector2(stride(g, t), scrape(g, t))


## Вершина i формы в позе pose (custom) в осях скребуна — так же двигает её шейдер GrazerView.
static func posed(i: int, pose: Vector2) -> Vector3:
	var r := rest[i]
	var pt := part[i]
	if pt >= 0 and pt < 6:
		var s := pose.x * tripod(pt)
		var ang := SWING * s
		var h := hips[pt]
		var dx := r.x - h.x
		var dz := r.z - h.z
		var c := cos(ang)
		var sn := sin(ang)
		return Vector3(h.x + dx * c + dz * sn, r.y + STEP_LIFT * maxf(0.0, s), h.z - dx * sn + dz * c)
	if pt == SCRAPER:
		return Vector3(r.x, r.y - pose.y, r.z)
	return r


## Место вершины i скребуна в мире в момент t (то, что нарисует MultiMesh).
static func place(g: EcoGrazer.Grazer, t: float, i: int) -> Vector3:
	return origin(g) + basis(g) * posed(i, custom(g, t))
