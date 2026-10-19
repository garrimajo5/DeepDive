class_name Reactor
extends RefCounted
## Реактор «Ковчега-7» (js/power.js, pogrujenie Core/Reactor.cs): 100 единиц энергии, инженер делит их между пятью
## системами (не больше 60 на одну, шаг 5). Доля меняет силу системы: k = доля / базовая доля (1 — как по умолчанию,
## 0 — обесточена). Перегрев: у Чёрного курильщика (тёплая вода плохо охлаждает) или раз в несколько минут реактор
## держит только 60 единиц; лишняя нагрузка греет его, на 100° — аварийный сброс: всё обесточено на 12 с.

enum Sys { ENGINES, SONAR, LIFE, ZAP, LAMP }

const NAMES: Array[String] = ["Двигатели", "Сонар", "Жизнеобеспечение", "Разряд по корпусу", "Прожектор"]
const HINTS: Array[String] = ["тяга", "дальность импульса", "ремонт корпуса", "радиус разряда", "дальность луча"]
const DEFAULTS: Array[int] = [30, 20, 25, 15, 10]
const TOTAL := 100
const MAX := 60
const STEP := 5
const SAFE := 60
const SCRAM_TIME := 12.0
const HEAT_UP := 0.12      ## ° в секунду на единицу сверх SAFE
const COOL := 0.25
const MIN_HOT_TIME := 20.0
const PERIOD := 420.0      ## перегрев раз в 7 минут
const FIRST_HOT := 240.0   ## первый — через 4 минуты
const VENT_COOLDOWN := 90.0
## Чёрный курильщик (ART-012, docs/concept-art/kurilshchik.md): ближе VENT_R — перегрев.
const VENT_POS := Vector2(-126.0, 45.0)
const VENT_R := 45.0

var share: Array[int] = DEFAULTS.duplicate()
var hot := false
var heat := 0.0
var hot_time := 0.0
var scram := 0.0
var next_hot := FIRST_HOT
var vent_cd := 0.0

## Сообщение для приборов: заголовок и пояснение.
signal message(title: String, text: String)


func reset() -> void:
	share = DEFAULTS.duplicate()
	hot = false
	heat = 0.0
	hot_time = 0.0
	scram = 0.0
	next_hot = FIRST_HOT
	vent_cd = 0.0


func used() -> int:
	var a := 0
	for v in share:
		a += v
	return a


func free_units() -> int:
	return TOTAL - used()


## Сколько единиц сейчас безопасно: 60 при перегреве, иначе 100.
func limit() -> int:
	return SAFE if hot else TOTAL


## Множитель системы относительно базовой доли; при аварийном сбросе 0.
func k(s: int) -> float:
	return 0.0 if scram > 0.0 else float(share[s]) / DEFAULTS[s]


## Поставить долю: округлить до шага 5, не больше 60 и не больше свободных единиц.
func set_share(s: int, value: int) -> int:
	var others := used() - share[s]
	var rounded := int(floor(value / float(STEP) + 0.5)) * STEP
	share[s] = maxi(0, mini(mini(MAX, rounded), TOTAL - others))
	return share[s]


func add(s: int, delta: int) -> int:
	return set_share(s, share[s] + delta)


func start_hot(vent: bool) -> bool:
	if hot:
		return false
	hot = true
	hot_time = 0.0
	heat = maxf(heat, 20.0)
	message.emit("Перегрев реактора", ("Тёплая вода у курильщика не охлаждает реактор. " if vent else "")
		+ "Безопасно только %d единиц — урежьте нагрузку на пульте энергии." % SAFE)
	return true


static func near_vent(x: float, z: float) -> bool:
	return Vector2(x, z).distance_to(VENT_POS) < VENT_R


func update(dt: float, at_vent: bool) -> void:
	vent_cd -= dt
	if scram > 0.0:
		scram -= dt
		if scram <= 0.0:
			scram = 0.0
			heat = 50.0
			message.emit("Реактор перезапущен", "Системы снова под напряжением.")
	if not hot:
		next_hot -= dt
		if at_vent and vent_cd <= 0.0:
			vent_cd = VENT_COOLDOWN
			start_hot(true)
		elif next_hot <= 0.0:
			start_hot(false)
		if not hot:
			heat = maxf(0.0, heat - dt * 2.0)
		return
	hot_time += dt
	var over := used() - SAFE
	if scram <= 0.0:
		heat = clampf(heat + (over * HEAT_UP if over > 0 else (over - 5) * COOL) * dt, 0.0, 100.0)
	if heat >= 100.0 and scram <= 0.0:
		scram = SCRAM_TIME
		message.emit("Аварийный сброс реактора", "Все системы обесточены на %d секунд." % int(SCRAM_TIME))
	if heat <= 0.0 and hot_time > MIN_HOT_TIME:
		hot = false
		next_hot = PERIOD
		message.emit("Реактор остыл", "Можно снова раздать все 100 единиц.")


## Табло тревоги: пусто, если всё спокойно.
func alert() -> String:
	if scram > 0.0:
		return "АВАРИЙНЫЙ СБРОС · %d с" % ceili(scram)
	if hot:
		return "ПЕРЕГРЕВ %d° · НАГРУЗКА %d/%d" % [roundi(heat), used(), SAFE]
	return ""


## Пульт энергии: выбор системы крестовиной вверх-вниз, влево-вправо — снять или добавить 5 единиц.
## Нажатие срабатывает сразу и повторяется, пока крестовину держат (через 0,4 с, потом каждые 0,18 с).
class Console:
	var sel := 0
	var _held := Vector2i.ZERO
	var _rep := 0.0

	## Крестовина: m.y = 1 — вверх. Возвращает изменение доли (для звука и проверки) или 0.
	func nav(r: Reactor, m: Vector2i, dt: float) -> int:
		var dir := Vector2i.ZERO
		if m.y != 0:
			dir = Vector2i(0, m.y)
		elif m.x != 0:
			dir = Vector2i(m.x, 0)
		if dir == Vector2i.ZERO:
			_held = Vector2i.ZERO
			return 0
		if dir == _held:
			_rep -= dt
			if _rep > 0.0:
				return 0
			_rep = 0.18
		else:
			_held = dir
			_rep = 0.4
		if dir.y == 1:
			sel = (sel + Sys.size() - 1) % Sys.size()
		elif dir.y == -1:
			sel = (sel + 1) % Sys.size()
		else:
			var before := r.share[sel]
			return r.add(sel, STEP * dir.x) - before
		return 0
