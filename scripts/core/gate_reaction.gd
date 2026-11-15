class_name GateReaction
extends RefCounted
## Реакции экипажа у террасы врат 07 (TXT-001, «Реакции экипажа»; подача — спецификация UX в #1866): подписанное
## замечание поста строкой приборов у того, кто стоит на посту реплики, — одно правило для соло и коопа. Не связь
## ART-040, не табличка над товарищем, не голос: невидимых говорящих напарников нет.
## Взвод — только событием этого сеанса: чтение гнезда (`arm`, сигнал `GateDiag.read`) или факт, пришедший гостю
## кадром хоста (`follow`; знания на момент входа — основа, не событие). Загрузка сохранения с фактами не взводит.
## Показ (`update` отдаёт строку один раз): корабль в круге 07, игрок у поста реплики (`POSTS`), с последнего
## сообщения-факта 07 прошло `AFTER_FACT` — реакция не стирает факт. Вышли из круга до показа — реплика снята.
## Часы стоят, пока шаг не зовут (меню, пауза) или `hidden` (брифинг, голосование, шторки).
## Ставит `OverlayFlow.reaction_step` (`main.reaction`), строка — `Status.Message.say(…, SHOW, wait)`.

const AFTER_FACT := Status.MESSAGE_SECONDS   ## после сообщения-факта 07 до реакции, с
const SHOW := 6.0                            ## реакция на приборах, с: 52–61 знак с подписью роли
const PLACE := "gate"                        ## ключ места 07 в `Run.PLACES`

## Факт → пост (`Deck.posts`), у которого стоит роль реплики.
const POSTS := {
	LayerLore.D07_RETURN: "sonar",
	LayerLore.D07_AUTH: "scanner",
}
## Факт → знание, после которого реплика устарела ("" — такого в слое 1 нет: ремонт обратного хода — на будущее).
const STALE := {
	LayerLore.D07_RETURN: "",
	LayerLore.D07_AUTH: LayerLore.AUTH07,
}

var armed: Array[String] = []    ## факты, чьи реплики ждут показа
var said: Array[String] = []     ## уже показанные за сеанс — второй раз не выходят
var since_fact := INF            ## с последнего сообщения-факта 07, с
var _base: Array[String] = []    ## гость: факты, которые уже видел `follow`
var _synced := false


## Подписанная реплика факта: «Биолог: Настройки закрыты. Нужно разрешение системы.»
static func line(fact: String) -> String:
	var r: Array = GateDiag.REACTION[fact]
	return "%s: %s" % [Crew.ROLE_NAMES[int(r[0])], r[1]]


## Корабль (x, z) в круге места 07.
static func in_place(ship: Vector2) -> bool:
	return ship.distance_to(Run.place_xz(PLACE)) < float(Run.PLACES[PLACE][2])


## Факт 07 прочитан сейчас (сообщение о нём — на приборах): часы после факта с нуля, реплика факта взведена.
func arm(fact: String) -> void:
	since_fact = 0.0
	if GateDiag.REACTION.has(fact) and not said.has(fact) and not armed.has(fact):
		armed.append(fact)


## Гость: знания пришли кадром хоста. Первый кадр — основа (как загрузка: не событие), дальше новый факт
## диагностики — то же, что `arm`.
func follow(lore: LayerLore) -> void:
	for f in LayerLore.DIAGNOSTICS:
		if lore.knows(f) and not _base.has(f):
			_base.append(f)
			if _synced:
				arm(f)
	_synced = true


## Новое подключение к хосту: его знания снова основа; взведённое прежде — снято.
func resync() -> void:
	_base.clear()
	_synced = false
	armed.clear()


## С чистого листа (сценарий тестера, шаг `nests`): взведённое и показанное забыто.
func forget() -> void:
	armed.clear()
	said.clear()
	since_fact = INF


## Шаг: ship — корабль (x, z), post — пост рядом со своим игроком ("" — нет). Отдаёт строку реплики, которую пора
## показать, или "" — не больше одной за шаг. hidden — приборы заняты (брифинг, голосование): часы стоят.
func update(dt: float, ship: Vector2, post: String, lore: LayerLore, hidden := false) -> String:
	if hidden:
		return ""
	since_fact += dt
	if armed.is_empty():
		return ""
	if not in_place(ship):
		armed.clear()   # вне 07 реплика без контекста
		return ""
	for f in armed.duplicate():
		var stale: String = STALE[f]
		if stale != "" and lore.knows(stale):
			armed.erase(f)   # состояние устарело — не повторяем
	if since_fact < AFTER_FACT:
		return ""
	for f in armed:
		if POSTS[f] == post:
			armed.erase(f)
			said.append(f)
			return line(f)
	return ""
