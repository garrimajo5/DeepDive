class_name Status
## Строка состояния на приборах (pogrujenie Core/StatusBoard.cs, StatusMessage.cs; Game.toast в js/game.js).

const SEPARATOR := " · "
## Сколько секунд держится сообщение на приборах (Game.toast — 4200 мс).
const MESSAGE_SECONDS := 4.2
## Румбы: север — нос карты (−Z), восток — +X.
const RUMBS: Array[String] = ["С", "СВ", "В", "ЮВ", "Ю", "ЮЗ", "З", "СЗ"]


## Разложить части по строкам ширины width; measure — ширина текста (в сцене — шрифт, в тестах — число букв).
## Части склеиваются через « · », часть не рвётся посередине, а переходит на следующую строку целиком;
## повтор той же части (без учёта регистра) не пишется. Часть шире строки стоит одна.
## (Отчёт тестера в pogrujenie: в трюме строка не помещалась, конец обрезался.)
static func lines(parts: Array, measure: Callable, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	var seen := {}
	var cur := ""
	for raw in parts:
		var p := str(raw).strip_edges()
		if p.is_empty() or seen.has(p.to_lower()):
			continue
		seen[p.to_lower()] = true
		if cur.is_empty():
			cur = p
			continue
		var joined := cur + SEPARATOR + p
		if float(measure.call(joined)) <= width:
			cur = joined
		else:
			out.append(cur)
			cur = p
	if not cur.is_empty():
		out.append(cur)
	return out


## Все части одной строкой (для лога и тестов), без повторов.
static func join(parts: Array) -> String:
	return SEPARATOR.join(lines(parts, func(_s: String) -> float: return 0.0, INF))


## Румб направления в мире (x, z): «С» — к −Z.
static func rumb(dir: Vector3) -> String:
	if Vector2(dir.x, dir.z).length() < 1e-6:
		return "—"
	var bearing := fposmod(rad_to_deg(atan2(dir.x, -dir.z)), 360.0)
	return RUMBS[int(round(bearing / 45.0)) % 8]


## Курс корабля в градусах 0…359 (0 — север, 90 — восток) по yaw (нос в (−sin yaw, 0, −cos yaw)).
static func course_deg(yaw: float) -> int:
	return int(round(fposmod(rad_to_deg(-yaw), 360.0))) % 360


## Сообщение в конце строки состояния («Вы за штурвалом», «Прожектор погашен»…): держится 4,2 с и гаснет.
## Сообщение-состояние гасят сразу, когда состояние кончилось (clear), — только если на приборах всё ещё оно.
## (Отчёт тестера в pogrujenie: «Вы за штурвалом» висело после «Встать» до следующего сообщения.)
class Message:
	var text := ""
	var left := 0.0

	func visible() -> bool:
		return not text.is_empty()

	func say(msg: String, seconds: float = MESSAGE_SECONDS) -> void:
		text = msg
		left = seconds if not msg.is_empty() else 0.0

	func clear(msg: String) -> void:
		if text == msg:
			text = ""
			left = 0.0

	func update(dt: float) -> void:
		if text.is_empty() or dt <= 0.0:
			return
		left -= dt
		if left <= 0.0:
			text = ""
			left = 0.0
