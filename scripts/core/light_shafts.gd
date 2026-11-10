class_name LightShafts
## Лучи света сквозь трещины льда по ART-052 (`docs/concept-art/luchi.md`): где стоят шахты-конусы, их размеры,
## сила по глубине и затухания. На Forward Mobile объёмного тумана нет — свет рисуется геометрией: один MultiMesh
## аддитивных конусов (рисует `OceanView`, шейдер `shaders/light_shafts.gdshader`, маска и шум — `textures/luchi/`).
## Числа шейдера повторены здесь, чтобы их проверяли тесты.

const COLOR := Color("9AD9E8")      ## цвет шахты
const ICE_COLOR := Color("86BCCB")  ## у самого льда
const CELL := 20.0                  ## клетка раскладки: центр + разброс ±JITTER → между соседями 12…28 м
const JITTER := 4.0
const LEN_MIN := 24.0               ## длина шахты, м
const LEN_MAX := 42.0
const TOP_D := Vector2(0.8, 2.0)    ## диаметр у льда, м
const BOT_D := Vector2(5.0, 13.0)   ## диаметр внизу, м
const TILT_MAX := 8.0               ## наклон, градусы
const CRACK_MIN := 0.5              ## порог открытости сети трещин (`IceSheet.gate`): шахты стоят группами
const EDGE_X := 160.0               ## Край отмели: за ним дно уходит вниз (Seabed.height), шахты гаснут
const EDGE_BAND := 20.0             ## полоса гашения у Края, м
const FLOOR_FADE := 3.0             ## обрыв по дну: затухание 2–4 м
const FAR := Vector2(45.0, 95.0)    ## гаснут вдали
const NEAR := Vector2(0.5, 1.5)     ## у самой камеры гаснут — не заливать стекло
const DEPTH_SCALE := 14.0           ## спад силы по глубине точки, м (ART-052 предлагал 9 — в снимке шахты гасли у льда)
const GAIN := 4.0                   ## общая сила: экспозиция (ART-052 — 1,0); уровни графики ART-044 и устройство поправят
const SEGMENTS := 16                ## граней конуса
const RINGS := 4                    ## поясов по длине


## Одна шахта: верх у льда, ось с наклоном, радиусы, сила 0,5…1, фаза шума, где под ней дно.
class Shaft:
	var top := Vector3.ZERO
	var axis := Vector3.DOWN
	var r_top := 0.5
	var r_bot := 3.0
	var length := 30.0
	var power := 1.0
	var phase := 0.0
	var floor_y := -30.0


## Сила света в точке на глубине depth (м подо льдом) до GAIN: 0,14 у льда, 5 м — 0,098, 30 м — 0,016.
static func intensity(depth: float) -> float:
	return 0.14 * exp(-maxf(depth, 0.0) / DEPTH_SCALE)


## Гашение вдали (1 — рядом, 0 — дальше 95 м).
static func far_k(dist: float) -> float:
	return 1.0 - HashNoise.smooth(FAR.x, FAR.y, dist)


## Гашение у самой камеры.
static func near_k(dist: float) -> float:
	return HashNoise.smooth(NEAR.x, NEAR.y, dist)


## Обрыв по дну: над дном выше FLOOR_FADE — полная сила, у дна и ниже — 0.
static func floor_k(y: float, floor_y: float) -> float:
	return HashNoise.smooth(floor_y, floor_y + FLOOR_FADE, y)


## У Края отмели шахты гаснут полосой EDGE_BAND — без световой стены над обрывом.
static func edge_k(x: float) -> float:
	return 1.0 - HashNoise.smooth(EDGE_X - EDGE_BAND, EDGE_X, x)


## Поле трещин 0…1: где сеть трещин льда открыта (`IceSheet.gate`, ART-056) — там шахты стоят группами.
## Столб «Светового колодца» — свой (поток Б, ART-031).
static func cracks(x: float, z: float) -> float:
	return IceSheet.gate(x, z)


## Основание шахты в клетке: точка сетки 1 м в пределах ±JITTER от центра, где маска трещин льда сильнее всего
## (ART-056: выше `IceSheet.SHAFT_MASK`). Нет такой — Vector2.INF.
static func base(cx: float, cz: float) -> Vector2:
	var best := IceSheet.SHAFT_MASK
	var at := Vector2.INF
	var n := int(JITTER) * 2
	for j in n + 1:
		for i in n + 1:
			var x := cx - JITTER + i
			var z := cz - JITTER + j
			var m := IceSheet.crack(x, z)
			if m > best:
				best = m
				at = Vector2(x, z)
	return at


