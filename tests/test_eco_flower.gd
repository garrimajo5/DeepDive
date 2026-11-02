extends TestCase
## Каменный цветок (место 1 карты отмели, концепт ART-027): место с карты, коралл 28 м стоит на дне, крона Ø 26 м
## не задевает логово стеклоуста и огнецвет, три ветви × четыре вилки = 48 кончиков, середина кроны выше краёв,
## кончики мерцают волной снизу вверх (6 с, 15…100 %), цоколь твёрдый, меш — один вызов отрисовки, грани наружу.
## Громкий импульс сонара рядом гасит огни, потом они возвращаются (#834).

const FLAT := -40.0
## Светящихся граней у кончика на «Экономно»: 4 грани × (2 острия + 2 между кольцами).
const LITE_TIP_TRIS := 16


static func _flat(_x: float, _z: float) -> float:
	return FLAT


func _flower(ground: Callable) -> EcoFlower:
	var w := EcoWorld.new()
	w.ground = ground
	return w.add(EcoFlower.new()) as EcoFlower


func test_place_from_map() -> void:
	var f := FileAccess.open("res://docs/concept-art/karta-otmeli-mesta.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var spot: Dictionary = {}
	for l in data["locations"]:
		if l["name"] == "Каменный цветок":
			spot = l
	near(EcoFlower.CENTER.x, float(spot["x"]), 1e-6, "x с карты отмели")
	near(EcoFlower.CENTER.y, float(spot["z"]), 1e-6, "z с карты отмели")
	eq(EcoFlower.ID, "flower", "ключ места как в Run.PLACES")
	eq(Run.PLACES[EcoFlower.ID][1], EcoFlower.CENTER, "точка маршрута — у цветка")


func test_giant_on_ground() -> void:
	var fl := _flower(Seabed.height)
	var y0 := Seabed.height(EcoFlower.CENTER.x, EcoFlower.CENTER.y)
	near(fl.base.y, y0, 1e-4, "подножие на дне")
	near(fl.top().y - y0, EcoFlower.HEIGHT, 1e-3, "высота 28 м — девятиэтажный дом")
	var trunk := fl.branches[0]
	eq(trunk.depth, 0, "первая ветвь — ствол")
	ok(trunk.p0.y < y0, "ствол уходит в дно")
	near(trunk.r0 * 2.0, 3.5, 1e-4, "ствол у дна Ø 3,5 м")
	ok(trunk.p1.y - y0 > 6.0 and trunk.p1.y - y0 < 11.5, "первая вилка на 7–11 м: %f" % (trunk.p1.y - y0))
	for b in fl.branches:
		ok(Vector2(b.p1.x - fl.base.x, b.p1.z - fl.base.z).length() <= EcoFlower.SPREAD + 1e-3, "крона не шире Ø 26 м")
		ok(b.p1.y > y0, "ветви над дном")
	for i in fl.tips.size():
		ok(Vector2(fl.tips[i].x - fl.base.x, fl.tips[i].z - fl.base.z).length() + fl.tip_r[i] <= EcoFlower.SPREAD + 1e-3,
			"кончик в кроне")
	var reach := 0.0
	for i in fl.tips.size():
		var e := fl.tip_end(i)
		reach = maxf(reach, Vector2(e.x - fl.base.x, e.z - fl.base.z).length())
	ok(reach > EcoFlower.SPREAD - 1.5, "крона раскрыта почти на Ø 26 м: радиус %f" % reach)
	# соседи: логово стеклоуста (#834 — у трещины 02↔01) и огнецвет (54,88; −68,69) — дальше кроны
	for xz in [EcoEel.LAIRS[0], EcoCoral.BASES[2]]:
		ok(Vector2(xz.x - fl.base.x, xz.y - fl.base.z).length() > EcoFlower.SPREAD + 6.0, "сосед %s не в кроне" % xz)


func test_branching_by_concept() -> void:
	var fl := _flower(_flat)
	var by_depth := [0, 0, 0, 0, 0, 0]
	for b in fl.branches:
		by_depth[b.depth] += 1
		ok(b.r1 < b.r0, "ветвь сужается")
	eq(by_depth, [1, 3, 6, 12, 24, 48], "ствол, три ветви, четыре вилки надвое")
	eq(fl.tips.size(), 48, "48 кончиков на концах последнего яруса")
	# чаша: внутренняя половина кончиков (ближе к оси) выше наружной
	var dist := []
	for i in fl.tips.size():
		dist.append(Vector2(fl.tips[i].x - fl.base.x, fl.tips[i].z - fl.base.z).length())
	var sorted := dist.duplicate()
	sorted.sort()
	var med: float = sorted[24]
	var inner := 0.0
	var outer := 0.0
	for i in fl.tips.size():
		if dist[i] < med:
			inner += fl.tips[i].y / 24.0
		else:
			outer += fl.tips[i].y / 24.0
	ok(inner > outer + 1.0, "середина кроны выше краёв: %f и %f" % [inner, outer])
	for i in fl.tips.size():
		ok(fl.tip_dir[i].y > 0.3, "кончик смотрит вверх")
	# форма своя — не зависит от зерна мира
	var w := EcoWorld.new(777)
	w.ground = _flat
	var other := w.add(EcoFlower.new()) as EcoFlower
	eq(other.tips, fl.tips, "форма одна при любом зерне мира")


func test_plinth() -> void:
	var fl := _flower(_flat)
	ok(fl.stones.size() >= 8 and fl.tubes.size() >= 8 and fl.tubes.size() <= 12, "цоколь: камни и 8–12 трубочек")
	for st in fl.stones:
		ok(Vector2(st.c.x - fl.base.x, st.c.z - fl.base.z).length() + st.r <= EcoFlower.PLINTH_R + 1e-3, "камень в цоколе Ø 8 м")
		ok(st.c.y < FLAT and st.c.y + st.h <= FLAT + EcoFlower.PLINTH_H + 1e-3, "камень на дне, не выше 1,5 м")
	var st0 := fl.stones[0]
	ok(fl.solid(st0.c + Vector3(0, st0.h - 0.2, 0)), "камень цоколя твёрдый")
	var t0 := fl.tubes[0]
	ok(fl.solid((t0.p0 + t0.p1) * 0.5), "трубочка твёрдая")


func test_solid_trunk_and_water_around() -> void:
	var fl := _flower(_flat)
	ok(fl.solid(fl.base + Vector3(0, 2, 0)), "ствол твёрдый")
	ok(fl.solid(fl.tips[0]), "кончик твёрдый")
	ok(not fl.solid(fl.base + Vector3(0, EcoFlower.HEIGHT + 3.0, 0)), "над цветком — вода")
	ok(not fl.solid(fl.base + Vector3(EcoFlower.SPREAD + 3.0, 10, 0)), "сбоку за кроной — вода")
	ok(not fl.solid(fl.base + Vector3(6, 0.5, 0)), "у подножия в 6 м — вода")


func test_tips_shimmer_wave() -> void:
	var fl := _flower(_flat)
	var lo := 1.0
	var hi := 0.0
	for k in 600:
		var g := EcoFlower.glow(fl.tip_phase[0], k * 0.01)
		lo = minf(lo, g)
		hi = maxf(hi, g)
	near(lo, 0.15, 0.01, "кончик не гаснет: минимум 15 %")
	near(hi, 1.0, 0.01, "максимум 100 %")
	near(EcoFlower.glow(0.7, 1.3), EcoFlower.glow(0.7, 7.3), 1e-5, "период 6 с")
	# волна вверх: верхний кончик загорается на 2 с позже нижнего
	var top_i := 0
	var low_i := 0
	for i in fl.tips.size():
		if fl.tips[i].y > fl.tips[top_i].y:
			top_i = i
		if fl.tips[i].y < fl.tips[low_i].y:
			low_i = i
	var lag := (fl.tip_phase[low_i] - fl.tip_phase[top_i]) / EcoFlower.GLOW_RATE
	near(lag, 2.0, 0.35, "волна снизу вверх за 2 с: %f" % lag)


func test_view_one_mesh_faces_out() -> void:
	var fl := _flower(_flat)
	var v := FlowerView.new(fl)
	tree.root.add_child(v)
	await frames(1)
	eq(v.mesh.get_surface_count(), 1, "один вызов отрисовки")
	ok(v.tris > 1000 and v.tris <= 8000, "треугольников в бюджете ART-027 (≤ 8 тыс.): %d" % v.tris)
	eq(v.layers, OceanView.LAYER_WORLD, "слой отмели")
	# грань смотрит наружу от оси своей ветви: проверим ствол выше цоколя и ниже начала ветвей
	var trunk_top := fl.branches[0].p1.y - 2.0
	var outward := 0
	var total := 0
	for i in range(0, v.verts.size(), 3):
		var c := (v.verts[i] + v.verts[i + 1] + v.verts[i + 2]) / 3.0
		if c.y < trunk_top and c.y > fl.base.y + 2.0 and Vector2(c.x - fl.base.x, c.z - fl.base.z).length() < 2.1:
			total += 1
			var cr := (v.verts[i + 1] - v.verts[i]).cross(v.verts[i + 2] - v.verts[i])
			var out := Vector3(c.x - fl.base.x, 0, c.z - fl.base.z)
			if cr.dot(out) < 0.0 and v.normals[i].dot(out) > 0.0:
				outward += 1
	ok(total > 0, "у ствола есть грани")
	eq(outward, total, "лицевая сторона ствола — снаружи (обход по часовой)")
	v.queue_free()
	await frames(1)


func test_in_eco_view() -> void:
	var ev := EcoView.new()
	ev.ground = _flat
	ok(ev.flower != null and ev.flower_view != null, "цветок в живом мире")
	near(ev.flower.base.y, FLAT, 1e-4, "встал на дно мира")
	ev.free()


func _ping_world() -> Array:
	var w := EcoWorld.new()
	w.ground = _flat
	var f := w.add(EcoFlower.new()) as EcoFlower
	w.reset()
	return [w, f]


func _ping(w: EcoWorld, pos: Vector3) -> void:
	w.ship.pos = pos
	w.ship.sonar_ping = true
	w.step(0.1)
	w.ship.sonar_ping = false


func _texts(w: EcoWorld) -> Array:
	var out := []
	for e in w.take_link():
		if e.get("type", "") == EcoLink.MESSAGE:
			out.append(e.get("text", ""))
	return out


func test_ping_dims_and_light_returns() -> void:
	var pair := _ping_world()
	var w: EcoWorld = pair[0]
	var f: EcoFlower = pair[1]
	near(f.light, 1.0, 1e-6, "до импульса горит")
	_ping(w, f.heart() + Vector3(35, 0, 0))
	ok(f.light <= EcoFlower.DARK_LIGHT + 1e-6, "импульс в 35 м гасит кончики")
	ok(EcoFlower.MSG_DARK in _texts(w), "на приборах — строка о погасшем цветке")
	for i in int(EcoFlower.DARK_HOLD / 0.5) - 1:
		w.step(0.5)
	ok(f.light <= EcoFlower.DARK_LIGHT + 1e-6, "темнота держится %s с" % EcoFlower.DARK_HOLD)
	w.step(1.0 + EcoFlower.RELIGHT_TIME * 0.5)
	ok(f.light > 0.3 and f.light < 0.9, "свет возвращается постепенно: %s" % f.light)
	w.step(EcoFlower.RELIGHT_TIME)
	near(f.light, 1.0, 1e-6, "через %s с цветок горит снова" % (EcoFlower.DARK_HOLD + EcoFlower.RELIGHT_TIME))


func test_far_ping_keeps_light() -> void:
	var pair := _ping_world()
	var w: EcoWorld = pair[0]
	var f: EcoFlower = pair[1]
	_ping(w, f.heart() + Vector3(0, 0, EcoFlower.PING_R + 5.0))
	near(f.light, 1.0, 1e-6, "импульс дальше %s м цветок не гасит" % EcoFlower.PING_R)
	ok(not (EcoFlower.MSG_DARK in _texts(w)), "и строки нет")


func test_dark_message_not_spammed() -> void:
	var pair := _ping_world()
	var w: EcoWorld = pair[0]
	var f: EcoFlower = pair[1]
	_ping(w, f.heart())
	_texts(w)
	w.step(EcoFlower.DARK_HOLD + EcoFlower.RELIGHT_TIME + 1.0)
	_ping(w, f.heart())
	ok(f.light <= EcoFlower.DARK_LIGHT + 1e-6, "второй импульс снова гасит")
	ok(not (EcoFlower.MSG_DARK in _texts(w)), "строка не чаще раза в %s с" % EcoFlower.MSG_CD)


func test_view_takes_light() -> void:
	var pair := _ping_world()
	var w: EcoWorld = pair[0]
	var f: EcoFlower = pair[1]
	var v := FlowerView.new(f)
	var mat := v.mesh.surface_get_material(0) as ShaderMaterial
	near(float(mat.get_shader_parameter("light")), 1.0, 1e-6, "сначала горит")
	ok(not v.sync(), "без перемен шейдеру не отдаёт")
	_ping(w, f.heart())
	ok(v.sync(), "после импульса отдаёт")
	ok(float(mat.get_shader_parameter("light")) > 0.4, "гаснет не за кадр")
	w.step(EcoFlower.DIM_TIME)
	ok(v.sync(), "и дальше отдаёт")
	near(float(mat.get_shader_parameter("light")), EcoFlower.DARK_LIGHT, 1e-6, "шейдер гасит кончики")
	v.free()


## Б3: импульс гасит кончики на виду за DIM_TIME с, а не за кадр (свет мира — сразу); разгораются вместе со светом.
func test_dims_smoothly() -> void:
	var pair := _ping_world()
	var w: EcoWorld = pair[0]
	var f: EcoFlower = pair[1]
	_ping(w, f.heart())   # шаг 0,1 с
	ok(f.light <= EcoFlower.DARK_LIGHT + 1e-6 and f.seen > 0.7, "свет мира погас сразу, на виду — ещё нет: %.3f" % f.seen)
	var was := f.seen
	var worst := 0.0
	for i in int(EcoFlower.DIM_TIME * 60.0) + 2:
		w.step(1.0 / 60.0)
		worst = maxf(worst, absf(f.seen - was))
		was = f.seen
	ok(worst <= 0.05, "за шаг 1/60 с — не больше 0,05: %.3f" % worst)
	near(f.seen, EcoFlower.DARK_LIGHT, 1e-6, "через DIM_TIME — погас")
	w.step(EcoFlower.DARK_HOLD + EcoFlower.RELIGHT_TIME * 0.5)
	near(f.seen, f.light, 1e-6, "разгорается вместе со светом")


func test_view_lite_coarser_mesh_same_material() -> void:
	var pair := _ping_world()
	var f: EcoFlower = pair[1]
	var v := FlowerView.new(f)
	tree.root.add_child(v)
	await frames(1)
	var full := v.tris
	var mat := v.mesh.surface_get_material(0)
	var box_full := v.mesh.get_aabb()
	v.set_lite(true)
	ok(v.lite, "цветок — на «Экономно»")
	ok(v.tris * 10 <= full * 7, "треугольников не больше 70 %% (%d → %d)" % [full, v.tris])
	eq(v.mesh.get_surface_count(), 1, "вызов тот же")
	ok(v.mesh.surface_get_material(0) == mat, "материал тот же — свет и мерцание не сбиваются")
	var box_lite := v.mesh.get_aabb()
	ok(box_lite.size.y > box_full.size.y * 0.95 and box_lite.size.x > box_full.size.x * 0.9,
		"силуэт тот же: %s → %s" % [box_full.size, box_lite.size])
	# кончики светятся по-прежнему: у каждого есть грани со свечением
	var glow := 0
	for i in range(0, v.verts.size(), 3):
		if v._col[i].a > 0.5:
			glow += 1
	eq(glow, f.tips.size() * LITE_TIP_TRIS, "у каждого кончика — светящиеся грани")
	# грани ствола смотрят наружу и на «Экономно»
	var trunk_top := f.branches[0].p1.y - 2.0
	var outward := 0
	var total := 0
	for i in range(0, v.verts.size(), 3):
		var c := (v.verts[i] + v.verts[i + 1] + v.verts[i + 2]) / 3.0
		if c.y < trunk_top and c.y > f.base.y + 2.0 and Vector2(c.x - f.base.x, c.z - f.base.z).length() < 2.1:
			total += 1
			var cr := (v.verts[i + 1] - v.verts[i]).cross(v.verts[i + 2] - v.verts[i])
			var out := Vector3(c.x - f.base.x, 0, c.z - f.base.z)
			if cr.dot(out) < 0.0 and v.normals[i].dot(out) > 0.0:
				outward += 1
	ok(total > 0, "у ствола есть грани")
	eq(outward, total, "лицевая сторона ствола — снаружи")
	# импульс гасит кончики и на «Экономно»
	var w: EcoWorld = pair[0]
	_ping(w, f.heart())
	w.step(EcoFlower.DIM_TIME)
	ok(v.sync(), "после импульса отдаёт свет")
	near(float((v.mesh.surface_get_material(0) as ShaderMaterial).get_shader_parameter("light")), EcoFlower.DARK_LIGHT,
		1e-6, "шейдер гасит кончики")
	v.set_lite(false)
	eq(v.tris, full, "назад — полный меш")
	v.queue_free()
	await frames(1)


func test_lite_kept_after_world_reset() -> void:
	var ev := EcoView.new()
	ev.ground = _flat
	ev.set_lite(true)
	ok(ev.flower_view.lite, "уровень дошёл до цветка")
	var lite_tris := ev.flower_view.tris
	ev.ground = Seabed.height
	ok(ev.flower_view.lite, "после сброса мира — по-прежнему «Экономно»")
	ok(ev.flower_view.tris <= lite_tris * 1.05 + 10, "и меш грубый")
	ev.set_lite(false)
	ev.free()
	EcoShaders.set_sway_lite(false)
