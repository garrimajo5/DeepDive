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
const MAP_SIZE := 700.0
const MAP_N := 256

var ping_time := -99.0
var range_m := BASE_RANGE
var blips: Array[Dictionary] = []   ## {"pos": Vector3, "species": String, "color": Color}


static func range_for(k: float) -> float:
	return BASE_RANGE * k


func can_ping(t: float) -> bool:
	return t - ping_time >= COOLDOWN


## Импульс в момент t при силе сонара k. Возвращает текст для приборов.
func ping(t: float, k: float) -> String:
	if k <= 0.0:
		return "Сонар обесточен"
	if not can_ping(t):
		return ""
	ping_time = t
	range_m = range_for(k)
	blips.clear()
	return "Сонар: импульс"


## Отметки из событий живого мира: только NEAR ближе дальности, не больше MAX_BLIPS (ближние первыми).
func take_contacts(events: Array, ship_pos: Vector3) -> void:
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


## Насколько видны отметки: 1 сразу после импульса, к 12 с — 0.
func blip_alpha(t: float) -> float:
	return maxf(0.0, 1.0 - (t - ping_time) / BLIP_TIME)


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


## Карта рельефа для голограммы (js/sonar.js So.init): глубже — темнее, изолинии через 6 м.
static func bathymetry(n: int = MAP_N) -> Image:
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	for j in n:
		for i in n:
			var wx := -MAP_SIZE / 2.0 + (i + 0.5) / n * MAP_SIZE
			var wz := -MAP_SIZE / 2.0 + (j + 0.5) / n * MAP_SIZE
			var h := Seabed.height(wx, wz)
			var t := clampf((h + 110.0) / 104.0, 0.0, 1.0)
			var line := 1.0 if fposmod(h, 6.0) < 0.9 else 0.0
			img.set_pixel(i, j, Color8(int(6 + 28 * t + line * 35), int(38 + 150 * t + line * 60), int(48 + 110 * t + line * 50)))
	return img
