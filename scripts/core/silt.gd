class_name Silt
extends RefCounted
## Событие «сонарная тьма» (js/silt.js): облако ила поднимается, когда корабль чиркает по дну, а у Края отмели раз
## в 5 минут сходит оползень. Облако дрейфует по течению и оседает. Внутри него импульс сонара вязнет в иле (на
## голостоле помехи), вода мутнеет, луч прожектора рассеивается (короче в 0,45 раза — и существа видят свет корабля
## только вблизи: `ShipState.light_range`).

const MAX_CLOUDS := 3
const SCRAPE_R := 16.0
const SCRAPE_LIFE := 45.0
const SLIDE_R := 30.0
const SLIDE_LIFE := 80.0
const SLIDE_PERIOD := 300.0
const SLIDE_FIRST := 150.0
## Край отмели (js/world.js, POI «drop»): там сходят оползни; облако — на 10 м над дном, не глубже 55 м.
const DROP := Vector2(215.0, 90.0)
## Облако несёт течением в 1,3 раза быстрее воды и опускает на 5 см/с.
const DRIFT := 1.3
const SINK := 0.05
## В облаке: луч прожектора × (1 − 0,55·k), муть воды — к бурому цвету ила.
const BEAM_K := 0.45
const COLOR := Color(0.42, 0.35, 0.27)
## Помехи на голостоле после импульса в иле, с.
const JAM_TIME := 4.0
const ALARM := "СОНАРНАЯ ТЬМА · ОБЛАКО ИЛА"
const ENTER_MSG := "Сонарная тьма: корабль в облаке ила — сонар не пробивает муть, свет рассеивается"
const SLIDE_MSG := "У Края отмели сошёл оползень: облако ила идёт по течению"
const JAM_MSG := "Сонар ослеп: импульс вязнет в иле. Выйдите из мути"


class Cloud:
	extends RefCounted
	var c := Vector3.ZERO
	var r := 0.0
	var life := 0.0
	var max_life := 0.0
	var why := ""

	## Плотность 0…1: густеет за первые полсекунды, оседает последние 8 с.
	func density() -> float:
		return minf(1.0, life / 8.0) * minf(1.0, (max_life - life) * 2.0 + 0.3)

	## Радиус частиц: облако разрастается от половины до полного за 2 с.
	func spread() -> float:
		return r * (0.5 + 0.5 * minf(1.0, (max_life - life) * 0.5))


var clouds: Array[Cloud] = []
var inside: Cloud = null
var k := 0.0  ## насколько корабль в иле, плавно 0…1 (муть, помехи)
var slide_t := SLIDE_FIRST
var jam_t := -99.0  ## когда импульс завяз в иле


func reset() -> void:
	clouds.clear()
	inside = null
	k = 0.0
	slide_t = SLIDE_FIRST
	jam_t = -99.0


func spawn(pos: Vector3, r: float, life: float, why: String) -> Cloud:
	if clouds.size() >= MAX_CLOUDS:
		clouds.pop_front()
	var cl := Cloud.new()
	cl.c = pos
	cl.r = r
	cl.life = life
	cl.max_life = life
	cl.why = why
	clouds.append(cl)
	return cl


## Корабль чиркнул по дну в точке center (ground — высота дна под ним): та же туча густеет снова или поднимается новая.
func on_scrape(center: Vector3, ground: float) -> void:
	for cl in clouds:
		if cl.c.distance_to(center) < cl.r * 0.6:
			cl.life = maxf(cl.life, SCRAPE_LIFE)
			return
	spawn(Vector3(center.x, maxf(center.y - 2.0, ground + 3.0), center.z), SCRAPE_R, SCRAPE_LIFE, "scrape")


## Облако вокруг точки p (только плотное).
func at(p: Vector3) -> Cloud:
	for cl in clouds:
		if p.distance_to(cl.c) < cl.r and cl.density() > 0.4:
			return cl
	return null


## Шаг: оползни, дрейф по течению current, оседание; ship — центр корабля. Возвращает сообщение для приборов.
func update(dt: float, ship: Vector3, current: Vector3) -> String:
	var msg := ""
	slide_t -= dt
	if slide_t <= 0.0:
		slide_t = SLIDE_PERIOD
		var g := Seabed.height(DROP.x, DROP.y)
		spawn(Vector3(DROP.x, maxf(g + 10.0, -55.0), DROP.y), SLIDE_R, SLIDE_LIFE, "slide")
		msg = SLIDE_MSG
	for i in range(clouds.size() - 1, -1, -1):
		var cl := clouds[i]
		cl.life -= dt
		if cl.life <= 0.0:
			clouds.remove_at(i)
			continue
		cl.c += current * (dt * DRIFT)
		cl.c.y -= dt * SINK
	var was := inside
	inside = at(ship)
	k += ((1.0 if inside else 0.0) - k) * minf(1.0, dt * 1.5)
	if inside and not was:
		msg = ENTER_MSG
	return msg


## Импульс сонара в момент t: в иле он вязнет (true) — отметок нет, на голостоле помехи.
func jam_ping(t: float) -> bool:
	if inside == null:
		return false
	jam_t = t
	return true


## Помехи на голостоле 0…1: пока корабль в иле и ещё JAM_TIME с после завязшего импульса.
func noise(t: float) -> float:
	return maxf(k if k > 0.05 else 0.0, 1.0 if t - jam_t < JAM_TIME else 0.0)


## Во сколько раз короче луч прожектора.
func beam_k() -> float:
	return 1.0 - (1.0 - BEAM_K) * k


## Строка табло тревог (пустая — тревоги нет).
func alarm() -> String:
	return ALARM if inside else ""


## Самое плотное облако — для прозрачности частиц.
func max_density() -> float:
	var m := 0.0
	for cl in clouds:
		m = maxf(m, cl.density())
	return m
