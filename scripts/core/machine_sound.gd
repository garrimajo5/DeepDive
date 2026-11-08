class_name MachineSound
extends RefCounted
## Машины корабля SND-005 (#706): роторы на ходу, гул реактора в машинном, зуммер перегрева и пар вентиля сброса.
## Здесь — файлы и громкости по состоянию; играет `scripts/game/machine_sounds.gd` (`main.machine_sounds`) на шине
## «Корабль», каждый шаг из `Main._sound`. Петли — WAV с кроссфейдом стыка (приёмка, `docs/zvuk/SND-005.md`).

const ENGINES := "res://audio/ship/engines.wav"
const REACTOR := "res://audio/ship/reactor-hum.wav"
const BUZZ := "res://audio/ship/overheat-buzz.wav"
const STEAM := "res://audio/ship/steam-valve.wav"
const FILES: Array[String] = [ENGINES, REACTOR, BUZZ, STEAM]

## Роторы (`HullMesh.Motion.spin`): за обшивкой, слышно по всему кораблю, тон и громкость — по оборотам.
const SPIN_MIN := 0.05       ## доля оборотов: меньше — молча
const ENG_SOFT_DB := -24.0   ## на SPIN_MIN
const ENG_DB := -11.0        ## на полных оборотах — под гулом корабля SND-001 (−12 дБ) чуть громче
const PITCH_LOW := 0.85      ## тон на SPIN_MIN
const PITCH_HIGH := 1.12     ## тон на полных оборотах

## Реактор: 3D у `ShipLayout.REACTOR_POS` — громко в машинном, на мостике едва.
const REACTOR_AT := ShipLayout.REACTOR_POS + Vector3(0.0, 1.2, 0.0)
const REACTOR_DB := -4.0
const REACTOR_HOT_DB := 4.0  ## прибавка на 100° перегрева
const REACTOR_UNIT := 4.0    ## м: ближе — в полную (`unit_size`)
const REACTOR_FAR := 22.0    ## м: дальше — молча (`max_distance`), мостик в носу — у края

## Зуммер перегрева — на весь корабль, пока `Reactor.hot` и нет аварийного сброса.
const BUZZ_DB := -14.0

## Пар вентиля: 3D у сопла (`ValveSteam.NOZZLE`), пока `EngineRoom.venting`.
const STEAM_DB := -2.0
const STEAM_UNIT := 3.0
const STEAM_FAR := 18.0

const FADE := 0.25           ## с: подъём и спад петель (без щелчка)


## Громкость роторов по доле оборотов spin (−1…1, задний ход — по модулю); меньше SPIN_MIN — NAN (молча).
static func engines_db(spin: float) -> float:
	var s := absf(spin)
	if s < SPIN_MIN:
		return NAN
	return lerpf(ENG_SOFT_DB, ENG_DB, clampf((s - SPIN_MIN) / (1.0 - SPIN_MIN), 0.0, 1.0))


## Тон роторов по доле оборотов.
static func engines_pitch(spin: float) -> float:
	return lerpf(PITCH_LOW, PITCH_HIGH, clampf((absf(spin) - SPIN_MIN) / (1.0 - SPIN_MIN), 0.0, 1.0))


## Гул реактора: заглушён (scram) — NAN (молча), иначе громче с нагревом при перегреве.
static func reactor_db(hot: bool, heat: float, scram: float) -> float:
	if scram > 0.0:
		return NAN
	return REACTOR_DB + (REACTOR_HOT_DB * clampf(heat / 100.0, 0.0, 1.0) if hot else 0.0)


## Зуммер звучит при перегреве, но не во время аварийного сброса (там тревога — «Аварийный сброс»).
static func buzz_on(hot: bool, scram: float) -> bool:
	return hot and scram <= 0.0


## Доля громкости петли 0…1 к цели on за шаг dt (подъём и спад за FADE).
static func fade(gain: float, on: bool, dt: float) -> float:
	return move_toward(gain, 1.0 if on else 0.0, dt / FADE)
