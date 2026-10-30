class_name NetGame
extends RefCounted
## Сетевая игра поверх сцены `Main` (#756). Хост (`main.net_host`): гости встают на палубу (`net_poll`,
## `seat_guest`), ушедшие — табличка «… отключился» и тающая фигура (`mate_gone`, `ghosts_step`), кадр гостям после
## шага (`net_send`). Гость (`main.net_client`): шаг корабля не считает — ввод хосту и кадры хоста в корабль и
## экипаж (`client_step`, `client_frame`), потеря хоста — диалог ART-043 (`drop_step`, `drop_taps`, `leave_net`).
## Состояние — поля `main.net_*`, `main.drop`, `main.weak`, `main.notice`, `main.ghosts`. Живёт полем
## `main.net_game`; входы для тестов, `tools/` и `QaRunner` (`host_game`, `join_game`, `mate_gone`) — тонкие
## пересылки у `Main`.

var main: Main
## Свои знания слоя до входа гостем (#823, часть 4): кадры хоста ставят его знания, `leave_net` возвращает свои.
var own_lore: Array = []


func _init(m: Main) -> void:
	main = m


## Хост закрывает сетевой забег: гости отключены (у них — диалог обрыва связи), их фигуры и тени убраны.
func stop_host() -> void:
	main.net_host.stop()
	main.net_host = null
	for id: int in main.net_mates:
		main.crew.erase(main.net_mates[id])
	main.net_mates.clear()
	main.ghosts.clear()
	ghosts_step(0.0, true)
	main.crew_view.set_members(main.crew, main.me)


## Открыть сетевой забег хостом (NetLink): телефоны по локальной сети встают членами экипажа, их ввод — `Member.pad`.
func host_game(port: int = NetLink.PORT) -> Error:
	if main.main_menu.open:
		main.close_menu()
	main.net_host = NetLink.Host.new()
	var err := main.net_host.start(port)
	if err != OK:
		main.net_host = null
	return err


## Гости хоста: пришёл — член экипажа своей роли и внешности с вводом гостя, ушёл — убрать с палубы.
func net_poll(dt: float = 0.0) -> void:
	if main.notice.active():
		main.notice.update(dt)
		main.drop_panel.show_notice(main.notice)
	if main.net_host == null:
		return
	var changed := false
	for e: Dictionary in main.net_host.poll(dt):
		var g: NetLink.Guest = e["guest"]
		if e["k"] == "join":
			var m := seat_guest(g)
			if MateGhost.forget(main.ghosts, m.name):   # вернулся — прежняя фигура уходит, встаёт новая
				ghosts_step(0.0, true)
			if not main.notice.joined(m.name, m.look == 1):
				main.say("На борту: %s" % m.name)
		elif e["k"] == "leave":
			var m: Crew.Member = main.net_mates.get(g.id)
			main.net_mates.erase(g.id)
			if m:
				mate_gone(m)
		else:   # запрос комнаты после старта — комнаты уже нет
			continue
		changed = true
	for id: int in main.net_mates:   # гость без ввода дольше NetLink.LOST_AFTER — табличка «Нет связи»
		var g: NetLink.Guest = main.net_host.guests.get(id)   # хост закрыт — гостей уже нет, а фигуры ещё на палубе
		(main.net_mates[id] as Crew.Member).lost = g == null or g.lost()
	if changed:
		main.crew_view.set_members(main.crew, main.me)
		net_index()


## Гость хоста на палубу: член экипажа своей роли и внешности с его вводом.
func seat_guest(g: NetLink.Guest) -> Crew.Member:
	var m := main.add_mate(Main.NET_SPAWN.x, Main.NET_SPAWN.y, Main.NET_SPAWN.z, g.role, g.look)
	if g.name != "":
		m.name = g.name
	m.pad = g.pad
	main.net_mates[g.id] = m
	return m


## Места гостей в экипаже — уходят им в кадре (`Guest.index`).
func net_index() -> void:
	for id: int in main.net_mates:
		(main.net_host.guests[id] as NetLink.Guest).index = main.crew.find(main.net_mates[id])


## Товарищ ушёл с борта (гость отключился): убрать с палубы, его пост свободен; у хоста — «… отключился» (ART-043).
func mate_gone(m: Crew.Member) -> void:
	main.notice.left(m.name, m.busy(), m.look == 1)
	main.crew.erase(m)
	main.crew_view.set_members(main.crew, main.me)
	main.drop_panel.show_notice(main.notice)
	main.ghosts.append(MateGhost.new(m))   # на последнем месте полупрозрачным с «Нет связи», без поста (ART-043)
	ghosts_step(0.0, true)


