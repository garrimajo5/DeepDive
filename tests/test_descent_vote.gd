extends TestCase
## Панель «Спуск к Кристальному лесу» у 10 (#1362): что не узнано на слое, мнения ролей, «вверх» ничего не делает,
## «позже» — кнопка «Спуск» у стола, одно поле «ВНИЗ» над столом, низ панели над кнопкой действия.


func _texts(rows: Array) -> Array:
	return rows.map(func(r: Array) -> String: return r[0])


func test_unknown_rows_follow_lore() -> void:
	var l := LayerLore.new()
	eq(DescentVote.unknown(l), [["Врата 07: не осмотрены", true], ["Раковина 03: не осмотрена", true],
		["Поле 08: не замечено", false]], "ничего не узнано: врата и Раковина — важное, поле — приглушённо")
	l.learn(LayerLore.D07_RETURN)
	eq(DescentVote.unknown(l)[0], ["Диагностика врат 07: 1 из 3", true], "прочитан один факт из трёх")
	l.learn(LayerLore.D07_RELAY)
	l.learn(LayerLore.SHELL03)
	eq(_texts(DescentVote.unknown(l)), ["Диагностика врат 07: 2 из 3", "Поле 08: не замечено"], "узнанное не пишется")
	l.learn(LayerLore.D07_AUTH)
	l.learn(LayerLore.FIELD08)
	eq(DescentVote.unknown(l), [[DescentVote.ALL_KNOWN, false]], "всё узнано — одна строка")


func test_opinions_against_first() -> void:
	var calm := DescentVote.opinions(Run.opinions(100.0, 100.0, false, false, 0))
	eq(calm.size(), 2, "не больше двух строк")
	eq([calm[0][0], calm[1][0]], ["Пилот", "Инженер"], "всё спокойно — пилот и инженер «за»")
	ok(not calm[0][1] and not calm[1][1])
	var hot := DescentVote.opinions(Run.opinions(100.0, 100.0, true, true, 6))
	eq(hot[0][0], "Инженер", "перегрев — «против» первым")
	ok(hot[0][1], "инженер против")
	eq(hot[0][2], "реактор перегрет", "текст — как в Run.opinions")
	var weak := DescentVote.opinions(Run.opinions(40.0, 100.0, false, false, 0))
	eq(weak[0][0], "Пилот", "корпус 40 % — пилот против первым")
	ok(weak[0][1])


func test_box_clears_action_button() -> void:
	for vis: Vector2 in [Vector2(1600, 720), Vector2(2400, 1080), Vector2(1920, 1080)]:
		var b := DescentVote.box(vis)
		var gap := DescentVote.action_top(vis) - b.end.y
		near(gap, DescentVote.GAP * vis.y / 1080.0, 0.01, "низ панели — на 16 px (H = 1080) над кнопкой при %s" % vis)
		ok(b.end.x <= vis.x and b.position.y > 0.0 and b.size.y > vis.y * 0.4, "панель на экране и не сплюснута %s" % vis)


func test_up_is_not_a_vote_at_descent() -> void:
	var r := Run.new()
	r.begin(0.0, 0, 0, 0)
	ok(r.vote_ok("up") and r.vote_ok("deep") and not r.vote_ok(""), "в старом голосовании — оба выбора")
	var at := Run.place_xz(Run.DESCENT)
	r.descent(at.x, at.y)
	ok(not r.vote_ok("up"), "у 10 «вверх» — не голос")
	ok(r.vote_ok("deep"))
	eq(r.label(), DescentVote.TITLE, "подпись поста у стола")
	eq(r.status(at.x, at.y), Run.place_name(Run.DESCENT), "строка 2 — имя места, не маршрут")


func test_holo_single_field() -> void:
	eq(VoteHolo.choices(true), ["deep"] as Array[String], "у 10 — одно поле")
	eq(VoteHolo.choices(false), VoteHolo.CHOICES)
	eq(VoteHolo.word("deep", true), "ВНИЗ")
	eq(VoteHolo.word("deep", false), "ГЛУБЖЕ")
	eq(VoteHolo.field_pos("deep", 0.5, true).z, 0.0, "поле по центру стола")
	ok(VoteHolo.ring_pos(true).z != 0.0, "кольцо таймера сбоку — не на стрелке")


func test_net_carries_descent() -> void:
	var host := Run.new()
	host.begin(0.0, 0, 0, 0)
	var at := Run.place_xz(Run.DESCENT)
	host.descent(at.x, at.y)
	var guest := Run.new()
	guest.begin(0.0, 0, 0, 0)
	NetSnap.apply_run(NetSnap.run_state(host, {}, -1, -1.0, "", [], [], []), guest)
	ok(guest.at_descent() and guest.voting, "гость знает, что корабль в круге 10")


func test_scene_descent_panel() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	var at := Run.place_xz(Run.DESCENT)
	main.helm.pos = Vector3(at.x, Seabed.height(at.x, at.y) + 20.0, at.y)
	main.step(1.0 / 30.0)
	main.walker.x = Main.ROUTE_POST.x
	main.walker.z = Main.ROUTE_POST.y
	main.use_post("route")
	ok(main.at_vote and main.vote_panel.descent, "у 10 — панель спуска")
	eq(main.vote_panel.title, DescentVote.TITLE)
	eq(main.vote_panel.rows, DescentVote.unknown(main.lore), "блок «не узнано» — по знаниям слоя")
	ok(not main.votes.has("up"), "над столом голосов «наверх» нет")
	# «вверх» ничего не делает
	main.overlay.router.move = Vector2i.ZERO
	main.step(1.0 / 30.0)
	main.overlay.router.move = Vector2i(0, 1)
	main.step(1.0 / 30.0)
	main.step(1.0 / 30.0)
	main.overlay.router.move = Vector2i.ZERO
	ok(not main.run.ended and main.at_vote, "«вверх» у 10 — не «наверх»: забег идёт, панель открыта")
	# «позже»: кнопка закрывает панель, голосование открыто, у стола — «Спуск»
	main.close_vote()
	main.step(1.0 / 30.0)
	ok(main.run.voting and not main.vote_panel.visible, "позже — панель закрыта, голосование открыто")
	eq(main.overlay.action_label, DescentVote.BUTTON, "кнопка у стола — «Спуск»")
	main.use_post("route")
	ok(main.at_vote and main.vote_panel.visible and main.vote_panel.descent, "«Спуск» снова открывает панель")
	main.queue_free()
	await frames(1)
