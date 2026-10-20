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
	var scan_range := 0.0        ## сканер биолога включён: дальность прицела, м (80 как в браузере); 0 — выключен

	## Нос корабля в мире.
	func nose() -> Vector3:
		return Vector3(-sin(yaw), 0.0, -cos(yaw))


## ---- События мира → корабль ----
## {"type": HIT, "by": "Серпохвост", "damage": 0…1, "at": Vector3}         — удар по корпусу: доля прочности
##     (0,12 — укус серпохвоста, как −12 % в браузере; 0,03 — щипок)
## {"type": DRAIN, "by": "Стеклоуст", "units": float}                      — тянет заряд корабля, ед./с, пока
##     событие приходит каждый шаг (батарея 0…100, восполняется 1,1 ед./с; стеклоуст — 3,2)
## {"type": NEAR, "species": "pred", "name": "серпохвост", "dist": м, "pos": Vector3, "r": м, "sonar": bool, "scan": bool}
##     — заметное существо рядом (E.scanTargets). species — ключ вида из Species, name — Species.called (настоящее
##     имя, если вид просканирован), dist — до центра корабля, r — размер цели для прицела сканера (м).
##     Сонар: в шаг с ShipState.sonar_ping мир шлёт NEAR для каждого заметного сонару существа ближе sonar_range
##     по горизонтали, у них "sonar": true — это отметки (цвет — Sonar.color_of). Кого сонар не видит (глазун,
##     присоска, скальник в маске), приходит только сканеру.
##     Сканер: пока ShipState.scan_range > 0, мир каждый шаг шлёт NEAR для каждого существа ближе scan_range,
##     кроме спрятавшихся, — у них "scan": true; события идут ближние первыми. Одно существо — одно событие,
##     даже если оно и для сонара, и для сканера; сонар берёт только "sonar": true.
## {"type": MESSAGE, "text": "…"}                                         — строка на приборы как есть
## {"type": OBSERVE, "species": "fish", "note": "flee", "text": "…"}      — наблюдение для журнала (handleEvents
##     в js/game.js): событие шины EcoBus с заметкой вида (Species.is_observation) не дальше EcoBus.HEARING от корабля.
##     text — строка на приборы ("" — без текста); корабль показывает её сам, как MESSAGE, а у нового наблюдения
##     без текста — «Новое наблюдение: …». Отдельный MESSAGE для того же события мир не шлёт.
const HIT := "hit"
const DRAIN := "drain"
const NEAR := "near"
const MESSAGE := "message"
const OBSERVE := "observe"


static func hit(by: String, damage: float, at: Vector3) -> Dictionary:
	return {"type": HIT, "by": by, "damage": clampf(damage, 0.0, 1.0), "at": at}


static func near(species: String, name: String, pos: Vector3, ship_pos: Vector3, r: float = 1.0,
		sonar: bool = true, scan: bool = false) -> Dictionary:
	return {"type": NEAR, "species": species, "name": name, "pos": pos, "dist": pos.distance_to(ship_pos), "r": r,
		"sonar": sonar, "scan": scan}


static func message(text: String) -> Dictionary:
	return {"type": MESSAGE, "text": text}


static func observe(species: String, note: String, text: String = "") -> Dictionary:
	return {"type": OBSERVE, "species": species, "note": note, "text": text}
