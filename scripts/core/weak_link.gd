class_name WeakLink
extends RefCounted
## Плашка «Слабая связь» у гостя (ART-043, `svyaz-poteryana.md`): кадры хоста опаздывают дольше
## `NetLink.WEAK_AFTER` (порог по связи, не по кадрам/с) — плашка 400×96 у левого края, игра идёт. Снимается после
## `CALM` секунд устойчивой связи (ни одного опоздания), появляется и уходит за `FADE` — без мигания: опоздания
## внутри спокойного отсчёта начинают его заново, а не гасят и зажигают плашку. Без цвета тревоги. Рисует `DropPanel`.

const BOX := Rect2(70, 430, 400, 96)   ## x 70, y 430 при 2400×1080; масштаб H/1080 от левого края (`to_screen`)
const CALM := 2.0     ## устойчивая связь столько секунд — плашка снимается
const FADE := 0.15    ## появление и уход, с
const TEXT := "Слабая связь"

var on := false    ## связь слабая (плашка должна быть видна)
var calm := 0.0    ## секунд без опозданий с последнего
var a := 0.0       ## прозрачность плашки 0…1


## quiet — секунд без кадра хоста (`NetLink.Client.quiet`).
func update(dt: float, quiet: float) -> void:
	if quiet > NetLink.WEAK_AFTER:
		on = true
		calm = 0.0
	elif on:
		calm += dt
		if calm >= CALM:
			on = false
	a = move_toward(a, 1.0 if on else 0.0, dt / FADE)


## Плашка на экране size: у левого края при любом соотношении сторон (не от центра, как диалоги `NetDrop`).
static func to_screen(size: Vector2) -> Rect2:
	var s := size.y / NetDrop.REF_H
	return Rect2(BOX.position * s, BOX.size * s)


func visible() -> bool:
	return a > 0.0


## Сразу убрать (диалог «Связь потеряна», выход из сетевого забега).
func reset() -> void:
	on = false
	calm = 0.0
	a = 0.0
