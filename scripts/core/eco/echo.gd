class_name EcoEcho
extends EcoSystem
## Эхоловец (js/echo.js, концепт ART-007 `docs/concept-art/eholovec.md`): засадчик около 3 м с двумя ушами-воронками
## лежит снаружи клетки Костей левиафана между рёбрами (EcoBones; без костей — в +14, +10 м от их центра, как
## в браузере) и почти не двигается. Корабль ближе LISTEN_R — слушает его: каждое ухо отдельно, двумя суставами
## (поворот и наклон), поворачивается на корабль (EAR_TURN рад/с, в пределах EAR_YAW/EAR_PITCH), дальше — уши
## медленно обводят воду. Затаившегося нет ни на сонаре, ни в прицеле сканера. Импульс сонара ближе REVEAL_R
## выдаёт его на REVEAL_T с (Ec.onPing): он виден сонару и сканеру, наблюдение «reveal» — только когда раскрылся.
## Подделка голосов (Ec.fake/real/onPing/onLight): корабль ближе LISTEN_R, эхоловец затаился — через FAKE_FIRST с
## и потом раз в FAKE_CD с он шлёт по внутренней связи (EcoLink.VOICE, плашка ART-040 у корабля) ложный вызов
## с просьбой, выгодной ему: «включите прожектор» (пилот, если свет выключен — в половине случаев) или «срочно
## импульс» (сонарщик). Кодового слова забега у подделки нет: на первом спуске она молчит на «Спросить код»
## (silent), на следующих — отвечает чужим словом (старое, с прошлого спуска). Просьба действует BAIT_T с: импульс
## ближе STRIKE_R — удар по корпусу STRIKE («strike»), свет включили — ближайший серпохвост ближе LURE_R бросается
## на корабль (EcoPred.lure, «lure»); не послушались — наблюдение «fake» без текста. Импульс, о котором он не просил,
## раскрывает его (выше) — пока раскрыт, подделок нет. Настоящие доклады экипажа с кодом забега (Ec.real) — ближе
## TALK_R раз в REAL_CD с, чтобы было с чем сравнить. Просьбу корабль сам не исполняет — решает игрок.

const ID := "echo"
## Слушает корабль ближе LISTEN_R (м), импульс сонара ближе REVEAL_R раскрывает его на REVEAL_T с (js/echo.js).
const LISTEN_R := 60.0
const REVEAL_R := 70.0
const REVEAL_T := 120.0
## Место у костей: между парами рёбер PAIR и PAIR + 1 левого борта клетки, на OUT м снаружи от ног рёбер.
const PAIR := 3
const OUT := 3.2
## Без костей — от их центра (js: b.pos + (14, 10)).
const OFFSET := Vector2(14.0, 10.0)
## Тело над дном (js: + 0,7; на склоне — над самым высоким дном под телом, BED).
const UP := 0.7
## Где мерить дно под телом (в осях тела): середина, голова, хвост, бока.
const BED: Array[Vector3] = [Vector3.ZERO, Vector3(0, 0, 1.4), Vector3(0, 0, -1.3), Vector3(0.6, 0, 0),
	Vector3(-0.6, 0, 0)]
## Уши: основание стебля в теле (x вбок, y вверх, z вперёд — голова к +Z), предел поворота от носа и наклона (рад),
## скорость сустава (рад/с). Покой: уши обводят воду ± IDLE_SWEEP за IDLE_PERIOD с, левое и правое — вразнобой.
## Сустав с инерцией (`ear_joint`): разгон и торможение не быстрее EAR_ACCEL рад/с², у цели — ход EAR_GAIN × отставание
## (тянется за медленной целью без рывков, к неподвижной подходит без перелёта). Поворот — в пределах ±EAR_YAW, без
## перехода через затылок (раньше разность бралась по кругу, и ухо уходило за предел сустава).
const EAR_BASE: Array[Vector3] = [Vector3(0.42, 0.45, 0.75), Vector3(-0.42, 0.45, 0.75)]
const EAR_YAW := 2.3
const EAR_PITCH_MIN := -0.35
const EAR_PITCH_MAX := 1.1
const EAR_TURN := 1.2
const EAR_ACCEL := 2.5
const EAR_GAIN := 4.0
const IDLE_SWEEP := 0.9
const IDLE_PERIOD := 23.0
const IDLE_PITCH := 0.35
## Цель сонара и сканера — тело, размер TARGET_R (js: r 2).
const TARGET_R := 2.0
## Без дна (тесты без ground) лежит на этой высоте.
const FALLBACK_FLOOR := -46.0
## Подделки голосов (js/echo.js): первая через FAKE_FIRST с после того, как корабль подошёл, потом раз в FAKE_CD с;
## просьба ждёт исполнения BAIT_T с; удар на выпрошенный импульс ближе STRIKE_R м — доля прочности STRIKE (−12 %);
## на свет идёт серпохвост не дальше LURE_R м.
const FAKE_FIRST := 12.0
const FAKE_CD := 45.0
const BAIT_T := 10.0
const STRIKE_R := 50.0
const STRIKE := 0.12
const LURE_R := 160.0
## Настоящие доклады экипажа: корабль ближе TALK_R м, первый через REAL_FIRST с, потом раз в REAL_CD с.
const TALK_R := 150.0
const REAL_FIRST := 30.0
const REAL_CD := 75.0
## Просьбы подделки (EcoLink.VOICE "ask").
const ASK_PING := "ping"
const ASK_LIGHT := "light"
## Ложные вызовы: просьба → [роль (Crew.Role), текст].
const FAKES := {
	"light": [0, "Включите прожектор, ничего не видно!"],
	"ping": [1, "Срочно импульс сонара, рядом что-то большое!"],
}
## Настоящие доклады: [роль, текст] — без чисел корабля (мир их не знает).
const REALS: Array = [
	[0, "Курс держим, идём дальше."],
	[2, "Слежу за реактором."],
	[1, "Сонар готов, жду команды."],
	[3, "Записываю всё, что видим."],
]


