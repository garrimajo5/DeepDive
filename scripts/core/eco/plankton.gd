class_name EcoPlankton
extends EcoSystem
## Мерцающий планктон (initClouds/cloudUpdate в js/creatures.js): четыре облака по 360 светящихся одноклеточных,
## радиус 12 м, 10 м над дном (не выше −10 м); облако медленно дрейфует вокруг дома (±6 м). Вспыхивает, когда его
## «режет» что-то быстрое: корабль быстрее 2,2 м/с (клетки ближе WAKE_GAP к корпусу), серпохвост в броске (быстрее
## 5 м/с, тело 4 м) и ледокрыл (крыло 6 м). Вспышка гаснет 0,45 в секунду — след держится пару секунд.
## Светящийся след корабля (wake > 0,5) выдаёт корабль серпохвосту даже без прожектора (EcoPred, поле plankton).
## Наблюдения журнала: «wake» — за кораблём тянется след (раз в 40 с на облако), «pred» — бросок серпохвоста сквозь
## облако видно издалека (раз в 40 с), «slow» — корабль медленно идёт сквозь облако без следа (4 с, раз в 60 с),
## «betray» — серпохвост заметил след (шлёт EcoPred). Облако — цель сонара и сканера.
## Клетки движутся по формуле времени (center + offset + wobble): вид повторяет её в шейдере, мир считает клетки
## только у облака, которое сейчас режут или которое ещё светится (режущих проверяют у половины клеток за шаг).

const ID := "plankton"
## Клеток в облаке и радиус облака, м (PL_N, PL_R).
const PER_CLOUD := 360
const R := 12.0
## Дома облаков (x, z) из браузера; высота — 10 м над дном, не выше CEILING.
const HOMES: Array[Vector2] = [Vector2(8, 72), Vector2(-60, 0), Vector2(60, -60), Vector2(-20, -140)]
const ABOVE := 10.0
const CEILING := -10.0
## Корабль режет облако быстрее этого, м/с (WAKE_SPEED); клетки ближе WAKE_GAP к коробке корпуса вспыхивают.
const WAKE_SPEED := 2.2
const WAKE_GAP := 1.0
## Медленнее этого корабль сквозь облако не «идёт» (наблюдение «slow»).
const SLOW_SPEED := 0.3
const SLOW_TIME := 4.0
## Серпохвост режет облако быстрее PRED_FAST м/с; тело — отрезок PRED_BODY м за головой, радиус PRED_GAP.
const PRED_FAST := 5.0
const PRED_BODY := 4.0
const PRED_GAP := 2.0
## Ледокрыл: отрезок от 3 м впереди до 4 м позади, радиус RAY_GAP.
const RAY_GAP := 6.0
## Вспышка гаснет GLOW_DOWN в секунду; ярче LIT_ON клетка считается светящейся (g > 0,4).
const GLOW_DOWN := 0.45
const LIT_ON := 0.4
## Клеток корабля для полного следа (lit / 25) и клеток хищника для наблюдения «pred» (> 8).
const WAKE_FULL := 25.0
const PRED_LIT := 8
## След ярче WAKE_ON выдаёт корабль (E.shipWake > 0,5).
const WAKE_ON := 0.5
const WAKE_CD := 40.0
const PRED_CD := 40.0
const SLOW_CD := 60.0
## Дрейф облака: ±6 м по x и z, ±1 м по высоте; покачивание клетки: ±0,4 м, по высоте ±0,25 м.
const DRIFT := 6.0
const DRIFT_Y := 1.0
const WOBBLE := 0.4
const WOBBLE_Y := 0.25
## Кто зажёг клетку (cl.by).
enum By { NONE, SHIP, PRED, RAY }
## Сколько секунд клетка светится ярче LIT_ON после вспышки.
const LIT_TIME := (1.0 - LIT_ON) / GLOW_DOWN
## Пока облако режут, вид переписывает буфер не чаще этого (вспышка за это время гаснет на 0,05).
const REFRESH := 0.1


## Облако планктона.
class Cloud:
	extends RefCounted
	var index := 0
	var home := Vector3.ZERO
	## Центр облака в этот шаг.
	var c := Vector3.ZERO
	var phase := 0.0
	## Смещения клеток от центра.
	var offsets := PackedVector3Array()
	## Время мира последней вспышки клетки (−99 — не вспыхивала) и кто её зажёг (By).
	var lit_at := PackedFloat32Array()
	var by := PackedByteArray()
	## След корабля 0…1 в этот шаг (cl.ship).
	var ship := 0.0
	## Клеток, что зажёг серпохвост, в этот шаг (predLit).
	var pred_lit := 0
	## Последний раз, когда облако резали (время мира); пока клетки светятся — облако считаем.
	var cut_at := -99.0
	## Растёт не чаще раза в REFRESH, пока облако зажигают, — виду пора переписать буфер.
	var version := 0
	var bumped_at := -99.0
	var slow_t := 0.0
	var wake_cd := 0.0
	var slow_cd := 0.0
	var pred_cd := 0.0


