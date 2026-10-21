class_name EcoView
extends Node3D
## Живой мир отмели в сцене (поток Б): держит мир экосистемы без узлов (EcoWorld, scripts/core/eco/) и рисует существ.
## Стоит в мире (не в корабле), на слое отмели OceanView.LAYER_WORLD. Корабль зовёт только step() — см. EcoLink.
## Виды подключаются модулями мира (world.add); их узлы рисования — в scripts/game/eco/.

## Мир экосистемы: зерно 20261018, подшаги ≤ 0,05 с.
var world := EcoWorld.new()
## Светляки-полосники: шесть стай у кораллов и их MultiMesh.
var fish: EcoFish
var fish_view: FishView
## Светящийся мох (22 пятна) и скребуны (10), что его объедают.
var moss: EcoMoss
var moss_view: MossView
var grazers: EcoGrazer
var grazer_view: GrazerView
## Серпохвосты: три хищника, охотятся на светляков и бросаются на корабль (EcoLink.HIT); модели MOD-011.
var preds: EcoPred
var pred_view: PredView
## Флора (ART-004): течение мира, огнецвет (три куста, кончики гаснут от шума) и веерники поперёк течения.
var current: EcoCurrent
var coral: EcoCoral
var coral_view: CoralView
var fans: EcoFan
var fan_view: FanView
## Пиявники на жабрах серпохвостов и станции чистки на вершинах огнецвета.
var leeches: EcoLeech
var leech_view: LeechView
## Волнолист: две куртины по четыре куста, раскрываются в луче прожектора, моллюски зовут стаи.
var ferns: EcoFern
var fern_view: FernView
## Пузырчатка-фонарь: три куста у пятен мха, луковицы зреют и лопаются облаком спор, на споры слетаются стаи.
var bladders: EcoBladder
var bladder_view: BladderView
## Трубные органы: две губки, в их гуле серпохвост не слышит двигателей корабля.
var organs: EcoOrgan
var organ_view: OrganView
## Подушечники: две подушки у стай светляков, от касания — облако чернил, в нём серпохвост теряет стаю и корабль.
var cushions: EcoCushion
var cushion_view: CushionView
## Стеклоусты: три логова в расщелинах, бросок на скребунов и светляков, присоска на стекле носа — тянет заряд.
var eels: EcoEel
var eel_view: EelView
## Радужники: три стаи гребневиков, вспыхивают в луче прожектора — вспышка зовёт серпохвостов издалека.
var raduzh: EcoRaduzh
var raduzh_view: RaduzhView
## Огнёвки: рачки-чистильщики на станциях чистки, у станции — перемирие и укрытие корабля.
var ognevka: EcoOgnevka
var ognevka_view: OgnevkaView
## Хватни у стай светляков 0…3 и пестрянки в их щупальцах: подманивают стаю, ловят светляков в темноте.
var hvaten: EcoHvaten
var hvaten_view: HvatenView
## Ленточник у стай светляков 1 и 2 и шипоежи, что его объедают: в густой роще хищник теряет напуганную стаю.
var kelp: EcoKelp
var kelp_view: KelpView
## Кольчужник: нора у второй рощи, раскалывает шипоежей, иглы — в панцирь; щиплет корабль у норы.
var krab: EcoKrab
var krab_view: KrabView
## Скальник: живой камень у норы кольчужника, в луче меняет цвет, гоняет краба, разглядывает тихий корабль.
var skalnik: EcoSkalnik
var skalnik_view: SkalnikView
## Монетники: три стайки над пятнами мха у старта, рассыпаются от сонара; глазуны в песке хватают их снизу.
var coins: EcoCoins
var coins_view: CoinsView
## Ледокрылы: два гигантских ската кружат подо льдом, водят стаи светляков, поют; над кораблём проходят поверху.
var rays: EcoRay
var ray_view: RayView
## Присоски: по три на спине ледокрыла, перебираются на корпус, тормозят корабль, отпугивают стеклоуста.
var remoras: EcoRemora
var remora_view: RemoraView
## Мерцающий планктон: четыре светящихся облака, вспыхивают от быстрого — след корабля выдаёт его серпохвосту.
var plankton: EcoPlankton
var plankton_view: PlanktonView
## Фонарные вуали: две колонии медуз дрейфуют над рифом, жалят светляков, под куполом серпохвост теряет корабль.
var veils: EcoVeil
var veil_view: VeilView
## Гротовик: панцирное существо с рифом на спине бредёт по отмели, в рифе живёт и прячется шестая стая светляков.
var grot: EcoGrot
var grot_view: GrotView
## Чёрный курильщик (место 2, ART-012): трубы на дне, светящиеся жерла, столб пузырей до льда, марево.
var vent: EcoVent
var vent_view: VentView
## Каменный цветок (место 1): коралл-исполин 28 м, светящиеся кончики мерцают волной снизу вверх.
var flower: EcoFlower
var flower_view: FlowerView
## Раковина древних (место 3): спираль Складчатых на дне, кольца знаков на витках загораются по очереди.
var shell: EcoShell
var shell_view: ShellView
## Кости левиафана (место 4, ART-030): клетка из 8 пар рёбер с проходом 14 × 7 м, хвост вбок, череп сбоку.
var bones: EcoBones
var bones_view: BonesView
## Световой колодец (место 5, ART-031): трещина во льду, наклонный столб солнечного света, пятно мха на дне.
var well: EcoWell
var well_view: WellView
## Край отмели (место 6, ART-032): скальные клинья вдоль бровки, шрам оползня с осыпью, трещины на площадке.
var drop: EcoDrop
var drop_view: DropView
## Эхоловец (ART-007): засадчик с ушами-воронками лежит у Костей левиафана, уши поворачивает на корабль,
## затаившегося выдаёт только импульс сонара.
var echo: EcoEcho
var echo_view: EchoView

