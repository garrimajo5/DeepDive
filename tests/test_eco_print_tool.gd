extends TestCase
## `tools/eco_print.gd` (#1400, (ан)): отпечаток живого мира для сравнения облака и CI — одинаковый мир даёт одну строку,
## разница в одном бите float у существа — другую, и `first_diff` называет время и разошедшуюся часть.

const EcoPrint := preload("res://tools/eco_print.gd")
const MidCalm := preload("res://tools/mid_calm.gd")


func test_same_world_same_line_and_bit_diff_found() -> void:
	var a: EcoView = MidCalm.make(1)
	var b: EcoView = MidCalm.make(1)
	for i in 30:
		a.world.step(EcoWorld.MAX_STEP)
		b.world.step(EcoWorld.MAX_STEP)
	var la := [EcoPrint.line(a.world.time, EcoPrint.of(a.world))]
	var lb := [EcoPrint.line(b.world.time, EcoPrint.of(b.world))]
	eq(la[0], lb[0], "одно зерно, те же шаги — одна строка")
	ok(EcoPrint.first_diff(la, lb).is_empty(), "расхождения нет")
	var p := EcoPrint.parse(la[0])
	ok(p["parts"].has("EcoPred") and p["parts"].has("существа/pred") and p["parts"].has("случай"), "части модулей, существ и случая")
	near(float(p["t"]), a.world.time, 0.051, "время в строке")
	var pr: EcoPred.Pred = b.preds.all[0]
	pr.agent.p.x += 1e-3   # миллиметр (Vector3 — float32): глазом не видно, в отпечатке — видно
	ok(pr.agent.p.x != a.preds.all[0].agent.p.x, "сдвиг есть")
	lb.append(EcoPrint.line(b.world.time + 10.0, EcoPrint.of(b.world)))
	la.append(EcoPrint.line(a.world.time + 10.0, EcoPrint.of(a.world)))
	var d := EcoPrint.first_diff(la, lb)
	ok(not d.is_empty(), "расхождение найдено")
	near(float(d.get("t", 0.0)), a.world.time + 10.0, 0.051, "во второй точке, не в первой")
	ok("существа/pred" in d.get("parts", []), "в серпохвостах: %s" % [d.get("parts", [])])
	ok(EcoPrint.parse("чужая строка").is_empty(), "чужая строка не разбирается")
	a.free()
	b.free()


## Отпечаток libm машины в лог (#1400, (ан)): полный мир расходится у облака (Ubuntu 24.04, glibc 2.39) и CI
## (ubuntu-26.04) с первых 10 с. Сравнить эту строку в логе CI с локальной — какая функция считает иначе.
func test_math_print() -> void:
	var s := EcoPrint.math_line()
	print("    " + s)
	eq(s, EcoPrint.math_line(), "на одной машине — одна строка")
	ok(s.begins_with("математика sin="), "строка разобрана")
