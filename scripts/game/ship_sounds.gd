class_name ShipSounds
extends Node
## Разовые звуки корабля SND-002 (#656) на шине «Корабль»: импульс сонара, удары по корпусу, скрежет о дно, удар о лёд и разряд (SND-003).
## Что и как громко — `HullSound`; сведение шины (пауза, меню, вид с борта) — `SoundMix.Mix`. У гостя сети пока молчат
## (удары и импульс считает хост).

var ping: AudioStreamPlayer
var hit: AudioStreamPlayer      ## удары — один плеер: новый удар обрывает хвост прошлого
var scrape: AudioStreamPlayer   ## скрежет под ударом о дно
var zap: AudioStreamPlayer      ## разряд по корпусу SND-003
var streams := {}               ## путь → AudioStream
var hits := 0                   ## счётчик ударов (HullSound.hit_index)
var last := ""                  ## что прозвучало последним (тесты)
var last_tail := ""             ## скрежет под последним ударом, пусто — без него (тесты)


func _init() -> void:
	name = "Звуки корабля"
	for path in [HullSound.PING, HullSound.SCRAPE, HullSound.ZAP] + HullSound.HITS:
		var s := load(path) as AudioStream
		if s:
			streams[path] = s
	ping = _player("Импульс сонара")
	hit = _player("Удары по корпусу")
	scrape = _player("Скрежет")
	zap = _player("Разряд")


func _player(title: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = title
	p.bus = SoundMix.SHIP
	add_child(p)
	return p


## Импульс сонара прошёл; jam — завяз в иле (глуше).
func play_ping(jam := false) -> void:
	_play(ping, HullSound.PING, HullSound.JAM_DB if jam else HullSound.PING_DB)


## Удар по корпусу (`Vitals.hit_taken`); at — точка удара в осях корабля (`HullSound.side`), null — не знаем.
func play_hit(percent: int, kind: String, at: Variant = null) -> void:
	var s := HullSound.for_hit(percent, kind, hits, at)
	if kind != "scrape" and not at is Vector3:
		hits += 1
	_play(hit, s["path"], s["db"])
	last_tail = s["tail"]
	if last_tail != "":
		var l := last
		_play(scrape, last_tail, s["tail_db"])
		last = l


## Разряд по корпусу прошёл (`Main.fire_zap`, SND-003).
func play_zap() -> void:
	_play(zap, HullSound.ZAP, HullSound.ZAP_DB)


## Корабль упёрся в лёд снизу со скоростью vy м/с (`Helm.Ship.knock`): прямой удар без урона, медленно — молча.
func play_ice(vy: float) -> void:
	var db := HullSound.ice_db(vy)
	if not is_nan(db):
		last_tail = ""
		_play(hit, HullSound.HITS[HullSound.Side.FRONT], db)


func _play(p: AudioStreamPlayer, path: String, db: float) -> void:
	last = path
	p.stream = streams.get(path)
	p.volume_db = db
	if p.stream and p.is_inside_tree():
		p.play()
