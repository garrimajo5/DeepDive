class_name TagParts
extends RefCounted
## Общие детали табличек над экипажем ART-033 (#762): флаги (без света, двусторонние, без билборда, без тени, слой
## корабля), `Sprite3D` и `Label3D` с размером в высотах плашки, табличка «плашка + буква роли + имя» и её ключ.
## Берут `NameTagView` (табличка над головой) и `BusyMarkView` (та же табличка на метке «Занято»).

const FONT_PX := 64


static func flags(g: GeometryInstance3D) -> void:
	g.set("shaded", false)
	g.set("double_sided", true)
	g.set("alpha_cut", SpriteBase3D.ALPHA_CUT_DISABLED)
	g.set("billboard", BaseMaterial3D.BILLBOARD_DISABLED)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.layers = OceanView.LAYER_SHIP


static func sprite(nm: String, prio: int) -> Sprite3D:
	var s := Sprite3D.new()
	s.name = nm
	flags(s)
	s.render_priority = prio
	return s


## Надпись высотой em (доля высоты плашки).
static func label(nm: String, em: float, prio: int) -> Label3D:
	var l := Label3D.new()
	l.name = nm
	flags(l)
	l.font_size = FONT_PX
	l.outline_size = 0
	l.pixel_size = em / FONT_PX
	l.render_priority = prio
	return l


## Ширина текста высотой em в высотах плашки.
static func text_w(text: String, em: float) -> float:
	return ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX).x * em / FONT_PX


## Ключ таблички: роль, подпись и связь — под него собраны текстуры.
static func key(m: Crew.Member) -> String:
	return "%d|%s|%s" % [m.role, NameTag.label(m.name, m.role), m.lost]


## Табличка в parent: плашка (имя plate_name, приоритет prio), буква роли и имя (prio + 1). [плашка, буква, имя].
static func add(parent: Node3D, plate_name: String, prio: int) -> Array:
	var s := sprite(plate_name, prio)
	parent.add_child(s)
	var l := label("Буква роли", NameTag.LETTER_EM, prio + 1)
	parent.add_child(l)
	var n := label("Имя", NameTag.NAME_EM, prio + 1)
	parent.add_child(n)
	return [s, l, n]


## Табличка под занявшего: плашка ширины pw (текстура tex), буква и имя (ширина tw) от центра pc, имя на высоте name_y.
static func fill(parts: Array, m: Crew.Member, tex: Texture2D, pw: float, tw: float, pc := 0.0, name_y := 0.0) -> void:
	var plate: Sprite3D = parts[0]
	plate.texture = tex
	plate.pixel_size = 1.0 / NameTag.TEX_H
	var letter: Label3D = parts[1]
	letter.text = NameTag.letter(m.role)
	letter.position = Vector3(pc + NameTag.letter_x(pw), 0.0, 0.01)
	var nm: Label3D = parts[2]
	nm.text = NameTag.label(m.name, m.role)
	nm.position = Vector3(pc + NameTag.name_x(pw, tw), name_y, 0.01)
