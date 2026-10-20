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
	main.decide("deep")
	main.step(0.3)
	ok(not sv.vote.visible, "решили — поля гаснут")
	eq(sv.mat.get_shader_parameter("dim"), 0.0)
	main.queue_free()
	await frames(1)
