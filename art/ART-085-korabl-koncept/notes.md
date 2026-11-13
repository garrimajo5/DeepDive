# ART-085 v2 — экспедиционный батискаф

Заказ #1788, встреча #1754; существующая ветка art/ART-085-korabl-koncept, PR #1801.
Исходный main ветки: bba84091. Правила и обновлённый объём сверены с origin/main **44b90e22** (13.11.2026).

**Предварительный комплект одной новой конструкции для проверки ГД и UX.** Направление выбрано владельцем; размеры ниже предлагаются впервые и ещё не утверждены. Это не рабочая документация, не сертификат прочности и не разрешение встройки. Старые десять листов и их notes.md сохранены без изменения содержания в `v1-staraya-shema/`. Старые вопросы Р-2 и камеры 6 сняты новым объёмом, не блокируют v2.

## Комплект

| Файл | Содержание |
|---|---|
| 01-v2-batiskaf.jpg | Внешний 3/4: округлый вытянутый корпус, три малых носовых порта, нижняя рабочая ниша, техническая корма; человек 1,8 м для ориентировочного масштаба |
| 02-v2-razrez.png | Боковой разрез: кожух, условный прочный объём, одна палуба, носовая зона → лаборатория → жилой отсек → технический; всё внутри внешнего габарита |
| 03-v2-plan.png | Общий план и отдельная схема четырёх постов с путями соло; обе оси каждого плана в одном масштабе |
| 04-v2-pilot.jpg | Вид сидящего пилота: два коротких органа под руками, прямой обзор через три порта и два малых экрана камер |
| 05-v2-nosovaya.jpg | Общая рабочая зона с четырьмя людьми: пилот впереди, инженер слева, биолог справа, сонар у общего стола |

## Одна конструкция и её назначение

Вытянутый обтекаемый кожух со светлыми защитными панелями закрывает тёмную силовую раму и округлый прочный объём. Верхняя часть — запас под плавучесть и коммуникации; обитаемая палуба над нижней мокрой нишей. Под носом два сложенных инструмента, контейнер и камера с подсветкой; в корме два защищённых движителя, как на внешнем рисунке. Полозья защищают нижний край. Это рабочий исследовательский аппарат и убежище на кампанию, без оружейного силуэта.

Носовая зона общая: каждый видит коллег, но информация остаётся распределена между отдельными постами. За ней лаборатория, четыре спальных места (две пары по бортам), техническое помещение. Короткий центральный путь соединяет отсеки без ступеней. В носовой зоне путь разветвляется вокруг стола; переход между постами не требует выхода в коридор. Быт и лабораторное оборудование на данном этапе показаны блоками, без деталировки.

ГД выбрал умеренное остекление вместо старого плоского окна. Центральный круглый порт предлагается Ø1,1 м, боковые Ø0,8 м, с толстыми посадочными рамами; положение пилота близко к центральному порту. Прямой обзор ограничен рамами и не заменяет круговой обзор. Малые экраны внешних камер дополняют его; необходимость, режимы и интерфейс камер ещё проверяют ГД/UX. На рисунках экраны — условные схемы, **не замена принятому ART-061**, не новый интерфейс и не пакет для встройки. Штурвал-колесо не сохраняется: две короткие рукоятки, кнопки света и вертикали в зоне кисти.

## Предложенные числа — не решения владельца

Координаты схем: метры, Y вверх, нос −Z; пол обитаемой палубы y=0. Внешняя высота от y=−5 до +4. Это новая система, не координаты старой сцены.

| Параметр | Предложение v2 | Следствие / проверка |
|---|---|---|
| Полный габарит со сложенным оборудованием | 28 × 10 × 9 м (длина × ширина × высота) | Длина −12,5% относительно 32 м из world.md. Мир пока не меняется |
| Сопоставление с фактическим HullPlan | Было 34,2 × 13,6 м по журналу паспорта | Новый прямоугольный след 28 × 10 м короче и уже, но это ещё не новая коллизия |
| Носовая рабочая зона | z −11…−3, ширина до 6,6 м | Передняя стенка округлая, высота падает у краёв; рабочий потолок около 2,8 м |
| Лаборатория / быт / техника | z −3…2 / 2…7 / 7…10,5 | 3 последовательных люка, одна палуба |
| Люки / проходы | 1,2 × 2,1 м / целевой минимум 1,0 м | Проверить капсулой игрока, открыванием люков, креслами и встречным проходом |
| Пилот | x0, z−10,2; глаз сидя примерно 1,33 м | Точный вынос к порту и обзор требуют макета; иллюстрация не замер углов |
| Инженер / биолог | x−2,1 / +2,1, z−7,7 | Чуть позади пилота, консоли наклонены; взаимный обзор с поворотом головы |
| Общий стол / сонарщик | центр x0,z−5,2; Ø1,3 м / место у кормовой кромки z−4 | Два обхода; оператор может работать со стороны кромки |
| Комфортная досягаемость | ориентир 0,55 м от плеча | На плане круг — только проекция, не доказательство полного движения руки |

