class_name EcoMossLook
extends RefCounted
## Как выглядит светящийся мох (пятна мха в js/world.js, Unity `Core/EcoMossLook.cs`): каждое пятно — сетка 7 × 7 м
## из 8 × 8 клеток, лежит по дну на 0,14 м выше него. Своя яркость вершины base: круг радиусом 3,4 м с мягким краем
## (полная до 1 м) и пятнистость по шуму, как в браузере. Яркость пятна целиком — EcoMoss.Patch.glow(): объеденное
## тускнеет до 0,15, отрастая — разгорается. Сцена складывает все 22 пятна в один меш (MossView).
## Грани смотрят вверх по правилу Godot: (b − a) × (c − a) — вниз, внутрь дна.

## Клеток по стороне пятна; вершин по стороне — на одну больше.
const CELLS := 8
const SIDE := CELLS + 1
const VERTS_PER_PATCH := SIDE * SIDE
const TRIS_PER_PATCH := CELLS * CELLS * 2
## Над дном (м).
const ABOVE := 0.14
## Цвет мха: цвет вершин (0,45; 1; 0,75) × цвет материала 0x9dffd0, как в браузере.
const COLOR := Color(0.45 * 0x9d / 255.0, 1.0, 0.75 * 0xd0 / 255.0)


## Меш всех пятен: вершины, своя яркость каждой вершины, номер пятна вершины, треугольники.
class MossMesh:
	extends RefCounted
	var verts := PackedVector3Array()
	var base := PackedFloat32Array()
	var patch := PackedInt32Array()
	var tris := PackedInt32Array()


## Своя яркость вершины пятна в точке (lx, lz) от середины пятна (px, pz): G.smooth(3,4; 1; r) × (0,55 + шум × 0,6).
static func base_at(lx: float, lz: float, px: float, _pz: float) -> float:
	var r := sqrt(lx * lx + lz * lz)
	return HashNoise.smooth(EcoMoss.RADIUS, 1.0, r) * (0.55 + HashNoise.value(lx * 1.3 + px, lz * 1.3) * 0.6)


## Собрать меш всех пятен мха по дну ground (пустой Callable — пятна плоские на высоте пятна).
static func build(patches: Array[EcoMoss.Patch], ground: Callable = Callable()) -> MossMesh:
	var m := MossMesh.new()
	var n := patches.size()
	m.verts.resize(n * VERTS_PER_PATCH)
	m.base.resize(n * VERTS_PER_PATCH)
	m.patch.resize(n * VERTS_PER_PATCH)
	m.tris.resize(n * TRIS_PER_PATCH * 3)
	var half := EcoMoss.SIZE / 2.0
	var st := EcoMoss.SIZE / CELLS
	var t := 0
	for p in n:
		var c := patches[p].pos
		var v0 := p * VERTS_PER_PATCH
		for iz in SIDE:
			for ix in SIDE:
				var lx := -half + ix * st
				var lz := -half + iz * st
				var x := c.x + lx
				var z := c.z + lz
				var y: float = (ground.call(x, z) if ground.is_valid() else c.y) + ABOVE
				var v := v0 + iz * SIDE + ix
				m.verts[v] = Vector3(x, y, z)
				m.base[v] = base_at(lx, lz, c.x, c.z)
				m.patch[v] = p
		for iz in CELLS:
			for ix in CELLS:
				var a := v0 + iz * SIDE + ix
				var b := a + 1
				var d := a + SIDE
				var e := d + 1
				# лицом вверх в Godot: (b − a) × (d − a) = x × z смотрит вниз
				m.tris[t] = a
				m.tris[t + 1] = b
				m.tris[t + 2] = d
				m.tris[t + 3] = b
				m.tris[t + 4] = e
				m.tris[t + 5] = d
				t += 6
	return m


## Яркость вершины v сейчас: своя × яркость пятна.
static func brightness(m: MossMesh, patches: Array[EcoMoss.Patch], v: int) -> float:
	return m.base[v] * patches[m.patch[v]].glow()
