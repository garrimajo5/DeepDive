extends TestCase
## Освещаемые существа (docs/grafika-plan-eco.md, этап Б1): тела ловят свет сквозь лёд, прожектор и тени, без света
## остаётся только то, что светится само (огоньки, глаза, кончики игл, споры, купола вуалей). Новые шейдеры
## не нужны: стержни игл берут шейдер норы кольчужника, кончики — шейдер прежних игл.

## Узлы мира без освещения (родитель/узел) — только свечение и прозрачная дымка. Новый узел без света — сюда
## и в план, если он светится сам; тело существа без света — ошибка.
const GLOW := [
	"Купола", "Кромка", "Щупальца", "Огоньки", "Мох", "Луковицы", "Споры", "Чернила", "Глаза", "Гребневики",
	"Ореолы", "Рачки", "Пестрянки", "Добыча", "Пузыри", "Марево", "Мох на костях", "Трещина во льду",
	"Столб света", "Мох колодца", "Клетки планктона",
]


static func _unshaded(m: Material) -> bool:
	if m is BaseMaterial3D:
		return (m as BaseMaterial3D).shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
	if m is ShaderMaterial and (m as ShaderMaterial).shader:
		for line in (m as ShaderMaterial).shader.code.split("\n"):
			if line.strip_edges().begins_with("render_mode"):
				return line.contains("unshaded")
	return false


## Цвет вершины хранится 8 битами на канал.
static func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


## Обе поверхности иглы: 0 — стержень со светом, 1 — кончик без света, грани лицом наружу.
func _check_spine(m: ArrayMesh, tip: Color, who: String) -> void:
	eq(m.get_surface_count(), 2, who + ": стержень и кончик — две поверхности")
	ok(not _unshaded(m.surface_get_material(0)), who + ": стержень освещается")
	ok(_unshaded(m.surface_get_material(1)), who + ": кончик светится сам")
	for s in 2:
		var arr := m.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		ok(v.size() > 0 and n.size() == v.size(), who + ": есть нормали")
		var bad := 0
		for i in range(0, v.size(), 3):
			if (v[i + 1] - v[i]).cross(v[i + 2] - v[i]).dot(n[i]) > 0.0:
				bad += 1
		eq(bad, 0, who + ": грани поверхности %d наружу" % s)
	var tips: PackedColorArray = m.surface_get_arrays(1)[Mesh.ARRAY_COLOR]
	for c in tips:
		ok(_same(c, tip), who + ": кончик — голубой")
	eq(ShaderKey.of(m.surface_get_material(0)), ShaderKey.of(KrabView.build_den().surface_get_material(0)),
		who + ": стержень — шейдер норы, нового нет")


func test_krab_spine_lit() -> void:
	_check_spine(KrabView.build_spine(), KrabView.SPINE_TIP, "кольчужник")


func test_urchin_spines_lit() -> void:
	var m := KelpView.build_spines()
	_check_spine(m, KelpView.SPINE_TIP, "шипоёж")
	eq(ShaderKey.of(m.surface_get_material(1)), ShaderKey.of(KrabView.build_spine().surface_get_material(1)),
		"кончики ежа и кольчужника — один шейдер")
	# стержень темнеет к основанию: у каждой грани одна вершина-кончик
	var col: PackedColorArray = m.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var top := 0
	for c in col:
		if _same(c, KelpView.SPINE_TIP):
			top += 1
	eq(top, KelpView.SPINES * 4, "по одной светлой вершине у грани")
	eq(col.size(), KelpView.SPINES * 4 * 3, "18 игл по четыре грани")


func _walk(n: Node, out: Array) -> void:
	if n is GeometryInstance3D:
		var g := n as GeometryInstance3D
		var who := "%s/%s" % [n.get_parent().name, n.name]
		var mesh: Mesh = null
		if n is MeshInstance3D:
			mesh = (n as MeshInstance3D).mesh
		elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh:
			mesh = (n as MultiMeshInstance3D).multimesh.mesh
		if g.material_override:
			if _unshaded(g.material_override) and not String(n.name) in GLOW:
				out.append(who)
		elif mesh:
			for s in mesh.get_surface_count():
				var m: Material = mesh.surface_get_material(s)
				if n is MeshInstance3D and (n as MeshInstance3D).get_surface_override_material(s):
					m = (n as MeshInstance3D).get_surface_override_material(s)
				# у игл без света — только кончик (последняя поверхность)
				var tip_ok := String(n.name) == "Иглы" and s == mesh.get_surface_count() - 1 and s > 0
				if _unshaded(m) and not tip_ok and not String(n.name) in GLOW:
					out.append("%s#%d" % [who, s])
	for c in n.get_children():
		_walk(c, out)


func test_scene_bodies_lit() -> void:
	var view := EcoView.new()
	tree.root.add_child(view)
	view.ground = Seabed.height
	await frames(1)
	var dark: Array = []
	_walk(view, dark)
	eq(dark, [], "тела существ освещаются, без света — только свечение")
	ok(view.find_child("Иглы", true, false) != null, "иглы в сцене есть")
	view.queue_free()
	await frames(1)
