extends TestCase
## Гротовик (initGrot/grotUpdate/grotShelter в js/creatures.js): бредёт по кругу из четырёх точек, в рифе на спине
## живёт шестая стая светляков и прячется от серпохвоста; задетый кораблём прячет ноги и замирает; цель сонара;
## в сцене — четыре вызова отрисовки.

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


func _world() -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var f := w.add(EcoFish.new()) as EcoFish
	var p := w.add(EcoPred.new(f)) as EcoPred
	var g := w.add(EcoGrot.new(f)) as EcoGrot
	p.grot = g
	return w


## Гротовик один, без стай и хищников: его ход от них не зависит (стая на спине только берёт дом), а шаг мира
## со стаями в долгих тестах хода — главная цена файла (12 тыс. шагов — ~12 с).
func _lone(ground: Callable = _flat) -> EcoWorld:
	var w := EcoWorld.new()
	w.ground = ground
	w.ship.pos = FAR
	w.add(EcoGrot.new())
	return w


func _sys(w: EcoWorld, cls: Variant) -> Variant:
	for s in w.systems:
		if is_instance_of(s, cls):
			return s
	return null


# ---------- Ход ----------

func test_starts_on_route_on_floor() -> void:
	var w := _world()
	var g: EcoGrot = _sys(w, EcoGrot)
	var gr := g.grot
	near(gr.p.x, EcoGrot.ROUTE[0].x, 1e-4, "первая точка круга")
	near(gr.p.z, EcoGrot.ROUTE[0].y, 1e-4)
	eq(gr.wp, 1, "идёт ко второй точке")
	near(gr.p.y, FLAT, 1e-4, "на дне")
	near(gr.body_y, FLAT + 0.6 + 0.55, 1e-4, "тело на ногах")
	near(gr.back.y, gr.body_y + 1.6, 1e-4, "спина над телом")
	near(gr.top, gr.body_y + 3.5, 1e-4, "верх рифа")


func test_walks_route_in_order_slowly() -> void:
	var w := _lone()
	var gr := (_sys(w, EcoGrot) as EcoGrot).grot
	var seen: Array[int] = []
	var last := Vector2(gr.p.x, gr.p.z)
	for i in 1200:  # 600 с
		w.run(0.5)
		var now := Vector2(gr.p.x, gr.p.z)
		ok(now.distance_to(last) <= EcoGrot.SPEED * 0.5 + 1e-3, "не быстрее 0,45 м/с")
		last = now
		if seen.is_empty() or seen[-1] != gr.wp:
			seen.append(gr.wp)
	ok(seen.size() >= 4, "прошёл несколько точек: %s" % [seen])
	for k in range(1, seen.size()):
		eq(seen[k], (seen[k - 1] + 1) % EcoGrot.ROUTE.size(), "точки по порядку")


## Б3 «Плавность поведения»: цель позади — сперва доворачивает почти на месте, а не уходит дугой на полном шаге.
func test_turns_nearly_in_place() -> void:
	var w := _world()
	var gr := (_sys(w, EcoGrot) as EcoGrot).grot
	var tg := EcoGrot.ROUTE[gr.wp]
	gr.yaw = atan2(tg.x - gr.p.x, tg.y - gr.p.z) + PI   # спиной к точке пути
	var at := Vector2(gr.p.x, gr.p.z)
	for i in 20:
		w.step(0.05)
	ok(Vector2(gr.p.x, gr.p.z).distance_to(at) < EcoGrot.SPEED * 0.5,
		"за секунду разворота прошёл меньше 0,23 м: %.2f" % Vector2(gr.p.x, gr.p.z).distance_to(at))
	ok(gr.stride <= EcoGrot.TURN_STRIDE + 0.05, "шаг мелкий: %.2f" % gr.stride)
	near(EcoGrot.want_stride(0.0, 1.0), 1.0, 1e-6, "прямо — полный шаг")
	near(EcoGrot.want_stride(PI, 1.0), EcoGrot.TURN_STRIDE, 1e-6, "позади — почти на месте")
	near(EcoGrot.want_stride(0.0, 0.5), 0.5, 1e-6, "ноги наполовину — полшага")


## Б3: после испуга трогается плавно — шаг растёт не быстрее ACCEL, ноги качаются в меру шага.
func test_starts_gradually_after_shy() -> void:
	var w := _world()
	var g: EcoGrot = _sys(w, EcoGrot)
	var gr := g.grot
	w.run(20.0)   # вышел на прямую к точке
	w.ship.pos = Vector3(gr.p.x + 8.0, gr.back.y, gr.p.z)
	w.step(0.05)
	ok(not gr.moving(), "испугался")
	eq(gr.stride, 0.0, "встал сразу")
	w.ship.pos = FAR
	w.run(10.0)
	ok(gr.moving(), "снова идёт")
	var last := gr.stride
	var at := Vector2(gr.p.x, gr.p.z)
	for i in 20:
		w.step(0.05)
		ok(gr.stride - last <= EcoGrot.ACCEL * 0.05 + 1e-5, "шаг растёт плавно")
		last = gr.stride
	ok(Vector2(gr.p.x, gr.p.z).distance_to(at) < EcoGrot.SPEED * 0.6, "первую секунду — не на полном ходу: %.2f"
		% Vector2(gr.p.x, gr.p.z).distance_to(at))
	w.run(6.0)
	ok(gr.stride > 0.8, "разошёлся до полного шага: %.2f" % gr.stride)


