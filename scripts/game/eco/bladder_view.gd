class_name BladderView
extends Node3D
## Пузырчатка-фонарь в сцене (initBladders в js/creatures.js; ART-004): все стебли — один MultiMesh из тонкого
## конуса (ставятся один раз), луковицы — второй MultiMesh со своим цветом сока у каждой, облака спор — третий
## MultiMesh из плоских светящихся точек лицом к камере (сложение цвета, без записи глубины). Сок и споры —
## зелёные (#8EE87E), своя эмиссия; стебли #3f7a5a. Стоит на слое отмели (OceanView.LAYER_WORLD).
## Стебли колышутся в течении, луковицы — на их вершинах (`EcoBladder.sway`, Б3): буфер стеблей переписывается с
## луковицами, на процессоре; «Экономно» — стоят.
## Пузырьки газа с луковиц (EcoBladderBubbles: лопнули — со всех луковиц, спелые сочатся) — четвёртый MultiMesh
## «Пузырьки» на общем шейдере EcoShaders.MIST (BUBBLE, `placed`) — +1 вызов отрисовки, шейдеров не прибавилось.
## «Экономно» (Б6, `set_lite`): рисуется половина спор каждого облака (`EcoMM.cloud_slot` — буфер вперемешку по
## кустам, `visible_instance_count` отрезает вторую половину). Мир (лопнула, свечение, сканер) не меняется.
## Луковицы не клоны (Б4, `EcoVary`): у луковицы свой размер (±BULB_SIZE_SPREAD) и яркость сока (±BULB_SHADE_SPREAD),
## у стебля — толщина (±STEM_THICK_SPREAD), по номеру луковицы; спелость куста видна по-прежнему (множители поверх
## `EcoBladder.bulb_size`/`bulb_color`). Вызовов и шейдеров столько же.
## Луковицы дышат соком (Б3, `pulse`): луковица набухает и опадает — ширина ± PULSE_W, высота ± PULSE_H за PULSE_T с
## (ритм ± PULSE_SPREAD и фаза — `EcoVary`), сок в набухшей ярче на PULSE_GLOW. Размах — по размеру луковицы
## (`pulse_k`): спелая — во весь, молодая едва, опавшая после лопания — нет (доля плавная — размах не прыгает).
## По времени мира (у гостя то же), масштаб и цвет экземпляра MultiMesh — даром, и на «Экономно».

const STEM := Color("3f7a5a")
## Луковица — сфера 0,16 м, вытянутая в 1,3 раза; спора — точка 0,35 м (в браузере 0,5 с ореолом — здесь ореол внутри точки).
const BULB_R := 0.16
const SPORE_SIZE := 0.35
const SPORE := Color(0.5, 1.0, 0.55)
## Чисел на экземпляр: transform 3 × 4, у луковиц и спор ещё цвет (4).
const STRIDE := 12
const STRIDE_C := 16
## Разброс луковиц и стеблей куста.
const BULB_SIZE_SPREAD := 0.15
const BULB_SHADE_SPREAD := 0.12
const STEM_THICK_SPREAD := 0.15
## Пульс сока (Б3).
const PULSE_W := 0.06
const PULSE_H := 0.03
const PULSE_T := 3.2
const PULSE_SPREAD := 0.2
const PULSE_GLOW := 0.15

