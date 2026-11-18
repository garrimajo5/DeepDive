extends TestCase
## Модель-макет ART-085 v3 (#1788, критерии владельца 17.11): габарит и контур по листам v3,
## порты и их рамы, рабочие точки постов стоят, путь соло капсулой проходим и в разумных временах,
## предел хода по днищу, зазор до врат 07 в проходе и касание при сносе. Счётная часть —
## `tools/maket085.gd`; прогоны — `tools/maket085_pass.gd` / `maket085_walk.gd`, снимки — `maket085_shot.gd`.

const Maket := preload("res://tools/maket085.gd")


## Габарит 28 × 10 × 9 м: контур даёт нос −14, корму +14, полуширину 5, верх +4, низ −5 (полозья).
func test_dimensions() -> void:
	eq(Maket.NOSE_Z, -14.0, "нос −14")
	eq(Maket.STERN_Z, 14.0, "корма +14")
	eq(Maket.HALF_W, 5.0, "полуширина 5")
	eq(Maket.TOP_Y - Maket.KEEL_Y, 9.0, "высота 9")
	near(Maket.half_width(-7.0), 5.0, 0.01, "полуширина в цилиндрической части")
	near(Maket.half_width(0.0), 5.0, 0.01, "полуширина на середине")
	near(Maket.half_width(-14.0), 0.0, 0.01, "сходимость на нос")
	near(Maket.half_width(14.0), 0.0, 0.01, "сходимость на корму")
	near(Maket.half_width(-13.0), 1.75, 0.01, "нос заужен: ±1,75 на z −13")
	var mid := Maket.section(0.0)
	near(mid.y, -4.67, 0.01, "низ на середине — грань днища (10;−4,3)…(−9;−5)")
	near(Maket.section(-9.0).y, -5.0, 0.01, "полозья −5 в точке z −9")
	near(mid.z, 4.0, 0.01, "верх на середине +4")
	ok(is_nan(Maket.section(20.0).y), "вне корпуса сечения нет")


## Порты: три, рамы не пересекаются, глаз пилота на оси центрального, все внутри передней стены.
func test_ports() -> void:
	eq(Maket.PORTS.size(), 3, "три порта")
	near(Maket.PORTS[1].x, 0.0, 0.001, "центральный по оси")
	near(Maket.EYE.y, Maket.PORT_Y, 0.001, "глаз на высоте портов")
	ok(Maket.EYE.z > Maket.PORT_Z0, "глаз за внутренней гранью стены")
	for i in [0, 2]:   # боковые не задевают центральный: |Δx| ≥ r_i + r_ц + 2·рама
		near(absf(Maket.PORTS[i].x), 1.15, 0.001, "боковой порт на ±1,15")
		ok(absf(Maket.PORTS[i].x - Maket.PORTS[1].x) >= Maket.PORTS[i].y + Maket.PORTS[1].y + 2.0 * Maket.RIM,
				"рамы не пересекаются")
	for port in Maket.PORTS:   # край рамы внутри передней стены (x ±3,3) и потолка 2,8
		ok(absf(port.x) + port.y + Maket.RIM <= 3.3, "порт с рамой внутри стены по x")
		ok(Maket.PORT_Y + port.y + Maket.RIM <= Maket.NOSE_H, "порт с рамой ниже потолка")
		ok(Maket.PORT_Y - port.y - Maket.RIM >= 0.0, "порт с рамой выше палубы")


## Рабочие точки постов и аварийной техники стоят (капсула Ø 0,7), кресла и стол — нет.
func test_stands() -> void:
	for st in [Maket.STAND_PILOT, Maket.STAND_ENGINEER, Maket.STAND_BIOLOG, Maket.STAND_SONAR, Maket.TECH_POST]:
		ok(Maket.can_stand(st.x, st.y), "рабочая точка стоит: %s" % str(st))
	for post in [Maket.POST_PILOT, Maket.POST_ENGINEER, Maket.POST_BIOLOG, Maket.TABLE]:
		ok(not Maket.can_stand(post.x, post.y), "мебель не проходима: %s" % str(post))
	ok(not Maket.can_stand(4.5, -8.0), "за бортом носовой зоны не стоит")
	ok(not Maket.can_stand(2.0, -3.0), "переборка не проходима вне люка")
	ok(Maket.can_stand(0.0, 2.0), "люк отсека проходим по оси")


## Путь соло: все маршруты проходимы, точки маршрутов стоят; соседние посты — 1,5…4 с
## (расчёт листа 03 — 2–3 с; пилот↔сонар выходит дольше из-за обхода стола — зафиксировано
## в tools/maket085.md), аварийные переходы в технику — до 10 с.
func test_walk() -> void:
	var res := Maket.walk_all()
	eq(res.size(), 12, "двенадцать маршрутов")
	for rname: String in res:
		var r: Dictionary = res[rname]
		ok(r["waypoints_ok"], "точки маршрута стоят: %s" % rname)
		ok(r["ok"], "маршрут проходим: %s" % rname)
		ok(r["time"] < 10.0, "время в разумных пределах: %s (%.1f с)" % [rname, r["time"]])
		ok(r["time"] > 0.5, "время не нулевое: %s" % rname)
	var near_routes := ["пилот → инженер", "инженер → пилот", "пилот → биолог", "биолог → пилот",
			"инженер → биолог", "биолог → сонар", "сонар → биолог", "пилот → сонар", "сонар → пилот"]
	for rname in near_routes:
		var r: Dictionary = res[rname]
		ok(r["time"] >= 1.5 and r["time"] <= 4.0, "межпостовый переход 1,5…4 с: %s (%.1f с)" % [rname, r["time"]])
	ok(res["пилот → сонар"]["time"] > res["пилот → инженер"]["time"], "обход стола длиннее прямого")


