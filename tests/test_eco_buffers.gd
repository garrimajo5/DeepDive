extends TestCase
## Буферы неподвижного не грузятся каждый кадр (issue #850): EcoMM.send отдаёт буфер в MultiMesh, только когда
## он изменился. Подушки, листья волнолиста (колышет шейдер), хватни и радужники в кадры без «due» — одинаковые
## кадр за кадром, их загрузка в видеокарту — пустая работа.


func test_send_only_when_changed() -> void:
	var holder := Node3D.new()
	var mi := EcoMM.instance(holder, "Проба", BoxMesh.new(), 2)
	var buf := PackedFloat32Array()
	buf.resize(2 * EcoMM.STRIDE)
	EcoMM.put(buf, 0, Transform3D.IDENTITY)
	var n0 := EcoMM.uploads
	ok(EcoMM.send(mi, buf), "первый раз — грузит")
	eq(mi.multimesh.buffer, buf, "буфер в MultiMesh")
	ok(not EcoMM.send(mi, buf), "тот же буфер — не грузит")
	EcoMM.put(buf, EcoMM.STRIDE, Transform3D(Basis.IDENTITY, Vector3(1, 2, 3)))
	ok(EcoMM.send(mi, buf), "изменился — грузит")
	eq(mi.multimesh.buffer, buf, "в MultiMesh — новый")
	ok(not EcoMM.send(mi, buf.duplicate()), "копия с теми же числами — не грузит")
	eq(EcoMM.uploads - n0, 2, "две загрузки")
	holder.free()


## Корабль далеко: неподвижные виды кадр за кадром одинаковы. Подменяем загруженный буфер нулями в обход send —
## без исправления следующий кадр загрузит буфер снова и нули пропадут.
func test_still_life_not_reuploaded() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var ship := EcoLink.ShipState.new()
	ship.pos = Vector3(500, 0, 500)
	for i in 20:
		view.step(0.05, ship)
	var still: Array[MultiMeshInstance3D] = [view.cushion_view.pads, view.fern_view.leaves]
	for mi in still:
		var zero := PackedFloat32Array()
		zero.resize(mi.multimesh.buffer.size())
		mi.multimesh.buffer = zero
	for i in 5:
		view.step(0.05, ship)
	for mi in still:
		var b := mi.multimesh.buffer
		var empty := true
		for x in b:
			if x != 0.0:
				empty = false
				break
		ok(empty, "%s: неподвижное не грузится заново" % view.get_path_to(mi))
	# изменилось — грузится: подушку сжали
	var cu := view.cushions.cushions[0]
	view.cushions.squeeze(view.world, cu, true)
	view.step(0.5, ship)
	var tr := CushionView.transform_at(view.cushion_view.pads.multimesh.buffer, 0, CushionView.STRIDE)
	ok(tr.basis.get_scale().y > 0.1 and tr.basis.get_scale().y < 0.7, "сжатая подушка — в MultiMesh")
	view.queue_free()
	await frames(1)


## Хватень вдали переписывается раз в FAR_EVERY кадров (HvatenView.due) — в остальные кадры буферы те же и не грузятся.
func test_far_anemone_uploads_only_when_due() -> void:
	var w := EcoWorld.new()
	w.ground = func(_x: float, _z: float) -> float: return -40.0
	var h := w.add(EcoHvaten.new(null, [Vector3(0, -40, 0)] as Array[Vector3])) as EcoHvaten
	w.reset()
	var view := HvatenView.new(h)
	tree.root.add_child(view)
	await frames(1)
	var far := Vector3(300, 0, 300)
	var due := 0
	var n0 := EcoMM.uploads
	for i in 6:
		w.run(0.1)
		if HvatenView.due(h.anemones[0], far, view._frame + 1):
			due += 1
		view.sync(w.time, far, false)
	ok(due > 0 and due < 6, "вдали — не каждый кадр (%d из 6)" % due)
	eq(EcoMM.uploads - n0, due * 3, "тела, щупальца и пестрянки грузятся только в свои кадры")
	view.queue_free()
	await frames(1)
