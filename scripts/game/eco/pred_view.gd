class_name PredView
extends Node3D
## Серпохвосты в сцене: у каждого — модель MOD-011 на скелете ANIM-001 (`models/serpohvost-anim.glb`, три сетки со
## skin — 3 вызова отрисовки на зверя, 5 719 треугольников). Место и курс — из мира, клипы выбирает EcoPredLook:
## Swim и SwimFast смешиваются по скорости (Blend2 с общей фазой), Bite — поверх, только челюсть, TailStrike — после
## укуса корпуса. Дерево анимации идёт вручную от времени мира (`sync`) — у гостя сети мир свой, клипы тоже.
## Глаза и фотофоры светятся сами (карта свечения в GLB). Стоит на слое отмели (OceanView.LAYER_WORLD).

## Узлы дерева анимации (parameters/<узел>/…).
const P_SWIM := "parameters/ts_swim/scale"
const P_FAST := "parameters/ts_fast/scale"
const P_MIX := "parameters/mix/blend_amount"
const P_STRIKE := "parameters/strike/request"
const P_BITE := "parameters/bite/request"
const P_STRIKE_ON := "parameters/strike/active"
const P_BITE_ON := "parameters/bite/active"

var preds: EcoPred
## Узел каждого хищника (в порядке preds.all), его дерево анимации и выбор разовых клипов.
var bodies: Array[Node3D] = []
var trees: Array[AnimationTree] = []
var cues: Array[EcoPredLook.Cues] = []

var _last_t := 0.0
var _started := false


func _init(system: EcoPred) -> void:
	preds = system
	name = "Серпохвосты"
	var scene: PackedScene = load(EcoPredLook.RIG_GLB)
	var blend := _blend_tree()
	for pr in preds.all:
		var root: Node3D = scene.instantiate()
		root.name = "Серпохвост %d" % (pr.index + 1)
		add_child(root)
		for m: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			m.layers = OceanView.LAYER_WORLD
			EcoShadows.cast(m)
		var at := AnimationTree.new()
		at.name = "Клипы"
		root.add_child(at)
		at.anim_player = NodePath("../AnimationPlayer")
		at.tree_root = blend
		at.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		at.active = true
		bodies.append(root)
		trees.append(at)
		cues.append(EcoPredLook.Cues.new())
	sync(0.0, Vector3(1e6, 0, 1e6))


## Общее дерево: Swim и SwimFast (каждый со своей скоростью, фаза одна) → Blend2 → удар серпом → укус (челюсть).
static func _blend_tree() -> AnimationNodeBlendTree:
	var bt := AnimationNodeBlendTree.new()
	var swim := AnimationNodeAnimation.new()
	swim.animation = EcoPredLook.SWIM
	var fast := AnimationNodeAnimation.new()
	fast.animation = EcoPredLook.SWIM_FAST
	var strike_clip := AnimationNodeAnimation.new()
	strike_clip.animation = EcoPredLook.STRIKE
	var bite_clip := AnimationNodeAnimation.new()
	bite_clip.animation = EcoPredLook.BITE
	var mix := AnimationNodeBlend2.new()
	mix.sync = true  # бросок идёт и при нулевом весе — фазы не расходятся
	var strike := _shot()
	var bite := _shot()
	bite.filter_enabled = true
	for b in EcoPredLook.BITE_BONES:
		bite.set_filter_path(NodePath("SerpohvostRig/Skeleton3D:" + b), true)
	bt.add_node("swim", swim, Vector2(0, 0))
	bt.add_node("fast", fast, Vector2(0, 200))
	bt.add_node("ts_swim", AnimationNodeTimeScale.new(), Vector2(200, 0))
	bt.add_node("ts_fast", AnimationNodeTimeScale.new(), Vector2(200, 200))
	bt.add_node("mix", mix, Vector2(400, 100))
	bt.add_node("strike_clip", strike_clip, Vector2(400, 300))
	bt.add_node("strike", strike, Vector2(600, 100))
	bt.add_node("bite_clip", bite_clip, Vector2(600, 300))
	bt.add_node("bite", bite, Vector2(800, 100))
	bt.connect_node("ts_swim", 0, "swim")
	bt.connect_node("ts_fast", 0, "fast")
	bt.connect_node("mix", 0, "ts_swim")
	bt.connect_node("mix", 1, "ts_fast")
	bt.connect_node("strike", 0, "mix")
	bt.connect_node("strike", 1, "strike_clip")
	bt.connect_node("bite", 0, "strike")
	bt.connect_node("bite", 1, "bite_clip")
	bt.connect_node("output", 0, "bite")
	return bt


static func _shot() -> AnimationNodeOneShot:
	var s := AnimationNodeOneShot.new()
	s.fadein_time = EcoPredLook.FADE_IN
	s.fadeout_time = EcoPredLook.FADE_OUT
	return s


## Поставить хищников по миру в момент t; ship — где корабль (укус в броске, дальние — без смены клипов).
func sync(t: float, ship: Vector3) -> void:
	var dt := clampf(t - _last_t, 0.0, 0.1)
	_last_t = t
	for i in preds.all.size():
		var pr := preds.all[i]
		var root := bodies[i]
		root.visible = pr.agent.alive
		root.transform = Transform3D(EcoPredLook.basis(pr), pr.agent.p)
		var at := trees[i]
		var rate := EcoPredLook.swim_rate(pr)
		at.set(P_SWIM, rate * EcoPredLook.SWIM_LEN)
		at.set(P_FAST, rate * EcoPredLook.SWIM_FAST_LEN)
		at.set(P_MIX, EcoPredLook.swim_mix(pr))
		var far := pr.agent.distance_to(ship) > EcoPredLook.CUE_FAR
		var cue := cues[i].update(pr, ship, t, far)
		if cue["strike"]:
			at.set(P_STRIKE, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		if cue["bite"]:
			at.set(P_BITE, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		if not _started:  # у каждого своя фаза плавания — не машут хвостами в лад
			at.advance(pr.index * 0.83)
		elif root.visible:
			at.advance(dt)
	_started = true
