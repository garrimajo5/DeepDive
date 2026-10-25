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
var breach_view: BreachView
var debug_weld := false        ## снимок: сварку держат без пальца
var save := SaveGame.new()     ## груз трюма, поднятые образцы и изученные виды в user:// (js/save.js)
var expedition := Expedition.new()   ## история для журнала ART-047: места, забеги, рекорд глубины, прочитанное
var scanner := Scanner.new()   ## сканер биолога: цели от живого мира, изученные виды
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
var engine := EngineRoom.new()   ## машинное: вентиль сброса пара и щиток «Аварийный сброс»
var debug_vent := false          ## снимок: вентиль держат без пальца
var debug_winch := false         ## снимок: кнопку у лебёдки держат без пальца
var zap_light: OmniLight3D   ## вспышка разряда вокруг корпуса (за бортом)
var drain_sound: AudioStreamPlayer   ## шипение тревоги, пока на корпусе присоска (Synth.latch)
var drain_hisses := 0                ## сколько раз шипела тревога присоски (для тестов)
## Прогрев шейдеров при старте (Warmup, issue #50): шторка, камера оглядывает корабль, скрытое показано на кадр.
var warm := Warmup.new()
var curtain: WarmSplash   ## заставка прогрева (ART-034), после прогрева — null
var _warm_drawn := false            ## прошлый шаг показал взгляд прогрева
var _warm_shown: Array[Node] = []   ## что прогрев показал на кадр — вернуть скрытым
var _warm_mates: Array = []         ## члены экипажа на время прогрева (каждая внешность)
var _warm_emit: Array = []          ## частицы, выпущенные прогревом: [узел, прежний preprocess]
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
var radio := Radio.new()   ## рация ART-041 (в игре скрыта до решения по голосу — `Radio.enabled`)
var radio_panel: RadioPanel
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
var graphics_level := Graphics.DEFAULT   ## применённый уровень графики ART-044 (`_apply_graphics`)
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
var message := Status.Message.new()
const SAT_MSG := "Вы за штурвалом"
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
	_build_world()
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
	walker.stand = stand_for(me)
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
	comms_panel = CommsPanel.new()   # плашка связи ART-040: касания — через Router.blocks/taps (`_comms_step`)
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
	lite_offer_panel = LiteOfferPanel.new()   # предложение «Экономно» ART-044: касания — `_offer_step`
	add_child(lite_offer_panel)
	if settings.pick_first(Graphics.auto_here()):   # первый запуск — уровень графики по телефону ART-044
		var d := Graphics.device()
		print("графика: автовыбор «%s» (%s, %d МБ)" % [Graphics.NAMES[settings.graphics], d["adapter"], d["memory_mb"]])
	settings.read()
	_apply_settings()
	tutorial.on = hints and not settings.hints_done and not QaRunner.pending()   # тестер включает шагом `tutorial`
	role_card.on = hints and not QaRunner.pending()   # тестер включает шагом `cards`
	role_card.set_read(settings.cards)
	save.expedition = expedition
	save.load_into(samples, scanner)
	_begin_run()
	samples.changed.connect(save.mark)
	scanner.changed.connect(save.mark)
	expedition.changed.connect(save.mark)
	scanner.message.connect(say)
	_place_ship()
	_place_camera()
	_begin_warmup()
	if menu:
		open_menu()
	if QaRunner.pending():
		start_qa()


## Идёт прогрев шейдеров: экран под шторкой, сценарий тестера ждёт.
func warming() -> bool:
	return warm.active()


## Заставка (WarmSplash, ART-034) и члены экипажа каждой внешности на время прогрева (Warmup).
func _begin_warmup() -> void:
	if not warm.active():
		return
	curtain = WarmSplash.new()   # заставка ART-034: фон, полоса по доле прогрева, подсказки
	add_child(curtain)
	for look in CrewRig.MODELS.size():
		var at: Vector2 = Warmup.MATE_AT[look % Warmup.MATE_AT.size()]
		_warm_mates.append(add_mate(at.x, at.y, PI, Crew.Role.PILOT, look))
	for look in CrewRig.MODELS.size():   # и материалом своего игрока: свои руки у пульта энергии (#217)
		var at: Vector2 = Warmup.OWN_AT[look % Warmup.OWN_AT.size()]
		var m := add_mate(at.x, at.y, PI, Crew.Role.PILOT, look)
		_warm_mates.append(m)
		crew_view.as_own.append(m)
	crew_view.apply()
	for r in Crew.Role.size():   # и полупрозрачными, как отключившийся гость (ART-043): каждая роль со снаряжением
		var g := Crew.Member.new(r)
		g.look = r % CrewRig.MODELS.size()
		var at: Vector2 = Warmup.MATE_AT[r % Warmup.MATE_AT.size()]
		g.place(at.x, at.y, PI)
		ghosts.append(MateGhost.new(g))
	_ghosts(0.0, true)
	_warm_particles(true)
	power_panel.reactor = reactor   # пульт энергии рисует строки под шторкой: шрифты всех размеров (#217)
	power_panel.panel = power
	_warm_frame()


## CPUParticles3D корабля (если появятся) на время прогрева выпущены сразу (preprocess) — их шейдер собирается под
## шторкой, а не при первом событии (issue #159). Конец прогрева — снова пусто. Пар вентиля ART-071 и частицы пробоины
## ART-072 — MultiMesh с пустой карточкой: их показывает _warm_show.
func _warm_particles(on: bool) -> void:
	if on:
		for p: CPUParticles3D in ship.find_children("*", "CPUParticles3D", true, false):
			if not p.emitting:
				_warm_emit.append([p, p.preprocess])
				p.preprocess = p.lifetime
				p.restart()
		return
	for e in _warm_emit:
		var p: CPUParticles3D = e[0]
		if is_instance_valid(p):
			p.preprocess = e[1]
			p.restart()
			p.emitting = false
	_warm_emit.clear()


## Конец шага: пока идёт прогрев — взгляд камеры, скрытые детали корабля на кадр, вспышка разряда, прожектор.
func _warm_frame() -> void:
	if not warm.active():
		return
	var k := warm.outside()
	if k >= 0:   # кадр снаружи: камера с борта в точке облёта (и всплытия, #519) смотрит на корпус (облёт ещё ждёт)
		flyby_cam.transform = Warmup.outside_pose(k)
		if not flyby_cam.current:
			flyby_cam.make_current()
	else:
		camera.position = warm.eye()   # центр мостика или место у поста (#217)
		camera.rotation = Vector3(warm.pitch(), warm.yaw(), 0.0)
		if not camera.current:   # облёт с борта ждёт: прогрев смотрит глазами на мостике
			camera.make_current()
	for root: Node in [ship, ocean, silt_view, samples_view, vote_panel.get_parent(), wreck_view]:
		_warm_show(root)
	_warm_drawn = true


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


## Показать на кадр скрытые узлы под root (запомнить, чтобы вернуть).
func _warm_show(root: Node) -> void:
	for n in root.get_children(true):
		if (n is Node3D or n is CanvasItem) and not n.visible:
			n.visible = true
			_warm_shown.append(n)
		_warm_show(n)


## Начало шага: вернуть скрытым показанное прогревом; кадр прогрева показан — следующий взгляд.
func _warm_restore() -> void:
	for n in _warm_shown:
		if is_instance_valid(n):
			n.visible = false
	_warm_shown.clear()
	if not _warm_drawn:
		return
	_warm_drawn = false
	var done := warm.advance()
	if curtain:
		curtain.set_progress(warm.progress())
	if done:
		for m in _warm_mates:
			crew.erase(m)
		_warm_mates.clear()
		crew_view.as_own.clear()
		crew_view.set_members(crew, me)
		ghosts.clear()
		_ghosts(0.0, true)
		_warm_particles(false)
		curtain.queue_free()   # вместе с текстурой фона
		curtain = null
		_place_camera()


