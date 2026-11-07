# ART-083 — прядь инеевой бахромы

Принято 07.11.2026 (PR #1353, issue #922). Исходник — ART-080 (`inevaya-bahroma-list.png`, `inevaya-bahroma-i-mol.md`).
Лист проверки — `inevaya-bahroma-pryad.png` (пять прядей без свечения и с маской × `#67DDEB`, длины 1 / 0,6 / 0,35).

## Решения и привязка к игре
- Карты — `models/inevaya-bahroma-pryad-cvet.png` (RGBA, альфа — силуэт), `-maska.png` (след ярче на узлах и щели),
  `-normal.png` (OpenGL, Y вверх); все 256 × 1024, сжаты для видеокарты, нормали — режимом нормалей.
- Встроено в `FringeView` (`scripts/game/eco/fringe_view.gd`): процедурный рисунок пряди заменён картами на тех же UV
  (u — поперёк, v — от корня). Силуэт в альфе, поэтому полоса ровная, в `SPAN` = 2 раза шире нити (0,28 м): стебель
  на карте — ≈ 1/8 полосы (≈ 3,5 см), средние узлы 0,1–0,2 м, верхний у льда до 0,25 м. Прозрачность — альфа карты
  (до 0,8) × 0,75. След касания — маска × `#67DDEB` через `eco_bio`, как и был. Треугольников и вызовов не прибавилось.
- Узлы по V (доли от корня) — `FringeView.NODES`: 0,09; 0,27; 0,41; 0,54; 0,66; 0,80; 0,91.
- Проверить на телефоне: пряди читаются в луче и в свете сквозь лёд (на мипах дальние нити — тонкие линии), след
  виден без bloom.

## Строение (заметки художника)
Шесть основных мягких ромбовидных узлов и седьмой небольшой перед свободным концом.
Центры V от корня (верх PNG = 0): примерно 0,09; 0,27; 0,41; 0,54; 0,66; 0,80; 0,91.
Полупрозрачность исходника сохранена и умножена на 0,80. В прозрачных пикселях RGB продолжен цветом тела, без чёрной подложки.
Маска строится из того же силуэта и центральной щели. Нормаль — из сглаженного рельефа поперечного сечения и впадины щели, цветовой шум в неё не попадает.
Самостоятельно выбраны нерегулярные интервалы узлов и сила рельефа. Лор и поведение не менялись.
Палитра: #86BCCB, #9AD9E8, #D9EDF2, #294651, #67DDEB, #0B1C24.
Плоская прядь предназначена для существующих полос MultiMesh; качание/след выполняет существующий шейдер.

## Генерация
Встроенный image_gen, transparent_background=true, принятый ART-080 как reference.
ID локального результата: exec-72be32f0-5531-42a5-9aa4-980ede3a81c1.
Промпт:
Generate production game texture, stylized-concept. Reference only: accepted alien frost fringe anatomy at bottom right. Single vertically hanging soft flattened pale blue translucent living filament, root at top and fraying taper at bottom, exactly six irregularly spaced soft diamond-shaped swellings and a narrow longitudinal central slit. Straight enough for a flat UV strip. Not an icicle, not seaweed. Entire single filament isolated on actual transparent background, no ice, no scenery, no text, no light bloom, no cast shadow. Very tall narrow strand centered, occupy full height, width about 15% of canvas. Subtle soft rounded tissue relief; cold blue palette #86BCCB #9AD9E8 #D9EDF2. Provide standalone strand image suitable for reducing to 256x1024.

Генератор добавил небольшой седьмой узел — оставлен в пределах требования 5–7. После генерации выполнен технический экспорт карт и листа.

## Проверка и ограничения
Просмотрены все четыре итоговые картинки: положение узлов/щели совпадает, края чистые на #0B1C24, подписи читаются.
Размеры и формат проверены повторным открытием PNG; все файлы меньше 2 МБ.
Нормали вычислены со знаком +Y вверх; шум генерации не используется как height.
Превью — иллюстрация маски с alpha, не снимок из Godot и не замер на телефоне. При встройке проверить при реальном масштабе 8–20 м, освещении и mipmapping; ширину/силу normal подобрать на существующем материале.
Свободный конец тонкий и неровный, но без широко расходящихся отдельных волосков. Это ограничение текущей генерации.