## Хост: фигуры отключившихся (`MateGhost`) — стоят, тают, растаявшие убраны; changed — список уже сменился.
func ghosts_step(dt: float, changed := false) -> void:
	if main.ghosts.is_empty() and not changed:
		return
	changed = MateGhost.step(main.ghosts, dt) or changed
	var list := MateGhost.members(main.ghosts)
	if changed:
		main.ghost_view.set_members(list, null)
	main.ghost_view.alphas.assign(main.ghosts.map(func(g: MateGhost) -> float: return g.alpha()))
	main.ghost_view.apply()
	var melting := main.ghosts.filter(func(g: MateGhost) -> bool: return g.t > MateGhost.HOLD).map(
		func(g: MateGhost) -> Crew.Member: return g.member)   # тает — табличка уже снята
	main.ghost_tags.show_tags(list, null, main.ghost_view, main.get_viewport().get_camera_3d(), main.camera, main.tag_blocks(), dt, melting,
			main.status_rect())


## Кадр гостям раз в NetSnap.SEND_DT — после шага, как его видит хост.
func net_send(dt: float) -> void:
	main.news_age += dt
	if main.net_host and main.net_host.due(dt):
		var welding := main.crew.any(func(m: Crew.Member) -> bool: return m.welding())
		var ev := NetSnap.events(main.breach, main.silt, main.time, welding, main.news if main.news_age < NetSnap.NEWS_TIME else [])
		ev["r"] = net_run()
		ev["w"] = main.wreck.t   # шторка «Корпус разрушен» — у всех (ART-036)
		ev["d"] = main.trip.pack()   # уход к Кристальному лесу у 10 (#828) — шторка у всех
		ev["z"] = NetSnap.scorch(main.scorch, main.time)   # следы разрядов на дне — тот же след у гостя
		ev["so"] = NetSnap.sonar(main.sonar, main.time)   # импульс и отметки голограммы — те же у гостя
		ev["c"] = main.comms.pack()   # связь ART-040: код забега, плашка и ход проверки — те же у гостя
		ev["k"] = main.lore.pack()    # знания слоя 1 (#825) — общие, подключившийся получает их сразу
		var f := NetSnap.frame(main.net_host.seq, main.time, main.helm, main.reactor, main.vitals, main.light_on, main.crew, ev)
		f["eco"] = EcoLink.pack_world(main.eco.world.agents, main.eco.world.systems, main.helm.pos, EcoLink.NET_R,
			main.eco.world.time)   # существа и мох рядом — гостям отдельным пакетом
		main.net_host.send_frame(f)


## Маршрут, голосование и итог для гостей (NetSnap.run_state): мнения ролей — по кораблю сейчас; метки — голоса
## у стола, а если голосует один — мнения ролей, как у своего игрока у стола.
func net_run() -> Dictionary:
	var ops := []
	if main.run.voting and not main.run.ended:
		ops = Run.opinions(main.vitals.hull, main.vitals.energy, main.reactor.hot, main.silt.inside != null, main.samples.cargo.size())
	var coop := main.vote_ids().size() > 1
	var marks: Dictionary = main.vote_marks() if coop or main.at_vote else VoteHolo.votes(ops)
	return NetSnap.run_state(main.run, marks, main.ballot.seconds() if coop else -1, main.ballot.fraction() if coop else -1.0,
		main.vote_panel.tally, ops, main.result_rows, main.result_detail)


## Войти в сетевой забег хоста по адресу в локальной сети: шаг корабля считает хост, здесь — свой ввод хосту
## (`net_pad` → `Client.send_pad`) и кадры хоста в корабль, реактор, корпус и экипаж; свой игрок — `crew[client.me]`.
func join_game(to: String, port: int = NetLink.PORT, player: String = "", role: int = Crew.Role.PILOT, look: int = 0) -> Error:
	if main.main_menu.open:
		main.close_menu()
	var c := NetLink.Client.new()
	var err := c.join(to, port, player, role, look)
	if err != OK:
		return err
	enter_client(c)
	return OK


