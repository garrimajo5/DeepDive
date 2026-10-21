class_name CrewHands
## Руки на постах: куда член экипажа кладёт кисти, пока работает у поста (оси корабля, метры). Каждая функция
## возвращает [левая, правая]; Vector3.INF — рука свободна (качается при ходьбе). Позу считает `Crew.Member.hold`,
## модель MOD-012 дотягивается туда же (`CrewRig`). Места — по моделям: пульт энергии MOD-005 (ползунки
## `BridgeProps.SLIDER_X`), голостол (Ø 2,2 м, край 0,9 м), рычаг разряда MOD-014, вентиль и щиток машинного MOD-009,
## опора лебёдки MOD-010, сканер MOD-007.

const FREE := Vector3.INF
## Сколько держать руки на посте после нажатия (импульс сонара, разряд, щиток), с.
const PRESS := 0.9
## Отошёл от места нажатия дальше LEAVE (м) — руки отпускают пост сразу, а не тянутся к нему через мостик (#349).
const LEAVE := 0.5


## Держать ли ещё руки на посте после нажатия: время не вышло и игрок не ушёл с места нажатия.
static func pressing(left: float, pressed_at: Vector2, at: Vector2) -> bool:
	return left > 0.0 and pressed_at.distance_to(at) <= LEAVE
## Голостол: край корпуса — радиус 1,1 м на высоте 0,9 м; ладони чуть внутрь края, на ширине плеч.
const TABLE_R := 1.0
const TABLE_Y := 0.92
const TABLE_SPREAD := 0.24
## Рычаг разряда: набалдашник в осях рычага (docs/concept-art/razryad.md).
const LEVER_KNOB := Vector3(0.20, 0.0, 0.0)
## Вентиль: колесо лицом в +X; хват за обод выше центра (вверх) и по сторонам (z).
const VALVE_GRIP := Vector2(0.12, 0.15)
## Опора лебёдки: колонна радиуса Samples.COLUMN_R; рукоять на высоте 1,1 м.
const WINCH_Y := 1.1
const WINCH_SPREAD := 0.16
## Сканер: края экрана (в осях модели экран лицом в −X, z ±0,37), ладони на раме.
const SCANNER_GRIP := Vector3(-0.43, 0.95, 0.40)
## Щиток «Аварийный сброс»: правая рука на крышке.
const SCRAM_GRIP := Vector3(2.78, 1.33, 17.2)


static func none() -> Array[Vector3]:
	return [FREE, FREE]


## Пульт энергии: ближняя рука на выбранном ползунке (левые для смотрящего пазы — левой), другая — на верхнем
## крае пульта со своей стороны.
static func energy(sel: int, share: float) -> Array[Vector3]:
	var b := Basis(Vector3.UP, deg_to_rad(BridgeProps.ENERGY_ROT))
	var y := BridgeProps.slider_y(share)
	var sx: float = BridgeProps.SLIDER_X[clampi(sel, 0, BridgeProps.SLIDER_X.size() - 1)]
	var knob := BridgeProps.ENERGY_POS + b * Vector3(sx, y, BridgeProps.slider_z(y) - 0.03)
	var left_edge := BridgeProps.ENERGY_POS + b * Vector3(0.45, 1.42, -0.3)
	var right_edge := BridgeProps.ENERGY_POS + b * Vector3(-0.45, 1.42, -0.3)
	if sx >= 0.0:
		return [knob, right_edge]
	return [left_edge, knob]


## Голостол: обе ладони на краю со стороны, где стоит член экипажа (x, z).
static func table(x: float, z: float) -> Array[Vector3]:
	var c := Vector3(0.0, TABLE_Y, BridgeProps.TABLE_Z)
	var d := Vector3(x, 0.0, z) - Vector3(c.x, 0.0, c.z)
	d = d.normalized() if d.length() > 1e-3 else Vector3.BACK
	var side := Vector3.UP.cross(d)  # вправо для того, кто смотрит на стол
	var p := c + d * TABLE_R
	return [p - side * TABLE_SPREAD, p + side * TABLE_SPREAD]


## Рычаг разряда: правая рука на набалдашнике, рычаг под углом deg (Zap.lever_deg).
static func lever(deg: float) -> Array[Vector3]:
	return [FREE, Zap.LEVER_POS + Basis(Vector3.BACK, deg_to_rad(deg)) * LEVER_KNOB]


## Вентиль сброса пара: обе руки на ободе колеса (стоя лицом к −X, левая рука — к +z).
static func valve() -> Array[Vector3]:
	var c := EngineRoom.VALVE_WHEEL + Vector3(0.05, VALVE_GRIP.x, 0.0)
	return [c + Vector3(0.0, 0.0, VALVE_GRIP.y), c - Vector3(0.0, 0.0, VALVE_GRIP.y)]


## Лебёдка: обе руки на рукояти опоры со стороны члена экипажа (x, z).
static func winch(x: float, z: float) -> Array[Vector3]:
	var d := Vector3(x - Samples.BASE.x, 0.0, z - Samples.BASE.z)
	d = d.normalized() if d.length() > 1e-3 else Vector3.LEFT
	var side := Vector3.UP.cross(d)
	var p := Vector3(Samples.BASE.x, WINCH_Y, Samples.BASE.z) + d * (Samples.COLUMN_R + 0.04)
	return [p - side * WINCH_SPREAD, p + side * WINCH_SPREAD]


## Сканер: ладони на раме экрана (стоя лицом к +X, левая — к носу, −z).
static func scanner() -> Array[Vector3]:
	var p := BridgeProps.SCANNER_POS
	return [p + Vector3(SCANNER_GRIP.x, SCANNER_GRIP.y, -SCANNER_GRIP.z),
		p + Vector3(SCANNER_GRIP.x, SCANNER_GRIP.y, SCANNER_GRIP.z)]


## Щиток машинного: правая рука на крышке.
static func scram() -> Array[Vector3]:
	return [FREE, SCRAM_GRIP]
