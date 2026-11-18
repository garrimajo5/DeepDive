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


## Сцена 00→01 (п. 2 (аг)): отбой «потерял корабль» (`pred/lost`, ведущая «держится» `EcoLink.KEEP_LEAD`, #1966) —
## единственный знак «угроза ушла» для того, кто не слышит щелчков: по ней включают свет. Постановка как в (ав):
## свет погас во «замере» — отбой приходит, пока на приборах срочная «замер», и ждёт очереди. Ждущий отбой под
## потоком строк фона (как в (аб)) не сменяет ни фон (`grazer/graze`, `grot/hide`), ни другая «держится» — бегство
## рыб (`fish/flee`, `EcoLink.KEEP` без ведущего ранга); а выйдя на приборы, держится все `MESSAGE_SECONDS` — фон
## ждёт очереди (`next`). Флаги строк — из мира (`take_link`), показ — `Status.Message`, как `Main._world_say`.
## Шов «ранг мира × очередь под потоком фона» юнит-тестами не покрыт: в `test_status.test_message_lead_keeps_queue`
## флаги выставлены руками, `test_eco_link.test_keep_lost_line` проверяет только таблицу рангов. Мутация: «lost»
## без ранга в `EcoLink.KEEP_LEAD` — ждущий отбой сменяет бегство рыб, отбоя на приборах нет вовсе. Без Main.
func test_lost_lead_line_held_under_background_stream() -> void:
	var r := _near(0)
	var w: EcoWorld = r[0]
	var line_a := "Гребневики пасутся на мху у подножия рифа"
	var flee_line := "Мелкая рыба: стая уходит в кораллы — рядом хищник"
	var bg_texts := {   # поток фона: у ждущего отбоя (+0,15 с, +0,30 с) и у видимого (+0,15 с, +0,30 с, +1,5 с, +3,0 с) — строки стоянки у 01, как в (аб)
		"Гребневики перешли на соседнее пятно мха": true,
		"Мелкая рыба: стая спряталась в рифе на спине гротовика, серпохвост её потерял": true,
		"Гребневики пасутся на мху у подножия рифа": true,
	}
	var msg := Status.Message.new()
	var shown: Array = []   # [текст, когда встал, сколько виден]
	var at := {"a": -1.0, "alert": -1.0, "lost": -1.0}
	var wait_stream: Array[float] = []   # фон и бегство рыб, наступающие на ждущий отбой
	var show_stream: Array[float] = []   # фон, наступающий на видимый отбой
	var wait_i := 0
	var show_i := 0
	var lost_text := ""
	var lost_keep := false
	var lost_lead := false
	var waiting_bg := 0   # строки фона, пришедшие, пока отбой ждал очереди
	var waiting_flee := 0   # другая «держится» у ждущего отбоя
	var shown_bg := 0   # строки фона, пришедшие, пока отбой на приборах
	var t := 0.0
	while t < 10.5:
		if at["a"] < 0.0 and t >= 0.499 and t < 1.5:
			w.emit(EcoGrazer.ID, "graze", w.ship.pos + Vector3(12, -4, 8), func(): return line_a)
		if not w.ship.light_on and at["lost"] < 0.0 and t >= 0.799 and t < 2.0:
			w.ship.light_on = true   # голодный хищник в 25 м: «замер» на этом шаге
		if w.ship.light_on and at["alert"] > 0.0 and t >= 2.299:
			w.ship.light_on = false   # свет погас во «замере» — отбой на этом шаге
		if not wait_stream.is_empty() and t >= wait_stream[0] - 0.001:
			wait_stream.remove_at(0)
			if wait_i == 2:
				w.emit(EcoFish.ID, "flee", w.ship.pos + Vector3(15, -3, 10), func(): return flee_line)
			elif wait_i == 0:
				w.emit(EcoGrazer.ID, "graze", w.ship.pos + Vector3(-8, -4, 10),
					func(): return "Гребневики перешли на соседнее пятно мха")
			else:
				w.emit(EcoGrot.ID, "hide", w.ship.pos + Vector3(10, -5, -7),
					func(): return "Мелкая рыба: стая спряталась в рифе на спине гротовика, серпохвост её потерял")
			wait_i += 1
		if not show_stream.is_empty() and t >= show_stream[0] - 0.001:
			show_stream.remove_at(0)
			if show_i % 2 == 0:
				w.emit(EcoGrazer.ID, "graze", w.ship.pos + Vector3(6, -4, -12), func(): return line_a)
			else:
				w.emit(EcoGrot.ID, "hide", w.ship.pos + Vector3(-12, -3, -6),
					func(): return "Мелкая рыба: стая спряталась в рифе на спине гротовика, серпохвост её потерял")
			show_i += 1
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
			elif text.contains("потерял корабль") and at["lost"] < 0.0:
				at["lost"] = t
				lost_text = text
				lost_keep = bool(e.get("keep", false))
				lost_lead = bool(e.get("lead", false))
				wait_stream.assign([t + 0.15, t + 0.30, t + 0.45])
			elif not lost_text.is_empty() and bg_texts.has(text):
				if msg.next == lost_text:
					waiting_bg += 1   # строка фона пришла, пока отбой ждал очереди
				if msg.text == lost_text:
					shown_bg += 1   # строка фона пришла, пока отбой на приборах
			elif text == flee_line and not lost_text.is_empty() and msg.next == lost_text:
				waiting_flee += 1   # другая «держится» наступила на ждущий отбой
			msg.say(text, Status.MESSAGE_SECONDS, true, bool(e.get("urgent", false)), bool(e.get("keep", false)),
				bool(e.get("lead", false)))
		msg.update(0.05)
		if not lost_text.is_empty() and msg.text == lost_text and show_i == 0 and show_stream.is_empty():
			show_stream.assign([t + 0.15, t + 0.30, t + 1.5, t + 3.0])   # отбой вышел — фон наступает на него
		if msg.text != "" and (shown.is_empty() or shown[-1][0] != msg.text):
			shown.append([msg.text, t, 0.0])
		if msg.text != "":
			shown[-1][2] = t - float(shown[-1][1]) + 0.05   # кадр t виден до следующего шага
	var lost_seen := 0.0
	var flee_seen := 0.0
	for s: Array in shown:
		if String(s[0]) == lost_text and not lost_text.is_empty():
			lost_seen = maxf(lost_seen, float(s[2]))
		elif String(s[0]) == flee_line:
			flee_seen = maxf(flee_seen, float(s[2]))
	var lines := PackedStringArray()
	for s: Array in shown:
		lines.append("%.2f с «%s» %.2f с" % [s[1], String(s[0]).left(40), s[2]])
	print("    отбой пришёл на %.2f с («замер» на %.2f с), у ждущего фона %d и бегство %d, фона при видимом отбое %d; на приборах: %s" % [
		at["lost"], at["alert"], waiting_bg, waiting_flee, shown_bg, " | ".join(lines)])
	ok(at["a"] > 0.0 and at["alert"] > 0.0 and at["lost"] > 0.0, "строка фона, «замер» и отбой пришли")
	ok(at["alert"] < at["lost"], "отбой пришёл во время показа «замера» — ждал очереди")
	ok(lost_keep and lost_lead, "отбой пришёл ведущей «держится» (EcoLink.KEEP_LEAD)")
	eq(waiting_bg, 2, "пока отбой ждал, наступал фон (%d) — проверка не пустая" % waiting_bg)
	eq(waiting_flee, 1, "пока отбой ждал, наступала другая «держится» — бегство рыб")
	ok(shown_bg >= 3, "пока отбой виден, пришёл поток фона (%d строки) — проверка не пустая" % shown_bg)
	eq(flee_seen, 0.0, "бегство рыб ждущий отбой не сменило и на приборы не вышло")
	ok(lost_seen >= Status.MESSAGE_SECONDS - 0.051, "отбой виден все %.1f с (по факту %.2f с)" % [
		Status.MESSAGE_SECONDS, lost_seen])


