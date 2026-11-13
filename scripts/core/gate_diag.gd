class_name GateDiag
extends RefCounted
## Диагностика с борта у террасы врат 07 (#826, часть 1; карта #818, раздел «07. Терраса врат»). На арке три
## контактных гнезда у правой опоры (`NESTS`, до модели MOD-023 — точки на дне по габаритам ART-079). Биолог у поста
## «Сканер» держит кнопку — сканер корабля читает ближнее гнездо (`READ_TIME`), и **человеческий** интерфейс
## переводит его состояние на экран мостика. Каждое гнездо — один факт `LayerLore.DIAGNOSTICS`, в любом порядке;
## прочитанное второй раз новым не приходит. Диагностика ничего не чинит: на будущее — действия терминала
## (`Act`) и что каждое может изменить (`effect`): коды авторизуют только этот терминал, питание ретранслятора — ремонт,
## которого в слое 1 нет. Створку узла открывает купольник (поток Б), но чтение от неё не зависит.
## Ставит `Main` (`main.gate`): цель — `aim` по позиции корабля и цели сканера, удержание — `hold`, факт — сигнал
## `read` → `LayerLore.learn`.

signal read(fact: String)

## Гнёзда: смещение (x, z) от середины террасы, м (по дну), и факт, который гнездо отдаёт. По ART-079
## (`docs/concept-art/terrasa-vrat.md`): тройка — треугольник со стороной 4 м у правой опоры (+X, подход с +Z),
## вне прохода X −30…+30, на лицевой стороне арки (её глубина по Z — 23 м).
const NESTS: Array[Dictionary] = [
	{"at": Vector2(36.0, 13.0), "fact": LayerLore.D07_RETURN},
	{"at": Vector2(40.0, 13.0), "fact": LayerLore.D07_RELAY},
	{"at": Vector2(38.0, 9.5), "fact": LayerLore.D07_AUTH},
]
const READ_R := 50.0       ## гнездо читается не дальше этого от корабля, м (по прямой); 45 → 50 с жёлобом (#1757):
                           ## гнёзда на его склоне на 10–12 м глубже, с 35 м над серединой до них 46–48 м
const READ_TIME := 3.0     ## удержание до перевода одного гнезда, с
const DECAY := 1.0         ## спад прогресса без удержания, доля в с

## Перевод на экран мостика — тексты TXT-001 (`docs/teksty/TXT-001-sloj1.md`, раздел 2): заголовок и три
## состояния раздельно; человеческий интерфейс корабля переводит состояние чужого узла.
const HEADER := "Перевод состояния узла"
const TEXT := {
	LayerLore.D07_RETURN: "Обратный ход врат неисправен.",
	LayerLore.D07_RELAY: "Ретранслятор: нет питания.",
	LayerLore.D07_AUTH: "Изменение настроек требует авторизации.",
}

## Строки экрана сканера — те же тексты; длинные экран переносит.
const SHORT := TEXT

## Реакции экипажа TXT-001 (роль `Crew.Role`, текст): необязательны для понимания фактов, подача — по UX
## (`docs/ux/put-novichka-sloj1.md`, п. 8); в соло невидимых говорящих напарников не создавать.
const REACTION := {
	LayerLore.D07_RETURN: [Crew.Role.SONAR, "Состояние прочитали. Обратный ход пока не работает."],
	LayerLore.D07_AUTH: [Crew.Role.BIOLOGIST, "Настройки закрыты. Нужно разрешение системы."],
}

## Действия терминала 07 на будущее (#826): локальная авторизация кодами и ремонт питания.
enum Act { CODES, POWER }

var nest := -1             ## гнездо в прицеле (-1 — нет)
var dist := 0.0            ## до него, м
var progress := 0.0
var busy := false          ## в прошлый шаг переводили гнездо (звук сканера SND-006)
var done := 0              ## сколько гнёзд прочитано за сеанс («вид изучен» — тот же сигнал)
var _holding := false