func test_reset_returns_to_start() -> void:
	var w := _world()
	var g: EcoGrot = _sys(w, EcoGrot)
	w.run(60.0)
	ok(g.grot.p.distance_to(Vector3(EcoGrot.ROUTE[0].x, FLAT, EcoGrot.ROUTE[0].y)) > 5.0, "ушёл")
	w.reset()
	near(g.grot.p.x, EcoGrot.ROUTE[0].x, 1e-4, "после сброса — на старте")
	eq(g.grot.wp, 1)
	ok(g.shoal.riding and g.shoal == (_sys(w, EcoFish) as EcoFish).shoals[EcoGrot.RIDERS], "стая снова на спине")


# ---------- Стая на спине ----------

func test_riders_live_on_back() -> void:
	var w := _world()
	var g: EcoGrot = _sys(w, EcoGrot)
	var f: EcoFish = _sys(w, EcoFish)
	var sh := f.shoals[EcoGrot.RIDERS]
	ok(g.shoal == sh and sh.riding, "шестая стая — на спине")
	near(sh.range_m, EcoGrot.RANGE, 1e-4, "блуждает в 4 м")
	near(sh.home.distance_to(g.grot.back + Vector3(0, 0.6, 0)), 0.0, 1e-4, "дом над спиной")
	for fi: EcoFish.Fish in sh.members:
		ok(fi.agent.p.distance_to(sh.home) < 6.0, "рыбка начинает у рифа")
	for k in f.shoals.size():
		if k != EcoGrot.RIDERS:
			ok(not f.shoals[k].riding, "другие стаи — не на спине")
	near(f.shoals[0].range_m, 14.0, 1e-4, "у других — прежний радиус")


func test_riders_travel_with_grot() -> void:
	var w := _world()
	var g: EcoGrot = _sys(w, EcoGrot)
	var sh := g.shoal
	var start := g.grot.back
	# 60 с хода + 20 с среднего: гротовик уже ~34 м от старта (0,45 м/с), стая за 60–80 с — в среднем 4,9 м от рифа
	# (за 100–120 с было 6,6 м) — запас тот же, а мира со стаями на треть меньше (#1350)
	w.run(60.0)
	# стая бродит у дома на спине (до ~10 м в отдельные мгновения) — среднее за 20 с, а не один снимок
	var d := 0.0
	for i in 40:
		w.run(0.5)
		d += sh.center.distance_to(g.grot.back) / 40.0
	ok(g.grot.back.distance_to(start) > 30.0, "гротовик ушёл: %.1f м" % g.grot.back.distance_to(start))
	near(sh.home.distance_to(g.grot.back + Vector3(0, 0.6, 0)), 0.0, 1e-4, "дом едет на спине")
	ok(d < 7.0, "стая рядом с рифом: в среднем %.1f м" % d)


func test_riders_skip_spores_ferns_and_rays() -> void:
	var w := EcoWorld.new()
	w.ground = _flat
	w.ship.pos = FAR
	var f := w.add(EcoFish.new()) as EcoFish
	var g := w.add(EcoGrot.new(f)) as EcoGrot
	var bl := w.add(EcoBladder.new(f)) as EcoBladder
	var fe := w.add(EcoFern.new(f)) as EcoFern
	var ry := w.add(EcoRay.new(f)) as EcoRay
	var sh := g.shoal
	sh.goal = sh.home
	var bush := EcoBladder.Bush.new()
	bush.cloud = sh.center + Vector3(2, 0, 0)
	bl._call_shoals(w, bush)
	ok(sh.goal != bush.cloud, "на споры не слетается")
	var fern: EcoFern.Fern = fe.ferns[0]
	fern.top = sh.center + Vector3(0, 0, 2)
	fe._call_shoals(w, fern)
	ok(sh.goal != fern.top, "к моллюскам не плывёт")
	var r: EcoRay.Ray = ry.rays[0]
	r.p = sh.center
	ry._lead(w, r)
	ok(sh.leader() == null, "ледокрыл её не уводит")


# ---------- Укрытие от серпохвоста ----------

