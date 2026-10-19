class_name EcoView
extends Node3D
## Живой мир отмели в сцене (поток Б): держит мир экосистемы без узлов (EcoWorld, scripts/core/eco/) и рисует существ.
## Стоит в мире (не в корабле), на слое отмели OceanView.LAYER_WORLD. Корабль зовёт только step() — см. EcoLink.
## Виды подключаются модулями мира (world.add); их узлы рисования — в scripts/game/eco/.

## Мир экосистемы: зерно 20261018, подшаги ≤ 0,05 с.
var world := EcoWorld.new()

## Высота дна под (x, z): Seabed.height. Даёт корабль при создании; уходит в мир.
var ground: Callable:
	set(value):
		ground = value
		world.ground = value


## Шаг мира: dt — время, ship — состояние корабля. Возвращает события для корабля (EcoLink).
func step(dt: float, ship: EcoLink.ShipState) -> Array[Dictionary]:
	world.ship = ship
	world.step(dt)
	return world.take_link()
