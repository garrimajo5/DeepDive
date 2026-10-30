class_name QaRunner
extends Node
## Прогон сценария тестера внутри игры (docs/QA.md). Если при запуске есть файл user://qa/scenario.json,
## игра проходит его шаги через то же разбор касаний, что и пальцы, снимает скриншоты и пишет лог в user://qa/out/,
## в конце — user://qa/out/done.txt. Сценарий после прогона переименовывается в scenario.last.json, чтобы обычный
## запуск игры не был сценарным.

const DIR := "user://qa"
const SCENARIO := DIR + "/scenario.json"
const OUT := DIR + "/out"

var main: Main
var script_q: QaScript
var log_lines: PackedStringArray = []
var time := 0.0
var shots: Array[String] = []
var _look_at := Vector2.ZERO
## Худший кадр (настоящее время между шагами, мс) с прошлого скриншота: средние кадр/с прячут разовый провал
## (issue #50 — сборка шейдеров при первом показе). Кадр сразу после скриншота не считаем — его тормозит сам снимок.
var worst_ms := 0.0
## Где был худший кадр (issue #217): шаг сценария и сколько из кадра заняла отрисовка на процессоре (сборка шейдеров
## и выгрузка мешей идут здесь) — отличить её от тяжёлого кода (отрисовка мала, кадр долгий).
var worst_at := ""
var _step_label := ""
var _last_us := 0
var _skip_frame := true
## Отрисовка последнего кадра, мс: от RenderingServer.frame_pre_draw до frame_post_draw того же кадра (issue #609).
## Замер движка (viewport_get_measured_render_time_cpu) приходит на несколько кадров позже и после сборки шейдеров
## бывает больше самого кадра — «отрисовка 1466 мс» при худшем 178 приписывалась чужому кадру (кадру снимка).
## Сюда входит и ожидание видеокарты и показа кадра (вплоть до кадровой развёртки).
var draw_ms := 0.0
var _draw_from_us := 0
## Сборки шейдеров (конвейеров видеокарты) в последнем кадре по видам `PIPES` (issue #983): провал «отрисовка 338 мс»
## на устройстве — сборка это или выгрузка. Счётчики движка накопительные; Compatibility их не ведёт (нули).
var pipes := PackedInt32Array([0, 0, 0, 0, 0])
var _pipes_total := PackedInt32Array([0, 0, 0, 0, 0])
const PIPES := [[RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS, "2D"],
	[RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH, "меши"],
	[RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE, "поверхности"],
	[RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW, "при отрисовке"],
	[RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION, "варианты"]]
## Кадры и их время (мкс) с прошлого скриншота — без кадра снимка и прогрева (issue #169): среднее движка
## за секунду считало и сам скриншот, и «05b-light-off» через 0,5 с после снимка показывал 3 к/с при худшем кадре 34 мс.
var frames := 0
var frames_us := 0
## Issue #435: кадры сразу после снимка на эмуляторе долгие (видеокарта догоняет после чтения кадра) — строка
## описания через 0,3 с после снимка показывала 1–18 к/с при 50–60 у скриншотов. В средние их не берём; худший кадр
## считается как раньше (рывок сразу после снимка не прячем). Своих кадров нет — у строки «—».
const SETTLE_FRAMES := 3
var _settle := 0
## Issue #1013: после шага «ship» (корабль перенесён через всю отмель) в кадр разом входят меши, текстуры и материалы
## мест — первая выгрузка в видеокарту даёт 130–180 мс, которых в обычной игре нет (корабль плывёт, места входят
## постепенно). Такие кадры идут не в худший кадр, а отдельно — « · после прыжка N мс» в строке скриншота.
const JUMP_FRAMES := 30
var _jump := 0
var jump_ms := 0.0
var _shot_taken := false
var _warm_frames := 0   ## кадры прогрева шейдеров при старте (Warmup) — в лог, когда он кончится
var _warm_from_us := 0
var _warm_last_us := 0
var _warm_ms: Array[int] = []   ## длительность каждого кадра прогрева, мс (issue #159: какой взгляд дорогой)
var composing := 0     ## кадры Google Play (шаг «play»), которые ещё собираются — «quit» их ждёт
var graphics_seen := ""   ## последняя записанная строка графики (`graphics_now`): новая — в лог (по отчёту #742)
var drain_left := 0.0   ## шаг «drain»: столько секунд ещё слать в игру EcoLink.DRAIN от стеклоуста


