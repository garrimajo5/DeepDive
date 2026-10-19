class_name EcoBus
extends RefCounted
## Шина событий экосистемы (E.emit в js/creatures.js, Unity `Core/EcoEvents.cs`): существа шлют, мир забирает раз в шаг
## (handleEvents в js/game.js). Сигнал emitted приходит сразу — так виды узнают друг о друге без прямых ссылок.
## Ключ вида проверяется по реестру Species: неизвестный вид — предупреждение, событие не отправляется.

## Дальше этого от корабля события не видны экипажу (80 м, как в браузере).
const HEARING := 80.0

signal emitted(ev: Event)


## Событие: какой вид, какое наблюдение, где и текст для ленты. Текст собирается лениво — в момент показа,
## когда известно, просканирован ли вид.
class Event:
	extends RefCounted
	var species: String
	var note: String
	var pos: Vector3
	var message: Callable  ## () -> String; пустой — событие без текста

	func _init(species_id: String, note_key: String, at: Vector3, msg: Callable = Callable()) -> void:
		species = species_id
		note = note_key
		pos = at
		message = msg

	## Текст для ленты; "" — событие без текста (только наблюдение).
	func text() -> String:
		return String(message.call()) if message.is_valid() else ""

	## Наблюдение для журнала: у вида есть заметка с ключом note (IsObservation). Иначе — только сигнал другим видам.
	func is_observation() -> bool:
		return Species.is_observation(species, note)


var pending: Array[Event] = []


## Отправить событие; null — нет такого вида в реестре (ошибка в коде вида, событие выброшено).
func emit(species: String, note: String, pos: Vector3, message: Callable = Callable()) -> Event:
	if not Species.has(species):
		push_warning("EcoBus: нет вида «%s»" % species)
		return null
	var ev := Event.new(species, note, pos, message)
	pending.append(ev)
	emitted.emit(ev)
	return ev


## Забрать все события по порядку и очистить очередь.
func take() -> Array[Event]:
	var out := pending.duplicate()
	pending.clear()
	return out


## Забрать события не дальше radius от точки (корабля), остальные выбросить.
func take_near(at: Vector3, radius: float = HEARING) -> Array[Event]:
	var out: Array[Event] = []
	for ev in pending:
		if ev.pos.distance_to(at) <= radius:
			out.append(ev)
	pending.clear()
	return out


func clear() -> void:
	pending.clear()
