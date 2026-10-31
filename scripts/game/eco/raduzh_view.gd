class_name RaduzhView
extends Node3D
## Радужники в сцене (initSwarms/swarmRender в js/creatures.js): все гребневики трёх стай — один MultiMesh из
## вытянутой сферы (0,16 × 0,24 м, сложение цвета, без записи глубины), ореолы вспышки — второй MultiMesh из мягких
## пятен лицом к камере (1,1 м). Без света гребневик — едва заметный голубоватый силуэт, в луче — бегущая радуга;
## ореол виден только у вспыхнувшей стаи (яркость glow² · 0,7). Своя эмиссия; туман для сложения выключен —
## гаснут сами к FADE_FAR. Гребневики не заходят в корпус (EcoRaduzh.member_pos_outside). Слой отмели.
## Разброс особей (Б4, EcoVary по номеру гребневика): свой размер, частота «дыхания» и яркость тёмного силуэта —
## стая не клоны; мир и его случай не меняются, вызовов отрисовки не прибавилось. Переливы по краю тела (EcoIris, Б2) —
## uniform iris, «Экономно» — EcoIris.set_lite.
## Слизь гребневиков (EcoRaduzhDust: вспыхнули в луче — облачка у нескольких гребневиков, корпус упёрся в стаю —
## облачко у задетого) — дочерний MultiMesh «Муть» на общем шейдере EcoShaders.MIST (INK) — +1 вызов отрисовки.
## «Экономно» (Б6, `set_lite`): в каждой стае рисуются два гребневика из трёх и их ореолы (каждого третьего по месту в
## стае — LITE_SKIP — нет): видимые — в начале буферов тел и ореолов (`order`), `visible_instance_count` отрезает
## остальных. Мир (вспышки, слизь, сонар, у гостя) считает всех; на «Обычно» буфер по номеру гребневика, как раньше.

