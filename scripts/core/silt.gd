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
## В облаке: луч прожектора × (1 − 0,55·k), муть воды — к тёмному илу.
const BEAM_K := 0.45
## Палитра ила по ART-048 (`sonarnaya-tma.md`): серо-зелёный, не бурый и не белый; хлопья не светятся.
const COLOR := Color("#45584F")       ## тёмный ил
const FLAKE_COLOR := Color("#728479") ## средние хлопья
const EDGE_COLOR := Color("#A0AEA0")  ## края хлопьев в луче
const FAR_COLOR := Color("#55665D")   ## дальняя взвесь: к ней мутнеет вода (OceanView.apply_water)
## Карточка хлопьев (SiltView.FLAKE, м) и пятна в её маске: поперечник 0,10–0,40 м, рваные края.
const CARD := 1.6
const SPOTS := 9
const SPOT_MIN := 0.10
const SPOT_MAX := 0.40
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


## Пятна в маске карточки (ART-048): {"c": Vector2 центр в долях карточки 0…1, "d": поперечник, м, "far": дальняя
## взвесь — темнее, "seed"}. Детерминированно; пятна не вылезают за край карточки.
static func flake_spots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in SPOTS:
		var h1 := _hash(i * 3.1 + 0.7)
		var h2 := _hash(i * 7.7 + 1.3)
		var h3 := _hash(i * 5.3 + 2.9)
		var d := lerpf(SPOT_MIN, SPOT_MAX, pow(h3, 1.6))   # мелких больше
		var m := (d * 0.5 * 1.45) / CARD + 0.02            # поля с запасом на рваный край
		out.append({"c": Vector2(lerpf(m, 1.0 - m, h1), lerpf(m, 1.0 - m, h2)), "d": d, "far": i % 3 == 2, "seed": i})
	return out


## Маска карточки n×n: рваные пятна (край — неровный радиус и дыры от шума), середина — средний тон, кромка — светлее
## (края в луче), дальние пятна — тусклее. Альфа — сама маска, вне пятен прозрачно.
static func flake_image(n: int = 128) -> Image:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(FLAKE_COLOR, 0.0))
	for sp in flake_spots():
		var c: Vector2 = sp["c"] * n
		var rad: float = sp["d"] * 0.5 / CARD * n
		var sd: float = sp["seed"]
		var base: Color = FAR_COLOR if sp["far"] else FLAKE_COLOR
		var reach := int(ceilf(rad * 1.5)) + 1
		for y in range(maxi(0, int(c.y) - reach), mini(n, int(c.y) + reach + 1)):
			for x in range(maxi(0, int(c.x) - reach), mini(n, int(c.x) + reach + 1)):
				var v := Vector2(x + 0.5, y + 0.5) - c
				var th := atan2(v.y, v.x)
				var edge := rad * (1.0 + 0.3 * sin(th * 3.0 + sd * 1.7) + 0.18 * sin(th * 5.0 + sd * 2.3)
						+ 0.1 * sin(th * 9.0 + sd))
				var q := v.length() / maxf(edge, 0.5)
				if q >= 1.0:
					continue
				var hole := HashNoise.fbm(x * 0.21 + sd * 13.0, y * 0.21 - sd * 7.0, 3)
				var a := (1.0 - smoothstep(0.7, 1.0, q)) * smoothstep(0.3, 0.55, hole + 0.25 * (1.0 - q))
				if a <= 0.0:
					continue
				var col := base.lerp(EDGE_COLOR, 0.0 if sp["far"] else smoothstep(0.55, 0.95, q) * 0.8)
				var old := img.get_pixel(x, y)
				if a > old.a:
					img.set_pixel(x, y, Color(col, a))
	return img


static func _hash(v: float) -> float:
	var u := sin(v * 12.9898) * 43758.5453
	return u - floorf(u)
