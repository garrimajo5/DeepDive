class_name SaveGame
extends RefCounted
## Сохранение экспедиции в user:// (как js/save.js): груз трюма, номера поднятых со дна образцов, изученные виды.
## Формат файла — JSON, совместимый с браузерным: {"v": 1, "cargo": [{"kind": "moss", "i": 3}, …], "got": [3, …],
## "species": {"fish": {"scanned": true, "seen": []}, …}} (i = null — образец не со дна; seen — ключи наблюдений вида, `Scanner.seen`). Запись не чаще раза в секунду после изменений и сразу, когда игру сворачивают.
## Файл недоступен или испорчен — игра просто не сохраняет и начинает с чистого трюма.

const PATH := "user://save.json"
const VERSION := 1
const DELAY := 1.0                                   ## с после изменения до записи
const KINDS := ["moss", "shell", "coral", "spine"]   ## Samples.Kind → вид в файле (как KIND в js/manip.js)

## Путь по умолчанию для новых сохранений; пустой — не сохранять (тесты и снимки ставят "", чтобы не зависеть
## от прошлых запусков).
static var default_path := PATH

var path := default_path        ## пустой — сохранение выключено
var dirty := false
var timer := 0.0


## Снимок того, что сохраняется.
static func snapshot(samples: Samples, scanner: Scanner = null) -> Dictionary:
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
	return out


## Вернуть снимок в игру; false — не наш формат (тогда ничего не меняется).
static func apply(data: Variant, samples: Samples, scanner: Scanner = null) -> bool:
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
	f.store_string(JSON.stringify(snapshot(samples, scanner)))
	f.close()
	return true


## Прочитать файл и вернуть его в игру; false — файла нет, он испорчен или сохранение выключено.
func load_into(samples: Samples, scanner: Scanner = null) -> bool:
	if not enabled() or not FileAccess.file_exists(path):
		return false
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return false
	return apply(json.data, samples, scanner)


## Стереть сохранение (новая экспедиция).
func wipe() -> void:
	dirty = false
	timer = 0.0
	if enabled() and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
