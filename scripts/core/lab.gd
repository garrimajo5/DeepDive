class_name Lab
extends RefCounted
## Лаборатория по ART-009 и моделям MOD-015 (`docs/concept-art/laboratoriya.md`): три колбы на тумбах и стойка журнала.
## Как в браузерной версии (js/ship.js, S.showTubes): в колбах — три последних образца из груза трюма, колба i —
## i-й из последних трёх; поднял лебёдкой — образец сам появляется в колбе. Пост «Колба» — что в ней; пост «Журнал» —
## сводка экспедиции на экране стойки (изученные виды — от сканера биолога, `Scanner`).
## Оси корабля; отсек x −4…4, z 8…14 (`ShipLayout.ROOMS`).

## Центры тумб колб на полу (x, z): две у левого борта у кормы, третья у правого у носа.
const FLASKS: Array[Vector2] = [Vector2(-3.3, 13.3), Vector2(-2.5, 13.4), Vector2(3.3, 9.0)]
const BASE := 0.6                   ## тумба 0,6 × 0,6 м
const GLASS_Y := 0.35               ## низ стекла (верх тумбы)
const SAMPLE_Y := 1.15              ## образец парит в середине колбы
## Стойка журнала: центр основания, лицом к −X (к проходу); корпус с экраном 0,6 × 0,98 м по полу.
const JOURNAL := Vector2(2.9, 12.75)
const JOURNAL_RECT := Rect2(2.6, 12.26, 0.6, 0.98)
const SCREEN_CENTER := Vector3(0.0, 1.125, 0.0)          ## в осях стойки
const SCREEN_NORMAL := Vector3(-0.5, 0.8660254, 0.0)
const SCREEN_SIZE := Vector2(0.9, 0.5)
## Посты: у колбы — вокруг тумбы, у журнала — со стороны прохода.
const FLASK_POST_R := 1.1
const JOURNAL_POST := Vector2(2.1, 12.75)
const JOURNAL_POST_R := 0.9


## Что в колбах: вид образца (Samples.Kind) или −1 — пусто. Три последних образца груза, по порядку.
static func contents(cargo: Array) -> Array[int]:
	var out: Array[int] = []
	var last := cargo.slice(maxi(0, cargo.size() - FLASKS.size()))
	for i in FLASKS.size():
		out.append(int(last[i][0]) if i < last.size() else -1)
	return out


## Подпись поста «Колба n».
static func flask_label(cargo: Array, n: int) -> String:
	var k: int = contents(cargo)[n]
	return "Колба %d: %s" % [n + 1, Samples.NAMES[k].to_lower()] if k >= 0 else "Колба %d пуста" % (n + 1)


## Сообщение по кнопке у колбы.
static func flask_info(cargo: Array, n: int) -> String:
	var k: int = contents(cargo)[n]
	if k < 0:
		return "Колба %d пуста: образцы поднимает лебёдка в трюме" % (n + 1)
	return "Колба %d: %s" % [n + 1, Samples.NAMES[k].to_lower()]


## Строки экрана журнала: заголовок, изучено видов (species < 0 — не писать), груз, поднято со дна, по видам образцов.
static func journal_lines(s: Samples, species: int = -1) -> PackedStringArray:
	var lines := PackedStringArray(["ЖУРНАЛ ЭКСПЕДИЦИИ"])
	if species >= 0:
		lines.append("Видов изучено: %d из %d" % [species, Species.count()])
	lines.append("Образцов в трюме: %d" % s.cargo.size())
	lines.append("Поднято со дна: %d из %d" % [s.got.size(), s.all.size()])
	var count := []
	count.resize(Samples.NAMES.size())
	count.fill(0)
	for c in s.cargo:
		count[int(c[0])] += 1
	for k in Samples.NAMES.size():
		if count[k] > 0:
			lines.append("%s — %d" % [Samples.NAMES[k], count[k]])
	if s.cargo.is_empty():
		lines.append("Образцов пока нет")
	return lines


## Сообщение по кнопке у журнала.
static func journal_info(s: Samples) -> String:
	var kinds := {}
	for c in s.cargo:
		kinds[int(c[0])] = true
	return "Журнал: образцов %d, видов образцов %d из %d" % [s.cargo.size(), kinds.size(), Samples.NAMES.size()]


## Тумбы и стойка — препятствия на полу.
static func blocks(x: float, z: float, r: float) -> bool:
	var p := Vector2(x, z)
	for f in FLASKS:
		if Rect2(f - Vector2(BASE, BASE) / 2.0, Vector2(BASE, BASE)).grow(r).has_point(p):
			return true
	return JOURNAL_RECT.grow(r).has_point(p)


## Посты лаборатории: «flask0…2» у тумб и «journal» у стойки.
static func posts() -> Array[Deck.Post]:
	var out: Array[Deck.Post] = []
	for i in FLASKS.size():
		out.append(Deck.Post.new("flask%d" % i, FLASKS[i], FLASK_POST_R, "Колба %d" % (i + 1)))
	out.append(Deck.Post.new("journal", JOURNAL_POST, JOURNAL_POST_R, "Журнал"))
	return out


## Образец в колбе слегка покачивается: подъём над серединой колбы, м.
static func bob(t: float, n: int) -> float:
	return 0.04 * sin(t * 1.3 + float(n) * 2.1)