## Высота дна под (x, z): Seabed.height. Даёт корабль при создании; уходит в мир. Мох и скребуны встают на дно
## заново (мир сбрасывается, меш мха собирается по новому дну).
var ground: Callable:
	set(value):
		ground = value
		world.ground = value
		world.reset()
		_rebuild_moss()
		_rebuild_coral()
		_rebuild_ferns()
		_rebuild_bladders()
		_rebuild_organs()
		_rebuild_cushions()
		_rebuild_eels()
		_rebuild_raduzh()
		_rebuild_ognevka()
		_rebuild_hvaten()
		_rebuild_kelp()
		_rebuild_coins()
		_rebuild_vent()
		_rebuild_flower()
		_rebuild_shell()
		_rebuild_bones()
		_rebuild_well()
		_rebuild_drop()
		_rebuild_plankton()


func _init() -> void:
	fish = world.add(EcoFish.new()) as EcoFish
	fish_view = FishView.new(fish)
	add_child(fish_view)
	moss = world.add(EcoMoss.new()) as EcoMoss
	grazers = world.add(EcoGrazer.new(moss)) as EcoGrazer
	grazer_view = GrazerView.new(grazers)
	add_child(grazer_view)
	preds = world.add(EcoPred.new(fish)) as EcoPred
	pred_view = PredView.new(preds)
	add_child(pred_view)
	current = world.add(EcoCurrent.new()) as EcoCurrent
	coral = world.add(EcoCoral.new()) as EcoCoral
	leeches = world.add(EcoLeech.new(preds, coral)) as EcoLeech
	leech_view = LeechView.new(leeches)
	add_child(leech_view)
	fans = world.add(EcoFan.new(current)) as EcoFan
	fan_view = FanView.new(fans)
	add_child(fan_view)
	ognevka = world.add(EcoOgnevka.new(leeches, fans)) as EcoOgnevka
	ferns = world.add(EcoFern.new(fish)) as EcoFern
	bladders = world.add(EcoBladder.new(fish)) as EcoBladder
	organs = world.add(EcoOrgan.new()) as EcoOrgan
	preds.organs = organs
	cushions = world.add(EcoCushion.new(fish)) as EcoCushion
	preds.cushions = cushions
	veils = world.add(EcoVeil.new()) as EcoVeil
	fish.veils = veils
	preds.veils = veils
	veil_view = VeilView.new(veils)
	add_child(veil_view)
	grot = world.add(EcoGrot.new(fish)) as EcoGrot
	preds.grot = grot
	grot_view = GrotView.new(grot)
	add_child(grot_view)
	eels = world.add(EcoEel.new(grazers, fish)) as EcoEel
	raduzh = world.add(EcoRaduzh.new()) as EcoRaduzh
	preds.raduzh = raduzh
	hvaten = world.add(EcoHvaten.new(fish)) as EcoHvaten
	kelp = world.add(EcoKelp.new(fish)) as EcoKelp
	preds.kelp = kelp
	krab = world.add(EcoKrab.new(kelp)) as EcoKrab
	skalnik = world.add(EcoSkalnik.new(krab)) as EcoSkalnik
	coins = world.add(EcoCoins.new(moss, preds)) as EcoCoins
	coins.bladders = bladders
	bladders.coins = coins
	rays = world.add(EcoRay.new(fish)) as EcoRay
	ray_view = RayView.new(rays)
	add_child(ray_view)
	remoras = world.add(EcoRemora.new(rays)) as EcoRemora
	eels.remoras = remoras
	remora_view = RemoraView.new(remoras)
	add_child(remora_view)
	plankton = world.add(EcoPlankton.new(preds, rays)) as EcoPlankton
	preds.plankton = plankton
	vent = world.add(EcoVent.new()) as EcoVent
	flower = world.add(EcoFlower.new()) as EcoFlower
	shell = world.add(EcoShell.new()) as EcoShell
	bones = world.add(EcoBones.new()) as EcoBones
	well = world.add(EcoWell.new()) as EcoWell
	drop = world.add(EcoDrop.new()) as EcoDrop
	echo = world.add(EcoEcho.new(bones)) as EcoEcho
	echo_view = EchoView.new(echo)
	add_child(echo_view)
	_rebuild_moss()
	_rebuild_coral()
	_rebuild_ferns()
	_rebuild_bladders()
	_rebuild_organs()
	_rebuild_cushions()
	_rebuild_eels()
	_rebuild_raduzh()
	_rebuild_ognevka()
	_rebuild_hvaten()
	_rebuild_kelp()
	_rebuild_coins()
	_rebuild_vent()
	_rebuild_flower()
	_rebuild_shell()
	_rebuild_bones()
	_rebuild_well()
	_rebuild_drop()
	_rebuild_plankton()