var clouds: Array[Cloud] = []
## Самый яркий след корабля в этот шаг (E.shipWake).
var wake := 0.0

var _homes: Array[Vector2]
## Серпохвосты и ледокрылы, что режут облака (null — их нет). Слабые ссылки: серпохвосты держат планктон
## (EcoPred.plankton) — сильная замкнула бы круг RefCounted и утекла при выходе.
var _preds: WeakRef
var _rays: WeakRef


## homes — свои места облаков (для тестов), пусто — по браузеру.
func _init(preds: EcoPred = null, rays: EcoRay = null, homes: Array[Vector2] = []) -> void:
	_preds = weakref(preds) if preds else null
	_rays = weakref(rays) if rays else null
	_homes = homes.duplicate() if not homes.is_empty() else HOMES.duplicate()


static func seed_for(world_seed: int) -> int:
	return (world_seed * 31 + 9157) & 0xFFFFFFFF


func reset(world: EcoWorld) -> void:
	var rnd := EcoWorld.seeded_for(seed_for(world.seed_value))
	clouds.clear()
	wake = 0.0
	for h in _homes:
		var cl := Cloud.new()
		cl.index = clouds.size()
		var y := CEILING
		if world.ground.is_valid():
			y = minf(float(world.ground.call(h.x, h.y)) + ABOVE, CEILING)
		cl.home = Vector3(h.x, y, h.y)
		cl.phase = rnd.range_f(0.0, 6.0)
		# центр — сразу по дрейфу, как в шаге: раньше стоял в доме и на первом шаге прыгал до 6 м
		cl.c = center(cl, world.time)
		cl.offsets.resize(PER_CLOUD)
		cl.lit_at.resize(PER_CLOUD)
		cl.lit_at.fill(-99.0)
		cl.by.resize(PER_CLOUD)
		for k in PER_CLOUD:
			var v := Vector3(rnd.range_f(-1, 1), rnd.range_f(-0.5, 0.5), rnd.range_f(-1, 1))
			if v.length_squared() > 1.0:
				v = v.normalized()
			cl.offsets[k] = v * R * pow(rnd.next(), 1.0 / 3.0)
		clouds.append(cl)


## Центр облака в момент t: дом с медленным дрейфом.
static func center(cl: Cloud, t: float) -> Vector3:
	return Vector3(cl.home.x + sin(t * 0.03 + cl.phase) * DRIFT, cl.home.y + sin(t * 0.17 + cl.phase) * DRIFT_Y,
		cl.home.z + cos(t * 0.025 + cl.phase) * DRIFT)


## Покачивание клетки k в момент t (то же — в шейдере вида).
static func wobble(k: int, t: float) -> Vector3:
	var w := t * 0.3 + k
	return Vector3(sin(w) * WOBBLE, sin(w * 1.3) * WOBBLE_Y, cos(w * 0.9) * WOBBLE)


## Где клетка k облака в момент t (без корпуса корабля).
static func cell_pos(cl: Cloud, k: int, t: float) -> Vector3:
	return center(cl, t) + cl.offsets[k] + wobble(k, t)


## Яркость вспышки клетки k в момент t: 1 при вспышке, гаснет GLOW_DOWN в секунду.
static func glow(cl: Cloud, k: int, t: float) -> float:
	return clampf(1.0 - (t - cl.lit_at[k]) * GLOW_DOWN, 0.0, 1.0)


## Центр корпуса корабля в мире.
static func hull_center(s: EcoLink.ShipState) -> Vector3:
	return s.pos + EcoHull.CENTER.rotated(Vector3.UP, s.yaw)


## Коробка корпуса в осях корабля (корпус, нос и корма по HullPlan): нижний и верхний углы.
const BOX_MIN := Vector3(-HullPlan.NOSE_W / 2.0, HullPlan.CENTER_Y - HullPlan.NOSE_H / 2.0, -11.0)
const BOX_MAX := Vector3(HullPlan.NOSE_W / 2.0, HullPlan.CENTER_Y + HullPlan.NOSE_H / 2.0, HullPlan.STERN_END)


## Ближе ли точка (оси корабля) к коробке корпуса, чем r (внутри — тоже да).
static func near_box(l: Vector3, r: float) -> bool:
	return l.x > BOX_MIN.x - r and l.x < BOX_MAX.x + r and l.y > BOX_MIN.y - r and l.y < BOX_MAX.y + r \
		and l.z > BOX_MIN.z - r and l.z < BOX_MAX.z + r


