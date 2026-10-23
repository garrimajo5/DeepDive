extends TestCase
## Разные шейдеры сцены (issue #159): на каждый новый шейдер Compatibility при первом показе собирает ~5 программ,
## это секунды прогрева на телефоне. Свои материалы корабля делят шейдеры по образцам ShaderKey.glass / flakes.

## Сколько разных шейдеров у корабля (без живого мира) — потолок. Вырос — проверить, нельзя ли взять образец.
const SHIP_BUDGET := 35   # +1: дуги разряда у окна и дна ART-068 `shaders/zap_cards.gdshader` (additive, кадр атласа и сдвиг дуги по времени, вид карточки в цвете вершин; образцы glass/flakes освещаются и не аддитивны; узел виден только в разряде — прогрев показывает его на кадр); +1: след винтов ART-063 `shaders/wake.gdshader` (билборды MultiMesh с ячейкой атласа в данных экземпляра; образец flakes — частицы CPUParticles; узел держит прозрачную карточку и прогревается под шторкой); +1: дальняя вода `shaders/far_water.gdshader` (#456: сфера цвета тумана у горизонта вместо фона; в кадре с первого кадра — прогревается сама); +1: стекло окон ART-057 `shaders/window_glass.gdshader` (маска и нормали, освещается плафонами; прежде делило образец glass с брызгами; в кадре с первого кадра); +1: взвесь ART-058 `shaders/marine_snow.gdshader` (атлас 4×4, кадр/размер/движение по семьям в вершинах, освещается; прежде делила образец flakes с илом; в кадре с первого кадра); +1: лёд снизу ART-056 `shaders/ice.gdshader` (карты, шум трещин; прежний StandardMaterial льда делил ключ с другими, этот — свой; лёд в кадре с первого кадра); +1: лучи сквозь лёд ART-052 `shaders/light_shafts.gdshader` (аддитив с маской и глубиной кадра, один MultiMesh, в кадре с первого кадра); +1: процедурный шейдер дна `shaders/seabed.gdshader` (образцом glass/flakes не заменить; дно видно с кадра 1 — прогревается само); +1: материалы мостика ART-054 `shaders/ship_surface.gdshader` (карты и выбор по нормали; мостик в кадре с первого кадра; отсеки ART-055 возьмут его же)


func test_same_flags_same_key() -> void:
	eq(ShaderKey.of(ShaderKey.glass(Color.RED)), ShaderKey.of(ShaderKey.glass(Color(0, 1, 0, 0.1))), "цвет не меняет шейдер")
	ok(ShaderKey.of(ShaderKey.glass(Color.RED)) != ShaderKey.of(ShaderKey.flakes(Color.RED)), "билборд — другой шейдер")
	var m := ShaderKey.glass(Color.RED)
	m.cull_mode = BaseMaterial3D.CULL_BACK
	ok(ShaderKey.of(m) != ShaderKey.of(ShaderKey.glass(Color.RED)), "отсечение граней — другой шейдер")
	eq(ShaderKey.of(null), "", "нет материала")
	var tagged := ShaderKey.glass(Color.RED)
	tagged.set_meta("_gltf_primary_texture_coord", 0)
	eq(ShaderKey.of(tagged), ShaderKey.of(ShaderKey.glass(Color.RED)), "метаданные шейдер не меняют")


func _find(keys: Dictionary, who: String) -> String:
	for k in keys:
		if who in keys[k]:
			return k
	return ""


func test_scene_ship_shares_shaders() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.open_silt()
	main.open_breach(0)
	main.step(0.1)
	var keys := ShaderKey.collect(main, main.eco)
	var snow := _find(keys, "Морской снег")
	ok(snow != "", "морской снег найден")
	ok(_find(keys, "Ил") != "", "ил найден")   # взвесь ART-058 — свой шейдер; ил по образцу flakes
	var glass := _find(keys, "Струя")
	ok(glass != "", "брызги пробоины найдены")
	eq(_find(keys, "Подложка итога"), glass, "подложка итога и брызги — один шейдер (образец glass)")
	eq(_find(keys, "Экран сканера"), _find(keys, "Заголовок итога"), "подписи сканера и итога — один материал")
	eq(_find(keys, "Место 1"), _find(keys, "Иконка 1"), "номера мест и их иконки — один материал")
	ok(keys.size() <= SHIP_BUDGET, "шейдеров корабля %d ≤ %d" % [keys.size(), SHIP_BUDGET])
	print("  шейдеров корабля: %d" % keys.size())
	main.queue_free()
	await frames(1)