var bladders: EcoBladder
var stems: MultiMeshInstance3D
var bulbs: MultiMeshInstance3D
var spores: MultiMeshInstance3D
var bubbles: MultiMeshInstance3D
var bubble := EcoBladderBubbles.new()
var bubble_buffer := PackedFloat32Array()
var _bubbles_empty := false
## Места пула, что видны или ждут своего мгновения, и сколько пузырьков пул уже принял (EcoBladderBubbles.added).
var _bubbles_live := PackedInt32Array()
var _bubbles_seen := 0
## Буфер стеблей: стебли колышутся в течении (`EcoBladder.sway`) — 21 экземпляр переписывается вместе с луковицами,
## на процессоре; шейдеров и вызовов не прибавилось. «Экономно» (`EcoShaders.sway_lite`) — стебли стоят.
var stem_buffer := PackedFloat32Array()
## Последние буферы луковиц и спор (для тестов).
var bulb_buffer := PackedFloat32Array()
var spore_buffer := PackedFloat32Array()
## Кусты, чьи споры в буфере ещё видны (облако было на прошлом кадре): нераскрытые кусты буфер спор не пишут
## и не грузят заново (issue #133).
var _spores_shown := PackedByteArray()
## «Экономно»: рисуется половина спор каждого облака.
var lite := false
## Разброс луковиц по номеру — считан один раз (bulb_scale, bulb_tint, stem_thick), шаг не хеширует.
var _size_k := PackedFloat32Array()
var _shade_k := PackedFloat32Array()
var _thick_k := PackedFloat32Array()


func _init(system: EcoBladder, on_lite := false) -> void:
	bladders = system
	name = "Пузырчатка"
	var n := bladders.bushes.size()
	stems = EcoMM.instance(self, "Стебли", build_stem(), n * EcoBladder.STEMS, false)
	bulbs = EcoMM.instance(self, "Луковицы", build_bulb(), n * EcoBladder.STEMS, true)
	spores = EcoMM.instance(self, "Споры", build_spore(), n * EcoBladder.SPORES, true)
	bubbles = EcoMM.instance(self, "Пузырьки", build_bubble(), EcoBladderBubbles.POOL, true)
	stem_buffer.resize(stems.multimesh.instance_count * STRIDE)
	for i in n * EcoBladder.STEMS:
		_size_k.append(bulb_scale(i))
		_shade_k.append(EcoVary.spread(i, EcoVary.SHADE, BULB_SHADE_SPREAD))
		_thick_k.append(stem_thick(i))
	EcoMM.fit([stems, bulbs, spores], places(bladders), FRAME_GROW)
	set_lite(on_lite)
	sync(0.0)


## «Экономно» — половина спор каждого облака; буфер спор переписывается целиком в следующем sync.
func set_lite(on: bool) -> void:
	lite = on
	spores.multimesh.visible_instance_count = EcoMM.cloud_shown(bladders.bushes.size(), EcoBladder.SPORES, on)
	spore_buffer = PackedFloat32Array()


## Место споры j куста bush в буфере спор.
func spore_slot(bush: int, j: int) -> int:
	return EcoMM.cloud_slot(bush, j, bladders.bushes.size(), EcoBladder.SPORES, lite)


## Сколько спор рисуется сейчас.
func spores_drawn() -> int:
	var v := spores.multimesh.visible_instance_count
	return spores.multimesh.instance_count if v < 0 else v


## Запас рамки вокруг подножий (#849): стебли, луковицы и облако спор (2,2 м вверх, 2,5 м вширь, тянется к кораблю).
const FRAME_GROW := 12.0


## Подножия кустов — по ним рамка видимости.
static func places(sys: EcoBladder) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for bl in sys.bushes:
		pts.append(bl.base)
	return pts


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
		EcoMM.put(out, i, Transform3D(Basis.from_scale(Vector3.ONE * s), o))
		out[i + 12] = c.r; out[i + 13] = c.g; out[i + 14] = c.b; out[i + 15] = a
	return out