const BODY_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;
uniform float fade_far = 70.0;
uniform float iris = 0.0;
varying vec3 tint;
varying float phase;
void vertex() {
	// сдвиг оттенка особи — от места гребневика (свой у каждого)
	phase = fract(dot(MODEL_MATRIX[3].xyz, vec3(0.173, 0.311, 0.257)));
	float far = length((VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz);
	tint = COLOR.rgb * clamp(1.0 - far / fade_far, 0.0, 1.0);
}
%s
void fragment() {
	// края прозрачного тела светлее середины — ряды ресничек
	float ndv = abs(dot(NORMAL, VIEW));
	float rim = 1.0 - ndv;
	ALBEDO = tint * (0.45 + rim * 0.9);
	// радуга по краю (EcoIris, Б2): доля своей яркости — в темноте силуэт тусклый, перелив тоже
	float lum = max(tint.r, max(tint.g, tint.b));
	ALBEDO += iris_film(ndv, phase * %s) * iris_weight(ndv) * rim * lum * iris;
}
"""

## Тело гребневика — сфера радиуса 1, сплющенная до 0,16 × 0,24 × 0,16 м (7 × 5 сегментов, как в браузере).
const BODY := Vector3(0.16, 0.24, 0.16)
const HALO_SIZE := 1.1
const HALO_K := 0.7
## Дальше этого гребневики и ореолы не видны (м от камеры).
const FADE_FAR := 70.0
## Чисел на экземпляр: transform 3 × 4 и цвет (4).
const STRIDE := 12
const STRIDE_C := 16
## Разброс особей: размер ±15 %, частота дыхания ±20 % (около BREATH_RATE), силуэт без света светлее-темнее ±25 %.
const SIZE_SPREAD := 0.15
const RATE_SPREAD := 0.2
const SHADE_SPREAD := 0.25
const BREATH_RATE := 2.4

var raduzh: EcoRaduzh
var bodies: MultiMeshInstance3D
var halos: MultiMeshInstance3D
## Последние буферы тел и ореолов (для тестов).
var body_buffer := PackedFloat32Array()
var halo_buffer := PackedFloat32Array()
## Разброс по номеру гребневика: размер, частота дыхания, яркость силуэта (хеш — раз, не в каждом кадре).
var _vary := PackedFloat32Array()
## Слизь гребневиков (EcoRaduzhDust); буфер — для тестов.
var dust := EcoRaduzhDust.new()
var dust_view: MultiMeshInstance3D
var dust_buffer: PackedFloat32Array:
	get:
		return _dust.data
var _dust := EcoDustBuffer.new()
## «Экономно»: в каждой стае не рисуется гребневик с местом k % LITE_SKIP == LITE_SKIP − 1.
const LITE_SKIP := 3
var lite := false
## Место гребневика в буферах по его номеру (стая · PER_SWARM + место; только «Экономно», пусто — по номеру).
var order := PackedInt32Array()


func _init(system: EcoRaduzh, on_lite := false) -> void:
	raduzh = system
	name = "Радужники"
	var n := raduzh.swarms.size() * EcoRaduzh.PER_SWARM
	bodies = EcoMM.instance(self, "Гребневики", build_body(), n, true)
	_vary.resize(n * 3)
	for i in n:
		_vary[i * 3] = member_scale(i)
		_vary[i * 3 + 1] = member_rate(i)
		_vary[i * 3 + 2] = member_shade(i)
	halos = EcoMM.instance(self, "Ореолы", build_halo(), n, true)
	dust_view = GrazerView.build_dust(EcoRaduzhDust.POOL)
	add_child(dust_view)
	if on_lite:
		set_lite(true)
	sync(0.0, Vector3(1e6, 0, 1e6), 0.0)


## «Экономно» — рисуются два гребневика из трёх в каждой стае (тела и ореолы); буферы переписываются целиком
## в следующем sync.
func set_lite(on: bool) -> void:
	lite = on
	order = lite_order(raduzh.swarms.size()) if on else PackedInt32Array()
	var shown := lite_count(raduzh.swarms.size()) if on else -1
	bodies.multimesh.visible_instance_count = shown
	halos.multimesh.visible_instance_count = shown
	body_buffer = PackedFloat32Array()   # дальние стаи пишутся не каждый кадр — места сменились, писать всех


## Рисуется ли на «Экономно» гребневик с местом k в стае.
static func lite_shown(k: int) -> bool:
	return k % LITE_SKIP != LITE_SKIP - 1


## Сколько гребневиков рисуется на «Экономно» при swarms стаях.
static func lite_count(swarms: int) -> int:
	var per := 0
	for k in EcoRaduzh.PER_SWARM:
		if lite_shown(k):
			per += 1
	return per * swarms


## Места в буферах на «Экономно»: сначала видимые по номеру, за ними — скрытые.
static func lite_order(swarms: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(swarms * EcoRaduzh.PER_SWARM)
	var at := 0
	for pass_shown: bool in [true, false]:
		for i in out.size():
			if lite_shown(i % EcoRaduzh.PER_SWARM) == pass_shown:
				out[i] = at
				at += 1
	return out


## Место гребневика n (стая · PER_SWARM + место) в буферах.
func slot_of(n: int) -> int:
	return order[n] if not order.is_empty() else n


## Сколько гребневиков рисуется сейчас.
func drawn() -> int:
	var v := bodies.multimesh.visible_instance_count
	return bodies.multimesh.instance_count if v < 0 else v


static func _material(code: String) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = EcoShaders.shader(code)
	mat.set_shader_parameter("fade_far", FADE_FAR)
	return mat


static func build_body() -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = 1.0
	m.height = 2.0
	m.radial_segments = 7
	m.rings = 5
	m.material = _material(body_code())
	EcoIris.apply(m.material as ShaderMaterial, EcoIris.RADUZH)
	return m


## Код шейдера тела с куском переливов EcoIris.
static func body_code() -> String:
	return BODY_SHADER % [EcoIris.glsl(), EcoIris._f(EcoIris.SHIFT)]


static func build_halo() -> QuadMesh:
	var m := QuadMesh.new()
	m.size = Vector2.ONE * HALO_SIZE
	m.material = _material(EcoShaders.SPOT)
	(m.material as ShaderMaterial).set_shader_parameter("halo", 1.0)
	return m


## Расставить гребневиков в момент t (время мира); корпус корабля — в ship_pos с курсом ship_yaw.
## Стая дальше FAR от корабля без вспышки переписывается раз в FAR_EVERY кадров, дальше MID — через кадр, стаи —
## вразнобой (бюджет кадра, issue #77/#133: дальних в тумане не разглядеть, за 50 м гребневики гаснут к FADE_FAR).
const FAR := EcoFish.FAR
const FAR_EVERY := 3
const MID := EcoFish.MID
const MID_EVERY := 2

var _frame := 0


## all — переписать все стаи сразу.
func sync(t: float, ship_pos: Vector3, ship_yaw: float, all := false) -> void:
	var n := bodies.multimesh.instance_count
	var full := all or body_buffer.size() != n * STRIDE_C
	body_buffer.resize(n * STRIDE_C)
	halo_buffer.resize(n * STRIDE_C)
	_frame += 1
	var by_slot := not order.is_empty()
	for sw in raduzh.swarms:
		if not full and not due(sw, ship_pos, _frame):
			continue
		var gg := sw.glow * sw.glow * HALO_K
		for k in EcoRaduzh.PER_SWARM:
			var idx := sw.index * EcoRaduzh.PER_SWARM + k
			var j := (order[idx] if by_slot else idx) * STRIDE_C
			var m := sw.members[k]
			var p := EcoRaduzh.member_pos_outside(sw, k, t, ship_pos, ship_yaw)
			var b := Basis.from_euler(Vector3(sin(t * 0.7 + m.phase) * 0.4, m.phase, 0.0))
			b = b.scaled_local(BODY * (_vary[idx * 3] * (1.0 + sin(t * _vary[idx * 3 + 1] + m.phase) * 0.08)))
			# свой силуэт без света; во вспышке радуга одна на всех
			var c := EcoRaduzh.member_color(sw, k, t) * lerpf(_vary[idx * 3 + 2], 1.0, sw.glow)
			EcoMM.put_basis(body_buffer, j, b, p)
			_color(body_buffer, j + STRIDE, c)
			# без вспышки ореол не нужен — схлопнут в точку, фрагментов не рисует
			EcoMM.put_basis(halo_buffer, j, Basis.IDENTITY if gg > 0.0 else Basis.from_scale(Vector3.ZERO), p)
			_color(halo_buffer, j + STRIDE, c * gg)
	EcoMM.send(bodies, body_buffer)
	EcoMM.send(halos, halo_buffer)


## Облачка слизи в момент t (время мира): ship — корабль (дальность, корпус и луч), flow — течение мира.
func sync_dust(t: float, ship: EcoLink.ShipState, flow := Vector3.ZERO) -> void:
	if ship == null:
		return
	dust.update(raduzh, t, ship.pos, ship.yaw)
	_dust.pack(dust.dust, t, flow, ship, EcoRaduzhDust.COLOR, EcoRaduzhDust.LIT)
	_dust.upload(dust_view)   # буфер — только когда изменился (#133), пустой слой спрятан (#849)


## Размер гребневика n (номер по всем стаям: стая · PER_SWARM + место) — множитель BODY.
static func member_scale(n: int) -> float:
	return EcoVary.spread(n, EcoVary.SIZE, SIZE_SPREAD)


## Частота «дыхания» гребневика n, рад/с.
static func member_rate(n: int) -> float:
	return BREATH_RATE * EcoVary.spread(n, EcoVary.RATE, RATE_SPREAD)


## Яркость тёмного силуэта гребневика n (без света).
static func member_shade(n: int) -> float:
	return EcoVary.spread(n, EcoVary.SHADE, SHADE_SPREAD)


## Переписать ли стаю в этом кадре: близкая или вспыхнувшая — всегда, средняя — через кадр, дальняя — в свой кадр
## из трёх.
static func due(sw: EcoRaduzh.Swarm, ship_pos: Vector3, frame: int) -> bool:
	if sw.glow > 0.0:
		return true
	var d := sw.c.distance_to(ship_pos)
	if d < MID:
		return true
	return (frame + sw.index) % (MID_EVERY if d < FAR else FAR_EVERY) == 0


static func _color(buf: PackedFloat32Array, i: int, c: Color) -> void:
	buf[i] = c.r; buf[i + 1] = c.g; buf[i + 2] = c.b; buf[i + 3] = 1.0


## Место экземпляра n из буфера.
static func origin_at(buf: PackedFloat32Array, n: int) -> Vector3:
	var i := n * STRIDE_C
	return Vector3(buf[i + 3], buf[i + 7], buf[i + 11])


## Цвет экземпляра n из буфера.
static func color_at(buf: PackedFloat32Array, n: int) -> Color:
	var i := n * STRIDE_C + STRIDE
	return Color(buf[i], buf[i + 1], buf[i + 2], buf[i + 3])
