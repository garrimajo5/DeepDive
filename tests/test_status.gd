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


func test_message_not_cut_right_away() -> void:
	# issue #979: строку веера через 0,2 с перебивал укус хищника — тестер её не видел
	var m := Status.Message.new()
	m.say("Кружевной веер у курильщика повёрнут к жерлу", Status.MESSAGE_SECONDS, true)
	m.update(0.2)
	m.say("Крупный хищник укусил корпус", Status.MESSAGE_SECONDS, true)
	eq(m.text, "Кружевной веер у курильщика повёрнут к жерлу", "первая строка видна MIN_SHOW")
	m.update(0.5)
	eq(m.text, "Кружевной веер у курильщика повёрнут к жерлу", "через 0,7 с ещё она")
	m.update(0.4)
	eq(m.text, "Крупный хищник укусил корпус", "после 1 с — ждущая")
	m.update(4.1)
	ok(m.visible(), "ждущая держит свои 4,2 с")
	m.update(0.2)
	ok(not m.visible(), "и гаснет")
	m.say("А")
	m.update(2.0)
	m.say("Б", Status.MESSAGE_SECONDS, true)
	eq(m.text, "Б", "после MIN_SHOW новое сразу")
	m.say("Б", Status.MESSAGE_SECONDS, true)
	eq(m.text, "Б", "то же самое — не в очередь")
	m.say("В", Status.MESSAGE_SECONDS, true)
	m.clear("В")
	m.update(1.5)
	eq(m.text, "Б", "погашенное ждущее не всплывает")
	m.say("Свет")
	eq(m.text, "Свет", "своё действие — сразу, без очереди")
	m.say("Мир", Status.MESSAGE_SECONDS, true)
	eq(m.text, "Мир", "своё строку мира не держит — она сразу")


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


## По issue #139: строки на приборах на тёмной полупрозрачной подложке — читаются поверх белых плафонов.
func test_hint_has_backing() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.step(0.1)
	var sb := main.hint.get_theme_stylebox("normal") as StyleBoxFlat
	ok(sb != null, "у строк есть подложка")
	ok(sb.bg_color.a >= 0.4 and sb.bg_color.a < 0.8 and sb.bg_color.get_luminance() < 0.15, "тёмная полупрозрачная: %s" % sb.bg_color)
	ok(sb.content_margin_left >= 6.0, "текст не у края подложки")
	near(main.hint.position.x + sb.content_margin_left, 24.0, 0.5, "текст на прежнем месте")
	main.queue_free()
	await frames(1)


## #847: та же строка — без новых замеров шрифтом; смена части, ширины или размера — пересчёт.
func test_lines_cached_until_change() -> void:
	var calls := [0]
	var counted := func(s: String) -> float:
		calls[0] += 1
		return float(s.length())
	var l := Status.Lines.new()
	var parts := ["Мостик", "глубина 20 м", "ход 1,5 м/с"]
	ok(l.update(parts, counted, 30.0, 20), "первый раз — новая строка")
	eq(l.text, "\n".join(Status.lines(parts, by_len, 30.0)), "текст как у Status.lines")
	var first: int = calls[0]
	ok(first > 0, "мерили шрифтом")
	for i in 30:
		ok(not l.update(["Мостик", "глубина 20 м", "ход 1,5 м/с"], counted, 30.0, 20), "та же строка — не новая")
	eq(calls[0], first, "за 30 кадров без изменений — ни одного замера")
	ok(l.update(["Мостик", "глубина 21 м", "ход 1,5 м/с"], counted, 30.0, 20), "глубина сменилась")
	ok(calls[0] > first, "пересчитали")
	ok(l.update(["Мостик", "глубина 21 м", "ход 1,5 м/с"], counted, 12.0, 20), "уже экран — пересчёт")
	eq(l.text, "Мостик\nглубина 21 м\nход 1,5 м/с", "по новой ширине")
	ok(l.update(["Мостик", "глубина 21 м", "ход 1,5 м/с"], counted, 12.0, 24), "другой размер шрифта — пересчёт")
	ok(l.update(["Мостик", "глубина 21 м"], counted, 12.0, 24), "часть ушла — пересчёт")
	ok(l.update(["Мостик глубина 21 м"], counted, 12.0, 24), "склейка частей — другая строка")
