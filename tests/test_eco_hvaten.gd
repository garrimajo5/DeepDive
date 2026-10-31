extends TestCase
## Хватень и пестрянки (initAnemones, anemoneUpdate в js/creatures.js): анемоны у стай светляков 0…3, щупальца
## прячутся в луче прожектора и раскрываются в темноте, ловят светляка у рта, пестрянки подманивают стаю и доедают
## остатки; наблюдения «hide», «immune», «lure», «catch», «leftovers»; три MultiMesh в сцене.

const FLAT := -40.0
const FAR := Vector3(500, -30, 500)


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _notes(w: EcoWorld, species: String, note: String) -> Array[EcoBus.Event]:
	var out: Array[EcoBus.Event] = []
	for ev in w.bus.pending:
		if ev.species == species and ev.note == note:
			out.append(ev)
	return out


func _system(w: EcoWorld) -> EcoHvaten:
	for s in w.systems:
		if s is EcoHvaten:
			return s
	return null


## Ровное дно, светляки, корабль далеко; один хватень у дома стаи 0 (на 3 м в сторону).
func _world() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var f := w.add(EcoFish.new()) as EcoFish
	var home := EcoFish.HOMES[0]
	var h := w.add(EcoHvaten.new(f, [Vector3(home.x + 3.0, FLAT, home.z)] as Array[Vector3])) as EcoHvaten
	_hungry(h)
	return w


## Хватень проголодался: раскрыт и готов ловить (в начале забега он сыт — START_FED).
func _hungry(h: EcoHvaten) -> void:
	for hv in h.anemones:
		hv.digest = 0.0
		hv.open = 1.0


## Корабль над точкой p так, что она в середине луча (как в test_eco_fern).
func _aim(w: EcoWorld, p: Vector3, d: float = 12.0) -> void:
	var down := deg_to_rad(Searchlight.PITCH)
	var dir := Vector3(0, -sin(down), -cos(down))
	w.ship.yaw = 0.0
	w.ship.pos = p - dir * d - Searchlight.LAMP
	w.ship.light_on = true
	w.ship.light_range = Searchlight.BASE_RANGE


# ---------- Расстановка ----------

func test_four_by_shoals_on_ground() -> void:
	var w := EcoWorld.new()
	w.ground = Seabed.height
	var f := w.add(EcoFish.new()) as EcoFish
	var h := w.add(EcoHvaten.new(f)) as EcoHvaten
	eq(h.anemones.size(), 4, "четыре хватня — у стай 0…3")
	for i in 4:
		var hv := h.anemones[i]
		var sh := f.shoals[i]
		var a := i * 2.1 + 0.7
		near(hv.base.x, sh.home.x + cos(a) * 5.0, 1e-4, "в 5 м от дома стаи %d" % i)
		near(hv.base.z, sh.home.z + sin(a) * 5.0, 1e-4)
		near(hv.base.y, Seabed.height(hv.base.x, hv.base.z), 1e-4, "на дне")
		near(hv.top.y - hv.base.y, 0.85, 1e-4, "диск на 0,85 м")
		near(hv.mouth.y - hv.top.y, 0.7, 1e-4, "рот ещё на 0,7 м выше")
		eq(hv.tents.size(), EcoHvaten.TENT, "22 щупальца")
		eq(hv.pestr.size(), EcoHvaten.PESTR_N, "три пестрянки")
		near(hv.open, EcoHvaten.DIGEST_OPEN, 1e-6, "в начале сыт — щупальца наполовину")
		near(hv.digest, EcoHvaten.START_FED, 1e-6, "первая поимка — не раньше чем через 35 с")
		ok(hv.lure_cd >= 4.0 and hv.lure_cd <= 12.0, "первое подманивание через 4–12 с")


func test_no_fish_no_anemones() -> void:
	var w := EcoWorld.new()
	w.ground = _flat
	var h := w.add(EcoHvaten.new()) as EcoHvaten
	eq(h.anemones.size(), 0, "без светляков хватней нет")
	w.run(1.0)


