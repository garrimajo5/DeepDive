class_name SoundMix
## Шины громкости по звуковой карте `docs/zvuk.md`: Master → Музыка, Эмбиент, Корабль, Мир, Голоса, Интерфейс.
## Шины заводит `ensure()` из кода (файла раскладки шин нет), каждый плеер ставит свою шину (`bus = SoundMix.SHIP`…).
## Сведение — `Mix`: по состоянию игры (меню, пауза, вид с борта, тревога, глубина) у каждой шины целевая доля
## громкости, к ней доля идёт плавно (FADE_S), на шину — в дБ (`apply`). Общую громкость (Master) ставят настройки, долю каждой шины —
## страница «Звук» (`SoundPage`, `Settings.buses`), она умножается на сведение в `apply`.
## Эмбиент по глубине — две петли (отмель и глубже 200 м): их доли — `shelf_k`/`deep_k`, их берёт плеер эмбиента.

const MUSIC := "Музыка"
const AMBIENT := "Эмбиент"
const SHIP := "Корабль"
const WORLD := "Мир"
const VOICE := "Голоса"
const UI := "Интерфейс"
const BUSES: Array[String] = [MUSIC, AMBIENT, SHIP, WORLD, VOICE, UI]

const MUTE_DB := -80.0
const FADE_S := 1.5          ## доля шины проходит 0 → 1 за столько секунд (музыка напряжения, меню, вид с борта)
const PAUSE_K := 0.25        ## пауза: корабль, мир и эмбиент — тише в 4 раза (−12 дБ), музыка и интерфейс — как есть
const MENU_MUSIC_K := 1.0    ## главное меню: тема меню на полную, корабль и мир молчат
const OUTSIDE_SHIP_K := 0.4  ## вид с борта (облёт): корабль слышен снаружи глуше (−8 дБ), мир и эмбиент — полностью
const INSIDE_WORLD_K := 0.7  ## изнутри корабля мир за обшивкой чуть глуше (−3 дБ)
const TENSION_AMBIENT_K := 0.6  ## напряжение: эмбиент уступает место музыке (−4,4 дБ)
## Эмбиент по глубине: до DEEP_FROM — петля отмели, глубже DEEP_TO — петля глубины, между — перекрёстно.
const DEEP_FROM := 150.0
const DEEP_TO := 250.0
## Петли эмбиента и гула (SND-001 #655, docs/zvuk/SND-001.md). Петля глубины ещё не заказана — пока её файла нет,
## петля отмели звучит на любой глубине (`loop_k`). Играет `scripts/game/ambience.gd` (`main.ambience`).
const SHELF_LOOP := "res://audio/ambient/ambient-shelf.mp3"
const DEEP_LOOP := "res://audio/ambient/ambient-deep.mp3"
const HUM_LOOP := "res://audio/ship/ship-hum.mp3"
const AMBIENT_DB := -6.0    ## эмбиент за бортом — фон под всем остальным
const HUM_DB := -12.0       ## гул корабля поверх эмбиента, тише (в файле он громче эмбиента на ~5 дБ)
## Музыка SND-004 (#658, docs/zvuk/SND-004.md): тема меню и напряжение — петли на шине «Музыка», играет
## `scripts/game/music.gd` (`main.music`). Какая из двух звучит — `Mix.music_pair`, громкость шины — `Mix.levels`.
const MENU_MUSIC := "res://audio/music/music-menu.mp3"
const TENSION_MUSIC := "res://audio/music/music-tension.mp3"
const MENU_DB := -2.0       ## тема меню звучит одна (корабль и мир молчат)
const TENSION_DB := -8.0    ## напряжение — слой под эмбиентом и тревогой, не поверх них


## Заводит недостающие шины (по порядку BUSES, выход — в Master). Повторный вызов ничего не меняет.
static func ensure() -> void:
	for name in BUSES:
		if AudioServer.get_bus_index(name) >= 0:
			continue
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, name)
		AudioServer.set_bus_send(i, "Master")


## Доля → дБ шины: 0 — тишина.
static func to_db(k: float) -> float:
	return MUTE_DB if k <= 0.001 else maxf(MUTE_DB, linear_to_db(k))


