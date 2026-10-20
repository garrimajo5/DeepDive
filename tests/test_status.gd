extends TestCase
## Строка состояния на приборах: раскладка по строкам, сообщения, румбы.

var by_len := func(s: String) -> float: return float(s.length())


func test_parts_wrap_whole() -> void:
	var l := Status.lines(["Трюм", "глубина 20 м", "шлюз открыт", "образцов в трюме 3"], by_len, 30)
	eq(l.size(), 3, "три строки")
	eq(l[0], "Трюм · глубина 20 м", "склеены, пока помещаются")
	eq(l[1], "шлюз открыт", "часть не рвётся посередине")
	for line in l:
		ok(line.length() <= 30 or not line.contains(Status.SEPARATOR), "строка в ширину: %s" % line)


func test_repeat_part_skipped() -> void:
	eq(Status.join(["Трюм", "шлюз открыт", "Шлюз открыт", "", "  "]), "Трюм · шлюз открыт", "повтор и пустые не пишутся")


## По issue #138: часть шире строки (карточка вида из журнала) переносится по словам, а не уходит за край.
func test_long_part_wraps_by_words() -> void:
	var l := Status.lines(["А", "очень длинная часть строки состояния", "Б"], by_len, 14)
	eq(l, PackedStringArray(["А", "очень длинная", "часть строки", "состояния · Б"]), "по словам, хвост склеен со следующей")
	for line in l:
		ok(line.length() <= 14, "в ширину: %s" % line)
	eq(Status.lines(["сверхдлинноеслово"], by_len, 5), PackedStringArray(["сверхдлинноеслово"]), "слово шире строки — одно")


func test_wrap_limited_with_ellipsis() -> void:
	var text := "раз два три четыре пять шесть семь восемь девять десять"
	var w := Status.wrap_words(text, by_len, 10)
	eq(w.size(), Status.PART_LINES, "не больше %d строк" % Status.PART_LINES)
	ok(w[w.size() - 1].ends_with("…"), "обрезано многоточием: %s" % w[w.size() - 1])
	for line in w:
		ok(line.length() <= 10, "в ширину: %s" % line)
	eq(Status.wrap_words("раз два", by_len, 10), PackedStringArray(["раз два"]), "короткое — как есть")


func test_message_fades_after_4_2_s() -> void:
	var m := Status.Message.new()
	m.say("Прожектор погашен")
	m.update(4.1)
	ok(m.visible(), "ещё видно через 4,1 с")
	m.update(0.2)
	ok(not m.visible(), "погасло после 4,2 с")


func test_clear_only_own_message() -> void:
	var m := Status.Message.new()
	m.say("Вы за штурвалом")
	m.clear("Вы за штурвалом")
	ok(not m.visible(), "своё гасится сразу")
	m.say("Течение сменилось")
	m.clear("Вы за штурвалом")
	eq(m.text, "Течение сменилось", "чужое не трогаем")


func test_rumbs_and_course() -> void:
	eq(Status.rumb(Vector3(0, 0, -1)), "С", "к −Z — север")
	eq(Status.rumb(Vector3(1, 0, 0)), "В", "+X — восток")
	eq(Status.rumb(Vector3(-1, 0, 1)), "ЮЗ", "юго-запад")
	eq(Status.course_deg(0.0), 0, "нос на север")
	eq(Status.course_deg(-PI / 2), 90, "повернули вправо — восток")


func test_scene_status_and_messages() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.step(0.1)
	var line := Status.join(main.status_parts())
	ok(line.begins_with("Мостик · глубина 20 м"), "на ногах: %s" % line)
	ok(line.contains("Сесть за штурвал"), "у кресла — подсказка поста")
	main.sit_at_helm()
	main.step(0.1)
	line = Status.join(main.status_parts())
	ok(line.contains("За штурвалом") and line.contains("курс 0°") and line.contains("до дна") and line.contains("Вы за штурвалом"), line)
	main.toggle_light()
	main.step(0.1)
	ok(Status.join(main.status_parts()).contains("прожектор выкл · реактор 100/100 · течение на ЮВ 0,3 м/с · Прожектор погашен"), Status.join(main.status_parts()))
	main.stand_up()
	main.step(0.1)
	ok(not main.message.visible() or main.message.text != Main.SAT_MSG, "после «Встать» «Вы за штурвалом» не висит")
	for i in 50:
		main.step(0.1)
	ok(not main.message.visible(), "сообщение погасло")
	ok(main.hint.text.contains("глубина"), "на экране приборы")
