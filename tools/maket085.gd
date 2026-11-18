extends RefCounted
## Модель-макет батискафа ART-085 v3 (28 × 10 × 9 м) — инструмент проверки, НЕ встройка в игру (#1788,
## комментарий владельца 17.11 14:53 UTC; п. 0 фокуса потока А 17.11). Геометрия — по листам v3
## (`art/ART-085-korabl-koncept/`: числа из `src/v3-diagrams.py` и `src/v3-control.py`, они воспроизводят
## листы 02/03/04 детерминированно). Код игры и `world.md` эта проверка не меняет.
## Оси — как у корабля игры: нос в −Z, палуба y = 0, правый борт +X. Точка отсчёта (0; 0; 0) — середина
## палубы, как `Helm.Ship.pos` у нынешнего корабля.
##
## Что проверяется (критерии владельца 17.11):
## 1. Проход врат 07 (48 × 22 м) ВСЕМ корпусом с выступами: контур ниже + наклон корпуса (HullMesh.Motion)
##    + след разворота + выход/возврат — `tools/maket085_pass.gd`.
## 2. Виды 00→01 из кресла пилота v3 (глаз EYE, наклон PITCH, порты PORTS) сквозь центральный порт —
##    `tools/maket085_shot.gd` (живой мир игры, ракурсы `ShotSetup.scena`).
## 3. Путь соло между четырьмя постами и к аварийному оборудованию капсулой игрока (Ø 0,7 м, 2,4 м/с,
##    как `Deck.Walker`) — `tools/maket085_walk.gd` и `walk()` здесь (счётно, поэтому покрыто тестом).
##
## Отступления макета от концепта (все — в сторону ЖЁСТЧЕ проверки, зафиксированы в `tools/maket085.md`):
## - тоннели портов доведены до внутренней грани носовой стены (z −12,5…−13,0, 0,5 м; в концепте кромки
##   на −12,75 и −13,0): тоннель длиннее → обзор чуть уже, чем посчитан лист 04;
## - передние скосы носовой зоны (±1,2 при z −12,5 → ±3,3 при z −10,5) в 3D-кладке кабины спрямлены:
##   передняя стена прямая по x ±3,3. На пути соло и обзоре из кресла не сказывается (скосы — мёртвые
##   углы за боковыми консолями); путь соло считается по полигону концепта И по прямоугольнику — сходится;
## - кормовые маршевые движители (два, внутри габарита) в макете — цилиндры Ø 2 м на (x ±1,5; y −1; z 12,5):
##   на листах только знак на разрезе; на проверку врат не влияет (внутри контура).

# ---------- Габарит и контур кожуха (листы 02/03 v3) ----------

const NOSE_Z := -14.0     ## нос (срез), м
const STERN_Z := 14.0     ## корма, м
const KEEL_Y := -5.0      ## низ полозьев, м
const TOP_Y := 4.0        ## верх кожуха, м
const HALF_W := 5.0       ## наибольшая полуширина, м

## Разрез кожуха (z, y) — `outer` листа 02 v3 (src/v3-diagrams.py).
const PROFILE: Array[Vector2] = [
	Vector2(-14.0, -2.0), Vector2(-13.0, -0.2), Vector2(-13.0, 2.5), Vector2(-10.0, 3.4),
	Vector2(-6.0, 4.0), Vector2(6.0, 4.0), Vector2(11.0, 2.6), Vector2(14.0, 0.2),
	Vector2(14.0, -2.6), Vector2(10.0, -4.3), Vector2(-9.0, -5.0), Vector2(-12.0, -3.8)]
## Полуширина кожуха по z — план листа 03 v3 (контур симметричен): (z, полуширина).
const PLAN_W: Array[Vector2] = [
	Vector2(-14.0, 0.0), Vector2(-12.0, 3.5), Vector2(-7.0, 5.0), Vector2(7.0, 5.0),
	Vector2(12.0, 3.5), Vector2(14.0, 1.5)]

## Зазор под полозьями на ровном дне, м: «дно y−8 — на 3 м ниже полозьев» (лист 04 v3). Точка хода
## (палуба) на ровном дне: дно + SKID_GAP − KEEL_Y = дно + 8 м (у нынешнего корабля: дно + 3 м).
const SKID_GAP := 3.0

# ---------- Порты и посадка пилота (лист 04 v3 / src/v3-control.py) ----------

const EYE := Vector3(0.0, 1.33, -11.8)          ## глаз пилота в кресле v3
const SEAT_Z := -11.4                            ## кресло пилота, z
const PITCH := -8.0 * PI / 180.0                 ## наклон взгляда (как Deck.SEAT_PITCH)
const FOV := 72.0                                ## угол обзора по вертикали (как Deck.FOV)
const PORT_Y := 1.33                             ## высота центров портов
const PORT_Z0 := -12.5                           ## внутренняя грань стены (у концепта кромка −12,75 — см. шапку)
const PORT_Z1 := -13.0                           ## внешняя кромка (носовая грань)
const RIM := 0.085                               ## запас рамы снаружи просвета
## Порты: (x центра, радиус просвета): центральный Ø 1,1; боковые Ø 0,8 при x ±1,15.
const PORTS: Array[Vector2] = [Vector2(-1.15, 0.4), Vector2(0.0, 0.55), Vector2(1.15, 0.4)]

