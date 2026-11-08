extends TestCase
## Общий слой мути живого мира (issue #849): облачка всех видов — один MultiMesh «Муть», один вызов отрисовки вместо
## ≈20; кусок буфера на пул вида, грузится только при изменениях, пустой слой спрятан, после пересборки видов
## слой собирается заново.


func test_all_species_dust_in_one_layer() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var layer := view.dust_layer
	var total := 0
	for p in layer.pools:
		total += p
	eq(layer.multimesh.instance_count, total, "мест в слое — сумма пулов видов")
	eq(layer.data.size(), total * GrazerView.DUST_STRIDE)
	for name in ["grazer_view", "fish_view", "pred_view", "kelp_view", "organ_view", "veil_view", "coins_view"]:
		var v: Node = view.get(name)
		ok(v.get("dust_view") == null, "%s: своего слоя мути нет" % name)
		ok(layer.parts.has(v.get("_dust")), "%s: муть — в общем слое" % name)
	var mat := (layer.multimesh.mesh as QuadMesh).material as ShaderMaterial
	ok(mat.shader == EcoShaders.mist(EcoShaders.Mist.INK).shader, "общий шейдер MIST — шейдеров не прибавилось")
	eq(layer.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "без тени")
	view.queue_free()
	await frames(1)


## Облачко у одного вида — слой виден, его числа на месте куска этого вида; без изменений буфер не грузится.
func test_puff_lands_in_species_slice() -> void:
	EcoGrazerDust.lite = false
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var layer := view.dust_layer
	var ship := EcoLink.ShipState.new()
	ship.pos = Vector3(0, 2000, 0)   # высоко — сами виды мути не поднимают
	view.step(0.05, ship)
	ok(not layer.visible, "мути нет — слой спрятан")
	var rv := view.ray_view
	var ry := view.rays.rays[0]
	rv.dust.dust.add(ry.p, view.world.time, 0.4, 1, 1.2)
	view.step(0.05, ship)
	ok(layer.visible, "облачко поднялось — слой виден")
	var k := layer.parts.find(rv._dust)
	var off := 0
	for i in k:
		off += layer.pools[i]
	var seen := 0
	for n in layer.multimesh.instance_count:
		if layer.data[n * GrazerView.DUST_STRIDE + 15] > 0.0:
			seen += 1
			ok(n >= off and n < off + layer.pools[k], "облачко — в куске ледокрылов")
	eq(seen, 1, "видно одно облачко")
	eq(layer.shown, 1)
	for i in int((EcoGrazerDust.LIFE + 0.5) / 0.05):
		view.step(0.05, ship)
	ok(not layer.visible, "облачко растаяло — слой снова спрятан")
	var n_up := layer.uploads
	for i in 5:
		view.step(0.05, ship)
	eq(layer.uploads, n_up, "мути нет и не было — буфер не грузим заново")
	view.queue_free()
	await frames(1)


## Новое дно — виды пересобраны: слой забирает муть новых видов, старые куски отпущены.
func test_rebuild_regathers() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var before := view.dust_layer.parts.size()
	view.ground = Seabed.height
	eq(view.dust_layer.parts.size(), before, "кусков столько же")
	ok(view.dust_layer.parts.has(view.kelp_view._dust), "муть новой рощи — в слое")
	eq(view.find_children("Муть", "MultiMeshInstance3D", true, false).size(), 1, "слой по-прежнему один")
	var ship := EcoLink.ShipState.new()
	ship.pos = Vector3(0, 2000, 0)
	view.step(0.05, ship)
	view.queue_free()
	await frames(1)
