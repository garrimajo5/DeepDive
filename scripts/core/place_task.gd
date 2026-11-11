class_name PlaceTask
extends RefCounted
## Задача места с действием (#1635, разбор пути новичка #1335, п. 8): у 07 Терраса врат, 03 Раковина древних и
## 08 Наблюдение поля, пока корабль в круге места (`Run.PLACES`) и действие не сделано (`LayerLore`), плашка цели за
## штурвалом (`GoalPlate.Kind.TASK`), строка при входе (`Run.update`) и строка приборов (`Run.status`) говорят, что
## делать и на каком посту. Механика мест и знания не меняются — только подача. Корабль в круге, но действие отсюда не
## сработает — «ближе N м» / «ниже N м» по тем же радиусам, что в коде действия. Задача — при любом маршруте и без него.

## Радиусы действий потока Б — копии (`EcoLink` не трогаем), равенство держит `test_place_task`.
const SHELL_SCAN_R := 30.0   ## = EcoShell.SCAN_R: сканер видит гнёзда Раковины ближе этого по горизонтали
const SHELL_SCAN_UP := 25.0  ## = EcoShell.SCAN_UP: и не выше этого над дном
const FIELD_SEE := 40.0      ## = EcoField.SEE: импульс с площадки ближе этого к середине поля

const PLATE_MAX := 34        ## плашка цели, знаков (задача)
const NEAR_MAX := 40         ## плашка «ближе N м» — ужимается кеглем (`GoalPlate.fit`)

## ключ места → пост (ячейка `ShipMap.CELLS`), пост коротко, задача на плашке, строка при входе (≤ `Run.LINE_MAX`).
const TASKS := {
	"gate": {"icon": "scanner", "post": "сканер", "plate": "сканер",
		"line": "Терраса врат — на месте. Сканер: прочитайте 3 гнезда арки"},
	"shell": {"icon": "scanner", "post": "сканер", "plate": "сканер и сонар",
		"line": "Раковина древних — на месте. Нужны сканер и импульс сонара"},
	"field": {"icon": "sonar", "post": "сонар", "plate": "импульс сонара",
		"line": "Наблюдение поля — на месте. Импульс сонара с площадки"},
}


static func has(key: String) -> bool:
	return TASKS.has(key)


## Сделано ли действие места key по знаниям lore (нет lore — считаем сделанным: подачи нет).
static func done(key: String, lore: LayerLore) -> bool:
	if lore == null or not TASKS.has(key):
		return true
	match key:
		"gate":
			return lore.unread_diagnostics().is_empty()
		"shell":
			return lore.knows(LayerLore.SHELL03)
		"field":
			return lore.knows(LayerLore.FIELD08)
	return true


## Ключ места с несделанным действием, в круге которого корабль (x, z), или "".
static func at(pos: Vector2, lore: LayerLore) -> String:
	for key in TASKS:
		if pos.distance_to(Run.place_xz(key)) < float(Run.PLACES[key][2]) and not done(key, lore):
			return key
	return ""


## Сколько гнёзд 07 прочитано: «1 / 3».
static func count(lore: LayerLore) -> String:
	var n := LayerLore.DIAGNOSTICS.size()
	return "%d / %d" % [n - lore.unread_diagnostics().size(), n]


## Что делать, коротко: «сканер 1 / 3», «сканер и сонар», «импульс сонара».
static func what(key: String, lore: LayerLore) -> String:
	var t: String = TASKS[key]["plate"]
	return "%s %s" % [t, count(lore)] if key == "gate" else t


## Недостача до радиуса действия из ship (корабль в мире): "" — отсюда сработает, иначе «ближе N м» / «ниже N м».
static func short(key: String, ship: Vector3, lore: LayerLore) -> String:
	var xz := Vector2(ship.x, ship.z)
	match key:
		"gate":
			var best := INF
			for i in GateDiag.NESTS.size():
				if lore != null and lore.knows(GateDiag.NESTS[i]["fact"]):
					continue
				best = minf(best, ship.distance_to(GateDiag.nest_pos(i)))
			if best > GateDiag.READ_R and best < INF:
				return "ближе %d м" % ceili(best - GateDiag.READ_R)
		"shell":
			var d := xz.distance_to(Run.place_xz(key))
			if d > SHELL_SCAN_R:
				return "ближе %d м" % ceili(d - SHELL_SCAN_R)
			var up := ship.y - Seabed.height(ship.x, ship.z)
			if up > SHELL_SCAN_UP:
				return "ниже %d м" % ceili(up - SHELL_SCAN_UP)
		"field":
			var d := xz.distance_to(Run.place_xz(key))
			if d >= FIELD_SEE:
				return "ближе %d м" % maxi(1, ceili(d - FIELD_SEE))
	return ""


## Плашка цели: «Терраса врат · сканер 1 / 3»; не дотягиваемся — «Терраса врат · сканер — ближе 20 м».
static func plate(key: String, ship: Vector3, lore: LayerLore) -> String:
	var far := short(key, ship, lore)
	if far != "":
		return "%s · %s — %s" % [Run.place_name(key), TASKS[key]["post"], far]
	return "%s · %s" % [Run.place_name(key), what(key, lore)]


## Строка приборов не за штурвалом: «Терраса врат: сканер 1 / 3».
static func status(key: String, lore: LayerLore) -> String:
	return "%s: %s" % [Run.place_name(key), what(key, lore)]


## Строка при входе в круг.
static func line(key: String) -> String:
	return TASKS[key]["line"]
