class_name HandSound
extends RefCounted
## Руки экипажа SND-006 (#719): сварка пробоины, сканер биолога за работой и «вид изучен». Здесь — файлы, места
## и громкости; играет `scripts/game/hand_sounds.gd` (`main.hand_sounds`) в осях корабля на шине «Корабль», шаг —
## из `Main._sound`. Импульс, завязший в иле, — `HullSound.JAM` (`ShipSounds.play_ping`). Приёмка —
## `docs/zvuk/SND-006.md`.

const WELD := "res://audio/ship/weld.wav"
const SCAN := "res://audio/ship/scanner-hold.wav"
const DONE := "res://audio/ship/scanner-done.wav"
const LOOPS: Array[String] = [WELD, SCAN]

## Сварка: 3D у шва (`Crew.Member.weld_at`) — поверх струи пробоины (`BreachView.JET_DB` −2 дБ), в соседнем отсеке тише.
const WELD_DB := 0.0
const WELD_UNIT := 2.5
const WELD_FAR := 18.0

## Сканер — у поста «Сканер» на правом борту мостика (`Deck.posts`), на плече у пульта.
const SCAN_AT := Vector3(3.85, 1.2, -2.0)
const SCAN_DB := -8.0        ## прибор работает — тихо, под голосом и тревогой
const DONE_DB := -4.0        ## «вид изучен» — заметно, один раз
const SCAN_UNIT := 2.0
const SCAN_FAR := 14.0       ## с кормы машинного не слышно

const FADE := 0.15           ## с: подъём и спад петель (без щелчка); отпустил кнопку — стихает быстро


## Точка шва первого, кто варит (`Crew.Member.welding`), в осях корабля; никто — INF.
static func weld_point(crew: Array) -> Vector3:
	for m: Crew.Member in crew:
		if m.welding():
			return m.weld_at
	return Vector3.INF


## Доля громкости петли 0…1 к цели on за шаг dt.
static func fade(gain: float, on: bool, dt: float) -> float:
	return move_toward(gain, 1.0 if on else 0.0, dt / FADE)
