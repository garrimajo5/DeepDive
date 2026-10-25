class_name EcoFishLook
extends RefCounted
## Как выглядит светляк-полосник по концепту ART-011 (`docs/concept-art/svetlyak-ognevka-vidy.png`, Unity
## `Core/EcoFishLook.cs`): тёмное веретено #344F63 с четырьмя поперечно-диагональными полосами живого света и плоский
## хвост с подсвеченными концами. Размер — как в браузере (тело 0,14 × 0,2 × 0,56 м, с хвостом 0,7 м). Полосы — цвет
## стаи (EcoFish.COLORS) × своя яркость рыбки, в тревоге горят ярче. Нос смотрит по скорости, рыбка виляет на ±0,25 рад.
## Съеденная стягивается в точку. Форма одна на всех — в сцене один MultiMesh (FishView), каждой рыбке — своя
## расстановка basis() и цвет полос stripe().
## Оси формы: x — бок, y — спина, z — нос. Грани тела — по правилу Godot: обход по часовой, если смотреть снаружи
## ((b − a) × (c − a) смотрит внутрь); хвост — один треугольник в обе стороны.

## Во сколько раз ярче полосы стаи в тревоге.
const ALARM_GLOW := 1.6
## Виляние: размах (рад) и частота (рад/с).
const WIGGLE := 0.25
const WIGGLE_RATE := 12.0
## Тело: полуширина, полувысота, нос и корма по z (м).
const HALF_WIDTH := 0.07
const HALF_HEIGHT := 0.1
const NOSE := 0.28
const BACK := -0.25
## Наклон полос: верх кольца сдвинут к носу, низ — к хвосту (м).
const SLANT := 0.015
## Цвет тела по ART-011.
const BODY_COLOR := Color("344F63")
## Доля цвета полос на концах хвоста.
const FIN_GLOW := 0.6
## Разброс особей (Б4, EcoVary): размер ±12 %, тело светлее-темнее ±20 %, частота виляния ±15 %.
const SIZE_SPREAD := 0.12
const SHADE_SPREAD := 0.2
const RATE_SPREAD := 0.15
## Волна хвоста (Б3): задняя часть тела и хвост гнутся вбок бегущей волной к кончику, поверх виляния всего тела.
## Гнётся то, что за TAIL_FROM (м по z), сильнее к кончику TAIL_TIP (квадрат доли); размах кончика TAIL_AMP (м),
## частота TAIL_RATE (рад/с, у особи ±TAIL_RATE_SPREAD по фазе), волна вдоль тела TAIL_K (рад/м). В шейдере FishView —
## двойник tail_wave; фаза особи — tail_phase в альфе цвета экземпляра.
const TAIL_FROM := 0.05
const TAIL_TIP := -0.42
const TAIL_AMP := 0.05
const TAIL_RATE := 9.0
const TAIL_RATE_SPREAD := 0.15
const TAIL_K := 9.0
## Взмах грудных плавников (Б3, у форм с весом в канале b цвета вершины — пестрянки EcoPestrLook; у светляка вес 0):
## кончик ходит вверх-вниз на ±PEC_AMP (м формы) с частотой PEC_RATE (рад/с), правый и левый — со сдвигом PEC_SKEW
## (рад) — гребут вразнобой. Двойник шейдера FishView — fin_flap.
const PEC_AMP := 0.035
const PEC_RATE := 6.0
const PEC_SKEW := 1.2

## Чем окрашена вершина.
enum Paint { BODY, STRIPE, FIN }

## Кольца тела от носа к хвосту: z середины кольца и полоса ли это (четыре полосы).
const RING_Z: Array[float] = [0.22, 0.16, 0.10, 0.04, -0.02, -0.08, -0.14, -0.19, -0.23]
const RING_STRIPE: Array[bool] = [false, true, false, true, false, true, false, true, false]

## Вершины рыбки в её осях, краски, нормали и треугольники.
static var shape := PackedVector3Array()
static var paints := PackedInt32Array()
static var normals := PackedVector3Array()
static var tris := PackedInt32Array()
## Вершина первого кольца-полосы (для тестов).
static var stripe_vertex := -1


static func _static_init() -> void:
	_build()