## Предел хода: на ровном дне точка хода на 8 м выше дна (3 м под полозьями + полозья на −5);
## без дна — глубокая вода.
func test_floor() -> void:
	var flat := func(_x: float, _z: float) -> float: return -60.0
	near(Maket.floor_at(Vector3(0, -50, 0), 0.0, flat), -52.0, 0.01, "ровное дно −60 → предел −52")
	eq(Maket.floor_at(Vector3.ZERO, 0.0, Callable()), Helm.Ship.DEEP, "без дна — DEEP")


## Врата 07: в проходе по оси на глубине сечения касания нет и зазор велик; снос на 30 м вбок — касание.
func test_arch() -> void:
	var f: float = GateArch.floor_y()
	var mid := Vector3(EcoGate.CENTER.x, f + 8.0, EcoGate.CENTER.y)   # точка хода: полозья на f + 3
	ok(not Maket.arch_hits(mid, 0.0), "по оси прохода касания нет")
	ok(Maket.arch_gap(mid, 0.0) > 5.0, "зазор по оси прохода больше 5 м")
	var side := mid + Vector3(30.0, 0.0, 0.0)
	ok(Maket.arch_hits(side, 0.0), "снос на 30 м вбок — опора твёрдая")
	ok(Maket.arch_gap(Vector3(EcoGate.CENTER.x + 400.0, -30.0, EcoGate.CENTER.y), 0.0) == INF,
			"вдали от врат зазор не считается")
	# наклон корпуса меняет зазор измеримо, но не роняет его в ноль по оси прохода
	var flat := Maket.arch_gap(mid, 0.0)
	var tilted := Maket.arch_gap(mid, 0.0, deg_to_rad(20.0))
	ok(tilted > 3.0, "с наклоном 20° зазор в проходе остаётся")
	ok(absf(tilted - flat) > 0.05, "наклон заметен в зазоре")


## Обзор гнезда купольника 07 из кресла пилота v3 (#1788, 18.11): угол взгляда вниз на гнездо
## против предела нижней кромки центрального порта (24,6°). Старая поза 57,5 м (прогон
## «к стоянке 37b (глубина макета)») — за кромкой (гнездо закрыто, замер пробы 18.11); соседняя
## точка уровней (мир (−81,5; −57,3; −213,1), курс −63°) — с запасом (проба потока А 18.11).
func test_gate_nest_view_angle() -> void:
	var nest := GateDiag.nest_pos(EcoDome.NEST)
	var limit := rad_to_deg(atan2(Maket.PORTS[1].y, Maket.EYE.z - Maket.PORT_Z1))
	near(limit, 24.6, 0.1, "предел нижней кромки порта 24,6°")
	var down := func(ship: Vector3, yaw_deg: float) -> float:
		var yaw := deg_to_rad(yaw_deg)
		var eye := Vector3(ship.x + Maket.EYE.z * sin(yaw), ship.y + Maket.EYE.y,
				ship.z + Maket.EYE.z * cos(yaw))
		var hor := Vector2(nest.x - eye.x, nest.z - eye.z).length()
		return rad_to_deg(atan2(eye.y - nest.y, hor))
	var old: float = down.call(Vector3(-77.2, -57.3, -215.3), -63.0)
	ok(old > limit, "старая поза 57,5 м за нижней кромкой (%.1f° > %.1f°)" % [old, limit])
	var cand: float = down.call(Vector3(-81.5, -57.3, -213.1), -63.0)
	ok(cand < limit, "точка уровней в просвете порта (%.1f° < %.1f°)" % [cand, limit])
	ok(limit - cand >= 2.0, "запас до кромки не меньше 2° (%.1f°)" % [limit - cand])


## Полный цикл смены поста и возвращения к управлению в соло (ГД, #1788 18.11): пилот сидит →
## встал → дошёл до поста → занял пост → встал → вернулся → сел. Маршруты проходимы, посадка —
## один шаг с рабочей точки и чисто от консолей, органы в досягаемости из позы оператора;
## по возвращении рукоятки пилота в зоне кисти (на подлокотниках, лист 03 v3).
func test_post_cycle() -> void:
	var res := Maket.cycle_all()
	eq(res.size(), 3, "три цикла к постам")
	for pname: String in res:
		var c: Dictionary = res[pname]
		ok(c["ok"], "цикл проходим: %s" % pname)
		ok(c["seat_clear"], "линия посадки не режет консоль: %s" % pname)
		ok(c["seat_dist"] <= 0.9, "посадка — один шаг: %s (%.2f м)" % [pname, c["seat_dist"]])
		ok(c["reach"] <= Maket.REACH_MAX, "орган поста в досягаемости: %s (%.2f м)" % [pname, c["reach"]])
		ok(c["t_cycle"] < 12.0, "цикл разумный: %s (%.1f с)" % [pname, c["t_cycle"]])
	near(res["инженер"]["reach"], res["биолог"]["reach"], 0.001, "посты симметричны по досягаемости")
	var grip := Maket.pilot_grip_reach()
	ok(grip <= Maket.REACH_OK, "рукоятки пилота в зоне кисти (%.2f м)" % grip)
	var tour := Maket.tour_all()
	ok(tour["ok"], "полный обход постов проходим")
	ok(tour["time"] < 20.0, "обход всех постов с возвратом < 20 с (%.1f)" % tour["time"])
