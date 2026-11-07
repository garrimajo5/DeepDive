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
