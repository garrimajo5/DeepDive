extends TestCase
## Разброс особей в MultiMesh (Б4, `docs/grafika-plan-eco.md`): у светляков и скребунов свой размер, оттенок
## и ритм — стая не клоны. Числа — хешем от номера особи (EcoVary): мир и его случай не меняются, вид один и тот же
## при каждом запуске, вызовов отрисовки и шейдеров не прибавилось.


func _fish_world() -> EcoWorld:
	var w := EcoWorld.new(EcoRandom.WORLD_SEED)
	w.ground = Seabed.height
	w.ship.pos = Vector3(500, 0, 500)
	w.add(EcoFish.new())
	return w


func _grazer_world() -> EcoWorld:
	var w := EcoWorld.new(EcoRandom.WORLD_SEED)
	w.ground = Seabed.height
	w.ship.pos = Vector3(500, 0, 500)
	var m := w.add(EcoMoss.new()) as EcoMoss
	w.add(EcoGrazer.new(m))
	return w


func _span(xs: Array) -> Vector2:
	var lo := INF
	var hi := -INF
	for x: float in xs:
		lo = minf(lo, x)
		hi = maxf(hi, x)
	return Vector2(lo, hi)


func _mean(xs: Array) -> float:
	var s := 0.0
	for x: float in xs:
		s += x
	return s / xs.size()


func test_hash_stable_and_in_range() -> void:
	var seen := {}
	for i in 500:
		var u := EcoVary.unit(i, EcoVary.SIZE)
		if not ok(u >= 0.0 and u < 1.0, "в [0, 1): %f" % u):
			return
		eq(u, EcoVary.unit(i, EcoVary.SIZE), "тот же номер — то же число")
		seen[snappedf(u, 0.1)] = true
		var s := EcoVary.spread(i, EcoVary.SHADE, 0.2)
		if not ok(s >= 0.8 and s <= 1.2, "1 ± 0,2: %f" % s):
			return
	ok(seen.size() >= 10, "покрывает весь отрезок: %d десятых" % seen.size())
	var same := 0
	for i in 200:
		if absf(EcoVary.unit(i, EcoVary.SIZE) - EcoVary.unit(i, EcoVary.SHADE)) < 0.02:
			same += 1
	ok(same < 12, "свойства одной особи не связаны: совпало %d из 200" % same)
	var close := 0
	for i in 199:
		if absf(EcoVary.unit(i, EcoVary.SIZE) - EcoVary.unit(i + 1, EcoVary.SIZE)) < 0.02:
			close += 1
	ok(close < 12, "соседи по номеру не похожи: %d из 199" % close)


func test_fish_differ_in_size_shade_and_rhythm() -> void:
	var fish := _fish_world().systems[0] as EcoFish
	var sizes := []
	var shades := []
	var rates := []
	for f: EcoFish.Fish in fish.all:
		if f.shoal.cage:
			continue  # молодь — своим размером, ниже
		sizes.append(EcoFishLook.scale(f))
		shades.append(EcoFishLook.shade(f))
		rates.append(EcoFishLook.wiggle_rate(f))
	var s := _span(sizes)
	ok(s.x >= 1.0 - EcoFishLook.SIZE_SPREAD - 1e-5 and s.y <= 1.0 + EcoFishLook.SIZE_SPREAD + 1e-5,
		"размер взрослых в пределах ±12 %%: %s" % s)
	ok(s.y - s.x > 0.18, "и заметно разный: %s" % s)
	near(_mean(sizes), 1.0, 0.03, "в среднем — прежняя рыбка")
	var d := _span(shades)
	ok(d.y - d.x > 0.3 and d.x >= 0.8 - 1e-5 and d.y <= 1.2 + 1e-5, "тело светлее-темнее: %s" % d)
	var r := _span(rates)
	ok(r.y - r.x > 3.0, "хвостами машут не в лад: %s рад/с" % r)
	near(_mean(rates), EcoFishLook.WIGGLE_RATE, 0.6, "средняя частота прежняя")
	# у каждой рыбки своё, вид не зависит от зерна мира (тот же номер — та же рыбка)
	var other := EcoWorld.new(77)
	other.ground = Seabed.height
	other.ship.pos = Vector3(500, 0, 500)
	var fish2 := other.add(EcoFish.new()) as EcoFish
	for i in 20:
		eq(EcoFishLook.scale(fish2.all[i]), EcoFishLook.scale(fish.all[i]), "размер — по номеру особи")