## Запустить сценарий тестера: из user://qa/scenario.json или из текста (тесты).
func start_qa(text: String = "") -> QaRunner:
	qa = QaRunner.new()
	qa.name = "Сценарий тестера"
	add_child(qa)
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
	_warm_restore()
	time += dt
	if qa:
		qa.tick(dt)
	if main_menu.open and not warm.active():   # главное меню: игра стоит, касания — кнопкам меню
		_tutorial_hide()
		_menu_step(dt)
		return
	if pause.open:   # пауза: игра стоит, касания — кнопкам паузы; меню сетевого забега — мир идёт без своего ввода
		var stop := pause.stops_world()
		_pause_step()
		if stop or main_menu.open:
			_tutorial_hide()
			return
		if settings.open:   # палец на ползунке настроек держится, но в игру не идёт
			overlay.router.mute()
		else:
			overlay.router.clear()   # палец на кнопке меню не идёт в игру: свой игрок стоит, за постом — без хода
	if _offer_step():   # предложение «Экономно»: касания — его кнопкам, свой игрок стоит, мир идёт
		overlay.router.clear()
	if net_client:   # клиент: корабль, реактор и экипаж — из кадров хоста
		_client_step(dt)
		clock.lap("гость", Time.get_ticks_usec())
		return
	_net_poll(dt)
	var r := overlay.router
	var wrecked := _wreck_step(dt)
	_mark_presses(r, dt)
	if r.noclip_pressed and not wrecked:
		toggle_noclip()
	var hold_valve := false
	var hold_winch := false
	var hold_weld := false
	var hold_scan := false
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
		hold_valve = post != null and post.id == "valve" and r.action_down
		hold_winch = post != null and post.id == "winch" and r.action_down
		hold_weld = post != null and post.id == "breach" and r.action_down
		at_scanner = post != null and post.id == "scanner"
		near_post = post.id if post else ""
		hold_scan = at_scanner and r.action_down
	var held := _mate_holds()   # товарищи держат кнопку у постов удержания — то же, что свой игрок
	_mate_posts(dt)
	layout.update(dt)
	airlock.update(dt)
	lock_water.update(dt, airlock.t, samples.hook_local(Samples.ship_xform(helm.pos, helm.yaw)), samples.carrying())
	var ship_xf := Samples.ship_xform(helm.pos, helm.yaw)
	if (hold_winch or held.has("winch") or debug_winch) and airlock.fully_open():
		samples.hold(Samples.lock_point(ship_xf), dt)
	samples.update(dt)
	samples_view.sync()
	save.tick(dt, samples, scanner)
	if hold_scan or held.has("scanner"):
		scanner.hold(dt)
	scanner.update(dt)
	if hold_weld or held.has("breach") or debug_weld:
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
			p.label = scanner.label()
		elif p.id == "route":
			p.label = run.label()
		elif p.id.begins_with("flask"):
			p.label = Lab.flask_label(samples.cargo, int(p.id.substr(5)))
	current.update(dt)
	var silt_msg := silt.update(dt, helm.pos, current.vel())
	if not silt_msg.is_empty():
		announce(silt_msg)
	silt_view.apply(silt, time, helm.pos, helm.yaw)
	var run_msg := run.update(helm.pos.x, helm.pos.z)
	if not run_msg.is_empty():
		announce(run_msg)
	expedition.visit(helm.pos.x, helm.pos.z)   # журнал ART-047: места и рекорд глубины
	expedition.dive_depth(helm.depth())
	reactor.update(dt, Reactor.near_vent(helm.pos.x, helm.pos.z))
	engine.update(dt, reactor, hold_valve or held.has("valve") or debug_vent)
	valve_steam.update(dt, engine.venting)
	helm.update(dt, reactor.k(Reactor.Sys.ENGINES), current.vel())
	hull_motion.update(dt, helm.in_thrust, helm.in_vert, reactor.k(Reactor.Sys.ENGINES))
	_wake(dt)
	helm.speed = vitals.scrape(helm.bump / maxf(dt, 1e-4), helm.speed)
	if vitals.update(dt, helm.in_thrust, helm.in_vert, Searchlight.lit(light_on, reactor.k(Reactor.Sys.LAMP)),
			0.0 if run.ended else reactor.k(Reactor.Sys.LIFE)):   # на итоге корпус не чинится — как на панели (#266)
		light_on = false
		overlay.set_light(false)
		say("Прожектор погас: не хватает энергии")
	vitals.hull = breach.update(dt, reactor.k(Reactor.Sys.LIFE), vitals.hull)
	breach_view.apply(dt)   # и частицы ART-072
	_drive_mates(dt)
	_tick_vote(dt)
	_hands(dt, hold_valve, hold_winch, hold_scan)
	_mate_hands(held)
	if (hold_weld or debug_weld) and breach.welding and breach.active:   # свой игрок варит: резак в руке, щиток опущен
		me.weld(breach.active.p, breach.active.n)
	else:
		me.weld(Vector3.INF)
	visor.visible = me.welding()
	breach.end_step()
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
	clock.lap("корабль", Time.get_ticks_usec())
	_step_eco(dt)
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
	rooms.set_lab(Lab.contents(samples.cargo), Lab.page_lines(samples, scanner, journal_page), time)
	rooms.set_shelves(HoldShelves.contents(samples.cargo))
	bridge.set_scanner_screen(scanner.screen_lines())
	message.update(dt)
	me.back = CrewView.own_back(walker.pitch, me.holding())   # взгляд вниз — фигура дальше позади глаза, видны ступни (#108)
	me.follow(walker.x, walker.z, walker.yaw, pilot.seated, helm.turn, dt)
	me.sync_post()
	crew_view.pitch = walker.pitch
	_apply_crew_view(dt)
	_place_ship()
	_place_camera()
	clock.lap("виды", Time.get_ticks_usec())
	route_card.show_card(brief.k, run.route, get_viewport().get_camera_3d(), sonar_view.to_global(Briefing.CARD_ANCHOR),
		comms.code)   # страница «Связь» — кодовое слово забега (ART-040)
	_update_ui()   # до меток: плашка строки уже на месте этого кадра (#387)
	_tutorial_step(dt)
	_card_step(dt)
	_comms_step(dt)
	_radio_step(dt)
	clock.lap("интерфейс", Time.get_ticks_usec())
	busy_marks.plate = status_rect()
	var busy := busy_marks.show_marks(crew, me, get_viewport().get_camera_3d(), camera)
	name_tags.show_tags(crew, me, crew_view, get_viewport().get_camera_3d(), camera, tag_blocks(), dt, busy,
			status_rect(), radio.voice())
	_ghosts(dt)
	_warm_frame()
	_net_send(dt)
	r.end_frame()
	clock.lap("метки и сеть", Time.get_ticks_usec())


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


## Руки своего игрока на посте (CrewHands): у пульта энергии, пока держит вентиль, лебёдку или сканер; после
## нажатия у голостола, рычага и щитка — ещё CrewHands.PRESS секунд.
func _hands(dt: float, valve: bool, winch: bool, scan: bool) -> void:
	press_t = maxf(press_t - dt, 0.0)
	if not CrewHands.pressing(press_t, press_at, Vector2(walker.x, walker.z)):
		press_t = 0.0   # отошёл от поста — руки не тянутся к нему через мостик, фигура не кланяется (#349)
	var g := CrewHands.none()
	if pilot.seated:
		pass
	elif at_power:
		g = CrewHands.energy(power.sel, reactor.share[power.sel] / float(Reactor.MAX))
	elif valve:
		g = CrewHands.valve()
	elif winch:
		g = CrewHands.winch(walker.x, walker.z)
	elif scan:
		g = CrewHands.scanner()
	elif press_t > 0.0:
		match press_post:
			"sonar", "route":
				g = CrewHands.table(walker.x, walker.z)
			"zap":
				g = CrewHands.lever(zap.lever_deg(time))
			"scram":
				g = CrewHands.scram()
	me.hold(g[0], g[1])


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
			elif run.done:
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
		if silt.jam_ping(time):
			msg = Silt.JAM_MSG
	if not msg.is_empty():
		tell.call(msg)


## Разряд по корпусу: живой мир узнаёт о нём в этот же шаг (ShipState.zap, zap_radius).
func fire_zap() -> void:
	var msg := zap.fire(time, reactor.k(Reactor.Sys.ZAP), vitals)
	if zap.fired_at(time):
		eco_ship.zap = true
		eco_ship.zap_radius = zap.radius
		if scorch.add(helm.pos, Seabed.height(helm.pos.x, helm.pos.z), reactor.k(Reactor.Sys.ZAP), time):
			ocean.set_scorch(scorch.uniforms(time))   # разряд у дна — след под корпусом
	say(msg)


## Шаг живого мира: корабль отдаёт своё состояние, получает события (EcoLink) и решает, что с ними делать.
func _step_eco(dt: float) -> void:
	var s := eco_ship
	s.pos = helm.pos
	s.yaw = helm.yaw
	s.speed = helm.speed
	s.light_on = Searchlight.lit(light_on, reactor.k(Reactor.Sys.LAMP))
	s.light_range = Searchlight.range_m(reactor.k(Reactor.Sys.LAMP)) * silt.beam_k() if s.light_on else 0.0
	s.hull_noise = engine.noise(clampf(absf(helm.speed) / 6.7, 0.0, 1.0))
	s.scan_range = Scanner.RANGE if at_scanner else 0.0
	s.dive = run.depth
	var xf := Samples.ship_xform(helm.pos, helm.yaw)
	s.claw = samples.hook_world(xf)
	s.claw_state = samples.state   # Samples.State совпадает с EcoLink.CLAW_*
	s.claw_target = samples.target.pos if samples.target else Vector3.ZERO
	s.claw_sample = samples.target.i if samples.target else -1
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
			vitals.hit(roundi(float(e.get("damage", 0.0)) * 100.0), str(e.get("by", "")))
		EcoLink.DRAIN:
			vitals.drain(str(e.get("by", "")), float(e.get("units", 0.0)))
		EcoLink.MESSAGE:
			say(str(e.get("text", "")))
		EcoLink.VOICE:   # голос во внутренней связи ART-040; просьбу не исполняем — решает игрок
			comms.push(int(e.get("role", Crew.Role.ENGINEER)), str(e.get("text", "")), bool(e.get("fake", false)),
				str(e.get("ask", "")), bool(e.get("silent", false)))
		EcoLink.DRAG:   # присоски на корпусе тормозят корабль (js/ship.js: drag = 0.45 + 0.025 * hullRemoras)
			helm.extra_drag = float(e.get("k", 0.0))
		EcoLink.STEAL:   # образец сорван с захвата (M.steal в js/manip.js)
			if samples.steal(int(e.get("sample", -1))):
				say("Образец украден: %s выхватил его из захвата и уносит в нору" % str(e.get("by", "Кто-то")))
		EcoLink.DROP:   # унесённый образец снова на дне (M.drop)
			samples.drop(int(e.get("sample", -1)), e.get("at", Vector3.ZERO))
		EcoLink.OBSERVE:   # наблюдение в журнал (handleEvents в js/game.js)
			var sp := str(e.get("species", ""))
			var fresh := scanner.observe(sp, str(e.get("note", "")))
			var text := str(e.get("text", ""))
			if text != "":
				say(text)
			elif fresh:
				say("Новое наблюдение: %s" % Species.called(sp, Species.Case.NOM, scanner.is_scanned(sp)))


func _on_hit(percent: int, kind: String) -> void:
	lock_water.on_hit()   # рябь в шахте шлюза вспыхивает (ART-073)
	if kind == "scrape":   # удар о дно поднимает ил
		silt.on_scrape(helm.pos, Seabed.height(helm.pos.x, helm.pos.z))
	if breach.on_hit(percent, vitals.hull):
		return   # о пробоине скажет Breach
	if kind == "scrape":
		say("Удар о дно: корпус −%d%%" % percent)
	elif kind.is_empty():
		say("Удар по корпусу: −%d%%" % percent)
	else:
		say("%s бьёт по корпусу: −%d%%" % [kind, percent])


## Главное меню ART-037 поверх сцены (после заставки прогрева — сразу под ней). Игра под меню стоит.
func open_menu() -> void:
	main_menu.open = true
	if menu_panel == null:
		menu_panel = MenuPanel.new()
		menu_panel.version = str(ProjectSettings.get_setting("application/config/version", "?"))
		add_child(menu_panel)
	menu_panel.show_menu(main_menu)
	overlay.visible = false
	if hint:
		hint.visible = false   # строки приборов не лезут к шапкам меню, сбора и журнала (#571)


## Шаг под меню: касания кнопок. «Погрузиться» — забег с начала (облёт, часы забега), палец с кнопки не идёт в игру.
func _menu_step(dt: float = 0.0) -> void:
	var r := overlay.router
	if settings.open:
		_settings_step(r)
		r.end_frame()
		return
	if address.open:
		_address_step(r, dt)
		r.end_frame()
		return
	if lobby.open:
		_lobby_step(r, dt)
		r.end_frame()
		return
	if logbook.open:
		_journal_step(r)
		r.end_frame()
		return
	for p in r.taps:
		var what := main_menu.press(main_menu.hit(p, get_viewport().get_visible_rect().size))
		if what == "dive":
			close_menu()
			_begin_run()
			break
		if what == "crew":
			open_lobby()
			break
		if what == "journal":
			open_journal()
			break
		if what == "settings":
			open_settings()
			break
	r.end_frame()


## Настройки ART-037 поверх главного меню (на его фоне) или паузы (над затемнённой сценой); «Назад» вернёт к ним.
func open_settings() -> void:
	settings.show()
	_settings_show()
	overlay.router.clear()   # палец с кнопки «Настройки» не берёт ползунок


func _settings_show() -> void:
	if settings_panel == null:
		settings_panel = SettingsPanel.new()
		add_child(settings_panel)
	settings.mic_ok = radio.mic   # статус микрофона на странице «Голос» ART-041
	settings_panel.show_settings(settings)
	if menu_panel:   # над главным меню — его фон без кнопок
		menu_panel.visible = main_menu.open and not address.open
		menu_panel.draw.visible = not settings.open
	if pause_panel:
		pause_panel.visible = pause.open and not settings.open and not ship_map.open


