class_name VoteLayout
extends RefCounted
## Раскладка панелей решения экипажа без узлов (#1970, макет UX): «Глубже или наверх?», итог забега и «Спуск к
## Кристальному лесу» у 10. Правило кегля на 6": основной текст (по нему решают — «Роль: решение», пункты
## «не узнано», строки итога) — не мельче MAIN, второй план (причины, подсказки, счёт) — не мельче SECOND; все
## числа — px при H = 720, на экране × k = H / 720. Не влезает по высоте — сжимаются зазоры, не кегль (`fit`).
## Отдаёт {"box": Rect2, "lines": [строка…], "dots": [точка…]}: строка — {"t" текст, "at" базовая линия слева,
## "px" кегль, "c" цвет, "main" основной?, "w" ширина поля для выравнивания вправо (0 — влево)}, точка — {"at",
## "r", "c"}. Рисует `VotePanel`, место по ширине и над кнопкой действия — `DescentVote.width`/`action_top`.

const TEAL := Color(0.75, 0.95, 1.0)
const DIM := Color(0.6, 0.75, 0.8)
const UP := Color("F1A23D")      ## «наверх» — янтарный, как риск в ART-016
const DEEP := Color("67DDEB")    ## «глубже» — голубой голограммы

const HEAD := 24.0     ## заголовок панели
const BIG := 27.0      ## заголовок итога
const MAIN := 22.0     ## основной текст — 12 sp на 6"
const SECOND := 18.0   ## второй план — 10 sp на 6"
const PAD := 16.0      ## поле слева и справа
const TOP := 0.17      ## верх общей панели — доля высоты экрана (под строками приборов)
const FOOT := "вниз — глубже · вверх — наверх"   ## без ▲▼ (#217); «позже» — на кнопке действия
const FOOT_RESULTS := "кнопка — новый забег"


static func scale(vis: Vector2) -> float:
	return vis.y / 720.0


## Кегль на экране: вверх до целого — не мельче предела и после округления.
static func px(size: float, vis: Vector2) -> int:
	return ceili(size * scale(vis) - 0.001)


## Все кегли панелей на экране vis — для прогрева глифов (`VotePanel.warm_sizes`).
static func sizes(vis: Vector2) -> Array[int]:
	var out: Array[int] = []
	for s: float in [BIG, HEAD, MAIN, SECOND]:
		if not px(s, vis) in out:
			out.append(px(s, vis))
	return out


## Место под панель: справа, от доли top высоты до зазора над кнопкой действия.
static func room(vis: Vector2, top: float) -> Rect2:
	var k := scale(vis)
	var vw := DescentVote.width(vis)
	var bottom := DescentVote.action_top(vis) - DescentVote.GAP * vis.y / 1080.0
	return Rect2(vis.x - vw - 24.0 * k, vis.y * top, vw, maxf(0.0, bottom - vis.y * top))


## «Глубже или наверх?»: заголовок, подпись со счётом голосов, мнения rows — [кто, наверх?, почему], подсказка.
static func vote(vis: Vector2, title: String, sub: String, tally: String, rows: Array, foot: String) -> Dictionary:
	var p := Pen.new(vis, room(vis, TOP))
	p.add(30.0, title, HEAD, TEAL, true)
	p.add(26.0, sub if tally == "" else "%s · %s" % [sub, tally], SECOND, DIM, false)
	p.gap(12.0)
	for r: Array in rows:
		var up: bool = r[1]
		p.add(24.0, "%s: %s" % [r[0], "наверх" if up else "глубже"], MAIN, UP if up else DEEP, true)
		p.add(22.0, str(r[2]), SECOND, DIM, false)
		p.gap(6.0)
	p.add(24.0, foot, SECOND, DIM, false)
	return p.done(12.0)


## Итог забега: заголовок, очки, строки rows — [название, значение] (значение — у правого поля), подсказка.
static func results(vis: Vector2, title: String, sub: String, rows: Array, foot: String) -> Dictionary:
	var p := Pen.new(vis, room(vis, TOP))
	p.add(36.0, title, BIG, TEAL, true)
	p.add(30.0, sub, MAIN, UP, true)
	p.gap(8.0)
	for r: Array in rows:
		p.add(32.0, str(r[0]), MAIN, DIM, true)
		p.right(str(r[1]), MAIN, TEAL, true)
	p.add(34.0, foot, SECOND, DIM, false)
	return p.done(14.0)


