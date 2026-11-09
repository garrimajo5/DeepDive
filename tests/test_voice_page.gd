extends TestCase
## Страница «Настройки · Голос» ART-041: раскладка, режим, приём и микрофон, ползунок товарищей, файл, рация.

var main: Main


func after() -> void:
	Main.menu = false
	Main.intro = false
	if main:
		main.queue_free()
		main = null
	await frames(1)


func test_layout_fits_phones() -> void:
	for size: Vector2 in [Vector2(2400, 1080), Vector2(1600, 720), Vector2(1920, 1080), Vector2(2340, 1080)]:
		var screen := Rect2(Vector2.ZERO, size)
		var ids: Array = VoicePage.IDS + ["v_state"]
		for i in ids.size():
			var r := VoicePage.screen_rect(ids[i], size)
			ok(r.size.x > 0.0 and screen.encloses(r), "%s на экране %s" % [ids[i], size])
			for j in range(i + 1, ids.size()):
				ok(not r.intersects(VoicePage.screen_rect(ids[j], size)), "%s и %s не налезают" % [ids[i], ids[j]])
	ok(VoicePage.NOTE_TOP > VoicePage.HOLD.end.y and VoicePage.NOTE_TOP + VoicePage.NOTE_PX < VoicePage.HEAR.position.y,
		"подпись режима — между режимом и переключателями")
	eq(VoicePage.hit(VoicePage.screen_rect("v_state", Vector2(1600, 720)).get_center(), Vector2(1600, 720)), "",
		"статус микрофона — не кнопка")


func test_texts() -> void:
	eq(VoicePage.state_text(true), "Разрешён", "микрофон разрешён")
	eq(VoicePage.state_text(false), "Нет доступа", "нет разрешения")
	eq(VoicePage.hear_text(true), "Звук товарищей: вкл.", "приём")
	eq(VoicePage.mic_text(false), "Микрофон: выкл.", "микрофон")
	eq(VoicePage.note(Radio.Mode.VOICE), "По голосу: передача при вашей речи", "подпись «По голосу» по макету")


func test_press_and_back() -> void:
	var s := Settings.new()
	var size := Vector2(1600, 720)
	s.show()
	eq(s.hit(Settings.screen_rect("golos", size).get_center(), size), "golos", "«Голос» на основной странице")
	eq(s.press("golos"), "", "открыть страницу")
	eq(s.page, "golos", "страница «Голос»")
	eq(s.hit(VoicePage.screen_rect("v_voice", size).get_center(), size), "v_voice", "касание режима")
	eq(s.press("v_voice"), "changed", "«По голосу»")
	eq(s.voice_mode, Radio.Mode.VOICE, "режим «По голосу»")
	eq(s.press("v_voice"), "", "повторное касание ничего не меняет")
	eq(s.press("v_hear"), "changed", "приём")
	ok(not s.hear and s.mic_on, "звук товарищей выкл., микрофон — независимо вкл.")
	eq(s.press("v_mic"), "changed", "микрофон")
	ok(not s.mic_on, "микрофон выкл.")
	var right := Splash.to_screen(Vector2(VoicePage.TRACK_X.y, VoicePage.TRACK_Y), size)
	eq(s.hit(right, size), "mates", "дорожка громкости товарищей")
	eq(s.press("mates", right, size), "changed", "касание ставит значение")
	eq(s.mates, 1.0, "правый край — 100 %")
	ok(s.drag(Splash.to_screen(Vector2(lerpf(VoicePage.TRACK_X.x, VoicePage.TRACK_X.y, 0.25), VoicePage.TRACK_Y),
		size), size), "палец ведёт ползунок")
	near(s.mates, 0.25, 1e-5, "четверть дорожки — 25 %")
	eq(s.value_text("mates"), "25 %", "подпись значения")
	near(s.volume, Settings.VOLUME_DEFAULT, 1e-5, "общая громкость не тронута")
	eq(s.back(), "", "системная «Назад» — к основной странице")
	ok(s.open and s.page == "" and s.grab == "", "основная страница, ползунок отпущен")
	s.press("golos")
	eq(s.press("back"), "", "экранная «Назад»")
	ok(s.open and s.page == "", "снова основная")


func test_file_roundtrip() -> void:
	var path := "user://test_golos.cfg"
	var s := Settings.new()
	s.path = path
	s.set_mates(0.4)
	s.voice_mode = Radio.Mode.VOICE
	s.hear = false
	s.mic_on = false
	ok(s.write(), "записано")
	var t := Settings.new()
	t.path = path
	ok(t.read(), "прочитано")
	near(t.mates, 0.4, 1e-5, "громкость товарищей")
	eq(t.voice_mode, Radio.Mode.VOICE, "режим")
	ok(not t.hear and not t.mic_on, "приём и микрофон")
	DirAccess.remove_absolute(path)
	var u := Settings.new()
	eq(u.voice_mode, Radio.Mode.HOLD, "по умолчанию — «Нажать и держать»")
	ok(u.hear and u.mic_on, "по умолчанию приём и микрофон включены")
	near(u.mates, 0.7, 1e-5, "громкость товарищей 70 % — как в макете")


func _tap(p: Vector2, finger: int) -> void:
	var r := main.overlay.router
	r.begin(finger, p)
	main.step(1.0 / 30.0)
	r.end(finger)
	main.step(1.0 / 30.0)


func test_scene_applies_to_radio() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var size := main.get_viewport().get_visible_rect().size
	main.back_pressed()
	_tap(main.pause.rect("settings", size).get_center(), 1)
	_tap(Settings.screen_rect("golos", size).get_center(), 2)
	eq(main.settings.page, "golos", "страница «Голос» открыта")
	ok(main.settings_panel.visible, "на экране")
	_tap(VoicePage.screen_rect("v_voice", size).get_center(), 3)
	eq(main.radio.mode, Radio.Mode.VOICE, "рация — «По голосу»")
	eq(main.radio.button_text(), "Микрофон", "кнопка рации — «Микрофон»")
	_tap(VoicePage.screen_rect("v_hear", size).get_center(), 4)
	ok(not main.radio.hear, "рация не слышит товарищей")
	_tap(VoicePage.screen_rect("v_mic", size).get_center(), 5)
	ok(not main.radio.mic_on, "микрофон выключен")
	var r := main.overlay.router
	r.begin(6, Splash.to_screen(Vector2(VoicePage.TRACK_X.x, VoicePage.TRACK_Y), size))
	main.step(1.0 / 30.0)
	eq(main.radio.volume, 0.0, "громкость товарищей — в рацию, пока палец ведёт")
	r.end(6)
	main.step(1.0 / 30.0)
	eq(main.settings.grab, "", "палец отпущен")
	main.radio.mic = false
	main._settings_show()
	ok(not main.settings.mic_ok, "статус микрофона — из рации")
	main.back_pressed()
	ok(main.settings.open and main.settings.page == "", "«Назад» — к основной странице")
	main.back_pressed()
	ok(not main.settings.open and main.pause.open, "ещё раз — пауза")
