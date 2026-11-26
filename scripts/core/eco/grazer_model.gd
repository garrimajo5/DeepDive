class_name EcoGrazerModel
extends RefCounted
## Модель скребуна MOD-024 (`models/skrebun.glb`, заказ #2120, приёмка #2123) в сцене вместо процедурной формы
## EcoGrazerLook (#2107): 1 119 треугольников из 1 500 по заказу, один меш, одна карта цвета 512². Поза в шейдере
## GrazerView та же, что у процедурной формы (лапы шагают двумя тройками, скребок ходит у пасущегося): разметка
## вершин считается здесь при загрузке — NORMAL.x = тройка лапы (EcoGrazerLook.tripod, у тела 0), NORMAL.y = скребок
## (1; осевые значения не меняются нормализацией массива), UV2 = бедро лапы (x, z). Оси модели совпадают с формой:
## y вверх от стоп, нос в +Z, начало под центром панциря в плоскости подошв — basis/origin EcoGrazerLook подходят
## без пересчёта. Скелета нет: шейдер крутит лапу вокруг бедра по разметке, как EcoGrazerLook.posed.
## Лапа — вершина ниже LEG_TOP и ближе LEG_D к оси «бедро → стопа» (HIPS/FEET: бёдра — из notes MOD-024, стопы — по
## сетке); скребок — зона SCRAPE_* из notes; остальное — тело (панцирь, мягкий низ). Правило даёт ровные доли на
## все шесть лап (70–79 вершин), низ тела в лапы не попадает.

const GLB := "res://models/skrebun.glb"
## Верх лап по высоте (выше — только панцирь) и предел близости вершины к оси бедро → стопа (м).
const LEG_TOP := 0.34
const LEG_D := 0.13
## Бёдра лап из notes MOD-024 (порядок, как у EcoGrazerLook.hips: 0–2 борт −x спереди назад, 3–5 борт +x)
## и стопы тех же лап по сетке — оси для разметки.
const HIPS: Array[Vector3] = [
	Vector3(-0.1508, 0.2053, 0.3503), Vector3(-0.3164, 0.2168, -0.0601), Vector3(-0.1040, 0.2121, -0.3943),
	Vector3(0.1512, 0.2050, 0.3503), Vector3(0.3241, 0.2212, -0.0738), Vector3(0.1079, 0.2119, -0.3948)]
const FEET: Array[Vector3] = [
	Vector3(-0.47, 0.0, 0.65), Vector3(-0.65, 0.0, 0.05), Vector3(-0.41, 0.0, -0.61),
	Vector3(0.47, 0.0, 0.65), Vector3(0.65, 0.0, 0.05), Vector3(0.41, 0.0, -0.61)]
## Зона скребка под головным краем (notes MOD-024): |x| меньше, y и z в пределах (м).
const SCRAPE_X := 0.16
const SCRAPE_Y := Vector2(0.13, 0.32)
const SCRAPE_Z := Vector2(0.40, 0.72)

## Вершины модели, части (лапа 0–5, EcoGrazerLook.SCRAPER, EcoGrazerLook.BODY), бёдра, треугольники и развёртка.
static var rest := PackedVector3Array()
static var part := PackedInt32Array()
static var hips := PackedVector3Array()
static var tris := PackedInt32Array()
static var uvs := PackedVector2Array()
## Карта цвета модели (в шейдер GrazerView, параметр skin).
static var skin: Texture2D = null
## Треугольников в модели.
static var tris_n := 0


static func _static_init() -> void:
	var scene: PackedScene = load(GLB)
	var body := scene.instantiate()
	var mi := body.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var arr := mi.mesh.surface_get_arrays(0)
	rest = arr[Mesh.ARRAY_VERTEX]
	uvs = arr[Mesh.ARRAY_TEX_UV]
	tris = arr[Mesh.ARRAY_INDEX]
	tris_n = tris.size() / 3
	skin = (mi.mesh.surface_get_material(0) as StandardMaterial3D).albedo_texture
	hips = PackedVector3Array(HIPS)
	part.resize(rest.size())
	for i in rest.size():
		part[i] = _classify(rest[i])
	body.free()


## Часть вершины p: скребок (зона из notes), лапа k (ниже LEG_TOP и ближе LEG_D к её оси) или тело.
static func _classify(p: Vector3) -> int:
	if absf(p.x) < SCRAPE_X and p.y > SCRAPE_Y.x and p.y < SCRAPE_Y.y and p.z > SCRAPE_Z.x and p.z < SCRAPE_Z.y:
		return EcoGrazerLook.SCRAPER
	if p.y < LEG_TOP:
		var best := -1
		var best_d := LEG_D
		for k in 6:
			var d := _axis_dist(p, HIPS[k], FEET[k])
			if d < best_d:
				best_d = d
				best = k
		if best >= 0:
			return best
	return EcoGrazerLook.BODY


## Расстояние от p до отрезка a — b (ось лапы бедро → стопа).
static func _axis_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Меш модели с разметкой для шейдера GrazerView (NORMAL — тройка/скребок/«краска из текстуры», UV2 — бедро;
## COLOR белый: оттенок особи — цвет экземпляра MultiMesh). mat — общий материал вида.
static func mesh(mat: ShaderMaterial) -> ArrayMesh:
	var n := rest.size()
	var norms := PackedVector3Array()
	var uv2 := PackedVector2Array()
	var paint := PackedColorArray()
	norms.resize(n)
	uv2.resize(n)
	paint.resize(n)
	for i in n:
		var pt := part[i]
		var h := Vector3.ZERO
		var tri := 0.0
		if pt >= 0 and pt < 6:
			tri = float(EcoGrazerLook.tripod(pt))
			h = hips[pt]
		norms[i] = Vector3(tri, 1.0 if pt == EcoGrazerLook.SCRAPER else 0.0, 0.0)
		uv2[i] = Vector2(h.x, h.z)
		paint[i] = Color.WHITE
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = rest
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = paint
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = tris
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	out.surface_set_material(0, mat)
	# лапы шагают в шейдере: запас к рамке модели, чтобы скребун не пропадал у края экрана
	out.custom_aabb = AABB(Vector3(-1.0, -0.1, -1.0), Vector3(2.0, 0.9, 2.0))
	return out


## Вершина i модели в позе pose (фаза шага, ход скребка) — то же движение делает шейдер GrazerView.
static func posed(i: int, pose: Vector2) -> Vector3:
	var r := rest[i]
	var pt := part[i]
	if pt >= 0 and pt < 6:
		var s := pose.x * EcoGrazerLook.tripod(pt)
		var ang := EcoGrazerLook.SWING * s
		var h := hips[pt]
		var dx := r.x - h.x
		var dz := r.z - h.z
		var c := cos(ang)
		var sn := sin(ang)
		return Vector3(h.x + dx * c + dz * sn, r.y + EcoGrazerLook.STEP_LIFT * maxf(0.0, s), h.z - dx * sn + dz * c)
	if pt == EcoGrazerLook.SCRAPER:
		return Vector3(r.x, r.y - pose.y, r.z)
	return r
