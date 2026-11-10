class_name Zap
extends RefCounted
## Разряд по корпусу (js/game.js Game.zap): рычаг на левом борту мостика. Стоит 15 единиц заряда, радиус —
## 20 м × доля «Разряд» реактора. Отпугивает хищников и сбрасывает присосавшихся (это решает живой мир по
## ShipState.zap / zap_radius). Свет на корабле мигает 0,8 с.

const BASE_RADIUS := 20.0
const COOLDOWN := 2.0
const FLICKER := 0.8
## Рычаг: левый борт, кормовее пульта энергии (z −2), между рёбрами −1,25 и 0,25.
const LEVER_POS := Vector3(-4.75, 1.05, -0.5)
## Щиток MOD-014 (docs/concept-art/razryad.md): pivot — центр задней плоскости на стене.
const PANEL_POS := Vector3(-4.85, 1.17, -0.5)
## Ход рычага вокруг оси Z: +25° взведён, −25° разряд; держится внизу, пока мигает свет, потом плавно встаёт к концу отката.
const LEVER_UP := 25.0
const LEVER_DOWN := -25.0
const POST_AT := Vector2(-3.9, -0.5)

## Дуги на обшивке по ART-068 (docs/concept-art/razryad-korpus.md): фронт бежит от носа к корме,
## z = ARC_FROM + ARC_SPEED·t, ширина ARC_WIDTH, к FLICKER гаснет до 0. Атлас 4×2 кадра, ARC_FPS кадров в секунду.
## Тот же расчёт — в shaders/hull_plating.gdshader (zap_t), тест test_zap.
const ARC_TEX := "res://textures/razryad/dugi.png"
const ARC_FROM := -7.2
const ARC_SPEED := 50.0
const ARC_WIDTH := 7.0
const ARC_FRAMES := 8
const ARC_FPS := 10.0
## Плитка атласа на обшивке: 8 м вдоль корабля × 2 м поперёк; рисунок бежит к корме 12 м/с.
const ARC_TILE := Vector2(8.0, 2.0)
const ARC_FLOW := 12.0
## Цвета ART-068: ядро и ореол; ядро светит до ARC_CORE × огибающая, швы — ARC_SEAM × огибающая.
const ARC_CORE_COLOR := Color("5ef2d6")
const ARC_HALO_COLOR := Color("67ddeb")
const ARC_CORE := 3.0
const ARC_SEAM := 0.2

## Карточки у окна и у дна по ART-068 (razryad-korpus.md): один меш, +1 вызов, additive, видны только в разряде;
## на «Экономно» выключены. Рисует HullView.set_zap_cards, шейдер shaders/zap_cards.gdshader. Оси корабля.
enum Card { WINDOW, BRANCH, SPARK }
## Дуга у нижней рамы носового окна (снаружи стекла): 2,4 м, бежит к +X со скоростью ARC_FLOW, уходит к WINDOW_GONE.
const WINDOW_FROM := Vector3(-3.7, 1.05, -6.15)
const WINDOW_TO := Vector3(-1.3, 1.05, -6.15)
const WINDOW_HALF := 0.65
const WINDOW_GONE := 0.22
## Ветви от киля к точке касания — только если от киля до дна (по сетке дна, Seabed.mesh_height) не больше GROUND_GAP.
const KEEL := Vector3(0.0, -1.6, 10.0)
const BRANCH_DZ := [-0.65, 0.0, 0.65]
const BRANCH_HALF := 0.7
const SPARK_HALF := 0.55
const GROUND_GAP := 3.0
const GROUND_LIFT := 0.08

var last := -99.0
var radius := BASE_RADIUS
var flicker := 0.0


static func radius_for(k: float) -> float:
	return BASE_RADIUS * k


## Энергия света вспышки при оставшемся мигании flicker (FLICKER → 0): 4 на пике, к концу гаснет.
## Сам свет всегда в сцене на наибольший радиус (Main.zap_light, issue #159); вне вспышки — Searchlight.DARK.
static func flash_energy(fl: float) -> float:
	return 4.0 * clampf(fl / FLICKER, 0.0, 1.0)


## Разряд в момент t при силе k и заряде vitals. Возвращает текст для приборов; разряд был, если fired() == true.
## Время с начала разряда по оставшемуся миганию (FLICKER → 0); −1 — разряда нет.
static func arc_time(fl: float) -> float:
	return FLICKER - fl if fl > 0.0 else -1.0


## Фронт дуг (z в осях корабля, м) через t с после разряда.
static func arc_front(t: float) -> float:
	return ARC_FROM + ARC_SPEED * t


