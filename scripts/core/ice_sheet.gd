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


const CRACK_MASK := "res://textures/ice/treshchiny.png"
const SHAFT_MASK := 0.70           ## основание шахты ART-052 — где маска трещин выше (ART-056)
## Каустики под трещинами: CAUSTIC·exp(−глубина дна / CAUSTIC_DEPTH). У ART-056 было 0,06·exp(−d/12), но дно отмели
## лежит на 30…47 м подо льдом (медиана 41) — там это 0,002, глазу не видно (#445); теперь ≈ 0,05 на 41 м.
const CAUSTIC := 0.12
const CAUSTIC_DEPTH := 45.0
const CAUSTIC_NET := 1.6           ## сеть каустик под трещиной ярче: cmask × (0,6 + 1,6·под трещиной), было 0,8
const CAUSTIC_WIDEN := 0.10        ## и гуще: порог нитей 0,16 + 0,10·под трещиной
static var _mask: Image


## Маска трещин 0…1 в точке льда (та же карта, что у шейдера, без фильтра — ближайший тексел).
static func crack(x: float, z: float) -> float:
	if _mask == null:
		_mask = (load(CRACK_MASK) as Texture2D).get_image()
		if _mask.is_compressed():
			_mask.decompress()
		_mask.clear_mipmaps()
	var w := _mask.get_width()
	var u := uv(x, z)
	var px := posmod(int(floorf(u.x * w)), w)
	var pz := posmod(int(floorf(u.y * w)), w)
	return _mask.get_pixel(px, pz).r


## Сила каустик под трещинами на дне глубиной depth (м подо льдом).
static func caustic(depth: float) -> float:
	return CAUSTIC * exp(-maxf(depth, 0.0) / CAUSTIC_DEPTH)


## Множитель сети каустик над точкой дна: under — маска трещин сверху (размытая, 0…1, с воротами `gate`).
static func caustic_net(under: float) -> float:
	return 0.6 + CAUSTIC_NET * clampf(under, 0.0, 1.0)


# --- Окно Снелля и отражение воды на нижней грани по ART-075 (`docs/concept-art/led-otrazhenie.md`) ---
# Двойник шейдера: LUT 256×16 (X — косинус угла взгляда к нижней нормали, строки — глубина корабля), маска гладкости по
# плитке 16 м. Отражение — в EMISSION, затухание по глубине уже в A таблицы (не умножать на exp(−depth/9)).
const REFLECT_LUT := "res://textures/ice/otrazhenie.png"   ## RGBA8 256×16, линейные данные, без mipmap
const SMOOTH_MASK := "res://textures/ice/gladkost.png"     ## L8 512², бесшовная по плитке, mipmap
const CRIT_COS := 0.6614378277661477   ## cos θc при n = 4/3 (θc = 48,59°)
const ROW_KEYS := [[0.0, 0.0], [8.0, 3.0], [20.0, 7.0], [45.0, 11.0], [90.0, 15.0]]   ## [глубина, строка LUT]
const OPEN_EDGE := Vector2(0.10, 0.55)  ## трещины пропускают свет, не зеркалят: smoothstep по crack·gate
const MIRROR_ROUGH := 0.20              ## шероховатость гладкой грани под зеркалом
const LITE_SMOOTH := 0.55               ## «Экономно» (ART-044): маску не читать — гладкость константой
const LITE_K := 0.55                    ## и доля отражения × 0,55


## Строка LUT (0…15, дробная — между строками фильтр) по глубине корабля: кусочно-линейно по ключам 0/8/20/45/90 м.
static func row(depth: float) -> float:
	var d := clampf(depth, 0.0, 90.0)
	for i in range(1, ROW_KEYS.size()):
		var a: Array = ROW_KEYS[i - 1]
		var b: Array = ROW_KEYS[i]
		if d <= b[0]:
			return lerpf(a[1], b[1], (d - a[0]) / (b[0] - a[0]))
	return 15.0


## Куда смотреть в LUT: шершавая грань (smooth → 0) прижимает косинус к критическому — граница окна мягче.
static func lookup(mu: float, smooth: float) -> float:
	return clampf(CRIT_COS + (mu - CRIT_COS) * lerpf(0.35, 1.0, smooth), 0.0, 1.0)


## Доля отражения: A таблицы, гладкость, открытые трещины, сила и ил (ил главнее — в густом нет отражения).
static func mirror(lut_a: float, smooth: float, crack: float, g: float, gain: float, silt: float,
		lite: bool = false) -> float:
	var s := LITE_SMOOTH if lite else smooth
	var open := HashNoise.smooth(OPEN_EDGE.x, OPEN_EDGE.y, crack * g)
	var a := lut_a * (0.30 + 0.70 * s) * (1.0 - open) * gain * (1.0 - clampf(silt, 0.0, 1.0))
	return a * LITE_K if lite else a
