class_name WaterGlints
extends RefCounted
## Блики воды в мостике по ART-067 (`docs/concept-art/bliki-vody.md`): маска каустик `textures/bridge/bliki-maska.png`
## в материале потолка и пола мостика (`shaders/ship_surface.gdshader`, uniform `glint_*`), без новых огней и вызовов.
## Здесь — числа и то, что считается на CPU раз в кадр: сила по глубине, ил, авария, мигание; оттенок воды; зона по z.
## Шейдер повторяет `zone`, `facing` и `flow` (двойники ниже — для тестов). Ставит `BridgeView.set_glints` из `Main._glints`.

const TILE := 3.2                         ## плитка маски, м
const FLOW_A := Vector2(0.012, 0.007)     ## первая выборка: сдвиг UV в секунду (≈ 0,04 м/с)
const FLOW_B := Vector2(-0.006, 0.011)    ## вторая — зеркальная по x, свой сдвиг
const B_OFFSET := 0.37
const MIX := Vector2(0.6, 0.4)            ## доли выборок A и B
const ZONE := Vector4(-6.7, -5.8, -1.0, 3.0)  ## z мостика в осях корабля: нарастает −6,7…−5,8, гаснет −1…3
const FLOOR := 0.6                        ## пол слабее потолка (потолок ×1, стены — 0)
## [глубина, сила] — линейно между ключами, выше 8 м — как на 8 м, глубже 90 м — 0 (не умножать на `Water.caustic`).
const KEYS := [[8.0, 0.12], [20.0, 0.06], [45.0, 0.002], [90.0, 0.0]]
const WHITE := 0.65                       ## оттенок: цвет воды по max RGB, смешанный с белым
const SILT := 0.98                        ## ил гасит: × (1 − 0,98·Silt.k)
const ALARM := 0.9                        ## авария: × (1 − 0,9·тревога)
const ALARM_TAU := 0.3                    ## огибающая тревоги, с
const MIN_K := 0.0001                     ## слабее — шейдер не читает маску

var alarm := 0.0     ## огибающая тревоги 0…1 (пробоина открыта — растёт к 1)
var lite := false    ## «Экономно» (ART-044): бликов нет


## Сила по глубине корабля, м.
static func strength(depth: float) -> float:
	return HashNoise.keyed(KEYS, depth, 1, 0.0)


## Оттенок бликов: цвет воды на глубине (`Seabed.Water.fog_color`), нормированный на max RGB, 65 % белого.
static func tint(depth: float) -> Color:
	var c := Seabed.Water.fog_color(depth)
	var m := maxf(c.r, maxf(c.g, c.b))
	if m > 0.0:
		c = Color(c.r / m, c.g / m, c.b / m)
	return c.lerp(Color.WHITE, WHITE)


## Шаг огибающей тревоги: on — открыта пробоина (у гостя — из кадра).
func step(dt: float, on: bool) -> void:
	alarm = lerpf(alarm, 1.0 if on else 0.0, 1.0 - exp(-dt / ALARM_TAU))


## Итоговая сила: глубина, ил 0…1, мигание плафонов lamp_k (Vitals.lamp_k × шторка), огибающая тревоги.
func k(depth: float, silt: float, lamp_k: float) -> float:
	if lite:
		return 0.0
	var v := strength(depth) * (1.0 - SILT * clampf(silt, 0.0, 1.0)) * (1.0 - ALARM * alarm) * clampf(lamp_k, 0.0, 1.0)
	return v if v >= MIN_K else 0.0


## Зона мостика по z в осях корабля: 0 за пределами, 1 в середине (двойник шейдера).
static func zone(z: float) -> float:
	return (1.0 - smoothstep(ZONE.z, ZONE.w, z)) * smoothstep(ZONE.x, ZONE.y, z)


## Грань по нормали y: потолок (вниз) — 1, пол (вверх) — 0,6, стены — 0.
static func facing(normal_y: float) -> float:
	if normal_y < -0.5:
		return 1.0
	return FLOOR if normal_y > 0.5 else 0.0


## UV двух выборок маски для точки корабля xz на время t, с (время непрерывное — без смены кадров).
static func flow(xz: Vector2, t: float) -> Array[Vector2]:
	var q := xz / TILE
	return [q + FLOW_A * t, q * Vector2(-1.0, 1.0) + FLOW_B * t + Vector2(B_OFFSET, B_OFFSET)]


## Узор маски в точке (двойник шейдера, без зоны и силы): mask — L8 `bliki-maska.png`.
static func pattern(mask: Image, xz: Vector2, t: float) -> float:
	var uv := flow(xz, t)
	return MIX.x * _sample(mask, uv[0]) + MIX.y * _sample(mask, uv[1])


static func _sample(img: Image, uv: Vector2) -> float:
	var w := img.get_width()
	var h := img.get_height()
	var x := posmod(int(floor(uv.x * w)), w)
	var y := posmod(int(floor(uv.y * h)), h)
	return img.get_pixel(x, y).r
