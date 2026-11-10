extends TestCase
## Клиент в сцене (Main.join_game): шаг корабля не считает — кадры хоста ставят корабль, реактор и экипаж,
## свой игрок — место `me` из кадра, камера у него; ввод с экрана уходит хосту; потеря хоста — диалог ART-043 (NetDrop).
## Хост здесь — голый NetLink.Host с кадрами NetSnap.frame (как шлёт Main хоста), по loopback.

const PORT := 24720
const DT := 1.0 / 30.0
var main: Main
var host: NetLink.Host
var guest: NetLink.Guest
## «Корабль хоста» для кадров.
var h_helm := Helm.Ship.new()
var h_reactor := Reactor.new()
var h_vitals := Vitals.new()
var h_crew: Array = []
var h_ev := {}   ## события в кадре хоста (NetSnap.events)
var h_eco := PackedFloat32Array()   ## существа рядом в кадре хоста (EcoLink.pack_near)
var h_lit := false   ## прожектор хоста


func before() -> void:
	h_lit = false
	host = NetLink.Host.new()
	eq(host.start(PORT), OK, "хост открыт")
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	h_helm.pos = Vector3(5.0, -40.0, 20.0)
	h_helm.yaw = 0.7
	h_helm.speed = 4.0
	h_reactor.share[Reactor.Sys.LAMP] = 0
	h_vitals.hull = 61.0
	var pilot := Crew.Member.new(Crew.Role.PILOT)
	pilot.name = "Хост"
	pilot.place(0.0, 2.0, 0.0, true)
	pilot.sync_post()
	h_crew = [pilot]
	eq(main.join_game("127.0.0.1", PORT, "Ира", Crew.Role.BIOLOGIST, 1), OK, "клиент подключается")
	guest = null


func after() -> void:
	if main.net_client:
		main.net_client.stop()
	host.stop()


## Шаг хоста: гость пришёл — встаёт в экипаж (место 1); кадр, если пора.
func _host_tick(send := true) -> void:
	for e: Dictionary in host.poll():
		if e["k"] == "join":
			guest = e["guest"]
			var m := Crew.Member.new(guest.role)
			m.look = guest.look
			m.name = guest.name
			m.place(-1.0, 4.0, 0.3)
			h_crew.append(m)
			guest.index = 1
	if send and host.due(DT):
		var f := NetSnap.frame(host.seq, 0.0, h_helm, h_reactor, h_vitals, h_lit, h_crew, h_ev)
		if not h_eco.is_empty():
			f["eco"] = h_eco
		host.send_frame(f)


## Шаги хоста и клиента, пока cond не true (до 3 с настоящего времени).
func _pump(cond: Callable, send := true) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		_host_tick(send)
		main.step(DT)
		if cond.call():
			return true
		OS.delay_msec(2)
	return false


func test_frame_sets_ship_and_own_player() -> void:
	ok(_pump(func() -> bool: return main.net_seq > 0), "кадр принят")
	ok(main.helm.pos.distance_to(h_helm.pos) < 0.01, "корабль как у хоста")
	near(main.helm.yaw, 0.7, 0.001)
	near(main.vitals.hull, 61.0, 0.01, "корпус как у хоста")
	eq(main.reactor.share[Reactor.Sys.LAMP], 0, "доли реактора как у хоста")
	ok(not main.light_on, "свет как у хоста")
	eq(main.crew.size(), 2, "экипаж как у хоста")
	ok(main.me == main.crew[1], "свой игрок — место из кадра")
	ok(main.walker == main.me.walker, "свой ходок — у него")
	eq(main.me.name, "Ира")
	eq(main.me.role, Crew.Role.BIOLOGIST)
	ok((main.crew[0] as Crew.Member).seated, "хост за штурвалом")
	eq(main.crew_view.figures.size(), 2, "две фигуры")
	ok(main.crew_view.local == main.me, "камера — глазами своего игрока")
	var eye := main.camera.position
	ok(Vector2(eye.x, eye.z).distance_to(Vector2(-1.0, 4.0)) < 0.6, "камера у своего игрока (%s)" % eye)


