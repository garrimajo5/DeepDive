class_name Vitals
extends RefCounted
## Корпус и энергия корабля (js/ship.js, js/game.js): прочность корпуса 0…100 % и заряд 0…100 единиц.
## Заряд копится 1,1 ед./с и тратится на ход (0,35 × тяга), всплытие и погружение (0,15), прожектор (0,22),
## присосавшихся существ (EcoLink.DRAIN), импульс сонара (6) и разряд (15). Корпус бьют существа (EcoLink.HIT)
## и дно (на скорости больше 2,4 м/с); жизнеобеспечение чинит его 0,15 %/с × доля «Жизнеобеспечение».
## На 0 % корпус разрушен — забег проигран.

const MAX := 100.0
const REGEN := 1.1
const DRAIN_THRUST := 0.35
const DRAIN_VERT := 0.15
const DRAIN_LIGHT := 0.22
const REPAIR := 0.15
const SONAR_COST := 6.0
const ZAP_COST := 15.0
const SCRAPE_SPEED := 2.4
const SCRAPE_LIFT := 1.5     ## дно поднимает корабль быстрее 1,5 м/с (крутой склон на ходу, нырок в дно) — удар
const HIT_COOLDOWN := 1.2
const LOW_ENERGY := 15.0
const LOW_HULL := 25.0
const DRAIN_HOLD := 0.5      ## тревога о присоске держится столько секунд после последнего EcoLink.DRAIN
## Мигание света, пока на корпусе присоска или после разряда (js/ship.js: каждый кадр с вероятностью 0,25 свет × 0,15).
## Здесь — ровными долями по 1/6 с и детерминированно (хеш доли): не чаще 3 вспышек в секунду, без случайности в тестах.
const FLICKER_HZ := 6.0
const FLICKER_DIM := 0.15
const FLICKER_CHANCE := 0.25

var hull := MAX
var energy := MAX
var hit_cd := 0.0
var shake := 0.0       ## тряска камеры после удара, с
var flash := 0.0       ## красная вспышка экрана после удара, 0…1
var drain_ext := 0.0   ## внешний расход в этот шаг (присоски), ед./с
var drain_by := ""     ## кто последним тянул заряд («Стеклоуст»)
var drain_left := 0.0  ## сколько ещё держать тревогу о присоске, с
var hiss_left := 0.0   ## до следующего шипения тревоги присоски, с (Vitals.hiss)

signal hit_taken(percent: int, kind: String)
signal destroyed


func reset() -> void:
	hull = MAX
	energy = MAX
	hit_cd = 0.0
	shake = 0.0
	flash = 0.0
	drain_ext = 0.0
	drain_by = ""
	drain_left = 0.0
	hiss_left = 0.0


func lost() -> bool:
	return hull <= 0.0


## Шаг: заряд, ремонт, затухание тряски. thrust, vert — ввод пилота; light — прожектор горит; k_life — доля жизнеобеспечения.
## Возвращает true, если заряда не хватило на прожектор (его надо погасить).
func update(dt: float, thrust: float, vert: float, light: bool, k_life: float) -> bool:
	var drain := absf(thrust) * DRAIN_THRUST + absf(vert) * DRAIN_VERT + (DRAIN_LIGHT if light else 0.0) + drain_ext
	energy = clampf(energy + (REGEN - drain) * dt, 0.0, MAX)
	drain_ext = 0.0
	drain_left = maxf(0.0, drain_left - dt)
	if hull > 0.0 and hull < MAX:
		hull = minf(MAX, hull + dt * REPAIR * k_life)
	hit_cd -= dt
	shake = maxf(0.0, shake - dt)
	flash = maxf(0.0, flash - dt * 2.0)
	return light and energy <= 0.5


## Удар по корпусу на percent %. kind: "bite", "scrape", … Возвращает, засчитан ли.
func hit(percent: int, kind: String) -> bool:
	if hull <= 0.0 or percent <= 0:
		return false
	hull = maxf(0.0, hull - percent)
	shake = 0.6
	flash = 1.0
	hit_taken.emit(percent, kind)
	if hull <= 0.0:
		destroyed.emit()
	return true


