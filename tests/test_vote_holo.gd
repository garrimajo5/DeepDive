extends TestCase
## Голосование «глубже или наверх» на голограмме над голостолом (ART-016): поля, метки ролей, счёт, рельеф гаснет.


func test_votes_follow_opinions() -> void:
	var calm := VoteHolo.votes(Run.opinions(100.0, 100.0, false, false, 0))
	eq(calm["deep"], [0, 1, 2, 3], "всё в порядке — все четыре роли за «глубже»")
	eq(calm["up"], [])
	# горячий реактор и полный трюм: инженер и биолог — наверх
	var v := VoteHolo.votes(Run.opinions(100.0, 100.0, true, false, 5))
	eq(v["deep"], [Crew.Role.PILOT, Crew.Role.SONAR], "порядок — как у ролей")
	eq(v["up"], [Crew.Role.ENGINEER, Crew.Role.BIOLOGIST])
	eq(VoteHolo.letter(Crew.Role.SONAR), "С")
	eq(VoteHolo.letter(Crew.Role.ENGINEER), "И")


func test_layout() -> void:
	var d := VoteHolo.field_pos("deep")
	var u := VoteHolo.field_pos("up")
	ok(d.z > 0.0 and u.z < 0.0, "от поста «Маршрут» (+X, взгляд к −X) «глубже» слева, «наверх» справа")
	eq(d.x, 0.0)
	ok(VoteHolo.WORD_Y > VoteHolo.ARROW_Y and VoteHolo.ARROW_Y > VoteHolo.DISC_Y and VoteHolo.DISC_Y > VoteHolo.MARK_Y
		and VoteHolo.MARK_Y > VoteHolo.COUNT_Y, "сверху вниз: подпись, стрелка, диск, метки, счёт")
	ok(VoteHolo.WORD_Y + 0.93 < 1.9 and VoteHolo.COUNT_Y + 0.93 > 1.0, "в высоте проекции 1,1…1,9 м над полом")
	var a := VoteHolo.mark_pos("deep", 0, 2)
	var b := VoteHolo.mark_pos("deep", 1, 2)
	near(a.z, d.z + VoteHolo.MARK_STEP * 0.5, 1e-6, "первая метка — слева")
	near(b.z, d.z - VoteHolo.MARK_STEP * 0.5, 1e-6)
	var far := VoteHolo.mark_pos("deep", 3, 4)
	ok(far.z > 0.0, "четыре метки не залезают на соседнее поле")
	eq(VoteHolo.mark_pos("up", 0, 1).z, u.z, "одна метка — по центру поля")
	ok(VoteHolo.wanted(true, false))
	ok(not VoteHolo.wanted(true, true), "итог — не голосование")
	ok(not VoteHolo.wanted(false, false))


func test_result_layout() -> void:
	ok(VoteHolo.result_wanted(true, true), "после «наверх» — итог")
	ok(not VoteHolo.result_wanted(true, false), "в голосовании итога нет")
	ok(not VoteHolo.result_wanted(false, true), "итог закрыт — подложки нет")
	var top := SonarView.TOP_Y + VoteHolo.BOARD_Y + VoteHolo.BOARD_H * 0.5
	var bottom := SonarView.TOP_Y + VoteHolo.BOARD_Y - VoteHolo.BOARD_H * 0.5
	ok(bottom > 1.1 and top < 1.9, "подложка в высоте проекции 1,1…1,9 м над полом: %.2f…%.2f" % [bottom, top])
	ok(VoteHolo.TITLE_DY < VoteHolo.BOARD_H * 0.5 and VoteHolo.TITLE_DY > VoteHolo.row_y(0), "заголовок над строками")
	ok(VoteHolo.row_y(3) - 0.04 > -VoteHolo.BOARD_H * 0.5, "четыре строки на подложке")
	eq(VoteHolo.board_lines(4).size(), 4 + 3, "рамка и три разделителя")
	var sep: Array = VoteHolo.board_lines(4)[4]
	near(sep[0].y, (VoteHolo.row_y(0) + VoteHolo.row_y(1)) * 0.5, 1e-6, "разделитель — между строками")
	# лицо подложки (+Z) смотрит на глаз
	for eye: Vector3 in [Vector3(1.5, 0.6, 0.0), Vector3(0.0, 0.6, 1.0), Vector3(-1.0, 0.6, -1.0)]:
		var face := Basis(Vector3.UP, VoteHolo.board_yaw(eye)) * Vector3.BACK
		near(face.angle_to(Vector3(eye.x, 0.0, eye.z)), 0.0, 1e-4, "подложка к глазу %s" % eye)
	eq(VoteHolo.board_yaw(Vector3(0, 1, 0)), 0.0, "глаз над центром — без поворота")


