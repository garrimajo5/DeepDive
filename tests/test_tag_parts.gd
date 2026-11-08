extends TestCase
## Общие детали табличек ART-033 (#762): `TagParts` и таблички `NameTagView` / метки «Занято» `BusyMarkView` на них.


func _mate(name: String, role: int, lost := false) -> Crew.Member:
	var m := Crew.Member.new()
	m.name = name
	m.role = role
	m.lost = lost
	return m


func test_flags_and_parts() -> void:
	var l := TagParts.label("Имя", NameTag.NAME_EM, 2)
	eq(l.font_size, TagParts.FONT_PX, "шрифт")
	near(l.pixel_size, NameTag.NAME_EM / TagParts.FONT_PX, 1e-9, "размер в высотах плашки")
	eq(l.render_priority, 2, "приоритет")
	ok(not l.shaded and l.double_sided, "без света, двусторонняя")
	eq(l.billboard, BaseMaterial3D.BILLBOARD_DISABLED, "без билборда")
	eq(l.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "без тени")
	eq(l.layers, OceanView.LAYER_SHIP, "слой корабля")
	var s := TagParts.sprite("Плашка", 1)
	ok(not s.shaded and s.double_sided, "спрайт без света")
	eq(s.alpha_cut, SpriteBase3D.ALPHA_CUT_DISABLED, "без отсечения")
	eq(s.render_priority, 1, "приоритет спрайта")
	l.free()
	s.free()


func test_tag_fill() -> void:
	var root := Node3D.new()
	var parts := TagParts.add(root, "Табличка", 2)
	eq(root.get_child_count(), 3, "плашка, буква, имя")
	eq((parts[1] as Label3D).render_priority, 3, "надписи над плашкой")
	var m := _mate("Игорь", 1)
	var tw := TagParts.text_w(NameTag.label(m.name, m.role), NameTag.NAME_EM)
	ok(tw > 0.0, "ширина имени")
	var pw := NameTag.width(tw)
	var tex := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	TagParts.fill(parts, m, tex, pw, tw, 0.3, 0.1)
	ok((parts[0] as Sprite3D).texture == tex, "текстура плашки")
	near((parts[0] as Sprite3D).pixel_size, 1.0 / NameTag.TEX_H, 1e-9, "плашка высотой 1")
	eq((parts[1] as Label3D).text, NameTag.letter(1), "буква роли")
	near((parts[1] as Label3D).position.x, 0.3 + NameTag.letter_x(pw), 1e-6, "буква от центра")
	eq((parts[2] as Label3D).text, NameTag.label("Игорь", 1), "имя")
	near((parts[2] as Label3D).position.y, 0.1, 1e-6, "высота имени")
	root.free()


func test_key_by_role_name_link() -> void:
	eq(TagParts.key(_mate("Игорь", 1)), TagParts.key(_mate("Игорь", 1)), "тот же ключ")
	ok(TagParts.key(_mate("Игорь", 1)) != TagParts.key(_mate("Игорь", 2)), "роль")
	ok(TagParts.key(_mate("Игорь", 1)) != TagParts.key(_mate("Аня", 1)), "имя")
	ok(TagParts.key(_mate("Игорь", 1)) != TagParts.key(_mate("Игорь", 1, true)), "связь")


func test_views_built_from_parts() -> void:
	var v := NameTagView.new()
	v._add()
	var m := _mate("Игорь", 2, true)
	v._build(0, m)
	eq(v.keys[0], TagParts.key(m), "ключ таблички — TagParts.key")
	eq(v.letters[0].text, NameTag.letter(2), "буква")
	near(v.names[0].position.y, NameTag.LOST_NAME_Y, 1e-6, "без связи имя выше")
	ok(v.states[0].visible, "«Нет связи»")
	eq(v.plates[0].render_priority, 1, "плашка таблички")
	eq(v.names[0].render_priority, 2, "имя таблички")
	v.free()
	var b := BusyMarkView.new()
	b._add("helm")
	var e := b._entry(_mate("Аня", 1))
	b._build("helm", _mate("Аня", 1))
	eq(e["key"], TagParts.key(_mate("Аня", 1)), "кэш по TagParts.key")
	eq(b.plates["helm"].render_priority, 2, "плашка метки над подложкой")
	eq(b.names["helm"].render_priority, 3, "имя метки")
	near(b.plates["helm"].position.z, 0.005, 1e-9, "плашка чуть перед подложкой")
	eq(b.letters["helm"].text, NameTag.letter(1), "буква на метке")
	b.free()
