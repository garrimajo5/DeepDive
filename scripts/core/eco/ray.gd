class_name EcoRay
extends EcoSystem
## Ледокрылы (initRays/rayUpdate в js/creatures.js, песни — Snd.song в js/soundscape.js; концепт icewing.jpg, бестиарий):
## гигантские скаты с размахом 14 м. Два ската кружат по своим кругам под самым льдом (не ниже 7 м над дном,
## не выше −5,5 м). Корабль на пути — скат поднимается и проходит над ним, крыльями корпус не задевает.
## Раз в 14–22 с скат зовёт ближайшую свободную стаю светляков рифа (ближе 45 м): стая 18 с держится
## в 12 м за ним и на 3 м ниже (EcoFish.Shoal.follow), наблюдение «follow». Раз в 14–23 с ближайший скат
## (ближе 160 м) поёт — 3–5 низких нот, слева или справа от корабля (song: для звука); ближе 110 м — наблюдение «song».
## Заметен сонару и сканеру. Присоски на спинах скатов — своей задачей.

const ID := "ray"
## Круги скатов: центр (высота — средняя глубина), радиус и скорость (м/с) — числа браузера.
const PATHS: Array[Dictionary] = [
	{"c": Vector3(0, -9, 10), "r": 85.0, "sp": 4.2},
	{"c": Vector3(-140, -11, -90), "r": 55.0, "sp": 3.6},
]
## Глубина качается ± 1,5 м (sin 0,2 t), но не выше TOP_Y и не ниже ABOVE_FLOOR над дном.
const SWAY := 1.5
const TOP_Y := -5.5
const ABOVE_FLOOR := 7.0
## Корабль на пути: точка круга ближе WING к корпусу (на высоте корабля + 1,6) — скат идёт не ниже
## SHIP_TOP + OVER над кораблём (но не выше −1), догоняя эту высоту быстро (3 /с, иначе 0,5 /с).
const WING := 11.0
const SHIP_TOP := 3.5
const OVER := 2.6
const CEIL_Y := -1.0
## Запас до корпуса (S.pushOut(ry.p, 1.5)).
const HULL_GAP := 1.5
## Ведёт стаю: ближе LEAD_R, на LEAD_T с, звать — раз в LEAD_CD с (первый раз через 5–15 с).
const LEAD_R := 45.0
const LEAD_T := 18.0
const LEAD_CD := Vector2(14, 22)
## Песня: слышно ближе SONG_R, наблюдение — ближе NOTE_R; первая через 8 с, дальше 14 + (фраза mod 4) · 3 с.
const SONG_R := 160.0
const NOTE_R := 110.0
const SONG_FIRST := 8.0
## Лад песни: низкие ноты пентатоники (Гц); у первого ската — на кварту ниже (× 0,75).
const SCALE: Array[float] = [110.0, 123.5, 146.8, 164.8, 196.0, 220.0]
## Размер цели сонара и сканера (r: 7).
const TARGET_R := 7.0


## Ледокрыл.
class Ray:
	extends RefCounted
	var index := 0
	var center := Vector3.ZERO
	var radius := 0.0
	var speed := 0.0
	## Угол на круге и начальный.
	var ang := 0.0
	var ang0 := 0.0
	var p := Vector3.ZERO
	## Куда плывёт (касательная к кругу против часовой, если смотреть сверху в осях браузера).
	var dir := Vector3.ZERO
	## Над кораблём сейчас (поднялся над корпусом).
	var over := false
	var lead_cd := 0.0
	var placed := false


var rays: Array[Ray] = []
## Последняя песня для звука: {"ray": номер, "notes": Array[float], "d": м, "pan": −1…1}; пусто — ещё не пел.
var song: Dictionary = {}
## Сколько раз пели (номер фразы).
var phrase := 0

var _rnd: EcoRandom
var _song_cd := SONG_FIRST
var _fish: EcoFish


## fish — светляки, которых скаты водят за собой (null — не водят).
func _init(fish: EcoFish = null) -> void:
	_fish = fish


static func seed_for(world_seed: int) -> int:
	return (world_seed * 31 + 7613) & 0xFFFFFFFF


func reset(world: EcoWorld) -> void:
	_rnd = EcoWorld.seeded_for(seed_for(world.seed_value))
	rays.clear()
	song = {}
	phrase = 0
	_song_cd = SONG_FIRST
	for o in PATHS:
		var ry := Ray.new()
		ry.index = rays.size()
		ry.center = o["c"]
		ry.radius = o["r"]
		ry.speed = o["sp"]
		ry.ang = _rnd.range_f(0.0, 6.28)
		ry.ang0 = ry.ang
		ry.lead_cd = _rnd.range_f(5.0, 15.0)
		rays.append(ry)
		_place(world, ry, 0.0)