## Сцена 00→01 (п. 2 (ад)): после «потерял корабль» экипаж по отбою снова включает свет и догоняет того же
## хищника — пока тот в отходе (`pr.wary`), он сразу даёт новый «замер» (`pred/alert`, ранг `EcoLink.URGENT`,
## #1498). Прежний отбой уже не описывает ситуацию (ГД, #1968): срочная срезает ВИДИМЫЙ отбой сразу, не
## дожидаясь его `MESSAGE_SECONDS`, — отбой виден меньше своих секунд, новый «замер» держится все свои, поток
## фона (строки стоянки у 01, как в (аб)) ждёт очереди (`next`). Постановка как в (аг): свет погас во «замере»
## — отбой приходит и ждёт очереди за срочной, выходит на приборы; свет снова — новый «замер». Флаги строк —
## из мира (`take_link`), показ — `Status.Message`, как `Main._world_say`. Шов «срочная × видимая ведущая
## „держится"» юнит-тестами не покрыт: `test_message_alert_drops_waiting_lead` (#1979) — про ЖДУЩИЙ отбой,
## `test_message_lead_keeps_queue` флаги выставляет руками. Мутация: «alert» без ранга в `EcoLink.URGENT` —
## новый «замер» ждёт очереди за видимым отбоем и выходит на ~3,2 с позже, отбой виден все свои секунды. Без Main.
func test_new_alert_cuts_visible_lost_line() -> void:
	var r := _near(0)
	var w: EcoWorld = r[0]
	var pr: EcoPred.Pred = r[1]
	var line_a := "Гребневики пасутся на мху у подножия рифа"
	var bg_texts := {   # поток фона у видимого второго «замера» (+0,15 с, +0,30 с, +1,5 с, +3,0 с) — строки стоянки у 01, как в (аб)
		"Гребневики перешли на соседнее пятно мха": true,
		"Мелкая рыба: стая спряталась в рифе на спине гротовика, серпохвост её потерял": true,
		"Гребневики пасутся на мху у подножия рифа": true,
	}
	var msg := Status.Message.new()
	var shown: Array = []   # [текст, когда встал, сколько виден]
	var at := {"alert": -1.0, "lost": -1.0, "alert2": -1.0}
	var lost_text := ""
	var alert2_text := ""
	var alert2_urgent := false
	var lost_out_at := -1.0   # когда отбой встал на приборы
	var bg2_stream: Array[float] = []   # фон, наступающий на видимый второй «замер»
	var bg2_i := 0
	var bg2_during := 0   # строки фона, пришедшие, пока на приборах второй «замер»
	var t := 0.0
	while t < 11.5:
		if not w.ship.light_on and at["alert"] < 0.0 and t >= 0.799 and t < 1.5:
			w.ship.light_on = true   # голодный хищник в 25 м: первый «замер» на этом шаге
		if w.ship.light_on and at["alert"] > 0.0 and at["lost"] < 0.0 and t >= 2.299:
			w.ship.light_on = false   # свет погас во «замере» — отбой на этом шаге
		if not w.ship.light_on and lost_out_at > 0.0 and at["alert2"] < 0.0 and t >= lost_out_at + 1.0:
			w.ship.pos = pr.agent.p + Vector3(20, 0, 0)   # догнали отходящего хищника
			w.ship.light_on = true   # свет снова — сразу новый «замер» (wary, RETREAT)
		if not bg2_stream.is_empty() and t >= bg2_stream[0] - 0.001:
			bg2_stream.remove_at(0)
			if bg2_i % 3 == 0:
				w.emit(EcoGrazer.ID, "graze", w.ship.pos + Vector3(-8, -4, 10),
					func(): return "Гребневики перешли на соседнее пятно мха")
			elif bg2_i % 3 == 1:
				w.emit(EcoGrot.ID, "hide", w.ship.pos + Vector3(10, -5, -7),
					func(): return "Мелкая рыба: стая спряталась в рифе на спине гротовика, серпохвост её потерял")
			else:
				w.emit(EcoGrazer.ID, "graze", w.ship.pos + Vector3(6, -4, -12), func(): return line_a)
			bg2_i += 1
		w.step(0.05)
		t += 0.05
		for e in w.take_link():
			if e.get("type") != EcoLink.MESSAGE and e.get("type") != EcoLink.OBSERVE:
				continue
			var text := String(e.get("text", ""))
			if text == "":
				continue
			if text.contains("потерял корабль") and at["lost"] < 0.0:
				at["lost"] = t
				lost_text = text
			elif text.contains("замер") and at["alert"] < 0.0:
				at["alert"] = t
			elif text.contains("замер") and at["lost"] > 0.0 and at["alert2"] < 0.0:
				at["alert2"] = t
				alert2_text = text
				alert2_urgent = bool(e.get("urgent", false))
			elif not alert2_text.is_empty() and at["alert2"] > 0.0 and msg.text == alert2_text \
					and bg_texts.has(text):
				bg2_during += 1   # строка фона пришла, пока на приборах второй «замер»
			msg.say(text, Status.MESSAGE_SECONDS, true, bool(e.get("urgent", false)), bool(e.get("keep", false)),
				bool(e.get("lead", false)))
		msg.update(0.05)
		if not lost_text.is_empty() and lost_out_at < 0.0 and msg.text == lost_text:
			lost_out_at = t   # отбой вышел на приборы
		if at["alert2"] > 0.0 and not alert2_text.is_empty() and msg.text == alert2_text and bg2_i == 0 \
				and bg2_stream.is_empty():
			bg2_stream.assign([t + 0.15, t + 0.30, t + 1.5, t + 3.0])   # второй «замер» вышел — фон наступает
		if msg.text != "" and (shown.is_empty() or shown[-1][0] != msg.text):
			shown.append([msg.text, t, 0.0])
		if msg.text != "":
			shown[-1][2] = t - float(shown[-1][1]) + 0.05   # кадр t виден до следующего шага
	var lost_seen := 0.0
	var lost_shown_at := -1.0
	var alert2_seen := 0.0
	var alert2_shown_at := -1.0
	var after_lost := ""
	for i in shown.size():
		var s: Array = shown[i]
		var txt := String(s[0])
		if not lost_text.is_empty() and txt == lost_text:
			lost_seen = maxf(lost_seen, float(s[2]))
			if lost_shown_at < 0.0:
				lost_shown_at = float(s[1])
			if i + 1 < shown.size():
				after_lost = String(shown[i + 1][0])
		elif txt.contains("замер") and float(s[1]) > at["alert"]:
			alert2_seen = maxf(alert2_seen, float(s[2]))
			if alert2_shown_at < 0.0:
				alert2_shown_at = float(s[1])
	var lines := PackedStringArray()
	for s: Array in shown:
		lines.append("%.2f с «%s» %.2f с" % [s[1], String(s[0]).left(40), s[2]])
	print("    «замер» %.2f с, отбой %.2f с (на приборах %.2f с), новый «замер» %.2f с (на приборах %.2f с, ждал %.2f с), фона при нём %d; на приборах: %s" % [
		at["alert"], at["lost"], lost_shown_at, at["alert2"], alert2_shown_at, alert2_shown_at - at["alert2"],
		bg2_during, " | ".join(lines)])
	ok(at["alert"] > 0.0 and at["lost"] > 0.0 and at["alert2"] > 0.0, "«замер», отбой и новый «замер» пришли")
	ok(at["alert"] < at["lost"] and at["lost"] < at["alert2"], "порядок: «замер» → отбой → новый «замер»")
	ok(lost_shown_at > 0.0 and lost_shown_at < at["alert2"], "отбой уже был на приборах, когда пришёл новый «замер»")
	ok(alert2_shown_at - at["alert2"] <= 0.051, "новый «замер» срезал отбой сразу (ждал %.2f с)" % [
		alert2_shown_at - at["alert2"]])
	ok(lost_seen > 0.0 and lost_seen < Status.MESSAGE_SECONDS, "отбой виден меньше своих %.1f с (по факту %.2f с)" % [
		Status.MESSAGE_SECONDS, lost_seen])
	ok(after_lost.contains("замер"), "сразу за срезанным отбоем на приборах — новый «замер», не фон")
	ok(alert2_urgent, "новый «замер» пришёл с рангом «срочная» (EcoLink.URGENT)")
	ok(bg2_during >= 3, "пока виден новый «замер», пришёл поток фона (%d строки) — проверка не пустая" % bg2_during)
	ok(alert2_seen >= Status.MESSAGE_SECONDS - 0.051, "новый «замер» виден все %.1f с (по факту %.2f с)" % [
		Status.MESSAGE_SECONDS, alert2_seen])


