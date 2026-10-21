# Погружение (DeepDive) — правила для разработки

Кооперативная игра про батискаф «Ковчег-7» в подлёдном океане. Делаем версию на **Godot 4.7.2 (GDScript) под Android**.
Прежние варианты (браузерный прототип и Unity) лежат в замороженном репозитории `garrimajo5/pogrujenie`: оттуда берём решения
и числа, но не код один в один. `js/…` в комментариях — файлы браузерного прототипа (`archive/web/js/…` в pogrujenie),
`Core/…cs` — Unity-версия там же. Клонировать при переносе: `git clone --depth 1 https://github.com/garrimajo5/pogrujenie`.
Мир (утверждён владельцем, главный источник по лору): `docs/world.md`. Контекст: `docs/context.txt`, бестиарий на 100 видов: `docs/bestiary.md`, концепт-арт: `docs/concept-art/`,
заказы художнику и ошибки — GitHub Issues, план: `ROADMAP.md`, поэтапный план игры: `docs/plan.md`.

## Правила
- Интерфейс и тексты — на русском, коротко и по делу.
- Игра работает на Android-телефоне в альбомной ориентации: крестовина + кнопка действия + свайп, без клавиатуры.
- Бюджет на телефоне: вызовов отрисовки < 260, треугольников < 350 тыс. Рендерер — Compatibility (OpenGL ES 3).
- Внешние библиотеки, аддоны и пакеты по сети — только с решения владельца. Тесты — свой раннер `tests/run.gd`.
- `docs/concept-art/` меняем только при приёмке художника.