func test_same_seed_same_world() -> void:
	var a := _world()
	var b := _world()
	a.run(20.0)
	b.run(20.0)
	var ha := _system(a).anemones[0]
	var hb := _system(b).anemones[0]
	ok(ha.pc.is_equal_approx(hb.pc), "пестрянки там же")
	near(ha.lure_cd, hb.lure_cd, 1e-6, "те же паузы")
	near(ha.tents[5].tilt, hb.tents[5].tilt, 1e-6, "те же щупальца")


func test_fed_at_start_no_catch_or_lure() -> void:
	# В начале забега у стаи на старте нет ни поимки, ни подманивания, ни текстов: первая поимка — после 35 с.
	var w := EcoWorld.new()
	w.ground = Seabed.height
	w.ship.pos = Helm.Ship.START
	var f := w.add(EcoFish.new()) as EcoFish
	w.add(EcoHvaten.new(f))
	w.run(30.0)
	var notes := 0
	for ev in w.bus.pending:
		if ev.species == "hvaten" or ev.species == "pestr":
			notes += 1
	eq(notes, 0, "первые 30 с хватни сыты и молчат")
	w.run(30.0)
	var caught := 0
	for ev in w.bus.pending:
		if ev.species == "hvaten" and ev.note == "catch":
			caught += 1
	ok(caught > 0, "проголодавшись, ловят светляков")


# ---------- Свет ----------

func test_hides_in_beam_and_reopens_in_dark() -> void:
	var w := _world()
	var hv := _system(w).anemones[0]
	_aim(w, hv.top)
	ok(w.in_beam(hv.top), "хватень в луче")
	w.run(0.2)
	ok(hv.lit, "освещён")
	near(hv.open, 1.0 - 0.2 * EcoHvaten.CLOSE_RATE, 1e-3, "щупальца прячутся быстро")
	eq(_notes(w, "hvaten", "hide").size(), 1, "«прячет щупальца»")
	eq(_notes(w, "pestr", "immune").size(), 1, "пестрянка ныряет в щупальца")
	ok(_notes(w, "hvaten", "hide")[0].text().contains("прожектор"), "текст про прожектор")
	w.run(1.0)
	near(hv.open, 0.0, 1e-6, "спрятал совсем")
	w.ship.light_on = false
	w.run(1.0)
	near(hv.open, EcoHvaten.OPEN_RATE, 1e-3, "в темноте раскрывается медленно")
	_aim(w, hv.top)
	w.run(0.1)
	eq(_notes(w, "hvaten", "hide").size(), 1, "приоткрытый хватень — без нового «hide»")


func test_hide_message_once_in_30_s() -> void:
	var w := EcoWorld.new()  # без светляков: хватень не ловит и не переваривает — только свет
	w.ground = _flat
	w.ship.pos = FAR
	_hungry(w.add(EcoHvaten.new(null, [Vector3(0, FLAT, 0)] as Array[Vector3])) as EcoHvaten)
	var hv := _system(w).anemones[0]
	for i in 2:
		_aim(w, hv.top)
		w.run(1.0)
		w.ship.light_on = false
		w.run(5.0)  # раскрылся больше чем наполовину
	ok(hv.open > EcoHvaten.HIDE_OPEN, "снова раскрыт")
	eq(_notes(w, "hvaten", "hide").size(), 1, "не чаще раза в 30 с")
	w.run(25.0)
	_aim(w, hv.top)
	w.run(0.1)
	eq(_notes(w, "hvaten", "hide").size(), 2, "через 30 с — снова")


# ---------- Ловля ----------

## Держит рыбку first у рта хватня, пока её не поймают (не дольше limit с). Возвращает, поймана ли.
func _feed(w: EcoWorld, hv: EcoHvaten.Anemone, f: EcoFish.Fish, limit: float) -> bool:
	for i in int(limit / EcoWorld.MAX_STEP):
		f.agent.p = hv.mouth + Vector3(0.3, 0, 0)
		w.step(EcoWorld.MAX_STEP)
		if not f.agent.alive:
			return true
	return false


## Все светляки, кроме keep, съедены (вернутся через 25–40 с): хватень может поймать только тех, кого держим у рта.
func _clear(w: EcoWorld, keep: Array) -> void:
	var fish := w.systems[0] as EcoFish
	for f: EcoFish.Fish in fish.all:
		if not f in keep:
			fish.kill(f)