## Шаг настроек: касания кнопок, палец на ползунке двигает значение; изменения — сразу в игру и в файл
## (ползунок — когда палец отпущен).
func _settings_step(r: Touch.Router) -> void:
	var size := get_viewport().get_visible_rect().size
	for p in r.taps:
		var id := settings.hit(p, size)
		var what := settings.press(id, p, size)
		if id in ["volume", "swipe", "mates"]:
			_apply_settings()
			continue
		_settings_do(what)
		if what == "back":
			break
	if settings.grab != "":
		var pts := r.points()
		if pts.is_empty():
			settings.grab = ""
			settings.write()
		elif settings.drag(pts[0], size):
			_apply_settings()
	_settings_show()


## Что сказали настройки: сохранить и применить, стереть сохранение забега, вернуться.
func _settings_do(what: String) -> void:
	match what:
		"changed":
			_apply_settings()
			settings.write()
		"graphics":
			_apply_settings()
			settings.write()
		"wipe":
			save.reset(samples, scanner)
			say("Сохранение сброшено")
		"back":
			settings.write()
			_settings_show()
			overlay.router.clear()   # палец с «Назад» не нажимает кнопку меню под ним


## Громкость шины Master, чувствительность свайпа, уровень графики ART-044; облёт читает `_begin_run`.
func _apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, Settings.volume_db(settings.volume))
	if overlay:
		overlay.swipe = settings.swipe
	if graphics_level != settings.graphics:
		_apply_graphics(settings.graphics)
	if fps_view:
		fps_view.visible = settings.fps
	radio.mode = settings.voice_mode   # страница «Голос» ART-041: режим, приём и микрофон — независимо
	radio.hear = settings.hear
	radio.mic_on = settings.mic_on
	radio.volume = settings.mates


## Предложение «Экономно» ART-044: открыть после низких кадр/с, когда ничего не мешает (не на «Экономно», не под
## тревогой, меню, паузой, настройками, облётом, голосованием, шторками; тестер — только шагом `slow`); касания —
## «Да» / «Нет». true — диалог открыт (ввод этого кадра в игру не идёт).
func _offer_step() -> bool:
	var blocked := not offer or qa != null or alarms_on().has(true) or main_menu.open or pause.open \
		or settings.open or warm.active() or flyby.active() or wreck.active() or at_vote or run.ended \
		or (net_client != null and drop.active())
	lite_offer.update(graphics_level, settings.lite_no, blocked)
	if lite_offer.open:
		var size := get_viewport().get_visible_rect().size
		for p in overlay.router.taps:
			var what := lite_offer.press(lite_offer.hit(p, size))
			if what != "":
				_offer_do(what)
				break
	if lite_offer_panel:
		lite_offer_panel.show_offer(lite_offer)
	return lite_offer.open


## Ответ на предложение: «Да» — «Экономно» сразу и в настройки, «Нет» — больше не предлагать.
func _offer_do(what: String) -> void:
	match what:
		"yes":
			settings.graphics = Graphics.ECONOMY
			_apply_settings()
			say("Графика: «Экономно»")
		"no":
			settings.lite_no = true
		_:
			return
	settings.write()
	if lite_offer_panel:
		lite_offer_panel.show_offer(lite_offer)
	overlay.router.clear()   # палец с кнопки не идёт в игру


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
		ocean.set_snow_lite(lite)     # взвесь ART-058 реже, без вращения
		ocean.set_decals_lite(lite)   # декали дна ART-066 реже и ближе
		ocean.set_layers_level(g["layers"])   # слои воды ART-069: 0 / 0,6 / 0,9
		ocean.set_shadows(g["shadows"])
	if hull:
		hull.set_relief(not lite)     # обшивка ART-053
	if bridge:
		bridge.set_relief(not lite)   # мостик ART-054
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
		grade.set_lite(lite)          # виньетка ART-065: без LUT, овал 0,10
	glints.lite = lite                # блики воды в мостике ART-067 выключены
	if eco:
		eco.set_lite(lite)            # живой мир: флора не колышется, ободка тел нет (EcoView.set_lite, #598)
	var vp := get_viewport()
	if vp:
		vp.msaa_3d = {0: Viewport.MSAA_DISABLED, 2: Viewport.MSAA_2X, 4: Viewport.MSAA_4X}.get(int(g["msaa"]),
			Viewport.MSAA_2X)
		vp.scaling_3d_scale = g["scale"]


## «Журнал экспедиции» ART-047 поверх главного меню: история `expedition`, изученные виды, груз трюма.
func open_journal() -> void:
	logbook.show()
	_journal_show()
	overlay.router.clear()


func _journal_show() -> void:
	if logbook_panel == null:
		logbook_panel = JournalPanel.new()
		add_child(logbook_panel)
	logbook.blank = Journal.empty(expedition, scanner.scanned.size(), samples.cargo.size())
	logbook_panel.show_journal(logbook, expedition, scanner, Species.count(), samples.cargo.size(),
		save.state == SaveGame.Load.BROKEN)
	if menu_panel:
		menu_panel.visible = main_menu.open and not logbook.open and not address.open


## Шаг журнала: касание места — название под картой, вида — карточка или подсказка, «Ранее» / «Далее», «Назад» — в меню.
func _journal_step(r: Touch.Router) -> void:
	for p in r.taps:
		var did := logbook.press(logbook.hit(p, get_viewport().get_visible_rect().size), scanner.scanned, expedition)
		if did in ["card", "back"]:   # карточка открыта/закрыта, журнал закрыт: палец не нажмёт то, что под ним
			overlay.router.clear()
			break
	if not logbook.open:   # прочитанные карточки («новое» снято) — в файл, пока меню стоит
		save.flush(samples, scanner)
	_journal_show()


## Сбор экипажа ART-028 по «Экипаж»: вход — поиск забегов в сети (`finder`), «Создать забег», «По адресу».
func open_lobby(why := "") -> void:
	lobby.show_entry(why)
	if finder.udp == null:
		finder.start()   # порт занят — список пуст, «Никого нет»; «По адресу» работает
	else:
		finder.search()
	_lobby_runs()
	_lobby_show()
	overlay.router.clear()   # палец с кнопки «Экипаж» не нажмёт кнопку входа под ним


func _lobby_show() -> void:
	if lobby_panel == null:
		lobby_panel = LobbyPanel.new()
		add_child(lobby_panel)
	lobby_panel.show_lobby(lobby)
	lobby_panel.visible = lobby.open and not address.open   # «По адресу» — экран адреса поверх входа
	if menu_panel:
		menu_panel.visible = main_menu.open and not lobby.open and not address.open


## Шаг сбора экипажа: касания кнопок; у хоста — гости в комнату (`LobbyLink.serve`), у гостя — снимок хоста
## (`LobbyLink.take`); «Начать погружение» — забег у всех с ролями из комнаты.
func _lobby_step(r: Touch.Router, dt: float) -> void:
	var size := get_viewport().get_visible_rect().size
	for p in r.taps:
		var id := lobby.hit(p, size)
		if id == "":
			continue
		if lobby.entry:
			match lobby.press(id):
				"create":
					finder.stop()
					_lobby_create()
				"address":
					open_address()
				"refresh":
					finder.search()
					_lobby_runs()
				"join":
					_lobby_join_start()
			overlay.router.clear()
			_lobby_show()
			return
		var q := ""
		if net_host:
			q = LobbyLink.host_press(lobby, net_host, id)
		elif lobby_client:
			q = LobbyLink.guest_press(lobby, lobby_client, id)
		if q == "back":
			_lobby_back(true)
			return
		if q == "retry" and lobby_client and lobby_client.rejoin(NetLink.TIMEOUT) != OK:
			lobby.retry_failed("timeout")
	if lobby.entry:
		finder.poll(dt)
		_lobby_runs()
		if lobby_join:
			_lobby_join_step(dt)
	elif net_host:
		beacon.step(dt, lobby, lobby_port)
		LobbyLink.serve(lobby, net_host, net_host.poll(dt))
		if lobby.started:
			_lobby_start_host()
			return
	elif lobby_client:
		lobby_client.poll(dt)
		if lobby.lost:   # карточка «Связь потеряна»: ждём ответа на «Повторить»
			if lobby.retrying:
				match lobby_client.state:
					NetLink.State.JOINED:
						lobby.rejoined()
						LobbyLink.take(lobby, lobby_client)
					NetLink.State.REFUSED, NetLink.State.LOST, NetLink.State.OFF:
						lobby.retry_failed(lobby_client.why)
		else:
			LobbyLink.take(lobby, lobby_client)
			if lobby.started and lobby_client.joined():
				_lobby_start_guest()
				return
			if not lobby_client.joined():   # хост закрыл забег или связь пропала — «Повторить» / «К списку забегов»
				lobby.lose()
	_lobby_show()


## Список найденных забегов — на экран входа (строку подключения держит, пока идёт попытка).
func _lobby_runs() -> void:
	if lobby_join == null:
		lobby.runs = finder.runs.duplicate()
	lobby.searching = not finder.done()


## «Подключиться» в строке забега: вход к хосту по адресу и порту из маяка.
func _lobby_join_start() -> void:
	var run: RunBeacon.Found = lobby.runs[lobby.joining]
	lobby_join = NetLink.Client.new()
	if lobby_join.join(run.address, run.port) != OK:
		_lobby_join_end("timeout")


## Ответ хоста на подключение из списка: принят — в его комнату, отказ или тишина — причина вместо заголовка.
func _lobby_join_step(dt: float) -> void:
	lobby_join.poll(dt)
	match lobby_join.state:
		NetLink.State.JOINED:
			var c := lobby_join
			lobby_join = null
			finder.stop()
			lobby_client = c
			lobby.guest()
			LobbyLink.take(lobby, c)
		NetLink.State.REFUSED, NetLink.State.LOST, NetLink.State.OFF:
			_lobby_join_end(lobby_join.why if lobby_join.why != "" else "timeout")


## Попытка из списка кончилась ничем (why — ключ `NetLink.WHY`; "" — отменена); список снова живой.
func _lobby_join_end(why: String) -> void:
	if lobby_join:
		lobby_join.stop()
		lobby_join = null
	lobby.joining = -1
	lobby.why = why
	_lobby_runs()


## «Создать забег»: открыть хост и комнату, где хост — первый игрок со своим адресом (ART-039).
func _lobby_create() -> void:
	net_host = NetLink.Host.new()
	if net_host.start(lobby_port) != OK:
		net_host = null
		open_lobby("port")
		return
	lobby.host("", Lobby.local_address())
	lobby.open = true
	beacon.start()   # нет сети — маяка нет, вход по адресу работает
	_lobby_show()


## Выйти из комнаты: хост закрывает забег (у гостей — «Связь с хостом потеряна»), гость уходит; со входа — в меню.
## pressed — «Назад» уже нажата (комната закрыта), иначе — системная «Назад».
func _lobby_back(pressed := false) -> void:
	if lobby_join and not pressed:   # «Назад» во время подключения из списка — отменить попытку, остаться в поиске
		_lobby_join_end("")
		_lobby_show()
		return
	var in_room := not lobby.entry
	if not in_room:
		finder.stop()
	if not pressed:
		lobby.back()
	beacon.stop()
	if net_host:
		net_host.stop()
		net_host = null
	if lobby_client:
		lobby_client.stop()
		lobby_client = null
	if in_room:
		open_lobby()
		return
	_lobby_show()
	if menu_panel:
		menu_panel.show_menu(main_menu)


