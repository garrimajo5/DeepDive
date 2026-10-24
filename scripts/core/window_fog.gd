class_name WindowFog
extends RefCounted
## Конденсат и иней на окнах мостика по ART-077 (docs/concept-art/kondensat-okon.md): капли и дорожки у рамы,
## иглы инея в углах — по глубине корабля (нет до 8 м, полный к 45 м), потере корпуса и нагреву реактора
## (`Reactor.heat`, при сбросе — 0). Сглаживание здесь, в шейдер стекла — готовые humidity и ice_k
## (`BridgeView.set_fog`, `shaders/window_glass.gdshader`). Маска `textures/bridge/kondensat-maska.png` (линейные данные,
## UV стекла `BridgeView.glass_uv`): R — капли, G — дорожки, B — иней, A — порог от рамы к центру; центр 56 × 56 % —
## R = G = B = 0, A = 1 (всегда чист). Без экранного буфера и нормалей капель: вариант «Экономно» для всех уровней,
## преломление — после замера на телефоне. `gate`/`drops`/`frost`/`alpha` — двойники шейдера для тестов.

const MASK := "res://textures/bridge/kondensat-maska.png"
const COLD_FROM := 8.0          ## м — выше конденсата нет
const COLD_TO := 45.0           ## м — холод полный
const WARM_FROM := 35.0         ## «градусы» реактора — стекло начинает оттаивать
const WARM_TO := 85.0
const GATE_W := 0.18            ## ширина перехода порога A
const TRACK_K := 0.65           ## дорожки слабее капель
const DROP_ALPHA := 0.16        ## добавка непрозрачности капель
const FROST_ALPHA := 0.42       ## и инея
const ICE_COLOR := Color(0.38, 0.62, 0.70)   ## линейный, ≈ sRGB #A6CEDA; сам не светится
const FROST_ROUGH := 0.85
## Постоянные времени, с: обогрев растёт / остывает, влажность высыхает / копится, иней тает / нарастает.
const WARM_UP := 6.0
const WARM_DOWN := 18.0
const DRY := 10.0
const WET := 30.0
const MELT := 6.0
const FREEZE := 24.0

var warm := 0.0       ## огибающая обогрева 0…1
var humidity := 0.0   ## влажность стекла 0…1 (порог маски A)
var ice_k := 0.0      ## доля инея 0…1


static func cold(depth: float) -> float:
	return smoothstep(COLD_FROM, COLD_TO, maxf(depth, 0.0))


## Цель обогрева от реактора: нагрев 35…85, при сбросе (SCRAM) — 0.
static func warm_target(heat: float, scram: float) -> float:
	if scram > 0.0:
		return 0.0
	return smoothstep(WARM_FROM, WARM_TO, heat)


## Влажность: холод глубины, повреждённый корпус добавляет (но мороза в тёплой воде не создаёт), обогрев сушит.
static func wet_target(depth: float, hull: float, w: float) -> float:
	var loss := clampf(1.0 - hull / 100.0, 0.0, 1.0)
	var c := cold(depth)
	return (0.03 + 0.97 * c) * (0.56 + 0.44 * smoothstep(0.0, 0.7, loss)) * (1.0 - 0.8 * clampf(w, 0.0, 1.0))


static func ice_target(depth: float, w: float) -> float:
	return cold(depth) * (1.0 - clampf(w, 0.0, 1.0))


static func _ease(v: float, target: float, dt: float, rise: float, fall: float) -> float:
	var tau := rise if target > v else fall
	return lerpf(v, target, 1.0 - exp(-dt / tau))


## Шаг: depth — глубина корабля (м), hull — прочность (%), heat/scram — реактор.
func step(dt: float, depth: float, hull: float, heat: float, scram: float) -> void:
	if dt <= 0.0:
		return
	warm = _ease(warm, warm_target(heat, scram), dt, WARM_UP, WARM_DOWN)
	humidity = _ease(humidity, wet_target(depth, hull, warm), dt, WET, DRY)
	ice_k = _ease(ice_k, ice_target(depth, warm), dt, FREEZE, MELT)


## Сразу в установившееся состояние (новый забег, снимок).
func snap(depth: float, hull: float, heat: float, scram: float) -> void:
	warm = warm_target(heat, scram)
	humidity = wet_target(depth, hull, warm)
	ice_k = ice_target(depth, warm)


## Порог маски: пиксель с порогом a «запотел», когда влажность его прошла.
static func gate(a: float, h: float) -> float:
	return smoothstep(a, a + GATE_W, h)


## Капли и дорожки по маске (r, g), иней (b) — как в шейдере.
static func drops(m: Color, h: float) -> float:
	return maxf(m.r, m.g * TRACK_K) * gate(m.a, h)


static func frost(m: Color, h: float, ice: float) -> float:
	return m.b * ice * gate(m.a, h)


## Непрозрачность стекла поверх исходной ART-057 (base): добавки складываются, не заменяют.
static func alpha(base: float, d: float, f: float) -> float:
	return 1.0 - (1.0 - base) * (1.0 - DROP_ALPHA * d - FROST_ALPHA * f)
