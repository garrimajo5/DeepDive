extends TestCase
## Плашка таблички ART-033 собирается из заготовки (#725): попиксельно как полный расчёт, и быстро.


func _same(a: Image, b: Image, what: String) -> void:
	eq(a.get_size(), b.get_size(), what + ": размер")
	if a.get_size() != b.get_size():
		return
	var da := a.get_data()
	var db := b.get_data()
	var worst := 0
	for i in da.size():
		worst = maxi(worst, absi(da[i] - db[i]))
	ok(worst <= 2, "%s: пиксели как у полного расчёта (расхождение %d/255 — только округление float у краёв)" % [what, worst])


func test_plate_matches_full() -> void:
	for w in [NameTag.MIN_W, 2.9, 3.47, 4.0, 5.3, NameTag.MAX_W]:
		for role in 4:
			var cols := NameTag.colors(role, false)
			_same(NameTag.plate_image(w, cols[1], cols[0]), NameTag._plate_full(w, cols[1], cols[0]), "плашка %s, роль %d" % [w, role])
		var dim := NameTag.colors(0, true)
		_same(NameTag.plate_image(w, dim[1], dim[0]), NameTag._plate_full(w, dim[1], dim[0]), "без связи %s" % w)
		_same(NameTag.glow_image(w), NameTag._glow_full(w), "«нажимает» %s" % w)


func test_narrow_falls_back() -> void:
	var w := float(NameTag.PLATE_CAP.x) / NameTag.TEX_H   # уже заготовки — полный расчёт
	_same(NameTag.plate_image(w, NameTag.ring_color(1)), NameTag._plate_full(w, NameTag.ring_color(1)), "узкая плашка")
	_same(NameTag.glow_image(0.5), NameTag._glow_full(0.5), "узкий слой")


func test_caps_cover_details() -> void:
	# левый край — до конца кольца и вне влияния угла, правый — за штрихами и углом
	var h := NameTag.TEX_H
	var corner := (NameTag.CORNER + NameTag.BORDER * 1.8) * h + 1.0
	ok(NameTag.PLATE_CAP.x >= (NameTag.CIRCLE_X + NameTag.CIRCLE_R + NameTag.RING * 0.5) * h + 1.0, "кольцо в левом краю")
	ok(NameTag.PLATE_CAP.x >= corner and NameTag.PLATE_CAP.y >= corner - NameTag.BORDER * 0.8 * h, "угол плашки в краях")
	ok(NameTag.GLOW_CAP.x >= corner and NameTag.GLOW_CAP.y >= corner, "угол слоя в краях")
	ok(NameTag.GLOW_CAP.y >= (float(NameTag.STROKE_X.max()) + NameTag.STROKE_T * 0.5) * h + 1.0, "штрихи в правом краю")


func test_build_is_fast() -> void:
	NameTag.plate_image(3.0, NameTag.ring_color(2))   # заготовка — раз на цвет
	NameTag.glow_image(3.0)
	BusyMark.panel_image(5.0)
	var t := Time.get_ticks_usec()
	for i in 8:
		NameTag.plate_image(3.0 + i * 0.4, NameTag.ring_color(2))
		NameTag.glow_image(3.0 + i * 0.4)
		BusyMark.panel_image(5.0 + i * 0.4)
	var ms := (Time.get_ticks_usec() - t) / 1000.0
	ok(ms < 20.0, "8 табличек и подложек «Занято» из заготовки за %.1f мс (полный расчёт — ~300 мс)" % ms)


func test_busy_panel_matches_full() -> void:
	# подложка «Занято» (BusyMark) — тот же приём: левый край с замком, середина, правый край
	for w in [1.2, 3.5, 4.47, 6.0, 9.3]:
		_same(BusyMark.panel_image(w), BusyMark._panel_full(w), "подложка %s" % w)
	var px := BusyMark.TEX_H / BusyMark.H
	ok(BusyMark.PANEL_CAP.x >= (BusyMark.PAD + BusyMark.LOCK_X + BusyMark.LOCK_W * 0.5 + BusyMark.LOCK_T) * px + 1.0, "замок в левом краю")
	ok(BusyMark.PANEL_CAP.y >= (BusyMark.CORNER + BusyMark.BORDER) * px + 1.0, "угол в правом краю")