func test_client_does_not_step_ship() -> void:
	ok(_pump(func() -> bool: return main.net_seq > 0), "кадр принят")
	var p := main.helm.pos
	for i in 30:   # секунда без кадров: на хосте корабль прошёл бы 4 м, клиент сам его не двигает
		main.step(DT)
	ok(main.helm.pos.distance_to(p) < 0.001, "корабль стоит до нового кадра")
	h_helm.pos += Vector3(0.0, 0.0, -4.0)
	var seq := main.net_seq
	ok(_pump(func() -> bool: return main.net_seq > seq), "новый кадр")
	ok(main.helm.pos.distance_to(h_helm.pos) < 0.01, "корабль сдвинул кадр хоста")


func test_screen_input_reaches_host() -> void:
	ok(_pump(func() -> bool: return main.net_seq > 0), "на борту")
	main.overlay.router.move = Vector2i(0, 1)
	ok(_pump(func() -> bool: return guest.pad.move == Vector2(0.0, 1.0)), "крестовина у хоста")
	main.overlay.router.move = Vector2i.ZERO
	main.overlay.router.action_pressed = true
	ok(_pump(func() -> bool: return guest.pad.action), "нажатие у хоста")
	main.overlay.router.light_pressed = true
	ok(_pump(func() -> bool: return guest.pad.light), "«Свет» у хоста")


func test_own_yaw_stays_local_until_post() -> void:
	ok(_pump(func() -> bool: return main.net_seq > 0), "на борту")
	main.walker.yaw = 1.2   # свайп повернул взгляд, хост ещё не знает
	var seq := main.net_seq
	ok(_pump(func() -> bool: return main.net_seq > seq + 2), "кадры идут")
	near(main.walker.yaw, 1.2, 0.001, "курс свой, кадр его не дёргает")
	(h_crew[1] as Crew.Member).place(0.0, 2.0, 0.0, true)   # хост посадил гостя за пост: курс от хоста
	(h_crew[1] as Crew.Member).sync_post()
	ok(_pump(func() -> bool: return main.me.seated), "сел по кадру")
	near(main.walker.yaw, 0.0, 0.001, "курс поста от хоста")


func test_lost_host_opens_dialog_not_solo() -> void:   # ART-043: не уходит в соло молча
	ok(_pump(func() -> bool: return main.crew.size() == 2), "на борту")
	host.stop()
	ok(_pump(func() -> bool: return main.drop.blocks(), false), "диалог открыт")
	ok(main.net_client != null, "клиент ждёт хоста, не соло")
	eq(main.drop.phase, NetDrop.Phase.WAIT)
	eq(main.net_client.state, NetLink.State.CONNECTING, "попытка переподключения к прежнему хосту")
	eq(main.crew.size(), 2, "последний кадр хоста на экране")
	ok(main.drop_panel.visible, "диалог виден")
	main.overlay.router.begin(5, Vector2(150, 600))   # крестовина под диалогом не работает
	main.step(DT)
	eq(main.net_pad.move, Vector2.ZERO, "управление остановлено")
	main.overlay.router.end(5)
	for i in int(NetDrop.WINDOW / DT) + 2:
		main.step(DT)
	eq(main.drop.phase, NetDrop.Phase.NO_ANSWER, "окно истекло — «Нет ответа»")
	eq(main.drop.wait_line(), "Нет ответа")
	ok(main.net_client != null, "автоматического соло нет")
	_tap("solo")
	eq(main.drop.phase, NetDrop.Phase.CONFIRM_SOLO, "подтверждение")
	_tap("no")
	eq(main.drop.phase, NetDrop.Phase.NO_ANSWER, "«Нет» — назад")
	_tap("solo")
	_tap("yes")
	ok(main.net_client == null, "одиночный забег")
	eq(main.crew.size(), 1, "остался свой игрок")
	ok(not main.drop.active() and not main.drop_panel.visible, "диалог закрыт")
	var p := main.helm.pos
	main.helm.speed = 3.0
	for i in 10:
		main.step(DT)
	ok(main.helm.pos.distance_to(p) > 0.01, "корабль снова считает свой шаг")


