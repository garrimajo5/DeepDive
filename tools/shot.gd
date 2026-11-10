extends SceneTree
## Скриншот главной сцены без телефона.
## xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1600x720 -s tools/shot.gd -- out.png [ключ=значение ...]
##
## Ключи — таблица ниже, строка на ключ: «ключ=пример — что делает». Новый ключ — новая строка; тест `test_shot_keys`
## падает, если ключ в таблице дважды (ключ уже занят — возьми другой, #1368), если ключа из кода нет в таблице
## и если ключа таблицы нет в коде (`tools/shot.gd`, `tools/shot_setup.gd`).
##
## --- Игрок и камера
## x=1.5 — игрок на палубе: x в осях корабля (правый борт +), м
## z=-3 — игрок на палубе: z в осях корабля (нос −), м
## yaw=0 — курс взгляда игрока, градусы (0 — к носу, растёт влево)
## pitch=-10 — наклон взгляда, градусы
## noclip=1 — тестовый полёт: глаз в x, y, z в осях корабля (не мира), сквозь корпус — смотреть живой мир
## y=-6 — высота глаза в noclip, в осях корабля (палуба — около 0)
## frames=30 — сколько кадров ждать до снимка
## view=14,3,-16 — камера снаружи в осях корабля (корпус)
## hud=0 — без крестовины, кнопок и строк приборов
## kadr=1 — ещё и кадр Google Play ART-046 (1…4: 1920×1080, подпись n-го шаблона, снимок в рамке 16:9) в <out>-kadr.png
## vyrez=80 — вырез телефона слева, px (безопасная область, #603)
##
## --- Корабль и пилот
## pilot=1 — сесть за штурвал (взгляд −8°, Deck.SEAT_PITCH)
## wheel=0.5 — колесо и руки в повороте без хода (доля −1…1)
## thrust=1 — ввод пилота: ход
## turn=0.5 — ввод пилота: поворот
## vert=-1 — ввод пилота: всплытие/погружение
## secs=3 — сколько секунд вести корабль до снимка
## ship=200,-80,0 — поставить корабль x,y,z[,курс°] (y — высота, глубина со знаком минус; 200,-80,0 — склон на востоке)
## place=07 — корабль у места слоя 1 (LayerMap.POINTS или ключ Run.PLACES: shell) носом к ориентиру, камера снаружи (#1358)
## place_cam=back — front — перед носом, back — позади-выше
## place_dist=38 — расстояние от ориентира, м
## place_side=0 — откуда смотреть, ° (0 — с юга; по умолчанию со стороны середины карты)
## scena=1 — контрольный ракурс сцены 00 → 01 (#1400): 1 — выход из 00, 2 — середина, 3 — подход к 01; в лог — дальность грунта в окнах
## scena_back=15 — с scena=: точка на столько метров раньше по тому же пути, высота — плавный ход в ней, нос к 01
## scena_yaw=10 — курс левее на столько градусов (минус — правее)
## scena_t=4 — мир идёт столько секунд, корабль висит в точке (кадры движения)
## scena_y=-34.9 — высота хода руками, м; scena_y=dno — 7 м над дном в точке; без ключа — плавный ход tools/pass_box.gd (контур 20×30); в лог — фактический y и источник
## zamer=bok — с scena=: фаза «замер» #1498 включена в снимке (4 с, отход 20 с); серпохвост №0 за 26 м: bok — справа, korma — за кормой, nos — перед носом; остальные уведены
## zamer_off=2 — с zamer=: погасить прожектор через столько секунд мира (ответ экипажа, дальше отход)
## budget=1 — после снимка в лог: вызовы и примитивы по частям сцены — без какой части сколько меньше (#1400, бюджет ART-044; 2 — ещё и дети «Отмели», «Живого мира» и «Корабля»)
## strah=40 — с scena=: голодный хищник №0 за стаей рифа у 01 на столько метров (причина — с дальней стороны); в лог раз в секунду — хищник и стая (#1400)
## light=0 — погасить прожектор
## power=1 — встать к пульту энергии
## hot=80 — перегрев реактора, градусы
## energy=20 — заряд корабля, ед.
## hull=40 — прочность корпуса, % (следы ART-049 снаружи, потёки и мокрый пол внутри ART-074)
## wear_t=0.05 — с hull=: частицы износа ART-074 ровно в этот момент (0,05 — пакет искр)
## relief=0 — без рельефа обшивки, мостика и льда ART-053/054/056, взвесь ART-058 «Экономно», без бликов и слоёв воды
## grade=0 — без виньетки и цветокоррекции ART-065
## glints=0 — без бликов воды на потолке и полу мостика ART-067
## layers=0.6 — слои воды ART-069: 0 — выкл, 0.6 — «Обычно», 0.9 — «Красиво»
## drain=1 — стеклоуст на корпусе
## lock=1 — шлюз трюма открыт
## lock_event=enter — кольца троса (enter) или всплеск (exit) в воде шахты ART-073
## lock_age=0.5 — через столько секунд после lock_event
## zap=1 — разряд (рычаг внизу, шкала погашена)
## zap_age=0.1 — дуги по обшивке ART-068 через столько секунд (у окна — до 0,22 с, у дна — если киль ≤ 3 м над дном)
## scorch=3 — следов разряда ART-066 на дне перед носом (первый — старое пятно)
## ping=1 — импульс сонара с пробными отметками; с silt=1 — импульс завяз
## age=1 — секунд после импульса (ping=1) или от начала облёта (flyby=)
## silt=1 — корабль в облаке ила (сонарная тьма)
## jam_age=0.4 — с silt=1 ping=1: секунд после завязшего импульса (ART-048)
## breach=0 — пробоина в месте n (0 мостик … 3 машинное)
## weld=0.5 — доля заварки пробоины
## water=0.3 — вода от пробоины, м
## steam=1 — пар из вентиля и открытая крышка щитка (снимок машинного)
## vent=2 — выпуски пузырей у сервисных крышек ART-063 через столько секунд после продувки (след винтов — по thrust и secs)
## sample=0 — корабль над образцом n, шлюз открыт
## grab=1 — с sample=: столько секунд держать кнопку у лебёдки
## cargo=0,2,1 — виды образцов в трюме (и в колбах лаборатории)
## save=user://save.json — груз и поднятые образцы из файла сохранения
## kamen=2 — у рядов каменщиков первые n гнёзд спрятали венчики (#1337)
## use=sonar — нажать кнопку действия у поста (scram, zap, sonar…; без x/z игрок шагает к посту сам), снимок 0,3 с спустя — frames=1
## flyby=start — камера с борта: start — облёт в начале забега, surface — вид при всплытии
##
## --- Экипаж и сеть
## mate=helm — ещё член экипажа: x,z,курс[,роль[,внешность 0…1]], несколько — через «;» (helm — за штурвалом, energy — у пульта: «Занято» ART-033)
## mate_hold=1 — последний товарищ держит кнопку действия (сварка с breach=, вентиль, сканер)
## hold_s=1.5 — сколько секунд держит
## tag=a;l;- — таблички товарищей ART-033 (a — нажимает, l — нет связи)
## gone=1 — последний товарищ отключился (плашка хоста ART-043)
## drop=wait — диалог «Связь с хостом потеряна» ART-043: wait|retry|no|refused|solo|back
## t=3.2 — с drop=: секунд в окне ожидания
## weak=1 — плашка «Слабая связь» у гостя ART-043
## svyaz=1 — плашка внутренней связи ART-040: 1|fake|wait|match|wrong|exposed|silent
## svyaz_text=… — с svyaz=: своя реплика на плашке, в кавычках целиком («svyaz_text=Сбросьте ход»): длина новых строк без правки снимка
## raciya=talk — рация ART-041: idle|talk|nomic|mute|two|wall|voice (с mate=… первый товарищ — Игорь)
##
## --- Забег, слой 1, мир
## route=2 — маршрут забега n (0…5) выбран у голостола; с pilot=1 — плашка цели #1344
## goal_yaw=30 — цель на столько градусов левее (минус — правее)
## vote=1 — решение «глубже или наверх»: 1 | coop — двое у стола (с mate=…) | up — итог забега (с flyby=surface — вид с борта)
## spusk_vote=1 — корабль в круге 10, панель «Спуск к Кристальному лесу» (#1362): 1|later|coop
## spusk=2 — уход к Кристальному лесу у 10 (#828): шторка через столько секунд после «глубже»
## lore=d07_return,shell03 — знания слоя 1 (LayerLore.KEYS)
## observe=fish:flee,pred:ping — наблюдения в журнале
## scanned=fish — изученные виды
## journal=1 — страница журнала лаборатории (0 — сводка, 1…2 — архив К-2, дальше карточки видов)
## brif=1 — брифинг прибытия TXT-001 (#827) на экране n (1…8)
## podskazki=3 — подсказка первого забега ART-038 на шаге 1…7
## done=1 — с podskazki=: «Выполнено»
## guest=1 — с podskazki=: как у гостя сети (без курса к цели, «n / 6»)
## kartochka=1 — карточка роли ART-045 у поста под игроком (x/z): 1|ask — свёрнута в «?»|foreign — чужая роль
## wreck=1 — шторка «Корпус разрушен» ART-036 на этом времени, с
## wreck_save=1 — есть сохранение кампании: подпись о возврате (#824)
##
## --- Экраны меню
## menu=1 — главное меню ART-037 (как при запуске)
## prodolzhit=1 — с «Продолжить» (есть сохранённый корабль, #823)
## splash=0.5 — заставка прогрева ART-034 на этой доле
## hint=2 — время подсказки заставки, с
## sbor=host — сбор экипажа ART-028: entry|list|join|host|all|guest|taken|lost
## sbor_search=1 — на входе «Ищем забеги…»
## sbor_why=lost — итог подключения: lost|port|full|timeout
## sbor_retry=1 — связь потеряна: 1|timeout
## sbor_adres=192.168.0.5 — «Ваш адрес» у хоста ART-039 (- — «Нет адреса сети»)
## adres=192.168 — экран «Войти по адресу» ART-039 с этим полем (- — пустое)
## last=192.168.0.5 — последний адрес
## adres_state=connecting — connecting|timeout|full|version
## pause=1 — пауза ART-037: 1|new|exit|leave|saved
## pause_mode=host — «Меню забега» коопа: host|guest
## shema=1 — схема корабля ART-042 поверх паузы: 1|door (люк коридор → лаборатория открыт)
## nastrojki=1 — настройки ART-037 поверх паузы: 1|reset|grafika|zvuk|golos
## grafika=1 — уровень графики ART-044 (0|1|2) — и в сцене
## zvuk=0.5 — на странице «Звук»: доля громкости музыки
## golos=voice — страница рации ART-041: voice|mute|nomic
## kadry=1 — счётчик кадров ART-044 (с menu=1 — поверх меню)
## ekonomno=1 — предложение «Экономно» ART-044 после низких кадр/с
## zhurnal=1 — «Журнал экспедиции» ART-047: 1|empty|old|broken
## pick=05 — касание места на карте журнала
## jpage=1 — страница сетки видов (с jtab=lore — «Узнано»)
## jask=fish — касание неизученного вида («Изучите вид сканером»)
## jcard=fish — карточка изученного вида
## jtab=lore — вкладка «Узнано» журнала (#825; знания — lore=…)
## pole=1 — поле 08 замечено, «граница» у 08 (#829)


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
		if kv.has("wreck_save"):   # wreck_save=1 — есть сохранённое место: подпись о возврате к нему (#824)
			main.save.ship = SaveGame.ship_read(SaveGame.ship_snapshot(main.helm, main.vitals))
		main.vitals.hull = 0.0
		main.vitals.destroyed.emit()
		while main.wreck.active() and main.wreck.t < float(kv["wreck"]):
			main.step(1.0 / 30.0)
		main.set_process(false)   # кадр — ровно на этом времени шторки
	if kv.has("spusk"):   # spusk=<с> — уход к Кристальному лесу у 10 (#828): шторка через столько секунд после «глубже»
		var at := Run.place_xz(Run.DESCENT)
		main.park_at(Vector3(at.x, Seabed.height(at.x, at.y) + 20.0, at.y))
		main.step(1.0 / 30.0)
		main.decide("deep")
		while main.trip.active and main.trip.t < float(kv["spusk"]):
			main.step(1.0 / 30.0)
		main.set_process(false)
	if kv.has("zap_age"):   # zap=1 zap_age=<с> — дуги по обшивке ART-068 через столько секунд после разряда
		main.step(0.0)
		while main.zap.flicker > 0.0 and Zap.arc_time(main.zap.flicker) < float(kv["zap_age"]) - 1e-3:
			main.step(1.0 / 30.0)
		main.set_process(false)   # кадр — ровно на этом времени разряда
	if kv.has("wheel"):   # wheel=<доля −1…1> — колесо штурвала и руки пилота в повороте без хода (приёмка штурвала #1402)
		main.helm.turn = clampf(float(kv["wheel"]), -1.0, 1.0)
		main.step(0.0)
		main.set_process(false)   # кадр — ровно в этом повороте, руль не возвращается к нулю
	if kv.has("wear_t"):   # hull=<%> wear_t=<с> — частицы износа ART-074 ровно в этот момент (0,05 — пакет искр)
		main.time = float(kv["wear_t"])
		main.step(0.0)
		main.set_process(false)
	if kv.has("lock_event"):   # lock=1 lock_event=enter|exit — событие троса ART-073 ровно на lock_age
		main.set_process(false)
		main.lock_water.event_age = float(kv.get("lock_age", "0.36"))
		main.step(0.0)
	if kv.has("podskazki"):   # podskazki=<1…7>[ done=1] — подсказка первого забега ART-038 на этом шаге («Выполнено»)
		main.tutorial.on = true
		main.tutorial.step = clampi(int(kv["podskazki"]) - 1, 0, Tutorial.STEPS.size() - 1)
		main.tutorial.a = 1.0
		if kv.get("done", "0") != "0":
			main.tutorial.done_t = 0.0
		if kv.get("guest", "0") != "0":   # guest=1 — как у гостя сети: без курса к цели, «n / 6»
			main.tutorial.set_guest(true)
		main.step(0.0)
		if kv.get("done", "0") != "0":
			main.set_process(false)   # кадр — на «Выполнено», а не на следующем шаге
	if kv.has("brif"):   # brif=<1…8> — брифинг прибытия TXT-001 (#827) на этом экране
		main.tutorial.on = true
		main.tutorial.a = 0.0
		main.arrival.on = true
		main.arrival.screen = clampi(int(kv["brif"]) - 1, 0, ArrivalBrief.count() - 1)
		main.arrival.a = 1.0
		main.arrival.t = 1.0
		main.step(0.0)
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
		ShotSetup.svyaz(main, kv)
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
	if kv.has("prodolzhit") and main.main_menu.open:   # prodolzhit=1 с menu=1 — «Продолжить» сверху (#823)
		main.main_menu.can_continue = true
		main.menu_panel.show_menu(main.main_menu)
	if kv.has("pause"):   # pause=1|new|exit|leave — пауза ART-037 по «Назад», new / exit / leave — подтверждение;
		main.back_pressed()   # pause_mode=host|guest — «Меню забега» сетевого забега (без сети, только вид)
		main.pause.mode = str(kv.get("pause_mode", main.pause.mode))
		if kv["pause"] in ["new", "exit", "leave"]:
			main.pause.press(kv["pause"])
		main.pause.saved = kv["pause"] == "saved"   # pause=saved — на кнопке «Сохранено» (#823)
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
		if kv.has("pole"):   # pole=1 — поле 08 замечено: подпись «граница» на карте (#829)
			main.lore.learn(LayerLore.FIELD08)
		if kv["zhurnal"] == "old":
			e.full = false
			main.samples.cargo.append([0, -1])
		if kv["zhurnal"] == "broken":
			main.save.state = SaveGame.Load.BROKEN
		main.open_journal()
		if kv.has("pick"):
			main.logbook.press("place:" + str(kv["pick"]))
		if kv.has("jtab"):   # вкладка до страниц: jpage листает её
			main.logbook.press("tab:" + str(kv["jtab"]))
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
	if kv.has("scena"):   # scena=n — с какого расстояния виден грунт в окне (#1400)
		print(ShotSetup.ground_line(main))
		print(ShotSetup.scena_line(main))
	print("SHOT ", out, " ", img.get_size(), " вызовов отрисовки: ",
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		", примитивов: ", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	if kv.has("budget"):
		await _budget(main, int(kv["budget"]))
	quit(0)


## Вызовы и примитивы кадра после трёх кадров отрисовки.
func _draw_count() -> Vector2i:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	return Vector2i(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))


## Бюджет по частям (#1400): часть прячется на кадр, разница с полным кадром — её цена.
## Мир на это время стоит: иначе существа и взвесь уходят из кадра и разница плывёт.
func _budget(main: Node, depth: int) -> void:
	main.process_mode = Node.PROCESS_MODE_DISABLED
	var full: Vector2i = await _draw_count()
	print("БЮДЖЕТ всего: вызовов %d, примитивов %d" % [full.x, full.y])
	var parts: Array[Node] = []
	for n in main.get_children():
		if n is Node3D or n is CanvasLayer:
			parts.append(n)
	if depth >= 2:
		for name in ["Отмель", "Живой мир", "Корабль"]:
			var g := main.get_node_or_null(name)
			if g:
				for c in g.get_children():
					if c is Node3D:
						parts.append(c)
	for n in parts:
		if not n.visible:
			continue
		n.visible = false
		var c: Vector2i = await _draw_count()
		n.visible = true
		var d := full - c
		if d.x != 0 or d.y != 0:
			print("БЮДЖЕТ %s: вызовов %d, примитивов %d" % [str(main.get_path_to(n)), d.x, d.y])
