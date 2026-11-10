class_name LockWater
extends RefCounted
## Вода в шахте нижнего шлюза по ART-073 (`docs/concept-art/shlyuz-voda.md`). Логика без узлов: видимость по крышке,
## сила ряби по ходу, корпусу и удару, события троса (вход — кольца, выход — всплеск) по пересечению глади захватом.
## Рисует `scripts/game/lock_water_view.gd` одной плоскостью (шейдер `shaders/lock_water.gdshader`, карты
## `textures/shlyuz/`), слой корабля, без огней.

const RIPPLE := "res://textures/shlyuz/ripple.png"   ## нормали ряби (данные, не цвет)
const RINGS := "res://textures/shlyuz/rings.png"     ## атлас 4×4: R — гребень, A — маска
const SIZE := 2.2                                    ## плоскость, м: запас уходит под стенки шахты
const Y := Airlock.Y + 0.03                          ## уровень воды в осях корабля (−1,12)
const CENTER := Vector3(0.0, Y, Airlock.Z)
const SHOW_FROM := 0.02                              ## крышка открыта меньше — воды не видно
const SHOW_FULL := 0.20
const RING_S := 1.4                                  ## кольца от входа троса
const SPLASH_S := 0.8                                ## всплеск при выходе захвата (след — до END_S)
const END_S := 1.4
const HIT_S := 0.65                                  ## затухание ряби от удара по корпусу
const LITE_K := 0.625                                ## «Экономно» (ART-044): рябь слабее
const WEAK_EXIT := 0.5                               ## выход без образца — всплеск слабее
const LAMP_COLOR := Color("C6D6DE")                  ## блик потолочной полосы трюма

enum Kind { ENTER, EXIT }

var lite := false
var event_age := -1.0      ## с от последнего события троса; < 0 — событий нет
var event_kind := Kind.ENTER
var event_k := 1.0         ## сила события (выход без образца — слабее)
var event_xz := Vector2.ZERO   ## где трос пересёк гладь, в осях корабля
var events := 0            ## сколько событий было (для тестов)
var hit_age := -1.0        ## с от удара по корпусу; < 0 — не было
var _hook_y := NAN         ## прошлая высота захвата


## Доля видимости по открытию крышки (Airlock.t): закрыто — 0, плоскость скрыта.
static func shown(lock_t: float) -> float:
	if lock_t <= SHOW_FROM:
		return 0.0
	return smoothstep(SHOW_FROM, SHOW_FULL, lock_t)


## Сила ряби: ход корабля, износ корпуса, удар (один раз по событию, затухает). «Экономно» — × LITE_K.
func amplitude(speed: float, hull: float) -> float:
	var a := 1.20 + 0.80 * clampf(absf(speed) / 5.0, 0.0, 1.0) + 0.30 * (1.0 - clampf(hull / 100.0, 0.0, 1.0))
	if hit_age >= 0.0:
		a += 1.10 * exp(-hit_age / HIT_S)
	return a * (LITE_K if lite else 1.0)


## Удар по корпусу (Vitals.hit_taken): рябь вспыхивает и гаснет.
func on_hit() -> void:
	hit_age = 0.0


## Шаг: lock_t — открытие крышки, hook — захват лебёдки в осях корабля (Samples.hook_local), carrying — несёт образец.
## Пересечение уровня воды вниз — «вход» (кольца), вверх — «выход» (всплеск). Неподвижный трос событий не даёт.
func update(dt: float, lock_t: float, hook: Vector3, carrying: bool) -> void:
	if event_age >= 0.0:
		event_age += dt
		if event_age > END_S:
			event_age = -1.0
	if hit_age >= 0.0:
		hit_age += dt
		if hit_age > HIT_S * 8.0:
			hit_age = -1.0
	var was := _hook_y
	_hook_y = hook.y
	if is_nan(was) or shown(lock_t) <= 0.0:
		return
	if absf(hook.x - CENTER.x) > SIZE * 0.5 or absf(hook.z - CENTER.z) > SIZE * 0.5:
		return
	if was > Y and hook.y <= Y:
		_event(Kind.ENTER, 1.0, hook)
	elif was < Y and hook.y >= Y:
		_event(Kind.EXIT, 1.0 if carrying else WEAK_EXIT, hook)


func _event(kind: Kind, k: float, hook: Vector3) -> void:
	event_kind = kind
	event_k = k
	event_age = 0.0
	event_xz = Vector2(hook.x, hook.z)
	events += 1


## Где событие на плоскости, UV 0…1 (U — X корабля, V — Z).
func event_uv() -> Vector2:
	return (event_xz - Vector2(CENTER.x, CENTER.z) + Vector2.ONE * SIZE * 0.5) / SIZE


## Новый забег: тихая вода.
func reset() -> void:
	event_age = -1.0
	hit_age = -1.0
	_hook_y = NAN


## Цвет воды по глубине корабля: туман ART-059 × 0,65 (центр темнее — в шейдере).
static func color(depth: float) -> Color:
	var c := Seabed.Water.fog_color(depth) * 0.65
	c.a = 1.0
	return c


## Полоса плафона на потолке трюма (отражается в воде): центр в осях корабля и полуразмеры x/z.
static func lamp() -> Array:
	var cargo: Array = ShipLayout.ROOMS[ShipLayout.Room.CARGO]
	var z0 := float(cargo[0])
	var z1 := float(cargo[1])
	return [Vector3(0.0, float(cargo[3]) - 0.02, (z0 + z1) * 0.5), Vector2(0.72, (z1 - z0 - 0.6) * 0.5 + 0.2)]
