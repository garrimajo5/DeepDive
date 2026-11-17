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
	ok(line.begins_with("Мостик · глубина 30 м"), "на ногах: %s" % line)
	ok(not line.contains("Сесть за штурвал"), "подписи поста в строке нет — она на кнопке (#1345): %s" % line)
	ok(not line.contains("течение"), "слабое течение не висит в строке (#1345)")
	main.sit_at_helm()
	main.step(0.1)
	line = Status.join(main.status_parts())
	ok(line.contains("За штурвалом") and line.contains("курс 0°") and line.contains("до дна") and line.contains("Вы за штурвалом"), line)
	main.toggle_light()
	main.step(0.1)
	ok(Status.join(main.status_parts()).contains("прожектор выкл · реактор 100/100 · Прожектор погашен"), Status.join(main.status_parts()))
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


## #1345: ряды приборов — последний (тревога и сообщение) по словам на оставшиеся строки, всего не больше трёх.
func test_rows_at_most_three() -> void:
	var m := func(t: String) -> float: return float(t.length())
	var rows := [["За штурвалом", "глубина 120 м", "ход 2,4 м/с"], ["до дна 8 м", "курс 90°"],
		["ПРОБОИНА · МОСТИК", "Пробоина: мостик — держите «Сварка» у пробоины, вода прибывает, плафоны гаснут"]]
	var out := Status.rows(rows, m, 50.0)
	eq(out.size(), 3, "три строки: %s" % [out])
	eq(out[0], "За штурвалом · глубина 120 м · ход 2,4 м/с", "ряд 1")
	eq(out[1], "до дна 8 м · курс 90°", "ряд 2")
	ok(out[2].begins_with("ПРОБОИНА · МОСТИК · Пробоина") and out[2].ends_with("…"), "ряд 3 ужат: %s" % out[2])
	eq(Status.rows([["а"], [], ["б"]], m, 50.0), PackedStringArray(["а", "б"]), "пустой ряд не строка")
	eq(Status.rows([["а"], ["а", "в"]], m, 50.0), PackedStringArray(["а", "в"]), "повтор в другом ряду не пишется")


## #1345: за штурвалом с маршрутом, сообщением и сменой течения строка приборов на экране — не больше трёх строк;
## течение — сообщением с направлением.
func test_scene_pilot_status_three_lines() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.run.choose(0)
	main.sit_at_helm()
	main.current.timer = 0.05
	main.step(0.1)
	ok(main.message.text.begins_with("Течение сменилось: на ") and main.message.text.ends_with(" 0,3 м/с"),
		"смена течения — сообщением: %s" % main.message.text)
	main.on_eco_event(EcoLink.message(EcoVent.WARN_TEXT))
	main.open_silt()
	for i in 3:
		main.step(0.1)
	var rows := main.status_rows()
	eq(rows.size(), 3, "три ряда")
	eq(str(rows[0][0]), "За штурвалом", "якорь «где я» — первым")
	ok(str(rows[2][0]).begins_with(AlarmWay.SILT_HEAD + " · выход: "), "тревога — в третьем ряду: %s" % [rows[2]])
	ok(main.hint.text.split("\n").size() <= 3, "на экране ≤ 3 строк:\n%s" % main.hint.text)
	main.queue_free()
	await frames(1)


## #1361: длинный ряд в середине (сообщение во время тревоги) не вытесняет тревогу — ужат до своей строки.
func test_rows_middle_leaves_line_for_alarm() -> void:
	var m := func(t: String) -> float: return float(t.length())
	var rows := [["Мостик", "глубина 30 м"], ["Вода теплеет: впереди шлейф Чёрного курильщика, обходите сбоку жерла"],
		["СОНАРНАЯ ТЬМА"]]
	var out := Status.rows(rows, m, 40.0)
	eq(out.size(), 3, "три строки: %s" % [out])
	ok(out[1].ends_with("…"), "сообщение ужато: %s" % out[1])
	eq(out[2], "СОНАРНАЯ ТЬМА", "тревога на месте")
	eq(Status.rows([["а"], ["б в г д"], []], m, 3.0).size(), 3, "без тревоги середина берёт свободные строки")


