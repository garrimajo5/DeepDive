extends TestCase
## Вырез-увеличение у шага «shot» сценария тестера (#1757): серии «видно ли из окна» сравнивают по фрагментам,
## а не по кадру 2400×1080. Разбор, прямоугольник в пикселях, сама картинка, файл рядом со снимком, сценарий.

const SERIES := ["37b-okno-gnezdo", "41-okno-zakryta", "41a-okno-podem", "41b-okno-otkryta", "41c-okno-uhodit"]


func test_crop_is_parsed() -> void:
	eq(QaScript.crop_of({"do": "shot", "name": "a"}), [], "без выреза")
	eq(QaScript.crop_of({"crop": [0.25, 0.5, 0.5, 0.25]}), [0.25, 0.5, 0.5, 0.25, QaScript.CROP_K], "без k — увеличение вдвое")
	eq(QaScript.crop_of({"crop": [0, 0, 1, 1, 3]}), [0.0, 0.0, 1.0, 1.0, 3.0], "целые числа из JSON — тоже числа")
	for bad in [[0.5, 0.5, 0.6, 0.2], [0.5, 0.5, 0.2, 0.6], [-0.1, 0, 0.5, 0.5], [0, 0, 0.5], [0, 0, 0.5, 0.5, 2, 1],
			[0, 0, 0.001, 0.5], [0, 0, 0.5, 0.5, 0.5], [0, 0, 0.5, 0.5, 20], ["a", 0, 0.5, 0.5], "0,0,1,1", [400, 300, 400, 300]]:
		eq(QaScript.crop_of({"crop": bad}), [], "неверный вырез %s" % str(bad))


func test_step_gives_crop_to_the_scene() -> void:
	var q := QaScript.parse('[{"do":"shot","name":"a","crop":[0.25,0.5,0.5,0.25,4]},{"do":"shot","name":"b"}]')
	eq(q.errors.size(), 0, "ошибок нет")
	var all: Array = []
	for i in 4:
		all.append_array(q.advance(0.05))
	eq(all[0], ["shot", "a", [0.25, 0.5, 0.5, 0.25, 4.0]], "снимок с вырезом")
	eq(all[1], ["shot", "b"], "снимок без выреза — как раньше, два слова")


func test_bad_crop_keeps_the_shot() -> void:
	var q := QaScript.parse('[{"do":"shot","name":"a","crop":[400,300,400,300]}]')
	eq(q.errors.size(), 1, "ошибка названа")
	ok(q.errors[0].contains("crop") and q.errors[0].contains("шаг 1"), "в ошибке — шаг и ключ: %s" % q.errors[0])
	eq(q.steps.size(), 1, "снимок остался")
	eq(q.advance(0.05)[0], ["shot", "a"], "без выреза")


func test_rect_follows_screen_size() -> void:
	var c := QaScript.crop_of({"crop": [0.25, 0.5, 0.5, 0.25]})
	eq(QaScript.crop_rect(c, Vector2i(2400, 1080)), Rect2i(600, 540, 1200, 270), "телефон 2400×1080")
	eq(QaScript.crop_rect(c, Vector2i(1600, 720)), Rect2i(400, 360, 800, 180), "облако 1600×720")
	eq(QaScript.crop_size(c, Vector2i(1600, 720)), Vector2i(1600, 360), "вдвое")
	var edge := QaScript.crop_of({"crop": [0.9, 0.9, 0.1, 0.1, 8]})
	var r := QaScript.crop_rect(edge, Vector2i(1601, 721))
	ok(r.end.x <= 1601 and r.end.y <= 721 and r.size.x > 0 and r.size.y > 0, "у края кадра — в границах: %s" % str(r))
	eq(QaScript.crop_rect(QaScript.crop_of({"crop": [0, 0, 1, 1]}), Vector2i(7, 5)), Rect2i(0, 0, 7, 5), "весь кадр")


func _quarters() -> Image:   # четыре цветные четверти 200×100
	var img := Image.create(200, 100, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(0, 0, 100, 50), Color.RED)
	img.fill_rect(Rect2i(100, 0, 100, 50), Color.GREEN)
	img.fill_rect(Rect2i(0, 50, 100, 50), Color.BLUE)
	img.fill_rect(Rect2i(100, 50, 100, 50), Color.WHITE)
	return img


