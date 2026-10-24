class_name HullMesh
## Меши корпуса «Ковчега-7» снаружи по HullPlan (ART-001): единичные формы (как Shapes.cs в pogrujenie) и сборка
## деталей одной краски в один меш — один вызов отрисовки на краску. Подвижные детали (роторы, рули глубины)
## собираются отдельно, вокруг своего центра, — их крутит сцена по HullMesh.Motion (pogrujenie Core/HullMotion.cs).
## Крышку нижнего шлюза рисует RoomsView (она же видна снаружи), здесь её нет.
## Лицевая сторона треугольника — по часовой стрелке, если смотреть на неё: (b − a) × (c − a) смотрит внутрь.

const SEG := 24
const RINGS := 10
const WINDOW_GLOW := 0.85
const LENS_GLOW := 1.0
const LOCK_GLOW := 0.45


## Обшивка ART-024 (`docs/concept-art/obshivka.md`): плитка 2 × 2 м трипланарно в осях корабля, швы по маске
## темнее и с блеском, обрастание на нижней половине по локальной высоте. Числа — те же, что в шейдере
## `shaders/hull_plating.gdshader` (их туда передаёт HullView).
const PLATE_TILE := 2.0
const PLATE_TEX := "res://textures/hull/%s.png"   ## tsvet, maska, obrastanie
const SEAM_DARK := 0.7          ## множитель цвета на шве (маска 255): швы читаются с 30 м
const STAIN_DARK := 0.95        ## пятна и подтёки (маска 128)
const GROWTH_MAX := 0.65
const GROWTH_FROM := 0.15       ## h, где обрастание начинает спадать
const GROWTH_TO := 0.5          ## h, где его уже нет
## Низ и высота корпуса для локальной высоты h: от киля основного объёма до верха носовой оболочки.
const KEEL_Y := HullPlan.CENTER_Y - HullPlan.NOSE_H * 0.5
const HULL_H := HullPlan.NOSE_H
## Следы повреждений ART-049 (`docs/concept-art/povrezhdeniya.md`): карта цвета с альфой и карта порога потери
## корпуса (линейная, без mipmap) в той же плитке и тех же координатах, что ART-024; на швах след слабее.
const DAMAGE_TEX := "res://textures/hull/%s.png"   ## povrezhdeniya, povrezhdeniya-uroven
const DAMAGE_SEAM := 0.55
## Против ровной сетки одинаковых следов (issue #406): два слоя карты следов — как есть и повёрнутый на 90°,
## крупнее и со сдвигом; какой слой виден, решает плавный шум по плоскости с ячейкой DAMAGE_CELL плиток
## (слои взаимно дополняют друг друга, поэтому доля следов почти не меняется). Числа — те же, что в шейдере.
const DAMAGE_ALT_SCALE := 0.83
const DAMAGE_ALT_SHIFT := Vector2(0.37, 0.61)
const DAMAGE_CELL := 1.37       ## ячейка шума выбора слоя в плитках (не кратна плитке)
const DAMAGE_GATE := Vector2(0.46, 0.54)
## Рельеф ART-053 (obshivka-normali.md): textures/hull/normali, sheroh, povrezhdeniya-normali; сила ≈ 1,0 и 0,7–1,0.
const NORMAL_DEPTH := 1.0
const DAMAGE_DEPTH := 0.85


