extends TestCase
## Флаг раннера `-- --say` (#1350, 13.11): сообщения пройденных проверок попадают в лог.


func _probe(on: bool) -> TestCase:
	var was := TestCase.say
	TestCase.say = on
	var t := TestCase.new()
	t.ok(true)                                  # без своего сообщения — не пишется
	t.ok(true, "хищник дальше 30 м")
	t.eq(3, 3, "клеток за шаг")
	t.eq(3, 3)                                  # без сообщения — не пишется
	t.near(30.25, 30.0, 0.5, "хищник дальше, м")
	t.ok(false, "упало")                       # падение — в failures, не в spoken
	TestCase.say = was
	return t


func test_said_when_on() -> void:
	var t := _probe(true)
	eq(t.spoken.size(), 3, "строк пройденных проверок")
	if t.spoken.size() == 3:
		eq(t.spoken[0], "хищник дальше 30 м")
		eq(t.spoken[1], "клеток за шаг: 3")
		ok(t.spoken[2].begins_with("хищник дальше, м: получено 30.250000"), t.spoken[2])
	eq(t.failures, ["упало"] as Array[String], "падения как раньше")


func test_silent_by_default() -> void:
	var t := _probe(false)
	eq(t.spoken.size(), 0, "без флага пройденные молчат")
	eq(t.failures.size(), 1)


func test_runner_reads_flag() -> void:
	var src := FileAccess.get_file_as_string("res://tests/run.gd")
	ok(src.contains('arg == "--say"'), "раннер разбирает --say")
	ok(src.contains("`-- --say`"), "флаг описан в шапке run.gd")
	ok(src.contains("t.spoken"), "раннер печатает сказанное")