## Стать клиентом хоста: c уже подключается (`join_game`) или на борту (экран адреса ART-039).
func enter_client(c: NetLink.Client) -> void:
	main.save.flush(main.samples, main.scanner)   # своё несохранённое — в файл до кадров хоста
	main.save.guest = true   # сохраняет хост (#823): кампания гостя не перетирается кадрами хоста
	own_lore = main.lore.snapshot()
	main.net_client = c
	main.net_seq = -1
	main.net_news = 0
	main.net_vote = {"secs": -1, "frac": -1.0, "tally": "", "ops": []}
	main.net_smooth = NetSmooth.new()
	main.net_pad.clear()
	main.drop = NetDrop.new()
	main.drop.menu_ready = true   # главное меню ART-037 есть: «В меню» в диалоге обрыва связи
	main.flyby.stop()   # клиент входит в идущий забег — облёта нет
	main.tutorial_guest = Tutorial.Guest.new()
	main.sonar.count = -1   # первый кадр хоста ставит его сонар, даже если счёт импульсов совпал со своим
	main.comms.reset_run(0)
	main.comms.code = ""   # кодовое слово — хоста, до первого кадра страницы «Связь» нет
	main.message.clear(Flyby.START_MSG)
	main.say(main.net_client.label())


## Шаг клиента: ввод с экрана — хосту, свежий кадр — в корабль и экипаж, дальше только картинка (без шага корабля).
func client_step(dt: float) -> void:
	var r := main.overlay.router
	var lk := main.overlay.look_points()
	main.wreck.update(dt)   # между кадрами хоста шторка идёт сама; кадр ставит время хоста
	main._wreck_show()
	main.trip.update(dt)   # шторка ухода к лесу (#828) — так же; корабль возвращает кадр хоста
	main.trip_view.apply(main.trip)
	if main.wreck.active() and not main.drop.blocks():   # шторка «Корпус разрушен»: ввод не идёт хосту
		main.net_pad.clear()
	elif main.drop.blocks():   # связь потеряна: управление остановлено, касания — кнопкам диалога
		main.net_pad.clear()
		drop_taps(r.taps)
		if main.net_client == null:   # «Играть одному» — уже одиночный забег
			r.end_frame()
			return
	else:
		main.walker.look(lk)   # взгляд сразу свой: курс хост подтвердит кадром, наклон хосту не нужен
		main.net_pad.move = Vector2(r.move)
		main.net_pad.look += lk
		main.net_pad.action = main.net_pad.action or r.action_pressed
		main.net_pad.hold = r.action_down   # держит кнопку: сварка, вентиль, лебёдка, сканер — у хоста (`CrewFlow.holds`)
		main.net_pad.vert = r.vert()
		main.net_pad.light = main.net_pad.light or r.light_pressed
	var was := main.net_client.state
	main.net_client.send_pad(main.net_pad)
	var f := main.net_client.poll(dt)
	if not f.is_empty():
		client_frame(f)
		main.drop.restored()   # хост принял снова и кадр применён — управление вернулось
	if main.net_client.lost():   # кадры хоста не идут — у товарищей «Нет связи», пока не придёт кадр
		for m: Crew.Member in main.crew:
			m.lost = m != main.me
	main.net_smooth.step(dt)
	main.net_smooth.apply(main.helm, main.crew, main.me)   # показ чуть позади свежего кадра: между кадрами — плавно
	var near := main.net_smooth.take_eco()   # существа рядом — на тех же часах показа, что корабль
	if main.net_client.state != was and not main.drop.active():
		main.say(main.net_client.label())
	drop_step(dt)
	if main.net_client == null:
		r.end_frame()
		return
	if main.drop.active():   # диалог или «Связь восстановлена» — плашка не нужна
		main.weak.reset()
	else:
		main.weak.update(dt, main.net_client.quiet)
	main.drop_panel.show_weak(main.weak)
	main.hull_motion.update(dt, main.helm.in_thrust, main.helm.in_vert, main.reactor.k(Reactor.Sys.ENGINES))
	main._wake(dt)   # пузыри у гостя — свои, по тяге из кадра
	main.searchlight.apply(main.light_on, main.reactor.k(Reactor.Sys.LAMP), main.silt.beam_k())
	main.breach.time += dt   # пульс тревоги и свет сварки — своим временем, состояние — из кадра
	if not main.scorch.all.is_empty():   # след хоста темнеет в «старое пятно» часами гостя
		main.ocean.set_scorch(main.scorch.uniforms(main.time))
	main.breach_view.apply(dt)   # частицы ART-072 у гостя — своим временем по состоянию из кадра
	main._cabin(Wreck.lamps(main.wreck.t))   # авария ART-064 у гостя — тот же ритм огней; шторка ART-036 гасит плафоны
	main._glints(dt, Wreck.lamps(main.wreck.t))
	main._wear(dt, Wreck.lamps(main.wreck.t))
	main.silt_view.apply(main.silt, main.time, main.helm.pos, main.helm.yaw)
	main.sonar_view.show_state(main.sonar, main.helm.pos, main.helm.yaw, main.time, main.reactor.k(Reactor.Sys.SONAR) > 0.0, main.silt.noise(main.time))
	client_eco(dt, near)
	main.visor.visible = main.me.welding()
	main.alarm_board.show_alarms(main.alarms_on(), main.time, main.breach.active)
	client_run_view(dt)
	var live := not (main.wreck.active() or main.drop.blocks())   # ввод, который ушёл хосту
	for ev in main.tutorial_guest.update(dt, main.pilot.seated, main.at_power, main.near_post, Vector2(r.move) if live else Vector2.ZERO,
			live and r.light_pressed, live and r.action_pressed, main.light_on, main.reactor.share, main.run.route, main.sonar.count):
		main.tutorial.note(ev)
	main.overlay_flow.step(dt)   # подсказки, карточка роли, связь, рация
	for i in Reactor.Sys.size():
		main.bridge.set_slider(i, main.reactor.share[i] / float(Reactor.MAX))
	main.overlay.set_pilot(main.pilot.seated)
	main.message.update(dt)
	main.me.back = CrewView.own_back(main.walker.pitch, main.me.holding())
	main.crew_view.pitch = main.walker.pitch
	main._apply_crew_view()
	main._place_ship()
	main._place_camera()
	main.route_card.show_card(main.brief.k, main.run.route, main.get_viewport().get_camera_3d(), main.sonar_view.global_transform,
		main.comms.code)   # код забега — из кадра хоста (`Comms.apply`)
	main._update_ui()   # до меток: плашка строки уже на месте этого кадра (#387)
	main.busy_marks.plate = main.status_rect()
	var busy := main.busy_marks.show_marks(main.crew, main.me, main.get_viewport().get_camera_3d(), main.camera)
	main.name_tags.show_tags(main.crew, main.me, main.crew_view, main.get_viewport().get_camera_3d(), main.camera, main.tag_blocks(), dt, busy,
			main.status_rect(), main.radio.voice())
	main.warm_run.frame()
	r.end_frame()


