class_name AlarmWay
extends RefCounted
## Тревога на строке приборов с «куда» и «что делать» (#1361, разбор #1335): пробоина и перегрев говорят, в каком
## отсеке цель, в какую сторону идти и сколько люков до неё; в отсеке цели — какую кнопку держать. Присоска, ил,
## «мало энергии» и аварийный сброс — как были (`Vitals`, `Silt`, `Reactor.alert`).
## Отсеки по z подряд (`ShipLayout.Room`: мостик → коридор → лаборатория → машинное → трюм), между соседними —
## один люк `ShipLayout.DOOR_Z`, поэтому люков между отсеками a и b — |a − b|.

## Короткие имена отсеков со строчной — для строки тревоги.
const ROOMS: Array[String] = ["мостик", "коридор", "лаборатория", "машинное", "трюм"]


## Сколько люков между отсеками.
static func doors(from_room: int, to_room: int) -> int:
	return absi(to_room - from_room)


## «в корму» — к большему z, «в нос» — к меньшему; тот же отсек — пусто.
static func side(from_room: int, to_room: int) -> String:
	if to_room == from_room:
		return ""
	return "в корму" if to_room > from_room else "в нос"


## «1 люк», «3 люка».
static func doors_text(n: int) -> String:
	return "%d %s" % [n, "люк" if n == 1 else "люка"]


## Ближний люк по пути из отсека в отсек (индекс в `ShipLayout.DOOR_Z`), −1 — уже в отсеке цели.
static func next_door(from_room: int, to_room: int) -> int:
	if to_room == from_room:
		return -1
	return from_room if to_room > from_room else from_room - 1


## Строка пробоины по месту игрока: «ПРОБОИНА · машинное · вода 4 см · в корму, 3 люка» или в отсеке пробоины —
## «ПРОБОИНА · вода 4 см · держите «Сварка»». Пробоины нет — как `Breach.status` (вода после сварки или пусто).
static func breach_line(b: Breach, player_room: int) -> String:
	if b.active == null:
		return b.status()
	var water := "вода %d см" % roundi(b.water * 100.0)
	var room := b.active.room
	if room == player_room:
		return "ПРОБОИНА · %s · держите «Сварка»" % water
	return "ПРОБОИНА · %s · %s · %s, %s" % [ROOMS[room], water, side(player_room, room),
		doors_text(doors(player_room, room))]


## Строка перегрева по месту игрока: «ПЕРЕГРЕВ 112° · вентиль в машинном, в корму» или в машинном —
## «ПЕРЕГРЕВ 112° · держите «Вентиль»». Сброс и спокойный реактор — как `Reactor.alert`.
static func heat_line(r: Reactor, player_room: int) -> String:
	if r.scram > 0.0 or not r.hot:
		return r.alert()
	var head := "ПЕРЕГРЕВ %d°" % roundi(r.heat)
	var room := ShipLayout.Room.ENGINE
	if player_room == room:
		return head + " · держите «Вентиль»"
	return "%s · вентиль в машинном, %s" % [head, side(player_room, room)]


## Указатель на цель тревоги в соло (#1361, часть B): тот же `HintPointer` в янтаре тревоги — над ближним люком по
## пути к цели. Только один игрок в экипаже, подсказки первого забега кончились, горит пробоина (раньше) или перегрев,
## игрок не в отсеке цели: там дальше ведёт рамка `AlarmBoard.hint`. Кооп — голос товарища (этап 5).
const POINTER_UP := 0.25   ## остриё шеврона над проёмом люка, м над DOOR_H
const POINTER_IN := 0.15   ## от переборки к игроку, м: стрелка не прячется в стене люка
const LABEL_PX := 30.0     ## подпись указателя при H = 1080
## Остриё не выше, px при H = 1080: над ним символ (до PX_MAX) и подпись, всё — под строкой приборов в три ряда
## (низ ≈ 172 px). Люк вплотную над головой — кольцо опускается сюда (`HintPointer.lower_tip`).
const TIP_MIN_Y := 172.0 + LABEL_PX * 1.6 + 16.0 + HintPointer.PX_MAX


class Pointer:
	var word := ""    ## «Пробоина» / «Перегрев» — подпись у стрелки у края
	var room := 0     ## отсек цели
	var door := -1    ## ближний люк по пути, индекс в ShipLayout.DOOR_Z
	var anchor := Vector3.ZERO   ## остриё шеврона, оси корабля

	## Подпись под стрелкой / над кольцом: «Пробоина · машинное».
	func label() -> String:
		return "%s · %s" % [word, ROOMS[room]]


## Указатель этого кадра или null. solo — в экипаже один игрок, tutorial — подсказки первого забега ещё идут.
static func pointer(b: Breach, r: Reactor, player_room: int, solo: bool, tutorial: bool) -> Pointer:
	if not solo or tutorial:
		return null
	var p := Pointer.new()
	if b.active != null:
		p.word = "Пробоина"
		p.room = b.active.room
	elif r.hot and r.scram <= 0.0:
		p.word = "Перегрев"
		p.room = ShipLayout.Room.ENGINE
	else:
		return null
	p.door = next_door(player_room, p.room)
	if p.door < 0:
		return null
	var dz := -POINTER_IN if p.room > player_room else POINTER_IN   # со стороны игрока
	p.anchor = Vector3(0.0, ShipLayout.DOOR_H + POINTER_UP, ShipLayout.DOOR_Z[p.door] + dz)
	return p


## Плашка подписи указателя на экране size: text_w — ширина текста, px; symbol — символ мирового указателя на экране
## (плашка над ним) или ячейка стрелки у края (edge, плашка под символом стрелки). Не выходит за экран.
static func label_rect(text_w: float, symbol: Rect2, edge: bool, size: Vector2) -> Rect2:
	var s := size.y / HintPointer.REF_H
	var w := text_w + 2.0 * 14.0 * s
	var h := LABEL_PX * 1.6 * s
	var gap := 8.0 * s
	var c := symbol.get_center()
	var top := symbol.position.y - gap - h
	if edge:
		var arrow := HintPointer.ARROW * s
		var cx := symbol.position.x + HintPointer.ARROW_X * symbol.size.x
		if symbol.size.x < 0.0:   # зеркальная ячейка у правого края
			cx = symbol.position.x + symbol.size.x * (1.0 - HintPointer.ARROW_X)
		c.x = cx
		top = c.y + arrow * 0.5 + gap
	var m := 16.0 * s
	var x := clampf(c.x - w * 0.5, m, size.x - m - w)
	return Rect2(x, clampf(top, m, size.y - m - h), w, h)
