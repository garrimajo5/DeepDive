extends TestCase
## Метка «Занято» на посту, занятом другим (ART-033): замок, «Занято», табличка занявшего; видна до 3 м,
## свой пост не помечается, табличка над головой занявшего при видной метке скрыта.

var main: Main


func before() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)


func after() -> void:
	main.queue_free()
	await frames(1)


func test_marks_only_others() -> void:
	var me := Crew.Member.new(Crew.Role.PILOT)
	var mate := Crew.Member.new(Crew.Role.ENGINEER, "Игрок 2")
	eq(BusyMark.marks([me, mate], me).size(), 0, "никто не держит пост — меток нет")
	mate.post = "energy"
	var mk := BusyMark.marks([me, mate], me)
	eq(mk.size(), 1, "пульт держит товарищ — одна метка")
	eq(mk[0][0], "energy")
	ok(mk[0][1] == mate, "на метке — занявший")
	me.post = "energy"
	eq(BusyMark.marks([me], me).size(), 0, "свой пост не помечается")
	for id: String in Crew.BUSY:
		ok(BusyMark.ANCHORS.has(id), "у поста %s есть место метки" % id)


func test_alpha_by_distance() -> void:
	near(BusyMark.alpha(1.0), 1.0, 1e-6, "вблизи — полностью")
	near(BusyMark.alpha(2.75), 0.5, 1e-6, "гаснет к 3 м")
	ok(not BusyMark.shown(3.2), "дальше 3 м не видна")


func test_panel_image_lock() -> void:
	var w := BusyMark.width(1.5, NameTag.width(1.5))
	var img := BusyMark.panel_image(w)
	eq(img.get_height(), BusyMark.TEX_H)
	var px := BusyMark.TEX_H / BusyMark.H
	var lx := roundi((BusyMark.PAD + BusyMark.LOCK_X - BusyMark.LOCK_W * 0.5) * px)   # левая стенка корпуса
	var ly := roundi(BusyMark.TEX_H * 0.5 - BusyMark.LOCK_Y * px)
	var c := img.get_pixel(lx, ly)
	ok(c.r > 0.6 and c.a > 0.8, "контур замка светлый (%s)" % c)
	var inside := img.get_pixel(roundi((BusyMark.PAD + BusyMark.LOCK_X) * px), ly)
	ok(inside.r < 0.3, "внутри замка — фон, только контур (%s)" % inside)
	near(img.get_pixel(0, 0).a, 0.0, 0.05, "углы скруглены")
	ok(BusyMark.tag_x(1.5) + NameTag.width(1.5) < w, "табличка в подложке")


func _helm_mate() -> Crew.Member:
	var mate := main.add_mate(0.0, Deck.SEAT_Z, 0.0, Crew.Role.PILOT, 1, true)
	mate.name = "Марина"
	return mate


func test_helm_mark_near_and_far() -> void:
	var mate := _helm_mate()
	var i := main.crew.find(mate)
	main.walker.x = 0.6
	main.walker.z = Deck.CHAIR_Z + 1.3
	main.walker.yaw = 0.0
	main.step(1.0 / 30.0)
	var v := main.busy_marks
	ok(v.roots["helm"].visible, "у штурвала, занятого другим, — метка")
	ok(not v.roots["energy"].visible, "пульт свободен — метки нет")
	eq(v.words["helm"].text, "Занято")
	eq(v.names["helm"].text, "Марина", "на метке имя занявшего")
	eq(v.letters["helm"].text, "П", "и буква роли")
	ok(not main.name_tags.tags[i].visible, "табличка над головой скрыта — она на метке")
	var p: Vector3 = v.roots["helm"].position
	ok(p.y > 1.4 and p.y < 2.0, "над колесом штурвала (%.2f м)" % p.y)
	main.walker.z = 1.0   # дальше 3 м от штурвала
	main.step(1.0 / 30.0)
	ok(not v.roots["helm"].visible, "дальше 3 м метки нет")
	ok(main.name_tags.tags[i].visible, "издали — обычная табличка над головой")


func test_own_post_unmarked() -> void:
	main.walker.x = 0.6
	main.walker.z = Deck.CHAIR_Z + 0.9
	main.sit_at_helm()
	main.step(1.0 / 30.0)
	ok(not main.busy_marks.roots["helm"].visible, "сам за штурвалом — метки нет")


func test_energy_mark() -> void:
	var mate := main.add_mate(-3.5, -2.0, PI * 0.5, Crew.Role.ENGINEER, 0)
	mate.pad.action = true   # своей кнопкой — к пульту
	main.step(1.0 / 30.0)
	eq(mate.post, "energy", "инженер у пульта")
	main.walker.x = -2.6
	main.walker.z = -1.2
	main.walker.yaw = PI * 0.5
	main.step(1.0 / 30.0)
	var v := main.busy_marks
	ok(v.roots["energy"].visible, "у пульта, занятого другим, — метка")
	eq(v.letters["energy"].text, "И")
	var p: Vector3 = v.roots["energy"].position
	ok(p.x > BridgeProps.ENERGY_POS.x, "метка перед пультом, не в стене (x %.2f)" % p.x)


func test_hidden_on_flyby() -> void:
	_helm_mate()
	main.walker.x = 0.6
	main.walker.z = Deck.CHAIR_Z + 1.3
	main.flyby.start(Flyby.Kind.START)
	main.step(1.0 / 30.0)
	ok(not main.busy_marks.roots["helm"].visible, "на облёте с борта метки нет")
