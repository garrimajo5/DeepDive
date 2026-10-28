class_name SaveGame
extends RefCounted
## Сохранение экспедиции в user:// (как js/save.js): груз трюма, номера поднятых со дна образцов, изученные виды.
## Формат файла — JSON, совместимый с браузерным: {"v": 1, "cargo": [{"kind": "moss", "i": 3}, …], "got": [3, …],
## "species": {"fish": {"scanned": true, "seen": []}, …}} (i = null — образец не со дна; seen — ключи наблюдений вида, `Scanner.seen`). Запись не чаще раза в секунду после изменений и сразу, когда игру сворачивают.
## История экспедиции для журнала ART-047 — ключ "log" (`Expedition.snapshot`), если задан `expedition`; старый файл без
## него принимается, история тогда неизвестна (`Expedition.full = false`).
## Место и состояние корабля для кампании слоя 1 (#823) — ключ "ship": {"x", "y", "z", "yaw", "hull", "energy"}, если
## заданы `helm` и `vitals` (`ship_snapshot`); прочитанное — `ship` (`ship_read`: числа проверены, место в пределах хода),
## вернуть в игру — `ship_apply`. Старый файл без "ship" принимается (версия та же — формат дополнен, как "species" и
## "log"), `ship` тогда пуст.
## Знания слоя 1 (#825) — ключ "lore" (`LayerLore.snapshot`, список ключей), если задан `lore`; старый файл без него —
## знаний нет.
## Файл недоступен или испорчен — игра просто не сохраняет и начинает с чистого трюма; что вышло при чтении — `state`
## (испорченный файл журнал показывает своим сообщением, не как первый запуск).

const PATH := "user://save.json"
const VERSION := 1
const DELAY := 1.0                                   ## с после изменения до записи
## Итог чтения файла: не читали / файла нет, прочитан, испорчен (не JSON или не наш формат).
enum Load { NONE, OK, BROKEN }

const KINDS := ["moss", "shell", "coral", "spine"]   ## Samples.Kind → вид в файле (как KIND в js/manip.js)

## Путь по умолчанию для новых сохранений; пустой — не сохранять (тесты и снимки ставят "", чтобы не зависеть
## от прошлых запусков).
static var default_path := PATH

var path := default_path        ## пустой — сохранение выключено
var dirty := false
var timer := 0.0
var expedition: Expedition = null   ## история для журнала ART-047; null — не сохранять её
var lore: LayerLore = null          ## знания слоя 1 (#825); null — не сохранять их
var state := Load.NONE              ## что вышло при последнем `load_into`
var helm: Helm.Ship = null          ## корабль для ключа "ship"; null — пишется то, что прочитано (`ship`)
var vitals: Vitals = null           ## корпус и заряд для ключа "ship" (вместе с `helm`)
var ship := {}                      ## корабль из файла или последней записи (`ship_read`); пусто — не сохранён
## Корабль в игре — тот, что сохраняем (забег идёт). false — главное меню: корабль у начала спуска не перетирает
## сохранённое место, запись берёт прочитанный `ship` («Продолжить», #823).
var live := true


## Снимок того, что сохраняется.
static func snapshot(samples: Samples, scanner: Scanner = null, history: Expedition = null,
		ship_data: Dictionary = {}, knowledge: LayerLore = null) -> Dictionary:
	var cargo: Array = []
	for c in samples.cargo:
		cargo.append({"kind": KINDS[int(c[0])], "i": int(c[1]) if int(c[1]) >= 0 else null})
	var got: Array = samples.got.keys()
	got.sort()
	var out := {"v": VERSION, "cargo": cargo, "got": got}
	if scanner:
		var species := {}
		for id in Species.ids():
			species[id] = {"scanned": scanner.is_scanned(id), "seen": scanner.seen_of(id)}
		out["species"] = species
	if history:
		out["log"] = history.snapshot()
	if not ship_data.is_empty():
		out["ship"] = ship_data
	if knowledge:
		out["lore"] = knowledge.snapshot()
	return out


## Корабль для файла: место (м, до сантиметра), курс (рад), корпус и заряд.
static func ship_snapshot(s: Helm.Ship, v: Vitals) -> Dictionary:
	return {"x": snappedf(s.pos.x, 0.01), "y": snappedf(s.pos.y, 0.01), "z": snappedf(s.pos.z, 0.01),
		"yaw": snappedf(wrapf(s.yaw, -PI, PI), 0.0001), "hull": snappedf(v.hull, 0.01), "energy": snappedf(v.energy, 0.01)}