## Есть ли сценарий для этого запуска.
static func pending() -> bool:
	return FileAccess.file_exists(SCENARIO)


## Загрузить сценарий из файла (или текста — для тестов) и подготовить папку результатов.
func start(m: Main, text: String = "") -> void:
	main = m
	if text.is_empty():
		text = FileAccess.get_file_as_string(SCENARIO)
		DirAccess.rename_absolute(SCENARIO, DIR + "/scenario.last.json")
	script_q = QaScript.parse(text)
	RenderingServer.viewport_set_measure_render_time(main.get_viewport().get_viewport_rid(), true)   # видеокарта — для worst_at
	RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	RenderingServer.frame_post_draw.connect(_on_post_draw)
	for i in PIPES.size():   # счёт сборок — с начала прогона, не с запуска (issue #983)
		_pipes_total[i] = RenderingServer.get_rendering_info(PIPES[i][0])
	_warm_from_us = Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(OUT)
	for f in DirAccess.get_files_at(OUT):
		DirAccess.remove_absolute(OUT + "/" + f)
	_log("Сценарий: %d шагов, версия %s, %s" % [script_q.steps.size(), ProjectSettings.get_setting("application/config/version", "?"),
		OS.get_model_name()])
	for e in script_q.errors:
		_log("ОШИБКА СЦЕНАРИЯ: " + e)


