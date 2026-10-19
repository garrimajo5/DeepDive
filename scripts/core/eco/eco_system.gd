class_name EcoSystem
extends RefCounted
## Модуль экосистемы — один вид или связь видов (как блоки E.update в js/creatures.js, Unity `IEcoSystem`).
## Файл вида — scripts/core/eco/<вид>.gd, наследует EcoSystem и переопределяет reset и step.


## Расставить существ заново (мир сброшен, случай — с начала).
func reset(_world: EcoWorld) -> void:
	pass


## Шаг на dt секунд (не больше EcoWorld.MAX_STEP).
func step(_world: EcoWorld, _dt: float) -> void:
	pass
