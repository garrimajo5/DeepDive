class_name EcoRay
extends EcoSystem
## Ледокрылы (initRays/rayUpdate в js/creatures.js, песни — Snd.song в js/soundscape.js; концепт icewing.jpg, бестиарий):
## гигантские скаты с размахом 14 м. Два ската кружат по своим кругам под самым льдом (не ниже 7 м над дном,
## не выше −5,5 м). Корабль на пути — скат поднимается и проходит над ним, крыльями корпус не задевает.
## Раз в 14–22 с скат зовёт ближайшую свободную стаю светляков рифа (ближе 45 м): стая 18 с держится
## в 12 м за ним и на 3 м ниже (EcoFish.Shoal.follow), наблюдение «follow». Раз в 14–23 с ближайший скат
## (ближе 160 м) поёт — 3–5 низких нот, слева или справа от корабля (song: для звука); ближе 110 м — наблюдение «song».
## Заметен сонару и сканеру. На спинах катаются присоски (EcoRemora).

const ID := "ray"
## Круги скатов: центр (высота — средняя глубина), радиус и скорость (м/с) — числа браузера. Второй круг (в браузере
## (−140, −11, −90), r 55) шёл в 19 м от Светового колодца 05 слоя 1 и поднимался над кораблём, стоящим у колодца:
## теперь он к юго-востоку от колодца — ледокрыл проходит вдалеке, в виду из окна, корабль не задевает (#836).
const PATHS: Array[Dictionary] = [
	{"c": Vector3(0, -9, 10), "r": 85.0, "sp": 4.2},
	{"c": Vector3(-100, -11, -120), "r": 35.0, "sp": 3.6},
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
## Низ корпуса над точкой корабля (EcoHull.box: −1,6 м). Скат ниже середины корпуса (между низом и SHIP_TOP) при
## встрече ныряет под киль на OVER ниже низа, если над дном хватает ABOVE_FLOOR; иначе — поверху. Раньше шёл только
## поверху: снизу его прижимало к днищу (push_out), он тёрся под кораблём, пока тот не проходил, и выскакивал на
## метр за кадр.
const SHIP_BOTTOM := -1.6
## Запас до корпуса (S.pushOut(ry.p, 1.5)).
const HULL_GAP := 1.5
## Скат видит корабль на пути заранее: на LOOK с хода вперёд (свой круг и ход корабля по носу, LOOK_STEPS взглядов
## через равные доли) — взмывает, пока корпус ещё не под крылом. Без этого корабль, идущий навстречу, накрывал ската
## раньше, чем тот успевал подняться (ход вверх не больше CLIMB_MAX), и обшивка (push_out) сдвигала тело рывком до
## метра за кадр.
const LOOK := 3.0
const LOOK_STEPS := 3
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
## Крен в поворот (Б3, «плавность поведения»): скат ложится на внутреннее крыло, как самолёт, — tan крена = боковое
## ускорение на круге (скорость × скорость поворота) / BANK_ACC, не круче BANK_MAX. Раньше крен был один на всех,
## rotateZ(−0,22) браузера, и клал ската на внешнее крыло: на круге он «падал» наружу. Тесный круг второго ската
## (35 м) — круче первого (85 м).
const BANK := 0.22   ## прежний постоянный крен браузера, рад — ориентир величины
const BANK_ACC := 1.0
const BANK_MAX := deg_to_rad(22.0)
## Тангаж (Б3, «плавность поведения»): идёт вверх — нос вверх, вниз — нос вниз, по наклону пути
## (atan2(вертикальная скорость, скорость по кругу)), не круче PITCH_MAX; догоняет нужный за PITCH_FOLLOW (1/с) —
## над кораблём скат не всплывает «лифтом», а взмывает и плавно выравнивается.
const PITCH_MAX := deg_to_rad(20.0)
const PITCH_FOLLOW := 4.0
## Высота (Б3, «плавность поведения»): вертикальный ход догоняет нужный (3 или 0,5 × остаток высоты, как раньше)
## не быстрее CLIMB_ACCEL м/с² и не больше CLIMB_MAX м/с, к нужной высоте тормозит заранее (√(2·a·d)). Раньше
## lerp 3/с срывал ската с места: корабль у льда — до 21 м/с вверх за кадр («лифт» при тангаже 20°).
const CLIMB_MAX := 4.0
const CLIMB_ACCEL := 6.0
## Взмах крыльев (Б3, «плавность поведения»): фаза идёт по времени мира со скоростью FLAP_RATE рад/с (как sin(1,3 t)
## в браузере). Взмывает над кораблём — машет сильнее (размах до FLAP_HARD при подъёме CLIMB_MAX) и чаще (до
## FLAP_FAST), опускается — планирует (размах до FLAP_GLIDE); доля размаха догоняет нужную за FLAP_FOLLOW (1/с), фаза
## копится шагом — частота меняется без скачка. Раньше крылья махали одинаково по TIME шейдера, и «сильный взмах»,
## что срывает вихри с кончиков (EcoRayDust), был только в облачках.
const FLAP_RATE := 1.3
const FLAP_HARD := 1.6
const FLAP_FAST := 1.5
const FLAP_GLIDE := 0.5
const FLAP_FOLLOW := 2.0


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
	## Корабль на пути (под крылом или будет через EcoRay.LOOK): скат обходит его по высоте.
	var over := false
	## Обходит снизу (под килем), а не поверху; решается в начале встречи.
	var under := false
	## Тангаж тела (рад, > 0 — нос вверх), плавный.
	var pitch := 0.0
	## Вертикальный ход (м/с), плавный.
	var vy := 0.0
	## Фаза взмаха (рад, 0…TAU) и доля размаха (1 — обычный, плавная).
	var flap := 0.0
	var flap_k := 1.0
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
		ry.flap = float(ry.index)   # сдвиг между скатами — как номер ската в браузере
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
	var floor_y := float(world.ground.call(x, z)) if world.ground.is_valid() else -INF
	ty = minf(TOP_Y, maxf(ty, floor_y + ABOVE_FLOOR))
	var s := world.ship
	var met := not ry.over
	ry.over = EcoHull.touches(Vector3(x, s.pos.y + 1.6, z), s.pos, s.yaw, WING) or foresees(ry, s)
	var keel := s.pos.y + SHIP_BOTTOM - OVER
	if not ry.over:
		ry.under = false
	elif met:
		ry.under = ry.placed and ry.p.y < s.pos.y + (SHIP_BOTTOM + SHIP_TOP) * 0.5 and keel >= floor_y + ABOVE_FLOOR
	if ry.over and ry.under and keel >= floor_y + ABOVE_FLOOR:
		ty = minf(ty, keel)
	elif ry.over:
		ry.under = false
		ty = minf(CEIL_Y, maxf(ty, s.pos.y + SHIP_TOP + OVER))
	var y0 := ry.p.y
	var y := ty
	if ry.placed:
		y = climb(ry, ty, 3.0 if ry.over else 0.5, dt)
	else:
		ry.vy = 0.0
	var was := ry.placed
	ry.placed = true
	ry.p = Vector3(x, y, z)
	var res := EcoHull.push_out(ry.p, s.pos, s.yaw, HULL_GAP)
	if not res.is_empty():
		ry.p = res[0]
	ry.dir = Vector3(-sin(ry.ang), 0.0, cos(ry.ang))
	if not was or dt <= 0.0:
		ry.pitch = 0.0
	else:
		ry.pitch = lerpf(ry.pitch, pitch_for((ry.p.y - y0) / dt, ry.speed), 1.0 - exp(-PITCH_FOLLOW * dt))
	flap_step(ry, dt)


## Корабль окажется под крылом за LOOK с хода вперёд: точка круга ската через t против корабля, ушедшего по носу на
## speed · t (t — LOOK / LOOK_STEPS, 2 · LOOK / LOOK_STEPS … LOOK).
static func foresees(ry: Ray, s: EcoLink.ShipState) -> bool:
	var nose := Vector3(-sin(s.yaw), 0.0, -cos(s.yaw)) * s.speed
	for k in LOOK_STEPS:
		var t := LOOK * float(k + 1) / LOOK_STEPS
		var a := ry.ang + ry.speed / ry.radius * t
		var at := Vector3(ry.center.x + cos(a) * ry.radius, s.pos.y + 1.6, ry.center.z + sin(a) * ry.radius)
		if EcoHull.touches(at, s.pos + nose * t, s.yaw, WING):
			return true
	return false


## Шаг взмаха: доля размаха к нужной по вертикальному ходу, фаза — по частоте от доли.
static func flap_step(ry: Ray, dt: float) -> void:
	if dt <= 0.0:
		return
	ry.flap_k = lerpf(ry.flap_k, flap_want(ry.vy), 1.0 - exp(-FLAP_FOLLOW * dt))
	ry.flap = fposmod(ry.flap + flap_rate(ry.flap_k) * dt, TAU)


## Нужная доля размаха при вертикальном ходе vy (м/с): вверх — до FLAP_HARD, вниз — до FLAP_GLIDE, ровно — 1.
static func flap_want(vy: float) -> float:
	var u := clampf(vy / CLIMB_MAX, -1.0, 1.0)
	return 1.0 + (FLAP_HARD - 1.0) * u if u >= 0.0 else 1.0 + (1.0 - FLAP_GLIDE) * u


## Частота взмаха (рад/с) при доле размаха k: сильнее обычного — чаще, до FLAP_FAST; планирует — как обычно.
static func flap_rate(k: float) -> float:
	return FLAP_RATE * lerpf(1.0, FLAP_FAST, clampf((k - 1.0) / (FLAP_HARD - 1.0), 0.0, 1.0))


## Подъём крыла (м) на расстоянии ax от середины (по x меша) — двойник шейдера RayView.
static func wing_lift(ax: float, flap: float, flap_k: float) -> float:
	return sin(flap - ax * 0.32) * pow(ax / 7.0, 1.4) * 1.8 * flap_k


## Шаг высоты к ty: нужный ход — follow × остаток, не больше CLIMB_MAX и не больше √(2·CLIMB_ACCEL·остаток) (успеть
## встать), сам ход ry.vy меняется не быстрее CLIMB_ACCEL; проскочил цель — встаёт на ней. Возвращает новую высоту.
static func climb(ry: Ray, ty: float, follow: float, dt: float) -> float:
	if dt <= 0.0:
		return ry.p.y
	var d := ty - ry.p.y
	var want := signf(d) * minf(minf(absf(d) * follow, CLIMB_MAX), sqrt(2.0 * CLIMB_ACCEL * absf(d)))
	ry.vy = move_toward(ry.vy, want, CLIMB_ACCEL * dt)
	var y := ry.p.y + ry.vy * dt
	if (ty - y) * d < 0.0:
		y = ty
		ry.vy = 0.0
	return y


## Нужный тангаж при вертикальной скорости vy (м/с) и скорости по кругу speed (м/с): наклон пути, ± PITCH_MAX.
static func pitch_for(vy: float, speed: float) -> float:
	return clampf(atan2(vy, maxf(speed, 0.1)), -PITCH_MAX, PITCH_MAX)


## Позвать ближайшую свободную стаю рифа (не у кроны и не молодь) ближе LEAD_R.
func _lead(world: EcoWorld, ry: Ray) -> void:
	if _fish == null:
		return
	var best: EcoFish.Shoal = null
	var bd := LEAD_R
	for sh in _fish.shoals:
		if sh.crown or sh.cage or sh.riding or sh.leader():
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


## Место ската в мире: +Z — по курсу, нос поднят на pitch, крен `bank` в поворот (как меш RayView). По нему же сидят
## присоски на спине.
static func xform(ry: Ray) -> Transform3D:
	var fwd := ry.dir if ry.dir.length_squared() > 1e-6 else Vector3.BACK
	fwd = fwd * cos(ry.pitch) + Vector3.UP * sin(ry.pitch)
	var b := Basis.looking_at(-fwd, Vector3.UP)  # looking_at смотрит в −Z: меш смотрит носом в +Z
	# +X меша — левое крыло: крен влево (bank > 0) опускает его — поворот вокруг носа на −bank
	b = b * Basis(Vector3.BACK, -bank(ry))
	return Transform3D(b, ry.p)


## Скорость поворота курса (рад/с, + — влево, к +X меша): по кругу угол ang растёт, курс (−sin, 0, cos) уходит вправо.
static func turn_rate(ry: Ray) -> float:
	return -ry.speed / ry.radius if ry.radius > 0.0 else 0.0


## Крен ската (рад, + — на левое крыло): в сторону поворота, atan(скорость × поворот / BANK_ACC), ± BANK_MAX.
static func bank(ry: Ray) -> float:
	return clampf(atan(ry.speed * turn_rate(ry) / BANK_ACC), -BANK_MAX, BANK_MAX)


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
