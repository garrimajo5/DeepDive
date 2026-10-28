class_name MenuFlow
extends RefCounted
## Экраны меню поверх сцены `Main` (#753): главное меню ART-037, настройки (страницы «Графика» ART-044, «Звук»,
## «Голос» ART-041), предложение «Экономно» ART-044, «Журнал экспедиции» ART-047. У каждого экрана один рисунок:
## открыть → `*_show` (панель) → шаг (касания `Touch.Router.taps` → `hit` → `press` → `*_do`). Состояние экранов —
## поля `main.main_menu`, `main.settings`, `main.lite_offer`, `main.logbook`, панели — `main.menu_panel`,
## `main.settings_panel`, `main.lite_offer_panel`, `main.logbook_panel`. Уровень графики ставит `Main._apply_graphics`.
## Живёт полем `main.menu_flow`; входы для тестов и `tools/` — тонкие пересылки у `Main`.

const CONTINUE_MSG := "Ковчег на месте сохранения"

var main: Main


func _init(m: Main) -> void:
	main = m


func _size() -> Vector2:
	return main.get_viewport().get_visible_rect().size


## Главное меню ART-037 поверх сцены (после заставки прогрева — сразу под ней). Игра под меню стоит.
func open_menu() -> void:
	main.main_menu.open = true
	main.save.live = false   # корабль под меню у начала спуска — сохранённое место не перетирать (#823)
	main.main_menu.can_continue = not main.save.ship.is_empty()
	if main.menu_panel == null:
		main.menu_panel = MenuPanel.new()
		main.menu_panel.version = str(ProjectSettings.get_setting("application/config/version", "?"))
		main.add_child(main.menu_panel)
	main.menu_panel.show_menu(main.main_menu)
	main.overlay.visible = false
	if main.hint:
		main.hint.visible = false   # строки приборов не лезут к шапкам меню, сбора и журнала (#571)


## Шаг под меню: касания кнопок. «Погрузиться» — забег с начала (облёт, часы забега), палец с кнопки не идёт в игру.
func menu_step(dt: float = 0.0) -> void:
	var r := main.overlay.router
	if main.settings.open:
		settings_step(r)
		r.end_frame()
		return
	if main.address.open:
		main.lobby_flow.address_step(r, dt)
		r.end_frame()
		return
	if main.lobby.open:
		main.lobby_flow.lobby_step(r, dt)
		r.end_frame()
		return
	if main.logbook.open:
		journal_step(r)
		r.end_frame()
		return
	for p in r.taps:
		var what := main.main_menu.press(main.main_menu.hit(p, _size()))
		if what == "dive":
			close_menu()
			main.save.live = true
			main._begin_run()
			break
		if what == "continue":
			close_menu()
			continue_run()
			break
		if what == "crew":
			main.open_lobby()
			break
		if what == "journal":
			open_journal()
			break
		if what == "settings":
			open_settings()
			break
	r.end_frame()


func close_menu() -> void:
	main.main_menu.open = false
	main.address.open = false
	main.lobby.open = false
	if main.lobby_panel:
		main.lobby_panel.show_lobby(main.lobby)
	main.logbook.open = false
	if main.logbook_panel:
		journal_show()
	if main.menu_panel:
		main.menu_panel.show_menu(main.main_menu)
	if main.address_panel:
		main.address_panel.show_screen(main.address)
	main.overlay.router.clear()   # палец ещё на кнопке: не крестовина и не касание, пропускающее облёт
	main.overlay.visible = not main.wreck.active()
	main.hint.visible = not main.wreck.active() and not main.pause.open


## «Продолжить» (#823): забег с сохранённого места — корабль стоит там, курс, корпус и заряд из файла, без облёта.
func continue_run() -> void:
	var m := main
	m.save.live = true
	m.flyby.stop()   # облёт, начатый при запуске под меню
	if not SaveGame.ship_apply(m.save.ship, m.helm, m.vitals):
		m._begin_run()
		return
	m.wear.snap(m.vitals.hull)
	m.window_fog.snap(m.helm.depth(), m.vitals.hull, m.reactor.heat, m.reactor.scram)
	m._begin_run(false)
	m.say(CONTINUE_MSG)


## Забег окончен, в главное меню: встать с постов, корабль у начала спуска, без облёта.
func to_menu() -> void:
	main.save.live = false   # «Забег будет потерян»: корабль у начала спуска не перетирает сохранённое место
	main._leave_posts()
	main._restart()
	main.flyby.stop()
	open_menu()


## Настройки ART-037 поверх главного меню (на его фоне) или паузы (над затемнённой сценой); «Назад» вернёт к ним.
func open_settings() -> void:
	main.settings.show()
	settings_show()
	main.overlay.router.clear()   # палец с кнопки «Настройки» не берёт ползунок


func settings_show() -> void:
	if main.settings_panel == null:
		main.settings_panel = SettingsPanel.new()
		main.add_child(main.settings_panel)
	main.settings.mic_ok = main.radio.mic   # статус микрофона на странице «Голос» ART-041
	main.settings_panel.show_settings(main.settings)
	if main.menu_panel:   # над главным меню — его фон без кнопок
		main.menu_panel.visible = main.main_menu.open and not main.address.open
		main.menu_panel.draw.visible = not main.settings.open
	if main.pause_panel:
		main.pause_panel.visible = main.pause.open and not main.settings.open and not main.ship_map.open