## Сцена 00→01 (п. 2 (ае)): ждущее бегство рыб у 01 (`fish/flee`, «держится» `EcoLink.KEEP` без ведущего
## ранга) при новой срочной «замер» (`pred/alert`, `EcoLink.URGENT`) НЕ устаревает и не теряется — в отличие
## от ждущего отбоя (#1968, PR #1979): бегство — про угрозу, которая длится (хищник рядом, стая уходит),
## а не про прошедшую. Постановка: бегство приходит, пока на приборах свежая строка фона, и ждёт очереди
## (`next`); тут же голодный хищник даёт «замер» — срочная выходит сразу и держится все свои секунды,
## бегство выходит следом за ней и держится свои `MESSAGE_SECONDS`; поток фона (строки стоянки у 01, как
## в (аб)) ждёт очереди. Флаги строк — из мира (`take_link`), показ — `Status.Message`, как `Main._world_say`.
## Шов «срочная × ждущая „держится" без ведущего ранга» юнит-тестами не покрыт:
## `test_message_alert_drops_waiting_lead` (#1979) — про ждущий отбой (не ведущая там только поставлена
## под «замер», выход её не проверен), `test_message_lead_keeps_queue` флаги выставляет руками. Мутация:
## в `Status.Message.say` ветка срочной дропает ждущее (`next`) безусловно — бегства на приборах нет вовсе.
## Без Main.
func test_pending_flee_survives_new_alert() -> void:
	var r := _near(0)
	var w: EcoWorld = r[0]
	var line_a := "Гребневики пасутся на мху у подножия рифа"
	var flee_line := "Мелкая рыба: стая уходит в кораллы — рядом хищник"
	var bg_texts := {   # поток фона у видимого бегства (+0,15 с, +0,30 с, +1,5 с, +3,0 с) — строки стоянки у 01, как в (аб)
		"Гребневики перешли на соседнее пятно мха": true,
		"Мелкая рыба: стая спряталась в рифе на спине гротовика, серпохвост её потерял": true,
		"Гребневики пасутся на мху у подножия рифа": true,
	}
	var msg := Status.Message.new()
	var shown: Array = []   # [текст, когда встал, сколько виден]
	var at := {"a": -1.0, "flee": -1.0, "alert": -1.0}
	var flee_keep := false
	var flee_lead := false
	var alert_urgent := false
	var flee_waiting_at_alert := false   # в момент прихода срочной бегство ждало очереди
	var flee_stream: Array[float] = []   # фон, наступающий на видимое бегство
	var flee_i := 0
	var bg_during_flee := 0   # строки фона, пришедшие, пока на приборах бегство
	var t := 0.0
	while t < 10.5:
		if at["a"] < 0.0 and t >= 0.499 and t < 0.6:
			w.emit(EcoGrazer.ID, "graze", w.ship.pos + Vector3(12, -4, 8), func(): return line_a)
		if at["a"] > 0.0 and at["flee"] < 0.0 and t >= 0.649 and t < 1.5:
			w.emit(EcoFish.ID, "flee", w.ship.pos + Vector3(15, -3, 10), func(): return flee_line)
		if not w.ship.light_on and at["flee"] > 0.0 and t >= 0.799:
			w.ship.light_on = true   # голодный хищник в 25 м: «замер» на этом шаге
		if not flee_stream.is_empty() and t >= flee_stream[0] - 0.001:
			flee_stream.remove_at(0)
			if flee_i % 3 == 0:
				w.emit(EcoGrazer.ID, "graze", w.ship.pos + Vector3(-8, -4, 10),
					func(): return "Гребневики перешли на соседнее пятно мха")
			elif flee_i % 3 == 1:
				w.emit(EcoGrot.ID, "hide", w.ship.pos + Vector3(10, -5, -7),
					func(): return "Мелкая рыба: стая спряталась в рифе на спине гротовика, серпохвост её потерял")
			else:
				w.emit(EcoGrazer.ID, "graze", w.ship.pos + Vector3(6, -4, -12), func(): return line_a)
			flee_i += 1
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
			elif text == flee_line and at["flee"] < 0.0:
				at["flee"] = t
				flee_keep = bool(e.get("keep", false))
				flee_lead = bool(e.get("lead", false))
			elif text.contains("замер") and at["alert"] < 0.0:
				at["alert"] = t
				alert_urgent = bool(e.get("urgent", false))
				flee_waiting_at_alert = msg.next == flee_line   # бегство ждало очереди, когда пришла срочная
			elif at["flee"] > 0.0 and msg.text == flee_line and bg_texts.has(text):
				bg_during_flee += 1   # строка фона пришла, пока на приборах бегство
			msg.say(text, Status.MESSAGE_SECONDS, true, bool(e.get("urgent", false)), bool(e.get("keep", false)),
				bool(e.get("lead", false)))
		msg.update(0.05)
		if at["flee"] > 0.0 and msg.text == flee_line and flee_i == 0 and flee_stream.is_empty():
			flee_stream.assign([t + 0.15, t + 0.30, t + 1.5, t + 3.0])   # бегство вышло — фон наступает на него
		if msg.text != "" and (shown.is_empty() or shown[-1][0] != msg.text):
			shown.append([msg.text, t, 0.0])
		if msg.text != "":
			shown[-1][2] = t - float(shown[-1][1]) + 0.05   # кадр t виден до следующего шага
	var a_seen := 0.0
	var alert_seen := 0.0
	var alert_shown_at := -1.0
	var flee_seen := 0.0
	var flee_shown_at := -1.0
	var after_alert := ""
	for i in shown.size():
		var s: Array = shown[i]
		var txt := String(s[0])
		if txt == line_a:
			a_seen = maxf(a_seen, float(s[2]))
		elif txt.contains("замер"):
			alert_seen = maxf(alert_seen, float(s[2]))
			if alert_shown_at < 0.0:
				alert_shown_at = float(s[1])
			if i + 1 < shown.size():
				after_alert = String(shown[i + 1][0])
		elif txt == flee_line:
			flee_seen = maxf(flee_seen, float(s[2]))
			if flee_shown_at < 0.0:
				flee_shown_at = float(s[1])
	var lines := PackedStringArray()
	for s: Array in shown:
		lines.append("%.2f с «%s» %.2f с" % [s[1], String(s[0]).left(40), s[2]])
	print("    фон %.2f с, бегство %.2f с (ждало при срочной: %s), «замер» %.2f с (на приборах %.2f с), бегство на приборах %.2f с, фона при нём %d; на приборах: %s" % [
		at["a"], at["flee"], flee_waiting_at_alert, at["alert"], alert_shown_at, flee_shown_at, bg_during_flee,
		" | ".join(lines)])
	ok(at["a"] > 0.0 and at["flee"] > 0.0 and at["alert"] > 0.0, "фон, бегство и «замер» пришли")
	ok(at["a"] < at["flee"] and at["flee"] < at["alert"], "порядок: фон → бегство → «замер»")
	ok(flee_keep and not flee_lead, "бегство пришло «держится» без ведущего ранга (EcoLink.KEEP)")
	ok(flee_waiting_at_alert, "в момент прихода срочной бегство ждало очереди (next) — постановка реальная")
	ok(alert_urgent, "«замер» пришёл с рангом «срочная» (EcoLink.URGENT)")
	ok(a_seen < Status.Message.MIN_SHOW, "срочная перебила свежую строку фона (та видна %.2f с < MIN_SHOW)" % a_seen)
	ok(alert_shown_at - at["alert"] <= 0.051, "срочная вышла на приборы сразу (ждала %.2f с)" % [
		alert_shown_at - at["alert"]])
	ok(alert_seen >= Status.MESSAGE_SECONDS - 0.051, "срочная видна все %.1f с (по факту %.2f с)" % [
		Status.MESSAGE_SECONDS, alert_seen])
	ok(flee_shown_at >= alert_shown_at + Status.MESSAGE_SECONDS - 0.051,
		"бегство вышло следом за срочной (на приборах %.2f с, срочная с %.2f с)" % [flee_shown_at, alert_shown_at])
	eq(after_alert, flee_line, "сразу за срочной на приборах — бегство, не фон")
	ok(bg_during_flee >= 3, "пока видно бегство, пришёл поток фона (%d строки) — проверка не пустая" % bg_during_flee)
	ok(flee_seen >= Status.MESSAGE_SECONDS - 0.051, "бегство видно все свои %.1f с (по факту %.2f с)" % [
		Status.MESSAGE_SECONDS, flee_seen])


## Сцена 00→01 (п. 2 (аф)): ВИДИМОЕ бегство рыб у 01 (`fish/flee`, «держится» `EcoLink.KEEP` без ведущего
## ранга) при новой срочной «замер» (`pred/alert`, `EcoLink.URGENT`) срезается сразу, не дожидаясь своих
## `MESSAGE_SECONDS` («срочная её перебивает сразу», `Status.Message`), и назад не возвращается — зеркало
## (ае): ждущее бегство переживает срочную, видимое — нет (угроза важнее последствия, которое уже показано).
## Постановка как в (ае), но бегство уже на приборах и держится, когда приходит срочная: фон, за ним бегство
## (ждало очереди за свежим фоном, вышло на приборы), тут же голодный хищник даёт «замер» — срочная выходит
## сразу и держится все свои секунды, бегство видно меньше своих и после срочной не возвращается (дальше —
## фон из очереди). Поток фона (строки стоянки у 01, как в (аб)) наступает на видимую срочную и ждёт очереди
## (`next`). Флаги строк — из мира (`take_link`), показ — `Status.Message`, как `Main._world_say`. Шов
## «срочная × ВИДИМАЯ „держится" без ведущего ранга» юнит-тестами не покрыт: `test_urgent_world_line_holds`
## и `test_keep_world_line_holds` флаги выставляют руками, (ад) — про видимый отбой (ведущая «держится»),
## (ае) — про ЖДУЩЕЕ бегство. Мутация: «alert» без ранга в `EcoLink.URGENT` — срочная ждёт очереди за
## видимым бегством и выходит на ~3,65 с позже, бегство видно все свои секунды. Без Main.
func test_new_alert_cuts_visible_flee_line() -> void:
	var r := _near(0)
	var w: EcoWorld = r[0]
	var line_a := "Гребневики пасутся на мху у подножия рифа"
	var flee_line := "Мелкая рыба: стая уходит в кораллы — рядом хищник"
	var bg_texts := {   # поток фона у видимой срочной (+0,15 с, +0,30 с, +1,5 с, +3,0 с) — строки стоянки у 01, как в (аб)
		"Гребневики перешли на соседнее пятно мха": true,
		"Мелкая рыба: стая спряталась в рифе на спине гротовика, серпохвост её потерял": true,
		"Гребневики пасутся на мху у подножия рифа": true,
	}
	var msg := Status.Message.new()
	var shown: Array = []   # [текст, когда встал, сколько виден]
	var at := {"a": -1.0, "flee": -1.0, "alert": -1.0}
	var flee_keep := false
	var flee_lead := false
	var alert_urgent := false
	var alert_text := ""
	var flee_visible_at_alert := false   # в момент прихода срочной бегство было на приборах
	var bg_stream: Array[float] = []   # фон, наступающий на видимую срочную
	var bg_i := 0
	var bg_during := 0   # строки фона, пришедшие, пока на приборах срочная
	var t := 0.0
	while t < 10.0:
		if at["a"] < 0.0 and t >= 0.499 and t < 0.6:
			w.emit(EcoGrazer.ID, "graze", w.ship.pos + Vector3(12, -4, 8), func(): return line_a)
		if at["a"] > 0.0 and at["flee"] < 0.0 and t >= 0.649 and t < 1.5:
			w.emit(EcoFish.ID, "flee", w.ship.pos + Vector3(15, -3, 10), func(): return flee_line)
		if not w.ship.light_on and at["flee"] > 0.0 and t >= 1.999:
			w.ship.light_on = true   # голодный хищник в 25 м: «замер» на этом шаге
		if not bg_stream.is_empty() and t >= bg_stream[0] - 0.001:
			bg_stream.remove_at(0)
			if bg_i % 3 == 0:
				w.emit(EcoGrazer.ID, "graze", w.ship.pos + Vector3(-8, -4, 10),
					func(): return "Гребневики перешли на соседнее пятно мха")
			elif bg_i % 3 == 1:
				w.emit(EcoGrot.ID, "hide", w.ship.pos + Vector3(10, -5, -7),
					func(): return "Мелкая рыба: стая спряталась в рифе на спине гротовика, серпохвост её потерял")
			else:
				w.emit(EcoGrazer.ID, "graze", w.ship.pos + Vector3(6, -4, -12), func(): return line_a)
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
			elif text == flee_line and at["flee"] < 0.0:
				at["flee"] = t
				flee_keep = bool(e.get("keep", false))
				flee_lead = bool(e.get("lead", false))
			elif text.contains("замер") and at["alert"] < 0.0:
				at["alert"] = t
				alert_text = text
				alert_urgent = bool(e.get("urgent", false))
				flee_visible_at_alert = msg.text == flee_line   # бегство было на приборах, когда пришла срочная
			elif not alert_text.is_empty() and msg.text == alert_text and bg_texts.has(text):
				bg_during += 1   # строка фона пришла, пока на приборах срочная
			msg.say(text, Status.MESSAGE_SECONDS, true, bool(e.get("urgent", false)), bool(e.get("keep", false)),
				bool(e.get("lead", false)))
		msg.update(0.05)
		if not alert_text.is_empty() and msg.text == alert_text and bg_i == 0 and bg_stream.is_empty():
			bg_stream.assign([t + 0.15, t + 0.30, t + 1.5, t + 3.0])   # срочная вышла — фон наступает на неё
		if msg.text != "" and (shown.is_empty() or shown[-1][0] != msg.text):
			shown.append([msg.text, t, 0.0])
		if msg.text != "":
			shown[-1][2] = t - float(shown[-1][1]) + 0.05   # кадр t виден до следующего шага
	var flee_seen := 0.0
	var flee_shown_at := -1.0
	var flee_entries := 0
	var after_flee := ""
	var alert_seen := 0.0
	var alert_shown_at := -1.0
	for i in shown.size():
		var s: Array = shown[i]
		var txt := String(s[0])
		if txt == flee_line:
			flee_seen = maxf(flee_seen, float(s[2]))
			flee_entries += 1
			if flee_shown_at < 0.0:
				flee_shown_at = float(s[1])
			if i + 1 < shown.size():
				after_flee = String(shown[i + 1][0])
		elif txt.contains("замер"):
			alert_seen = maxf(alert_seen, float(s[2]))
			if alert_shown_at < 0.0:
				alert_shown_at = float(s[1])
	var lines := PackedStringArray()
	for s: Array in shown:
		lines.append("%.2f с «%s» %.2f с" % [s[1], String(s[0]).left(40), s[2]])
	print("    фон %.2f с, бегство %.2f с (на приборах %.2f с, было видно при срочной: %s), «замер» %.2f с (на приборах %.2f с, ждал %.2f с), фона при нём %d; на приборах: %s" % [
		at["a"], at["flee"], flee_shown_at, flee_visible_at_alert, at["alert"], alert_shown_at,
		alert_shown_at - at["alert"], bg_during, " | ".join(lines)])
	ok(at["a"] > 0.0 and at["flee"] > 0.0 and at["alert"] > 0.0, "фон, бегство и «замер» пришли")
	ok(at["a"] < at["flee"] and at["flee"] < at["alert"], "порядок: фон → бегство → «замер»")
	ok(flee_keep and not flee_lead, "бегство пришло «держится» без ведущего ранга (EcoLink.KEEP)")
	ok(flee_shown_at > 0.0 and flee_shown_at < at["alert"], "бегство уже было на приборах, когда пришла срочная")
	ok(flee_visible_at_alert, "в момент прихода срочной бегство было на приборах и держалось — постановка реальная")
	ok(alert_urgent, "«замер» пришёл с рангом «срочная» (EcoLink.URGENT)")
	ok(alert_shown_at - at["alert"] <= 0.051, "срочная срезала видимое бегство сразу (ждала %.2f с)" % [
		alert_shown_at - at["alert"]])
	ok(flee_seen > 0.0 and flee_seen < Status.MESSAGE_SECONDS,
		"бегство видно меньше своих %.1f с (по факту %.2f с)" % [Status.MESSAGE_SECONDS, flee_seen])
	ok(after_flee.contains("замер"), "сразу за срезанным бегством на приборах — срочная, не фон")
	ok(alert_seen >= Status.MESSAGE_SECONDS - 0.051, "срочная видна все %.1f с (по факту %.2f с)" % [
		Status.MESSAGE_SECONDS, alert_seen])
	eq(flee_entries, 1, "бегство на приборы не вернулось (показано %d раза)" % flee_entries)
	ok(bg_during >= 3, "пока видна срочная, пришёл поток фона (%d строки) — проверка не пустая" % bg_during)


