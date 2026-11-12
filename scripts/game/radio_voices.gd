class_name RadioVoices
extends Node
## Голоса внутренней связи SND-009 (#1476): реплика на плашке ART-040 (`Comms.cur`) с ID TXT-002 звучит своим файлом
## (`VoiceFiles.stream` по роли сообщения и внешности того, кто держит роль) на шине «Эфир» (`SoundMix.radio_bus` —
## обработка рации). У хоста и в одиночной игре речь сообщения — длина файла (`Comms.set_voice`), гостю она едет
## в снимке связи. Файла нет — тишина, только текст. Плашка отложена (меню, пауза) — голос на паузе; разоблачение
## «Это был не наш», «Понятно» или смена сообщения — голос смолкает. Шаг — `update` из `Main._sound`.

var player: AudioStreamPlayer
var msg: Object = null      ## сообщение, для которого выбран файл
var started := false        ## голос этого сообщения уже запущен (второй раз не начинается)
var plays := 0              ## сколько реплик зазвучало (для тестов: в headless `playing` ненадёжен)


func _init() -> void:
	name = "Голоса эфира"
	player = AudioStreamPlayer.new()
	player.name = "Реплика"
	player.volume_db = VoiceFiles.RADIO_DB
	add_child(player)


func _ready() -> void:
	SoundMix.radio_bus()
	player.bus = SoundMix.RADIO


## Шаг: comms — связь (`main.comms`), crew — экипаж (внешность говорящей роли, `VoiceFiles.look_of`).
func update(comms: Comms, crew: Array) -> void:
	var cur := comms.cur
	if cur != msg:
		msg = cur
		started = false
		player.stop()
		player.stream = null
		if cur != null and cur.voice_id != "":
			var s := VoiceFiles.stream(cur.role, VoiceFiles.look_of(cur.role, crew), cur.voice_id)
			player.stream = s
			if s != null and not comms.follow:   # гость берёт речь из кадра хоста
				comms.set_voice(cur, VoiceFiles.length(s))
	if player.stream == null or cur == null:
		return
	if comms.closing or comms.state == Comms.Ask.EXPOSED:   # разоблачили или закрыли — замолкает
		if player.playing:
			player.stop()
		return
	if not started and comms.shown and comms.a > 0.0:
		started = true
		plays += 1
		if player.is_inside_tree():
			player.play()
	player.stream_paused = not comms.shown
