class_name Touch
## Сенсорное управление без узлов: раскладка, крестовина, разбор касаний.
## Экран Godot: начало вверху слева, y вниз. Крестовина внизу слева, кнопка действия внизу справа.


## Раскладка органов от безопасной области экрана (вырезы телефона), размеры — от её короткой стороны.
class Layout:
	const PAD_SHARE := 0.19
	const ACTION_SHARE := 0.11
	const MARGIN_SHARE := 0.06
	const PILOT_SHARE := 0.075
	## Подписи кнопок пилота (#1918): кегль — доля радиуса, но не мельче LABEL_MIN короткой стороны (≈ 12 sp на 6").
	const LABEL_MIN := 0.03
	const LIFT_LABEL := 0.36   ## «Всплыть», «Вниз»
	const LIGHT_LABEL := 0.4   ## «Свет»
	const LABEL_PAD := 12.0 / 720.0  ## поля подписи внутри круга, доля короткой стороны (оба края вместе)

	var pad := Circle.new()
	var action := Circle.new()
	var up := Circle.new()
	var down := Circle.new()
	var light := Circle.new()
	var noclip := Circle.new()  ## тестовая кнопка «noclip» в правом верхнем углу
	## Безопасная область экрана (без вырезов), от которой разложены органы: по ней же — плашки поверх них (#603).
	var area := Rect2()
	var side := 0.0  ## короткая сторона безопасной области: от неё радиусы и нижний предел кегля

	func compute(safe: Rect2) -> void:
		area = safe
		var s := minf(safe.size.x, safe.size.y)
		side = s
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

	## Кегль подписи кнопки пилота, px: доля k радиуса, не мельче LABEL_MIN короткой стороны (вверх до целого).
	func label_px(c: Circle, k: float) -> int:
		return int(ceilf(maxf(c.r * k, side * LABEL_MIN)))

	## Сколько места у строки внутри круга, px: диаметр без полей.
	func label_room(c: Circle) -> float:
		return c.r * 2.0 - side * LABEL_PAD

	## Прямоугольники вокруг органов под пальцами с зазором gap (#1345): крестовина и кнопка действия, у пилота — ещё
	## «Всплыть», «Вниз», «Свет». На них не ложатся плашки, которые ловят касания (карточка роли).
	func rects(pilot: bool, gap: float = 0.0) -> Array:
		var cs: Array = [pad, action]
		if pilot:
			cs.append_array([up, down, light])
		var out: Array = []
		for c: Circle in cs:
			out.append(Rect2(c.c - Vector2(c.r, c.r), Vector2(c.r, c.r) * 2.0).grow(gap))
		return out


class Circle:
	var c := Vector2.ZERO
	var r := 0.0

	func _init(center: Vector2 = Vector2.ZERO, radius: float = 0.0) -> void:
		c = center
		r = radius

	func has(p: Vector2) -> bool:
		return p.distance_to(c) <= r


const DEAD_ZONE := 0.2  ## доля радиуса крестовины: в центре — стоп
## Дожим за упором взгляда для режима «у порта» (#2095): столько «точек» (≈0,3″) в ту же сторону после упора.
const LEAN_PUSH := 48.0


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
	enum Role { PAD, ACTION, LOOK, UP, DOWN, LIGHT, NOCLIP, UI }

	var layout := Layout.new()
	var pilot_buttons := false  ## за штурвалом работают «Всплыть», «Вниз», «Свет»
	var move := Vector2i.ZERO
	var action_down := false
	var action_pressed := false  ## нажали в этом кадре
	var light_pressed := false
	var noclip_pressed := false  ## нажали тестовую кнопку noclip в этом кадре
	var look := Vector2.ZERO     ## смещение пальцев обзора за кадр, px
	var taps: Array[Vector2] = []   ## где пальцы коснулись экрана в этом кадре — кнопки диалогов (NetDrop)
	## Прямоугольники экрана, где касание берёт интерфейс поверх игры (карточка роли ART-045): палец там не крутит
	## взгляд — только `taps`. Кнопки управления важнее.
	var blocks: Array[Rect2] = []
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
		else:
			for b in blocks:
				if b.has_point(p):
					role = Role.UI
		_fingers[id] = [role, p, p]
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

	## Где сейчас пальцы на экране (ползунки настроек ART-037).
	func points() -> Array[Vector2]:
		var out: Array[Vector2] = []
		for f in _fingers.values():
			out.append(f[1])
		return out

	## Держит ли палец кнопку интерфейса (рация ART-041): коснулся внутри `r` и ещё на экране — можно сползти.
	func held_in(r: Rect2) -> bool:
		for f in _fingers.values():
			if f[0] == Role.UI and r.has_point(f[2]):
				return true
		return false

	## Касается ли экрана хоть один палец.
	func touching() -> bool:
		return not _fingers.is_empty()

	## Ввод кадра не идёт в игру, пальцы остаются на экране (ползунок настроек поверх идущего мира).
	func mute() -> void:
		move = Vector2i.ZERO
		action_down = false
		end_frame()

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

	## Палец обзора на экране: накопление дожима «у порта» (#2095) сбрасывается, когда его отпустили.
	func has_look() -> bool:
		return _has(Role.LOOK)

	func _apply(id: int, p: Vector2) -> void:
		var f: Array = _fingers[id]
		match f[0]:
			Role.PAD:
				move = Touch.dpad(p - layout.pad.c, layout.pad.r)
			Role.LOOK:
				look += p - f[1]
		f[1] = p
