extends TestCase
## Трубный орган (initOrgans, organsUpdate, hearsShip в js/creatures.js; ART-004): две губки по семь труб, гул
## прячет двигатели корабля от серпохвоста ближе 22 м, наблюдения «hum» и «mask», цели сонара и сканера, один меш.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _organs(w: EcoWorld) -> EcoOrgan:
	for s in w.systems:
		if s is EcoOrgan:
			return s
	return null


func _preds(w: EcoWorld) -> EcoPred:
	for s in w.systems:
		if s is EcoPred:
			return s
	return null


func _notes(w: EcoWorld, species: String, note: String) -> Array[EcoBus.Event]:
	var out: Array[EcoBus.Event] = []
	for ev in w.bus.pending:
		if ev.species == species and ev.note == note:
			out.append(ev)
	return out


## Ровное дно, серпохвосты и губка у первого хищника (−40, 20); with_organ = false — без губки.
func _pred_world(with_organ := true) -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var p := w.add(EcoPred.new()) as EcoPred
	if with_organ:
		p.organs = w.add(EcoOrgan.new([Vector2(-40, 20)] as Array[Vector2])) as EcoOrgan
	return w


## Первый хищник голоден, готов напасть; корабль в 20 м по +X на его высоте и идёт быстро — шум слышно.
func _loud_ship(w: EcoWorld) -> EcoPred.Pred:
	var pr := _preds(w).all[0]
	pr.hunger = 0.5
	pr.cooldown = 0.0
	w.ship.pos = pr.agent.p + Vector3(20, 0, 0)
	w.ship.speed = 4.0
	return pr


# ---------- Расстановка ----------

func test_two_organs_seven_tubes_on_ground() -> void:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	var o := w.add(EcoOrgan.new()) as EcoOrgan
	eq(o.organs.size(), 3, "две губки из браузера и третья в Тихой заводи (#831)")
	for i in o.organs.size():
		var og := o.organs[i]
		near(og.base.x, EcoOrgan.SPOTS[i].x, 1e-6, "место из браузера")
		near(og.base.z, EcoOrgan.SPOTS[i].y, 1e-6)
		near(og.base.y, Seabed.height(og.base.x, og.base.z), 1e-4, "на дне")
		near(og.top.y - og.base.y, EcoOrgan.TOP_UP, 1e-6, "верх на 3,2 м")
		eq(og.tube_base.size(), EcoOrgan.TUBES, "семь труб")
		near(Vector2(og.tube_base[0].x - og.base.x, og.tube_base[0].z - og.base.z).length(), 0.0, 1e-6, "первая — в середине")
		for k in EcoOrgan.TUBES:
			var b := og.tube_base[k]
			near(b.y, Seabed.height(b.x, b.z) - EcoOrgan.SINK, 1e-4, "труба уходит в дно на 0,1 м")
			var r := Vector2(b.x - og.base.x, b.z - og.base.z).length()
			if k > 0:
				near(r, 0.75 if k % 2 == 0 else 1.1, 1e-4, "кольца 0,75 и 1,1 м")
			near(og.tube_len[k], 3.4 - r * 1.2 + (k % 3) * 0.4, 1e-4, "длина по organGeo")
			ok(og.tube_len[k] > 2.0 and og.tube_len[k] < 4.0, "около 2,5–3,4 м")
	var t := w.scan_targets()
	eq(t.size(), o.organs.size(), "все губки видны сонару и сканеру")
	eq(t[0]["species"], EcoOrgan.ID)
	near(t[1]["r"], 1.6, 1e-6)


# ---------- Гул и наблюдения ----------

func test_hums_when_ship_near_once_per_120s() -> void:
	var w := EcoWorld.new()
	w.ground = _flat
	var o := w.add(EcoOrgan.new([Vector2(0, 0)] as Array[Vector2])) as EcoOrgan
	w.ship.pos = Vector3(32, FLAT, 0)
	w.run(1.0)
	eq(_notes(w, EcoOrgan.ID, "hum").size(), 0, "дальше 30 м не гудит в журнал")
	near(o.loudness, 1.0 - 32.0 / 45.0, 1e-4, "гул слышно ближе 45 м")
	w.ship.pos = Vector3(25, FLAT, 0)
	w.run(1.0)
	var ev := _notes(w, EcoOrgan.ID, "hum")
	eq(ev.size(), 1, "ближе 30 м — гудит")
	eq(ev[0].text(), "Гудящая губка гудит в течении, как орган", "не изучен — по виду")
	w.run(118.0)
	eq(_notes(w, EcoOrgan.ID, "hum").size(), 1, "раз в 120 с")
	w.run(1.5)
	eq(_notes(w, EcoOrgan.ID, "hum").size(), 2, "через 120 с — снова")
	w.ship.pos = FAR
	w.run(0.1)
	near(o.loudness, 0.0, 1e-6, "далеко — тихо")