## Хост: «Начать погружение» принято — роли гостей из комнаты (`LobbyLink.seat`), свой — тоже, гости на палубе,
## забег с начала. Снимок со стартом уже ушёл всем (`LobbyLink.host_press`).
func _lobby_start_host() -> void:
	beacon.stop()   # забег начался — в списках гостей он больше не нужен
	LobbyLink.seat(lobby, net_host)
	var mine := lobby.mine()
	if mine and mine.role >= 0:
		me.role = mine.role
		me.name = mine.name
	close_menu()
	for g: NetLink.Guest in net_host.guests.values():
		var p := lobby.find(g.id)
		var m := _seat_guest(g)
		if p:
			m.name = p.name   # имя как в комнате («Игрок 3», если телефон не назвался)
	crew_view.set_members(crew, me)
	_net_index()
	_begin_run()


## Гость: старт у хоста — дальше кадры хоста (`_enter_client`); облёта у гостя нет.
func _lobby_start_guest() -> void:
	var c := lobby_client
	lobby_client = null
	close_menu()
	c.quiet = 0.0   # в комнате кадров не было — «Нет связи» не мигнёт до первого кадра
	_enter_client(c)


## Экран «Войти по адресу» ART-039 поверх входа сбора экипажа ART-028 («По адресу»).
func open_address() -> void:
	address.show()
	if address_panel == null:
		address_panel = AddressPanel.new()
		add_child(address_panel)
	address_panel.show_screen(address)
	if menu_panel:
		menu_panel.visible = false
	if lobby_panel:
		lobby_panel.visible = false


## Шаг экрана адреса: клавиши, «Войти» / «Отмена», «Назад»; попытка входа ждёт ответа хоста здесь, под экраном.
## На борту — экран и меню закрыты, дальше — шаг клиента (`_enter_client`).
func _address_step(r: Touch.Router, dt: float) -> void:
	for p in r.taps:
		_address_do(address.press(address.hit(p, get_viewport().get_visible_rect().size)))
	if address_client:
		address_client.poll(dt)
		if address.result(address_client.state, address_client.why):   # хост принял — в его комнату (ART-028)
			var c := address_client
			address_client = null
			address.open = false
			address_panel.show_screen(address)
			lobby_client = c
			finder.stop()
			lobby.guest()
			LobbyLink.take(lobby, c)
			_lobby_show()
			return
		if not address.field.connecting:
			address_client = null
	if address_panel:
		address_panel.show_screen(address)


## Что сказал экран адреса: подключаться, бросить попытку или вернуться в меню.
func _address_do(what: String) -> void:
	match what:
		"join":
			address_client = NetLink.Client.new()
			if address_client.join(address.field.text) != OK:
				address_client = null
				address.failed()
		"cancel", "back":
			if address_client:
				address_client.stop()
				address_client = null
			if what == "back":
				if address_panel:
					address_panel.show_screen(address)
				if lobby.open:   # назад — ко входу сбора экипажа
					_lobby_show()
				elif menu_panel:
					menu_panel.show_menu(main_menu)


## Системная «Назад» (Esc на ПК): в забеге — пауза ART-037, в паузе закрывает сначала подтверждение, потом паузу;
## в главном меню — выход из игры. В сетевом забеге — «Меню забега» (мир идёт); под шторкой «Корпус разрушен» и
## диалогом обрыва связи ART-043 — без паузы.
func back_pressed() -> void:
	if warm.active():
		return
	if ship_map.open:   # схема корабля — назад туда, откуда открыли (пауза)
		_map_back()
		return
	if settings.open:   # настройки: сначала подтверждение сброса, потом — назад к меню или паузе
		_settings_do(settings.back())
		_settings_show()
		return
	if main_menu.open and logbook.open:
		logbook.back()
		if not logbook.open:
			save.flush(samples, scanner)
		_journal_show()
		return
	if main_menu.open and address.open:   # экран адреса: сначала отмена попытки, потом вход сбора
		_address_do(address.back())
		if address_panel:
			address_panel.show_screen(address)
		return
	if main_menu.open and lobby.open:   # комната — ко входу, вход — в меню (ART-028)
		_lobby_back()
		return
	if main_menu.open:
		save.flush(samples, scanner)
		get_tree().quit()
		return
	if lite_offer.open:   # «Назад» над предложением «Экономно» — как «Нет»
		_offer_do(lite_offer.back())
		return
	if not pause.open:
		if wreck.active() or (net_client != null and drop.blocks()):
			return
		pause.set_mode("host" if net_host != null else ("guest" if net_client != null else "solo"))
	pause.back()
	_pause_show()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_ESCAPE:
		back_pressed()


func _pause_show() -> void:
	if pause_panel == null:
		pause_panel = PausePanel.new()
		add_child(pause_panel)
	if not pause.open and ship_map.open:   # пауза закрылась (шторка, обрыв связи) — схема с ней
		ship_map.close()
	pause_panel.show_pause(pause)
	if ship_map.open:
		pause_panel.visible = false
	_map_show()
	overlay.visible = not pause.open and not wreck.active()
	hint.visible = not pause.open and not wreck.active()   # строки приборов не лезут к заголовку паузы
	overlay.router.clear()   # палец, открывший или закрывший паузу, не идёт в игру


## Шаг под паузой: касания кнопок. «Новый забег» — с начала спуска, «Выйти в меню» — главное меню ART-037.
## Меню сетевого забега: хост — новый забег у всех или конец забега (гости теряют хоста), гость — «Покинуть экипаж».
## Шторка «Корпус разрушен», обрыв связи или конец сети закрывают меню забега.
func _pause_step() -> void:
	var r := overlay.router
	if not pause.stops_world() and (wreck.active() or (net_client != null and drop.blocks())
			or (net_host == null and net_client == null)):
		pause.close()
		settings.close()
		_settings_show()
		_pause_show()
		return
	if ship_map.open:
		_map_step(r)
		r.end_frame()
		return
	if settings.open:
		_settings_step(r)
		r.end_frame()
		return
	for p in r.taps:
		var what := pause.press(pause.hit(p, get_viewport().get_visible_rect().size))
		if what != "":
			_pause_show()
			match what:
				"new":
					_leave_posts()
					_restart()
					if net_host:
						announce("Хост начал новый забег: Ковчег у начала спуска")
					else:
						say("Новый забег: Ковчег у начала спуска")
				"exit":
					if net_host:
						_stop_host()
					_to_menu()
				"leave":
					_leave_net()
					_to_menu()
				"settings":
					open_settings()
				"map":
					open_map("pause")
			break
		pause_panel.show_pause(pause)
	r.end_frame()


## Схема корабля ART-042 поверх паузы / меню забега: кнопки паузы скрыты, касания — «Назад».
func open_map(where: String) -> void:
	ship_map.open_from(where)
	if pause_panel:
		pause_panel.visible = false
	_map_show()
	overlay.router.clear()   # палец с пункта «Схема корабля» не жмёт «Назад»


## Кнопка «Схема» на подсказке первого забега: схема поверх паузы (одиночный забег стоит, в коопе мир идёт —
## «Меню забега»), «Назад» — сразу к подсказке.
func open_hint_map() -> void:
	pause.set_mode("host" if net_host != null else ("guest" if net_client != null else "solo"))
	if not pause.open:
		pause.back()
	_pause_show()
	open_map("hint")


## «Назад» схемы: обратно в паузу; открыли с подсказки — к подсказке, пауза закрывается.
func _map_back() -> void:
	if ship_map.back() == "hint":
		_map_show()
		pause.close()
		_pause_show()
		return
	_map_show()
	if pause_panel:
		pause_panel.show_pause(pause)
	overlay.router.clear()


## Шаг открытой схемы: касание «Назад»; в коопе мир идёт — отметки товарищей перерисовываются каждый шаг.
func _map_step(r: Touch.Router) -> void:
	for p in r.taps:
		if ship_map.hit(p, get_viewport().get_visible_rect().size) == "back":
			_map_back()
			return
	_map_show()


## Данные схемы: отметки экипажа (свой — me), люки, тревога по главному полю табло.
func _map_show() -> void:
	if ship_map_panel == null:
		if not ship_map.open:
			return
		ship_map_panel = ShipMapPanel.new()
		add_child(ship_map_panel)
	var marks: Array = []
	for m: Crew.Member in crew:
		marks.append([m.x, m.z, ShipMap.letter(m.role)])
	var doors: Array[bool] = []
	for d in layout.doors:
		doors.append(d.passable())
	var a := ShipMap.alarm(AlarmBoard.main_field(alarms_on()), breach.active)
	ship_map_panel.show_map(ship_map, marks, crew.find(me), doors, a)


## Забег окончен, в главное меню: встать с постов, корабль у начала спуска, без облёта.
func _to_menu() -> void:
	_leave_posts()
	_restart()
	flyby.stop()
	open_menu()


## Хост закрывает сетевой забег: гости отключены (у них — диалог обрыва связи), их фигуры и тени убраны.
func _stop_host() -> void:
	net_host.stop()
	net_host = null
	for id: int in net_mates:
		crew.erase(net_mates[id])
	net_mates.clear()
	ghosts.clear()
	_ghosts(0.0, true)
	crew_view.set_members(crew, me)


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
	main_menu.open = false
	address.open = false
	lobby.open = false
	if lobby_panel:
		lobby_panel.show_lobby(lobby)
	logbook.open = false
	if logbook_panel:
		_journal_show()
	if menu_panel:
		menu_panel.show_menu(main_menu)
	if address_panel:
		address_panel.show_screen(address)
	overlay.router.clear()   # палец ещё на кнопке: не крестовина и не касание, пропускающее облёт
	overlay.visible = not wreck.active()
	hint.visible = not wreck.active() and not pause.open


## Корпус разрушен: забег проигран — шторка ART-036 3,5 с (`Wreck`), под сплошной шторкой подъём к старту с целым
## корпусом (`_wreck_step` → `_restart`). Ввод на это время не идёт в игру.
func _on_destroyed() -> void:
	if wreck.active():
		return
	_leave_posts()
	pause.close()
	if ship_map.open:
		ship_map.close()
		_map_show()
	if settings.open:
		settings.close()
		_settings_show()
	if pause_panel:
		pause_panel.show_pause(pause)
	wreck.start()
	_wreck_show()


## Шаг шторки «Корпус разрушен»: сплошная — забег с начала. true — шторка идёт (ввод не идёт в игру).
func _wreck_step(dt: float) -> bool:
	if not wreck.active():
		return false
	if wreck.update(dt):
		expedition.end_run()
		_restart()
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


## Корабль у начала спуска, целый и заряженный, забег с нуля (корпус разрушен или новый забег после итога).
func _restart() -> void:
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
	_begin_run()


func _begin_run() -> void:
	run.begin(time, samples.cargo.size(), scanner.scanned.size(), breach.count)
	if intro and settings.intro:
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
		announce(run.go_deeper())   # гостям — тоже
		return
	var rows := run.finish(time, samples.cargo.size(), scanner.scanned.size(), breach.count, vitals.hull)
	expedition.end_run()
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