## Сцена 00→01 (п. 2 (ах)): кормёжка серпохвоста (`pred/catch`, «держится» `EcoLink.KEEP` без ведущего ранга —
## флаги таблицы проверяет и `test_eco_link.test_keep_lost_line`) — такое же последствие угрозы, как бегство рыб
## (аб): ждущую кормёжку обычная строка фона не сменяет, видимую — не сменяет и не срезает до `MIN_SHOW`,
## держится все `MESSAGE_SECONDS`. Постановка как в (аб) — кормёжка вместо бегства: заметка `catch` у `pred`,
## текст из `EcoPred._catch_text` (тот же, что шлёт мир, — по просканированным видам), фон — реальные заметки
## стоянки у 01 (`grazer/graze`, `grot/hide`), флаги строк — из мира (`take_link`), показ — `Status.Message`,
## как `Main._world_say`. Шов «ранг мира × очередь под потоком фона» юнит-тестами не покрыт: в
## `test_status.test_message_lead_keeps_queue` флаги выставлены руками. Мутация: «catch» без ранга в
## `EcoLink.KEEP` — ждущую кормёжку сменяет первая же строка фона, кормёжки на приборах нет вовсе. Без Main.
func test_catch_keep_line_held_under_background_stream() -> void:
	var w := EcoWorld.new(EcoRandom.WORLD_SEED)
	w.ground = Seabed.height
	var stand := Vector2(33.0, -22.0)
	w.ship.pos = Vector3(stand.x, Seabed.height(stand.x, stand.y) + 7.0, stand.y)
	w.ship.light_on = true
	var line_a := "Гребневики пасутся на мху у подножия рифа"
	var bg_texts := {   # фон: у ждущей кормёжки (+0,15 с, +0,30 с) и у видимой (+0,15 с, +0,30 с, +1,5 с, +3,0 с) — строки стоянки у 01, как в (аб)
		"Гребневики перешли на соседнее пятно мха": true,
		"Мелкая рыба: стая спряталась в рифе на спине гротовика, серпохвост её потерял": true,
		"Гребневики пасутся на мху у подножия рифа": true,
	}
	var msg := Status.Message.new()
	var shown: Array = []   # [текст, когда встал, сколько виден]
	var at := {"a": -1.0, "catch": -1.0}
	var wait_stream: Array[float] = []   # фон, наступающий на ждущую кормёжку
	var show_stream: Array[float] = []   # фон, наступающий на видимую кормёжку
	var wait_i := 0
	var show_i := 0
	var catch_text := ""
	var catch_keep := false
	var catch_lead := false
	var waiting_bg := 0   # строки фона, пришедшие, пока кормёжка ждала очереди
	var shown_bg := 0   # строки фона, пришедшие, пока кормёжка на приборах
	var t := 0.0
	while t < 7.0:
		if at["a"] < 0.0 and t >= 0.499:
			w.emit(EcoGrazer.ID, "graze", w.ship.pos + Vector3(12, -4, 8), func(): return line_a)
		if at["a"] > 0.0 and at["catch"] < 0.0 and t >= at["a"] + 0.299:
			w.emit(EcoPred.ID, "catch", w.ship.pos + Vector3(15, -3, 10), EcoPred._catch_text(w))
		if not wait_stream.is_empty() and t >= wait_stream[0] - 0.001:
			wait_stream.remove_at(0)
			if wait_i == 0:
				w.emit(EcoGrazer.ID, "graze", w.ship.pos + Vector3(-8, -4, 10),
					func(): return "Гребневики перешли на соседнее пятно мха")
			else:
				w.emit(EcoGrot.ID, "hide", w.ship.pos + Vector3(10, -5, -7),
					func(): return "Мелкая рыба: стая спряталась в рифе на спине гротовика, серпохвост её потерял")
			wait_i += 1
		if not show_stream.is_empty() and t >= show_stream[0] - 0.001:
			show_stream.remove_at(0)
			if show_i % 2 == 0:
				w.emit(EcoGrazer.ID, "graze", w.ship.pos + Vector3(6, -4, -12), func(): return line_a)
			else:
				w.emit(EcoGrot.ID, "hide", w.ship.pos + Vector3(-12, -3, -6),
					func(): return "Мелкая рыба: стая спряталась в рифе на спине гротовика, серпохвост её потерял")
			show_i += 1
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
			elif String(e.get("note", "")) == "catch" and at["catch"] < 0.0:
				at["catch"] = t
				catch_text = text
				catch_keep = bool(e.get("keep", false))
				catch_lead = bool(e.get("lead", false))
				wait_stream.assign([t + 0.15, t + 0.30])
			elif not catch_text.is_empty() and bg_texts.has(text):
				if msg.next == catch_text:
					waiting_bg += 1   # строка фона пришла, пока кормёжка ждала очереди
				if msg.text == catch_text:
					shown_bg += 1   # строка фона пришла, пока кормёжка на приборах
			msg.say(text, Status.MESSAGE_SECONDS, true, bool(e.get("urgent", false)), bool(e.get("keep", false)),
				bool(e.get("lead", false)))
		msg.update(0.05)
		if not catch_text.is_empty() and msg.text == catch_text and show_i == 0 and show_stream.is_empty():
			show_stream.assign([t + 0.15, t + 0.30, t + 1.5, t + 3.0])   # кормёжка вышла — фон наступает на неё
		if msg.text != "" and (shown.is_empty() or shown[-1][0] != msg.text):
			shown.append([msg.text, t, 0.0])
		if msg.text != "":
			shown[-1][2] = t - float(shown[-1][1]) + 0.05   # кадр t виден до следующего шага
	var catch_seen := 0.0
	var a_seen := 0.0
	for s: Array in shown:
		if String(s[0]) == catch_text and not catch_text.is_empty():
			catch_seen = maxf(catch_seen, float(s[2]))
		elif String(s[0]) == line_a:
			a_seen = maxf(a_seen, float(s[2]))
	var lines := PackedStringArray()
	for s: Array in shown:
		lines.append("%.2f с «%s» %.2f с" % [s[1], String(s[0]).left(40), s[2]])
	print("    кормёжка пришла на %.2f с (фон на %.2f с), у ждущей фона %d, фона при видимой %d; на приборах: %s" % [
		at["catch"], at["a"], waiting_bg, shown_bg, " | ".join(lines)])
	ok(at["a"] > 0.0 and at["catch"] > 0.0, "строка фона и кормёжка пришли")
	ok(at["catch"] - at["a"] < Status.Message.MIN_SHOW - 0.2,
		"кормёжка пришла, пока фон виден меньше MIN_SHOW — ждала очереди: %.2f с" % (at["catch"] - at["a"]))
	ok(catch_text.contains("поймал"), "текст кормёжки из `_catch_text` мира: «%s»" % catch_text)
	ok(catch_keep and not catch_lead, "кормёжка пришла «держится» без ведущего ранга (EcoLink.KEEP)")
	eq(waiting_bg, 2, "пока кормёжка ждала, наступал фон (%d) — проверка не пустая" % waiting_bg)
	ok(a_seen < Status.Message.MIN_SHOW + 0.06,
		"фон уступил место ждущей «держится» после MIN_SHOW (виден %.2f с)" % a_seen)
	ok(shown_bg >= 3, "пока кормёжка видна, пришёл поток фона (%d строки) — проверка не пустая" % shown_bg)
	ok(catch_seen >= Status.MESSAGE_SECONDS - 0.051, "кормёжка видна все %.1f с (по факту %.2f с)" % [
		Status.MESSAGE_SECONDS, catch_seen])


