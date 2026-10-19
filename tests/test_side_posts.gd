extends TestCase
## Бортовые посты мостика: пульт энергии с ползунками, сканер биолога, люк в коридор (MOD-005…007).


func test_posts_reachable_and_apart() -> void:
	var posts := Deck.posts()
	for p in posts:
		var reach := false
		for i in 16:  # есть где встать в радиусе поста
			var a := TAU * i / 16.0
			var q := p.at + Vector2(cos(a), sin(a)) * p.r * 0.8
			if Deck.can_stand(q.x, q.y) and Deck.nearest(posts, q.x, q.y) == p:
				reach = true
		ok(reach, "к посту «%s» можно подойти" % p.label)
		eq(Deck.nearest(posts, p.at.x, p.at.y).id, p.id, "в центре поста «%s» — он сам" % p.label)


func test_side_panels_block_walk_and_fit_between_ribs() -> void:
	ok(not Deck.can_stand(-4.6, -2.0), "в пульт энергии не войти")
	ok(not Deck.can_stand(4.6, -2.0), "в сканер не войти")
	for z in BridgePlan.RIB_Z:
		ok(absf(z - BridgeProps.SIDE_Z) > 0.6 + 0.09, "ребро борта z %.2f не пересекает пульт" % z)


func test_slider_follows_tilted_face() -> void:
	near(BridgeProps.slider_z(0.75), -0.35, 1e-6, "внизу лица — 0,35 м от стены")
	ok(BridgeProps.slider_z(1.15) > BridgeProps.slider_z(0.85), "выше — ближе к стене")
	near(BridgeProps.slider_y(0.0), BridgeProps.SLIDER_Y_MIN, 1e-6, "доля 0 — внизу")
	near(BridgeProps.slider_y(1.0), BridgeProps.SLIDER_Y_MAX, 1e-6, "доля 1 — вверху")


func test_scene_side_models_and_posts() -> void:
	var main: Main = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await frames(1)
	var b := main.bridge
	for name in [BridgeProps.ENERGY, BridgeProps.SCANNER, BridgeProps.HATCH_FRAME]:
		ok(b.props.has(name), "модель %s на мостике" % name)
	eq(b.sliders.size(), 5, "пять ползунков")
	var panel: Node3D = b.props[BridgeProps.ENERGY]
	var face := -panel.global_transform.basis.z
	ok(face.x > 0.99, "пульт энергии смотрит в отсек (+X): %s" % str(face))
	b.set_slider(0, 1.0)
	ok(b.sliders[0].position.y > b.sliders[1].position.y, "ползунок двигается")
	ok(b.hatch_wheel.get_parent() == b.hatch_door, "колесо на створке люка")
	main.walker.x = -3.9
	main.walker.z = -2.0
	var r := main.overlay.router
	r.begin(1, r.layout.action.c)
	r.end(1)
	main.step(0.1)
	ok(main.message.text.begins_with("Энергия"), "у пульта — про энергию: %s" % main.message.text)
	main.walker.x = 0.0
	main.walker.z = 1.4
	r.begin(2, r.layout.action.c)
	r.end(2)
	main.step(0.1)
	eq(main.message.text, "Люк в коридор задраен", "люк пока задраен")