func test_catches_fish_in_dark() -> void:
	var w := _world()
	var h := _system(w)
	var hv := h.anemones[0]
	var fish := w.systems[0] as EcoFish
	var f := fish.shoals[0].members[0] as EcoFish.Fish
	var g := fish.shoals[0].members[1] as EcoFish.Fish
	_clear(w, [f, g])
	ok(_feed(w, hv, f, 10.0), "светляк у рта пойман")
	near(hv.digest, EcoHvaten.DIGEST, 0.06, "переваривает 35 с")
	eq(_notes(w, "hvaten", "catch").size(), 1, "«поймал светляка»")
	ok(_notes(w, "hvaten", "catch")[0].text().contains("поймал"), "текст поимки")
	w.run(1.0)
	ok(hv.open < 0.75, "переваривая, сжимает щупальца")
	ok(not _feed(w, hv, g, 2.5), "сытый не ловит")
	near(hv.open, EcoHvaten.DIGEST_OPEN, 1e-3, "раскрыт наполовину")
	eq(_notes(w, "pestr", "leftovers").size(), 1, "через 3 с пестрянки доедают остатки")
	ok(hv.msg_cd > 80.0, "дальше — пауза текстов")


func test_no_catch_in_beam() -> void:
	var w := _world()
	var hv := _system(w).anemones[0]
	var f := (w.systems[0] as EcoFish).shoals[0].members[0] as EcoFish.Fish
	_clear(w, [f])
	_aim(w, hv.top)
	ok(not _feed(w, hv, f, 5.0), "в луче щупальца спрятаны — не ловит")
	eq(_notes(w, "hvaten", "catch").size(), 0)


func test_far_fish_not_caught() -> void:
	var w := _world()
	var hv := _system(w).anemones[0]
	var f := (w.systems[0] as EcoFish).shoals[0].members[0] as EcoFish.Fish
	_clear(w, [f])
	for i in 100:
		f.agent.p = hv.mouth + Vector3(EcoHvaten.REACH + 0.2, 0, 0)
		w.step(EcoWorld.MAX_STEP)
	ok(f.agent.alive, "дальше 1,9 м от рта не достаёт")


# ---------- Пестрянки ----------

func test_pestr_lure_calm_shoal() -> void:
	var w := _world()
	var hv := _system(w).anemones[0]
	var sh := (w.systems[0] as EcoFish).shoals[0]
	hv.lure_cd = 0.0
	w.step(EcoWorld.MAX_STEP)
	ok(hv.lure == sh, "ведут ближайшую стаю")
	eq(_notes(w, "pestr", "lure").size(), 1, "«выманивает светляков»")
	ok(_notes(w, "pestr", "lure")[0].text().contains("щупальцам"), "текст подманивания")
	ok(hv.lure_cd >= EcoHvaten.LURE_CD_MIN and hv.lure_cd <= EcoHvaten.LURE_CD_MAX, "снова через 25–45 с")
	w.run(1.0)
	ok(sh.goal.is_equal_approx(hv.top + Vector3(0, EcoHvaten.LURE_UP, 0)), "цель стаи — над щупальцами")
	ok(hv.pc.distance_to(hv.top) > 1.0, "пестрянки выплыли к стае")
	sh.alarm = 2.0
	w.step(EcoWorld.MAX_STEP)
	ok(hv.lure == null, "встревоженную стаю отпускают")


func test_lure_ends_after_14_s() -> void:
	var w := _world()
	var hv := _system(w).anemones[0]
	hv.lure_cd = 0.0
	w.step(EcoWorld.MAX_STEP)
	var fish := w.systems[0] as EcoFish
	ok(hv.lure != null)
	_clear(w, [])  # никого не поймать — дождаться конца подманивания
	fish.shoals[0].alarm = 0.0
	w.run(EcoHvaten.LURE_T + 0.2)
	ok(hv.lure == null, "через 14 с пестрянки возвращаются")
	w.run(2.0)
	ok(hv.pc.distance_to(hv.top) < 1.5, "снова среди щупалец")


