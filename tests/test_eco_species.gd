extends TestCase
## Реестр видов отмели (Unity EcoCoreTests: «РеестрВидовКакВБраузере», «НазваниеВПадежах», IsObservation и проверка
## ключа вида в шине и у существа).


func test_registry_like_browser() -> void:
	eq(Species.count(), 26, "видов как в G.SPECIES_ORDER")
	eq(Species.ids(), ["fish", "pred", "veil", "grazer", "eel", "ray", "ognevka", "leech", "hvaten", "pestr", "ezh",
		"krab", "raduzh", "plankton", "monet", "glazun", "grot", "skalnik", "prisoska", "kamen", "organ", "cushion",
		"bladder", "fan", "fern", "echo"] as Array[String], "порядок журнала")
	eq(Species.index_of("pred"), 1, "серпохвост второй")
	eq(Species.index_of("кракен"), -1, "нет такого")
	ok(not Species.has("кракен") and not Species.has(""), "неизвестный ключ")
	var notes := 0
	for id in Species.ids():
		var s := Species.info(id)
		ok(s.name != "" and s.acc != "" and s.unom != "" and s.uacc != "" and s.desc != "", "тексты есть: " + id)
		ok(s.notes.size() > 0, "есть заметки: " + id)
		var keys := {}
		for n in s.notes:
			ok(not keys.has(n[0]), "%s: ключ заметки повторяется %s" % [id, n[0]])
			keys[n[0]] = true
			ok(String(n[1]) != "", "%s.%s: текст" % [id, n[0]])
		notes += s.notes.size()
	eq(notes, 77, "заметок для журнала столько же, сколько в браузере")


func test_names_in_cases() -> void:
	eq(Species.called("fish"), "мелкая рыба", "до сканирования")
	eq(Species.called("fish", Species.Case.ACC), "мелкую рыбу", "винительный")
	eq(Species.called("fish", Species.Case.GEN), "мелкую рыбу", "нет родительного — винительный")
	eq(Species.called("fish", Species.Case.NOM, true), "светляк-полосник", "настоящее имя строчными")
	eq(Species.called("fish", Species.Case.ACC, true), "светляка-полосника", "настоящее в винительном")
	eq(Species.called("hvaten", Species.Case.GEN), "донного анемона", "свой родительный до сканирования")
	eq(Species.called("hvaten", Species.Case.GEN, true), "хватня", "свой родительный после")
	eq(Species.called("raduzh", Species.Case.GEN, true), "радужников", "родительный множественного")
	eq(Species.cap(Species.called("pred", Species.Case.NOM, true)), "Серпохвост", "заглавная (G.cap)")
	eq(Species.cap(""), "", "пустая строка")
	eq(Species.called("кракен"), "", "нет вида — пусто")
	ok(Species.info("кракен") == null, "нет вида — null")
	var g := Species.info("grazer")
	ok(g.has_note("graze") and not g.has_note("catch"), "заметки скребуна")
	eq(g.note("graze"), "Объедает светящийся мох. Съеденные пятна гаснут и потом отрастают.", "текст заметки")


func test_observation_and_unknown_species() -> void:
	var bus := EcoBus.new()
	var catch_ev := bus.emit("pred", "catch", Vector3.ZERO)
	var signal_ev := bus.emit("leech", "signal", Vector3.ZERO)
	ok(catch_ev.is_observation(), "catch — заметка журнала серпохвоста")
	ok(not signal_ev.is_observation(), "у пиявника нет заметки signal — только сигнал")
	ok(EcoBus.Event.new("leech", "cleaned", Vector3.ZERO).is_observation(), "cleaned — заметка пиявника")
	ok(bus.emit("кракен", "x", Vector3.ZERO) == null, "неизвестный вид не отправляется")
	eq(bus.pending.size(), 2, "в очереди только свои виды")
	ok(not EcoAgent.new("кракен", Vector3.ZERO).alive, "существо неизвестного вида неживое")
	ok(EcoAgent.new("pred", Vector3.ZERO).alive, "своё живое")
	var w := EcoWorld.new()
	ok(w.spawn("кракен", Vector3.ZERO) == null, "мир не заводит неизвестный вид")
	eq(w.agents.size(), 0, "никого")


func test_world_names_by_scan() -> void:
	var w := EcoWorld.new()
	eq(w.nm("pred"), "крупный хищник", "без сканера — описательно")
	var done := {"pred": true}
	w.scanned = func(id: String) -> bool: return done.has(id)
	eq(w.nm("pred", Species.Case.ACC), "серпохвоста", "просканирован")
	eq(w.nm("fish", Species.Case.ACC), "мелкую рыбу", "не просканирован")
	w.emit("pred", "catch", Vector3.ZERO,
		func(): return "%s поймал %s" % [Species.cap(w.nm("pred")), w.nm("fish", Species.Case.ACC)])
	done["fish"] = true  # текст собирается в момент показа
	eq(w.bus.take()[0].text(), "Серпохвост поймал светляка-полосника", "как в браузере")
