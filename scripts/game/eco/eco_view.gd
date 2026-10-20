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
## Серпохвосты: три хищника, охотятся на светляков и бросаются на корабль (EcoLink.HIT); модели MOD-011.
var preds: EcoPred
var pred_view: PredView
## Флора (ART-004): течение мира, огнецвет (три куста, кончики гаснут от шума) и веерники поперёк течения.
var current: EcoCurrent
var coral: EcoCoral
var coral_view: CoralView
var fans: EcoFan
var fan_view: FanView

## Высота дна под (x, z): Seabed.height. Даёт корабль при создании; уходит в мир. Мох и скребуны встают на дно
## заново (мир сбрасывается, меш мха собирается по новому дну).
var ground: Callable:
	set(value):
		ground = value
		world.ground = value
		world.reset()
		_rebuild_moss()
		_rebuild_coral()


func _init() -> void:
	fish = world.add(EcoFish.new()) as EcoFish
	fish_view = FishView.new(fish)
	add_child(fish_view)
	moss = world.add(EcoMoss.new()) as EcoMoss
	grazers = world.add(EcoGrazer.new(moss)) as EcoGrazer
	grazer_view = GrazerView.new(grazers)
	add_child(grazer_view)
	preds = world.add(EcoPred.new(fish)) as EcoPred
	pred_view = PredView.new(preds)
	add_child(pred_view)
	current = world.add(EcoCurrent.new()) as EcoCurrent
	coral = world.add(EcoCoral.new()) as EcoCoral
	fans = world.add(EcoFan.new(current)) as EcoFan
	fan_view = FanView.new(fans)
	add_child(fan_view)
	_rebuild_moss()
	_rebuild_coral()


## Меш мха по дну мира (пятна плоские, пока дна нет).
func _rebuild_moss() -> void:
	if moss_view:
		remove_child(moss_view)
		moss_view.free()
	moss_view = MossView.new(moss, world.ground)
	add_child(moss_view)


## Меш огнецвета по дну мира (кусты встают на дно при сбросе мира).
func _rebuild_coral() -> void:
	if coral_view:
		remove_child(coral_view)
		coral_view.free()
	coral_view = CoralView.new(coral)
	add_child(coral_view)


## Шаг мира: dt — время, ship — состояние корабля. Возвращает события для корабля (EcoLink).
func step(dt: float, ship: EcoLink.ShipState) -> Array[Dictionary]:
	world.ship = ship
	world.step(dt)
	fish_view.sync(world.time)
	grazer_view.sync(world.time)
	pred_view.sync(world.time, ship.pos)
	moss_view.sync()
	coral_view.sync()
	fan_view.sync(world.time)
	return world.take_link()