## Как устроен проект
- Общая схема, дерево сцены, шаг игры и границы потоков — `docs/ARCHITECTURE.md`.
- `project.godot`, главная сцена `scenes/main.tscn` (корень с `scripts/game/main.gd`) — сцена собирается из кода.
- `scripts/core/` — логика без узлов сцены (static-функции и внутренние классы `RefCounted`): её проверяют быстрые тесты.
  `hash_noise.gd` (шум как `G.noise`/`G.fbm`), `seabed.gd` (рельеф `W.height`, цвет дна, вода по глубине),
  `helm.gd` (ход корабля `Helm.Ship`, течение `Helm.SeaCurrent`), `deck.gd` (палуба, посты, игрок `Deck.Walker`),
  `touch.gd` (раскладка, крестовина, разбор касаний), `bridge_plan.gd` (оболочка мостика по ART-002),
  `bridge_props.gd` (места моделей художника на мостике), `searchlight.gd` (прожектор: числа, луч до дна, меш конуса),
  `texture_glow.gd` (маска голубых огней), `qa_script.gd` (сценарий тестера), `status.gd` (строка состояния
  по строкам экрана, сообщения на 4,2 с, румбы), `reactor.gd` (доли энергии `Reactor.k(Sys…)` — сила систем, перегрев,
  сброс; `Reactor.Console` — выбор на пульте). Новая система корабля берёт силу из `main.reactor.k(...)`.
  `ship_layout.gd` — отсеки за мостиком (z 2…24), люки `ShipLayout.Door`, `can_stand` для всего корабля (мостик — `Deck`),
  геометрия `parts()`; рисует `scripts/game/rooms_view.gd` (там же реактор). `hull_plan.gd` — корпус снаружи по ART-001
  (28 деталей, `inside`/`inside_world`); меши по краскам и движение роторов и рулей — `hull_mesh.gd` (`HullMesh.Motion`; обшивка ART-024 — `HullMesh.plated`/`growth`,
  карты `textures/hull/`, шейдер `shaders/hull_plating.gdshader`),
  рисует `scripts/game/hull_view.gd` (`main.hull`, слой 1). `sonar.gd` — импульс, дальность,
  отметки из `EcoLink.NEAR`, карта рельефа; голограмма — `scripts/game/sonar_view.gd` + `shaders/sonar_holo.gdshader`.
  `crew.gd` — член экипажа (`Crew.Member`: поза стоя, на ходу и в кресле, руки на штурвале, резак при сварке `weld`, наклон к посту `lean` (`ease_lean`; камера за головой — `eye_offset`; своя фигура стоя позади глаза — `back`, взглядом вниз — дальше, `CrewView.own_back`, меш без груди `CrewView.mesh_kind`; места у постов `Main.*_STAND`), снимок для сети; пост одного человека — `Crew.BUSY`/`Crew.holder`, `Crew.Member.post` («Штурвал занят»); свой ходок и ввод у каждого — `Member.walker`, `Crew.Pad` (`Member.drive`, товарищей ведёт `Main._drive_mates`, `main.walker` — это `me.walker`); посты у каждого свои — `Member.pilot`/`seated`, `at_power`, `at_vote` (`main.pilot`/`at_power`/`at_vote` — это `me`), кнопка товарища `Pad.action` → `Main.mate_action`, товарищ на посту правит кораблём — `Main._mate_posts` (`Pad.vert`, `Pad.light`);
  `main.me` — свой игрок, `main.crew` — все, `main.add_mate`), рисует `scripts/game/crew_view.gd` моделями MOD-012: позу на скелет переносит `crew_rig.gd` (`CrewRig.pose`, внешность `Crew.Member.look`), снаряжение ролей MOD-016 — `CrewRig.GEAR`/`ROLE_GEAR` (подгонка к телу — `GEAR_FIT`, щиток — `visor_xform`), надевает `CrewView._dress`; руки на постах — `crew_hands.gd` (`CrewHands.*` → `Crew.Member.hold`, ставит `Main._hands`). `engine_room.gd` — вентиль сброса пара (удержание, `main.engine`) и щиток «Аварийный сброс» в машинном. `airlock.gd` — нижний шлюз трюма (крышка `cover_pose`, проём `in_hole`). `samples.gd` — образцы на дне и лебёдка трюма (`main.samples`: удержание `hold`, груз `cargo`, `restore`; захват для мира — `EcoLink.ShipState.claw*`, кража — `steal`/`drop` по `EcoLink.STEAL`/`DROP`), камешки на дне — `scripts/game/samples_view.gd`, лебёдка — `RoomsView.set_winch`; полки трюма на 24 банки — `hold_shelves.gd` (`HoldShelves.cells`, `contents(cargo)`), банки — `RoomsView.set_shelves`. `save_game.gd` — сохранение в `user://save.json` (`main.save`: груз, поднятые образцы и изученные виды, формат `js/save.js`; тесты, снимки и прогон тестера его не трогают — `SaveGame.default_path = ""`). `breach.gd` — событие «пробоина» (`main.breach`: `on_hit`, `hold` — сварка, вода `water`, `status()`; `main.open_breach(n)`), рисует `scripts/game/breach_view.gd` (модели MOD-013, струя, вода, тревога). `silt.gd` — событие «сонарная тьма» (`main.silt`: облака ила, `on_scrape`, `jam_ping` — импульс вязнет, `beam_k`, `noise`; `main.open_silt()`), хлопья — `scripts/game/silt_view.gd`; табло тревог одной строкой — `Status.alarm`; табло над носовым окном (ART-025) — `alarm_board.gd` (`AlarmBoard.levels`, поля по `Main.alarms_on`; рамка у поста главной тревоги — `AlarmBoard.hint`), рисует `scripts/game/alarm_board_view.gd` (`main.alarm_board`). `zap.gd` — разряд по корпусу (рычаг `Zap.LEVER_POS`, `main.fire_zap()`). `scanner.gd` — сканер биолога (`main.scanner`: цели из `EcoLink.NEAR` с "scan", пока игрок у поста — `ShipState.scan_range`; `hold`, изученные виды `scanned`, наблюдения `seen` от `EcoLink.OBSERVE` — `observe`, экран `BridgeView.set_scanner_screen`). `lab.gd` — лаборатория (колбы `Lab.FLASKS` с тремя последними образцами груза `Lab.contents`, стойка журнала `Lab.journal_lines`, карточки видов `Lab.page_lines` — нажатия листают, `main.journal_page`, посты `flask0…2`/`journal`), рисует `RoomsView.set_lab`; кольцо-светильник MOD-020 на потолке — `Lab.RING`, `RoomsView.lab_ring`. `synth.gd` — процедурный звук без файлов (петли PCM: `Synth.siren()`, `Synth.jet()`, шипение присоски `Synth.latch()`; новые звуки — сюда, числа из `js/audio.js`), играет `BreachView`. `vitals.gd` — корпус и заряд корабля (`main.vitals`: `hit`, `spend`, `scrape`, присоски `drain` → тревога `drain_alarm`, мигание света `lamp_k` → `Main._flicker`: плафоны `set_lamps`, прожектор `set_flicker`; помехи экранов `screen_k` → `BridgeView.set_screens`, `RoomsView.set_journal_k`), то, что тратит заряд, берёт его через `spend`. `briefing.gd` — голограмма брифинга у поста «Маршрут» по ART-016 (карта отмели `Briefing.table_xz`, отрезки
  маршрутов `segments`, переход `Fade`, иконки мест `textures/places/<ключ>.png` — `icon_path`; рисует `SonarView.show_briefing`, `main.brief`; карточка выбранного маршрута — `Briefing.card_lines`/`card_rect`,
  экранная надпись `scripts/game/route_card.gd`, `main.route_card`). `run.gd` — маршрут забега (`main.run`: места `Run.PLACES` по карте ART-005, маршруты `Run.ROUTES`, пост «Маршрут» `Main.ROUTE_POST` справа от голостола — `cycle`, точки `update`, строка `status`, точка на голограмме `SonarView.show_waypoint`; после маршрута — «глубже или наверх»: `Run.opinions`, `vote_nav`, `go_deeper`, итог `finish`, `main.open_vote`/`decide`, панель `scripts/game/vote_panel.gd`; поля голосования над столом — `vote_holo.gd` (`VoteHolo.votes`), рисует `scripts/game/vote_view.gd`, `SonarView.show_vote`; голоса игроков у стола (кооп) — `ballot.gd` (`main.ballot`: большинство, таймер `Ballot.TIME`, метки `Main.vote_marks`; кольцо таймера над столом — `VoteHolo.ring_arc`, `VoteView.timer`); итог над столом — `Run.summary`, `VoteHolo.result_wanted`, `SonarView.show_result`, иконки строк ART-026 — `textures/summary/`, `VoteHolo.summary_icon`). `flyby.gd` — камера с борта (`main.flyby`, узел `main.flyby_cam`: облёт `Flyby.Kind.START` в начале забега — касание пропускает, вид при всплытии `SURFACE` — путь и стоянка `SURFACE_HOLD`, кончается сам, кнопка пропускает; тесты и снимки выключают облёт — `Main.intro = false`). `warmup.gd` — прогрев шейдеров при старте (`main.warm`, `Main.warming()`: шторка «Погружение…», камера оглядывает корабль `Warmup.VIEWS`, скрытые узлы корабля и панели интерфейса показаны на кадр, частицы корабля выпущены, два кадра снаружи камерой облёта `Warmup.OUTSIDE`, прожектор и вспышка разряда всегда в сцене — гаснут энергией `Searchlight.DARK`, не прячутся (один набор огней), каждая внешность экипажа; время кадров — «прогрев по кадрам» в логе тестера; тесты — `Warmup.enabled = false`, новое скрытое до события тоже прогреется). `net_snap.gd` — снимки для сети без сокетов (`NetSnap.frame`/`apply_frame` — корабль, реактор, корпус, свет, экипаж плотно `pack_member`; события пробоины и ила — `events`/`apply_events`, маршрут, голосование и итог — `run_state`/`apply_run` (у гостя — `Main._client_run_view`), сообщение для всех — `main.announce`; ввод — `Crew.Pad.snapshot`/`apply`); транспорт — `net_link.gd` (ENet без узлов: `NetLink.Host` — `start`, `poll` → события join/leave, ввод гостя `Guest.pad`, место `Guest.index`, `due`/`send_frame`; `NetLink.Client` — `join`, `poll` → свежий кадр, `me`, `send_pad`, `label`; хост в игре — `main.host_game`, гости — `main.net_mates`; клиент в игре — `main.join_game`, `main.net_client`: шаг корабля не считает, `Main._client_step` — ввод хосту и кадр в корабль и экипаж, свой игрок `crew[client.me]`; показ между кадрами хоста — `net_smooth.gd`, `main.net_smooth`: `NetSmooth.push`/`step`/`apply`, отставание `DELAY`). `shader_key.gd` — разные шейдеры сцены (`ShaderKey.of`/`collect`, потолок корабля в `test_shader_key`; образцы материалов `ShaderKey.glass`/`flakes` — новый материал корабля сначала брать из них, отчёт — `tools/shaders.gd`). Сообщение на приборах — `main.say(текст)`, части строки — `main.status_parts()`.
