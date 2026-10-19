extends TestCase
## Палуба мостика: где стоять, посты, ходьба и обзор.


func test_walls_and_table_block() -> void:
	ok(Deck.can_stand(0, -3), "середина мостика")
	ok(not Deck.can_stand(4.9, 0), "у правого борта не пройти")
	ok(not Deck.can_stand(0, -5.9), "у носовой стены не пройти")
	ok(not Deck.can_stand(0, -1.2), "сквозь голостол не пройти")
	ok(not Deck.can_stand(0, -3.95), "сквозь кресло не пройти")
	ok(not Deck.can_stand(0.5, -5.3), "в пульт не войти")
	ok(Deck.can_stand(2.5, -5.4), "у окна сбоку от пульта можно стоять")


func test_walk_forward_to_nose() -> void:
	var w := Deck.Walker.new()
	w.x = 3.0
	for i in 600:
		w.walk(Vector2(0, 1), 1.0 / 60.0)
	near(w.x, 3.0, 1e-6, "по прямой")
	near(w.z, -6.0 + Deck.Walker.RADIUS, 0.05, "упёрлись в носовую стену")


func test_slides_along_wall() -> void:
	var w := Deck.Walker.new()
	w.x = 4.5
	w.z = -3.0
	for i in 60:
		w.walk(Vector2(1, 1), 1.0 / 60.0)
	ok(w.z < -3.5, "скользит вдоль борта к носу")
	ok(w.x <= 5.0 - Deck.Walker.RADIUS, "в борт не вошёл")


func test_swipe_right_turns_right() -> void:
	var w := Deck.Walker.new()
	w.look(Vector2(100, 0))
	ok(w.yaw < 0.0, "yaw уменьшился")
	ok(w.forward().x > 0.0, "смотрим правее (+X)")
	w.look(Vector2(0, -100))
	ok(w.pitch > 0.0, "палец вверх — взгляд вверх")
	w.look(Vector2(0, -100000))
	near(w.pitch, Deck.Walker.MAX_PITCH, 1e-6, "взгляд ограничен")


func test_helm_post_near_chair() -> void:
	var posts := Deck.posts()
	var p := Deck.nearest(posts, 0, Deck.STAND_Z)
	ok(p != null and p.id == "helm", "у кресла — штурвал")
	ok(Deck.nearest(posts, 0, -0.2) == null, "посреди мостика поста нет")
	ok(Deck.can_stand(p.at.x, p.at.y + p.r * 0.8), "к посту можно подойти")
	eq(p.label, "Сесть за штурвал", "подпись")


func test_sit_and_stand_behind_chair() -> void:
	var w := Deck.Walker.new()
	var pilot := Deck.Pilot.new()
	w.x = 1.0
	w.yaw = 2.0
	pilot.sit(w)
	ok(pilot.seated, "сели")
	eq(pilot.eye(w), Vector3(0, Deck.SEAT_EYE, Deck.SEAT_Z), "глаз над креслом")
	near(w.yaw, 0.0, 1e-9, "лицом к носу")
	pilot.stand(w)
	ok(not pilot.seated, "встали")
	ok(w.z > BridgeProps.CHAIR_Z + 0.5, "за креслом (ближе к корме)")
	near(w.x, 0.0, 1e-9, "по оси мостика")
	near(w.yaw, 0.0, 1e-9, "лицом к носу")