## Сила дуг на обшивке в точке z через t с: гауссов фронт × (1 − t/FLICKER); вне 0…FLICKER — 0.
static func arc_k(z: float, t: float) -> float:
	if t < 0.0 or t >= FLICKER:
		return 0.0
	var d := (z - arc_front(t)) / ARC_WIDTH
	return exp(-d * d) * (1.0 - t / FLICKER)


## Кадр атласа (0…7) через t с: 10 Гц, на последнем держится. lite («Экономно») — всегда первый кадр.
static func arc_frame(t: float, lite := false) -> int:
	if lite or t <= 0.0:
		return 0
	return mini(int(floor(t * ARC_FPS)), ARC_FRAMES - 1)


## Сила карточки kind через t с после разряда (двойник shaders/zap_cards.gdshader); вне 0…FLICKER — 0.
static func card_k(kind: int, t: float) -> float:
	if t < 0.0 or t >= FLICKER:
		return 0.0
	match kind:
		Card.WINDOW:
			return 1.0 - smoothstep(0.0, WINDOW_GONE, t)
		Card.BRANCH:
			return smoothstep(0.12, 0.28, t) * (1.0 - smoothstep(0.4, FLICKER, t))
	return smoothstep(0.12, 0.22, t) * (1.0 - smoothstep(0.4, FLICKER, t))


## Точка касания дна под килем в осях корабля (ship — его мировое положение): чуть над сеткой дна;
## Vector3.INF — дно дальше GROUND_GAP от киля, ветвей нет.
static func ground_contact(ship: Transform3D) -> Vector3:
	var keel := ship * KEEL
	var floor_y := Seabed.mesh_height(keel.x, keel.z)
	if keel.y - floor_y > GROUND_GAP:
		return Vector3.INF
	return ship.affine_inverse() * Vector3(keel.x, floor_y + GROUND_LIFT, keel.z)


## Полосы карточек [от, до, полуширина (вектор), вид Card]: дуга у окна всегда, ветви и искра — при касании.
static func card_strips(contact: Vector3) -> Array:
	var out := [[WINDOW_FROM, WINDOW_TO, Vector3(0.0, WINDOW_HALF, 0.0), Card.WINDOW]]
	if contact == Vector3.INF:
		return out
	for dz: float in BRANCH_DZ:
		out.append([KEEL + Vector3(0.0, 0.0, dz), contact, Vector3(0.0, 0.0, BRANCH_HALF), Card.BRANCH])
	out.append([contact + Vector3(0.0, 0.03, -SPARK_HALF), contact + Vector3(0.0, 0.03, SPARK_HALF),
		Vector3(SPARK_HALF, 0.0, 0.0), Card.SPARK])
	return out


## Массивы меша карточек: по два треугольника на полосу, UV 0…1 по длине и ширине, вид — в COLOR.r.
static func card_arrays(strips: Array) -> Array:
	var pos := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var corner_uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for s: Array in strips:
		var a: Vector3 = s[0]
		var b: Vector3 = s[1]
		var w: Vector3 = s[2]
		var pts := [a - w, b - w, b + w, a + w]
		for i: int in [0, 1, 2, 0, 2, 3]:
			pos.append(pts[i])
			uv.append(corner_uv[i])
			col.append(Color(float(s[3]), 0.0, 0.0, 1.0))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_COLOR] = col
	return arr


func fire(t: float, k: float, vitals: Vitals) -> String:
	if k <= 0.0:
		return "Разряд обесточен"
	if t - last < COOLDOWN:
		return "Разряд копится"
	if not vitals.spend(Vitals.ZAP_COST):
		return "Мало энергии: для разряда нужно %d единиц" % int(Vitals.ZAP_COST)
	last = t
	radius = radius_for(k)
	flicker = FLICKER
	return "Разряд по корпусу"


func fired_at(t: float) -> bool:
	return last == t


## Разряд готов: откат кончился (шкала на щитке горит).
func ready(t: float) -> bool:
	return t - last >= COOLDOWN


## Угол рычага, градусы (rotation.z модели), в момент t.
func lever_deg(t: float) -> float:
	var e := t - last
	if e >= COOLDOWN:
		return LEVER_UP
	if e < FLICKER:
		return LEVER_DOWN
	return lerpf(LEVER_DOWN, LEVER_UP, (e - FLICKER) / (COOLDOWN - FLICKER))


func update(dt: float) -> void:
	flicker = maxf(0.0, flicker - dt)