static func verts_per_fish() -> int:
	return shape.size()


static func _add(p: Vector3, c: Paint, n: Vector3) -> int:
	shape.append(p)
	paints.append(c)
	normals.append(n)
	return shape.size() - 1


## Треугольник тела, повёрнутый по правилу Godot: (b − a) × (c − a) — к оси тела (внутрь).
static func _tri(a: int, b: int, c: int) -> void:
	var n := (shape[b] - shape[a]).cross(shape[c] - shape[a])
	var m := (shape[a] + shape[b] + shape[c]) / 3.0
	var o := Vector3(m.x, m.y, m.z * 0.5)
	if n.dot(o) > 0.0:
		var s := b
		b = c
		c = s
	tris.append_array([a, b, c])


## Нормаль веретена в точке: от оси наружу, как у эллипсоида.
static func _body_normal(p: Vector3) -> Vector3:
	var l := NOSE if p.z >= 0.0 else -BACK
	var n := Vector3(p.x / (HALF_WIDTH * HALF_WIDTH), p.y / (HALF_HEIGHT * HALF_HEIGHT), p.z / (l * l))
	return n.normalized() if n.length_squared() > 1e-9 else Vector3(0, 0, 1)


static func _build() -> void:
	shape.clear()
	paints.clear()
	normals.clear()
	tris.clear()
	var nose := _add(Vector3(0, 0, NOSE), Paint.BODY, Vector3(0, 0, 1))
	var ring: Array[int] = []
	stripe_vertex = -1
	for r in RING_Z.size():
		var z := RING_Z[r]
		var l := NOSE if z >= 0.0 else -BACK
		var s := sqrt(maxf(0.0, 1.0 - (z / l) * (z / l)))
		var c := Paint.STRIPE if RING_STRIPE[r] else Paint.BODY
		var pts := [Vector3(HALF_WIDTH * s, 0, z), Vector3(0, HALF_HEIGHT * s, z + SLANT),
			Vector3(-HALF_WIDTH * s, 0, z), Vector3(0, -HALF_HEIGHT * s, z - SLANT)]
		ring.append(shape.size())
		for p: Vector3 in pts:
			_add(p, c, _body_normal(p))
		if stripe_vertex < 0 and RING_STRIPE[r]:
			stripe_vertex = ring[r]
	var back := _add(Vector3(0, 0, BACK), Paint.BODY, Vector3(0, 0, -1))
	var last := ring[RING_Z.size() - 1]
	for j in 4:
		var k := (j + 1) % 4
		_tri(nose, ring[0] + j, ring[0] + k)
		_tri(back, last + k, last + j)
	for r in RING_Z.size() - 1:
		for j in 4:
			var k := (j + 1) % 4
			_tri(ring[r] + j, ring[r] + k, ring[r + 1] + k)
			_tri(ring[r] + j, ring[r + 1] + k, ring[r + 1] + j)
	var root := _add(Vector3(0, 0, -0.22), Paint.BODY, Vector3(1, 0, 0))
	var up := _add(Vector3(0, 0.12, -0.42), Paint.FIN, Vector3(1, 0, 0))
	var down := _add(Vector3(0, -0.12, -0.42), Paint.FIN, Vector3(1, 0, 0))
	tris.append_array([root, up, down, root, down, up])


## Яркость полос: своя яркость рыбки, в тревоге стаи — ярче в ALARM_GLOW раз.
static func brightness(f: EcoFish.Fish) -> float:
	return f.bright * (ALARM_GLOW if f.shoal.alarm > 0.0 else 1.0)


## Цвет полос рыбки: цвет стаи × brightness (может быть больше 1 — горит ярко).
static func stripe(f: EcoFish.Fish) -> Color:
	var c := f.shoal.color
	var k := brightness(f)
	return Color(c.r * k, c.g * k, c.b * k)


## Размер рыбки в форме: свой у каждой особи (EcoVary) × размер возраста (молодь мельче).
static func scale(f: EcoFish.Fish) -> float:
	return f.size * EcoVary.spread(f.index, EcoVary.SIZE, SIZE_SPREAD)