## Дно: если оно поднимает корабль со скоростью lift м/с при ходе speed — удар (скорость × 1,4 %),
## корабль отскакивает. Возвращает новую скорость.
func scrape(lift: float, speed: float) -> float:
	if lift > SCRAPE_LIFT and absf(speed) > SCRAPE_SPEED and hit_cd <= 0.0:
		hit_cd = HIT_COOLDOWN
		hit(roundi(absf(speed) * 1.4), "scrape")
		return speed * -0.25
	return speed


## Существо тянет заряд (EcoLink.DRAIN): units ед./с уйдут в следующем шаге, тревога держится DRAIN_HOLD с.
func drain(by: String, units: float) -> void:
	if units <= 0.0:
		return
	drain_ext += units
	drain_by = by
	drain_left = DRAIN_HOLD


## Тревога для приборов, пока на корпусе присоска (js/game.js: «Стеклоуст на корпусе пьёт энергию…»); пусто — нет.
func drain_alarm() -> String:
	if drain_left <= 0.0:
		return ""
	return "%s на корпусе пьёт энергию. Разряд — рычаг у левого борта" % (drain_by if drain_by != "" else "Существо")


## Шипение тревоги присоски (A.alarmCue('latch') раз в Synth.LATCH_PERIOD): true — в этот шаг запустить звук.
## Первое — сразу, как тревога загорелась; погасла — отсчёт с начала.
func hiss(dt: float) -> bool:
	if drain_left <= 0.0:
		hiss_left = 0.0
		return false
	hiss_left -= dt
	if hiss_left > 0.0:
		return false
	hiss_left = maxf(hiss_left + Synth.LATCH_PERIOD, 0.0)
	return true


## Множитель плафонов и прожектора в момент time: 1 — ровный свет, FLICKER_DIM — провал.
## Мигает, пока на корпусе присоска (drain_left) или extra (разряд, Zap.flicker).
func lamp_k(time: float, extra: bool = false) -> float:
	if drain_left <= 0.0 and not extra:
		return 1.0
	return flicker_k(time)


## Мигание без условий: доля времени floor(time × FLICKER_HZ) тёмная с вероятностью FLICKER_CHANCE.
static func flicker_k(time: float) -> float:
	return FLICKER_DIM if HashNoise.hash2(floori(time * FLICKER_HZ), 487) < FLICKER_CHANCE else 1.0


## Помехи вторичных экранов, пока стеклоуст на корпусе (ART-025, `tablo-trevog.md`): у каждого экрана свой период
## 0,8…1,4 с и своя фаза — провалы несинхронные; провал JAM_DROP с, яркость экрана JAM_DIM. Табло тревог, строка
## состояния (курс) и шкала готовности разряда не гаснут — их сюда не подключаем.
enum Screen { HELM_L, HELM_C, HELM_R, SCANNER, JOURNAL }
const JAM_MIN := 0.8
const JAM_MAX := 1.4
const JAM_DROP := 0.15
const JAM_DIM := 0.08


## Период провалов экрана i, с.
static func jam_period(i: int) -> float:
	return lerpf(JAM_MIN, JAM_MAX, HashNoise.hash2(i, 911))


## Яркость экрана i в момент time при помехах: JAM_DIM в первые JAM_DROP с каждого своего периода, иначе 1.
static func jam_k(time: float, i: int) -> float:
	var p := jam_period(i)
	var u := time / p + HashNoise.hash2(i, 377)
	return JAM_DIM if (u - floorf(u)) * p < JAM_DROP else 1.0


## Яркость экрана i: помехи только пока присоска на корпусе (drain_left), иначе 1.
func screen_k(time: float, i: int) -> float:
	return jam_k(time, i) if drain_left > 0.0 else 1.0


## Потратить заряд; false — не хватает.
func spend(units: float) -> bool:
	if energy < units:
		return false
	energy -= units
	return true


## Предупреждение для приборов: пусто, если всё в порядке.
func warning() -> String:
	if hull < LOW_HULL:
		return "Корпус повреждён"
	if energy < LOW_ENERGY:
		return "Мало энергии: сбавьте ход и погасите прожектор"
	return ""
