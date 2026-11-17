extends TestCase
## Фаза «замер» включена в игре (#1498, вариант 1 гейм-дизайнера): у каждого из трёх серпохвостов по умолчанию
## замер 4 с перед броском, после «потерял корабль» — отход 20 с. Проверки из описания #1498: все три хищника,
## свет после 30 с ожидания в темноте, повторный подход, свет рядом с уже присутствующим хищником, импульс сонара.

const FLAT := -40.0


static func _flat(_x: float, _z: float) -> float:
	return FLAT


## Мир с тремя хищниками по умолчанию; корабль далеко и тёмный.
func _world() -> Array:
	var w := EcoWorld.new()
	w.ground = _flat
	var ps := EcoPred.new()
	w.add(ps)
	w.ship.pos = Vector3(-300, -30, 300)
	w.ship.light_on = false
	return [w, ps]


## Хищник i голоден и готов; остальные уведены далеко; корабль тёмный в 25 м по +X от него.
func _near(i: int) -> Array:
	var r := _world()
	var w: EcoWorld = r[0]
	var ps: EcoPred = r[1]
	for j in ps.all.size():
		var o := ps.all[j]
		if j != i:
			o.agent.p = Vector3(600 + 100 * j, FLAT + 6.0, -600)
			o.cooldown = 999.0
	var pr := ps.all[i]
	pr.hunger = 0.5
	pr.cooldown = 0.0
	w.ship.pos = pr.agent.p + Vector3(25, 0, 0)
	return [w, pr, ps]


func _secs(w: EcoWorld, s: float) -> void:
	for k in int(round(s / EcoWorld.MAX_STEP)):
		w.step(EcoWorld.MAX_STEP)


func test_defaults_are_variant_1() -> void:
	var ps := EcoPred.new()
	near(ps.alert, 4.0, 1e-6, "замер 4 с")
	near(ps.alert_leave, 20.0, 1e-6, "отход 20 с")
	near(EcoPred.ALERT_LOSE_CD, 8.0, 1e-6, "пауза 8 с после отхода")


## Каждый из трёх: свет рядом — замер, а не бросок; свет горит 4 с — бросок.
func test_each_pred_alerts_then_charges() -> void:
	for i in 3:
		var r := _near(i)
		var w: EcoWorld = r[0]
		var pr: EcoPred.Pred = r[1]
		w.ship.light_on = true
		w.step(EcoWorld.MAX_STEP)
		eq(pr.mode, EcoPred.Mode.ALERT, "№%d: сначала замер" % i)
		_secs(w, 3.5)
		eq(pr.mode, EcoPred.Mode.ALERT, "№%d: замер держится 4 с" % i)
		_secs(w, 1.0)
		eq(pr.mode, EcoPred.Mode.CHARGE, "№%d: свет так и горит — бросок" % i)


## Каждый из трёх: экипаж гасит свет через 1,5 с — «потерял корабль», отход, броска нет.
func test_each_pred_answer_light_off() -> void:
	for i in 3:
		var r := _near(i)
		var w: EcoWorld = r[0]
		var pr: EcoPred.Pred = r[1]
		w.ship.light_on = true
		w.step(EcoWorld.MAX_STEP)
		_secs(w, 1.5)
		w.ship.light_on = false
		w.step(EcoWorld.MAX_STEP)
		eq(pr.mode, EcoPred.Mode.RETREAT, "№%d: потерял корабль — отходит" % i)
		for k in int(10.0 / EcoWorld.MAX_STEP):
			w.step(EcoWorld.MAX_STEP)
			ok(pr.mode != EcoPred.Mode.CHARGE, "№%d: в темноте не бросается" % i)
		ok(pr.agent.distance_to(w.ship.pos) > EcoPred.REACH, "№%d: за 10 с ушёл дальше чутья на свет" % i)


## Корабль 30 с стоит тёмный рядом с хищником, потом включает свет — замер с предупреждением, не мгновенный бросок.
func test_light_after_30s_wait_alerts_first() -> void:
	var r := _near(0)
	var w: EcoWorld = r[0]
	var pr: EcoPred.Pred = r[1]
	var ps: EcoPred = r[2]
	_secs(w, 30.0)
	ok(pr.mode != EcoPred.Mode.CHARGE, "тёмный корабль не манит")
	w.ship.pos = pr.agent.p + Vector3(25, 0, 0)   # хищник за 30 с ушёл по патрулю — корабль снова рядом
	pr.hunger = 0.5
	pr.cooldown = 0.0
	w.ship.light_on = true
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.ALERT, "свет после ожидания — замер")
	ok(ps.alert > 0.0)


