class_name HandSounds
extends Node3D
## Руки экипажа SND-006 (#719) на шине «Корабль»: сварка у шва, сканер за работой, «вид изучен». Узел — в осях
## корабля (`main.ship`). Числа — `HandSound`; шаг — `update` из `Main._sound` (по прошлому шагу).

var weld: AudioStreamPlayer3D   ## сварка пробоины — у шва
var scan: AudioStreamPlayer3D   ## сканер работает — у поста
var done: AudioStreamPlayer3D   ## вид изучен — у поста, один раз
var gain := {"weld": 0.0, "scan": 0.0}
var done_seen := 0              ## счётчик изученного, на котором уже прозвенели (`Scanner.done` + `GateDiag.done`)


func _init() -> void:
	name = "Руки экипажа"
	weld = _player("Сварка", HandSound.WELD, Vector3.ZERO, HandSound.WELD_UNIT, HandSound.WELD_FAR, true)
	scan = _player("Сканер", HandSound.SCAN, HandSound.SCAN_AT, HandSound.SCAN_UNIT, HandSound.SCAN_FAR, true)
	done = _player("Вид изучен", HandSound.DONE, HandSound.SCAN_AT, HandSound.SCAN_UNIT, HandSound.SCAN_FAR, false)
	done.volume_db = HandSound.DONE_DB


func _player(title: String, path: String, at: Vector3, unit: float, far: float, loop: bool) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = title
	p.position = at
	p.unit_size = unit
	p.max_distance = far
	p.bus = SoundMix.SHIP
	var s := load(path) as AudioStreamWAV
	if s and loop and s.loop_mode == AudioStreamWAV.LOOP_DISABLED:   # петля и в импорте (loop_mode=2)
		s = s.duplicate() as AudioStreamWAV
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(round(s.get_length() * s.mix_rate))
	p.stream = s
	add_child(p)
	return p


## Шаг: weld_at — точка шва (INF — никто не варит), scanning — сканер переводит вид или гнездо, scanned — счётчик
## изученного (растёт — «вид изучен»).
func update(dt: float, weld_at: Vector3, scanning: bool, scanned: int) -> void:
	var welding := weld_at.is_finite()
	if welding:
		weld.position = weld_at
	_loop(weld, "weld", welding, HandSound.WELD_DB, dt)
	_loop(scan, "scan", scanning, HandSound.SCAN_DB, dt)
	if scanned > done_seen and done.stream and done.is_inside_tree():
		done.play()
	done_seen = scanned


func _loop(p: AudioStreamPlayer3D, key: String, on: bool, db: float, dt: float) -> void:
	gain[key] = HandSound.fade(gain[key], on, dt)
	if gain[key] <= 0.0:
		if p.playing:
			p.stop()
		return
	p.volume_db = db + linear_to_db(gain[key])
	if not p.playing and p.stream and p.is_inside_tree():
		p.play()