## Ключ "ship" из файла: {"pos": Vector3, "yaw", "hull", "energy"}; не словарь или нет числа — пусто (корабль не
## сохранён). Место — в пределах хода (`Helm.Ship.EDGE`, лёд `CEILING` … `DEEP`), корпус не ниже 1 % (разрушенный
## корпус не сохраняют — гибель ведёт к прошлой записи), заряд 0…100.
static func ship_read(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return {}
	var n := {}
	for k in ["x", "y", "z", "yaw", "hull", "energy"]:
		var x: Variant = raw.get(k)
		if not (typeof(x) in [TYPE_INT, TYPE_FLOAT]) or not is_finite(float(x)):
			return {}
		n[k] = float(x)
	var e := Helm.Ship.EDGE
	return {"pos": Vector3(clampf(n["x"], -e, e), clampf(n["y"], Helm.Ship.DEEP, Helm.Ship.CEILING), clampf(n["z"], -e, e)),
		"yaw": wrapf(n["yaw"], -PI, PI), "hull": clampf(n["hull"], 1.0, Vitals.MAX),
		"energy": clampf(n["energy"], 0.0, Vitals.MAX)}


## Вернуть прочитанный корабль (`ship_read`): стоит на месте, курс, корпус и заряд из файла; false — пусто.
static func ship_apply(d: Dictionary, s: Helm.Ship, v: Vitals) -> bool:
	if d.is_empty():
		return false
	s.reset()
	v.reset()
	s.pos = d["pos"]
	s.yaw = d["yaw"]
	v.hull = d["hull"]
	v.energy = d["energy"]
	return true


## Вернуть снимок в игру; false — не наш формат (тогда ничего не меняется).
static func apply(data: Variant, samples: Samples, scanner: Scanner = null, history: Expedition = null,
		knowledge: LayerLore = null) -> bool:
	if not (data is Dictionary) or int(data.get("v", 0)) != VERSION:
		return false
	var cargo: Array = []
	var raw_cargo: Variant = data.get("cargo", [])
	if raw_cargo is Array:
		for c in raw_cargo:
			if not (c is Dictionary):
				continue
			var k := KINDS.find(str(c.get("kind", "")))
			if k < 0:
				continue
			var i: Variant = c.get("i")
			var n := int(i) if typeof(i) in [TYPE_INT, TYPE_FLOAT] else -1
			cargo.append([k, n])
	var raw_got: Variant = data.get("got", [])
	samples.restore(raw_got if raw_got is Array else [], cargo)
	if scanner:
		var ids: Array = []
		var notes := {}
		var raw_species: Variant = data.get("species", {})
		if raw_species is Dictionary:
			for id in raw_species:
				var sp: Variant = raw_species[id]
				if not (sp is Dictionary):
					continue
				if bool(sp.get("scanned", false)):
					ids.append(id)
				if sp.get("seen") is Array:
					notes[id] = sp["seen"]
		scanner.restore(ids, notes)
	if history:
		history.apply(data.get("log"))
	if knowledge:
		knowledge.apply(data.get("lore"))
	return true


func enabled() -> bool:
	return not path.is_empty()


## Что-то сохраняемое изменилось: записать через DELAY.
func mark() -> void:
	dirty = true


## Кадр игры: пора ли записать.
func tick(dt: float, samples: Samples, scanner: Scanner = null) -> void:
	if not dirty:
		return
	timer += dt
	if timer >= DELAY:
		save(samples, scanner)


## Записать сейчас, если есть что (игру сворачивают или закрывают).
func flush(samples: Samples, scanner: Scanner = null) -> void:
	if dirty:
		save(samples, scanner)


func save(samples: Samples, scanner: Scanner = null) -> bool:
	dirty = false
	timer = 0.0
	if not enabled():
		return false
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	# разрушенный корпус (шторка ART-036 идёт) не пишется: гибель ведёт к прошлому месту (#824)
	var raw := ship_snapshot(helm, vitals) if helm and vitals and live and vitals.hull > 0.0 else {}
	if not raw.is_empty():
		ship = ship_read(raw)
	elif not ship.is_empty():   # корабль не подключён или не в забеге — не терять прочитанный
		raw = {"x": ship["pos"].x, "y": ship["pos"].y, "z": ship["pos"].z, "yaw": ship["yaw"], "hull": ship["hull"],
			"energy": ship["energy"]}
	f.store_string(JSON.stringify(snapshot(samples, scanner, expedition, raw, lore)))
	f.close()
	return true


## Прочитать файл и вернуть его в игру; false — файла нет, он испорчен или сохранение выключено.
func load_into(samples: Samples, scanner: Scanner = null) -> bool:
	state = Load.NONE
	ship = {}
	if not enabled() or not FileAccess.file_exists(path):
		return false
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not apply(json.data, samples, scanner, expedition, lore):
		state = Load.BROKEN
		return false
	ship = ship_read(json.data.get("ship"))
	state = Load.OK
	return true


## Стереть сохранение (новая экспедиция).
func wipe() -> void:
	dirty = false
	timer = 0.0
	if enabled() and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## «Сбросить сохранение» в настройках ART-037: файл стёрт, груз, поднятые образцы, изученные виды и история
## журнала — с нуля.
func reset(samples: Samples, scanner: Scanner = null) -> void:
	apply({"v": VERSION}, samples, scanner)
	if expedition:
		expedition.clear()   # новая экспедиция — история с начала, полная
	if lore:
		lore.clear()         # и знания слоя — с нуля
	state = Load.NONE
	ship = {}
	wipe()