## Подсказки первого забега ART-038: скрыты под тревогой, голосованием, итогом, облётом, шторкой, паузой и меню
## (шаг стоит); у гостя сети — свои шаги без сонара (`Tutorial.Guest`). Пройдено — запомнить в настройках.
func _tutorial_step(dt: float) -> void:
	var hidden := alarms_on().has(true) or at_vote or run.ended or pause.open \
		or main_menu.open or settings.open or flyby.active() or warm.active() or wreck.active() or walker.noclip
	if tutorial.update(dt, hidden):
		settings.hints_done = true
		settings.write()
	var near := near_post
	var target := tutorial.pointer_target(pilot.seated) if tutorial.shown() else ""
	var edge := hint_pointer.show_pointer(target, near == target or (at_power and target == "energy"), tutorial.a, dt,
		get_viewport().get_camera_3d(), camera)
	tutorial_panel.show_tutorial(tutorial, tutorial.text(pilot.seated, near),
		tutorial.highlight(pilot.seated, at_power, near), status_rect(),
		power_panel.box() if power_panel.visible else Rect2(), edge,
		not hidden and tutorial.map_wanted(target, near, at_power))
	var m := tutorial_panel.map_rect()
	for p in overlay.router.taps:
		if m.has_point(p):
			open_hint_map()
			return


## Карточка роли у поста ART-045: пост, у которого стоит свой игрок, своей ли он роли (в одиночном забеге — все
## свои), что её скрывает; касания карточки и «?» — из `Router.taps`, взгляд под ними не крутится (`Router.blocks`).
func _card_step(dt: float) -> void:
	var at := RoleCard.post_at(pilot.seated, at_power, near_post)
	var solo := net_client == null and net_mates.is_empty()
	var hidden := alarms_on().has(true) or at_vote or at_power or run.ended or pause.open or main_menu.open or settings.open \
		or flyby.active() or warm.active() or wreck.active() or walker.noclip or brief.k > 0.0 \
		or (net_client != null and drop.active())
	var quiet := tutorial.active() or (at != "" and Crew.holder(crew, me, at) != null)
	var changed := role_card.update(dt, at, RoleCard.is_own(at, me.role, solo), hidden, quiet)
	var size := get_viewport().get_visible_rect().size
	role_card.status = status_rect()
	var avoid: Array = []
	if power_panel.visible:
		avoid.append(power_panel.box())
	if route_card.visible:
		avoid.append(route_card.rect)
	var rect := RoleCard.card_rect(role_card.post, size, avoid, status_rect()) if role_card.open else Rect2()
	if role_card.open and not rect.has_area():   # места нет — сразу «?»
		changed = role_card.fold() or changed
	if not hidden:
		var before := role_card.read.size()
		for p in overlay.router.taps:
			if role_card.tap(p, size, rect) == "ask":   # «?» — карточка снова на своём месте
				rect = RoleCard.card_rect(role_card.post, size, avoid, status_rect())
		changed = changed or role_card.read.size() != before
	overlay.router.blocks = role_card.blocks(size, rect)
	if tutorial_panel.map_rect().has_area():   # кнопка «Схема» на подсказке: палец там не крутит взгляд
		overlay.router.blocks.append(tutorial_panel.map_rect())
	if changed:
		settings.cards = role_card.read_list()
		settings.write()
	role_card_panel.show_card(role_card, rect if rect.has_area() else role_card_panel.rect)


## Внутренняя связь ART-040: при голосовании, итоге, меню, паузе, брифинге (и шторках) — отложена, часы стоят;
## «Спросить код» / «Понятно» — из `Router.taps`, кнопка не крутит взгляд (`Router.blocks`, после карточки роли).
## Где раскладывать плашку связи: безопасная область крестовины и кнопок (`Touch.Layout.area`), пока её нет — экран.
func comms_area() -> Rect2:
	var area := overlay.router.layout.area
	return area if area.has_area() else get_viewport().get_visible_rect()


func _comms_step(dt: float) -> void:
	var hidden := _overlay_hidden()
	comms.solo = net_client == null and net_mates.is_empty()
	comms.follow = net_client != null   # гость: плашка и проверка — по кадру хоста (`Comms.apply`)
	var size := get_viewport().get_visible_rect().size
	if net_client == null:
		for m: Crew.Member in crew:   # «Спросить код» / «Понятно» гостя — его сообщению (`Crew.Pad.ask`)
			if m != me and m.pad.ask > 0:
				comms.press(m.pad.ask)
				m.pad.ask = 0
	comms.update(dt, hidden)
	var area := comms_area()   # плашка в безопасной области, как крестовина: вырез не сдвигает её на крестовину (#603)
	if not hidden:
		for p in overlay.router.taps:
			comms.tap(p - area.position, area.size)
	if comms.asked > 0:   # гость: нажатие уходит хосту со следующим вводом
		net_pad.ask = comms.asked
		comms.asked = 0
	for r in comms.blocks(area.size):
		overlay.router.blocks.append(Rect2(r.position + area.position, r.size))
	comms_panel.show_comms(comms, time, area)


## Плашки поверх игры (связь ART-040, рация ART-041) не показываются: голосование, итог, меню, пауза, брифинг, шторки.
func _overlay_hidden() -> bool:
	return at_vote or run.ended or pause.open or main_menu.open or settings.open or ship_map.open \
		or brief.k > 0.0 or flyby.active() or warm.active() or wreck.active() or (net_client != null and drop.active())


## Рация ART-041 в коопе: «Нажать и держать» — палец на кнопке (`Router.held_in`), меню и пауза обрывают передачу;
## кнопка не крутит взгляд (`Router.blocks`). Голоса пока нет (решение владельца) — `Radio.enabled` выключено.
func _radio_step(dt: float) -> void:
	if radio.pinned:
		radio_panel.show_radio(radio, time)
		return
	radio.on = Radio.enabled and (net_client != null or not net_mates.is_empty())
	var size := get_viewport().get_visible_rect().size
	radio.update(dt, overlay.router.held_in(Radio.button_rect(size)), _overlay_hidden())
	_radio_sight()
	for p in overlay.router.taps:
		radio.tap(p, size)
	radio.settings_wanted = false   # запрос разрешения микрофона Android — вместе с голосом
	overlay.router.blocks.append_array(radio.blocks(size))
	radio_panel.show_radio(radio, time)


## Говорящий товарищ в поле зрения или за стеной (ART-041): за закрытым люком — строка «Вне поля зрения», табличка
## над ним без «активности» (`ShipLayout.in_sight`).
func _radio_sight() -> void:
	for t in radio.talkers:
		if t.id >= 0 and t.id < crew.size():
			t.seen = ShipLayout.in_sight(me.z, (crew[t.id] as Crew.Member).z, layout.doors)


func _tutorial_hide() -> void:
	tutorial.a = 0.0
	comms.a = 0.0   # плашка связи ART-040 под меню и паузой не висит: после — снова по `_comms_step`
	if comms_panel != null and comms_panel.visible:
		comms_panel.visible = false
	radio.update(0.0, false, true)   # рация ART-041: меню и пауза обрывают передачу сразу
	if radio_panel != null and radio_panel.visible:
		radio_panel.visible = false
	role_card.a = 0.0   # и карточка роли ART-045 (меню, пауза): после — снова по `_card_step`
	role_card.q = 0.0
	role_card.f = 0.0
	if role_card_panel != null and role_card_panel.visible:
		role_card_panel.visible = false
	if overlay != null:
		overlay.router.blocks.clear()
	if hint_pointer != null:
		hint_pointer.show_pointer("", false, 0.0, 0.0, null, null)
	if tutorial_panel != null and tutorial_panel.visible:
		tutorial_panel.visible = false


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
	hint.text = "\n".join(Status.lines(status_parts(),
		func(t: String) -> float: return font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, width))
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
	if not run.done or run.ended:
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


## Товарищ на посту правит кораблём своим вводом (`Member.pad`, гость по сети — тоже): за штурвалом — ход, руль,
## «Всплыть/Вниз» и «Свет», у пульта энергии — доли реактора. Пост держит один человек (Crew.BUSY): свой ввод
## тогда штурвал не трогает.
func _mate_posts(dt: float) -> void:
	for m: Crew.Member in crew:
		if m == me:
			continue
		var mv := Vector2i(roundi(m.pad.move.x), roundi(m.pad.move.y))   # крестовина 8 направлений, как у своего
		if m.seated and not pilot.seated:
			helm.in_thrust = mv.y
			helm.in_turn = mv.x
			helm.in_vert = m.pad.vert
			m.wheel_turn = helm.turn
			if m.pad.light:
				toggle_light()
		elif m.at_power and not at_power:
			power.nav(reactor, mv, dt)
		m.pad.light = false


## Посты, у которых товарищ держит кнопку действия (`Pad.hold`): сварка пробоины, вентиль, лебёдка, сканер —
## {пост: товарищ}. Занятый постом (штурвал, пульт, голосование) не держит. Товарищ у сканера — мир шлёт цели
## (`at_scanner`), как своему игроку.
const MATE_HOLDS := ["breach", "valve", "winch", "scanner"]

func _mate_holds() -> Dictionary:
	var out := {}
	for m: Crew.Member in crew:
		if m == me or m.busy():
			continue
		var post := Deck.nearest(posts, m.walker.x, m.walker.z)
		if post == null or post.id not in MATE_HOLDS:
			continue
		if post.id == "scanner":
			at_scanner = true
		if m.pad.hold and not out.has(post.id):
			out[post.id] = m
	return out


## Поза товарищей, которые держат пост (`_mate_holds`): резак у шва и щиток, руки на вентиле, лебёдке, сканере.
func _mate_hands(held: Dictionary) -> void:
	for m: Crew.Member in crew:
		if m == me:
			continue
		if held.get("breach") == m and breach.active:
			m.weld(breach.active.p, breach.active.n)
		else:
			m.weld(Vector3.INF)
		var g := CrewHands.none()
		if held.get("valve") == m:
			g = CrewHands.valve()
		elif held.get("winch") == m:
			g = CrewHands.winch(m.walker.x, m.walker.z)
		elif held.get("scanner") == m:
			g = CrewHands.scanner()
		m.hold(g[0], g[1])


func _drive_mates(dt: float) -> void:
	for m: Crew.Member in crew:
		if m != me:
			if m.pad.action:
				m.pad.action = false
				mate_action(m)
			if m.at_vote and run.done and not run.ended:   # голос своей крестовиной
				var c := ballot.nav(m.get_instance_id(), m.pad.move, true)
				if c != "":
					ballot.cast(m.get_instance_id(), m.role, c)
			m.drive(dt, breach.slow(ShipLayout.room_at(m.walker.z)))


## Кто нажал кнопку в этом кадре (действие или «Свет»; свой — с экрана, товарищ — `Pad`): табличка над ним
## «нажимает» (ART-033, `Member.pressed`). До того, как шаг съест нажатия.
func _mark_presses(r: Touch.Router, dt: float) -> void:
	for m: Crew.Member in crew:
		m.tick_press(dt)
		if (r.action_pressed or r.light_pressed) if m == me else (m.pad.action or m.pad.light):
			m.pressed()


