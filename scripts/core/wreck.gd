class_name Wreck
extends RefCounted
## Шторка «Корпус разрушен» по ART-036 (`docs/concept-art/korpus-razrushen.md`): 3,5 с поверх живой сцены — трещины
## `textures/korpus/treshchiny.png` по всему экрану, виньетка #0B1C24, янтарный заголовок и подпись; плафоны гаснут
## (множитель `lamps` поверх `Vitals.lamp_k`); в 3,2…3,5 с всё уходит под сплошную шторку, в RESTART_AT — `_restart`,
## потом шторка тает за FADE_OUT. Пока шторка идёт (`active`), ввод не идёт в игру, крестовина и кнопка скрыты.
## Здесь — время и доли без узлов; рисует `scripts/game/wreck_view.gd` (`main.wreck_view`). Макет 2400×1080 — как `Splash`.

const CRACKS := "res://textures/korpus/treshchiny.png"
const DARK := Color("#0B1C24")      ## виньетка и сплошная шторка
const AMBER := Color("#FFB259")     ## заголовок — янтарь табло ART-025
const INK := Color("#D5E4E8")       ## подпись

const TITLE := "Корпус разрушен"
const SUB := "Ковчег поднимают к началу спуска"
const TITLE_PX := 104.0
const SUB_PX := 48.0
const TITLE_TOP := 430.0   ## верх глифов заголовка, центр по x 1200
const SUB_TOP := 580.0
const SHIFT_PX := 4.0      ## один сдвиг слоя трещин в начале и возврат
const W_CENTER := 1200.0  ## центр надписей по x в макете

## Время, с.
const HIT := 0.15          ## удар: трещины до 0,6, виньетка 0,12 от конечной, сдвиг
const TEXT_IN := 0.4       ## надписи проявились
const DARK_AT := 1.0       ## трещины 0,9, виньетка 0,6, плафоны погасли
const FULL_AT := 1.5       ## виньетка в полную силу
const OUT_AT := 3.2        ## надписи и трещины уходят, сплошная шторка наплывает
const RESTART_AT := 3.5    ## шторка сплошная — забег с начала
const FADE_OUT := 0.3      ## затем шторка тает
const END := RESTART_AT + FADE_OUT

## Плафоны: провал к LAMP_DIP за 0,1 с после TEXT_IN, частичный возврат к LAMP_BACK в 0,6 с, темнота к DARK_AT.
const LAMP_DIP := 0.15
const LAMP_BACK := 0.55

var t := -1.0          ## секунд с начала шторки; < 0 — шторки нет
var restarted := false


func start() -> void:
	t = 0.0
	restarted = false


func reset() -> void:
	t = -1.0
	restarted = false


## Шторка идёт (с первого кадра до конца таяния).
func active() -> bool:
	return t >= 0.0 and t < END


## Шаг шторки. Возвращает true ровно один раз — в шаг, когда шторка стала сплошной: пора `_restart`.
func update(dt: float) -> bool:
	if t < 0.0:
		return false
	t += dt
	if not restarted and t >= RESTART_AT:
		restarted = true
		return true
	if t >= END:
		t = -1.0
	return false


## Гость ставит время шторки из кадра хоста (`NetSnap.events`, "w"): < 0 — шторки нет.
func follow(host_t: float) -> void:
	if host_t < 0.0:
		reset()
		return
	if t < 0.0 or host_t < t:
		restarted = false
	t = host_t


## Непрозрачность трещин 0…1.
static func cracks(time: float) -> float:
	if time < 0.0 or time >= RESTART_AT:
		return 0.0
	if time < HIT:
		return 0.6 * time / HIT
	if time < TEXT_IN:
		return 0.6
	if time < DARK_AT:
		return lerpf(0.6, 0.9, (time - TEXT_IN) / (DARK_AT - TEXT_IN))
	if time < OUT_AT:
		return 0.9
	return lerpf(0.9, 0.0, (time - OUT_AT) / (RESTART_AT - OUT_AT))


## Доля конечной виньетки 0…1 (сама виньетка — `vignette_alpha`).
static func vignette(time: float) -> float:
	if time < 0.0 or time >= RESTART_AT:
		return 0.0
	if time < HIT:
		return 0.12 * time / HIT
	if time < TEXT_IN:
		return 0.12
	if time < DARK_AT:
		return lerpf(0.12, 0.6, (time - TEXT_IN) / (DARK_AT - TEXT_IN))
	if time < FULL_AT:
		return lerpf(0.6, 1.0, (time - DARK_AT) / (FULL_AT - DARK_AT))
	return 1.0


## Непрозрачность виньетки в точке экрана uv (0…1 по обеим осям) при полной силе — формула художника:
## a = 0,58 + 0,35 · clamp(((x−1200)/1200)² + ((y−540)/540)², 0, 1). Двойник шейдера `shaders/wreck_vignette.gdshader`.
static func vignette_alpha(uv: Vector2) -> float:
	var d := (uv * 2.0 - Vector2.ONE)
	return 0.58 + 0.35 * clampf(d.x * d.x + d.y * d.y, 0.0, 1.0)


## Непрозрачность надписей 0…1: читаются с TEXT_IN.
static func text(time: float) -> float:
	if time < HIT or time >= RESTART_AT:
		return 0.0
	if time < TEXT_IN:
		return (time - HIT) / (TEXT_IN - HIT)
	if time < OUT_AT:
		return 1.0
	return 1.0 - (time - OUT_AT) / (RESTART_AT - OUT_AT)


## Непрозрачность сплошной шторки #0B1C24: наплывает в OUT_AT…RESTART_AT, тает за FADE_OUT.
static func solid(time: float) -> float:
	if time < OUT_AT or time >= END:
		return 0.0
	if time < RESTART_AT:
		return (time - OUT_AT) / (RESTART_AT - OUT_AT)
	return 1.0 - (time - RESTART_AT) / FADE_OUT


## Сдвиг слоя трещин в px макета: один толчок на SHIFT_PX вправо-вниз и возврат за HIT.
static func shift(time: float) -> Vector2:
	if time <= 0.0 or time >= HIT:
		return Vector2.ZERO
	return Vector2(SHIFT_PX, SHIFT_PX * 0.5) * sin(PI * time / HIT)


## Множитель плафонов 0…1: до TEXT_IN горят, провал, частичный возврат в 0,6 с, темнота к DARK_AT —
## до сплошной шторки; после `_restart` — снова свет.
static func lamps(time: float) -> float:
	if time < TEXT_IN or time >= RESTART_AT:
		return 1.0
	if time < TEXT_IN + 0.1:
		return lerpf(1.0, LAMP_DIP, (time - TEXT_IN) / 0.1)
	if time < 0.6:
		return lerpf(LAMP_DIP, LAMP_BACK, (time - TEXT_IN - 0.1) / (0.6 - TEXT_IN - 0.1))
	if time < DARK_AT:
		return lerpf(LAMP_BACK, 0.0, (time - 0.6) / (DARK_AT - 0.6))
	return 0.0
