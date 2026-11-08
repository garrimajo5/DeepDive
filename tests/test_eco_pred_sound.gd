extends TestCase
## Голос серпохвоста SND-008 (#1054): файлы, выбор звука по режиму и укусу (`EcoPredSound`), плееры в `PredView`.


## Приёмка PR #1448: щелчки 1, рык 1, укус 1, уход 2 — разовые, длина по заказу.
func test_files() -> void:
	var want := {EcoPredSound.CLICK: [1.0, 2.0], EcoPredSound.ROAR: [1.5, 3.0], EcoPredSound.JAW: [0.5, 1.0],
			EcoPredSound.FLEE: [1.0, 2.0]}
	for path: String in EcoPredSound.FILES:
		var s := load(path) as AudioStreamWAV
		ok(s != null, "звук загружается: %s" % path)
		if s:
			eq(s.loop_mode, AudioStreamWAV.LOOP_DISABLED, "разовый, не петля: %s" % path)
			var r: Array = want[path]
			ok(s.get_length() >= r[0] and s.get_length() <= r[1], "длина: %s %.2f" % [path, s.get_length()])


func _pred(m: EcoPred.Mode) -> EcoPred.Pred:
	var pr := EcoPred.Pred.new()
	pr.agent = EcoAgent.new(EcoPred.ID, Vector3.ZERO)
	pr.mode = m
	return pr


func test_first_update_is_silent() -> void:
	var v := EcoPredSound.Call.new()
	var pr := _pred(EcoPred.Mode.CHARGE)
	pr.bit_at = 5.0
	eq(v.update(pr, 5.1, 10.0), EcoPredSound.Cue.NONE, "загружен в броске и после укуса — молчит")
	eq(v.update(pr, 5.2, 10.0), EcoPredSound.Cue.NONE, "режим не менялся, укус старый — молчит")


func test_hunt_clicks_every_few_seconds() -> void:
	var v := EcoPredSound.Call.new(1)
	var pr := _pred(EcoPred.Mode.PATROL)
	v.update(pr, 0.0, 20.0)
	eq(v.update(pr, 10.0, 20.0), EcoPredSound.Cue.NONE, "в патруле молчит")
	pr.mode = EcoPred.Mode.HUNT
	eq(v.update(pr, 10.1, 20.0), EcoPredSound.Cue.CLICK, "начал охоту — щёлкает сразу")
	var times: Array[float] = [10.1]
	var t := 10.1
	while t < 40.0:
		t += 0.1
		if v.update(pr, t, 20.0) == EcoPredSound.Cue.CLICK:
			times.append(t)
	ok(times.size() >= 5, "за 30 с охоты — несколько щелчков: %d" % times.size())
	for k in range(1, times.size()):
		var gap := times[k] - times[k - 1]
		ok(gap >= EcoPredSound.CLICK_MIN - 0.11 and gap <= EcoPredSound.CLICK_MAX + 0.11,
				"пауза между щелчками 3–6 с: %.1f" % gap)


func test_investigate_clicks_and_far_is_silent() -> void:
	var v := EcoPredSound.Call.new()
	var pr := _pred(EcoPred.Mode.PATROL)
	v.update(pr, 0.0, 100.0)
	pr.mode = EcoPred.Mode.INVESTIGATE
	eq(v.update(pr, 0.1, EcoPredSound.CLICK_FAR + 5.0), EcoPredSound.Cue.NONE, "дальше 60 м щелчков не слышно")
	pr.mode = EcoPred.Mode.PATROL
	v.update(pr, 0.2, 30.0)
	pr.mode = EcoPred.Mode.INVESTIGATE
	eq(v.update(pr, 0.3, 30.0), EcoPredSound.Cue.CLICK, "плывёт на звук сонара — щёлкает")


func test_charge_roars_once() -> void:
	var v := EcoPredSound.Call.new()
	var pr := _pred(EcoPred.Mode.HUNT)
	v.update(pr, 0.0, 30.0)
	pr.mode = EcoPred.Mode.CHARGE
	eq(v.update(pr, 1.0, 30.0), EcoPredSound.Cue.ROAR, "бросок — рык")
	for k in 20:
		eq(v.update(pr, 1.1 + k * 0.1, 30.0), EcoPredSound.Cue.NONE, "в броске рык не повторяется и щелчков нет")


func test_bite_then_flee() -> void:
	var v := EcoPredSound.Call.new()
	var pr := _pred(EcoPred.Mode.CHARGE)
	v.update(pr, 0.0, 5.0)
	pr.bit_at = 2.0
	pr.mode = EcoPred.Mode.RETREAT
	eq(v.update(pr, 2.05, 3.0), EcoPredSound.Cue.JAW, "укус корпуса — челюсти")
	eq(v.update(pr, 2.1, 3.0), EcoPredSound.Cue.NONE, "один укус — один звук; отход после укуса молчит")
	pr.mode = EcoPred.Mode.FLEE
	eq(v.update(pr, 3.0, 10.0), EcoPredSound.Cue.FLEE, "разряд сбил охоту — уходит со звуком")


func test_old_bite_and_far_bite_silent() -> void:
	var v := EcoPredSound.Call.new()
	var pr := _pred(EcoPred.Mode.CHARGE)
	v.update(pr, 0.0, 5.0)
	pr.bit_at = 1.0
	eq(v.update(pr, 1.0 + EcoPredSound.JAW_LATE + 0.5, 5.0), EcoPredSound.Cue.NONE, "старый укус не звучит")
	pr.bit_at = 4.0
	eq(v.update(pr, 4.0, EcoPredSound.LOUD_FAR + 1.0), EcoPredSound.Cue.NONE, "укус вдали не слышен")
	eq(v.update(pr, 4.1, 5.0), EcoPredSound.Cue.NONE, "подплыв ближе, старый укус не отыгрывает")


func test_new_run_resets() -> void:
	var v := EcoPredSound.Call.new()
	var pr := _pred(EcoPred.Mode.CHARGE)
	pr.bit_at = 50.0
	v.update(pr, 50.0, 5.0)
	var fresh := _pred(EcoPred.Mode.HUNT)   # новый забег: новый зверь, время мира с начала
	eq(v.update(fresh, 0.0, 20.0), EcoPredSound.Cue.NONE, "новый зверь — сначала запоминает")
	fresh.bit_at = 0.5
	eq(v.update(fresh, 0.5, 5.0), EcoPredSound.Cue.JAW, "укус нового забега звучит, хотя время меньше прошлого")


func test_view_players_on_world_bus() -> void:
	SoundMix.ensure()
	var preds := EcoPred.new()
	var world := EcoWorld.new()
	world.add(preds)
	world.reset(7)
	var view := PredView.new(preds)
	tree.root.add_child(view)
	eq(view.clicks.size(), preds.all.size(), "плеер щелчков у каждого")
	eq(view.calls.size(), preds.all.size(), "плеер голоса у каждого")
	for p in view.clicks + view.calls:
		eq(String(p.bus), SoundMix.WORLD, "шина «Мир»")
		ok(p.get_parent() in view.bodies, "звук идёт от тела зверя")
	var pr := preds.all[0]
	var near := pr.agent.p + Vector3(0, 0, 20)
	view.sync(1.0, near)
	pr.mode = EcoPred.Mode.CHARGE
	view.sync(1.1, near)
	eq(view.last_cue[0], EcoPredSound.Cue.ROAR, "бросок рядом — рык")
	eq(view.calls[0].stream, load(EcoPredSound.ROAR), "в плеере голоса — рык")
	view.free()