## Все шахты отмели (детерминированно). size — сторона карты, ground — высота дна (x, z) → y.
static func layout(size: float = Seabed.SIZE, ground: Callable = Seabed.height) -> Array[Shaft]:
	var out: Array[Shaft] = []
	var n := int(size / CELL)
	var half := size / 2.0
	for j in n:
		for i in n:
			var cx := -half + (i + 0.5) * CELL
			var cz := -half + (j + 0.5) * CELL
			var h := HashNoise.hash2(i + 401, j + 977)
			var c := cracks(cx, cz)
			if c < CRACK_MIN or h > 0.25 + c:   # плотность растёт с силой трещин
				continue
			var e := edge_k(cx)
			if e <= 0.0:
				continue
			var s := Shaft.new()
			var at := base(cx, cz)   # верх шахты — на трещине льда (ART-056)
			if at == Vector2.INF:
				continue
			var x := at.x
			var z := at.y
			var floor_y := float(ground.call(x, z))
			s.top = Vector3(x, Seabed.ICE_Y, z)
			s.floor_y = floor_y
			var ha := HashNoise.hash2(i * 13 + 5, j * 17 + 6)
			var hb := HashNoise.hash2(i * 19 + 7, j * 23 + 8)
			var tilt := deg_to_rad(TILT_MAX * hb)
			var dir := ha * TAU
			s.axis = Vector3(sin(tilt) * cos(dir), -cos(tilt), sin(tilt) * sin(dir))
			var hl := HashNoise.hash2(i * 29 + 9, j * 31 + 10)
			# длина не уходит далеко под дно: ниже дна свет не виден (затухание по дну в шейдере)
			s.length = minf(lerpf(LEN_MIN, LEN_MAX, hl), (Seabed.ICE_Y - floor_y) / cos(tilt) + FLOOR_FADE)
			var hr := HashNoise.hash2(i * 37 + 11, j * 41 + 12)
			s.r_top = lerpf(TOP_D.x, TOP_D.y, hr) * 0.5
			s.r_bot = lerpf(BOT_D.x, BOT_D.y, HashNoise.hash2(i * 43 + 13, j * 47 + 14)) * 0.5
			s.power = lerpf(0.5, 1.0, HashNoise.hash2(i * 53 + 15, j * 59 + 16)) * e
			s.phase = HashNoise.hash2(i * 61 + 17, j * 67 + 18)
			out.append(s)
	return out


## Шахты в радиусе r от точки p по горизонтали (сколько их видно рядом с кораблём).
static func near(shafts: Array[Shaft], p: Vector3, r: float) -> Array[Shaft]:
	var out: Array[Shaft] = []
	for s in shafts:
		if Vector2(s.top.x - p.x, s.top.z - p.z).length() <= r:
			out.append(s)
	return out


## Преобразование экземпляра MultiMesh: верх шахты в начале, локальная −Y — вдоль оси шахты.
static func instance_xform(s: Shaft) -> Transform3D:
	var down := s.axis.normalized()
	var y := -down
	var x := y.cross(Vector3.FORWARD).normalized() if absf(y.dot(Vector3.FORWARD)) < 0.99 else Vector3.RIGHT
	var z := x.cross(y).normalized()
	return Transform3D(Basis(x, y, z), s.top)


## Данные экземпляра для шейдера: custom = (r_top, r_bot, length, phase), цвет = (power, floor_y / 100, 0, 1).
static func instance_custom(s: Shaft) -> Color:
	return Color(s.r_top, s.r_bot, s.length, s.phase)


static func instance_color(s: Shaft) -> Color:
	return Color(s.power, -s.floor_y / 100.0, 0.0, 1.0)


## Единичный открытый конус без торцов: точка (cos a, −t, sin a), UV = (a / 2π, t); размеры задаёт шейдер.
## Лицевая сторона — снаружи (обход по часовой, если смотреть снаружи); шейдер рисует обе стороны.
static func cone_arrays(segments: int = SEGMENTS, rings: int = RINGS) -> Array:
	var pos := PackedVector3Array()
	var nor := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	for k in rings + 1:
		var t := float(k) / rings
		for i in segments + 1:
			var a := TAU * i / segments
			pos.append(Vector3(cos(a), -t, sin(a)))
			nor.append(Vector3(cos(a), 0.0, sin(a)))
			uv.append(Vector2(float(i) / segments, t))
			col.append(Color.WHITE)   # цвет экземпляра умножается на цвет вершины
	var row := segments + 1
	for k in rings:
		for i in segments:
			var a0 := k * row + i
			var b0 := a0 + 1
			var a1 := a0 + row
			var b1 := a1 + 1
			idx.append_array([a0, a1, b0, b0, a1, b1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_NORMAL] = nor
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_COLOR] = col
	arr[Mesh.ARRAY_INDEX] = idx
	return arr


## Внутри ли точка корпуса (в осях корабля): шахта не светит сквозь мостик и отсеки. Та же форма — в шейдере.
## SHIP — (полуширина, полувысота, нос, корма) вытянутого эллипса вокруг корпуса HullPlan.
const SHIP := Vector4(6.8, 3.4, HullPlan.NOSE_CUT - 0.2, HullPlan.STERN_END + 0.5)


static func in_ship(local: Vector3) -> bool:
	var ex := local.x / SHIP.x
	var ey := (local.y - HullPlan.CENTER_Y) / SHIP.y
	return ex * ex + ey * ey < 1.0 and local.z > SHIP.z and local.z < SHIP.w