Внешний 3/4 и интерьер — художественные перспективы этой компоновки; численные габариты читаются со схем, а не измеряются по пикселям перспективных иллюстраций. Места креплений, толщины, позы, углы и окончательный масштаб панелей будут уточняться после проверки крупной конструкции. Бортовые вспомогательные огни/вентиляционные элементы внешнего вида не являются дополнительными обзорными окнами носовой зоны.

### Разворот и врата

- Для прямоугольного следа 28 × 10 м с поворотом **вокруг геометрического центра** геометрический радиус охватывающего круга = sqrt(14²+5²) ≈ **14,87 м**, диаметр ≈ **29,73 м**. Это консервативная геометрическая оценка для сложенных инструментов, **не динамический радиус разворота**: скорость, инерция, управляющие силы, фактический pivot и запас безопасности ещё не заданы.
- При условно прямоугольном проходе 07 **48 × 30 м**, строго по центру и без крена: запас по ширине (48−10)/2 = **19 м на сторону**, по высоте (30−9)/2 = **10,5 м**. Это только проверка габаритной рамки.
- В паспорте есть уточнение, что по силуэту арки высота около **22 м**, а 30 м было ошибкой замера по подписи. Для 48 × 22 получается **6,5 м** вертикального запаса. Применять более строгую рамку до ответа уровней; реальная арка не прямоугольник, и годность по этим вычитаниям не доказана.
- Перед поворотом к 08 весь корпус должен выйти из арки. Укорочение корпуса уменьшает требуемое место, но не разрешает поворот внутри врат автоматически. Потоку А и уровням после выбора размеров проверить полный swept volume, полозья, кормовые движители, крен/дифферент и маршруты 00–08; отдельной оценки требуют теснины следующих слоёв.

## Что предлагается изменить

| Решение v2 | От старого к новому | Кто проверяет до реализации |
|---|---|---|
| Н-1 | Прямоугольная схема старого мостика → округлый экспедиционный аппарат, новая оболочка и палуба | Владелец после ГД/UX; затем поток А и уровни |
| Н-2 | Большое окно → три ограниченных порта + вспомогательные камеры | ГД/UX: ощущение океана, читаемость наблюдений, функции камер |
| Н-3 | Большое колесо → два коротких органа, компактный пульт | UX, анимации и поток А после утверждения; чужую #727 не меняем |
| Н-4 | Посты у стен → общая носовая рабочая зона и стол с обходом | UX: позы, взгляд, коллизии; ГД: обмен сведениями и соло |
| Н-5 | Новый порядок отсеков и небольшой быт | ГД: темп перемещений; это предложение компоновки, не механика сна |
| Н-6 | Нижняя рабочая ниша, инструменты, пробы | Концепт назначения, не разрешение вводить новые действия/собирательство |

## Материалы и свет

| Материал | Где и зачем | Hex | Примерная roughness |
|---|---|---|---|
| Светлая защитная облицовка | Крупные внешние панели, чистые внутренние поверхности; читаемая человеческая техника | #B8B5AA | 0,65 |
| Тёмный окрашенный металл | Рама, рёбра, основания; отделяет узлы и несёт крепления | #303A40 | 0,72 |
| Охристая краска | Сервисные крышки и органы, небольшие акценты | #A9864C | 0,62 |
| Матовая резина | Хваты, уплотнения, опоры | #242A2C | 0,9 |
| Стекло | Малые порты, приборы | #93C3CC | 0,12 |
| Тёмный настил | Проходы, нескользкая поверхность | #434847 | 0,85 |