# ---------- Носовая зона, посты, отсеки (лист 03 v3) ----------

## Стены носовой зоны (x, z) — увеличенный план листа 03 (передняя грань z −12,5 при x ±1,2, скосы к ±3,3).
const NOSE_POLY: Array[Vector2] = [
	Vector2(-1.2, -12.5), Vector2(-3.3, -10.5), Vector2(-3.3, -3.0),
	Vector2(3.3, -3.0), Vector2(3.3, -10.5), Vector2(1.2, -12.5)]
const NOSE_H := 2.8        ## рабочий потолок, м
## Отсеки за носовой зоной: (z от, z до, полуширина): лаборатория, жилой, технический.
const ROOMS: Array[Vector3] = [Vector3(-3.0, 2.0, 3.3), Vector3(2.0, 7.0, 3.3), Vector3(7.0, 10.5, 3.3)]
const HATCH_Z: Array[float] = [-3.0, 2.0, 7.0]   ## люки между отсеками
const HATCH_HALF := 0.6                          ## полуширина люка (1,2 × 2,1 м)

## Посты (x, z) — лист 03 v3.
const POST_PILOT := Vector2(0.0, -11.4)
const POST_ENGINEER := Vector2(-2.1, -7.7)
const POST_BIOLOG := Vector2(2.1, -7.7)
const POST_SONAR := Vector2(0.0, -4.0)
const TABLE := Vector2(0.0, -5.2)    ## общий стол сонара
const TABLE_R := 0.65                ## Ø 1,3 м
const CHAIR_R := 0.35                ## кресло поста (круг на листе 03)
## Рабочие места у кресел (куда встаёт капсула соло): у инженера и биолога — сзади-сбоку кресла
## (консоль впереди по рабочему взгляду 45°, подойти спереди нельзя — она у стены), у пилота — за креслом.
const STAND_PILOT := Vector2(0.0, -10.6)
const STAND_ENGINEER := Vector2(-2.65, -7.15)
const STAND_BIOLOG := Vector2(2.65, -7.15)
## Стол обходится с любой стороны; место оператора — у кормовой кромки стола.
const STAND_SONAR := Vector2(0.0, -4.0)

## Консоль пилота у передней стены (src/v3-control.py: top 0,85; x ±0,65; z −12,35…−12,65).
const PILOT_CONSOLE := Vector4(0.0, -12.5, 0.65, 0.15)   ## (x, z, полуширина, полуглубина), не повёрнута
const CONSOLE_TOP := 0.85

## Подлокотники и рукоятки пилота — по листу 03 v3 («Пилот: два коротких органа на подлокотниках»,
## «кнопки света и вертикали в зоне кисти»). Рукоятка — на переднем конце подлокотника кресла пилота.
## (18.11: раньше макет ставил рукоятки на консоль — 0,85 м от плеча сидящего, вне зоны досягаемости.)
const ARMREST_X := 0.45      ## ось подлокотника от оси кресла, м (просвет между подлокотниками 0,8 м)
const ARMREST_TOP := 0.76    ## верх подлокотника, м
const GRIP_Y := 0.83         ## ось рукоятки (вертикальный стержень h 0,14 на подлокотнике)
const GRIP_Z := -11.55       ## рукоятка у переднего края подлокотника, z
## Боковые консоли: 0,65 м впереди поста по рабочему взгляду 45° (лист 03), 0,9 × 0,36 м, верх как у пилота.
## (x, z, полуширина, полуглубина, курс взгляда рад: +45° — инженер смотрит вправо от носа).
const SIDE_CONSOLES: Array = [
	Vector4(-2.1 + 0.65 * 0.7071, -7.7 - 0.65 * 0.7071, 0.45, 0.18),   # инженер
	Vector4(2.1 - 0.65 * 0.7071, -7.7 - 0.65 * 0.7071, 0.45, 0.18)]    # биолог
const SIDE_DIR: Array[float] = [PI / 4.0, -PI / 4.0]

## Аварийное оборудование макета (предположение проверки, зафиксировано в maket085.md): питание и разряд —
## пост инженера; щиток реактора и вентиль — технический отсек, точка у кормовой стены.
const TECH_POST := Vector2(0.0, 9.8)

## Капсула игрока — как Deck.Walker.
const WALK_R := 0.35
const WALK_SPEED := 2.4
const WALK_EYE := 1.65


# ---------- Сечения и контур ----------

## Полуширина кожуха в сечении z (линейно по PLAN_W); вне корпуса — 0.
static func half_width(z: float) -> float:
	if z <= PLAN_W[0].x or z >= PLAN_W[-1].x:
		return 0.0
	for i in range(1, PLAN_W.size()):
		if z <= PLAN_W[i].x:
			var a := PLAN_W[i - 1]
			var b := PLAN_W[i]
			return lerpf(a.y, b.y, (z - a.x) / (b.x - a.x))
	return 0.0