func test_arrow_and_ring() -> void:
	var down := VoteHolo.arrow_outline(0.2, true)
	var up := VoteHolo.arrow_outline(0.2, false)
	eq(down.size(), 7)
	var tip_d := down[4]
	var tip_u := up[4]
	ok(tip_d.y < 0.0 and tip_u.y > 0.0, "острие «глубже» внизу, «наверх» — вверху")
	ok(Geometry2D.triangulate_polygon(down).size() == 15, "контур делится в 5 треугольников")
	var img := VoteHolo.ring_image(64)
	eq(img.get_size(), Vector2i(64, 64))
	ok(img.get_pixel(32, 32).a > 0.5 and img.get_pixel(32, 32).r < 0.1, "середина — тёмная подложка")
	ok(img.get_pixel(60, 32).r > 0.8, "кольцо — светлое, цвет роли даёт modulate")
	eq(img.get_pixel(0, 0).a, 0.0, "за кругом прозрачно")


func test_scene_vote_on_table() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	var sv := main.sonar_view
	ok(sv.vote != null, "поля голосования — над голостолом")
	main.step(0.3)
	ok(not sv.vote.visible, "без голосования полей нет")
	eq(sv.mat.get_shader_parameter("dim"), 0.0, "рельеф сонара — ярко")
	main.walker.x = Main.ROUTE_POST.x
	main.walker.z = Main.ROUTE_POST.y
	main.use_post("route")
	main.complete_route()
	main.run.open_vote()   # в слое голосование откроет переход у 10 (#828)
	main.reactor.heat = 120.0   # горячо — инженер за «наверх»
	main.reactor.hot = true
	main.use_post("route")      # маршрут пройден — голосование
	ok(main.at_vote)
	main.step(0.3)
	ok(sv.vote.visible, "в голосовании поля над столом")
	near(sv.mat.get_shader_parameter("dim"), VoteHolo.DIM_SONAR, 1e-5, "рельеф гаснет")
	var up: Dictionary = sv.vote.fields["up"]
	var deep: Dictionary = sv.vote.fields["deep"]
	eq((up["count"] as Label3D).text, "1", "за «наверх» — инженер")
	eq((deep["count"] as Label3D).text, "3")
	var m0: Array = up["marks"][0]
	ok((m0[0] as Sprite3D).visible)
	eq((m0[1] as Label3D).text, "И", "буква роли")
	eq((m0[0] as Sprite3D).modulate.r, Crew.role_color(Crew.Role.ENGINEER).r, "кружок — цвета роли")
	ok(not (up["marks"][1][0] as Sprite3D).visible, "лишние метки скрыты")
	ok(not sv.vote.board.visible, "в голосовании итога нет")
	main.decide("deep")
	main.step(0.3)
	ok(not sv.vote.visible, "решили — поля гаснут")
	eq(sv.mat.get_shader_parameter("dim"), 0.0)
	main.queue_free()
	await frames(1)


func test_scene_result_on_table() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	var sv := main.sonar_view
	main.walker.x = Main.ROUTE_POST.x
	main.walker.z = Main.ROUTE_POST.y
	main.use_post("route")
	main.complete_route()       # «Рифовый сад»: три места
	main.run.open_vote()   # в слое голосование откроет переход у 10 (#828)
	main.breach.count += 1      # пробоина за забег
	main.use_post("route")
	main.step(0.3)
	main.decide("up")
	main.flyby.stop()
	main.step(0.3)
	var board := sv.vote.board
	ok(board.visible and sv.vote.visible, "наверх — итог над столом")
	near(sv.mat.get_shader_parameter("dim"), VoteHolo.DIM_SONAR, 1e-5, "рельеф погас")
	ok(not (sv.vote.fields["up"]["disc"] as Node3D).visible, "поля голосования спрятаны")
	ok(not (sv.vote.fields["up"]["marks"][0][0] as Sprite3D).visible, "метки спрятаны")
	var names := []
	var vals := []
	for r: Array in sv.vote.board_rows:
		names.append((r[0] as Label3D).text)
		vals.append((r[1] as Label3D).text)
	eq(names, ["Образцы", "Виды", "Места", "Пробоины"], "четыре строки ART-016")
	eq(vals[2], "3", "пройдено три места")
	eq(vals[3], "1", "одна пробоина")
	for r: Array in sv.vote.board_rows:   # иконки ART-026 слева от строк, текстура по названию
		var ic: Sprite3D = r[2]
		ok(ic.is_visible_in_tree() and ic.texture != null, "иконка у строки «%s»" % (r[0] as Label3D).text)
		eq(ic.texture.resource_path, VoteHolo.summary_icon((r[0] as Label3D).text), "своя иконка")
		ok(ic.position.x < (r[0] as Label3D).position.x, "иконка левее названия")
		near(ic.modulate.a, 1.0, 1e-5, "итог открыт — иконка горит")
	# подложка смотрит на глаза игрока у поста «Маршрут»
	var eye := board.to_local(main.camera.global_position)
	ok(eye.z > 0.0 and absf(eye.x) < 0.05, "лицом к игроку: %s" % eye)
	eq(main.vote_panel.rows.size(), 4, "на панели — подробности без строк голограммы")
	eq(main.vote_panel.rows[0][0], "Время под водой")
	main.close_vote()           # кнопка — новый забег
	for i in 10:
		main.step(0.1)
	ok(not board.visible and not sv.vote.visible, "новый забег — итог погас")
	eq(sv.mat.get_shader_parameter("dim"), 0.0)
	main.queue_free()
	await frames(1)