Тёплые локальные плафоны внутри, мягкая подсветка прохода; холодный океан непосредственно виден через порты. Информация — сдержанный голубой #67DDEB. Внешняя рабочая подсветка — белая, а не декоративная цветная лента. При аварии предлагается гасить обычный рабочий свет, сохраняя низкую навигационную подсветку и принятый аварийный сигнал экранов; окончательная связь с системой питания — отдельная проверка потока А. Красные декоративные огни не добавляются.

Износ только в местах хвата, краях сервисных крышек и настиле; чистые крупные поверхности сохраняются. Надписи функциональные, названий видов нет. Экипаж в иллюстрациях — масштабные фигуры в рабочей одежде, не новый дизайн персонажей или замена MOD-012.

## Для следующего этапа 3D

Собирать из 1 округлого вытянутого объёма, носовой оболочки, кормового блока, примерно 8–12 крупных панелей, нескольких поперечных рёбер, 3 рам портов, 2 полозьев, 2 блоков движителей, 1 ниши с 2 сложенными инструментами и контейнером. Внутри отдельные блоки четырёх постов и 3 перегородки. Подвижные части потенциально — рукоятки, ползунки, кресла, люки; инструменты пока только сложены. Точный poly-budget назначается отдельным MOD-заказом после выбора владельца; сейчас модели не создавались.

## Проверка и пределы сдачи

Пять новых листов покрывают новый предварительный объём: внешность, внутренний объём, проходы и роли, пилот, совместная рабочая зона. Схемы сохраняют один полный габарит и последовательность отсеков. Проверены глазами экспортированные картинки; PNG/JPEG декодируются и меньше 2 МБ каждый. Код игры, мир, UI и чужие ветки не менялись.

Для ГД/UX: оценить крупную архитектуру, соотношение прямого/камерного обзора, роли и пути соло; подтвердить либо поправить предложенные числа. После этого владелец оценивает конструкцию. Реальный обзор, позы рук, столкновения, прочность, масса, плавучесть и глубинные материалы **не проверены симуляцией**. Деталировку и модели до этой оценки не заказывать.

## Инструменты и воспроизведение

Встроенный imagegen (не CLI): внешний вид, общий интерьер и вид пилота. Сводка промптов ниже; исходные формулировки сохранены в разделе «Промпты». Python 3.12 / Pillow 13, Windows PowerShell 5.1: схемы и экспорт с русскими подписями. Изображения не скачивались как готовый арт; использованы собственные генерации этого запуска. Предыдущие иллюстрации не служили основой новой архитектуры.

## Промпты — встроенный imagegen

### 1

Use case: stylized-concept. Create a professional preliminary ship design concept for the game Погружение, landscape 16:9. ONE expedition bathyscaphe, entirely new elongated rounded architecture, not a boxy submarine room. Three-quarter front-left view, nose on left, entire vessel visible on dark blue studio background with subtle ground plane. Proposed overall dimensions 28m length x10m width x9m height, silhouette elongated not squat. Pale warm grey protective buoyancy/fairing panels over charcoal structural ribs, a few ochre service panels, low technical tail with two guarded ducted thrusters. Rounded occupied pressure hull inside fairing. Three modest round thick-rimmed observation ports across the protected upper nose (central port 1.1m diameter, side ports .8m), NO large panoramic glass. Below nose a recessed working bay containing two folded short manipulators, sample box and small camera/light pods, tools entirely within hull envelope. Two low skid rails below, no legs, no weapons, no conning tower. Interior arrangement implied: forward shared work room, then lab, small living compartment, technical stern. Human 1.8m standing as scale silhouette beside front skid on ground, no diving scene. Broad simple readable forms, controlled detail, credible assembled futuristic expedition equipment, atmosphere of durable human refuge. Cold rim lighting, warm metal highlights. Only text: small ship stencil 'КОВЧЕГ-7'. Leave clear dark margin for later captions. Not a technical certification. No logos, no species names. Make exact distinctive design easy to repeat in interior views and diagrams.

### 2

Edit this concept image. Preserve exact vessel silhouette, body, all panels, lower work recess, tools, thrusters, framing, lighting and typography. Correct scale only: reduce the standing human silhouette height to HALF its current height, keep feet on same ground line. Shrink EACH of the three round nose windows to 55% of its current diameter, preserving each center point and thick structural rim; fill surrounding former window area with matching pale fairing. Thus these are small observation portholes, not giant room windows. No other changes. Landscape 16:9.

### 3

