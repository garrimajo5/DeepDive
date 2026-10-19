class_name EcoView
extends Node3D
## Живой мир отмели в сцене (поток Б): держит мир экосистемы без узлов (scripts/core/eco/) и рисует существ.
## Стоит в мире (не в корабле), на слое отмели OceanView.LAYER_WORLD. Корабль зовёт только step() — см. EcoLink.
## Пока мир пуст: заглушка, чтобы поток Б начинал с наполнения, не трогая main.gd.

## Высота дна под (x, z): Seabed.height. Даёт корабль при создании.
var ground: Callable


## Шаг мира: dt — время, ship — состояние корабля. Возвращает события для корабля (EcoLink).
func step(_dt: float, _ship: EcoLink.ShipState) -> Array[Dictionary]:
	return []
