class_name OverlayFlow
extends RefCounted
## Наложения поверх игры (#758): подсказки первого забега ART-038, карточка роли у поста ART-045, внутренняя связь
## ART-040, рация ART-041. Каждый кадр после приборов: шаг → касания `Touch.Router.taps` → места, где палец не крутит
## взгляд (`Router.blocks`) → панель. Состояние — поля `main.tutorial`, `main.role_card`, `main.comms`, `main.radio`,
## панели — `main.tutorial_panel`, `main.role_card_panel`, `main.comms_panel`, `main.radio_panel`.
## Живёт полем `main.overlay_flow`; `Main.comms_area` — пересылка для тестов, `tools/` и `QaRunner`.

var main: Main
var mic_permit := MicPermit.here()   ## разрешение микрофона Android для рации (#634)


func _init(m: Main) -> void:
	main = m


func _size() -> Vector2:
	return main.get_viewport().get_visible_rect().size


## Все четыре по порядку: подсказки, карточка роли, связь, рация (шаг гостя; у хоста — по одному, с замерами).
func step(dt: float) -> void:
	tutorial_step(dt)
	card_step(dt)
	comms_step(dt)   # гость: нажатие — `net_pad.ask` со следующим вводом
	radio_step(dt)


## Подсказки первого забега ART-038: скрыты под тревогой, голосованием, итогом, облётом, шторкой, паузой и меню
## (шаг стоит); у гостя сети — свои шаги без сонара (`Tutorial.Guest`). Пройдено — запомнить в настройках.
func tutorial_step(dt: float) -> void:
	var m := main
	var hidden := m.alarms_on().has(true) or m.at_vote or m.run.ended or m.pause.open \
		or m.main_menu.open or m.settings.open or m.flyby.active() or m.warm.active() or m.wreck.active() \
		or m.walker.noclip
	if m.tutorial.update(dt, hidden):
		m.settings.hints_done = true
		m.settings.write()
		m.lore.learn(LayerLore.INTRO)   # знание кампании «обучение просмотрено» (#827): загрузка его не повторит
	var near := m.near_post
	var target := m.tutorial.pointer_target(m.pilot.seated) if m.tutorial.shown() else ""
	var edge := m.hint_pointer.show_pointer(target, near == target or (m.at_power and target == "energy"),
		m.tutorial.a, dt, m.get_viewport().get_camera_3d(), m.camera)
	m.tutorial_panel.show_tutorial(m.tutorial, m.tutorial.text(m.pilot.seated, near),
		m.tutorial.highlight(m.pilot.seated, m.at_power, near), m.status_rect(),
		m.power_panel.box() if m.power_panel.visible else Rect2(), edge,
		not hidden and m.tutorial.map_wanted(target, near, m.at_power))
	var map := m.tutorial_panel.map_rect()
	for p in m.overlay.router.taps:
		if map.has_point(p):
			m.open_hint_map()
			return


## Карточка роли у поста ART-045: пост, у которого стоит свой игрок, своей ли он роли (в одиночном забеге — все
## свои), что её скрывает; касания карточки и «?» — из `Router.taps`, взгляд под ними не крутится (`Router.blocks`).
func card_step(dt: float) -> void:
	var m := main
	var card := m.role_card
	var at := RoleCard.post_at(m.pilot.seated, m.at_power, m.near_post)
	var solo := m.net_client == null and m.net_mates.is_empty()
	var hidden := m.alarms_on().has(true) or m.at_vote or m.at_power or m.run.ended or m.pause.open \
		or m.main_menu.open or m.settings.open or m.flyby.active() or m.warm.active() or m.wreck.active() \
		or m.walker.noclip or m.brief.k > 0.0 or (m.net_client != null and m.drop.active())
	var quiet := m.tutorial.active() or (at != "" and Crew.holder(m.crew, m.me, at) != null)
	var changed := card.update(dt, at, RoleCard.is_own(at, m.me.role, solo), hidden, quiet)
	var size := _size()
	card.status = m.status_rect()
	var avoid: Array = []
	if m.power_panel.visible:
		avoid.append(m.power_panel.box())
	if m.route_card.visible:
		avoid.append(m.route_card.rect)
	var rect := RoleCard.card_rect(card.post, size, avoid, m.status_rect()) if card.open else Rect2()
	if card.open and not rect.has_area():   # места нет — сразу «?»
		changed = card.fold() or changed
	if not hidden:
		var before := card.read.size()
		for p in m.overlay.router.taps:
			if card.tap(p, size, rect) == "ask":   # «?» — карточка снова на своём месте
				rect = RoleCard.card_rect(card.post, size, avoid, m.status_rect())
		changed = changed or card.read.size() != before
	m.overlay.router.blocks = card.blocks(size, rect)
	if m.tutorial_panel.map_rect().has_area():   # кнопка «Схема» на подсказке: палец там не крутит взгляд
		m.overlay.router.blocks.append(m.tutorial_panel.map_rect())
	if changed:
		m.settings.cards = card.read_list()
		m.settings.write()
	m.role_card_panel.show_card(card, rect if rect.has_area() else m.role_card_panel.rect)


## Внутренняя связь ART-040: при голосовании, итоге, меню, паузе, брифинге (и шторках) — отложена, часы стоят;
## «Спросить код» / «Понятно» — из `Router.taps`, кнопка не крутит взгляд (`Router.blocks`, после карточки роли).
## Где раскладывать плашку связи: безопасная область крестовины и кнопок (`Touch.Layout.area`), пока её нет — экран.
func comms_area() -> Rect2:
	var area := main.overlay.router.layout.area
	return area if area.has_area() else main.get_viewport().get_visible_rect()


