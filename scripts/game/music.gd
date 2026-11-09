class_name Music
extends Node
## Музыка SND-004 (#658): тема главного меню и напряжение (тревога, «Корпус разрушен») — петли на шине «Музыка».
## Громкость шины по состоянию игры ведёт `SoundMix.Mix`, какая петля звучит — `Mix.music_pair` (`Main._sound`).
## Петля с долей 0 стоит на паузе: когда вернётся — продолжит с того же места, не с начала.

var menu: AudioStreamPlayer      ## тема главного меню
var tension: AudioStreamPlayer   ## напряжение


func _init() -> void:
	name = "Музыка"
	menu = _player("Тема меню", SoundMix.MENU_MUSIC)
	tension = _player("Напряжение", SoundMix.TENSION_MUSIC)


func _player(title: String, path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = title
	p.bus = SoundMix.MUSIC
	p.volume_db = SoundMix.MUTE_DB
	p.stream_paused = true   # молчит, пока сведение не даст ей долю
	var s := load(path) as AudioStream
	if s and "loop" in s:
		s.loop = true   # петля и в импорте (loop=true), здесь — на случай сброшенного .import
	p.stream = s
	add_child(p)
	return p


## Доли [тема меню, напряжение] → громкость плееров; молчащая петля — на паузе.
func set_pair(pair: Vector2) -> void:
	_level(menu, SoundMix.MENU_DB, pair.x)
	_level(tension, SoundMix.TENSION_DB, pair.y)


func _level(p: AudioStreamPlayer, db: float, k: float) -> void:
	p.volume_db = db + SoundMix.to_db(k)
	var on := k > 0.001 and p.stream != null
	if not on:
		p.stream_paused = true
	elif p.stream_paused:
		p.stream_paused = false
		if not p.playing:
			p.play()
	elif not p.playing:
		p.play()


## Звучит ли петля (для тестов и лога): играет и не на паузе.
static func sounding(p: AudioStreamPlayer) -> bool:
	return p.playing and not p.stream_paused
