extends SceneTree
## Скриншот главной сцены без телефона.
## xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1600x720 -s tools/shot.gd -- out.png [ключ=значение ...]
## Ключи: x, z, yaw, pitch — игрок на палубе (yaw в градусах, 0 — к носу); noclip=1 y=<м> — тестовый полёт (глаз в x,y,z, сквозь корпус — смотреть живой мир); frames — сколько кадров ждать;
## pilot=1 — сесть за штурвал; thrust, turn, vert — ввод пилота; secs — сколько секунд вести корабль до снимка;
## light=0 — погасить прожектор; lock=1 — шлюз трюма открыт (lock_event=enter|exit — кольца троса / всплеск в воде шахты ART-073, lock_age=<с>); zap=1 — разряд (рычаг внизу, шкала погашена), zap_age=<с> — дуги по обшивке ART-068 через столько секунд (у окна — до 0,22 с, у дна — если киль ≤ 3 м над дном); ping=1 — импульс сонара с пробными отметками (age=<с> после импульса); power=1 — встать к пульту энергии; hot=<градусы> — перегрев реактора; energy=<ед.> — заряд корабля; hull=<%> — прочность корпуса (следы ART-049 снаружи, потёки и мокрый пол внутри ART-074); relief=0 — обшивка, мостик и лёд без рельефа ART-053/054/056, взвесь ART-058 «Экономно»; drain=1 — стеклоуст на корпусе; ship=x,y,z — поставить корабль (например ship=200,-80,0 — глубокий склон на востоке); view=x,y,z — камера снаружи в осях корабля (корпус). mate=x,z,курс[,роль[,внешность 0…1]] — ещё один член экипажа на палубе, несколько — через «;» (mate=helm — за штурвалом, mate=energy — инженер у пульта: метка «Занято» ART-033 вблизи), mate_hold=1 hold_s=<с> — последний из них держит кнопку действия столько секунд (сварка пробоины с breach=n, вентиль, сканер), tag=a;l;- — состояния их табличек ART-033 (a — нажимает, l — нет связи), gone=1 — последний из них отключился (плашка хоста ART-043); cargo=0,2,1 — виды образцов в трюме (и в колбах лаборатории). save=<путь> — груз и поднятые образцы из файла сохранения. silt=1 — корабль в облаке ила (сонарная тьма). breach=n — пробоина в месте n (0 мостик … 3 машинное), weld=<доля>, water=<м>. observe=fish:flee,pred:ping — наблюдения в журнале, scanned=fish — изученные виды, journal=n — страница журнала (0 — сводка). route=n — маршрут забега n (0…2) выбран у голостола; vote=1 — маршрут пройден, решение «глубже или наверх», vote=coop — двое у стола (с mate=…), свой голос «глубже», ждём товарища; vote=up — итог забега (с мостика: итог на голограмме; с flyby=surface — вид с борта). flyby=start|surface — камера с борта (облёт в начале забега, вид при всплытии), age=<с> от начала облёта. vent=<с> — выпуски пузырей у сервисных крышек ART-063 через столько секунд после продувки (след винтов — по thrust и secs). grade=0 — без виньетки и цветокоррекции ART-065 (relief=0 — только овал «Экономно»). glints=0 — без бликов воды на потолке и полу мостика ART-067 (relief=0 — тоже выкл). layers=<сила> — слои воды ART-069: 0 — выкл (как relief=0), 0.6 — «Обычно», 0.9 — «Красиво». wreck=<с> — шторка «Корпус разрушен» (ART-036) на этом времени. splash=<доля> — заставка прогрева (ART-034), hint=<с> — подсказка на это время. menu=1 — главное меню ART-037 (как при запуске). sbor=entry|list|join|host|all|guest|taken|lost — экран сбора экипажа ART-028 (вход — поиск забегов: entry — пусто, sbor_search=1 — «Ищем забеги…», list — два найденных, join — подключаемся, sbor_why=lost|port|full|timeout; хост ждёт / все готовы / глазами гостя / роль занята / связь потеряна, sbor_retry=1|timeout), у хоста «Ваш адрес» ART-039 — sbor_adres=<адрес> (- — «Нет адреса сети»). adres=<поле> (- — пустое), last=<адрес>, adres_state=connecting|timeout|full|version — экран «Войти по адресу» ART-039. pause=1|new|exit|leave — пауза ART-037 (new / exit / leave — с подтверждением), pause_mode=host|guest — «Меню забега» коопа. shema=1|door — схема корабля ART-042 поверх паузы (door — люк коридор → лаборатория открыт; с breach=n, hot=…, drain=1 — тревога янтарём, с mate=… — товарищи). nastrojki=1|reset|grafika|zvuk|golos — настройки ART-037 поверх паузы (reset — подтверждение сброса, zvuk — громкости шин (zvuk=<доля> музыки), grafika — страница ART-044, уровень grafika=0|1|2 — и в сцене; golos — страница рации ART-041, golos=voice|mute|nomic — «По голосу», звук товарищей выкл., нет разрешения микрофона), kadry=1 — счётчик кадров ART-044, с menu=1 — поверх главного меню. zhurnal=1|empty|old|broken — «Журнал экспедиции» ART-047 из меню (3 места, 5 забегов, 340 м; empty — первый запуск, old — старое сохранение без истории, broken — испорченный файл), pick=<место> — касание места на карте, jpage=n — страница сетки видов, jask=<вид> — касание неизученного («Изучите вид сканером»), jcard=<вид> — карточка изученного (fish). scorch=n — n следов разряда ART-066 на дне перед носом (первый — старое пятно). podskazki=<1…6> — подсказка первого забега ART-038 на этом шаге (done=1 — «Выполнено», guest=1 — как у гостя сети: без сонара, «n / 5»). ekonomno=1 — предложение «Экономно» ART-044 после низких кадр/с. kartochka=1|ask|foreign — карточка роли ART-045 у поста под игроком (x/z), свёрнутая в «?», плашка чужой роли. use=<пост> — нажать кнопку действия у поста (scram, zap, sonar…; без x/z — игрок шагает к посту сам), снимок 0,3 с спустя — frames=1. svyaz=1|fake|wait|match|wrong|exposed|silent — плашка внутренней связи ART-040 (своё сообщение, подделка «Код: …», «Ждём ответ…», «Код совпал», чужой код, «Это был не наш», «Нет ответа»); vyrez=<px> — вырез телефона слева (безопасная область, #603). raciya=idle|talk|nomic|mute|two|wall|voice — рация ART-041 (покой «Удерживайте», «Вас слышно» с говорящим Игорем, нет разрешения микрофона, звук товарищей выкл., говорят двое, товарищ за стеной, режим «По голосу»; с mate=… первый товарищ — Игорь, его табличка ART-033 в «активности»). hud=0 — без крестовины, кнопок и строк приборов; kadr=<1…4> — ещё и кадр Google Play ART-046 (1920×1080, подпись n-го шаблона, снимок в рамке 16:9 с полями) в <out>-kadr.png.


