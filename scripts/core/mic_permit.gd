class_name MicPermit
extends RefCounted
## Разрешение микрофона Android для рации ART-041 (#634; решение владельца 27.10 — встроенными средствами Godot).
## В пресетах экспорта — `permissions/record_audio`, в проекте — `audio/driver/enable_input`. На Android микрофон
## включаем, только когда разрешение выдано (`OS.get_granted_permissions`): иначе `Radio.mic` = false — «Нет
## доступа» и просьба «Разрешите микрофон». Системный запрос — сами, при первом нажатии кнопки без доступа (раз за
## сеанс) и по «В настройки» (`Radio.settings_wanted`); Android после двух отказов окно не показывает — тогда только
## настройки телефона. Ответ не ждём сигналом — опрашиваем список, пока разрешения нет: раз в `POLL` в `WAIT` после
## запроса, иначе раз в `IDLE`, и только пока рация на экране (`on`, кооп). Список — запрос к системе Android
## (20–40 мс на эмуляторе, «интерфейс/рация» в логе тестера): в одиночной игре его не трогаем вовсе.
## Не Android (ПК, тесты) — разрешение не нужно. Узлов нет: `OverlayFlow.radio_step` даёт список и делает запрос.

const NAME := "android.permission.RECORD_AUDIO"
const POLL := 0.5            ## как часто смотреть список разрешений сразу после запроса, с
const WAIT := 20.0           ## сколько после запроса опрашивать часто (ответ в окне или из настроек), с
const IDLE := 5.0            ## как часто смотреть список в остальное время, пока доступа нет, с

var needed := false          ## телефон Android: без разрешения микрофон не включаем
var granted := false
var asked := false           ## первое нажатие уже спросило — дальше только «В настройки»
var _poll := 0.0
var _fast := 0.0             ## осталось частого опроса после запроса, с


static func here() -> MicPermit:
	var p := MicPermit.new()
	p.needed = OS.has_feature("android")
	return p


## Микрофон можно включать.
func ok() -> bool:
	return not needed or granted


## Шаг: `on` — рация на экране (кооп; иначе список не трогаем), `pressed` — в этом шаге нажали кнопку рации без
## доступа (`Radio.begged`), `retry` — «В настройки», `list` — Callable() → PackedStringArray выданных разрешений.
## true — пора показать системный запрос.
func step(dt: float, on: bool, pressed: bool, retry: bool, list: Callable) -> bool:
	if not needed or granted:
		return false
	if not on:
		_poll = 0.0   # рация появится — посмотрим сразу
		return false
	_poll -= dt
	_fast = maxf(_fast - dt, 0.0)
	if _poll <= 0.0:
		_poll = POLL if _fast > 0.0 else IDLE
		granted = NAME in list.call()
		if granted:
			return false
	if retry or (pressed and not asked):
		asked = true
		_poll = 0.0   # ответ мог прийти сразу — посмотрим на следующем шаге
		_fast = WAIT
		return true
	return false