## Шаг: выполнить команды сценария до шага игры (main.step зовёт его первым).
func tick(dt: float) -> void:
	if script_q == null or script_q.finished:
		return
	if main.warming():   # прогрев шейдеров при старте: шаги сценария ждут, кадры не считаем
		_warm_frames += 1
		_warm_tick(Time.get_ticks_usec())
		_skip_frame = true
		return
	if _warm_frames > 0:
		var now := Time.get_ticks_usec()
		_warm_tick(now)
		_log("прогрев шейдеров: %d кадров, %d мс" % [_warm_frames, (now - _warm_from_us) / 1000])
		_log("прогрев по кадрам, мс: " + warm_line(_warm_ms))
		_warm_frames = -1
	time += dt
	_measure(Time.get_ticks_usec())
	_log_graphics()
	var r := main.overlay.router
	for c in script_q.advance(dt):
		match c[0]:
			"begin":
				var p := _point(c[2], c[3])
				_look_at = p
				r.begin(c[1], p)
			"move":
				_look_at += c[2]
				r.moved(c[1], _look_at)
			"end":
				r.end(c[1])
			"shot":
				_shot(c[1])
			"hud":   # кадры для магазина: без крестовины, кнопок и строк приборов
				main.set_hud(c[1])
			"play":   # кадр Google Play ART-046: снимок и кадр 1920×1080 с подписью
				_play(c[1])
			"goto":
				if main.pilot.seated:
					main.stand_up()
				if main.at_power:
					main.close_power()
				if main.at_vote:
					main.close_vote()
				main.walker.x = c[1]
				main.walker.z = c[2]
				main.walker.yaw = deg_to_rad(c[3])
				if c.size() > 4:
					main.walker.pitch = deg_to_rad(c[4])
			"hot":
				if c[1] <= 0.0:   # heat 0 — остудить: перегрев снят, следующие шаги без него
					main.reactor.hot = false
					main.reactor.heat = 0.0
				else:
					main.reactor.start_hot(false)
					main.reactor.heat = c[1]
			"sample":
				main.park_over_sample(c[1])
			"ship":   # корабль в точку мира и стоит (вид на дно под трещинами, #445)
				if c.size() > 4:   # курс задан — видно то же место, как бы ни шёл забег до этого
					main.helm.yaw = deg_to_rad(c[4])
					main.helm.turn = 0.0
				main.park_at(Vector3(c[1], c[2], c[3]))
				_jump = JUMP_FRAMES
			"fly":   # тестовый полёт noclip: глаз на высоте c[2] в осях корабля, наклон c[3]
				if main.walker.noclip != c[1]:
					main.toggle_noclip()
				if c[1]:
					main.walker.y = c[2]
					main.walker.pitch = deg_to_rad(c[3])
			"breach":
				if c[1] < 0:
					main.close_breach()
				else:
					main.open_breach(c[1])
			"route":   # маршрут разом и голосование у стола — как его откроет переход у 10 (#828, #824)
				main.complete_route()
				main.open_vote()
			"silt":
				if c[1]:
					main.open_silt()
				else:
					main.silt.reset()
			"drain":
				drain_left = c[1]
			"hull":
				main.vitals.hull = c[1]
				main.timeline.set_hull(main.time, c[1])   # износ из сценария — не «удар» (#692)
			"charge":
				main.vitals.energy = c[1]
			"ping":   # импульс сонара, как с поста (у площадки 08 — ритм пограничного поля, #833)
				main.ping_sonar()
			"save":   # место для гибели (#824): как автосохранение, но только в памяти — файл прогона не пишется
				main.save.ship = SaveGame.ship_read(SaveGame.ship_snapshot(main.helm, main.vitals)) if c[1] else {}
			"wreck":   # корпус разрушен — как от удара (шторка ART-036)
				main.vitals.hull = 0.0
				main.timeline.set_hull(main.time, 0.0)   # крушение из сценария — не «удар» в хронометраже
				main.vitals.destroyed.emit()
			"back":   # системная «Назад»: пауза ART-037
				main.back_pressed()
			"tutorial":   # подсказки первого забега ART-038: с первого шага или убрать
				main.tutorial.reset()
				main.tutorial.on = c[1]
			"voice":   # голос во внутренней связи ART-040 — как событие мира EcoLink.VOICE
				main.on_eco_event(EcoLink.voice(c[1], c[2], c[3], c[4], c[5]))
			"slow":   # предложение «Экономно» ART-044 — как после нескольких секунд низких кадр/с
				main.lite_offer.force()
			"cards":   # карточки ролей у постов ART-045: с нуля (ничего не прочитано) или убрать
				main.role_card.set_read([])
				main.role_card.reset_run()
				main.role_card.on = c[1]
			"mate":
				var mate: Crew.Member
				if c[6]:   # за штурвалом
					mate = main.add_mate(0.0, Deck.SEAT_Z, 0.0, clampi(c[4], 0, 3), clampi(c[5], 0, 1), true)
				else:
					mate = main.add_mate(c[1], c[2], deg_to_rad(c[3]), clampi(c[4], 0, 3), clampi(c[5], 0, 1))
				if c.size() > 9:   # идёт своим вводом (Crew.Pad), свой игрок стоит
					mate.pad.move = Vector2(c[7], c[8])
					mate.pad.left = c[9]
			"act":   # последний товарищ жмёт кнопку действия (свой ввод, CrewFlow.drive)
				if main.crew.size() > 1:
					(main.crew[-1] as Crew.Member).pad.action = true
			"mate_hold":   # последний товарищ держит кнопку действия (Crew.Pad.hold — сварка, вентиль, лебёдка, сканер)
				if main.crew.size() > 1:
					(main.crew[-1] as Crew.Member).pad.hold = c[1]
			"gone":   # последний товарищ отключился, как гость сети (Main.mate_gone)
				if main.crew.size() > 1:
					main.mate_gone(main.crew[-1])
			"log":
				_log("%s | %s" % [c[1], state()])
			"quit":
				_quit_after_frames()
			"done":
				_finish()
	_step_label = step_label(script_q)   # этот кадр рисуется на этом шаге — к нему и отнесём его время
	if drain_left > 0.0:   # как присосавшийся стеклоуст: 3,2 ед./с (js/creatures.js), пока не истечёт шаг
		drain_left -= dt
		main.on_eco_event(EcoLink.drain("Стеклоуст", 3.2))


## Уровень графики и то, что он поставил на деле, — в лог при старте и при каждой смене (отчёт #742: видеокарта
## 30–40 мс весь первый забег и 1–3 мс после страницы «Графика» — по логу не понять, с каким уровнем шёл забег).
func _log_graphics() -> void:
	var line := graphics_now()
	if line != graphics_seen:
		graphics_seen = line
		_log(line)


