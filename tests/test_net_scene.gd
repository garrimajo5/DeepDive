extends TestCase
## Хост в сцене (Main.host_game): телефон по loopback встаёт членом экипажа, его ввод ведёт фигуру,
## кадры уходят раз в SEND_DT, ушедший пропадает с палубы.

const PORT := 24710
const DT := 1.0 / 30.0
var main: Main
var client: NetLink.Client
var frame := {}


func before() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)
	eq(main.host_game(PORT), OK, "хост открыт")
	client = NetLink.Client.new()
	client.join("127.0.0.1", PORT, "Ира", Crew.Role.BIOLOGIST, 1)


func after() -> void:
	client.stop()
	main.net_host.stop()


## Шаги хоста и клиента, пока cond не true (до 3 с настоящего времени).
func _pump(cond: Callable) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		main.step(DT)
		var f := client.poll(DT)
		if not f.is_empty():
			frame = f
		if cond.call():
			return true
		OS.delay_msec(2)
	return false


func test_guest_joins_as_mate() -> void:
	ok(_pump(func() -> bool: return main.crew.size() == 2), "гость на палубе")
	var m: Crew.Member = main.crew[1]
	eq(m.role, Crew.Role.BIOLOGIST, "роль гостя")
	eq(m.look, 1, "внешность гостя")
	eq(m.name, "Ира", "имя гостя")
	eq(main.crew_view.figures.size(), 2, "фигура гостя")
	ok(main.crew_view.figures[1].visible, "видна")
	var g: NetLink.Guest = main.net_host.guests.values()[0]
	ok(m.pad == g.pad, "ввод члена экипажа — ввод гостя")
	eq(g.index, 1, "место гостя в экипаже")


func test_frames_reach_guest_with_place() -> void:
	main.helm.pos = Vector3(3.0, -30.0, 12.0)
	ok(_pump(func() -> bool: return client.got >= 3), "кадры идут")
	eq(client.me, 1, "своё место — второй")
	var helm := Helm.Ship.new()
	var crew: Array = []
	NetSnap.apply_frame(frame, -1, helm, Reactor.new(), Vitals.new(), crew)
	ok(helm.pos.distance_to(main.helm.pos) < 0.5, "корабль как у хоста")
	eq(crew.size(), 2, "экипаж как у хоста")
	eq((crew[1] as Crew.Member).role, Crew.Role.BIOLOGIST)
	# 20 кадров в секунду: за секунду шагов хоста — около 20 (не 30)
	var before := main.net_host.seq
	for i in 30:
		main.step(DT)
	eq(main.net_host.seq - before, 20, "кадр раз в SEND_DT")


func test_guest_pad_walks_mate() -> void:
	ok(_pump(func() -> bool: return main.crew.size() == 2), "гость на палубе")
	var m: Crew.Member = main.crew[1]
	var z0 := m.walker.z
	var pad := Crew.Pad.new()
	pad.move = Vector2(0.0, 1.0)   # вперёд — к носу (−Z)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000 and m.walker.z > z0 - 0.5:
		client.send_pad(pad)
		main.step(DT)
		client.poll(DT)
		OS.delay_msec(2)
	ok(m.walker.z < z0 - 0.5, "фигура гостя идёт его крестовиной (%.2f → %.2f)" % [z0, m.walker.z])


func test_guest_leaves() -> void:
	ok(_pump(func() -> bool: return main.crew.size() == 2), "гость на палубе")
	client.stop()
	ok(_pump(func() -> bool: return main.crew.size() == 1), "ушёл с палубы")
	ok(main.crew[0] == main.me, "остался свой игрок")
	eq(main.net_mates.size(), 0)
	ok(not main.crew_view.figures[1].visible, "фигура гостя скрыта")