## Сцена 00→01 (п. 2 (аш), зеркало (ае) для кормёжки): ждущая кормёжка серпохвоста (`pred/catch`, «держится»
## `EcoLink.KEEP` без ведущего ранга) при новой срочной «замер» (`pred/alert`, `EcoLink.URGENT`) НЕ теряется:
## ветка срочной в `Status.Message.say` дропает ждущее, только если оно — ведущая «держится» (`next_lead`,
## ждущий отбой, #1968), — кормёжка выходит следом за срочной и держится свои `MESSAGE_SECONDS`. Постановка
## как в (ае), кормёжка вместо бегства: кормёжка приходит, пока на приборах свежая строка фона, и ждёт очереди
## (`next`); тут же голодный хищник даёт «замер» — срочная выходит сразу и держится все свои секунды, кормёжка
## выходит следом за ней; поток фона (строки стоянки у 01, как в (аб)) ждёт очереди. Флаги строк — из мира
## (`take_link`), показ — `Status.Message`, как `Main._world_say`. Шов «срочная × ждущая кормёжка» покрыт только
## для бегства ((ае)) — у кормёжки тот же ранг, но свой источник (`EcoPred._catch_text`). Мутация: ветка срочной
## в `Status.Message.say` дропает `next` безусловно — кормёжки на приборах нет вовсе. Без Main.
func test_pending_catch_survives_new_alert() -> void:
	var r := _near(0)
	var w: EcoWorld = r[0]
	var line_a := "Гребневики пасутся на мху у подножия рифа"
	var bg_texts := {   # поток фона у видимой кормёжки (+0,15 с, +0,30 с, +1,5 с, +3,0 с) — строки стоянки у 01, как в (аб)
		"Гребневики перешли на соседнее пятно мха": true,
		"Мелкая рыба: стая спряталась в рифе на спине гротовика, серпохвост её потерял": true,
		"Гребневики пасутся на мху у подножия рифа": true,
	}
	var msg := Status.Message.new()
	var shown: Array = []   # [текст, когда встал, сколько виден]
	var at := {"a": -1.0, "catch": -1.0, "alert": -1.0}
	var catch_text := ""
	var catch_keep := false
	var catch_lead := false
	var alert_urgent := false
	var catch_waiting_at_alert := false   # в момент прихода срочной кормёжка ждала очереди
	var catch_stream: Array[float] = []   # фон, наступающий на видимую кормёжку
	var catch_i := 0
	var bg_during_catch := 0   # строки фона, пришедшие, пока на приборах кормёжка
	var t := 0.0
	while t < 10.5:
		if at["a"] < 0.0 and t >= 0.499 and t < 0.6:
			w.emit(EcoGrazer.ID, "graze", w.ship.pos + Vector3(12, -4, 8), func(): return line_a)
		if at["a"] > 0.0 and at["catch"] < 0.0 and t >= 0.649 and t < 1.5:
			w.emit(EcoPred.ID, "catch", w.ship.pos + Vector3(15, -3, 10), EcoPred._catch_text(w))
		if not w.ship.light_on and at["catch"] > 0.0 and t >= 0.799:
			w.ship.light_on = true   # голодный хищник в 25 м: «замер» на этом шаге
		if not catch_stream.is_empty() and t >= catch_stream[0] - 0.001:
			catch_stream.remove_at(0)
			if catch_i % 3 == 0:
				w.emit(EcoGrazer.ID, "graze", w.ship.pos + Vector3(-8, -4, 10),
					func(): return "Гребневики перешли на соседнее пятно мха")
			elif catch_i % 3 == 1:
				w.emit(EcoGrot.ID, "hide", w.ship.pos + Vector3(10, -5, -7),
					func(): return "Мелкая рыба: стая спряталась в рифе на спине гротовика, серпохвост её потерял")
			else:
				w.emit(EcoGrazer.ID, "graze", w.ship.pos + Vector3(6, -4, -12), func(): return line_a)
			catch_i += 1
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
			elif String(e.get("note", "")) == "catch" and at["catch"] < 0.0:
				at["catch"] = t
				catch_text = text
				catch_keep = bool(e.get("keep", false))
				catch_lead = bool(e.get("lead", false))
			elif text.contains("замер") and at["alert"] < 0.0:
				at["alert"] = t
				alert_urgent = bool(e.get("urgent", false))
				catch_waiting_at_alert = msg.next == catch_text   # кормёжка ждала очереди, когда пришла срочная
			elif at["catch"] > 0.0 and not catch_text.is_empty() and msg.text == catch_text and bg_texts.has(text):
				bg_during_catch += 1   # строка фона пришла, пока на приборах кормёжка
			msg.say(text, Status.MESSAGE_SECONDS, true, bool(e.get("urgent", false)), bool(e.get("keep", false)),
				bool(e.get("lead", false)))
		msg.update(0.05)
		if at["catch"] > 0.0 and not catch_text.is_empty() and msg.text == catch_text and catch_i == 0 \
				and catch_stream.is_empty():
			catch_stream.assign([t + 0.15, t + 0.30, t + 1.5, t + 3.0])   # кормёжка вышла — фон наступает на неё
		if msg.text != "" and (shown.is_empty() or shown[-1][0] != msg.text):
			shown.append([msg.text, t, 0.0])
		if msg.text != "":
			shown[-1][2] = t - float(shown[-1][1]) + 0.05   # кадр t виден до следующего шага
	var a_seen := 0.0
	var alert_seen := 0.0
	var alert_shown_at := -1.0
	var catch_seen := 0.0
	var catch_shown_at := -1.0
	var after_alert := ""
	for i in shown.size():
		var s: Array = shown[i]
		var txt := String(s[0])
		if txt == line_a:
			a_seen = maxf(a_seen, float(s[2]))
		elif txt.contains("замер"):
			alert_seen = maxf(alert_seen, float(s[2]))
			if alert_shown_at < 0.0:
				alert_shown_at = float(s[1])
			if i + 1 < shown.size():
				after_alert = String(shown[i + 1][0])
		elif not catch_text.is_empty() and txt == catch_text:
			catch_seen = maxf(catch_seen, float(s[2]))
			if catch_shown_at < 0.0:
				catch_shown_at = float(s[1])
	var lines := PackedStringArray()
	for s: Array in shown:
		lines.append("%.2f с «%s» %.2f с" % [s[1], String(s[0]).left(40), s[2]])
	print("    фон %.2f с, кормёжка %.2f с (ждала при срочной: %s), «замер» %.2f с (на приборах %.2f с), кормёжка на приборах %.2f с, фона при ней %d; на приборах: %s" % [
		at["a"], at["catch"], catch_waiting_at_alert, at["alert"], alert_shown_at, catch_shown_at, bg_during_catch,
		" | ".join(lines)])
	ok(at["a"] > 0.0 and at["catch"] > 0.0 and at["alert"] > 0.0, "фон, кормёжка и «замер» пришли")
	ok(at["a"] < at["catch"] and at["catch"] < at["alert"], "порядок: фон → кормёжка → «замер»")
	ok(catch_text.contains("поймал"), "текст кормёжки из `_catch_text` мира: «%s»" % catch_text)
	ok(catch_keep and not catch_lead, "кормёжка пришла «держится» без ведущего ранга (EcoLink.KEEP)")
	ok(catch_waiting_at_alert, "в момент прихода срочной кормёжка ждала очереди (next) — постановка реальная")
	ok(alert_urgent, "«замер» пришёл с рангом «срочная» (EcoLink.URGENT)")
	ok(a_seen < Status.Message.MIN_SHOW, "срочная перебила свежую строку фона (та видна %.2f с < MIN_SHOW)" % a_seen)
	ok(alert_shown_at - at["alert"] <= 0.051, "срочная вышла на приборы сразу (ждала %.2f с)" % [
		alert_shown_at - at["alert"]])
	ok(alert_seen >= Status.MESSAGE_SECONDS - 0.051, "срочная видна все %.1f с (по факту %.2f с)" % [
		Status.MESSAGE_SECONDS, alert_seen])
	ok(catch_shown_at >= alert_shown_at + Status.MESSAGE_SECONDS - 0.051,
		"кормёжка вышла следом за срочной (на приборах %.2f с, срочная с %.2f с)" % [catch_shown_at, alert_shown_at])
	eq(after_alert, catch_text, "сразу за срочной на приборах — кормёжка, не фон")
	ok(bg_during_catch >= 3, "пока видна кормёжка, пришёл поток фона (%d строки) — проверка не пустая" % bg_during_catch)
	ok(catch_seen >= Status.MESSAGE_SECONDS - 0.051, "кормёжка видна все свои %.1f с (по факту %.2f с)" % [
		Status.MESSAGE_SECONDS, catch_seen])


