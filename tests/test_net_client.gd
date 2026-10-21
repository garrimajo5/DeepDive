extends TestCase
## Клиент в сцене (Main.join_game): шаг корабля не считает — кадры хоста ставят корабль, реактор и экипаж,
## свой игрок — место `me` из кадра, камера у него; ввод с экрана уходит хосту; потеря хоста — одиночная игра.
## Хост здесь — голый NetLink.Host с кадрами NetSnap.frame (как шлёт Main хоста), по loopback.

const PORT := 24720
const DT := 1.0 / 30.0
var main: Main
var host: NetLink.Host
var guest: NetLink.Guest
## «Корабль хоста» для кадров.
var h_helm := Helm.Ship.new()
var h_reactor := Reactor.new()
var h_vitals := Vitals.new()
var h_crew: Array = []


func before() -> void:
	host = NetLink.Host.new()
	eq(host.start(PORT), OK, "хост открыт")
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	h_helm.pos = Vector3(5.0, -40.0, 20.0)
	h_helm.yaw = 0.7
	h_helm.speed = 4.0
	h_reactor.share[Reactor.Sys.LAMP] = 0
	h_vitals.hull = 61.0
	var pilot := Crew.Member.new(Crew.Role.PILOT)
	pilot.name = "Хост"
	pilot.place(0.0, 2.0, 0.0, true)
	pilot.sync_post()
	h_crew = [pilot]
	eq(main.join_game("127.0.0.1", PORT, "Ира", Crew.Role.BIOLOGIST, 1), OK, "клиент подключается")
	guest = null


func after() -> void:
	if main.net_client:
		main.net_client.stop()
	host.stop()


## Шаг хоста: гость пришёл — встаёт в экипаж (место 1); кадр, если пора.
func _host_tick(send := true) -> void:
	for e: Dictionary in host.poll():
		if e["k"] == "join":
			guest = e["guest"]
			var m := Crew.Member.new(guest.role)
			m.look = guest.look
			m.name = guest.name
			m.place(-1.0, 4.0, 0.3)
			h_crew.append(m)
			guest.index = 1
	if send and host.due(DT):
		host.send_frame(NetSnap.frame(host.seq, 0.0, h_helm, h_reactor, h_vitals, false, h_crew))


## Шаги хоста и клиента, пока cond не true (до 3 с настоящего времени).
func _pump(cond: Callable, send := true) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		_host_tick(send)
		main.step(DT)
		if cond.call():
			return true
		OS.delay_msec(2)
	return false


func test_frame_sets_ship_and_own_player() -> void:
	ok(_pump(func() -> bool: return main.net_seq > 0), "кадр принят")
	ok(main.helm.pos.distance_to(h_helm.pos) < 0.01, "корабль как у хоста")
	near(main.helm.yaw, 0.7, 0.001)
	near(main.vitals.hull, 61.0, 0.01, "корпус как у хоста")
	eq(main.reactor.share[Reactor.Sys.LAMP], 0, "доли реактора как у хоста")
	ok(not main.light_on, "свет как у хоста")
	eq(main.crew.size(), 2, "экипаж как у хоста")
	ok(main.me == main.crew[1], "свой игрок — место из кадра")
	ok(main.walker == main.me.walker, "свой ходок — у него")
	eq(main.me.name, "Ира")
	eq(main.me.role, Crew.Role.BIOLOGIST)
	ok((main.crew[0] as Crew.Member).seated, "хост за штурвалом")
	eq(main.crew_view.figures.size(), 2, "две фигуры")
	ok(main.crew_view.local == main.me, "камера — глазами своего игрока")
	var eye := main.camera.position
	ok(Vector2(eye.x, eye.z).distance_to(Vector2(-1.0, 4.0)) < 0.6, "камера у своего игрока (%s)" % eye)


func test_client_does_not_step_ship() -> void:
	ok(_pump(func() -> bool: return main.net_seq > 0), "кадр принят")
	var p := main.helm.pos
	for i in 30:   # секунда без кадров: на хосте корабль прошёл бы 4 м, клиент сам его не двигает
		main.step(DT)
	ok(main.helm.pos.distance_to(p) < 0.001, "корабль стоит до нового кадра")
	h_helm.pos += Vector3(0.0, 0.0, -4.0)
	var seq := main.net_seq
	ok(_pump(func() -> bool: return main.net_seq > seq), "новый кадр")
	ok(main.helm.pos.distance_to(h_helm.pos) < 0.01, "корабль сдвинул кадр хоста")


func test_screen_input_reaches_host() -> void:
	ok(_pump(func() -> bool: return main.net_seq > 0), "на борту")
	main.overlay.router.move = Vector2i(0, 1)
	ok(_pump(func() -> bool: return guest.pad.move == Vector2(0.0, 1.0)), "крестовина у хоста")
	main.overlay.router.move = Vector2i.ZERO
	main.overlay.router.action_pressed = true
	ok(_pump(func() -> bool: return guest.pad.action), "нажатие у хоста")


func test_own_yaw_stays_local_until_post() -> void:
	ok(_pump(func() -> bool: return main.net_seq > 0), "на борту")
	main.walker.yaw = 1.2   # свайп повернул взгляд, хост ещё не знает
	var seq := main.net_seq
	ok(_pump(func() -> bool: return main.net_seq > seq + 2), "кадры идут")
	near(main.walker.yaw, 1.2, 0.001, "курс свой, кадр его не дёргает")
	(h_crew[1] as Crew.Member).place(0.0, 2.0, 0.0, true)   # хост посадил гостя за пост: курс от хоста
	(h_crew[1] as Crew.Member).sync_post()
	ok(_pump(func() -> bool: return main.me.seated), "сел по кадру")
	near(main.walker.yaw, 0.0, 0.001, "курс поста от хоста")


func test_lost_host_continues_alone() -> void:
	ok(_pump(func() -> bool: return main.crew.size() == 2), "на борту")
	host.stop()
	ok(_pump(func() -> bool: return main.net_client == null, false), "связь потеряна")
	eq(main.crew.size(), 1, "остался свой игрок")
	ok(main.crew[0] == main.me)
	var p := main.helm.pos
	main.helm.speed = 3.0
	for i in 10:
		main.step(DT)
	ok(main.helm.pos.distance_to(p) > 0.01, "корабль снова считает свой шаг")
