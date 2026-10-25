class_name ShipMap
extends RefCounted
## Схема корабля по ART-042 (`docs/concept-art/shema.md`, `shema-korablya.png`, `shema-sostoyaniya.png`): вид сверху
## поверх затемнённой сцены — пять отсеков из `ShipLayout.ROOMS` и `Deck.BRIDGE_MIN/MAX`, люки (`Door.passable`),
## значки постов `Deck.posts()` из атласа `textures/shema/znachki.png`, отметки экипажа (свой — «Вы здесь»),
## тревога янтарём (пробоина — отсек и место сварки, перегрев — вентиль, стеклоуст — разряд), легенда и линейка 5 м.
## Вход — «Схема корабля» в паузе / меню забега ART-037 (`Pause`), «Назад» и системная «Назад» возвращают туда.
## Здесь — состояние и раскладка без узлов; рисует `scripts/game/ship_map_panel.gd` (`main.ship_map_panel`),
## шаг — `Main._map_step`. Раскладка — в пикселях макета высотой 1080 на всю ширину экрана: масштаб H/1080,
## ширина макета W·1080/H. Нос влево, правый борт (+X) вверх: X = X0 + (z + 6)·s, Y = 520 − x·s.

const REF_H := 1080.0
const TITLE := "Схема корабля"
const TITLE_AT := Vector2(-90, 52)   ## от X0 плана; y — верх глифов
const TITLE_PX := 56.0
const BACK_TEXT := "Назад"
const BACK_W := 660.0                ## «Назад»: x = W − 660, y 48, 300×112
const BACK := Rect2(0, 48, 300, 112)
const BACK_PX := 38.0
const NOSE := "Нос · вид сверху"   ## стрелки к носу и корме рисуются линиями (в шрифте игры их нет)
const STERN := "Корма"
const ARROW := 30.0                  ## стрелка у «Нос» / «Корма»: длина, отступ до текста — 10
const ENDS_TOP := 178.0              ## верх глифов «Нос» / «Корма»
const ENDS_PX := 28.0
const NAMES_TOP := 220.0             ## верх глифов названий отсеков
const NAMES_PX := 30.0
const NAMES: Array[String] = ["Мостик", "Коридор", "Лаборатория", "Машинное", "Трюм"]
const CENTER_Y := 520.0
const PLAN_M := 30.0                 ## длина плана, м: z −6…24
const SIDE := 720.0                  ## поля по бокам вместе: s = min(50, (W − 720)/30)
const MAX_S := 50.0
const EDGE := 3.0                    ## контур отсека, px
const DOOR_TICK := 0.5               ## голубой торец проёма, м по z (по 0,25 в обе стороны)
const DOOR_TEXT := "Люк закрыт"
const DOOR_PX := 24.0
const DOOR_GAP := 30.0               ## подпись закрытого люка ниже большего из соседних отсеков
const ICON := 48.0                   ## значок поста, px макета (не зависит от масштаба плана)
const MARK := 50.0                   ## кружок игрока
const MARK_PX := 32.0
const HERE := "Вы здесь"
const HERE_PX := 30.0
const HERE_LINE := 40.0              ## выноска «Вы здесь» вниз от кружка
const SPREAD := 48.0                 ## разнос наложенных отметок
const RULER_M := 5.0
const RULER_GAP := 40.0              ## линейка ниже мостика
const RULER_PX := 22.0
const LEGEND_Y: Array[float] = [884.0, 966.0]   ## центры строк легенды
const LEGEND_STEP := 0.28            ## шаг колонок — доля длины плана
const LEGEND_PX := 30.0
const ALARM_EDGE := 5.0
const ALARM_BOX := 64.0
const ALARM_PX: Array[float] = [28.0, 22.0]
const ALARM_TOP := 790.0             ## подпись тревоги за мостиком: верх глифов первой строки
const ALARM_SIDE := 24.0             ## подпись тревоги на мостике: отступ от левого края плана
const ALARM_STEP := 34.0             ## вторая строка ниже первой
const DIM := 0.9                    ## затемнение сцены под схемой (табло и окна не спорят с планом)
const AMBER := Color("#FFB259")
const ACCENT := Color("#67DDEB")
const ICON_COLOR := Color("#D5E4E8")

## Атлас значков ART-042 (`shema-znachki.png`): 512×384, ячейки 128²; пост → ячейка.
const ATLAS := "res://textures/shema/znachki.png"
const CELL := 128
const CELLS := {
	"helm": Vector2i(0, 0), "energy": Vector2i(1, 0), "scanner": Vector2i(2, 0), "sonar": Vector2i(3, 0),
	"zap": Vector2i(0, 1), "airlock": Vector2i(1, 1), "valve": Vector2i(2, 1), "scram": Vector2i(3, 1),
	"weld": Vector2i(0, 2),
}
## Легенда: две строки по четыре значка.
const LEGEND := [["helm", "Штурвал"], ["energy", "Энергия"], ["scanner", "Сканер"], ["sonar", "Сонар"],
	["zap", "Разряд"], ["airlock", "Шлюз"], ["valve", "Вентиль"], ["scram", "Сброс"]]