## Ободок и затенение щелей ART-076 (`docs/concept-art/obodok-korpusa.md`): LUT 256×8 (линейные данные, X — e = 1 − N·V,
## строки — глубина RIM_ROWS_M и ил) даёт мягкую синюю кромку в EMISSION; AO процедурный — шов по маске ART-024 и поля
## примыканий в метрах корабля (max, не сумма). Числа — те же, что в `hull_plating.gdshader` (передаёт HullView).
const RIM_TEX := "res://textures/hull/obodok-gradient.png"
const RIM_ROWS := 8
const RIM_ROWS_M: Array[float] = [0.0, 8.0, 14.0, 20.0, 32.5, 45.0, 90.0]   ## строка 7 — ил (A = 0), не берём
const RIM_LITE := 0.65          ## «Экономно»: кромка слабее, примыкания не считаются
const RIM_CONTACT := 0.55       ## у примыканий кромка гаснет на эту долю
const RIM_ZAP := 0.55           ## пока идёт разряд ART-068, кромка уступает дугам
const AO_SEAM := 0.18
const AO_CONTACT := 0.34
const AO_MIN := 0.55
const AO_ALBEDO := 0.55
const AO_LIGHT := 0.15
const AO_PROTECT := 0.8         ## на следах ART-049 щели не темнеют дважды
## Примыкания (оси корабля, x — по модулю): крепления двигателя (box SDF), ниша ротора, корни рулей и стабилизаторов.
const AO_MOUNT := Vector3(3.45, 1.0, 26.3)
const AO_MOUNT_HALF := Vector3(0.75, 0.225, 0.7)
const AO_MOUNT_FEATHER := 0.18
const AO_RECESS := Vector3(5.4, 1.0, 26.5)
const AO_RECESS_R := Vector2(1.0, 1.29)
const AO_RECESS_Z := 0.72
const AO_RUDDER := Vector3(3.95, 2.6, 24.6)
const AO_RUDDER_R := Vector3(0.28, 0.30, 1.0)
const AO_STAB_UP := Vector3(0.0, 3.42, 25.0)
const AO_STAB_UP_R := Vector3(0.28, 0.25, 1.3)
const AO_STAB_DOWN := Vector3(0.0, -0.2, 25.0)
const AO_STAB_DOWN_R := Vector3(0.25, 0.24, 1.1)


## Строка LUT ободка по глубине (0…6, дробная — шейдер смешивает соседние строки): 0→1 на 0…8 м, 1→3 на 8…20,
## 3→5 на 20…45, 5→6 на 45…90.
static func rim_row(depth: float) -> float:
	var d := maxf(depth, 0.0)
	if d < 8.0:
		return d / 8.0
	if d < 20.0:
		return 1.0 + 2.0 * (d - 8.0) / 12.0
	if d < 45.0:
		return 3.0 + 2.0 * (d - 20.0) / 25.0
	return minf(5.0 + (d - 45.0) / 45.0, 6.0)


## V строки LUT (центр текселя).
static func rim_v(row: float) -> float:
	return (row + 0.5) / RIM_ROWS


## «Корпус разрушен» ART-036: кромка гаснет к Wreck.DARK_AT, нет до RESTART_AT, возвращается к Wreck.END.
static func rim_alive(wreck_t: float) -> float:
	if wreck_t < 0.0:
		return 1.0
	if wreck_t < Wreck.RESTART_AT:
		return 1.0 - smoothstep(0.0, Wreck.DARK_AT, wreck_t)
	return smoothstep(Wreck.RESTART_AT, Wreck.END, wreck_t)


## Общий множитель кромки с CPU (uniform `rim_k`): жив ли корпус, ил гасит, «Экономно» — RIM_LITE.
static func rim_k(alive: float, silt_k: float, lite: bool) -> float:
	return clampf(alive, 0.0, 1.0) * (1.0 - clampf(silt_k, 0.0, 1.0)) * (RIM_LITE if lite else 1.0)


## Кромка уступает дугам разряда: 1 − RIM_ZAP · sin²(π t / dur), вне разряда — 1 (как в шейдере).
static func rim_zap(zap_t: float, zap_dur: float) -> float:
	if zap_t < 0.0 or zap_t >= zap_dur:
		return 1.0
	var s := sin(PI * zap_t / zap_dur)
	return 1.0 - RIM_ZAP * s * s


static func _patch(p: Vector3, c: Vector3, r: Vector3) -> float:
	var q := (p - c) / r
	return exp(-q.length_squared())