func test_no_lure_when_lit_or_alarmed() -> void:
	var w := _world()
	var hv := _system(w).anemones[0]
	var fish := w.systems[0] as EcoFish
	for sh in fish.shoals:
		sh.alarm = 5.0
	hv.lure_cd = 0.0
	w.step(EcoWorld.MAX_STEP)
	ok(hv.lure == null, "встревоженную стаю не зовут")
	eq(_notes(w, "pestr", "lure").size(), 0)


func test_lure_without_text_while_story_lasts() -> void:
	var w := _world()
	var hv := _system(w).anemones[0]
	hv.msg_cd = 50.0
	hv.lure_cd = 0.0
	w.step(EcoWorld.MAX_STEP)
	var lure := _notes(w, "pestr", "lure")
	eq(lure.size(), 1, "наблюдение есть")
	eq(lure[0].text(), "", "но без текста — у хватня ещё идёт прошлая история")


func test_targets() -> void:
	var w := _world()
	var hv := _system(w).anemones[0]
	var t := w.scan_targets()
	var kinds: Array[String] = []
	for d in t:
		kinds.append(d["species"])
	ok("hvaten" in kinds and "pestr" in kinds, "хватень и пестрянки — цели сонара и сканера")
	for d in t:
		if d["species"] == "hvaten":
			ok((d["pos"] as Vector3).is_equal_approx(hv.top), "хватень — по макушке")
			near(d["r"], 1.2, 1e-6)


# ---------- Сцена ----------

func test_view_three_multimeshes() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var hv := view.hvaten_view
	ok(hv != null and hv.get_parent() == view, "хватни — в живом мире")
	ok(view.hvaten.fish == view.fish, "знают светляков")
	for mi in [hv.bodies, hv.tents, hv.pestr]:
		eq(mi.layers, OceanView.LAYER_WORLD, "слой отмели")
	eq(hv.bodies.multimesh.instance_count, 4, "тела одним MultiMesh")
	eq(hv.tents.multimesh.instance_count, 4 * EcoHvaten.TENT, "щупальца одним MultiMesh")
	eq(hv.pestr.multimesh.instance_count, 4 * EcoHvaten.PESTR_N, "пестрянки одним MultiMesh")
	var a := view.hvaten.anemones[2]
	var tr := HvatenView.transform_at(hv.tent_buffer, 2 * EcoHvaten.TENT + 3)
	near(tr.origin.distance_to(a.top), EcoHvaten.TENT_R * EcoHvaten.breath(a, view.world.time), 1e-4,
		"щупальце растёт из диска")
	var tip := tr * Vector3(0, 1, 0)
	ok(Vector2(tip.x - a.top.x, tip.z - a.top.z).length() > Vector2(tr.origin.x - a.top.x, tr.origin.z - a.top.z).length(),
		"раскрытое щупальце клонится наружу")
	ok(tip.y > a.top.y + 0.3, "и вверх")
	a.open = 0.0
	hv.sync(view.world.time)
	var closed := HvatenView.transform_at(hv.tent_buffer, 2 * EcoHvaten.TENT + 3)
	ok((closed * Vector3(0, 1, 0)).distance_to(closed.origin) < 0.2, "спрятанное — короткое")
	var pe := HvatenView.transform_at(hv.pestr_buffer, 2 * EcoHvaten.PESTR_N, HvatenView.STRIDE_P)
	ok(pe.origin.is_equal_approx(a.pestr[0].p), "пестрянка на месте")
	near(hv.pestr_buffer[2 * EcoHvaten.PESTR_N * HvatenView.STRIDE_P + 16], HvatenView.PESTR_COLORS[0].r * EcoPestrLook.GLOW,
		1e-4, "оранжевая — свечение в INSTANCE_CUSTOM")
	view.queue_free()
	await frames(1)


# ---------- Дыхание тела (план реализма Б3) ----------

