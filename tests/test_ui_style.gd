extends TestCase
## Общая плашка экранных панелей (UiStyle): те же скругления, рамки и цвета, что панели собирали сами.


func test_box_border_only_with_width() -> void:
	var plain := UiStyle.box(Color.BLACK, 12.4)
	eq(plain.get_corner_radius(CORNER_TOP_LEFT), 12, "скругление округлено")
	eq(plain.get_border_width(SIDE_LEFT), 0, "без толщины — без рамки (заливка до края)")
	var framed := UiStyle.box(Color.BLACK, 12.0, Color.RED, 0.3)
	eq(framed.get_border_width(SIDE_TOP), 1, "рамка не тоньше пикселя")
	eq(framed.border_color, Color.RED, "цвет рамки")
	eq(UiStyle.box(Color.BLACK, 8.0, Color.RED, 2.6).get_border_width(SIDE_BOTTOM), 3, "толщина округлена")


func test_menu_button() -> void:
	var main := UiStyle.menu_button(true, 2.0)
	eq(main.bg_color, MainMenu.MAIN, "главная — голубая")
	eq(main.get_border_width(SIDE_LEFT), 0, "без рамки")
	eq(main.get_corner_radius(CORNER_BOTTOM_RIGHT), roundi(MainMenu.RADIUS * 2.0), "скругление по раскладке")
	var off := UiStyle.menu_button(false, 1.0, 0.6, 0.6, 0.5)
	eq(off.bg_color, Color(MainMenu.PANEL, 0.3), "погашенная панель, затухание экрана")
	eq(off.border_color, Color(MainMenu.EDGE, 0.3), "рамка тоже")
	eq(off.get_border_width(SIDE_TOP), 2, "рамка 2 px при s = 1")
	eq(UiStyle.dialog(1.0).bg_color, Color(MainMenu.PANEL, 0.97), "окно подтверждения почти непрозрачно")


func test_palette_shared() -> void:
	eq(CommsPanel.TEXT, UiStyle.TEXT, "связь — общий цвет текста")
	eq(RadioPanel.ACCENT, UiStyle.ACCENT, "рация — общий акцент")


func _full(c: Control) -> bool:
	return c.anchor_left == 0.0 and c.anchor_top == 0.0 and c.anchor_right == 1.0 and c.anchor_bottom == 1.0 \
			and c.mouse_filter == Control.MOUSE_FILTER_IGNORE


func test_screen_frame() -> void:
	# каркас полноэкранной панели (#761): подложка → фон заставки → затемнение → холст
	var layer := CanvasLayer.new()
	var c := UiStyle.screen(layer, "Холст", func() -> void: pass, MainMenu.DARK, Color(MainMenu.DARK, 0.6))
	eq(layer.get_child_count(), 4, "подложка, фон, затемнение, холст")
	var kids := layer.get_children()
	ok(kids[0] is ColorRect and (kids[0] as ColorRect).color == MainMenu.DARK, "сначала тёмная подложка")
	ok(kids[1] is TextureRect and (kids[1] as TextureRect).texture != null, "фон заставки")
	eq((kids[1] as TextureRect).stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED, "обрезан по сторонам")
	eq((kids[2] as ColorRect).color, Color(MainMenu.DARK, 0.6), "затемнение")
	ok(kids[3] == c and c.name == "Холст", "холст последним")
	for k in kids:
		ok(_full(k), "%s: на весь экран, мимо касаний" % k.name)
	eq(c.draw.get_connections().size(), 1, "холст рисует своё")
	var plain := CanvasLayer.new()
	UiStyle.screen(plain, "Кнопки", func() -> void: pass, MainMenu.DARK)
	eq(plain.get_child_count(), 3, "без затемнения — три слоя")
	layer.free()
	plain.free()


func test_panels_on_frame() -> void:
	var menu := MenuPanel.new()
	eq(menu.get_child_count(), 3, "меню: подложка, фон, кнопки")
	ok(menu.draw == menu.get_child(2), "холст меню")
	var adr := AddressPanel.new()
	eq(adr.get_child_count(), 4, "адрес: с затемнением")
	eq((adr.get_child(2) as ColorRect).color, Color(MainMenu.DARK, AddressScreen.DIM), "затемнение адреса")
	var jr := JournalPanel.new()
	eq((jr.get_child(2) as ColorRect).color, Color(Journal.DARK, JournalPanel.DIM), "затемнение журнала")
	var lb := LobbyPanel.new()
	eq(lb.get_child_count(), 2, "сбор: затемнение и строки")
	eq((lb.get_child(0) as ColorRect).color, Lobby.DIM, "затемнение сбора")
	for p in [PausePanel.new(), SettingsPanel.new(), FpsView.new(), LiteOfferPanel.new(), ShipMapPanel.new()]:
		eq(p.get_child_count(), 1, "%s: один холст" % p.name)
		ok(_full(p.draw), "%s: холст на весь экран" % p.name)
		p.free()
	for p in [menu, adr, jr, lb]:
		p.free()