func test_host_back_restores() -> void:   # хост вернулся в окно ожидания — «Связь восстановлена», управление снова
	ok(_pump(func() -> bool: return main.net_seq > 0), "на борту")
	host.stop()
	ok(_pump(func() -> bool: return main.drop.blocks(), false), "диалог открыт")
	eq(host.start(PORT), OK, "хост снова открыт")
	h_crew.resize(1)
	ok(_pump(func() -> bool: return not main.drop.blocks()), "принят снова")
	eq(main.drop.phase, NetDrop.Phase.BACK)
	eq(main.drop.lines()[0], "Связь восстановлена")
	ok(main.net_client.joined())
	for i in int(NetDrop.BACK_TIME / DT) + 2:
		_host_tick()
		main.step(DT)
	ok(not main.drop.active(), "плашка ушла через 2 с")


func test_refused_on_rejoin_no_retry() -> void:   # отказ хоста при попытке — причина вместо ожидания, «Ждать» погашена
	ok(_pump(func() -> bool: return main.net_seq > 0), "на борту")
	host.stop()
	ok(_pump(func() -> bool: return main.drop.blocks(), false), "диалог открыт")
	main.net_client.version = -7
	main.net_client.rejoin(NetDrop.WINDOW)
	eq(host.start(PORT), OK)
	ok(_pump(func() -> bool: return main.drop.phase == NetDrop.Phase.REFUSED), "отказ")
	eq(main.drop.wait_line(), "Другая версия игры")
	eq(main.drop.hit(_at("wait"), _size()), "", "без повторов")


func _size() -> Vector2:
	return main.get_viewport().get_visible_rect().size


func _at(id: String) -> Vector2:
	return NetDrop.to_screen(NetDrop.BUTTONS[id], _size()).get_center()


## Касание кнопки диалога за один шаг.
func _tap(id: String) -> void:
	main.overlay.router.begin(9, _at(id))
	main.step(DT)
	main.overlay.router.end(9)


## Хост ведёт корабль и шлёт кадры со своим временем: у клиента корабль идёт ровно, без шага в 20 раз в секунду.
func test_ship_moves_smoothly_between_frames() -> void:
	ok(_pump(func() -> bool: return main.net_seq > 0), "на борту")
	var t := 0.0
	var last := Vector3.INF
	var worst := 0.0
	var n := 0
	var v := 6.0
	var d := 1.0 / 60.0   # экран 60 к/с: кадр хоста — раз в три шага экрана
	for i in 150:
		_host_tick(false)
		t += d
		h_helm.pos.z -= v * d
		if host.due(d):
			host.send_frame(NetSnap.frame(host.seq, t, h_helm, h_reactor, h_vitals, false, h_crew))
		main.step(d)
		if i > 50 and last != Vector3.INF:
			worst = maxf(worst, last.distance_to(main.helm.pos))
			n += 1
		last = main.helm.pos
		OS.delay_msec(2)
	ok(n > 80)
	ok(worst < v * d * 1.8, "шаг корабля у клиента %.3f м за кадр (ход %.3f)" % [worst, v * d])
	ok(main.helm.pos.distance_to(h_helm.pos) < v * 0.5, "отстаёт не больше полсекунды хода")