## Графика сейчас одной строкой: уровень `Main.graphics_level` и фактические MSAA, масштаб сцены и тени солнца.
func graphics_now() -> String:
	var vp := main.get_viewport()
	var msaa := {Viewport.MSAA_DISABLED: 0, Viewport.MSAA_2X: 2, Viewport.MSAA_4X: 4, Viewport.MSAA_8X: 8}.get(
		vp.msaa_3d, -1) as int
	var splits := 0
	if main.ocean and main.ocean.sun.shadow_enabled:
		splits = 4 if main.ocean.sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS else 2
	return graphics_line(main.graphics_level, msaa, vp.scaling_3d_scale, splits,
		RenderingServer.get_video_adapter_name())


## «графика «Обычно»: MSAA 2×, масштаб 1,00, тени 2 · видеокарта Adreno 740».
static func graphics_line(level: int, msaa: int, scale: float, splits: int, adapter: String) -> String:
	var aa := "выкл" if msaa == 0 else "%d×" % msaa
	var sh := "выкл" if splits == 0 else str(splits)
	return "графика «%s»: MSAA %s, масштаб %s, тени %s · видеокарта %s" % [Graphics.NAMES[Graphics.valid(level)], aa,
		("%.2f" % scale).replace(".", ","), sh, adapter if not adapter.is_empty() else "—"]


## Учесть кадр, начавшийся в момент now_us (мкс).
func _measure(now_us: int) -> void:
	if not _skip_frame and _last_us > 0:
		var ms := (now_us - _last_us) / 1000.0
		if _jump > 0:   # кадры сразу после переноса корабля — отдельно (issue #1013)
			_jump -= 1
			jump_ms = maxf(jump_ms, ms)
			_skip_frame = false
			_last_us = now_us
			return
		if ms > worst_ms:
			worst_ms = ms
			worst_at = worst_note(_step_label, render_ms(), code_ms(), gpu_ms(), ms, main.clock.last_note() if main else "", pipes)   # _measure — уже в новом шаге (issue #662)
		if _settle > 0:
			_settle -= 1
		else:
			frames += 1
			frames_us += now_us - _last_us
	_skip_frame = false
	_last_us = now_us