## Сцена 00→01 (п. 2 (аш), зеркало (аф) для кормёжки): ВИДИМАЯ кормёжка серпохвоста (`pred/catch`, «держится»
## `EcoLink.KEEP` без ведущего ранга) при новой срочной «замер» (`pred/alert`, `EcoLink.URGENT`) срезается сразу,
## не дожидаясь своих `MESSAGE_SECONDS`, и назад не возвращается — зеркало `test_pending_catch_survives_new_alert`:
## ждущая кормёжка переживает срочную, видимая — нет (угроза важнее последствия, которое уже показано). Постановка
## как в (аф), кормёжка вместо бегства: фон, за ним кормёжка (ждала очереди за свежим фоном, вышла на приборы),
## тут же голодный хищник даёт «замер» — срочная выходит сразу и держится все свои секунды, кормёжка видна меньше
## своих и после срочной не возвращается. Поток фона (строки стоянки у 01, как в (аб)) наступает на видимую
## срочную и ждёт очереди (`next`). Флаги строк — из мира (`take_link`), показ — `Status.Message`, как
## `Main._world_say`. Шов «срочная × ВИДИМАЯ кормёжка» покрыт только для бегства ((аф)) и видимого отбоя ((ад)).
## Мутация: «alert» без ранга в `EcoLink.URGENT` — срочная ждёт очереди за видимой кормёжкой, кормёжка видна все
## свои секунды. Без Main.
func test_new_alert_cuts_visible_catch_line() -> void:
	var r := _near(0)
	var w: EcoWorld = r[0]
	var line_a := "Гребневики пасутся на мху у подножия рифа"
	var bg_texts := {   # поток фона у видимой срочной (+0,15 с, +0,30 с, +1,5 с, +3,0 с) — строки стоянки у 01, как в (аб)
		"Гребневики перешли на соседнее пятно мха": true,
		"Мелкая рыба: стая спряталась в рифе на спине гротовика, серпохвост её потерял": true,
		"Гребневики пасутся на мху у подножия рифа": true,
	}
	var msg := Status.Message.new()
	var shown: Array = []   # [текст, когда встал, сколько виден]
	var at := {"a": -1.0, "catch": -1.0, "alert": -1.0}
	var catch_text := ""
	var catch_keep := false
	var catch_lead := false
	var alert_urgent := false
	var alert_text := ""
	var catch_visible_at_alert := false   # в момент прихода срочной кормёжка была на приборах
	var bg_stream: Array[float] = []   # фон, наступающий на видимую срочную
	var bg_i := 0
	var bg_during := 0   # строки фона, пришедшие, пока на приборах срочная
	var t := 0.0
	while t < 10.0:
		if at["a"] < 0.0 and t >= 0.499 and t < 0.6:
			w.emit(EcoGrazer.ID, "graze", w.ship.pos + Vector3(12, -4, 8), func(): return line_a)
		if at["a"] > 0.0 and at["catch"] < 0.0 and t >= 0.649 and t < 1.5:
			w.emit(EcoPred.ID, "catch", w.ship.pos + Vector3(15, -3, 10), EcoPred._catch_text(w))
		if not w.ship.light_on and at["catch"] > 0.0 and t >= 1.999:
			w.ship.light_on = true   # голодный хищник в 25 м: «замер» на этом шаге
		if not bg_stream.is_empty() and t >= bg_stream[0] - 0.001:
			bg_stream.remove_at(0)
			if bg_i % 3 == 0:
				w.emit(EcoGrazer.ID, "graze", w.ship.pos + Vector3(-8, -4, 10),
					func(): return "Гребневики перешли на соседнее пятно мха")
			elif bg_i % 3 == 1:
				w.emit(EcoGrot.ID, "hide", w.ship.pos + Vector3(10, -5, -7),
					func(): return "Мелкая рыба: стая спряталась в рифе на спине гротовика, серпохвост её потерял")
			else:
				w.emit(EcoGrazer.ID, "graze", w.ship.pos + Vector3(6, -4, -12), func(): return line_a)
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
			elif String(e.get("note", "")) == "catch" and at["catch"] < 0.0:
				at["catch"] = t
				catch_text = text
				catch_keep = bool(e.get("keep", false))
				catch_lead = bool(e.get("lead", false))
			elif text.contains("замер") and at["alert"] < 0.0:
				at["alert"] = t
				alert_text = text
				alert_urgent = bool(e.get("urgent", false))
				catch_visible_at_alert = msg.text == catch_text   # кормёжка была на приборах, когда пришла срочная
			elif not alert_text.is_empty() and msg.text == alert_text and bg_texts.has(text):
				bg_during += 1   # строка фона пришла, пока на приборах срочная
			msg.say(text, Status.MESSAGE_SECONDS, true, bool(e.get("urgent", false)), bool(e.get("keep", false)),
				bool(e.get("lead", false)))
		msg.update(0.05)
		if not alert_text.is_empty() and msg.text == alert_text and bg_i == 0 and bg_stream.is_empty():
			bg_stream.assign([t + 0.15, t + 0.30, t + 1.5, t + 3.0])   # срочная вышла — фон наступает на неё
		if msg.text != "" and (shown.is_empty() or shown[-1][0] != msg.text):
			shown.append([msg.text, t, 0.0])
		if msg.text != "":
			shown[-1][2] = t - float(shown[-1][1]) + 0.05   # кадр t виден до следующего шага
	var catch_seen := 0.0
	var catch_shown_at := -1.0
	var catch_entries := 0
	var after_catch := ""
	var alert_seen := 0.0
	var alert_shown_at := -1.0
	for i in shown.size():
		var s: Array = shown[i]
		var txt := String(s[0])
		if not catch_text.is_empty() and txt == catch_text:
			catch_seen = maxf(catch_seen, float(s[2]))
			catch_entries += 1
			if catch_shown_at < 0.0:
				catch_shown_at = float(s[1])
			if i + 1 < shown.size():
				after_catch = String(shown[i + 1][0])
		elif txt.contains("замер"):
			alert_seen = maxf(alert_seen, float(s[2]))
			if alert_shown_at < 0.0:
				alert_shown_at = float(s[1])
	var lines := PackedStringArray()
	for s: Array in shown:
		lines.append("%.2f с «%s» %.2f с" % [s[1], String(s[0]).left(40), s[2]])
	print("    фон %.2f с, кормёжка %.2f с (на приборах %.2f с, была видна при срочной: %s), «замер» %.2f с (на приборах %.2f с, ждал %.2f с), фона при нём %d; на приборах: %s" % [
		at["a"], at["catch"], catch_shown_at, catch_visible_at_alert, at["alert"], alert_shown_at,
		alert_shown_at - at["alert"], bg_during, " | ".join(lines)])
	ok(at["a"] > 0.0 and at["catch"] > 0.0 and at["alert"] > 0.0, "фон, кормёжка и «замер» пришли")
	ok(at["a"] < at["catch"] and at["catch"] < at["alert"], "порядок: фон → кормёжка → «замер»")
	ok(catch_text.contains("поймал"), "текст кормёжки из `_catch_text` мира: «%s»" % catch_text)
	ok(catch_keep and not catch_lead, "кормёжка пришла «держится» без ведущего ранга (EcoLink.KEEP)")
	ok(catch_shown_at > 0.0 and catch_shown_at < at["alert"], "кормёжка уже была на приборах, когда пришла срочная")
	ok(catch_visible_at_alert, "в момент прихода срочной кормёжка была на приборах и держалась — постановка реальная")
	ok(alert_urgent, "«замер» пришёл с рангом «срочная» (EcoLink.URGENT)")
	ok(alert_shown_at - at["alert"] <= 0.051, "срочная срезала видимую кормёжку сразу (ждала %.2f с)" % [
		alert_shown_at - at["alert"]])
	ok(catch_seen > 0.0 and catch_seen < Status.MESSAGE_SECONDS,
		"кормёжка видна меньше своих %.1f с (по факту %.2f с)" % [Status.MESSAGE_SECONDS, catch_seen])
	ok(after_catch.contains("замер"), "сразу за срезанной кормёжкой на приборах — срочная, не фон")
	ok(alert_seen >= Status.MESSAGE_SECONDS - 0.051, "срочная видна все %.1f с (по факту %.2f с)" % [
		Status.MESSAGE_SECONDS, alert_seen])
	eq(catch_entries, 1, "кормёжка на приборы не вернулась (показана %d раза)" % catch_entries)
	ok(bg_during >= 3, "пока видна срочная, пришёл поток фона (%d строки) — проверка не пустая" % bg_during)