## Пробоина и ил у хоста — у клиента по кадру: тревога, вода в отсеке, облако вокруг корабля, сообщение один раз.
func test_events_from_host_frame() -> void:
	ok(_pump(func() -> bool: return main.net_seq > 0), "на борту")
	ok(main.breach.active == null and main.silt.clouds.is_empty(), "событий нет")
	var b := Breach.new()
	b.start(b.all[1])
	b.water = 0.2
	var sl := Silt.new()
	sl.spawn(h_helm.pos, Silt.SCRAPE_R, Silt.SCRAPE_LIFE, "scrape")
	sl.inside = sl.clouds[0]
	sl.k = 1.0
	h_ev = NetSnap.events(b, sl, 0.0, false, [7, "Пробоина: коридор — держите «Сварка» у пробоины"])
	ok(_pump(func() -> bool: return main.breach.active != null), "пробоина пришла кадром")
	ok(main.breach.active == main.breach.all[1], "та же — в коридоре")
	near(main.breach.water, 0.2, 0.001, "вода в отсеке")
	ok(main.breach_view.water.visible, "вода видна")
	ok(main.breach_view.siren.playing, "сирена воет")
	ok(main.alarms_on()[0], "табло: пробоина")
	ok(main.silt.inside != null, "корабль в облаке ила")
	near(main.silt.k, 1.0, 0.001)
	ok(main.alarms_on()[3], "табло: сонарная тьма")
	ok(main.message.text.begins_with("Пробоина: коридор"), "сообщение события на приборах")
	main.message.say("своё")
	var seq := main.net_seq
	ok(_pump(func() -> bool: return main.net_seq > seq + 3), "ещё кадры с тем же сообщением")
	eq(main.message.text, "своё", "сообщение события показано один раз")
	b.hold(10.0)   # хост заварил, облако осело
	sl.clouds.clear()
	sl.inside = null
	sl.k = 0.0
	h_ev = NetSnap.events(b, sl, 0.0, false)
	ok(_pump(func() -> bool: return main.breach.active == null), "шов заварен у хоста — и у клиента")
	ok(main.silt.clouds.is_empty() and main.silt.inside == null, "ила нет")
	ok(not main.breach_view.siren.playing, "сирена смолкла")


func test_scorch_from_host_frame() -> void:   # разряд хоста у дна — тот же след на дне у гостя (ART-066)
	ok(_pump(func() -> bool: return main.net_seq > 0), "на борту")
	eq(main.scorch.all.size(), 0, "дно чистое")
	var sc := Seabed.Scorch.new()
	var fy := Seabed.height(h_helm.pos.x, h_helm.pos.z)
	ok(sc.add(Vector3(h_helm.pos.x, fy + Helm.Ship.CLEARANCE, h_helm.pos.z), fy, 1.0, 0.0), "след у хоста")
	h_ev = {"z": NetSnap.scorch(sc, 0.0)}
	ok(_pump(func() -> bool: return main.scorch.all.size() == 1), "след пришёл кадром")
	var at: PackedVector4Array = main.ocean.seabed_mat.get_shader_parameter("scorch_at")
	near(at[0].x, h_helm.pos.x, 0.01, "в материале дна под кораблём хоста")
	var k: PackedVector4Array = main.ocean.seabed_mat.get_shader_parameter("scorch_k")
	ok(k[0].x > 0.9 and k[0].z < 0.01, "свежий")
	sc.clear()
	h_ev = {"z": NetSnap.scorch(sc, 0.0)}
	ok(_pump(func() -> bool: return main.scorch.all.is_empty()), "новый забег у хоста — чистое дно")
	k = main.ocean.seabed_mat.get_shader_parameter("scorch_k")
	eq(k[0].x, 0.0, "и в материале")


func test_scorch_ages_on_guest() -> void:   # между кадрами след темнеет часами гостя
	var sc := Seabed.Scorch.new()
	var fy := Seabed.height(h_helm.pos.x, h_helm.pos.z)
	sc.add(Vector3(h_helm.pos.x, fy + Helm.Ship.CLEARANCE, h_helm.pos.z), fy, 1.0, 0.0)
	h_ev = {"z": NetSnap.scorch(sc, Seabed.Scorch.OLD.x)}   # хост: след уже 40 с
	ok(_pump(func() -> bool: return main.scorch.all.size() == 1), "след пришёл")
	for i in 20:
		_host_tick()
		main.step(5.0)   # 100 с у гостя: хост тот же кадр, но счёт не менялся
	var k: PackedVector4Array = main.ocean.seabed_mat.get_shader_parameter("scorch_k")
	near(k[0].z, 1.0, 1e-3, "стал старым пятном")


