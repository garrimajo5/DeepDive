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
const POST_AT := Vector2(-3.9, -0.5)

var last := -99.0
var radius := BASE_RADIUS
var flicker := 0.0


static func radius_for(k: float) -> float:
	return BASE_RADIUS * k


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


func update(dt: float) -> void:
	flicker = maxf(0.0, flicker - dt)
