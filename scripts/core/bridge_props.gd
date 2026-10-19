class_name BridgeProps
## Модели художника на мостике (MOD-001…004, Meshy по ART-002, GLB в models/): кресло пилота, корпус голостола,
## стойка и колесо штурвала, пульт пилота с тремя экранами. Опорная точка — центр основания на полу;
## у колеса — центр ступицы, лицом к пилоту (+Z). Места — как в pogrujenie (`Core/BridgeProps.cs`), x тот же (модели на оси).

const WHEEL := "shturval-koleso"
const STAND := "shturval-stoyka"
const CHAIR := "kreslo-pilota"
const TABLE := "golostol-korpus"
const CONSOLE := "pult-pilota"
const SCREENS := "pult-ekrany"

## Штурвал: центр колеса и наклон к пилоту (градусы вокруг x), чтобы из кресла был виден обод.
const WHEEL_Y := 0.95
const WHEEL_Z := -5.25
const WHEEL_TILT := -20.0
## Колесо поворачивается вслед за штурвалом: градусов на единицу поворота (Helm.Ship.turn −1…1).
const WHEEL_TURN_DEG := 80.0
## Вал стойки в модели: высота оси и передний торец (м, до масштаба); полутолщина колеса.
const SHAFT_Y := 0.7125
const SHAFT_FRONT := 0.137
const WHEEL_HALF_DEPTH := 0.083
const STAND_SCALE_Y := WHEEL_Y / SHAFT_Y
const STAND_Z := WHEEL_Z - WHEEL_HALF_DEPTH - SHAFT_FRONT

const CHAIR_Z := -3.95
const TABLE_Z := -1.2

## Пульт MOD-004: 2,5 × 1,42 × 0,65 м вплотную к носовой стене. Окно в игре начинается с 0,8 м, поэтому пульт ниже
## концепта (×0,74), а по глубине ужат (×0,75), чтобы не задевать колесо; стойка штурвала — в проёме между тумбами.
const CONSOLE_H := 1.42
const CONSOLE_D := 0.65
const CONSOLE_SY := 0.74
const CONSOLE_SZ := 0.75
const CONSOLE_Z := Deck.NOSE_INNER + CONSOLE_D * CONSOLE_SZ / 2.0
const CONSOLE_FRONT := Deck.NOSE_INNER + CONSOLE_D * CONSOLE_SZ
const CONSOLE_TOP := CONSOLE_H * CONSOLE_SY
## Экраны пульта светятся ровным голубым, пока на них ничего не рисуем.
const SCREEN_GLOW := Color(0.06, 0.26, 0.32)


## Модель на мостике: имя файла в models/, подпись, место и масштаб.
class Prop:
	var model: String
	var label: String
	var pos: Vector3
	var scale: Vector3

	func _init(m: String, l: String, p: Vector3, s: Vector3 = Vector3.ONE) -> void:
		model = m
		label = l
		pos = p
		scale = s

	func path() -> String:
		return "res://models/%s.glb" % model


## Неподвижные модели (колесо ставится отдельно на узел штурвала).
static func fixed() -> Array[Prop]:
	return [
		Prop.new(CHAIR, "Кресло пилота", Vector3(0, 0, CHAIR_Z)),
		Prop.new(TABLE, "Голостол сонара", Vector3(0, 0, TABLE_Z)),
		Prop.new(STAND, "Стойка штурвала", Vector3(0, 0, STAND_Z), Vector3(1, STAND_SCALE_Y, 1)),
		Prop.new(CONSOLE, "Пульт пилота", Vector3(0, 0, CONSOLE_Z), Vector3(1, CONSOLE_SY, CONSOLE_SZ)),
		Prop.new(SCREENS, "Экраны пульта", Vector3(0, 0, CONSOLE_Z), Vector3(1, CONSOLE_SY, CONSOLE_SZ)),
	]


static func wheel() -> Prop:
	return Prop.new(WHEEL, "Колесо штурвала", Vector3(0, WHEEL_Y, WHEEL_Z))
