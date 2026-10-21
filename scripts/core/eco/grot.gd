class_name EcoGrot
extends EcoSystem
## Гротовик (initGrot/grotUpdate/grotShelter в js/creatures.js; бестиарий): живой остров — панцирное существо 6 м
## с рифом на спине бредёт по отмели по кругу из четырёх точек браузера (0,45 м/с, поворачивает плавно — 0,3 /с).
## В рифе живёт шестая стая светляков (EcoFish, стая RIDERS): её дом — над спиной, блуждает она в 4 м вокруг
## (sh.range = 4) и кочует вместе с гротовиком; на споры пузырчатки и моллюсков волнолиста не слетается, ледокрыл
## её не уводит (EcoFish.Shoal.riding). Напуганный светляк этой стаи ближе HIDE_R к спине спрятан в рифе: серпохвост
## его теряет (EcoPred, поле grot), наблюдение «hide» — раз в 40 с.
## Корабль задел панцирь (ближе R + SHIP_PAD по горизонтали и ниже верха рифа) — гротовик прячет ноги и замирает
## на 10 с («shy», не чаще раза в 25 с), стая на спине пугается на 3 с. На ходу рядом с кораблём (спина ближе 35 м)
## — наблюдение «drift» раз в 90 с. Заметен сонару и сканеру — у спины, размер 3 м.
## Столкновение корабля с панцирем — `solid` (World.obstacles в браузере), подключить — поток А.

const ID := "grot"
## Круг по отмели (x, z) — как в браузере (js: [[-22, 62], [18, 44], [30, 4], [-14, 12]]).
const ROUTE: Array[Vector2] = [Vector2(-22, 62), Vector2(18, 44), Vector2(30, 4), Vector2(-14, 12)]
## Радиус панциря (м), скорость (м/с), поворот (доля разницы курса в секунду), точка пути пройдена ближе REACHED.
const R := 3.2
const SPEED := 0.45
const TURN := 0.3
const REACHED := 1.5
## Высота: тело над дном FLOOR_UP + LEG_UP · lift; спина — на BACK_UP выше тела, верх рифа — на TOP_UP.
const FLOOR_UP := 0.6
const LEG_UP := 0.55
const BACK_UP := 1.6
const TOP_UP := 3.5
## Стая на спине: номер в EcoFish.shoals, дом — на HOME_UP над спиной, блуждает в RANGE м; прячется ближе HIDE_R.
const RIDERS := 5
const HOME_UP := 0.6
const RANGE := 4.0
const HIDE_R := 5.0
## Корабль задел панцирь: ближе R + SHIP_PAD по горизонтали и ниже верха рифа — замирает на SHY_T с, не чаще SHY_CD,
## стая пугается на SHY_ALARM с.
const SHIP_PAD := 6.4
const SHY_T := 10.0
const SHY_CD := 25.0
const SHY_ALARM := 3.0
## Наблюдения: «hide» — раз в HIDE_CD с, «drift» — раз в DRIFT_CD с, если спина ближе DRIFT_R к кораблю.
const HIDE_CD := 40.0
const DRIFT_CD := 90.0
const DRIFT_R := 35.0
## Цель сонара и сканера — спина, размер TARGET_R.
const TARGET_R := 3.0
## Панцирь для столкновения: полуэллипсоид SHELL (ширина, высота, длина) над телом, с запасом на голову спереди.
const SHELL := Vector3(2.4, 1.1, 3.2)
## Без дна (тесты без ground) тело стоит на этой высоте.
const FALLBACK_FLOOR := -40.0


## Сам гротовик.
class Walker:
	extends RefCounted
	## Место на дне (x, z; y — дно под ним), курс (yaw = 0 — к +Z, как в браузере; растёт — поворот влево).
	var p := Vector3.ZERO
	var yaw := 0.0
	## Номер точки пути, к которой идёт.
	var wp := 1
	## Ноги: 1 — выпущены (идёт), 0 — спрятаны под панцирь; тянется к цели за ~0,5 с.
	var lift := 1.0
	## Замер (с) и перезарядка испуга, перезарядки наблюдений.
	var shy := 0.0
	var shy_cd := 0.0
	var hide_cd := 0.0
	var drift_cd := 0.0
	## Высота тела (низ панциря), спина (риф) и верх рифа — ставит place().
	var body_y := 0.0
	var back := Vector3.ZERO
	var top := 0.0

	## Идёт (не замер).
	func moving() -> bool:
		return shy <= 0.0


var grot: Walker
## Стая на спине (EcoFish.shoals[RIDERS]) — нет светляков, нет и стаи.
var shoal: EcoFish.Shoal

var _fish: EcoFish
var _ground: Callable


func _init(fish: EcoFish = null) -> void:
	_fish = fish


func reset(world: EcoWorld) -> void:
	_ground = world.ground
	grot = Walker.new()
	var s := ROUTE[0]
	grot.p = Vector3(s.x, _floor(s.x, s.y), s.y)
	shoal = null
	if _fish and _fish.shoals.size() > RIDERS:
		shoal = _fish.shoals[RIDERS]
	place()
	if shoal:  # стая начинает на спине (в браузере рыбы встают на home после переноса дома)
		shoal.riding = true
		shoal.range_m = RANGE
		var from := shoal.center
		for f: EcoFish.Fish in shoal.members:
			f.agent.p += shoal.home - from
			f.agent.home = shoal.home
		shoal.center = shoal.home
		shoal.goal = shoal.home


