class_name Lab
extends RefCounted
## Лаборатория по ART-009 и моделям MOD-015 (`docs/concept-art/laboratoriya.md`): три колбы на тумбах и стойка журнала.
## Как в браузерной версии (js/ship.js, S.showTubes): в колбах — три последних образца из груза трюма, колба i —
## i-й из последних трёх; поднял лебёдкой — образец сам появляется в колбе. Пост «Колба» — что в ней; пост «Журнал» —
## сводка экспедиции на экране стойки (изученные виды — от сканера биолога, `Scanner`). Нажатия «Журнал» листают
## страницы: сводка, бортовой архив — передача К-2 TXT-001 §3 (`ARCHIVE`, #825), затем карточки видов (изученные или
## с наблюдениями, порядок журнала), снова сводка (renderJournal в js/game.js: имя, наблюдения «n из m»).
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
## Кольцо-светильник MOD-020 (`laboratoriya.md`): pivot — центр верхней плоскости, вплотную к потолку отсека
## (`ShipLayout.ROOMS` — 3,4 м; в концепте 3,45), над серединой отсека; Ø 3,2 м, высота 0,2 м.
const RING := Vector3(0.0, 3.4, 11.0)
const RING_D := 3.2
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


const CARD_NOTES := 1                ## на карточке — последняя заметка (больше не помещается на экран)


## Виды с карточкой в журнале: изучены сканером или есть наблюдения; порядок журнала (Species.ids).
static func cards(sc: Scanner) -> Array[String]:
	var out: Array[String] = []
	for id in Species.ids():
		if sc.is_scanned(id) or sc.seen.has(id):
			out.append(id)
	return out


## Бортовой архив: фрагмент передачи «Ковчега-2», полученной Землёй (TXT-001 §3, L1_K2_01…06) — копия на борту К-7,
## не прямой эфир. Две страницы по 8 строк экрана стойки; дочитал до последней — знание `LayerLore.K2` (#825).
const ARCHIVE_HEAD := "АРХИВ · ПЕРЕДАЧА К-2 · %d / %d"
const ARCHIVE_SOURCE := "Передача К-2. Получено на Земле"
const ARCHIVE: Array[String] = [
	"Земля, это «Ковчег-2».",
	"Обратный ход врат не работает.",
	"Его можно восстановить.",
	"У ретранслятора остался заряд на одну передачу.",
	"Весь заряд уходит на это сообщение.",
	"Для следующего придётся восстановить питание.",
]
const ARCHIVE_END := "Конец доступного фрагмента"
const ARCHIVE_SPLIT := 3             ## строк передачи на первой странице
const ARCHIVE_PAGES := 2
const ARCHIVE_INFO := "Архив: передача «Ковчега-2», полученная Землёй"


## Страница page — архив К-2 (1…ARCHIVE_PAGES).
static func is_archive(page: int) -> bool:
	return page >= 1 and page <= ARCHIVE_PAGES


## Последняя страница архива: дочитано — `LayerLore.K2`.
static func archive_done(page: int) -> bool:
	return page == ARCHIVE_PAGES


## Строки экрана архива на странице n (1 или 2): подпись источника, строки передачи, конец фрагмента.
static func archive_lines(n: int) -> PackedStringArray:
	var lines := PackedStringArray([ARCHIVE_HEAD % [n, ARCHIVE_PAGES]])
	if n <= 1:
		lines.append(ARCHIVE_SOURCE)
		for t in ARCHIVE.slice(0, ARCHIVE_SPLIT):
			lines.append(t)
	else:
		for t in ARCHIVE.slice(ARCHIVE_SPLIT):
			lines.append(t)
		lines.append(ARCHIVE_END)
	return lines


## Сообщение при открытии страницы архива.
static func archive_info(page: int) -> String:
	return ("%s. %s" % [ARCHIVE_INFO, ARCHIVE_END]) if archive_done(page) else ARCHIVE_INFO


## Страниц журнала: сводка, архив и карточки.
static func pages(sc: Scanner) -> int:
	return 1 + ARCHIVE_PAGES + cards(sc).size()


## Карточка вида на странице page (−1 — сводка или архив).
static func card_index(page: int, sc: Scanner) -> int:
	var i := page - 1 - ARCHIVE_PAGES
	return i if i >= 0 and i < cards(sc).size() else -1


## Строки карточки вида: номер карточки, имя (до сканирования — «Неизвестный вид»), счёт и последние наблюдения.
static func card_lines(sc: Scanner, id: String, n: int, total: int) -> PackedStringArray:
	var info := Species.info(id)
	var lines := PackedStringArray(["ЖУРНАЛ · ВИД %d ИЗ %d" % [n, total]])
	lines.append(info.name if sc.is_scanned(id) else "Неизвестный вид: %s" % info.unom)
	var got := sc.seen_of(id)
	lines.append("Наблюдений %d из %d" % [got.size(), info.notes.size()])
	for k in got.slice(maxi(0, got.size() - CARD_NOTES)):
		lines.append("· " + info.note(k))
	if got.is_empty():
		lines.append("Наблюдения пишутся, когда вид рядом с кораблём")
	return lines


## Сообщение при открытии карточки: сведения об изученном виде или подсказка.
static func card_info(sc: Scanner, id: String) -> String:
	var info := Species.info(id)
	if sc.is_scanned(id):
		return "%s: %s" % [info.name, info.desc]
	return "Неизвестный вид: изучите его сканером на мостике"


## Экран журнала на странице page (0 — сводка, 1…2 — архив К-2, дальше карточки); страница за краем — сводка.
static func page_lines(s: Samples, sc: Scanner, page: int) -> PackedStringArray:
	if is_archive(page):
		return archive_lines(page)
	var ids := cards(sc)
	var i := card_index(page, sc)
	if i < 0:
		return journal_lines(s, sc.scanned.size())
	return card_lines(sc, ids[i], i + 1, ids.size())


## Сообщение по кнопке «Журнал» на странице page.
static func page_info(s: Samples, sc: Scanner, page: int) -> String:
	if is_archive(page):
		return archive_info(page)
	var i := card_index(page, sc)
	return journal_info(s) if i < 0 else card_info(sc, cards(sc)[i])



## Экран журнала без пересчёта каждый кадр (#847): строки (сводка — перебор груза, карточки — 100 видов реестра)
## считаются заново, только когда сменились груз (`Samples.cargo_rev`), изученное (`Scanner.rev`) или страница.
class Screen:
	extends RefCounted
	var builds := 0                      ## сколько раз строки считались (для теста)
	var _key := []
	var _lines := PackedStringArray()

	func lines(s: Samples, sc: Scanner, page: int) -> PackedStringArray:
		var key := [s.cargo_rev, s.cargo.size(), s.got.size(), sc.rev, sc.scanned.size(), page]
		if key != _key:
			_key = key
			_lines = Lab.page_lines(s, sc, page)
			builds += 1
		return _lines

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