## Низ и верх кожуха в сечении z (границы многоугольника PROFILE): Vector2(низ, верх); вне корпуса — NaN.
static func profile_span(z: float) -> Vector2:
	var lo := INF
	var hi := -INF
	for i in PROFILE.size():
		var a := PROFILE[i]
		var b := PROFILE[(i + 1) % PROFILE.size()]
		if (a.x <= z and z < b.x) or (b.x <= z and z < a.x):
			var t := (z - a.x) / (b.x - a.x)
			var y := lerpf(a.y, b.y, t)
			lo = minf(lo, y)
			hi = maxf(hi, y)
		elif a.x == b.x and a.x == z:   # вертикальная грань (нос z −13): берём обе
			lo = minf(lo, minf(a.y, b.y))
			hi = maxf(hi, maxf(a.y, b.y))
	if lo == INF:
		return Vector2(NAN, NAN)
	return Vector2(lo, hi)


## Сечение кожуха в z: (полуширина, низ, верх). Вне корпуса — (0, NaN, NaN).
static func section(z: float) -> Vector3:
	var span := profile_span(z)
	if is_nan(span.x):
		return Vector3(0.0, NAN, NAN)
	return Vector3(half_width(z), span.x, span.y)


## Точки поверхности габарита в осях макета: сечения через STEP_Z, по периметру 8 точек
## (углы и середины сторон). Выступы (каналы В/Б, движители, ниша, полозья) — внутри этого контура
## (лист 06: «схема показывает каналы условно внутри кожуха»; низ контура — полозья).
const STEP_Z := 1.0
static func envelope_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var z := NOSE_Z
	while z <= STERN_Z + 0.01:
		var s := section(z)
		if s.x < 0.05:   # заострённый нос
			out.append(Vector3(0.0, (s.y + s.z) / 2.0, z))
		else:
			var mid := (s.y + s.z) / 2.0
			for sx in [-1.0, 1.0]:
				out.append(Vector3(sx * s.x, s.y, z))
				out.append(Vector3(sx * s.x, s.z, z))
				out.append(Vector3(sx * s.x, mid, z))
			out.append(Vector3(0.0, s.y, z))
			out.append(Vector3(0.0, s.z, z))
		z += STEP_Z
	return out


## Точки днища в осях макета (для предела хода): по килю через STEP_Z, три поперёк (ось и 0,8 полуширины).
static func keel_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var z := NOSE_Z
	while z <= STERN_Z + 0.01:
		var s := section(z)
		out.append(Vector3(0.0, s.y, z))
		if s.x > 0.5:
			out.append(Vector3(-0.8 * s.x, s.y, z))
			out.append(Vector3(0.8 * s.x, s.y, z))
		z += STEP_Z
	return out


## Точка макета (нос в −Z) → мир: наклон pitch (рад, + — нос вверх) вокруг точки хода, потом курс yaw.
static func to_world(p: Vector3, pos: Vector3, yaw: float, pitch: float) -> Vector3:
	var cp := cos(pitch)
	var sp := sin(pitch)
	var y := p.y * cp - p.z * sp   # нос (z < 0) при pitch > 0 поднимается
	var z := p.y * sp + p.z * cp
	var cy := cos(yaw)
	var sy := sin(yaw)
	return pos + Vector3(p.x * cy + z * sy, y, -p.x * sy + z * cy)


# ---------- Проверка врат 07 ----------

## Корпус макета в позе (pos, yaw, pitch) задевает блоки арки 07 (`GateArch.boxes`): хоть одна точка
## поверхности внутри блока. В игре крен не учитывается (`GateArch.hits` — без наклона); здесь наклон —
## измерение запаса (см. maket085_pass.gd), а не физика.
static func arch_hits(pos: Vector3, yaw: float, pitch := 0.0) -> bool:
	if absf(pos.x - EcoGate.CENTER.x) > 120.0 or absf(pos.z - EcoGate.CENTER.y) > 80.0:
		return false
	for p in envelope_points():
		if GateArch.inside(to_world(p, pos, yaw, pitch)):
			return true
	return false


## Наименьшее расстояние от поверхности макета до блоков арки (3D, м; 0 — касание/внутри). Далеко — INF.
static func arch_gap(pos: Vector3, yaw: float, pitch := 0.0) -> float:
	var q := GateArch.local(pos)
	if absf(q.x) > 120.0 or absf(q.z) > 80.0:
		return INF
	var gap := INF
	for b: AABB in GateArch.boxes():
		for p in envelope_points():
			var w := GateArch.local(to_world(p, pos, yaw, pitch))
			var dx := maxf(maxf(b.position.x - w.x, w.x - b.end.x), 0.0)
			var dy := maxf(maxf(b.position.y - w.y, w.y - b.end.y), 0.0)
			var dz := maxf(maxf(b.position.z - w.z, w.z - b.end.z), 0.0)
			gap = minf(gap, Vector3(dx, dy, dz).length())
	return gap


## Нижний предел хода точки pos (курс yaw): днище макета не ниже дна + SKID_GAP (как Helm.Ship.floor_at,
## но килем макета). Без дна — Helm.Ship.DEEP.
static func floor_at(pos: Vector3, yaw: float, ground: Callable) -> float:
	if not ground.is_valid():
		return Helm.Ship.DEEP
	var cy := cos(yaw)
	var sy := sin(yaw)
	var f := Helm.Ship.DEEP
	for q in keel_points():
		var wx := pos.x + q.x * cy + q.z * sy
		var wz := pos.z - q.x * sy + q.z * cy
		f = maxf(f, float(ground.call(wx, wz)) + SKID_GAP - q.y)
	return f


# ---------- Носовая зона: куда встаёт капсула ----------

