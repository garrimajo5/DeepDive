extends TestCase
## Интерфейс и связь SND-007 (#733): касания, кнопка поста, сообщение связи, тангента (`UiSound`, `UiSounds`).

const DT := 0.1


## Приёмка PR #1446: касание 2, пост 2, связь 1, тангента 1 (нажатие) и 2 (отпускание) — разовые, длина по заказу.
func test_files() -> void:
	var want := {UiSound.TAP: [0.08, 0.15], UiSound.POST: [0.15, 0.3], UiSound.COMMS: [0.5, 1.0],
		UiSound.KEY: [0.2, 0.4], UiSound.KEY_UP: [0.2, 0.4]}
	for path: String in want:
		var s := load(path) as AudioStreamWAV
		ok(s != null, "загружается: %s" % path)
		if s:
			eq(s.loop_mode, AudioStreamWAV.LOOP_DISABLED, "разовый, не петля: %s" % path)
			var r: Array = want[path]
			ok(s.get_length() >= r[0] - 0.01 and s.get_length() <= r[1] + 0.01, "длина: %s %.2f" % [path, s.get_length()])


func test_comms_due() -> void:
	var a := Comms.Msg.new()
	var b := Comms.Msg.new()
	ok(not UiSound.comms_due(null, true, null), "плашки нет — тихо")
	ok(UiSound.comms_due(a, true, null), "новое сообщение — щелчок линии")
	ok(not UiSound.comms_due(a, true, a), "то же сообщение — один раз")
	ok(not UiSound.comms_due(b, false, a), "отложено (меню, шторка) — ждём")
	ok(UiSound.comms_due(b, true, a), "показалось — звучит")


func test_key_edge() -> void:
	eq(UiSound.key_edge(false, false), 0, "тишина")
	eq(UiSound.key_edge(false, true), 1, "нажали «Говорить»")
	eq(UiSound.key_edge(true, true), 0, "держат — без повтора")
	eq(UiSound.key_edge(true, false), -1, "отпустили")


func test_node_buses_and_update() -> void:
	SoundMix.ensure()
	var u := UiSounds.new()
	tree.root.add_child(u)
	eq(String(u.tap_p.bus), SoundMix.UI, "касание — «Интерфейс»")
	eq(String(u.post_p.bus), SoundMix.UI, "пост — «Интерфейс»")
	for p: AudioStreamPlayer in [u.comms_p, u.key_p, u.key_up_p]:
		eq(String(p.bus), SoundMix.VOICE, "связь — «Голоса»: %s" % p.name)
	var m := Comms.Msg.new()
	u.update(m, true, false)
	ok(u.comms_p.playing, "сообщение пришло — линия")
	u.comms_p.stop()
	u.update(m, true, false)
	ok(not u.comms_p.playing, "один раз на сообщение")
	u.update(null, false, true)
	ok(u.key_p.playing, "нажали тангенту")
	u.update(null, false, true)
	u.update(null, false, false)
	ok(u.key_up_p.playing, "отпустили — щелчок отпускания")
	u.tap()
	u.tap()
	eq(u.taps, 1, "два касания вплотную — один щелчок")
	u.queue_free()
	await frames(1)


func test_scene_post_and_pause_taps() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var u := main.ui_sounds
	ok(u != null, "узел интерфейса есть")
	main.use_post("sonar")
	eq(u.posts, 1, "кнопка поста — щелчок")
	main.back_pressed()
	main.step(DT)
	ok(main.pause.open, "пауза открыта")
	var size := main.get_viewport().get_visible_rect().size
	main.overlay.router.taps.append(Vector2(-50, -50))   # мимо кнопок — тихо
	main.step(DT)
	eq(u.taps, 0, "мимо кнопки — без щелчка")
	main.overlay.router.taps.append(main.pause.rect("resume", size).get_center())
	main.step(DT)
	eq(u.taps, 1, "кнопка паузы — щелчок")
	ok(not main.pause.open, "и пауза закрылась")
	main.queue_free()
	await frames(1)


func test_scene_comms_line() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.comms.reset_run(0)
	main.on_eco_event(EcoLink.voice(Crew.Role.ENGINEER, "Сбросьте ход, перегрев"))
	for i in 4:
		main.step(DT)
	ok(main.comms.cur != null, "сообщение на плашке")
	eq(main.ui_sounds.heard, main.comms.cur, "линия щёлкнула на этом сообщении")
	main.queue_free()
	await frames(1)