## ART-026: иконки строк итога — файлы в textures/summary, у каждой строки Run.summary своя, все в левом поле подложки.
func test_summary_icons() -> void:
	var run := Run.new()
	var seen := {}
	for r: Array in run.summary(0, 0, 0):
		var path := VoteHolo.summary_icon(r[0])
		ok(ResourceLoader.exists(path), "иконка строки «%s»: %s" % [r[0], path])
		seen[path] = true
	eq(seen.size(), 4, "четыре разные иконки")
	eq(VoteHolo.summary_icon("Время под водой"), "", "у строк панели иконок нет")
	var left := -VoteHolo.BOARD_W * 0.5
	near(VoteHolo.icon_x() - VoteHolo.ICON_SIZE * 0.5 - left, VoteHolo.BOARD_PAD, 1e-6, "иконка у левого поля")
	ok(VoteHolo.name_x() > VoteHolo.icon_x() + VoteHolo.ICON_SIZE * 0.5, "название правее иконки")
	ok(VoteHolo.ICON_SIZE < VoteHolo.ROW_STEP, "иконка не залезает на соседние строки")


func test_look_up_to_fields() -> void:
	var c := Vector3(0.0, 0.93, -1.2)
	var v := VoteHolo.look(Vector3(1.5, Deck.Walker.EYE, -1.2), c)
	near(v.x, PI / 2.0, 1e-5, "с поста «Маршрут» — лицом к −X")
	ok(v.y < 0.0 and v.y > -0.3, "взгляд чуть вниз, к середине раскладки: %.2f" % v.y)
	near(VoteHolo.look(Vector3(0.0, 1.0, 0.0), c).x, 0.0, 1e-5, "стол к носу — yaw 0")


## #193: с точки сценария 09d-vote (у поста «Маршрут», взгляд на карту −38°) поля, метки и счёт были вне кадра.
func test_scene_vote_in_frame() -> void:
	var was := tree.root.size
	tree.root.size = Vector2i(1600, 720)   # экран телефона (в headless окно другое)
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.walker.x = 1.6
	main.walker.z = -1.2
	main.walker.yaw = PI / 2.0
	main.walker.pitch = deg_to_rad(-38.0)
	main.step(0.1)
	main.complete_route()
	main.run.open_vote()   # в слое голосование откроет переход у 10 (#828)
	main.use_post("route")
	ok(main.at_vote, "маршрут пройден — голосование")
	main.step(0.5)
	await frames(1)
	var cam := main.get_viewport().get_camera_3d()
	var scr := main.get_viewport().get_visible_rect().size
	var top := scr.y * 0.25   # выше — строки приборов
	for choice in VoteHolo.CHOICES:
		var f: Dictionary = main.sonar_view.vote.fields[choice]
		for key in ["word", "count"]:
			var n: Node3D = f[key]
			ok(not cam.is_position_behind(n.global_position), "%s %s перед камерой" % [choice, key])
			var p := cam.unproject_position(n.global_position)
			ok(p.y > top and p.y < scr.y and p.x > 0.0 and p.x < scr.x,
				"%s %s в кадре ниже строк приборов: %s" % [choice, key, p])
		var mark: Node3D = f["marks"][0][0]
		ok(cam.unproject_position(mark.global_position).y > top, "%s: метки ролей не на строках приборов" % choice)
	main.queue_free()
	tree.root.size = was
	await frames(1)


