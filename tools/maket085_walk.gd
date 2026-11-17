extends SceneTree
## Путь соло по носовой зоне и отсекам макета ART-085 v3 — критерий владельца 17.11 (#1788):
## «путь соло между четырьмя постами и доступ к аварийному оборудованию — расчётные 2–3 с перехода
## должны подтвердиться реальной камерой и капсулой игрока». Капсула — как Deck.Walker (Ø 0,7 м,
## 2,4 м/с, скольжение вдоль стен), счёт — `Maket085.walk` (детерминирован, покрыт test_maket085).
## Headless, без узлов. Ничего не переставляет — только отчёт.
##   godot --headless --path . -s tools/maket085_walk.gd [-- png=<файл плана>]

const Maket := preload("res://tools/maket085.gd")

## Ожидание листа 03 v3: переходы между соседними постами 2–3 с.
const EXPECT_MAX := 3.0


func _init() -> void:
	var kv := {}
	for a in OS.get_cmdline_user_args():
		var p := a.split("=", true, 1)
		kv[p[0]] = p[1] if p.size() > 1 else ""
	print("Путь соло по макету ART-085 v3: капсула Ø %.1f м, %.1f м/с (Deck.Walker), скольжение вдоль стен." % [
			Maket.WALK_R * 2.0, Maket.WALK_SPEED])
	print("Посты: пилот %s, инженер %s, биолог %s, сонар %s; аварийное — техника %s." % [
			Maket.STAND_PILOT, Maket.STAND_ENGINEER, Maket.STAND_BIOLOG, Maket.STAND_SONAR, Maket.TECH_POST])
	var res := Maket.walk_all()
	print("\nмаршрут | путь, м | время, с | итог")
	var worst := 0.0
	var all_ok := true
	for rname: String in res:
		var r: Dictionary = res[rname]
		all_ok = all_ok and r["ok"] and r["waypoints_ok"]
		var note := "ок"
		if not r["waypoints_ok"]:
			note = "ТОЧКА НЕ СТОИТ: %s" % r["bad_point"]
		elif not r["ok"]:
			note = "ВСТАЛ в %s" % str(r["stuck"])
		elif r["time"] > EXPECT_MAX and r["len"] < 12.0:
			note = "дольше расчётных %.0f с" % EXPECT_MAX
		worst = maxf(worst, r["time"])
		print("%-28s | %7.1f | %8.1f | %s" % [rname, r["len"], r["time"], note])
	print("\nВсе маршруты проходимы: %s; наибольшее время %.1f с." % ["да" if all_ok else "НЕТ", worst])
	if kv.has("png"):
		plan_image(res).save_png(kv["png"])
		print("План: %s" % kv["png"])
	quit()


## Точка палубы (x, z) → пиксель плана (z вниз, нос сверху).
static func _px(x: float, z: float) -> Vector2:
	return Vector2((x + 4.5) * PX_M, (z - Z0) * PX_M)


const PX_M := 30.0    ## пикселей на метр
const Z0 := -13.5     ## верх плана, z палубы


## План носовой зоны и отсеков: стены белым, стол и кресла — заливка, консоли — повёрнутые
## прямоугольники, рабочие точки зелёным, трассы маршрутов — цветные линии с затуханием.
static func plan_image(res: Dictionary) -> Image:
	var w := int(9.0 * PX_M)
	var h := int(25.0 * PX_M)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color(0.07, 0.09, 0.11))
	# палуба: носовая зона и отсеки — тон заливки
	for iy in h:
		for ix in w:
			var x := ix / PX_M - 4.5
			var z := Z0 + iy / PX_M
			if Geometry2D.is_point_in_polygon(Vector2(x, z), PackedVector2Array(Maket.NOSE_POLY)):
				img.set_pixel(ix, iy, Color(0.13, 0.16, 0.19))
			else:
				for room in Maket.ROOMS:
					if absf(x) < room.z and z > room.x and z < room.y:
						img.set_pixel(ix, iy, Color(0.11, 0.14, 0.17))
	# стены
	for wseg in Maket.walls():
		_line(img, _px(wseg.x, wseg.y), _px(wseg.z, wseg.w), Color(0.85, 0.87, 0.9))
	# стол и кресла
	_disc(img, _px(Maket.TABLE.x, Maket.TABLE.y), Maket.TABLE_R, Color(0.2, 0.35, 0.5))
	for chair in [Maket.POST_PILOT, Maket.POST_ENGINEER, Maket.POST_BIOLOG]:
		_disc(img, _px(chair.x, chair.y), Maket.CHAIR_R, Color(0.3, 0.3, 0.34))
	# консоли (повёрнутые прямоугольники — заливка по сетке)
	for c in Maket.consoles():
		var v: Vector4 = c[0]
		var dir: float = c[1]
		for iy in range(int((v.y - 1.0 - Z0) * PX_M), int((v.y + 1.0 - Z0) * PX_M)):
			for ix in range(int((v.x - 1.0 + 4.5) * PX_M), int((v.x + 1.0 + 4.5) * PX_M)):
				var x := ix / PX_M - 4.5
				var z := Z0 + iy / PX_M
				if Maket._in_console(x, z, v, dir, 0.0) and ix >= 0 and ix < w and iy >= 0 and iy < h:
					img.set_pixel(ix, iy, Color(0.45, 0.25, 0.15))
	# люки — метки на переборках
	for hz in Maket.HATCH_Z:
		_line(img, _px(-Maket.HATCH_HALF, hz), _px(Maket.HATCH_HALF, hz), Color(0.25, 0.5, 0.3))
	# трассы маршрутов
	var colors: Array[Color] = [Color(0.95, 0.3, 0.2), Color(0.95, 0.8, 0.15), Color(0.3, 0.85, 0.35),
			Color(0.3, 0.6, 0.95), Color(0.8, 0.4, 0.95), Color(0.95, 0.5, 0.7), Color(0.5, 0.9, 0.9),
			Color(1.0, 0.6, 0.2), Color(0.6, 0.95, 0.5), Color(0.7, 0.7, 1.0)]
	var n := 0
	for rname: String in res:
		var col: Color = colors[n % colors.size()]
		n += 1
		var tr: Array = res[rname]["trace"]
		for i in range(1, tr.size()):
			_line(img, _px(tr[i - 1].x, tr[i - 1].y), _px(tr[i].x, tr[i].y), col)
	# рабочие точки поверх трасс
	for st in [Maket.STAND_PILOT, Maket.STAND_ENGINEER, Maket.STAND_BIOLOG, Maket.STAND_SONAR, Maket.TECH_POST]:
		_disc(img, _px(st.x, st.y), 0.12, Color(0.3, 1.0, 0.4))
	return img


static func _line(img: Image, a: Vector2, b: Vector2, col: Color) -> void:
	var n := int(a.distance_to(b)) * 2 + 1
	for i in n + 1:
		var p := a.lerp(b, float(i) / float(n))
		var ix := int(p.x)
		var iy := int(p.y)
		if ix >= 0 and ix < img.get_width() and iy >= 0 and iy < img.get_height():
			img.set_pixel(ix, iy, col)


static func _disc(img: Image, c: Vector2, r: float, col: Color) -> void:
	var rp := r * PX_M
	for iy in range(int(c.y - rp), int(c.y + rp) + 1):
		for ix in range(int(c.x - rp), int(c.x + rp) + 1):
			if Vector2(ix, iy).distance_to(c) <= rp and ix >= 0 and ix < img.get_width() \
					and iy >= 0 and iy < img.get_height():
				img.set_pixel(ix, iy, col)