## Сам эхоловец.
class Lurker:
	extends RefCounted
	## Тело (центр, y — над дном на UP) и курс: yaw = 0 — голова к +Z, растёт — поворот влево (как EcoGrot).
	var p := Vector3.ZERO
	var yaw := 0.0
	## Уши: (поворот от носа, наклон вверх) каждого, рад.
	var ears: Array[Vector2] = [Vector2(0.6, IDLE_PITCH), Vector2(-0.6, IDLE_PITCH)]
	## Скорость суставов ушей (поворот, наклон), рад/с.
	var ear_vel: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
	## Корабль ближе LISTEN_R — слушает его (Ec.near).
	var near := false
	## Сколько ещё раскрыт (с); ≤ 0 — затаился.
	var revealed := 0.0
	## До следующей подделки и настоящего доклада, с (Ec.fakeT, Ec.realT).
	var fake_t := FAKE_FIRST
	var real_t := REAL_FIRST
	## Просьба последней подделки ("" — нет) и сколько ещё ждёт исполнения, с (Ec.bait).
	var bait := ""
	var bait_t := 0.0
	## Ложных вызовов за забег.
	var fakes := 0
	## Ударов по корпусу за забег (выпрошенный импульс; муть — EcoEchoDust).
	var strikes := 0

	func is_revealed() -> bool:
		return revealed > 0.0

	## Тело → мир.
	func xform() -> Transform3D:
		return Transform3D(Basis(Vector3.UP, yaw), p)

	## Основание уха i в мире.
	func ear_base(i: int) -> Vector3:
		return xform() * EAR_BASE[i]


var echo: Lurker

## Серпохвосты: на свет по подделке идёт ближайший (null — хищников нет).
var preds: EcoPred

var _bones: EcoBones
var _ground: Callable
var _t := 0.0
var _rnd: EcoRandom
var _light_was := false


func _init(bones: EcoBones = null, pred: EcoPred = null) -> void:
	_bones = bones
	preds = pred


## Своё зерно (js: свой генератор, не сбивает случайность экосистемы).
static func seed_for(world_seed: int) -> int:
	return (world_seed * 37 + 9) & 0xFFFFFFFF


func reset(world: EcoWorld) -> void:
	_ground = world.ground
	_t = 0.0
	_rnd = EcoWorld.seeded_for(seed_for(world.seed_value))
	_light_was = world.ship.light_on
	echo = Lurker.new()
	var at := lair()
	echo.yaw = heading()
	echo.p = Vector3(at.x, _bed(at, echo.yaw) + UP, at.y)


## Где лежит (x, z): снаружи клетки костей между парами рёбер PAIR и PAIR + 1; без костей — OFFSET от их центра.
func lair() -> Vector2:
	if _bones == null or _bones.rib_z.size() <= PAIR + 1:
		var c := EcoBones.CENTER + OFFSET
		return c
	var f0 := _bones.rib_point(PAIR * 2, 0)
	var f1 := _bones.rib_point((PAIR + 1) * 2, 0)
	var foot_x := (f0.x + f1.x) * 0.5
	var local := Vector3(foot_x + signf(foot_x) * OUT, 0.0, (_bones.rib_z[PAIR] + _bones.rib_z[PAIR + 1]) * 0.5)
	var w := _bones.to_world(local)
	return Vector2(w.x, w.z)


