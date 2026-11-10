class_name EcoDrop
extends EcoSystem
## Край отмели — место 6 карты отмели по концепту ART-032 (docs/concept-art/kray-otmeli.md): рельеф поднятого дна
## Чаши, не постройка. Бровка идёт с севера на юг по фактическому склону `Seabed` (x ≈ 150–160, дно −45…−60 м)
## вдоль z 40…140, глубина — к востоку (+X). Рельеф не меняем: вдоль бровки стоят четыре скальных клина по ≈ 20 м —
## верх у бровки вровень с дном (рваная кромка ± 5 м по шуму), полка нависает над склоном, дальше стенка круче
## склона уходит вниз и заглублена в него. Между вторым и третьим клином у z = 90 — свежий шрам оползня шириной
## 20 м: врезан в площадку на 6,5 м, светлый скол, ложе по склону и диагональная осыпь — откуда идёт облако
## `silt.gd`. На площадке — три тёмные трещины. Светится только редкое обрастание. Темнота за краем — туман
## OceanView, своей «пустоты» нет. Форма своя, от зерна мира не зависит. Столкновение — `solid`, подключить — поток А.

const ID := "drop"
## Точка на карте отмели (karta-otmeli-mesta.json, место 6) — та же, что Run.PLACES["drop"]; над склоном.
const CENTER := Vector2(215.0, 90.0)
## Бровка: средняя линия x, участок вдоль z, рваность кромки ± JAG м (шум по z, шаг JAG_SCALE).
const BROW_X := 155.0
const Z_FROM := 40.0
const Z_TO := 140.0
const JAG := 5.0
const JAG_SCALE := 0.07
## Клинья: участки z (между вторым и третьим — шрам), зазор в стыке, м.
const WEDGES: Array[Vector2] = [Vector2(40.0, 59.0), Vector2(59.0, 80.0), Vector2(100.0, 121.0),
	Vector2(121.0, 140.0)]
const SEAM := 0.35
## Профиль клина (поперёк бровки): заход за бровку в площадку (под дном на BACK_SINK), подъём кромки над дном,
## вынос полки над склоном (у середины клина; к торцам — на TAPER короче), опускание полки к губе,
## крутизна стенки (м вниз на м вбок), глубина низа стенки под бровкой и заглубление его в склон.
const BACK := 7.0
const BACK_SINK := 0.6
const RISE := 1.6
const LIP := 16.0
const TAPER := 0.45
const DIP := 2.2
const STEEP := 2.75
const DEPTH := 40.0
const FOOT_SINK := 3.0
## Шрам оползня: середина по z, ширина, насколько врезан в площадку; ложе лежит над дном на FLOOR_UP и тянется
## по склону на SCAR_RUN м за бровку.
const SCAR_Z := 90.0
const SCAR_W := 20.0
const SCAR_CUT := 6.5
const FLOOR_UP := 0.45
const SCAR_RUN := 32.0
## Осыпь: камней, размер, снос по диагонали (м по z на всю длину).
const SCREE := 26
const ROCK_MIN := 0.5
const ROCK_MAX := 1.9
const SCREE_DRIFT := 12.0
## Трещины на площадке: начало (x, z), направление к бровке (x, z), длина, м.
const CRACKS: Array[Vector4] = [Vector4(139.0, 63.0, 1.0, 0.35), Vector4(143.0, 112.0, 1.0, -0.25),
	Vector4(137.0, 131.0, 1.0, 0.15)]
const CRACK_LEN: Array[float] = [14.0, 11.0, 16.0]
## Сколько м над дном лежит трещина (чтобы не мерцала с ним).
const CRACK_UP := 0.12

## Высота дна (мир передаёт при сбросе; без дна — ровно −50 м).
var ground: Callable


func reset(world: EcoWorld) -> void:
	ground = world.ground


## Дно под (x, z): мир передаёт Seabed.height; без него — −50 м.
func floor_y(x: float, z: float) -> float:
	return float(ground.call(x, z)) if ground.is_valid() else -50.0


## Кромка бровки при z: x (рваная по шуму, ± JAG).
static func brow_x(z: float) -> float:
	return BROW_X + clampf(JAG * 1.6 * (HashNoise.fbm(z * JAG_SCALE, 7.3, 2) * 2.0 - 1.0), -JAG, JAG)


## Вынос полки клина w при z (к торцам короче — клин в плане).
static func lip_len(w: int, z: float) -> float:
	var r := WEDGES[w]
	var t := clampf((z - r.x) / (r.y - r.x), 0.0, 1.0)
	var k := 0.85 + 0.3 * HashNoise.value(float(w) * 3.7, 1.9)
	return LIP * k * (1.0 - TAPER + TAPER * sin(PI * t))


