class_name EcoLink
## Связь живого мира отмели (поток Б) с кораблём (поток А). Единственное место, где потоки договариваются:
## корабль каждый шаг отдаёт миру ShipState, мир возвращает события (словари ниже). Корабль решает, что событие
## с ним делает (урон, сообщение, тревога); мир не трогает узлы и состояние корабля напрямую.
## Меняется только по согласию потоков: новое поле или событие — в той же PR оба конца и тест в tests/test_eco_link.gd.


## Что мир знает о корабле в этот шаг. Оси мира Godot: нос −Z, +X — восток.
class ShipState:
	var pos := Vector3.ZERO      ## центр корабля в мире
	var yaw := 0.0               ## курс: нос в (−sin yaw, 0, −cos yaw)
	var speed := 0.0             ## м/с вдоль носа
	var light_on := false        ## прожектор светит (включён и есть энергия)
	var light_range := 0.0       ## дальность луча, м
	var sonar_ping := false      ## в этот шаг был импульс сонара
	var sonar_range := 0.0       ## дальность импульса, м
	var zap := false             ## в этот шаг был разряд по корпусу
	var zap_radius := 0.0        ## радиус разряда, м
	var hull_noise := 0.0        ## шум корабля 0…1 (ход, двигатели) — существа слышат

	## Нос корабля в мире.
	func nose() -> Vector3:
		return Vector3(-sin(yaw), 0.0, -cos(yaw))


## ---- События мира → корабль ----
## {"type": HIT, "by": "Серпохвост", "damage": 0…1, "at": Vector3}         — удар по корпусу: доля прочности
##     (0,12 — укус серпохвоста, как −12 % в браузере; 0,03 — щипок)
## {"type": DRAIN, "by": "Стеклоуст", "units": float}                      — тянет заряд корабля, ед./с, пока
##     событие приходит каждый шаг (батарея 0…100, восполняется 1,1 ед./с; стеклоуст — 3,2)
## {"type": NEAR, "species": "serpohvost", "name": "серпохвост", "dist": м, "pos": Vector3} — заметное существо рядом.
##     В шаг с ShipState.sonar_ping мир шлёт NEAR для каждого заметного существа ближе sonar_range — это отметки сонара
##     (species — ключ вида, цвет отметки — Sonar.color_of). Сканер берёт ближайшее NEAR.
## {"type": MESSAGE, "text": "…"}                                         — строка на приборы как есть
const HIT := "hit"
const DRAIN := "drain"
const NEAR := "near"
const MESSAGE := "message"


static func hit(by: String, damage: float, at: Vector3) -> Dictionary:
	return {"type": HIT, "by": by, "damage": clampf(damage, 0.0, 1.0), "at": at}


static func near(species: String, name: String, pos: Vector3, ship_pos: Vector3) -> Dictionary:
	return {"type": NEAR, "species": species, "name": name, "pos": pos, "dist": pos.distance_to(ship_pos)}


static func message(text: String) -> Dictionary:
	return {"type": MESSAGE, "text": text}
