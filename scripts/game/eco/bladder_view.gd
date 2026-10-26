class_name BladderView
extends Node3D
## Пузырчатка-фонарь в сцене (initBladders в js/creatures.js; ART-004): все стебли — один MultiMesh из тонкого
## конуса (ставятся один раз), луковицы — второй MultiMesh со своим цветом сока у каждой, облака спор — третий
## MultiMesh из плоских светящихся точек лицом к камере (сложение цвета, без записи глубины). Сок и споры —
## зелёные (#8EE87E), своя эмиссия; стебли #3f7a5a. Стоит на слое отмели (OceanView.LAYER_WORLD).
## Пузырьки газа с луковиц (EcoBladderBubbles: лопнули — со всех луковиц, спелые сочатся) — четвёртый MultiMesh
## «Пузырьки» на общем шейдере EcoShaders.MIST (BUBBLE, `placed`) — +1 вызов отрисовки, шейдеров не прибавилось.

const STEM := Color("3f7a5a")
## Луковица — сфера 0,16 м, вытянутая в 1,3 раза; спора — точка 0,35 м (в браузере 0,5 с ореолом — здесь ореол внутри точки).
const BULB_R := 0.16
const SPORE_SIZE := 0.35
const SPORE := Color(0.5, 1.0, 0.55)
## Чисел на экземпляр: transform 3 × 4, у луковиц и спор ещё цвет (4).
const STRIDE := 12
const STRIDE_C := 16

var bladders: EcoBladder
var stems: MultiMeshInstance3D
var bulbs: MultiMeshInstance3D
var spores: MultiMeshInstance3D
var bubbles: MultiMeshInstance3D
var bubble := EcoBladderBubbles.new()
var bubble_buffer := PackedFloat32Array()
var _bubbles_empty := false
## Последние буферы луковиц и спор (для тестов).
var bulb_buffer := PackedFloat32Array()
var spore_buffer := PackedFloat32Array()
## Кусты, чьи споры в буфере ещё видны (облако было на прошлом кадре): нераскрытые кусты буфер спор не пишут
## и не грузят заново (issue #133).
var _spores_shown := PackedByteArray()


func _init(system: EcoBladder) -> void:
	bladders = system
	name = "Пузырчатка"
	var n := bladders.bushes.size()
	stems = _instance("Стебли", build_stem(), n * EcoBladder.STEMS, false)
	bulbs = _instance("Луковицы", build_bulb(), n * EcoBladder.STEMS, true)
	spores = _instance("Споры", build_spore(), n * EcoBladder.SPORES, true)
	bubbles = _instance("Пузырьки", build_bubble(), EcoBladderBubbles.POOL, true)
	var buf := PackedFloat32Array()
	buf.resize(stems.multimesh.instance_count * STRIDE)
	for bl in bladders.bushes:
		for k in EcoBladder.STEMS:
			var a := bl.stem_base[k]
			var up := bl.stem_top[k] - a
			_put(buf, (bl.index * EcoBladder.STEMS + k) * STRIDE, Transform3D(_along(up), a + up * 0.5))  # конус стоит серединой в нуле
	stems.multimesh.buffer = buf
	sync(0.0)


func _instance(n: String, mesh: Mesh, count: int, colors: bool) -> MultiMeshInstance3D:
	var mi := MultiMeshInstance3D.new()
	mi.name = n
	mi.layers = OceanView.LAYER_WORLD
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = mesh
	mm.instance_count = count
	mi.multimesh = mm
	# облака и луковицы двигаются — границы не пересчитываем, рамка на всю отмель
	mi.custom_aabb = AABB(Vector3(-400, -200, -400), Vector3(800, 400, 800))
	add_child(mi)
	return mi


## Стебель 1 м по +Y: усечённый конус 0,04 → 0,025 м, 4 грани (в расстановке тянется на длину стебля).
static func build_stem() -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.025
	m.bottom_radius = 0.04
	m.height = 1.0
	m.radial_segments = 4
	m.rings = 1
	m.cap_top = false
	m.cap_bottom = false
	var mat := StandardMaterial3D.new()
	mat.albedo_color = STEM
	mat.roughness = 0.8
	m.material = mat
	return m


## Луковица: полупрозрачная светящаяся капля, цвет сока — цвет экземпляра.
static func build_bulb() -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = BULB_R
	m.height = BULB_R * 2.0 * 1.3
	m.radial_segments = 8
	m.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.9)
	m.material = mat
	return m


static func build_spore() -> QuadMesh:
	var m := QuadMesh.new()
	m.size = Vector2.ONE * SPORE_SIZE
	var mat := ShaderMaterial.new()
	mat.shader = EcoShaders.shader(EcoShaders.SPOT)
	mat.set_shader_parameter("fade_far", 60.0)
	m.material = mat
	return m


## Пузырёк: квадрат лицом к камере, светлый ободок и прозрачная середина (как пузыри курильщика); место, размер,
## цвет и непрозрачность — из экземпляра.
static func build_bubble() -> QuadMesh:
	var m := QuadMesh.new()
	m.size = Vector2.ONE
	m.material = EcoShaders.mist(EcoShaders.Mist.BUBBLE, {"tint": Color.WHITE, "placed": true})
	return m


