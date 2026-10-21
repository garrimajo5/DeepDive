extends TestCase
## Общие шейдеры живого мира (issue #279): каждый новый шейдер — ~5 программ и доли секунды прогрева на телефоне.
## Одинаковый код — один ресурс, похожие материалы мест и видов — общий код EcoShaders с числами в uniform.

## Сколько разных шейдеров у живого мира — потолок. Вырос — проверить, нельзя ли взять общий из EcoShaders.
const ECO_BUDGET := 31


func test_same_code_same_shader() -> void:
	var a := EcoShaders.shader(EcoShaders.MOSS)
	eq(EcoShaders.shader(EcoShaders.MOSS), a, "тот же код — тот же ресурс")
	ok(EcoShaders.shader(EcoShaders.SPOT) != a, "другой код — другой шейдер")
	var m1 := EcoShaders.stone(Color.RED, 0.3, 0.9, 0.2)
	var m2 := EcoShaders.stone(Color.BLUE, 0.45, 0.95, 0.15)
	eq(m1.shader, m2.shader, "камни с разными числами — один шейдер")
	near(float(m2.get_shader_parameter("fill")), 0.45, 1e-6, "подсветка — в uniform")
	eq(float(m1.get_shader_parameter("flicker")), 0.0, "камень по умолчанию не мерцает")


func test_moss_glow_padded() -> void:
	var g := PackedFloat32Array([0.5, 1.0, 0.25])
	var out := EcoShaders.moss_glow(g)
	eq(out.size(), EcoShaders.MOSS_MAX, "массив по размеру шейдера")
	near(out[1], 1.0, 1e-6, "яркость пятна на месте")
	eq(out[EcoShaders.MOSS_MAX - 1], 0.0, "лишние — ноль")
	eq(g.size(), 3, "исходный массив не тронут")
	ok(EcoShaders.MOSS.contains("glow[%d]" % EcoShaders.MOSS_MAX), "MOSS_MAX совпадает с шейдером")


## Ключ шейдера узла по имени (в ShaderKey.collect у ключа только первые три имени).
func _find(root: Node, who: String) -> String:
	var n := root.find_child(who, true, false)
	if n == null:
		return ""
	return ShaderKey.collect(n).keys()[0] if not ShaderKey.collect(n).is_empty() else ""


func test_scene_world_shares_shaders() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.step(0.1)
	var ev: EcoView = main.eco
	ok(ev.moss_view.moss.patches.size() <= EcoShaders.MOSS_MAX, "пятен мха ≤ MOSS_MAX")
	var keys := ShaderKey.collect(ev)
	var moss := _find(ev, "Мох")
	ok(moss != "", "мох найден")
	eq(_find(ev, "Мох на костях"), moss, "мох костей и мох рифа — один шейдер")
	eq(_find(ev, "Мох колодца"), moss, "мох колодца и мох рифа — один шейдер")
	var stone := _find(ev, "Раковина древних")
	ok(stone != "", "раковина найдена")
	eq(_find(ev, "Кости левиафана"), stone, "кости и раковина — один шейдер")
	eq(_find(ev, "Край отмели"), stone, "край отмели и раковина — один шейдер")
	eq(_find(ev, "Порода"), stone, "порода курильщика и раковина — один шейдер")
	var spot := _find(ev, "Споры")
	ok(spot != "", "споры найдены")
	eq(_find(ev, "Ореолы"), spot, "ореолы гребневиков и споры — один шейдер")
	var rims := 0
	for k in keys:
		if "Кромка" in keys[k]:
			rims += 1
	eq(rims, 1, "кромки двух вуалей — один шейдер")
	var rock := ev.vent_view.rock.mesh.surface_get_material(0) as ShaderMaterial
	eq(float(rock.get_shader_parameter("flicker")), 1.0, "жерла курильщика мерцают")
	ok(keys.size() <= ECO_BUDGET, "шейдеров мира %d ≤ %d" % [keys.size(), ECO_BUDGET])
	print("  шейдеров живого мира: %d" % keys.size())
	main.queue_free()
	await frames(1)