func test_route_vote_and_result_from_host() -> void:   # маршрут, голосование и итог хоста — у гостя на голостоле
	ok(_pump(func() -> bool: return main.net_seq > 0), "на борту")
	var run := Run.new()
	run.begin(0.0, 0, 0, 0)
	run.choose(2)
	h_ev = NetSnap.events(Breach.new(), Silt.new(), 0.0, false)
	h_ev["r"] = NetSnap.run_state(run, {}, -1, -1.0, "", [], [], [])
	ok(_pump(func() -> bool: return main.run.route == 2), "маршрут хоста — «Край отмели»")
	eq(main.run.waypoint(), Run.place_xz("well"), "точка на голостоле — колодец")
	for k in Run.ROUTES[2]["places"]:
		run.update(Run.place_xz(k).x, Run.place_xz(k).y)
	run.open_vote()   # в слое — переход у 10 (#828)
	var ops := Run.opinions(30.0, 80.0, false, false, 0)
	(h_crew[1] as Crew.Member).at_vote = true   # гость у голостола
	h_ev["r"] = NetSnap.run_state(run, {"deep": [Crew.Role.PILOT], "up": [Crew.Role.BIOLOGIST]}, 9, 0.6,
		"голосов 2 из 2 · 9 с", ops, [], [])
	ok(_pump(func() -> bool: return main.at_vote and main.sonar_view.vote.visible), "гость у стола — поля голосования")
	ok(main.run.done and not main.run.ended, "решают")
	eq(main.votes, {"deep": [Crew.Role.PILOT], "up": [Crew.Role.BIOLOGIST]}, "метки голосов хоста")
	ok(main.vote_panel.visible and not main.vote_panel.results, "панель голосования")
	eq(main.vote_panel.rows, ops, "мнения ролей хоста")
	eq(main.vote_panel.tally, "голосов 2 из 2 · 9 с", "счёт и таймер")
	run.finish(300.0, 2, 1, 0, 30.0)
	var rows := run.summary(2, 1, 0)
	h_ev["r"] = NetSnap.run_state(run, {}, -1, -1.0, "", [], rows, Run.detail(run.results(300.0, 2, 1, 0, 30.0)))
	ok(_pump(func() -> bool: return main.vote_panel.results), "наверх — итог на панели")
	ok(main.run.ended)
	eq(main.result_rows, rows, "итог на голограмме — как у хоста")
	ok(_pump(func() -> bool: return main.sonar_view.vote.board.visible), "итог над столом")
	(h_crew[1] as Crew.Member).at_vote = false
	ok(_pump(func() -> bool: return not main.vote_panel.visible), "отошёл от стола — панели нет")


func test_creatures_near_from_host() -> void:   # живой мир у гостя: существа рядом встают по кадру хоста
	ok(_pump(func() -> bool: return main.net_seq > 0), "кадр принят")
	var agents := main.eco.world.agents
	ok(agents.size() > 3, "у гостя свой мир по зерну")
	var i := 3
	var a: EcoAgent = agents[i]
	var t0 := main.eco.world.time
	# мир хоста: то же существо в другом месте, удирает
	var hw: Array[EcoAgent] = []
	for k in i + 1:
		hw.append(EcoAgent.new(agents[k].species, agents[k].p))
	var want := h_helm.pos + Vector3(4, 1, -6)
	hw[i].p = want
	hw[i].v = Vector3(0.5, 0, 0)
	hw[i].set_state(EcoAgent.State.FLEE)
	h_eco = EcoLink.pack_near(hw, h_helm.pos)
	ok(_pump(func() -> bool: return a.p.distance_to(want) < 0.2), "существо встало, где у хоста")
	eq(a.state, EcoAgent.State.FLEE, "состояние как у хоста")
	ok(main.eco.world.time > t0, "мир гостя идёт сам")
	h_eco = PackedFloat32Array()