## Примыкание 0…1 в точке p (оси корабля) — как `contact()` в шейдере.
static func contact(p: Vector3) -> float:
	var a := Vector3(absf(p.x), p.y, p.z)
	var q := (a - AO_MOUNT).abs() - AO_MOUNT_HALF
	var box := Vector3(maxf(q.x, 0.0), maxf(q.y, 0.0), maxf(q.z, 0.0)).length() + minf(maxf(q.x, maxf(q.y, q.z)), 0.0)
	var c := exp(-maxf(box, 0.0) / AO_MOUNT_FEATHER)
	var rho := Vector2(a.x - AO_RECESS.x, a.y - AO_RECESS.y).length()
	var dz := (a.z - AO_RECESS.z) / AO_RECESS_Z
	c = maxf(c, (1.0 - smoothstep(AO_RECESS_R.x, AO_RECESS_R.y, rho)) * exp(-dz * dz))
	c = maxf(c, _patch(a, AO_RUDDER, AO_RUDDER_R))
	c = maxf(c, _patch(p, AO_STAB_UP, AO_STAB_UP_R))
	c = maxf(c, _patch(p, AO_STAB_DOWN, AO_STAB_DOWN_R))
	return c


## Затенение 0,55…1: шов (smoothstep маски), примыкание, cover — альфа следов ART-049 (там щели не темнеют).
static func occlusion(seam: float, contact_k: float, cover: float) -> float:
	var protect := 1.0 - AO_PROTECT * clampf(cover, 0.0, 1.0)
	return clampf(1.0 - (AO_SEAM * seam + AO_CONTACT * contact_k) * protect, AO_MIN, 1.0)


## Краска под обшивкой: металл корпуса. Швы-кольца, окна, линза, шлюз — своим цветом.
static func plated(paint: int) -> bool:
	return paint == HullPlan.Paint.METAL


## Локальная высота точки корпуса (оси корабля): 0 у киля, 1 у верха.
static func local_height(y: float) -> float:
	return clampf((y - KEEL_Y) / HULL_H, 0.0, 1.0)


## Потеря корпуса для следов ART-049: 0 при 100 %, 1 при 0 %.
static func wear(hull: float) -> float:
	return clampf(1.0 - hull / 100.0, 0.0, 1.0)


## След с порогом `threshold` (0…1, карта уровня) виден при потере `loss` — как в шейдере: d > 0 и d ≥ t.
static func damage_shown(loss: float, threshold: float) -> bool:
	return loss > 0.0 and loss >= threshold


## Координаты второго слоя следов: повёрнуты на 90°, крупнее и сдвинуты (как `damage_alt_uv` в шейдере).
static func damage_alt_uv(uv: Vector2) -> Vector2:
	return Vector2(-uv.y, uv.x) * DAMAGE_ALT_SCALE + DAMAGE_ALT_SHIFT


## Хеш узла решётки 0…1 (как `cell_hash` в шейдере).
static func cell_hash(c: Vector2) -> float:
	var v := sin(c.dot(Vector2(127.1, 311.7))) * 43758.5453
	return v - floorf(v)


## Плавный шум по плоскости 0…1 с ячейкой DAMAGE_CELL плиток (как `gate_noise` в шейдере).
static func gate_noise(uv: Vector2) -> float:
	var q := uv / DAMAGE_CELL
	var i := q.floor()
	var f := q - i
	f = f * f * (Vector2(3, 3) - 2.0 * f)
	var a := cell_hash(i)
	var b := cell_hash(i + Vector2(1, 0))
	var c := cell_hash(i + Vector2(0, 1))
	var d := cell_hash(i + Vector2(1, 1))
	return lerpf(lerpf(a, b, f.x), lerpf(c, d, f.x), f.y)


## Вес первого слоя следов в точке плоскости (второй — 1 − вес).
static func damage_gate(uv: Vector2) -> float:
	return smoothstep(DAMAGE_GATE.x, DAMAGE_GATE.y, gate_noise(uv))