## Расстояние от точки до отрезка (2D).
static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (p - (a + ab * t)).length()


## Стены палубы макета (отрезки, x/z): контур носовой зоны, борта и переборки отсеков с проёмами люков.
static func walls() -> Array[Vector4]:   # (ax, az, bx, bz)
	var out: Array[Vector4] = []
	var add := func(a: Vector2, b: Vector2) -> void:
		out.append(Vector4(a.x, a.y, b.x, b.y))
	# носовая зона: передняя грань и скосы, борта; кормовая стена — с проёмом люка
	add.call(NOSE_POLY[0], NOSE_POLY[1])
	add.call(NOSE_POLY[1], NOSE_POLY[2])
	add.call(NOSE_POLY[2], Vector2(-HATCH_HALF, -3.0))
	add.call(Vector2(HATCH_HALF, -3.0), NOSE_POLY[3])
	add.call(NOSE_POLY[3], NOSE_POLY[4])
	add.call(NOSE_POLY[4], NOSE_POLY[5])
	add.call(NOSE_POLY[5], NOSE_POLY[0])
	# отсеки: борта и переборки; в переборках с люком — проём |x| < HATCH_HALF
	for i in ROOMS.size():
		var r := ROOMS[i]
		add.call(Vector2(-r.z, r.x), Vector2(-r.z, r.y))
		add.call(Vector2(r.z, r.x), Vector2(r.z, r.y))
		var zb := r.y   # кормовая стена отсека (у технического — корма корабля, без люка)
		if HATCH_Z.has(zb):
			add.call(Vector2(-r.z, zb), Vector2(-HATCH_HALF, zb))
			add.call(Vector2(HATCH_HALF, zb), Vector2(r.z, zb))
		else:
			add.call(Vector2(-r.z, zb), Vector2(r.z, zb))
	return out


## Консоли как препятствия: пары [Vector4 (x, z, полуширина, полуглубина), курс рад].
static func consoles() -> Array:
	return [
		[Vector4(PILOT_CONSOLE.x, PILOT_CONSOLE.y, PILOT_CONSOLE.z, PILOT_CONSOLE.w), 0.0],
		[SIDE_CONSOLES[0], SIDE_DIR[0]],
		[SIDE_CONSOLES[1], SIDE_DIR[1]]]


## Внутри ли (x, z) консоли (центр, полуразмеры, курс взгляда поста), раздутой на r.
static func _in_console(x: float, z: float, c: Vector4, dir: float, r: float) -> bool:
	var dx := x - c.x
	var dz := z - c.y
	var along := dx * sin(dir) + dz * -cos(dir)    # по взгляду (глубина консоли)
	var across := dx * cos(dir) + dz * sin(dir)    # поперёк (ширина)
	return absf(along) <= c.w + r and absf(across) <= c.z + r


## Можно ли стоять капсуле радиуса r в (x, z) палубы макета: внутри контура, не в мебели.
static func can_stand(x: float, z: float, r: float = WALK_R) -> bool:
	var p := Vector2(x, z)
	var inside := Geometry2D.is_point_in_polygon(p, PackedVector2Array(NOSE_POLY))
	if not inside:
		for room in ROOMS:
			if absf(x) < room.z and z > room.x and z < room.y:
				inside = true
				break
	if not inside:   # люки соединяют отсеки: коридорчик проёма
		for h in HATCH_Z:
			if absf(x) < HATCH_HALF and absf(z - h) < 0.3:
				inside = true
				break
	if not inside:
		return false
	for wseg in walls():
		if _seg_dist(p, Vector2(wseg.x, wseg.y), Vector2(wseg.z, wseg.w)) < r:
			return false
	if p.distance_to(TABLE) < TABLE_R + r:
		return false
	for chair in [POST_PILOT, POST_ENGINEER, POST_BIOLOG]:
		if p.distance_to(chair) < CHAIR_R + r:
			return false
	var cs := consoles()
	for c in cs:
		if _in_console(x, z, c[0], c[1], r):
			return false
	return true


# ---------- Путь соло (счётно; снимки — maket085_walk.gd / shot) ----------

