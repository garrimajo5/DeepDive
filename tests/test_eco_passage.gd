extends TestCase
## Склон к Кристальному лесу (#832, часть 2): в проходе 60 м за Краем отмели 06 (`Seabed.Slope`, x 285…430, ±30 м у
## оси) у дна ничего живого мира не стоит — ни существа на месте, ни заметные цели (кусты, камни, гнёзда), корабль
## проходит по оси. «Стоит» — у дна и на том же месте два замера подряд.

const S := Seabed.Slope
const DT := 1.0 / 30.0
const X := Vector2(285.0, 430.0)   ## участок прохода по x
const HALF := 30.0                 ## ±30 м у оси — проход 60 м
const ABOVE := 25.0                ## у дна: не выше этого над дном

var main: Main


func after() -> void:
	if main:
		main.queue_free()
		main = null
	await frames(1)


static func in_passage(p: Vector3) -> bool:
	return p.x >= X.x and p.x <= X.y and absf(p.z - S.GAP_Z) <= HALF and p.y - Seabed.height(p.x, p.z) <= ABOVE


## Что живой мир держит в проходе у дна: ключ → место (существа — по объекту, цели — по виду и месту).
static func standing(w: EcoWorld) -> Dictionary:
	var out := {}
	for a in w.agents:
		if a.alive and in_passage(a.p):
			out["%s #%d" % [a.species, a.get_instance_id()]] = a.p
	for t in w.scan_targets():
		var p: Vector3 = t["pos"]
		if in_passage(p):
			out["%s у (%.0f, %.0f, %.0f)" % [t["species"], p.x, p.y, p.z]] = p
	return out


func test_in_passage_bounds() -> void:
	var floor_y := Seabed.height(360.0, S.GAP_Z)
	ok(in_passage(Vector3(360.0, floor_y + 2.0, S.GAP_Z)), "у дна на оси — в проходе")
	ok(in_passage(Vector3(360.0, floor_y + 2.0, S.GAP_Z + 29.0)), "у края 60 м — в проходе")
	ok(not in_passage(Vector3(360.0, floor_y + 40.0, S.GAP_Z)), "высоко над дном — вода, корабль не цепляет")
	ok(not in_passage(Vector3(360.0, floor_y + 2.0, S.GAP_Z + 40.0)), "в стороне от прохода")
	ok(not in_passage(Vector3(250.0, floor_y + 2.0, S.GAP_Z)), "ещё на Краю отмели")


func test_scene_passage_is_clear() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	var w := main.eco.world
	ok(w.agents.size() > 10 and w.scan_targets().size() > 10, "живой мир есть")
	for x: float in [300.0, 360.0, 420.0]:
		main.park_at(Vector3(x, Seabed.height(x, S.GAP_Z) + 12.0, S.GAP_Z))
		for i in 30:
			main.step(DT)
		var a := standing(w)
		for i in 60:
			main.step(DT)
		var b := standing(w)
		var still := a.keys().filter(func(k: String) -> bool:
			return b.has(k) and (b[k] as Vector3).distance_to(a[k]) < 0.5)
		eq(still, [], "у x = %.0f в проходе ничего не стоит" % x)
