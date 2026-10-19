class_name HullPlan
## «Ковчег-7» снаружи по принятому концепту ART-001 (docs/concept-art/kovcheg-7.md): 28 простых деталей.
## Нос в −Z, пол отсеков y = 0. Корпус подогнан к отсекам (мостик шириной 10 м, всё внутри от z = −6 до 24), поэтому
## длиннее и шире, чем в заметках художника: 37 м с двигателями, 13,6 м в носовой оболочке. Детали симметричны по x
## (кроме деталей на оси), поэтому числа из Unity-версии (pogrujenie Core/HullPlan.cs) не меняют знак.
## Без узлов: форму корпуса читает и поток Б (существа не проходят сквозь корабль — inside()).
##
## Формы в единичных величинах: куб 1 м; шар Ø1; цилиндр, капсула, усечённый конус и труба Ø1 высотой 2 по оси y;
## купол — шар Ø1, срезанный плоскостью y = −0,25; ротор — диск Ø1 толщиной 1 с пятью лопастями;
## клин — брусок 1 м, толстый у −z и острый у +z; пластина — квадрат 1 м в плоскости xy лицом в +z.

enum Form { CUBE, SPHERE, CYLINDER, CAPSULE, DOME, FRUSTUM, TUBE, ROTOR, WEDGE, PLATE }
enum Paint { METAL, SEAM, WINDOW, LENS, LOCK }
enum Piece { BODY, NOSE, STERN, GLASS, LAB_WINDOW, SHROUD, ROTOR, MOUNT, RUDDER, STABILIZER, SEARCHLIGHT, MANIPULATOR, AIRLOCK, COVER }

const COLORS := {
	Paint.METAL: Color("8C806B"),
	Paint.SEAM: Color("514D43"),
	Paint.WINDOW: Color("F6DEAC"),
	Paint.LENS: Color("E9F7FF"),
	Paint.LOCK: Color("9AD9E8"),
}

const CENTER_Y := 1.6
## Основной объём: сплюснутая капсула 12,8 × 6 м от z = −7 до 27.
const BODY_W := 12.8
const BODY_H := 6.0
const BODY_Z := 10.0
const BODY_HALF := 17.0
## Носовая оболочка: эллипсоид 13,6 × 6,4 × 16 м, срезан спереди плоскостью z = −7,2 под стекло.
const NOSE_W := 13.6
const NOSE_H := 6.4
const NOSE_L := 8.0
const NOSE_Z := -3.2
const NOSE_CUT := -7.2
## Двигатели: центры кожухов.
const ENGINE_X := 5.4
const ENGINE_Y := 1.0
const ENGINE_Z := 26.5
const SHROUD_D := 2.6
const SHROUD_L := 2.2
const SEARCHLIGHT_Y := -0.1
const LENS_Z := -7.75
## Нижний шлюз трюма (крышка под проёмом в полу, ART-010).
const AIRLOCK_Z := 22.0
const AIRLOCK_Y := -1.15
const AIRLOCK_R := 1.1
const AIRLOCK_THICK := 0.2
const STERN_END := 29.0