const ShotSetup := preload("res://tools/shot_setup.gd")

func _initialize() -> void:
	SaveGame.default_path = ""   # не читать и не писать сохранение игрока
	AddressScreen.default_path = ""   # и последний адрес входа ART-039
	Settings.default_path = ""   # и настройки ART-037
	RunTimeline.default_path = ""   # и хронометраж забегов (#633)
	Main.intro = false   # снимок с мостика; flyby=start|surface — вид с борта
	Main.menu = "menu=1" in OS.get_cmdline_user_args()   # menu=1 — главное меню ART-037 поверх сцены
	Main.hints = false   # подсказки первого забега ART-038 — только по podskazki=<шаг>
	Main.offer = false   # предложение «Экономно» ART-044 — только по ekonomno=1
	_go.call_deferred()


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var out := "shot.png"
	var kv := {}
	for a in args:
		if a.contains("="):
			var p := a.split("=", true, 1)
			kv[p[0]] = p[1]
		else:
			out = a
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	while main.has_method("warming") and main.warming():   # прогрев шейдеров под шторкой (Warmup)
		await process_frame
	if kv.has("save"):  # save=<путь> — груз и поднятые образцы из файла сохранения (как при запуске игры)
		var sg := SaveGame.new()
		sg.path = kv["save"]
		print("сохранение: ", sg.load_into(main.samples))
	ShotSetup.apply(main, kv)
	var w = main.get("walker")
	if w:
		if kv.has("x"): w.x = float(kv["x"])
		if kv.has("z"): w.z = float(kv["z"])
		if kv.has("yaw"): w.yaw = deg_to_rad(float(kv["yaw"]))
		if kv.has("pitch"): w.pitch = deg_to_rad(float(kv["pitch"]))
		if kv.has("noclip"): w.noclip = kv["noclip"] != "0"   # тестовый полёт: глаз в (x, y, z), сквозь корпус
		if kv.has("y"): w.y = float(kv["y"])
	if kv.has("splash"):   # splash=<доля 0…1> — заставка прогрева ART-034 поверх сцены, hint=<с> — время подсказки
		var sp := WarmSplash.new()
		root.add_child(sp)
		sp.set_progress(float(kv["splash"]))
		sp._process(float(kv.get("hint", "0")))
	if kv.has("wreck"):   # wreck=<с> — шторка «Корпус разрушен» ART-036 через столько секунд после разрушения
		main.vitals.hull = 0.0
		main.vitals.destroyed.emit()
		while main.wreck.active() and main.wreck.t < float(kv["wreck"]):
			main.step(1.0 / 30.0)
		main.set_process(false)   # кадр — ровно на этом времени шторки
	if kv.has("zap_age"):   # zap=1 zap_age=<с> — дуги по обшивке ART-068 через столько секунд после разряда
		main.step(0.0)
		while main.zap.flicker > 0.0 and Zap.arc_time(main.zap.flicker) < float(kv["zap_age"]) - 1e-3:
			main.step(1.0 / 30.0)
		main.set_process(false)   # кадр — ровно на этом времени разряда
	if kv.has("wear_t"):   # hull=<%> wear_t=<с> — частицы износа ART-074 ровно в этот момент (0,05 — пакет искр)
		main.time = float(kv["wear_t"])
		main.step(0.0)
		main.set_process(false)
	if kv.has("lock_event"):   # lock=1 lock_event=enter|exit — событие троса ART-073 ровно на lock_age
		main.set_process(false)
		main.lock_water.event_age = float(kv.get("lock_age", "0.36"))
		main.step(0.0)
	if kv.has("podskazki"):   # podskazki=<1…6>[ done=1] — подсказка первого забега ART-038 на этом шаге («Выполнено»)
		main.tutorial.on = true
		main.tutorial.step = clampi(int(kv["podskazki"]) - 1, 0, Tutorial.STEPS.size() - 1)
		main.tutorial.a = 1.0
		if kv.get("done", "0") != "0":
			main.tutorial.done_t = 0.0
		if kv.get("guest", "0") != "0":   # guest=1 — как у гостя сети: без шага сонара, «n / 5»
			main.tutorial.set_guest(true)
		main.step(0.0)
		if kv.get("done", "0") != "0":
			main.set_process(false)   # кадр — на «Выполнено», а не на следующем шаге
	if kv.has("kartochka"):   # kartochka=1|ask|foreign — карточка роли ART-045 у поста под игроком (x/z), «?», чужая роль
		main.tutorial.on = false
		main.role_card.on = true
		main.role_card.set_read(RoleCard.CARDS.keys() if kv["kartochka"] == "ask" else [])
		for i in 6:
			main.step(0.05)
		if kv["kartochka"] == "foreign":
			main.role_card.open = false
			main.role_card.a = 0.0
			main.role_card.foreign = main.role_card.post
			main.role_card.f = 1.0
			main.role_card.own = false
			main.role_card_panel.show_card(main.role_card, Rect2())
	if kv.has("vyrez"):   # vyrez=<px> — вырез телефона слева: крестовина и плашки — от безопасной области (#603)
		var vis := main.get_viewport().get_visible_rect()
		var cut := float(kv["vyrez"])
		main.overlay.router.layout.compute(Rect2(vis.position.x + cut, vis.position.y, vis.size.x - cut, vis.size.y))
		main.overlay.queue_redraw()
	if kv.has("svyaz"):   # svyaz=1|fake|wait|match|wrong|exposed|silent — плашка внутренней связи ART-040 в этом состоянии
		var v: String = kv["svyaz"]
		main.comms.reset_run(0)
		var fake := v in ["fake", "wrong", "exposed", "silent"]
		main.on_eco_event(EcoLink.voice(Crew.Role.PILOT if fake else Crew.Role.ENGINEER,
			"Дайте импульс сонара" if fake else "Сбросьте ход, перегрев", fake, "ping" if fake else "", v == "silent"))
		for i in 6:
			main.step(0.05)
		var states := {"wait": Comms.Ask.WAIT, "match": Comms.Ask.MATCH, "wrong": Comms.Ask.WRONG,
			"exposed": Comms.Ask.EXPOSED, "silent": Comms.Ask.SILENT}
		if states.has(v):
			main.comms.state = states[v]
		main.comms_panel.show_comms(main.comms, main.time, main.comms_area())
	if kv.has("raciya"):   # raciya=idle|talk|nomic|mute|two|wall|voice — рация ART-041 в этом состоянии
		var v: String = kv["raciya"]
		var r: Radio = main.radio
		r.pinned = true
		r.on = true
		r.link = true   # как будет с голосом: «Вас слышно» — только когда голос уходит
		r.mic = v != "nomic"
		r.hear = v != "mute"
		r.mode = Radio.Mode.VOICE if v == "voice" else Radio.Mode.HOLD
		if v not in ["idle", "nomic", "mute"]:
			r.heard(1, "Игорь", Crew.Role.ENGINEER, 0.8, v != "wall")
			if main.crew.size() > 1:   # с mate=… — над ним табличка ART-033 в «активности» (wall — без неё)
				main.crew[1].name = "Игорь"
				main.crew[1].role = Crew.Role.ENGINEER
		if v == "two":
			r.heard(2, "Марина", Crew.Role.BIOLOGIST, 0.5)
		var down := v in ["talk", "two", "wall", "nomic", "voice"]
		r.update(0.3, down, false)
		if v == "voice":
			r.update(0.0, false, false)
		main.radio_panel.show_radio(r, main.time)
	if kv.has("nastrojki"):   # nastrojki=1|reset — настройки ART-037 (поверх паузы; с menu=1 — поверх меню)
		if not Main.menu:
			main.back_pressed()
		main.open_settings()
		if kv["nastrojki"] == "reset":
			main.settings.press("reset")
		if kv["nastrojki"] == "grafika":   # страница «Настройки · Графика» ART-044 (уровень — grafika=0|1|2)
			main.settings.press("graphics")
			main.settings.graphics = Graphics.valid(int(kv.get("grafika", "1")))
		if kv["nastrojki"] == "zvuk":   # страница «Настройки · Звук» (zvuk=<доля> — музыка, остальные 100 %)
			main.settings.press("zvuk")
			if kv.has("zvuk"):
				main.settings.set_bus(SoundMix.MUSIC, float(kv["zvuk"]))
		if kv["nastrojki"] == "golos":   # страница «Настройки · Голос» ART-041 (golos=voice|mute|nomic)
			main.settings.press("golos")
			var g: String = kv.get("golos", "")
			if g == "voice":
				main.settings.press("v_voice")
			if g == "mute":
				main.settings.press("v_hear")
			if g == "nomic":
				main.radio.mic = false
		main._settings_show()
	if kv.get("ekonomno", "0") == "1":   # ekonomno=1 — предложение «Телефон не справляется» ART-044
		main.lite_offer.force()
		main.lite_offer_panel.show_offer(main.lite_offer)
	if kv.get("kadry", "0") == "1":   # kadry=1 — счётчик кадров ART-044 у правого края
		main.settings.fps = true
		main._apply_settings()
		for i in 40:
			main.fps_view.push(1.0 / 58.0)
	if kv.has("pause"):   # pause=1|new|exit|leave — пауза ART-037 по «Назад», new / exit / leave — подтверждение;
		main.back_pressed()   # pause_mode=host|guest — «Меню забега» сетевого забега (без сети, только вид)
		main.pause.mode = str(kv.get("pause_mode", main.pause.mode))
		if kv["pause"] in ["new", "exit", "leave"]:
			main.pause.press(kv["pause"])
		main.pause_panel.show_pause(main.pause)
		if kv.has("pause_mode"):
			main.set_process(false)   # без сети меню забега закрылось бы следующим шагом
	if kv.has("shema"):   # shema=1|door — схема корабля ART-042 из паузы (door — люк в лабораторию открыт; тревога —
		if not main.pause.open:   # breach=n / hot=… / drain=1, товарищи — mate=…)
			main.back_pressed()
		if kv["shema"] == "door":
			main.layout.doors[1].open = true
			main.layout.doors[1].t = 1.0
		main.open_map("pause")
	if kv.has("zhurnal"):   # zhurnal=1|empty|old|broken — «Журнал экспедиции» ART-047 (pick=<место> — касание карты)
		Main.menu = true
		main.open_menu()
		var e: Expedition = main.expedition
		e.clear()
		if kv["zhurnal"] in ["1", "broken"]:
			for k in ["flower", "bones", "well"]:
				var p: Vector2 = Run.place_xz(k)
				e.visit(p.x, p.y)
			e.runs = 5
			e.deepest = 340
			for k in ["fish", "pred", "eel"]:   # изучены три вида, у двух карточки прочитаны — «новое» у светляка
				if Species.has(k):
					main.scanner.scanned[k] = true
			main.scanner.observe("fish", "flee")
			e.mark_read("pred")
			e.mark_read("eel")
		if kv["zhurnal"] == "old":
			e.full = false
			main.samples.cargo.append([0, -1])
		if kv["zhurnal"] == "broken":
			main.save.state = SaveGame.Load.BROKEN
		main.open_journal()
		if kv.has("pick"):
			main.logbook.press("place:" + str(kv["pick"]))
		for i in int(kv.get("jpage", "0")):
			main.logbook.press("next")
		if kv.has("jask"):
			main.logbook.press("species:" + str(kv["jask"]), main.scanner.scanned, e)
		if kv.has("jcard"):
			main.logbook.press("species:" + str(kv["jcard"]), main.scanner.scanned, e)
		main._journal_show()
	if kv.has("adres"):   # adres=<текст поля>[ last=<адрес>] [adres_state=connecting|timeout|full|version] — «Войти по адресу» ART-039
		Main.menu = true
		main.open_menu()
		main.address.field.last = str(kv.get("last", ""))
		main.open_address()
		main.address.field.text = "" if kv["adres"] == "-" else str(kv["adres"])
		var st := str(kv.get("adres_state", ""))
		if st != "":
			main.address.field.connecting = true
			if st != "connecting":
				main.address.result(NetLink.State.REFUSED, st)
		main.address_panel.show_screen(main.address)
	if kv.has("drop"):   # drop=wait|retry|no|refused|solo|back — диалог «Связь с хостом потеряна» (ART-043), t=<с> в окне
		var d := NetDrop.new()
		d.open()
		match kv["drop"]:
			"retry":
				d.update(NetDrop.WINDOW)
				d.press("wait")
			"no":
				d.update(NetDrop.WINDOW)
			"refused":
				d.refused("full")
			"solo":
				d.press("solo")
			"back":
				d.restored()
		d.update(float(kv.get("t", "3.2")))
		var dp := DropPanel.new()
		root.add_child(dp)
		dp.show_drop(d)
	if kv.has("weak"):   # weak=1 — плашка «Слабая связь» у гостя (ART-043)
		var wl := WeakLink.new()
		wl.update(1.0, NetLink.WEAK_AFTER + 0.1)
		var wp := DropPanel.new()
		root.add_child(wp)
		wp.show_weak(wl)
	if kv.has("sbor"):   # sbor=host|all|guest|taken — экран сбора экипажа ART-028 (комната на троих / четверых)
		main.overlay.visible = false   # на экране сбора крестовины и кнопки действия нет (ART-028)
		main.hint.visible = false
		var lb := Lobby.new()
		var ad: String = kv.get("sbor_adres", "192.168.43.17")   # адрес хоста ART-039; - — нет сети
		lb.host("Игрок 1", "" if ad == "-" else ad)
		lb.open = true
		lb.add(2, "Игорь")
		lb.add(3, "")
		lb.act(2, "role:1")
		lb.act(2, "ready")
		lb.act(3, "role:2")
		lb.act(3, "ready")
		match kv["sbor"]:
			"entry", "list", "join":   # вход по «Экипаж» — поиск забегов; sbor_why=lost|port|full|timeout — итог попытки
				lb.show_entry(kv.get("sbor_why", ""))   # list — найдено два забега, join — подключаемся к первому
				lb.searching = kv.get("sbor_search", "0") == "1"
				if kv["sbor"] != "entry":
					for d: Dictionary in [{"name": "Лена", "n": 2, "free": [2, 3]}, {"name": "Игорь", "n": 4, "free": []}]:
						var f := RunBeacon.Found.new()
						f.name = d["name"]
						f.players = d["n"]
						f.vacant.assign(d["free"])
						lb.runs.append(f)
					if kv["sbor"] == "join":
						lb.joining = 0
			"host":   # главный кадр: хост — пилот, ещё «Ждём»
				lb.press("pick0")
			"all":   # все готовы: старт у хоста
				lb.press("pick0")
				lb.press("ready")
			"guest", "taken", "lost":   # глазами гостя «Игрок 3»; taken — пришёл четвёртым и попросил занятую роль;
				# lost — связь с хостом пропала (sbor_retry=1 — «Подключаемся…», sbor_retry=timeout — повтор не удался)
				lb.act(Lobby.HOST, "role:0")
				lb.act(Lobby.HOST, "ready")
				var d := lb.pack()
				lb = Lobby.new()
				lb.open = true
				lb.me = 3
				if kv["sbor"] == "taken":
					d["p"].pop_back()   # пришёл только что: роли ещё нет
					d["p"].append([3, "Игрок 3", -1, false])
					lb.answer("taken", "role:0")
				lb.unpack(d)
				if kv["sbor"] == "lost":
					lb.lose()
					match kv.get("sbor_retry", ""):
						"1":
							lb.press("retry")
						"":
							pass
						var fail:
							lb.retry_failed(fail)
		lb.open = true
		var lp := LobbyPanel.new()
		root.add_child(lp)
		lp.show_lobby(lb)
	if kv.get("hud", "1") == "0":   # hud=0 — без крестовины, кнопок и строк приборов (кадры для магазина)
		main.set_hud(false)
	for i in int(kv.get("frames", "8")):
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out)
	if kv.has("kadr"):   # kadr=<1…4> — ещё и кадр Google Play ART-046 1920×1080 с подписью: <out>-kadr.png
		var cap: Image = await PlayCaption.render(root, PlayFrame.caption(int(kv["kadr"])))
		PlayFrame.compose(img, cap).save_png(out.get_basename() + "-kadr.png")
	print("SHOT ", out, " ", img.get_size(), " вызовов отрисовки: ",
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		", примитивов: ", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	quit(0)
