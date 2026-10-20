class_name VotePanel
extends Control
## Решение экипажа на экране (js/run.js, панели #vote и #results): после пройденного маршрута — «глубже или наверх»
## с мнениями ролей (Run.opinions), после «наверх» — итог забега и очки. Открыт, пока игрок решает у голостола
## (Main.at_vote). В голосовании поля и метки ролей — на голограмме (VoteView), панель — справа, сбоку от стола:
## доводы ролей и подсказка крестовины. Итог на голограмме — позже.

const TEAL := Color(0.75, 0.95, 1.0)
const DIM := Color(0.6, 0.75, 0.8)
const UP := Color("F1A23D")      ## «наверх» — янтарный, как риск в ART-016
const DEEP := Color("67DDEB")    ## «глубже» — голубой голограммы

var title := ""
var sub := ""
var rows: Array = []     ## голосование: [кто, наверх?, почему]; итог: [название, значение]
var results := false
var foot := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func show_vote(depth: int, opinions: Array) -> void:
	results = false
	title = "Глубже или наверх?"
	sub = "Первый спуск" if depth == 0 else "Сейчас %d-й спуск" % (depth + 1)
	rows = opinions
	foot = "▲ — наверх · ▼ — глубже · кнопка — позже"
	visible = true
	queue_redraw()


func show_results(lines: Array, score: int) -> void:
	results = true
	title = "Экипаж поднялся наверх"
	sub = "Очки экспедиции: %d" % score
	rows = lines
	foot = "кнопка — новый забег"
	visible = true
	queue_redraw()


## Прямоугольник панели: итог — по центру, ниже четырёх строк приборов; голосование — справа, над кнопкой действия,
## чтобы не закрывать поля голосования над столом.
func box() -> Rect2:
	var vis := get_viewport_rect().size
	if not results:
		var vw := minf(470.0, vis.x * 0.3)
		return Rect2(vis.x - vw - 24.0, vis.y * 0.21, vw, minf(300.0, vis.y * 0.42))
	var w := minf(640.0, vis.x * 0.44)
	var h := minf(400.0, vis.y * 0.56)
	return Rect2((vis.x - w) * 0.5, vis.y * 0.22, w, h)


func _draw() -> void:
	var font := get_theme_default_font()
	var b := box()
	draw_rect(b, Color(0.03, 0.09, 0.11, 0.88))
	draw_rect(b, Color(0.4, 0.86, 0.92, 0.6), false, 2.0)
	var pad := b.size.x * 0.05
	var x := b.position.x + pad
	var head := 1.0 if results else 0.8
	_text(font, Vector2(x, b.position.y + 42.0 * head), title, 27 if results else 24, TEAL)
	_text(font, Vector2(x, b.position.y + 72.0 * head), sub, 19 if results else 17, UP if results else DIM)
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


func _text(font: Font, at: Vector2, t: String, size_px: int, c: Color) -> void:
	draw_string(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, c)