## Маршруты соло по листу 03 v3. Разметка прогонами макета (maket085_walk.gd): кресло поста стоит
## вплотную к своей консоли (центры в 0,65 м — капсуле Ø 0,7 между ними не пройти, как и задумано —
## там сидит оператор), поэтому ход носовой зоной — по оси между боковыми консолями (канал чист:
## их повёрнутые зоны не достают до x = 0), к креслам инженера/биолога — только СЗАДИ кресла,
## стол сонара обходится по дуге. Точки: C — канал, J — перед столом, T — сбоку стола, B — за креслом.
static func routes() -> Dictionary:
	var c := Vector2(0.0, -8.2)            # канал между боковыми консолями
	var j := Vector2(0.0, -6.7)            # перед столом
	var tl := Vector2(-1.7, -5.9)          # сбоку стола, лево
	var tr := Vector2(1.7, -5.9)           # сбоку стола, право
	var sl := Vector2(-1.6, -4.3)          # за столом, лево
	var sr := Vector2(1.6, -4.3)           # за столом, право
	var el := Vector2(-1.6, -7.1)          # за консолью инженера
	var br := Vector2(1.6, -7.1)           # за консолью биолога
	var eb := Vector2(-2.65, -6.5)         # за креслом инженера
	var bb := Vector2(2.65, -6.5)          # за креслом биолога
	var hatch_in := Vector2(0.0, -2.5)     # люк в лабораторию (за переборкой z −3)
	var lab := Vector2(0.0, 1.5)           # лаборатория, перед люком жилого
	var live := Vector2(0.0, 2.5)          # жилой отсек (за люком z 2)
	var live2 := Vector2(0.0, 6.5)         # жилой, перед люком техники
	var tech_in := Vector2(0.0, 7.5)       # технический отсек (за люком z 7)
	return {
		"сонар → пилот": [STAND_SONAR, sl, tl, j, c, STAND_PILOT],
		"пилот → сонар": [STAND_PILOT, c, j, tr, sr, STAND_SONAR],
		"пилот → инженер": [STAND_PILOT, c, el, eb, STAND_ENGINEER],
		"инженер → пилот": [STAND_ENGINEER, eb, el, c, STAND_PILOT],
		"пилот → биолог": [STAND_PILOT, c, br, bb, STAND_BIOLOG],
		"биолог → пилот": [STAND_BIOLOG, bb, br, c, STAND_PILOT],
		"инженер → биолог": [STAND_ENGINEER, eb, el, j, br, bb, STAND_BIOLOG],
		"биолог → сонар": [STAND_BIOLOG, bb, br, tr, sr, STAND_SONAR],
		"сонар → биолог": [STAND_SONAR, sr, tr, br, bb, STAND_BIOLOG],
		"пилот → техника (щиток)": [STAND_PILOT, c, j, tl, sl, Vector2(0.0, -3.4), hatch_in,
			lab, live, live2, tech_in, TECH_POST],
		"инженер → техника (щиток)": [STAND_ENGINEER, eb, el, j, tl, sl, Vector2(0.0, -3.4),
			hatch_in, lab, live, live2, tech_in, TECH_POST],
		"сонар → техника (щиток)": [STAND_SONAR, Vector2(0.0, -3.4), hatch_in, lab, live,
			live2, tech_in, TECH_POST],
	}


## Проход маршрута капсулой игрока (счётно; скольжение вдоль стен — как Deck.Walker.walk).
## {ok, time, len, trace (точки каждые 0,1 с), stuck — где капсула встала (иначе Vector2(INF, INF))}.
static func walk(route: Array, r: float = WALK_R, speed: float = WALK_SPEED, dt: float = 0.05) -> Dictionary:
	var pos: Vector2 = route[0]
	var t := 0.0
	var len := 0.0
	var trace: Array[Vector2] = [pos]
	var next_trace := 0.1
	for i in range(1, route.size()):
		var wp: Vector2 = route[i]
		var guard := 0
		while pos.distance_to(wp) > 0.05:
			guard += 1
			if guard > 4000:   # 200 с на точку — встали
				return {"ok": false, "time": t, "len": len, "trace": trace, "stuck": pos}
			var step := speed * dt
			if pos.distance_to(wp) <= step and can_stand(wp.x, wp.y, r):
				len += pos.distance_to(wp)   # досадка на точку: шаг длиннее остатка — не осциллируем
				pos = wp
				t += dt
				break
			var d := (wp - pos).normalized() * step
			if can_stand(pos.x + d.x, pos.y + d.y, r):
				pos += d
				len += d.length()
			elif can_stand(pos.x + d.x, pos.y, r):
				pos.x += d.x
				len += absf(d.x)
			elif can_stand(pos.x, pos.y + d.y, r):
				pos.y += d.y
				len += absf(d.y)
			else:   # упёрлись углом: встали
				return {"ok": false, "time": t, "len": len, "trace": trace, "stuck": pos}
			t += dt
			if t >= next_trace:
				trace.append(pos)
				next_trace += 0.1
	trace.append(pos)
	return {"ok": true, "time": t, "len": len, "trace": trace, "stuck": Vector2(INF, INF)}


## Все маршруты routes(): имя → результат walk(). Проверка точек маршрута — каждая стоит.
static func walk_all(r: float = WALK_R) -> Dictionary:
	var out := {}
	for name: String in routes():
		var route: Array = routes()[name]
		var bad := ""
		for wp: Vector2 in route:
			if not can_stand(wp.x, wp.y, r):
				bad = str(wp)
				break
		var res := walk(route, r)
		res["waypoints_ok"] = bad == ""
		if bad != "":
			res["bad_point"] = bad
		out[name] = res
	return out



# ---------- Полный цикл смены поста в соло (ГД, #1788 18.11) ----------

## Зоны досягаемости от плеча (UX Р-2, #1754 шаг 2): комфорт 0,55 м, предел 0,68 м.
const REACH_OK := 0.55
const REACH_MAX := 0.68
## Посадка и вставание — допущение проверки (в игре — анимация кресла): по 0,8 с на действие.
const SIT_T := 0.8

## Плечо сидящего оператора поста: 0,18 м ниже и 0,1 м позади глаза; глаз сидя 1,33 м (лист 04 v3),
## у боковых постов — на 0,1 м впереди оси кресла по рабочему взгляду (наклон к консоли).
static func shoulder_at(post: Vector2, dir: float) -> Vector3:
	var fwd := Vector2(sin(dir), -cos(dir))
	return Vector3(post.x + fwd.x * 0.1, 1.33 - 0.18, post.y + fwd.y * 0.1)


