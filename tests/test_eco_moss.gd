extends TestCase
## Светящийся мох мерцает (Б3): по колонии бегут медленные волны свечения — двойник шейдера `MossView.shimmer`,
## время мира — uniform `now` у всех трёх мхов (отмель, кости, колодец).


func test_shimmer_bounded_and_averages_to_one() -> void:
	var lo := 10.0
	var hi := -10.0
	var sum := 0.0
	var n := 0
	for i in 400:
		var t := i * 0.25
		var k := MossView.shimmer(30.8, 94.4, t)
		lo = minf(lo, k)
		hi = maxf(hi, k)
		sum += k
		n += 1
	ok(lo >= 1.0 - MossView.SHIMMER - 1e-5 and hi <= 1.0 + MossView.SHIMMER + 1e-5, "в пределах ±SHIMMER: %.3f…%.3f" % [lo, hi])
	ok(hi - lo > MossView.SHIMMER, "мерцает заметно: %.3f…%.3f" % [lo, hi])
	near(sum / n, 1.0, 0.05, "в среднем яркость пятна та же")


func test_shimmer_slow_and_travels() -> void:
	# Медленно: за кадр 1/30 с меняется меньше чем на 1 %.
	for i in 50:
		var t := i * 0.7
		ok(absf(MossView.shimmer(5.0, 3.0, t + 1.0 / 30.0) - MossView.shimmer(5.0, 3.0, t)) < 0.01, "без дрожи (t %.1f)" % t)
	# По пятну (7 м) — не одним цветом: в один миг вершины в 3 м друг от друга светят по-разному.
	var spread := 0.0
	for i in 20:
		var t := i * 1.3
		spread = maxf(spread, absf(MossView.shimmer(0.0, 0.0, t) - MossView.shimmer(3.0, 0.0, t)))
	ok(spread > 0.1, "волна бежит по пятну, а не мигает целиком: %.3f" % spread)


func test_shader_matches_twin() -> void:
	ok(EcoShaders.MOSS.contains("uniform float now"), "время мира — в шейдере мха")
	ok(EcoShaders.MOSS.contains("(1.0 + shimmer * w)"), "мерцание множит яркость вершины")
	ok(EcoShaders.MOSS.contains("0.6 * sin(now * 0.9 + q.x * 0.8 + q.y * 0.55) + 0.4 * sin(now * 0.55 - q.x * 0.35 + q.y * 0.9)"),
		"формула волн — как у двойника MossView.shimmer")


func test_view_sets_world_time_on_all_moss() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var ship := EcoLink.ShipState.new()
	ship.pos = Vector3(0, -30, 95)
	for i in 5:
		view.step(0.05, ship)
	var views: Array[MossView] = [view.moss_view]
	if view.bones_view.moss_view:
		views.append(view.bones_view.moss_view)
	if view.well_view.moss_view:
		views.append(view.well_view.moss_view)
	ok(views.size() >= 2, "мох отмели и ещё хотя бы один: %d" % views.size())
	for mv in views:
		var mat := mv.mesh.surface_get_material(0) as ShaderMaterial
		near(float(mat.get_shader_parameter("now")), view.world.time, 1e-5, "%s: время мира в шейдере" % mv.name)
		near(float(mat.get_shader_parameter("shimmer")), MossView.SHIMMER, 1e-6, "%s: размах мерцания" % mv.name)
	var mv0 := view.moss_view
	mv0.set_lite(true)
	var lite_mat := mv0.mesh.surface_get_material(0) as ShaderMaterial
	near(float(lite_mat.get_shader_parameter("shimmer")), MossView.SHIMMER, 1e-6, "на «Экономно» мерцает так же")
	view.queue_free()
	await frames(1)