## Участок z клина w без стыков.
static func wedge_z(w: int) -> Vector2:
	var r := WEDGES[w]
	var a := r.x + (SEAM if w > 0 and WEDGES[w - 1].y == r.x else 0.0)
	var b := r.y - (SEAM if w < WEDGES.size() - 1 and WEDGES[w + 1].x == r.y else 0.0)
	return Vector2(a, b)


## Профиль клина w при z — точки (x, y) в плоскости x-y: заход в площадку, кромка, губа полки, низ стенки.
func profile(w: int, z: float) -> PackedVector2Array:
	var xe := brow_x(z)
	var yb := floor_y(xe, z)
	var back := Vector2(xe - BACK, floor_y(xe - BACK, z) - BACK_SINK)
	var rim := Vector2(xe, yb + RISE)
	var lx := xe + lip_len(w, z)
	var lip := Vector2(lx, yb + RISE - DIP)
	var fy := yb - DEPTH
	var fx := lx + (lip.y - fy) / STEEP
	fy = minf(fy, floor_y(fx, z) - FOOT_SINK)
	return PackedVector2Array([back, rim, lip, Vector2(fx, fy)])


## Головная стенка шрама при z (в полосе шрама): x скола, врезанного в площадку.
static func scar_head_x(z: float) -> float:
	var u := clampf((z - SCAR_Z) / (SCAR_W * 0.5), -1.0, 1.0)
	return brow_x(z) - SCAR_CUT * sqrt(1.0 - u * u)


## Точка схода оползня: верх скола на бровке у середины шрама (для облака `silt.gd` — поток А).
func scar_point() -> Vector3:
	var x := scar_head_x(SCAR_Z)
	return Vector3(x, floor_y(x, SCAR_Z) + RISE, SCAR_Z)


## Камни осыпи (мир): центр и размер, по диагонали вниз по ложу шрама и дальше по склону.
func scree() -> Array[Vector4]:
	var out: Array[Vector4] = []
	var rnd := EcoRandom.new(3202)
	for i in SCREE:
		var t := float(i) / float(SCREE - 1)
		var x := brow_x(SCAR_Z) + 2.0 + t * (SCAR_RUN + 4.0) + rnd.range_f(-1.5, 1.5)
		var z := SCAR_Z - 3.0 + t * SCREE_DRIFT + rnd.range_f(-1.0, 1.0) * (2.5 + 4.0 * t)
		var r := lerpf(ROCK_MIN, ROCK_MAX, rnd.range_f(0.0, 1.0) * (0.45 + 0.55 * t))
		out.append(Vector4(x, floor_y(x, z) + r * 0.25, z, r))
	return out


## Трещина k: точки ломаной по площадке (мир, над дном на CRACK_UP).
func crack_points(k: int) -> PackedVector3Array:
	var c := CRACKS[k]
	var d := Vector2(c.z, c.w).normalized()
	var side := Vector2(-d.y, d.x)
	var out := PackedVector3Array()
	var n := 9
	for i in n:
		var t := float(i) / float(n - 1)
		var p := Vector2(c.x, c.y) + d * CRACK_LEN[k] * t
		p += side * (HashNoise.value(float(i) * 1.7 + k * 9.1, 4.4) - 0.5) * 2.4
		p.x = minf(p.x, brow_x(p.y) - 1.0)
		out.append(Vector3(p.x, floor_y(p.x, p.y) + CRACK_UP, p.y))
	return out


## Верх скального клина в (x, z) мира (поверхность полки по профилю), или −INF, если клина тут нет.
## Поток А поднимает сюда «пол» корпуса — корабль не проходит сквозь скалу и чиркает по ней (Vitals.scrape).
func top(x: float, z: float) -> float:
	for w in WEDGES.size():
		var r := wedge_z(w)
		if z < r.x or z > r.y:
			continue
		var pr := profile(w, z)
		if x < pr[0].x or x > pr[3].x:
			return -INF
		for i in 3:
			var a := pr[i]
			var b := pr[i + 1]
			if x >= a.x and x <= b.x:
				return lerpf(a.y, b.y, (x - a.x) / maxf(b.x - a.x, 1e-6))
	return -INF


## Точка (в мире) внутри скальных клиньев — для существ и столкновения корабля (подключает поток А).
func solid(p: Vector3) -> bool:
	var y := top(p.x, p.z)
	return y != -INF and p.y < y


## Точка облака оползня для `silt.gd`: ниже скола по склону (+X на SLIDE_OFF), на SLIDE_UP м над дном, не глубже −55.
## Так ил идёт из самого свежего шрама, а не с открытого склона в 60 м восточнее (issue #258).
const SLIDE_OFF := 8.0
const SLIDE_UP := 10.0
func slide_cloud_point() -> Vector3:
	var sp := scar_point()
	var x := sp.x + SLIDE_OFF
	return Vector3(x, maxf(floor_y(x, sp.z) + SLIDE_UP, -55.0), sp.z)