## Клиент: живой мир идёт сам, существа рядом встают по кадру хоста (`EcoView.step_client`). Удары, присоски и
## сообщения мира разбирает хост — у гостя мир событий кораблю не шлёт.
func client_eco(dt: float, near: PackedFloat32Array) -> void:
	main.eco.step_client(dt, main._fill_ship_state(false), near)


## Клиент: маршрут, голосование и итог по кадру хоста (`run` уже как у хоста) — точка и брифинг на голостоле, поля
## голосования с метками и таймером, итог над столом, панель у стола.
func client_run_view(dt: float) -> void:
	main.near_post = ""
	if not main.me.busy():
		var post := Deck.nearest(main.posts, main.walker.x, main.walker.z)
		main.near_post = post.id if post else ""
	main.sonar_view.show_waypoint(main.run.waypoint())
	main.sonar_view.show_briefing(main.brief.update(dt, Briefing.wanted(main.near_post, main.at_vote, main.run.ended)), main.run, main.helm.pos)
	main.sonar_view.show_vote(main.vote_fade.update(dt, VoteHolo.wanted(main.at_vote, main.run.ended)), main.votes, int(main.net_vote["secs"]),
		float(main.net_vote["frac"]))
	main.sonar_view.show_result(main.result_fade.update(dt, VoteHolo.result_wanted(main.at_vote, main.run.ended)), main.result_rows,
		main.camera.global_position)
	if not main.at_vote:
		main.vote_panel.visible = false
	elif main.run.ended:
		main.vote_panel.show_results(main.result_detail, main.run.score)
	else:
		main.vote_panel.show_vote(main.run.depth, main.net_vote["ops"])
		main.vote_panel.set_tally(main.net_vote["tally"])