## Сцена 00→01 (п. 2 (ач)): брифинг прибытия (`Status.Message.take_world`, #1429, вызов — `main.gd`)
## забирает строки мира с приборов: гасит и ВИДИМУЮ «держится» (бегство рыб `fish/flee`, `EcoLink.KEEP`),
## и ЖДУЩУЮ строку мира (фон в `next`), брифингу отдаётся последняя; своё сообщение игрока
## (`wait` = false) брифинг не трогает — после брифинга ни бегство, ни фон на приборы не выходят.
## Постановка как в (аф): фон → после MIN_SHOW бегство (встаёт на приборы сразу) → фон ждёт очереди
## за «держится»; флаги строк — из мира (`take_link`), показ — `Status.Message`, как `Main._world_say`.
## Шов «брифинг × ранги мира × очередь» юнит-тестом не покрыт: в `test_status.test_message_take_world`
## флаги выставлены руками и «держится» среди них нет. Мутация: `take_world` оставляет `next` —
## ждущий фон выходит после брифинга. Без Main.
func test_arrival_brief_drops_world_lines() -> void:
	var w := EcoWorld.new(EcoRandom.WORLD_SEED)
	w.ground = Seabed.height
	var stand := Vector2(33.0, -22.0)
	w.ship.pos = Vector3(stand.x, Seabed.height(stand.x, stand.y) + 7.0, stand.y)
	w.ship.light_on = true
	var line_a := "Гребневики пасутся на мху у подножия рифа"
	var flee_line := "Мелкая рыба: стая уходит в кораллы — рядом хищник"
	var line_bg := "Мелкая рыба: стая спряталась в рифе на спине гротовика, серпохвост её потерял"
	var msg := Status.Message.new()
	var shown: Array = []   # тексты на приборах до брифинга
	var at := {"a": -1.0, "flee": -1.0, "bg": -1.0}
	var flee_keep := false
	var flee_lead := false
	var brief_at := -1.0
	var brief := ""
	var pre_text := ""
	var pre_next := ""
	var post_text := "~"
	var post_next := "~"
	var t := 0.0
	while t < 4.0 and brief_at < 0.0:
		if at["a"] < 0.0 and t >= 0.499:
			w.emit(EcoGrazer.ID, "graze", w.ship.pos + Vector3(12, -4, 8), func(): return line_a)
		if at["a"] > 0.0 and at["flee"] < 0.0 and t >= at["a"] + 1.199:   # фон виден дольше MIN_SHOW — бегство встанет сразу
			w.emit(EcoFish.ID, "flee", w.ship.pos + Vector3(15, -3, 10), func(): return flee_line)
		if at["flee"] > 0.0 and at["bg"] < 0.0 and t >= at["flee"] + 0.299:   # бегство «держится» на приборах — фон ждёт очереди
			w.emit(EcoGrot.ID, "hide", w.ship.pos + Vector3(10, -5, -7), func(): return line_bg)
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
			elif text == flee_line and at["flee"] < 0.0:
				at["flee"] = t
				flee_keep = bool(e.get("keep", false))
				flee_lead = bool(e.get("lead", false))
			elif text == line_bg and at["bg"] < 0.0:
				at["bg"] = t
			msg.say(text, Status.MESSAGE_SECONDS, true, bool(e.get("urgent", false)), bool(e.get("keep", false)),
				bool(e.get("lead", false)))
		msg.update(0.05)
		if at["bg"] > 0.0 and t >= at["bg"] + 0.299:
			pre_text = msg.text
			pre_next = msg.next
			brief_at = t
			brief = msg.take_world()   # брифинг прибытия забирает строки мира
			post_text = msg.text
			post_next = msg.next
		if msg.text != "" and (shown.is_empty() or shown[-1] != msg.text):
			shown.append(msg.text)
	var after: Array = []
	for i in 120:   # 6 с после брифинга
		msg.update(0.05)
		if msg.text != "" and (after.is_empty() or after[-1] != msg.text):
			after.append(msg.text)
	print("    фон %.2f с, бегство %.2f с, ждущий фон %.2f с, брифинг %.2f с; до брифинга: %s; после: %s" % [
		at["a"], at["flee"], at["bg"], brief_at, " | ".join(shown), " | ".join(after)])
	ok(at["a"] > 0.0 and at["flee"] > 0.0 and at["bg"] > 0.0, "фон, бегство и ждущий фон пришли")
	ok(flee_keep and not flee_lead, "бегство пришло «держится» без ведущего ранга (EcoLink.KEEP)")
	eq(pre_text, flee_line, "в момент брифинга на приборах — видимое бегство")
	eq(pre_next, line_bg, "фон ждал очереди — постановка реальная")
	eq(brief, line_bg, "брифингу отдана последняя строка мира — ждущий фон")
	eq(post_text, "", "брифинг погасил видимое бегство")
	eq(post_next, "", "и снял ждущий фон")
	ok(after.is_empty(), "после брифинга ни бегство, ни фон на приборы не выходят (показано: %s)" % [" | ".join(after)])
	# своё сообщение игрока (`wait` = false) брифинг не трогает
	msg.say("Прожектор погашен")
	eq(msg.text, "Прожектор погашен", "своё сообщение игрока — сразу на приборы")
	eq(msg.take_world(), "", "своё сообщение — не строка мира, брифингу не отдаётся")
	eq(msg.text, "Прожектор погашен", "и остаётся на приборах")
	msg.update(1.5)
	eq(msg.text, "Прожектор погашен", "и не сменяется вернувшейся строкой мира")


## Сцена 00→01 (п. 2 (ат)): брифинг прибытия (`Status.Message.take_world`, #1429, вызов — `main.gd`)
## гасит и ВИДИМУЮ срочную «замер» (`pred/alert`, `EcoLink.URGENT`, #1498), и ЖДУЩИЙ ведущий отбой
## (`pred/lost`, `EcoLink.KEEP_LEAD` в `next`, #1966): после брифинга ни «замер», ни отбой на приборы
## не выходят, брифингу отдаётся последняя строка мира — ждущий отбой; своё сообщение игрока
## (`wait` = false) брифинг не трогает. Постановка как в (аг) — брифинг вместо повторного света:
## свет → «замер» на приборах (`hot`), свет погас во «замере» → отбой ждёт очереди за срочной.
## Флаги строк — из мира (`take_link`), показ — `Status.Message`, как `Main._world_say`.
## Шов «брифинг × срочная × ждущая ведущая» юнит-тестом не покрыт: в `test_status.test_message_take_world`
## флаги выставлены руками и срочной среди них нет, (ач) — про «держится» без срочной. Мутация:
## `take_world` не трогает горячую (`hot`) — «замер» остаётся на приборах после брифинга. Без Main.
func test_arrival_brief_drops_urgent_and_pending_lead() -> void:
	var r := _near(0)
	var w: EcoWorld = r[0]
	var msg := Status.Message.new()
	var shown: Array = []   # [текст, когда встал, сколько виден] до брифинга
	var at := {"alert": -1.0, "lost": -1.0}
	var alert_text := ""
	var alert_urgent := false
	var lost_text := ""
	var lost_keep := false
	var lost_lead := false
	var brief_at := -1.0
	var brief := ""
	var pre_text := ""
	var pre_next := ""
	var post_text := "~"
	var post_next := "~"
	var t := 0.0
	while t < 4.0 and brief_at < 0.0:
		if not w.ship.light_on and at["alert"] < 0.0 and t >= 0.799:
			w.ship.light_on = true   # голодный хищник в 25 м: «замер» на этом шаге
		if w.ship.light_on and at["alert"] > 0.0 and at["lost"] < 0.0 and t >= 2.299:
			w.ship.light_on = false   # свет погас во «замере» — отбой на этом шаге
		w.step(0.05)
		t += 0.05
		for e in w.take_link():
			if e.get("type") != EcoLink.MESSAGE and e.get("type") != EcoLink.OBSERVE:
				continue
			var text := String(e.get("text", ""))
			if text == "":
				continue
			if text.contains("замер") and at["alert"] < 0.0:
				at["alert"] = t
				alert_text = text
				alert_urgent = bool(e.get("urgent", false))
			elif text.contains("потерял корабль") and at["lost"] < 0.0:
				at["lost"] = t
				lost_text = text
				lost_keep = bool(e.get("keep", false))
				lost_lead = bool(e.get("lead", false))
			msg.say(text, Status.MESSAGE_SECONDS, true, bool(e.get("urgent", false)), bool(e.get("keep", false)),
				bool(e.get("lead", false)))
		msg.update(0.05)
		if at["lost"] > 0.0 and brief_at < 0.0 and t >= at["lost"] + 0.299:
			pre_text = msg.text
			pre_next = msg.next
			brief_at = t
			brief = msg.take_world()   # брифинг прибытия забирает строки мира
			post_text = msg.text
			post_next = msg.next
		if msg.text != "" and (shown.is_empty() or shown[-1][0] != msg.text):
			shown.append([msg.text, t, 0.0])
		if msg.text != "":
			shown[-1][2] = t - float(shown[-1][1]) + 0.05   # кадр t виден до следующего шага
	var after: Array = []
	for i in 120:   # 6 с после брифинга
		msg.update(0.05)
		if msg.text != "" and (after.is_empty() or after[-1] != msg.text):
			after.append(msg.text)
	var lines := PackedStringArray()
	for s: Array in shown:
		lines.append("%.2f с «%s» %.2f с" % [s[1], String(s[0]).left(40), s[2]])
	print("    «замер» %.2f с, отбой %.2f с, брифинг %.2f с; до брифинга: %s; после: %s" % [
		at["alert"], at["lost"], brief_at, " | ".join(lines), " | ".join(after)])
	ok(at["alert"] > 0.0 and at["lost"] > 0.0, "«замер» и отбой пришли")
	ok(alert_urgent, "«замер» пришла с рангом «срочная» (EcoLink.URGENT)")
	ok(lost_keep and lost_lead, "отбой пришёл ведущей «держится» (EcoLink.KEEP_LEAD)")
	eq(pre_text, alert_text, "в момент брифинга на приборах — видимая срочная «замер»")
	eq(pre_next, lost_text, "отбой ждал очереди за срочной — постановка реальная")
	eq(brief, lost_text, "брифингу отдана последняя строка мира — ждущий отбой")
	eq(post_text, "", "брифинг погасил видимую срочную")
	eq(post_next, "", "и снял ждущий отбой")
	ok(after.is_empty(), "после брифинга ни «замер», ни отбой на приборы не выходят (показано: %s)" % [" | ".join(after)])
	# своё сообщение игрока (`wait` = false) брифинг не трогает
	msg.say("Прожектор погашен")
	eq(msg.text, "Прожектор погашен", "своё сообщение игрока — сразу на приборы")
	eq(msg.take_world(), "", "своё сообщение — не строка мира, брифингу не отдаётся")
	eq(msg.text, "Прожектор погашен", "и остаётся на приборах")
	msg.update(1.5)
	eq(msg.text, "Прожектор погашен", "и не сменяется вернувшейся строкой мира")


