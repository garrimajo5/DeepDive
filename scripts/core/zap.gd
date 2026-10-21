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