func test_message_take_world() -> void:
	# #1429: брифинг прибытия забирает строки мира с приборов — видимую и ждущую очереди, отдаёт последнюю
	var m := Status.Message.new()
	m.say("Из песка что-то схватило круглую рыбку", Status.MESSAGE_SECONDS, true)
	m.update(0.2)
	m.say("Стайка круглых рыбок пасётся на светящемся мху", Status.MESSAGE_SECONDS, true)
	eq(m.take_world(), "Стайка круглых рыбок пасётся на светящемся мху", "отдана ждущая, последняя")
	ok(not m.visible(), "видимая строка мира погасла")
	m.update(2.0)
	ok(not m.visible(), "ждущая не вышла")
	m.say("Течение сменилось", Status.MESSAGE_SECONDS, true)
	eq(m.take_world(), "Течение сменилось", "одна видимая — отдана она")
	m.say("Вы за штурвалом")
	eq(m.take_world(), "", "своё сообщение игрока — не строка мира")
	eq(m.text, "Вы за штурвалом", "и остаётся на приборах")


func test_urgent_world_line_holds() -> void:
	# #1516: строку угрозы «Серпохвост замер…» стирала следующая строка мира через 1 с — единственный знак до броска
	var m := Status.Message.new()
	m.say("Рыбы пасутся на мху", Status.MESSAGE_SECONDS, true)
	m.update(0.2)
	m.say("Серпохвост замер и смотрит на корабль", Status.MESSAGE_SECONDS, true, true)
	eq(m.text, "Серпохвост замер и смотрит на корабль", "срочная — сразу, без очереди")
	m.update(1.5)
	m.say("Кружевной веер повёрнут к жерлу", Status.MESSAGE_SECONDS, true)
	for i in 26:
		m.update(0.1)
		eq(m.text, "Серпохвост замер и смотрит на корабль", "строка мира ждёт, пока видна срочная (%.1f с)" % (1.6 + i * 0.1))
	m.update(0.2)
	eq(m.text, "Кружевной веер повёрнут к жерлу", "срочная погасла сама — вышла ждущая")
	m.update(Status.MESSAGE_SECONDS + 0.1)
	ok(not m.visible(), "ждущая отстояла своё и погасла")
	m.say("Серпохвост замер и смотрит на корабль", Status.MESSAGE_SECONDS, true, true)
	m.say("Вы за штурвалом")
	eq(m.text, "Вы за штурвалом", "своё сообщение игрока перебивает и срочную")
	m.say("Рыбы пасутся на мху", Status.MESSAGE_SECONDS, true)
	m.update(1.5)
	m.say("Серпохвост замер", Status.MESSAGE_SECONDS, true, true)
	m.say("Рыбы ушли", Status.MESSAGE_SECONDS, true)
	m.update(Status.MESSAGE_SECONDS - 0.1)
	eq(m.text, "Серпохвост замер", "срочная держит все 4,2 с, а не MIN_SHOW")
	m.clear("Серпохвост замер")
	eq(m.text, "Рыбы ушли", "погашенная срочная пускает ждущую")
	m.update(1.2)
	m.say("Течение сменилось", Status.MESSAGE_SECONDS, true)
	eq(m.text, "Течение сменилось", "обычная строка после срочной снова сменяется через MIN_SHOW")