func test_alarmed_rider_hidden_in_reef() -> void:
	var w := _world()
	var g: EcoGrot = _sys(w, EcoGrot)
	var fi: EcoFish.Fish = g.shoal.members[0]
	fi.agent.p = g.grot.back + Vector3(1, 0.5, 0)
	ok(g.shelter(fi) == null, "спокойная стая не прячется")
	g.shoal.alarm = 2.0
	ok(g.shelter(fi) == g.grot, "напуганная — в рифе")
	fi.agent.p = g.grot.back + Vector3(EcoGrot.HIDE_R + 0.5, 0, 0)
	ok(g.shelter(fi) == null, "дальше 5 м — не в рифе")
	var other: EcoFish.Fish = (_sys(w, EcoFish) as EcoFish).shoals[0].members[0]
	other.agent.p = g.grot.back
	ok(g.shelter(other) == null, "чужая стая в рифе не прячется")


func test_pred_loses_rider_in_reef() -> void:
	var w := _world()
	var g: EcoGrot = _sys(w, EcoGrot)
	var p: EcoPred = _sys(w, EcoPred)
	var f: EcoFish = _sys(w, EcoFish)
	var fi: EcoFish.Fish = g.shoal.members[0]
	fi.agent.p = g.grot.back
	g.shoal.alarm = 3.0
	var hidden := p._hidden_fish()
	ok(hidden.is_valid() and hidden.call(fi), "серпохвост не выбирает рыбку в рифе")
	ok(f.nearest_fish(g.grot.back, 3.0, hidden) == null or f.nearest_fish(g.grot.back, 3.0, hidden).shoal != g.shoal,
		"ближайшая — не из рифа")
	var pr: EcoPred.Pred = p.all[0]
	pr.agent.p = g.grot.back + Vector3(10, 0, 0)
	EcoPred._set_mode(pr, EcoPred.Mode.HUNT, 12.0)
	pr.prey = fi
	w.step(0.05)
	ok(pr.prey == null and pr.mode == EcoPred.Mode.PATROL, "потерял стаю — снова патруль")
	eq(_notes(w, "grot", "hide").size(), 1, "наблюдение «hide»")
	EcoPred._set_mode(pr, EcoPred.Mode.HUNT, 12.0)
	pr.prey = fi
	g.shoal.alarm = 3.0
	fi.agent.p = g.grot.back
	w.step(0.05)
	eq(_notes(w, "grot", "hide").size(), 1, "не чаще раза в 40 с")


func test_calm_world_no_hidden_filter_from_grot() -> void:
	var w := _world()
	var g: EcoGrot = _sys(w, EcoGrot)
	var p: EcoPred = _sys(w, EcoPred)
	g.shoal.alarm = 0.0
	ok(not p._hidden_fish().is_valid(), "спокойно — без лишнего фильтра")


# ---------- Корабль ----------

func test_ship_bump_makes_shy() -> void:
	var w := _world()
	var g: EcoGrot = _sys(w, EcoGrot)
	var gr := g.grot
	w.ship.pos = Vector3(gr.p.x + 8.0, gr.back.y, gr.p.z)
	w.step(0.05)
	eq(_notes(w, "grot", "shy").size(), 1, "задели — «shy»")
	ok(not gr.moving(), "замер")
	ok(g.shoal.alarm >= 2.9, "стая на спине испугалась")
	w.ship.pos = FAR
	var at := Vector2(gr.p.x, gr.p.z)
	w.run(5.0)
	near(Vector2(gr.p.x, gr.p.z).distance_to(at), 0.0, 1e-4, "стоит")
	ok(gr.lift < 0.1, "ноги спрятаны: %.2f" % gr.lift)
	near(gr.body_y, FLAT + 0.6 + 0.55 * gr.lift, 1e-4, "опустился на дно")
	w.run(6.0)
	ok(gr.moving(), "через 10 с снова идёт")
	w.run(3.0)
	ok(Vector2(gr.p.x, gr.p.z).distance_to(at) > 0.5, "пошёл дальше")


func test_shy_cooldown_and_ship_above() -> void:
	var w := _lone()
	var g: EcoGrot = _sys(w, EcoGrot)
	var gr := g.grot
	w.ship.pos = Vector3(gr.p.x, gr.top + 1.0, gr.p.z)
	w.run(2.0)
	eq(_notes(w, "grot", "shy").size(), 0, "над рифом — не задевает")
	w.ship.pos = Vector3(gr.p.x + 5.0, gr.body_y, gr.p.z)
	w.run(15.0)
	eq(_notes(w, "grot", "shy").size(), 1, "раз — и 25 с перезарядки")
	w.run(12.0)
	eq(_notes(w, "grot", "shy").size(), 2, "через 25 с — снова")


func test_drift_note_near_ship() -> void:
	var w := _lone()
	var g: EcoGrot = _sys(w, EcoGrot)
	w.run(2.0)
	eq(_notes(w, "grot", "drift").size(), 0, "далеко — без наблюдения")
	w.ship.pos = g.grot.back + Vector3(0, 10, 25)
	w.step(0.05)
	eq(_notes(w, "grot", "drift").size(), 1, "рядом — «drift»")
	w.run(30.0)
	eq(_notes(w, "grot", "drift").size(), 1, "не чаще раза в 90 с")