## Повторный подход после отхода: корабль со светом догоняет того же хищника — снова замер, не бросок сразу.
func test_repeat_approach_alerts_again() -> void:
	var r := _near(1)
	var w: EcoWorld = r[0]
	var pr: EcoPred.Pred = r[1]
	w.ship.light_on = true
	w.step(EcoWorld.MAX_STEP)
	w.ship.light_on = false
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.RETREAT)
	_secs(w, 5.0)
	w.ship.light_on = true
	w.ship.pos = pr.agent.p + Vector3(20, 0, 0)
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.ALERT, "повторный подход — новый замер")


## Импульс сонара рядом — осознанная провокация: тоже замер с причиной «сонар», не бросок сразу.
func test_ping_alerts_with_reason() -> void:
	var r := _near(2)
	var w: EcoWorld = r[0]
	var pr: EcoPred.Pred = r[1]
	var ps: EcoPred = r[2]
	ps.on_ping(w, w.ship.pos)
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.ALERT, "импульс — замер")
	var text := ""
	for ev in w.bus.pending:
		if ev.species == EcoPred.ID and ev.note == "alert":
			text = ev.text()
	ok(text.contains("сонар"), "строка с причиной: %s" % text)


## Постановка шага `zamer` сценария тестера и `shot.gd zamer=` (#1498): хищник n в stage_spot — голодный, без паузы,
## остальные далеко с паузой; со светом мир сам начинает замер с игровыми числами, свет погас — отход.
func test_stage_near_alerts_with_game_numbers() -> void:
	var r := _world()
	var w: EcoWorld = r[0]
	var ps: EcoPred = r[1]
	var ship := Vector3(20, FLAT + 7.0, 22.5)
	w.ship.pos = ship
	w.ship.light_on = true
	var yaw := deg_to_rad(-15.0)
	var at := EcoPred.stage_spot(ship, yaw, "nos")
	ok(not ps.stage_near(ps.all.size(), at, ship), "нет такого хищника — false")
	ok(ps.stage_near(1, at, ship), "хищник 1 поставлен")
	var pr := ps.all[1]
	eq(pr.agent.p, at, "в точке постановки")
	near(Vector2(at.x - ship.x, at.z - ship.z).length(), EcoPred.STAGE_DIST, 1e-3, "26 м от корабля")
	ok(EcoPred.STAGE_DIST < EcoPred.REACH, "ближе дальности чутья")
	for o in ps.all:
		if o != pr:
			ok(o.agent.distance_to(ship) >= EcoPred.STAGE_FAR, "хищник %d уведён" % o.index)
			eq(o.cooldown, EcoPred.STAGE_CALM, "и не нападает")
	w.step(EcoWorld.MAX_STEP)
	eq(pr.mode, EcoPred.Mode.ALERT, "со светом — замер, не бросок")
	near(pr.agent.timer, EcoPred.ALERT_ON, 0.1, "замер по числам игры")
	w.ship.light_on = false
	_secs(w, 0.2)
	eq(pr.mode, EcoPred.Mode.RETREAT, "свет погас — отход")