func test_body_breathes_slowly() -> void:
	var w := _world()
	var hv := _system(w).anemones[0]
	var lo := 9.0
	var hi := 0.0
	for i in 110:
		var b := EcoHvaten.breath(hv, i * 0.05)
		lo = minf(lo, b)
		hi = maxf(hi, b)
	ok(hi - lo > EcoHvaten.BREATH_AMP * 1.5, "за период тело раздувается и опадает")
	ok(lo >= 1.0 - EcoHvaten.BREATH_AMP - 1e-4 and hi <= 1.0 + EcoHvaten.BREATH_AMP + 1e-4, "не больше ±5 %")
	near(EcoHvaten.breath(hv, 1.0), EcoHvaten.breath(hv, 1.0 + EcoHvaten.BREATH_T), 1e-4, "период 5,5 с")
	ok(absf(EcoHvaten.breath(hv, 1.0) - EcoHvaten.breath(hv, 1.1)) < 0.01, "медленно — без дрожи")
	hv.open = 0.0
	ok(EcoHvaten.breath(hv, 1.0) < 1.0 - EcoHvaten.BREATH_AMP, "спрятавший щупальца сжимается")
	near(EcoHvaten.breath(hv, 1.0, false), EcoHvaten.CLOSED_W, 1e-5, "без дыхания — только сжатие")


func test_anemones_breathe_apart() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var a := view.hvaten.anemones
	ok(a.size() >= 2, "хватней несколько")
	var t := 3.0
	for hv in a:
		hv.open = 1.0
	ok(absf(EcoHvaten.breath(a[0], t) - EcoHvaten.breath(a[1], t)) > 0.005, "соседи дышат вразнобой")
	view.queue_free()
	await frames(1)


func test_body_and_tentacles_breathe_in_view() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var hv := view.hvaten_view
	var a := view.hvaten.anemones[1]
	a.open = 1.0
	var widths: Array[float] = []
	for i in 8:
		var t := EcoHvaten.BREATH_T * i / 8.0
		hv.sync(t)
		var body := HvatenView.transform_at(hv.body_buffer, 1)
		ok(body.origin.is_equal_approx(a.base), "тело стоит у подножия")
		near(body.basis.y.length(), 1.0, 1e-5, "высота не меняется — диск на месте")
		near(body.basis.x.length(), EcoHvaten.breath(a, t), 1e-5, "ширина тела — дыхание")
		widths.append(body.basis.x.length())
		var tent := HvatenView.transform_at(hv.tent_buffer, EcoHvaten.TENT + 5)
		var r := Vector2(tent.origin.x - a.top.x, tent.origin.z - a.top.z).length()
		near(r, EcoHvaten.TENT_R * widths[-1], 1e-4, "щупальца сидят на дышащем диске")
		ok(r < 0.4 * widths[-1], "не мимо края диска")
	ok(widths.max() - widths.min() > EcoHvaten.BREATH_AMP, "в сцене тело дышит")
	EcoShaders.set_sway_lite(true)
	hv.sync(EcoHvaten.BREATH_T * 0.25)
	var w1 := HvatenView.transform_at(hv.body_buffer, 1).basis.x.length()
	hv.sync(EcoHvaten.BREATH_T * 0.75)
	near(HvatenView.transform_at(hv.body_buffer, 1).basis.x.length(), w1, 1e-5, "на «Экономно» тело не дышит")
	EcoShaders.set_sway_lite(false)
	view.queue_free()
	await frames(1)


# ---------- Плавники пестрянок (план реализма Б3) ----------

## Форма пестрянки: тело закрыто и смотрит наружу, хвост-веер позади кормы, грудные плавники по бокам гребут.
func test_pestr_shape_has_fins() -> void:
	var L := EcoPestrLook
	eq(L.shape.size(), L.normals.size(), "нормаль у каждой вершины")
	eq(L.shape.size(), L.colors.size(), "цвет у каждой вершины")
	eq(L.tris.size() % 3, 0, "треугольники")
	near(L.shape[L.nose_vertex].z, L.NOSE, 1e-6, "нос по +Z")
	var body_tris := 2 * L.SEGMENTS * L.RINGS
	var mid := (L.NOSE + L.BACK) * 0.5
	for t in body_tris:
		var a := L.shape[L.tris[t * 3]]
		var b := L.shape[L.tris[t * 3 + 1]]
		var c := L.shape[L.tris[t * 3 + 2]]
		var m := (a + b + c) / 3.0
		ok((b - a).cross(c - a).dot(Vector3(m.x, m.y, m.z - mid)) < 0.0, "грань тела %d — лицом наружу" % t)
	eq(L.tail_tips.size(), 2, "две лопасти хвоста")
	for i in L.tail_tips:
		ok(L.shape[i].z < L.BACK - 0.1, "хвост за кормой")
		eq(L.colors[i].b, 0.0, "хвост не гребёт — машет волной")
	eq(L.pec_tips.size(), 2, "два грудных плавника")
	ok(L.shape[L.pec_tips[0]].x > L.HALF_WIDTH and L.shape[L.pec_tips[1]].x < -L.HALF_WIDTH, "по бокам")
	for i in L.pec_tips:
		eq(L.colors[i].b, 1.0, "кончик грудного гребёт целиком")
	for i in L.shape.size():
		var tip := false
		for j in L.pec_tips:
			tip = tip or L.shape[i].is_equal_approx(L.shape[j])
		if not tip:
			eq(L.colors[i].b, 0.0, "остальное не гребёт (вершина %d)" % i)


