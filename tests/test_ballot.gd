extends TestCase
## Голосование экипажа у голостола (Ballot): у каждого своя крестовина, большинство, таймер, ничья — решает пилот.


func test_solo_decides_at_once() -> void:
	var b := Ballot.new()
	eq(b.update(0.1, [1]), "", "без голосов решения нет")
	b.cast(1, Crew.Role.PILOT, "deep")
	eq(b.update(0.0, [1]), "deep", "один у стола — решает сразу")


func test_majority_when_all_voted() -> void:
	var b := Ballot.new()
	b.cast(1, Crew.Role.PILOT, "deep")
	eq(b.update(1.0, [1, 2, 3]), "", "ждём остальных")
	eq(b.seconds(), ceili(Ballot.TIME - 1.0), "первый голос запустил таймер")
	b.cast(2, Crew.Role.ENGINEER, "up")
	b.cast(3, Crew.Role.BIOLOGIST, "deep")
	eq(b.update(0.1, [1, 2, 3]), "deep", "все проголосовали — большинство")
	eq(b.marks(), {"deep": [Crew.Role.PILOT, Crew.Role.BIOLOGIST], "up": [Crew.Role.ENGINEER]}, "метки ролей")
	eq(b.tally(3), "голосов 3 из 3 · %d с" % b.seconds())


func test_tie_waits_then_pilot() -> void:
	var b := Ballot.new()
	b.cast(1, Crew.Role.PILOT, "deep")
	b.cast(2, Crew.Role.SONAR, "up")
	eq(b.update(1.0, [1, 2]), "", "ничья — ждём: голос можно сменить")
	b.cast(2, Crew.Role.SONAR, "deep")
	eq(b.update(0.1, [1, 2]), "deep", "сменил голос — единогласно")
	b.clear()
	eq(b.seconds(), -1, "таймер сброшен")
	b.cast(1, Crew.Role.PILOT, "deep")
	b.cast(2, Crew.Role.SONAR, "up")
	eq(b.update(Ballot.TIME - 0.5, [1, 2]), "")
	eq(b.update(0.6, [1, 2]), "deep", "время вышло при ничьей — решает пилот (#828)")
	b.clear()
	b.cast(1, Crew.Role.PILOT, "up")
	b.cast(2, Crew.Role.SONAR, "deep")
	b.update(Ballot.TIME + 0.1, [1, 2])
	eq(b.winner(), "up", "пилот за «наверх» — наверх")


func test_tie_without_pilot_up() -> void:
	var b := Ballot.new()
	b.cast(1, Crew.Role.ENGINEER, "deep")
	b.cast(2, Crew.Role.SONAR, "up")
	eq(b.update(Ballot.TIME + 0.1, [1, 2, 3]), "up", "пилот молчит — ничья наверх")
	b.clear()
	b.cast(1, Crew.Role.PILOT, "deep")
	b.cast(2, Crew.Role.SONAR, "up")
	b.cast(3, Crew.Role.ENGINEER, "deep")
	b.cast(4, Crew.Role.BIOLOGIST, "up")
	eq(b.update(Ballot.TIME + 0.1, [1, 2, 3, 4]), "deep", "двое на двое — голос пилота")
	b.update(0.0, [2, 3, 4])
	eq(b.pilot_pick(), "", "пилот отключился — его голос снят")
	eq(b.winner(), "up", "без пилота — большинство оставшихся")


func test_timer_decides_without_absent() -> void:
	var b := Ballot.new()
	b.cast(1, Crew.Role.PILOT, "deep")
	eq(b.update(Ballot.TIME - 0.1, [1, 2]), "", "второй молчит")
	eq(b.update(0.2, [1, 2]), "deep", "по таймеру — поданные голоса")


func test_leaving_drops_vote() -> void:
	var b := Ballot.new()
	b.cast(1, Crew.Role.PILOT, "up")
	eq(b.update(0.1, [2, 3]), "", "ушёл от стола — голос снят")
	ok(b.picks.is_empty())
	eq(b.seconds(), -1, "без голосов таймер не идёт")


func test_nav_per_voter() -> void:
	var b := Ballot.new()
	eq(b.nav(1, Vector2(0, -1), true), "", "держал с подхода — не голос")
	eq(b.nav(1, Vector2.ZERO), "")
	eq(b.nav(1, Vector2(0, -1)), "deep", "вниз — глубже")
	eq(b.nav(1, Vector2(0, -1)), "", "один голос за нажатие")
	eq(b.nav(2, Vector2(0, 1)), "up", "у второго своя крестовина")


func test_fraction_for_ring() -> void:
	var b := Ballot.new()
	eq(b.fraction(), -1.0, "без голосов кольца нет")
	b.cast(1, Crew.Role.PILOT, "deep")
	near(b.fraction(), 1.0, 1e-6, "первый голос — полное кольцо")
	b.update(Ballot.TIME * 0.25, [1, 2])
	near(b.fraction(), 0.75, 1e-5, "четверть времени прошла — дуга на три четверти")
	eq(b.seconds(), ceili(Ballot.TIME * 0.75))
