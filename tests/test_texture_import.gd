extends TestCase
## Текстуры моделей художника сжаты для видеокарты (ETC2/ASTC на телефоне), по issue #843, эпик #852.
## Без сжатия (`compress/mode=0`, «Lossless») 1024² занимает ≈5 МБ памяти видеокарты с мипами и ≈1,7 МБ в APK,
## сжатая — ≈0,7 МБ и там и там. Новая модель из Meshy приходит с «Lossless» — при приёмке поставить в её
## `*.png.import` `compress/mode=2` (VRAM Compressed) и переимпортировать.


func _mode(path: String) -> int:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return -1
	return int(cfg.get_value("params", "compress/mode", -1))


func test_model_textures_vram_compressed() -> void:
	var files := DirAccess.get_files_at("res://models")
	var n := 0
	for f in files:
		if not f.ends_with(".png.import"):
			continue
		n += 1
		eq(_mode("res://models/" + f), 2, "%s: VRAM Compressed (compress/mode=2)" % f)
	ok(n >= 60, "текстуры моделей найдены (%d)" % n)


## Вторая часть #843: карты грунтов дна ART-060 (на экране всегда, 9 штук 1024²) и цвет льда. Карты нормалей дна —
## режимом нормалей (`compress/normal_map=1`, на телефоне — два канала RG): шейдер дна читает только `.rg`.
## Не сжимаем то, что читается на CPU (маска трещин), декодирует нормали вручную (обшивка, мостик, отсеки)
## или служит таблицей (LUT, градиенты, атласы карточек) — им нужна точность.
func test_seabed_and_ice_textures_vram_compressed() -> void:
	for g in ["pesok", "il", "galka"]:
		for m in ["tsvet", "orm", "normali"]:
			var path := "res://textures/dno/%s-%s.png.import" % [g, m]
			eq(_mode(path), 2, "%s: VRAM Compressed" % path)
			var cfg := ConfigFile.new()
			cfg.load(path)
			eq(int(cfg.get_value("params", "compress/normal_map", -1)), 1 if m == "normali" else 0,
				"%s: режим нормалей — только у карт нормалей" % path)
	eq(_mode("res://textures/ice/tsvet.png.import"), 2, "цвет льда: VRAM Compressed")
	eq(_mode("res://textures/ice/treshchiny.png.import"), 0, "маска трещин — без потерь: её читает CPU (IceSheet.crack)")


func test_compressed_texture_loads_as_vram() -> void:
	var t: Texture2D = load("res://models/pult-pilota_pult-pilota-color.png")
	ok(t != null, "текстура грузится")
	var img := t.get_image()
	ok(img.is_compressed(), "в памяти — сжатый формат видеокарты")
	eq(t.get_size(), Vector2(1024, 1024), "размер прежний")