## Точка экрана для кнопки сценария по текущей раскладке (координаты не зашиты в сценарий).
func _point(what: String, dir: Vector2) -> Vector2:
	var l := main.overlay.router.layout
	match what:
		"pad":
			return l.pad.c + Vector2(dir.x, -dir.y).limit_length(1.0) * l.pad.r * 0.7
		"action":
			return l.action.c
		"up":
			return l.up.c
		"down":
			return l.down.c
		"light":
			return l.light.c
		"dive":   # «Погрузиться» в главном меню ART-037
			return main.main_menu.rect("dive", main.get_viewport().get_visible_rect().size).get_center()
		"hint_map":   # кнопка «Схема» на плашке подсказки ART-038
			return main.tutorial_panel.map_rect().get_center()
		"map_back":   # «Назад» схемы корабля ART-042
			return ShipMap.back_rect(main.get_viewport().get_visible_rect().size).get_center()
		"map":   # «Схема корабля» в паузе / меню забега ART-042
			return Pause.screen_rect("map", main.get_viewport().get_visible_rect().size, main.pause.mode).get_center()
		"resume", "new", "exit", "yes", "no":   # пауза ART-037 и её подтверждение
			return Pause.screen_rect(what, main.get_viewport().get_visible_rect().size).get_center()
		"settings":   # «Настройки» паузы или главного меню ART-037
			var size := main.get_viewport().get_visible_rect().size
			return (Pause.screen_rect("settings", size, main.pause.mode) if main.pause.open
				else MainMenu.screen_rect("settings", size)).get_center()
		"graphics":   # «Графика» в настройках ART-044
			return Settings.screen_rect("graphics", main.get_viewport().get_visible_rect().size).get_center()
		"ask":   # «Спросить код» / «Понятно» на плашке связи ART-040
			var area: Rect2 = main.comms_area()
			return Comms.button_rect(area.size).get_center() + area.position
		"lite_yes", "lite_no":   # «Да» / «Нет» предложения «Экономно» ART-044
			return LiteOffer.screen_rect(what.substr(5), main.get_viewport().get_visible_rect().size).get_center()
		"golos", "zvuk":   # «Голос» ART-041 / «Звук» (громкости шин) в настройках
			return Settings.screen_rect(what, main.get_viewport().get_visible_rect().size).get_center()
		"s0":   # страница «Настройки · Звук»: середина ползунка «Музыка» — 50 %
			return SoundPage.screen_rect(what, main.get_viewport().get_visible_rect().size).get_center()
		"v_hold", "v_voice", "v_hear", "v_mic":   # страница «Настройки · Голос» ART-041: режим, приём, микрофон
			return VoicePage.screen_rect(what, main.get_viewport().get_visible_rect().size).get_center()
		"g0", "g1", "g2", "fps":   # страница «Настройки · Графика» ART-044: уровень, «Показывать кадры/с»
			return Graphics.screen_rect(what, main.get_viewport().get_visible_rect().size).get_center()
		"lobby_new", "lobby_addr", "lobby_refresh":   # поиск забегов ART-028: «Создать забег» / «По адресу» / «Обновить»
			return Lobby.screen_rect({"lobby_new": "new", "lobby_addr": "address", "lobby_refresh": "refresh"}[what],
				main.get_viewport().get_visible_rect().size).get_center()
		"crew", "journal":   # «Экипаж» (вход сбора экипажа ART-028), «Журнал экспедиции» ART-047 в главном меню
			return main.main_menu.rect(what, main.get_viewport().get_visible_rect().size).get_center()   # с «Продолжить» — ниже
		"jprev":   # «Журнал экспедиции» ART-047: «Ранее» / «Далее», «Закрыть» карточки
			return Journal.prev_rect(main.get_viewport().get_visible_rect().size).get_center()
		"jnext":
			return Journal.next_rect(main.get_viewport().get_visible_rect().size).get_center()
		"jclose":
			return Journal.close_rect(main.get_viewport().get_visible_rect().size).get_center()
		"join", "last":
			return AddressScreen.screen_rect(what, main.get_viewport().get_visible_rect().size).get_center()
	if what.begins_with("jcell"):   # ячейка сетки видов журнала ART-047
		return Journal.cell_rect(int(what.substr(5)), main.get_viewport().get_visible_rect().size).get_center()
	if what.begins_with("key"):   # клавиша экрана адреса: key0…key9, key., keydel
		var k := what.substr(3)
		for r in AddressPad.KEYS.size():
			var c: int = AddressPad.KEYS[r].find(k)
			if c >= 0:
				return AddressPad.key_rect(c, r, main.get_viewport().get_visible_rect().size).get_center()
	return main.get_viewport().get_visible_rect().get_center()


## Средние кадр/с с прошлого скриншота по своим замерам. Среднее движка — только когда своих кадров нет: оно за секунду
## считает и сам снимок (issue #281: «14b-hold-shelves» через 0,3 с после снимка — 4 к/с при худшем кадре 172 мс).
## Issue #435: после снимка, пока своих кадров нет (SETTLE_FRAMES), — -1 («—» в строке), а не среднее движка со снимком.
func fps() -> int:
	if frames < 1 or frames_us <= 0:
		return -1 if _shot_taken else roundi(Engine.get_frames_per_second())
	return roundi(frames * 1000000.0 / frames_us)


## Кадр/с для строки лога: число или «—» (сразу после снимка замера нет, issue #435).
func fps_text() -> String:
	var f := fps()
	return "—" if f < 0 else str(f)


## Состояние игры одной строкой для лога.
func state() -> String:
	var h := main.helm
	return "t %.1f с · %s · свет %s · глубина %.1f м · ход %.2f м/с · курс %d° · корабль (%.1f, %.1f, %.1f) · игрок (%.2f, %.2f) · реактор %s · %s кадр/с" % [
		time, "за штурвалом" if main.pilot.seated else ("у пульта энергии" if main.at_power else "на ногах"), "вкл" if main.light_on else "выкл", h.depth(), h.speed, Status.course_deg(h.yaw),
		h.pos.x, h.pos.y, h.pos.z, main.walker.x, main.walker.z, "%s %d°%s" % [str(main.reactor.share), roundi(main.reactor.heat), " сброс" if main.reactor.scram > 0.0 else ""], fps_text()] + worst_text() + ("" if main.breach.status().is_empty() else " · " + main.breach.status()) \
		+ _run_state()