## Непрозрачность видимых следов в точке плоскости `uv` (в плитках) при потере `loss` — как `damage2` в шейдере.
## `col` — карта цвета с альфой, `lvl` — карта порога (обе 1024², как в textures/hull).
static func damage_alpha(col: Image, lvl: Image, uv: Vector2, loss: float) -> float:
	var k := damage_gate(uv)
	return _damage_one(col, lvl, uv, loss) * k + _damage_one(col, lvl, damage_alt_uv(uv), loss) * (1.0 - k)


static func _damage_one(col: Image, lvl: Image, uv: Vector2, loss: float) -> float:
	var x := int(fposmod(uv.x, 1.0) * col.get_width()) % col.get_width()
	var y := int(fposmod(uv.y, 1.0) * col.get_height()) % col.get_height()
	var t := lvl.get_pixel(x * lvl.get_width() / col.get_width(), y * lvl.get_height() / col.get_height()).r
	return col.get_pixel(x, y).a if damage_shown(loss, t) else 0.0


## Нормаль из пикселя карты OpenGL (+Y — вверх по картинке) в осях плитки: x вдоль u, y вдоль v (v идёт вниз по
## картинке, поэтому y меняет знак), z — от поверхности. Как `decode_n` в шейдере.
static func decode_normal(c: Color) -> Vector3:
	return Vector3(c.r * 2.0 - 1.0, -(c.g * 2.0 - 1.0), c.b * 2.0 - 1.0)


## Нормаль второго слоя следов (координаты `damage_alt_uv`, поворот на 90°) — обратно в оси плитки.
static func alt_back(t: Vector3) -> Vector3:
	return Vector3(t.y, -t.x, t.z)


## Деталь `d` поверх основы `b` (reoriented normal mapping), обе в осях плитки — как `rnm` в шейдере.
static func rnm(b: Vector3, d: Vector3) -> Vector3:
	var t := b + Vector3(0, 0, 1)
	var u := d * Vector3(-1, -1, 1)
	return (t * t.dot(u) / t.z - u).normalized()


## Нормаль плитки `t` на трипланарной плоскости `axis` (0 — zy, 1 — xz, 2 — xy) при нормали меша `n`, в осях корабля
## (whiteout, как `tri_normal` в шейдере для одной плоскости).
static func plane_normal(axis: int, n: Vector3, t: Vector3) -> Vector3:
	match axis:
		0:
			return Vector3(absf(t.z) * n.x, t.y + n.y, t.x + n.z).normalized()
		1:
			return Vector3(t.x + n.x, absf(t.z) * n.y, t.y + n.z).normalized()
	return Vector3(t.x + n.x, t.y + n.y, absf(t.z) * n.z).normalized()


## Вес обрастания по локальной высоте (заметки художника ART-024): 0.65 · (1 − smoothstep(0.15, 0.50, h)).
static func growth(h: float) -> float:
	return GROWTH_MAX * (1.0 - smoothstep(GROWTH_FROM, GROWTH_TO, h))


## Детали, которые рисует корпус: все, кроме крышки шлюза.
static func drawn(part: HullPlan.Part) -> bool:
	return part.piece != HullPlan.Piece.AIRLOCK


## Подвижная деталь: своя сетка вокруг центра детали.
static func moving(part: HullPlan.Part) -> bool:
	return part.piece == HullPlan.Piece.ROTOR or part.piece == HullPlan.Piece.RUDDER


static func glow(paint: int) -> float:
	match paint:
		HullPlan.Paint.WINDOW:
			return WINDOW_GLOW
		HullPlan.Paint.LENS:
			return LENS_GLOW
		HullPlan.Paint.LOCK:
			return LOCK_GLOW
	return 0.0


