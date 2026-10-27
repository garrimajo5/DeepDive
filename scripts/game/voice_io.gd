class_name VoiceIO
extends Node
## Голос рации ART-041 узлами (#634): захват микрофона и проигрыватели голосов товарищей. Числа — `Voice.Station`.
## Захват: шина `MIC_BUS` с `AudioEffectCapture`, на ней `AudioStreamMicrophone`; шина в −80 дБ (громкость шины
## Godot ставит после эффектов — захват полный, себя игрок не слышит). Микрофон включается, только когда игрок
## хочет говорить (`Radio.wants()`, на Android — только с разрешением `RECORD_AUDIO`, `MicPermit`) и в проекте
## включён ввод (`audio/driver/enable_input`); иначе захвата нет, `Radio.link` — false.
## Проигрыватели: по `AudioStreamGenerator` на место в экипаже на шине «Голоса» (`SoundMix.VOICE`), громкость —
## `Radio.volume`, «Звук товарищей» выкл. — тишина. Нет проигрывателя (сервер звука без вывода) — голос идёт по
## времени шага, `Radio.heard` всё равно получает говорящих.

const MIC_BUS := "Микрофон"
const BUFFER := 0.1          ## буфер генератора, с

var station := Voice.Station.new()
var mic_player: AudioStreamPlayer
var capture: AudioEffectCapture
var players := {}            ## место в экипаже → AudioStreamPlayer


static func input_on() -> bool:
	return bool(ProjectSettings.get_setting("audio/driver/enable_input", false))


func _init() -> void:
	name = "Голос"


## Шаг: свой голос в сеть, голоса товарищей в проигрыватели и в список рации. `radio` — `main.radio`, `crew` —
## экипаж (имя и роль говорящего), `me` — своё место, `send` — куда пакет (Callable(p)), `packets` — принятые
## [[место, пакет], …], `sight` — место → в поле зрения.
func step(dt: float, radio: Radio, online: bool, send: Callable, packets: Array, crew: Array, me: int,
		sight: Callable) -> void:
	var talk := radio.wants()
	_mic(talk)
	var frames := PackedVector2Array()
	if capture != null and talk:
		frames = capture.get_buffer(capture.get_frames_available())
	elif capture != null:
		capture.clear_buffer()
	var out := station.outgoing(frames, AudioServer.get_mix_rate(), dt, talk, radio.mode == Radio.Mode.VOICE, online)
	for p in out:
		send.call(p)
	radio.link = station.link
	station.incoming(packets)
	for who: int in station.room.decoders:
		if who == me:
			continue
		_play(who, dt, radio)
	for v in station.voices():
		var who: int = v[0]
		if who == me or who < 0 or who >= crew.size():
			continue
		var m: Crew.Member = crew[who]
		radio.heard(who, m.name, m.role, v[1], bool(sight.call(who)))


func _mic(on: bool) -> void:
	if not on or not input_on():
		if mic_player != null and mic_player.playing:
			mic_player.stop()
		return
	if mic_player == null:
		SoundMix.ensure()
		var i := AudioServer.get_bus_index(MIC_BUS)
		if i < 0:
			AudioServer.add_bus()
			i = AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, MIC_BUS)
			AudioServer.set_bus_send(i, "Master")
			capture = AudioEffectCapture.new()
			AudioServer.add_bus_effect(i, capture)
		else:
			capture = AudioServer.get_bus_effect(i, 0) as AudioEffectCapture
		AudioServer.set_bus_volume_db(i, SoundMix.MUTE_DB)
		mic_player = AudioStreamPlayer.new()
		mic_player.name = "Микрофон"
		mic_player.stream = AudioStreamMicrophone.new()
		mic_player.bus = MIC_BUS
		add_child(mic_player)
	if not mic_player.playing:
		mic_player.play()


func _play(who: int, dt: float, radio: Radio) -> void:
	var p: AudioStreamPlayer = players.get(who)
	if p == null:
		SoundMix.ensure()
		p = AudioStreamPlayer.new()
		p.name = "Голос %d" % who
		p.bus = SoundMix.VOICE
		var g := AudioStreamGenerator.new()
		g.mix_rate = AudioServer.get_mix_rate()
		g.buffer_length = BUFFER
		p.stream = g
		players[who] = p
		add_child(p)
		if p.is_inside_tree():
			p.play()
	p.volume_db = SoundMix.to_db(radio.volume) if radio.hear else SoundMix.MUTE_DB
	var pb := p.get_stream_playback() as AudioStreamGeneratorPlayback if p.playing else null
	if pb != null:
		var n := pb.get_frames_available()
		if n > 0:
			pb.push_buffer(station.pull(who, n, AudioServer.get_mix_rate()))
	else:   # нет вывода звука — голос идёт по времени шага, говорящие всё равно видны
		station.pull(who, int(dt * Voice.RATE), Voice.RATE)
