class_name RunTimeline
extends RefCounted
## Хронометраж забега (эпик #633): когда что случилось и сколько длилось — для полного забега на телефоне и баланса
## событий по его итогам. Main каждый шаг отдаёт состояние (`watch`: какие события идут, корпус, глубина) и отмечает
## разовое (`mark`: точка маршрута, разряд); в конце забега (`finish`) лента и сводка ложатся в `user://zabegi.txt`
## (последние KEEP забегов, новый — сверху). Сводка отвечает на вопросы тестера: сколько длился забег, какая доля —
## под событиями, где самое долгое затишье («скучно»), сколько времени шли два события сразу («перегруз»).
## Свернули игру посреди забега — недописанный забег пишется с пометкой «не закончен» (`save`), вернулись — дописывается.
## Тесты и снимки файл не пишут — `RunTimeline.default_path = ""`; прогон тестера пишет свой в `qa/out/zabeg.txt`.

const PATH := "user://zabegi.txt"
static var default_path := PATH
const KEEP := 20          ## сколько забегов держать в файле
const HIT_MIN := 1.5      ## падение корпуса за шаг от стольких % — «удар» (вода пробоины точит понемногу)
const SHORT := 10.0       ## забег короче, с — не пишем (вышли в меню сразу после «Погрузиться»)
const UNFINISHED := "не закончен"   ## итог в шапке недописанного забега
const BLINK := 0.5        ## событие короче, с — мигание состояния (сценарий тестера на кадр снимка), в ленту не идёт (#692)

var path := default_path
var running := false
var t0 := 0.0             ## время игры в начале забега
var t_last := 0.0         ## последний шаг
var events: Array = []    ## [t от начала, текст] — по времени
var spans: Array = []     ## [имя, начало, конец (−1 — ещё идёт)]
var deepest := 0.0
var hull := 100.0
var legs: Array = []      ## участки слоя (#824): [откуда id, куда id, с] — от прихода к месту до прихода к следующему
var _on := {}             ## имя события → индекс в spans, пока идёт
var _place := ""          ## id `LayerMap` места, где корабль был последним
var _place_at := 0.0      ## когда пришёл туда, с от начала забега
var _old: Array[String] = []   ## записанные забеги (блоки текста), новый — первым
var _n := 0               ## номер забега за всё время файла


func _init() -> void:
	_load()


## Новый забег с t (время игры). Идущий длиннее SHORT — дописать «прерван».
func begin(t: float) -> void:
	if running and t_last - t0 >= SHORT:
		finish(t_last, "прерван новым забегом")
	running = true
	t0 = t
	t_last = t
	events.clear()
	spans.clear()
	legs.clear()
	_on.clear()
	_place = ""
	_place_at = 0.0
	deepest = 0.0
	hull = 100.0
	_add(0.0, "начало")


## Шаг забега: on — какие события идут сейчас (имя → bool), корпус в %, глубина в м.
func watch(t: float, on: Dictionary, hull_now: float, depth: float) -> void:
	if not running:
		return
	t_last = t
	var at := t - t0
	for name: String in on:
		var going: bool = on[name]
		if going and not _on.has(name):
			_on[name] = spans.size()
			spans.append([name, at, -1.0])
			_add(at, name + " — началось")
		elif not going and _on.has(name):
			var i: int = _on[name]
			var s: Array = spans[i]
			_on.erase(name)
			if at - s[1] < BLINK:
				_drop(i)
				continue
			s[2] = at
			_add(at, "%s — кончилось (%s)" % [name, clock(at - s[1])])
	if hull - hull_now >= HIT_MIN:
		_add(at, "удар: корпус %d%%" % roundi(hull_now))
	hull = hull_now
	deepest = maxf(deepest, depth)


## Корабль в (x, z) (шаг забега): пришёл к другому месту слоя — участок от прошлого места (кампания #824: хронометраж
## по участкам слоя, а не только по забегу). Вышел из круга и вернулся к тому же месту — участка нет.
func place(t: float, x: float, z: float) -> void:
	if not running:
		return
	var id := place_at(x, z)
	if id.is_empty() or id == _place:
		return
	var at := t - t0
	if not _place.is_empty():
		legs.append([_place, id, at - _place_at])
	_place = id
	_place_at = at


## id `LayerMap` места, в круге которого точка (x, z) (радиусы `Run.PLACES`), или "".
static func place_at(x: float, z: float) -> String:
	for k: String in Run.PLACES:
		if Vector2(x, z).distance_to(Run.place_xz(k)) < float(Run.PLACES[k][2]):
			return LayerMap.id_of(k)
	return ""


## Корпус задан не ударом (сценарий тестера ставит износ) — строка «корпус задан», в «удары» не идёт (#692).
func set_hull(t: float, pct: float) -> void:
	if not running:
		return
	if absf(pct - hull) >= HIT_MIN:
		_add(t - t0, "корпус задан: %d%%" % roundi(pct))
	hull = pct


## Разовое событие забега (сообщение на приборах, «разряд»).
func mark(t: float, text: String) -> void:
	if running and not text.is_empty():
		_add(t - t0, text)