## Меш мха по дну мира (пятна плоские, пока дна нет).
func _rebuild_moss() -> void:
	if moss_view:
		remove_child(moss_view)
		moss_view.free()
	moss_view = MossView.new(moss, world.ground)
	add_child(moss_view)


## Меш огнецвета по дну мира (кусты встают на дно при сбросе мира).
func _rebuild_coral() -> void:
	if coral_view:
		remove_child(coral_view)
		coral_view.free()
	coral_view = CoralView.new(coral)
	add_child(coral_view)


## Волнолист по дну мира (моллюски лежат на дне и ставятся один раз).
func _rebuild_ferns() -> void:
	if fern_view:
		remove_child(fern_view)
		fern_view.free()
	fern_view = FernView.new(ferns, world.ground)
	add_child(fern_view)


## Пузырчатка по дну мира (стебли ставятся один раз).
func _rebuild_bladders() -> void:
	if bladder_view:
		remove_child(bladder_view)
		bladder_view.free()
	bladder_view = BladderView.new(bladders)
	add_child(bladder_view)


## Трубные органы по дну мира (меш собирается один раз).
func _rebuild_organs() -> void:
	if organ_view:
		remove_child(organ_view)
		organ_view.free()
	organ_view = OrganView.new(organs)
	add_child(organ_view)


## Подушечники по дну мира (подушки встают на дно при сбросе мира).
func _rebuild_cushions() -> void:
	if cushion_view:
		remove_child(cushion_view)
		cushion_view.free()
	cushion_view = CushionView.new(cushions)
	add_child(cushion_view)


## Стеклоусты по дну мира (камни логов ставятся один раз).
func _rebuild_eels() -> void:
	if eel_view:
		remove_child(eel_view)
		eel_view.free()
	eel_view = EelView.new(eels)
	add_child(eel_view)


## Радужники по дну мира (стаи встают на 9 м над дном при сбросе мира).
func _rebuild_raduzh() -> void:
	if raduzh_view:
		remove_child(raduzh_view)
		raduzh_view.free()
	raduzh_view = RaduzhView.new(raduzh)
	add_child(raduzh_view)


## Огнёвки по станциям мира (число рачков — по станциям после сброса).
func _rebuild_ognevka() -> void:
	if ognevka_view:
		remove_child(ognevka_view)
		ognevka_view.free()
	ognevka_view = OgnevkaView.new(ognevka)
	add_child(ognevka_view)


## Хватни по дну мира (тела ставятся один раз).
func _rebuild_hvaten() -> void:
	if hvaten_view:
		remove_child(hvaten_view)
		hvaten_view.free()
	hvaten_view = HvatenView.new(hvaten)
	add_child(hvaten_view)


