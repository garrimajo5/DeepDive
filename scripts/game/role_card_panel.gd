class_name RoleCardPanel
extends Control
## Карточка роли у поста ART-045, «?» и плашка чужой роли (состояние и места — `RoleCard`). Касания идут через
## `Touch.Router.blocks`/`taps` (`Main._card_step`), сам узел их не ловит. Палитра ART-028/038, красного нет.

const TEXT := Color("D5E4E8")
const DIM := Color("9AD9E8")
const ACCENT := Color("67DDEB")
const DARK := Color("0B1C24")
const BACK := Color(0.043, 0.11, 0.141, 244.0 / 255.0)   ## #0B1C24, альфа 244

var card: RoleCard
var rect := Rect2()   ## место карточки этого кадра (`RoleCard.card_rect`); пусто — карточки нет
var atlas: Texture2D


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	atlas = load(RoleCard.ATLAS)


func show_card(c: RoleCard, r: Rect2) -> void:
	card = c
	rect = r
	var vis := c != null and (c.a > 0.0 or c.q > 0.0 or c.f > 0.0)
	if vis != visible:
		visible = vis
	if vis:
		queue_redraw()


func _box(r: Rect2, s: float, a: float, fill: Color = BACK, border: Color = ACCENT, radius := 12.0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(fill, fill.a * a)
	sb.border_color = Color(border, border.a * a)
	sb.set_border_width_all(maxi(1, roundi(2.0 * s)))
	sb.set_corner_radius_all(roundi(radius * s))
	draw_style_box(sb, r)


func _draw() -> void:
	if card == null:
		return
	var size := get_viewport_rect().size
	var s := size.y / RoleCard.REF_H
	var font := get_theme_default_font()
	var id := card.post
	if card.a > 0.0 and rect.has_area() and RoleCard.CARDS.has(id):
		var a := card.a
		var o := rect.position
		_box(rect, s, a)
		if atlas != null:
			draw_texture_rect_region(atlas, Rect2(o + RoleCard.ICON.position * s, RoleCard.ICON.size * s),
				RoleCard.cell(id), Color(1, 1, 1, a))
		draw_string(font, o + RoleCard.TITLE_AT * s, RoleCard.title(id), HORIZONTAL_ALIGNMENT_LEFT, -1,
			int(RoleCard.TITLE_PX * s), Color(TEXT, a))
		var c := o + RoleCard.LETTER_C * s
		var rad := RoleCard.LETTER_D * 0.5 * s
		draw_arc(c, rad, 0.0, TAU, 48, Color(TEXT, a), maxf(1.5, 2.5 * s), true)
		var lpx := int(RoleCard.LETTER_PX * s)
		var lw := font.get_string_size(RoleCard.letter(id), HORIZONTAL_ALIGNMENT_LEFT, -1, lpx).x
		draw_string(font, c + Vector2(-lw * 0.5, lpx * 0.36), RoleCard.letter(id), HORIZONTAL_ALIGNMENT_LEFT, -1, lpx,
			Color(TEXT, a))
		var lines := RoleCard.lines(id)
		var maxw := rect.size.x - 2.0 * RoleCard.LINES_AT.x * s
		for i in lines.size():   # длинная строка (энергия) — мельче, но целиком
			var px := int(RoleCard.LINE_PX * s)
			var w := font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			if w > maxw:
				px = int(px * maxw / w)
			draw_string(font, o + (RoleCard.LINES_AT + Vector2(0, RoleCard.LINE_STEP * i)) * s, lines[i],
				HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(TEXT if i == 0 else DIM, a))
		var b := RoleCard.button_rect(rect, size)
		_box(b, s, a, ACCENT, ACCENT, 10.0)
		var bpx := int(RoleCard.BUTTON_PX * s)
		draw_string(font, Vector2(b.position.x, b.get_center().y + bpx * 0.36), RoleCard.OK_TEXT,
			HORIZONTAL_ALIGNMENT_CENTER, b.size.x, bpx, Color(DARK, a))
	if card.q > 0.0:
		var r := RoleCard.ask_rect(size, card.status)
		_box(r, s, card.q)
		var qpx := int(RoleCard.ASK_PX * s)
		draw_string(font, Vector2(r.position.x, r.get_center().y + qpx * 0.36), "?", HORIZONTAL_ALIGNMENT_CENTER,
			r.size.x, qpx, Color(ACCENT, card.q))
	if card.f > 0.0 and RoleCard.CARDS.has(card.foreign):
		var r := RoleCard.foreign_rect(size)
		_box(r, s, card.f, BACK, Color(DIM, 0.6))
		var p1 := int(RoleCard.FOREIGN_PX.x * s)
		var p2 := int(RoleCard.FOREIGN_PX.y * s)
		draw_string(font, Vector2(r.position.x, r.position.y + 62.0 * s), RoleCard.foreign_title(card.foreign),
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, p1, Color(TEXT, card.f))
		draw_string(font, Vector2(r.position.x, r.position.y + 112.0 * s), RoleCard.FOREIGN_SUB,
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, p2, Color(DIM, card.f))
