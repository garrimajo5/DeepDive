extends TestCase
## Наблюдение поля 08 (#831, часть 2): точка — как на карте слоя `LayerMap`; жизнь редкая — два веерника по бокам
## площадки, вид на запад открыт, проход 07→08 свободен; ни стай, ни рощ, ни кустов у площадки.


func test_place_from_layer_map() -> void:
	eq(EcoField.CENTER, LayerMap.xz("08"), "середина площадки — место 08 карты слоя")
	eq(LayerMap.POINTS["08"]["key"], EcoField.ID, "ключ места как в LayerMap")
	eq(Run.PLACES[EcoField.ID][1], EcoField.CENTER, "точка маршрута — на площадке")


## Веерники у площадки, не западнее её, дальше CLEAR от проходов и друг от друга.
func test_fans_off_lane_and_view() -> void:
	eq(EcoField.FANS.size(), 2, "жизнь редкая — два веерника")
	for p in EcoField.FANS:
		var d := p.distance_to(EcoField.CENTER)
		ok(d > 30.0 and d < 60.0, "у площадки, но не на ней (%.1f м)" % d)
		ok(p.x >= EcoField.CENTER.x, "вид на запад открыт")
		for s: Array in Seabed.Layer.segments():
			ok(Seabed.Layer._seg_dist(p, s[0], s[1]) >= EcoField.CLEAR, "дальше %.0f м от прохода" % EcoField.CLEAR)
	ok(EcoField.FANS[0].distance_to(EcoField.FANS[1]) >= 60.0, "по разные стороны площадки")
	for p in EcoField.FANS:
		ok(EcoFan.default_spots().has(p), "веерник площадки — в местах EcoFan")


## В мире у площадки стоят оба веерника на дне гребня и поперёк течения; других видов ближе 60 м нет.
func test_world_sparse() -> void:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	var sea := w.add(EcoCurrent.new()) as EcoCurrent
	var fish := w.add(EcoFish.new()) as EcoFish
	w.add(EcoCoral.new())
	var fans := w.add(EcoFan.new(sea)) as EcoFan
	w.add(EcoKelp.new(fish))
	w.add(EcoOrgan.new())
	w.ship.pos = Vector3(EcoField.CENTER.x, -30.0, EcoField.CENTER.y)
	for i in 20:
		w.step(0.1)
	var here := 0
	for f in fans.fans:
		if Vector2(f.pos.x, f.pos.z).distance_to(EcoField.CENTER) < 60.0:
			here += 1
			near(f.pos.y, Seabed.height(f.pos.x, f.pos.z) - 0.05, 1e-4, "на дне")
			ok(f.pos.y > Seabed.Layer.RIDGE_FLOOR - 4.0, "на гребне, а не в яме (%.1f м)" % f.pos.y)
	eq(here, 2, "у площадки — два веерника")
	for t in w.scan_targets():
		var p: Vector3 = t["pos"]
		if Vector2(p.x, p.z).distance_to(EcoField.CENTER) < 60.0:
			eq(t["species"], EcoFan.ID, "у площадки только веерники")
	for sh in fish.shoals:
		ok(Vector2(sh.home.x, sh.home.z).distance_to(EcoField.CENTER) > 60.0, "стая %d живёт не на площадке" % sh.index)


## Весь живой мир (как в игре): у площадки после расстановки — только веерники.
func test_scene_only_fans_near() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var seen := {}
	for t in view.world.scan_targets():
		var p: Vector3 = t["pos"]
		if Vector2(p.x, p.z).distance_to(EcoField.CENTER) < 60.0:
			seen[t["species"]] = int(seen.get(t["species"], 0)) + 1
	eq(seen, {EcoFan.ID: 2}, "у площадки — два веерника и больше ничего")
	view.queue_free()
	await frames(1)


## Пограничное поле (#833): крупный вид, плывущий на запад, разворачивается у кромки пояса и в пояс не заходит.
func test_big_turns_at_belt() -> void:
	var a := EcoAgent.new("pred", Vector3(-270.0, -20.0, -210.0))
	ok(a.big, "серпохвост — крупный")
	var turned := false
	for i in 300:
		a.steer_to(Vector3(-400.0, -20.0, -210.0), 6.0, 0.05)
		ok(a.p.x >= EcoField.BELT_IN, "не в поясе (x = %.2f)" % a.p.x)
		if a.v.x > 0.0:
			turned = true
	ok(turned, "развернулся на восток")
	ok(a.goal.x >= EcoField.BELT_IN, "цель за кромкой отражена на восток")


## Мелкий вид проходит в пояс до края отмели — дальше края мира нет (выхода во внешний океан нет).
func test_small_passes_belt() -> void:
	var a := EcoAgent.new("fish", Vector3(-270.0, -20.0, -210.0))
	ok(not a.big, "светляк — мелкий")
	for i in 300:
		a.steer_to(Vector3(-400.0, -20.0, -210.0), 6.0, 0.05)
	ok(EcoField.in_belt(a.p.x), "в поясе (x = %.2f)" % a.p.x)
	near(a.p.x, -EcoAgent.EDGE, 0.01, "дальше края отмели — нет")
	ok(-EcoAgent.EDGE > EcoField.BELT_OUT, "край отмели — внутри пояса")
	ok(-EcoAgent.EDGE < EcoField.BELT_IN, "край отмели — за внутренней кромкой")


## Восток и прочие края поле не трогает; кромку держит только запад.
func test_belt_only_west() -> void:
	var a := EcoAgent.new("pred", Vector3(280.0, -20.0, 280.0))
	for i in 200:
		a.steer_to(Vector3(400.0, -20.0, 400.0), 6.0, 0.05)
	near(a.p.x, EcoAgent.EDGE, 0.01, "на востоке — обычный край отмели")
	near(a.p.z, EcoAgent.EDGE, 0.01, "на юге — тоже")


## В мире ни одно логово стеклоуста и ни один старт серпохвоста не лежит в поясе — крупных у поля не выталкивает.
func test_big_homes_off_belt() -> void:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	var fish := w.add(EcoFish.new()) as EcoFish
	var moss := w.add(EcoMoss.new()) as EcoMoss
	var grazers := w.add(EcoGrazer.new(moss)) as EcoGrazer
	w.add(EcoPred.new(fish))
	w.add(EcoEel.new(grazers, fish))
	w.step(0.1)
	var big := 0
	for a in w.agents:
		if a.big:
			big += 1
			ok(a.home.x >= EcoField.BELT_IN, "%s дома не в поясе (x = %.1f)" % [a.species, a.home.x])
	ok(big > 0, "крупные в мире есть")
