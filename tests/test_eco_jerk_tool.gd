extends TestCase
## `tools/jerk.gd` (#1400): у мест, где ближе near никого нет, вместо пустого списка худших — строка с ближайшими
## за прогон, чтобы отличить «мир у точки не заселён» от «точка съёмки далеко от жизни».


func test_quiet_line_names_nearest_first() -> void:
	var tool: GDScript = load("res://tools/jerk.gd")
	var line: String = tool.quiet_line(50.0, {"Рыбы": 74.2, "Скаты": 61.0, "Мох": 130.0}, 2)
	ok(line.begins_with("  ближе 50 м никого"), line)
	ok(line.find("Скаты 61 м") < line.find("Рыбы 74 м"), "ближайший первым: " + line)
	ok(line.find("Мох") < 0, "не больше top: " + line)


func test_quiet_line_without_anyone() -> void:
	var tool: GDScript = load("res://tools/jerk.gd")
	var line: String = tool.quiet_line(120.0, {}, 5)
	ok(line.ends_with("нет ни одного"), line)
