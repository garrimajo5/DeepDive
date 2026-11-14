class_name PredView
extends Node3D
## Серпохвосты в сцене: у каждого — модель MOD-011 на скелете ANIM-001 (`models/serpohvost-anim.glb`, три сетки со
## skin — 3 вызова отрисовки на зверя, 5 719 треугольников). Место и курс — из мира, клипы выбирает EcoPredLook:
## Swim и SwimFast смешиваются по скорости (Blend2 с общей фазой), Bite — поверх, только челюсть, TailStrike — после
## укуса корпуса; переходы ANIM-005 (#1753): Hover — замер поверх плавания, BendL/BendR — хвост дугой в повороте,
## Coil — взвод в начале броска, Recoil — отход после удара серпом. Дерево анимации идёт вручную от времени мира (`sync`) — у гостя сети мир свой, клипы тоже.
## Глаза и фотофоры светятся сами (карта свечения в GLB). Муть у дна от броска (EcoPredDust) — дочерний MultiMesh
## «Муть» в мировых координатах на общем шейдере EcoShaders.MIST (INK), +1 вызов. Стоит на слое отмели
## (OceanView.LAYER_WORLD).
## Дышит жабрами — тело шире и выше в такт (`EcoPredLook.breath`, Б3), в броске — нет.
## Голос SND-008 (`EcoPredSound`): у каждого два плеера `AudioStreamPlayer3D` на шине «Мир» — щелчки поиска и
## разовые (рык броска, укус, уход после разряда), чтобы щелчок не обрывал рык.

## Узлы дерева анимации (parameters/<узел>/…) — StringName: строка не разбирается в путь каждый кадр (#850).
const P_SWIM := &"parameters/ts_swim/scale"
const P_FAST := &"parameters/ts_fast/scale"
const P_MIX := &"parameters/mix/blend_amount"
const P_STRIKE := &"parameters/strike/request"
const P_BITE := &"parameters/bite/request"
const P_STRIKE_ON := &"parameters/strike/active"
const P_BITE_ON := &"parameters/bite/active"
const P_HOVER := &"parameters/hover/blend_amount"
const P_BEND_L := &"parameters/bend_l/blend_amount"
const P_BEND_R := &"parameters/bend_r/blend_amount"
const P_COIL := &"parameters/coil/request"
const P_RECOIL := &"parameters/recoil/request"
const P_COIL_ON := &"parameters/coil/active"
const P_RECOIL_ON := &"parameters/recoil/active"

var preds: EcoPred
## Узел каждого хищника (в порядке preds.all), его дерево анимации и выбор разовых клипов.
var bodies: Array[Node3D] = []
var trees: Array[AnimationTree] = []
var cues: Array[EcoPredLook.Cues] = []
## Часы скелета каждого (LOD анимации: вдали реже, дальше EcoPredLook.HIDE_FAR — спрятан и стоит, #850).
var clocks: Array[EcoPredLook.Clock] = []
## Голос каждого (EcoPredSound.Call) и его плееры: щелчки и разовые звуки; last_cue — что прозвучало (для тестов).
var voices: Array[EcoPredSound.Call] = []
var clicks: Array[AudioStreamPlayer3D] = []
var calls: Array[AudioStreamPlayer3D] = []
var last_cue: Array[int] = []
var _streams := {}
## «Экономно» (Б6, `set_lite`): скелет — как на «Обычно» (прореживание в луче дёргало хвост, #1753).
var lite := false

## Муть от броска у дна и её MultiMesh; буфер мути — для тестов.
var dust := EcoPredDust.new()
var dust_view: MultiMeshInstance3D
## Буфер мути (EcoDustBuffer, issue #732).
var dust_buffer: PackedFloat32Array:
	get:
		return _dust.data
