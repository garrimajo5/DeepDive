class_name Main
extends Node3D
## Сцена собирается из кода: отмель, корабль с мостиком, игрок на палубе или за штурвалом, экранное управление.
## Мир неподвижен, корабль (узел «Корабль») движется по Helm.Ship; камера — глаза игрока в осях корабля.

var me := Crew.Member.new(Crew.Role.PILOT)   ## свой игрок как фигура (видят другие и он сам)
var walker: Deck.Walker = me.walker          ## свой ходок; у других членов экипажа — свой (`Member.walker`)
## Посты своего игрока — его состояние (`Crew.Member`), у товарищей — свои: за штурвалом, у пульта, у голостола.
var pilot: Deck.Pilot:
	get:
		return me.pilot
var crew: Array = [me]                       ## экипаж на борту; позже — игроки по сети
var crew_view: CrewView
var ghosts: Array[MateGhost] = []   ## хост: фигуры отключившихся гостей — полупрозрачные 10 с (ART-043)
var ghost_view: CrewView   ## их фигуры (alpha)
var ghost_tags: NameTagView   ## их таблички «Нет связи»
var name_tags: NameTagView  ## таблички игроков над фигурами (ART-033, NameTag)
var busy_marks: BusyMarkView  ## метки «Занято» над постами, занятыми другим (ART-033, BusyMark)
var layout := ShipLayout.new()
var airlock := Airlock.new()
var posts: Array[Deck.Post] = []
var helm := Helm.Ship.new()
var reactor := Reactor.new()
var sonar := Sonar.new()
var vitals := Vitals.new()   ## корпус и заряд корабля
var zap := Zap.new()
var scorch := Seabed.Scorch.new()   ## следы разрядов у дна ART-066 (ячейки 13–15), до нового забега
var samples := Samples.new()   ## образцы на дне и лебёдка трюма
var samples_view: SamplesView
var breach := Breach.new()     ## событие «пробоина»: струя, вода, сварка удержанием
var silt := Silt.new()         ## событие «сонарная тьма»: облака ила (на дне от удара, у Края отмели — оползни)
var silt_view: SiltView
var run := Run.new()           ## маршрут забега: выбор у голостола, точки по местам отмели
var trip := DescentTrip.new()  ## уход к Кристальному лесу у 10 после «глубже» (#828), шторка — `trip_view`
var trip_view: DescentView
var breach_view: BreachView
var debug_weld := false        ## снимок: сварку держат без пальца
var save := SaveGame.new()     ## груз трюма, поднятые образцы и изученные виды в user:// (js/save.js)
var autosave := Autosave.new()   ## автосохранение у мест-стоянок 00, 07, 09, 10 (#823)
var expedition := Expedition.new()   ## история для журнала ART-047: места, забеги, рекорд глубины, прочитанное
var lore := LayerLore.new()   ## знания слоя 1 (#825): диагностика 07, запись К-2, Раковина 03, поле 08…
var scanner := Scanner.new()   ## сканер биолога: цели от живого мира, изученные виды
var gate := GateDiag.new()     ## диагностика 07 сканером с борта (#826): гнёзда арки → факты `lore`
var at_scanner := false        ## игрок у поста «Сканер»: мир шлёт цели (ShipState.scan_range)
var near_post := ""            ## пост рядом с игроком на ногах (id), "" — нет или игрок занят постом
var busy_said := {}           ## пост → «Пульт энергии занят: Инженер» на приборах; гаснет, когда пост освободился
var _noclip_return := Vector2.ZERO  ## куда вернуть игрока при выходе из noclip (где включил)
var brief := Briefing.Fade.new()  ## голограмма брифинга у поста «Маршрут» (ART-016)
var vote_fade := Briefing.Fade.new()  ## голосование на голограмме (VoteHolo)
var votes := {}                   ## голоса ролей в открытом голосовании (VoteHolo.votes)
var ballot := Ballot.new()        ## голоса игроков у голостола (кооп): решение большинством, таймер
var result_fade := Briefing.Fade.new()  ## итог забега на голограмме (VoteHolo.result_wanted)
var result_rows: Array = []      ## четыре строки итога на голограмме (Run.summary)
var result_detail: Array = []    ## итог на панели (Run.detail) — гостям в кадре
var journal_page := 0          ## страница журнала лаборатории: 0 — сводка, дальше карточки видов (Lab.page_lines)
var lab_screen := Lab.Screen.new()   ## строки экрана журнала — только при изменении (#847)
var engine := EngineRoom.new()   ## машинное: вентиль сброса пара и щиток «Аварийный сброс»
var debug_vent := false          ## снимок: вентиль держат без пальца
var debug_winch := false         ## снимок: кнопку у лебёдки держат без пальца
var zap_light: OmniLight3D   ## вспышка разряда вокруг корпуса (за бортом)
var drain_sound: AudioStreamPlayer   ## шипение тревоги, пока на корпусе присоска (Synth.latch)
var drain_hisses := 0                ## сколько раз шипела тревога присоски (для тестов)
var ambience: Ambience   ## фон забега: эмбиент за бортом и гул корабля (SND-001), доли по глубине — Main._sound
var music: Music   ## музыка SND-004: тема меню и напряжение, какая звучит — Main._sound (SoundMix.Mix.music_pair)
var ship_sounds: ShipSounds   ## разовые звуки корабля SND-002: импульс сонара, удары, скрежет (`HullSound`)
var hit_local: Variant = null   ## точка удара существа в осях корабля, пока идёт vitals.hit (звук по стороне, #656)
var sound_mix := SoundMix.Mix.new()  ## сведение шин звука (docs/zvuk.md): меню, пауза, вид с борта, тревога — Main._sound
## Прогрев шейдеров при старте (Warmup, issue #50): шторка, камера оглядывает корабль, скрытое показано на кадр.
var warm := Warmup.new()
var timeline := RunTimeline.new()   ## хронометраж забега (#633): лента и сводка в user://zabegi.txt
var curtain: WarmSplash   ## заставка прогрева (ART-034), после прогрева — null
var warm_run := WarmRunner.new(self)   ## прогрев на сцене: заставка, взгляды, скрытое на кадр (#752)
var menu_flow := MenuFlow.new(self)   ## экраны меню: главное, настройки, «Экономно», журнал (#753)
var overlay_flow := OverlayFlow.new(self)   ## подсказки, карточка роли, связь, рация поверх игры (#758)
var crew_flow := CrewFlow.new(self)   ## товарищи на постах, руки экипажа, новый товарищ (#757)
var pause_flow := PauseFlow.new(self)   ## «Назад», пауза ART-037, схема корабля ART-042 (#754)
var lobby_flow := LobbyFlow.new(self)   ## сбор экипажа ART-028 и вход по адресу ART-039 (#755)
var net_game := NetGame.new(self)   ## сетевая игра: хост, гость, потеря связи, фигуры ушедших (#756)
var hit_flash: ColorRect
var visor: ColorRect          ## щиток сварщика: затемнение, пока свой игрок варит (Breach.VISOR)
var sonar_view: SonarView
var alarm_board: AlarmBoardView   ## табло тревог над носовым окном (ART-025)
var time := 0.0             ## секунды игры (для сонара и событий)
var power := Reactor.Console.new()   ## выбор на пульте энергии
var at_power: bool:               ## игрок у пульта энергии: крестовина правит доли (`me.at_power`)
	get:
		return me.at_power
	set(v):
		me.at_power = v
var press_post := ""               ## пост, у которого только что нажали кнопку (руки на нём CrewHands.PRESS с)
var press_t := 0.0
var press_at := Vector2.ZERO        ## где стоял игрок при нажатии: ушёл дальше CrewHands.LEAVE — руки отпускают пост
var power_panel: PowerPanel
var at_vote: bool:                ## игрок решает у голостола «глубже или наверх» (или смотрит итог; `me.at_vote`)
	get:
		return me.at_vote
	set(v):
		me.at_vote = v
var vote_panel: VotePanel
var route_card: RouteCard   ## карточка выбранного маршрута над голостолом (ART-016)
var drop := NetDrop.new()   ## гость потерял хоста (ART-043): диалог, окно переподключения, «Играть одному»
var drop_panel: DropPanel
var wreck := Wreck.new()   ## шторка «Корпус разрушен» ART-036: время, затем _restart
var wreck_view: WreckView
var notice := HostNotice.new()   ## у хоста: «Игорь отключился» / «Игорь вернулся» (ART-043), рисует drop_panel
var weak := WeakLink.new()   ## у гостя: кадры хоста опаздывают — плашка «Слабая связь» (ART-043), рисует drop_panel
var current := Helm.SeaCurrent.new()