func test_solid_shell() -> void:
	var w := _world()
	var g: EcoGrot = _sys(w, EcoGrot)
	var gr := g.grot
	var base := Vector3(gr.p.x, gr.body_y, gr.p.z)
	ok(g.solid(base + Vector3(0, 0.5, 0)), "внутри панциря")
	ok(not g.solid(base + Vector3(0, 1.5, 0)), "над панцирем")
	ok(not g.solid(base + Vector3(3.0, 0.2, 0)), "сбоку за панцирем")
	ok(not g.solid(base + Vector3(0, -2.0, 0)), "под дном")
	var fwd := Basis(Vector3.UP, gr.yaw) * Vector3(0, 0.2, 3.5)
	ok(g.solid(base + fwd), "голова спереди по курсу")


# ---------- Наклон по склону (Б3) ----------

## Склон: дно поднимается к +X на SLOPE_K метров на метр.
const SLOPE_K := 0.3


static func _slope_x(x: float, _z: float) -> float:
	return FLAT + x * SLOPE_K


## Раньше панцирь стоял ровно: на склоне верхний край уходил в дно, нижний висел. Теперь нос и борта ложатся по дну.
func test_shell_lies_along_slope() -> void:
	var w := _lone(_slope_x)
	var gr := (_sys(w, EcoGrot) as EcoGrot).grot
	var want := atan(SLOPE_K)
	for i in 120:  # 60 с — курс меняется, наклон догоняет
		w.run(0.5)
	var b := gr.basis()
	var up := b * Vector3.UP
	near(up.x, -sin(want), 0.06, "ось тела наклонена от склона (вверх по +X — нормаль к −X)")
	near(up.dot(Vector3(-SLOPE_K, 1, 0).normalized()), 1.0, 0.01, "спина — по нормали к дну")
	var nose := b * Vector3.BACK
	near(nose.dot(Vector3(-SLOPE_K, 1, 0).normalized()), 0.0, 0.01, "нос идёт вдоль дна, не в него")
	var spine := gr.back - Vector3(gr.p.x, gr.body_y, gr.p.z)
	near(spine.normalized().dot(up), 1.0, 1e-4, "спина над телом по оси тела")


func test_tilt_flat_and_capped() -> void:
	var w := _world()
	var gr := (_sys(w, EcoGrot) as EcoGrot).grot
	w.run(0.5)
	near(gr.tilt.length(), 0.0, 1e-6, "ровное дно — ровно")
	var steep := func(x: float, _z: float) -> float: return FLAT + x * 3.0
	var t := EcoGrot.slope_tilt(steep, 0.0, 0.0, PI / 2.0)
	near(t.x, EcoGrot.TILT_MAX, 1e-6, "носом в крутой склон — не круче TILT_MAX")
	near(t.y, 0.0, 1e-4, "борта на одной высоте")
	t = EcoGrot.slope_tilt(steep, 0.0, 0.0, 0.0)
	near(t.y, EcoGrot.TILT_MAX, 1e-6, "левым бортом (+X) к склону — крен вверх, не круче TILT_MAX")
	near(t.x, 0.0, 1e-4)
	eq(EcoGrot.slope_tilt(Callable(), 0.0, 0.0, 0.0), Vector2.ZERO, "без дна — ровно")


## Дно под ступнями щупается не каждый кадр (шум дорог, #133): за 1 с хода на 0,45 м/с — несколько раз, не 60.
func test_tilt_feels_ground_rarely() -> void:
	var calls := [0]
	var counted := func(x: float, z: float) -> float:
		calls[0] += 1
		return FLAT + x * SLOPE_K
	var w := _lone(counted)
	for i in 120:
		w.run(0.5)  # разогнался, курс выровнялся
	calls[0] = 0
	for i in 60:
		w.run(1.0 / 60.0)
	ok(calls[0] < 60 + 4 * 5, "щупает редко: %d выборок за 60 кадров" % calls[0])


## Наклон догоняет плавно, а не щелчком: за шаг 0,1 с — не больше TILT_FOLLOW · dt разницы.
func test_tilt_follows_smoothly() -> void:
	var w := _world()
	var g: EcoGrot = _sys(w, EcoGrot)
	var gr := g.grot
	gr.shy = 100.0  # замер: дно не щупает, тянется к заданному
	gr.tilt_want = Vector2(0.3, 0.0)
	var was := gr.tilt
	w.run(0.1)
	ok(gr.tilt.x > was.x, "тянется к склону")
	ok(gr.tilt.x <= 0.3 * EcoGrot.TILT_FOLLOW * 0.1 + 1e-4, "не щелчком: %.3f" % gr.tilt.x)


