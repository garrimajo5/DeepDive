class_name Ambience
extends Node
## Постоянный фон забега (SND-001 #655): эмбиент за бортом на шине «Эмбиент» и гул корабля на шине «Корабль».
## Петли — `SoundMix.SHELF_LOOP`/`DEEP_LOOP`/`HUM_LOOP`; доли отмели и глубины ставит `Main._sound` (`set_pair`),
## громкость шин по состоянию игры — `SoundMix.Mix`.

var shelf: AudioStreamPlayer   ## петля Подлёдного сада
var deep: AudioStreamPlayer    ## петля глубины — null, пока файла нет
var hum: AudioStreamPlayer     ## гул корабля изнутри


func _init() -> void:
	name = "Фон"
	shelf = _player("Эмбиент отмели", SoundMix.SHELF_LOOP, SoundMix.AMBIENT, SoundMix.AMBIENT_DB)
	if ResourceLoader.exists(SoundMix.DEEP_LOOP):
		deep = _player("Эмбиент глубины", SoundMix.DEEP_LOOP, SoundMix.AMBIENT, SoundMix.MUTE_DB)
	hum = _player("Гул корабля", SoundMix.HUM_LOOP, SoundMix.SHIP, SoundMix.HUM_DB)


func _ready() -> void:
	for p in [shelf, deep, hum]:
		if p and p.stream:
			p.play()


func _player(title: String, path: String, bus: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = title
	p.bus = bus
	p.volume_db = db
	var s := load(path) as AudioStream
	if s and "loop" in s:
		s.loop = true   # петля и в импорте (loop=true), здесь — на случай сброшенного .import
	p.stream = s
	add_child(p)
	return p


## Доли петель [отмель, глубина] (`SoundMix.Mix.ambient_pair`) → громкость плееров эмбиента.
func set_pair(pair: Vector2) -> void:
	var k := SoundMix.loop_k(pair, deep != null)
	shelf.volume_db = SoundMix.AMBIENT_DB + SoundMix.to_db(k.x)
	if deep:
		deep.volume_db = SoundMix.AMBIENT_DB + SoundMix.to_db(k.y)