## Множитель цвета тела особи: одни рыбки светлее, другие темнее.
static func shade(f: EcoFish.Fish) -> float:
	return EcoVary.spread(f.index, EcoVary.SHADE, SHADE_SPREAD)


## Частота виляния особи (рад/с): стая не машет хвостами в лад.
static func wiggle_rate(f: EcoFish.Fish) -> float:
	return WIGGLE_RATE * EcoVary.spread(f.index, EcoVary.RATE, RATE_SPREAD)


## Доля изгиба точки формы с z (0 — жёсткая голова, 1 — кончик хвоста): квадрат доли пути от TAIL_FROM к TAIL_TIP.
static func tail_bend(z: float) -> float:
	var s := clampf((TAIL_FROM - z) / (TAIL_FROM - TAIL_TIP), 0.0, 1.0)
	return s * s


## Фаза волны хвоста особи (доля оборота 0…1): от её фазы виляния — соседки в стае машут вразнобой.
static func tail_phase(f: EcoFish.Fish) -> float:
	return fposmod(f.phase / TAU, 1.0)


## Сдвиг вбок (м, по оси x формы) точки формы с z в момент t шейдера у особи с фазой a (tail_phase); sway_k — 0
## на «Экономно». Двойник вершинного шейдера FishView.
static func tail_wave(z: float, t: float, a: float, sway_k := 1.0) -> float:
	var rate := TAIL_RATE * (1.0 - TAIL_RATE_SPREAD + 2.0 * TAIL_RATE_SPREAD * fposmod(a * 7.13, 1.0))
	return sin(t * rate + a * TAU + z * TAIL_K) * TAIL_AMP * tail_bend(z) * sway_k


## Сдвиг вверх (м, по оси y формы) точки плавника с боком x и весом взмаха w (канал b цвета вершины) в момент t
## у особи с фазой a; sway_k — 0 на «Экономно». Двойник вершинного шейдера FishView.
static func fin_flap(x: float, w: float, t: float, a: float, sway_k := 1.0) -> float:
	return sin(t * PEC_RATE + a * TAU + signf(x) * PEC_SKEW) * PEC_AMP * w * sway_k


## Цвет тела особи: BODY_COLOR × shade().
static func body_color(f: EcoFish.Fish) -> Color:
	var k := shade(f)
	return Color(BODY_COLOR.r * k, BODY_COLOR.g * k, BODY_COLOR.b * k)


## Цвет вершины по краске: тело тёмное (своего оттенка, в тревоге не меняется), полосы и концы хвоста — светом стаи.
static func vertex_color(f: EcoFish.Fish, p: Paint) -> Color:
	if p == Paint.BODY:
		return body_color(f)
	var c := stripe(f)
	return Color(c.r * FIN_GLOW, c.g * FIN_GLOW, c.b * FIN_GLOW) if p == Paint.FIN else c


## Куда смотрит нос: по скорости (вверх-вниз тоже), с вилянием вокруг вертикали.
static func forward(f: EcoFish.Fish, t: float) -> Vector3:
	var v := f.agent.v
	var dir := v.normalized() if v.length_squared() > 1e-8 else Vector3(0, 0, 1)
	var w := sin(t * wiggle_rate(f) + f.phase) * WIGGLE
	var cw := cos(w)
	var sw := sin(w)
	return Vector3(dir.x * cw + dir.z * sw, dir.y, -dir.x * sw + dir.z * cw)


## Расстановка рыбки в мире: столбцы — бок, спина, нос формы (× scale(): своя у особи, молодь мельче). Съеденная — нулевой basis (стянута в точку).
static func basis(f: EcoFish.Fish, t: float) -> Basis:
	if not f.agent.alive:
		return Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
	var fw := forward(f, t)
	# бок = вверх × вперёд; рыбка, идущая отвесно, берёт ось x
	var side := Vector3(fw.z, 0, -fw.x)
	side = side.normalized() if side.length() > 1e-4 else Vector3(1, 0, 0)
	var up := fw.cross(side)
	var k := scale(f)
	return Basis(side * k, up * k, fw * k)


## Место вершины i формы для рыбки в момент t (то, что нарисует MultiMesh).
static func place(f: EcoFish.Fish, t: float, i: int) -> Vector3:
	return f.agent.p + basis(f, t) * shape[i]