## Панцирь для столкновения наклонён вместе с телом.
func test_solid_follows_tilt() -> void:
	var w := _world()
	var g: EcoGrot = _sys(w, EcoGrot)
	var gr := g.grot
	var base := Vector3(gr.p.x, gr.body_y, gr.p.z)
	var side := Basis(Vector3.UP, gr.yaw) * Vector3(2.0, 1.0, 0.0)
	ok(not g.solid(base + side), "ровный панцирь: точка над бортом снаружи")
	gr.tilt = Vector2(0.0, 0.3)
	ok(g.solid(base + side), "левый борт поднят — та же точка внутри")


func test_scan_target_and_texts() -> void:
	var w := _world()
	var g: EcoGrot = _sys(w, EcoGrot)
	var found := false
	for t in w.scan_targets():
		if t["species"] == "grot":
			found = true
			near((t["pos"] as Vector3).distance_to(g.grot.back), 0.0, 1e-4, "отметка на спине")
			near(float(t["r"]), 3.0, 1e-4, "размер 3 м")
	ok(found, "цель сонара")
	g.hid_fish(w)
	var ev := _notes(w, "grot", "hide")
	ok(ev[0].text().contains("рифе") and ev[0].text().contains("ходячего рифа"), ev[0].text())
	ok(Species.is_observation("grot", "shy") and Species.is_observation("grot", "drift"), "заметки вида")


# ---------- Сцена ----------

func test_view_four_draw_calls() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var gv := view.grot_view
	ok(gv != null and gv.get_parent() == view, "гротовик — в живом мире")
	ok(view.preds.grot == view.grot, "серпохвосты знают о гротовике")
	ok(view.grot.shoal == view.fish.shoals[EcoGrot.RIDERS], "стая на спине")
	var gr := view.grot.grot
	var ship := EcoLink.ShipState.new()
	ship.pos = gr.back + Vector3(0, 5, 30)
	view.step(0.05, ship)
	ok(gv.visible, "рядом — виден")
	near(gv.group.position.distance_to(Vector3(gr.p.x, gr.body_y, gr.p.z)), 0.0, 1e-4, "узел на теле")
	near(gv.legs.scale.y, 0.35 + 0.65 * gr.lift, 1e-4, "ноги по lift")
	var b := GrotView.breath(gr.lift, view.world.time)
	for mi in [gv.body, gv.reef, gv.glow]:
		near((mi as Node3D).scale.distance_to(b), 0.0, 1e-5, "дышит по времени мира: %s" % mi.name)
	var calls := 0
	var tris := 0
	for c in gv.group.get_children():
		var mi := c as MeshInstance3D
		eq(mi.layers, OceanView.LAYER_WORLD, "слой отмели: %s" % c.name)
		calls += 1
		tris += mi.mesh.surface_get_array_len(0) / 3
	eq(calls, 4, "четыре вызова отрисовки")
	ok(tris < 2500, "треугольников: %d" % tris)
	var far_ship := EcoLink.ShipState.new()
	far_ship.pos = Vector3(-300, -20, -300)
	view.step(0.05, far_ship)
	ok(not gv.visible, "далеко — спрятан")
	view.queue_free()
	await frames(1)


func test_shell_breathes_held_when_hidden() -> void:
	var top := 0.0
	var low := 9.0
	var held := 0.0
	var t := 0.0
	while t < GrotView.BREATH_T:
		var s := GrotView.breath(1.0, t)
		top = maxf(top, s.y)
		low = minf(low, s.y)
		held = maxf(held, GrotView.breath(0.0, t).y)
		eq(s.z, 1.0, "длина не меняется — голова на месте")
		ok(s.x > 1.0 == (s.y > 1.0) or is_equal_approx(s.y, 1.0), "вдох — выше и шире разом")
		t += 0.05
	near(top, 1.0 + GrotView.BREATH_H, 1e-3, "вдох — выше на BREATH_H")
	near(low, 1.0 - GrotView.BREATH_H, 1e-3, "выдох — ниже на BREATH_H")
	near(held - 1.0, GrotView.BREATH_H * GrotView.HELD, 1e-3, "ноги спрятаны — затаил дыхание")
	var step := 0.0
	for i in 200:
		var a := GrotView.breath(1.0 - i / 200.0, i * 0.05)
		var c := GrotView.breath(1.0 - (i + 1) / 200.0, (i + 1) * 0.05)
		step = maxf(step, absf(c.y - a.y))
	ok(step < 0.004, "размах меняется плавно: %.4f за кадр" % step)


func _grot_tris(gv: GrotView) -> Dictionary:
	var out := {}
	for c in gv.group.get_children():
		var mi := c as MeshInstance3D
		out[String(c.name)] = mi.mesh.surface_get_array_len(0) / 3
	return out


