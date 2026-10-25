extends TestCase
## Экипаж в сцене: своя фигура идёт за игроком и садится за штурвал, другой член экипажа виден целиком.

var main: Main


func before() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(2)


func _shown(fig: int, part: String) -> Variant:
	return main.crew_view.shown[fig].get(part)


func test_own_figure_follows_player() -> void:
	eq(main.crew_view.figures.size(), 1, "одна фигура — свой игрок")
	eq(main.crew_view.meshes[0].layers, 2, "слой корабля")
	for i in 15:
		main.walker.z -= Deck.Walker.SPEED / 30.0
		main.step(1.0 / 30.0)
	ok(main.me.swing > 0.5, "фигура шагает")
	var knee: Vector3 = _shown(0, "knee_l")
	near(Vector2(knee.x, knee.z).distance_to(Vector2(main.walker.x, main.walker.z)), 0.0, 0.4, "ноги под игроком")
	ok(_shown(0, "head") == null, "свою голову не видно")


func test_seated_hands_on_wheel_in_scene() -> void:
	main.sit_at_helm()
	main.helm.turn = 0.0
	main.step(1.0 / 30.0)
	var hand: Vector3 = _shown(0, "hand_r")
	var grip: Vector3 = Crew.wheel_grips(main.helm.turn)[1]
	ok(hand.distance_to(grip) < 0.16, "правая рука у обода (%.2f м)" % hand.distance_to(grip))
	var palm: Vector3 = main.me.joints()["palm_r"]
	ok(palm.distance_to(grip) < 0.1, "ладонь на ободе (%.2f м)" % palm.distance_to(grip))
	near(main.camera.position.y, main.me.eye().y, 1e-4, "камера в голове фигуры")
	main.stand_up()


func test_mate_visible_whole() -> void:
	await main.debug_setup({"mate": "1,0.5,180,2"})
	main.step(1.0 / 30.0)
	eq(main.crew_view.figures.size(), 2, "две фигуры")
	eq(main.crew[1].role, Crew.Role.ENGINEER, "роль из ключа")
	ok(_shown(1, "head") != null, "голову другого видно")
	near(_shown(1, "head").y, Deck.Walker.EYE, 0.05, "на высоте роста")


func test_mate_not_inside_table() -> void:   # issue #156: сценарий ставил второго в голостол (0,4; −1,6)
	ok(not main.layout.can_stand(0.4, -1.6), "место из сценария — внутри голостола")
	var m := main.add_mate(0.4, -1.6, PI / 2.0, Crew.Role.BIOLOGIST, 0)
	ok(main.layout.can_stand(m.x, m.z), "стоит на полу у стола: (%.2f; %.2f)" % [m.x, m.z])
	ok(Vector2(m.x, m.z).distance_to(Vector2(0.4, -1.6)) < 0.8, "рядом с указанным местом")
	ok(Vector2(m.x, m.z).distance_to(Deck.OBSTACLES[0][0]) > 0.9, "снаружи стола")
	var free := main.add_mate(0.2, -2.6, 0.0, Crew.Role.ENGINEER, 1)
	eq(Vector2(free.x, free.z), Vector2(0.2, -2.6), "свободное место не трогаем")
	var seat := main.add_mate(0.0, Deck.SEAT_Z, 0.0, Crew.Role.SONAR, 0, true)
	eq(seat.z, Deck.SEAT_Z, "в кресле — как есть")


func test_screen_input_only_to_own() -> void:   # ввод с экрана — своему, у другого свой ввод
	var m := main.add_mate(1.5, 0.5, 0.0, Crew.Role.ENGINEER, 0)
	eq(m.walker.stand, main.layout.can_stand, "ходок товарища знает весь корабль")
	var me0 := Vector2(main.walker.x, main.walker.z)
	main.overlay.router.move = Vector2i(0, 1)
	for i in 20:
		main.step(1.0 / 30.0)
	main.overlay.router.move = Vector2i.ZERO
	ok(Vector2(main.walker.x, main.walker.z).distance_to(me0) > 0.3, "свой игрок пошёл")
	eq(Vector2(m.x, m.z), Vector2(1.5, 0.5), "товарищ стоит")
	me0 = Vector2(main.walker.x, main.walker.z)
	m.pad.move = Vector2(0.0, 1.0)
	for i in 20:
		main.step(1.0 / 30.0)
	ok(m.z < 0.0, "товарищ идёт своим вводом (z %.2f)" % m.z)
	ok(main.crew_view.shown[1]["hip"].z < 0.2, "его фигура в сцене тоже")
	eq(Vector2(main.walker.x, main.walker.z), me0, "свой игрок стоит")
	m.pad.clear()


