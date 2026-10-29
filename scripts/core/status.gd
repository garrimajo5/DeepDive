class_name Status
## Строка состояния на приборах (pogrujenie Core/StatusBoard.cs, StatusMessage.cs; Game.toast в js/game.js).

const SEPARATOR := " · "
## Сколько секунд держится сообщение на приборах (Game.toast — 4200 мс).
const MESSAGE_SECONDS := 4.2
## Румбы: север — нос карты (−Z), восток — +X.
const RUMBS: Array[String] = ["С", "СВ", "В", "ЮВ", "Ю", "ЮЗ", "З", "СЗ"]
## Сколько строк самое большее у одной длинной части (описание вида из журнала); дальше — «…».
const PART_LINES := 4


## Разложить части по строкам ширины width; measure — ширина текста (в сцене — шрифт, в тестах — число букв).
## Части склеиваются через « · », часть не рвётся посередине, а переходит на следующую строку целиком;
## повтор той же части (без учёта регистра) не пишется. Часть шире строки переносится по словам (`wrap_words`), не больше
## PART_LINES строк. (Отчёт тестера в pogrujenie: в трюме строка не помещалась, конец обрезался; issue #138 — карточка
## вида из журнала уходила за правый край.)
static func lines(parts: Array, measure: Callable, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	var seen := {}
	var cur := ""
	for raw in parts:
		var p := str(raw).strip_edges()
		if p.is_empty() or seen.has(p.to_lower()):
			continue
		seen[p.to_lower()] = true
		if float(measure.call(p)) > width:   # часть шире строки — по словам, хвост остаётся для следующих частей
			if not cur.is_empty():
				out.append(cur)
			var w := wrap_words(p, measure, width)
			for i in w.size() - 1:
				out.append(w[i])
			cur = w[w.size() - 1]
			continue
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


## Текст по словам в строки ширины width, не больше PART_LINES; не влезло — последняя строка кончается «…».
## Слово шире строки стоит одно.
static func wrap_words(text: String, measure: Callable, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	var cur := ""
	for word in text.split(" ", false):
		var joined := word if cur.is_empty() else cur + " " + word
		if cur.is_empty() or float(measure.call(joined)) <= width:
			cur = joined
		else:
			out.append(cur)
			cur = word
	if not cur.is_empty():
		out.append(cur)
	if out.size() > PART_LINES:
		var last := out[PART_LINES - 1]
		while last.contains(" ") and float(measure.call(last + "…")) > width:
			last = last.substr(0, last.rfind(" "))
		out.resize(PART_LINES)
		out[PART_LINES - 1] = last.rstrip(" ,.;:—") + "…"
	return out


## Все части одной строкой (для лога и тестов), без повторов.
static func join(parts: Array) -> String:
	return SEPARATOR.join(lines(parts, func(_s: String) -> float: return 0.0, INF))


## Табло тревог — одна строка: первая непустая по важности (пробоина, реактор, сонарная тьма, заряд), как #alert
## в js/silt.js — пробоина и реактор важнее ила.
static func alarm(by_priority: Array) -> String:
	for a in by_priority:
		if not str(a).is_empty():
			return str(a)
	return ""


## Румб направления в мире (x, z): «С» — к −Z.
static func rumb(dir: Vector3) -> String:
	if Vector2(dir.x, dir.z).length() < 1e-6:
		return "—"
	var bearing := fposmod(rad_to_deg(atan2(dir.x, -dir.z)), 360.0)
	return RUMBS[int(round(bearing / 45.0)) % 8]


## Курс корабля в градусах 0…359 (0 — север, 90 — восток) по yaw (нос в (−sin yaw, 0, −cos yaw)).
static func course_deg(yaw: float) -> int:
	return int(round(fposmod(rad_to_deg(-yaw), 360.0))) % 360


## Строки по частям без пересчёта каждый кадр (#847): шрифтом меряем только при смене частей, ширины или размера
## шрифта — иначе ≈25 замеров строк на кадр. `update` — true, если текст новый (плашку тогда ужать заново).
class Lines:
	var key := ""
	var text := ""

	func update(parts: Array, measure: Callable, width: float, size: int = 0) -> bool:
		var k := "%s|%d|%s" % [width, size, "\u001f".join(PackedStringArray(parts.map(func(p): return str(p))))]
		if k == key:
			return false
		key = k
		text = "\n".join(Status.lines(parts, measure, width))
		return true


## Сообщение в конце строки состояния («Вы за штурвалом», «Прожектор погашен»…): держится 4,2 с и гаснет.
## Сообщение-состояние гасят сразу, когда состояние кончилось (clear), — только если на приборах всё ещё оно.
## (Отчёт тестера в pogrujenie: «Вы за штурвалом» висело после «Встать» до следующего сообщения.)
## Сообщение мира (`wait`) не перебивает другое сообщение мира, пока то видно меньше MIN_SHOW с: ждёт своей очереди (одно, последнее), —
## иначе строку мира («веер повёрнут к жерлу») стирал укус хищника в ту же секунду (issue #979). Свои действия
## игрока (`wait` = false) показываются сразу — отклик на кнопку не ждёт.
class Message:
	const MIN_SHOW := 1.0
	var text := ""
	var left := 0.0
	## Сколько секунд видно текущее сообщение; ждущее и его время.
	var shown := 0.0
	var next := ""
	var next_left := 0.0
	## Текущее — строка мира (её и бережём от следующей строки мира).
	var world := false

	func visible() -> bool:
		return not text.is_empty()

	func say(msg: String, seconds: float = MESSAGE_SECONDS, wait := false) -> void:
		if wait and world and not msg.is_empty() and not text.is_empty() and msg != text and shown < MIN_SHOW:
			next = msg
			next_left = seconds
			return
		if wait or msg == next:
			next = ""
			next_left = 0.0
		_show(msg, seconds)
		world = wait

	func clear(msg: String) -> void:
		if next == msg:
			next = ""
			next_left = 0.0
		if text == msg:
			text = ""
			left = 0.0
			_take_next()

	func update(dt: float) -> void:
		if text.is_empty() or dt <= 0.0:
			_take_next()
			return
		left -= dt
		shown += dt
		if not next.is_empty() and shown >= MIN_SHOW:
			_take_next()
		elif left <= 0.0:
			text = ""
			left = 0.0
			_take_next()

	func _show(msg: String, seconds: float) -> void:
		text = msg
		left = seconds if not msg.is_empty() else 0.0
		shown = 0.0

	func _take_next() -> void:
		if next.is_empty():
			return
		var m := next
		var s := next_left
		next = ""
		next_left = 0.0
		_show(m, s)
		world = true