var ocean: OceanView
var eco: EcoView            ## живой мир отмели (поток Б), связь — EcoLink
var gate_view: GateView     ## временная арка врат 07 и чаши гнёзд (#826, `GateArch`) до MOD-023
var step_ms := 0.0          ## сколько занял прошлый шаг игры (код), мс — для лога тестера (issue #217)
var clock := StepClock.new()   ## части прошлого шага (корабль, мир, виды) — для лога тестера (issue #627)
var eco_ship := EcoLink.ShipState.new()
var ship: Node3D            ## корабль: всё, что движется вместе с ним
var bridge: BridgeView
var rooms: RoomsView
var searchlight: SearchlightView
var hull: HullView          ## корпус снаружи (HullPlan), роторы и рули — по hull_motion
var hull_motion := HullMesh.Motion.new()
var wake := Wake.new()      ## след винтов и выпуски при всплытии ART-063
var valve_steam := ValveSteam.new()   ## пар вентиля ART-071 (рисует rooms.steam)
var lock_water := LockWater.new()     ## вода в шахте шлюза ART-073 (рисует rooms.lock_water)
var wake_view: WakeView
var glints := WaterGlints.new()   ## блики воды в мостике ART-067 (сила, огибающая тревоги; рисует BridgeView)
var window_fog := WindowFog.new()   ## конденсат и иней на окнах мостика ART-077 (рисует BridgeView.set_fog)
var wear := CabinWear.new()   ## «корабль устал» внутри ART-074 по Vitals.hull (рисуют BridgeView, RoomsView)
var grade: GradeView   ## виньетка и цветокоррекция по глубине ART-065 (слой −1, под интерфейсом)
var light_on := true        ## прожектор включён (кнопка «Свет» за штурвалом)
var camera: Camera3D
## Облёт с борта в начале забега (тесты и снимки выключают: tests/run.gd, tools/shot.gd).
static var intro := true
## Главное меню ART-037 после заставки прогрева (тесты и снимки выключают: tests/run.gd, tools/shot.gd).
static var menu := true
## Подсказки первого забега ART-038 (тесты и снимки выключают: tests/run.gd, tools/shot.gd; прогон тестера — шаг `tutorial`).
static var hints := true
var tutorial := Tutorial.new()   ## шаги «штурвал → ход → свет → энергия → сонар → маршрут»; пройдено — Settings.hints_done
var tutorial_panel: TutorialPanel
## Карточка роли у поста ART-045 (выключают те же `hints`; тестер — шаг `cards`): прочитанное — Settings.cards.
var role_card := RoleCard.new()
var role_card_panel: RoleCardPanel
## Внутренняя связь ART-040: плашка внизу по центру, кодовое слово забега, «Спросить код» (голоса — `EcoLink.VOICE`).
var comms := Comms.new()
var comms_panel: CommsPanel
var radio := Radio.new()   ## рация ART-041 (в коопе; разрешение микрофона — `OverlayFlow.mic_permit`)
var radio_panel: RadioPanel
var voice_io: VoiceIO   ## голос рации (#634): захват и проигрыватели товарищей, шаг — `OverlayFlow.voice_step`
var _code_rng := RandomNumberGenerator.new()   ## кодовое слово нового забега
var tutorial_guest: Tutorial.Guest   ## у гостя сети: свои шаги по своему нажатию и кадру хоста; в своей игре — null
var hint_pointer: HintPointerView   ## указатель над постом-целью подсказки (ART-038, HintPointer); вне кадра — стрелка у края
var main_menu := MainMenu.new()   ## «Погрузиться» / «Экипаж» / «Настройки»: пока открыто — игра стоит под меню
var menu_panel: MenuPanel
var address := AddressScreen.new()   ## «Войти по адресу» ART-039 поверх меню («Экипаж»): пока открыт — меню ждёт
var address_panel: AddressPanel
var address_client: NetLink.Client   ## попытка входа с экрана адреса; принят — в комнату сбора (`lobby_client`)
var lobby := Lobby.new()   ## сбор экипажа ART-028 по «Экипаж»: вход, комната хоста или гостя; пока открыт — меню ждёт
var lobby_panel: LobbyPanel
var lobby_client: NetLink.Client   ## гость в комнате хоста (`LobbyLink.take`); старт — становится `net_client`
var lobby_port := NetLink.PORT   ## порт «Создать забег» (тесты ставят свой)
var finder := RunBeacon.Finder.new()   ## поиск забегов на входе сбора: маяки хостов в сети (ART-028)
var lobby_join: NetLink.Client   ## подключение к забегу из списка; принят — в комнату (`lobby_client`)
var beacon := RunBeacon.Beacon.new()   ## маяк забега в сети, пока у хоста открыта комната (поиск забегов ART-028)
var pause := Pause.new()   ## пауза одиночного забега ART-037 (системная «Назад»): пока открыта — игра стоит
var pause_panel: PausePanel
var ship_map := ShipMap.new()   ## схема корабля ART-042 из паузы / меню забега: пока открыта — пауза под ней
var ship_map_panel: ShipMapPanel
var settings := Settings.new()   ## настройки ART-037 поверх меню или паузы: громкость, свайп, облёт, сброс сохранения
var settings_panel: SettingsPanel
## Применённый уровень графики ART-044 (`_apply_graphics`); −1 — ещё не применён: при старте `_apply_settings` ставит
## уровень всегда, даже «Обычно» — иначе MSAA и прочее остаются, какими были до него (issue #744).
var graphics_level := -1
var fps_view: FpsView   ## счётчик кадров ART-044 у правого края («Показывать кадры/с»)
## Предложение «Экономно» ART-044 после нескольких секунд низких кадр/с (тесты и снимки выключают: tests/run.gd,
## tools/shot.gd; прогон тестера — только шаг `slow`). Отказ — `Settings.lite_no`.
static var offer := true
var lite_offer := LiteOffer.new()
var lite_offer_panel: LiteOfferPanel
var logbook := Journal.new()   ## «Журнал экспедиции» ART-047 поверх меню: пока открыт — меню ждёт
var logbook_panel: JournalPanel
var flyby := Flyby.new()   ## камера с борта: облёт в начале забега, вид при всплытии
var flyby_cam: Camera3D
var overlay: TouchOverlay
var hint: Label            ## строка состояния на приборах (Status), по строкам экрана
var status_lines := Status.Lines.new()   ## раскладка строки состояния — пересчёт только при смене (#847)
var message := Status.Message.new()
const SAT_MSG := "Вы за штурвалом"
const LOADED_MSG := "Корпус разрушен. Ковчег у последнего сохранения"   ## гибель в кампании (#824)
const DRAIN_DB := -12.0   ## шипение присоски: js/audio.js 0,12 против 0,05 у сирены (−16 дБ)
var env: Environment
var qa: QaRunner           ## прогон сценария тестера, если он есть (docs/QA.md)
var net_host: NetLink.Host   ## хост сетевого забега (`host_game`); null — игра без сети
var net_mates := {}          ## peer id гостя → его член экипажа (Crew.Member)
var net_client: NetLink.Client   ## клиент сетевого забега (`join_game`): шаг корабля не считает, применяет кадры хоста
var net_seq := -1            ## номер последнего применённого кадра хоста
var net_smooth := NetSmooth.new()   ## клиент: корабль и фигуры между кадрами хоста — плавно, с отставанием DELAY
var net_pad := Crew.Pad.new()   ## свой ввод клиента: копится за кадр и уходит хосту (`Client.send_pad`)
var news := []                ## хост: последнее сообщение события [номер, текст] — едет гостям в кадрах NetSnap.NEWS_TIME
var news_age := 99.0
var net_vote := {"secs": -1, "frac": -1.0, "tally": "", "ops": []}   ## клиент: таймер, счёт и мнения голосования хоста
var net_news := 0             ## клиент: номер последнего показанного сообщения события хоста
const NET_SPAWN := Vector3(0.0, 1.0, 0.0)   ## гость встаёт на мостике: x, z, курс


func _ready() -> void:
	_build_audio()
	_build_world()
	_build_outside()
	_build_ship()
	_build_ui()
	_load_state()
	_place_ship()
	_place_camera()
	warm_run.begin()
	if menu:
		open_menu()
	if QaRunner.pending():
		start_qa()


## Сборка: шины звука и плееры — до всего остального.
func _build_audio() -> void:
	SoundMix.ensure()   # шины звука — до первых плееров
	ambience = Ambience.new()
	add_child(ambience)
	voice_io = VoiceIO.new()
	add_child(voice_io)
	music = Music.new()
	add_child(music)
	ship_sounds = ShipSounds.new()
	add_child(ship_sounds)


## Сборка: за бортом — отмель, ил, след, живой мир, образцы; пол корпуса для хода.
func _build_outside() -> void:
	ocean = OceanView.new()
	ocean.name = "Отмель"
	add_child(ocean)
	silt_view = SiltView.new()
	add_child(silt_view)
	wake_view = WakeView.new()   # в «Отмели»: прогрев показывает его на кадр
	ocean.add_child(wake_view)
	eco = EcoView.new()
	eco.name = "Живой мир"
	eco.ground = Seabed.height
	eco.world.scanned = scanner.is_scanned
	add_child(eco)
	samples_view = SamplesView.new(samples)
	samples_view.name = "Образцы"
	add_child(samples_view)
	# Пол корпуса — дно плюс верх скальных клиньев Края отмели: корабль не проходит сквозь скалу и чиркает по ней
	# существующим ударом о дно (helm.bump → Vitals.scrape). Облако оползня — из свежего шрама (issue #258).
	var ecv := eco
	helm.ground = func(x: float, z: float) -> float:
		var g: float = Seabed.height(x, z)
		if ecv.drop:
			g = maxf(g, ecv.drop.top(x, z))
		return g
	if eco.drop:
		silt.slide_origin = eco.drop.slide_cloud_point()
	gate_view = GateView.new()
	ocean.add_child(gate_view)
	helm.solid = GateArch.hits   # корабль сквозь опоры арки 07 не проходит (#826)


## Сборка: корабль — мостик, вспышка разряда, отсеки, экипаж, метки, посты, прожектор, корпус, камеры.
func _build_ship() -> void:
	ship = Node3D.new()
	ship.name = "Корабль"
	add_child(ship)
	bridge = BridgeView.new()
	bridge.name = "Мостик"
	ship.add_child(bridge)
	zap_light = OmniLight3D.new()
	zap_light.name = "Вспышка разряда"
	zap_light.light_color = Color("5ef2d6")
	zap_light.light_cull_mask = OceanView.LAYER_WORLD
	zap_light.position = Vector3(0, 1.6, 8)
	# вспышка всегда в сцене на наибольший радиус и почти без энергии: набор огней на предметах отмели не меняется
	# при разряде — шейдеры не собираются заново (issue #159)
	zap_light.omni_range = Warmup.zap_radius()
	zap_light.light_energy = Searchlight.DARK
	ship.add_child(zap_light)
	drain_sound = AudioStreamPlayer.new()
	drain_sound.name = "Тревога присоски"
	drain_sound.stream = Synth.latch()
	drain_sound.volume_db = DRAIN_DB
	drain_sound.bus = SoundMix.SHIP
	add_child(drain_sound)
	sonar_view = SonarView.new()
	bridge.add_child(sonar_view)
	alarm_board = AlarmBoardView.new()
	alarm_board.name = "Табло тревог"
	bridge.add_child(alarm_board)
	rooms = RoomsView.new()
	rooms.name = "Отсеки"
	ship.add_child(rooms)
	breach_view = BreachView.new(breach)
	ship.add_child(breach_view)
	crew_view = CrewView.new()
	ship.add_child(crew_view)
	crew_view.set_members(crew, me)
	name_tags = NameTagView.new()
	name_tags.name = "Таблички экипажа"
	ship.add_child(name_tags)
	ghost_view = CrewView.new()
	ghost_view.name = "Отключившиеся"
	ship.add_child(ghost_view)
	ghost_tags = NameTagView.new()
	ghost_tags.name = "Таблички отключившихся"
	ship.add_child(ghost_tags)
	busy_marks = BusyMarkView.new()
	busy_marks.name = "Метки «Занято»"
	ship.add_child(busy_marks)
	hint_pointer = HintPointerView.new()
	hint_pointer.name = "Указатель подсказки"
	ship.add_child(hint_pointer)
	walker.stand = crew_flow.stand_for(me)
	posts = Deck.posts()
	posts.append(Deck.Post.new("winch", Samples.POST_AT, Samples.POST_R, "Лебёдка"))
	posts.append(Deck.Post.new("breach", breach.post_at(), Breach.POST_R, "Сварка"))
	posts.append(Deck.Post.new("route", ROUTE_POST, ROUTE_POST_R, run.label()))
	posts.append_array(Lab.posts())
	for i in layout.doors.size():
		posts.append(Deck.Post.new("door%d" % i, Vector2(0.0, ShipLayout.DOOR_Z[i]), 1.2, "Открыть люк"))
	searchlight = SearchlightView.new()
	searchlight.name = "Прожектор"
	ship.add_child(searchlight)
	hull = HullView.new()
	hull.name = "Корпус"
	ship.add_child(hull)
	camera = Camera3D.new()
	camera.name = "Глаза"
	camera.fov = Deck.FOV
	camera.near = 0.05
	camera.far = 400.0
	ship.add_child(camera)
	camera.make_current()
	me.smooth_lean = true   # камера в голове: наклон к посту плавный
	me.back = CrewView.OWN_BACK   # стоя своя фигура чуть позади камеры
	flyby_cam = Camera3D.new()
	flyby_cam.name = "Камера с борта"
	flyby_cam.fov = Deck.FOV
	flyby_cam.near = 0.2
	flyby_cam.far = 400.0
	ship.add_child(flyby_cam)


