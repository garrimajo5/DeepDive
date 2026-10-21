class_name Ballot
extends RefCounted
## Голосование экипажа «глубже или наверх» (этап «Кооп», ART-016 «Голосование»): голосуют те, кто стоит у голостола
## (`Crew.Member.at_vote`), каждый своей крестовиной — ▲ наверх, ▼ глубже, голос можно сменить до решения.
## Один у стола — решает сразу (как в одиночной игре, мнения ролей — подсказка). Двое и больше — первый голос
## запускает таймер TIME: решение, как только проголосовали все у стола и есть большинство, иначе — по таймеру
## большинством поданных голосов. Ничья по таймеру — «наверх» (осторожный выбор; правило можно сменить).
## Метки на голограмме — кружки цвета роли голосующего (`marks`, формат `VoteHolo.votes`).
## Кольцо таймера на голограмме — `VoteView` (секунды `seconds()`, доля дуги `fraction()`).

const TIME := 15.0   ## секунд на решение после первого голоса (на листе ART-016 «12 с» — пример)

var picks := {}      ## id голосующего → [роль, "deep" | "up"]
var left := INF      ## до решения по таймеру, с; INF — таймер не идёт
var _held := {}      ## id → крестовину держат с прошлого голоса (новый голос — после того, как отпустят)


func clear() -> void:
	picks.clear()
	_held.clear()
	left = INF


## Крестовина голосующего id (move.y > 0 — вверх): "up", "deep" или "" — как Run.vote_nav, но у каждого своя.
## Первое касание после открытия не считается, если крестовину уже держали (held_at_start).
func nav(id: int, move: Vector2, held_at_start: bool = false) -> String:
	if not _held.has(id):
		_held[id] = held_at_start
	if absf(move.y) < 0.5:
		_held[id] = false
		return ""
	if _held[id]:
		return ""
	_held[id] = true
	return "up" if move.y > 0.0 else "deep"


## Голос (или смена голоса) id с ролью role. Первый голос запускает таймер.
func cast(id: int, role: int, choice: String) -> void:
	picks[id] = [role, choice]
	if left == INF:
		left = TIME


## Сколько голосов за choice.
func count(choice: String) -> int:
	var n := 0
	for p: Array in picks.values():
		if p[1] == choice:
			n += 1
	return n


## Решение большинства поданных голосов; ничья — "up".
func winner() -> String:
	return "deep" if count("deep") > count("up") else "up"


## Шаг: voters — id тех, кто у стола (голоса ушедших снимаются). Возвращает решение или "".
func update(dt: float, voters: Array) -> String:
	for id in picks.keys():
		if not id in voters:
			picks.erase(id)
	if picks.is_empty():
		left = INF
		return ""
	var tie := count("deep") == count("up")
	if voters.size() <= 1 or (picks.size() >= voters.size() and not tie):
		return winner()
	left -= dt
	if left <= 0.0:
		return winner()
	return ""


## Целых секунд до решения по таймеру (вверх); -1 — таймер не идёт.
func seconds() -> int:
	return -1 if left == INF else maxi(0, ceili(left))


## Доля оставшегося времени 0…1 для дуги кольца; -1 — таймер не идёт.
func fraction() -> float:
	return -1.0 if left == INF else clampf(left / TIME, 0.0, 1.0)


## Метки для голограммы: {"deep": [роль…], "up": [роль…]} по порядку ролей (как VoteHolo.votes).
func marks() -> Dictionary:
	var out := {"deep": [], "up": []}
	for p: Array in picks.values():
		out[p[1]].append(p[0])
	for c in out:
		out[c].sort()
	return out


## Строка счёта для панели: «голосов 1 из 2 · 12 с».
func tally(voters: int) -> String:
	var s := "голосов %d из %d" % [picks.size(), voters]
	return s if seconds() < 0 else "%s · %d с" % [s, seconds()]
