extends SceneTree
## Кадр Google Play ART-046 из готового снимка (скриншот с телефона, `qa/out/kadr-n-snimok.png`, `shot.gd`):
## xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 -s tools/play_frame.gd -- снимок.png кадр.png <1…4>
## Снимок — в рамку 16:9 целиком с тёмными полями, сверху подпись n-го шаблона (`PlayFrame.CAPTIONS`). Подпись нужна
## отрисовка: в --headless кадр выйдет без неё (предупреждение в выводе).


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		printerr("нужно: снимок.png кадр.png <1…4>")
		quit(1)
		return
	var shot := Image.load_from_file(args[0])
	var n := int(args[2])
	if shot == null or shot.is_empty() or PlayFrame.caption(n).is_empty():
		printerr("нет снимка %s или номер кадра не 1…4" % args[0])
		quit(1)
		return
	var cap: Image = await PlayCaption.render(root, PlayFrame.caption(n))
	if cap == null:
		print("без подписи: нет отрисовки (headless) — запустите под xvfb-run без --headless")
	PlayFrame.compose(shot, cap).save_png(args[1])
	print("KADR ", args[1], " «", PlayFrame.caption(n), "» снимок ", shot.get_size(), " → ", PlayFrame.fit(shot.get_size()))
	quit(0)