func test_fish_buffer_carries_variation() -> void:
	var fish := _fish_world().systems[0] as EcoFish
	var buf := FishView.pack(fish, 2.0)
	var shades := {}
	for f: EcoFish.Fish in fish.all:
		var tr := FishView.transform_at(buf, f.index)
		if not near(tr.basis.x.length(), EcoFishLook.scale(f), 1e-4, "размер в буфере — EcoFishLook.scale"):
			return
		if not ok(tr.basis.z.distance_to(EcoFishLook.basis(f, 2.0).z) < 1e-4, "курс с вилянием особи"):
			return
		near(FishView.shade_at(buf, f.index), EcoFishLook.shade(f), 1e-5, "оттенок тела в INSTANCE_CUSTOM.a")
		shades[snappedf(FishView.shade_at(buf, f.index), 0.05)] = true
	ok(shades.size() >= 6, "тела разного оттенка: %d" % shades.size())
	ok(FishView.SHADER.contains("body_color * shade"), "шейдер берёт оттенок особи")


func test_grazers_differ_and_stand_on_ground() -> void:
	var w := _grazer_world()
	var grazers: EcoGrazer = null
	for sys in w.systems:
		if sys is EcoGrazer:
			grazers = sys
	var sizes := []
	var tints := {}
	for g: EcoGrazer.Grazer in grazers.all:
		var k := EcoGrazerLook.scale(g)
		sizes.append(k)
		ok(k >= 0.9 - 1e-5 and k <= 1.1 + 1e-5, "размер ±10 %%: %f" % k)
		var tn := EcoGrazerLook.tint(g)
		tints[Vector3i(roundi(tn.r * 40), roundi(tn.g * 40), roundi(tn.b * 40))] = true
		ok(tn.g >= 0.88 - 1e-5 and tn.g <= 1.12 + 1e-5 and absf(tn.r - tn.b) <= 2.0 * 0.06 * 1.12 + 1e-4,
			"оттенок в пределах: %s" % tn)
		# стопы остаются на дне при любом размере
		var low := INF
		for i in EcoGrazerLook.verts_per_grazer():
			low = minf(low, EcoGrazerLook.place(g, 0.0, i).y)
		near(low, g.agent.p.y - EcoGrazer.LIFT, 1e-3, "стопы скребуна %d на дне" % g.index)
	var s := _span(sizes)
	ok(s.y - s.x > 0.08, "скребуны разного размера: %s" % s)
	ok(tints.size() >= grazers.all.size() * 0.7, "почти все разного оттенка: %d из %d" % [tints.size(), grazers.all.size()])
	var buf := GrazerView.pack(grazers, 1.0)
	for g: EcoGrazer.Grazer in grazers.all:
		ok(GrazerView.tint_at(buf, g.index).is_equal_approx(EcoGrazerLook.tint(g)), "оттенок — цвет экземпляра")


## Разброс не трогает случай мира: стаи плывут так же, как без него (поведение берёт f.size, не scale()).
func test_world_unchanged() -> void:
	var a := _fish_world()
	var b := _fish_world()
	a.run(5.0)
	b.run(5.0)
	var fa := a.systems[0] as EcoFish
	var fb := b.systems[0] as EcoFish
	for i in fa.all.size():
		if not ok(fa.all[i].agent.p.distance_to(fb.all[i].agent.p) < 1e-6, "рыбка %d там же" % i):
			return
	for f: EcoFish.Fish in fa.all:
		if not near(f.agent.clearance, 0.4 * f.size, 1e-6, "зазор — по размеру возраста"):
			return
