class_name MelochView
extends Node3D
## Фоновая мелочь у дна (EcoMeloch, #2108): один MultiMesh «Мелочь у дна» — один вызов отрисовки,
## ~336 экземпляров рыбки 6–15 см (меш — тот же силуэт, что у «Силуэтов вдали», FarLifeView.build). Материал —
## без света с цветом экземпляра: шейдеров не прибавилось. «Экономно» — узел скрыт (set_lite): ноль вызовов.

## Чисел на экземпляр: transform 3 × 4 и цвет (4).
const STRIDE := 16
## Пятно переписывается раз в EVERY кадров, пятна — по очереди: мелочь плывёт 0,2–0,5 м/с, сдвиг за два кадра
## на 30 кадр/с — до 3 см на 9…45 м, глазом не виден, а шаг вида — вдвое дешевле.
const EVERY := 2

var mm: MultiMeshInstance3D
## Последний буфер (для тестов).
var buffer := PackedFloat32Array()
var lite := false
## Пятно в прошлом кадре было видно (его мелочь в буфере не сжата).
var _shown: Array[bool] = []
## Номер кадра (очередь пятен).
var frame := 0


func _init() -> void:
	name = "Мелочь у дна"
	mm = EcoMM.instance(self, "Мелочь у дна", FarLifeView.build(), EcoMeloch.count(), true)
	buffer.resize(EcoMeloch.count() * STRIDE)
	_shown.resize(EcoMeloch.PATCHES)
	_shown.fill(false)
	for i in EcoMeloch.PATCHES:
		var c := EcoMeloch.tint(i)
		for j in EcoMeloch.PER:
			var at := (i * EcoMeloch.PER + j) * STRIDE + 12
			buffer[at] = c.r
			buffer[at + 1] = c.g
			buffer[at + 2] = c.b
			buffer[at + 3] = 1.0
	mm.multimesh.buffer = buffer


## «Экономно» (ART-044): мелочи нет.
func set_lite(on: bool) -> void:
	lite = on
	visible = not on


## Мелочь на время мира t у корабля ship_pos; ground — высота дна (x, z). В кадр — каждое EVERY-е пятно.
func sync(t: float, ship_pos: Vector3, ground: Callable) -> void:
	if lite:
		return
	var dirty := false
	frame += 1
	for i in EcoMeloch.PATCHES:
		if (i + frame) % EVERY != 0:
			continue
		var s := EcoMeloch.patch_at(i, t, ship_pos, ground)
		var on := s[2] > 0.0
		if not on and not _shown[i]:
			continue   # невидимое и уже сжатое — буфер не трогаем
		_shown[i] = on
		dirty = true
		for j in EcoMeloch.PER:
			EcoMM.put(buffer, (i * EcoMeloch.PER + j) * STRIDE, EcoMeloch.mote(i, j, t, s, ground))
	if dirty:
		mm.multimesh.buffer = buffer