## Шаг настроек: касания кнопок, палец на ползунке двигает значение; изменения — сразу в игру и в файл
## (ползунок — когда палец отпущен).
func settings_step(r: Touch.Router) -> void:
	var size := _size()
	var settings := main.settings
	for p in r.taps:
		var id := settings.hit(p, size)
		var what := settings.press(id, p, size)
		if id == "swipe" or Settings.is_volume(id):
			apply_settings()
			continue
		settings_do(what)
		if what == "back":
			break
	if settings.grab != "":
		var pts := r.points()
		if pts.is_empty():
			settings.grab = ""
			settings.write()
		elif settings.drag(pts[0], size):
			apply_settings()
	settings_show()


## Что сказали настройки: сохранить и применить, стереть сохранение забега, вернуться.
func settings_do(what: String) -> void:
	match what:
		"changed":
			apply_settings()
			main.settings.write()
		"graphics":
			apply_settings()
			main.settings.write()
		"wipe":
			main.save.reset(main.samples, main.scanner)
			main.say("Сохранение сброшено")
		"back":
			main.settings.write()
			settings_show()
			main.overlay.router.clear()   # палец с «Назад» не нажимает кнопку меню под ним


## Громкость шины Master, чувствительность свайпа, уровень графики ART-044; облёт читает `_begin_run`.
func apply_settings() -> void:
	var settings := main.settings
	AudioServer.set_bus_volume_db(0, Settings.volume_db(settings.volume))
	if main.overlay:
		main.overlay.swipe = settings.swipe
	if main.graphics_level != settings.graphics:
		main._apply_graphics(settings.graphics)
	if main.fps_view:
		main.fps_view.visible = settings.fps
	var radio := main.radio
	radio.mode = settings.voice_mode   # страница «Голос» ART-041: режим, приём и микрофон — независимо
	radio.hear = settings.hear
	radio.mic_on = settings.mic_on
	radio.volume = settings.mates


## Предложение «Экономно» ART-044: открыть после низких кадр/с, когда ничего не мешает (не на «Экономно», не под
## тревогой, меню, паузой, настройками, облётом, голосованием, шторками; тестер — только шагом `slow`); касания —
## «Да» / «Нет». true — диалог открыт (ввод этого кадра в игру не идёт).
func offer_step() -> bool:
	var m := main
	var blocked := not Main.offer or m.qa != null or m.alarms_on().has(true) or m.main_menu.open or m.pause.open \
		or m.settings.open or m.warm.active() or m.flyby.active() or m.wreck.active() or m.at_vote or m.run.ended \
		or (m.net_client != null and m.drop.active())
	var lite_offer := m.lite_offer
	lite_offer.update(m.graphics_level, m.settings.lite_no, blocked)
	if lite_offer.open:
		for p in m.overlay.router.taps:
			var what := lite_offer.press(lite_offer.hit(p, _size()))
			if what != "":
				offer_do(what)
				break
	if m.lite_offer_panel:
		m.lite_offer_panel.show_offer(lite_offer)
	return lite_offer.open


## Ответ на предложение: «Да» — «Экономно» сразу и в настройки, «Нет» — больше не предлагать.
func offer_do(what: String) -> void:
	match what:
		"yes":
			main.settings.graphics = Graphics.ECONOMY
			apply_settings()
			main.say("Графика: «Экономно»")
		"no":
			main.settings.lite_no = true
		_:
			return
	main.settings.write()
	if main.lite_offer_panel:
		main.lite_offer_panel.show_offer(main.lite_offer)
	main.overlay.router.clear()   # палец с кнопки не идёт в игру


## «Журнал экспедиции» ART-047 поверх главного меню: история `expedition`, изученные виды, груз трюма.
func open_journal() -> void:
	main.logbook.show()
	journal_show()
	main.overlay.router.clear()


func journal_show() -> void:
	var m := main
	if m.logbook_panel == null:
		m.logbook_panel = JournalPanel.new()
		m.add_child(m.logbook_panel)
	m.logbook.blank = Journal.empty(m.expedition, m.scanner.scanned.size(), m.samples.cargo.size())
	m.logbook_panel.show_journal(m.logbook, m.expedition, m.scanner, Species.count(), m.samples.cargo.size(),
		m.save.state == SaveGame.Load.BROKEN)
	if m.menu_panel:
		m.menu_panel.visible = m.main_menu.open and not m.logbook.open and not m.address.open


## Шаг журнала: касание места — название под картой, вида — карточка или подсказка, «Ранее» / «Далее», «Назад» — в меню.
func journal_step(r: Touch.Router) -> void:
	var m := main
	for p in r.taps:
		var did := m.logbook.press(m.logbook.hit(p, _size()), m.scanner.scanned, m.expedition)
		if did in ["card", "back"]:   # карточка открыта/закрыта, журнал закрыт: палец не нажмёт то, что под ним
			m.overlay.router.clear()
			break
	if not m.logbook.open:   # прочитанные карточки («новое» снято) — в файл, пока меню стоит
		m.save.flush(m.samples, m.scanner)
	journal_show()
