class_name EcoDustBuffer
extends RefCounted
## Буфер MultiMesh мути у дна (TRANSFORM_3D + цвет, GrazerView.DUST_STRIDE) — общий для всех видов, что поднимают
## облачка пулом EcoGrazerDust (скребуны, кольчужник, ежи, серпохвост, хватень, скальник, гротовик, монетники,
## подушечник, эхоловец, стеклоуст). Тот же рисунок, что GrazerView.pack_dust, но дешевле (issue #732): буфер не
## создаётся заново каждый кадр, растаявшее облачко стягивается в точку один раз, а не переписывается каждый кадр,
## счёт возраста, размера, места и света — одной строкой без вызовов (в GDScript каждый вызов дорог), сколько
## облачков видно — тем же проходом (без EcoGrazerDust.shown). Грузить в MultiMesh — только когда `changed`.

var data := PackedFloat32Array()
## Сколько облачков видно после последнего pack.
var shown := 0
## Буфер изменился с прошлой загрузки: мути нет и не было — не грузим заново (issue #133).
var changed := true
## Буфер отдан общему слою мути живого мира (EcoDustLayer.gather, issue #849): свой слой вида убран, upload только
## отмечает `dirty`, грузит общий слой.
var joined := false
## Для общего слоя: буфер менялся с его прошлой сборки.
var dirty := false
var _packed := PackedByteArray()
var _added := -1
## В пуле есть облачко, что ещё не поднялось (время мира шло назад) — пул проходить, пока не встанет.
var _pending := false


## Переписать буфер для пула d в момент t: flow — течение мира, ship — корабль (свет прожектора, null — темно),
## dark/lit — цвет ила в темноте и в луче, floor_at(x, z) — высота видимой сетки дна (пустой — не поднимать).
## Возвращает, сколько облачков видно.
func pack(d: EcoGrazerDust, t: float, flow: Vector3, ship: EcoLink.ShipState = null,
		dark: Color = EcoGrazerDust.COLOR, lit: Color = EcoGrazerDust.LIT, floor_at: Callable = Callable()) -> int:
	var puffs := d.puffs
	var stride := GrazerView.DUST_STRIDE
	var was := shown
	var fresh := data.size() != puffs.size() * stride
	if fresh:
		data.resize(puffs.size() * stride)
		data.fill(0.0)
		_packed.resize(puffs.size())
		_packed.fill(0)
	elif was == 0 and not _pending and d.added == _added:
		changed = false   # всё растаяло и нового нет — буфер тот же, проход по пулу не нужен
		return 0
	_added = d.added
	var lit_on := ship != null and ship.light_on and ship.light_range > 0.0
	var eye := ship.pos if ship != null else Vector3.ZERO
	var drift := Vector3(flow.x, 0.0, flow.z) * EcoGrazerDust.DRIFT * EcoGrazerDust.LIFE
	var has_floor := floor_at.is_valid()
	var dr := lit.r - dark.r
	var dg := lit.g - dark.g
	var db := lit.b - dark.b
	var n_shown := 0
	_pending = false
	for n in puffs.size():
		var p := puffs[n]
		var age := (t - p.born) / EcoGrazerDust.LIFE
		if age < 0.0 or age >= 1.0 or p.alpha <= 0.0:
			if age < 0.0 and p.alpha > 0.0:
				_pending = true
			if _packed[n] != 0:
				var i0 := n * stride
				for k in stride:
					data[i0 + k] = 0.0
				_packed[n] = 0
			continue
		n_shown += 1
		var i := n * stride
		var a := p.alpha * minf(1.0, age / 0.1) * (1.0 - age)
		if a <= 0.0:   # миг рождения: ещё не видно — точка, как растаявшее
			if _packed[n] != 0:
				for k in stride:
					data[i + k] = 0.0
				_packed[n] = 0
			continue
		_packed[n] = 1
		var grow := 1.0 - (1.0 - age) * (1.0 - age)
		var s := lerpf(EcoGrazerDust.SIZE_START, EcoGrazerDust.SIZE_END, grow) * p.scale
		var o := p.at + drift * age
		o.y += EcoGrazerDust.RISE * p.scale * grow
		if has_floor:
			if p.floor_y == -INF:   # дно под облачком — раз на облачко: течение уносит его на полметра
				p.floor_y = float(floor_at.call(p.at.x, p.at.z))
			o.y = maxf(o.y, p.floor_y + s * EcoGrazerDust.CLEAR)
		var k := 0.0
		if lit_on:
			k = clampf((1.0 - o.distance_to(eye) / ship.light_range) * 2.0, 0.0, 1.0)
		data[i] = s; data[i + 3] = o.x
		data[i + 5] = s; data[i + 7] = o.y
		data[i + 10] = s; data[i + 11] = o.z
		data[i + 12] = dark.r + dr * k; data[i + 13] = dark.g + dg * k; data[i + 14] = dark.b + db * k
		data[i + 15] = a
	shown = n_shown
	changed = fresh or n_shown > 0 or was > 0
	return n_shown


## Загрузить буфер в слой мути mi, если он изменился (issue #133), и спрятать слой, пока облачков нет: пустой
## MultiMesh всё равно стоит вызова отрисовки, а слоёв мути у видов ≈20 (issue #849).
## В общем слое (`joined`) mi не нужен — только отметка для EcoDustLayer.sync.
func upload(mi: MultiMeshInstance3D) -> void:
	if joined:
		dirty = dirty or changed
		return
	if changed:
		mi.multimesh.buffer = data
	mi.visible = shown > 0