## Деталь: форма, краска, центр, масштаб и поворот (градусы: сначала z, потом x, потом y — как в Unity-версии).
class Part:
	var name: String
	var piece: int
	var form: int
	var paint: int
	var pos: Vector3
	var size: Vector3
	var rot: Vector3

	func _init(n: String, nd: int, f: int, p: int, at: Vector3, s: Vector3, r: Vector3 = Vector3.ZERO) -> void:
		name = n
		piece = nd
		form = f
		paint = p
		pos = at
		size = s
		rot = r

	static func _rot(a: float, b: float, deg: float) -> Vector2:
		if deg == 0.0:
			return Vector2(a, b)
		var r := deg_to_rad(deg)
		return Vector2(a * cos(r) - b * sin(r), a * sin(r) + b * cos(r))

	## Повернуть вектор из осей детали в оси корабля.
	func rotate(v: Vector3) -> Vector3:
		var q := _rot(v.x, v.y, rot.z)
		v.x = q.x; v.y = q.y
		q = _rot(v.y, v.z, rot.x)
		v.y = q.x; v.z = q.y
		q = _rot(v.z, v.x, rot.y)
		v.z = q.x; v.x = q.y
		return v

	## Обратный поворот: из осей корабля в оси детали.
	func unrotate(v: Vector3) -> Vector3:
		var q := _rot(v.z, v.x, -rot.y)
		v.z = q.x; v.x = q.y
		q = _rot(v.y, v.z, -rot.x)
		v.y = q.x; v.z = q.y
		q = _rot(v.x, v.y, -rot.z)
		v.x = q.x; v.y = q.y
		return v

	## Преобразование единичной формы в оси корабля (для меша).
	func xform() -> Transform3D:
		var b := Basis(rotate(Vector3.RIGHT) * size.x, rotate(Vector3.UP) * size.y, rotate(Vector3.BACK) * size.z)
		return Transform3D(b, pos)

	## Точка в осях корабля → в единичных осях формы.
	func to_local(p: Vector3) -> Vector3:
		return unrotate(p - pos) / size

	## Внутри ли точка (оси корабля) сплошной детали. Для пластины, трубы, ротора и клина — всегда нет.
	func contains(p: Vector3) -> bool:
		var l := to_local(p)
		var rr := l.x * l.x + l.z * l.z
		match form:
			Form.CUBE:
				return absf(l.x) <= 0.5 and absf(l.y) <= 0.5 and absf(l.z) <= 0.5
			Form.SPHERE:
				return rr + l.y * l.y <= 0.25
			Form.DOME:
				return l.y >= -0.25 and rr + l.y * l.y <= 0.25
			Form.CYLINDER:
				return absf(l.y) <= 1.0 and rr <= 0.25
			Form.CAPSULE:
				var dy := l.y - clampf(l.y, -0.5, 0.5)
				return rr + dy * dy <= 0.25
			Form.FRUSTUM:
				if absf(l.y) > 1.0:
					return false
				var r := HullPlan.frustum_radius(l.y)
				return rr <= r * r
		return false


## Радиус усечённого конуса на высоте ly: 0,5 внизу (y = −1), 0,25 вверху (y = 1).
static func frustum_radius(ly: float) -> float:
	return 0.5 - 0.125 * (ly + 1.0)


static var _parts: Array[Part] = []


static func parts() -> Array[Part]:
	if _parts.is_empty():
		_parts = _build()
	return _parts


