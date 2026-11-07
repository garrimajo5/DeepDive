class_name DescentVote
extends RefCounted
## Панель «Спуск к Кристальному лесу» у 10 (#1362, макет UX `m10-spusk`): в кампании у 10 выбор не «глубже или
## наверх», а «спуститься сейчас или позже» — «наверх» и очков здесь нет. Панель показывает, что на слое 1 ещё не
## узнано (`LayerLore`: диагностика врат 07, Раковина 03, поле 08), и до двух мнений ролей — сначала «против».
## Здесь — строки и место панели без узлов; рисует `VotePanel.show_descent`, открывает `Main.open_vote`
## (`Run.at_descent`). Над столом — одно поле «ВНИЗ» (`VoteHolo.choices`).

const TITLE := "Спуск к Кристальному лесу"
const SUB := "глубже 300 м · вернуться сюда можно"
const HEAD := "Слой 1 — не узнано"
const ALL_KNOWN := "Слой 1: всё важное узнано"
const FOOT := "вниз — спуститься · кнопка — позже"
const GAP := 16.0          ## зазор низа панели над кнопкой действия при H = 1080, px (масштаб — по высоте экрана)
const TOP := 0.18          ## верх панели — доля высоты экрана (под строками приборов)
const BUTTON := "Спуск"    ## кнопка действия у голостола, пока спуск отложен «позже» (корабль в круге 10)


## Что на слое ещё не узнано: [текст, важное?]. Важное (янтарь) — диагностика врат 07 и Раковина 03, поле 08 —
## необязательное (приглушённо). Всё узнано — одна строка ALL_KNOWN (не важная).
static func unknown(lore: LayerLore) -> Array:
	var out := []
	var left := lore.unread_diagnostics().size()
	var n := LayerLore.DIAGNOSTICS.size()
	if left == n:
		out.append(["Врата 07: не осмотрены", true])
	elif left > 0:
		out.append(["Диагностика врат 07: %d из %d" % [n - left, n], true])
	if not lore.knows(LayerLore.SHELL03):
		out.append(["Раковина 03: не осмотрена", true])
	if not lore.knows(LayerLore.FIELD08):
		out.append(["Поле 08: не замечено", false])
	if out.is_empty():
		out.append([ALL_KNOWN, false])
	return out


## Мнения ролей на панели (из `Run.opinions` — [кто, наверх?, почему]): пилот и инженер, сначала «против» (корпус
## < 50 %, энергия < 40, перегрев) — не больше двух строк. Возвращает [кто, против?, почему].
static func opinions(ops: Array) -> Array:
	var against := []
	var pro := []
	for r: Array in ops:
		if not (r[0] in ["Пилот", "Инженер"]):
			continue
		(against if r[1] else pro).append(r)
	var out := against + pro
	return out.slice(0, 2)


## Место панели на экране vis: справа, верх — TOP высоты, низ — на GAP (в масштабе H/1080) выше кнопки действия.
static func box(vis: Vector2) -> Rect2:
	var bottom := action_top(vis) - GAP * vis.y / 1080.0
	var vw := minf(vis.x * 0.3, vis.y * 0.68)
	var top := vis.y * TOP
	return Rect2(vis.x - vw - 24.0 * vis.y / 720.0, top, vw, maxf(0.0, bottom - top))


## Верх круга кнопки действия на экране vis (раскладка `Touch.Layout` по всему экрану).
static func action_top(vis: Vector2) -> float:
	var l := Touch.Layout.new()
	l.compute(Rect2(Vector2.ZERO, vis))
	return l.action.c.y - l.action.r