func comms_step(dt: float) -> void:
	var m := main
	var comms := m.comms
	var hide := hidden()
	comms.solo = m.net_client == null and m.net_mates.is_empty()
	comms.follow = m.net_client != null   # гость: плашка и проверка — по кадру хоста (`Comms.apply`)
	if m.net_client == null:
		for c: Crew.Member in m.crew:   # «Спросить код» / «Понятно» гостя — его сообщению (`Crew.Pad.ask`)
			if c != m.me and c.pad.ask > 0:
				comms.press(c.pad.ask)
				c.pad.ask = 0
	comms.update(dt, hide)
	var area := comms_area()   # плашка в безопасной области, как крестовина: вырез не сдвигает её на крестовину (#603)
	if not hide:
		for p in m.overlay.router.taps:
			comms.tap(p - area.position, area.size)
	if comms.asked > 0:   # гость: нажатие уходит хосту со следующим вводом
		m.net_pad.ask = comms.asked
		comms.asked = 0
	for r in comms.blocks(area.size):
		m.overlay.router.blocks.append(Rect2(r.position + area.position, r.size))
	m.comms_panel.show_comms(comms, m.time, area)


## Плашки поверх игры (связь ART-040, рация ART-041) не показываются: голосование, итог, меню, пауза, брифинг, шторки.
func hidden() -> bool:
	var m := main
	return m.at_vote or m.run.ended or m.pause.open or m.main_menu.open or m.settings.open or m.ship_map.open \
		or m.brief.k > 0.0 or m.flyby.active() or m.warm.active() or m.wreck.active() \
		or (m.net_client != null and m.drop.active())


## Рация ART-041 в коопе: «Нажать и держать» — палец на кнопке (`Router.held_in`), меню и пауза обрывают передачу;
## кнопка не крутит взгляд (`Router.blocks`). Голос — `voice_step`; разрешение микрофона Android — `mic_permit`: нет
## доступа — `Radio.mic` = false, первое нажатие и «В настройки» показывают системный запрос.
func radio_step(dt: float) -> void:
	var m := main
	var radio := m.radio
	if radio.pinned:
		m.radio_panel.show_radio(radio, m.time)
		return
	radio.on = Radio.enabled and (m.net_client != null or not m.net_mates.is_empty())
	radio.mic = mic_permit.ok()
	var size := _size()
	radio.update(dt, m.overlay.router.held_in(Radio.button_rect(size)), hidden())
	voice_step(dt)
	radio_sight()
	for p in m.overlay.router.taps:
		radio.tap(p, size)
	if mic_permit.step(dt, radio.begged, radio.settings_wanted, OS.get_granted_permissions):
		OS.request_permission(MicPermit.NAME)   # ответ — в списке разрешений, `mic_permit` опросит
	radio.settings_wanted = false
	m.overlay.router.blocks.append_array(radio.blocks(size))
	m.radio_panel.show_radio(radio, m.time)


## Голос рации (#634): свой захват хосту (гость) или всем на палубе (хост), голоса товарищей — в проигрыватели и
## в список рации (`VoiceIO`, `Voice.Station`).
func voice_step(dt: float) -> void:
	var m := main
	if m.voice_io == null:
		return
	var online := false
	var send := func(_p: PackedByteArray) -> void: pass
	var packets := []
	var me := m.crew.find(m.me)
	if m.net_client != null:
		online = m.net_client.joined()
		send = m.net_client.send_voice
		packets = m.net_client.take_voice()
		me = m.net_client.me
	elif m.net_host != null:
		online = not m.net_mates.is_empty()
		var host := m.net_host
		var i := me
		send = func(p: PackedByteArray) -> void: host.send_voice(i, p)
		packets = m.net_host.take_voice()
	var sight := func(w: int) -> bool:
		return w < 0 or w >= m.crew.size() \
			or ShipLayout.in_sight(m.me.z, (m.crew[w] as Crew.Member).z, m.layout.doors)
	m.voice_io.step(dt, m.radio, online, send, packets, m.crew, me, sight)


## Говорящий товарищ в поле зрения или за стеной (ART-041): за закрытым люком — строка «Вне поля зрения», табличка
## над ним без «активности» (`ShipLayout.in_sight`).
func radio_sight() -> void:
	var m := main
	for t in m.radio.talkers:
		if t.id >= 0 and t.id < m.crew.size():
			t.seen = ShipLayout.in_sight(m.me.z, (m.crew[t.id] as Crew.Member).z, m.layout.doors)


## Меню и пауза: все наложения гаснут сразу, передача рации обрывается; после — снова по своим шагам.
func hide_all() -> void:
	var m := main
	m.tutorial.a = 0.0
	m.comms.a = 0.0   # плашка связи ART-040 под меню и паузой не висит: после — снова по `comms_step`
	if m.comms_panel != null and m.comms_panel.visible:
		m.comms_panel.visible = false
	m.radio.update(0.0, false, true)   # рация ART-041: меню и пауза обрывают передачу сразу
	if m.radio_panel != null and m.radio_panel.visible:
		m.radio_panel.visible = false
	m.role_card.a = 0.0   # и карточка роли ART-045 (меню, пауза): после — снова по `card_step`
	m.role_card.q = 0.0
	m.role_card.f = 0.0
	if m.role_card_panel != null and m.role_card_panel.visible:
		m.role_card_panel.visible = false
	if m.overlay != null:
		m.overlay.router.blocks.clear()
	if m.hint_pointer != null:
		m.hint_pointer.show_pointer("", false, 0.0, 0.0, null, null)
	if m.tutorial_panel != null and m.tutorial_panel.visible:
		m.tutorial_panel.visible = false