## Спуск у 10 (макет `m10-spusk`, #1362): заголовок, подпись, «Слой 1 — не узнано» с точками rows — [текст,
## важное?] (янтарь — важное), мнения notes — [кто, против?, почему], подсказка и счёт голосов.
static func descent(vis: Vector2, title: String, sub: String, rows: Array, notes: Array, foot: String,
		tally: String) -> Dictionary:
	var p := Pen.new(vis, room(vis, DescentVote.TOP))
	var all_known: bool = rows.size() == 1 and rows[0][0] == DescentVote.ALL_KNOWN
	p.add(32.0, title, HEAD, TEAL, true)
	p.add(26.0, sub, SECOND, DIM, false)
	if all_known:   # всё узнано — одна строка, без заголовка блока
		p.gap(6.0)
	else:
		p.add(34.0, DescentVote.HEAD, MAIN, DEEP, true)
	for r: Array in rows:
		var c := UP if r[1] else DIM
		p.add(29.0, str(r[0]), MAIN, c, true, 20.0)
		p.dot(c)
	p.gap(8.0)
	for r: Array in notes:
		p.add(25.0, "%s: %s" % [r[0], r[2]], SECOND, UP if r[1] else DEEP, false)
	p.add(30.0, foot, SECOND, DIM, false)
	if tally != "":
		p.add(25.0, tally, SECOND, DIM, false)
	return p.done(12.0)


## Перо: копит строки сверху вниз шагами при H = 720, в `done` сжимает шаги под высоту места.
class Pen:
	var k := 1.0
	var area := Rect2()
	var y := 0.0          ## базовая линия последней строки от верха панели, px при H = 720
	var lines: Array = []
	var dots: Array = []

	func _init(vis: Vector2, room: Rect2) -> void:
		k = vis.y / 720.0
		area = room

	func gap(step: float) -> void:
		y += step

	## Строка: step — от прошлой базовой линии до этой; indent — отступ от левого поля.
	func add(step: float, t: String, size: float, c: Color, main: bool, indent := 0.0) -> void:
		y += step
		lines.append({"t": t, "y": y, "x": VoteLayout.PAD + indent, "size": size, "c": c, "main": main, "w": 0.0})

	## Значение у правого поля — на базовой линии последней строки.
	func right(t: String, size: float, c: Color, main: bool) -> void:
		lines.append({"t": t, "y": y, "x": VoteLayout.PAD, "size": size, "c": c, "main": main, "w": -1.0})

	## Точка слева от последней строки (маркер пункта).
	func dot(c: Color) -> void:
		dots.append({"y": y - 7.0, "x": VoteLayout.PAD + 6.0, "r": 4.0, "c": c})

	## Готовая раскладка: pad — поле под последней строкой. Выше места — шаги сжаты (кегль тот же).
	func done(pad: float) -> Dictionary:
		var h := (y + pad) * k
		var s := VoteLayout.fit(h, area.size.y)
		var box := Rect2(area.position, Vector2(area.size.x, h * s))
		var vis := Vector2(0.0, k * 720.0)
		var out_lines := []
		for l: Dictionary in lines:
			var at := box.position + Vector2(l["x"] * k, l["y"] * k * s)
			out_lines.append({"t": l["t"], "at": at, "px": VoteLayout.px(l["size"], vis), "c": l["c"],
				"main": l["main"], "w": box.size.x - 2.0 * VoteLayout.PAD * k if l["w"] < 0.0 else 0.0})
		var out_dots := []
		for d: Dictionary in dots:
			out_dots.append({"at": box.position + Vector2(d["x"] * k, d["y"] * k * s), "r": d["r"] * k, "c": d["c"]})
		return {"box": box, "lines": out_lines, "dots": out_dots}


## Во сколько раз сжать шаги строк, чтобы раскладка высотой h вошла в место room (1 — входит и так).
static func fit(h: float, room: float) -> float:
	return 1.0 if h <= room or h <= 0.0 else room / h
