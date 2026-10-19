class_name BridgePlan
## Оболочка мостика по ART-002 (docs/concept-art/mostik.md) на игровых размерах 10 × 8 × 3,2 м:
## пол, потолок, борта, кормовая переборка с люком, носовая стена с окном из трёх секций,
## скос потолка от окна, рёбра бортов и плафоны. Оси корабля: нос в −Z, пол y = 0, правый борт +X.

enum Paint { METAL, SEAM, SHADOW, DECK, PLAFOND }

## Палитра концепта.
const COLORS := {
	Paint.METAL: Color("8C806B"),
	Paint.SEAM: Color("514D43"),
	Paint.SHADOW: Color("0B1C24"),
	Paint.DECK: Color("34484C"),
	Paint.PLAFOND: Color("F6DEAC"),
}

const HALF_W := 5.0          ## внешняя полуширина отсека (борта по x ±5)
const SIDE_INNER := 4.9
const CEILING := 3.2
const NOSE_INNER := -5.9
const STERN := 2.0
const WINDOW_HALF := 3.8
const WINDOW_BOTTOM := 0.8
const WINDOW_TOP := 2.7
const MULLIONS: Array[float] = [-1.3, 1.3]
const SLOPE_DEPTH := 1.0
const LAMP_Z: Array[float] = [-5.0, -3.5, -2.0, -0.5, 1.0]
const LAMP_Y := 2.35
const RIB_Z: Array[float] = [-4.25, -2.75, -1.25, 0.25]
const HATCH_HALF := 0.6      ## люк в коридор: проём 1,2 × 2,1 м
const HATCH_H := 2.1


## Брусок: размеры, центр и наклон вокруг x (градусы).
class Part:
	var name: String
	var paint: int
	var size: Vector3
	var center: Vector3
	var rx: float

	func _init(n: String, p: int, s: Vector3, c: Vector3, rot_x: float = 0.0) -> void:
		name = n
		paint = p
		size = s
		center = c
		rx = rot_x

	func xform() -> Transform3D:
		return Transform3D(Basis(Vector3.RIGHT, deg_to_rad(rx)), center)

	## Восемь углов с учётом наклона.
	func corners() -> Array[Vector3]:
		var out: Array[Vector3] = []
		var t := xform()
		for sx in [-0.5, 0.5]:
			for sy in [-0.5, 0.5]:
				for sz in [-0.5, 0.5]:
					out.append(t * Vector3(sx * size.x, sy * size.y, sz * size.z))
		return out


static func parts() -> Array[Part]:
	var p: Array[Part] = []
	var add := func(n: String, k: int, s: Vector3, c: Vector3, rx: float = 0.0) -> void:
		p.append(Part.new(n, k, s, c, rx))
	var len_z := STERN - NOSE_INNER
	var mid_z := (STERN + NOSE_INNER) / 2.0
	# пол и потолок
	add.call("Пол", Paint.DECK, Vector3(2 * HALF_W, 0.1, len_z + 0.2), Vector3(0, -0.05, mid_z))
	add.call("Потолок", Paint.SEAM, Vector3(2 * HALF_W, 0.1, len_z + 0.2), Vector3(0, CEILING + 0.05, mid_z))
	# борта
	for s in [-1.0, 1.0]:
		add.call("Борт", Paint.METAL, Vector3(0.1, CEILING, len_z), Vector3(s * (SIDE_INNER + 0.05), CEILING / 2.0, mid_z))
	# носовая стена вокруг окна
	var nz := NOSE_INNER - 0.1
	add.call("Нос: под окном", Paint.METAL, Vector3(2 * HALF_W, WINDOW_BOTTOM, 0.2), Vector3(0, WINDOW_BOTTOM / 2.0, nz))
	add.call("Нос: над окном", Paint.METAL, Vector3(2 * HALF_W, CEILING - WINDOW_TOP, 0.2), Vector3(0, (CEILING + WINDOW_TOP) / 2.0, nz))
	for s in [-1.0, 1.0]:
		var w := HALF_W - WINDOW_HALF
		add.call("Нос: у окна", Paint.METAL, Vector3(w, WINDOW_TOP - WINDOW_BOTTOM, 0.2),
			Vector3(s * (WINDOW_HALF + w / 2.0), (WINDOW_TOP + WINDOW_BOTTOM) / 2.0, nz))
	# рама и переплёты окна
	var wy := (WINDOW_TOP + WINDOW_BOTTOM) / 2.0
	var wh := WINDOW_TOP - WINDOW_BOTTOM
	add.call("Рама окна: низ", Paint.METAL, Vector3(2 * WINDOW_HALF + 0.2, 0.1, 0.3), Vector3(0, WINDOW_BOTTOM, -5.92))
	add.call("Рама окна: верх", Paint.METAL, Vector3(2 * WINDOW_HALF + 0.2, 0.1, 0.3), Vector3(0, WINDOW_TOP, -5.92))
	for s in [-1.0, 1.0]:
		add.call("Рама окна: бок", Paint.METAL, Vector3(0.14, wh, 0.3), Vector3(s * (WINDOW_HALF + 0.03), wy, -5.92))
	for x in MULLIONS:
		add.call("Переплёт окна", Paint.METAL, Vector3(0.16, wh, 0.3), Vector3(x, wy, -5.95))
	# скос потолка от верхней кромки окна назад до потолка
	var rise := CEILING - WINDOW_TOP
	var slope_len := sqrt(SLOPE_DEPTH * SLOPE_DEPTH + rise * rise)
	var ang := rad_to_deg(atan2(rise, SLOPE_DEPTH))
	add.call("Скос потолка", Paint.METAL, Vector3(2 * SIDE_INNER, 0.06, slope_len),
		Vector3(0, (WINDOW_TOP + CEILING) / 2.0, NOSE_INNER + SLOPE_DEPTH / 2.0), -ang)
	# кормовая переборка с проёмом люка
	var sw := HALF_W - HATCH_HALF
	for s in [-1.0, 1.0]:
		add.call("Корма", Paint.METAL, Vector3(sw, CEILING, 0.2), Vector3(s * (HATCH_HALF + sw / 2.0), CEILING / 2.0, STERN + 0.1))
	add.call("Корма: над люком", Paint.METAL, Vector3(2 * HATCH_HALF, CEILING - HATCH_H, 0.2),
		Vector3(0, (CEILING + HATCH_H) / 2.0, STERN + 0.1))
	add.call("Люк", Paint.SEAM, Vector3(2 * HATCH_HALF, HATCH_H, 0.08), Vector3(0, HATCH_H / 2.0, STERN + 0.12))
	# рёбра бортов и плафоны с подложкой
	for s in [-1.0, 1.0]:
		for z in RIB_Z:
			add.call("Ребро борта", Paint.METAL, Vector3(0.08, CEILING, 0.18), Vector3(s * (SIDE_INNER - 0.04), CEILING / 2.0, z))
		for z in LAMP_Z:
			add.call("Подложка плафона", Paint.SEAM, Vector3(0.04, 0.38, 0.5), Vector3(s * (SIDE_INNER - 0.02), LAMP_Y, z))
			add.call("Плафон", Paint.PLAFOND, Vector3(0.06, 0.28, 0.4), Vector3(s * (SIDE_INNER - 0.05), LAMP_Y, z))
	return p