## Накопитель треугольников: вершины с нормалями, порядок обхода выправляется по нормали наружу.
class Builder:
	var pos := PackedVector3Array()
	var nor := PackedVector3Array()
	var idx := PackedInt32Array()

	func add(p: Vector3, n: Vector3) -> int:
		pos.append(p)
		nor.append(n.normalized())
		return pos.size() - 1

	func tri(a: int, b: int, c: int) -> void:
		var n := nor[a] + nor[b] + nor[c]
		var g := (pos[b] - pos[a]).cross(pos[c] - pos[a])
		if g.dot(n) > 0.0:   # должно смотреть внутрь
			idx.append_array([a, c, b])
		else:
			idx.append_array([a, b, c])

	func quad(a: int, b: int, c: int, d: int) -> void:
		tri(a, b, c)
		tri(a, c, d)

	## Добавить другой накопитель, переведя его вершины преобразованием xf (нормали — обратной транспонированной).
	func merge(o: Builder, xf: Transform3D) -> void:
		var nb := xf.basis.inverse().transposed()
		var base := pos.size()
		for i in o.pos.size():
			pos.append(xf * o.pos[i])
			nor.append((nb * o.nor[i]).normalized())
		for i in o.idx:
			idx.append(base + i)

	func arrays() -> Array:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = pos
		arr[Mesh.ARRAY_NORMAL] = nor
		arr[Mesh.ARRAY_INDEX] = idx
		return arr

	func triangles() -> int:
		return idx.size() / 3


## Единичная форма HullPlan.Form (размеры — в шапке hull_plan.gd).
static func unit(form: int) -> Builder:
	var b := Builder.new()
	match form:
		HullPlan.Form.CUBE:
			_block(b, Vector3.ZERO, Vector3(0.5, 0, 0), Vector3(0, 0.5, 0), Vector3(0, 0, 0.5))
		HullPlan.Form.SPHERE:
			_sphere(b, 0.0, PI, Vector3.ZERO)
		HullPlan.Form.CYLINDER:
			_side(b, 0.5, -1.0, 0.5, 1.0, true)
			_disc(b, 1.0, 0.5, Vector3.UP)
			_disc(b, -1.0, 0.5, Vector3.DOWN)
		HullPlan.Form.CAPSULE:
			_side(b, 0.5, -0.5, 0.5, 0.5, true)
			_sphere(b, 0.0, PI / 2.0, Vector3(0, 0.5, 0))
			_sphere(b, PI / 2.0, PI, Vector3(0, -0.5, 0))
		HullPlan.Form.DOME:   # шар Ø1, срезанный плоскостью y = −0,25 (широта 120°), срез закрыт кругом
			var cut := PI * 2.0 / 3.0
			_sphere(b, 0.0, cut, Vector3.ZERO)
			_disc(b, -0.25, 0.5 * sin(cut), Vector3.DOWN)
		HullPlan.Form.FRUSTUM:
			_side(b, 0.5, -1.0, 0.25, 1.0, true)
			_disc(b, 1.0, 0.25, Vector3.UP)
			_disc(b, -1.0, 0.5, Vector3.DOWN)
		HullPlan.Form.TUBE:   # стенка от 0,42 до 0,5
			_side(b, 0.5, -1.0, 0.5, 1.0, true)
			_side(b, 0.42, -1.0, 0.42, 1.0, false)
			for y in [1.0, -1.0]:
				_ring(b, y, 0.42, 0.5, Vector3(0, y, 0))
		HullPlan.Form.ROTOR:
			_rotor(b, 5)
		HullPlan.Form.WEDGE:
			_wedge(b)
		HullPlan.Form.PLATE:
			var n := Vector3.BACK
			b.quad(b.add(Vector3(-0.5, -0.5, 0), n), b.add(Vector3(0.5, -0.5, 0), n),
				b.add(Vector3(0.5, 0.5, 0), n), b.add(Vector3(-0.5, 0.5, 0), n))
	return b


