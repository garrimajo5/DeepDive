extends TestCase
## Плашка «Слабая связь» у гостя (ART-043): кадры хоста опаздывают дольше NetLink.WEAK_AFTER — видна,
## снимается после 2 с устойчивой связи, появляется за 0,15 с, без мигания.

const DT := 0.05


func test_late_frames_show() -> void:
	var w := WeakLink.new()
	w.update(DT, NetLink.WEAK_AFTER - 0.01)
	ok(not w.on and not w.visible(), "кадр чуть запоздал, но в пороге — плашки нет")
	w.update(DT, NetLink.WEAK_AFTER + 0.01)
	ok(w.on, "кадр опоздал — слабая связь")
	near(w.a, DT / WeakLink.FADE, 0.001, "появляется постепенно")
	w.update(0.1, NetLink.WEAK_AFTER + 0.1)
	near(w.a, 1.0, 0.001, "за 0,15 с — целиком")


func test_calm_two_seconds_hides() -> void:
	var w := WeakLink.new()
	w.update(DT, 1.0)
	var t := 0.0
	while t < WeakLink.CALM - 0.1:
		w.update(DT, 0.0)
		t += DT
	ok(w.on and w.visible(), "до 2 с устойчивой связи — видна")
	for i in 3:
		w.update(DT, 0.0)
	ok(not w.on, "2 с устойчивой связи — снимается")
	for i in 4:
		w.update(DT, 0.0)
	ok(not w.visible(), "ушла за 0,15 с")


func test_no_blinking() -> void:   # опоздание в спокойном отсчёте — отсчёт заново, плашка не гаснет
	var w := WeakLink.new()
	w.update(DT, 1.0)
	var t := 0.0
	for k in 3:
		for i in int(1.5 / DT):
			w.update(DT, 0.0)
			t += DT
			ok(w.visible(), "видна без перерыва на %.2f с" % t)
		w.update(DT, NetLink.WEAK_AFTER + 0.05)
	ok(w.on, "связь то и дело опаздывает — плашка стоит")


func test_threshold_by_link_not_fps() -> void:
	ok(NetLink.WEAK_AFTER > NetSnap.SEND_DT * 3.0, "порог — несколько кадров хоста, не один")
	ok(NetLink.WEAK_AFTER < NetLink.LOST_AFTER, "слабая связь раньше «Нет связи»")


func test_box_in_reference_screen() -> void:
	var r := WeakLink.to_screen(Vector2(2400, 1080))
	near(r.position.x, 70.0, 0.5)
	near(r.position.y, 430.0, 0.5)
	near(r.size.x, 400.0, 0.5)
	near(r.size.y, 96.0, 0.5)


func test_left_edge_on_any_screen() -> void:   # 16:9 и 4:3 — плашка у левого края, не уезжает за экран
	for size: Vector2 in [Vector2(1920, 1080), Vector2(1024, 768), Vector2(3200, 1080)]:
		var r := WeakLink.to_screen(size)
		near(r.position.x, 70.0 * size.y / 1080.0, 0.5, "отступ слева на %s" % size)
		ok(r.end.x < size.x * 0.5, "в левой половине на %s" % size)