## Курс тела: голова наружу от клетки (поперёк оси костей); без костей — к +Z.
func heading() -> float:
	if _bones == null or _bones.rib_z.size() <= PAIR + 1:
		return 0.0
	var at := lair()
	var out := Vector3(at.x, 0.0, at.y) - _bones.to_world(Vector3(0, 0, _bones.rib_z[PAIR]))
	out.y = 0.0
	out -= _bones.axis() * out.dot(_bones.axis())
	return atan2(out.x, out.z)


func step(world: EcoWorld, dt: float) -> void:
	_t += dt
	var ec := echo
	if ec == null:
		return
	var s := world.ship.pos
	var d := ec.p.distance_to(s)
	ec.near = d < LISTEN_R
	if ec.revealed > 0.0:
		ec.revealed = maxf(0.0, ec.revealed - dt)
	_step_voices(world, d, dt)
	for i in 2:
		var want := aim(i, s) if ec.near else idle(i, _t)
		var e := ec.ears[i]
		var v := ec.ear_vel[i]
		var yaw := ear_joint(e.x, v.x, want.x, dt)
		var pitch := ear_joint(e.y, v.y, want.y, dt)
		ec.ears[i] = Vector2(clampf(yaw.x, -EAR_YAW, EAR_YAW), clampf(pitch.x, EAR_PITCH_MIN, EAR_PITCH_MAX))
		ec.ear_vel[i] = Vector2(yaw.y, pitch.y)


## Шаг сустава уха: угол a со скоростью v догоняет want за dt → (новый угол, новая скорость). Скорость к цели — не
## больше EAR_TURN, EAR_GAIN × отставание и того, с какой можно остановиться вполсилы торможения (√(EAR_ACCEL ·
## отставание) — запас на шаг мира; на стыке с EAR_GAIN торможение ровно EAR_ACCEL); меняется не быстрее EAR_ACCEL.
## Шаг, что перелетел бы цель, кончается в ней.
static func ear_joint(a: float, v: float, want: float, dt: float) -> Vector2:
	var err := want - a
	var reach := minf(EAR_TURN, minf(absf(err) * EAR_GAIN, sqrt(EAR_ACCEL * absf(err))))
	v = move_toward(v, signf(err) * reach, EAR_ACCEL * dt)
	var step := v * dt
	if err != 0.0 and signf(step) == signf(err) and absf(step) > absf(err):
		return Vector2(want, err / dt)
	return Vector2(a + step, v)


## Куда смотрит ухо i, чтобы слушать точку target: поворот от носа и наклон, в пределах суставов.
func aim(i: int, target: Vector3) -> Vector2:
	var d := Basis(Vector3.UP, echo.yaw).inverse() * (target - echo.ear_base(i))
	var yaw := clampf(atan2(d.x, d.z), -EAR_YAW, EAR_YAW)
	var pitch := clampf(atan2(d.y, Vector2(d.x, d.z).length()), EAR_PITCH_MIN, EAR_PITCH_MAX)
	return Vector2(yaw, pitch)


## Покой: уши обводят воду вразнобой (левое смотрит левее, правое — правее).
static func idle(i: int, t: float) -> Vector2:
	var side := 1.0 if i == 0 else -1.0
	var ph := TAU * t / IDLE_PERIOD + i * 2.1
	return Vector2(side * 0.7 + sin(ph) * IDLE_SWEEP, IDLE_PITCH + 0.15 * sin(ph * 1.7))


## Направление уха i в мире (куда открыта воронка).
func ear_dir(i: int) -> Vector3:
	var e := echo.ears[i]
	var local := Vector3(sin(e.x) * cos(e.y), sin(e.y), cos(e.x) * cos(e.y))
	return Basis(Vector3.UP, echo.yaw) * local


## Голоса по связи: свет включили по просьбе, просьба истекла, настоящий доклад, новая подделка.
func _step_voices(world: EcoWorld, d: float, dt: float) -> void:
	var ec := echo
	var light := world.ship.light_on
	if light and not _light_was:
		on_light(world)
	_light_was = light
	if ec.bait != "":
		ec.bait_t -= dt
		if ec.bait_t <= 0.0:   # не послушались — подделка ничего не дала
			ec.bait = ""
			world.emit(ID, "fake", ec.p)
	if d < TALK_R:
		ec.real_t -= dt
		if ec.real_t <= 0.0:
			ec.real_t = REAL_CD
			if ec.bait == "":
				real(world)
	if ec.near and not ec.is_revealed():
		ec.fake_t -= dt
		if ec.fake_t <= 0.0:
			ec.fake_t = FAKE_CD
			fake(world)
	elif not ec.near:
		ec.fake_t = maxf(ec.fake_t, FAKE_FIRST)


