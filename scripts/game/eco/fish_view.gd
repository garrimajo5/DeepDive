class_name FishView
extends MultiMeshInstance3D
## Светляки-полосники в сцене: все рыбки (стаи рифа, кроны и молодь в костях) — один MultiMesh (один вызов отрисовки). Форма — EcoFishLook, место
## и курс каждой рыбки — EcoFishLook.basis, цвет полос — EcoFishLook.stripe в INSTANCE_CUSTOM.rgb, оттенок тела особи
## (EcoFishLook.shade, Б4) — в INSTANCE_CUSTOM.a; размер и ритм виляния у каждой свои. Краска вершины лежит
## в цвете вершины (r: 0 — тело, 1 — полоса, FIN_GLOW — конец хвоста): тело тёмное и освещается, полосы светятся сами.
## Хвост и корма гнутся бегущей волной (EcoFishLook.tail_wave, Б3): фаза особи — альфа цвета экземпляра (Godot множит
## цвет экземпляра на цвет вершины, у вершин альфа 1); «Экономно» — sway_k = 0 через EcoShaders.follow / set_sway_lite.
## Грудные плавники гребут вверх-вниз (EcoFishLook.fin_flap, вес — канал b цвета вершины): у светляка вес 0, тот же
## шейдер рисует пестрянок (HvatenView, форма EcoPestrLook). Переливы чешуи по углу (EcoIris, Б2) — uniform iris,
## сдвиг оттенка — от фазы особи; у пестрянок iris = 0, «Экономно» — EcoIris.set_lite. Стоит на слое отмели (OceanView.LAYER_WORLD).
## Муть у дна (EcoFishDust: всполошились у дна — облачка из-под хвостов, забились в коралл — клуб у дна под домом) —
## дочерний MultiMesh «Муть» (GrazerView.build_dust, общий шейдер мути, +1 вызов).
## «Экономно» (Б6, `set_lite`): рисуются две рыбки из трёх в каждой стае (LITE_SKIP — каждая третья по месту в стае
## `Fish.slot` не рисуется): видимые — в начале буфера (`order`), `visible_instance_count` отрезает остальных. Мир
## (стаи, тревоги, хищники, сканер, у гостя) считает всех; на «Обычно» буфер по номеру рыбки, как раньше.

const SHADER := """
shader_type spatial;
render_mode cull_back;
""" + EcoGlow.GLSL + """
uniform vec3 body_color : source_color;
uniform float sway_k = 1.0;
uniform float rough = 0.6;
uniform float spec = 0.5;
uniform float iris = 0.0;
varying vec3 glow;
varying float phase;
varying float paint;
varying float shade;
void vertex() {
	glow = INSTANCE_CUSTOM.rgb;
	shade = INSTANCE_CUSTOM.a;
	paint = COLOR.r;
	// волна хвоста — двойник EcoFishLook.tail_wave
	float a = COLOR.a;
	phase = a;
	float s = clamp((%s - VERTEX.z) / %s, 0.0, 1.0);
	float rate = %s * (%s + %s * fract(a * 7.13));
	VERTEX.x += sin(TIME * rate + a * 6.2831853 + VERTEX.z * %s) * %s * s * s * sway_k;
	// взмах грудных плавников (вес — канал b, у светляка 0) — двойник EcoFishLook.fin_flap
	VERTEX.y += sin(TIME * %s + a * 6.2831853 + sign(VERTEX.x) * %s) * %s * COLOR.b * sway_k;
}
%s
void fragment() {
	// перелив чешуи по углу к взгляду (EcoIris, Б2): к телу, под светом; у пестрянок iris = 0
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 body = body_color * shade + iris_film(ndv, fract(phase) * %s) * iris_weight(ndv) * iris;
	// полоса — узкая середина кольца, конец хвоста — канал g
	float p = smoothstep(0.55, 0.95, paint) + COLOR.g;
	ALBEDO = mix(body, glow * 0.3, clamp(p, 0.0, 1.0));
	ROUGHNESS = rough;
	SPECULAR = spec;
	EMISSION = eco_bio(glow * p * 1.8);
}
"""