- `scripts/game/` — узлы: `main.gd` (сборка сцены, шаг игры `step(dt)`, пилот), `bridge_view.gd` (оболочка, стекло, модели,
  колесо `set_wheel_turn`), `ocean_view.gd` (дно, лёд, морской снег, вода по глубине `apply_water`), `searchlight_view.gd` (свет и конус луча,
  `apply(on, k)`), `touch_overlay.gd`, `qa_runner.gd`. Шейдеры — `shaders/`.
- Посты кнопки действия — `Deck.posts()` (штурвал, энергия, сканер, люк), действие — `Main.use_post(id)`,
  подпись на кнопке — `Main.POST_BUTTON`. Препятствия на полу — `Deck.OBSTACLES` (круги) и прямоугольники `*_RECT`.
- Слои света: отмель — слой 1 (`OceanView.LAYER_WORLD`, свет сквозь лёд), корабль изнутри — слой 2 (`LAYER_SHIP`, только
  плафоны). Новые детали корабля ставить на слой 2, иначе их осветит «солнце» сквозь потолок.
- Сценовые тесты двигают игру через `main.step(dt)` с ровным шагом: в headless кадры идут без пауз, на `await frames` время почти не идёт.
- **Оси Godot совпадают с браузерным прототипом**: y вверх, нос корабля в −Z, правый борт +X. Числа из `js/` переносим
  без смены знака; в Unity-коде pogrujenie x стоит со знаком минус — при переносе оттуда знак x меняем обратно.
  Поворот: `rotation.y` растёт — поворот влево; у игрока и корабля yaw = 0 — лицом к −Z.