## Кнопка действия товарища (`Pad.action`): занятый постом встаёт; стоящий у штурвала садится, у пульта энергии
## встаёт к ползункам, у голостола после маршрута — к голосованию. Пост, который держит другой, не берёт.
## Возвращает пост, за который встал или сел ("" — встал с поста или рядом нечего взять).
func mate_action(m: Crew.Member) -> String:
	if m.busy():
		if m.seated:
			m.stand()
		m.at_power = false
		m.at_vote = false
		m.sync_post()
		return ""
	var post := Deck.nearest(posts, m.walker.x, m.walker.z)
	if post == null or Crew.holder(crew, m, post.id):
		return ""
	m.pad.move = Vector2.ZERO   # крестовина, которой шёл к посту, не ведёт корабль (гость пришлёт новую)
	m.pad.left = INF
	match post.id:
		"helm":
			m.sit()
		"energy":
			m.at_power = true
			m.walker.x = POWER_STAND.x
			m.walker.z = POWER_STAND.y
			m.walker.yaw = PI / 2.0
			m.place(m.walker.x, m.walker.z, m.walker.yaw)
		"route":
			if not run.done:   # маршрут не пройден: кнопка у поста «Маршрут» листает маршруты — у всех
				announce(run.cycle())
				return ""
			m.at_vote = true
		"sonar":   # импульс хоста — голограмма и отметки у всех (у гостя — по кадру, NetSnap.sonar)
			ping_sonar(true)
			return ""
		_:
			return ""
	m.sync_post()
	return post.id


## Открыть сетевой забег хостом (NetLink): телефоны по локальной сети встают членами экипажа, их ввод — `Member.pad`.
func host_game(port: int = NetLink.PORT) -> Error:
	if main_menu.open:
		close_menu()
	net_host = NetLink.Host.new()
	var err := net_host.start(port)
	if err != OK:
		net_host = null
	return err


## Гости хоста: пришёл — член экипажа своей роли и внешности с вводом гостя, ушёл — убрать с палубы.
func _net_poll(dt: float = 0.0) -> void:
	if notice.active():
		notice.update(dt)
		drop_panel.show_notice(notice)
	if net_host == null:
		return
	var changed := false
	for e: Dictionary in net_host.poll(dt):
		var g: NetLink.Guest = e["guest"]
		if e["k"] == "join":
			var m := _seat_guest(g)
			if MateGhost.forget(ghosts, m.name):   # вернулся — прежняя фигура уходит, встаёт новая
				_ghosts(0.0, true)
			if not notice.joined(m.name, m.look == 1):
				say("На борту: %s" % m.name)
		elif e["k"] == "leave":
			var m: Crew.Member = net_mates.get(g.id)
			net_mates.erase(g.id)
			if m:
				mate_gone(m)
		else:   # запрос комнаты после старта — комнаты уже нет
			continue
		changed = true
	for id: int in net_mates:   # гость без ввода дольше NetLink.LOST_AFTER — табличка «Нет связи»
		var g: NetLink.Guest = net_host.guests.get(id)   # хост закрыт — гостей уже нет, а фигуры ещё на палубе
		(net_mates[id] as Crew.Member).lost = g == null or g.lost()
	if changed:
		crew_view.set_members(crew, me)
		_net_index()


## Гость хоста на палубу: член экипажа своей роли и внешности с его вводом.
func _seat_guest(g: NetLink.Guest) -> Crew.Member:
	var m := add_mate(NET_SPAWN.x, NET_SPAWN.y, NET_SPAWN.z, g.role, g.look)
	if g.name != "":
		m.name = g.name
	m.pad = g.pad
	net_mates[g.id] = m
	return m


## Места гостей в экипаже — уходят им в кадре (`Guest.index`).
func _net_index() -> void:
	for id: int in net_mates:
		(net_host.guests[id] as NetLink.Guest).index = crew.find(net_mates[id])


## Товарищ ушёл с борта (гость отключился): убрать с палубы, его пост свободен; у хоста — «… отключился» (ART-043).
func mate_gone(m: Crew.Member) -> void:
	notice.left(m.name, m.busy(), m.look == 1)
	crew.erase(m)
	crew_view.set_members(crew, me)
	drop_panel.show_notice(notice)
	ghosts.append(MateGhost.new(m))   # на последнем месте полупрозрачным с «Нет связи», без поста (ART-043)
	_ghosts(0.0, true)


## Хост: фигуры отключившихся (`MateGhost`) — стоят, тают, растаявшие убраны; changed — список уже сменился.
func _ghosts(dt: float, changed := false) -> void:
	if ghosts.is_empty() and not changed:
		return
	changed = MateGhost.step(ghosts, dt) or changed
	var list := MateGhost.members(ghosts)
	if changed:
		ghost_view.set_members(list, null)
	ghost_view.alphas.assign(ghosts.map(func(g: MateGhost) -> float: return g.alpha()))
	ghost_view.apply()
	var melting := ghosts.filter(func(g: MateGhost) -> bool: return g.t > MateGhost.HOLD).map(
		func(g: MateGhost) -> Crew.Member: return g.member)   # тает — табличка уже снята
	ghost_tags.show_tags(list, null, ghost_view, get_viewport().get_camera_3d(), camera, tag_blocks(), dt, melting,
			status_rect())


## Кадр гостям раз в NetSnap.SEND_DT — после шага, как его видит хост.
func _net_send(dt: float) -> void:
	news_age += dt
	if net_host and net_host.due(dt):
		var welding := crew.any(func(m: Crew.Member) -> bool: return m.welding())
		var ev := NetSnap.events(breach, silt, time, welding, news if news_age < NetSnap.NEWS_TIME else [])
		ev["r"] = _net_run()
		ev["w"] = wreck.t   # шторка «Корпус разрушен» — у всех (ART-036)
		ev["z"] = NetSnap.scorch(scorch, time)   # следы разрядов на дне — тот же след у гостя
		ev["so"] = NetSnap.sonar(sonar, time)   # импульс и отметки голограммы — те же у гостя
		ev["c"] = comms.pack()   # связь ART-040: код забега, плашка и ход проверки — те же у гостя
		var f := NetSnap.frame(net_host.seq, time, helm, reactor, vitals, light_on, crew, ev)
		f["eco"] = EcoLink.pack_world(eco.world.agents, eco.world.systems, helm.pos, EcoLink.NET_R,
			eco.world.time)   # существа и мох рядом — гостям отдельным пакетом
		net_host.send_frame(f)


## Маршрут, голосование и итог для гостей (NetSnap.run_state): мнения ролей — по кораблю сейчас; метки — голоса
## у стола, а если голосует один — мнения ролей, как у своего игрока у стола.
func _net_run() -> Dictionary:
	var ops := []
	if run.done and not run.ended:
		ops = Run.opinions(vitals.hull, vitals.energy, reactor.hot, silt.inside != null, samples.cargo.size())
	var coop := vote_ids().size() > 1
	var marks: Dictionary = vote_marks() if coop or at_vote else VoteHolo.votes(ops)
	return NetSnap.run_state(run, marks, ballot.seconds() if coop else -1, ballot.fraction() if coop else -1.0,
		vote_panel.tally, ops, result_rows, result_detail)


## Войти в сетевой забег хоста по адресу в локальной сети: шаг корабля считает хост, здесь — свой ввод хосту
## (`net_pad` → `Client.send_pad`) и кадры хоста в корабль, реактор, корпус и экипаж; свой игрок — `crew[client.me]`.
func join_game(to: String, port: int = NetLink.PORT, player: String = "", role: int = Crew.Role.PILOT, look: int = 0) -> Error:
	if main_menu.open:
		close_menu()
	var c := NetLink.Client.new()
	var err := c.join(to, port, player, role, look)
	if err != OK:
		return err
	_enter_client(c)
	return OK


## Стать клиентом хоста: c уже подключается (`join_game`) или на борту (экран адреса ART-039).
func _enter_client(c: NetLink.Client) -> void:
	net_client = c
	net_seq = -1
	net_news = 0
	net_vote = {"secs": -1, "frac": -1.0, "tally": "", "ops": []}
	net_smooth = NetSmooth.new()
	net_pad.clear()
	drop = NetDrop.new()
	drop.menu_ready = true   # главное меню ART-037 есть: «В меню» в диалоге обрыва связи
	flyby.stop()   # клиент входит в идущий забег — облёта нет
	tutorial_guest = Tutorial.Guest.new()
	sonar.count = -1   # первый кадр хоста ставит его сонар, даже если счёт импульсов совпал со своим
	comms.reset_run(0)
	comms.code = ""   # кодовое слово — хоста, до первого кадра страницы «Связь» нет
	message.clear(Flyby.START_MSG)
	say(net_client.label())