## Плавники живые: хвост ходит вбок, грудные — вверх-вниз вразнобой, нос стоит; «Экономно» — всё стоит.
func test_pestr_fins_beat() -> void:
	var L := EcoPestrLook
	var a := 0.37
	var tail := 0.0
	var nose := 0.0
	var pec := 0.0
	var differ := 0.0
	for k in 240:
		var t := k * 0.011
		tail = maxf(tail, absf(L.offset(L.tail_tips[0], t, a).x))
		nose = maxf(nose, L.offset(L.nose_vertex, t, a).length())
		var r := L.offset(L.pec_tips[0], t, a)
		var l := L.offset(L.pec_tips[1], t, a)
		pec = maxf(pec, absf(r.y))
		differ = maxf(differ, absf(r.y - l.y))
	eq(nose, 0.0, "нос стоит")
	ok(tail > 0.6 * EcoFishLook.TAIL_AMP, "хвост машет: %.3f" % tail)
	ok(pec > 0.9 * EcoFishLook.PEC_AMP and pec <= EcoFishLook.PEC_AMP + 1e-6, "грудной гребёт на ±PEC_AMP")
	ok(differ > 0.5 * EcoFishLook.PEC_AMP, "правый и левый — вразнобой")
	eq(L.offset(L.pec_tips[0], 0.4, a, 0.0), Vector3.ZERO, "«Экономно» — грудной стоит")
	eq(L.offset(L.tail_tips[0], 0.4, a, 0.0), Vector3.ZERO, "«Экономно» — хвост стоит")
	eq(EcoFishLook.fin_flap(0.1, 0.0, 0.4, a), 0.0, "у светляка (вес 0) грудных взмахов нет")


## В сцене пестрянки — тот же шейдер, что светляки (шейдеров не прибавилось), фаза плавников у каждой своя.
func test_pestr_view_shares_fish_shader() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var hv := view.hvaten_view
	var mat := hv.pestr.multimesh.mesh.surface_get_material(0) as ShaderMaterial
	var fish := view.fish_view.multimesh.mesh.surface_get_material(0) as ShaderMaterial
	ok(mat != null and fish != null, "материалы на шейдере")
	eq(mat.shader, fish.shader, "пестрянки и светляки — один шейдер")
	ok(mat.shader.code.contains("COLOR.b") and mat.shader.code.contains("%.5f" % EcoFishLook.PEC_AMP),
		"взмах грудных в шейдере — числа из EcoFishLook")
	ok(hv.pestr.multimesh.use_custom_data, "свечение — в INSTANCE_CUSTOM")
	var phases := {}
	for i in hv.pestr.multimesh.instance_count:
		var a := hv.pestr_buffer[i * HvatenView.STRIDE_P + 15]
		ok(a >= 0.0 and a < 1.0, "фаза — доля оборота")
		phases[snappedf(a, 0.01)] = true
	ok(phases.size() > hv.pestr.multimesh.instance_count / 2, "пестрянки машут вразнобой")
	var tr := HvatenView.transform_at(hv.pestr_buffer, 0, HvatenView.STRIDE_P)
	near(tr.basis.z.length(), EcoPestrLook.SCALE, 1e-4, "форма уменьшена до пестрянки")
	EcoShaders.set_sway_lite(true)
	eq(mat.get_shader_parameter("sway_k"), 0.0, "«Экономно» гасит плавники")
	EcoShaders.set_sway_lite(false)
	eq(mat.get_shader_parameter("sway_k"), 1.0, "и возвращает")
	view.queue_free()
	await frames(1)


