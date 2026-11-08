class_name UiSounds
extends Node
## Интерфейс и связь SND-007 (#733): касания меню и постов — шина «Интерфейс», сообщение связи и тангента рации —
## шина «Голоса». Числа и правила — `UiSound`; касания — `tap`/`post` из мест нажатия, связь и рация — `update`
## из `Main._sound`.

var tap_p: AudioStreamPlayer
var post_p: AudioStreamPlayer
var comms_p: AudioStreamPlayer
var key_p: AudioStreamPlayer
var key_up_p: AudioStreamPlayer
var taps := 0              ## сколько щелчков касания прозвучало (для тестов)
var posts := 0
var heard: Object = null   ## сообщение связи, на котором уже прозвучало (`UiSound.comms_due`)
var keyed := false         ## рация хотела передавать в прошлом шаге
var _since_tap := INF


func _init() -> void:
	name = "Звуки интерфейса"   # не «Интерфейс»: так зовут CanvasLayer панелей
	tap_p = _player("Касание", UiSound.TAP, SoundMix.UI, UiSound.TAP_DB)
	post_p = _player("Пост", UiSound.POST, SoundMix.UI, UiSound.POST_DB)
	comms_p = _player("Связь", UiSound.COMMS, SoundMix.VOICE, UiSound.COMMS_DB)
	key_p = _player("Тангента", UiSound.KEY, SoundMix.VOICE, UiSound.KEY_DB)
	key_up_p = _player("Тангента отпущена", UiSound.KEY_UP, SoundMix.VOICE, UiSound.KEY_DB)


func _player(title: String, path: String, bus: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = title
	p.bus = bus
	p.volume_db = db
	p.stream = load(path) as AudioStream
	add_child(p)
	return p


func _process(dt: float) -> void:
	_since_tap += dt


## Касание кнопки меню, паузы, настроек, журнала (попали в кнопку — `hit` не пуст).
func tap() -> void:
	if _since_tap < UiSound.TAP_GAP:
		return
	_since_tap = 0.0
	taps += 1
	_play(tap_p)


## Кнопка действия у поста (`Main.use_post`).
func post() -> void:
	posts += 1
	_play(post_p)


## Шаг: cur/shown — сообщение на плашке связи и показана ли она, wants — рация хочет передавать (`Radio.wants`).
func update(cur: Object, shown: bool, wants: bool) -> void:
	if UiSound.comms_due(cur, shown, heard):
		heard = cur
		_play(comms_p)
	match UiSound.key_edge(keyed, wants):
		1:
			_play(key_p)
		-1:
			_play(key_up_p)
	keyed = wants


func _play(p: AudioStreamPlayer) -> void:
	if p.stream and p.is_inside_tree():
		p.play()
