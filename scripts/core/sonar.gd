class_name Sonar
extends RefCounted
## Сонар на голостоле (js/sonar.js): карта рельефа вокруг корабля, импульс по кнопке показывает существ на 12 с.
## Дальность импульса — 110 м × сила доли «Сонар» реактора. Существ сообщает живой мир (поток Б): в шаг с
## ShipState.sonar_ping он шлёт EcoLink.NEAR для каждого заметного существа ближе sonar_range.

const BASE_RANGE := 110.0
const BLIP_TIME := 12.0      ## сколько секунд видны отметки
const WAVE_TIME := 2.5       ## сколько секунд идёт волна импульса
const COOLDOWN := 3.0        ## между импульсами
const MAX_BLIPS := 32        ## столько отметок держит голограмма
## Карта рельефа: квадрат 700 м с центром в 0 (как Seabed), N×N точек.
## Карта рельефа, м мира: отмель 700 × 700 м и склон к месту 10 за восточным краем (`Seabed.EAST`, #829).
const MAP_RECT := Rect2(-350.0, -350.0, 1050.0, 700.0)
const MAP_N := 256             ## точек карты по z (по x — в MAP_RECT.size.x / size.y раз больше)

var ping_time := -99.0
var blip_time := -99.0  ## когда сняты нынешние отметки (завязший импульс их не обновляет)
var range_m := BASE_RANGE
var blips: Array[Dictionary] = []   ## {"pos": Vector3, "species": String, "color": Color}
var jammed := false  ## импульс завяз в иле (Silt): отметок нет до следующего импульса
var count := 0       ## импульсов за игру: гость сети по нему узнаёт новый импульс хоста (NetSnap.sonar)


static func range_for(k: float) -> float:
	return BASE_RANGE * k


func can_ping(t: float) -> bool:
	return t - ping_time >= COOLDOWN


## Импульс в момент t при силе сонара k. Возвращает текст для приборов.
## jam — корабль в иле (Silt, ART-048): импульс вязнет — новых отметок нет, старые гаснут, как гасли (не прыгают).
func ping(t: float, k: float, jam: bool = false) -> String:
	if k <= 0.0:
		return "Сонар обесточен"
	if not can_ping(t):
		return ""
	ping_time = t
	count += 1
	jammed = jam
	if jam:
		return "Сонар: импульс"
	range_m = range_for(k)
	blip_time = t
	blips.clear()
	return "Сонар: импульс"


## Отметки из событий живого мира: только NEAR ближе дальности, не больше MAX_BLIPS (ближние первыми).
func take_contacts(events: Array, ship_pos: Vector3) -> void:
	if jammed:
		return
	var found: Array[Dictionary] = []
	for e in events:
		if e.get("type", "") != EcoLink.NEAR or not e.has("pos") or not bool(e.get("sonar", true)):
			continue   # цели только для сканера (issue #85) сонар не видит
		var p: Vector3 = e["pos"]
		if Vector2(p.x - ship_pos.x, p.z - ship_pos.z).length() > range_m:
			continue
		found.append({"pos": p, "species": str(e.get("species", "")), "color": color_of(str(e.get("species", "")))})
	found.sort_custom(func(a, b): return a["pos"].distance_squared_to(ship_pos) < b["pos"].distance_squared_to(ship_pos))
	blips.append_array(found.slice(0, MAX_BLIPS - blips.size()))


## Насколько видны отметки: 1 сразу после импульса, к 12 с — 0 (считается от импульса, который их снял).
func blip_alpha(t: float) -> float:
	return maxf(0.0, 1.0 - (t - blip_time) / BLIP_TIME)


## Цвет отметки по виду, как в js/sonar.js: хищники и паразиты — красные, остальные — по своим цветам, прочие — жёлтые.
static func color_of(species: String) -> Color:
	var c := {
		"pred": "ff5d6c", "eel": "ff5d6c", "leech": "ff5d6c", "serpohvost": "ff5d6c", "stekloust": "ff5d6c",
		"ognevka": "ff8c3c", "hvaten": "ce82ff", "krab": "ffaa5a", "ezh": "8cdcff", "raduzh": "c8ffaa",
		"plankton": "78ffe6", "monet": "ffe68c", "grot": "e6c896", "skalnik": "ff785a", "prisoska": "c8dce6",
		"kamen": "ff96aa", "organ": "d2aa82", "cushion": "f096c8", "bladder": "96ffa0", "fan": "ffb48c",
		"fern": "78dc8c", "echo": "ff783c", "veil": "ff8ae0", "ray": "bff6ff",
	}
	return Color(c.get(species, "ffd26b"))


## Карта рельефа для голограммы (js/sonar.js So.init) на всю `MAP_RECT`: n точек по z, по x — пропорционально.
## Глубже — темнее, изолинии через 6 м; на склоне ниже 110 м (#822) — через 30 м, частые слились бы в заливку.
static func bathymetry(n: int = MAP_N) -> Image:
	var nx := map_width(n)
	var img := Image.create(nx, n, false, Image.FORMAT_RGB8)
	for j in n:
		for i in nx:
			var wx := MAP_RECT.position.x + (i + 0.5) / nx * MAP_RECT.size.x
			var wz := MAP_RECT.position.y + (j + 0.5) / n * MAP_RECT.size.y
			var h := Seabed.height(wx, wz)
			var t := clampf((h + 110.0) / 104.0, 0.0, 1.0)
			var line := 0.0
			if h > -110.0:
				line = 1.0 if fposmod(h, 6.0) < 0.9 else 0.0
			else:
				line = 0.7 if fposmod(h, 30.0) < 2.0 else 0.0
			img.set_pixel(i, j, Color8(int(6 + 28 * t + line * 35), int(38 + 150 * t + line * 60), int(48 + 110 * t + line * 50)))
	return img


## Ширина карты рельефа в точках при n точках по z.
static func map_width(n: int = MAP_N) -> int:
	return roundi(n * MAP_RECT.size.x / MAP_RECT.size.y)
