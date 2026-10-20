class_name Warmup
extends RefCounted
## Прогрев шейдеров при старте (issue #50). Рендерер Compatibility собирает шейдер материала в момент, когда предмет
## впервые попадает в кадр с данным набором огней, — на телефоне это провал до 10–16 к/с при первом повороте головы,
## разряде, гашении прожектора, появлении члена экипажа. Пока идёт прогрев, экран закрыт шторкой «Погружение…»,
## камера за несколько кадров оглядывает корабль из центра мостика (взгляды VIEWS), скрытые детали корабля на эти
## кадры показаны, вспышка разряда горит на наибольший радиус, а последние взгляды — с погашенным прожектором.
## Сцену собирает Main (`main.warm`, `Main.warming()`); тесты и снимки без прогрева — `Warmup.enabled = false`.

static var enabled := true

## Глаза в осях корабля: центр мостика (палуба z −6…2), рост как у игрока.
const EYE := Vector3(0.0, 1.6, -2.0)
## Взгляды по кадру на каждый: [курс°, наклон°, прожектор горит]. Круг по 60° (поле зрения Deck.FOV шире 60°),
## пол и потолок, затем круг вперёд-назад без прожектора.
const VIEWS := [
	[0.0, -8.0, true], [60.0, -8.0, true], [120.0, -8.0, true], [180.0, -8.0, true], [240.0, -8.0, true], [300.0, -8.0, true],
	[0.0, -60.0, true], [180.0, -60.0, true], [0.0, 50.0, true], [180.0, 50.0, true],
	[0.0, -8.0, false], [90.0, -8.0, false], [180.0, -8.0, false], [270.0, -8.0, false],
]
## Члены экипажа на время прогрева — каждая внешность CrewRig.MODELS перед глазами (x, z на палубе).
const MATE_AT := [Vector2(-0.6, -3.6), Vector2(0.6, -3.6)]

var i := 0


func _init() -> void:
	if not enabled:
		i = VIEWS.size()


func active() -> bool:
	return i < VIEWS.size()


## Курс камеры (радианы) в текущем взгляде.
func yaw() -> float:
	return deg_to_rad(VIEWS[mini(i, VIEWS.size() - 1)][0])


func pitch() -> float:
	return deg_to_rad(VIEWS[mini(i, VIEWS.size() - 1)][1])


## Прожектор в этом кадре прогрева (без прогрева — как в игре).
func lamp() -> bool:
	return not active() or VIEWS[i][2]


## Кадр показан — следующий взгляд. Возвращает true, когда прогрев только что кончился.
func advance() -> bool:
	if not active():
		return false
	i += 1
	return not active()


## Доля прогрева 0…1 — для шторки.
func progress() -> float:
	return clampf(float(i) / VIEWS.size(), 0.0, 1.0)


## Наибольший радиус разряда: доля «Разряд» на пределе Reactor.MAX.
static func zap_radius() -> float:
	return Zap.radius_for(float(Reactor.MAX) / Reactor.DEFAULTS[Reactor.Sys.ZAP])