## Неподвижные детали одной краски одним накопителем в осях корабля.
static func paint_builder(paint: int) -> Builder:
	var b := Builder.new()
	var cache := {}
	for part in HullPlan.parts():
		if part.paint != paint or not drawn(part) or moving(part):
			continue
		if not cache.has(part.form):
			cache[part.form] = unit(part.form)
		b.merge(cache[part.form], part.xform())
	return b


## Подвижная деталь в осях её центра (узел ставится в part.pos с поворотом детали).
static func part_builder(part: HullPlan.Part) -> Builder:
	var b := Builder.new()
	var xf := part.xform()
	b.merge(unit(part.form), Transform3D(xf.basis, Vector3.ZERO))
	return b


## Краски, у которых есть неподвижные детали.
static func paints() -> Array[int]:
	var out: Array[int] = []
	for part in HullPlan.parts():
		if drawn(part) and not moving(part) and not out.has(part.paint):
			out.append(part.paint)
	out.sort()
	return out


## Шаровой пояс от широты lat0 до lat1 (0 — верх, π — низ), радиус 0,5, со сдвигом c.
static func _sphere(b: Builder, lat0: float, lat1: float, c: Vector3) -> void:
	var rows := []
	for i in RINGS + 1:
		var lat := lerpf(lat0, lat1, float(i) / RINGS)
		var row := PackedInt32Array()
		for j in SEG + 1:
			var lon := TAU * j / SEG
			var n := Vector3(sin(lat) * cos(lon), cos(lat), sin(lat) * sin(lon))
			row.append(b.add(c + n * 0.5, n))
		rows.append(row)
	for r in RINGS:
		for j in SEG:
			b.quad(rows[r][j], rows[r][j + 1], rows[r + 1][j + 1], rows[r + 1][j])


static func _disc(b: Builder, y: float, r: float, n: Vector3, seg: int = SEG) -> void:
	var c := b.add(Vector3(0, y, 0), n)
	var ring := PackedInt32Array()
	for j in seg + 1:
		var lon := TAU * j / seg
		ring.append(b.add(Vector3(cos(lon) * r, y, sin(lon) * r), n))
	for j in seg:
		b.tri(c, ring[j], ring[j + 1])


static func _ring(b: Builder, y: float, ri: float, ro: float, n: Vector3) -> void:
	var o := PackedInt32Array()
	var i := PackedInt32Array()
	for j in SEG + 1:
		var lon := TAU * j / SEG
		o.append(b.add(Vector3(cos(lon) * ro, y, sin(lon) * ro), n))
		i.append(b.add(Vector3(cos(lon) * ri, y, sin(lon) * ri), n))
	for j in SEG:
		b.quad(o[j], o[j + 1], i[j + 1], i[j])


## Боковая поверхность вращения от (r0, y0) до (r1, y1); outward = false — лицом к оси.
static func _side(b: Builder, r0: float, y0: float, r1: float, y1: float, outward: bool, seg: int = SEG) -> void:
	var slope := (r0 - r1) / (y1 - y0)
	var lo := PackedInt32Array()
	var hi := PackedInt32Array()
	for j in seg + 1:
		var lon := TAU * j / seg
		var n := Vector3(cos(lon), slope, sin(lon)) * (1.0 if outward else -1.0)
		lo.append(b.add(Vector3(cos(lon) * r0, y0, sin(lon) * r0), n))
		hi.append(b.add(Vector3(cos(lon) * r1, y1, sin(lon) * r1), n))
	for j in seg:
		b.quad(hi[j], hi[j + 1], lo[j + 1], lo[j])


## Брусок с центром c и полуосями u, v, w.
static func _block(b: Builder, c: Vector3, u: Vector3, v: Vector3, w: Vector3) -> void:
	var axes := [u, v, w]
	for k in 3:
		var a: Vector3 = axes[k]
		var p: Vector3 = axes[(k + 1) % 3]
		var q: Vector3 = axes[(k + 2) % 3]
		for sgn in [1.0, -1.0]:
			var n: Vector3 = a * sgn
			var f: Vector3 = c + a * sgn
			b.quad(b.add(f - p - q, n), b.add(f + p - q, n), b.add(f + p + q, n), b.add(f - p + q, n))