## Сборка: экранный интерфейс — приборы, панели, вспышки, управление, подсказки, связь, шторки.
func _build_ui() -> void:
	grade = GradeView.new()
	add_child(grade)
	var ui := CanvasLayer.new()
	ui.name = "Интерфейс"
	add_child(ui)
	hint = Label.new()
	hint.name = "Приборы"
	hint.position = HINT_POS
	hint.add_theme_stylebox_override("normal", hint_backing())   # подложка: строки читаются поверх светлых плафонов (#139)
	hint.add_theme_font_size_override("font_size", 24)
	hint.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hint.add_theme_constant_override("outline_size", 6)
	hint.add_theme_constant_override("line_spacing", -2)
	ui.add_child(hint)
	current.changed.connect(func(_i: int) -> void: say("Течение сменилось"))
	power_panel = PowerPanel.new()
	power_panel.name = "Пульт энергии"
	ui.add_child(power_panel)
	trip_view = DescentView.new()
	add_child(trip_view)
	vote_panel = VotePanel.new()
	vote_panel.name = "Решение экипажа"
	ui.add_child(vote_panel)
	route_card = RouteCard.new()
	route_card.name = "Карточка маршрута"
	ui.add_child(route_card)
	hit_flash = ColorRect.new()
	hit_flash.name = "Вспышка удара"
	hit_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit_flash.color = Color(1.0, 0.36, 0.42, 0.0)
	ui.add_child(hit_flash)
	visor = ColorRect.new()
	visor.name = "Щиток сварщика"
	visor.set_anchors_preset(Control.PRESET_FULL_RECT)
	visor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visor.color = Color.WHITE
	var vm := ShaderMaterial.new()   # яркое (искры, вспышка) сквозь щиток не тонирует — по issue #530
	vm.shader = load("res://shaders/visor.gdshader")
	vm.set_shader_parameter("shade", Breach.VISOR)
	vm.set_shader_parameter("knee", Breach.VISOR_KNEE)
	visor.material = vm
	visor.visible = false
	ui.add_child(visor)
	vitals.hit_taken.connect(_on_hit)
	vitals.destroyed.connect(_on_destroyed)
	overlay = TouchOverlay.new()
	overlay.name = "Управление"
	ui.add_child(overlay)
	var ver := Label.new()   # версия сборки на экране (отладка): видно, какой APK запущен
	ver.name = "Версия"
	ver.text = version_text()
	ver.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ver.add_theme_font_size_override("font_size", 13)
	ver.modulate = Color(1.0, 1.0, 1.0, 0.45)
	ver.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 4)
	ver.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ui.add_child(ver)
	tutorial_panel = TutorialPanel.new()   # поверх кнопок: обводка нужной ложится на них, касания проходят
	tutorial_panel.name = "Подсказка"
	tutorial_panel.layout = overlay.router.layout
	ui.add_child(tutorial_panel)
	role_card_panel = RoleCardPanel.new()   # карточка роли ART-045: касания — через Router.blocks/taps
	role_card_panel.name = "Карточка роли"
	ui.add_child(role_card_panel)
	comms_panel = CommsPanel.new()   # плашка связи ART-040: касания — через Router.blocks/taps (`OverlayFlow.comms_step`)
	comms_panel.name = "Связь"
	ui.add_child(comms_panel)
	radio_panel = RadioPanel.new()   # рация ART-041: кнопка «Говорить» и список говорящих; касания — Router.blocks
	radio_panel.name = "Рация"
	ui.add_child(radio_panel)
	_code_rng.randomize()
	drop_panel = DropPanel.new()   # поверх управления: пока диалог открыт, кнопки под ним не работают
	drop_panel.name = "Связь потеряна"
	ui.add_child(drop_panel)
	wreck_view = WreckView.new()   # выше крестовины и кнопки, ниже заставки прогрева
	add_child(wreck_view)
	power_panel.layout = overlay.router.layout   # панель пульта не ложится под noclip и кнопку действия (#349)
	busy_marks.layout = overlay.router.layout    # метка «Занято» тоже (#373)


## Сборка: сигналы систем, настройки, сохранение и первый забег.
func _load_state() -> void:
	reactor.message.connect(func(title: String, _text: String) -> void: say(title))
	airlock.message.connect(say)
	samples.message.connect(say)
	engine.message.connect(say)
	breach.message.connect(announce)
	if QaRunner.pending():   # прогон тестера — всегда с чистого трюма и без записи
		save.path = ""
		address.path = ""
		settings.path = ""   # и облёт в начале — как в сценарии, а не как у тестера в настройках
	address.load_last()
	fps_view = FpsView.new()   # счётчик кадров ART-044: под меню и паузой, касаний не принимает
	add_child(fps_view)
	lite_offer_panel = LiteOfferPanel.new()   # предложение «Экономно» ART-044: касания — `MenuFlow.offer_step`
	add_child(lite_offer_panel)
	if settings.pick_first(Graphics.auto_here()):   # первый запуск — уровень графики по телефону ART-044
		var d := Graphics.device()
		print("графика: автовыбор «%s» (%s, %d МБ)" % [Graphics.NAMES[settings.graphics], d["adapter"], d["memory_mb"]])
	settings.read()
	_apply_settings()
	role_card.on = hints and not QaRunner.pending()   # тестер включает шагом `cards`
	role_card.set_read(settings.cards)
	save.expedition = expedition
	save.lore = lore       # знания слоя 1 — ключ "lore" (#825)
	save.helm = helm       # место, курс, корпус и заряд — ключ "ship" для кампании (#823)
	save.vitals = vitals
	save.load_into(samples, scanner)
	# обучение — пока не пройдено ни в настройках, ни в кампании (знание «обучение просмотрено», #827); тестер
	# включает шагом `tutorial`
	tutorial.on = hints and not settings.hints_done and not lore.knows(LayerLore.INTRO) and not QaRunner.pending()
	_begin_run()
	samples.changed.connect(save.mark)
	scanner.changed.connect(save.mark)
	expedition.changed.connect(save.mark)
	lore.changed.connect(save.mark)
	scanner.message.connect(say)
	gate.read.connect(func(f: String) -> void: announce(GateDiag.TEXT[f]))   # факт 07 видят все (#826)


## Идёт прогрев шейдеров: экран под шторкой, сценарий тестера ждёт.
func warming() -> bool:
	return warm.active()


## Слои первого взгляда прогрева (#424) — `WarmRunner.layers`.
func warm_layers() -> Array:
	return warm_run.layers()


## Огни корабля по ART-064 (CabinLight): авария — пока открыта пробоина, ритм — часами пробоины (у гостя тоже идут),
## k — мигание Vitals.lamp_k поверх.
func _cabin(k: float) -> void:
	var br := breach.active.room if breach.active else -1
	breach_view.lamp_k = k   # вода струи ART-072 гаснет со светом отсеков
	bridge.set_cabin(br, breach.time, k)
	rooms.set_cabin(br, breach.time, k)


## Блики воды на потолке и полу мостика ART-067: глубина корабля, ил, авария (огибающая), мигание плафонов lamp_k.
func _glints(dt: float, lamp_k: float) -> void:
	glints.step(dt, breach.active != null)
	var d := helm.depth()
	bridge.set_glints(glints.k(d, silt.k, lamp_k), WaterGlints.tint(d), time)


## «Корабль устал» внутри ART-074: потёки и мокрый пол мостика и машинного по прочности корпуса (сглажено 0,3 с),
## капли, искры и пар — WearDrops по тем же часам (у гостя — свои часы, корпус из кадра); light — свет плафонов.
func _wear(dt: float, light: float) -> void:
	wear.step(dt, vitals.hull)
	bridge.set_wear(wear.loss)
	rooms.set_wear(wear.loss)
	rooms.drops.apply(time, wear.loss, light)
	window_fog.step(dt, helm.depth(), vitals.hull, reactor.heat, reactor.scram)   # конденсат на окнах ART-077
	bridge.set_fog(window_fog.humidity, window_fog.ice_k)


## Свет мигает, пока на корпусе присоска и после разряда (Vitals.lamp_k); тревога присоски шипит раз в 1,6 с
## (Vitals.hiss — короткий звук без петли, issue #163).
func _flicker(dt: float) -> void:
	var k := vitals.lamp_k(time, zap.flicker > 0.0)
	_cabin(k * Wreck.lamps(wreck.t))   # шторка «Корпус разрушен»: плафоны гаснут
	rooms.steam.apply(valve_steam, ValveSteam.tint(reactor, k * Wreck.lamps(wreck.t)))   # пар ART-071
	rooms.lock_water.apply(lock_water, airlock.t, helm.depth(), helm.speed, vitals.hull, time, k * Wreck.lamps(wreck.t))   # ART-073
	_glints(dt, k * Wreck.lamps(wreck.t))
	_wear(dt, k * Wreck.lamps(wreck.t))
	searchlight.set_flicker(k)
	bridge.set_screens(Vector3(vitals.screen_k(time, Vitals.Screen.HELM_L), vitals.screen_k(time, Vitals.Screen.HELM_C),
		vitals.screen_k(time, Vitals.Screen.HELM_R)), vitals.screen_k(time, Vitals.Screen.SCANNER))
	rooms.set_journal_k(vitals.screen_k(time, Vitals.Screen.JOURNAL))   # помехи экранов при стеклоусте (ART-025)
	if vitals.hiss(dt):
		drain_sound.play()
		drain_hisses += 1
	elif vitals.drain_left <= 0.0 and drain_sound.playing:
		drain_sound.stop()


## Запустить сценарий тестера: из user://qa/scenario.json или из текста (тесты).
func start_qa(text: String = "") -> QaRunner:
	qa = QaRunner.new()
	qa.name = "Сценарий тестера"
	add_child(qa)
	timeline.path = QaRunner.OUT + "/zabeg.txt"   # хронометраж прогона — рядом с логом, файл игрока не трогаем
	timeline.forget()
	qa.start(self, text)
	return qa


func _build_world() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Тонмаппинг ACES: киношная свёртка ярких мест (мягкий перекат светов против пересвета мелководья),
	# экспозиция чуть приглушена под «таинственную глубину».
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.9
	env.tonemap_white = 6.0
	# Свечение биолюминесценции (Forward Mobile): цветут только яркие места (огни текстур #67DDEB, вспышки)
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 0.9
	env.glow_intensity = 1.1
	env.glow_bloom = 0.22
	env.glow_strength = 1.15
	# Цветокоррекция «таинственной глубины»: лёгкий контраст и насыщение, чуть холоднее — без пост-эффектов,
	# работает на Forward Mobile. (SSAO/SSIL убраны: на Forward Mobile не поддерживаются — SSAO только Forward+/
	# Compatibility, SSIL только Forward+; «вес» объектам дают тени от света сквозь лёд, а щели/ободок — шейдеры
	# на «героях», этап 3. Для уровня «Красиво» на Forward+ их можно вернуть за флагом ART-044.)
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


## Кадры для магазина (ART-046, шаг тестера `hud`, `shot.gd hud=0`): спрятать или вернуть крестовину и кнопки,
## строки приборов и плашку версии. Следующее событие интерфейса (пауза, меню, шторка) ставит их по-своему.
func set_hud(on: bool) -> void:
	overlay.visible = on
	hint.visible = on
	var ver := overlay.get_parent().get_node_or_null("Версия") as CanvasItem
	if ver:
		ver.visible = on


## Версия сборки для отладочной плашки: config/version + номер сборки из version.txt (пишет CI), иначе «dev».
func version_text() -> String:
	var v := str(ProjectSettings.get_setting("application/config/version", "?"))
	var build := "dev"
	if FileAccess.file_exists("res://version.txt"):
		build = FileAccess.get_file_as_string("res://version.txt").strip_edges()
	return "v%s · %s" % [v, build]


## Игру сворачивают или закрывают — несохранённое записать сразу.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:   # системная «Назад» Android (`quit_on_go_back` выключен)
		back_pressed()
	elif what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		save.flush(samples, scanner)
		timeline.save(Time.get_datetime_string_from_system(false, true))   # недописанный забег — «не закончен»
	elif what == NOTIFICATION_EXIT_TREE:
		if net_host:
			net_host.stop()
		if net_client:
			net_client.stop()


