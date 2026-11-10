extends TestCase
## Файлы голосов эфира SND-009 (#1476): ID реплики TXT-002 → `audio/voice/<роль>-<m|f>/<id>.wav`, ID едет от
## `EcoLink.VOICE` до `Comms` и гостю сети; файла нет — без звука, только текст.

const DT := 1.0 / 30.0

var main: Main


func after() -> void:
	if main:
		main.queue_free()
		main = null
	await frames(1)


func test_names_as_in_order() -> void:   # примеры из таблицы «Файлы» SND-009
	eq(VoiceFiles.file_name("RADIO_TRUE_P01"), "true-p01")
	eq(VoiceFiles.file_name("RADIO_FAKE_LIGHT03"), "fake-light03")
	eq(VoiceFiles.file_name(""), "", "без ID — без озвучки")
	eq(VoiceFiles.file_name("Сбросьте ход"), "", "не ID")
	eq(VoiceFiles.folder(Crew.Role.PILOT, 0), "pilot-m")
	eq(VoiceFiles.folder(Crew.Role.SONAR, 1), "sonar-f")
	eq(VoiceFiles.folder(Crew.Role.ENGINEER, 1), "engineer-f")
	eq(VoiceFiles.folder(Crew.Role.BIOLOGIST, 0), "biolog-m")
	eq(VoiceFiles.path(Crew.Role.ENGINEER, 1, "RADIO_FAKE_PULSE03"), "res://audio/voice/engineer-f/fake-pulse03.wav")
	eq(VoiceFiles.path(Crew.Role.ENGINEER, 1, ""), "")


func test_every_echo_line_has_file_name() -> void:   # все реплики эхоловца (#1477) — с именем файла по своей роли
	var n := 0
	for ask in EcoEcho.FAKES:
		for v in EcoEcho.FAKES[ask]:
			var f := VoiceFiles.file_name(str(v[1]))
			ok(f.begins_with("fake-light") or f.begins_with("fake-pulse"), "подделка %s → %s" % [v[1], f])
			eq(VoiceFiles.true_role(str(v[1])), -1, "подделка — не настоящий доклад")
			n += 1
	for v in EcoEcho.REALS:
		ok(VoiceFiles.file_name(str(v[1])).begins_with("true-"), "доклад %s" % v[1])
		eq(VoiceFiles.true_role(str(v[1])), int(v[0]), "буква ID — роль доклада %s" % v[1])
		n += 1
	eq(n, 26, "10 подделок и 16 докладов")


func test_look_of_role_holder() -> void:
	var a := Crew.Member.new(Crew.Role.PILOT)
	var b := Crew.Member.new(Crew.Role.SONAR)
	b.look = 1
	eq(VoiceFiles.look_of(Crew.Role.SONAR, [a, b]), 1, "сонарщица — женский голос")
	eq(VoiceFiles.look_of(Crew.Role.PILOT, [a, b]), 0)
	eq(VoiceFiles.look_of(Crew.Role.BIOLOGIST, [a, b]), 0, "роли нет в экипаже — мужской")


func test_no_file_no_sound() -> void:   # голоса ещё не сданы — сообщение только текстом
	eq(VoiceFiles.stream(Crew.Role.PILOT, 0, "RADIO_TRUE_P02"), null)
	eq(VoiceFiles.stream(Crew.Role.PILOT, 0, ""), null)


func test_id_reaches_guest() -> void:
	var h := Comms.new()
	h.reset_run(0)
	var g := Comms.new()
	g.follow = true
	h.push(Crew.Role.BIOLOGIST, "Включите прожектор. Сейчас, пока можно.", true, "light", false, "RADIO_FAKE_LIGHT03")
	h.update(DT, false)
	g.apply(h.pack())
	eq(g.cur.voice_id, "RADIO_FAKE_LIGHT03", "гость знает реплику — свой голос сыграет сам")


func test_scene_event_id_to_comms() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.comms.reset_run(0)
	main.on_eco_event(EcoLink.voice(Crew.Role.PILOT, "Сонарщик, я на связи.", false, "", false, "RADIO_TRUE_P04"))
	main.step(DT)
	var m: Comms.Msg = main.comms.cur if main.comms.cur != null else main.comms.queue.back()
	eq(m.voice_id, "RADIO_TRUE_P04", "ID события мира — в сообщении связи")