## Буфер пузырьков (TRANSFORM_3D + цвет): растаявшие и не сорвавшиеся стянуты в точку, в луче прожектора — светлее.
static func pack_bubbles(d: EcoBladderBubbles, t: float, flow: Vector3,
		ship: EcoLink.ShipState = null) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(d.bubbles.size() * STRIDE_C)
	for n in d.bubbles.size():
		var b := d.bubbles[n]
		var i := n * STRIDE_C
		var a := EcoBladderBubbles.fade(b, t)
		var s := EcoBladderBubbles.size(b, t) if a > 0.0 else 0.0
		var o := EcoBladderBubbles.pos(b, t, flow) if a > 0.0 else b.at
		var c := EcoBladderBubbles.COLOR.lerp(EcoBladderBubbles.LIT, EcoGrazerDust.light(o, ship))
		_put(out, i, Transform3D(Basis.from_scale(Vector3.ONE * s), o))
		out[i + 12] = c.r; out[i + 13] = c.g; out[i + 14] = c.b; out[i + 15] = a
	return out


## Расставить луковицы, споры и пузырьки в момент t (время мира); ship — корабль (дальность и луч), flow — течение.
func sync(t: float, ship: EcoLink.ShipState = null, flow := Vector3.ZERO) -> void:
	_sync_bubbles(t, ship, flow)
	bulb_buffer.resize(bulbs.multimesh.instance_count * STRIDE_C)
	var fresh := spore_buffer.size() != spores.multimesh.instance_count * STRIDE_C
	spore_buffer.resize(spores.multimesh.instance_count * STRIDE_C)
	_spores_shown.resize(bladders.bushes.size())
	var spores_changed := fresh
	for bl in bladders.bushes:
		var r := EcoBladder.bulb_size(bl)
		var c := EcoBladder.bulb_color(bl)
		for k in EcoBladder.STEMS:
			var i := (bl.index * EcoBladder.STEMS + k) * STRIDE_C
			_put(bulb_buffer, i, Transform3D(Basis.from_scale(Vector3.ONE * r), EcoBladder.bulb(bl, k, t)))
			_color(bulb_buffer, i + STRIDE, c)
		var popped := bl.popped()
		if not popped and not fresh and _spores_shown[bl.index] == 0:
			continue
		spores_changed = true
		_spores_shown[bl.index] = 1 if popped else 0
		var g := EcoBladder.spore_glow(bl)
		for j in EcoBladder.SPORES:
			var i := (bl.index * EcoBladder.SPORES + j) * STRIDE_C
			if popped:
				_put(spore_buffer, i, Transform3D(Basis.IDENTITY, EcoBladder.spore(bl, j, t)))
			else:
				_put(spore_buffer, i, Transform3D(Basis.from_scale(Vector3.ZERO), bl.cloud))
			_color(spore_buffer, i + STRIDE, SPORE * g)
	bulbs.multimesh.buffer = bulb_buffer
	if spores_changed:
		spores.multimesh.buffer = spore_buffer


func _sync_bubbles(t: float, ship: EcoLink.ShipState, flow: Vector3) -> void:
	bubble.update(bladders, t, ship.pos if ship else Vector3.ZERO)
	var shown := bubble.shown(t)
	if shown == 0 and _bubbles_empty and bubble_buffer.size() == EcoBladderBubbles.POOL * STRIDE_C:
		return   # пузырьков нет и в буфере пусто — буфер не грузим заново (issue #133)
	bubble_buffer = pack_bubbles(bubble, t, flow, ship)
	bubbles.multimesh.buffer = bubble_buffer
	_bubbles_empty = shown == 0


## Базис, что ставит единичный стебель (ось +Y, середина в нуле) от основания по вектору up.
static func _along(up: Vector3) -> Basis:
	var y := up.normalized()
	var x := y.cross(Vector3.FORWARD).normalized()
	if x.length_squared() < 0.5:
		x = Vector3.RIGHT
	var z := x.cross(y)
	return Basis(x, y * up.length(), z)


static func _put(buf: PackedFloat32Array, i: int, tr: Transform3D) -> void:
	var b := tr.basis
	var o := tr.origin
	buf[i] = b.x.x; buf[i + 1] = b.y.x; buf[i + 2] = b.z.x; buf[i + 3] = o.x
	buf[i + 4] = b.x.y; buf[i + 5] = b.y.y; buf[i + 6] = b.z.y; buf[i + 7] = o.y
	buf[i + 8] = b.x.z; buf[i + 9] = b.y.z; buf[i + 10] = b.z.z; buf[i + 11] = o.z


static func _color(buf: PackedFloat32Array, i: int, c: Color) -> void:
	buf[i] = c.r; buf[i + 1] = c.g; buf[i + 2] = c.b; buf[i + 3] = 1.0


## Расстановка экземпляра n из буфера с шагом stride.
static func transform_at(buf: PackedFloat32Array, n: int, stride: int = STRIDE_C) -> Transform3D:
	var i := n * stride
	return Transform3D(Vector3(buf[i], buf[i + 4], buf[i + 8]), Vector3(buf[i + 1], buf[i + 5], buf[i + 9]),
		Vector3(buf[i + 2], buf[i + 6], buf[i + 10]), Vector3(buf[i + 3], buf[i + 7], buf[i + 11]))
