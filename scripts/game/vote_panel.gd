class_name VotePanel
extends Control
## Решение экипажа на экране (js/run.js, панели #vote и #results): после пройденного маршрута — «глубже или наверх»
## с мнениями ролей (Run.opinions), после «наверх» — итог забега и очки. Открыт, пока игрок решает у голостола
## (Main.at_vote). В голосовании поля и метки ролей — на голограмме (VoteView), панель — справа, сбоку от стола:
## доводы ролей и подсказка крестовины. Итог: четыре строки — на голограмме (VoteView.show_result), на панели справа —
## подробности (Run.detail: время, спуски, маршруты, корпус) и очки.

const TEAL := Color(0.75, 0.95, 1.0)
const DIM := Color(0.6, 0.75, 0.8)
const UP := Color("F1A23D")      ## «наверх» — янтарный, как риск в ART-016
const DEEP := Color("67DDEB")    ## «глубже» — голубой голограммы

var title := ""
var sub := ""
var rows: Array = []     ## голосование: [кто, наверх?, почему]; итог: [название, значение]
var results := false
var foot := ""
var tally := ""         ## кооп: «голосов 1 из 2 · 12 с» (Ballot.tally) — после строки спуска
var descent := false    ## у 10 — панель «Спуск к Кристальному лесу» (#1362, `DescentVote`): rows — [текст, важное?]
var notes: Array = []   ## у 10: мнения ролей [кто, против?, почему] (`DescentVote.opinions`)
var warming := false    ## прогрев (`warm`): все кегли голосования, итога и спуска одним рисунком под шторкой


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func show_vote(depth: int, opinions: Array) -> void:
	results = false
	descent = false
	title = "Глубже или наверх?"
	sub = "Первый спуск" if depth == 0 else "Сейчас %d-й спуск" % (depth + 1)
	rows = opinions
	foot = "вверх — наверх · вниз — глубже · кнопка — позже"   # без ▲▼ (#217)
	visible = true
	queue_redraw()


## У 10 (#1362): «спуститься сейчас или позже» — что на слое не узнано (`DescentVote.unknown`) и до двух мнений
## ролей (`DescentVote.opinions`); «наверх» и очков нет.
func show_descent(unknown: Array, opinions: Array) -> void:
	results = false
	descent = true
	title = DescentVote.TITLE
	sub = DescentVote.SUB
	rows = unknown
	notes = opinions
	foot = DescentVote.FOOT
	visible = true
	queue_redraw()


func set_tally(t: String) -> void:
	tally = t
	queue_redraw()


func show_results(lines: Array, score: int) -> void:
	results = true
	descent = false
	title = "Экипаж поднялся наверх"
	sub = "Очки экспедиции: %d" % score
	rows = lines
	foot = "кнопка — новый забег"
	visible = true
	queue_redraw()


## Прогрев (WarmRunner, #519: `21a-vent` и `09d-vote` — «узлы» 60–124 мс вне шага при первом показе): под шторкой
## панель рисует буквы `UiStyle.GLYPHS` каждым своим кеглем (`warm_sizes`) — глифы в кэше шрифта до первого
## голосования и итога. on = false — снова скрыта, первый настоящий показ перерисует.
func warm(on: bool) -> void:
	warming = on
	visible = on
	queue_redraw()


## Кегли панели, px: голосование, итог и спуск у 10 (от высоты экрана, как в `_draw_descent`).
func warm_sizes() -> Array[int]:
	var out: Array[int] = [27, 24, 21, 20, 19, 17, 15]
	var k := get_viewport_rect().size.y / 720.0
	for px in [23, 17, 16, 15, 14]:
		var n := roundi(px * k)
		if not n in out:
			out.append(n)
	return out


## Прямоугольник панели: справа, над кнопкой действия, чтобы не закрывать голограмму над столом (поля голосования
## или итог).
func box() -> Rect2:
	var vis := get_viewport_rect().size
	if descent:
		return DescentVote.box(vis)
	var vw := minf(470.0, vis.x * 0.3)
	var top := vis.y * 0.21
	var bottom := DescentVote.action_top(vis) - DescentVote.GAP * vis.y / 1080.0   # не на кнопке действия (#1362)
	return Rect2(vis.x - vw - 24.0, top, vw, minf(minf(300.0, vis.y * 0.42), bottom - top))