## Квадрат расстояния от точки до отрезка a–b (segD2).
static func seg_d2(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	var u := clampf((p - a).dot(ab) / l2, 0.0, 1.0) if l2 > 0.0 else 0.0
	return p.distance_squared_to(a + ab * u)


func step(world: EcoWorld, dt: float) -> void:
	var t := world.time
	var s := world.ship
	var hc := hull_center(s)
	var speed := absf(s.speed)
	var preds: EcoPred = _preds.get_ref() if _preds else null
	var rays: EcoRay = _rays.get_ref() if _rays else null
	wake = 0.0
	for cl in clouds:
		cl.wake_cd -= dt
		cl.slow_cd -= dt
		cl.pred_cd -= dt
		cl.c = center(cl, t)
		# кто сейчас режет облако: корабль, если быстрый; серпохвосты в броске; ледокрылы
		var ship_cuts := speed > WAKE_SPEED and hc.distance_to(cl.c) < R + EcoHull.REACH
		var segs: Array[Vector3] = []
		var gaps: Array[float] = []
		var who: Array[int] = []
		if preds:
			for pr in preds.all:
				var a := pr.agent
				if a.alive and a.v.length() > PRED_FAST and a.p.distance_to(cl.c) < R + PRED_BODY:
					segs.append_array([a.p, a.p - a.v.normalized() * PRED_BODY])
					gaps.append(PRED_GAP * PRED_GAP)
					who.append(By.PRED)
		if rays:
			for ry in rays.rays:
				if ry.placed and ry.p.distance_to(cl.c) < R + 8.0:
					segs.append_array([ry.p + ry.dir * 3.0, ry.p - ry.dir * 4.0])
					gaps.append(RAY_GAP * RAY_GAP)
					who.append(By.RAY)
		var cutting := ship_cuts or not who.is_empty()
		if cutting:
			cl.cut_at = t
		var lit := 0
		cl.pred_lit = 0
		if cutting or t - cl.cut_at < LIT_TIME:
			var drift := cl.c
			var any := false
			var half := (world.steps + cl.index) & 1
			for k in PER_CLOUD:
				# режущих проверяем у половины клеток за шаг, вразнобой: вспышка держится секунды, разницы не видно
				if cutting and (k & 1) == half:
					var p := drift + cl.offsets[k] + wobble(k, t)
					var by := By.NONE
					if ship_cuts and near_box(EcoHull.to_ship(p, s.pos, s.yaw), WAKE_GAP):
						by = By.SHIP
					else:
						for i in who.size():
							if seg_d2(p, segs[i * 2], segs[i * 2 + 1]) < gaps[i]:
								by = who[i]
								break
					if by != By.NONE:
						any = true
						cl.lit_at[k] = t
						cl.by[k] = by
				if t - cl.lit_at[k] < LIT_TIME:
					if cl.by[k] == By.SHIP:
						lit += 1
					elif cl.by[k] == By.PRED:
						cl.pred_lit += 1
			if any and t - cl.bumped_at >= REFRESH:
				cl.version += 1
				cl.bumped_at = t
		cl.ship = minf(1.0, lit / WAKE_FULL)
		wake = maxf(wake, cl.ship)
		if cl.ship > WAKE_ON and cl.wake_cd <= 0.0:
			cl.wake_cd = WAKE_CD
			world.emit(ID, "wake", s.pos, _text(world, "%s вспыхивает: за кораблём тянется светящийся след", true))
		if cl.pred_lit > PRED_LIT and cl.pred_cd <= 0.0:
			cl.pred_cd = PRED_CD
			world.emit(ID, "pred", cl.c, _pred_text(world))
		# медленно сквозь облако — без следа
		if hc.distance_to(cl.c) < R and speed > SLOW_SPEED and speed <= WAKE_SPEED and lit == 0:
			cl.slow_t += dt
		else:
			cl.slow_t = 0.0
		if cl.slow_t > SLOW_TIME and cl.slow_cd <= 0.0:
			cl.slow_cd = SLOW_CD
			world.emit(ID, "slow", s.pos, _text(world, "Корабль идёт медленно — %s не вспыхивает"))


## След корабля виден хищникам (E.shipWake > 0,5).
func betrays() -> bool:
	return wake > WAKE_ON


## Каждое облако видно сонару и сканеру (радиус отметки 4 м, как в браузере).
func targets(_world: EcoWorld, out: Array[Dictionary]) -> void:
	for cl in clouds:
		out.append(EcoWorld.target(ID, cl.c, 4.0))


## Текст события собирается в момент показа (вид мог быть уже просканирован); мир — слабой ссылкой, без self.
## fmt — с одним %s для «мерцающего планктона» в именительном падеже; cap — с заглавной.
static func _text(world: EcoWorld, fmt: String, cap := false) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var name := w.nm(ID) if w else Species.called(ID)
		return fmt % (Species.cap(name) if cap else name)


static func _pred_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var p := w.nm(EcoPred.ID, Species.Case.GEN) if w else Species.called(EcoPred.ID, Species.Case.GEN)
		var c := w.nm(ID, Species.Case.ACC) if w else Species.called(ID, Species.Case.ACC)
		return "Бросок %s сквозь %s видно издалека" % [p, c]
