class_name Expedition
extends RefCounted
## История экспедиции для «Журнала экспедиции» ART-047 (`docs/concept-art/zhurnal-ekspedicii.md`): посещённые места
## отмели, завершённые забеги, рекорд глубины, прочитанные карточки видов. Хранится в `SaveGame` ключом "log"
## (`snapshot`/`apply`), остальной формат файла не меняется. Сохранение без "log" (старое) — история неизвестна
## (`full = false`): журнал пишет «—» и «История посещений ещё не записана», а не выдумывает. Новое дальше
## записывается, но `full` остаётся false до сброса сохранения.
## Ставит `Main`: `visit` по месту корабля, `dive_depth` по глубине (оба — шаг корабля у хоста и в одиночном
## забеге), `end_run` — «наверх» и «Корпус разрушен»; `main.expedition`.

signal changed

var places: Array[String] = []   ## ключи `Run.PLACES`, в порядке первого посещения
var runs := 0                    ## завершённых забегов: экипаж поднялся наверх или корпус разрушен
var deepest := 0                 ## рекорд глубины, целые метры
var read: Array[String] = []     ## виды, чьи карточки в журнале открыты (снимает «новое»)
var full := true                 ## история записана с начала экспедиции


## Корабль в (x, z): место, в радиус которого он вошёл впервые, или "". Любое место `Run.PLACES`, не только
## по маршруту.
func visit(x: float, z: float) -> String:
	for k: String in Run.PLACES:
		if places.has(k):
			continue
		if Vector2(x, z).distance_to(Run.place_xz(k)) < float(Run.PLACES[k][2]):
			places.append(k)
			changed.emit()
			return k
	return ""


func visited(key: String) -> bool:
	return places.has(key)


## Глубина корабля d м: новый рекорд — true (целые метры, чтобы не писать файл каждый кадр).
func dive_depth(d: float) -> bool:
	var m := floori(d)
	if m <= deepest:
		return false
	deepest = m
	changed.emit()
	return true


## Забег завершён (наверх или корпус разрушен).
func end_run() -> void:
	runs += 1
	changed.emit()


## Карточка вида открыта в журнале: «новое» снято.
func mark_read(id: String) -> void:
	if read.has(id):
		return
	read.append(id)
	changed.emit()


## «Новое» у вида: изучен сканером, карточка ещё не открыта.
func is_new(id: String, scanned: Array) -> bool:
	return scanned.has(id) and not read.has(id)


## «Дальше: <место>» — первое непосещённое место по порядку маршрутов (`Run.ROUTES`), "" — все посещены. Пока
## история не полная, совета нет: непосещённое по записи могло быть посещено раньше.
func next_place() -> String:
	if not full:
		return ""
	for r: Dictionary in Run.ROUTES:
		for k: String in r["places"]:
			if not places.has(k):
				return k
	return ""


## Для файла: {"places": [...], "runs": n, "deepest": m, "read": [...], "full": bool}.
func snapshot() -> Dictionary:
	return {"places": places.duplicate(), "runs": runs, "deepest": deepest, "read": read.duplicate(), "full": full}


## Из файла. data = null — сохранения с историей нет (старое): история неизвестна. Испорченные поля — пусто.
func apply(data: Variant) -> void:
	clear()
	if not (data is Dictionary):
		full = false
		return
	var raw_places: Variant = data.get("places", [])
	if raw_places is Array:
		for k in raw_places:
			if Run.PLACES.has(str(k)) and not places.has(str(k)):
				places.append(str(k))
	runs = maxi(0, _int(data.get("runs"), 0))
	deepest = maxi(0, _int(data.get("deepest"), 0))
	var raw_read: Variant = data.get("read", [])
	if raw_read is Array:
		for id in raw_read:
			if not read.has(str(id)):
				read.append(str(id))
	full = bool(data.get("full", true))


## Новая экспедиция: история с нуля и полная.
func clear() -> void:
	places.clear()
	runs = 0
	deepest = 0
	read.clear()
	full = true


static func _int(v: Variant, fallback: int) -> int:
	return int(v) if typeof(v) in [TYPE_INT, TYPE_FLOAT] else fallback