const LETTERS := ["П", "С", "И", "Б"]

var open := false
var from := ""   ## откуда открыли: "pause" — пауза / меню забега


## Отметка игрока: настоящая точка на экране, место кружка (после разноса), буква роли, свой ли.
class Mark:
	var at := Vector2.ZERO
	var pos := Vector2.ZERO
	var letter := ""
	var own := false


## Цель тревоги: отсек, точка ремонта (x, z), значок и две строки выноски.
class Alarm:
	var room := 0
	var at := Vector2.ZERO
	var icon := ""
	var lines: Array[String] = []


func open_from(where: String) -> void:
	open = true
	from = where


## «Назад» (кнопка или системная): закрыть и вернуть, откуда открыли.
func back() -> String:
	var w := from
	open = false
	from = ""
	return w


func close() -> void:
	open = false
	from = ""


## Касание: "back" — «Назад», "" — мимо (касание люка и постов ничего не делает).
func hit(p: Vector2, size: Vector2) -> String:
	return "back" if open and back_rect(size).has_point(p) else ""


## Масштаб макета на экран и ширина макета.
static func k(size: Vector2) -> float:
	return size.y / REF_H


static func width(size: Vector2) -> float:
	return size.x / k(size)


## Масштаб плана, px макета на метр, и левый край плана (z = −6) в макете.
static func plan_s(size: Vector2) -> float:
	return minf(MAX_S, (width(size) - SIDE) / PLAN_M)


static func plan_x0(size: Vector2) -> float:
	return (width(size) - PLAN_M * plan_s(size)) * 0.5


## Точка корабля (x — к правому борту, z — к корме) на экране.
static func to_screen(x: float, z: float, size: Vector2) -> Vector2:
	var s := plan_s(size)
	return Vector2(plan_x0(size) + (z + 6.0) * s, CENTER_Y - x * s) * k(size)


## Точка макета на экране.
static func at(p: Vector2, size: Vector2) -> Vector2:
	return p * k(size)


## Отсек в осях: (z от, z до, полуширина).
static func room_box(room: int) -> Vector3:
	if room == ShipLayout.Room.BRIDGE:
		return Vector3(Deck.BRIDGE_MIN.y, Deck.BRIDGE_MAX.y, Deck.BRIDGE_MAX.x)
	var r: Array = ShipLayout.ROOMS[room]
	return Vector3(r[0], r[1], r[2])


## Прямоугольник отсека на экране.
static func room_rect(room: int, size: Vector2) -> Rect2:
	var b := room_box(room)
	var a := to_screen(b.z, b.x, size)
	var c := to_screen(-b.z, b.y, size)
	return Rect2(a, c - a)


## Проём люка i на экране: полоса шириной 1,4 м поперёк переборки (по x), тонкая по z.
static func door_rect(i: int, size: Vector2) -> Rect2:
	var z: float = ShipLayout.DOOR_Z[i]
	var h := ShipLayout.DOOR_HALF
	var w := EDGE * 2.0 * k(size)
	var a := to_screen(h, z, size)
	var b := to_screen(-h, z, size)
	return Rect2(a.x - w * 0.5, a.y, w, b.y - a.y)


## Место подписи «Люк закрыт» (центр, верх глифов) под переборкой i.
static func door_label(i: int, size: Vector2) -> Vector2:
	var z: float = ShipLayout.DOOR_Z[i]
	var half := maxf(room_box(ShipLayout.room_at(z - 0.2)).z, room_box(ShipLayout.room_at(z + 0.2)).z)
	return Vector2(to_screen(0.0, z, size).x, (CENTER_Y + half * plan_s(size) + DOOR_GAP) * k(size))


## Значок поста (48 px макета) в его точке на полу.
static func icon_rect(p: Vector2, size: Vector2) -> Rect2:
	var c := to_screen(p.x, p.y, size)
	var w := ICON * k(size)
	return Rect2(c - Vector2(w, w) * 0.5, Vector2(w, w))


## Ячейка атласа значка.
static func cell(id: String) -> Rect2:
	var c: Vector2i = CELLS[id]
	return Rect2(c.x * CELL, c.y * CELL, CELL, CELL)