func test_keep_world_line_holds() -> void:
	# #1555: «Хищник потерял корабль и отворачивает» сменялась строкой мира через 1 с — не дочитать, когда включать свет
	var m := Status.Message.new()
	var lost := "Крупный хищник потерял корабль и отворачивает"
	m.say(lost, Status.MESSAGE_SECONDS, true, false, true)
	ok(m.hot and m.keep, "«держится» — держится, но не срочная")
	m.update(0.5)
	m.say("Рыбы пасутся на мху", Status.MESSAGE_SECONDS, true)
	for i in 36:
		m.update(0.1)
		eq(m.text, lost, "строка мира ждёт, пока видна «держится» (%.1f с)" % (0.6 + i * 0.1))
	m.update(0.2)
	eq(m.text, "Рыбы пасутся на мху", "«держится» погасла сама через 4,2 с — вышла ждущая")
	ok(not m.hot and not m.keep, "обычная строка снова обычная")
	# срочная перебивает «держится» сразу
	m.say(lost, Status.MESSAGE_SECONDS, true, false, true)
	m.update(0.3)
	m.say("Серпохвост замер", Status.MESSAGE_SECONDS, true, true)
	eq(m.text, "Серпохвост замер", "срочная — сразу, поверх «держится»")
	ok(m.hot and not m.keep, "и держится как срочная")
	# «держится» перебивает обычную строку мира не раньше MIN_SHOW, как сейчас
	m.say("Вы за штурвалом")
	m.say("Течение сменилось", Status.MESSAGE_SECONDS, true)
	m.update(0.4)
	m.say(lost, Status.MESSAGE_SECONDS, true, false, true)
	eq(m.text, "Течение сменилось", "«держится» ждёт MIN_SHOW обычной строки")
	m.say("Рыбы ушли", Status.MESSAGE_SECONDS, true)
	eq(m.next, lost, "ждущую «держится» обычная строка не сменяет")
	m.update(0.7)
	eq(m.text, lost, "через MIN_SHOW вышла «держится»")
	ok(m.keep, "и держится")
	m.update(Status.MESSAGE_SECONDS - 0.2)
	eq(m.text, lost, "все 4,2 с")
	# срочная видна — «держится» ждёт её конца
	m.say("Серпохвост замер", Status.MESSAGE_SECONDS, true, true)
	m.update(1.5)
	m.say(lost, Status.MESSAGE_SECONDS, true, false, true)
	eq(m.text, "Серпохвост замер", "срочную «держится» не перебивает")
	m.update(Status.MESSAGE_SECONDS)
	eq(m.text, lost, "срочная погасла — вышла «держится»")
	ok(m.keep, "ждущая вышла и держится")


## Сцена: строка «держится» от мира (pred/lost), следом строки мира — на приборах она все 4,2 с (#1555).
func test_scene_keep_eco_message() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	for i in 5:
		main.step(1.0 / 30.0)
	var lost := "Крупный хищник потерял корабль и отворачивает — тестовая строка"
	main.on_eco_event(EcoLink.observe("pred", "lost", lost, false, true))
	main.step(1.0 / 30.0)
	eq(main.message.text, lost, "строка отхода на приборах")
	for i in 10:   # шаг 0,1 с: таймер строки — по времени, не по кадрам (здоровье тестов, #1350)
		main.step(0.1)
	main.on_eco_event(EcoLink.message("Стайка рыбок у мха — тестовая строка"))
	main.on_eco_event({"type": EcoLink.OBSERVE, "species": "fish", "note": "graze", "text": "Рыбы пасутся — тестовая строка"})
	for i in 30:   # до ~4,03 с
		main.step(0.1)
		eq(main.message.text, lost, "строка отхода держится (кадр %d)" % i)
	for i in 10:
		main.step(0.1)
	ok(main.message.text != lost, "после 4,2 с сменилась: %s" % main.message.text)
	main.queue_free()
	await frames(1)