## Худший кадр с прошлого скриншота для строки состояния: « · худший кадр 726 мс (шаг 53 press, логика 9 мс)».
func worst_text() -> String:
	return (" · худший кадр %d мс (%s)" % [roundi(worst_ms), worst_at] if worst_ms > 0.0 else "") \
		+ (" · после прыжка %d мс" % roundi(jump_ms) if jump_ms > 0.0 else "")


const PARTS_FROM := 20.0   ## код дольше, мс, — пишем его части (issue #627)


## Подпись к худшему кадру: шаг, код (шаг игры `Main.step` с живым миром), отрисовка на процессоре и, если драйвер умеет
## замерять, на видеокарте, мс (issue #217, #281). Долгий код — с частями шага `StepClock.note` (issue #627):
## «код 112 мс (мир 80, виды 20), …». Код и отрисовка малы, а кадр долгий — время ушло вне шага и
## отрисовки (физика, ввод, система). Замер видеокарты движок отдаёт с запаздыванием на несколько кадров: больше самого
## кадра frame (мс) — он от другого кадра, не пишем (issue #609).
static func worst_note(step: String, draw: float, code: float = -1.0, gpu: float = 0.0, frame := INF, parts := "",
		built := PackedInt32Array()) -> String:
	var d := "отрисовка %d мс" % roundi(draw)
	var b := pipes_note(built)
	if not b.is_empty():
		d += " (%s)" % b
	if code >= 0.0:
		d = "код %d мс%s, %s" % [roundi(code), " (%s)" % parts if not parts.is_empty() and code >= PARTS_FROM else "", d]
	if gpu > 0.0 and gpu <= frame + 1.0:
		d += ", видеокарта %d мс" % roundi(gpu)
	return step + ", " + d if not step.is_empty() else d


## Сборки шейдеров кадра по видам `PIPES` для лога: «сборок шейдеров 3: поверхности 2, при отрисовке 1»; нет — "".
## «При отрисовке» — то, что прогрев не собрал заранее и кадр ждал (issue #983).
static func pipes_note(built: PackedInt32Array) -> String:
	var n := 0
	var parts: Array[String] = []
	for i in mini(built.size(), PIPES.size()):
		if built[i] > 0:
			n += built[i]
			parts.append("%s %d" % [PIPES[i][1], built[i]])
	return "" if n == 0 else "сборок шейдеров %d: %s" % [n, ", ".join(parts)]


## Отрисовка прошлого кадра, мс — того же, чьё время меряет _measure (issue #609, `draw_ms`).
func render_ms() -> float:
	return draw_ms


func _on_pre_draw() -> void:
	_draw_from_us = Time.get_ticks_usec()


func _on_post_draw() -> void:
	if _draw_from_us > 0:
		draw_ms = (Time.get_ticks_usec() - _draw_from_us) / 1000.0
	for i in PIPES.size():   # сборки шейдеров этого кадра (issue #983)
		var t := RenderingServer.get_rendering_info(PIPES[i][0])
		pipes[i] = t - _pipes_total[i]
		_pipes_total[i] = t


## Код прошлого кадра: шаг игры `Main.step` (корабль, живой мир, виды), мс. Performance.TIME_PROCESS не годится —
## в него входит и отрисовка, и он обновляется не каждый кадр.
func code_ms() -> float:
	return main.step_ms if main != null else 0.0


## Отрисовка прошлого кадра на видеокарте, мс (0 — драйвер не замеряет).
func gpu_ms() -> float:
	if main == null or not main.is_inside_tree():
		return 0.0
	return RenderingServer.viewport_get_measured_render_time_gpu(main.get_viewport().get_viewport_rid())


