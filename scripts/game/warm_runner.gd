class_name WarmRunner
extends RefCounted
## Прогрев шейдеров при старте (`Warmup`, #50, #424) на сцене `Main`: заставка ART-034 (`main.curtain`), члены экипажа
## каждой внешности, частицы корабля, взгляд камеры и скрытые узлы на кадр, первый взгляд по слоям. Числа и порядок
## взглядов — `scripts/core/warmup.gd` (`main.warm`); здесь — узлы. Живёт полем `main.warm_run` (#752).

var main: Main
var _drawn := false            ## прошлый шаг показал взгляд прогрева
var _shown: Array[Node] = []   ## что прогрев показал на кадр — вернуть скрытым
var _hidden: Array[Node] = []  ## что кадр по слоям (#424) скрыл — вернуть видимым
var _mates: Array = []         ## члены экипажа на время прогрева (каждая внешность)
var _emit: Array = []          ## частицы, выпущенные прогревом: [узел, прежний preprocess]


func _init(m: Main) -> void:
	main = m


## Заставка (WarmSplash, ART-034) и члены экипажа каждой внешности на время прогрева (Warmup).
func begin() -> void:
	var warm := main.warm
	if not warm.active():
		return
	main.curtain = WarmSplash.new()   # заставка ART-034: фон, полоса по доле прогрева, подсказки
	main.add_child(main.curtain)
	for r in Warmup.mate_count():   # каждая роль со снаряжением и каждая внешность (#883)
		var at: Vector2 = Warmup.MATE_AT[r % Warmup.MATE_AT.size()]
		_mates.append(main.add_mate(at.x, at.y, PI, r % Crew.Role.size(), r % CrewRig.MODELS.size()))
	for look in CrewRig.MODELS.size():   # и материалом своего игрока: свои руки у пульта энергии (#217)
		var at: Vector2 = Warmup.OWN_AT[look % Warmup.OWN_AT.size()]
		var m := main.add_mate(at.x, at.y, PI, Crew.Role.PILOT, look)
		_mates.append(m)
		main.crew_view.as_own.append(m)
	main.crew_view.apply()
	for r in Crew.Role.size():   # и полупрозрачными, как отключившийся гость (ART-043): каждая роль со снаряжением
		var g := Crew.Member.new(r)
		g.look = r % CrewRig.MODELS.size()
		var at: Vector2 = Warmup.MATE_AT[r % Warmup.MATE_AT.size()]
		g.place(at.x, at.y, PI)
		main.ghosts.append(MateGhost.new(g))
	main.net_game.ghosts_step(0.0, true)
	_particles(true)
	main.power_panel.reactor = main.reactor   # пульт энергии рисует строки под шторкой: шрифты всех размеров (#217)
	main.power_panel.panel = main.power
	main.route_card.warm(true)   # карточка у стола рисует свои кегли под шторкой (09c0-route-celi)
	main.pause_flow.warm_map(true)   # схема корабля — узел, значки и кегли под шторкой (29-shema)
	frame()


## CPUParticles3D корабля (если появятся) на время прогрева выпущены сразу (preprocess) — их шейдер собирается под
## шторкой, а не при первом событии (issue #159). Конец прогрева — снова пусто. Пар вентиля ART-071 и частицы пробоины
## ART-072 — MultiMesh с пустой карточкой: их показывает _show.
func _particles(on: bool) -> void:
	if on:
		for p: CPUParticles3D in main.ship.find_children("*", "CPUParticles3D", true, false):
			if not p.emitting:
				_emit.append([p, p.preprocess])
				p.preprocess = p.lifetime
				p.restart()
		return
	for e in _emit:
		var p: CPUParticles3D = e[0]
		if is_instance_valid(p):
			p.preprocess = e[1]
			p.restart()
			p.emitting = false
	_emit.clear()


## Конец шага: пока идёт прогрев — взгляд камеры, скрытые детали корабля на кадр, вспышка разряда, прожектор.
func frame() -> void:
	var warm := main.warm
	if not warm.active():
		return
	var k := warm.outside()
	if k >= 0:   # кадр снаружи: камера с борта в точке облёта (и всплытия, #519) смотрит на корпус (облёт ещё ждёт)
		main.flyby_cam.transform = Warmup.outside_pose(k)
		if not main.flyby_cam.current:
			main.flyby_cam.make_current()
	else:
		main.camera.position = warm.eye()   # центр мостика или место у поста (#217)
		main.camera.rotation = Vector3(warm.pitch(), warm.yaw(), 0.0)
		if not main.camera.current:   # облёт с борта ждёт: прогрев смотрит глазами на мостике
			main.camera.make_current()
	for root: Node in [main.ship, main.ocean, main.silt_view, main.samples_view, main.vote_panel.get_parent(),
			main.wreck_view, main.trip_view]:
		_show(root)
	var s := warm.stage()
	if s >= 0:   # первый взгляд по слоям (#424): слои после s на этот кадр скрыты
		var ls := layers()
		for later in range(s + 1, ls.size()):
			for n: Node3D in ls[later]:
				if n.visible:
					n.visible = false
					_hidden.append(n)
	_drawn = true


## Слои первого взгляда прогрева (Warmup.STAGES, #424): интерьер с интерфейсом (всё, чего нет ниже) → экипаж и
## корпус → вода → живой мир. Кадр слоя s показывает слои 0…s.
func layers() -> Array:
	return [[], [main.crew_view, main.ghost_view, main.hull], [main.ocean], [main.eco, main.silt_view, main.samples_view]]


## Показать на кадр скрытые узлы под root (запомнить, чтобы вернуть).
func _show(root: Node) -> void:
	for n in root.get_children(true):
		if (n is Node3D or n is CanvasItem) and not n.visible:
			n.visible = true
			_shown.append(n)
		_show(n)


## Начало шага: вернуть скрытым показанное прогревом; кадр прогрева показан — следующий взгляд.
func restore() -> void:
	for n in _shown:
		if is_instance_valid(n):
			n.visible = false
	_shown.clear()
	for n in _hidden:
		if is_instance_valid(n):
			n.visible = true
	_hidden.clear()
	if not _drawn:
		return
	_drawn = false
	var warm := main.warm
	var done := warm.advance()
	if main.curtain:
		main.curtain.set_progress(warm.progress())
	if done:
		for m in _mates:
			main.crew.erase(m)
		_mates.clear()
		main.crew_view.as_own.clear()
		main.crew_view.set_members(main.crew, main.me)
		main.ghosts.clear()
		main.net_game.ghosts_step(0.0, true)
		_particles(false)
		main.route_card.warm(false)
		main.pause_flow.warm_map(false)
		main.curtain.queue_free()   # вместе с текстурой фона
		main.curtain = null
		main._place_camera()
