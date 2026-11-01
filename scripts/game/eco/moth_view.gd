class_name MothView
extends Node3D
## Ледяная моль у Светового колодца 05 в сцене (#836, часть 2; ART-080): все рачки — один MultiMesh карточек атласа
## `models/ledyanaya-mol-atlas.png` (2×2 ракурса, не кадры), лицом к камере, обычное альфа-смешение, без теней и
## без своего свечения: панцирь светит только отражённым светом — в луче прожектора бликует (#D9EDF2), без света
## тонет в темноте (правило `test_eco_lit`). Буфер (место и INSTANCE_CUSTOM.x — клетка атласа) переписывается каждый
## кадр, пока корабль у колодца
## (`EcoMoth.near`); дальше узел скрыт и ничего не пишет. «Экономно» — первые COUNT_LITE рачков. Слой отмели.
## Моль на стекле (#836, часть 4) — тот же MultiMesh: после рачков в воде идут сидящие на наружном стекле (до GLASS),
## место — из осей корабля в мир (`Swarm.glass_world`); корабль их не освещает изнутри — на светлой воде они тёмные
## точки, в луче — блики. Сидящий садится и слетает размером карточки (`Swarm.glass_k`), клетка атласа у места на
## стекле своя и не прыгает, когда слетел сосед; корабль ушёл от колодца — рисуются только слетающие со стекла
## (рамка — вокруг корабля).

const ATLAS := "res://models/ledyanaya-mol-atlas.png"
## Карточка, м: рачок 5 мм с лапками; на экране телефона он был бы меньше пикселя, поэтому карточка крупнее
## (как хлопья взвеси ART-058) — моль читается россыпью бликов в луче; тело рачка — около половины карточки.
const SIZE := 0.18
## Дальше этого карточки гаснут (м от камеры).
const FADE_FAR := 32.0
## Цвет панциря — блик моли из палитры ART-080.
const TINT := Color("d9edf2")
## Чисел на экземпляр: transform 3 × 4 и свои данные (4).
const STRIDE := 16
const CUSTOM := 12

const CODE := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 tint : source_color;
uniform float fade_far = 32.0;
varying float fade;
varying vec2 cell;
void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	float s = length(MODEL_MATRIX[0].xyz);
	float c = INSTANCE_CUSTOM.x;
	cell = vec2(mod(c, 2.0), floor(c / 2.0));
	float far = length((VIEW_MATRIX * vec4(o, 1.0)).xyz);
	fade = clamp(1.0 - far / fade_far, 0.0, 1.0);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s,
		vec4(o, 1.0));
}
void fragment() {
	// клетка 128² из 256², UV зажаты внутри клетки (поля 32 px) — без подтекания соседа на мипах
	vec2 uv = (cell + clamp(UV, vec2(0.02), vec2(0.98))) * 0.5;
	vec4 t = texture(atlas, uv);
	ALBEDO = tint * t.rgb;
	ROUGHNESS = 0.35;
	SPECULAR = 0.7;
	ALPHA = t.a * fade * 0.9;
}
"""

## Рамка роя у колодца: круг ACTIVE с запасом на корпус; вдали — SHIP_BOX вокруг корабля (слетают со стекла).
const WELL_BOX := AABB(Vector3(EcoMoth.WELL.x - EcoMoth.ACTIVE - 20.0, -80.0, EcoMoth.WELL.y - EcoMoth.ACTIVE - 20.0),
		Vector3((EcoMoth.ACTIVE + 20.0) * 2.0, 80.0, (EcoMoth.ACTIVE + 20.0) * 2.0))
const SHIP_BOX := 30.0

var moth: EcoMoth
var cards: MultiMeshInstance3D
var material: ShaderMaterial
## Последний буфер (для тестов) и сколько раз его писали.
var buffer := PackedFloat32Array()
var writes := 0


func _init(system: EcoMoth) -> void:
	moth = system
	name = "Ледяная моль"
	cards = MultiMeshInstance3D.new()
	cards.name = "Рачки моли"
	cards.layers = OceanView.LAYER_WORLD
	cards.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = build_mesh()
	material = mm.mesh.material as ShaderMaterial
	mm.instance_count = moth.swarm.pos.size() + EcoMoth.GLASS
	cards.multimesh = mm
	# рой ходит у колодца, стекло — с кораблём ближе ACTIVE: рамка — круг ACTIVE с запасом на корпус
	cards.custom_aabb = WELL_BOX
	add_child(cards)
	buffer.resize(mm.instance_count * STRIDE)
	for i in mm.instance_count:
		var b := i * STRIDE
		buffer[b] = 1.0
		buffer[b + 5] = 1.0
		buffer[b + 10] = 1.0
		buffer[b + CUSTOM] = float(i % 4)
	visible = false


static func build_mesh() -> QuadMesh:
	var m := QuadMesh.new()
	m.size = Vector2.ONE * SIZE
	m.material = EcoShaders.material(CODE, {"atlas": load(ATLAS), "tint": TINT, "fade_far": FADE_FAR})
	return m


## Рой у колодца — места в буфер; корабль далеко — узел скрыт.
func sync(ship: EcoLink.ShipState) -> void:
	var sw := moth.swarm
	var at_well := EcoMoth.near(ship)
	if not at_well and sw.on_glass == 0:
		visible = false
		return
	visible = true
	var mm := cards.multimesh
	if mm.instance_count != sw.pos.size() + EcoMoth.GLASS:
		return
	var n := 0
	if at_well:
		cards.custom_aabb = WELL_BOX
		for i in sw.active:
			_put(i, sw.pos[i], 1.0, i % 4)
		n = sw.active
	else:
		cards.custom_aabb = AABB(ship.pos - Vector3.ONE * SHIP_BOX, Vector3.ONE * SHIP_BOX * 2.0)
	for k in sw.glass_max:
		if sw.glass_life[k] > 0.0:
			_put(n, sw.glass_world(ship, k), sw.glass_k(k), (EcoMoth.COUNT + k) % 4)
			n += 1
	mm.buffer = buffer
	mm.visible_instance_count = n
	writes += 1


## Карточка i: место, доля размера s и клетка атласа cell.
func _put(i: int, p: Vector3, s: float, cell: int) -> void:
	var b := i * STRIDE
	buffer[b] = s
	buffer[b + 5] = s
	buffer[b + 10] = s
	buffer[b + CUSTOM] = float(cell)
	buffer[b + 3] = p.x
	buffer[b + 7] = p.y
	buffer[b + 11] = p.z


## Место, размер и клетка атласа карточки n из буфера.
func scale_at(n: int) -> float:
	return buffer[n * STRIDE]


func cell_at(n: int) -> int:
	return int(buffer[n * STRIDE + CUSTOM])


## Место рачка n из буфера.
func origin_at(n: int) -> Vector3:
	var b := n * STRIDE
	return Vector3(buffer[b + 3], buffer[b + 7], buffer[b + 11])
