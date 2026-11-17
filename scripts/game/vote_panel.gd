class_name VotePanel
extends Control
## Решение экипажа на экране (js/run.js, панели #vote и #results): после пройденного маршрута — «глубже или наверх»
## с мнениями ролей (Run.opinions), после «наверх» — итог забега и очки. Открыт, пока игрок решает у голостола
## (Main.at_vote). В голосовании поля и метки ролей — на голограмме (VoteView), панель — справа, сбоку от стола:
## доводы ролей и подсказка крестовины. Итог: четыре строки — на голограмме (VoteView.show_result), на панели справа —
## подробности (Run.detail: время, спуски, маршруты, корпус) и очки. Места строк и кегли — `VoteLayout` (#1970: основной
## текст не мельче 12 sp на 6", второй план — 10 sp), здесь — только рисунок.

const TEAL := VoteLayout.TEAL

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
	foot = VoteLayout.FOOT
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
	foot = VoteLayout.FOOT_RESULTS
	visible = true
	queue_redraw()


## Прогрев (WarmRunner, #519: `21a-vent` и `09d-vote` — «узлы» 60–124 мс вне шага при первом показе): под шторкой
## панель рисует буквы `UiStyle.GLYPHS` каждым своим кеглем (`warm_sizes`) — глифы в кэше шрифта до первого
## голосования и итога. on = false — снова скрыта, первый настоящий показ перерисует.
func warm(on: bool) -> void:
	warming = on
	visible = on
	queue_redraw()


## Кегли панели на экране, px: голосование, итог и спуск у 10 (`VoteLayout.sizes`).
func warm_sizes() -> Array[int]:
	return VoteLayout.sizes(get_viewport_rect().size)


## Раскладка панели сейчас (`VoteLayout`): рамка, строки и точки — по тому, что показано.
func layout() -> Dictionary:
	var vis := get_viewport_rect().size
	if descent:
		return VoteLayout.descent(vis, title, sub, rows, notes, foot, tally)
	if results:
		return VoteLayout.results(vis, title, sub, rows, foot)
	return VoteLayout.vote(vis, title, sub, tally, rows, foot)


## Прямоугольник панели: справа, над кнопкой действия, чтобы не закрывать голограмму над столом (поля голосования
## или итог); высота — по содержимому.
func box() -> Rect2:
	return layout()["box"]


func _draw() -> void:
	var font := get_theme_default_font()
	if warming:
		var y := 40.0
		for px in warm_sizes():
			y += px * 1.2
			_text(font, Vector2(20.0, y), UiStyle.GLYPHS, px, TEAL)
		return
	var l := layout()
	var b: Rect2 = l["box"]
	draw_rect(b, Color(0.03, 0.09, 0.11, 0.88))
	draw_rect(b, Color(0.4, 0.86, 0.92, 0.6), false, 2.0)
	for d: Dictionary in l["dots"]:
		draw_circle(d["at"], d["r"], d["c"])
	for r: Dictionary in l["lines"]:
		if r["w"] > 0.0:
			draw_string(font, r["at"], r["t"], HORIZONTAL_ALIGNMENT_RIGHT, r["w"], r["px"], r["c"])
		else:
			_text(font, r["at"], r["t"], r["px"], r["c"])


func _text(font: Font, at: Vector2, t: String, size_px: int, c: Color) -> void:
	draw_string(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, c)
