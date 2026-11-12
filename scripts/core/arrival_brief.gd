class_name ArrivalBrief
extends RefCounted
## Брифинг прибытия у старта 00 (#827, тексты TXT-001 §1, `docs/teksty/TXT-001-sloj1.md`): восемь экранов по одной-двум
## строкам после облёта `Flyby.Kind.START`, до подсказок первого забега. Переход — касанием (не крестовиной), таймер
## экран не закрывает; первые `MIN_SHOW` с экрана касание не листает — случайное двойное не проскакивает текст.
## Пока идёт — подсказки скрыты и стоят, события слоя ждут (`Main.events_held`). Пройден — знание
## `LayerLore.BRIEF`: загрузка и возвращение в Сад его не повторяют. Здесь состояние, строки и места (2400×1080,
## масштаб H/1080, центр W/2); рисует `scripts/game/arrival_brief_panel.gd`, шагает `OverlayFlow.brief_step`.

## Пары строк экранов L1_BRIEF_01…08; "" — второй строки нет (в TXT-001 — «—», игроку не показывать).
const LINES: Array[String] = [
	"Талассия-IV.", "Подо льдом — чужой океан.",
	"Наша задача — исследовать этот мир.", "И выяснить, как людям здесь обосноваться.",
	"До нас сюда ушли шесть экспедиций.", "Ни одна не вернулась.",
	"Но Земля получила передачу «Ковчега-2».", "",
	"Они сообщили: обратный ход врат можно восстановить.", "",
	"Начнём с террасы врат.", "Нужно понять, что ещё работает.",
	"«Ковчег-7» — наш дом на всю экспедицию.", "Берегите корабль.",
	"Проверьте посты.", "Идём малым ходом.",
]
const SOURCE := "Бортовой брифинг"
const HINT := "Коснитесь экрана — дальше"
const HINT_LAST := "Коснитесь экрана — к постам"
const MIN_SHOW := 0.4   ## с: столько экран не листается касанием
const FADE := 0.25      ## с: плашка появляется и тает
## Плашка при 2400×1080: по центру сверху, над крестовиной и кнопками (правило UX: зазор от их кругов).
const BOX := Rect2(560, 205, 1280, 300)   ## под строкой приборов (до 3 строк)
const SOURCE_AT := Vector2(64, 40)   ## от угла плашки, верх глифов
const LINE1_AT := Vector2(64, 92)
const LINE2_AT := Vector2(64, 158)
const FOOT_AT := Vector2(64, 246)
const SOURCE_PX := 26
const LINE_PX := 40   ## длинная строка ужимается панелью по ширине плашки
const FOOT_PX := 24

var on := false    ## брифинг нужен (первое прибытие кампании)
var screen := 0    ## текущий экран, 0…count()-1; count() — пройден
var t := 0.0       ## с на текущем экране
var a := 0.0       ## видимость 0…1


static func count() -> int:
	return LINES.size() / 2


static func line(i: int, row: int) -> String:
	return LINES[clampi(i, 0, count() - 1) * 2 + row]


## Идёт: включён и не пройден.
func active() -> bool:
	return on and screen < count()


func shown() -> bool:
	return active() and a > 0.0


## Касание экрана (не крестовины). true — брифинг только что пройден целиком.
func tap() -> bool:
	if not active() or a < 1.0 or t < MIN_SHOW:
		return false
	screen += 1
	t = 0.0
	return screen >= count()


## Шаг времени. hidden — облёт, шторка, меню, пауза: плашка тает, экран не считает время.
func update(dt: float, hidden: bool) -> void:
	var want := active() and not hidden
	a = move_toward(a, 1.0 if want else 0.0, dt / FADE)
	if want and a >= 1.0:
		t += dt


## «3 / 8 · Коснитесь экрана — дальше»
func footer() -> String:
	var last := screen >= count() - 1
	return "%d / %d · %s" % [mini(screen + 1, count()), count(), HINT_LAST if last else HINT]


static func scale(size: Vector2) -> float:
	return size.y / 1080.0


## Плашка на экране size: по центру по x, высота и отступы — от H/1080.
static func box(size: Vector2) -> Rect2:
	var s := scale(size)
	var w := BOX.size.x * s
	return Rect2(size.x * 0.5 - w * 0.5, BOX.position.y * s, w, BOX.size.y * s)


## Точка внутри плашки (верх глифов) на экране size.
static func at(p: Vector2, size: Vector2) -> Vector2:
	return box(size).position + p * scale(size)