## Плечи пилота в кресле v3 (глаз EYE — на 0,4 м впереди оси кресла, лист 04 v3).
static func pilot_shoulder(sx: float) -> Vector3:
	return Vector3(sx * 0.2, EYE.y - 0.18, EYE.z + 0.1)


## Худшая досягаемость рукояток пилота из кресла (обе руки), м.
static func pilot_grip_reach() -> float:
	var worst := 0.0
	for sx in [-1.0, 1.0]:
		worst = maxf(worst, pilot_shoulder(sx).distance_to(Vector3(sx * ARMREST_X, GRIP_Y, GRIP_Z)))
	return worst


## Досягаемость ближнего края рабочей поверхности консоли из позы сидящего оператора поста (3D), м.
static func console_reach(post: Vector2, dir: float, c: Vector4) -> float:
	var fwd := Vector2(sin(dir), -cos(dir))
	var edge := Vector2(c.x, c.y) - fwd * c.w   # ближний к посту край консоли
	var sh := shoulder_at(post, dir)
	return Vector3(edge.x - sh.x, CONSOLE_TOP - sh.y, edge.y - sh.z).length()


## Посадка с рабочей точки на кресло поста: расстояние и чистота прямого перевода
## (капсула сжимается до r 0,2 — сесть можно, когда линия «стояние → кресло» не режет консоль).
static func seat_check(post: Vector2, stand: Vector2) -> Dictionary:
	var d := post.distance_to(stand)
	var clear := true
	var n := int(d / 0.05) + 1
	for i in n + 1:
		var p := stand.lerp(post, float(i) / n)
		for con in consoles():
			if _in_console(p.x, p.y, con[0], con[1], 0.2):
				clear = false
	return {"dist": d, "clear": clear}


## Полный цикл «пилот сидит → встал → дошёл до поста → занял пост → встал → вернулся → сел».
## Посты: имя → [кресло, рабочая точка, взгляд рад, сидя?]. Сонар — стоящий пост у стола.
static func cycle_posts() -> Dictionary:
	return {
		"инженер": [POST_ENGINEER, STAND_ENGINEER, SIDE_DIR[0], true],
		"биолог": [POST_BIOLOG, STAND_BIOLOG, SIDE_DIR[1], true],
		"сонар": [POST_SONAR, STAND_SONAR, 0.0, false],
	}


## Досягаемость органа поста из рабочей позы: сидя — консоль (3D от плеча), стоя у стола —
## горизонталь до ближней кромки стола (стоящий наклоняется; вертикаль не считаем).
static func post_reach(pname: String) -> float:
	var p: Array = cycle_posts()[pname]
	if p[3]:
		var idx := 0 if pname == "инженер" else 1
		return console_reach(p[0], p[2], SIDE_CONSOLES[idx])
	var stand: Vector2 = p[1]
	return stand.distance_to(TABLE) - TABLE_R


## Все циклы смены поста: имя → {ok, t_out, t_back, t_cycle, seat_dist, seat_clear, reach}.
## Время цикла: путь туда + путь обратно + посадки/вставания (по SIT_T; у стоячего поста — без кресла).
static func cycle_all() -> Dictionary:
	var rts := routes()
	var out := {}
	for pname: String in cycle_posts():
		var p: Array = cycle_posts()[pname]
		var go := walk(rts["пилот → %s" % pname])
		var back := walk(rts["%s → пилот" % pname])
		var seat := seat_check(p[0], p[1])
		var reach := post_reach(pname)
		var sits := 4.0 if p[3] else 2.0   # встал у пилота + сел на посту + встал + сел у пилота
		out[pname] = {"ok": go["ok"] and back["ok"] and seat["clear"] and reach <= REACH_MAX,
				"t_out": go["time"], "t_back": back["time"],
				"t_cycle": go["time"] + back["time"] + sits * SIT_T,
				"seat_dist": seat["dist"], "seat_clear": seat["clear"], "reach": reach}
	return out


## Полный обход всех постов с возвращением к управлению: пилот → инженер → биолог → сонар → пилот.
static func tour_all() -> Dictionary:
	var rts := routes()
	var t := 0.0
	var ok_all := true
	for nm in ["пилот → инженер", "инженер → биолог", "биолог → сонар", "сонар → пилот"]:
		var r := walk(rts[nm])
		t += r["time"]
		ok_all = ok_all and r["ok"]
	# посадки: встал у пилота, сел/встал у инженера и биолога, сел у пилота (сонар — стоя)
	return {"ok": ok_all, "time": t + 6.0 * SIT_T}


# ---------- 3D-кладка макета (для maket085_shot.gd; игру не трогает) ----------

## Материалы макета: кабина тёмная, рамы светлее, экраны — свечение #67DDEB (биолюм-акценты мира).
static func _mat(col: Color, rough := 0.85, metal := 0.05) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	return m


static func _mat_cabin() -> StandardMaterial3D:
	return _mat(Color(0.16, 0.19, 0.23))


static func _mat_rim() -> StandardMaterial3D:
	return _mat(Color(0.35, 0.38, 0.4), 0.5, 0.6)


static func _mat_screen() -> StandardMaterial3D:
	var m := _mat(Color(0.02, 0.05, 0.06), 0.4, 0.0)
	m.emission_enabled = true
	m.emission = Color("67ddeb")
	m.emission_energy_multiplier = 0.9
	return m