## Конец забега: итог одной строкой, stamp — дата и время (Main даёт системные). Возвращает строки забега.
func finish(t: float, result: String, stamp := "") -> PackedStringArray:
	if not running:
		return PackedStringArray()
	var off := {}
	for k: String in _on:
		off[k] = false
	watch(t, off, hull, deepest)   # идущие события кончаются вместе с забегом
	running = false
	var lines := text_lines(result, stamp)
	if t - t0 >= SHORT:
		_n += 1
		lines[0] = "Забег %d · %s" % [_n, lines[0]]
		_old.push_front("\n".join(lines))
		_old.resize(mini(_old.size(), KEEP))
		save()
	return lines


## Записать файл: прошлые забеги и идущий («не закончен»), если он длиннее SHORT.
func save(stamp := "") -> void:
	if path.is_empty():
		return
	var blocks := _old.duplicate()
	if running and t_last - t0 >= SHORT:
		var keep := spans.duplicate(true)
		_close(t_last - t0)
		var lines := text_lines(UNFINISHED, stamp)
		lines[0] = "Забег %d · %s" % [_n + 1, lines[0]]   # шапка как у законченных (#692)
		blocks.push_front("\n".join(lines))
		spans = keep
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string("\n\n".join(blocks) + "\n")


## Забыть записанное (прогон тестера пишет свой файл с нуля).
func forget() -> void:
	_old.clear()
	_n = 0


## Строки забега: заголовок, лента, сводка.
func text_lines(result: String, stamp := "") -> PackedStringArray:
	var dur := t_last - t0
	var head := "%s · %s" % [clock(dur), result]
	if not stamp.is_empty():
		head = stamp + " · " + head
	var out := PackedStringArray([head])
	for e in events:
		out.append("%s %s" % [clock(e[0]), e[1]])
	out.append_array(summary(dur))
	return out


## Сводка: доля под событиями, самое долгое затишье, два события сразу, сколько раз какое событие, глубина.
func summary(dur: float) -> PackedStringArray:
	var busy := _covered(dur, 1)
	var both := _covered(dur, 2)
	var quiet := longest_quiet(dur)
	var out := PackedStringArray()
	out.append("Под событиями %s из %s (%d%%), два сразу — %s" % [clock(busy), clock(dur),
		roundi(100.0 * busy / maxf(dur, 1e-3)), clock(both)])
	out.append("Самое долгое затишье %s (%s–%s)" % [clock(quiet.y - quiet.x), clock(quiet.x), clock(quiet.y)])
	var count := {}
	for s in spans:
		count[s[0]] = count.get(s[0], 0) + 1
	var parts := PackedStringArray()
	for k: String in count:
		parts.append("%s ×%d" % [k, count[k]])
	var hits := 0
	for e in events:
		if String(e[1]).begins_with("удар"):
			hits += 1
	parts.append("ударов %d" % hits)
	out.append("События: %s · глубже всего %d м · корпус %d%%" % [", ".join(parts), roundi(deepest), roundi(hull)])
	if not legs.is_empty():
		var ls := PackedStringArray()
		for l: Array in legs:
			ls.append("%s→%s %s" % [l[0], l[1], clock(l[2])])
		out.append("Участки: " + " · ".join(ls))
	return out


## Самый длинный промежуток (начало, конец; с от начала забега) без идущих событий и без отметок ленты.
func longest_quiet(dur: float) -> Vector2:
	var cuts: Array[float] = [0.0, dur]
	for e in events:
		cuts.append(float(e[0]))
	cuts.sort()
	var best := Vector2.ZERO
	for i in cuts.size() - 1:
		var a := cuts[i]
		var b := cuts[i + 1]
		if b - a > best.y - best.x and not _busy_at((a + b) * 0.5, dur):
			best = Vector2(a, b)
	return best


## «мм:сс».
static func clock(s: float) -> String:
	var n := maxi(0, roundi(s))
	return "%02d:%02d" % [n / 60, n % 60]


func _add(at: float, text: String) -> void:
	events.append([at, text])


## Убрать мигнувшее событие: его отрезок и строку «началось».
func _drop(i: int) -> void:
	var s: Array = spans[i]
	spans.remove_at(i)
	for k: String in _on:
		if _on[k] > i:
			_on[k] -= 1
	for j in range(events.size() - 1, -1, -1):
		if events[j][0] == s[1] and events[j][1] == s[0] + " — началось":
			events.remove_at(j)
			break


func _close(at: float) -> void:
	for s in spans:
		if s[2] < 0.0:
			s[2] = at


## Сколько времени шло не меньше k событий сразу (идущие считаются до dur).
func _covered(dur: float, k: int) -> float:
	var edges: Array = []
	for s in spans:
		edges.append([float(s[1]), 1])
		edges.append([dur if s[2] < 0.0 else float(s[2]), -1])
	edges.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var n := 0
	var from := 0.0
	var total := 0.0
	for e in edges:
		if n >= k:
			total += e[0] - from
		n += e[1]
		from = e[0]
	return total


func _busy_at(x: float, dur: float) -> bool:
	for s in spans:
		var end: float = dur if s[2] < 0.0 else s[2]
		if x >= s[1] and x <= end:
			return true
	return false


func _load() -> void:
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	var text := FileAccess.get_file_as_string(path).strip_edges()
	if text.is_empty():
		return
	for b in text.split("\n\n", false):
		if b.begins_with("Забег "):   # и «не закончен» — игру закрыли посреди забега
			_old.append(b)
			_n = maxi(_n, b.substr(6).get_slice(" ", 0).get_slice(",", 0).to_int())   # «, не закончен» — старый файл
	_old.resize(mini(_old.size(), KEEP))
