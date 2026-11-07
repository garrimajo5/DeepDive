# ART-083 — прядь инеевой бахромы
Issue: #922. Основа main: d5caec1e87020ed52080f1e8d8ce012c53a0fdb1.
Принятый исходник: docs/concept-art/inevaya-bahroma-list.png и inevaya-bahroma-i-mol.md (ART-080).

## Файлы
- pryad-cvet.png — 256×1024 RGBA, прямой alpha, корень сверху, свободный конец снизу.
- pryad-maska.png — 256×1024 RGB с одинаковыми каналами (чёрно-белая), тот же UV; щель и узлы ярче краёв.
- pryad-normal.png — 256×1024 RGB, tangent-space OpenGL (+Y вверх); нейтральный фон (128,128,255).
- preview.png — 1600×1100, по пять прядей без свечения / с маской × #67DDEB. Вертикальные масштабы 1 / 0,6 / 0,35 / 0,6 / 1. Фон #0B1C24, без bloom. Ширина увеличена для проверки текстуры, это не физический масштаб в мире.
- src/pryad-source.png — исходная генерация; src/export.ps1 — воспроизводимый экспорт, Windows PowerShell 5.1 + System.Drawing, без внешних пакетов.
Запуск из папки репозитория:
powershell.exe -NoProfile -File art/ART-083-bahroma-pryad/src/export.ps1 -Source art/ART-083-bahroma-pryad/src/pryad-source.png

## Строение и решения
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