func test_view_lite_coarser_shell_reef_and_glow() -> void:
	var w := _world()
	var g: EcoGrot = _sys(w, EcoGrot)
	var gv := GrotView.new(g)
	tree.root.add_child(gv)
	await frames(1)
	var full := _grot_tris(gv)
	var mats := {}
	for c in gv.group.get_children():
		mats[String(c.name)] = (c as MeshInstance3D).mesh.surface_get_material(0)
	gv.set_lite(true)
	ok(gv.lite, "гротовик — на «Экономно»")
	var lite := _grot_tris(gv)
	var sum_full := 0
	var sum_lite := 0
	for k in full:
		sum_full += full[k]
		sum_lite += lite[k]
	ok(sum_lite * 2 <= sum_full, "треугольников не больше половины (%d → %d)" % [sum_full, sum_lite])
	for k in ["Панцирь", "Риф", "Огоньки"]:
		ok(lite[k] < full[k], "%s грубее (%d → %d)" % [k, full[k], lite[k]])
	eq(lite["Ноги"], full["Ноги"], "ноги те же")
	eq(gv.group.get_child_count(), 4, "вызовов столько же")
	for c in gv.group.get_children():
		ok((c as MeshInstance3D).mesh.surface_get_material(0) == mats[String(c.name)], "материал тот же: %s" % c.name)
	# силуэт тот же: высота купола и размах обода не меняются
	var a_full := GrotView.build_body(false).get_aabb()
	var a_lite := GrotView.build_body(true).get_aabb()
	near(a_lite.size.y, a_full.size.y, 0.05, "высота панциря та же")
	near(a_lite.size.x, a_full.size.x, 0.05, "ширина та же")
	gv.set_lite(false)
	eq(_grot_tris(gv), full, "назад — прежняя сетка")
	gv.queue_free()
	await frames(1)
	var view := EcoView.new()
	tree.root.add_child(view)
	view.ground = Seabed.height
	view.set_lite(true)
	ok(view.grot_view.lite, "EcoView.set_lite — до гротовика")
	view.ground = Seabed.height   # сброс мира — вид тот же
	ok(view.grot_view.lite, "сброс мира — снова «Экономно»")
	view.set_lite(false)   # общие выключатели мира (EcoShaders, EcoRim…) — назад для следующих тестов
	view.queue_free()
	await frames(1)