func test_image_is_the_asked_part_enlarged() -> void:
	var img := _quarters()
	var part := QaScript.crop_image(img, QaScript.crop_of({"crop": [0.5, 0.0, 0.5, 0.5, 3]}))
	eq(Vector2i(part.get_width(), part.get_height()), Vector2i(300, 150), "100×50 втрое")
	for at in [Vector2i(5, 5), Vector2i(150, 75), Vector2i(294, 144)]:
		ok(part.get_pixelv(at).is_equal_approx(Color.GREEN), "правая верхняя четверть целиком: %s" % str(at))
	var mid := QaScript.crop_image(img, QaScript.crop_of({"crop": [0.25, 0.25, 0.5, 0.5]}))
	eq(Vector2i(mid.get_width(), mid.get_height()), Vector2i(200, 100), "середина вдвое")
	ok(mid.get_pixel(20, 20).is_equal_approx(Color.RED) and mid.get_pixel(180, 20).is_equal_approx(Color.GREEN)
		and mid.get_pixel(20, 80).is_equal_approx(Color.BLUE) and mid.get_pixel(180, 80).is_equal_approx(Color.WHITE),
		"в середине — все четыре четверти на своих местах")
	eq(Vector2i(img.get_width(), img.get_height()), Vector2i(200, 100), "снимок не тронут")


func test_runner_writes_crop_beside_the_shot() -> void:
	var dir := "user://qa-crop-test"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := "%s/x%s.png" % [dir, QaScript.CROP_TAIL]
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var qa := QaRunner.new()
	var crop := QaScript.crop_of({"crop": [0.0, 0.5, 0.5, 0.5, 2]})
	qa.save_crop(_quarters(), "x", crop, dir)
	ok(FileAccess.file_exists(path), "файл x-krupno.png рядом со снимком")
	var got := Image.load_from_file(path)
	eq(Vector2i(got.get_width(), got.get_height()), Vector2i(200, 100), "размер выреза")
	ok(got.get_pixel(100, 50).is_equal_approx(Color.BLUE), "левая нижняя четверть")
	eq(qa.log_lines[-1], "вырез x-krupno.png: 100×50 пикс. от (0, 50), ×2 → 200×100", "строка лога называет файл и место")
	ok(not qa.log_lines[-1].begins_with("скриншот "), "не строка «скриншот»: run-qa.ps1 считает снимки по ним")
	qa.free()
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(dir)


## Готово, когда у серии из носового окна (#1757) есть вырез — один на все кадры: сравнивают фрагменты между собой.
func test_window_series_has_one_crop() -> void:
	var q := QaScript.parse(FileAccess.get_file_as_string("res://tools/qa/scenario.json"))
	var crops := {}
	for st: Dictionary in q.steps:
		if st["do"] == "shot" and st.has("crop"):
			ok(not QaScript.crop_of(st).is_empty(), "вырез у %s записан верно" % st["name"])
			crops[st["name"]] = QaScript.crop_of(st)
	for name: String in SERIES:
		ok(crops.has(name), "у кадра %s есть вырез" % name)
		if crops.has(name):
			eq(crops[name], crops[SERIES[0]], "вырез %s тот же, что у %s" % [name, SERIES[0]])
	var r := QaScript.crop_rect(crops.get(SERIES[0], [0, 0, 1, 1, 1]), Vector2i(2400, 1080))
	ok(r.size.x <= 600 and r.size.y <= 400, "вырез — фрагмент окна, а не пол-экрана: %s" % str(r))


## Вырезы в счёт «снимков N из M» не идут: считаем снимки шагов, а не все *.png папки прогона.
func test_run_qa_counts_only_step_shots() -> void:
	var ps := FileAccess.get_file_as_bytes("res://tools/qa/run-qa.ps1").slice(3).get_string_from_utf8()
	ok(ps.contains("снимков $(@($want | Where-Object { $_ -in $have }).Count) из $($want.Count)"), "счёт — по именам из лога")
	ok(not ps.contains("снимков $($have.Count)"), "не по числу файлов")