## Гнездо i в мире: на дне под точкой смещения.
static func nest_pos(i: int) -> Vector3:
	var p: Vector2 = EcoGate.CENTER + (NESTS[i]["at"] as Vector2)
	return Vector3(p.x, Seabed.height(p.x, p.y), p.y)


## Что действие a может изменить (ключи `LayerLore`). Коды — только авторизация этого терминала; питание
## ретранслятора кодами не чинится, ремонта питания в слое 1 нет — пусто. «Починить сразу» нет.
static func effect(a: int) -> Array[String]:
	if a == Act.CODES:
		return [LayerLore.AUTH07]
	return []


## Цель шага: ближнее непрочитанное гнездо в `READ_R` (все прочитаны — ближнее прочитанное, нажатие повторит
## перевод). Ближнее — по горизонтали: гнёзда на склоне жёлоба стоят на разной высоте, и сверху по прямой ближе
## оказалось бы не то, над которым корабль (#1757); предел `READ_R` и расстояние на экране — по прямой.
## Если у сканера есть цель-существо ближе гнезда — гнездо не в прицеле. Идёт чтение — держит своё.
func aim(ship: Vector3, lore: LayerLore, creature_dist := INF) -> void:
	var best := -1
	var best_d := INF
	var best_flat := INF
	var best_known := true
	for i in NESTS.size():
		var p := nest_pos(i)
		var d := ship.distance_to(p)
		if d > READ_R:
			continue
		var flat := Vector2(ship.x - p.x, ship.z - p.z).length()
		var known := lore.knows(NESTS[i]["fact"])
		if progress > 0.0 and i == nest:
			best = i
			best_d = d
			break
		if (best_known and not known) or (known == best_known and flat < best_flat):
			best = i
			best_d = d
			best_flat = flat
			best_known = known
	if best >= 0 and best_d > creature_dist:
		best = -1
	if best != nest:
		progress = 0.0
	nest = best
	dist = best_d if best >= 0 else 0.0


func active() -> bool:
	return nest >= 0


func fact() -> String:
	return NESTS[nest]["fact"] if nest >= 0 else ""


## Кадр удержания у поста: переводить гнездо в прицеле. Прочитанное повторно не читается.
func hold(dt: float, lore: LayerLore) -> void:
	if nest < 0 or lore.knows(fact()):
		return
	_holding = true
	progress = minf(1.0, progress + dt / READ_TIME)
	if progress >= 1.0:
		var f := fact()
		progress = 0.0
		if lore.learn(f):
			done += 1
			read.emit(f)


func update(dt: float) -> void:
	busy = _holding
	if not _holding:
		progress = maxf(0.0, progress - dt * DECAY)
	_holding = false


## Подпись поста «Сканер», пока гнездо в прицеле.
func label(lore: LayerLore) -> String:
	if progress > 0.0:
		return "Перевод %d%%" % int(progress * 100.0)
	if lore.knows(fact()):
		return "Гнездо 07 · прочитано"
	return "Гнездо 07 · %d м · держать" % roundi(dist)


## Нажатие у поста: прочитанное — перевод ещё раз, нет — как читать.
func press_text(lore: LayerLore) -> String:
	if lore.knows(fact()):
		return TEXT[fact()]
	return "Держать — перевести состояние гнезда"


## Экран сканера: заголовок, гнездо, прогресс и уже переведённое.
func screen_lines(lore: LayerLore) -> PackedStringArray:
	var lines := PackedStringArray(["ДИАГНОСТИКА 07", "Гнездо %d из %d · %d м" % [nest + 1, NESTS.size(), roundi(dist)]])
	if progress > 0.0:
		lines.append("Перевод %d %%" % int(progress * 100.0))
	elif not lore.knows(fact()):
		lines.append("Держать — перевод")
	var head := false
	for k in LayerLore.DIAGNOSTICS:
		if lore.knows(k):
			if not head:
				lines.append(HEADER)
				head = true
			lines.append(SHORT[k])
	return lines
