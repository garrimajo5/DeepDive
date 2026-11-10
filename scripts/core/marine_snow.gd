class_name MarineSnow
## Взвесь за бортом по ART-058 (`docs/concept-art/vzves.md`): атлас 4×4 в «Морском снеге» `OceanView` — один узел,
## один материал (`shaders/marine_snow.gdshader`, атлас `textures/vzves/atlas.png`). Кадр выбирается один раз при
## рождении по долям семей; размер, оседание и вращение — по семье. Частица несёт случайное r 0…1
## (`INSTANCE_CUSTOM.z` — смещение анимации CPUParticles3D), шейдер выводит из него всё остальное.
## Числа шейдера повторены здесь, чтобы их проверяли тесты.

const ATLAS := "res://textures/vzves/atlas.png"
const GRID := 4                      ## атлас 4×4, ячейка 128²
const COLOR := Color("D5E4E8")       ## RGB атласа постоянный, форму несёт альфа
const AMOUNT := 420                  ## потолок частиц, как прежний снег
const AMOUNT_LITE := 180             ## «Экономно» (ART-044): реже и без вращения
const EXTENTS := Vector3(28, 14, 28) ## объём 56 × 28 × 56 м вокруг корабля, мировые координаты
const LIFETIME := 15.0               ## жизнь 12–18 с: середина, появление и угасание мягкие
const FADE_IN := 0.12                ## доля жизни на появление
const FADE_OUT := 0.85               ## с этой доли — угасание
const NEAR := Vector2(0.5, 1.5)      ## у самой камеры гаснут — не лезут в стекло

enum Family { FLAKE, THREAD, DUST, BUBBLE }

## Семьи: ячейки атласа, доля каждой ячейки, видимая форма (м), доля формы в карточке,
## вертикальная скорость (м/с, + вверх), вращение (°/с; у нитей — размах качания).
const FAMILIES := {
	Family.FLAKE: {"cells": [0, 1, 2, 3, 4, 5], "share": 0.09, "form": Vector2(0.025, 0.07), "card": 0.78,
		"vy": Vector2(-0.06, -0.02), "spin": Vector2(2.0, 8.0)},
	Family.THREAD: {"cells": [6, 7, 8], "share": 0.04, "form": Vector2(0.05, 0.12), "card": 0.84,
		"vy": Vector2(-0.03, 0.0), "spin": Vector2(4.0, 10.0)},
	Family.DUST: {"cells": [9, 10, 11], "share": 0.10, "form": Vector2(0.008, 0.018), "card": 0.55,
		"vy": Vector2(-0.06, 0.06), "spin": Vector2(0.0, 0.0)},
	Family.BUBBLE: {"cells": [12, 13, 14], "share": 0.04 / 3.0, "form": Vector2(0.015, 0.05), "card": 0.78,
		"vy": Vector2(0.10, 0.25), "spin": Vector2(0.0, 0.0)},
}


## Семья ячейки атласа (15 — пустая, не выбирается).
static func family(cell: int) -> int:
	if cell <= 5:
		return Family.FLAKE
	if cell <= 8:
		return Family.THREAD
	if cell <= 11:
		return Family.DUST
	return Family.BUBBLE


## Доля ячейки среди рождений.
static func share(cell: int) -> float:
	if cell < 0 or cell > 14:
		return 0.0
	return FAMILIES[family(cell)]["share"]


## Накопленные доли ячеек 0…14 (последняя = 1): шейдер берёт первую ячейку, где r < cdf[i].
static func cdf() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var acc := 0.0
	for i in 15:
		acc += share(i)
		out.append(acc)
	out[14] = 1.0
	return out


## Ячейка по случайному r 0…1 — как в шейдере.
static func cell_of(r: float) -> int:
	var c := cdf()
	for i in 15:
		if r < c[i]:
			return i
	return 14


## UV угла ячейки в атласе (размер ячейки — 1/GRID).
static func cell_uv(cell: int) -> Vector2:
	return Vector2(cell % GRID, cell / GRID) / float(GRID)


## Сторона карточки по семье и случайному t 0…1: видимая форма / доля формы в карточке.
static func card_size(cell: int, t: float) -> float:
	var f: Dictionary = FAMILIES[family(cell)]
	var form: Vector2 = f["form"]
	return lerpf(form.x, form.y, t) / float(f["card"])


## Сколько частиц и вращение: «Экономно» — 180 без вращения.
static func amount(lite: bool) -> int:
	return AMOUNT_LITE if lite else AMOUNT


## Видимость частицы: появление и угасание по доле жизни и у камеры.
static func fade(phase: float, cam_dist: float) -> float:
	var life := smoothstep(0.0, FADE_IN, phase) * (1.0 - smoothstep(FADE_OUT, 1.0, phase))
	return life * smoothstep(NEAR.x, NEAR.y, cam_dist)
