extends TestCase
## Голоса связи SND-009 до файлов (#632, #1476): реплика с ID звучит своим WAV на шине «Эфир» (обработка рации),
## речь — длина файла; файла нет — только текст. WAV синтетический во временной папке, `audio/voice/` не трогаем.

const DIR := "user://test_radio_voices"
const LEN := 3.0   ## длина синтетической реплики, с (не совпадает с речью по тексту)
const ID := "RADIO_TRUE_E01"

var node: RadioVoices


func before() -> void:
	VoiceFiles.root = DIR
	DirAccess.make_dir_recursive_absolute(DIR + "/engineer-f")
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 8000
	var data := PackedByteArray()
	data.resize(int(LEN * 8000) * 2)
	w.data = data
	eq(w.save_to_wav(DIR + "/engineer-f/" + VoiceFiles.file_name(ID) + ".wav"), OK, "синтетический WAV записан")


func after() -> void:
	VoiceFiles.root = VoiceFiles.DIR
	if node:
		node.queue_free()
		node = null
	var d := DirAccess.open(DIR + "/engineer-f")
	if d:
		for f in d.get_files():
			d.remove(f)
	DirAccess.remove_absolute(DIR + "/engineer-f")
	DirAccess.remove_absolute(DIR)
	await frames(1)


func _engineer(look: int) -> Array:
	var m := Crew.Member.new()
	m.role = Crew.Role.ENGINEER
	m.look = look
	return [m]


func test_stream_from_folder() -> void:
	var s := VoiceFiles.stream(Crew.Role.ENGINEER, 1, ID)
	ok(s != null, "файл в папке роли и внешности найден")
	near(VoiceFiles.length(s), LEN, 0.05, "длина файла")
	eq(VoiceFiles.stream(Crew.Role.ENGINEER, 0, ID), null, "у мужского голоса файла нет — только текст")
	eq(VoiceFiles.length(null), 0.0)


func test_speech_by_file() -> void:
	var c := Comms.new()
	var m := c.push(Crew.Role.ENGINEER, "Сбросьте ход")
	var by_text := m.speech
	c.set_voice(m, 0.0)
	eq(m.speech, by_text, "нет файла — речь по тексту")
	c.set_voice(m, 6.5)
	eq(m.speech, 6.5, "речь — длина файла")
	eq(m.show_time(), 6.5 + Comms.AFTER_SPEECH, "показ — речь + после речи")


func test_radio_bus() -> void:
	var i := SoundMix.radio_bus()
	eq(SoundMix.radio_bus(), i, "второй вызов шину не добавляет")
	eq(String(AudioServer.get_bus_send(i)), SoundMix.VOICE, "«Эфир» идёт в «Голоса» — их ползунок и сведение")
	eq(AudioServer.get_bus_effect_count(i), 3, "срез низа, верха и перегруз")
	ok(AudioServer.get_bus_effect(i, 0) is AudioEffectHighPassFilter, "срез низа")
	ok(AudioServer.get_bus_effect(i, 1) is AudioEffectLowPassFilter, "срез верха")
	ok(AudioServer.get_bus_effect(i, 2) is AudioEffectDistortion, "перегруз")


func test_plays_with_file() -> void:
	node = RadioVoices.new()
	tree.root.add_child(node)
	await frames(1)
	eq(String(node.player.bus), SoundMix.RADIO, "реплика — на шине «Эфир»")
	var c := Comms.new()
	var m := c.push(Crew.Role.ENGINEER, "Сбросьте ход", false, "", false, ID)
	c.update(0.1, false)
	node.update(c, _engineer(1))
	ok(node.player.stream != null, "файл выбран")
	near(m.speech, LEN, 0.05, "речь — длина файла")
	eq(node.plays, 1, "зазвучала")
	node.update(c, _engineer(1))
	eq(node.plays, 1, "второй раз не начинается")
	c.update(0.1, true)
	node.update(c, _engineer(1))
	ok(node.player.stream_paused, "плашка отложена — голос на паузе")
	c.update(0.1, false)
	node.update(c, _engineer(1))
	ok(not node.player.stream_paused, "плашка снова — голос дальше")


func test_silent_without_file() -> void:
	node = RadioVoices.new()
	tree.root.add_child(node)
	await frames(1)
	var c := Comms.new()
	var m := c.push(Crew.Role.ENGINEER, "Сбросьте ход", false, "", false, ID)
	var by_text := m.speech
	c.update(0.1, false)
	node.update(c, _engineer(0))   # мужской голос — файла нет
	ok(node.player.stream == null, "без файла — без звука")
	eq(m.speech, by_text, "речь по тексту")
	eq(node.plays, 0)


func test_guest_keeps_host_speech() -> void:
	node = RadioVoices.new()
	tree.root.add_child(node)
	await frames(1)
	var c := Comms.new()
	c.follow = true
	c.apply({"k": "Иней", "m": [5, Crew.Role.ENGINEER, "Сбросьте ход", false, "", 0.0, 4.2, 0, 0.0, false, 0, ID]})
	c.update(0.1, false)
	node.update(c, _engineer(1))
	eq(c.cur.speech, 4.2, "гость: речь из кадра хоста")
	eq(node.plays, 1, "гость слышит голос сам")


func test_exposed_stops() -> void:
	node = RadioVoices.new()
	tree.root.add_child(node)
	await frames(1)
	var c := Comms.new()
	c.push(Crew.Role.ENGINEER, "Сбросьте ход", true, "", false, ID)
	c.update(0.1, false)
	node.update(c, _engineer(1))
	eq(node.plays, 1)
	c.state = Comms.Ask.EXPOSED
	node.update(c, _engineer(1))
	ok(not node.player.playing, "разоблачили — голос смолк")
	c.state = Comms.Ask.NONE
	node.update(c, _engineer(1))
	eq(node.plays, 1, "после разоблачения не начинается заново")


func test_main_has_voices() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/game/main.gd")
	ok(src.contains("radio_voices.update(comms, crew)"), "Main ведёт голоса связи в `_sound`")