func _process(dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	step(dt)
	step_ms = (Time.get_ticks_usec() - t0) / 1000.0
	if fps_view and fps_view.visible:
		fps_view.push(dt)
	lite_offer.push(dt)   # настоящее время кадра: предложение «Экономно» ART-044


## Один шаг игры: ввод, игрок, корабль, вода. Вынесен из _process для тестов.
func step(dt: float) -> void:
	clock.start(Time.get_ticks_usec(), dt)
	warm_run.restore()
	_sound(dt)
	time += dt
	if qa:
		qa.tick(dt)
	if main_menu.open and not warm.active():   # главное меню: игра стоит, касания — кнопкам меню
		overlay_flow.hide_all()
		menu_flow.menu_step(dt)
		return
	if pause.open:   # пауза: игра стоит, касания — кнопкам паузы; меню сетевого забега — мир идёт без своего ввода
		var stop := pause.stops_world()
		pause_flow.pause_step()
		if stop or main_menu.open:
			overlay_flow.hide_all()
			return
		if settings.open:   # палец на ползунке настроек держится, но в игру не идёт
			overlay.router.mute()
		else:
			overlay.router.clear()   # палец на кнопке меню не идёт в игру: свой игрок стоит, за постом — без хода
	if menu_flow.offer_step():   # предложение «Экономно»: касания — его кнопкам, свой игрок стоит, мир идёт
		overlay.router.clear()
	if net_client:   # клиент: корабль, реактор и экипаж — из кадров хоста
		net_game.client_step(dt)
		clock.lap("гость", Time.get_ticks_usec())
		return
	net_game.net_poll(dt)
	var r := overlay.router
	var wrecked := _wreck_step(dt)
	var h := _step_input(dt, r, wrecked)
	h.held = crew_flow.holds()   # товарищи держат кнопку у постов удержания — то же, что свой игрок
	_step_posts(dt, h)
	_step_ship(dt, h)
	_step_zap(dt)
	clock.lap("корабль", Time.get_ticks_usec())
	_step_eco(dt)
	_step_view(dt)
	clock.lap("виды", Time.get_ticks_usec())
	_step_ui(dt)
	_step_marks(dt, r)
	clock.lap("метки и сеть", Time.get_ticks_usec())


## Кнопки удержания в этом кадре: свой игрок у поста (`valve`…) и товарищи (`held` — `CrewFlow.holds`).
class Holds:
	var valve := false
	var winch := false
	var weld := false
	var scan := false
	var held := {}


## Шаг: свой ввод — посты, ход, взгляд; что держит свой игрок (`Holds`).
func _step_input(dt: float, r: Touch.Router, wrecked: bool) -> Holds:
	crew_flow.mark_presses(r, dt)
	if r.noclip_pressed and not wrecked:
		toggle_noclip()
	var h := Holds.new()
	at_scanner = false
	near_post = ""
	flyby.update(0.0 if warm.active() else dt)   # облёт ждёт конца прогрева шейдеров (под шторкой)
	if wrecked:   # шторка «Корпус разрушен»: корабль без хода, игрок стоит
		helm.in_thrust = 0.0
		helm.in_turn = 0.0
		helm.in_vert = 0.0
	elif flyby.kind == Flyby.Kind.START:   # облёт в начале забега: касание — к мостику, ввод этого кадра не идёт в игру
		helm.in_thrust = 0.0
		helm.in_turn = 0.0
		helm.in_vert = 0.0
		if r.touching() or r.action_pressed:
			flyby.stop()
			message.clear(Flyby.START_MSG)
	elif walker.noclip:   # тестовый полёт: крестовина ведёт по взгляду сквозь корпус, посты не трогаем
		helm.in_thrust = 0.0
		helm.in_turn = 0.0
		helm.in_vert = 0.0
		walker.look(overlay.look_points())
		walker.walk(Vector2(r.move), dt)
	elif pilot.seated:
		helm.in_thrust = r.move.y
		helm.in_turn = r.move.x
		helm.in_vert = r.vert()
		if r.move.y > 0:
			tutorial.note(Tutorial.Ev.THRUST)
		if r.light_pressed:
			var was_lit := light_on
			toggle_light()
			if light_on != was_lit:
				tutorial.note(Tutorial.Ev.LIGHT)
		walker.look(overlay.look_points())
		if r.action_pressed:
			stand_up()
	elif at_power:
		helm.in_thrust = 0.0
		helm.in_turn = 0.0
		helm.in_vert = 0.0
		walker.look(overlay.look_points())
		var shares := reactor.share.duplicate()
		power.nav(reactor, r.move, dt)
		if reactor.share != shares:
			tutorial.note(Tutorial.Ev.SHARE)
		if r.action_pressed:
			close_power()
	elif at_vote:
		helm.in_thrust = 0.0
		helm.in_turn = 0.0
		helm.in_vert = 0.0
		walker.look(overlay.look_points())
		var choice := "" if run.ended else run.vote_nav(r.move)
		if choice != "":
			ballot.cast(me.get_instance_id(), me.role, choice)   # решает _tick_vote: один у стола — сразу
		if r.action_pressed and flyby.kind == Flyby.Kind.SURFACE:
			flyby.stop()   # вид с борта при всплытии: кнопка — к итогу на голограмме, новый забег — следующим нажатием
		elif r.action_pressed:
			close_vote()
	else:
		helm.in_thrust = 0.0
		helm.in_turn = 0.0
		helm.in_vert = 0.0
		walker.look(overlay.look_points())
		walker.speed_k = breach.slow(ShipLayout.room_at(walker.z))
		walker.walk(Vector2(r.move), dt)
		var post := Deck.nearest(posts, walker.x, walker.z)
		if post and r.action_pressed:
			use_post(post.id)
		h.valve = post != null and post.id == "valve" and r.action_down
		h.winch = post != null and post.id == "winch" and r.action_down
		h.weld = post != null and post.id == "breach" and r.action_down
		at_scanner = post != null and post.id == "scanner"
		near_post = post.id if post else ""
		h.scan = at_scanner and r.action_down
	return h


## Шаг: товарищи на постах, отсеки, лебёдка, сканер, сварка, подписи постов.
func _step_posts(dt: float, h: Holds) -> void:
	var held := h.held
	crew_flow.posts(dt)
	layout.update(dt)
	airlock.update(dt)
	lock_water.update(dt, airlock.t, samples.hook_local(Samples.ship_xform(helm.pos, helm.yaw)), samples.carrying())
	var ship_xf := Samples.ship_xform(helm.pos, helm.yaw)
	if (h.winch or held.has("winch") or debug_winch) and airlock.fully_open():
		samples.hold(Samples.lock_point(ship_xf), dt)
	samples.update(dt)
	samples_view.sync()
	save.tick(dt, samples, scanner)
	gate.aim(helm.pos, lore, float(scanner.target["dist"]) if not scanner.target.is_empty() else INF)
	if h.scan or held.has("scanner"):
		if gate.active():
			gate.hold(dt, lore)   # гнездо 07 ближе существа — сканер переводит его (#826)
		else:
			scanner.hold(dt)
	scanner.update(dt)
	gate.update(dt)
	if h.weld or held.has("breach") or debug_weld:
		breach.hold(dt)
	for p in posts:
		if p.id.begins_with("door"):
			p.label = "Закрыть люк" if layout.doors[int(p.id.substr(4))].open else "Открыть люк"
		elif Crew.BUSY.has(p.id):   # пост одного человека: занят другим — так и пишем в строке
			var who := Crew.holder(crew, me, p.id)
			p.label = Crew.BUSY[p.id] if who else POST_FREE[p.id]
			if busy_said.has(p.id) and (who == null or Crew.busy_text(p.id, who) != busy_said[p.id]):
				message.clear(busy_said[p.id])   # державший встал или отключился — строка не врёт (issue #419)
				busy_said.erase(p.id)
		elif p.id == "airlock":
			p.label = airlock.label()
		elif p.id == "winch":
			p.label = samples.label()
		elif p.id == "breach":
			p.at = breach.post_at()
			p.label = breach.label()
		elif p.id == "scanner":
			p.label = gate.label(lore) if gate.active() else scanner.label()
		elif p.id == "route":
			p.label = run.label()
		elif p.id.begins_with("flask"):
			p.label = Lab.flask_label(samples.cargo, int(p.id.substr(5)))


## Шаг: течение, ил, маршрут, реактор, ход, корпус, пробоина, руки экипажа.
func _step_ship(dt: float, h: Holds) -> void:
	var held := h.held
	current.update(dt)
	var silt_msg := silt.update(dt, helm.pos, current.vel())
	if not silt_msg.is_empty():
		announce(silt_msg)
	silt_view.apply(silt, time, helm.pos, helm.yaw)
	var run_msg := run.update(helm.pos.x, helm.pos.z)
	if not run_msg.is_empty():
		announce(run_msg)
		timeline.mark(time, run_msg)
	var deep_msg := run.descent(helm.pos.x, helm.pos.z)   # переход у 10: голосование «глубже или наверх» (#828)
	if not deep_msg.is_empty():
		announce(deep_msg)
		timeline.mark(time, deep_msg)
		if not run.voting:   # ушли от спуска, не решив: голоса и панель — прочь
			ballot.clear()
			for m: Crew.Member in crew:
				m.at_vote = false
			vote_panel.visible = false
	expedition.visit(helm.pos.x, helm.pos.z)   # журнал ART-047: места и рекорд глубины
	timeline.place(time, helm.pos.x, helm.pos.z)   # хронометраж по участкам слоя (#824)
	var spot := autosave.update(helm.pos.x, helm.pos.z)   # кампания #823: вошли к месту-стоянке — записать
	if spot != "" and save.live and not wreck.active() and save_now():
		say(Autosave.message(spot))
	expedition.dive_depth(helm.depth())
	reactor.update(dt, Reactor.near_vent(helm.pos.x, helm.pos.z))
	engine.update(dt, reactor, h.valve or held.has("valve") or debug_vent)
	valve_steam.update(dt, engine.venting)
	helm.update(dt, reactor.k(Reactor.Sys.ENGINES), current.vel())
	hull_motion.update(dt, helm.in_thrust, helm.in_vert, reactor.k(Reactor.Sys.ENGINES))
	_wake(dt)
	helm.speed = vitals.scrape(helm.bump / maxf(dt, 1e-4), helm.speed)
	if helm.knock > 0.0:
		ship_sounds.play_ice(helm.knock)   # упёрлись в лёд снизу — удар без урона (#656)
	ship_sounds.set_rub(helm.rub, dt)   # трёмся о дно на ходу — петля скрежета (#656)
	if vitals.update(dt, helm.in_thrust, helm.in_vert, Searchlight.lit(light_on, reactor.k(Reactor.Sys.LAMP)),
			0.0 if run.ended else reactor.k(Reactor.Sys.LIFE)):   # на итоге корпус не чинится — как на панели (#266)
		light_on = false
		overlay.set_light(false)
		say("Прожектор погас: не хватает энергии")
	vitals.hull = breach.update(dt, reactor.k(Reactor.Sys.LIFE), vitals.hull)
	timeline.watch(time, {"пробоина": breach.active != null, "сонарная тьма": silt.inside != null,
		"присоска": vitals.drain_left > 0.0, "перегрев": reactor.hot, "сброс реактора": reactor.scram > 0.0,
		"голосование": at_vote}, vitals.hull, helm.depth())
	breach_view.apply(dt)   # и частицы ART-072
	crew_flow.drive(dt)
	_tick_vote(dt)
	crew_flow.hands(dt, h.valve, h.winch, h.scan, held)
	if (h.weld or debug_weld) and breach.welding and breach.active:   # свой игрок варит: резак в руке, щиток опущен
		me.weld(breach.active.p, breach.active.n)
	else:
		me.weld(Vector3.INF)
	visor.visible = me.welding()
	breach.end_step()


## Шаг: прожектор и разряд — вспышка, рычаг, дуги и следы у дна.
func _step_zap(dt: float) -> void:
	searchlight.apply(light_on, reactor.k(Reactor.Sys.LAMP), silt.beam_k())
	zap.update(dt)
	if zap.flicker > 0.0:
		hit_flash.color = Color(0.37, 0.95, 0.84, zap.flicker / Zap.FLICKER * 0.4)
		zap_light.light_energy = Zap.flash_energy(zap.flicker)
	else:
		hit_flash.color = Color(1.0, 0.36, 0.42, vitals.flash * 0.35)
		zap_light.light_energy = Searchlight.DARK
	bridge.set_zap_lever(zap.lever_deg(time), zap.ready(time))
	hull.set_zap(Zap.arc_time(zap.flicker))   # дуги по обшивке ART-068
	if zap.flicker > 0.0 or hull.zap_cards.visible:   # у окна и у дна — карточки ART-068
		hull.set_zap_cards(Zap.arc_time(zap.flicker), Zap.ground_contact(ship.global_transform))
	if not scorch.all.is_empty():   # свежий след темнеет в «старое пятно»
		ocean.set_scorch(scorch.uniforms(time))


## Шаг: виды корабля — пульты, голограммы, отсеки, своя фигура, корабль и камера.
func _step_view(dt: float) -> void:
	_flicker(dt)
	for i in Reactor.Sys.size():
		bridge.set_slider(i, reactor.share[i] / float(Reactor.MAX))
	bridge.set_hatch(layout.doors[0].offset())
	sonar_view.show_state(sonar, helm.pos, helm.yaw, time, reactor.k(Reactor.Sys.SONAR) > 0.0, silt.noise(time))
	sonar_view.show_waypoint(run.waypoint())
	alarm_board.show_alarms(alarms_on(), time, breach.active)
	sonar_view.show_briefing(brief.update(dt, Briefing.wanted(near_post, at_vote, run.ended)), run, helm.pos)
	var coop := vote_ids().size() > 1   # таймер — только у голосов игроков (Ballot), в одиночной игре его нет
	sonar_view.show_vote(vote_fade.update(dt, VoteHolo.wanted(at_vote, run.ended)), vote_marks(),
		ballot.seconds() if coop else -1, ballot.fraction() if coop else -1.0)
	sonar_view.show_result(result_fade.update(dt, VoteHolo.result_wanted(at_vote, run.ended)), result_rows,
		camera.global_position)
	rooms.apply(layout, reactor, airlock, engine)
	var carry_c: Color = Samples.COLORS[samples.target.kind] if samples.target else Color.WHITE
	rooms.set_winch(samples.hook_local(Samples.ship_xform(helm.pos, helm.yaw)), samples.carrying(), carry_c)
	rooms.set_lab(Lab.contents(samples.cargo), lab_screen.lines(samples, scanner, journal_page), time)
	rooms.set_shelves(HoldShelves.contents(samples.cargo))
	bridge.set_scanner_screen(gate.screen_lines(lore) if gate.active() else scanner.screen_lines())
	message.update(dt)
	me.back = CrewView.own_back(walker.pitch, me.holding())   # взгляд вниз — фигура дальше позади глаза, видны ступни (#108)
	me.follow(walker.x, walker.z, walker.yaw, pilot.seated, helm.turn, dt)
	me.sync_post()
	crew_view.pitch = walker.pitch
	_apply_crew_view(dt)
	_place_ship()
	_place_camera()


## Шаг: интерфейс — карточка маршрута, приборы, подсказки, связь, рация (подчасти — в худшем кадре лога тестера, #745).
func _step_ui(dt: float) -> void:
	_trip_step(dt)
	route_card.show_card(brief.k, run.route, get_viewport().get_camera_3d(), sonar_view.global_transform,
		comms.code)   # страница «Связь» — кодовое слово забега (ART-040)
	clock.lap("интерфейс/маршрут", Time.get_ticks_usec())   # подчасти — в худшем кадре лога тестера (#745)
	_update_ui()   # до меток: плашка строки уже на месте этого кадра (#387)
	clock.lap("интерфейс/приборы", Time.get_ticks_usec())
	overlay_flow.tutorial_step(dt)
	clock.lap("интерфейс/подсказки", Time.get_ticks_usec())
	overlay_flow.card_step(dt)
	clock.lap("интерфейс/карточка роли", Time.get_ticks_usec())
	overlay_flow.comms_step(dt)
	clock.lap("интерфейс/связь", Time.get_ticks_usec())
	overlay_flow.radio_step(dt)
	clock.lap("интерфейс/рация", Time.get_ticks_usec())


## Шаг: метки «Занято», таблички, ушедшие, прогрев, сеть.
func _step_marks(dt: float, r: Touch.Router) -> void:
	busy_marks.plate = status_rect()
	var busy := busy_marks.show_marks(crew, me, get_viewport().get_camera_3d(), camera)
	name_tags.show_tags(crew, me, crew_view, get_viewport().get_camera_3d(), camera, tag_blocks(), dt, busy,
			status_rect(), radio.voice())
	net_game.ghosts_step(dt)
	warm_run.frame()
	net_game.net_send(dt)
	r.end_frame()


## Подложка строк на приборах: тёмная полупрозрачная плашка с отступом HINT_PAD — белые плафоны потолка не съедают
## белый текст (issue #139), дно и лёд за ней видно.
const HINT_PAD := 10.0
const HINT_POS := Vector2(24, 14) - Vector2(HINT_PAD, HINT_PAD * 0.5)   ## верх-лево плашки на своём месте
const HINT_BACKING := Color(0.02, 0.06, 0.08, 0.55)


static func hint_backing() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = HINT_BACKING
	sb.set_corner_radius_all(8)
	sb.content_margin_left = HINT_PAD
	sb.content_margin_right = HINT_PAD
	sb.content_margin_top = HINT_PAD * 0.5
	sb.content_margin_bottom = HINT_PAD * 0.5
	return sb


## Короткая подпись на кнопке действия у поста.
const POST_BUTTON := {"helm": "Штурвал", "energy": "Энергия", "scanner": "Сканер", "sonar": "Сонар", "zap": "Разряд", "airlock": "Шлюз", "winch": "Лебёдка",
	"valve": "Вентиль", "scram": "Сброс", "breach": "Сварка", "journal": "Журнал", "route": "Маршрут"}
## Подписи постов одного человека (Crew.BUSY), когда они свободны, — как в Deck.posts().
const POST_FREE := {"helm": "Сесть за штурвал", "energy": "Пульт энергии"}
## Где встать у пульта энергии (у поста «energy») и куда смотреть, рад: ниже — ползунки и рука на выбранном.
const POWER_STAND := Vector2(-4.05, -2.0)
const POWER_PITCH := PowerScreen.CAM_PITCH   ## наклон взгляда у открытого пульта (ракурс ART-050)
## Где встать у щитка «Аварийный сброс»: правое плечо напротив крышки, фигура позади камеры (Crew.Member.back)
## достаёт рукой без наклона и поворота ключицы (issue #137).
const SCRAM_STAND := Vector2(2.35, 17.0)
## Где встать у рычага разряда: своя фигура позади камеры (Crew.Member.back) — из середины поста пришлось бы
## наклониться до предела.
const ZAP_STAND := Vector2(-4.05, -0.5)
## Пост «Маршрут» — у правого борта голостола (с остальных сторон стол — сонар).
const ROUTE_POST := Vector2(1.5, BridgeProps.TABLE_Z)
const ROUTE_POST_R := 0.6


## Кнопка действия у поста.
func use_post(id: String) -> void:
	var other := Crew.holder(crew, me, id)
	if other:   # пост держит другой член экипажа
		say(Crew.busy_text(id, other))
		busy_said[id] = message.text
		return
	if id in ["sonar", "zap", "scram", "route"]:
		press_post = id
		press_t = CrewHands.PRESS
	match id:
		"helm":
			sit_at_helm()
		"energy":
			open_power()
		"sonar":
			ping_sonar()
			if sonar.ping_time == time:   # импульс прошёл (не «обесточен» и не «мало энергии»)
				tutorial.note(Tutorial.Ev.PING)
		"route":
			if run.ended:   # итог, решённый без своего игрока
				at_vote = true
				vote_panel.visible = true
			elif run.voting:   # голосование открыто (переход у 10, #828): вернуться к нему
				open_vote()
			else:
				announce(run.cycle())   # маршрут выбран — гостям тоже
				tutorial.note(Tutorial.Ev.ROUTE)
		"zap":
			walker.x = ZAP_STAND.x   # шаг к рычагу (#137)
			walker.z = ZAP_STAND.y
			walker.yaw = PI / 2.0   # рычаг на левом борту (−X)
			fire_zap()
		"airlock":
			if samples.state != Samples.State.IDLE:
				say("Захват за бортом — шлюз не закрыть")
			else:
				airlock.toggle()
		"winch":
			var why := samples.why_not(airlock.fully_open(), Samples.lock_point(Samples.ship_xform(helm.pos, helm.yaw)))
			if why != "":
				say(why)
		"scram":
			walker.x = SCRAM_STAND.x   # шаг к щитку (#137)
			walker.z = SCRAM_STAND.y
			walker.yaw = -PI / 2.0   # щиток на правом борту (+X)
			engine.press(reactor)
		"scanner":
			if gate.active():
				say(gate.press_text(lore))
			else:
				scanner.press()
		"journal":   # листать: сводка → карточки видов → сводка
			journal_page = (journal_page + 1) % Lab.pages(scanner)
			say(Lab.journal_info(samples) if journal_page == 0 else Lab.card_info(scanner, Lab.cards(scanner)[journal_page - 1]))
		_ when id.begins_with("flask"):
			say(Lab.flask_info(samples.cargo, int(id.substr(5))))
		_ when id.begins_with("door"):
			var d: ShipLayout.Door = layout.doors[int(id.substr(4))]
			d.open = not d.open
	press_at = Vector2(walker.x, walker.z)   # после шага к рычагу или щитку


## Открыть пробоину в месте n и поставить игрока у неё лицом к борту (сценарий тестера, снимки).
func open_breach(n: int) -> void:
	var s: Breach.Spot = breach.all[clampi(n, 0, breach.all.size() - 1)]
	breach.cd = 0.0
	if breach.active:
		breach.active = null
	breach.start(s)
	if pilot.seated:
		stand_up()
	walker.x = s.at.x
	walker.z = s.at.y
	walker.yaw = atan2(s.n.x, s.n.z)
	walker.pitch = atan2(s.p.y - Deck.Walker.EYE, Vector2(s.p.x, s.p.z).distance_to(s.at))   # взгляд на пробоину
	breach_view.apply()


## Убрать пробоину и воду без следа (сценарий тестера: чистый кадр 32-kaustiki после случайных ударов).
## Новая пробоина от удара не откроется ещё Breach.COOLDOWN секунд.
func close_breach() -> void:
	breach.reset()
	breach.cd = Breach.COOLDOWN
	breach_view.apply()


## Поставить корабль над образцом n: шлюз в 8 м над ним, корабль стоит, шлюз открыт (сценарий тестера, снимки).
func park_over_sample(n: int) -> void:
	var smp: Samples.Sample = samples.all[clampi(n, 0, samples.all.size() - 1)]
	helm.speed = 0.0
	helm.vy = 0.0
	helm.pos = smp.pos + Vector3(0.0, 8.0 - Airlock.Y, 0.0) - Basis(Vector3.UP, helm.yaw) * Vector3(0.0, 0.0, Airlock.Z)
	airlock.open = true
	airlock.t = 1.0
	rooms.apply(layout, reactor, airlock, engine)
	_place_ship()


## Поставить корабль в точку мира (y — высота, глубина со знаком минус) и остановить: снимки и шаг тестера `ship`.
func park_at(p: Vector3) -> void:
	helm.speed = 0.0
	helm.vy = 0.0
	helm.pos = p
	_place_ship()
	window_fog.snap(helm.depth(), vitals.hull, reactor.heat, reactor.scram)   # окна сразу по глубине (ART-077)
	bridge.set_fog(window_fog.humidity, window_fog.ice_k)


## Встать к пульту энергии: взгляд на пульт, крестовина правит доли, кнопка — закрыть.
func open_power() -> void:
	at_power = true
	var at: Vector2 = POWER_STAND   # шаг к пульту: из радиуса поста руки не достали бы до ползунков (#107)
	walker.x = at.x
	walker.z = at.y
	walker.yaw = PowerScreen.STAND_YAW   # пульт на левом борту (−X); камера — свой ракурс (_place_camera)
	walker.pitch = POWER_PITCH   # взгляд на ползунки: рука на выбранном видна
	power_panel.show_for(reactor, power)


func close_power() -> void:
	at_power = false
	power_panel.visible = false


func toggle_light() -> void:
	if not light_on and vitals.energy < 3.0:
		say("Мало энергии: прожектор не включить")
		return
	light_on = not light_on
	searchlight.apply(light_on, reactor.k(Reactor.Sys.LAMP))
	overlay.set_light(light_on)
	say("Прожектор включён" if light_on else "Прожектор погашен")


## Сообщение на приборах, гаснет через 4,2 с.
func say(msg: String) -> void:
	message.say(msg)


## Сообщение события для всего экипажа (пробоина, ил, маршрут): на своих приборах и у гостей — по кадру хоста.
## Своё («Вы за штурвалом») — `say`, гостям оно не уходит.
func announce(msg: String) -> void:
	say(msg)
	news = [(news[0] + 1) if news.size() == 2 else 1, msg]
	news_age = 0.0


## Пройти выбранный маршрут разом (или первый, если не выбран): сценарий тестера и снимки.
func complete_route() -> void:
	if run.route < 0:
		run.choose(0)
	for k in Run.ROUTES[run.route]["places"]:
		var p := Run.place_xz(k)
		say(run.update(p.x, p.y))


## Импульс сонара: сила — доля «Сонар»; существ в этот же шаг сообщит живой мир (EcoLink.NEAR). Голограмма одна на
## всех (гостям — `NetSnap.sonar`); everyone — нажал товарищ: ответ приборов и ему (`announce`).
func ping_sonar(everyone: bool = false) -> void:
	var tell := announce if everyone else say
	if reactor.k(Reactor.Sys.SONAR) > 0.0 and sonar.can_ping(time) and vitals.energy < Vitals.SONAR_COST:
		tell.call("Мало энергии: для импульса нужно %d единиц" % int(Vitals.SONAR_COST))
		return
	var msg := sonar.ping(time, reactor.k(Reactor.Sys.SONAR), silt.inside != null)
	if msg == "Сонар: импульс":
		vitals.spend(Vitals.SONAR_COST)
		eco_ship.sonar_ping = true   # существа слышат импульс и в иле
		eco_ship.sonar_range = Sonar.range_for(reactor.k(Reactor.Sys.SONAR))
		var jam := silt.jam_ping(time)
		if jam:
			msg = Silt.JAM_MSG
		ship_sounds.play_ping(jam)
	if not msg.is_empty():
		tell.call(msg)


## Разряд по корпусу: живой мир узнаёт о нём в этот же шаг (ShipState.zap, zap_radius).
func fire_zap() -> void:
	var msg := zap.fire(time, reactor.k(Reactor.Sys.ZAP), vitals)
	if zap.fired_at(time):
		eco_ship.zap = true
		eco_ship.zap_radius = zap.radius
		timeline.mark(time, "разряд")
		ship_sounds.play_zap()   # SND-003
		if scorch.add(helm.pos, Seabed.height(helm.pos.x, helm.pos.z), reactor.k(Reactor.Sys.ZAP), time):
			ocean.set_scorch(scorch.uniforms(time))   # разряд у дна — след под корпусом
	say(msg)


## Шаг живого мира: корабль отдаёт своё состояние, получает события (EcoLink) и решает, что с ними делать.
func _step_eco(dt: float) -> void:
	var s := _fill_ship_state(true)
	var events := eco.step(dt, s)
	clock.lap("мир", Time.get_ticks_usec())   # живой мир и его виды (EcoView)
	scanner.take(events if at_scanner else [])
	if s.sonar_ping and not sonar.jammed:
		sonar.take_contacts(events, helm.pos)
		announce("Сонар: контактов %d" % sonar.blips.size())   # отметки на голограмме видят все
	helm.extra_drag = 0.0   # нет события EcoLink.DRAG — тормоза нет (#270)
	for e in events:
		on_eco_event(e)
	s.sonar_ping = false
	s.zap = false
	clock.lap("события мира", Time.get_ticks_usec())


## Событие живого мира (EcoLink). Пока — на приборы; урон корпусу и тревога — задачи потока А.
func on_eco_event(e: Dictionary) -> void:
	match e.get("type", ""):
		EcoLink.HIT:
			if flyby.shields() or events_held():
				return   # облёт в начале забега (#506) и обучение у старта (#827): удар не доходит до корпуса
			var at: Variant = e.get("at")
			hit_local = hit_local_of(at) if at is Vector3 else null   # откуда бьёт — для звука удара (#656)
			vitals.hit(roundi(float(e.get("damage", 0.0)) * 100.0), str(e.get("by", "")))
			hit_local = null
		EcoLink.DRAIN:
			if events_held():
				return   # обучение (#827): присоски энергию не тянут
			vitals.drain(str(e.get("by", "")), float(e.get("units", 0.0)))
		EcoLink.MESSAGE:
			_world_say(str(e.get("text", "")))
		EcoLink.VOICE:   # голос во внутренней связи ART-040; просьбу не исполняем — решает игрок
			if bool(e.get("fake", false)) and events_held():
				return   # обучение (#827): подделок в эфире нет, свои доклады идут
			comms.push(int(e.get("role", Crew.Role.ENGINEER)), str(e.get("text", "")), bool(e.get("fake", false)),
				str(e.get("ask", "")), bool(e.get("silent", false)))
		EcoLink.DRAG:   # присоски на корпусе тормозят корабль (js/ship.js: drag = 0.45 + 0.025 * hullRemoras)
			helm.extra_drag = 0.0 if events_held() else float(e.get("k", 0.0))   # обучение (#827) — не тормозят
		EcoLink.STEAL:   # образец сорван с захвата (M.steal в js/manip.js)
			if samples.steal(int(e.get("sample", -1))):
				say("Образец украден: %s выхватил его из захвата и уносит в нору" % str(e.get("by", "Кто-то")))
		EcoLink.FIELD:   # импульс с площадки 08 поймал ритм поля (#833) — «граница» в журнале (#829)
			lore.learn(LayerLore.FIELD08)
			_world_say(str(e.get("text", "")))
		EcoLink.SHELL:   # Раковина 03: гнёзда на сканере и рельеф на сонаре (#835) — знание «осмотр 03»
			lore.learn(LayerLore.SHELL03)
			_world_say(str(e.get("text", "")))
		EcoLink.PETAL:   # купольник у 07 поднял створку гнезда (#837) — знание в кампании, больше не выходит
			if lore.learn(LayerLore.PETAL07):
				_world_say(str(e.get("text", "")))
		EcoLink.DROP:   # унесённый образец снова на дне (M.drop)
			samples.drop(int(e.get("sample", -1)), e.get("at", Vector3.ZERO))
		EcoLink.OBSERVE:   # наблюдение в журнал (handleEvents в js/game.js)
			var sp := str(e.get("species", ""))
			var fresh := scanner.observe(sp, str(e.get("note", "")))
			var text := str(e.get("text", ""))
			if text != "":
				_world_say(text)
			elif fresh:
				_world_say("Новое наблюдение: %s" % Species.called(sp, Species.Case.NOM, scanner.is_scanned(sp)))


## Строка живого мира на приборы. Пока идёт облёт в начале забега, она не перебивает `Flyby.START_MSG` — игрок ещё
## ничего не делает, а сцена у старта сразу в луче (#827); наблюдение в журнал при этом записано.
func _world_say(text: String) -> void:
	if flyby.kind != Flyby.Kind.START:
		message.say(text, Status.MESSAGE_SECONDS, true)   # не стирает строку, видную меньше 1 с (issue #979)


## Идёт обучение у старта 00 (#827, `Tutorial.holds_events`): события слоя ждут его конца.
func events_held() -> bool:
	return tutorial.holds_events()


## Точка удара at (мир) в осях корабля: нос −Z, правый борт +X (`HullSound.side`).
func hit_local_of(at: Vector3) -> Vector3:
	return (at - helm.pos).rotated(Vector3.UP, -helm.yaw)


func _on_hit(percent: int, kind: String) -> void:
	ship_sounds.play_hit(percent, kind, hit_local)   # SND-002: удар (по стороне) или удар о дно со скрежетом (#656)
	lock_water.on_hit()   # рябь в шахте шлюза вспыхивает (ART-073)
	var held := events_held()   # обучение у старта (#827): ни сонарной тьмы, ни пробоины от удара о дно
	if kind == "scrape" and not held:   # удар о дно поднимает ил
		silt.on_scrape(helm.pos, Seabed.height(helm.pos.x, helm.pos.z))
	if not held and breach.on_hit(percent, vitals.hull):
		return   # о пробоине скажет Breach
	if kind == "scrape":
		say("Удар о дно: корпус −%d%%" % percent)
	elif kind.is_empty():
		say("Удар по корпусу: −%d%%" % percent)
	else:
		say("%s бьёт по корпусу: −%d%%" % [kind, percent])


## Уход к Кристальному лесу (#828): посреди экрана «в разработке» корабль — снова у 10, знания и сохранение.
func _trip_step(dt: float) -> void:
	if not trip.active:
		return
	match trip.update(dt):
		"arrive":
			park_at(DescentTrip.return_spot())
			helm.yaw = 0.5 * PI   # носом на запад — к террасе 07
			_place_ship()
			lore.learn(LayerLore.DOWN)
			lore.learn(LayerLore.BACK)
			save_now()
			timeline.mark(time, "вернулись к спуску 10")
		"done":
			announce(DescentTrip.BACK_MSG)
	trip_view.apply(trip)


## «Сохранить» в паузе (#823): записать сейчас — груз, виды, журнал и корабль на месте.
func save_now() -> bool:
	return save.save(samples, scanner)


## «Продолжить» в главном меню (#823) — `MenuFlow.continue_run`.
func continue_run() -> void:
	menu_flow.continue_run()


## Главное меню ART-037 поверх сцены — `MenuFlow.open_menu` (#753).
func open_menu() -> void:
	menu_flow.open_menu()


## Настройки ART-037 поверх меню или паузы — `MenuFlow.open_settings` (#753).
func open_settings() -> void:
	menu_flow.open_settings()


func _settings_show() -> void:
	menu_flow.settings_show()


## Громкость, свайп, уровень графики, рация — `MenuFlow.apply_settings` (#753).
func _apply_settings() -> void:
	menu_flow.apply_settings()


## Уровень графики ART-044 (`Graphics.LEVELS`): дальность камер, «Экономно» у рельефа, частиц и пост, тени света
## сквозь лёд и прожектора, сглаживание и разрешение 3D-сцены (интерфейс — в полном), сила слоёв воды.
func _apply_graphics(level: int) -> void:
	graphics_level = Graphics.valid(level)
	var g := Graphics.level(graphics_level)
	var lite: bool = g["lite"]
	for cam: Camera3D in [camera, flyby_cam]:
		if cam:
			cam.far = g["far"]
	if ocean:
		ocean.set_far(g["wall"])
		ocean.set_relief(not lite)    # лёд ART-056
		ocean.set_shafts_lite(lite)   # лучи ART-052 без чтения глубины кадра (#852)
		ocean.set_snow_lite(lite)     # взвесь ART-058 реже, без вращения
		ocean.set_decals_lite(lite)   # декали дна ART-066 реже и ближе
		ocean.set_layers_level(g["layers"])   # слои воды ART-069: 0 / 0,6 / 0,9
		ocean.set_shadows(g["shadows"])
	if hull:
		hull.set_relief(not lite)     # обшивка ART-053
	if bridge:
		bridge.set_relief(not lite)   # мостик ART-054
		bridge.set_wet(g.get("wet", false))   # капли ART-077 с преломлением — только «Красиво»
	if rooms:
		rooms.set_relief(not lite)    # отсеки ART-055
		rooms.drops.lite = lite       # капли износа ART-074: 12 карточек
	if searchlight:
		searchlight.set_lite(lite)    # луч прожектора ART-062 без дрейфа
		searchlight.spot.shadow_enabled = int(g["shadows"]) > 0
	wake.lite = lite                  # след винтов ART-063: 96 карточек, кадры 0–11
	if wake_view:
		wake_view.set_lite(lite)
	valve_steam.lite = lite           # пар вентиля ART-071: 24 карточки
	lock_water.lite = lite            # рябь в шахте шлюза ART-073 × 0,625
	if breach_view:
		breach_view.parts.lite = lite  # частицы пробоины ART-072: 24/16/15+1
	if grade:
		grade.set_lite(lite)          # виньетка ART-065: без LUT и без копии экрана, овал 0,10 (#842)
	if env:
		env.glow_enabled = not lite   # bloom — лишние проходы размытия на слабых телефонах (#842)
	glints.lite = lite                # блики воды в мостике ART-067 выключены
	if eco:
		eco.set_lite(lite)            # живой мир: флора не колышется, ободка тел нет (EcoView.set_lite, #598)
	var vp := get_viewport()
	if vp:
		vp.msaa_3d = {0: Viewport.MSAA_DISABLED, 2: Viewport.MSAA_2X, 4: Viewport.MSAA_4X}.get(int(g["msaa"]),
			Viewport.MSAA_2X)
		vp.scaling_3d_scale = g["scale"]


## «Журнал экспедиции» ART-047 — `MenuFlow.open_journal` (#753).
func open_journal() -> void:
	menu_flow.open_journal()


func _journal_show() -> void:
	menu_flow.journal_show()


## Сбор экипажа ART-028 по «Экипаж» — `LobbyFlow.open_lobby` (#755).
func open_lobby(why := "") -> void:
	lobby_flow.open_lobby(why)


## Экран «Войти по адресу» ART-039 поверх входа сбора экипажа — `LobbyFlow.open_address` (#755).
func open_address() -> void:
	lobby_flow.open_address()


## Системная «Назад» (Esc на ПК): пауза, схема, экраны меню — `PauseFlow.back_pressed` (#754).
func back_pressed() -> void:
	pause_flow.back_pressed()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_ESCAPE:
		back_pressed()


## Схема корабля ART-042 поверх паузы / меню забега (`PauseFlow.open_map`).
func open_map(where: String) -> void:
	pause_flow.open_map(where)


## Кнопка «Схема» на подсказке первого забега (`PauseFlow.open_hint_map`).
func open_hint_map() -> void:
	pause_flow.open_hint_map()


## Встать с постов перед новым забегом (штурвал, пульт, голосование).
func _leave_posts() -> void:
	if pilot.seated:
		stand_up()
	if at_power:
		close_power()
	if at_vote:
		at_vote = false
		vote_panel.visible = false


func close_menu() -> void:
	menu_flow.close_menu()


## Корпус разрушен: шторка ART-036 3,5 с (`Wreck`), под сплошной шторкой — загрузка последнего сохранения кампании
## (#824, `_load_last`); сохранения нет — подъём к старту с целым корпусом. Ввод на это время не идёт в игру.
func _on_destroyed() -> void:
	if wreck.active():
		return
	_leave_posts()
	pause.close()
	if ship_map.open:
		ship_map.close()
		pause_flow.map_show()
	if settings.open:
		settings.close()
		_settings_show()
	if pause_panel:
		pause_panel.show_pause(pause)
	wreck.start()
	wreck_view.sub.text = Wreck.sub(has_saved_ship())
	_wreck_show()


## Шаг шторки «Корпус разрушен»: сплошная — загрузка последнего сохранения (#824). true — шторка идёт (ввод не
## идёт в игру).
func _wreck_step(dt: float) -> bool:
	if not wreck.active():
		return false
	if wreck.update(dt):
		expedition.end_run()
		timeline.finish(time, "корпус разрушен", Time.get_datetime_string_from_system(false, true))
		if _load_last():
			say(LOADED_MSG)
		else:
			say("Корпус разрушен. Ковчег поднят к началу спуска")
	_wreck_show()
	return wreck.active()


## Шторка на экране; крестовина, кнопка, строки приборов и плашки скрыты, пока она идёт (#473).
func _wreck_show() -> void:
	wreck_view.show_at(wreck.t)
	var on := wreck.active()
	overlay.visible = not on
	hint.visible = not on
	drop_panel.set_quiet(on)


## Есть сохранённое место кампании (#823), к которому вернёт гибель (#824).
func has_saved_ship() -> bool:
	return save.live and not save.ship.is_empty()


## Гибель в кампании (#824): системы и события как на старте, корабль — место, курс, корпус и заряд последнего
## сохранения, без облёта. Груз, изученные виды, знания слоя и журнал не трогаются (они в памяти те же, что в
## файле). false — сохранённого места нет: корабль у начала спуска, как `_restart`.
func _load_last() -> bool:
	_reset_ship()
	if not has_saved_ship() or not SaveGame.ship_apply(save.ship, helm, vitals):
		_begin_run()
		return false
	wear.snap(vitals.hull)
	window_fog.snap(helm.depth(), vitals.hull, reactor.heat, reactor.scram)
	_begin_run(false)
	return true


## Корабль у начала спуска, целый и заряженный, забег с нуля (новый забег из паузы, после итога, в меню).
func _restart() -> void:
	_reset_ship()
	_begin_run()


## Корабль у начала спуска, целый и заряженный; события, посты и связь — с нуля.
func _reset_ship() -> void:
	ballot.clear()
	role_card.reset_run()
	comms.reset_run(_code_rng.randi())   # новый забег — новое кодовое слово, очередь связи пуста
	for m: Crew.Member in crew:
		if m != me:
			m.at_vote = false
	if at_vote:
		at_vote = false
		vote_panel.visible = false
	helm.reset()
	vitals.reset()
	wear.snap(vitals.hull)   # новый забег — стены сразу сухие
	breach.reset()
	silt.reset()
	reactor.reset()   # сброс, перегрев и доли — как на старте (#265)
	window_fog.snap(helm.depth(), vitals.hull, reactor.heat, reactor.scram)   # окна — по глубине старта (ART-077)
	airlock.reset()
	lock_water.reset()
	scorch.clear()
	ocean.set_scorch(scorch.uniforms(time))
	walker.reset()
	var spawn := Crew.spawn_spot(crew, me, walker.x, walker.z, layout.can_stand)   # не в товарища у штурвала (#602)
	walker.x = spawn.x
	walker.z = spawn.y
	light_on = true
	overlay.set_light(true)


func _begin_run(fly := true) -> void:
	autosave.reset()   # место под кораблём на старте или после «Продолжить» — не повод записать
	run.begin(time, samples.cargo.size(), scanner.scanned.size(), breach.count)
	timeline.begin(time)
	if fly and intro and settings.intro:
		flyby.start(Flyby.Kind.START)   # облёт корабля с борта, затем — глаза на мостике
		say(Flyby.START_MSG)


## У голостола после пройденного маршрута: мнения ролей, крестовина — решение, кнопка — отложить.
func open_vote() -> void:
	at_vote = true
	run.open_vote()
	var ops := Run.opinions(vitals.hull, vitals.energy, reactor.hot, silt.inside != null, samples.cargo.size())
	votes = VoteHolo.votes(ops)
	vote_panel.show_vote(run.depth, ops)
	if not pilot.seated:   # взгляд с карты брифинга — на поля голосования (#193)
		var v := VoteHolo.look(Vector3(walker.x, Deck.Walker.EYE, walker.z), sonar_view.position)
		walker.yaw = v.x
		walker.pitch = v.y


func close_vote() -> void:
	at_vote = false
	vote_panel.visible = false
	if run.ended:
		_restart()
		say("Новый забег: Ковчег у начала спуска")


## Решение экипажа: "deep" — следующий спуск, "up" — итог забега на экране.
func decide(choice: String) -> void:
	ballot.clear()
	vote_panel.set_tally("")
	if choice == "deep":
		for m: Crew.Member in crew:   # все у стола отходят: маршрут выбирать заново
			m.at_vote = false
		vote_panel.visible = false
		timeline.mark(time, "решили: глубже")
		var at_ten := run.at_descent()
		var msg := run.go_deeper()
		if at_ten:   # у спуска 10 — кат-сцена и экран «Кристальный лес — в разработке» (#828)
			trip.start()
			msg = DescentTrip.START_MSG
		announce(msg)   # гостям — тоже
		return
	var rows := run.finish(time, samples.cargo.size(), scanner.scanned.size(), breach.count, vitals.hull)
	expedition.end_run()
	timeline.finish(time, "наверх, очки %d" % run.score, Time.get_datetime_string_from_system(false, true))
	result_rows = run.summary(samples.cargo.size(), scanner.scanned.size(), breach.count)
	result_detail = Run.detail(rows)
	vote_panel.show_results(result_detail, run.score)
	vote_panel.visible = at_vote   # решили товарищи, пока свой у другого поста: итог — у голостола
	flyby.start(Flyby.Kind.SURFACE)   # вид с борта при всплытии, затем — итог на голограмме
	wake.vent()   # продувка: пузыри у сервисных крышек
	announce("Экипаж поднялся наверх: очки %d" % run.score)


func sit_at_helm() -> void:
	pilot.sit(walker)
	overlay.set_pilot(true)
	say(SAT_MSG)
	tutorial.note(Tutorial.Ev.SAT)


## Где раскладывать плашку связи ART-040 — пересылка `OverlayFlow.comms_area` (тесты, `tools/shot.gd`, `QaRunner`).
func comms_area() -> Rect2:
	return overlay_flow.comms_area()


func stand_up() -> void:
	pilot.stand(walker)
	overlay.set_pilot(false)
	message.clear(SAT_MSG)


## Тестовая кнопка noclip: вкл — игрок летит сквозь корпус смотреть живой мир; выкл — назад на пол, где включил.
func toggle_noclip() -> void:
	if walker.noclip:
		walker.noclip = false
		var p := layout.free_spot(_noclip_return.x, _noclip_return.y)
		walker.x = p.x
		walker.z = p.y
		walker.y = Deck.Walker.EYE
		say("noclip выкл")
	else:
		if pilot.seated:
			stand_up()
		if at_power:
			close_power()
		if at_vote:   # выходим из голосования без перезапуска забега
			at_vote = false
			vote_panel.visible = false
		_noclip_return = Vector2(walker.x, walker.z)
		walker.noclip = true
		walker.y = Deck.Walker.EYE
		say("noclip вкл — крестовина ведёт по взгляду, можно выйти с корабля")
	overlay.set_noclip(walker.noclip)


## След винтов ART-063: пузыри за роторами по тяге, в мировых координатах.
func _wake(dt: float) -> void:
	wake.update(dt, Transform3D(Basis(Vector3.UP, helm.yaw), helm.pos), hull_motion.spin, current.vel())
	wake_view.apply(wake, helm.pos)


func _place_ship() -> void:
	ship.position = helm.pos
	ship.rotation = Vector3(0.0, helm.yaw, 0.0)
	hull.apply(hull_motion)
	hull.set_hull(vitals.hull)   # следы повреждений ART-049
	hull.set_rim(helm.depth(), silt.k, HullMesh.rim_alive(wreck.t))   # ободок ART-076
	bridge.set_wheel_turn(helm.turn)
	ocean.apply_water(env, helm.depth(), helm.pos, silt.k)
	ocean.set_ship(helm.pos, helm.yaw)   # лучи ART-052 не светят внутри корпуса


var power_eye := Vector3.ZERO   ## сдвиг глаза наклоном своей фигуры на ракурсе пульта (`_apply_crew_view`)


## Открыт пульт энергии — камера и своя фигура на ракурсе ART-050 (`PowerScreen.CAM_AT`), а не в ходоке.
func power_view() -> bool:
	return at_power and not walker.noclip


## Фигуры экипажа (dt ≥ 0 — ещё шаг наклона своей фигуры к посту). У открытого пульта своя фигура стоит у камеры
## ракурса (как в принятом макете ART-050: тянется к ползункам, тело не заслоняет пульт), и камера — в её голове;
## место игрока для постов и сети остаётся у пульта (`POWER_STAND`). Курс фигуры — курс ходока (лицом к пульту,
## как стоя у поста), а не курс камеры: повёрнутая на 70° фигура тянула правую руку через весь кадр (#576).
func _apply_crew_view(dt: float = -1.0) -> void:
	var keep := [me.x, me.z, me.yaw]
	if power_view():
		me.x = PowerScreen.CAM_AT.x
		me.z = PowerScreen.CAM_AT.y
	if dt >= 0.0:
		me.ease_lean(dt)
	crew_view.hide_own = power_view()   # #576: рукава у пульта загромождали кадр — фигуру прячем, пока нет анимации рук
	crew_view.apply()
	power_eye = me.eye_offset()
	me.x = keep[0]
	me.z = keep[1]
	me.yaw = keep[2]


func _place_camera() -> void:
	if flyby.active():
		flyby_cam.transform = flyby.pose()
		if not flyby_cam.current:
			flyby_cam.make_current()
	elif flyby_cam.current:   # облёт кончился — глаза на мостике
		camera.make_current()
	camera.position = pilot.eye(walker) + me.eye_offset()   # наклон к посту — камера в голове
	var cam_yaw := walker.yaw
	if power_view():   # ракурс ART-050: камера отходит от ходока, таблица не закрывает ползунки
		camera.position = PowerScreen.cam_pos(pilot.eye(walker)) + power_eye
		cam_yaw = PowerScreen.cam_yaw(walker.yaw)
	if vitals.shake > 0.0:   # тряска после удара: детерминированная, затухает за 0,6 с
		var a := vitals.shake / 0.6 * 0.04
		camera.position += Vector3(sin(time * 61.0) * a, sin(time * 47.0 + 1.3) * a, 0.0)
	camera.rotation = Vector3(walker.pitch, cam_yaw, 0.0)
	var eye := flyby_cam if flyby_cam.current else camera
	grade.apply(-eye.global_position.y, silt.k)   # ART-065: по глубине камеры, не корабля


func _update_ui() -> void:
	if pilot.seated:
		overlay.set_action_label("Встать")
	elif at_power:
		overlay.set_action_label("Закрыть")
	elif at_vote:
		overlay.set_action_label("Дальше" if run.ended else "Позже")
	else:
		var post := Deck.nearest(posts, walker.x, walker.z)
		var label := ""
		if post:
			label = POST_BUTTON.get(post.id, "Люк" if post.id.begins_with("door") else "Колба" if post.id.begins_with("flask") else "")
			if Crew.holder(crew, me, post.id):
				label = "Занято"
		overlay.set_action_label(label)
	var font := hint.get_theme_font("font")
	var fs := hint.get_theme_font_size("font_size")
	var width := minf(900.0, get_viewport().get_visible_rect().size.x - 48.0)
	if status_lines.update(status_parts(),   # шрифтом меряем только новую строку (#847)
			func(t: String) -> float: return font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, width, fs):
		hint.text = status_lines.text
		hint.reset_size()   # Label сам растёт, но не ужимается: после длинного сообщения плашка оставалась высокой
	var plate := Rect2(HINT_POS, hint.size)
	hint.position.y = AlarmBoard.status_y(plate, board_screen_rect())   # плашка под табло, а не поверх (#376)


## Плашка строки состояния на экране (метки и таблички на неё не ложатся, #387); пусто, если строк нет.
func status_rect() -> Rect2:
	if hint == null or not hint.is_visible_in_tree() or hint.text.is_empty():
		return Rect2()
	return Rect2(hint.position, hint.size)


## Табло тревог на экране (AlarmBoard.screen_rect); пусто, если его нет в кадре.
func board_screen_rect() -> Rect2:
	var cam := get_viewport().get_camera_3d()
	if cam == null or alarm_board == null or not alarm_board.is_inside_tree():
		return Rect2()
	var pts := PackedVector2Array()
	var behind := false
	for c in AlarmBoard.corners():
		var g := alarm_board.to_global(c)
		behind = behind or cam.is_position_behind(g)
		pts.append(cam.unproject_position(g))
	return AlarmBoard.screen_rect(pts, behind, get_viewport().get_visible_rect())


## Где на экране интерфейс, на который не ложится табличка товарища (#319): кнопки и открытые панели.
func tag_blocks() -> Array:
	var l := overlay.router.layout
	var out: Array = []
	var buttons: Array = [l.noclip, l.pad, l.action]
	if overlay.router.pilot_buttons:
		buttons.append_array([l.up, l.down, l.light])
	for c: Touch.Circle in buttons:
		out.append(NameTag.circle_rect(c.c, c.r))
	for p: Control in [vote_panel, power_panel]:
		if p.visible:
			out.append(p.call("box"))
	if route_card.visible:
		out.append(route_card.rect)
	if tutorial_panel != null and tutorial_panel.visible:   # плашка подсказки ART-038
		out.append(tutorial_panel.box())
	return out


## Сведение шин звука по состоянию игры (SoundMix.Mix): меню, пауза мира, вид с борта, тревога, глубина.
func _sound(dt: float) -> void:
	sound_mix.menu = main_menu.open and not warm.active()
	sound_mix.paused = pause.open and pause.stops_world()
	sound_mix.outside = flyby.active()
	sound_mix.tension = wreck.active() or alarms_on().slice(0, AlarmBoard.Field.size() - 1).has(true)
	sound_mix.depth = helm.depth()
	SoundMix.apply(sound_mix.update(dt), settings.buses)   # × громкости шин из настроек («Звук»)
	ambience.set_pair(sound_mix.ambient_pair())
	music.set_pair(sound_mix.music_pair())


## Активные поля табло тревог (AlarmBoard.Field) — из тех же строк, что тревога в строке состояния.
func alarms_on() -> Array[bool]:
	return AlarmBoard.active(breach.status(), vitals.drain_alarm(), reactor.alert(), silt.alarm(),
		vitals.energy < Vitals.LOW_ENERGY)


## Части строки состояния: где игрок, глубина, ход, у штурвала — до дна, курс и прожектор, течение, пост рядом, сообщение.
func status_parts() -> Array:
	var parts: Array = []
	var alarm := Status.alarm([breach.status(), vitals.drain_alarm(), reactor.alert(), silt.alarm(), vitals.warning()])
	if not alarm.is_empty():
		parts.append(alarm)
	parts.append("За штурвалом" if pilot.seated else ShipLayout.ROOM_NAMES[ShipLayout.room_at(walker.z)])
	parts.append("глубина %d м" % roundi(helm.depth()))
	parts.append("ход %s м/с" % _num(helm.speed))
	parts.append("корпус %d%%" % roundi(vitals.hull))
	parts.append("энергия %d" % floori(vitals.energy))
	if pilot.seated:
		parts.append("до дна %d м" % roundi(helm.pos.y - Seabed.height(helm.pos.x, helm.pos.z)))
		parts.append("курс %d°" % Status.course_deg(helm.yaw))
		parts.append("прожектор %s" % ("вкл" if light_on else "выкл"))
	parts.append(run.status(helm.pos.x, helm.pos.z))
	if reactor.alert().is_empty():
		parts.append("реактор %d/%d" % [reactor.used(), reactor.limit()])
	parts.append("течение на %s %s м/с" % [Status.rumb(current.vel()), _num(Helm.SeaCurrent.SPEED)])
	if not airlock.closed():
		parts.append("шлюз открыт" if airlock.fully_open() else "шлюз в движении")
	if not pilot.seated and not at_power and not at_vote:
		var post := Deck.nearest(posts, walker.x, walker.z)
		if post:
			parts.append(post.label)
	if message.visible():
		parts.append(message.text)
	return parts


static func _num(v: float) -> String:
	return ("%.1f" % v).replace(".", ",")


## Облако ила вокруг корабля, как от удара о дно (сценарий тестера, снимки).
func open_silt() -> void:
	var cl := silt.spawn(helm.pos, Silt.SCRAPE_R, Silt.SCRAPE_LIFE, "scrape")
	cl.life = Silt.SCRAPE_LIFE - 3.0   # уже густое
	silt.update(0.0, helm.pos, Vector3.ZERO)
	silt.k = 1.0
	silt_view.apply(silt, time, helm.pos, helm.yaw)
	_place_ship()


## Другие члены экипажа идут своим ходоком по своему вводу (`Member.pad`; позже — по сети). Ввод с экрана — только `me`.
## Голосование у голостола: голоса тех, кто у стола (Ballot), решение — большинством или по таймеру.
func _tick_vote(dt: float) -> void:
	if not run.voting or run.ended:
		ballot.clear()
		return
	var ids := vote_ids()
	var choice := ballot.update(dt, ids)
	if ids.size() > 1:
		vote_panel.set_tally(ballot.tally(ids.size()))
	elif vote_panel.tally != "":
		vote_panel.set_tally("")
	if choice != "":
		decide(choice)


## Кто голосует: члены экипажа у голостола (id — get_instance_id).
func vote_ids() -> Array:
	var out := []
	for m: Crew.Member in crew:
		if m.at_vote:
			out.append(m.get_instance_id())
	return out


## Метки на голограмме: у стола двое и больше — голоса игроков цветами ролей, один — мнения ролей.
func vote_marks() -> Dictionary:
	return ballot.marks() if vote_ids().size() > 1 else votes


## Открыть сетевой забег хостом — пересылка `NetGame.host_game` (тесты, `tools/`).
func host_game(port: int = NetLink.PORT) -> Error:
	return net_game.host_game(port)


## Войти в сетевой забег хоста — пересылка `NetGame.join_game` (тесты, `tools/`).
func join_game(to: String, port: int = NetLink.PORT, player: String = "", role: int = Crew.Role.PILOT, look: int = 0) -> Error:
	return net_game.join_game(to, port, player, role, look)


## Товарищ ушёл с борта — пересылка `NetGame.mate_gone` (`QaRunner`, `tools/`).
func mate_gone(m: Crew.Member) -> void:
	net_game.mate_gone(m)


## Состояние корабля для живого мира (`eco_ship`): место, курс, ход, прожектор (с илом), глубина маршрута. full —
## у хоста ещё шум двигателей, сканер и захват лебёдки. Гостю они не нужны нарочно (#765): его мир событий не шлёт,
## существа рядом, цели сканера и кража образца приходят кадром хоста (`EcoLink.apply_world`), а `hull_noise` мир
## пока не читает — у гостя они остаются прежними (нулями), и мир гостя не считает списки сканера зря.
func _fill_ship_state(full: bool) -> EcoLink.ShipState:
	var s := eco_ship
	s.pos = helm.pos
	s.yaw = helm.yaw
	s.speed = helm.speed
	s.light_on = Searchlight.lit(light_on, reactor.k(Reactor.Sys.LAMP))
	s.light_range = Searchlight.range_m(reactor.k(Reactor.Sys.LAMP)) * silt.beam_k() if s.light_on else 0.0
	s.dive = run.depth
	s.petal_open = lore.knows(LayerLore.PETAL07)   # у гостя — по знаниям хоста (кадр «k»)
	if not full:
		return s
	s.hull_noise = engine.noise(clampf(absf(helm.speed) / 6.7, 0.0, 1.0))
	s.scan_range = Scanner.RANGE if at_scanner else 0.0
	var xf := Samples.ship_xform(helm.pos, helm.yaw)
	s.claw = samples.hook_world(xf)
	s.claw_state = samples.state   # Samples.State совпадает с EcoLink.CLAW_*
	s.claw_target = samples.target.pos if samples.target else Vector3.ZERO
	s.claw_sample = samples.target.i if samples.target else -1
	return s


## Ещё один член экипажа на палубе — пересылка `CrewFlow.add_mate` (тесты, `tools/`, `QaRunner`).
func add_mate(x: float, z: float, yaw: float, role: int, look: int, seated: bool = false) -> Crew.Member:
	return crew_flow.add_mate(x, z, yaw, role, look, seated)