# ---------- Плавность (Б3) ----------

func test_pestr_turn_limited_and_holds_when_still() -> void:
	var f := Vector3(0, 0, -1)
	var back := EcoHvaten.turn(f, Vector3(0, 0, 1), 0.1)
	near(f.angle_to(back), EcoHvaten.LOOK_MAX * 0.1, 1e-3, "ровно назад — не быстрее LOOK_MAX")
	ok(absf(back.y) < 1e-4, "разворот по горизонтали")
	var want := Vector3(sin(PI / 6.0), 0, -cos(PI / 6.0))
	var side := EcoHvaten.turn(f, want, 0.05)
	near(f.angle_to(side), PI / 6.0 * EcoHvaten.LOOK_K * 0.05, 1e-3, "доля угла за шаг")
	ok(EcoHvaten.turn(f, Vector3.ZERO, 0.1).is_equal_approx(f), "стоит — держит курс")
	ok(EcoHvaten.turn(Vector3.ZERO, Vector3(2, 0, 0), 0.1).is_equal_approx(Vector3.RIGHT), "курс не задан — сразу по ходу")


func test_pestr_nose_does_not_snap_when_lure_starts() -> void:
	var w := _world()
	var hv := _system(w).anemones[0]
	w.run(3.0)
	var before: Array[Vector3] = []
	for pe in hv.pestr:
		before.append(EcoHvaten.pestr_pose(hv, hv.pestr.find(pe), w.time).basis.z)
	hv.lure_cd = 0.0
	w.step(EcoWorld.MAX_STEP)   # хватень подманил стаю — цель пестрянок прыгнула к ней
	for k in hv.pestr.size():
		var now := EcoHvaten.pestr_pose(hv, k, w.time).basis.z
		ok(before[k].angle_to(now) <= EcoHvaten.LOOK_MAX * EcoWorld.MAX_STEP + 0.25,
			"пестрянка %d: нос не щёлкнул (%.2f рад)" % [k, before[k].angle_to(now)])


func test_view_lite_draws_every_other_tentacle() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var hv := view.hvaten_view
	var n := view.hvaten.anemones.size()
	eq(hv.drawn(), n * EcoHvaten.TENT, "на «Обычно» — все щупальца")
	view.set_lite(true)
	ok(hv.lite, "хватни — на «Экономно»")
	eq(hv.drawn(), n * EcoHvaten.TENT / 2, "каждое второе щупальце")
	eq(hv.bodies.multimesh.visible_instance_count, -1, "тела — все")
	eq(hv.pestr.multimesh.visible_instance_count, -1, "пестрянки — все")
	var seen := {}
	for i in n:
		for k in EcoHvaten.TENT:
			var s := HvatenView.tent_slot(i, k, n, true)
			seen[s] = true
			eq(s < hv.drawn(), HvatenView.lite_shown(k), "видно только показанное (%d, %d)" % [i, k])
	eq(seen.size(), n * EcoHvaten.TENT, "места в буфере не повторяются")
	var a := view.hvaten.anemones[2]
	hv.sync(view.world.time)
	var tr := HvatenView.transform_at(hv.tent_buffer, HvatenView.tent_slot(2, 4, n, true))
	ok(tr.is_equal_approx(EcoHvaten.tentacle(a, 4, view.world.time, not EcoShaders.sway_lite)),
		"видимое щупальце — на своём месте буфера")
	view.ground = Seabed.height   # сброс мира — виды пересобираются
	ok(view.hvaten_view.lite and view.hvaten_view.drawn() < n * EcoHvaten.TENT, "сброс мира — снова «Экономно»")
	view.set_lite(false)
	hv = view.hvaten_view
	eq(hv.drawn(), n * EcoHvaten.TENT, "назад — все")
	a = view.hvaten.anemones[2]
	var back := HvatenView.transform_at(hv.tent_buffer, 2 * EcoHvaten.TENT + 3)
	ok(back.is_equal_approx(EcoHvaten.tentacle(a, 3, hv._t, not EcoShaders.sway_lite)), "буфер снова по номеру")
	view.queue_free()
	await frames(1)
