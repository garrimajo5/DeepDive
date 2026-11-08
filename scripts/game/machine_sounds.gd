class_name MachineSounds
extends Node3D
## Машины корабля SND-005 (#706) на шине «Корабль»: роторы, гул реактора, зуммер перегрева, пар вентиля.
## Узел — в осях корабля (`main.ship`), реактор и пар звучат из своих мест. Громкости — `MachineSound`; шаг —
## `update` из `Main._sound`. Сведение шины (пауза, меню, вид с борта) — `SoundMix.Mix`.

var engines: AudioStreamPlayer     ## роторы за обшивкой
var reactor: AudioStreamPlayer3D   ## гул реактора в машинном
var buzz: AudioStreamPlayer        ## зуммер перегрева
var steam: AudioStreamPlayer3D     ## пар вентиля сброса
## Доли громкости петель 0…1 (плавный подъём и спад, MachineSound.FADE) и последняя громкость, на которой спадают.
var gain := {"engines": 0.0, "reactor": 0.0, "buzz": 0.0, "steam": 0.0}
var level := {"engines": MachineSound.ENG_SOFT_DB, "reactor": MachineSound.REACTOR_DB,
	"buzz": MachineSound.BUZZ_DB, "steam": MachineSound.STEAM_DB}


func _init() -> void:
	name = "Машины корабля"
	engines = AudioStreamPlayer.new()
	engines.name = "Роторы"
	_setup(engines, MachineSound.ENGINES)
	reactor = _spatial("Гул реактора", MachineSound.REACTOR, MachineSound.REACTOR_AT, MachineSound.REACTOR_UNIT,
		MachineSound.REACTOR_FAR)
	buzz = AudioStreamPlayer.new()
	buzz.name = "Зуммер перегрева"
	_setup(buzz, MachineSound.BUZZ)
	steam = _spatial("Пар вентиля", MachineSound.STEAM, ValveSteam.NOZZLE, MachineSound.STEAM_UNIT,
		MachineSound.STEAM_FAR)


func _spatial(title: String, path: String, at: Vector3, unit: float, far: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = title
	p.position = at
	p.unit_size = unit
	p.max_distance = far
	_setup(p, path)
	return p


func _setup(p: Node, path: String) -> void:
	p.set("bus", SoundMix.SHIP)
	var s := load(path) as AudioStreamWAV
	if s and s.loop_mode == AudioStreamWAV.LOOP_DISABLED:   # петля и в импорте (loop_mode=2); здесь — на случай сброса
		s = s.duplicate() as AudioStreamWAV
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(round(s.get_length() * s.mix_rate))
	p.set("stream", s)
	add_child(p)


## Шаг: spin — доля оборотов роторов (`HullMesh.Motion.spin`), состояние реактора и вентиля.
func update(dt: float, spin: float, hot: bool, heat: float, scram: float, venting: bool) -> void:
	var eng := MachineSound.engines_db(spin)
	_loop(engines, "engines", eng, dt)
	engines.pitch_scale = MachineSound.engines_pitch(spin)
	_loop(reactor, "reactor", MachineSound.reactor_db(hot, heat, scram), dt)
	_loop(buzz, "buzz", MachineSound.BUZZ_DB if MachineSound.buzz_on(hot, scram) else NAN, dt)
	_loop(steam, "steam", MachineSound.STEAM_DB if venting else NAN, dt)


## Петля к громкости db (NAN — молча) с плавным подъёмом и спадом; на нуле останавливается.
func _loop(p: Node, key: String, db: float, dt: float) -> void:
	gain[key] = MachineSound.fade(gain[key], not is_nan(db), dt)
	if gain[key] <= 0.0:
		if p.get("playing"):
			p.call("stop")
		return
	if not is_nan(db):
		level[key] = db
	p.set("volume_db", level[key] + linear_to_db(gain[key]))
	if not p.get("playing") and p.get("stream") and p.is_inside_tree():
		p.call("play")