## Расставить луковицы, споры и пузырьки в момент t (время мира); ship — корабль (дальность и луч), flow — течение.
func sync(t: float, ship: EcoLink.ShipState = null, flow := Vector3.ZERO) -> void:
	var amount := 0.0 if EcoShaders.sway_lite else 1.0
	bubble.flow = flow
	bubble.sway = amount
	_sync_bubbles(t, ship, flow)
	bulb_buffer.resize(bulbs.multimesh.instance_count * STRIDE_C)
	var fresh := spore_buffer.size() != spores.multimesh.instance_count * STRIDE_C
	spore_buffer.resize(spores.multimesh.instance_count * STRIDE_C)
	_spores_shown.resize(bladders.bushes.size())
	var spores_changed := fresh
	for bl in bladders.bushes:
		var r := EcoBladder.bulb_size(bl)
		var c := EcoBladder.bulb_color(bl)
		var pk := pulse_k(r)
		for k in EcoBladder.STEMS:
			var n := bl.index * EcoBladder.STEMS + k
			var i := n * STRIDE_C
			var top := EcoBladder.bulb(bl, k, t, flow, amount)
			var p := pulse(n, t) * pk
			var rr := r * _size_k[n]
			EcoMM.put(bulb_buffer, i, Transform3D(Basis.from_scale(Vector3(
				rr * (1.0 + PULSE_W * p), rr * (1.0 + PULSE_H * p), rr * (1.0 + PULSE_W * p))), top))
			var sk := _shade_k[n] * (1.0 + PULSE_GLOW * p)
			_color(bulb_buffer, i + STRIDE, Color(c.r * sk, c.g * sk, c.b * sk))
			var a := bl.stem_base[k]
			var up := top - a
			EcoMM.put(stem_buffer, n * STRIDE, Transform3D(_along(up, _thick_k[n]), a + up * 0.5))  # конус стоит серединой в нуле
		var popped := bl.popped()
		if not popped and not fresh and _spores_shown[bl.index] == 0:
			continue
		spores_changed = true
		_spores_shown[bl.index] = 1 if popped else 0
		var g := EcoBladder.spore_glow(bl)
		for j in EcoBladder.SPORES:
			var i := spore_slot(bl.index, j) * STRIDE_C
			if popped:
				EcoMM.put(spore_buffer, i, Transform3D(Basis.IDENTITY, EcoBladder.spore(bl, j, t)))
			else:
				EcoMM.put(spore_buffer, i, Transform3D(Basis.from_scale(Vector3.ZERO), bl.cloud))
			_color(spore_buffer, i + STRIDE, SPORE * g)
	EcoMM.send(bulbs, bulb_buffer)
	EcoMM.send(stems, stem_buffer)
	if spores_changed:
		spores.multimesh.buffer = spore_buffer


func _sync_bubbles(t: float, ship: EcoLink.ShipState, flow: Vector3) -> void:
	bubble.update(bladders, t, ship.pos if ship else Vector3.ZERO)
	var shown := pack_bubbles_into(t, flow, ship)
	if shown == 0 and _bubbles_empty:
		return   # пузырьков нет и в буфере пусто — буфер не грузим заново (issue #133)
	bubbles.multimesh.buffer = bubble_buffer
	_bubbles_empty = shown == 0


