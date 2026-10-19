class_name EcoView
extends Node3D
## Живой мир отмели в сцене (поток Б): держит мир экосистемы без узлов (EcoWorld, scripts/core/eco/) и рисует существ.
## Стоит в мире (не в корабле), на слое отмели OceanView.LAYER_WORLD. Корабль зовёт только step() — см. EcoLink.
## Виды подключаются модулями мира (world.add); их узлы рисования — в scripts/game/eco/.

## Мир экосистемы: зерно 20261018, подшаги ≤ 0,05 с.
var world := EcoWorld.new()
## Светляки-полосники: шесть стай у кораллов и их MultiMesh.
var fish: EcoFish
var fish_view: FishView
## Светящийся мох (22 пятна) и скребуны (10), что его объедают.
var moss: EcoMoss
var moss_view: MossView
var grazers: EcoGrazer
var grazer_view: GrazerView

## Высота дна под (x, z): Seabed.height. Даёт корабль при создании; уходит в мир. Мох и скребуны встают на дно
## заново (мир сбрасывается, меш мха собирается по новому дну).
var ground: Callable:
	set(value):
		ground = value
		world.ground = value
		world.reset()
		_rebuild_moss()


func _init() -> void:
	fish = world.add(EcoFish.new()) as EcoFish
	fish_view = FishView.new(fish)
	add_child(fish_view)
	moss = world.add(EcoMoss.new()) as EcoMoss
	grazers = world.add(EcoGrazer.new(moss)) as EcoGrazer
	grazer_view = GrazerView.new(grazers)
	add_child(grazer_view)
	_rebuild_moss()


## Меш мха по дну мира (пятна плоские, пока дна нет).
func _rebuild_moss() -> void:
	if moss_view:
		remove_child(moss_view)
		moss_view.free()
	moss_view = MossView.new(moss, world.ground)
	add_child(moss_view)


## Шаг мира: dt — время, ship — состояние корабля. Возвращает события для корабля (EcoLink).
func step(dt: float, ship: EcoLink.ShipState) -> Array[Dictionary]:
	world.ship = ship
	world.step(dt)
	fish_view.sync(world.time)
	grazer_view.sync(world.time)
	moss_view.sync()
	return world.take_link()
