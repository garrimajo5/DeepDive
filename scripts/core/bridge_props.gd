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

const CHAIR_Z := Deck.CHAIR_Z
const TABLE_Z := -1.2

## Пульт MOD-004: 2,5 × 1,42 × 0,65 м вплотную к носовой стене. Окно в игре начинается с 0,8 м, поэтому пульт ниже
## концепта (×0,74), а по глубине ужат (×0,75), чтобы не задевать колесо; стойка штурвала — в проёме между тумбами.
const CONSOLE_H := 1.42
const CONSOLE_D := 0.65
const CONSOLE_SY := 0.74
const CONSOLE_SZ := 0.75
const CONSOLE_Z := Deck.NOSE_INNER + CONSOLE_D * CONSOLE_SZ / 2.0
## Экраны пульта светятся ровным голубым, пока на них ничего не рисуем.
const SCREEN_GLOW := Color(0.06, 0.26, 0.32)
## Стёкла трёх экранов в осях модели пульта (до масштаба), углы слева направо: низ-лево, низ-право, верх-право,
## верх-лево (#1388). Рамки на корпусе MOD-004 не прямоугольные: боковые экраны развёрнуты к пилоту и скошены —
## у внешнего края ниже; плоскость сетки `pult-ekrany` была прямоугольной и вылезала за рамку. Углы сняты лучами
## по тёмному полю экрана в текстуре корпуса, на 1,2 см внутрь от края поля и на 8 мм над поверхностью
## (`test_bridge_screens`). Плоский список: по четыре угла на экран.
const SCREEN_CORNERS: Array[Vector3] = [
	Vector3(-1.021, 1.009, 0.044), Vector3(-0.601, 1.045, 0.069), Vector3(-0.601, 1.278, -0.019), Vector3(-1.021, 1.221, -0.031),
	Vector3(-0.345, 1.052, 0.086), Vector3(0.345, 1.052, 0.086), Vector3(0.345, 1.303, 0.015), Vector3(-0.345, 1.303, 0.015),
	Vector3(0.601, 1.054, 0.067), Vector3(1.021, 1.014, 0.049), Vector3(1.021, 1.222, -0.032), Vector3(0.601, 1.272, -0.016),
]
const SCREEN_COUNT := 3


## Четыре угла экрана i (0 — левый).
static func screen_quad(i: int) -> PackedVector3Array:
	return PackedVector3Array(SCREEN_CORNERS.slice(i * 4, i * 4 + 4))


## Сетка стёкол экранов по `SCREEN_CORNERS`: два треугольника на экран, лицом к пилоту (+Z), UV — 0…1 по экрану.
static func screen_mesh() -> ArrayMesh:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for k in SCREEN_COUNT:
		var q := screen_quad(k)
		var base := v.size()
		var face := (q[1] - q[0]).cross(q[3] - q[0]).normalized()   # наружу, к пилоту
		for i in 4:
			v.append(q[i])
			n.append(face)
			uv.append(uvs[i])
		# лицевая сторона — обход по часовой, если смотреть на неё (CLAUDE.md)
		idx.append_array([base, base + 3, base + 2, base, base + 2, base + 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## Модель на мостике: имя файла в models/, подпись, место и масштаб.
class Prop:
	var model: String
	var label: String
	var pos: Vector3
	var scale: Vector3
	var rot_y := 0.0   ## поворот вокруг вертикали, градусы

	func _init(m: String, l: String, p: Vector3, s: Vector3 = Vector3.ONE, ry: float = 0.0) -> void:
		model = m
		label = l
		pos = p
		scale = s
		rot_y = ry

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


## ---- Бортовые посты: MOD-005…007 (docs/concept-art/modeli-bortovye-posty.md) ----
const ENERGY := "pult-energii"
const SLIDER := "polzunok"
const SCANNER := "skaner-biologa"
const HATCH_FRAME := "lyuk-rama"
const HATCH_DOOR := "lyuk-stvorka"
const HATCH_WHEEL := "lyuk-koleso"

## Пульт энергии на левом борту и сканер на правом — между рёбрами бортов z −2,75 и −1,25 (пульт шириной 1,2 м).
const SIDE_Z := -2.0
const WALL_X := 4.9
## Пульт энергии: модель лицом в −Z, задняя плоскость z = 0; поворот −90° — лицом в отсек (+X). 1,2 × 1,6 × 0,4 м.
const ENERGY_POS := Vector3(-WALL_X, 0.0, SIDE_Z)
const ENERGY_ROT := -90.0
const ENERGY_DEPTH := 0.4
## Ползунки на пульте (в осях пульта): пять пазов по x, ход по y; лицо наклонено — z следует за y.
## Порядок как у пиктограмм на модели слева направо (двигатели, сонар, жизнь, разряд, прожектор): модель смотрит в −Z,
## поэтому левый для смотрящего паз — это +x модели.
const SLIDER_X: Array[float] = [0.34, 0.17, 0.0, -0.17, -0.34]
const SLIDER_Y_MIN := 0.72   ## паз на модели — примерно y 0,62…1,37
const SLIDER_Y_MAX := 1.28
## Сканер: лицом в −X, задняя плоскость x = 0, 0,45 × 1,9 × 1,0 м.
const SCANNER_POS := Vector3(WALL_X, 0.0, SIDE_Z)
const SCANNER_DEPTH := 0.45
## Экран сканера в осях модели (MOD-007): плоскость лицом в −X, y 0,40…1,72, z ±0,37; текст рисует игра.
const SCANNER_SCREEN := Vector3(-0.39, 1.06, 0.0)
const SCANNER_SCREEN_SIZE := Vector2(0.74, 1.32)
## Люк в кормовой переборке: рама лицом в мостик (−Z), проём 1,4 × 2,1 м; створка за рамой, колесо на створке.
const HATCH_POS := Vector3(0.0, 0.0, 2.0)
const HATCH_DOOR_OFFSET := Vector3(0.0, -0.10, 0.14)
const HATCH_WHEEL_OFFSET := Vector3(0.0, 1.15, -0.10)


## Ползунок пульта: z паза на высоте y (лицо пульта наклонено: на высоте 0,75 м — 0,35 м от стены, выше — ближе).
static func slider_z(y: float) -> float:
	return -0.35 + 0.103 * (y - 0.75)


## Высота ползунка по доле 0…1.
static func slider_y(share: float) -> float:
	return lerpf(SLIDER_Y_MIN, SLIDER_Y_MAX, clampf(share, 0.0, 1.0))


static func side_props() -> Array[Prop]:
	return [
		Prop.new(ENERGY, "Пульт энергии", ENERGY_POS, Vector3.ONE, ENERGY_ROT),
		Prop.new(SCANNER, "Сканер биолога", SCANNER_POS),
		Prop.new(HATCH_FRAME, "Люк в коридор", HATCH_POS),
	]