func test_timer_ring_layout() -> void:
	ok(not VoteHolo.timer_wanted(-1), "таймер не идёт — кольца нет")
	ok(VoteHolo.timer_wanted(0))
	eq(VoteHolo.timer_text(12), "12 с", "как на листе ART-016")
	eq(VoteHolo.ring_segs(1.0), VoteHolo.RING_SEGS, "полное кольцо")
	eq(VoteHolo.ring_segs(0.0), 0, "время вышло — дуги нет")
	eq(VoteHolo.ring_segs(0.001), 1, "пока есть время — дуга видна")
	eq(VoteHolo.ring_segs(0.5), VoteHolo.RING_SEGS / 2)
	var v := VoteHolo.ring_arc(VoteHolo.RING_SEGS / 4)
	eq(v.size(), VoteHolo.RING_SEGS / 4 * 6, "два треугольника на сегмент")
	near(v[1].x, 0.0, 1e-6, "дуга начинается сверху")
	ok(v[1].y > 0.0)
	var last := v[v.size() - 2]
	ok(last.x > 0.05 and absf(last.y) < 1e-4, "четверть — по часовой до трёх часов: %s" % last)
	# лицевая сторона к +Z: (b − a) × (c − a) смотрит внутрь (−Z) — обход по часовой, если смотреть на кольцо
	ok((v[1] - v[0]).cross(v[2] - v[0]).z < 0.0, "обход по часовой стрелке")
	# между полями: кольцо не залезает на стрелки, в высоте проекции, над стрелками и дисками
	ok(VoteHolo.RING_R + VoteHolo.RING_W < VoteHolo.SPREAD - VoteHolo.ARROW_H * 0.31, "кольцо между стрелками")
	ok(VoteHolo.RING_Y - VoteHolo.RING_R > VoteHolo.DISC_Y, "над дисками полей")
	ok(SonarView.TOP_Y + VoteHolo.RING_Y + VoteHolo.RING_R < 1.9, "в высоте проекции")


func test_scene_timer_ring() -> void:
	var was := tree.root.size
	tree.root.size = Vector2i(1600, 720)
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.walker.x = 1.6
	main.walker.z = -1.2
	main.walker.yaw = PI / 2.0
	main.walker.pitch = deg_to_rad(-38.0)
	main.step(0.1)
	main.complete_route()
	main.run.open_vote()   # в слое голосование откроет переход у 10 (#828)
	main.use_post("route")
	ok(main.at_vote)
	main.step(0.5)
	var vv := main.sonar_view.vote
	ok(vv.visible and not vv.timer.visible, "один у стола — таймера нет (решает сразу)")
	var mate := main.add_mate(1.85, -0.75, PI / 2.0, Crew.Role.BIOLOGIST, 0)
	mate.pad.action = true
	main.step(0.1)
	ok(mate.at_vote, "биолог встал к голосованию")
	main.step(0.3)
	ok(not vv.timer.visible, "голосов нет — таймер не идёт")
	main.ballot.cast(main.me.get_instance_id(), main.me.role, "deep")
	main.step(0.1)
	ok(vv.timer.visible, "первый голос — кольцо таймера над столом")
	eq(vv.timer_label.text, VoteHolo.timer_text(main.ballot.seconds()))
	var full := (vv.timer_arc.mesh as ArrayMesh).surface_get_array_len(0)
	for i in 50:
		main.step(0.1)
	ok(main.ballot.seconds() < int(Ballot.TIME), "секунды идут")
	eq(vv.timer_label.text, VoteHolo.timer_text(main.ballot.seconds()), "подпись — секунды Ballot")
	var now := (vv.timer_arc.mesh as ArrayMesh).surface_get_array_len(0)
	ok(now < full, "дуга убывает: %d < %d" % [now, full])
	await frames(1)
	var cam := main.get_viewport().get_camera_3d()
	var scr := main.get_viewport().get_visible_rect().size
	var p := cam.unproject_position(vv.timer.global_position + Vector3(0, VoteHolo.RING_R, 0))
	ok(not cam.is_position_behind(vv.timer.global_position), "кольцо перед камерой")
	ok(p.y > scr.y * 0.25 and p.x > 0.0 and p.x < scr.x, "верх кольца в кадре ниже строк приборов: %s" % p)
	main.decide("deep")
	main.step(0.3)
	ok(not vv.timer.visible, "решили — кольца нет")
	main.queue_free()
	tree.root.size = was
	await frames(1)
