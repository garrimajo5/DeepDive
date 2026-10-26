class_name ShipSounds
extends Node
## Разовые звуки корабля SND-002 (#656) на шине «Корабль»: импульс сонара, удары по корпусу и скрежет о дно.
## Что и как громко — `HullSound`; сведение шины (пауза, меню, вид с борта) — `SoundMix.Mix`. У гостя сети пока молчат
## (удары и импульс считает хост).

var ping: AudioStreamPlayer
var hit: AudioStreamPlayer      ## удары и скрежет — один плеер: новый удар обрывает хвост прошлого
var streams := {}               ## путь → AudioStream
var hits := 0                   ## счётчик ударов (HullSound.hit_index)
var last := ""                  ## что прозвучало последним (тесты)


func _init() -> void:
	name = "Звуки корабля"
	for path in [HullSound.PING, HullSound.SCRAPE] + HullSound.HITS:
		var s := load(path) as AudioStream
		if s:
			streams[path] = s
	ping = _player("Импульс сонара")
	hit = _player("Удары по корпусу")


func _player(title: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = title
	p.bus = SoundMix.SHIP
	add_child(p)
	return p


## Импульс сонара прошёл; jam — завяз в иле (глуше).
func play_ping(jam := false) -> void:
	_play(ping, HullSound.PING, HullSound.JAM_DB if jam else HullSound.PING_DB)


## Удар по корпусу (`Vitals.hit_taken`).
func play_hit(percent: int, kind: String) -> void:
	var s := HullSound.for_hit(percent, kind, hits)
	if kind != "scrape":
		hits += 1
	_play(hit, s["path"], s["db"])


func _play(p: AudioStreamPlayer, path: String, db: float) -> void:
	last = path
	p.stream = streams.get(path)
	p.volume_db = db
	if p.stream and p.is_inside_tree():
		p.play()
