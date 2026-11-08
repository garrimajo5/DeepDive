extends TestCase
## Общий буфер мути у дна EcoDustBuffer (issue #732): тот же рисунок, что GrazerView.pack_dust, но растаявшее
## не переписывается, а пустой пул без новых облачков не проходится — шаг живого мира с мутью Б3 снова в пороге.


func _pool() -> EcoGrazerDust:
	var d := EcoGrazerDust.new(8)
	for k in 5:
		d.add(Vector3(k * 2.0, -40.0 + k * 0.1, 3.0 - k), 0.5 * k, 0.5, k, 1.0 if k % 2 == 0 else 0.6)
	return d


func _floor(_x: float, _z: float) -> float:
	return -39.8


## Живые облачки — как в GrazerView.pack_dust (размер, место над дном, течение, свет луча, непрозрачность),
## растаявшие и пустые места — нули.
func test_same_as_grazer_pack() -> void:
	var ship := EcoLink.ShipState.new()
	ship.pos = Vector3(4, -36, 2)
	ship.light_on = true
	ship.light_range = 20.0
	var flow := Vector3(0.3, 0.2, -0.1)
	var floor := Callable(self, "_floor")
	var buf := EcoDustBuffer.new()
	var checked := 0
	for f in 120:
		var t := f * 0.05
		var d := _pool()
		var ref := GrazerView.pack_dust(d, t, flow, ship, EcoKrabDust.COLOR, EcoKrabDust.LIT, floor)
		var shown := buf.pack(d, t, flow, ship, EcoKrabDust.COLOR, EcoKrabDust.LIT, floor)
		eq(shown, d.shown(t), "видно столько же облачков (t=%.2f)" % t)
		eq(buf.data.size(), ref.size())
		for n in d.puffs.size():
			var i := n * GrazerView.DUST_STRIDE
			if ref[i + 15] <= 0.0:
				for k in GrazerView.DUST_STRIDE:
					if buf.data[i + k] != 0.0:
						ok(false, "растаявшее облачко %d стянуто в точку (t=%.2f)" % [n, t])
						return
				continue
			checked += 1
			for k in GrazerView.DUST_STRIDE:
				if absf(buf.data[i + k] - ref[i + k]) > 1e-5:
					ok(false, "облачко %d, поле %d: %.5f и %.5f (t=%.2f)" % [n, k, buf.data[i + k], ref[i + k], t])
					return
	ok(checked > 100, "сравнили живых облачков (%d)" % checked)


## Всё растаяло и нового нет — пул не проходится и буфер не грузится заново; новое облачко — снова в буфере.
func test_empty_pool_skipped_until_new_puff() -> void:
	var d := EcoGrazerDust.new(8)
	var buf := EcoDustBuffer.new()
	eq(buf.pack(d, 1.0, Vector3.ZERO), 0)
	ok(buf.changed, "первый раз буфер грузится")
	eq(buf.pack(d, 1.1, Vector3.ZERO), 0)
	ok(not buf.changed, "пусто и было пусто — не грузим")
	var p := d.add(Vector3(1, -40, 1), 1.2, 0.5, 3)
	eq(buf.pack(d, 1.3, Vector3.ZERO), 1, "новое облачко видно")
	ok(buf.changed)
	ok(buf.data[15] > 0.0, "непрозрачность записана")
	eq(buf.pack(d, 1.2 + EcoGrazerDust.LIFE + 0.1, Vector3.ZERO), 0, "растаяло")
	ok(buf.changed, "растаявшее стянуто в точку — буфер грузится последний раз")
	near(buf.data[0], 0.0, 1e-9)
	near(buf.data[15], 0.0, 1e-9)
	eq(buf.pack(d, 1.2 + EcoGrazerDust.LIFE + 0.2, Vector3.ZERO), 0)
	ok(not buf.changed, "снова пусто — не грузим")
	ok(p != null)


## Время мира ушло назад (новый забег): облачко из «будущего» встаёт, когда до него дойдёт время, — пустой пул
## с ним не пропускается.
func test_future_puff_rises_after_time_jump() -> void:
	var d := EcoGrazerDust.new(4)
	var buf := EcoDustBuffer.new()
	d.add(Vector3(0, -40, 0), 5.0, 0.5, 1)
	eq(buf.pack(d, 1.0, Vector3.ZERO), 0, "ещё не поднялось")
	eq(buf.pack(d, 2.0, Vector3.ZERO), 0)
	eq(buf.pack(d, 5.5, Vector3.ZERO), 1, "время дошло — облачко видно")
