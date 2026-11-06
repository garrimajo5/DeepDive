class_name SeabedTufts
extends SeabedStones
## Кочки водорослей-щёток на дне — третья мелочь одним MultiMesh (`docs/grafika-plan.md`, этап 4 «MultiMesh для
## мелочи»: камни, трава, ракушки). Низкие бурые пучки жёстких лопастей там, где сквозь лёд ещё доходит свет: гуще
## на иле грунтов ART-060 (камни там тонут, створки затянуло), реже на песке, на гальке почти нет; пятнами-лужайками
## по шуму `meadow`; с глубиной дна редеют и к `DEEP.y` м пропадают совсем (свету не хватает — склон к 10 голый).
## Это фон дна, не вид мира: сонар, сканер и существа его не видят. Тот же порядок, что у камней `SeabedStones`
## (клетки CELL м своим хешем, по CELLS_STEP за шаг, кэш, у края радиуса мельчают, не у образцов). Радиус —
## TUFT_RADIUS, «Экономно» — TUFT_LITE. Рисует `scripts/game/tufts_view.gd` (`OceanView.tufts`).

const TUFT_RADIUS := 30.0        ## радиус россыпи, м
const TUFT_LITE := 16.0          ## «Экономно»
const TUFT_PER_CELL := 3         ## кандидатов в клетке
const TUFT_SIZE := Vector2(0.3, 0.75)   ## поперечник кочки, м (высота — TUFT_TALL доли)
const TUFT_TALL := Vector2(0.55, 1.0)   ## высота кочки — доля поперечника
const ON_SILT := 0.85            ## доля кандидатов на иле
const ON_SAND := 0.3             ## на песке
const ON_PEBBLE := 0.04          ## на гальке
const MEADOW_SCALE := 0.06       ## частота шума лужаек, 1/м (пятна ~15 м)
const MEADOW_EDGE := Vector2(0.38, 0.6)   ## шум ниже x — кочек почти нет, выше y — лужайка целиком
const MEADOW_MIN := 0.12         ## вне лужайки — столько от полной густоты
const DEEP := Vector2(55.0, 95.0)   ## глубина дна, м: глубже x кочки редеют, к y — нет совсем
const OLIVE := Color(0.44, 0.42, 0.22)   ## цвет пучка (бурая олива — темнее и зеленее дна)
const OLIVE_MIX := 0.7           ## доля своего цвета поверх цвета дна
const TUFT_SINK := 0.08          ## доля высоты в грунте


func radius() -> float:
	return TUFT_LITE if lite else TUFT_RADIUS


## Лужайка в (x, z): MEADOW_MIN — кочек почти нет, 1 — гуще всего.
static func meadow(x: float, z: float) -> float:
	var n := HashNoise.fbm(x * MEADOW_SCALE - 11.3, z * MEADOW_SCALE + 4.9, 2)
	return lerpf(MEADOW_MIN, 1.0, HashNoise.smooth(MEADOW_EDGE.x, MEADOW_EDGE.y, n))


## Доля кандидатов, что остаются кочкой, по весам грунта [песок, ил, галька] (без лужаек и глубины).
static func tuft_density(w: Array) -> float:
	return ON_SAND * w[0] + ON_SILT * w[1] + ON_PEBBLE * w[2]


## Сколько света для кочек на глубине дна depth (м): 1 — мелко, 0 — с DEEP.y.
static func light_k(depth: float) -> float:
	return 1.0 - HashNoise.smooth(DEEP.x, DEEP.y, depth)


## Хеш клетки кочек — свой, не совпадает с камнями и ракушками той же клетки.
static func ht(ix: int, iz: int, k: int) -> float:
	return HashNoise.hash2(ix * 41 + 6143 * k - 377, iz * 37 - 2711 * k + 91)


func cell(ix: int, iz: int) -> Array[Stone]:
	var out: Array[Stone] = []
	var cx := (ix + 0.5) * CELL
	var cz := (iz + 0.5) * CELL
	var cy := Seabed.height(cx, cz)
	var lk := light_k(-cy)
	if lk <= 0.0:
		return out   # глубоко — свету нет, дно голое (и клетка почти даром)
	var ny := ny_at(cx, cz)
	if ny < STEEP_NY:
		return out
	var w := Seabed.Ground.weights(cx, cz, ny, -cy)
	var keep := tuft_density(w) * meadow(cx, cz) * lk * Seabed.Ground.detail_k(ny)
	for k in TUFT_PER_CELL:
		var b := k * 8
		if ht(ix, iz, b) >= keep:
			continue
		var x := (ix + ht(ix, iz, b + 1)) * CELL
		var z := (iz + ht(ix, iz, b + 2)) * CELL
		if _near_sample(x, z):
			continue
		var s := Stone.new()
		var big := ht(ix, iz, b + 3)
		s.size = lerpf(TUFT_SIZE.x, TUFT_SIZE.y, big * big)
		var tall := lerpf(TUFT_TALL.x, TUFT_TALL.y, ht(ix, iz, b + 4))
		var turn := Basis(Vector3.UP, ht(ix, iz, b + 5) * TAU) \
				* Basis(Vector3.RIGHT, (ht(ix, iz, b + 6) - 0.5) * 0.3)
		s.basis = turn * Basis.from_scale(Vector3(1.0, tall, 1.0) * s.size)
		var y := Seabed.mesh_height(x, z)
		s.pos = Vector3(x, y - TUFT_SINK * tall * s.size, z)
		var g := Seabed.color_at(x, y, z, ny)
		var v := lerpf(0.8, 1.15, ht(ix, iz, b + 7))
		var c := g.lerp(OLIVE, OLIVE_MIX)
		s.color = Color(c.r * v, c.g * v, c.b * v)
		out.append(s)
	return out