static func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material, yaw := 0.0, bname := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = at
	mi.rotation.y = yaw
	mi.material_override = mat
	if bname != "":
		mi.name = bname
	parent.add_child(mi)
	return mi


static func _cyl(parent: Node3D, r0: float, r1: float, h: float, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r0
	cm.bottom_radius = r1
	cm.height = h
	mi.mesh = cm
	mi.position = at
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## Кабина макета (оси корабля): пол/потолок/стены носовой зоны и отсеков, передняя стена с тремя
## портами (просветы Ø 1,1/0,8/0,8, тоннели 0,5 м, рамы +0,085 м), консоли с экранами и рукоятками,
## кресла постов, стол сонара, свет. Скосы носовой зоны спрямлены (шапка файла): передняя стена
## по x ±3,3 — порты все в одной плоскости z −12,5…−13,0, как на листе 04.
static func build_cabin() -> Node3D:
	var cabin := Node3D.new()
	cabin.name = "МакетКабина"
	var m := _mat_cabin()
	var wall := 0.1
	# палуба и потолок: носовая зона и отсеки (z −12,5…10,5), рабочий потолок 2,8 м
	_box(cabin, Vector3(HALF_W * 2.0 + 1.6, 0.08, 23.0), Vector3(0.0, -0.04, -1.0), m, 0.0, "Палуба")
	_box(cabin, Vector3(HALF_W * 2.0 + 1.6, wall, 23.0), Vector3(0.0, NOSE_H + wall / 2.0, -1.0), m, 0.0, "Потолок")
	# борта
	for sx in [-1.0, 1.0]:
		_box(cabin, Vector3(wall, NOSE_H, 23.0), Vector3(sx * (3.3 + wall / 2.0), NOSE_H / 2.0, -1.0), m)
	# корма техотсека
	_box(cabin, Vector3(6.6 + wall, NOSE_H, wall), Vector3(0.0, NOSE_H / 2.0, 10.5 + wall / 2.0), m)
	# переборки с люками (z −3, 2, 7): простенки и перемычка над проёмом 1,2 × 2,1
	for hz in HATCH_Z:
		for sx in [-1.0, 1.0]:
			_box(cabin, Vector3(3.3 - HATCH_HALF + wall, NOSE_H, wall),
					Vector3(sx * (HATCH_HALF + (3.3 - HATCH_HALF) / 2.0), NOSE_H / 2.0, hz), m)
		_box(cabin, Vector3(HATCH_HALF * 2.0, NOSE_H - 2.1, wall), Vector3(0.0, 2.1 + (NOSE_H - 2.1) / 2.0, hz), m)
	# передняя стена с портами: сетка квадов 0,025 м с круглыми просветами, нормалью в кабину (+z)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cell := 0.025
	var nx := int(ceil(6.6 / cell))
	var ny := int(ceil(NOSE_H / cell))
	for iy in ny:
		for ix in nx:
			var cx := -3.3 + (ix + 0.5) * cell
			var cy := (iy + 0.5) * cell
			var hole := false
			for port in PORTS:
				if Vector2(cx - port.x, cy - PORT_Y).length() < port.y:
					hole = true
					break
			if hole:
				continue
			var x0 := -3.3 + ix * cell
			var y0 := iy * cell
			for tri in [[Vector3(x0, y0, PORT_Z0), Vector3(x0 + cell, y0, PORT_Z0), Vector3(x0 + cell, y0 + cell, PORT_Z0)],
					[Vector3(x0, y0, PORT_Z0), Vector3(x0 + cell, y0 + cell, PORT_Z0), Vector3(x0, y0 + cell, PORT_Z0)]]:
				st.set_normal(Vector3(0, 0, 1))
				for v: Vector3 in tri:
					st.add_vertex(v)
	var wall_mi := MeshInstance3D.new()
	wall_mi.name = "Стена с портами"
	wall_mi.mesh = st.commit()
	wall_mi.material_override = m
	cabin.add_child(wall_mi)
	# тоннели портов (открытые цилиндры, изнанка видна — без отсечки) и рамы с двух сторон
	var tunnel_mat := _mat_rim()
	tunnel_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for port in PORTS:
		var tun := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = port.y
		cm.bottom_radius = port.y
		cm.height = PORT_Z0 - PORT_Z1
		cm.radial_segments = 48
		cm.cap_top = false
		cm.cap_bottom = false
		tun.mesh = cm
		tun.rotation.x = PI / 2.0
		tun.position = Vector3(port.x, PORT_Y, (PORT_Z0 + PORT_Z1) / 2.0)
		tun.material_override = tunnel_mat
		cabin.add_child(tun)
		for rz in [PORT_Z0 - 0.01, PORT_Z1 + 0.01]:
			var rim := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = port.y - 0.02
			tm.outer_radius = port.y + RIM
			tm.ring_segments = 48
			tm.rings = 12
			rim.mesh = tm
			rim.rotation.x = PI / 2.0
			rim.position = Vector3(port.x, PORT_Y, rz)
			rim.material_override = _mat_rim()
			cabin.add_child(rim)
	# консоль пилота: тумба 1,3 × 0,3, верх 0,85; три экрана
	var pc := PILOT_CONSOLE
	_box(cabin, Vector3(pc.z * 2.0, CONSOLE_TOP, pc.w * 2.0), Vector3(pc.x, CONSOLE_TOP / 2.0, pc.y), m, 0.0, "Консоль пилота")
	var scr := _mat_screen()
	for i in 3:
		var sx := (i - 1) * 0.42
		var sc := _box(cabin, Vector3(0.34, 0.2, 0.02), Vector3(sx, CONSOLE_TOP + 0.1, pc.y + 0.17), scr, 0.0, "Экран")
		sc.rotation.x = -0.35
	# подлокотники и рукоятки пилота — на кресле (лист 03 v3: «два коротких органа на подлокотниках»)
	for sx in [-1.0, 1.0]:
		_box(cabin, Vector3(0.1, ARMREST_TOP - 0.5, 0.5),
				Vector3(sx * ARMREST_X, 0.5 + (ARMREST_TOP - 0.5) / 2.0, POST_PILOT.y + 0.05), m, 0.0, "Подлокотник")
		var grip := _cyl(cabin, 0.025, 0.025, 0.14, Vector3(sx * ARMREST_X, GRIP_Y, GRIP_Z), _mat_rim())
		grip.name = "Рукоятка"
	# боковые консоли под 45° к постам, экраном к креслу
	for i in 2:
		var c: Vector4 = SIDE_CONSOLES[i]
		var con := _box(cabin, Vector3(c.z * 2.0, CONSOLE_TOP, c.w * 2.0),
				Vector3(c.x, CONSOLE_TOP / 2.0, c.y), m, SIDE_DIR[i], "Боковая консоль")
		var sc := _box(con, Vector3(0.5, 0.24, 0.02), Vector3(0.0, 0.62, -c.w + 0.03), scr)
		sc.rotation.x = -0.3
	# кресла постов: стойка, сиденье Ø 0,7, спинка по взгляду поста
	for i in 3:
		var post: Vector2 = [POST_PILOT, POST_ENGINEER, POST_BIOLOG][i]
		var dir: float = [0.0, SIDE_DIR[0], SIDE_DIR[1]][i]
		var chair_mat := _mat(Color(0.22, 0.2, 0.18))
		var leg := _cyl(cabin, 0.05, 0.07, 0.45, Vector3(post.x, 0.225, post.y), chair_mat)
		leg.name = "Стойка кресла"
		var seat := _cyl(cabin, CHAIR_R, CHAIR_R, 0.1, Vector3(post.x, 0.5, post.y), chair_mat)
		seat.name = "Сиденье"
		_box(cabin, Vector3(0.6, 0.6, 0.08), Vector3(
				post.x - sin(dir) * 0.36, 0.85, post.y + cos(dir) * 0.36), chair_mat, dir, "Спинка")
	# стол сонара Ø 1,3, верх — тусклый голубой
	var tbl := _cyl(cabin, TABLE_R, TABLE_R, 0.95, Vector3(TABLE.x, 0.475, TABLE.y), m)
	tbl.name = "Стол сонара"
	_box(cabin, Vector3(1.1, 0.02, 1.1), Vector3(TABLE.x, 0.96, TABLE.y), _mat_screen(), 0.0, "Стол-экран")
	# свет кабины: тёплые плафоны на потолке (нос, стол, отсеки)
	for lp in [Vector3(0.0, 2.55, -9.0), Vector3(0.0, 2.55, -4.5), Vector3(0.0, 2.55, 4.0)]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.9, 0.75)
		lamp.light_energy = 0.9
		lamp.omni_range = 7.0
		lamp.position = lp
		cabin.add_child(lamp)
	return cabin


