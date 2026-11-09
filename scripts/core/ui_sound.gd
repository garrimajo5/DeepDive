class_name UiSound
extends RefCounted
## Интерфейс и связь SND-007 (#733): касание кнопок меню, кнопка поста, приход сообщения связи, тангента рации.
## Здесь — файлы, громкости и когда звучать; играет `scripts/game/ui_sounds.gd` (`main.ui_sounds`): касания —
## `tap`/`post` прямо из мест нажатия (`MenuFlow`, `PauseFlow`, `Main.use_post`), связь и рация — `update` из
## `Main._sound`. Приёмка — `docs/zvuk/SND-007.md`.

const TAP := "res://audio/ui/ui-tap.wav"          ## меню, пауза, настройки, журнал — шина «Интерфейс»
const POST := "res://audio/ui/ui-post.wav"        ## кнопка действия у поста — «Интерфейс»
const COMMS := "res://audio/ui/comms-in.wav"      ## новое сообщение связи ART-040 — «Голоса»
const KEY := "res://audio/ui/radio-key.wav"       ## «Говорить» нажата — «Голоса»
const KEY_UP := "res://audio/ui/radio-key-up.wav" ## «Говорить» отпущена — «Голоса»

## Громкости: файлы уже сведены (UI ≈ −24 LUFS, связь ≈ −20); касания звучат чаще всего — ещё чуть тише.
const TAP_DB := -2.0
const POST_DB := 0.0
const COMMS_DB := 0.0
const KEY_DB := -2.0

const TAP_GAP := 0.06     ## с: два касания в одном кадре или вплотную — один щелчок, не дребезг


## Новое сообщение связи на плашке: cur — `Comms.cur`, shown — плашка не отложена (`Comms.shown`), last — сообщение,
## на котором уже прозвучало. Отложенное (меню, шторка) звучит, когда плашка выйдет.
static func comms_due(cur: Object, shown: bool, last: Object) -> bool:
	return cur != null and shown and cur != last


## Тангента: was — передача хотела идти в прошлом шаге, now — сейчас (`Radio.wants`). 1 — нажали, −1 — отпустили, 0.
static func key_edge(was: bool, now: bool) -> int:
	if now == was:
		return 0
	return 1 if now else -1