## Ленточник и шипоежи по дну мира (ленты встают на дно при сбросе мира).
func _rebuild_kelp() -> void:
	if kelp_view:
		remove_child(kelp_view)
		kelp_view.free()
	kelp_view = KelpView.new(kelp)
	add_child(kelp_view)
	# нора кольчужника — у рощи, встаёт на дно заново вместе с ней
	if krab_view:
		remove_child(krab_view)
		krab_view.free()
	krab_view = KrabView.new(krab)
	add_child(krab_view)
	# скальник живёт у норы — встаёт заново вместе с ней
	if skalnik_view:
		remove_child(skalnik_view)
		skalnik_view.free()
	skalnik_view = SkalnikView.new(skalnik)
	add_child(skalnik_view)


## Монетники и глазуны по дну мира (глазуны лежат на дне и встают заново вместе с ним).
func _rebuild_coins() -> void:
	if coins_view:
		remove_child(coins_view)
		coins_view.free()
	coins_view = CoinsView.new(coins)
	add_child(coins_view)


## Чёрный курильщик по дну мира (трубы встают на дно, пузыри — от жерл; дальше движутся в шейдере).
func _rebuild_vent() -> void:
	if vent_view:
		remove_child(vent_view)
		vent_view.free()
	vent_view = VentView.new(vent)
	add_child(vent_view)


## Каменный цветок по дну мира (ветви встают на дно, кончики мерцают в шейдере).
func _rebuild_flower() -> void:
	if flower_view:
		remove_child(flower_view)
		flower_view.free()
	flower_view = FlowerView.new(flower)
	add_child(flower_view)


## Меш раковины древних по дну мира (раковина встаёт на дно при сбросе мира).
func _rebuild_shell() -> void:
	if shell_view:
		remove_child(shell_view)
		shell_view.free()
	shell_view = ShellView.new(shell)
	add_child(shell_view)


## Меш костей левиафана по дну мира (рёбра и череп встают на дно при сбросе мира).
func _rebuild_bones() -> void:
	if bones_view:
		remove_child(bones_view)
		bones_view.free()
	bones_view = BonesView.new(bones)
	add_child(bones_view)


## Световой колодец по дну мира (столб встаёт от льда до дна, мох — на дно при сбросе мира).
func _rebuild_well() -> void:
	if well_view:
		remove_child(well_view)
		well_view.free()
	well_view = WellView.new(well)
	add_child(well_view)


func _rebuild_drop() -> void:
	if drop_view:
		remove_child(drop_view)
		drop_view.free()
	drop_view = DropView.new(drop)
	add_child(drop_view)


## Планктон по дну мира (облака встают на 10 м над дном при сбросе мира).
func _rebuild_plankton() -> void:
	if plankton_view:
		remove_child(plankton_view)
		plankton_view.free()
	plankton_view = PlanktonView.new(plankton)
	add_child(plankton_view)


## Шаг мира: dt — время, ship — состояние корабля. Возвращает события для корабля (EcoLink).
func step(dt: float, ship: EcoLink.ShipState) -> Array[Dictionary]:
	world.ship = ship
	world.step(dt)
	fish_view.sync(world.time)
	grazer_view.sync(world.time)
	pred_view.sync(world.time, ship.pos)
	leech_view.sync(world.time)
	moss_view.sync()
	if bones_view.moss_view:
		bones_view.moss_view.sync()
	if well_view.moss_view:
		well_view.moss_view.sync()
	coral_view.sync()
	fan_view.sync(world.time)
	fern_view.sync(world.time)
	bladder_view.sync(world.time)
	cushion_view.sync(world.time)
	eel_view.sync(world.time)
	raduzh_view.sync(world.time, ship.pos, ship.yaw)
	ognevka_view.sync()
	hvaten_view.sync(world.time, ship.pos, false)
	kelp_view.sync(world.time)
	krab_view.sync(world.time)
	skalnik_view.sync(world.time, ship.pos)
	coins_view.sync(world.time)
	ray_view.sync()
	remora_view.sync(world.time)
	veil_view.sync(world.time, ship.pos)
	grot_view.sync(world.time, ship.pos)
	plankton_view.sync(world.time, ship.pos, ship.yaw)
	echo_view.sync(world.time, ship.pos)
	return world.take_link()