## Посты на плане: [id, точка (x, z)] — все из `Deck.posts()`, у которых есть значок.
static func posts() -> Array:
	var out: Array = []
	for p in Deck.posts():
		if CELLS.has(p.id):
			out.append([p.id, p.at])
	return out


static func back_rect(size: Vector2) -> Rect2:
	var kk := k(size)
	return Rect2(Vector2(width(size) - BACK_W, BACK.position.y) * kk, BACK.size * kk)


## Линейка 5 м: начало и конец на экране (под мостиком, от носа).
static func ruler(size: Vector2) -> Array:
	var kk := k(size)
	var y := CENTER_Y + Deck.BRIDGE_MAX.x * plan_s(size) + RULER_GAP
	var x0 := plan_x0(size)
	return [Vector2(x0, y) * kk, Vector2(x0 + RULER_M * plan_s(size), y) * kk]


## Центр значка i-й строки легенды (текст — правее на 60 px макета).
static func legend_at(i: int, size: Vector2) -> Vector2:
	var step := PLAN_M * plan_s(size) * LEGEND_STEP
	var x := plan_x0(size) + TITLE_AT.x + ICON * 0.5 + step * (i % 4)
	return Vector2(x, LEGEND_Y[i / 4]) * k(size)


## Отметки экипажа: points — (x, z) каждого, letters — буквы ролей, own — индекс своего (−1 — нет).
## Наложенные кружки разнесены на SPREAD px макета (выноска к настоящей точке), свой — всегда на месте.
static func marks(points: Array, letters: Array, own: int, size: Vector2) -> Array[Mark]:
	var out: Array[Mark] = []
	var order: Array[int] = []
	if own >= 0 and own < points.size():
		order.append(own)
	for i in points.size():
		if i != own:
			order.append(i)
	var kk := k(size)
	var gap := MARK * kk
	for i in order:
		var m := Mark.new()
		var p: Vector2 = points[i]
		m.at = to_screen(p.x, p.y, size)
		m.pos = m.at
		m.letter = letters[i] if i < letters.size() else ""
		m.own = i == own
		if _crowded(m.pos, out, gap):
			for d in 8:
				var cand := m.at + Vector2.from_angle(-PI * 0.25 - d * PI * 0.25) * SPREAD * kk
				if not _crowded(cand, out, gap):
					m.pos = cand
					break
		out.append(m)
	return out


static func _crowded(p: Vector2, placed: Array[Mark], gap: float) -> bool:
	for m in placed:
		if m.pos.distance_to(p) < gap - 0.01:
			return true
	return false


static func letter(role: int) -> String:
	return LETTERS[clampi(role, 0, LETTERS.size() - 1)]


## Цель тревоги по главному полю табло (`AlarmBoard.main_field`), null — нечего показывать.
## Пробоина — из настоящего события (`Breach.active`), перегрев — вентиль, стеклоуст — рычаг разряда.
static func alarm(field: int, spot: Breach.Spot) -> Alarm:
	var a := Alarm.new()
	match field:
		AlarmBoard.Field.BREACH:
			if spot == null:
				return null
			a.room = spot.room
			a.at = spot.at
			a.icon = "weld"
			a.lines = ["Пробоина", "%s · сварка" % NAMES[spot.room]]
		AlarmBoard.Field.HEAT:
			a.room = ShipLayout.Room.ENGINE
			a.at = EngineRoom.VALVE_POST
			a.icon = "valve"
			a.lines = ["Перегрев", "Машинное · вентиль"]
		AlarmBoard.Field.DRAIN:
			a.room = ShipLayout.Room.BRIDGE
			a.at = Zap.POST_AT
			a.icon = "zap"
			a.lines = ["Стеклоуст", "Мостик · разряд"]
		_:
			return null
	return a


## Рамка 64² у места ремонта на экране.
static func alarm_box(a: Alarm, size: Vector2) -> Rect2:
	var c := to_screen(a.at.x, a.at.y, size)
	var w := ALARM_BOX * k(size)
	return Rect2(c - Vector2(w, w) * 0.5, Vector2(w, w))


## Подпись тревоги: верх глифов первой строки и выравнивание. Отсеки за мостиком — строка ALARM_TOP под планом
## (ниже подписей люков), по центру рамки; мостик — слева от плана на высоте рамки, к правому краю (под мостиком — линейка).
static func alarm_label(a: Alarm, size: Vector2) -> Vector2:
	var box := alarm_box(a, size)
	if alarm_left(a):
		return Vector2(plan_x0(size) * k(size) - ALARM_SIDE * k(size), box.get_center().y - ALARM_PX[0] * k(size))
	return Vector2(box.get_center().x, ALARM_TOP * k(size))


static func alarm_left(a: Alarm) -> bool:
	return a.room == ShipLayout.Room.BRIDGE
