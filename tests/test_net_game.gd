extends TestCase
## Сетевая игра (#756) — `NetGame` (`main.net_game`): хост, гость, потеря связи, фигуры ушедших; у `Main` —
## пересылки `host_game`, `join_game`, `mate_gone`.

const DT := 1.0 / 30.0
const PORT := 24811

var main: Main


func after() -> void:
	if main:
		if main.net_host:
			main.net_host.stop()
		if main.net_client:
			main.net_client.stop()
		main.queue_free()
		main = null
	await frames(1)


func test_scene_net_game() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	ok(main.net_game is NetGame and main.net_game.main == main, "сетевая игра — поле main.net_game")
	for f in ["_stop_host", "_net_poll", "_seat_guest", "_net_index", "_ghosts", "_net_send", "_net_run",
			"_enter_client", "_client_step", "_client_eco", "_client_run_view", "_client_frame", "_drop_step",
			"_drop_taps", "_leave_net"]:
		ok(not main.has_method(f), "%s больше не в Main" % f)
	for f in ["host_game", "join_game", "mate_gone"]:
		ok(main.has_method(f), "пересылка %s у Main" % f)
	# хост: пересылка открывает хоста, ушедший товарищ — табличка у хоста и тающая фигура
	eq(main.host_game(PORT), OK, "host_game — пересылка")
	ok(main.net_host != null, "хост открыт")
	var m := main.add_mate(0.0, 1.0, 0.0, Crew.Role.BIOLOGIST, 1)
	m.name = "Ира"
	main.step(DT)
	main.mate_gone(m)
	ok(not main.crew.has(m), "ушла с палубы")
	eq(main.ghosts.size(), 1, "её фигура тает на месте")
	eq(main.notice.title, "Ира отключилась")
	main.step(DT)
	main.net_game.stop_host()
	ok(main.net_host == null and main.ghosts.is_empty(), "хост закрыт — фигуры убраны")
	# гость: пересылка входит клиентом, отказ при входе — дальше одиночная игра
	eq(main.join_game("127.0.0.1", PORT + 1), OK, "join_game — пересылка")
	ok(main.net_client != null and main.tutorial_guest != null, "стал гостем")
	main.step(DT)
	main.net_game.leave_net()
	ok(main.net_client == null and main.tutorial_guest == null, "связь кончилась — одиночный забег")
	eq(main.crew, [main.me], "на борту только свой")
	main.step(DT)


## Кооп в кампании (#823, часть 4): сохраняет хост. У гостя кадры хоста (знания «k», корабль) не перетирают его
## файл; своё несохранённое уходит в файл до входа; после ухода из сетевого забега — свои знания и снова запись,
## «Играть одному» — своя кампания с последнего сохранения.
func test_scene_guest_keeps_own_save() -> void:
	const SAVE_PATH := "user://test_guest_save.json"
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	main.save.path = SAVE_PATH
	main.helm.pos = Vector3(10.0, -25.0, 40.0)
	main.lore.learn(LayerLore.INTRO)
	ok(main.save_now(), "своя кампания записана")
	main.lore.learn(LayerLore.K2)   # узнал и ещё не записал
	ok(main.save.dirty, "запись ждёт")
	eq(main.join_game("127.0.0.1", PORT + 2), OK, "вошёл гостем")
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	eq(raw["lore"], [LayerLore.INTRO, LayerLore.K2], "своё несохранённое записано до кадров хоста")
	ok(main.save.guest, "у гостя запись выключена")
	# кадр хоста: его знания и его корабль
	var host := LayerLore.new()
	host.learn(LayerLore.SHELL03)
	main.lore.apply_net(host.pack())
	main.helm.pos = Vector3(200.0, -60.0, -100.0)
	for i in int(SaveGame.DELAY / DT) + 3:
		main.step(DT)
	ok(not main.save_now(), "«Сохранить» у гостя не пишет")
	main.save.flush(main.samples, main.scanner)
	raw = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	eq(raw["lore"], [LayerLore.INTRO, LayerLore.K2], "знания хоста в файл гостя не попали")
	near(float(raw["ship"]["x"]), 10.0, 0.01, "место хоста в файл гостя не попало")
	main.net_game.leave_net()
	ok(not main.save.guest, "связь кончилась — снова своя запись")
	eq(main.lore.snapshot(), [LayerLore.INTRO, LayerLore.K2], "свои знания вместо знаний хоста")
	ok(main._load_last(), "«Играть одному» — с последнего сохранения")
	near(main.helm.pos.x, 10.0, 0.01, "корабль на своём месте")
	ok(main.save_now(), "запись снова идёт")
	DirAccess.remove_absolute(SAVE_PATH)