var fish: EcoFish
## «Экономно»: в каждой стае не рисуется рыбка с местом в стае slot % LITE_SKIP == LITE_SKIP − 1.
const LITE_SKIP := 3
var lite := false
## Место рыбки в буфере по её номеру (только «Экономно»; пусто — по номеру).
var order := PackedInt32Array()
## Муть у дна от стай (Б3).
var dust := EcoFishDust.new()
var dust_view: MultiMeshInstance3D
## Буфер мути (EcoDustBuffer, issue #732).
var dust_buffer: PackedFloat32Array:
	get:
		return _dust.data
var _dust := EcoDustBuffer.new()


func _init(system: EcoFish) -> void:
	fish = system
	name = "Светляки"
	layers = OceanView.LAYER_WORLD
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true  # белый: без цвета экземпляра Compatibility гасит COLOR вершин
	mm.use_custom_data = true
	mm.mesh = build_mesh()
	mm.instance_count = fish.all.size()
	multimesh = mm
	dust_view = GrazerView.build_dust(EcoFishDust.POOL)
	add_child(dust_view)
	sync(0.0)


## «Экономно» — рисуются две рыбки из трёх в каждой стае; буфер переписывается целиком в следующем sync.
func set_lite(on: bool) -> void:
	lite = on
	if on:
		order = lite_order(fish)
		multimesh.visible_instance_count = lite_count(fish)
	else:
		order = PackedInt32Array()
		multimesh.visible_instance_count = -1
	buffer = PackedFloat32Array()   # у дальних стай fill пропускает рыбок — места сменились, писать всех


## Рисуется ли рыбка на «Экономно».
static func lite_shown(f: EcoFish.Fish) -> bool:
	return f.slot % LITE_SKIP != LITE_SKIP - 1


## Сколько рыбок рисуется на «Экономно».
static func lite_count(system: EcoFish) -> int:
	var n := 0
	for f: EcoFish.Fish in system.all:
		if lite_shown(f):
			n += 1
	return n


## Места в буфере на «Экономно»: сначала видимые по номеру, за ними — скрытые.
static func lite_order(system: EcoFish) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(system.all.size())
	var k := 0
	for f: EcoFish.Fish in system.all:
		if lite_shown(f):
			out[f.index] = k
			k += 1
	for f: EcoFish.Fish in system.all:
		if not lite_shown(f):
			out[f.index] = k
			k += 1
	return out


## Сколько рыбок рисуется сейчас.
func drawn() -> int:
	var v := multimesh.visible_instance_count
	return multimesh.instance_count if v < 0 else v


## Место рыбки n (номер `Fish.index`) в буфере.
func slot_of(n: int) -> int:
	return order[n] if not order.is_empty() else n