## Сцена 00→01 (п. 2 (ав)): срочная строка «замер» (`pred/alert`, ранг `EcoLink.URGENT`, #1498) перебивает свежую
## строку фона сразу и держится все `MESSAGE_SECONDS`, пока идёт поток строк фона, — фон ждёт очереди (`next`),
## срочную не сменяет и не срезает до `MIN_SHOW`. Флаги строк — из мира (`take_link`), показ — `Status.Message`,
## как `Main._world_say`; фон — реальные заметки стоянки у 01 (`grazer/graze`, `grot/hide`), как в (аб).
## Шов «ранг мира × очередь под потоком фона» юнит-тестом очереди (`test_status.test_urgent_world_line_holds`)
## не покрыт: там флаги выставлены руками. Мутация: «alert» без ранга в `EcoLink.URGENT` — срочная ждёт очереди
## за строкой фона и сменяется следующей строкой фона, на приборах её нет вовсе. Без Main.
func test_alert_urgent_line_held_under_background_stream() -> void:
	var r := _near(0)
	var w: EcoWorld = r[0]
	var line_a := "Гребневики пасутся на мху у подножия рифа"
	var bg_texts := {   # поток фона после «замера» (+0,15 с, +0,30 с, +1,5 с, +3,0 с) — строки стоянки у 01, как в (аб)
		"Гребневики перешли на соседнее пятно мха": true,
		"Мелкая рыба: стая спряталась в рифе на спине гротовика, серпохвост её потерял": true,
		"Гребневики пасутся на мху у подножия рифа": true,
	}
	var msg := Status.Message.new()
	var shown: Array = []   # [текст, когда встал, сколько виден]
	var at := {"a": -1.0, "alert": -1.0}
	var stream_at: Array[float] = []
	var alert_text := ""
	var alert_urgent := false
	var bg_during := 0   # строки фона, пришедшие, пока на приборах «замер»
	var bg_i := 0
	var t := 0.0
	while t < 7.0:
		if at["a"] < 0.0 and t >= 0.499 and t < 1.5:
			w.emit(EcoGrazer.ID, "graze", w.ship.pos + Vector3(12, -4, 8), func(): return line_a)
		if not w.ship.light_on and t >= 0.799:
			w.ship.light_on = true   # голодный хищник в 25 м: «замер» на этом шаге
		if not stream_at.is_empty() and t >= stream_at[0] - 0.001:
			stream_at.remove_at(0)
			if bg_i == 0:
				w.emit(EcoGrazer.ID, "graze", w.ship.pos + Vector3(-8, -4, 10),
					func(): return "Гребневики перешли на соседнее пятно мха")
			elif bg_i == 1:
				w.emit(EcoGrot.ID, "hide", w.ship.pos + Vector3(10, -5, -7),
					func(): return "Мелкая рыба: стая спряталась в рифе на спине гротовика, серпохвост её потерял")
			elif bg_i == 2:
				w.emit(EcoGrazer.ID, "graze", w.ship.pos + Vector3(6, -4, -12), func(): return line_a)
			else:
				w.emit(EcoGrot.ID, "hide", w.ship.pos + Vector3(-12, -3, -6),
					func(): return "Мелкая рыба: стая спряталась в рифе на спине гротовика, серпохвост её потерял")
			bg_i += 1
		w.step(0.05)
		t += 0.05
		for e in w.take_link():
			if e.get("type") != EcoLink.MESSAGE and e.get("type") != EcoLink.OBSERVE:
				continue
			var text := String(e.get("text", ""))
			if text == "":
				continue
			if text == line_a and at["a"] < 0.0:
				at["a"] = t
			elif text.contains("замер") and at["alert"] < 0.0:
				at["alert"] = t
				alert_text = text
				alert_urgent = bool(e.get("urgent", false))
				stream_at.assign([t + 0.15, t + 0.30, t + 1.5, t + 3.0])
			elif not alert_text.is_empty() and msg.text == alert_text and bg_texts.has(text):
				bg_during += 1   # строка фона пришла, пока на приборах срочная
			msg.say(text, Status.MESSAGE_SECONDS, true, bool(e.get("urgent", false)), bool(e.get("keep", false)),
				bool(e.get("lead", false)))
		msg.update(0.05)
		if msg.text != "" and (shown.is_empty() or shown[-1][0] != msg.text):
			shown.append([msg.text, t, 0.0])
		if msg.text != "":
			shown[-1][2] = t - float(shown[-1][1]) + 0.05   # кадр t виден до следующего шага
	var a_seen := 0.0
	var alert_seen := 0.0
	for s: Array in shown:
		if String(s[0]).contains("замер"):
			alert_seen = maxf(alert_seen, float(s[2]))
		elif String(s[0]) == line_a:
			a_seen = maxf(a_seen, float(s[2]))
	var lines := PackedStringArray()
	for s: Array in shown:
		lines.append("%.2f с «%s» %.2f с" % [s[1], String(s[0]).left(40), s[2]])
	print("    «замер» пришёл на %.2f с (фон на %.2f с), фона при срочной %d; на приборах: %s" % [
		at["alert"], at["a"], bg_during, " | ".join(lines)])
	ok(at["a"] > 0.0 and at["alert"] > 0.0, "строка фона и «замер» пришли")
	ok(at["a"] < at["alert"], "фон был на приборах, когда пришла срочная — прерывание реальное")
	ok(a_seen < Status.Message.MIN_SHOW, "срочная перебила свежую строку фона (та видна %.2f с < MIN_SHOW)" % a_seen)
	ok(alert_urgent, "«замер» пришёл с рангом «срочная» (EcoLink.URGENT)")
	ok(bg_during >= 3, "пока виден «замер», пришёл поток фона (%d строки) — проверка не пустая" % bg_during)
	ok(alert_seen >= Status.MESSAGE_SECONDS - 0.051, "срочная строка видна все %.1f с (по факту %.2f с)" % [
		Status.MESSAGE_SECONDS, alert_seen])