func _tris(mi: MeshInstance3D) -> int:
	return (mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3


func test_model_replaces_capsules() -> void:
	await main.debug_setup({"mate": "1,0.5,180,2"})
	main.step(1.0 / 30.0)
	var cv := main.crew_view
	ok(cv.skeletons[0] is Skeleton3D and cv.skeletons[0].get_bone_count() == 24, "модель MOD-012 со скелетом")
	eq(cv.looks[1], 1, "второй член экипажа — женская модель")
	eq(cv.meshes[1].layers, 2, "модель на слое корабля")
	ok(_tris(cv.meshes[0]) < _tris(cv.meshes[1]) * 0.9, "свой игрок — без головы (%d треуг.)" % _tris(cv.meshes[0]))
	ok(cv.meshes[0].material_override != null and cv.meshes[1].material_override == null, "свой — с отсечением граней")
	ok(cv.patches[1].visible and not cv.patches[0].visible, "нашивка роли — у других")
	var j := main.me.joints()
	var hip: Vector3 = _shown(0, "hip")
	near((hip - main.camera.position).dot(j["fwd"]), -CrewView.OWN_BACK, 1e-3, "стоя своя модель чуть позади камеры")
	main.sit_at_helm()
	main.step(1.0 / 30.0)
	eq(main.me.joints()["hip"], Crew.seat_hip(), "сидя — на месте, руки на штурвале")
	main.stand_up()


func test_hands_on_posts_in_scene() -> void:
	main.walker.x = -3.9
	main.walker.z = -2.0
	main.open_power()
	main.power.sel = 4
	for i in 10:   # наклон к пульту плавный
		main.step(1.0 / 30.0)
	var g := CrewHands.energy(4, main.reactor.share[4] / float(Reactor.MAX))
	ok(main.me.hands[1].is_equal_approx(g[1]), "у пульта: правая на ползунке прожектора")
	var hand: Vector3 = main.crew_view.shown[0]["hand_r"]
	var sh: Vector3 = main.crew_view.shown[0]["shoulder_r"]
	## Ракурс ART-050: своя фигура у камеры (как в макете) — рука вытянута к ползунку, хват — в me.hands для сети.
	ok(hand.distance_to(g[1]) < sh.distance_to(g[1]) - 0.4, "модель тянется к ползунку (%.3f м)" % hand.distance_to(g[1]))
	main.close_power()
	main.step(1.0 / 30.0)
	ok(not main.me.holding(), "отошёл от пульта — руки свободны")
	main.walker.x = 0.0
	main.walker.z = 0.5
	main.use_post("sonar")
	main.step(1.0 / 30.0)
	ok(main.me.hands[0].is_finite() and main.me.hands[0].z > BridgeProps.TABLE_Z, "импульс — ладони на голостоле")
	for i in int(CrewHands.PRESS * 30.0) + 2:
		main.step(1.0 / 30.0)
	ok(not main.me.holding(), "через %.1f с руки свободны" % CrewHands.PRESS)


## По issue #106: наклон к голостолу — камера идёт за головой, а не остаётся над спиной (лоскуты меша у камеры).
func test_camera_follows_lean_at_table() -> void:
	main.walker.x = 0.0
	main.walker.z = 0.5
	main.walker.yaw = 0.0
	main.use_post("sonar")
	for i in 10:
		main.step(1.0 / 30.0)
	ok(main.me.lean > 0.1, "наклон к столу (%.2f рад)" % main.me.lean)
	var j := main.me.joints()
	var head: Vector3 = j["head"] + (j["fwd"] as Vector3) * (0.04 + main.me.back)   # фигура позади глаза
	ok(main.camera.position.distance_to(head) < 0.01, "камера в голове (%.3f м)" % main.camera.position.distance_to(head))
	for i in int(CrewHands.PRESS * 30.0) + 10:
		main.step(1.0 / 30.0)
	eq(main.me.lean, 0.0, "руки свободны — выпрямился")
	near(main.camera.position.y, Deck.Walker.EYE, 1e-4, "камера на прежней высоте")


## По issue #107: у пульта энергии игрок встаёт к нему и смотрит на ползунки — ближняя рука на выбранном.
func test_power_steps_to_panel() -> void:
	main.walker.x = -3.4   # край радиуса поста
	main.walker.z = -2.3
	main.open_power()
	var post: Deck.Post = Deck.posts().filter(func(p): return p.id == "energy")[0]
	eq(Vector2(main.walker.x, main.walker.z), Main.POWER_STAND, "встал к пульту")
	ok(Main.POWER_STAND.distance_to(post.at) < post.r, "в радиусе поста")
	near(main.walker.pitch, Main.POWER_PITCH, 1e-6, "взгляд на ползунки")
	main.power.sel = 0
	for i in 15:
		main.step(1.0 / 30.0)
	var g := CrewHands.energy(0, main.reactor.share[0] / float(Reactor.MAX))
	ok(main.me.hands[0].is_equal_approx(g[0]), "левая на ползунке двигателей (хват для сети и товарищей)")
	var hand: Vector3 = main.crew_view.shown[0]["hand_l"]
	var sh: Vector3 = main.crew_view.shown[0]["shoulder_l"]
	ok(hand.distance_to(g[0]) < sh.distance_to(g[0]) - 0.4, "модель тянется к ползунку (%.3f м)" % hand.distance_to(g[0]))
	main.close_power()


## Ракурс открытого пульта ART-050: камера и своя фигура — у CAM_AT (курс 70°, наклон −32°), таблица справа не
## закрывает ползунки; ходок и место для сети — у пульта, свайп крутит взгляд от ракурса; закрыл — камера в ходоке.
func test_power_view() -> void:
	main.open_power()
	main.step(1.0 / 30.0)
	var cam: Vector3 = main.camera.position
	near(Vector2(cam.x, cam.z).distance_to(PowerScreen.CAM_AT), 0.0, 0.15, "камера на ракурсе (в голове наклонённой фигуры)")
	near(main.camera.rotation.y, PowerScreen.CAM_YAW, 1e-4, "курс 70°")
	near(main.camera.rotation.x, PowerScreen.CAM_PITCH, 1e-4, "наклон −32°")
	eq(Vector2(main.walker.x, main.walker.z), Main.POWER_STAND, "ходок у пульта")
	eq(Vector2(main.me.x, main.me.z), Main.POWER_STAND, "для сети — у пульта")
	var hip: Vector3 = main.crew_view.shown[0]["hip"]
	ok(Vector2(hip.x, hip.z).distance_to(PowerScreen.CAM_AT) < 0.3, "своя фигура — у камеры, не заслоняет пульт")
	main.walker.yaw += 0.2   # свайп
	main.step(1.0 / 30.0)
	near(main.camera.rotation.y, PowerScreen.CAM_YAW + 0.2, 1e-4, "свайп — от ракурса")
	main.close_power()
	main.step(1.0 / 30.0)
	var eye: Vector3 = main.pilot.eye(main.walker) + main.me.eye_offset()
	ok(main.camera.position.distance_to(eye) < 1e-4, "закрыл — камера в ходоке")
	near(main.camera.rotation.y, main.walker.yaw, 1e-6, "курс ходока")


## Снаряжение ролей MOD-016: роль видна по деталям, свой игрок не видит их на голове и груди, щиток — на сварке.
func test_role_gear() -> void:
	var mate := main.add_mate(0.0, -4.6, PI, Crew.Role.ENGINEER, 0)
	main.step(1.0 / 30.0)
	var i := main.crew.find(mate)
	var g: Dictionary = main.crew_view.gear[i]
	eq(g.keys(), CrewRig.ROLE_GEAR[Crew.Role.ENGINEER], "инженер — фартук и щиток")
	for n in g.values():
		ok((n as Node3D).is_visible_in_tree(), "%s видна" % n.name)
		for mi in (n as Node).find_children("*", "MeshInstance3D", true, false):
			eq((mi as MeshInstance3D).layers, 2, "%s на слое корабля" % n.name)
	var visor: Node3D = g["gear-shchitok"]
	var head: Vector3 = main.crew_view.shown[i]["head"]
	var at := main.crew_view.to_local(visor.global_position)
	ok(at.distance_to(head) < 0.3, "щиток у головы (%.2f м)" % at.distance_to(head))
	var up := visor.transform
	mate.weld(Vector3(0.0, 1.2, -6.0), Vector3.BACK)
	main.step(1.0 / 30.0)
	ok(not visor.transform.is_equal_approx(up), "на сварке щиток опущен")
	mate.weld(Vector3.INF)
	mate.role = Crew.Role.BIOLOGIST
	main.step(1.0 / 30.0)
	eq(main.crew_view.gear[i].keys(), CrewRig.ROLE_GEAR[Crew.Role.BIOLOGIST], "сменил роль — туника и пробы")
	var own: Dictionary = main.crew_view.gear[main.crew.find(main.me)]
	ok(not (own["gear-garnitura"] as Node3D).visible, "своя гарнитура не видна (камера в голове)")


## По issue #137: у щитка «Аварийный сброс» игрок встаёт к нему, плечи позади камеры (камера не внутри груди —
## не видно изнанки обрезанного меша), правая кисть на крышке.
func test_scram_body_behind_camera() -> void:
	main.walker.x = EngineRoom.PANEL_POST.x - 0.1
	main.walker.z = EngineRoom.PANEL_POST.y + 0.3
	main.use_post("scram")
	for i in 10:
		main.step(1.0 / 30.0)
	eq(Vector2(main.walker.x, main.walker.z), Main.SCRAM_STAND, "встал к щитку")
	ok(main.layout.can_stand(main.walker.x, main.walker.z), "место у щитка свободно")
	var fwd: Vector3 = main.me.joints()["fwd"]
	near(fwd.x, 1.0, 1e-4, "лицом к щитку (+X)")
	var sh: Vector3 = (_shown(0, "shoulder_l") + _shown(0, "shoulder_r")) * 0.5
	var ahead := (sh - main.camera.position).dot(fwd)
	ok(ahead < -0.08, "плечи позади камеры (%.3f м)" % ahead)
	var hand: Vector3 = _shown(0, "hand_r")
	ok(hand.distance_to(CrewHands.SCRAM_GRIP) < 0.08, "кисть на крышке (%.3f м)" % hand.distance_to(CrewHands.SCRAM_GRIP))


## По issue #108: стоя взглядом вниз видны свои ноги и ступни — груди у камеры нет, фигура дальше позади глаза.
func test_look_down_sees_feet() -> void:
	main.walker.x = 0.0
	main.walker.z = -3.0
	main.walker.yaw = 0.0
	main.walker.pitch = -0.1
	main.step(1.0 / 30.0)
	var cv := main.crew_view
	eq(CrewView.mesh_kind(main.me, true, main.walker.pitch), 1, "взгляд вперёд — меш с грудью")
	main.walker.pitch = -1.4
	for i in 3:
		main.step(1.0 / 30.0)
	eq(CrewView.mesh_kind(main.me, true, main.walker.pitch), 2, "взгляд вниз — меш без груди")
	ok(cv.meshes[0].mesh == cv._meshes[cv.looks[0]][2], "на фигуре — меш без груди")
	near(main.me.back, CrewView.DOWN_BACK, 1e-4, "фигура дальше позади глаза")
	var cam: Transform3D = main.camera.transform
	var hip: Vector3 = _shown(0, "hip")
	var fwd: Vector3 = main.me.joints()["fwd"]
	for k in ["toe_l", "toe_r"]:
		var toe: Vector3 = _shown(0, k)
		var loc := cam.affine_inverse() * toe
		ok(loc.z < 0.0 and absf(rad_to_deg(atan2(loc.y, -loc.z))) < Deck.FOV * 0.5, "%s в кадре" % k)
		## Луч к носку проходит перед поясом, а не сквозь него.
		var t := (cam.origin.y - hip.y) / (cam.origin.y - toe.y)
		var p := cam.origin.lerp(toe, t)
		ok((p - hip).dot(fwd) > 0.2, "%s: луч на %.2f м перед поясом" % [k, (p - hip).dot(fwd)])
	main.sit_at_helm()
	main.step(1.0 / 30.0)
	eq(CrewView.mesh_kind(main.me, true, main.walker.pitch), 1, "сидя — с грудью")
	main.stand_up()


func test_own_back_by_pitch() -> void:
	near(CrewView.own_back(0.0), CrewView.OWN_BACK, 1e-6, "взгляд вперёд — как было")
	near(CrewView.own_back(CrewView.LEGS_PITCH), CrewView.OWN_BACK, 1e-6, "с порога — плавно")
	near(CrewView.own_back(-1.45), CrewView.DOWN_BACK, 1e-6, "до конца вниз")
	var a := CrewView.own_back(-0.9)
	ok(a > CrewView.OWN_BACK and a < CrewView.DOWN_BACK, "посередине — между")
	near(CrewView.own_back(-1.45, true), CrewView.OWN_BACK, 1e-6, "руки на посте — не отъезжает от пульта")


func test_helm_busy_for_second() -> void:   # ROADMAP «Кооп»: занятый пост не даёт сесть второму
	var mate := main.add_mate(0.0, Deck.SEAT_Z, 0.0, Crew.Role.SONAR, 0, true)
	eq(mate.post, "helm", "второй держит штурвал")
	main.walker.x = 0.6
	main.walker.z = Deck.CHAIR_Z + 0.9
	main.step(1.0 / 30.0)
	eq(main.overlay.action_label, "Занято", "на кнопке — «Занято»")
	ok(main.status_parts().has("Штурвал занят"), "в строке состояния — «Штурвал занят»")
	main.use_post("helm")
	ok(not main.pilot.seated, "свой игрок не сел во второе кресло")
	eq(main.message.text, "Штурвал занят: Сонарщик", "на приборах — кто держит")
	mate.follow(0.6, Deck.CHAIR_Z + 1.5, 0.0, false, 0.0, 0.1)
	mate.post = ""
	main.step(1.0 / 30.0)
	eq(main.overlay.action_label, "Штурвал", "встал — пост свободен")
	ok(main.status_parts().has("Сесть за штурвал"), "в строке — снова «Сесть за штурвал»")
	main.use_post("helm")
	ok(main.pilot.seated, "теперь сел")
	main.step(1.0 / 30.0)
	eq(main.me.post, "helm", "свой игрок держит штурвал")
	eq(Crew.holder(main.crew, mate, "helm"), main.me, "для второго штурвал занят")


func test_posts_are_member_state() -> void:   # ROADMAP «Кооп»: посты у каждого свои — состояние Member, не main
	ok(main.pilot == main.me.pilot, "штурвал своего игрока — его Member")
	main.open_power()
	ok(main.me.at_power, "у пульта — флаг своего Member")
	main.close_power()
	var m := main.add_mate(1.5, 0.5, 0.0, Crew.Role.ENGINEER, 0)
	ok(m.pilot != main.me.pilot, "у товарища свой штурвальный флаг")
	main.sit_at_helm()
	ok(main.me.seated and not m.seated, "сел свой — товарищ стоит")
	main.stand_up()


func test_mate_action_sits_and_stands() -> void:   # кнопка действия товарища садит его за штурвал и поднимает
	var m := main.add_mate(0.6, Deck.CHAIR_Z + 0.9, 0.0, Crew.Role.SONAR, 1)
	m.pad.action = true
	main.step(1.0 / 30.0)
	ok(m.seated, "товарищ сел за штурвал своей кнопкой")
	eq(m.post, "helm", "держит штурвал")
	ok(not m.pad.action, "нажатие съедено")
	ok(not main.pilot.seated, "свой игрок не сел")
	m.pad.move = Vector2(0.0, 1.0)
	var z0 := m.walker.z
	for i in 10:
		main.step(1.0 / 30.0)
	eq(m.walker.z, z0, "сидящий не ходит крестовиной")
	m.pad.clear()
	main.walker.x = 0.6
	main.walker.z = Deck.CHAIR_Z + 0.9
	main.use_post("helm")
	ok(not main.pilot.seated, "свой игрок не сел в занятое кресло")
	eq(main.message.text, "Штурвал занят: Сонарщик", "на приборах — кто держит")
	m.pad.action = true
	main.step(1.0 / 30.0)
	ok(not m.seated, "товарищ встал")
	eq(m.post, "", "штурвал свободен")
	main.use_post("helm")
	ok(main.pilot.seated, "теперь сел свой")
	m.pad.action = true
	main.step(1.0 / 30.0)
	ok(not m.seated, "в занятое кресло товарищ не садится")


func test_mate_action_power() -> void:   # товарищ у пульта энергии: держит пост, свой игрок к пульту не встаёт
	var m := main.add_mate(-3.5, -2.0, PI / 2.0, Crew.Role.ENGINEER, 0)
	m.pad.action = true
	main.step(1.0 / 30.0)
	ok(m.at_power, "инженер у пульта")
	eq(m.post, "energy", "держит пульт")
	near(m.walker.x, Main.POWER_STAND.x, 0.01, "шагнул к ползункам")
	ok(not main.at_power, "свой игрок не у пульта")
	m.pad.move = Vector2(0.0, 1.0)
	for i in 10:
		main.step(1.0 / 30.0)
	near(m.walker.z, Main.POWER_STAND.y, 0.01, "у пульта крестовина не ведёт ходока")
	m.pad.clear()
	main.walker.x = -3.3
	main.walker.z = -1.5
	main.step(1.0 / 30.0)
	eq(main.overlay.action_label, "Занято", "на кнопке — «Занято»")
	main.use_post("energy")
	ok(not main.at_power, "свой игрок не встал к занятому пульту")
	eq(main.message.text, "Пульт энергии занят: Инженер", "на приборах — кто держит")
	m.pad.action = true
	main.step(1.0 / 30.0)
	ok(not m.at_power, "инженер отошёл")
	main.use_post("energy")
	ok(main.at_power, "теперь у пульта свой")
	main.close_power()


func test_busy_message_clears_when_mate_leaves() -> void:   # issue #419: «Пульт энергии занят: Инженер» после ухода
	var m := main.add_mate(-3.5, -2.0, PI / 2.0, Crew.Role.ENGINEER, 0)
	m.pad.action = true
	main.step(1.0 / 30.0)
	m.pad.clear()
	ok(m.at_power, "инженер у пульта")
	main.walker.x = -3.3
	main.walker.z = -1.5
	main.use_post("energy")
	eq(main.message.text, "Пульт энергии занят: Инженер", "на приборах — кто держит")
	main.step(1.0 / 30.0)
	eq(main.message.text, "Пульт энергии занят: Инженер", "пока держит — строка остаётся")
	main.mate_gone(m)
	main.step(1.0 / 30.0)
	eq(main.message.text, "", "инженер отключился — строка погасла сразу")
	main.say("Прожектор включён")
	main.step(1.0 / 30.0)
	eq(main.message.text, "Прожектор включён", "чужое сообщение не гасим")


func test_busy_message_clears_when_mate_stands() -> void:
	var m := main.add_mate(-3.5, -2.0, PI / 2.0, Crew.Role.ENGINEER, 0)
	m.pad.action = true
	main.step(1.0 / 30.0)
	main.walker.x = -3.3
	main.walker.z = -1.5
	main.use_post("energy")
	m.pad.action = true
	main.step(1.0 / 30.0)
	ok(not m.at_power, "инженер отошёл")
	main.step(1.0 / 30.0)
	eq(main.message.text, "", "пост свободен — строка «занят» погасла")


func test_mate_action_vote() -> void:   # у голостола товарищ встаёт к голосованию только после маршрута
	var m := main.add_mate(Main.ROUTE_POST.x + 0.3, Main.ROUTE_POST.y + 0.3, 0.0, Crew.Role.BIOLOGIST, 1)
	m.walker.x = Main.ROUTE_POST.x + 0.2
	m.walker.z = Main.ROUTE_POST.y + 0.2
	m.pad.action = true
	main.step(1.0 / 30.0)
	ok(not m.at_vote, "маршрут не пройден — голосовать рано")
	main.complete_route()
	m.pad.action = true
	main.step(1.0 / 30.0)
	ok(m.at_vote, "товарищ у голосования")
	ok(not main.at_vote, "свой игрок — нет")
	m.pad.action = true
	main.step(1.0 / 30.0)
	ok(not m.at_vote, "кнопка — отойти")


func test_mate_action_sonar() -> void:   # ROADMAP «импульс сонара у гостя»: кнопка товарища у голостола — импульс хоста
	var m := main.add_mate(-1.3, -1.6, -PI / 2.0, Crew.Role.SONAR, 1)
	m.walker.x = -1.3
	m.walker.z = -1.6
	main.time = 50.0
	var n := main.sonar.count
	var e0: float = main.vitals.energy
	m.pad.action = true
	main.step(1.0 / 30.0)
	eq(main.sonar.count, n + 1, "импульс прошёл")
	ok(main.vitals.energy < e0, "заряд потрачен, как за свой импульс")
	ok(not m.busy(), "у голостола товарищ поста не держит")
	eq(str(main.news[1]).begins_with("Сонар:"), true, "ответ приборов — всем (сообщение события): %s" % [main.news])
	m.pad.action = true
	main.step(1.0 / 30.0)
	eq(main.sonar.count, n + 1, "перезарядка — второго импульса нет")


func test_coop_vote_majority() -> void:   # двое у голостола: метки — голоса игроков, решение ждёт второго
	main.walker.x = Main.ROUTE_POST.x
	main.walker.z = Main.ROUTE_POST.y
	main.complete_route()
	var m := main.add_mate(Main.ROUTE_POST.x + 0.2, Main.ROUTE_POST.y + 0.2, 0.0, Crew.Role.BIOLOGIST, 1)
	m.walker.x = Main.ROUTE_POST.x + 0.2
	m.walker.z = Main.ROUTE_POST.y + 0.2
	m.pad.action = true
	main.step(1.0 / 30.0)
	ok(m.at_vote, "биолог у стола")
	main.use_post("route")
	ok(main.at_vote, "свой у стола")
	main.ballot.cast(main.me.get_instance_id(), main.me.role, "deep")   # своя крестовина — Run.vote_nav
	main.step(1.0 / 30.0)
	ok(main.at_vote and not main.run.ended, "один голос из двух — ждём")
	eq(main.vote_marks(), {"deep": [main.me.role], "up": []}, "метка — свой голос цветом роли")
	ok(main.vote_panel.tally.begins_with("голосов 1 из 2"), "счёт на панели: " + main.vote_panel.tally)
	var depth := main.run.depth
	m.pad.move = Vector2(0, -1)   # своя крестовина биолога
	main.step(1.0 / 30.0)
	eq(main.run.depth, depth + 1, "оба за «глубже» — следующий спуск")
	ok(not main.at_vote and not m.at_vote, "все отошли от стола")
	eq(main.vote_panel.tally, "")


func test_coop_vote_timer_up() -> void:   # второй молчит — по таймеру решает поданный голос
	main.walker.x = Main.ROUTE_POST.x
	main.walker.z = Main.ROUTE_POST.y
	main.complete_route()
	var m := main.add_mate(Main.ROUTE_POST.x + 0.2, Main.ROUTE_POST.y + 0.2, 0.0, Crew.Role.ENGINEER, 0)
	m.walker.x = Main.ROUTE_POST.x + 0.2
	m.walker.z = Main.ROUTE_POST.y + 0.2
	m.pad.action = true
	main.step(1.0 / 30.0)
	main.use_post("route")
	m.pad.move = Vector2.ZERO
	main.step(1.0 / 30.0)
	m.pad.move = Vector2(0, 1)
	main.step(1.0 / 30.0)
	eq(main.vote_marks(), {"deep": [], "up": [Crew.Role.ENGINEER]}, "инженер за «наверх»")
	for i in int(Ballot.TIME * 2.0) - 1:
		main.step(0.5)
		ok(not main.run.ended, "до конца таймера не решено")
		if main.run.ended:
			break
	main.step(0.5)
	main.step(0.5)
	ok(main.run.ended, "время вышло — наверх")
	ok(main.at_vote, "свой у стола видит итог")
	main.close_vote()