## Ротор в диске радиуса 0,5 толщиной 1 по y: ступица и лопасти, повёрнутые на 25° вокруг своего луча.
static func _rotor(b: Builder, blades: int) -> void:
	_side(b, 0.12, -0.5, 0.12, 0.5, true, 12)
	_disc(b, 0.5, 0.12, Vector3.UP, 12)
	_disc(b, -0.5, 0.12, Vector3.DOWN, 12)
	for k in blades:
		var a := TAU * k / blades
		var radial := Vector3(cos(a), 0, sin(a))
		var tangent := Vector3(-radial.z, 0, radial.x)
		var chord := (tangent * cos(0.44) + Vector3.UP * sin(0.44)) * 0.08
		var thick := radial.cross(chord).normalized() * 0.02
		_block(b, radial * 0.3, radial * 0.19, chord, thick)


## Клин: сечение в плоскости yz — треугольник (−z: y от −0,5 до 0,5; +z: острый край на y = 0).
static func _wedge(b: Builder) -> void:
	for x in [-0.5, 0.5]:
		var n := Vector3(x * 2.0, 0, 0)
		b.tri(b.add(Vector3(x, 0.5, -0.5), n), b.add(Vector3(x, -0.5, -0.5), n), b.add(Vector3(x, 0, 0.5), n))
	var back := Vector3.FORWARD
	b.quad(b.add(Vector3(-0.5, 0.5, -0.5), back), b.add(Vector3(0.5, 0.5, -0.5), back),
		b.add(Vector3(0.5, -0.5, -0.5), back), b.add(Vector3(-0.5, -0.5, -0.5), back))
	for y in [0.5, -0.5]:
		var n := Vector3(0, y * 2.0, 0.5)
		b.quad(b.add(Vector3(-0.5, y, -0.5), n), b.add(Vector3(0.5, y, -0.5), n),
			b.add(Vector3(0.5, 0, 0.5), n), b.add(Vector3(-0.5, 0, 0.5), n))


## Движение корпуса (pogrujenie Core/HullMotion.cs, заметки ART-001): роторы раскручиваются за тягой с запаздыванием,
## рули глубины встают за «Всплыть»/«Вниз». Без узлов.
class Motion:
	const MAX_RPS := 2.5        ## оборотов в секунду на полной тяге
	const SPIN_LAG := 1.5
	const MAX_PITCH := 25.0     ## градусов
	const PITCH_LAG := 3.0

	var spin := 0.0             ## −1…1 доля оборотов
	var rotor_angle := 0.0      ## градусы 0…360
	var pitch := 0.0            ## градусы: + — всплытие, задняя кромка руля поднята

	func reset() -> void:
		spin = 0.0
		rotor_angle = 0.0
		pitch = 0.0

	## thrust, vert — ввод пилота (−1…1), k — доля двигателей реактора.
	func update(dt: float, thrust: float, vert: float, k: float) -> void:
		if dt <= 0.0:
			return
		var target := clampf(thrust, -1.0, 1.0) * maxf(0.0, k)
		spin += (target - spin) * minf(1.0, dt * SPIN_LAG)
		rotor_angle = fposmod(rotor_angle + spin * MAX_RPS * 360.0 * dt, 360.0)
		pitch += (clampf(vert, -1.0, 1.0) * MAX_PITCH - pitch) * minf(1.0, dt * PITCH_LAG)

	## Угол ротора борта sx (−1 — левый): роторы крутятся навстречу друг другу.
	func rotor_angle_of(sx: float) -> float:
		return -rotor_angle if sx < 0.0 else rotor_angle
