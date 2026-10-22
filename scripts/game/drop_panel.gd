class_name DropPanel
extends Control
## Диалог «Связь с хостом потеряна» (ART-043) поверх затемнённого последнего кадра хоста; подтверждение
## «Продолжить одному?»; плашка «Связь восстановлена». Состояние, тексты и места — `NetDrop`. У хоста — плашка
## «Игорь отключился» / «Игорь вернулся» (`HostNotice`). Палитра ART-028, ничего красного.

const TEXT := Color("D5E4E8")
const DIM := Color("9AD9E8")
const ACCENT := Color("67DDEB")
const BACK := Color("0B1C24")
const BTN := Color("11293A")
const DARK_TEXT := Color("0B1C24")

var drop: NetDrop
var notice: HostNotice


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func show_drop(d: NetDrop) -> void:
	drop = d
	_refresh()


## Уведомление хоста о госте (ART-043): плашка поверх сцены, кнопки под ней работают.
func show_notice(n: HostNotice) -> void:
	notice = n
	_refresh()


func _refresh() -> void:
	visible = (drop != null and drop.active()) or (notice != null and notice.active())
	if visible:
		queue_redraw()


func _draw() -> void:
	var size := get_viewport_rect().size
	var s := size.y / NetDrop.REF_H
	var font := get_theme_default_font()
	if notice != null and notice.active():
		var a := notice.alpha()
		var nb := NetDrop.to_screen(HostNotice.BOX, size)
		draw_rect(nb, Color(BACK, 0.92 * a))
		draw_rect(nb, Color(ACCENT, 0.8 * a), false, 2.0)
		var one := notice.sub == ""
		_center(font, nb, (104.0 if one else 72.0) * s, notice.title, 44.0 * s, Color(TEXT, a))
		_center(font, nb, 130.0 * s, notice.sub, 32.0 * s, Color(DIM, a))
	if drop == null or not drop.active():
		return
	var l := drop.lines()
	if drop.phase == NetDrop.Phase.BACK:
		var b := NetDrop.to_screen(NetDrop.BACK_BOX, size)
		_panel(b, 0.92)
		_center(font, b, 52.0 * s, l[0], 40.0 * s, TEXT)
		_center(font, b, 100.0 * s, l[1], 28.0 * s, DIM)
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.02, 0.03, 0.55))   # затемнённый последний кадр хоста
	var confirm := drop.phase == NetDrop.Phase.CONFIRM_SOLO or drop.phase == NetDrop.Phase.CONFIRM_MENU
	var box := NetDrop.to_screen(NetDrop.BOX, size)
	_panel(box, 0.96)
	var under: String = l[0] if not confirm else "Связь с хостом потеряна"
	_center(font, box, 92.0 * s, under, 56.0 * s, Color(TEXT, 0.35 if confirm else 1.0))
	if not confirm:
		_center(font, box, 165.0 * s, l[1], 36.0 * s, DIM)
		_center(font, box, 220.0 * s, l[2], 32.0 * s, DIM)
		_center(font, box, 330.0 * s, l[3], 42.0 * s, ACCENT)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.02, 0.03, 0.45))
		var c := NetDrop.to_screen(NetDrop.CONFIRM_BOX, size)
		_panel(c, 0.98)
		_center(font, c, 90.0 * s, l[0], 44.0 * s, TEXT)
		_center(font, c, 160.0 * s, l[1], 32.0 * s, DIM)
		_center(font, c, 210.0 * s, l[2], 32.0 * s, DIM)
	for b: Array in drop.buttons():
		var r := NetDrop.to_screen(NetDrop.BUTTONS[b[0]], size)
		var main_btn: bool = b[2]
		var on: bool = b[3]
		var fill := ACCENT if main_btn else BTN
		draw_rect(r, Color(fill, 1.0 if on else 0.35))
		if not main_btn:
			draw_rect(r, Color(ACCENT, 0.45 if on else 0.2), false, maxf(1.0, 2.0 * s))
		var col := DARK_TEXT if main_btn else TEXT
		_center(font, r, r.size.y * 0.5 + 12.0 * s, b[1], 34.0 * s, Color(col, 1.0 if on else 0.45))


func _panel(r: Rect2, a: float) -> void:
	draw_rect(r, Color(BACK, a))
	draw_rect(r, Color(ACCENT, 0.8), false, 2.0)


## Строка по центру прямоугольника r, базовая линия — на y от его верха.
func _center(font: Font, r: Rect2, y: float, text: String, px: float, color: Color) -> void:
	if text == "":
		return
	draw_string(font, Vector2(r.position.x, r.position.y + y), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x,
		int(px), color)
