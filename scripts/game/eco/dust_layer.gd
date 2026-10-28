class_name EcoDustLayer
extends MultiMeshInstance3D
## Общий слой мути живого мира (issue #849): облачка ила всех видов (скребуны, светляки, ежи, хватни, вуали…) — один
## MultiMesh «Муть» и один вызов отрисовки вместо ≈20 слоёв по виду (меш, шейдер EcoShaders.MIST INK и рисунок у них
## одинаковые). Каждый вид по-прежнему считает свои облачка в свой EcoDustBuffer (свой пул, свой цвет ила), слой
## складывает буферы подряд — кусок на пул вида — и грузит, только когда какой-то изменился. Облачков нет нигде —
## слой спрятан. Вне EcoView (тесты вида) у вида свой слой, как раньше.

var parts: Array[EcoDustBuffer] = []
## Мест в пуле у каждого куска (по порядку parts).
var pools := PackedInt32Array()
## Последний собранный буфер (в headless сервер отрисовки буфер не хранит — по нему проверяют тесты).
var data := PackedFloat32Array()
## Сколько облачков видно во всём слое после sync.
var shown := 0
## Сколько раз буфер грузился (тесты: без изменений — не грузим).
var uploads := 0
var _zeros: Array[PackedFloat32Array] = []


func _init() -> void:
	name = "Муть"
	layers = OceanView.LAYER_WORLD
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = EcoShaders.mist(EcoShaders.Mist.INK)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	multimesh = mm
	custom_aabb = AABB(Vector3(-400, -200, -400), Vector3(800, 400, 800))
	visible = false


## Забрать муть у видов — детей root: у кого есть свой слой `dust_view` и буфер `_dust` (EcoDustBuffer), слой
## убирается, буфер пишется сюда. Звать после каждой пересборки видов (старые куски отпускаются).
func gather(root: Node) -> void:
	var old_parts := parts.duplicate()
	var old_pools := pools.duplicate()
	parts.clear()
	pools.clear()
	_zeros.clear()
	var total := 0
	for c in root.get_children():
		if c == self:
			continue
		var buf = c.get("_dust")
		if not buf is EcoDustBuffer:
			continue
		var mi = c.get("dust_view")
		var pool := 0
		if mi is MultiMeshInstance3D:
			pool = (mi as MultiMeshInstance3D).multimesh.instance_count
			c.remove_child(mi)
			mi.free()
			c.set("dust_view", null)
		elif (buf as EcoDustBuffer).joined and old_parts.has(buf):   # вид не пересобран — кусок уже здесь
			pool = old_pools[old_parts.find(buf)]
		else:
			continue
		(buf as EcoDustBuffer).joined = true
		(buf as EcoDustBuffer).dirty = true
		parts.append(buf)
		pools.append(pool)
		var z := PackedFloat32Array()
		z.resize(pool * GrazerView.DUST_STRIDE)
		z.fill(0.0)
		_zeros.append(z)
		total += pool
	multimesh.instance_count = total
	data.resize(total * GrazerView.DUST_STRIDE)
	data.fill(0.0)
	shown = 0
	visible = false


## Собрать и загрузить буфер, если какой-то кусок изменился с прошлого раза; спрятать слой, пока облачков нет.
func sync() -> void:
	var any := false
	var n := 0
	for b in parts:
		n += b.shown
		any = any or b.dirty
	shown = n
	if any:
		var out := PackedFloat32Array()
		for i in parts.size():
			var b := parts[i]
			b.dirty = false
			out.append_array(b.data if b.data.size() == _zeros[i].size() else _zeros[i])
		data = out
		multimesh.buffer = data
		uploads += 1
	visible = n > 0