var _dust := EcoDustBuffer.new()

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
		clocks.append(EcoPredLook.Clock.new())
		voices.append(EcoPredSound.Call.new(pr.index))
		clicks.append(_player(root, "Щелчки", EcoPredSound.CLICK_FAR))
		calls.append(_player(root, "Голос", EcoPredSound.LOUD_FAR))
		last_cue.append(EcoPredSound.Cue.NONE)
	dust_view = GrazerView.build_dust(EcoPredDust.POOL)
	add_child(dust_view)
	sync(0.0, Vector3(1e6, 0, 1e6))


func _player(root: Node3D, title: String, far: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = title
	p.bus = SoundMix.WORLD
	p.unit_size = EcoPredSound.UNIT
	p.max_distance = far
	p.attenuation_filter_cutoff_hz = EcoPredSound.MUFFLE_HZ
	p.attenuation_filter_db = EcoPredSound.MUFFLE_DB
	root.add_child(p)
	return p


## Сыграть звук cue зверя i (не в дереве сцены — только запомнить).
func _voice(i: int, cue: EcoPredSound.Cue) -> void:
	last_cue[i] = cue
	if cue == EcoPredSound.Cue.NONE:
		return
	var p := clicks[i] if cue == EcoPredSound.Cue.CLICK else calls[i]
	var path := EcoPredSound.path_of(cue)
	if not _streams.has(path):
		_streams[path] = load(path)
	p.stream = _streams[path]
	p.volume_db = EcoPredSound.CLICK_DB if cue == EcoPredSound.Cue.CLICK else EcoPredSound.LOUD_DB
	if p.stream and p.is_inside_tree():
		p.play()


## «Экономно» — скелет реже (EcoPredLook.Clock.step_at).
func set_lite(on: bool) -> void:
	lite = on


## Общее дерево: Swim и SwimFast (каждый со своей скоростью, фаза одна) → Blend2 → замер Hover → изгиб BendL/BendR
## (только хвост и передние плавники) → взвод Coil → отход Recoil → удар серпом → укус (челюсть).
static func _blend_tree() -> AnimationNodeBlendTree:
	var bt := AnimationNodeBlendTree.new()
	var mix := AnimationNodeBlend2.new()
	mix.sync = true  # бросок идёт и при нулевом весе — фазы не расходятся
	bt.add_node("swim", _clip(EcoPredLook.SWIM), Vector2(0, 0))
	bt.add_node("fast", _clip(EcoPredLook.SWIM_FAST), Vector2(0, 200))
	bt.add_node("ts_swim", AnimationNodeTimeScale.new(), Vector2(200, 0))
	bt.add_node("ts_fast", AnimationNodeTimeScale.new(), Vector2(200, 200))
	bt.add_node("mix", mix, Vector2(400, 100))
	bt.connect_node("ts_swim", 0, "swim")
	bt.connect_node("ts_fast", 0, "fast")
	bt.connect_node("mix", 0, "ts_swim")
	bt.connect_node("mix", 1, "ts_fast")
	var hover := AnimationNodeBlend2.new()
	var bend_l := AnimationNodeBlend2.new()
	var bend_r := AnimationNodeBlend2.new()
	for b in [bend_l, bend_r]:
		b.filter_enabled = true
		for bone in EcoPredLook.BEND_BONES:
			b.set_filter_path(NodePath("SerpohvostRig/Skeleton3D:" + bone), true)
	var recoil := _shot(EcoPredLook.RECOIL_FADE)
	recoil.filter_enabled = true
	for bone in EcoPredLook.RECOIL_BONES:
		recoil.set_filter_path(NodePath("SerpohvostRig/Skeleton3D:" + bone), true)
	var bite := _shot()
	bite.filter_enabled = true
	for b in EcoPredLook.BITE_BONES:
		bite.set_filter_path(NodePath("SerpohvostRig/Skeleton3D:" + b), true)
	# звено за звеном: вход 0 — всё, что ниже по цепочке, вход 1 — свой клип
	var chain := [
		["hover", hover, EcoPredLook.HOVER],
		["bend_l", bend_l, EcoPredLook.BEND_L],
		["bend_r", bend_r, EcoPredLook.BEND_R],
		["coil", _shot(), EcoPredLook.COIL],
		["recoil", recoil, EcoPredLook.RECOIL],
		["strike", _shot(), EcoPredLook.STRIKE],
		["bite", bite, EcoPredLook.BITE],
	]
	var below := "mix"
	var x := 600
	for link in chain:
		var id: String = link[0]
		bt.add_node(id, link[1], Vector2(x, 100))
		bt.add_node(id + "_clip", _clip(link[2]), Vector2(x, 300))
		bt.connect_node(id, 0, below)
		bt.connect_node(id, 1, id + "_clip")
		below = id
		x += 200
	bt.connect_node("output", 0, below)
	return bt


static func _clip(clip: String) -> AnimationNodeAnimation:
	var a := AnimationNodeAnimation.new()
	a.animation = clip
	return a


static func _shot(fade := 0.0) -> AnimationNodeOneShot:
	var s := AnimationNodeOneShot.new()
	s.fadein_time = fade if fade > 0.0 else EcoPredLook.FADE_IN
	s.fadeout_time = fade if fade > 0.0 else EcoPredLook.FADE_OUT
	return s


## Поставить хищников по миру в момент t; ship — где корабль (укус в броске, дальние — без смены клипов).
## state — корабль для мути (в луче прожектора светлее), flow — течение (уносит муть), ground — дно мира.
func sync(t: float, ship: Vector3, state: EcoLink.ShipState = null, flow := Vector3.ZERO,
		ground := Callable()) -> void:
	_sync_dust(t, ship, state, flow, ground)
	var dt := clampf(t - _last_t, 0.0, 0.1)
	_last_t = t
	for i in preds.all.size():
		var pr := preds.all[i]
		var root := bodies[i]
		var dist := pr.agent.distance_to(ship)
		root.visible = pr.agent.alive and dist <= EcoPredLook.HIDE_FAR
		var breath := EcoPredLook.breath_scale(EcoPredLook.breath(pr, t))
		root.transform = Transform3D(EcoPredLook.basis(pr).scaled_local(breath), pr.agent.p)
		var at := trees[i]
		var cue := cues[i].update(pr, ship, t, dist > EcoPredLook.CUE_FAR)
		_voice(i, voices[i].update(pr, t, dist) if pr.agent.alive else EcoPredSound.Cue.NONE)
		var step := clocks[i].tick(dt, dist, lite)
		if not _started:  # у каждого своя фаза плавания — не машут хвостами в лад
			step = pr.index * 0.83
		elif not root.visible:
			step = 0.0
		elif step <= 0.0 and (cue["strike"] or cue["bite"] or cue["coil"] or cue["recoil"]):
			step = clocks[i].flush()   # на «Экономно» между позами: разовый клип не теряется
		if step <= 0.0:
			continue  # спрятан или вдали между позами — дерево не трогаем: укусов и ударов там нет (CUE_FAR < ANIM_FAR)
		var rate := EcoPredLook.swim_rate(pr)
		at.set(P_SWIM, rate * EcoPredLook.SWIM_LEN)
		at.set(P_FAST, rate * EcoPredLook.SWIM_FAST_LEN)
		at.set(P_MIX, EcoPredLook.swim_mix(pr))
		at.set(P_HOVER, cues[i].hover)
		var bend := cues[i].bend
		at.set(P_BEND_L, maxf(bend, 0.0))
		at.set(P_BEND_R, maxf(-bend, 0.0))
		if cue["coil"]:
			at.set(P_COIL, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		if cue["recoil"]:
			at.set(P_RECOIL, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		if cue["strike"]:
			at.set(P_STRIKE, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		if cue["bite"]:
			at.set(P_BITE, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		at.advance(step)
	_started = true


func _sync_dust(t: float, ship: Vector3, state: EcoLink.ShipState, flow: Vector3, ground: Callable) -> void:
	dust.update(preds, t, ship, ground)
	_dust.pack(dust.dust, t, flow, state, EcoPredDust.COLOR, EcoPredDust.LIT,
			Seabed.mesh_height)
	_dust.upload(dust_view)   # буфер — только когда изменился (#133), пустой слой спрятан (#849)