func _draw() -> void:
	var font := get_theme_default_font()
	if warming:
		var y := 40.0
		for px in warm_sizes():
			y += px * 1.2
			_text(font, Vector2(20.0, y), UiStyle.GLYPHS, px, TEAL)
		return
	if descent:
		_draw_descent(font)
		return
	var b := box()
	draw_rect(b, Color(0.03, 0.09, 0.11, 0.88))
	draw_rect(b, Color(0.4, 0.86, 0.92, 0.6), false, 2.0)
	var pad := b.size.x * 0.05
	var x := b.position.x + pad
	var head := 1.0 if results else 0.8
	_text(font, Vector2(x, b.position.y + 42.0 * head), title, 27 if results else 24, TEAL)
	var line := sub if results or tally == "" else "%s · %s" % [sub, tally]
	_text(font, Vector2(x, b.position.y + 72.0 * head), line, 19 if results else 17, UP if results else DIM)
	var top := b.position.y + 90.0 * head
	var row_h := (b.end.y - (44.0 if results else 34.0) - top) / maxf(1.0, rows.size())
	for i in rows.size():
		var r: Array = rows[i]
		var y := top + row_h * i
		if results:
			_text(font, Vector2(x, y + row_h * 0.7), str(r[0]), 20, DIM)
			draw_string(font, Vector2(b.end.x - pad - 160.0, y + row_h * 0.7), str(r[1]), HORIZONTAL_ALIGNMENT_RIGHT,
				160.0, 21, TEAL)
		else:
			var up: bool = r[1]
			_text(font, Vector2(x, y + row_h * 0.45), "%s: %s" % [r[0], "наверх" if up else "глубже"], 19, UP if up else DEEP)
			_text(font, Vector2(x, y + row_h * 0.9), str(r[2]), 15, DIM)
	_text(font, Vector2(x, b.end.y - (14.0 if results else 10.0)), foot, 15, DIM)


## Панель спуска у 10 по макету `m10-spusk` (#1362): заголовок, подпись, «Слой 1 — не узнано» с точками (янтарь —
## важное), мнения ролей, подвал и счёт голосов. Размеры — от высоты экрана (макет — H = 720).
func _draw_descent(font: Font) -> void:
	var vis := get_viewport_rect().size
	var b := DescentVote.box(vis)
	var k := vis.y / 720.0
	var all_known: bool = rows.size() == 1 and rows[0][0] == DescentVote.ALL_KNOWN
	# высота по строкам: заголовок и подпись, блок «не узнано», мнения, подвал (и счёт голосов) — не выше места
	var h := (64.0 + (10.0 if all_known else 36.0) + 26.0 * rows.size() + 10.0 + 24.0 * notes.size() + 30.0
		+ (24.0 if tally != "" else 0.0) + 22.0) * k
	b.size.y = minf(b.size.y, h)
	draw_rect(b, Color(0.03, 0.09, 0.11, 0.88))
	draw_rect(b, Color(0.4, 0.86, 0.92, 0.6), false, 2.0)
	var x := b.position.x + 22.0 * k
	var y := b.position.y + 36.0 * k
	_text(font, Vector2(x, y), title, roundi(23 * k), TEAL)
	y += 28.0 * k
	_text(font, Vector2(x, y), sub, roundi(14 * k), DIM)
	if not all_known:   # всё узнано — одна строка, без заголовка блока
		y += 36.0 * k
		_text(font, Vector2(x, y), DescentVote.HEAD, roundi(17 * k), DEEP)
	else:
		y += 10.0 * k
	for r: Array in rows:
		y += 26.0 * k
		var c := UP if r[1] else DIM
		draw_circle(Vector2(x + 5.0 * k, y - 5.0 * k), 3.5 * k, c)
		_text(font, Vector2(x + 20.0 * k, y), str(r[0]), roundi(16 * k), c)
	y += 10.0 * k
	for r: Array in notes:
		y += 24.0 * k
		_text(font, Vector2(x, y), "%s: %s" % [r[0], r[2]], roundi(15 * k), UP if r[1] else DEEP)
	y += 30.0 * k
	_text(font, Vector2(x, y), foot, roundi(14 * k), DIM)
	if tally != "":
		y += 24.0 * k
		_text(font, Vector2(x, y), tally, roundi(14 * k), DIM)


func _text(font: Font, at: Vector2, t: String, size_px: int, c: Color) -> void:
	draw_string(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, c)
