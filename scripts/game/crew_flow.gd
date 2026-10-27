class_name CrewFlow
extends RefCounted
## Экипаж на постах (#757): нажатия над табличками, товарищи у постов удержания и за постами управления, их кнопка
## действия и ход, руки своего игрока и товарищей на постах (`CrewHands`), место на палубе и новый товарищ.
## Товарищ — гость сети или член экипажа сценария тестера; его ввод — `Crew.Member.pad`.
## Живёт полем `main.crew_flow`; `Main.add_mate` — пересылка для тестов, `tools/` и `QaRunner`.

## Посты, у которых товарищ держит кнопку действия (`Pad.hold`).
const HOLDS := ["breach", "valve", "winch", "scanner"]

var main: Main


func _init(m: Main) -> void:
	main = m


## Кто нажал кнопку в этом кадре (действие или «Свет»; свой — с экрана, товарищ — `Pad`): табличка над ним
## «нажимает» (ART-033, `Member.pressed`). До того, как шаг съест нажатия.
func mark_presses(r: Touch.Router, dt: float) -> void:
	for m: Crew.Member in main.crew:
		m.tick_press(dt)
		if (r.action_pressed or r.light_pressed) if m == main.me else (m.pad.action or m.pad.light):
			m.pressed()


## Посты, у которых товарищ держит кнопку действия (`Pad.hold`): сварка пробоины, вентиль, лебёдка, сканер —
## {пост: товарищ}. Занятый постом (штурвал, пульт, голосование) не держит. Товарищ у сканера — мир шлёт цели
## (`main.at_scanner`), как своему игроку.
func holds() -> Dictionary:
	var out := {}
	for m: Crew.Member in main.crew:
		if m == main.me or m.busy():
			continue
		var post := Deck.nearest(main.posts, m.walker.x, m.walker.z)
		if post == null or post.id not in HOLDS:
			continue
		if post.id == "scanner":
			main.at_scanner = true
		if m.pad.hold and not out.has(post.id):
			out[post.id] = m
	return out


## Товарищ на посту правит кораблём своим вводом (`Member.pad`, гость по сети — тоже): за штурвалом — ход, руль,
## «Всплыть/Вниз» и «Свет», у пульта энергии — доли реактора. Пост держит один человек (Crew.BUSY): свой ввод
## тогда штурвал не трогает.
func posts(dt: float) -> void:
	var g := main
	for m: Crew.Member in g.crew:
		if m == g.me:
			continue
		var mv := Vector2i(roundi(m.pad.move.x), roundi(m.pad.move.y))   # крестовина 8 направлений, как у своего
		if m.seated and not g.pilot.seated:
			g.helm.in_thrust = mv.y
			g.helm.in_turn = mv.x
			g.helm.in_vert = m.pad.vert
			m.wheel_turn = g.helm.turn
			if m.pad.light:
				g.toggle_light()
		elif m.at_power and not g.at_power:
			g.power.nav(g.reactor, mv, dt)
		m.pad.light = false


## Товарищи идут своим вводом: кнопка действия (`mate_action`), голос у стола крестовиной, шаг по палубе
## (в затопленном отсеке медленнее).
func drive(dt: float) -> void:
	var g := main
	for m: Crew.Member in g.crew:
		if m != g.me:
			if m.pad.action:
				m.pad.action = false
				mate_action(m)
			if m.at_vote and g.run.done and not g.run.ended:   # голос своей крестовиной
				var c := g.ballot.nav(m.get_instance_id(), m.pad.move, true)
				if c != "":
					g.ballot.cast(m.get_instance_id(), m.role, c)
			m.drive(dt, g.breach.slow(ShipLayout.room_at(m.walker.z)))


## Руки на посте удержания (вентиль, лебёдка, сканер) — одна поза для своего игрока и товарища; "" — нет.
static func grip(m: Crew.Member, post: String) -> Array:
	match post:
		"valve":
			return CrewHands.valve()
		"winch":
			return CrewHands.winch(m.walker.x, m.walker.z)
		"scanner":
			return CrewHands.scanner()
	return CrewHands.none()