func step(world: EcoWorld, dt: float) -> void:
	_ground = world.ground
	var gr := grot
	gr.shy -= dt
	gr.shy_cd -= dt
	gr.hide_cd -= dt
	gr.drift_cd -= dt
	var s := world.ship.pos
	if Vector2(s.x - gr.p.x, s.z - gr.p.z).length() < R + SHIP_PAD and s.y < gr.top and gr.shy <= 0.0 \
			and gr.shy_cd <= 0.0:
		gr.shy = SHY_T
		gr.shy_cd = SHY_CD
		if shoal:
			shoal.alarm = maxf(shoal.alarm, SHY_ALARM)
		world.emit(ID, "shy", gr.back, _text(world, "%s прячет ноги под панцирь и замирает"))
	var moving := gr.moving()
	gr.lift += ((1.0 if moving else 0.0) - gr.lift) * minf(1.0, dt * 2.0)
	if moving:
		var tg := ROUTE[gr.wp]
		var to := Vector2(tg.x - gr.p.x, tg.y - gr.p.z)
		if to.length() < REACHED:
			gr.wp = (gr.wp + 1) % ROUTE.size()
		else:
			gr.yaw += wrapf(atan2(to.x, to.y) - gr.yaw, -PI, PI) * minf(1.0, dt * TURN)
			gr.p.x += sin(gr.yaw) * SPEED * dt
			gr.p.z += cos(gr.yaw) * SPEED * dt
		if gr.drift_cd <= 0.0 and s.distance_to(gr.back) < DRIFT_R:
			gr.drift_cd = DRIFT_CD
			world.emit(ID, "drift", gr.back, _text(world, "%s неспешно бредёт по отмели, на спине у него риф"))
	place()


## Поставить тело, спину и верх рифа по дну и ногам; дом стаи — над спиной (grotPlace).
func place() -> void:
	var gr := grot
	gr.p.y = _floor(gr.p.x, gr.p.z)
	gr.body_y = gr.p.y + FLOOR_UP + LEG_UP * gr.lift
	gr.back = Vector3(gr.p.x, gr.body_y + BACK_UP, gr.p.z)
	gr.top = gr.body_y + TOP_UP
	if shoal:
		_follow(shoal)


func _follow(sh: EcoFish.Shoal) -> void:
	sh.home = grot.back + Vector3(0, HOME_UP, 0)


## Гротовик, в рифе которого прячется светляк f (grotShelter): f из стаи на спине, стая напугана, f ближе HIDE_R
## к спине; иначе null.
func shelter(f: EcoFish.Fish) -> Walker:
	if grot == null or shoal == null or f == null or f.shoal != shoal or not (shoal.alarm > 0.0):
		return null
	return grot if f.agent.p.distance_to(grot.back) < HIDE_R else null


## Серпохвост потерял стаю в рифе: наблюдение «hide» не чаще HIDE_CD.
func hid_fish(world: EcoWorld) -> void:
	if grot.hide_cd > 0.0:
		return
	grot.hide_cd = HIDE_CD
	world.emit(ID, "hide", grot.back, _hide_text(world))


## Точка (в мире) внутри панциря — для столкновения корабля (подключает поток А).
func solid(p: Vector3) -> bool:
	var gr := grot
	if gr == null:
		return false
	var q := Basis(Vector3.UP, gr.yaw).inverse() * (p - Vector3(gr.p.x, gr.body_y, gr.p.z))
	if q.y < gr.p.y - gr.body_y:
		return false
	var e := Vector3(q.x / SHELL.x, maxf(q.y, 0.0) / SHELL.y, q.z / (SHELL.z + 0.6))
	return e.length_squared() < 1.0


## Гротовик виден сонару и сканеру.
func targets(_world: EcoWorld, out: Array[Dictionary]) -> void:
	if grot:
		out.append(EcoWorld.target(ID, grot.back, TARGET_R))


func _floor(x: float, z: float) -> float:
	return float(_ground.call(x, z)) if _ground.is_valid() else FALLBACK_FLOOR


## Текст с названием гротовика (в именительном, с большой буквы) — в момент показа; мир — слабой ссылкой.
static func _text(world: EcoWorld, fmt: String) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		return fmt % Species.cap(w.nm(ID) if w else Species.called(ID))


## «Светляки: стая спряталась в рифе на спине гротовика, серпохвост её потерял».
static func _hide_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var f := w.nm(EcoFish.ID) if w else Species.called(EcoFish.ID)
		var g := w.nm(ID, Species.Case.GEN) if w else Species.called(ID, Species.Case.GEN)
		var p := w.nm(EcoPred.ID) if w else Species.called(EcoPred.ID)
		return "%s: стая спряталась в рифе на спине %s, %s её потерял" % [Species.cap(f), g, p]