## Сцена: срочная MESSAGE от мира, следом обычная — на приборах срочная до 4,2 с (#1516).
func test_scene_urgent_eco_message() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	for i in 5:
		main.step(1.0 / 30.0)
	var hot := "Серпохвост замер и смотрит на корабль — тестовая строка"
	main.on_eco_event(EcoLink.message(hot, true))
	main.step(1.0 / 30.0)
	main.on_eco_event(EcoLink.message("Стайка рыбок у мха — тестовая строка"))
	main.on_eco_event({"type": EcoLink.OBSERVE, "species": "fish", "note": "graze", "text": "Рыбы пасутся — тестовая строка"})
	for i in 36:   # ~3,63 с шагом 0,1 (здоровье тестов, #1350)
		main.step(0.1)
		eq(main.message.text, hot, "срочная на приборах (кадр %d)" % i)
	for i in 10:
		main.step(0.1)
	ok(main.message.text != hot, "после 4,2 с срочная сменилась: %s" % main.message.text)
	main.queue_free()
	await frames(1)


## Ведущая «держится» (#1966, `EcoLink.KEEP_LEAD`): ждущую «потерял корабль» другая «держится» (кормёжка, бегство
## рыб) не сменяет, а она ждущую другую сменяет; срочная выходит сразу в обоих случаях.
func test_message_lead_keeps_queue() -> void:
	var lost := "Хищник потерял корабль и отворачивает"
	var feed := "Хищник схватил рыбу у цветка"
	var m := Status.Message.new()
	m.say("Течение сменилось", Status.MESSAGE_SECONDS, true)
	m.update(0.3)
	m.say(lost, Status.MESSAGE_SECONDS, true, false, true, true)
	ok(m.next_keep and m.next_lead, "ждёт ведущая «держится»")
	m.say(feed, Status.MESSAGE_SECONDS, true, false, true)
	eq(m.next, lost, "другая «держится» ведущую не сменяет")
	ok(m.next_lead, "и ведущей она осталась")
	m.say("Рыбы ушли", Status.MESSAGE_SECONDS, true)
	eq(m.next, lost, "обычная — тем более")
	m.update(0.8)
	eq(m.text, lost, "через MIN_SHOW вышла «потерял корабль»")
	ok(m.keep and m.lead and not m.next_lead, "держится, ведущая; очередь пуста")
	m.say(feed, Status.MESSAGE_SECONDS, true, false, true)
	eq(m.text, lost, "видимую «держится» другая не перебивает")
	eq(m.next, feed, "ждёт своей очереди")
	m.update(Status.MESSAGE_SECONDS)
	eq(m.text, feed, "вышла следом")
	ok(m.keep and not m.lead, "держится, не ведущая")
	# обратный порядок: ждёт кормёжка — «потерял корабль» её сменяет
	m = Status.Message.new()
	m.say("Течение сменилось", Status.MESSAGE_SECONDS, true)
	m.update(0.3)
	m.say(feed, Status.MESSAGE_SECONDS, true, false, true)
	m.say("Рыбы бегут от рифа", Status.MESSAGE_SECONDS, true, false, true)
	eq(m.next, "Рыбы бегут от рифа", "две не ведущие: ждёт последняя, как раньше")
	m.say(lost, Status.MESSAGE_SECONDS, true, false, true, true)
	eq(m.next, lost, "ведущая сменяет ждущую «держится»")
	m.say("Хищник снова потерял корабль", Status.MESSAGE_SECONDS, true, false, true, true)
	eq(m.next, "Хищник снова потерял корабль", "ведущую сменяет только ведущая")
	# срочная выходит сразу; ведущая, пришедшая под ней, ждёт, и другая «держится» её не сменяет
	m.say("Серпохвост замер", Status.MESSAGE_SECONDS, true, true)
	eq(m.text, "Серпохвост замер", "«замер» — сразу")
	m.say(lost, Status.MESSAGE_SECONDS, true, false, true, true)
	eq(m.next, lost, "потеря после «замера» ждёт")
	m.say(feed, Status.MESSAGE_SECONDS, true, false, true)
	eq(m.next, lost, "и под срочной её не сменяет другая «держится»")
	m.update(Status.MESSAGE_SECONDS)
	eq(m.text, lost, "срочная погасла — вышла ведущая")
	ok(m.lead, "ведущей и осталась")
	# «ведущая» без «держится» — обычная строка
	m = Status.Message.new()
	m.say("Течение сменилось", Status.MESSAGE_SECONDS, true)
	m.say("Рыбы ушли", Status.MESSAGE_SECONDS, true, false, false, true)
	ok(not m.next_keep and not m.next_lead, "lead без keep ничего не значит")