func test_weak_link_plate() -> void:   # ART-043: кадры хоста опаздывают — «Слабая связь», игра идёт; 2 с ровно — снята
	ok(_pump(func() -> bool: return main.net_seq > 0), "на борту")
	ok(not main.weak.visible(), "связь ровная — плашки нет")
	for i in int((NetLink.WEAK_AFTER + 0.2) / DT):
		_host_tick(false)   # хост молчит: кадры опаздывают
		main.step(DT)
	ok(main.weak.on, "слабая связь")
	ok(main.drop_panel.visible, "плашка видна")
	ok(not main.drop.active(), "диалога нет — игра идёт")
	main.overlay.router.move = Vector2i(0, 1)   # крестовина под плашкой работает
	main.step(DT)
	eq(main.net_pad.move, Vector2(0.0, 1.0), "управление не остановлено")
	main.overlay.router.move = Vector2i.ZERO
	ok(_pump(func() -> bool: return main.net_client.quiet == 0.0), "кадры снова идут")
	for i in int(1.5 / DT):
		_host_tick()
		main.step(DT)
	ok(main.weak.visible(), "до 2 с устойчивой связи плашка стоит")
	for i in int(1.0 / DT):
		_host_tick()
		main.step(DT)
	ok(not main.weak.visible(), "2 с ровной связи — снята")
	ok(not main.drop_panel.visible, "панель скрыта")


## Касание кнопки меню забега (ART-037) за один шаг.
func _tap_pause(id: String) -> void:
	main.overlay.router.begin(8, main.pause.rect(id, _size()).get_center())
	main.step(DT)
	main.overlay.router.end(8)


func test_guest_run_menu_world_goes_on() -> void:   # ART-037 кооп: «Меню забега» у гостя, кадры идут, ввода нет
	ok(_pump(func() -> bool: return main.net_seq > 0), "на борту")
	main.back_pressed()
	ok(main.pause.open, "«Назад» — меню забега")
	eq(main.pause.mode, "guest")
	eq(main.pause.title(), "Меню забега")
	eq(main.pause.subtitle(), "Вы — гость · забег продолжается")
	ok(main.pause_panel.visible and not main.overlay.visible, "меню на экране, крестовина скрыта")
	var pad := main.overlay.router.layout.pad
	var at := pad.c + Vector2(0, -pad.r * 0.7)
	if main.pause.hit(at, _size()) != "":   # на квадратном окне кнопки меню ложатся на крестовину — палец мимо них
		at = pad.c + Vector2(-pad.r * 0.7, 0)
	main.overlay.router.begin(5, at)
	h_helm.pos += Vector3(0.0, 0.0, -6.0)
	var seq := main.net_seq
	ok(_pump(func() -> bool: return main.net_seq > seq), "кадры хоста идут под меню")
	ok(main.helm.pos.distance_to(h_helm.pos) < 0.5, "корабль идёт по кадрам хоста")
	eq(main.net_pad.move, Vector2.ZERO, "крестовина под меню хосту не идёт")
	main.overlay.router.end(5)
	_tap_pause("leave")
	eq(main.pause.ask, "leave", "«Покинуть экипаж» — через подтверждение")
	eq(main.pause.ask_lines()[1], "Вы выйдете из текущего забега.")
	_tap_pause("no")
	ok(main.pause.open and main.net_client != null, "«Нет» — снова меню, гость на борту")
	_tap_pause("leave")
	_tap_pause("yes")
	ok(main.net_client == null, "гость покинул экипаж")
	eq(main.crew.size(), 1, "остался свой игрок")
	ok(not main.pause.open and not main.pause_panel.visible, "меню забега закрыто")
	ok(main.main_menu.open and main.menu_panel.visible, "главное меню")
	ok(_pump(func() -> bool: return host.guests.is_empty()), "хост увидел уход гостя")


func test_drop_dialog_to_menu() -> void:   # ART-043: «В меню» в диалоге обрыва связи — главное меню ART-037
	ok(_pump(func() -> bool: return main.crew.size() == 2), "на борту")
	host.stop()
	ok(_pump(func() -> bool: return main.drop.blocks(), false), "диалог открыт")
	main.back_pressed()
	ok(not main.pause.open, "под диалогом обрыва меню забега не открывается")
	ok(main.drop.menu_ready, "«В меню» доступна")
	_tap("menu")
	eq(main.drop.phase, NetDrop.Phase.CONFIRM_MENU, "подтверждение")
	_tap("yes")
	ok(main.net_client == null, "сетевой забег покинут")
	ok(not main.drop.active() and not main.drop_panel.visible, "диалог закрыт")
	ok(main.main_menu.open and main.menu_panel.visible, "главное меню")