## Сцена 00→01 (п. 2 (ащ)): экипаж видит «замер» первого хищника (свет), бьёт разрядом (тот уходит) и тут же
## даёт импульс сонара — второй голодный хищник рядом отвечает своей срочной «замер» (`pred/alert`, ранг
## `EcoLink.URGENT`, #1498) с причиной «сонар». Вторая срочная срезает ВИДИМУЮ первую сразу, не дожидаясь её
## `MESSAGE_SECONDS`, — ветка срочной в `Status.Message.say` показывает безусловно, у новой срочной тот же
## приоритет над горячей строкой, что у неё над видимым отбоем ((ад)) — и держится все свои секунды; ждущая
## в `next` строка фона (стоянка у 01, как в (аб)) не теряется — выходит следом за второй срочной. Постановка
## `_near` с двумя хищниками у корабля: первый в 25 м (свет его зовёт), второй в 34 м — за чутьём на свет
## (`REACH` 32 м), ближе зова сонара (`PING_CALL` 150 м); сдрейфует в патруле под 32 м до гашения света — не
## страшно: замер ему закрывает угроза первого (`threat_free`). Разряд (`ps.on_zap` радиусом 30 м — только по
## первому) уводит первого в `FLEE` без строки «потерял корабль»: та (`KEEP_LEAD`) встала бы в `next` вместо
## фона; угроза свободна через `THREAT_HOLD` (1 с) после ухода первого. Свет погашен до импульса — иначе
## строка второго была бы про свет (`_lure_kind` смотрит свет первым). Флаги строк — из мира (`take_link`),
## показ — `Status.Message`, как `Main._world_say`. Шов «срочная × видимая срочная» до этого был не покрыт:
## (ад) — срочная × видимый отбой, в `test_status` флаги выставлены руками. Мутация: ветка срочной не
## перебивает горячую (`and not hot` в `say`) — вторая «замер» кладётся в `next` поверх ждущего фона (тот не
## выходит вовсе) и сама выходит, только когда догорит первая. Без Main.
func test_second_alert_cuts_visible_first_alert() -> void:
	var w := EcoWorld.new()
	w.ground = _flat
	var ps := EcoPred.new()
	ps.alert = 100.0   # «замеры» не кончаются броском в окне теста: строка броска встала бы в `next` вместо фона
	w.add(ps)
	w.ship.light_on = false
	var p0 := ps.all[0]
	p0.hunger = 0.5
	p0.cooldown = 0.0
	w.ship.pos = p0.agent.p + Vector3(25, 0, 0)
	var p1 := ps.all[1]
	p1.agent.p = w.ship.pos + Vector3(34, 0, 0)   # за чутьём на свет (32 м), ближе зова сонара (150 м)
	p1.hunger = 0.5
	p1.cooldown = 0.0
	var p2 := ps.all[2]
	p2.agent.p = Vector3(700, FLAT + 6.0, -600)
	p2.cooldown = 999.0
	var line_a := "Гребневики пасутся на мху у подножия рифа"
	var line_c := "Мелкая рыба: стая спряталась в рифе на спине гротовика, серпохвост её потерял"
	var bg_texts := {   # ждущий фон и поток фона у второй «замеры» (+0,3 с, +1,5 с) — строки стоянки у 01, как в (аб)
		line_a: true,
		line_c: true,
		"Гребневики перешли на соседнее пятно мха": true,
	}
	var msg := Status.Message.new()
	var shown: Array = []   # [текст, когда встал, сколько виден]
	var at := {"a": -1.0, "alert1": -1.0, "zap": -1.0, "alert2": -1.0}
	var alert1_text := ""
	var alert2_text := ""
	var alert2_urgent := false
	var alert2_wait := -1.0   # сколько вторая срочная ждала показа (0,00 — в тот же вызов say)
	var pre2_text := ""   # что было на приборах в момент второй срочной
	var pre2_next := ""   # и что ждало в `next`
	var stream_at: Array[float] = []   # фон, наступающий на видимую вторую «замер»
	var bg_during := 0   # строки фона, пришедшие, пока на приборах вторая «замер»
	var zapped := false
	var emitted_c := false
	var t := 0.0
	while t < 9.5:
		if at["a"] < 0.0 and t >= 0.499 and t < 1.5:
			w.emit(EcoGrazer.ID, "graze", w.ship.pos + Vector3(12, -4, 8), func(): return line_a)
		if not w.ship.light_on and t >= 0.799 and t < 1.5:
			w.ship.light_on = true   # голодный хищник в 25 м: первая «замер» на этом шаге
		if not zapped and at["alert1"] > 0.0 and t >= at["alert1"] + 1.15:
			ps.on_zap(w, 30.0)   # разряд только по первому (второй в ~34 м): FLEE без строки «потерял корабль»
			w.ship.light_on = false   # до импульса — иначе вторая «замер» была бы с причиной «свет»
			ps.on_ping(w, w.ship.pos)   # второй голодный в 38 м < PING_CALL — плывёт на звук
			zapped = true
		if zapped and not emitted_c and t >= 0.35 + 2.05:
			w.emit(EcoGrot.ID, "hide", w.ship.pos + Vector3(-12, -3, -6), func(): return line_c)   # ждущий фон
			emitted_c = true
		if not stream_at.is_empty() and t >= stream_at[0] - 0.001:
			stream_at.remove_at(0)
			w.emit(EcoGrazer.ID, "graze", w.ship.pos + Vector3(6, -4, -12),
				func(): return "Гребневики перешли на соседнее пятно мха")
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
			elif text.contains("замер") and at["alert1"] < 0.0:
				at["alert1"] = t
				alert1_text = text
			elif text.contains("замер") and not alert1_text.is_empty() and text != alert1_text \
					and at["alert2"] < 0.0:
				at["alert2"] = t
				alert2_text = text
				alert2_urgent = bool(e.get("urgent", false))
				pre2_text = msg.text
				pre2_next = msg.next
				stream_at.assign([t + 0.3, t + 1.5])
			elif text.begins_with("Разряд отпугнул") and at["zap"] < 0.0:
				at["zap"] = t
			elif not alert2_text.is_empty() and msg.text == alert2_text and bg_texts.has(text):
				bg_during += 1   # строка фона пришла, пока на приборах вторая «замер»
			msg.say(text, Status.MESSAGE_SECONDS, true, bool(e.get("urgent", false)), bool(e.get("keep", false)),
				bool(e.get("lead", false)))
		msg.update(0.05)
		if not alert2_text.is_empty() and alert2_wait < 0.0 and msg.text == alert2_text:
			alert2_wait = t - at["alert2"]
		if msg.text != "" and (shown.is_empty() or shown[-1][0] != msg.text):
			shown.append([msg.text, t, 0.0])
		if msg.text != "":
			shown[-1][2] = t - float(shown[-1][1]) + 0.05   # кадр t виден до следующего шага
	var alert1_seen := 0.0
	var alert2_seen := 0.0
	var after2 := ""   # что вышло следом за второй срочной
	for i in shown.size():
		var s: Array = shown[i]
		if String(s[0]) == alert1_text:
			alert1_seen = maxf(alert1_seen, float(s[2]))
		elif String(s[0]) == alert2_text:
			alert2_seen = maxf(alert2_seen, float(s[2]))
			if i + 1 < shown.size():
				after2 = String(shown[i + 1][0])
	var lines := PackedStringArray()
	for s: Array in shown:
		lines.append("%.2f с «%s» %.2f с" % [s[1], String(s[0]).left(40), s[2]])
	print("    «замер» 1 на %.2f с, разряд %.2f с, «замер» 2 на %.2f с (ждала %.2f с), фона при ней %d; на приборах: %s" % [
		at["alert1"], at["zap"], at["alert2"], maxf(alert2_wait, 0.0), bg_during, " | ".join(lines)])
	ok(at["a"] > 0.0 and at["alert1"] > 0.0, "строка фона и первая «замер» пришли")
	ok(at["zap"] > 0.0, "разряд по первому хищнику прошёл")
	ok(at["alert2"] > 0.0, "вторая «замер» пришла (импульс сонара у второго хищника)")
	ok(alert1_text.contains("свет") and alert2_text.contains("сонар"), "причины различны: свет и сонар")
	ok(alert2_urgent, "вторая «замер» пришла с рангом «срочная» (EcoLink.URGENT)")
	eq(pre2_text, alert1_text, "в момент второй срочной на приборах — видимая первая (постановка реальная)")
	eq(pre2_next, line_c, "в момент второй срочной фон ждёт в `next` (постановка реальная)")
	ok(alert2_wait >= 0.0 and alert2_wait < 0.06, "вторая срочная на приборах сразу (ждала %.2f с)" % [
		maxf(alert2_wait, 0.0)])
	ok(alert1_seen < Status.MESSAGE_SECONDS - 0.5, "первая срочная срезана, не догорев (видна %.2f с < %.1f с)" % [
		alert1_seen, Status.MESSAGE_SECONDS])
	ok(alert2_seen >= Status.MESSAGE_SECONDS - 0.051, "вторая срочная видна все %.1f с (по факту %.2f с)" % [
		Status.MESSAGE_SECONDS, alert2_seen])
	ok(bg_during >= 2, "пока видна вторая «замер», пришёл поток фона (%d строки) — проверка не пустая" % bg_during)
	ok(bg_texts.has(after2), "следом за второй срочной вышел ждущий фон («%s»)" % after2.left(40))
