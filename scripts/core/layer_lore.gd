class_name LayerLore
extends RefCounted
## Знания слоя 1 (#825, таблица «Состояния и подача знаний» #818): что экипаж уже узнал на отмели. Каждый факт
## ставит только своё событие (`learn`), гибель и загрузка их не сбрасывают — стирает только новая экспедиция
## («Сбросить сохранение», `clear`). Хранится в `SaveGame` ключом "lore" (`snapshot`/`apply`, список ключей), в
## коопе знания общие: хост шлёт `pack` (битовая маска) в кадре «k», гость `apply_net` — подключившийся получает всё
## сразу. Ремонт, авторизация и доступ к комплексу сами не ставятся — только своим событием.
## Перед уходом вниз у 10 интерфейс отмечает непрочитанную диагностику 07 (`unread_diagnostics`), но спуск не
## запрещает (`may_descend` — всегда true). `main.lore`.

signal changed

## Ключи фактов; порядок — биты `pack`, новые только в конец.
const INTRO := "intro"          ## обучение и брифинг прибытия просмотрены (00)
const D07_RETURN := "d07_return"   ## диагностика 07: обратный ход неисправен
const D07_RELAY := "d07_relay"     ## диагностика 07: ретранслятор без питания
const D07_AUTH := "d07_auth"       ## диагностика 07: нужна авторизация
const K2 := "k2"                ## запись К-2 прослушана
const SHELL03 := "shell03"      ## Раковина 03 осмотрена: чужая архитектура, продолжение комплекса
const FIELD08 := "field08"      ## поле 08 замечено: граница, зависит от размера
const AUTH07 := "auth07"        ## терминал 07 авторизован локально (позже)
const DOWN := "down"            ## экипаж ушёл в слой 2
const BACK := "back"            ## вернулся из слоя 2
const KEYS: Array[String] = [INTRO, D07_RETURN, D07_RELAY, D07_AUTH, K2, SHELL03, FIELD08, AUTH07, DOWN, BACK]
const DIAGNOSTICS: Array[String] = [D07_RETURN, D07_RELAY, D07_AUTH]

var facts: Array[String] = []   ## узнанное, в порядке узнавания
var rev := 0                    ## растёт при каждом изменении — показ пересчитывает строки только по нему


## Событие игры открыло факт: true — новое (сохранить, показать). Неизвестный ключ — ошибка вызова, false.
func learn(key: String) -> bool:
	if not KEYS.has(key) or facts.has(key):
		return false
	facts.append(key)
	_touch()
	return true


func knows(key: String) -> bool:
	return facts.has(key)


## Факты диагностики 07, ещё не прочитанные, — их отмечает интерфейс у 10 перед уходом вниз.
func unread_diagnostics() -> Array[String]:
	var out: Array[String] = []
	for k in DIAGNOSTICS:
		if not facts.has(k):
			out.append(k)
	return out


## Уход вниз у 10 знаниями не запирается: непрочитанная диагностика — подсказка, не условие.
func may_descend() -> bool:
	return true


## Для файла: ключи в порядке узнавания.
func snapshot() -> Array:
	return facts.duplicate()


## Из файла. Нет ключа (старое сохранение) или испорчен — знаний нет; чужие ключи пропускаются.
func apply(data: Variant) -> void:
	facts.clear()
	if data is Array:
		for k in data:
			var s := str(k)
			if KEYS.has(s) and not facts.has(s):
				facts.append(s)
	_touch()


## Для кадра сети: бит i — KEYS[i].
func pack() -> int:
	var m := 0
	for i in KEYS.size():
		if facts.has(KEYS[i]):
			m |= 1 << i
	return m


## Кадр хоста у гостя: знания — как у хоста. Не число (старый хост, кадр без «k») — без изменений; изменилось —
## true.
func apply_net(v: Variant) -> bool:
	if not (typeof(v) in [TYPE_INT, TYPE_FLOAT]):
		return false
	var m := int(v)
	if m == pack():
		return false
	var keep: Array[String] = []
	for k in facts:   # порядок узнанного сохраняем, новое — в порядке KEYS
		if m & (1 << KEYS.find(k)):
			keep.append(k)
	for i in KEYS.size():
		if m & (1 << i) and not keep.has(KEYS[i]):
			keep.append(KEYS[i])
	facts = keep
	_touch()
	return true


## Новая экспедиция: ничего не узнано.
func clear() -> void:
	if facts.is_empty():
		return
	facts.clear()
	_touch()


func _touch() -> void:
	rev += 1
	changed.emit()