## Шаг клиента: ввод с экрана — хосту, свежий кадр — в корабль и экипаж, дальше только картинка (без шага корабля).
func _client_step(dt: float) -> void:
	var r := overlay.router
	var lk := overlay.look_points()
	wreck.update(dt)   # между кадрами хоста шторка идёт сама; кадр ставит время хоста
	_wreck_show()
	if wreck.active() and not drop.blocks():   # шторка «Корпус разрушен»: ввод не идёт хосту
		net_pad.clear()
	elif drop.blocks():   # связь потеряна: управление остановлено, касания — кнопкам диалога
		net_pad.clear()
		_drop_taps(r.taps)
		if net_client == null:   # «Играть одному» — уже одиночный забег
			r.end_frame()
			return
	else:
		walker.look(lk)   # взгляд сразу свой: курс хост подтвердит кадром, наклон хосту не нужен
		net_pad.move = Vector2(r.move)
		net_pad.look += lk
		net_pad.action = net_pad.action or r.action_pressed
		net_pad.hold = r.action_down   # держит кнопку: сварка, вентиль, лебёдка, сканер — у хоста (`_mate_holds`)
		net_pad.vert = r.vert()
		net_pad.light = net_pad.light or r.light_pressed
	var was := net_client.state
	net_client.send_pad(net_pad)
	var f := net_client.poll(dt)
	if not f.is_empty():
		_client_frame(f)
		drop.restored()   # хост принял снова и кадр применён — управление вернулось
	if net_client.lost():   # кадры хоста не идут — у товарищей «Нет связи», пока не придёт кадр
		for m: Crew.Member in crew:
			m.lost = m != me
	net_smooth.step(dt)
	net_smooth.apply(helm, crew, me)   # показ чуть позади свежего кадра: между кадрами — плавно
	var near := net_smooth.take_eco()   # существа рядом — на тех же часах показа, что корабль
	if net_client.state != was and not drop.active():
		say(net_client.label())
	_drop_step(dt)
	if net_client == null:
		r.end_frame()
		return
	if drop.active():   # диалог или «Связь восстановлена» — плашка не нужна
		weak.reset()
	else:
		weak.update(dt, net_client.quiet)
	drop_panel.show_weak(weak)
	hull_motion.update(dt, helm.in_thrust, helm.in_vert, reactor.k(Reactor.Sys.ENGINES))
	_wake(dt)   # пузыри у гостя — свои, по тяге из кадра
	searchlight.apply(light_on, reactor.k(Reactor.Sys.LAMP), silt.beam_k())
	breach.time += dt   # пульс тревоги и свет сварки — своим временем, состояние — из кадра
	if not scorch.all.is_empty():   # след хоста темнеет в «старое пятно» часами гостя
		ocean.set_scorch(scorch.uniforms(time))
	breach_view.apply(dt)   # частицы ART-072 у гостя — своим временем по состоянию из кадра
	_cabin(Wreck.lamps(wreck.t))   # авария ART-064 у гостя — тот же ритм огней; шторка ART-036 гасит плафоны
	_glints(dt, Wreck.lamps(wreck.t))
	_wear(dt, Wreck.lamps(wreck.t))
	silt_view.apply(silt, time, helm.pos, helm.yaw)
	sonar_view.show_state(sonar, helm.pos, helm.yaw, time, reactor.k(Reactor.Sys.SONAR) > 0.0, silt.noise(time))
	_client_eco(dt, near)
	visor.visible = me.welding()
	alarm_board.show_alarms(alarms_on(), time, breach.active)
	_client_run_view(dt)
	var live := not (wreck.active() or drop.blocks())   # ввод, который ушёл хосту
	for ev in tutorial_guest.update(dt, pilot.seated, at_power, near_post, Vector2(r.move) if live else Vector2.ZERO,
			live and r.light_pressed, live and r.action_pressed, light_on, reactor.share, run.route, sonar.count):
		tutorial.note(ev)
	_tutorial_step(dt)
	_card_step(dt)
	_comms_step(dt)   # плашка связи хоста; нажатие — `net_pad.ask` со следующим вводом
	_radio_step(dt)
	for i in Reactor.Sys.size():
		bridge.set_slider(i, reactor.share[i] / float(Reactor.MAX))
	overlay.set_pilot(pilot.seated)
	message.update(dt)
	me.back = CrewView.own_back(walker.pitch, me.holding())
	crew_view.pitch = walker.pitch
	_apply_crew_view()
	_place_ship()
	_place_camera()
	route_card.show_card(brief.k, run.route, get_viewport().get_camera_3d(), sonar_view.to_global(Briefing.CARD_ANCHOR),
		comms.code)   # код забега — из кадра хоста (`Comms.apply`)
	_update_ui()   # до меток: плашка строки уже на месте этого кадра (#387)
	busy_marks.plate = status_rect()
	var busy := busy_marks.show_marks(crew, me, get_viewport().get_camera_3d(), camera)
	name_tags.show_tags(crew, me, crew_view, get_viewport().get_camera_3d(), camera, tag_blocks(), dt, busy,
			status_rect(), radio.voice())
	_warm_frame()
	r.end_frame()


## Клиент: живой мир идёт сам, существа рядом встают по кадру хоста (`EcoView.step_client`). Удары, присоски и
## сообщения мира разбирает хост — у гостя мир событий кораблю не шлёт.
func _client_eco(dt: float, near: PackedFloat32Array) -> void:
	var s := eco_ship
	s.pos = helm.pos
	s.yaw = helm.yaw
	s.speed = helm.speed
	s.light_on = Searchlight.lit(light_on, reactor.k(Reactor.Sys.LAMP))
	s.light_range = Searchlight.range_m(reactor.k(Reactor.Sys.LAMP)) * silt.beam_k() if s.light_on else 0.0
	s.dive = run.depth
	eco.step_client(dt, s, near)


## Клиент: маршрут, голосование и итог по кадру хоста (`run` уже как у хоста) — точка и брифинг на голостоле, поля
## голосования с метками и таймером, итог над столом, панель у стола.
func _client_run_view(dt: float) -> void:
	near_post = ""
	if not me.busy():
		var post := Deck.nearest(posts, walker.x, walker.z)
		near_post = post.id if post else ""
	sonar_view.show_waypoint(run.waypoint())
	sonar_view.show_briefing(brief.update(dt, Briefing.wanted(near_post, at_vote, run.ended)), run, helm.pos)
	sonar_view.show_vote(vote_fade.update(dt, VoteHolo.wanted(at_vote, run.ended)), votes, int(net_vote["secs"]),
		float(net_vote["frac"]))
	sonar_view.show_result(result_fade.update(dt, VoteHolo.result_wanted(at_vote, run.ended)), result_rows,
		camera.global_position)
	if not at_vote:
		vote_panel.visible = false
	elif run.ended:
		vote_panel.show_results(result_detail, run.score)
	else:
		vote_panel.show_vote(run.depth, net_vote["ops"])
		vote_panel.set_tally(net_vote["tally"])


## Кадр хоста: корабль, реактор, корпус, свет, экипаж. Свой игрок — место `me` в кадре; его курс остаётся своим
## (свайп уже повернул камеру), пока он не сел за пост или не встал — тогда курс хоста.
func _client_frame(f: Dictionary) -> void:
	var yaw := walker.yaw
	var was_busy := me.busy()
	var n := crew.size()
	var seq := net_seq
	net_seq = NetSnap.apply_frame(f, net_seq, helm, reactor, vitals, crew)
	if net_seq != seq:
		net_smooth.push(float(f.get("t", 0.0)), helm.pos, helm.yaw, crew, f.get("eco", PackedFloat32Array()))
		var ev := NetSnap.apply_events(f.get("ev", {}), breach, silt, time)
		if ev.size() == 2 and ev[0] > net_news:   # сообщение события хоста — один раз
			net_news = ev[0]
			say(ev[1])
		var evd: Variant = f.get("ev", {})
		if evd is Dictionary:
			wreck.follow(float(evd.get("w", -1.0)))
			if NetSnap.apply_scorch(evd.get("z"), scorch, time):
				ocean.set_scorch(scorch.uniforms(time))   # разряд хоста у дна или новый забег
			NetSnap.apply_sonar(evd.get("so"), sonar, time)
			comms.apply(evd.get("c"))
		var rs := NetSnap.apply_run(evd.get("r") if evd is Dictionary else null, run)
		if not rs.is_empty():   # маршрут хоста уже в run; метки, таймер и итог — для показа
			votes = rs["marks"]
			result_rows = rs["rows"]
			result_detail = rs["detail"]
			net_vote = rs
	light_on = bool(f.get("light", light_on))
	overlay.set_light(light_on)
	var i := net_client.me
	var mine: Crew.Member = crew[i] if i >= 0 and i < crew.size() else me
	if mine != me or crew.size() != n:
		var moved := mine != me
		me = mine
		walker = me.walker
		crew_view.set_members(crew, me)
		if moved:
			walker.pitch = 0.0
			return
	if me.busy() == was_busy:
		walker.yaw = yaw
		me.yaw = yaw
	elif me.busy():
		walker.pitch = 0.0


## Потеря хоста у гостя (ART-043): не соло молча — диалог и попытка переподключения на NetDrop.WINDOW; отказ хоста
## при попытке — причина без повторов; окно истекло — «Нет ответа». Отказ при первом входе — одиночная игра.
func _drop_step(dt: float) -> void:
	var st := net_client.state
	if st == NetLink.State.LOST and not drop.blocks():
		drop.open()
		net_client.rejoin(NetDrop.WINDOW)
	elif drop.blocks():
		if st == NetLink.State.REFUSED and net_client.why in ["version", "full"]:
			drop.refused(net_client.why)
		if drop.update(dt):
			net_client.stop()
	elif st == NetLink.State.REFUSED:
		_leave_net()
		return
	else:
		drop.update(dt)
	drop_panel.show_drop(drop)


## Касания кнопок диалога «Связь потеряна».
func _drop_taps(taps: Array[Vector2]) -> void:
	for p in taps:
		match drop.press(drop.hit(p, get_viewport().get_visible_rect().size)):
			"rejoin":
				net_client.rejoin(NetDrop.WINDOW)
			"solo":   # перенос забега в соло не сделан — новый одиночный забег
				_leave_net()
				if me.pilot.seated:
					me.stand()
				_restart()
			"menu":   # «В меню» (ART-043): сетевой забег покинут, главное меню ART-037
				_leave_net()
				_to_menu()
		drop_panel.show_drop(drop)
		if net_client == null:
			return


## Связь с хостом кончилась (отказ при входе или «Играть одному»): дальше одиночная игра с последним кадром.
func _leave_net() -> void:
	net_client.stop()
	net_client = null
	tutorial_guest = null
	wreck.reset()   # шторка хоста — не своя: одиночный забег без неё
	_wreck_show()
	weak.reset()
	drop_panel.show_weak(weak)
	crew = [me]
	me.lost = false
	crew_view.set_members(crew, me)


## Куда может шагнуть член экипажа m: пол корабля (ShipLayout.can_stand) и не в другую фигуру (Crew.room_for, #602).
func stand_for(m: Crew.Member) -> Callable:
	return func(x: float, z: float) -> bool: return layout.can_stand(x, z) and Crew.room_for(crew, m, x, z)


## Ещё один член экипажа на палубе (снимки и сценарий тестера, пока нет сети): место, курс (рад), роль, внешность.
## Стоящего не ставим в мебель: место внутри голостола или пульта сдвигается к ближайшему свободному (issue #156).
func add_mate(x: float, z: float, yaw: float, role: int, look: int, seated: bool = false) -> Crew.Member:
	var mate := Crew.Member.new(role)
	mate.look = look
	mate.walker.stand = stand_for(mate)
	if not seated:
		var p := layout.free_spot(x, z)
		x = p.x
		z = p.y
	mate.place(x, z, yaw, seated)
	mate.sync_post()
	crew.append(mate)
	crew_view.set_members(crew, me)
	crew_view.apply()
	return mate