static func _build() -> Array[Part]:
	var p: Array[Part] = []
	var add := func(n: String, nd: int, f: int, pt: int, at: Vector3, s: Vector3, r: Vector3 = Vector3.ZERO) -> void:
		p.append(Part.new(n, nd, f, pt, at, s, r))
	var M := Paint.METAL
	var S := Paint.SEAM
	# поворот (90, 0, 0) кладёт ось y формы вдоль +Z корабля; масштаб: (ширина, длина/2 или длина, высота)
	add.call("Корпус", Piece.BODY, Form.CAPSULE, M, Vector3(0, CENTER_Y, BODY_Z), Vector3(BODY_W, BODY_HALF, BODY_H), Vector3(90, 0, 0))
	# купол срезан у −y формы, после поворота срез смотрит в нос
	add.call("Носовая оболочка", Piece.NOSE, Form.DOME, M, Vector3(0, CENTER_Y, NOSE_Z), Vector3(NOSE_W, NOSE_L * 2, NOSE_H), Vector3(90, 0, 0))
	# кормовой переход: широкий конец у −y формы → к носу; z от 21 до 29
	add.call("Кормовой переход", Piece.STERN, Form.FRUSTUM, M, Vector3(0, CENTER_Y, 25), Vector3(11, 4, 5.2), Vector3(90, 0, 0))
	# панорамное стекло на срезе носа, лицом вперёд (пластина смотрит в +z, поворот на 180°)
	add.call("Панорамное стекло", Piece.GLASS, Form.PLATE, Paint.WINDOW, Vector3(0, 1.75, NOSE_CUT - 0.02), Vector3(9, 2, 1), Vector3(0, 180, 0))
	# окна лаборатории: по два на борт, на цилиндрической части корпуса у отсека z 8…14
	for sx in [-1.0, 1.0]:
		for z in [10.1, 11.9]:
			add.call("Окно лаборатории", Piece.LAB_WINDOW, Form.PLATE, Paint.WINDOW,
				Vector3(sx * (BODY_W / 2 + 0.02), CENTER_Y, z), Vector3(1.7, 1, 1), Vector3(0, sx * 90.0, 0))
	for sx in [-1.0, 1.0]:
		var ex: float = sx * ENGINE_X
		add.call("Кожух двигателя", Piece.SHROUD, Form.TUBE, M, Vector3(ex, ENGINE_Y, ENGINE_Z), Vector3(SHROUD_D, SHROUD_L / 2, SHROUD_D), Vector3(90, 0, 0))
		add.call("Ротор", Piece.ROTOR, Form.ROTOR, S, Vector3(ex, ENGINE_Y, ENGINE_Z), Vector3(SHROUD_D * 0.8, 0.15, SHROUD_D * 0.8), Vector3(90, 0, 0))
		add.call("Крепление двигателя", Piece.MOUNT, Form.CUBE, S, Vector3(sx * 3.45, ENGINE_Y, ENGINE_Z - 0.2), Vector3(1.5, 0.45, 1.4))
		# клин: размах по x, толщина по y, хорда по z; острый край к корме
		add.call("Руль глубины", Piece.RUDDER, Form.WEDGE, M, Vector3(sx * 5.2, 2.6, 24.6), Vector3(2.6, 0.22, 1.8))
	# поворот (0, 0, 90) ставит клин вертикально: размах по y
	add.call("Верхний стабилизатор", Piece.STABILIZER, Form.WEDGE, M, Vector3(0, 4.2, 25), Vector3(1.6, 0.26, 2.6), Vector3(0, 0, 90))
	add.call("Нижний стабилизатор", Piece.STABILIZER, Form.WEDGE, M, Vector3(0, -0.8, 25), Vector3(1.2, 0.22, 2.2), Vector3(0, 0, 90))
	# прожектор под стеклом: корпус-цилиндр вдоль Z и светящаяся линза
	add.call("Корпус прожектора", Piece.SEARCHLIGHT, Form.CYLINDER, S, Vector3(0, SEARCHLIGHT_Y, -7.4), Vector3(0.9, 0.3, 0.9), Vector3(90, 0, 0))
	add.call("Линза прожектора", Piece.SEARCHLIGHT, Form.SPHERE, Paint.LENS, Vector3(0, SEARCHLIGHT_Y, LENS_Z), Vector3(0.75, 0.75, 0.12))
	# манипулятор под носом: основание, два звена (капсулы), две губки захвата
	add.call("Основание манипулятора", Piece.MANIPULATOR, Form.CYLINDER, S, Vector3(0, -1.5, -5.5), Vector3(1, 0.15, 1))
	add.call("Звено манипулятора", Piece.MANIPULATOR, Form.CAPSULE, M, Vector3(0, -1.9, -6.4), Vector3(0.35, 0.95, 0.35), Vector3(-108.4, 0, 0))
	add.call("Звено манипулятора", Piece.MANIPULATOR, Form.CAPSULE, M, Vector3(0, -1.95, -7.95), Vector3(0.3, 0.7, 0.3), Vector3(-69, 0, 0))
	for sx in [-1.0, 1.0]:
		add.call("Губка захвата", Piece.MANIPULATOR, Form.WEDGE, S, Vector3(sx * 0.17, -1.65, -8.85), Vector3(0.12, 0.25, 0.6), Vector3(0, 180, 0))
	# нижний шлюз трюма и сервисные крышки на спине
	add.call("Нижний шлюз", Piece.AIRLOCK, Form.CYLINDER, Paint.LOCK, Vector3(0, AIRLOCK_Y, AIRLOCK_Z), Vector3(AIRLOCK_R * 2, AIRLOCK_THICK, AIRLOCK_R * 2))
	add.call("Сервисная крышка", Piece.COVER, Form.CUBE, S, Vector3(0, 4.62, 15.5), Vector3(2.4, 0.25, 1.8))
	add.call("Сервисная крышка", Piece.COVER, Form.CUBE, S, Vector3(0, 4.62, 19), Vector3(2.4, 0.25, 1.8))
	return p


## Внутри ли точка (оси корабля) основного объёма: корпус, носовая оболочка или кормовой переход.
static func inside(p: Vector3) -> bool:
	for part in parts():
		if (part.piece == Piece.BODY or part.piece == Piece.NOSE or part.piece == Piece.STERN) and part.contains(p):
			return true
	return false


## Внутри ли точка мира корпуса корабля, стоящего в ship_pos с курсом yaw (для существ: не заплывать в корабль).
static func inside_world(p: Vector3, ship_pos: Vector3, yaw: float) -> bool:
	return inside((p - ship_pos).rotated(Vector3.UP, -yaw))


## Светится ли краска сама: окна, линза, метка шлюза. Металл эмиссией не красим.
static func glows(paint: int) -> bool:
	return paint == Paint.WINDOW or paint == Paint.LENS or paint == Paint.LOCK
