extends TestCase
## Рамки видимости неподвижных видов (issue #849): у пузырчатки, подушечника, хватней, ленточника, камней логов
## стеклоуста и глазунов рамка — вокруг их мест, а не на всю отмель, чтобы Godot отсекал вид за спиной и вдали.
## Все видимые экземпляры остаются внутри рамки — вид не пропадает, пока на него смотрят.

## Вид → его неподвижные слои.
const FIXED := {
	"Пузырчатка": ["Стебли", "Луковицы", "Споры"],
	"Подушечник": ["Подушки", "Чернила"],
	"Хватни": ["Тела", "Щупальца", "Пестрянки"],
	"Ленточник": ["Ленты"],
	"Стеклоусты": ["Камни логов"],
	"Монетники": ["Глазуны"],
}
## Слои, которые видны только после события (куст лопнул, подушку сжали): тест вызывает событие сам.
const BURST: Array[String] = ["Споры", "Чернила"]


func test_frame_around_points() -> void:
	var box := EcoMM.frame(PackedVector3Array([Vector3(1, 0, 2), Vector3(-3, 4, 5)]), 1.0)
	near(box.position.x, -4.0, 1e-5, "левый край с запасом")
	near(box.end.y, 5.0, 1e-5, "верх с запасом")
	near(box.end.z, 6.0, 1e-5, "дальний край с запасом")
	eq(EcoMM.frame(PackedVector3Array(), 3.0), AABB(), "мест нет — нулевая рамка")


func test_fixed_species_get_own_frame() -> void:
	var view := EcoView.new()
	view.ground = Seabed.height
	tree.root.add_child(view)
	await frames(1)
	var ship := EcoLink.ShipState.new()
	var shelf := EcoMM.SHOAL_AABB.get_volume()
	var checked := 0
	# Корабль проходит тот же путь, что и раньше за 300 шагов, — прыжками по 2,5 м (рамки от его места не зависят).
	for i in 60:
		ship.pos = Vector3(sin(i * 0.1) * 60.0, -30.0, -i * 2.5)
		view.step(0.1, ship)
	# Подвижные слои — тоже в рамке: споры лопнувших кустов, чернила сжатых подушек (раньше споры ждали проход
	# корабля у куста, чернила не появлялись вовсе).
	for bl in view.bladders.bushes:
		view.bladders.pop(view.world, bl, false)
	for cu in view.cushions.cushions:
		view.cushions.squeeze(view.world, cu, false)
	for i in 10:   # мир за кадр — один подшаг (EcoView.world_dt): облака успевают разойтись
		view.step(0.1, ship)
	for sp: String in FIXED:
		var holder := view.find_child(sp, true, false)
		ok(holder != null, "вид %s в мире" % sp)
		if holder == null:
			continue
		for layer: String in FIXED[sp]:
			var mi := holder.get_node_or_null(layer) as MultiMeshInstance3D
			ok(mi != null, "%s: слой %s" % [sp, layer])
			if mi == null or mi.multimesh.instance_count == 0:
				continue
			var box := mi.custom_aabb
			ok(box.size != Vector3.ZERO, "%s/%s: рамка задана" % [sp, layer])
			ok(box.get_volume() < shelf * 0.5, "%s/%s: рамка меньше отмели" % [sp, layer])
			var mm := mi.multimesh
			var stride := 12 + (4 if mm.use_colors else 0) + (4 if mm.use_custom_data else 0)
			var buf := mm.buffer
			ok(buf.size() == mm.instance_count * stride, "%s/%s: буфер записан" % [sp, layer])
			var outside := 0
			var shown := 0
			for k in buf.size() / stride:
				var i := k * stride
				var sc := Vector3(buf[i], buf[i + 4], buf[i + 8]).length()
				if sc < 1e-4:
					continue  # спрятанный экземпляр (масштаб 0)
				shown += 1
				if not box.has_point(Vector3(buf[i + 3], buf[i + 7], buf[i + 11])):
					outside += 1
			eq(outside, 0, "%s/%s: все видимые экземпляры в рамке" % [sp, layer])
			if layer in BURST:
				ok(shown > 0, "%s/%s: облако видно — проверка не пустая" % [sp, layer])
			checked += 1
	ok(checked >= 10, "проверено слоёв (%d)" % checked)
	view.queue_free()
	await frames(1)
