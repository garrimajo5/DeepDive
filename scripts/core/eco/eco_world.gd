class_name EcoWorld
extends RefCounted
## Живой мир отмели без узлов (Unity `Core/EcoWorld.cs`): случай по зерну, шина событий, существа и модули видов.
## Шаг делится на подшаги не длиннее 0,05 с, модули идут в порядке добавления, поэтому при одном зерне и одном вводе
## мир повторяется точь-в-точь — на этом стоят тесты. Сцена (EcoView) только рисует существ по agents и отдаёт
## кораблю события take_link() (EcoLink).

const MAX_STEP := 0.05
## Радиус разряда, если корабль его не сообщил (м): 20 при полной доле реактора, как Zap.BASE_RADIUS.
const ZAP_RADIUS := 20.0

var seed_value: int
var random: EcoRandom
var bus := EcoBus.new()
var agents: Array[EcoAgent] = []
var systems: Array[EcoSystem] = []
## Корабль в этот шаг (даёт EcoView из Main). Мир его не меняет.
var ship := EcoLink.ShipState.new()
## Время мира последнего импульса сонара (E.lastPing); −99 — не было.
var last_ping := -99.0
## Высота дна в (x, z) — Seabed.height; пустой — дна нет.
var ground: Callable
## Просканирован ли вид: (species: String) -> bool, для названий в сообщениях (nm); пустой — ничего не просканировано.
var scanned: Callable
## Секунды с последнего сброса.
var time := 0.0
## Сколько подшагов сделано с последнего сброса.
var steps := 0
## Сколько ударов по корпусу с последнего сброса и последний удар (событие EcoLink.HIT; {} — не было).
var hits := 0
var last_hit: Dictionary = {}

var _link: Array[Dictionary] = []


func _init(world_seed: int = EcoRandom.WORLD_SEED) -> void:
	seed_value = world_seed
	random = EcoRandom.new(world_seed)


## Своё зерно для вида (G.seed(7031)): новый вид не перетасовывает остальной мир.
static func seeded_for(s: int) -> EcoRandom:
	return EcoRandom.new(s)


## Подключить модуль: он сразу расставляет своих существ.
func add(system: EcoSystem) -> EcoSystem:
	systems.append(system)
	system.reset(self)
	return system


## Сбросить мир: случай с начала (то же или новое зерно), существа заново, очереди событий пусты.
func reset(world_seed: int = -1) -> void:
	if world_seed >= 0:
		seed_value = world_seed
	random = EcoRandom.new(seed_value)
	bus.clear()
	_link.clear()
	agents.clear()
	time = 0.0
	steps = 0
	hits = 0
	last_hit = {}
	last_ping = -99.0
	for s in systems:
		s.reset(self)


## Шаг мира на dt секунд, дробится на подшаги ≤ MAX_STEP. Импульс сонара и разряд корабля модули узнают в начале
## шага (on_ping, on_zap) — один раз, сколько бы ни было подшагов.
func step(dt: float) -> void:
	if dt <= 0.0:
		return
	if ship.sonar_ping:
		last_ping = time
		for s in systems:
			s.on_ping(self, ship.pos)
	if ship.zap:
		var r := ship.zap_radius if ship.zap_radius > 0.0 else ZAP_RADIUS
		for s in systems:
			s.on_zap(self, r)
	var n := maxi(1, int(ceil(dt / MAX_STEP - 1e-4)))
	var h := dt / n
	for i in n:
		time += h
		steps += 1
		for a in agents:
			a.tick(h)
		for s in systems:
			s.step(self, h)


## Прогнать мир seconds секунд шагами dt (для тестов).
func run(seconds: float, dt: float = MAX_STEP) -> void:
	for i in int(round(seconds / dt)):
		step(dt)


## Новое существо в мире; null — нет такого вида в реестре.
func spawn(species: String, pos: Vector3) -> EcoAgent:
	if not Species.has(species):
		push_warning("EcoWorld: нет вида «%s»" % species)
		return null
	var a := EcoAgent.new(species, pos)
	agents.append(a)
	return a


func count(species: String, alive_only: bool = true) -> int:
	var c := 0
	for a in agents:
		if a.species == species and (not alive_only or a.alive):
			c += 1
	return c


## Ближайшее живое существо вида не дальше max_dist (null — нет такого). filter: (EcoAgent) -> bool.
func nearest(species: String, pos: Vector3, max_dist: float = INF, filter: Callable = Callable()) -> EcoAgent:
	var best: EcoAgent = null
	var bd := max_dist
	for a in agents:
		if not a.alive or a.species != species or (filter.is_valid() and not filter.call(a)):
			continue
		var d := a.p.distance_to(pos)
		if d <= bd:
			bd = d
			best = a
	return best


## Название вида для сообщений (G.nm): настоящее, если вид просканирован (scanned), иначе описательное.
func nm(species: String, c: Species.Case = Species.Case.NOM) -> String:
	return Species.called(species, c, scanned.is_valid() and bool(scanned.call(species)))


## Отправить событие экосистемы (E.emit); null — нет такого вида.
func emit(species: String, note: String, pos: Vector3, message: Callable = Callable()) -> EcoBus.Event:
	return bus.emit(species, note, pos, message)


## Существо ударило по корпусу (Game.hullHit): мир только сообщает кораблю, урон — доля прочности 0…1.
func hit_ship(by: String, damage: float, at: Vector3) -> void:
	hits += 1
	last_hit = EcoLink.hit(by, damage, at)
	_link.append(last_hit)


## Любое другое событие для корабля (EcoLink.near, DRAIN, …).
func send(event: Dictionary) -> void:
	_link.append(event)


## Забрать события для корабля: прямые (удар, энергия, рядом) и тексты событий шины, которые экипаж слышит
## (не дальше EcoBus.HEARING от корабля) — как EcoLink.MESSAGE. Очереди очищаются.
func take_link() -> Array[Dictionary]:
	var out := _link.duplicate()
	_link.clear()
	for ev in bus.take_near(ship.pos):
		var t := ev.text()
		if t != "":
			out.append(EcoLink.message(t))
	return out
