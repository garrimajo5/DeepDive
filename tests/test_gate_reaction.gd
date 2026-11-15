extends TestCase
## Реакции экипажа у 07 (#1866, спецификация UX): реплика роли — строкой приборов у того, кто стоит у её поста.

const AT := Vector2(-100.0, -240.0)     ## корабль над серединой террасы 07
const FAR := Vector2(200.0, 200.0)      ## вне круга 07
const BIO := "Биолог: Настройки закрыты. Нужно разрешение системы."
const SONAR := "Сонарщик: Состояние прочитали. Обратный ход пока не работает."
const DT := 0.1


func _lore(keys: Array = []) -> LayerLore:
	var lore := LayerLore.new()
	for k in keys:
		lore.learn(k)
	return lore


## Шаги до времени t; строки, которые вышли.
func _run(r: GateReaction, t: float, ship: Vector2, post: String, lore: LayerLore, hidden := false) -> Array:
	var out := []
	for i in roundi(t / DT):
		var s := r.update(DT, ship, post, lore, hidden)
		if s != "":
			out.append(s)
	return out


func test_lines_are_signed_txt() -> void:
	eq(GateReaction.line(LayerLore.D07_AUTH), BIO, "биолог — подпись роли и текст TXT-001")
	eq(GateReaction.line(LayerLore.D07_RETURN), SONAR, "сонарщик")
	for f in GateDiag.REACTION:
		ok(GateReaction.POSTS.has(f) and GateReaction.STALE.has(f), "у реплики %s есть пост и условие" % f)
	var ids := []
	for p in Deck.posts():
		ids.append(p.id)
	for f in GateReaction.POSTS:
		ok(ids.has(GateReaction.POSTS[f]), "пост %s есть на палубе" % GateReaction.POSTS[f])
	ok(GateReaction.in_place(AT) and not GateReaction.in_place(FAR), "круг места 07")


func test_shows_once_at_own_post_after_fact() -> void:
	var r := GateReaction.new()
	var lore := _lore([LayerLore.D07_AUTH])
	eq(_run(r, 10.0, AT, "scanner", lore), [], "без события чтения реплики нет (загрузка с фактами)")
	r.arm(LayerLore.D07_AUTH)
	eq(_run(r, GateReaction.AFTER_FACT - 0.3, AT, "scanner", lore), [], "раньше 4,2 с после факта — нет: факт на приборах")
	eq(_run(r, 0.6, AT, "scanner", lore), [BIO], "после — у своего поста, одна")
	r.arm(LayerLore.D07_AUTH)
	eq(_run(r, 10.0, AT, "scanner", lore), [], "второй раз за сеанс — нет")


func test_waits_for_post_and_place() -> void:
	var r := GateReaction.new()
	var lore := _lore()
	r.arm(LayerLore.D07_RETURN)
	eq(_run(r, 8.0, AT, "scanner", lore), [], "сонарщик — не у сканера")
	eq(_run(r, 2.0, AT, "", lore), [], "и не без поста")
	eq(_run(r, 0.2, AT, "sonar", lore), [SONAR], "подошёл к голостолу — вышла")
	r.arm(LayerLore.D07_AUTH)
	eq(_run(r, 0.2, FAR, "scanner", lore), [], "вне круга 07 — нет")
	eq(_run(r, 10.0, AT, "scanner", lore), [], "вышли из круга до показа — реплика снята")


func test_next_fact_delays_and_relay_has_no_line() -> void:
	var r := GateReaction.new()
	var lore := _lore()
	r.arm(LayerLore.D07_AUTH)
	_run(r, 3.0, AT, "scanner", lore)
	r.arm(LayerLore.D07_RELAY)   # биолог читает следующее гнездо — его факт на приборах
	eq(r.armed, [LayerLore.D07_AUTH] as Array[String], "у ретранслятора реплики нет")
	eq(_run(r, 3.0, AT, "scanner", lore), [], "реакция ждёт, пока погаснет и этот факт")
	eq(_run(r, 1.5, AT, "scanner", lore), [BIO], "потом выходит")


func test_stale_and_hidden() -> void:
	var r := GateReaction.new()
	var lore := _lore()
	r.arm(LayerLore.D07_AUTH)
	eq(_run(r, 10.0, AT, "scanner", lore, true), [], "брифинг, голосование — часы стоят")
	near(r.since_fact, 0.0, 1e-6, "и время после факта не идёт")
	lore.learn(LayerLore.AUTH07)
	eq(_run(r, 10.0, AT, "scanner", lore), [], "терминал авторизован — состояние устарело")
	ok(r.armed.is_empty(), "реплика снята")
	ok(GateReaction.STALE[LayerLore.D07_RETURN] == "", "ремонта обратного хода в слое 1 нет — место на будущее")


