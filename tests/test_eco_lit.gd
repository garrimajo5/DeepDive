extends TestCase
## Освещаемые существа (docs/grafika-plan-eco.md, этап Б1): тела ловят свет сквозь лёд, прожектор и тени, без света
## остаётся только то, что светится само (огоньки, глаза, кончики игл, споры, купола вуалей). Новые шейдеры
## не нужны: стержни игл берут шейдер норы кольчужника, кончики — шейдер прежних игл.

## Узлы мира без освещения (родитель/узел) — только свечение и прозрачная дымка. Новый узел без света — сюда
## и в план, если он светится сам; тело существа без света — ошибка.
const GLOW := [
	"Купола", "Кромка", "Щупальца", "Огоньки", "Мох", "Луковицы", "Споры", "Чернила", "Глаза", "Гребневики",
	"Ореолы", "Рачки", "Пестрянки", "Добыча", "Пузыри", "Марево", "Мох на костях", "Трещина во льду",
	"Столб света", "Мох колодца", "Клетки планктона", "Муть", "Пузырьки",
	# фон вдали (Б1: дальние стаи остаются дешёвыми) — тёмные силуэты, их гасит туман
	"Силуэты вдали",
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


## Ёж одним мешем (#849): одна поверхность со светом на общем шейдере растений; грани наружу; свечение — альфой
## вершины (кончик — сам), тело — едва (общий glow); стержень темнеет к основанию.
func test_urchin_one_surface_lit() -> void:
	var m := KelpView.build_urchin()
	eq(m.get_surface_count(), 1, "шипоёж — одна поверхность")
	var mat := m.surface_get_material(0)
	ok(not _unshaded(mat), "шипоёж освещается")
	eq(ShaderKey.of(mat), ShaderKey.of(KelpView.build_stalk().surface_get_material(0)),
		"шипоёж — шейдер растений, нового нет")
	eq(int((mat as ShaderMaterial).get_shader_parameter("mode")), int(EcoShaders.Plant.TENTACLE))
	var arr := m.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var col: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	eq(n.size(), v.size(), "есть нормали")
	eq(col.size(), v.size(), "есть цвета")
	var bad := 0
	for i in range(0, v.size(), 3):
		if (v[i + 1] - v[i]).cross(v[i + 2] - v[i]).dot(n[i]) > 0.0:
			bad += 1
	eq(bad, 0, "грани наружу (по нормали)")
	# тело: нормаль от центра ежа
	var inward := 0
	for i in range(0, v.size(), 3):
		if col[i].a > 0.01 and col[i].a < 0.99 and n[i].dot(v[i]) < 0.0:
			inward += 1
	eq(inward, 0, "нормали тела наружу")
	var tips := 0
	var shaft_top := 0
	var body := 0
	for c in col:
		ok(c.a < 0.01 or c.a > 0.99, "альфа вершины — только 0 или 1 (одинаково во всех рендерерах)")
		if c.a > 0.99:
			ok(_same(c, KelpView.SPINE_TIP), "светится сам только голубой кончик")
			tips += 1
		elif _same(c, KelpView.SPINE_TIP):
			shaft_top += 1
		elif _same(c, KelpView.BODY):
			body += 1
	eq(tips, KelpView.SPINES * 8 * 3, "кончики: 18 ромбиков по 8 граней")
	eq(shaft_top, KelpView.SPINES * 4, "стержни: по одной светлой вершине у грани")
	ok(body > 0, "тело есть")
	# прежнее слабое свечение тела — общим glow
	var g: Vector3 = (mat as ShaderMaterial).get_shader_parameter("glow")
	var lin := KelpView.BODY_GLOW.srgb_to_linear()
	ok(g.is_equal_approx(Vector3(lin.r, lin.g, lin.b)), "свечение тела BODY_GLOW")


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
