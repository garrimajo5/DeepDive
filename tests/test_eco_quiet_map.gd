extends TestCase
## tools/quiet_map.gd (#1400): печать, попадает ли дом стаи в кольца правил вида — риф у цветка и тихий круг.


func test_reef_home_inside_flower_ring() -> void:
	var line := QuietMap.rings(Vector2(55.0, -69.0))   # риф к юго-востоку от 01 — в 24 м от оси цветка
	ok(line.contains("риф у цветка 24.2 м — внутри"), line)
	ok(line.contains("круга 55 м") and line.contains("тихий круг 98.0 м — вне"), line)


func test_old_home_outside_flower_ring() -> void:
	var line := QuietMap.rings(Vector2(56.0, 6.0))
	ok(line.contains("— вне кольца 32 м"), line)
	ok(line.contains("тихий круг 39.6 м — внутри"), line)


func test_lines_cover_moved_or_all_homes() -> void:
	eq(QuietMap.ring_lines({}).size(), EcoFish.HOMES.size())
	var moved := QuietMap.ring_lines({1: Vector2(-57.0, 23.0)})
	eq(moved.size(), 1)
	ok(moved[0].begins_with("  дом стаи 1 → (-57; 23)"), moved[0])
