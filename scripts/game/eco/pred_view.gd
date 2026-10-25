class_name PredView
extends Node3D
## Серпохвосты в сцене: у каждого — тело, хвост со серпом и нижняя челюсть из моделей художника MOD-011
## (3 вызова отрисовки на зверя, 5 719 треугольников). Место и курс — из мира, хвост и пасть — EcoPredLook.
## Глаза и фотофоры светятся сами (карта свечения в GLB). Стоит на слое отмели (OceanView.LAYER_WORLD).

## Как быстро пасть догоняет нужное раскрытие (1/с).
const JAW_FOLLOW := 8.0

var preds: EcoPred
## Узел каждого хищника (в порядке preds.all) и его хвост и челюсть.
var bodies: Array[Node3D] = []
var tails: Array[Node3D] = []
var jaws: Array[Node3D] = []

var _last_t := 0.0


func _init(system: EcoPred) -> void:
	preds = system
	name = "Серпохвосты"
	var body_scene: PackedScene = load(EcoPredLook.BODY_GLB)
	var tail_scene: PackedScene = load(EcoPredLook.TAIL_GLB)
	var jaw_scene: PackedScene = load(EcoPredLook.JAW_GLB)
	for pr in preds.all:
		var root := Node3D.new()
		root.name = "Серпохвост %d" % (pr.index + 1)
		add_child(root)
		root.add_child(_part(body_scene, Vector3.ZERO))
		var tail := _part(tail_scene, EcoPredLook.TAIL_ROOT)
		root.add_child(tail)
		var jaw := _part(jaw_scene, EcoPredLook.JAW_HINGE)
		root.add_child(jaw)
		bodies.append(root)
		tails.append(tail)
		jaws.append(jaw)
	sync(0.0, Vector3(1e6, 0, 1e6))


## Часть модели на своём месте; все меши — на слой отмели, с тенью (EcoShadows).
static func _part(scene: PackedScene, at: Vector3) -> Node3D:
	var n: Node3D = scene.instantiate()
	n.position = at
	for m: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		m.layers = OceanView.LAYER_WORLD
		EcoShadows.cast(m)
	return n


## Поставить хищников по миру в момент t; ship — где корабль (пасть раскрывается в броске).
func sync(t: float, ship: Vector3) -> void:
	var dt := clampf(t - _last_t, 0.0, 0.1)
	_last_t = t
	for i in preds.all.size():
		var pr := preds.all[i]
		var root := bodies[i]
		root.visible = pr.agent.alive
		root.transform = Transform3D(EcoPredLook.basis(pr), pr.agent.p)
		tails[i].rotation.y = EcoPredLook.tail_angle(pr, t)
		var want := EcoPredLook.jaw_angle(pr, ship, t)
		var now := -jaws[i].rotation.x
		jaws[i].rotation.x = -lerpf(now, want, minf(1.0, dt * JAW_FOLLOW)) if dt > 0.0 else -want
