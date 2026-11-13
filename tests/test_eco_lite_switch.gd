extends TestCase
## Смена «Экономно» в живом мире (#1798): второй вариант мешей собран заранее (EcoView.prefetch_lite, по виду за
## шаг), смена уровня ставит готовый — EcoView.set_lite укладывается в 10 мс; варианты те же, что свежая сборка,
## материал у вариантов общий.

## Порог смены уровня, мс (#1798: было 56–106 мс на ПК; с запасом готовые варианты — ≈ 4 мс).
const LIMIT_MS := 10.0


func _view() -> EcoView:
	var v := EcoView.new()
	tree.root.add_child(v)
	return v


## Подпись мешей вида: треугольники каждого меша (свой, детей, оболочки MultiMesh), по порядку обхода.
static func _sig(view: Node) -> Array:
	var out := []
	var nodes: Array = [view]
	nodes.append_array(view.find_children("*", "", true, false))
	for n in nodes:
		if n != view and n.has_method("prefetch_lite"):
			continue   # свой мох — отдельный вид списка
		var m: Mesh = null
		if n is MeshInstance3D:
			m = (n as MeshInstance3D).mesh
		elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh:
			m = (n as MultiMeshInstance3D).multimesh.mesh
		if m:
			out.append([String(n.name), m.get_faces().size() / 3])
	return out


static func _sigs(ev: EcoView) -> Array:
	var out := []
	for v in ev.lite_views():
		out.append([String(v.name), _sig(v)])
	return out


static func _prefetch_all(ev: EcoView) -> int:
	var n := 0
	while ev.prefetch_lite():
		n += 1
		assert(n < 100)
	return n


func test_switch_fits_after_prefetch() -> void:
	var ev := _view()
	var n := _prefetch_all(ev)
	eq(n, ev.lite_views().size(), "второй вариант — у каждого вида списка, по одному за вызов")
	ok(ev.prefetched, "все готовы")
	# стенные часы, лучшее из трёх: время процессора (/proc) на миллисекундах не обновляется между вытеснениями
	var best_on := INF
	var best_off := INF
	for k in 3:
		var t0 := Time.get_ticks_usec() / 1000.0
		ev.set_lite(true)
		var t1 := Time.get_ticks_usec() / 1000.0
		ev.set_lite(false)
		var t2 := Time.get_ticks_usec() / 1000.0
		best_on = minf(best_on, t1 - t0)
		best_off = minf(best_off, t2 - t1)
	print("    EcoView.set_lite: «Экономно» %.1f мс, назад %.1f мс (порог %.0f)" % [best_on, best_off, LIMIT_MS])
	ok(best_on < LIMIT_MS, "включить «Экономно» — %.1f мс" % best_on)
	ok(best_off < LIMIT_MS, "выключить «Экономно» — %.1f мс" % best_off)
	ev.free()


## Готовый вариант — тот же меш, что свежая сборка на этом уровне; вернулись — как было.
func test_variants_match_fresh_build() -> void:
	var a := _view()
	var full := _sigs(a)
	_prefetch_all(a)
	eq(_sigs(a), full, "сборка заранее вид не меняет")
	a.set_lite(true)
	var b := _view()
	b.set_lite(true)   # без сборки заранее: собирает сразу
	var lite := _sigs(b)
	eq(_sigs(a), lite, "готовый вариант «Экономно» = свежая сборка")
	ok(lite != full, "варианты разные (иначе проверка пустая)")
	a.set_lite(false)
	eq(_sigs(a), full, "назад — полные меши")
	a.free()
	b.free()


## Смена уровня не теряет материал вида (ободок и свечение мира ставятся на материал один раз): корка спуска
## и оболочка ленточника раньше брали новый материал при каждой пересборке.
func test_material_kept() -> void:
	var ev := _view()
	var brink := ev.brink_view.mesh.surface_get_material(0)
	var shell := (ev.eel_view.shell.multimesh.mesh as PrimitiveMesh).material
	ev.set_lite(true)
	ok(ev.brink_view.mesh.surface_get_material(0) == brink, "корка спуска — тот же материал")
	ok((ev.eel_view.shell.multimesh.mesh as PrimitiveMesh).material == shell, "оболочка ленточника — тот же")
	ev.set_lite(false)
	ok(ev.brink_view.mesh.surface_get_material(0) == brink, "назад — тот же")
	ev.free()


## Шаг мира собирает варианты сам, по одному виду за шаг; выключатель EcoView.prefetch — не собирает.
func test_step_prefetches() -> void:
	var ship := EcoLink.ShipState.new()
	ship.pos = Helm.Ship.START
	EcoView.prefetch = false
	var still := _view()
	for i in 5:
		still.step(1.0 / 60.0, ship)
	ok(not still.prefetched, "выключено — шаг не собирает")
	still.free()
	EcoView.prefetch = true
	var ev := _view()
	var views := ev.lite_views().size()
	for i in views:
		ev.step(1.0 / 60.0, ship)
	ok(not ev.prefetched, "за %d шагов — ещё не отмечено (по одному виду за шаг)" % views)
	ev.step(1.0 / 60.0, ship)
	ok(ev.prefetched, "шаг %d — все готовы" % (views + 1))
	ev.free()