Precise single change to this ship concept: make ONLY the small standing human silhouette at far lower left 1.4 times as tall as it is now, feet anchored to exactly same ground position. Target human about110 pixels tall relative to this1672x941 reference, so it reads as1.8m beside a roughly9m high vessel with perspective. Preserve every pixel of the ship design as closely as possible, small windows, panels, folded tools, lighting, text, entire composition. Do not change ship or add elements.

### 4

Use case stylized-concept. New interior companion view of the SAME expedition bathyscaphe in reference (reference is exterior design only, do not copy its camera). Landscape16:9 professional preliminary concept, clear broad shapes rather than decoration. Camera at rear entrance of forward work compartment, standing eye1.65m, looking forward down its center, show four human crew1.8m scale. Room roughly8m long x6.6m clear width x2.8m clear ceiling, rounded ribs, pale warm grey panels, dark structure, muted ochre accents, low warm service strips, dark floor. At the very front: central seated pilot close to three SMALL thick circular observation portholes (center diameter1.1m, two side .8m), all at seated eye level; NO huge windows. Show cold blue ocean through portholes, no creatures. Pilot chair has two armrest controls and low slim screen, no wheel. Behind and to pilot left: engineer seated at compact console oriented toward nose, five physical energy sliders. Behind and right: biologist seated at separate compact forward-oriented screen. Third/foreground station a low circular sonar/navigation table1.3m diameter centerline, one standing crew at rear edge. FOUR people total, neutral tan work clothes, no flashy spacesuits. Two clear side passageways at least1m wide around table linking the entry, both side posts and pilot; no cables crossing floor. Colleagues can see each other by turning heads. Hands visibly on reachable controls. Small camera-feed screens supplement the ports, not a wall-sized screen. Screens show abstract cyan traces, no readable UI claims. Only functional Russian station labels 'ПИЛОТ', 'ЭНЕРГИЯ', 'БИОЛОГ', 'СОНАР'. Light restrained, human warm refuge against cold ocean. Ceiling hugs hull curvature; room must fit the exterior. No giant holograms, no architecture from previous rectangular ship. Keep exact three portholes and no other windows.

### 5

Edit only the left engineer and right biologist workstations and their seated people in this interior. Both side consoles must be freestanding angled units facing diagonally forward toward the center nose portholes, about45 degrees inward from their current wall-facing orientation. Rotate each seated person and chair with their console so their gaze is toward front/center, not into the side wall; show their backs in three-quarter view, hands reaching controls. Keep side stations behind the pilot, preserve clearly open passages between side seats and sonar table. Keep EXACT same room, three portholes, scale, pilot, foreground sonar station and standing woman, lighting, materials, labels and composition. Do not add people or windows. This is a single coherent ship, not a new design.

### 6

Use case stylized-concept, new camera view of EXACT SAME forward cabin in reference. Create landscape16:9 first person SEATED PILOT EYE VIEW. Reference is the exact cabin design: preserve three round thick-rimmed portholes, central1.1m and side .8m, pale warm-grey panels and dark ribs, ochre pilot console, warm low strips. Camera at seated eye1.33m close to center port, looking straight forward. Ocean blue and faint suspended particles visible directly through the modest central port; two small side ports also visible. Bottom foreground show seated pilot's tan-sleeved forearms resting on two armrests and hands on two short compact joysticks within comfortable reach, no wheel. Joystick thumb buttons marked 'СВЕТ' and 'ВЕРТИКАЛЬ'. Three small low screens below sill: abstract cyan navigation/status center; small camera views left/right. Do NOT make these screens huge or cover direct view. Center screen has thin amber alarm perimeter and subtle separate line, no species words or invented detailed UI. Functional engraved labels 'ХОД', 'КАМЕРА', 'СВЕТ', 'ВЕРТИКАЛЬ'. Preserve medium sized structural circular ports rather than panoramic windshield; window bottom remains above console. Fine controlled detail, believable hand posture, atmosphere of warm refuge in cold alien ocean. No HUD, no new windows, no side characters, no weapons. All important controls reachable without leaning. Only one pilot with two hands.


<details><summary>Воспроизводимые схемы: Python 3.12 / Pillow 13</summary>

Сохранить блок как draw_v2.py в корне репозитория и выполнить `python draw_v2.py`. Шрифт Windows Arial.