## Ставит шинам громкости из словаря «шина → доля» (`Mix.levels`), умноженные на доли из настроек user
## («шина → доля», `Settings.buses`; нет записи — 100 %). Шины без записи в levels не трогает.
static func apply(levels: Dictionary, user := {}) -> void:
	for name: String in levels:
		var i := AudioServer.get_bus_index(name)
		if i >= 0:
			AudioServer.set_bus_volume_db(i, to_db(gain(levels, user, name)))


## Итоговая доля шины name: сведение × настройка игрока.
static func gain(levels: Dictionary, user: Dictionary, name: String) -> float:
	return float(levels.get(name, 0.0)) * clampf(float(user.get(name, 1.0)), 0.0, 1.0)


## Доля петли отмели на глубине depth (м): 1 до DEEP_FROM, 0 глубже DEEP_TO, между — плавно.
static func shelf_k(depth: float) -> float:
	return 1.0 - smoothstep(DEEP_FROM, DEEP_TO, depth)


## Доля петли глубины — дополняет отмель до 1.
static func deep_k(depth: float) -> float:
	return 1.0 - shelf_k(depth)


## Доли петель [отмель, глубина] с учётом того, есть ли петля глубины: без неё отмель — на полную везде.
static func loop_k(pair: Vector2, has_deep: bool) -> Vector2:
	return pair if has_deep else Vector2(1.0, 0.0)


## Сведение шин. Состояние игры — полями (ставит `Main._sound` каждый кадр), `update(dt)` ведёт доли к целям.
class Mix extends RefCounted:
	var menu := false      ## главное меню (и экраны из него): тема меню, корабль и мир молчат
	var paused := false    ## пауза, которая останавливает мир
	var outside := false   ## камера снаружи корабля (облёт в начале, вид при всплытии)
	var tension := false   ## тревога на корабле или «Корпус разрушен» — играет музыка напряжения
	var depth := 0.0       ## глубина корабля, м — для эмбиента (shelf_k/deep_k)
	var levels := {}       ## шина → текущая доля 0…1
	## Доля темы меню в шине «Музыка» (остальное — напряжение). Меняется, только пока шина звучит или к ней идёт:
	## шина затихает — какая звучала, та и затихает (меню закрыли — тема не сменяется напряжением на спаде);
	## шина молчит — сразу та, что нужна (тревога после меню — без хвоста темы меню).
	var menu_k := 0.0

	func _init() -> void:
		levels = target()
		menu_k = 1.0 if menu else 0.0

	## Цели долей для текущего состояния.
	func target() -> Dictionary:
		var t := {MUSIC: 0.0, AMBIENT: 1.0, SHIP: 1.0, WORLD: INSIDE_WORLD_K, VOICE: 1.0, UI: 1.0}
		if menu:
			t[MUSIC] = MENU_MUSIC_K
			t[AMBIENT] = 0.0
			t[SHIP] = 0.0
			t[WORLD] = 0.0
			t[VOICE] = 0.0
			return t
		if tension:
			t[MUSIC] = 1.0
			t[AMBIENT] = TENSION_AMBIENT_K
		if outside:
			t[SHIP] = OUTSIDE_SHIP_K
			t[WORLD] = 1.0
		if paused:
			for b in [AMBIENT, SHIP, WORLD]:
				t[b] *= PAUSE_K
		return t

	## Доли — к целям со скоростью 1/FADE_S в секунду. Возвращает levels (для `SoundMix.apply`).
	func update(dt: float) -> Dictionary:
		var t := target()
		var step := dt / FADE_S
		var want := 1.0 if menu else 0.0
		if float(levels.get(MUSIC, 0.0)) <= 0.001:
			menu_k = want
		elif float(t[MUSIC]) > 0.0:
			menu_k = move_toward(menu_k, want, step)
		for b: String in t:
			levels[b] = move_toward(float(levels.get(b, t[b])), t[b], step)
		return levels

	## Доли петель музыки [тема меню, напряжение] — их берёт плеер музыки (`Music.set_pair`).
	func music_pair() -> Vector2:
		return Vector2(menu_k, 1.0 - menu_k)

	## Доли петель эмбиента на текущей глубине: [отмель, глубина].
	func ambient_pair() -> Vector2:
		return Vector2(SoundMix.shelf_k(depth), SoundMix.deep_k(depth))