func test_hum_is_link_observe() -> void:
	var w := EcoWorld.new()
	w.ground = _flat
	w.add(EcoOrgan.new([Vector2(0, 0)] as Array[Vector2]))
	w.scanned = func(id: String) -> bool: return id == EcoOrgan.ID
	w.ship.pos = Vector3(10, FLAT, 0)
	w.run(0.1)
	var found := false
	for e in w.take_link():
		if e["type"] == EcoLink.OBSERVE and e["species"] == EcoOrgan.ID and e["note"] == "hum":
			found = true
			eq(e["text"], "Трубный орган гудит в течении, как орган", "изучен — по имени")
	ok(found, "наблюдение для журнала")


func test_organ_masks_engines_from_pred() -> void:
	var w := _pred_world(false)
	var pr := _loud_ship(w)
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.CHARGE, "без губки двигатели слышно")

	w = _pred_world()
	pr = _loud_ship(w)
	ok(_organs(w).masking(w) != null, "корабль в гуле: ближе 22 м к губке")
	w.run(3.0)
	eq(pr.mode, EcoPred.Mode.PATROL, "в гуле серпохвост не слышит корабль")
	eq(_notes(w, EcoPred.ID, "hear").size(), 0)
	var ev := _notes(w, EcoOrgan.ID, "mask")
	eq(ev.size(), 1, "наблюдение «mask» один раз")
	ok(ev[0].text().begins_with("Гул гудящей губки заглушает двигатели — ") and ev[0].text().ends_with(" не слышит корабль"), ev[0].text())
	w.run(36.0)
	eq(_notes(w, EcoOrgan.ID, "mask").size(), 1, "раз в 40 с")
	# патрульный уплыл — возвращаем его и корабль к губке
	pr.agent.p = pr.start
	w.ship.pos = pr.start + Vector3(20, 0, 0)
	w.run(2.5)
	eq(_notes(w, EcoOrgan.ID, "mask").size(), 2, "через 40 с — снова")
	eq(pr.mode, EcoPred.Mode.PATROL, "и снова не слышит")


func test_organ_does_not_hide_light() -> void:
	var w := _pred_world()
	var pr := _loud_ship(w)
	w.ship.light_on = true
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.CHARGE, "свет прожектора гул не прячет")
	eq(_notes(w, EcoOrgan.ID, "mask").size(), 0, "заметил свет — гул ни при чём")


func test_mask_only_for_watching_pred() -> void:
	var w := _pred_world()
	var pr := _loud_ship(w)
	pr.mode = EcoPred.Mode.EAT
	pr.agent.timer = 10.0
	w.step(EcoWorld.MAX_STEP)
	eq(_notes(w, EcoOrgan.ID, "mask").size(), 0, "ест — не слушает, наблюдения нет")
	eq(pr.mode, EcoPred.Mode.EAT)

	# сытый патрульный тоже «не слышит»: заметка есть, хоть нападать он и не стал бы
	w = _pred_world()
	pr = _loud_ship(w)
	pr.hunger = 0.0
	w.step(EcoWorld.MAX_STEP)
	eq(_notes(w, EcoOrgan.ID, "mask").size(), 1, "патрульный в гуле не слышит корабль")


func test_slow_or_far_ship_not_masked_event() -> void:
	var w := _pred_world()
	var pr := _loud_ship(w)
	w.ship.speed = 2.0
	w.run(1.0)
	eq(_notes(w, EcoOrgan.ID, "mask").size(), 0, "малый ход и так не слышно")
	eq(pr.mode, EcoPred.Mode.PATROL)


func test_reset_clears_cooldowns() -> void:
	var w := _pred_world()
	_loud_ship(w)
	w.run(1.0)
	eq(_notes(w, EcoOrgan.ID, "mask").size(), 1)
	w.reset()
	var og := _organs(w).organs[0]
	near(og.mask_cd, 0.0, 1e-6, "пауза «mask» с нуля")
	near(og.hum_cd, 0.0, 1e-6, "пауза «hum» с нуля")
	eq(w.bus.pending.size(), 0)


# ---------- Сцена ----------

func test_view_one_mesh() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	ok(view.preds.organs == view.organs, "серпохвосты знают про органы")
	var ov := view.organ_view
	ok(ov != null and ov.get_parent() == view, "органы — в живом мире")
	eq(ov.layers, OceanView.LAYER_WORLD, "слой отмели")
	eq(ov.mesh.get_surface_count(), 1, "один вызов отрисовки")
	var per_tube := OrganView.SIDES * 2 + OrganView.SIDES * OrganView.RIM_SIDES * 2
	eq(ov.tris, EcoOrgan.SPOTS.size() * EcoOrgan.TUBES * per_tube, "треугольников: %d" % ov.tris)
	var og := view.organs.organs[1]
	var top := og.tube_base[3] + Vector3(0, og.tube_len[3], 0)
	var best := INF
	for v in ov.verts:
		best = minf(best, v.distance_to(top + Vector3(EcoOrgan.TUBE_TOP_R, 0, 0)))
	ok(best < 0.06, "устье трубы — в меше")
	view.queue_free()
	await frames(1)