```python
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import math
OUT=Path('art/ART-085-korabl-koncept')
BG='#0b1c24'; FG='#dce5e6'; MUT='#8fa6ad'; CY='#67ddeb'; AM='#e8b772'; GREY='#354953'
font='C:/Windows/Fonts/arial.ttf'
def new(title,sub):
 im=Image.new('RGB',(2048,1152),BG); d=ImageDraw.Draw(im)
 txt(d,(58,30),title,44);txt(d,(60,92),sub,23,MUT);d.line((60,133,1985,133),fill=GREY,width=2);return im,d
def txt(d,xy,t,s=24,c=FG):d.text(xy,t,font=ImageFont.truetype(font,s),fill=c)
def poly(d,pts,c=FG,w=3):d.line(pts,fill=c,width=w,joint='curve')
def dim(d,a,b,label):
 d.line((a,b),fill=CY,width=2)
 for x,y in (a,b):d.line((x-5,y-8,x+5,y+8),fill=CY,width=2)
 txt(d,((a[0]+b[0])/2-60,a[1]-32),label,22,CY)
def human(d,x,y,s=1,c=FG):
 # baseline at y, exact total 1.8 m
 d.ellipse((x-.12*s,y-1.8*s,x+.12*s,y-1.56*s),outline=c,width=2)
 d.line((x,y-1.56*s,x,y-.65*s),fill=c,width=3)
 d.line((x-.35*s,y-1.1*s,x,y-1.4*s,x+.35*s,y-1.1*s),fill=c,width=3)
 d.line((x-.2*s,y,x,y-.65*s,x+.2*s,y),fill=c,width=3)
# side section: z horizontal, y vertical, 54 px/metre
im,d=new('02 / ЭКСПЕДИЦИОННЫЙ БАТИСКАФ · РАЗРЕЗ','ART-085 / v2 · Одна конструкция · Все размеры — предложение на оценку')
s=54; ox=1030; oy=440
P=lambda z,y:(ox+z*s,oy-y*s)
outer=[(-14,-1.0),(-13,2.5),(-10,3.4),(-6,4),(6,4),(11,2.6),(14,.2),(14,-2.6),(10,-4.3),(-9,-5),(-12,-3.8),(-14,-1.0)]
poly(d,[P(*p) for p in outer],FG,4)
pressure=[(-12.6,1.5),(-11.6,2.4),(-9,3),(-5,3.4),(7,3.4),(9.7,2.7),(11,1.0),(10,-.9),(-8,-.9),(-11,-.4),(-12.6,1.5)]
poly(d,[P(*p) for p in pressure],CY,3)
d.line((P(-11,0),P(10,0)),fill=FG,width=4)
for z in (-3,2,7):
 d.line((P(z,0),P(z,2.8)),fill=FG,width=3)
 d.line((P(z,0),P(z,2.1)),fill=AM,width=7)
# simplified furniture, not structural engineering
for z in (-9.7,-6.7):human(d,*P(z,0),s)
for z1,z2,h in [(-10.9,-10.5,.8),(-2.5,.7,.95),(3.5,5.5,.6),(7.6,9.8,2.1)]:
 d.rectangle((*P(z1,h),*P(z2,0)),outline=AM,width=3)
# habitat second bunk
poly(d,[P(3.5,1.6),P(5.5,1.6)],AM,3)
# port at bow eye height
poly(d,[P(-12.6,1),P(-12.6,2.1)],CY,9)
# low work recess and folded arms
poly(d,[P(-12,-1.3),P(-6,-1.3),P(-6,-4.2)],AM,4)
poly(d,[P(-11,-3.2),P(-8.2,-2.3),P(-9,-4.0)],AM,5)
d.rectangle((*P(-7.9,-2.7),*P(-6.8,-3.8)),outline=AM,width=3)
for z in (-8,7):d.ellipse((*P(z,3.8),*P(z+1.4,3.5)),outline=MUT,width=3)
# stern duct side symbol
d.ellipse((*P(11.5,2),*P(13.5,0)),outline=AM,width=4)
d.ellipse((*P(11.5,-.5),*P(13.5,-2.5)),outline=AM,width=4)
for a in range(0,360,60):
 x,y=P(12.5,1);r=.7*s;d.line((x,y,x+r*math.cos(math.radians(a)),y+r*math.sin(math.radians(a))),fill=MUT,width=2)
for z,t in [(-10.8,'ОБЩАЯ НОСОВАЯ'),(-2.7,'ЛАБОРАТОРИЯ'),(2.3,'ЖИЛОЙ'),(7.2,'ТЕХНИЧЕСКИЙ')]:txt(d,P(z,2.6),t,19)
for z in (-14,-12,-3,2,7,11,14):txt(d,(P(z,0)[0]-15,735),str(z),20,CY)
dim(d,(P(-14,0)[0],795),(P(14,0)[0],795),'28 м')
for x,y,t in [(75,170,'Нос / −Z'),(1690,170,'Корма / +Z'),(78,860,'Габарит: 28 × 10 × 9 м'),(78,900,'Палуба y=0; 1 деление координат — 1 м'),(78,940,'Человек 1,8 м; люки 1,2 × 2,1 м'),(78,980,'Потолок 2,8 м; у краёв ниже')]:txt(d,(x,y),t,25)
for i,t in enumerate(['Голубой — условный прочный корпус; белый — внешний кожух.', 'Под носом: мокрая ниша, сложенные инструменты и контейнер проб.', 'Над корпусом — плавучесть; снизу — рама, коммуникации, полозья.', 'Две койки показаны сбоку; ещё две — на противоположном борту.', 'Прочность, плавучесть, масса и глубина применения не рассчитаны.']):txt(d,(850,860+i*39),t,23,FG if i<4 else AM)
txt(d,(60,1090),'Схема компоновки, не инженерный проект. Изоляция помещений и оборудование — предложения, не новые механики.',22,MUT)
im.save(OUT/'02-v2-razrez.png')
# plan, full envelope at 43px/m top; enlarged bridge below 75 px/m
im,d=new('03 / ЧЕТЫРЕ ПОСТА · ПЛАН И ПУТЬ СОЛО','ART-085 / v2 · Размеры в метрах · Нос слева на общем плане, сверху на увеличении')
s=43;ox=850;oy=400
P=lambda z,x:(ox+z*s,oy+x*s)
outer=[(-14,0),(-12,-3.5),(-7,-5),(7,-5),(12,-3.5),(14,-1.5),(14,1.5),(12,3.5),(7,5),(-7,5),(-12,3.5),(-14,0)]
poly(d,[P(*p) for p in outer],FG,4)
for z1,z2,label in [(-11,-3,'НОСОВАЯ ЗОНА'),(-3,2,'ЛАБОРАТОРИЯ'),(2,7,'БЫТ'),(7,10.5,'ТЕХНИКА')]:
 d.rectangle((*P(z1,-3.3),*P(z2,3.3)),outline=CY,width=2);txt(d,P(z1+.15,-2.9),label,17)
for z in (-3,2,7):poly(d,[P(z,-.6),P(z,.6)],AM,7)
# all four posts scaled
for z,x,r,c in [(-10.2,0,.35,AM),(-7.7,-2.1,.35,AM),(-7.7,2.1,.35,AM),(-4,0,.35,AM),(-5.2,0,.65,CY)]:
 px,py=P(z,x);d.ellipse((px-r*s,py-r*s,px+r*s,py+r*s),outline=c,width=3)
poly(d,[P(9,0),P(-3,0),P(-3.8,-1.4),P(-8.8,-1.4),P(-9.3,0)],AM,3)
for z in (3.5,):
 for x in (-2.5,2.5):d.rectangle((*P(z,x-.5),*P(z+2,x+.5)),outline=MUT,width=2)
dim(d,(248,660),(1452,660),'28 м')
txt(d,(1505,220),'ГАБАРИТ / ПРЕДЛОЖЕНИЕ',24,AM)
for i,t in enumerate(['Длина 28; ширина 10; высота 9.', 'Внутренняя ширина до 6,6.', 'Обитаемая палуба одна.', 'По оси: нос → лаборатория', '→ быт → техническая корма.', 'Быт: 2 × 2 койки по бортам;', 'проход посредине остаётся.', 'Общая зона: 4 поста;', 'камера не заменяет окно.']):txt(d,(1505,270+34*i),t,21)
# bottom enlarged nose plan oriented bow up, wide left panel
s=70;cx=470;cy=755
B=lambda x,z:(cx+x*43,cy+(z+10.5)*43)
# small bridge panel large horizontal? extent y755..1080
for x in range(-3,4):d.line((B(x,-11),B(x,-3)),fill='#20343d',width=1)
for z in range(-11,-2):d.line((B(-3.3,z),B(3.3,z)),fill='#20343d',width=1)
d.rectangle((*B(-3.3,-11),*B(3.3,-3)),outline=CY,width=2)
for x,z,label,off in [(0,-10.2,'1',(35,-15)),(-2.1,-7.7,'2',(-35,-15)),(2.1,-7.7,'3',(23,-15)),(0,-4,'4',(30,-10))]:
 px,py=B(x,z);d.ellipse((px-12,py-12,px+12,py+12),fill=AM)
 txt(d,(px+off[0],py+off[1]),label,24)
 # reach ellipse projected correctly unequal scales
 d.ellipse((px-.55*43,py-.55*43,px+.55*43,py+.55*43),outline=MUT,width=1)
 # desk forward
 d.rectangle((px-30,py-32,px+30,py-15),outline=FG,width=2)
px,py=B(0,-5.2);d.ellipse((px-.65*43,py-.65*43,px+.65*43,py+.65*43),outline=CY,width=3)
poly(d,[B(0,-3),B(-1.4,-4),B(-1.4,-8.9),B(0,-9.3)],AM,3)
poly(d,[B(0,-3),B(1.4,-4),B(1.4,-8.9)],AM,3)
txt(d,(85,718),'НОС / −Z ↑ · 43 px/м',22,CY)
for i,t in enumerate(['1  Пилот: два коротких органа на подлокотниках.', '2  Инженер: питание / аварийное, лицом к носу.', '3  Биолог: отдельный экран, коллеги в боковом поле.', '4  Сонар / маршрут: общий стол Ø1,3 м.', 'Янтарный — путь соло; две боковые ветви у стола.', 'Проходы ≥1,0 м; люки 1,2 м; палуба без ступеней.', 'Серый круг: досягаемость 0,55 м (проекция).', 'Поворот кресла и реальные позы проверит UX.']):txt(d,(850,740+i*43),t,24,AM if i==7 else FG)
im.save(OUT/'03-v2-plan.png')

```
</details>

