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


## Импульс сонара корабля из точки pos (E.onPing) — мир зовёт в начале шага, где ShipState.sonar_ping.
func on_ping(_world: EcoWorld, _pos: Vector3) -> void:
	pass


## Разряд по корпусу радиусом radius м вокруг корабля (E.onZap) — в начале шага, где ShipState.zap.
func on_zap(_world: EcoWorld, _radius: float) -> void:
	pass


## Заметные существа модуля для сонара и сканера (E.scanTargets): добавить в out по EcoWorld.target(…) на каждое.
func targets(_world: EcoWorld, _out: Array[Dictionary]) -> void:
	pass