## Кадр хоста: корабль, реактор, корпус, свет, экипаж. Свой игрок — место `me` в кадре; его курс остаётся своим
## (свайп уже повернул камеру), пока он не сел за пост или не встал — тогда курс хоста.
func client_frame(f: Dictionary) -> void:
	var yaw := main.walker.yaw
	var was_busy := main.me.busy()
	var n := main.crew.size()
	var seq := main.net_seq
	main.net_seq = NetSnap.apply_frame(f, main.net_seq, main.helm, main.reactor, main.vitals, main.crew)
	if main.net_seq != seq:
		main.net_smooth.push(float(f.get("t", 0.0)), main.helm.pos, main.helm.yaw, main.crew, f.get("eco", PackedFloat32Array()))
		var ev := NetSnap.apply_events(f.get("ev", {}), main.breach, main.silt, main.time)
		if ev.size() == 2 and ev[0] > main.net_news:   # сообщение события хоста — один раз
			main.net_news = ev[0]
			main.say(ev[1])
		var evd: Variant = f.get("ev", {})
		if evd is Dictionary:
			main.wreck.follow(float(evd.get("w", -1.0)))
			main.trip.follow(float(evd.get("d", -1.0)))
			if NetSnap.apply_scorch(evd.get("z"), main.scorch, main.time):
				main.ocean.set_scorch(main.scorch.uniforms(main.time))   # разряд хоста у дна или новый забег
			NetSnap.apply_sonar(evd.get("so"), main.sonar, main.time)
			main.comms.apply(evd.get("c"))
			main.lore.apply_net(evd.get("k"))
		var rs := NetSnap.apply_run(evd.get("r") if evd is Dictionary else null, main.run)
		if not rs.is_empty():   # маршрут хоста уже в run; метки, таймер и итог — для показа
			main.votes = rs["marks"]
			main.result_rows = rs["rows"]
			main.result_detail = rs["detail"]
			main.net_vote = rs
	main.light_on = bool(f.get("light", main.light_on))
	main.overlay.set_light(main.light_on)
	var i := main.net_client.me
	var mine: Crew.Member = main.crew[i] if i >= 0 and i < main.crew.size() else main.me
	if mine != main.me or main.crew.size() != n:
		var moved := mine != main.me
		main.me = mine
		main.walker = main.me.walker
		main.crew_view.set_members(main.crew, main.me)
		if moved:
			main.walker.pitch = 0.0
			return
	if main.me.busy() == was_busy:
		main.walker.yaw = yaw
		main.me.yaw = yaw
	elif main.me.busy():
		main.walker.pitch = 0.0


## Потеря хоста у гостя (ART-043): не соло молча — диалог и попытка переподключения на NetDrop.WINDOW; отказ хоста
## при попытке — причина без повторов; окно истекло — «Нет ответа». Отказ при первом входе — одиночная игра.
func drop_step(dt: float) -> void:
	var st := main.net_client.state
	if st == NetLink.State.LOST and not main.drop.blocks():
		main.drop.open()
		main.net_client.rejoin(NetDrop.WINDOW)
	elif main.drop.blocks():
		if st == NetLink.State.REFUSED and main.net_client.why in ["version", "full"]:
			main.drop.refused(main.net_client.why)
		if main.drop.update(dt):
			main.net_client.stop()
	elif st == NetLink.State.REFUSED:
		leave_net()
		return
	else:
		main.drop.update(dt)
	main.drop_panel.show_drop(main.drop)


## Касания кнопок диалога «Связь потеряна».
func drop_taps(taps: Array[Vector2]) -> void:
	for p in taps:
		match main.drop.press(main.drop.hit(p, main.get_viewport().get_visible_rect().size)):
			"rejoin":
				main.net_client.rejoin(NetDrop.WINDOW)
			"solo":   # перенос забега в соло не сделан — своя кампания с последнего сохранения (#823)
				leave_net()
				if main.me.pilot.seated:
					main.me.stand()
				main._load_last()
			"menu":   # «В меню» (ART-043): сетевой забег покинут, главное меню ART-037
				leave_net()
				main.menu_flow.to_menu()
		main.drop_panel.show_drop(main.drop)
		if main.net_client == null:
			return


## Связь с хостом кончилась (отказ при входе или «Играть одному»): дальше одиночная игра с последним кадром.
func leave_net() -> void:
	main.net_client.stop()
	main.net_client = null
	main.tutorial_guest = null
	main.save.guest = false   # снова своя кампания: свои знания вместо пришедших от хоста (#823)
	main.lore.apply(own_lore)
	main.wreck.reset()   # шторка хоста — не своя: одиночный забег без неё
	main._wreck_show()
	main.trip.follow(-1.0)   # и шторка ухода к лесу (#828)
	main.trip_view.apply(main.trip)
	main.weak.reset()
	main.drop_panel.show_weak(main.weak)
	main.crew = [main.me]
	main.me.lost = false
	main.crew_view.set_members(main.crew, main.me)