## Для tools/shot.gd: сесть за штурвал и провести корабль перед снимком (ключи pilot, thrust, turn, vert, secs).
func debug_setup(kv: Dictionary) -> void:
	flyby.stop()   # снимки — с мостика; flyby=start|surface — вид с борта (age=<с> от начала)
	message.clear(Flyby.START_MSG)
	if kv.get("pilot", "0") == "1":
		sit_at_helm()
	if kv.get("light", "1") == "0":
		toggle_light()
	if kv.get("power", "0") == "1":  # у пульта энергии
		walker.x = -3.9
		walker.z = -2.0
		open_power()
	if kv.get("ping", "0") == "1":  # импульс сонара с тремя пробными отметками (живого мира ещё нет)
		sonar.ping(time, 1.0)
		sonar.take_contacts([
			EcoLink.near("serpohvost", "серпохвост", helm.pos + Vector3(35, 0, -40), helm.pos),
			EcoLink.near("svetlyak", "светляк", helm.pos + Vector3(-50, 0, -20), helm.pos),
			EcoLink.near("veil", "вуаль", helm.pos + Vector3(10, 0, 60), helm.pos)], helm.pos)
		time += float(kv.get("age", "1.0"))
		sonar_view.show_state(sonar, helm.pos, helm.yaw, time, true)
	if kv.get("zap", "0") == "1":  # разряд: рычаг внизу, шкала готовности погашена
		fire_zap()
	if kv.get("lock", "0") == "1":  # открытый шлюз трюма
		airlock.open = true
		airlock.t = 1.0
		rooms.apply(layout, reactor, airlock)
		if kv.has("lock_event"):  # lock_event=enter|exit — кольца от троса / всплеск захвата ART-073, lock_age=<с>
			var exit: bool = kv["lock_event"] == "exit"
			lock_water._event(LockWater.Kind.EXIT if exit else LockWater.Kind.ENTER, 1.0, LockWater.CENTER)
			lock_water.event_age = float(kv.get("lock_age", "0.36"))
	if kv.has("mate"):  # mate=x,z,курс°[,роль 0…3[,внешность 0…1]] — ещё один член экипажа стоит на палубе; mate=helm — сидит за штурвалом, mate=energy — инженер у пульта
		if kv["mate"] == "helm":
			add_mate(0.0, Deck.SEAT_Z, 0.0, Crew.Role.SONAR, 0, true)
		elif kv["mate"] == "energy":   # инженер у пульта энергии (метка «Занято»)
			var e := add_mate(POWER_STAND.x, POWER_STAND.y, PI * 0.5, Crew.Role.ENGINEER, 0)
			e.at_power = true
			e.sync_post()
		else:  # несколько — через «;»
			for one: String in kv["mate"].split(";"):
				var m: PackedFloat64Array = one.split_floats(",")
				add_mate(m[0], m[1], deg_to_rad(m[2]) if m.size() > 2 else 0.0, int(m[3]) if m.size() > 3 else Crew.Role.SONAR,
					int(m[4]) if m.size() > 4 else 1)
		if kv.has("tag"):  # tag=a;l;- — состояния табличек товарищей по порядку (ART-033): a — нажимает, l — нет связи
			var st: PackedStringArray = kv["tag"].split(";")
			for k in mini(st.size(), crew.size() - 1):
				var mm: Crew.Member = crew[k + 1]
				mm.press = -1e3 if st[k] == "a" else INF   # на время снимка
				mm.lost = st[k] == "l"
		if kv.get("gone", "0") == "1":  # gone=1 — последний товарищ отключился: у хоста плашка ART-043
			mate_gone(crew[-1])
	if kv.get("silt", "0") == "1":  # silt=1 — корабль в облаке ила (снимок сонарной тьмы); с ping=1 — импульс завяз
		open_silt()   # (jam_age=<с> — сколько прошло с завязшего импульса, ART-048)
		if kv.get("ping", "0") == "1":
			sonar.ping(time, 1.0, true)
			silt.jam_ping(time)
			time += float(kv.get("jam_age", "0.4"))
	if kv.has("hot"):  # hot=1 — перегрев (для снимка табло)
		reactor.start_hot(false)
		reactor.heat = float(kv["hot"])
	if kv.has("hull"):  # hull=<%> — прочность корпуса (следы повреждений ART-049 снаружи, износ внутри ART-074)
		vitals.hull = float(kv["hull"])
		wear.snap(vitals.hull)
	if kv.get("relief", "1") == "0":  # relief=0 — уровень «Экономно» ART-044 (рельеф ART-053…056, частицы, пост)
		_apply_graphics(Graphics.ECONOMY)
	if kv.has("grafika"):  # grafika=0|1|2 — уровень графики ART-044 (0 — «Экономно», 2 — «Красиво»)
		_apply_graphics(int(kv["grafika"]))
	if kv.get("glints", "1") == "0":  # glints=0 — без бликов воды в мостике ART-067 (сравнить)
		glints.lite = true
	if kv.has("layers"):  # layers=<сила> — слои воды ART-069 (0 — выкл, 0,6 — «Обычно», 0,9 — «Красиво»)
		ocean.set_layers_level(float(kv["layers"]))
	if kv.get("grade", "1") == "0":  # grade=0 — без виньетки и цветокоррекции ART-065 (сравнить)
		grade.set_on(false)
	if kv.has("energy"):  # energy=<ед.> — заряд корабля (меньше 20 — «МАЛО ЗАРЯДА» на табло)
		vitals.energy = float(kv["energy"])
	if kv.get("drain", "0") == "1":  # drain=1 — стеклоуст на корпусе (табло и рамка у щитка разряда)
		vitals.drain("Стеклоуст", 0.01)
		vitals.drain_left = 60.0
	if kv.get("steam", "0") == "1":  # пар из вентиля и открытая крышка щитка (для снимка машинного)
		debug_vent = true
		engine.pressed = 30.0
		engine.lid = 1.0
	if kv.has("sample"):  # sample=n — корабль над образцом n, шлюз открыт; grab=<с> — столько держать кнопку у лебёдки
		park_over_sample(int(kv["sample"]))
		walker.x = Samples.POST_AT.x - 0.7
		walker.z = Samples.POST_AT.y + 0.3
		var lock := Samples.lock_point(Samples.ship_xform(helm.pos, helm.yaw))
		var held := float(kv.get("grab", "0"))
		debug_winch = held > 0.0 and held < Samples.GRAB_TIME
		while held > 0.0:
			samples.hold(lock, 0.05)
			samples.update(0.05)
			held -= 0.05
		rooms.set_winch(samples.hook_local(Samples.ship_xform(helm.pos, helm.yaw)), samples.carrying(),
			Samples.COLORS[samples.target.kind] if samples.target else Color.WHITE)
	if kv.has("cargo"):  # cargo=0,2,1 — виды образцов в трюме (и в колбах лаборатории)
		samples.cargo.clear()
		for k in kv["cargo"].split(",", false):
			samples.cargo.append([clampi(int(k), 0, Samples.NAMES.size() - 1), -1])
		rooms.set_lab(Lab.contents(samples.cargo), Lab.page_lines(samples, scanner, journal_page), time)
	if kv.has("observe"):  # observe=fish:flee,pred:ping — наблюдения в журнале; scanned=fish,pred — изученные виды;
		# journal=n — страница журнала (0 — сводка)
		for pair in kv["observe"].split(",", false):
			var kn: PackedStringArray = pair.split(":")
			if kn.size() == 2:
				scanner.observe(kn[0], kn[1])
	if kv.has("scanned"):
		for id in kv["scanned"].split(",", false):
			scanner.scanned[id] = true
	if kv.has("route"):   # маршрут n (0…2) выбран у голостола
		run.choose(int(kv["route"]))
	if kv.get("vote", "") in ["1", "up"]:   # маршрут пройден, решение у голостола; vote=up — итог забега
		complete_route()
		open_vote()
		if kv["vote"] == "up":
			decide("up")
			if not kv.has("flyby"):
				flyby.stop()   # снимок итога — с мостика: итог на голограмме над столом
	if kv.get("vote", "") == "coop":   # двое у стола: товарищи (mate=…) голосуют, свой — «глубже», решение ждёт их
		complete_route()
		open_vote()
		for m: Crew.Member in crew:
			m.at_vote = true
		ballot.cast(me.get_instance_id(), me.role, "deep")
	if kv.has("journal"):
		journal_page = clampi(int(kv["journal"]), 0, Lab.pages(scanner) - 1)
		rooms.set_lab(Lab.contents(samples.cargo), Lab.page_lines(samples, scanner, journal_page), time)
	if kv.has("breach"):  # breach=n — пробоина в месте n (0 мостик, 1 коридор, 2 лаборатория, 3 машинное), игрок у неё;
		# weld=<доля> — шов заварен на долю (1 — заварен, шов горячий); water=<м> — вода на полу
		open_breach(int(kv["breach"]))
		var w := float(kv.get("weld", "0"))
		if w >= 1.0:
			breach.hold(1.0 / Breach.WELD_RATE)
		elif w > 0.0:
			breach.weld = w
			debug_weld = true
		if kv.has("water"):
			breach.water = float(kv["water"])
		breach.time = 0.25
		for i in 60:   # частицы ART-072 уже летят: секунда пробоины (и сварки, если weld)
			breach.welding = debug_weld
			breach_view.apply(1.0 / 60.0)
		breach.time = 0.25
	if kv.has("ship"):  # ship=x,y,z — поставить корабль (y — высота, глубина со знаком минус)
		var p: PackedFloat64Array = kv["ship"].split_floats(",")
		park_at(Vector3(p[0], p[1], p[2]))
	if kv.has("scorch"):  # scorch=n — n следов разряда на дне перед носом через 4 м (первый — старое пятно)
		var n := int(kv["scorch"])
		for i in n:
			var at := helm.pos + helm.nose() * (9.0 + 4.0 * i)
			var fy := Seabed.height(at.x, at.z)
			scorch.add(Vector3(at.x, fy + Helm.Ship.CLEARANCE, at.z), fy, 1.0,
					time - (Seabed.Scorch.OLD.y if i == 0 else 0.0))
		ocean.set_scorch(scorch.uniforms(time))
	if kv.has("use"):  # use=<пост> — встать (x, z, yaw) и нажать кнопку действия у поста, шаг игры 0,3 с — снимок
		walker.x = float(kv.get("x", str(walker.x)))
		walker.z = float(kv.get("z", str(walker.z)))
		walker.yaw = deg_to_rad(float(kv.get("yaw", "0")))
		use_post(kv["use"])
		for i in 9:
			step(1.0 / 30.0)
	if kv.has("secs"):
		var secs := float(kv["secs"])
		var dt := 1.0 / 30.0
		for i in int(secs / dt):
			helm.in_thrust = float(kv.get("thrust", "0"))
			helm.in_turn = float(kv.get("turn", "0"))
			helm.in_vert = float(kv.get("vert", "0"))
			current.update(dt)
			helm.update(dt, 1.0, current.vel())
			hull_motion.update(dt, helm.in_thrust, helm.in_vert, 1.0)
			_wake(dt)
		_place_ship()
		_place_camera()
		_update_ui()
	if kv.has("flyby"):
		flyby.start(Flyby.Kind.SURFACE if kv["flyby"] == "surface" else Flyby.Kind.START)
		flyby.update(float(kv.get("age", "2.0")))
		_place_camera()
	if kv.has("vent"):  # vent=<с> — выпуски у сервисных крышек ART-063 через столько секунд после продувки
		wake.vent()
		for i in int(float(kv["vent"]) * 30.0):
			_wake(1.0 / 30.0)
	if kv.has("view"):  # view=x,y,z — камера снаружи в осях корабля, смотрит на середину корпуса (снимок корпуса)
		var v: PackedFloat64Array = kv["view"].split_floats(",")
		var out := Camera3D.new()
		out.fov = Deck.FOV
		out.far = 400.0
		add_child(out)
		out.global_position = ship.to_global(Vector3(v[0], v[1], v[2]))
		out.look_at(ship.to_global(Vector3(0.0, HullPlan.CENTER_Y, 10.0)))
		out.make_current()
	if kv.get("mate_hold", "0") == "1" and crew.size() > 1:   # последний товарищ держит кнопку (сварка, вентиль…)
		if kv.has("x"):   # свой игрок — на своём месте до шагов: пост держит товарищ
			walker.x = float(kv["x"])
			walker.z = float(kv.get("z", "0"))
		var mate: Crew.Member = crew[-1]
		mate.pad.hold = true
		for i in int(float(kv.get("hold_s", "1.5")) * 10.0):
			step(0.1)