## Ждущий отбой устарел, когда пришла новая угроза (ГД, PR #1968): «потерял корабль» не выходит следом за «замер»,
## пока хищник не потерял корабль снова. Фон (кормёжка, бегство рыб) ждущий отбой по-прежнему не стирает.
func test_message_alert_drops_waiting_lead() -> void:
	var lost := "Хищник потерял корабль и отворачивает"
	var alert := "Серпохвост замер"
	var m := Status.Message.new()
	m.say("Течение сменилось", Status.MESSAGE_SECONDS, true)
	m.update(0.3)
	m.say(lost, Status.MESSAGE_SECONDS, true, false, true, true)
	eq(m.next, lost, "отбой ждёт")
	m.say("Рыбы бегут от рифа", Status.MESSAGE_SECONDS, true, false, true)
	eq(m.next, lost, "фон отбой не стирает")
	m.say(alert, Status.MESSAGE_SECONDS, true, true)
	eq(m.text, alert, "«замер» — сразу")
	eq(m.next, "", "ждущий отбой снят новой угрозой")
	ok(not m.next_keep and not m.next_lead, "и его признаки тоже")
	m.update(Status.MESSAGE_SECONDS)
	eq(m.text, "", "строка истекла, новой потери не было — отбоя нет")
	m.update(1.0)
	eq(m.text, "", "и позже не выходит")
	m.say(lost, Status.MESSAGE_SECONDS, true, false, true, true)
	eq(m.text, lost, "новая потеря — новый отбой")
	ok(m.lead, "ведущая")
	# ждущую не ведущую «держится» и обычную строку «замер» не трогает — как раньше
	m = Status.Message.new()
	m.say("Течение сменилось", Status.MESSAGE_SECONDS, true)
	m.update(0.3)
	m.say("Хищник схватил рыбу у цветка", Status.MESSAGE_SECONDS, true, false, true)
	m.say(alert, Status.MESSAGE_SECONDS, true, true)
	eq(m.next, "Хищник схватил рыбу у цветка", "не ведущая «держится» ждёт под «замер»")


## То же через события мира (`Main.on_eco_event`): ждущий отбой → «замер» → строка истекла, новой потери не было.
func test_scene_alert_drops_waiting_lost() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	still_world(main)
	for i in 5:
		main.step(1.0 / 30.0)
	var lost := "Серпохвост потерял корабль и отворачивает — тестовая строка"
	var alert := "Серпохвост замер и смотрит на корабль — тестовая строка"
	main.on_eco_event(EcoLink.message("Стайка рыбок у мха — тестовая строка"))
	main.step(0.1)
	main.on_eco_event(EcoLink.observe("pred", "lost", lost, false, true, true))
	eq(main.message.next, lost, "отбой ждёт очереди")
	main.on_eco_event(EcoLink.observe("fish", "flee", "Рыбы бегут от рифа — тестовая строка", false, true))
	eq(main.message.next, lost, "фон его не стирает")
	main.on_eco_event(EcoLink.observe("pred", "alert", alert, true))
	eq(main.message.text, alert, "«замер» на приборах")
	eq(main.message.next, "", "ждущий отбой снят")
	for i in 60:   # 6 с: строка «замер» истекла (4,2 с), новой потери не было
		main.step(0.1)
		ok(main.message.text != lost, "старый отбой не выходит (кадр %d)" % i)
	main.on_eco_event(EcoLink.observe("pred", "lost", lost, false, true, true))
	eq(main.message.text, lost, "новая потеря — отбой на приборах")
	main.queue_free()
	await frames(1)