## Руки экипажа на постах (CrewHands). Свой игрок: у пульта энергии, пока держит вентиль, лебёдку или сканер;
## после нажатия у голостола, рычага и щитка — ещё CrewHands.PRESS секунд. Товарищи, которые держат пост
## (`holds`): резак у шва и щиток, руки на вентиле, лебёдке, сканере.
func hands(dt: float, valve: bool, winch: bool, scan: bool, held: Dictionary) -> void:
	var g := main
	g.press_t = maxf(g.press_t - dt, 0.0)
	if not CrewHands.pressing(g.press_t, g.press_at, Vector2(g.walker.x, g.walker.z)):
		g.press_t = 0.0   # отошёл от поста — руки не тянутся к нему через мостик, фигура не кланяется (#349)
	var own := CrewHands.none()
	if g.pilot.seated:
		pass
	elif g.at_power:
		own = CrewHands.energy(g.power.sel, g.reactor.share[g.power.sel] / float(Reactor.MAX))
	elif valve or winch or scan:
		own = grip(g.me, "valve" if valve else "winch" if winch else "scanner")
	elif g.press_t > 0.0:
		match g.press_post:
			"sonar", "route":
				own = CrewHands.table(g.walker.x, g.walker.z)
			"zap":
				own = CrewHands.lever(g.zap.lever_deg(g.time))
			"scram":
				own = CrewHands.scram()
	g.me.hold(own[0], own[1])
	for m: Crew.Member in g.crew:
		if m == g.me:
			continue
		if held.get("breach") == m and g.breach.active:
			m.weld(g.breach.active.p, g.breach.active.n)
		else:
			m.weld(Vector3.INF)
		var post := ""
		for id: String in ["valve", "winch", "scanner"]:
			if held.get(id) == m:
				post = id
				break
		var h := grip(m, post)
		m.hold(h[0], h[1])


## Кнопка действия товарища (`Pad.action`): занятый постом встаёт; стоящий у штурвала садится, у пульта энергии
## встаёт к ползункам, у голостола после маршрута — к голосованию. Пост, который держит другой, не берёт.
## Возвращает пост, за который встал или сел ("" — встал с поста или рядом нечего взять).
func mate_action(m: Crew.Member) -> String:
	var g := main
	if m.busy():
		if m.seated:
			m.stand()
		m.at_power = false
		m.at_vote = false
		m.sync_post()
		return ""
	var post := Deck.nearest(g.posts, m.walker.x, m.walker.z)
	if post == null or Crew.holder(g.crew, m, post.id):
		return ""
	m.pad.move = Vector2.ZERO   # крестовина, которой шёл к посту, не ведёт корабль (гость пришлёт новую)
	m.pad.left = INF
	match post.id:
		"helm":
			m.sit()
		"energy":
			m.at_power = true
			m.walker.x = Main.POWER_STAND.x
			m.walker.z = Main.POWER_STAND.y
			m.walker.yaw = PI / 2.0
			m.place(m.walker.x, m.walker.z, m.walker.yaw)
		"route":
			if not g.run.done:   # маршрут не пройден: кнопка у поста «Маршрут» листает маршруты — у всех
				g.announce(g.run.cycle())
				return ""
			m.at_vote = true
		"sonar":   # импульс хоста — голограмма и отметки у всех (у гостя — по кадру, NetSnap.sonar)
			g.ping_sonar(true)
			return ""
		_:
			return ""
	m.sync_post()
	return post.id


## Куда может шагнуть член экипажа m: пол корабля (ShipLayout.can_stand) и не в другую фигуру (Crew.room_for, #602).
## m держим слабой ссылкой: лямбда лежит в m.walker.stand, иначе цикл RefCounted и утечка после выхода (#779).
func stand_for(m: Crew.Member) -> Callable:
	var w: WeakRef = weakref(m)
	var g := main
	return func(x: float, z: float) -> bool:
		var mm: Crew.Member = w.get_ref()
		return g.layout.can_stand(x, z) and (mm == null or Crew.room_for(g.crew, mm, x, z))


## Ещё один член экипажа на палубе (снимки и сценарий тестера, пока нет сети): место, курс (рад), роль, внешность.
## Стоящего не ставим в мебель: место внутри голостола или пульта сдвигается к ближайшему свободному (issue #156).
func add_mate(x: float, z: float, yaw: float, role: int, look: int, seated: bool = false) -> Crew.Member:
	var g := main
	var mate := Crew.Member.new(role)
	mate.look = look
	mate.walker.stand = stand_for(mate)
	if not seated:
		var p := g.layout.free_spot(x, z)
		x = p.x
		z = p.y
	mate.place(x, z, yaw, seated)
	mate.sync_post()
	g.crew.append(mate)
	g.crew_view.set_members(g.crew, g.me)
	g.crew_view.apply()
	return mate