## Меш одной рыбки по EcoFishLook: вершины, нормали, краска в цвете вершины.
static func build_mesh() -> ArrayMesh:
	var colors := PackedColorArray()
	for p in EcoFishLook.paints:
		match p:
			EcoFishLook.Paint.STRIPE:
				colors.append(Color(1, 0, 0))
			EcoFishLook.Paint.FIN:
				colors.append(Color(0, EcoFishLook.FIN_GLOW, 0))
			_:
				colors.append(Color(0, 0, 0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = EcoFishLook.shape
	arrays[Mesh.ARRAY_NORMAL] = EcoFishLook.normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = EcoFishLook.tris
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = EcoShaders.shader(shader_code())
	mat.set_shader_parameter("body_color", EcoFishLook.BODY_COLOR)
	EcoIris.apply(mat, EcoIris.FISH)
	mesh.surface_set_material(0, EcoShaders.follow(mat))
	return mesh


## Код шейдера с числами волны хвоста из EcoFishLook.
static func shader_code() -> String:
	var L := EcoFishLook
	return SHADER % [_f(L.TAIL_FROM), _f(L.TAIL_FROM - L.TAIL_TIP), _f(L.TAIL_RATE), _f(1.0 - L.TAIL_RATE_SPREAD),
		_f(2.0 * L.TAIL_RATE_SPREAD), _f(L.TAIL_K), _f(L.TAIL_AMP), _f(L.PEC_RATE), _f(L.PEC_SKEW), _f(L.PEC_AMP),
		EcoIris.glsl(), _f(EcoIris.SHIFT)]


static func _f(x: float) -> String:
	return "%.5f" % x


## Расставить рыбок по миру в момент t (время мира): один буфер MultiMesh за раз. ship — корабль (муть — ближе
## EcoGrazerDust.NEAR, светлее в луче; null — мути нет), flow — течение мира (уносит муть), ground — дно мира.
func sync(t: float, ship: EcoLink.ShipState = null, flow := Vector3.ZERO, ground := Callable()) -> void:
	if ship != null:
		dust.update(fish, t, ship.pos, ground)
		_dust.pack(dust.dust, t, flow, ship, EcoFishDust.COLOR, EcoFishDust.LIT, Seabed.mesh_height)
		_dust.upload(dust_view)   # буфер — только когда изменился (#133), пустой слой спрятан (#849)
	if order.size() != (fish.all.size() if lite else 0):
		order = lite_order(fish) if lite else PackedInt32Array()   # мир пересобран — места заново
		multimesh.visible_instance_count = lite_count(fish) if lite else -1
		buffer = PackedFloat32Array()
	if buffer.size() != fish.all.size() * STRIDE:
		buffer = pack(fish, t, order)
	else:
		fill(buffer, fish, t, true, order)
	multimesh.buffer = buffer


## Последний буфер MultiMesh (по нему проверяют тесты: в headless сервер отрисовки буфер не хранит).
var buffer := PackedFloat32Array()

## Чисел на рыбку в буфере: transform 3 × 4 по строкам, цвет экземпляра (белый, в альфе — фаза хвоста
## EcoFishLook.tail_phase), затем INSTANCE_CUSTOM.
const STRIDE := 20

## Разброс особей по номеру рыбки: размер (EcoFishLook.scale без возраста), частота виляния, оттенок тела, фаза
## хвоста — считается раз (хеш на каждую рыбку в каждом кадре дорог).
static var _vary := PackedFloat32Array()
const VARY := 4


static func _vary_of(system: EcoFish) -> PackedFloat32Array:
	if _vary.size() != system.all.size() * VARY:
		_vary.resize(system.all.size() * VARY)
		for f: EcoFish.Fish in system.all:
			_vary[f.index * VARY] = EcoVary.spread(f.index, EcoVary.SIZE, EcoFishLook.SIZE_SPREAD)
			_vary[f.index * VARY + 1] = EcoFishLook.wiggle_rate(f)
			_vary[f.index * VARY + 2] = EcoFishLook.shade(f)
			_vary[f.index * VARY + 3] = EcoFishLook.tail_phase(f)
	return _vary


## Буфер MultiMesh (TRANSFORM_3D + custom data) для всех рыбок в момент t. Те же числа, что EcoFishLook.basis
## и EcoFishLook.stripe, но без вызовов на каждую рыбку (132 за кадр): цвет и тревога — по стае, basis — на месте.
## at — места в буфере по номеру рыбки (`lite_order`), пусто — по номеру.
static func pack(system: EcoFish, t: float, at := PackedInt32Array()) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(system.all.size() * STRIDE)
	fill(out, system, t, false, at)
	return out


## Переписать буфер out (размер — на всех рыбок). moved_only — только стаи, шагнувшие в этом кадре: дальняя стая
## копит время (lag > 0) и стоит на месте — её рыбки остаются как были, только съеденные гаснут (issue #133).
static func fill(out: PackedFloat32Array, system: EcoFish, t: float, moved_only: bool,
		at := PackedInt32Array()) -> void:
	var vary := _vary_of(system)
	var by_slot := not at.is_empty()
	for sh in system.shoals:
		if moved_only and sh.lag > 0.0:
			for f: EcoFish.Fish in sh.members:
				if not f.agent.alive:
					var j := (at[f.index] if by_slot else f.index) * STRIDE
					for c in [0, 1, 2, 4, 5, 6, 8, 9, 10]:
						out[j + c] = 0.0
			continue
		var glow := EcoFishLook.ALARM_GLOW if sh.alarm > 0.0 else 1.0
		var col := sh.color
		for f: EcoFish.Fish in sh.members:
			var a := f.agent
			var i := (at[f.index] if by_slot else f.index) * STRIDE
			var o := a.p
			out[i + 3] = o.x
			out[i + 7] = o.y
			out[i + 11] = o.z
			out[i + 12] = 1.0
			out[i + 13] = 1.0
			out[i + 14] = 1.0
			out[i + 15] = vary[f.index * VARY + 3]
			var k := f.bright * glow
			out[i + 16] = col.r * k
			out[i + 17] = col.g * k
			out[i + 18] = col.b * k
			out[i + 19] = vary[f.index * VARY + 2]
			if not a.alive:
				for c in [0, 1, 2, 4, 5, 6, 8, 9, 10]:
					out[i + c] = 0.0  # съеденная — нулевой basis
				continue
			# EcoFishLook.forward: нос по скорости с вилянием вокруг вертикали
			var v := f.look if f.look.length_squared() > 1e-8 else a.v   # нос догоняет скорость (EcoFish.turn)
			var dir := v.normalized() if v.length_squared() > 1e-8 else Vector3(0, 0, 1)
			var w := sin(t * vary[f.index * VARY + 1] + f.phase) * EcoFishLook.WIGGLE
			var cw := cos(w)
			var sw := sin(w)
			var fw := Vector3(dir.x * cw + dir.z * sw, dir.y, -dir.x * sw + dir.z * cw)
			var side := Vector3(fw.z, 0, -fw.x)
			side = side.normalized() if side.length() > 1e-4 else Vector3(1, 0, 0)
			var up := fw.cross(side)
			var sz := f.size * vary[f.index * VARY]  # своя у особи, молодь мельче
			if sz != 1.0:
				fw *= sz
				side *= sz
				up *= sz
			out[i] = side.x
			out[i + 1] = up.x
			out[i + 2] = fw.x
			out[i + 4] = side.y
			out[i + 5] = up.y
			out[i + 6] = fw.y
			out[i + 8] = side.z
			out[i + 9] = up.z
			out[i + 10] = fw.z


## Расстановка рыбки n из буфера.
static func transform_at(buf: PackedFloat32Array, n: int) -> Transform3D:
	var i := n * STRIDE
	return Transform3D(Vector3(buf[i], buf[i + 4], buf[i + 8]), Vector3(buf[i + 1], buf[i + 5], buf[i + 9]),
		Vector3(buf[i + 2], buf[i + 6], buf[i + 10]), Vector3(buf[i + 3], buf[i + 7], buf[i + 11]))


## Цвет полос рыбки n из буфера.
static func stripe_at(buf: PackedFloat32Array, n: int) -> Color:
	var i := n * STRIDE + 16
	return Color(buf[i], buf[i + 1], buf[i + 2])


## Фаза хвоста рыбки n из буфера (EcoFishLook.tail_phase).
static func tail_phase_at(buf: PackedFloat32Array, n: int) -> float:
	return buf[n * STRIDE + 15]


## Оттенок тела рыбки n из буфера (EcoFishLook.shade).
static func shade_at(buf: PackedFloat32Array, n: int) -> float:
	return buf[n * STRIDE + 19]
