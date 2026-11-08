class_name Warmup
extends RefCounted
## Прогрев шейдеров при старте (issue #50). Рендерер Compatibility собирает шейдер материала в момент, когда предмет
## впервые попадает в кадр с данным набором огней, — на телефоне это провал до 10–16 к/с при первом повороте головы,
## разряде, гашении прожектора, появлении члена экипажа. Пока идёт прогрев, экран закрыт заставкой ART-034 (`Splash`, `WarmSplash`),
## камера за несколько кадров оглядывает корабль из центра мостика (взгляды VIEWS), скрытые детали корабля на эти
## кадры показаны. Прожектор и вспышка разряда в сцене всегда (погашены энергией, Searchlight.DARK), поэтому набор огней
## на предметах один и кадров «без прожектора» и «со вспышкой» не нужно (issue #159).
## Сцену собирает Main (`main.warm`, `Main.warming()`); тесты и снимки без прогрева — `Warmup.enabled = false`.
## Issue #159: ещё кадры камерой с борта (точки облёта OUTSIDE — корпус и дно снаружи), на время прогрева выпущены
## частицы корабля (пар вентиля, струя и искры пробоины) и показаны скрытые панели интерфейса (решение экипажа).

static var enabled := true

## Глаза в осях корабля: центр мостика (палуба z −6…2), рост как у игрока.
const EYE := Vector3(0.0, 1.6, -2.0)
## Взгляды по кадру на каждый: [курс°, наклон°]. Круг по 60° (поле зрения Deck.FOV шире 60°), пол и потолок.
const VIEWS := [
	[0.0, -8.0], [60.0, -8.0], [120.0, -8.0], [180.0, -8.0], [240.0, -8.0], [300.0, -8.0],
	[0.0, -60.0], [180.0, -60.0], [0.0, 50.0], [180.0, 50.0],
]
## Issue #217: рывок при первом нажатии у пульта энергии — камера впервые вплотную к пульту и взглядом вниз (мелкие
## уровни текстур, ближние детали). Кадры глазами у постов: [x, y, z, курс°, наклон°] в осях корабля —
## у открытого пульта энергии (ракурс ART-050: PowerScreen.CAM_AT, CAM_YAW, CAM_PITCH), за штурвалом сидя
## (Deck.SEAT_EYE), у сканера.
const POSTS := [
	[-3.0, Deck.Walker.EYE, -2.0, 70.0, -32.0],
	[0.0, Deck.SEAT_EYE, Deck.SEAT_Z, 0.0, -20.0],
	[3.85, Deck.Walker.EYE, -2.0, -90.0, -30.0],
]
## Кадры снаружи после взглядов с мостика: [вид облёта, точка пути] — камера с борта смотрит на корпус. Issue #519:
## ещё вид при всплытии (`Flyby.Kind.SURFACE`, последняя точка — под бортом, взглядом вверх к льду): там идёт продувка
## (выпуски `Wake.vent`), и без этого кадра первый вид снизу собирал шейдеры прямо на всплытии (провал 211 мс, `21a-vent`).
## Issue #424: на холодном кэше (первый запуск после установки APK) почти вся сборка шейдеров шла в кадр 1 — 8,3 с из
## 10,9 на эмуляторе, полоса заставки стояла. Первый взгляд показываем по слоям: STAGES кадров тем же взглядом VIEWS[0],
## на кадре s скрыто то, что в Main.warm_layers() идёт после слоя s (интерьер → экипаж и корпус → вода → живой мир);
## сборка делится на части, полоса заставки идёт. Шейдеров столько же — кадров на STAGES больше.
const STAGES := 3
const OUTSIDE := [[Flyby.Kind.START, 0], [Flyby.Kind.START, 2], [Flyby.Kind.SURFACE, 2]]
## Члены экипажа на время прогрева — каждая роль (снаряжение MOD-016 CrewRig.ROLE_GEAR) и каждая внешность
## CrewRig.MODELS перед глазами (x, z на палубе). Issue #883: раньше все были пилотами — фартук, щиток, туника, пробы и
## планшет впервые рисовались непрозрачными при появлении товарища (провал 192–309 мс на `06c-crew-model`, инженер).
const MATE_AT := [Vector2(-0.6, -3.6), Vector2(0.6, -3.6), Vector2(-0.6, -4.8), Vector2(0.6, -4.8)]
## Issue #217: ещё по фигуре каждой внешности материалом своего игрока (`CrewView.as_own`) — его шейдер иначе
## собирался при первом взгляде на свои руки у пульта энергии (рывок 0,8–1,4 с на шаге `08-power`).
const OWN_AT := [Vector2(-1.3, -4.2), Vector2(1.3, -4.2)]


## Сколько товарищей ставит прогрев: на каждую роль и каждую внешность хотя бы по одному (#883).
static func mate_count() -> int:
	return maxi(Crew.Role.size(), CrewRig.MODELS.size())

var i := 0


func _init() -> void:
	if not enabled:
		i = frames()


## Всего кадров прогрева: взгляды из центра мостика, у постов и снаружи.
static func frames() -> int:
	return _inside() + OUTSIDE.size()


static func _inside() -> int:
	return STAGES + VIEWS.size() + POSTS.size()


func active() -> bool:
	return i < frames()


## Номер кадра снаружи в OUTSIDE; -1 — кадр с мостика или прогрев кончился.
func outside() -> int:
	return i - _inside() if active() and i >= _inside() else -1


## Слой первого взгляда (0…STAGES−1): показано только то, что в слоях до него; -1 — обычный кадр, всё видно.
func stage() -> int:
	return i if active() and i < STAGES else -1


## Камера с борта для кадра снаружи k (оси корабля): точка пути облёта, взгляд как у самого облёта (`Flyby.pose`).
static func outside_pose(k: int) -> Transform3D:
	var kind: Flyby.Kind = OUTSIDE[k][0]
	var path: Array = Flyby.START_PATH if kind == Flyby.Kind.START else Flyby.SURFACE_PATH
	var p: Vector3 = path[OUTSIDE[k][1]]
	var look := Flyby.LOOK_AT + (Vector3.UP * Flyby.SURFACE_LOOK_UP if kind == Flyby.Kind.SURFACE else Vector3.ZERO)
	return Transform3D(Basis.looking_at(look - p, Vector3.UP), p)


## Взгляд с мостика текущего кадра: [x, y, z, курс°, наклон°].
func _view() -> Array:
	var k := clampi(i - STAGES, 0, _inside() - STAGES - 1)   # кадры по слоям — тем же первым взглядом
	if k < VIEWS.size():
		return [EYE.x, EYE.y, EYE.z, VIEWS[k][0], VIEWS[k][1]]
	return POSTS[k - VIEWS.size()]


## Где глаза камеры в текущем взгляде (оси корабля): центр мостика или место у поста.
func eye() -> Vector3:
	var v := _view()
	return Vector3(v[0], v[1], v[2])


## Курс камеры (радианы) в текущем взгляде.
func yaw() -> float:
	return deg_to_rad(_view()[3])


func pitch() -> float:
	return deg_to_rad(_view()[4])


## Кадр показан — следующий взгляд. Возвращает true, когда прогрев только что кончился.
func advance() -> bool:
	if not active():
		return false
	i += 1
	return not active()


## Доля прогрева 0…1 — для шторки.
func progress() -> float:
	return clampf(float(i) / frames(), 0.0, 1.0)


## Наибольший радиус разряда: доля «Разряд» на пределе Reactor.MAX.
static func zap_radius() -> float:
	return Zap.radius_for(float(Reactor.MAX) / Reactor.DEFAULTS[Reactor.Sys.ZAP])
