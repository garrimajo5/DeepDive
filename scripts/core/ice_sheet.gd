class_name IceSheet
## Лёд снизу по ART-056 (`docs/concept-art/led-snizu.md`): числа материала «Льда» `OceanView` (шейдер
## `shaders/ice.gdshader`, карты `textures/ice/`). Плитка 16 × 16 м по `world.xz`; сеть трещин светит только там, где
## её открывает крупный мировой шум `gate` (период ≫ 16 м) — так рвётся повтор плитки. Свечение вместо ровной 0,35:
## слабый фон и добавка трещин, гаснут по глубине наблюдателя. Числа шейдера повторены здесь для тестов;
## `gate` в шейдере считается тем же хешем, что `HashNoise` (до точности float).

const TILE := 16.0                 ## плитка карт, м
const GLOW_COLOR := Color("9AD9E8")
const GLOW_BASE := 0.02            ## свечение толщи (ART-056: 0,015–0,025)
const GLOW_CRACK := 0.08           ## добавка трещин при маске 1 и открытом шуме
const GLOW_DEPTH := 9.0            ## спад свечения по глубине наблюдателя, м: exp(−depth / 9)
const CONTRAST := Vector2(8.0, 38.0)   ## альбедо уходит в цвет воды с глубины 8 м до 38 м
const RELIEF_TO := 35.0            ## нормали гаснут к этой глубине наблюдателя
const NORMAL_DEPTH := 0.35         ## сила нормалей (ART-056: 0,25–0,5)
const ROUGHNESS := 0.62
const GATE_SCALE := 60.0           ## крупный шум по world.xz / 60 — период много больше плитки
const GATE_OCT := 2                ## октав крупного шума (в шейдере столько же)
const GATE_EDGE := Vector2(0.48, 0.62)  ## шум ниже — трещины не светят, выше — светят полностью


## UV карт для точки льда (общее начало для цвета, нормалей и маски).
static func uv(x: float, z: float) -> Vector2:
	return Vector2(x / TILE, z / TILE)


## Где сеть трещин открыта: 0 — едва заметные борозды, 1 — светит.
static func gate(x: float, z: float) -> float:
	var n := HashNoise.fbm(x / GATE_SCALE, z / GATE_SCALE, GATE_OCT)
	return HashNoise.smooth(GATE_EDGE.x, GATE_EDGE.y, n)


## Свечение льда (энергия эмиссии) при маске трещин crack 0…1 и открытости g, наблюдатель на глубине depth.
static func glow(depth: float, crack: float, g: float) -> float:
	return (GLOW_BASE + GLOW_CRACK * crack * g) * exp(-maxf(depth, 0.0) / GLOW_DEPTH)


## Сколько своего цвета у льда (1 — у поверхности, 0 — с 38 м только цвет воды).
static func contrast(depth: float) -> float:
	return 1.0 - HashNoise.smooth(CONTRAST.x, CONTRAST.y, depth)


## Сила нормалей по глубине наблюдателя (0 с 35 м).
static func relief(depth: float) -> float:
	return NORMAL_DEPTH * clampf(1.0 - depth / RELIEF_TO, 0.0, 1.0)