func test_guest_tutorial_steps() -> void:   # ART-038 у гостя: плашка видна, свет — по своему нажатию и кадру хоста
	ok(_pump(func() -> bool: return main.net_seq > 0), "на борту")
	var t := main.tutorial
	t.on = true
	t.step = 2   # «За штурвалом нажмите «Свет»»
	var me := h_crew[1] as Crew.Member
	me.sit()
	me.sync_post()
	ok(_pump(func() -> bool: return main.pilot.seated), "гость за штурвалом по кадру")
	ok(_pump(func() -> bool: return main.tutorial_panel.visible), "у гостя плашка подсказки видна")
	eq(main.tutorial_panel.ring, "light", "обведён «Свет»")
	main.overlay.router.light_pressed = true
	ok(_pump(func() -> bool: return guest.pad.light), "«Свет» ушёл хосту")
	for i in 5:
		_host_tick()
		main.step(DT)
	ok(t.done_t < 0.0 and t.step == 2, "пока свет в кадре не сменился — не засчитан")
	h_lit = true   # хост переключил прожектор по нажатию гостя
	ok(_pump(func() -> bool: return t.done_t >= 0.0 or t.step > 2), "свет в кадре хоста — шаг засчитан")
	ok(_pump(func() -> bool: return t.step == 3), "шаг энергии")
	eq(t.step_line(), "Первый забег · 4 / 6", "у гостя все шесть: сонар — импульсом хоста")


func test_comms_from_host_and_ask_back() -> void:   # ART-040 у гостя: плашка и код хоста, «Спросить код» — хосту
	var hc := Comms.new()
	hc.reset_run(5)
	h_ev = {"c": hc.pack()}
	ok(_pump(func() -> bool: return main.net_seq > 0 and main.comms.code == hc.code), "код забега хоста")
	ok(main.comms.follow and not main.comms.active(), "гость следует за хостом, сообщения нет")
	hc.push(Crew.Role.PILOT, "Свет на полную", true, "light")
	hc.update(DT, false)
	h_ev = {"c": hc.pack()}
	ok(_pump(func() -> bool: return main.comms_panel.visible and main.comms.a >= 1.0), "плашка у гостя")
	eq(main.comms.line(), "Свет на полную")
	eq(main.comms.code_line(), "Код: …", "подделка — «Код: …»")
	var size := main.get_viewport().get_visible_rect().size
	main.overlay.router.taps.append(Comms.button_rect(size).get_center())
	ok(_pump(func() -> bool: return guest.pad.ask == hc.cur.id), "нажатие дошло хосту номером сообщения")
	eq(main.comms.state, Comms.Ask.NONE, "проверку ведёт хост")
	ok(hc.press(guest.pad.ask), "хост начал проверку")
	h_ev = {"c": hc.pack()}
	ok(_pump(func() -> bool: return main.comms.state == Comms.Ask.WAIT), "«Ждём ответ…» у гостя")


func test_lore_from_host_frame() -> void:   # #825: знания слоя общие — гость получает их кадром хоста
	var host_lore := LayerLore.new()
	host_lore.learn(LayerLore.D07_RELAY)
	host_lore.learn(LayerLore.K2)
	h_ev = {"k": host_lore.pack()}
	ok(_pump(func() -> bool: return main.lore.knows(LayerLore.K2)), "знания хоста у гостя")
	eq(main.lore.pack(), host_lore.pack(), "те же факты")
	h_ev = {}
	ok(_pump(func() -> bool: return main.net_seq > 3), "кадры без «k» идут")
	ok(main.lore.knows(LayerLore.D07_RELAY), "без «k» знания не теряются")

