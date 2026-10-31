class_name SeabedShells
extends SeabedStones
## Ракушки на дне — вторая мелочь одним MultiMesh (`docs/grafika-plan.md`, этап 4 «MultiMesh для мелочи»): пустые
## створки на песке, светлые пятна в луче прожектора у дна. Тот же порядок, что у камней `SeabedStones` (клетки
## CELL м хешем, по CELLS_STEP за шаг, кэш, у края радиуса мельчают, не у образцов), но лежат наоборот: на песке
## грунтов ART-060 наносами — полосами по шуму `drift` (волна течения сгоняет створки), на гальке редко, в иле нет.
## Мельче и ближе камней: RADIUS 26 м, «Экономно» — LITE_RADIUS. Светлее дна, створка выпуклой стороной вверх.
## Рисует `scripts/game/shells_view.gd` (`OceanView.shells`).

const SHELL_RADIUS := 26.0       ## радиус россыпи, м
const SHELL_LITE := 14.0         ## «Экономно»
const SHELL_PER_CELL := 4        ## кандидатов в клетке
const SHELL_SIZE := Vector2(0.14, 0.38)   ## поперечник створки, м
const ON_SAND := 0.9             ## доля кандидатов на песке в наносе
const ON_PEBBLE := 0.12          ## на гальке
const DRIFT_SCALE := 0.045       ## частота шума наносов, 1/м (полосы ~20 м)
const DRIFT_EDGE := Vector2(0.42, 0.62)   ## шум ниже x — створок нет, выше y — нанос целиком
const DRIFT_MIN := 0.08          ## вне наноса — столько от полной густоты
const PALE := Color(0.96, 0.93, 0.86)     ## цвет чистой створки (светлее дна)
const PALE_MIX := 0.55           ## доля чистого цвета поверх цвета дна (остальное — налёт грунта)
const SHELL_SINK := 0.25         ## доля высоты створки в грунте
const SHELL_HEIGHT := 0.32       ## высота чаши створки (доля поперечника; меш `ShellsView.shell_mesh`)


func radius() -> float:
	return SHELL_LITE if lite else SHELL_RADIUS


## Нанос в (x, z): 0 — створок почти нет, 1 — гуще всего.
static func drift(x: float, z: float) -> float:
	var n := HashNoise.fbm(x * DRIFT_SCALE + 3.7, z * DRIFT_SCALE * 0.6 - 8.1, 2)
	return lerpf(DRIFT_MIN, 1.0, HashNoise.smooth(DRIFT_EDGE.x, DRIFT_EDGE.y, n))


## Доля кандидатов, что остаются створкой, по весам грунта [песок, ил, галька] (без наноса).
static func shell_density(w: Array) -> float:
	return ON_SAND * w[0] + ON_PEBBLE * w[2]


## Хеш клетки ракушек — свой, не совпадает с камнями той же клетки.
static func hs(ix: int, iz: int, k: int) -> float:
	return HashNoise.hash2(ix * 29 - 5011 * k + 71, iz * 23 + 4027 * k - 9)


func cell(ix: int, iz: int) -> Array[Stone]:
	var out: Array[Stone] = []
	var cx := (ix + 0.5) * CELL
	var cz := (iz + 0.5) * CELL
	var ny := ny_at(cx, cz)
	if ny < STEEP_NY:
		return out
	var cy := Seabed.height(cx, cz)
	var w := Seabed.Ground.weights(cx, cz, ny, -cy)
	if w[1] > 0.5:
		return out   # в иле створки затянуло
	var keep := shell_density(w) * drift(cx, cz) * Seabed.Ground.detail_k(ny)
	for k in SHELL_PER_CELL:
		var b := k * 8
		if hs(ix, iz, b) >= keep:
			continue
		var x := (ix + hs(ix, iz, b + 1)) * CELL
		var z := (iz + hs(ix, iz, b + 2)) * CELL
		if _near_sample(x, z):
			continue
		var s := Stone.new()
		var big := hs(ix, iz, b + 3)
		s.size = lerpf(SHELL_SIZE.x, SHELL_SIZE.y, big * big)
		var turn := Basis(Vector3.UP, hs(ix, iz, b + 4) * TAU) \
				* Basis(Vector3.RIGHT, (hs(ix, iz, b + 5) - 0.5) * 0.6) \
				* Basis(Vector3.BACK, (hs(ix, iz, b + 6) - 0.5) * 0.4)
		s.basis = turn * Basis.from_scale(Vector3.ONE * s.size)
		var y := Seabed.mesh_height(x, z)
		s.pos = Vector3(x, y - SHELL_SINK * SHELL_HEIGHT * s.size, z)
		var g := Seabed.color_at(x, y, z, ny)
		var v := lerpf(0.95, 1.12, hs(ix, iz, b + 7))
		var c := g.lerp(PALE, PALE_MIX)
		s.color = Color(c.r * v, c.g * v, c.b * v * 0.97)
		out.append(s)
	return out