## Шаг сценария, который сейчас идёт: «шаг 53 press».
static func step_label(q: QaScript) -> String:
	if q == null or q.steps.is_empty():
		return ""
	var i := mini(q.index, q.steps.size() - 1)
	return "шаг %d %s" % [i + 1, str((q.steps[i] as Dictionary).get("do", "?"))]


## Забег в логе: спуск, маршрут, решение у голостола.
func _run_state() -> String:
	var r := main.run
	if r.route < 0 and r.depth == 0:
		return ""
	var s := " · спуск %d" % (r.depth + 1)
	if r.route >= 0:
		s += " · " + r.status(main.helm.pos.x, main.helm.pos.z)
	if main.at_vote:
		s += " · итог забега" if r.ended else " · решение у голостола"
	return s


func _shot(name: String) -> void:
	var img: Image = null
	if DisplayServer.get_name() != "headless":
		img = main.get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		_log("скриншот %s: нет картинки (headless)" % name)
		return
	img.save_png("%s/%s.png" % [OUT, name])
	shots.append(name)
	_log("скриншот %s | %s" % [name, state()])
	after_shot()


## Кадр Google Play n (ART-046): снимок как есть — kadr-n-snimok.png, собранный кадр с подписью — kadr-n.png
## (подпись рисуется одним кадром позже, `PlayCaption`; в headless — лог без картинки, как у скриншота).
func _play(n: int) -> void:
	var name := PlayFrame.file_name(n)
	var img: Image = null
	if DisplayServer.get_name() != "headless":
		img = main.get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		_log("кадр %s: нет картинки (headless)" % name)
		return
	img.save_png("%s/%s-snimok.png" % [OUT, name])
	shots.append(name)
	_log("кадр %s «%s» | %s" % [name, PlayFrame.caption(n), state()])
	after_shot()
	composing += 1
	var cap: Image = await PlayCaption.render(self, PlayFrame.caption(n))
	PlayFrame.compose(img, cap).save_png("%s/%s.png" % [OUT, name])
	composing -= 1


## «quit»: дождаться сборки кадров Google Play (подпись рисуется кадр спустя), затем итог и выход.
func _quit_after_frames() -> void:
	while composing > 0:
		await get_tree().process_frame
	_finish()
	main.get_tree().quit()


## Сброс замеров после скриншота: кадр снимка не считается совсем, следующие SETTLE_FRAMES — только в худший кадр.
func after_shot() -> void:
	worst_ms = 0.0
	jump_ms = 0.0
	worst_at = ""
	frames = 0
	frames_us = 0
	_skip_frame = true
	_settle = SETTLE_FRAMES
	_shot_taken = true


## Отметка кадра прогрева: сколько прошло с прошлой (первая — от начала сценария).
func _warm_tick(now_us: int) -> void:
	_warm_ms.append((now_us - (_warm_last_us if _warm_last_us > 0 else _warm_from_us)) / 1000)
	_warm_last_us = now_us


## Строка лога «по кадрам»: ms[0] — от запуска сценария до первого кадра прогрева (сборка сцены, не кадр), дальше —
## кадры прогрева с единицы; самый долгий — номером в конце. Так чисел кадров столько же, сколько в заголовке
## «прогрев шейдеров: N кадров» (отчёт qa/2026-10-21-2310: 15 чисел при 14 кадрах).
static func warm_line(ms: Array[int]) -> String:
	if ms.is_empty():
		return "—"
	var head := "до первого кадра %d" % ms[0]
	if ms.size() < 2:
		return head
	var worst := 1
	var parts := PackedStringArray()
	for k in range(1, ms.size()):
		parts.append(str(ms[k]))
		if ms[k] > ms[worst]:
			worst = k
	return "%s; кадры: %s; худший — кадр %d из %d" % [head, ", ".join(parts), worst, ms.size() - 1]


func _log(line: String) -> void:
	log_lines.append(line)
	print("QA ", line)
	var f := FileAccess.open(OUT + "/log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines) + "\n")


func _finish() -> void:
	_log("Готово | " + state())
	main.timeline.save(Time.get_datetime_string_from_system(false, true))   # хронометраж забега прогона — qa/out/zabeg.txt
	var f := FileAccess.open(OUT + "/done.txt", FileAccess.WRITE)
	if f:
		f.store_string("ok\n")
