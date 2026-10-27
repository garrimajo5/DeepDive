class_name Scanner
extends RefCounted
## Сканер биолога (js/game.js: findScanTarget, completeScan; модель MOD-007 на правом борту мостика). Пока игрок
## у поста «Сканер», корабль просит у живого мира цели (`EcoLink.ShipState.scan_range` = 80 м), мир шлёт `EcoLink.NEAR`
## с "scan": true, ближние первыми. Цель — ближайшая неизученная (иначе ближайшая): на телефоне прицел заменяет
## выбор сканера. Удержание кнопки 1,5 с — вид изучен («Новый вид: …»), записан в журнал экспедиции и в сохранение;
## отпустил раньше — прогресс спадает вдвое быстрее. Пока прогресс есть, прицел держит сканируемый вид, даже если
## ближе подплыл другой (issue #90). Изученная цель — нажатие показывает сведения о виде.
## Наблюдения — заметки журнала вида (`Species.Info.notes`) по событиям мира рядом (`EcoLink.OBSERVE`): `seen`,
## записываются и до сканирования, в журнале и сохранении (`seen` в формате js/save.js).

const RANGE := 80.0          ## дальность прицела, м (как в браузере)
const SCAN_TIME := 1.5       ## удержание до записи вида, с
const DECAY := 2.0           ## спад прогресса без удержания, доля в с

var scanned := {}            ## изученные виды: ключ Species → true
var seen := {}               ## наблюдения: ключ Species → [ключ заметки, …] в порядке, как увидели
var rev := 0                 ## растёт при каждом изменении scanned/seen (экран журнала лаборатории, #847)
var targets: Array[Dictionary] = []   ## NEAR с "scan": true этого шага, ближние первыми
var target: Dictionary = {}  ## текущая цель ({} — никого)
var key := ""                ## вид, который сканируется
var progress := 0.0
var _holding := false

signal message(text: String)
signal changed               ## изучен новый вид — сохранить


## Просканирован ли вид (для EcoWorld.scanned — названия в сообщениях мира).
func is_scanned(species: String) -> bool:
	return scanned.has(species)


## События мира за шаг: оставить цели сканера и выбрать цель.
func take(events: Array) -> void:
	targets.clear()
	for e in events:
		if e.get("type", "") == EcoLink.NEAR and bool(e.get("scan", false)) and Species.has(str(e.get("species", ""))):
			targets.append(e)
	targets.sort_custom(func(a, b): return float(a["dist"]) < float(b["dist"]))
	target = {}
	if key != "" and progress > 0.0:   # идёт скан: прицел держит вид, пока он в дальности (issue #90)
		for t in targets:
			if t["species"] == key:
				target = t
				return
	for t in targets:
		if not is_scanned(t["species"]):
			target = t
			break
	if target.is_empty() and not targets.is_empty():
		target = targets[0]


## Кадр удержания кнопки у поста: сканировать текущую цель.
func hold(dt: float) -> void:
	if target.is_empty() or is_scanned(target["species"]):
		return
	var sp: String = target["species"]
	if key != sp:
		key = sp
		progress = 0.0
	_holding = true
	progress = minf(1.0, progress + dt / SCAN_TIME)
	if progress >= 1.0:
		complete(sp)


## Вид изучен (completeScan).
func complete(species: String) -> void:
	key = ""
	progress = 0.0
	if is_scanned(species):
		return
	scanned[species] = true
	rev += 1
	changed.emit()
	message.emit("Новый вид: %s" % Species.info(species).name)


func update(dt: float) -> void:
	if not _holding:
		progress = maxf(0.0, progress - dt * DECAY)
		if progress <= 0.0:
			key = ""
	_holding = false


## Наблюдение вида рядом с кораблём; true — новое (записать в сохранение). Ключ, которого нет у вида, — не наблюдение.
func observe(species: String, note: String) -> bool:
	if not Species.is_observation(species, note):
		return false
	var got: Array = seen.get(species, [])
	if got.has(note):
		return false
	got.append(note)
	seen[species] = got
	rev += 1
	changed.emit()
	return true


## Наблюдения вида по порядку записи.
func seen_of(species: String) -> Array[String]:
	var out: Array[String] = []
	for n in seen.get(species, []):
		out.append(n)
	return out


## Нажатие у поста: подсказка или сведения об изученном виде.
func press() -> void:
	if target.is_empty():
		message.emit("Сканер: рядом никого ближе %d м" % int(RANGE))
	elif is_scanned(target["species"]):
		var info := Species.info(target["species"])
		message.emit("%s: %s" % [info.name, info.desc])
	else:
		message.emit("Держать — сканировать")


## Название цели: настоящее после сканирования, до — «Неизвестный вид».
func target_name() -> String:
	if target.is_empty():
		return ""
	return Species.info(target["species"]).name if is_scanned(target["species"]) else "Неизвестный вид"


## Подпись поста в строке состояния.
func label() -> String:
	if target.is_empty():
		return "Сканер: целей нет"
	if progress > 0.0:
		return "Сканирую %d%%" % int(progress * 100.0)
	return "Цель: %s · %d м" % [target_name(), roundi(float(target["dist"]))]


## Строки экрана сканера.
func screen_lines() -> PackedStringArray:
	var lines := PackedStringArray(["СКАНЕР БИОЛОГА"])
	if target.is_empty():
		lines.append("Целей нет")
	else:
		lines.append(target_name())
		lines.append("%d м · целей %d" % [roundi(float(target["dist"])), targets.size()])
		if is_scanned(target["species"]):
			lines.append("Изучен")
		elif progress > 0.0:
			lines.append("Скан %d %%" % int(progress * 100.0))
		else:
			lines.append("Держать — скан")
	lines.append("Видов изучено: %d из %d" % [scanned.size(), Species.count()])
	return lines


## Изученные виды по порядку журнала (для сохранения).
func list() -> Array[String]:
	var out: Array[String] = []
	for id in Species.ids():
		if scanned.has(id):
			out.append(id)
	return out


## Из сохранения: известные реестру виды и их наблюдения (seen: ключ вида → [ключ заметки, …]; чужие ключи пропускаются).
func restore(ids: Array, notes: Dictionary = {}) -> void:
	scanned.clear()
	seen.clear()
	rev += 1
	for id in ids:
		if Species.has(str(id)):
			scanned[str(id)] = true
	for id in notes:
		var info := Species.info(str(id))
		if info == null or not (notes[id] is Array):
			continue
		var got: Array = []
		for n in notes[id]:
			if info.has_note(str(n)) and not got.has(str(n)):
				got.append(str(n))
		if not got.is_empty():
			seen[str(id)] = got
	target = {}
	key = ""
	progress = 0.0