## Кожух макета снаружи: лофт сечений (план × разрез, эллиптические кольца через 0,5 м), кормовые
## движители — цилиндры Ø 2 м. Для внешних кадров макета у врат и на фоне мира.
static func build_hull() -> Node3D:
	var hull := Node3D.new()
	hull.name = "МакетКорпус"
	var m := _mat(Color(0.24, 0.27, 0.3), 0.6, 0.35)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 16
	var prev: Array[Vector3] = []
	var z := NOSE_Z
	while z <= STERN_Z + 0.01:
		var s := section(z)
		var ring: Array[Vector3] = []
		var mid := (s.y + s.z) / 2.0
		var hr := maxf((s.z - s.y) / 2.0, 0.05)
		var hw: float = maxf(s.x, 0.05)
		for i in segs:
			var a := TAU * i / segs
			ring.append(Vector3(hw * sin(a), mid + hr * cos(a), z))
		if not prev.is_empty():
			for i in segs:
				var j := (i + 1) % segs
				st.add_vertex(prev[i])
				st.add_vertex(ring[i])
				st.add_vertex(ring[j])
				st.add_vertex(prev[i])
				st.add_vertex(ring[j])
				st.add_vertex(prev[j])
		prev = ring
		z += 0.5
	var hull_mi := MeshInstance3D.new()
	hull_mi.name = "Кожух"
	hull_mi.mesh = st.commit()
	hull_mi.material_override = m
	hull.add_child(hull_mi)
	for sx in [-1.5, 1.5]:
		var eng := _cyl(hull, 1.0, 1.0, 3.0, Vector3(sx, -1.0, 12.5), m)
		eng.rotation.x = PI / 2.0
		eng.name = "Движитель"
	return hull