- Модели художника (GLB из Meshy) лежат в `models/` и грузятся Godot напрямую, без конвертации. Голубые огни их текстур
  (#67DDEB) зажигает `BridgeView.light_texture` (шейдер `shaders/tex_glow.gdshader`, маска — `TextureGlow`, список моделей там же).
- Свои меши: лицевая сторона треугольника — обход по часовой стрелке, если смотреть на неё
  (векторное (b − a) × (c − a) смотрит внутрь).
- Экспорт: `export_presets.cfg`, пресет «Android» (arm64-v8a и x86_64 для эмулятора), подпись — `android/debug.keystore`
  (отладочный ключ, пароль `android`, в репозитории намеренно — чтобы APK обновлялся поверх).

## Тесты и проверка
- **Каждая новая фича или исправление приходит с тестами**; исправленный баг закрепляется тестом, который без исправления
  падает. Тесты детерминированные.
- Тест — файл `tests/test_<что>.gd`, `extends TestCase`, методы `test_*`; проверки `ok`, `eq`, `near`; сценовые тесты
  создают узлы в `tree.root` и ждут кадры `await frames(n)`. Ошибка движка во время теста тоже валит тест.
- Запуск в облачной сессии (Godot ставится за минуту, см. ниже):
  - `godot --headless --path . --import` (после новых файлов и моделей), затем `godot --headless --path . -s tests/run.gd`
    (фильтр: `-- test_helm` или часть имени теста);
  - картинка: `xvfb-run -a -s "-screen 0 1600x720x24" godot --path . --rendering-driver opengl3 --resolution 1600x720 -s tools/shot.gd -- out.png z=-3 yaw=0`
    (ключи — в `tools/shot.gd`), смотреть через Read. Сцену после изменений смотреть глазами, не только тестами.
- Поставить Godot в сессии: скачать `Godot_v4.7.2-stable_linux.x86_64.zip` с GitHub releases godotengine/godot,
  распаковать, `ln -s …/Godot_v4.7.2-stable_linux.x86_64 /usr/local/bin/godot`. Android SDK в сессии нет (`dl.google.com` закрыт),
  APK собирает только CI.
- CI «Godot» (`.github/workflows/godot.yml`): «Тесты» и «Сборка APK» (артефакт `deepdive-apk`) идут **параллельно**;
  релиз `apk-latest` — отдельный job «Релиз» после обоих зелёных, только на `main`. PR сливается, когда тесты и APK зелёные.
  Импорт проекта кэшируется (`.godot`), поэтому прогон быстрый. Если в PR нет кода (только `art/`, `qa/`, `*.md`, картинки
  и html в `docs/`), job «Что изменилось» пропускает тесты, APK и релиз — «skipped» тоже считается зелёным.
  Тогда `apk-latest` не пересобирается; ручной запуск (Run workflow) на `main` пересобирает его, на ветке — даёт артефакт.
  Фикс из открытой PR можно проверить на устройстве до слияния по артефакту (`tools/qa/run-qa.ps1 -Pr`, см. `docs/QA.md`).

## Задачи художника и тестера — GitHub Issues
`main` хранит текущее состояние, задачи — в Issues, работа приходит короткими PR. Долгоживущих веток у художника
и тестера нет. В начале каждой сессии — открытые issues и PR (REST: `gh api "repos/garrimajo5/DeepDive/issues?state=open"`,
`gh api repos/garrimajo5/DeepDive/pulls`; GraphQL из сессии закрыт).

**Художник (Codex)** — правила для него: `AGENTS.md`, `art/ARTIST.md`.
- Заказ — issue с меткой `art` или `model`: назначение, исходник, размеры, что сдать, бюджет, критерии приёмки.
  Держать 3–5 открытых заказов; модели заказываем только по принятому концепту.
- Метки состояния: «в работе», «на приёмке» (ставит художник), «правки», «ждёт владельца» (ставим мы).
- Работа приходит PR из ветки `art/<номер>-<кратко>` с `Closes #N`. Приёмка — в той же PR: посмотреть каждый файл
  глазами (модель — ещё и в Godot), лучшие картинки перенести в `docs/concept-art/` под понятными именами с заметкой
  `<имя>.md` (раздел «Решения и привязка к игре»), GLB — в `models/`, черновую папку `art/<номер>-…/` удалить,
  слить PR — issue закроется. Правки — метка «правки» и список в комментарии; художник дописывает в ту же ветку.
- Решения по уже принятым заказам — в `docs/concept-art/*.md` и `docs/concept-art/prinyatye-zakazy.md`.

**Тестер** — порядок для него: `docs/QA.md`, скрипты — `tools/qa/` (меняем вместе с управлением и экранами;
  `*.ps1` — UTF-8 с BOM, иначе Windows PowerShell 5.1 ломает кириллицу, тест `test_qa_tools`).
- Сценарий прогона — `tools/qa/scenario.json`: игра сама проходит шаги (`scripts/core/qa_script.gd` — шаги,
  `scripts/game/qa_runner.gd` — выполнение, если есть `user://qa/scenario.json`). Новая фича, которую видно с телефона, —
  шаги в сценарий (тест `test_qa` прогоняет его целиком). Проверить в сессии: положить сценарий с шагом `quit`
  в `~/.local/share/godot/app_userdata/Погружение/qa/scenario.json` и запустить игру под xvfb — результат в `qa/out/`.
- Ошибка с устройства — issue с меткой «баг» и меткой потока (существа, флора, места — «поток Б»). Такие задачи идут раньше
  ROADMAP своего потока, падения и неработающее управление — первыми. Отчёты тестера разбирает поток А.
- PR с исправлением: `Fixes #N` не пишем — пишем «По issue #N» и закрепляем ошибку тестом. Дальше по тому, как баг виден:
  - **Видно тестом** (логика, состояние, геометрия, тайминг — в снимке не разглядеть): закрываем issue **сразу при слиянии
    фикса**, со ссылкой на тест. Метку «проверить» не ставим — к тестеру такое не идёт.
  - **Видно только на устройстве** (кадр, читаемость, частота кадров): ставим метку «проверить» — подтверждает тестер.
- **Баги с меткой «проверить» закрывает тестер** после подтверждения на устройстве — комментарием «Проверено на
  `<коммит>`, `<устройство>`» в самом issue и закрытием, отдельным действием. Если тестер подтвердил баг в `report.md`,
  но issue не закрыл, его **закрывает поток А при слиянии этого отчёта** (ниже) — строка «Проверено на…» и есть основание.
  Так закрытие привязано к слиянию отчёта и не повисает: issue не остаётся открытым, когда починка давно подтверждена.
- Отчёт приходит PR из ветки `qa/<папка>` с папкой `qa/<папка>/` (`report.md` и JPEG-скриншоты). При разборе: прочитать,
  **закрыть каждый issue, помеченный в отчёте «Проверено на…»** (раздел «Issues проверить»), завести недостающие issues,
  слить. Если тестер только запушил ветку — открыть PR самим.

## Потоки
Работают два аккаунта Claude параллельно, каждый — по своему разделу `ROADMAP.md`. Архитектура и границы — `docs/ARCHITECTURE.md`.
- **Поток А — корабль:** посты, системы (ход, реактор, прожектор, сонар, разряд, корпус), отсеки, события, сценарий
  тестера, приём отчётов тестера, заказы и приёмка художника кроме живого мира. Ветки `feat/a-…`, `fix/a-…`.
  Файлы: `scripts/core/*.gd`, `scripts/game/*.gd`, `shaders/`, `tools/`, `docs/` (кроме заметок концептов существ).
- **Поток Б — живой мир отмели:** фауна, флора, места на дне, реестр видов, заказы художнику на существ и места (issues
  с меткой «поток Б»: заводит и принимает поток Б, по правилам раздела «Художник»). Ветки `feat/b-…`, `fix/b-…`.
  Файлы: `scripts/core/eco/`, `scripts/game/eco/`, `tests/test_eco_*.gd`; модели существ в `models/`, заметки концептов
  существ и мест в `docs/concept-art/`.
- **Связь — только `scripts/core/eco/eco_link.gd`:** корабль даёт миру `ShipState`, мир возвращает события (удар, тянет
  энергию, существо рядом, сообщение), `Main.on_eco_event` решает, что они значат. Новое поле или событие — одна PR
  с обоими концами и тестом `tests/test_eco_link.gd`; если это задача другого потока — issue с меткой его потока.
- **Общие файлы** (`main.gd`, `CLAUDE.md`, `ROADMAP.md`, `CHANGELOG.md`, `tools/qa/scenario.json`, `docs/ARCHITECTURE.md`):
  меняем минимально и только свои строки — отметку задачи, строку изменений, шаг сценария. Поток Б в `main.gd` не пишет:
  всё, что ему нужно от корабля, — через `EcoLink`.
- Чужие PR не трогать. В каждом потоке открыта не больше одной своей PR (не считая приёмки художника); перед слиянием —
  свежий `main` и зелёный CI. Ошибка в чужом коде — issue «баг» с меткой потока-владельца, а не правка.
- Метки issues: «поток А», «поток Б» — чей это заказ или ошибка. Без метки — поток А.

## Процесс
- Ветка `feat/<a|b>-<кратко>` или `fix/<a|b>-<кратко>` от свежего `main` (буква — поток). Одна задача из `ROADMAP.md` = одна PR: что сделано, как проверено
  (тесты, скриншоты). В той же PR — `[x]` в `ROADMAP.md` и строка в `CHANGELOG.md`.
- После зелёного CI PR сливается в `main` (squash). Владелец разрешил сливать самостоятельно.
- Перед пушем — `git fetch` своей ветки: если в ней чужие свежие коммиты Claude (вторая сессия), влить их, не перетирать.