<details><summary>Экспорт иллюстраций: Python 3.12 / Pillow 13</summary>

Встроенный imagegen сохраняет исходники в generated_images; пути в скрипте относятся к этому запуску. Для повторного экспорта сохранить блок как export_v2.py и выполнить `python export_v2.py` после получения этих исходников.

```python
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
out=Path('art/ART-085-korabl-koncept')
base=Path('C:/Users/FEDYA/.codex/generated_images/01a150d4-51bb-7de2-a546-c950a2e37207')
items=[('exec-538b05c3-9bf6-4436-a688-72a939ae9bfa.png','01-v2-batiskaf.jpg','01 / ЭКСПЕДИЦИОННЫЙ БАТИСКАФ · ART-085 v2','Предложение: 28 × 10 × 9 м · Человек 1,8 м · Габариты и оборудование ещё не утверждены'),('exec-6f62544f-3b10-45b0-a18d-bb58be351f2d.png','04-v2-pilot.jpg','04 / ВИД ПИЛОТА · ТРИ ПОРТА И ВСПОМОГАТЕЛЬНЫЕ КАМЕРЫ','Предварительный концепт · Органы под руками · Графика экранов условная, не замена ART-061'),('exec-99f5949f-c38e-4c78-9fcf-335ce438a676.png','05-v2-nosovaya.jpg','05 / ОБЩАЯ НОСОВАЯ ЗОНА · ЧЕТЫРЕ ПОСТА','Пилот впереди · Инженер слева · Биолог справа · Сонар у стола · Проходы — на листе 03')]
for src,name,title,cap in items:
 im=Image.new('RGB',(1600,900),'#0b1c24');d=ImageDraw.Draw(im)
 pic=Image.open(base/src).convert('RGB').resize((1472,828),Image.Resampling.LANCZOS)
 im.paste(pic,(64,36))
 d.text((64,5),title,font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',24),fill='#dce5e6')
 d.text((64,870),cap,font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',20),fill='#a4b9c0')
 im.save(out/name,quality=92,subsampling=0,optimize=True)
for f in sorted(out.iterdir()):
 if f.suffix.lower() in ('.png','.jpg'):
  with Image.open(f) as im:
   print(f.name, im.size, f.stat().st_size);im.verify()
  assert f.stat().st_size<2000000

```
</details>
