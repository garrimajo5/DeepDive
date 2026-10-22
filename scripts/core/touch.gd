class_name Touch
## Сенсорное управление без узлов: раскладка, крестовина, разбор касаний.
## Экран Godot: начало вверху слева, y вниз. Крестовина внизу слева, кнопка действия внизу справа.


## Раскладка органов от безопасной области экрана (вырезы телефона), размеры — от её короткой стороны.
class Layout:
	const PAD_SHARE := 0.19
	const ACTION_SHARE := 0.11
	const MARGIN_SHARE := 0.06
	const PILOT_SHARE := 0.075

	var pad := Circle.new()
	var action := Circle.new()
	var up := Circle.new()
	var down := Circle.new()
	var light := Circle.new()
	var noclip := Circle.new()  ## тестовая кнопка «noclip» в правом верхнем углу

	func compute(safe: Rect2) -> void:
		var s := minf(safe.size.x, safe.size.y)
		var m := s * MARGIN_SHARE
		var pr := s * PAD_SHARE
		var ar := s * ACTION_SHARE
		var bottom := safe.position.y + safe.size.y
		var tr := s * 0.05
		noclip = Circle.new(Vector2(safe.position.x + safe.size.x - m - tr, safe.position.y + m + tr), tr)
		pad = Circle.new(Vector2(safe.position.x + m + pr, bottom - m - pr), pr)
		# кнопка действия чуть выше нижнего края — там её удобнее достать большим пальцем
		action = Circle.new(Vector2(safe.position.x + safe.size.x - m - ar * 1.3, bottom - m - pr), ar)
		# кнопки пилота: «Всплыть» и «Вниз» столбиком слева от кнопки действия, «Свет» над ней
		var br := s * PILOT_SHARE
		var gap := s * 0.035
		var cx := action.c.x - action.r - gap - br * 1.4
		up = Circle.new(Vector2(cx, action.c.y - br - gap * 0.5), br)
		down = Circle.new(Vector2(cx, action.c.y + br + gap * 0.5), br)
		var over := down.c.y + br - (bottom - gap)
		if over > 0.0:  # на низком экране столбик поднимаем
			up.c.y -= over
			down.c.y -= over
		light = Circle.new(Vector2(action.c.x, action.c.y - action.r - gap - br), br)


class Circle:
	var c := Vector2.ZERO
	var r := 0.0

	func _init(center: Vector2 = Vector2.ZERO, radius: float = 0.0) -> void:
		c = center
		r = radius

	func has(p: Vector2) -> bool:
		return p.distance_to(c) <= r


const DEAD_ZONE := 0.2  ## доля радиуса крестовины: в центре — стоп


## Крестовина на 8 направлений (js/controls.js). d — смещение пальца от центра, y вниз.
## Возвращает (x, y): x вправо, y — вперёд (палец вверх) = 1. Компоненты −1, 0 или 1.
static func dpad(d: Vector2, radius: float) -> Vector2i:
	if d.length() <= radius * DEAD_ZONE:
		return Vector2i.ZERO
	var step := PI / 4.0
	var ang := roundf(atan2(-d.y, d.x) / step) * step
	return Vector2i(int(roundf(cos(ang))), int(roundf(sin(ang))))


## Разбор касаний: палец на крестовине ведёт игрока (можно вести по кругу и за край), на кнопке — держит её,
## остальные — обзор свайпом. Пальцы работают одновременно.
class Router:
	enum Role { PAD, ACTION, LOOK, UP, DOWN, LIGHT, NOCLIP }

	var layout := Layout.new()
	var pilot_buttons := false  ## за штурвалом работают «Всплыть», «Вниз», «Свет»
	var move := Vector2i.ZERO
	var action_down := false
	var action_pressed := false  ## нажали в этом кадре
	var light_pressed := false
	var noclip_pressed := false  ## нажали тестовую кнопку noclip в этом кадре
	var look := Vector2.ZERO     ## смещение пальцев обзора за кадр, px
	var taps: Array[Vector2] = []   ## где пальцы коснулись экрана в этом кадре — кнопки диалогов (NetDrop)
	var _fingers := {}           ## id → [Role, последняя точка]

	func vert() -> int:
		if not pilot_buttons:
			return 0
		if _has(Role.UP):
			return 1
		if _has(Role.DOWN):
			return -1
		return 0

	func begin(id: int, p: Vector2) -> void:
		var role := Role.LOOK
		if layout.pad.has(p):
			role = Role.PAD
		elif layout.action.has(p):
			role = Role.ACTION
		elif layout.noclip.has(p):   # тестовая кнопка всегда доступна
			role = Role.NOCLIP
		elif pilot_buttons and layout.up.has(p):
			role = Role.UP
		elif pilot_buttons and layout.down.has(p):
			role = Role.DOWN
		elif pilot_buttons and layout.light.has(p):
			role = Role.LIGHT
		_fingers[id] = [role, p]
		taps.append(p)
		if role == Role.ACTION:
			action_down = true
			action_pressed = true
		if role == Role.LIGHT:
			light_pressed = true
		if role == Role.NOCLIP:
			noclip_pressed = true
		_apply(id, p)

	func moved(id: int, p: Vector2) -> void:
		if _fingers.has(id):
			_apply(id, p)

	func end(id: int) -> void:
		if not _fingers.has(id):
			return
		var role: Role = _fingers[id][0]
		_fingers.erase(id)
		if role == Role.PAD:
			move = Vector2i.ZERO
		if role == Role.ACTION:
			action_down = _has(Role.ACTION)

	func end_frame() -> void:
		look = Vector2.ZERO
		taps.clear()
		action_pressed = false
		light_pressed = false
		noclip_pressed = false

	## Касается ли экрана хоть один палец.
	func touching() -> bool:
		return not _fingers.is_empty()

	func clear() -> void:
		_fingers.clear()
		move = Vector2i.ZERO
		action_down = false
		end_frame()

	func _has(role: Role) -> bool:
		for f in _fingers.values():
			if f[0] == role:
				return true
		return false

	func _apply(id: int, p: Vector2) -> void:
		var f: Array = _fingers[id]
		match f[0]:
			Role.PAD:
				move = Touch.dpad(p - layout.pad.c, layout.pad.r)
			Role.LOOK:
				look += p - f[1]
		f[1] = p
