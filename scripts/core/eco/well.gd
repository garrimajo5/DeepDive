class_name EcoWell
extends EcoSystem
## Световой колодец — место 5 карты отмели по концепту ART-031 (docs/concept-art/svetovoy-kolodets.md): локальное
## просветление льда, а не яма в дне. Трещина во льду 12 × 3 м, от неё до дна — столб мягкого солнечного света,
## внизу — пятно светящегося мха 22 × 16 м. Своего источника света нет: столб наклонён по «солнцу» OceanView
## (DirectionalLight3D (−70°; 20°; 0)), трещина смещена против света, чтобы луч падал ровно в пятно мха.
## Мох — существующий вид (EcoMoss, ART-004): пять своих пятен, скребуны рифа их не делят. Яркость столба и трещины
## дышит на ± 5 % за 10 с (без пульса и вращения). Форма своя, от зерна мира не зависит; столкновения нет — свет.

const ID := "well"
## Точка на карте отмели (karta-otmeli-mesta.json, место 5) — та же, что Run.PLACES["well"]; середина пятна мха.
const CENTER := Vector2(-170.0, -70.0)
## «Солнце» OceanView: поворот DirectionalLight3D в градусах (один источник света с отмелью).
const SUN_DEG := Vector3(-70.0, 20.0, 0.0)
## Трещина во льду, м: длина и ширина; насколько ниже плоскости льда (чтобы не мерцала с ней).
const CRACK_L := 12.0
const CRACK_W := 3.0
const CRACK_SINK := 0.06
## Пятно света и мха на дне, м: длина и ширина (длинная сторона — вдоль трещины).
const SPOT_L := 22.0
const SPOT_W := 16.0
## Столб: сторон оболочки и колец по высоте (открытая оболочка без торцов: 12 × 3 × 2 = 72 треугольника).
const SIDES := 12
const RINGS := 4
## Край трещины: вершин по кругу и рваность (доля полуоси); ореол вокруг — во сколько раз шире.
const CRACK_PTS := 18
const CRACK_JAG := 0.22
const HALO := 1.7
## Дыхание яркости: размах (доля) и период, с.
const PULSE := 0.05
const PERIOD := 10.0
## Пятна мха в пятне света (локально: вдоль трещины, поперёк), м — середина и четыре вокруг, перекрываются.
const MOSS: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(-7.5, 0.6), Vector2(7.5, -0.6), Vector2(1.2, 4.5),
	Vector2(-1.2, -4.5)]

## Середина пятна на дне (мир) и середина трещины под льдом.
var base := Vector3.ZERO
var top := Vector3.ZERO
## Вдоль трещины и поперёк (горизонтальные единичные векторы мира).
var along := Vector3.RIGHT
var across := Vector3.BACK
## Высота дна (мир передаёт при сбросе; без дна — ровно −46 м).
var ground: Callable
## Свой мох (MossView рисует его у WellView).
var moss: EcoMoss

var _center: Vector2


## center — своё место (для тестов), по умолчанию — с карты отмели.
func _init(center: Vector2 = CENTER) -> void:
	_center = center


## Куда идёт свет «солнца» OceanView (единичный, вниз).
static func sun_dir() -> Vector3:
	return -Basis.from_euler(SUN_DEG * PI / 180.0).z


## Яркость столба и трещины в момент t, с: 1 ± PULSE за PERIOD (то же — в шейдере WellView по TIME).
static func glow(t: float) -> float:
	return 1.0 + PULSE * sin(TAU * t / PERIOD)


func reset(world: EcoWorld) -> void:
	ground = world.ground
	_build()
	moss = EcoMoss.new(moss_spots())
	moss.reset(world)


func step(world: EcoWorld, dt: float) -> void:
	if moss:
		moss.step(world, dt)


## Дно под (x, z) мира: мир передаёт Seabed.height; без него — −46 м.
func floor_y(x: float, z: float) -> float:
	return float(ground.call(x, z)) if ground.is_valid() else -46.0


func _build() -> void:
	base = Vector3(_center.x, floor_y(_center.x, _center.y), _center.y)
	var d := sun_dir()
	var top_y := Seabed.ICE_Y - CRACK_SINK
	top = base - d * ((base.y - top_y) / d.y)
	# трещина лежит поперёк хода света: свет падает на её широкую сторону
	across = Vector3(d.x, 0.0, d.z).normalized()
	along = Vector3.UP.cross(across).normalized()


## Места пятен мха (мир, y — дно).
func moss_spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for m in MOSS:
		var p := base + along * m.x + across * m.y
		p.y = floor_y(p.x, p.z)
		out.append(p)
	return out


## Точка оболочки столба: кольцо k (0 — трещина, RINGS − 1 — дно), сторона j. Сечение — горизонтальный эллипс,
## от трещины 12 × 3 до пятна 22 × 16, середина — на линии света.
func column_point(k: int, j: int) -> Vector3:
	var s := float(k) / float(RINGS - 1)
	var c := top.lerp(base, s)
	var a := lerpf(CRACK_L, SPOT_L, s) * 0.5
	var b := lerpf(CRACK_W, SPOT_W, s) * 0.5
	var ang := TAU * float(j) / float(SIDES)
	return c + along * (cos(ang) * a) + across * (sin(ang) * b)


## Точка рваного края трещины i (мир, под льдом): эллипс 12 × 3 с зазубринами; scale > 1 — ореол.
func crack_point(i: int, scale: float = 1.0) -> Vector3:
	var ang := TAU * float(i) / float(CRACK_PTS)
	var jag := 1.0 - CRACK_JAG * fposmod(sin(float(i) * 12.9898 + 4.1) * 43758.5453, 1.0)
	var r := jag * scale
	return top + along * (cos(ang) * CRACK_L * 0.5 * r) + across * (sin(ang) * CRACK_W * 0.5 * r)
