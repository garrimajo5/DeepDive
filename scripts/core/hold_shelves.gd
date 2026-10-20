class_name HoldShelves
## Полки трюма на 24 образца (ART-010, MOD-017, docs/concept-art/tryum.md): стеллаж у каждого борта, 3 яруса × 4 ячейки.
## Груз трюма (`Samples.cargo`) стоит в банках: образец встаёт в ближайшую к захвату лебёдки свободную ячейку,
## поэтому n-й образец груза — в n-й ячейке `cells()`. Рисует `RoomsView.set_shelves`.

## Стеллажи: pivot — середина нижней кромки задней панели на полу, полки тянутся в +X модели.
## Левый борт без поворота, правый — повёрнут на 180°.
const RACKS := [Vector3(-2.5, 0.0, 21.8), Vector3(2.5, 0.0, 21.8)]
## Ячейка — центр донца банки в осях стеллажа: x, ярусы y, места z.
const CELL_X := 0.285
const CELL_Y := [0.55, 1.30, 2.05]
const CELL_Z := [-1.2, -0.4, 0.4, 1.2]
const CAPACITY := 24
## Полоса стеллажа на полу у борта (м): глубина и длина вдоль борта.
const DEPTH := 0.55
const LENGTH := 3.28
## Образец в банке (в осях банки): цилиндр r 0,09, y 0,05…0,27.
const SAMPLE_R := 0.09
const SAMPLE_Y0 := 0.05
const SAMPLE_Y1 := 0.27
## Откуда образец приходит на полки — захват лебёдки в покое над проёмом.
const FROM := Vector3(0.0, 1.1, 22.0)


## Поворот стеллажа борта side (0 — левый, 1 — правый) вокруг y, рад.
static func rack_yaw(side: int) -> float:
	return 0.0 if side == 0 else PI


## Центр донца банки в ячейке (борт, ярус, место) в осях корабля.
static func cell_at(side: int, tier: int, slot: int) -> Vector3:
	var b := Basis(Vector3.UP, rack_yaw(side))
	return RACKS[side] + b * Vector3(CELL_X, CELL_Y[tier], CELL_Z[slot])


## Все 24 ячейки по порядку заполнения: ближе к захвату лебёдки — раньше; при равенстве — левый борт, нижний ярус,
## к носу.
static func cells() -> Array[Vector3]:
	var all: Array[Vector3] = []
	for side in RACKS.size():
		for tier in CELL_Y.size():
			for slot in CELL_Z.size():
				all.append(cell_at(side, tier, slot))
	var order := range(all.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		var da := all[a].distance_to(FROM)
		var db := all[b].distance_to(FROM)
		return da < db - 1e-4 or (absf(da - db) <= 1e-4 and a < b))
	var out: Array[Vector3] = []
	for i in order:
		out.append(all[i])
	return out


## Вид образца в каждой ячейке cells() (−1 — пусто) по грузу трюма [вид, номер]; сверх CAPACITY не помещается.
static func contents(cargo: Array) -> Array[int]:
	var out: Array[int] = []
	out.resize(CAPACITY)
	out.fill(-1)
	for i in mini(cargo.size(), CAPACITY):
		out[i] = int(cargo[i][0])
	return out


## Стеллажи — препятствия: полоса DEPTH у каждого борта трюма.
static func blocks(x: float, z: float, r: float) -> bool:
	for p in RACKS:
		var x0: float = p.x if p.x < 0.0 else p.x - DEPTH
		if Rect2(x0, p.z - LENGTH / 2.0, DEPTH, LENGTH).grow(r).has_point(Vector2(x, z)):
			return true
	return false
