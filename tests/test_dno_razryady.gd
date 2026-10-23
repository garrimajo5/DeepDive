extends TestCase
## Следы разрядов у дна по ART-066 (`Seabed.Scorch`, ячейки атласа 13–15): только после настоящего разряда у дна,
## в точке под кораблём, сила 0…1 на событие, держатся последние MAX, свежий темнеет в «старое пятно».

const S := Seabed.Scorch


func test_strength_by_gap() -> void:
	near(S.strength(0.0, 1.0), 1.0, 1e-6, "корабль на дне — полный след")
	near(S.strength(S.REACH.x, 1.0), 1.0, 1e-6, "до 2 м зазора — полный")
	eq(S.strength(S.REACH.y, 1.0), 0.0, "к 10 м — нет следа")
	eq(S.strength(30.0, 1.0), 0.0, "в толще воды — нет")
	var mid := S.strength(6.0, 1.0)
	ok(mid > 0.3 and mid < 0.7, "посередине — половина: %.2f" % mid)
	near(S.strength(0.0, 0.5), 0.5, 1e-6, "половина доли «Разряд» — половина силы")
	near(S.strength(0.0, 1.5), 1.0, 1e-6, "усиленный разряд не сильнее 1")
	eq(S.strength(0.0, 0.05), 0.0, "совсем слабый — следа нет")


func test_add_under_ship_only_near_floor() -> void:
	var s := S.new()
	var floor_y := -40.0
	ok(not s.add(Vector3(5.0, floor_y + Helm.Ship.CLEARANCE + 20.0, 7.0), floor_y, 1.0, 0.0), "высоко — следа нет")
	eq(s.all.size(), 0)
	ok(s.add(Vector3(5.0, floor_y + Helm.Ship.CLEARANCE, 7.0), floor_y, 1.0, 1.0), "у дна — след")
	eq(s.all.size(), 1)
	var m: Dictionary = s.all[0]
	eq(m.at, Vector2(5.0, 7.0), "под кораблём")
	near(m.k, 1.0, 1e-6)
	near(m.size, S.SIZE.y, 1e-6, "полный — самый крупный")
	ok(S.FRESH.has(m.index), "свежий — разряд А или Б")
	var hits := s.at_point(5.0, 7.0, 1.0)
	eq(hits.size(), 1, "точка под кораблём накрыта")
	ok(hits[0].st.is_equal_approx(Vector2(0.5, 0.5)), "центр штампа")
	eq(s.at_point(5.0 + S.SIZE.y, 7.0, 1.0).size(), 0, "дальше квадрата — пусто")


func test_ring_keeps_last() -> void:
	var s := S.new()
	for i in S.MAX + 2:
		s.add(Vector3(i * 10.0, -37.0, 0.0), -40.0, 1.0, float(i))
	eq(s.all.size(), S.MAX, "держит последние %d" % S.MAX)
	eq(s.all[0].at, Vector2(20.0, 0.0), "первые два ушли")
	eq(s.all[S.MAX - 1].at, Vector2((S.MAX + 1) * 10.0, 0.0), "последний — новый")
	ok(s.all[0].index != s.all[1].index, "А и Б по очереди")
	ok(s.all[0].rot != s.all[1].rot, "повёрнуты по-разному")
	s.clear()
	eq(s.all.size(), 0, "новый забег — чистое дно")
	eq(s.count, 0)


func test_ages_into_old_spot() -> void:
	var s := S.new()
	s.add(Vector3(0.0, -37.0, 0.0), -40.0, 1.0, 10.0)
	var u: Array = s.uniforms(10.0)
	eq(u[0].size(), S.MAX, "массив — на MAX")
	eq(u[1].size(), S.MAX)
	near(u[1][0].x, 1.0, 1e-6, "свежий — полная сила")
	near(u[1][0].z, 0.0, 1e-6, "свежий")
	ok(S.FRESH.has(int(u[1][0].y)), "ячейка 13/14")
	eq(u[1][1], Vector4.ZERO, "пустые места — сила 0")
	var late: Array = s.uniforms(10.0 + S.OLD.y)
	near(late[1][0].z, 1.0, 1e-6, "через 120 с — старое пятно")
	near(late[1][0].x, S.OLD_K, 1e-6, "старое бледнее")
	eq(s.all.size(), 1, "но держится")
	var mid: Array = s.uniforms(10.0 + (S.OLD.x + S.OLD.y) * 0.5)
	ok(mid[1][0].z > 0.2 and mid[1][0].z < 0.8, "темнеет плавно")


## Атлас: ячейки 13–15 непустые — штамп виден.
func test_atlas_cells() -> void:
	var img: Image = (load(Seabed.Marks.ATLAS) as Texture2D).get_image()
	img.decompress()
	for cell in S.FRESH + [S.STALE]:
		var uv := Seabed.Marks.atlas_uv(cell, Vector2(0.5, 0.5))
		var a := img.get_pixel(int(uv.x * 1024.0), int(uv.y * 1024.0)).a
		ok(a > 0.5, "ячейка %d в середине непрозрачна: %.2f" % [cell, a])
	ok(S.SIZE.y < Seabed.Marks.CELL * 2.0, "след не огромный")


func test_shader_mirrors_core() -> void:
	var src := FileAccess.get_file_as_string("res://shaders/seabed.gdshader")
	ok(src.contains("uniform vec4 scorch_at[%d]" % S.MAX), "массив на MAX")
	ok(src.contains("uniform vec4 scorch_k[%d]" % S.MAX))
	ok(src.contains("for (int i = 0; i < %d; i++)" % S.MAX), "все следы")
	ok(src.contains("(vec2(3.0, 3.0) + st) / 4.0"), "старое пятно — ячейка 15")
	eq(S.STALE, 15)


## Разряд у дна в игре кладёт след в материал дна; высоко — нет; новый забег стирает.
func test_scene_zap_marks_floor() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	main.helm.pos.y = 0.0
	main.fire_zap()
	eq(main.scorch.all.size(), 0, "высоко над дном — следа нет")
	var floor_y := Seabed.height(main.helm.pos.x, main.helm.pos.z)
	main.helm.pos.y = floor_y + Helm.Ship.CLEARANCE
	main.step(Zap.COOLDOWN + 0.1)
	main.fire_zap()
	eq(main.scorch.all.size(), 1, "у дна — след")
	var k: PackedVector4Array = main.ocean.seabed_mat.get_shader_parameter("scorch_k")
	ok(k.size() == S.MAX and k[0].x > 0.9, "в материале дна")
	var at: PackedVector4Array = main.ocean.seabed_mat.get_shader_parameter("scorch_at")
	near(at[0].x, main.helm.pos.x, 0.5, "под кораблём")
	for i in 25:
		main.step(5.0)
	k = main.ocean.seabed_mat.get_shader_parameter("scorch_k")
	near(k[0].z, 1.0, 1e-3, "за 125 с стал старым пятном")
	main._restart()
	eq(main.scorch.all.size(), 0, "новый забег — чистое дно")
	k = main.ocean.seabed_mat.get_shader_parameter("scorch_k")
	eq(k[0].x, 0.0, "и в материале")
	main.queue_free()
	await frames(1)