## Гость: знания хоста на входе — основа; новый факт кадром — реплика у своего поста. У хоста (не у поста) — нет.
func test_guest_follows_host_frames() -> void:
	var host_lore := _lore([LayerLore.D07_RELAY])
	var guest_lore := LayerLore.new()
	var guest := GateReaction.new()
	guest_lore.apply_net(host_lore.pack())
	guest.follow(guest_lore)
	host_lore.learn(LayerLore.D07_RETURN)   # до входа второго гостя
	var late := GateReaction.new()
	var late_lore := LayerLore.new()
	late_lore.apply_net(host_lore.pack())
	late.follow(late_lore)
	ok(late.armed.is_empty(), "факты на момент входа не взводят")
	var host := GateReaction.new()
	host.arm(LayerLore.D07_RETURN)
	guest_lore.apply_net(host_lore.pack())
	guest.follow(guest_lore)
	guest.follow(guest_lore)
	eq(guest.armed, [LayerLore.D07_RETURN] as Array[String], "новый факт от хоста взвёл реплику, один раз")
	eq(_run(guest, 5.0, AT, "sonar", guest_lore), [SONAR], "гость у голостола видит её")
	eq(_run(host, 5.0, AT, "scanner", host_lore), [], "хост у другого поста — нет")
	guest.arm(LayerLore.D07_AUTH)
	guest.resync()
	ok(guest.armed.is_empty(), "новое подключение — взведённое снято")
	guest.follow(guest_lore)
	ok(guest.armed.is_empty(), "и знания хоста снова основа")


## Сцена, соло: прочитали гнёзда — у «Сканера» после факта выходит биолог на 6 с одной строкой, сонарщик — когда
## игрок подошёл к голостолу; с загруженными фактами без чтения — ничего.
func test_scene_solo_lines_on_status() -> void:
	var was := tree.root.size
	tree.root.size = Vector2i(1280, 720)
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	still_world(main)
	main.helm.ground = func(_x: float, _z: float) -> float: return -80.0
	main.helm.pos = Vector3(AT.x, -35.0, AT.y)
	main.helm.speed = 0.0
	main.walker.x = 3.85   # у поста «Сканер»
	main.walker.z = -2.0
	main.lore.learn(LayerLore.D07_RELAY)   # как из сохранения: без события
	for i in 60:
		main.step(DT)
		main.helm.pos = Vector3(AT.x, -35.0, AT.y)
	ok(not main.message.text.contains(":"), "без чтения реплик нет: «%s»" % main.message.text)
	for f in [LayerLore.D07_RETURN, LayerLore.D07_AUTH]:
		main.lore.learn(f)
		main.gate.read.emit(f)
	eq(main.message.text, GateDiag.TEXT[LayerLore.D07_AUTH], "сначала факт")
	for i in 40:
		main.step(DT)
		main.helm.pos = Vector3(AT.x, -35.0, AT.y)
	ok(main.message.text != BIO, "4 с — реакции ещё нет: «%s»" % main.message.text)
	for i in 5:
		main.step(DT)
		main.helm.pos = Vector3(AT.x, -35.0, AT.y)
	eq(main.message.text, BIO, "у «Сканера» — биолог")
	ok(main.message.left > 5.0, "держится 6 с, не 4,2 (осталось %.1f)" % main.message.left)
	await frames(1)
	var rows := main.hint.text.split("\n")
	ok(rows.has(BIO), "1280×720: реплика одной строкой, не обрезана: %s" % str(rows))
	eq(main.news.size(), 2, "гостям — только факт")
	ok(String(main.news[1]) != BIO, "реплика по сети не идёт")
	main.walker.x = 0.0   # к голостолу
	main.walker.z = -1.2
	main.message.clear(BIO)
	for i in 3:
		main.step(DT)
		main.helm.pos = Vector3(AT.x, -35.0, AT.y)
	eq(main.message.text, SONAR, "у голостола — сонарщик")
	await frames(1)
	ok(main.hint.text.split("\n").has(SONAR), "и она одной строкой: %s" % main.hint.text)
	main.queue_free()
	await frames(1)
	tree.root.size = was


## Шаг тестера `nests`: кадры 35d/35e не зависят от того, что прогон прочитал раньше (#1866).
func test_qa_nests_step_forgets() -> void:
	var q := QaScript.parse('[{"do": "nests"}]')
	eq(q.errors.size(), 0, "шаг nests известен")
	eq(q.advance(0.01)[0], ["nests"], "команда сцене")
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	still_world(main)
	main.lore.learn(LayerLore.D07_AUTH)
	main.lore.learn(LayerLore.BRIEF)
	main.reaction.said.append(LayerLore.D07_AUTH)
	main.reaction.arm(LayerLore.D07_RETURN)
	main.start_qa('[{"do": "nests"}, {"do": "wait", "s": 1}]')
	main.step(0.1)
	main.step(0.1)
	ok(not main.lore.knows(LayerLore.D07_AUTH), "факт гнезда забыт")
	ok(main.lore.knows(LayerLore.BRIEF), "остальные знания целы")
	ok(main.reaction.said.is_empty() and main.reaction.armed.is_empty(), "реакции с нуля")
	main.queue_free()
	await frames(1)