func _pose(t: float, k: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(12)
	for i in 6:
		var s := GrotView.leg_step(i, t, k)
		a[i * 2] = -s.x * GrotView.LEG_SWING
		a[i * 2 + 1] = s.y * GrotView.LEG_LIFT
	return a


func test_legs_step_in_tripods_without_slip() -> void:
	# треноги: 0, 2, 4 (левые передняя и задняя, правая средняя) против 1, 3, 5
	for t in [0.3, 1.1, 2.7]:
		var a := GrotView.leg_step(0, t, 1.0)
		for i in [2, 4]:
			near(GrotView.leg_step(i, t, 1.0).distance_to(a), 0.0, 1e-6, "нога %d — в треноге с 0" % i)
		for i in [1, 3, 5]:
			near(GrotView.leg_step(i, t, 1.0).x, -a.x, 1e-6, "нога %d — в противофазе" % i)
	eq(GrotView.leg_step(0, 0.0, 1.0).y, 1.0, "на выносе вперёд стопа поднята")
	for i in 6:
		eq(GrotView.leg_step(i, 1.3, 0.0), Vector2.ZERO, "стоит — ноги в покое")
	near(GrotView.leg_step(0, 0.5, 0.5).x, GrotView.leg_step(0, 0.5, 1.0).x * 0.5, 1e-6, "размах — по доле шага")
	# стопа на дне (без подъёма) уходит назад почти со скоростью хода
	var dt := 0.01
	var back := 0.0
	var span := 0.0
	var t := 0.0
	while t < TAU / GrotView.LEG_RATE:
		var p0 := GrotView.foot(0, _pose(t, 1.0))
		var p1 := GrotView.foot(0, _pose(t + dt, 1.0))
		if GrotView.leg_step(0, t, 1.0).y == 0.0 and GrotView.leg_step(0, t + dt, 1.0).y == 0.0:
			back += p1.z - p0.z
			span += dt
		else:
			ok(p1.z >= p0.z - 1e-6 or absf(p1.z - p0.z) < 1e-3, "поднятая стопа идёт вперёд")
		t += dt
	ok(span > 1.0, "полцикла на дне: %.2f с" % span)
	near(-back / span, EcoGrot.SPEED, EcoGrot.SPEED * 0.1, "стопа на дне — назад со скоростью хода")
	var f := GrotView.foot(1, _pose(0.0, 1.0))
	near(f.y, GrotView.LEG_Y - GrotView.LEG_LEN * cos(GrotView.LEG_TILT), 1e-4,
			"опорная стопа внизу")
	ok(GrotView.foot(0, _pose(0.0, 1.0)).y > f.y + GrotView.LEG_LIFT * 0.9, "вынесенная — поднята")


func test_view_legs_mesh_walks_and_rests() -> void:
	var w := _world()
	var g: EcoGrot = _sys(w, EcoGrot)
	var gv := GrotView.new(g)
	tree.root.add_child(gv)
	await frames(1)
	var gr := g.grot
	var ship := Vector3(gr.p.x, gr.body_y, gr.p.z) + Vector3(0, 5, 20)
	var rest := (gv.legs.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	gr.stride = 1.0
	gv.sync(PI * 0.5 / GrotView.LEG_RATE, ship)
	eq(gv.legs.rotation, Vector3.ZERO, "узел ног не качается целиком")
	var v := (gv.legs.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	eq(v.size(), rest.size(), "те же вершины")
	var leg: PackedInt32Array = gv._rest["leg"]
	var dz := [0.0, 0.0]
	for j in v.size():
		dz[(int(leg[j] / 3.0) + leg[j] % 3) % 2] += v[j].z - rest[j].z
	ok(dz[0] > 0.1 and dz[1] < -0.1, "треноги врозь: вперёд %.2f, назад %.2f" % dz)
	near(GrotView.foot(0, gv.leg_pose).z - GrotView.hip(0).z, GrotView.LEG_LEN * cos(GrotView.LEG_TILT)
			* sin(GrotView.LEG_SWING), 1e-3, "нога 0 вынесена вперёд")
	var writes := gv.leg_pose
	gr.stride = 0.0
	gv.sync(0.3, ship)
	for x in gv.leg_pose:
		eq(x, 0.0, "встал — ноги в покое")
	ok(gv.leg_pose != writes, "меш переписан в покой")
	var still := (gv.legs.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	near(still[5].distance_to(rest[5]), 0.0, 1e-5, "покой — как построен")
	gr.stride = 1.0
	gv.sync(0.6, ship + Vector3(0, 0, GrotView.LEG_FAR + 10))
	for x in gv.leg_pose:
		eq(x, 0.0, "далеко — ноги не шагают")
	gv.queue_free()
	await frames(1)


# ---------- Корабль не проходит сквозь панцирь и риф ----------

func _helm(w: EcoWorld) -> Helm.Ship:
	var s := Helm.Ship.new()
	s.ground = _flat
	s.solid = func(p: Vector3, yaw: float) -> bool: return EcoLink.solid(w.systems, p, yaw)
	return s


func test_ship_at_grot_touches_reef() -> void:
	var w := _world()
	var g: EcoGrot = _sys(w, EcoGrot)
	var gr := g.grot
	var low := FLAT + Helm.Ship.CLEARANCE
	ok(g.blocks(Vector3(gr.p.x, low, gr.p.z), 0.0), "корабль у дна над гротовиком задевает риф")
	ok(not g.blocks(Vector3(gr.p.x, gr.top + 12.0, gr.p.z), 0.0), "высоко над рифом — свободно")
	ok(not g.blocks(Vector3(gr.p.x + 60.0, low, gr.p.z), 0.0), "в 60 м — свободно")


func test_ship_cannot_pass_through_grot() -> void:
	var w := _world()
	var g: EcoGrot = _sys(w, EcoGrot)
	var gr := g.grot
	gr.shy = 1e9   # стоит на месте
	var s := _helm(w)
	s.pos = Vector3(gr.p.x, FLAT + Helm.Ship.CLEARANCE, gr.p.z + 45.0)
	s.yaw = 0.0   # нос к −Z — прямо на гротовика
	s.in_thrust = 1.0
	var dt := 1.0 / 60.0
	for i in int(20.0 / dt):
		s.update(dt)
		w.ship.pos = s.pos
		w.ship.yaw = s.yaw
		if g.blocks(s.pos, s.yaw):
			ok(false, "корабль вошёл в гротовика на %.1f с" % (i * dt))
			return
	ok(s.pos.z > gr.p.z, "не прошёл насквозь: z %.1f" % s.pos.z)


## Корабль задним ходом идёт мимо гротовика так, что корпус проходит рядом, а двигатель правого борта (кожух
## |x| до 6,7 м, кормовой переход там — 3,6 м) — сквозь панцирь. Твёрдое — корабль целиком (`EcoHull.touches_whole`),
## а не только основной объём: двигатель в панцирь не входит (по примеру арки 07, #1835).
func test_engine_does_not_pass_through_grot() -> void:
	var w := _world()
	var g: EcoGrot = _sys(w, EcoGrot)
	var gr := g.grot
	gr.shy = 1e9   # стоит на месте
	gr.yaw = 0.0
	g.place()
	var s := _helm(w)
	var engine := Vector3(HullPlan.ENGINE_X, HullPlan.ENGINE_Y, HullPlan.ENGINE_Z)
	var side := HullPlan.ENGINE_X + EcoGrot.SHELL.x   # край панциря — под осью двигателя, риф — в кожухе
	s.pos = Vector3(gr.p.x - side, maxf(gr.body_y + 0.5 - HullPlan.ENGINE_Y, FLAT + Helm.Ship.CLEARANCE),
			gr.p.z - engine.z - 40.0)
	s.yaw = 0.0   # нос к −Z, задним ходом — к +Z, на гротовика
	s.in_thrust = -1.0
	# на траверзе гротовика основной объём его не задевает — без выступов корабль прошёл бы
	var beside := Vector3(gr.p.x - side, s.pos.y, gr.p.z - engine.z)   # двигатель — на траверзе гротовика
	var main_hits := 0
	for q in EcoGrot.body_points():
		if EcoHull.touches(Vector3(gr.p.x, gr.body_y, gr.p.z) + gr.basis() * q, beside, 0.0, EcoGrot.HULL_PAD):
			main_hits += 1
	eq(main_hits, 0, "корпус без выступов проходит мимо")
	ok(g.blocks(beside, 0.0), "корабль целиком — задевает двигателем")
	var dt := 1.0 / 60.0
	for i in int(25.0 / dt):
		s.update(dt)
		w.ship.pos = s.pos
		w.ship.yaw = s.yaw
		var hit := _in_engine(gr, s, engine)
		if hit >= 0.0:
			ok(false, "панцирь или риф в кожухе двигателя на %.1f с (%.2f м от оси), корабль z %.1f" % [i * dt, hit, s.pos.z])
			return
	print("  двигатель встал у панциря: корабль z %.1f, гротовик z %.1f, сдвиг вдоль борта %.1f м" % [s.pos.z, gr.p.z,
			s.pos.z + engine.z - gr.p.z])
	ok(s.pos.z + engine.z < gr.p.z, "двигатель не прошёл мимо центра гротовика")


## Ближайшая к оси кожуха двигателя (оси корабля) точка панциря или рифа gr внутри кожуха — расстояние до оси; нет — −1.
func _in_engine(gr: EcoGrot.Walker, s: Helm.Ship, engine: Vector3) -> float:
	var best := -1.0
	for q in EcoGrot.body_points():
		var l := EcoHull.to_ship(Vector3(gr.p.x, gr.body_y, gr.p.z) + gr.basis() * q, s.pos, s.yaw)
		var r := Vector2(l.x - engine.x, l.y - engine.y).length()
		if r <= HullPlan.SHROUD_D / 2.0 and absf(l.z - engine.z) <= HullPlan.SHROUD_L / 2.0 and (best < 0.0 or r < best):
			best = r
	return best


func test_grot_does_not_walk_into_ship() -> void:
	var w := _lone()
	var g: EcoGrot = _sys(w, EcoGrot)
	var gr := g.grot
	# корабль стоит на пути ко второй точке круга, в 20 м впереди
	var to := (EcoGrot.ROUTE[1] - EcoGrot.ROUTE[0]).normalized()
	var at := EcoGrot.ROUTE[0] + to * 20.0
	w.ship.pos = Vector3(at.x, FLAT + Helm.Ship.CLEARANCE, at.y)
	w.ship.yaw = atan2(to.x, to.y)   # бортом к нему не важно — корпус длинный
	for i in 1200:   # 60 с
		w.step(0.05)
		if EcoGrot.touches_ship(gr, w.ship.pos, w.ship.yaw):
			ok(false, "гротовик вошёл в корабль на %.1f с" % (i * 0.05))
			return
	ok(Vector2(gr.p.x, gr.p.z).distance_to(EcoGrot.ROUTE[0]) > 2.0, "дошёл до корабля и встал")


## Круг на пробу (`EcoGrot.route`, инструменты расчёта #1400): гротовик стартует с его первой точки и идёт по его
## точкам; в игре `route` — прежний ROUTE.
func test_probe_route_followed() -> void:
	ok(EcoGrot.route == EcoGrot.ROUTE, "по умолчанию — круг игры")
	EcoGrot.route = [Vector2(43, 75), Vector2(55, 65), Vector2(55, 49), Vector2(43, 39)] as Array[Vector2]
	var w := _lone()
	var gr := (_sys(w, EcoGrot) as EcoGrot).grot
	var start := Vector2(gr.p.x, gr.p.z)
	var seen: Array[int] = []
	for i in 300:  # 150 с
		w.run(0.5)
		if seen.is_empty() or seen[-1] != gr.wp:
			seen.append(gr.wp)
	var at := Vector2(gr.p.x, gr.p.z)
	EcoGrot.route = EcoGrot.ROUTE
	near(start.distance_to(Vector2(43, 75)), 0.0, 1e-4, "старт — первая точка пробы")
	ok(seen.size() >= 3, "прошёл точки пробы: %s" % [seen])
	ok(at.x > 40.0 and at.x < 58.0 and at.y > 36.0 and at.y < 78.0, "ходит по кругу пробы: %s" % at)