func step(world: EcoWorld, dt: float) -> void:
	for ry in rays:
		ry.ang += ry.speed / ry.radius * dt
		_place(world, ry, dt)
		ry.lead_cd -= dt
		if ry.lead_cd <= 0.0:
			ry.lead_cd = _rnd.range_f(LEAD_CD.x, LEAD_CD.y)
			_lead(world, ry)
	_song_cd -= dt
	if _song_cd <= 0.0:
		_song_cd = 14.0 + (phrase % 4) * 3.0
		_sing(world)


## Встать на круг: высота по дну и кораблю, обход корпуса, курс по касательной.
func _place(world: EcoWorld, ry: Ray, dt: float) -> void:
	var x := ry.center.x + cos(ry.ang) * ry.radius
	var z := ry.center.z + sin(ry.ang) * ry.radius
	var ty := ry.center.y + sin(world.time * 0.2 + ry.index) * SWAY
	if world.ground.is_valid():
		ty = maxf(ty, float(world.ground.call(x, z)) + ABOVE_FLOOR)
	ty = minf(TOP_Y, ty)
	var s := world.ship
	ry.over = EcoHull.touches(Vector3(x, s.pos.y + 1.6, z), s.pos, s.yaw, WING)
	if ry.over:
		ty = minf(CEIL_Y, maxf(ty, s.pos.y + SHIP_TOP + OVER))
	var y := lerpf(ry.p.y, ty, minf(1.0, dt * (3.0 if ry.over else 0.5))) if ry.placed else ty
	ry.placed = true
	ry.p = Vector3(x, y, z)
	var res := EcoHull.push_out(ry.p, s.pos, s.yaw, HULL_GAP)
	if not res.is_empty():
		ry.p = res[0]
	ry.dir = Vector3(-sin(ry.ang), 0.0, cos(ry.ang))


## Позвать ближайшую свободную стаю рифа (не у кроны и не молодь) ближе LEAD_R.
func _lead(world: EcoWorld, ry: Ray) -> void:
	if _fish == null:
		return
	var best: EcoFish.Shoal = null
	var bd := LEAD_R
	for sh in _fish.shoals:
		if sh.crown or sh.cage or sh.leader():
			continue
		var d := sh.center.distance_to(ry.p)
		if d < bd:
			bd = d
			best = sh
	if best == null:
		return
	best.follow(ry, LEAD_T)
	world.emit(ID, "follow", ry.p, _text(world, "%s ведёт за собой стаю рыб"))
	world.emit(EcoFish.ID, "follow", ry.p)


## Песня ближайшего ската (ближе SONG_R): 3–5 нот, сторона — по оси x корабля (правый борт +X).
func _sing(world: EcoWorld) -> void:
	var s := world.ship
	var best: Ray = null
	var bd := SONG_R
	for ry in rays:
		var d := ry.p.distance_to(s.pos)
		if d < bd:
			bd = d
			best = ry
	if best == null:
		return
	var local := EcoHull.to_ship(best.p, s.pos, s.yaw)
	var pan := clampf(local.x / 40.0, -1.0, 1.0)
	var notes: Array[float] = []
	for k in 3 + (best.index + phrase) % 3:
		notes.append(SCALE[(best.index * 2 + k * 3 + phrase) % SCALE.size()] * (1.0 if best.index else 0.75))
	phrase += 1
	song = {"ray": best.index, "notes": notes, "d": bd, "pan": pan}
	if bd < NOTE_R:
		# песню слышно сквозь корпус издалека: событие — в сторону ската, но в пределах слуха экипажа (EcoBus.HEARING)
		var at := s.pos + (best.p - s.pos).limit_length(EcoBus.HEARING - 1.0)
		var side := "слева" if pan < -0.3 else ("справа" if pan > 0.3 else "рядом")
		world.emit(ID, "song", at, _text(world, "%s поёт где-то " + side + " — низкий голос слышен сквозь корпус"))


## Каждый скат виден сонару и сканеру.
func targets(_world: EcoWorld, out: Array[Dictionary]) -> void:
	for ry in rays:
		out.append(EcoWorld.target(ID, ry.p, TARGET_R))


## Текст собирается в момент показа (вид мог быть уже просканирован); мир — слабой ссылкой.
static func _text(world: EcoWorld, fmt: String) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		return fmt % Species.cap(w.nm(ID) if w else Species.called(ID))