## Переписать буфер пузырьков на месте (как pack_bubbles, но без нового буфера каждый кадр и без перебора всего
## пула — замер шага мира test_eco_speed): смотрим только места, что были видны, и новые с прошлого кадра
## (EcoBladderBubbles.added); живые — на месте, растаявшие стянуты в точку один раз. Возвращает, сколько видно.
func pack_bubbles_into(t: float, flow: Vector3, ship: EcoLink.ShipState = null) -> int:
	var list := bubble.bubbles
	var pool := list.size()
	if bubble_buffer.size() != pool * STRIDE_C:
		bubble_buffer.resize(pool * STRIDE_C)
		bubble_buffer.fill(0.0)
		_bubbles_live.clear()
		_bubbles_seen = bubble.added - pool   # все места пула — на проверку
	var fresh := mini(bubble.added - _bubbles_seen, pool)
	_bubbles_seen = bubble.added
	var check := _bubbles_live
	var top := bubble.slot()
	for f in fresh:
		var n := posmod(top - 1 - f, pool)
		if not check.has(n):
			check.append(n)
	var live := PackedInt32Array()
	for n in check:
		var b := list[n]
		var i := n * STRIDE_C
		var age := t - b.born
		var a := EcoBladderBubbles.fade(b, t) if age >= 0.0 and age < EcoBladderBubbles.LIFE else 0.0
		if a <= 0.0:
			for k in STRIDE_C:
				bubble_buffer[i + k] = 0.0
			if age < 0.0:
				live.append(n)   # ещё не сорвался — ждёт своего мгновения
			continue
		live.append(n)
		var sz := EcoBladderBubbles.size(b, t)
		var o := EcoBladderBubbles.pos(b, t, flow)
		var c := EcoBladderBubbles.COLOR.lerp(EcoBladderBubbles.LIT, EcoGrazerDust.light(o, ship))
		bubble_buffer[i] = sz; bubble_buffer[i + 3] = o.x
		bubble_buffer[i + 5] = sz; bubble_buffer[i + 7] = o.y
		bubble_buffer[i + 10] = sz; bubble_buffer[i + 11] = o.z
		bubble_buffer[i + 12] = c.r; bubble_buffer[i + 13] = c.g; bubble_buffer[i + 14] = c.b; bubble_buffer[i + 15] = a
	_bubbles_live = live
	var shown := 0
	for n in live:
		if bubble_buffer[n * STRIDE_C + 15] > 0.0:
			shown += 1
	return shown


## Множитель размера луковицы n (номер — куст · STEMS + стебель); один и тот же при каждом вызове.
static func bulb_scale(n: int) -> float:
	return EcoVary.spread(n, EcoVary.SIZE, BULB_SIZE_SPREAD)


## Сок луковицы n: цвет спелости куста, ярче или тусклее на ±BULB_SHADE_SPREAD.
static func bulb_tint(c: Color, n: int) -> Color:
	var k := EcoVary.spread(n, EcoVary.SHADE, BULB_SHADE_SPREAD)
	return Color(c.r * k, c.g * k, c.b * k, c.a)


## Фаза пульса луковицы n в момент t (время мира): −1…1, ритм и фаза у каждой свои.
static func pulse(n: int, t: float) -> float:
	var rate := EcoVary.spread(n, EcoVary.RATE, PULSE_SPREAD)
	var ph := EcoVary.unit(n, EcoVary.TURN) * TAU
	return sin(t * TAU / PULSE_T * rate + ph)


## Доля размаха пульса по размеру луковицы куста (EcoBladder.bulb_size: 0,2 опавшая … 1 спелая): 0…1.
static func pulse_k(size: float) -> float:
	return clampf((size - 0.2) / 0.8, 0.0, 1.0)


## Толщина стебля n (множитель радиуса конуса).
static func stem_thick(n: int) -> float:
	return EcoVary.spread(n, EcoVary.WIDTH, STEM_THICK_SPREAD)


## Базис, что ставит единичный стебель (ось +Y, середина в нуле) от основания по вектору up; thick — толщина.
static func _along(up: Vector3, thick := 1.0) -> Basis:
	var y := up.normalized()
	var x := y.cross(Vector3.FORWARD).normalized()
	if x.length_squared() < 0.5:
		x = Vector3.RIGHT
	var z := x.cross(y)
	return Basis(x * thick, y * up.length(), z * thick)


static func _color(buf: PackedFloat32Array, i: int, c: Color) -> void:
	buf[i] = c.r; buf[i + 1] = c.g; buf[i + 2] = c.b; buf[i + 3] = 1.0


## Расстановка экземпляра n из буфера с шагом stride.
static func transform_at(buf: PackedFloat32Array, n: int, stride: int = STRIDE_C) -> Transform3D:
	var i := n * stride
	return Transform3D(Vector3(buf[i], buf[i + 4], buf[i + 8]), Vector3(buf[i + 1], buf[i + 5], buf[i + 9]),
		Vector3(buf[i + 2], buf[i + 6], buf[i + 10]), Vector3(buf[i + 3], buf[i + 7], buf[i + 11]))