## Ложный вызов (Ec.fake): ask — "light" или "ping"; "" — сам выбирает (свет выключен — в половине случаев свет).
## Кода забега у подделки нет: на первом спуске молчит на «Спросить код», дальше — отвечает старым словом.
func fake(world: EcoWorld, ask := "") -> Dictionary:
	var ec := echo
	if ask == "":
		ask = ASK_LIGHT if not world.ship.light_on and _rnd.chance(0.5) else ASK_PING
	var line: Array = FAKES[ask]
	ec.bait = ask
	ec.bait_t = BAIT_T
	ec.fakes += 1
	var e := EcoLink.voice(line[0], line[1], true, ask, world.ship.dive == 0)
	world.send(e)
	return e


## Настоящий доклад экипажа с кодом забега (Ec.real): роль и текст — по очереди случая.
func real(world: EcoWorld) -> Dictionary:
	var line: Array = REALS[_rnd.index(REALS.size())]
	var e := EcoLink.voice(line[0], line[1])
	world.send(e)
	return e


## Свет включили (Ec.onLight): по просьбе подделки — ближайший серпохвост ближе LURE_R (не в броске) идёт на корабль.
func on_light(world: EcoWorld) -> EcoPred.Pred:
	var ec := echo
	if ec == null or ec.bait != ASK_LIGHT:
		return null
	ec.bait = ""
	var best: EcoPred.Pred = null
	if preds:
		var bd := LURE_R
		for pr in preds.all:
			var dd := pr.agent.distance_to(world.ship.pos)
			if pr.agent.alive and pr.mode != EcoPred.Mode.CHARGE and dd < bd:
				bd = dd
				best = pr
	if best:
		preds.lure(world, best)
	world.emit(ID, "lure", ec.p, _lure_text(world))
	return best


## Импульс сонара (Ec.onPing): выпрошенный подделкой ближе STRIKE_R — удар по корпусу; не выпрошенный ближе
## REVEAL_R — раскрыт на REVEAL_T с; наблюдение — только когда раскрылся.
func on_ping(world: EcoWorld, pos: Vector3) -> void:
	var ec := echo
	if ec == null:
		return
	var d := ec.p.distance_to(pos)
	if ec.bait == ASK_PING:
		if d < STRIKE_R:
			ec.bait = ""
			ec.strikes += 1
			world.hit_ship(Species.cap(world.nm(ID)), STRIKE, ec.p)
			world.emit(ID, "strike", ec.p, _strike_text(world))
		return
	if d >= REVEAL_R:
		return
	var was := ec.is_revealed()
	ec.revealed = REVEAL_T
	ec.bait = ""
	if not was:
		world.emit(ID, "reveal", ec.p, _reveal_text(world))


## Затаившегося нет ни на сонаре, ни в прицеле (js: hidden и noSonar, пока не раскрыт).
func targets(_world: EcoWorld, out: Array[Dictionary]) -> void:
	if echo:
		var h := not echo.is_revealed()
		out.append(EcoWorld.target(ID, echo.p, TARGET_R, not h, h))


## Дно под телом на склоне: самое высокое под серединой, головой, хвостом и боками — тело не тонет в склоне.
func _bed(at: Vector2, yaw: float) -> float:
	var b := Basis(Vector3.UP, yaw)
	var y := -INF
	for o: Vector3 in BED:
		var q := b * o
		y = maxf(y, _floor(at.x + q.x, at.y + q.z))
	return y


func _floor(x: float, z: float) -> float:
	return float(_ground.call(x, z)) if _ground.is_valid() else FALLBACK_FLOOR


## «Импульс сонара выдал засадчика с ушами-воронками: он раскрыт» — название в момент показа; мир — слабой ссылкой.
static func _reveal_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var who := w.nm(ID, Species.Case.ACC) if w else Species.called(ID, Species.Case.ACC)
		return "Импульс сонара выдал %s: он раскрыт" % who


## «Эхоловец ударил по корпусу на звук импульса…» и «на свет идёт серпохвост» — названия в момент показа.
static func _strike_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var who := w.nm(ID) if w else Species.called(ID)
		return "%s ударил по корпусу на звук импульса, который сам выпросил" % Species.cap(who)


static func _lure_text(world: EcoWorld) -> Callable:
	var wr: WeakRef = weakref(world)
	return func() -> String:
		var w: EcoWorld = wr.get_ref()
		var p := w.nm(EcoPred.ID) if w else Species.called(EcoPred.ID)
		return "Свет включили по ложному вызову — на него идёт %s" % p
