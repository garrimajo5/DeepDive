# ART-086 — гротовик

Заказ [#2135](https://github.com/garrimajo5/DeepDive/issues/2135), база `main` `52d31ed060c357958a6863982524f8fb19c7f0d4`. Для масштаба беру 6 м из заказа и `EcoGrot`; в бестиарии пока указаны 4 м. Поведение, окраска огнецвета и роль рифа сверены с бестиарием и принятым листом флоры отмели.

| Файл | Что видно |
|---|---|
| `01-list-rakursov.png` | Бок, верх, фронт и силуэт. Голова справа на боковом виде и внизу на виде сверху. Линейка относится к боковому виду. |
| `02-rif.png` | Крепление огнецвета к швам щитков, мох на плоскостях, укрытие светляка-полосника (25 см). |
| `03-pozy.png` | Шаг с мутью у опорных ног и `shy`: шесть ног убраны, нижний обод осел на грунт. |
| `04-vid-iz-nosa.jpg` | Концепт вида из носового окна на ориентировочных 25 м. |
| `05-vid-na-telefone.jpg` | Тот же кадр 1280×720 с кнопками по геометрии `Touch.Layout` для безопасной области во весь кадр. |

## Габариты и риг

- Рабочая форма для модели — купол длиной 6,0 м, шириной 4,8 м и высотой 1,1 м от нижней кромки до макушки без рифа. Обод — непрерывный пояс 0,25–0,35 м по высоте. Форма щитков, толщина обода и вылет ступней — предложения концепта. За основу ширины и высоты взят игровой полуэллипсоид `SHELL`: его запас столкновения спереди определяется отдельно.
- Рабочий просвет под ободом на полном шаге около 1,15 м. В `shy` внешняя кромка касается грунта, видимый просвет и выступ ног — 0. Это цель силуэта при анимации. Текущая процедурная схема поднимает опорную точку тела на `FLOOR_UP + LEG_UP × lift`, то есть 0,6–1,15 м над грунтом. На встройке согласовать разницу между опорной точкой и внешней кромкой, чтобы не менять коллизию случайно.
- Одна масса купола с ободом и плоскими щитками, одна короткая голова под передним краем, 6 ног по 2 сегмента и 6 клиновидных ступней. Три пары ног, 3 опоры: передняя и задняя с одной стороны, средняя с другой. Оси у корней под ободом, сгиб в среднем суставе, отдельная опора на ступне. Голова уходит внутрь на короткой шее вместе с посадкой купола. Риф закреплён на корпусе.
- 11 кустов огнецвета и 6 мшистых бугров по заказу. Считать по спецификации: число мелких ответвлений и пятен меняется между иллюстрациями. Светляк — отдельный обитатель рифа, геометрия существующей стаи. Крупные просветы между ветками оставить для укрытия.
- На «Обычно» ≤ 8 000 треугольников и 1–2 вызова отрисовки на особь. Приоритет геометрии — обод, суставы и ветки на контуре, мелкие края щитков в карте нормалей. Карты цвета, нормалей и эмиссии. На «Экономно» сохранить те же массы и просветы, убрать мелкие ветвления и неровности ступней, оставить самые читаемые точки свечения в материале.

## Палитра и свечение

`#354650` сланцевый купол, `#819096` кромки, `#223039` подбрюшье, `#B35933` огнецвет, `#59CC8C` мох, `#F6AE55` эмиссия только на кончиках огнецвета, `#EFC768` слабое свечение глаз, `#6BDCE4` полоса отдельного светляка. На дальнем плане жилки и глаза могут пропадать, но тёплые кончики, фигурная кромка купола и просвет между ногами остаются различимыми.

## Проверка

Сверил читаемость шага и укрытия по силуэту, видимые три пары ног на листе, укрытие светляка и видимость купола с телефона по листу с кнопками. Размеры листов и кадров проверены после экспорта, каждый файл меньше 2 МБ. Дистанция в кадре и муть заданы художественно. После встройки сцену следует проверить на телефоне на 20 и 30 м при штатном прожекторе: форма окна, масштаб и рассеяние зависят от камеры и среды игры.

## Генерация

Листы созданы встроенным ImageGen. Лист ракурсов использован как референс формы для рифа, поз и окна. Экспорт и контрольная разметка сделаны с Pillow 13.0.0.

<details>
<summary>Лист ракурсов</summary>

Stylized realism production concept sheet for original underwater game DeepDive. Landscape 16:9 dark uniform slate background, Russian labels exactly «СБОКУ», «СВЕРХУ», «СПЕРЕДИ», «6 м» with thin scale bar. Three clearly separated equal-size orthographic views of the SAME alien six-legged slow benthic grazer, Grotovik, a walking living reef island. Reference design: flattened symmetrical broad oval charcoal slate dome with thick sculpted continuous stepped rim and flecked overlapping mineral armor, blunt short retractable chitin brow and tiny paired amber eyes low in front, no beak, exactly six arthropod two-segment legs in three left/right pairs, broad wedge feet. Side shows three near legs visibly staggered and far three subtly offset, top shows six knees outside rim, front shows the three feet each side either offset in depth or behind. Dome crown covered in 11 short rusty branching fire-coral tufts (#b35933), soft apricot glints at selected tips, 6 squat muted green emerald moss cushions (#59cc8c), arranged in an organically integrated reef. Looks an alien walking boulder reef, no turtle anatomy or vertebrate face, no red lights. Fine material detail in service of crisp geometry, desaturated, soft overhead teal lighting. Single coherent anatomy with readable legs and feet; no decorative logos, no English or extra text. Small solid near-black side silhouette inset if space. Keep elements inset for 16:9 cropping.

</details>

<details>
<summary>Риф</summary>

Use the supplied production sheet as design reference only. Keep the exact overlapping charcoal shale plates, broad stepped lip, tiny paired amber eyes under blunt brow, three pairs of two-segment legs with wedge feet, rusty branching fire coral with peach amber tips and soft green moss patches. The same animal, realistic stylized DeepDive videogame. New landscape 16:9 production detail sheet against dark uniform slate. Tranquil subtle teal light. A single very close oblique view of the dome crown, with natural attachments of branched rust fire-coral growing from broad rooted scabs along seams, green hemispherical moss pads hugging the plates, healthy orange-apricot pinpricks at the branch tips. One small thumb-length translucent teal light-stripe fish hiding horizontally between two branches, body partly occluded, with short cyan stripe. Three modest thin annotation leaders with accurate Russian labels «ОГНЕЦВЕТ», «МОХ», «СВЕТЛЯК». Entire focus on close-up of the dorsal reef and visible lower rim. No red lights. Keep frame margin, no English.

</details>

<details>
<summary>Позы</summary>

Use the supplied production sheet as design reference only. Keep the exact overlapping charcoal shale plates, broad stepped lip, tiny paired amber eyes under blunt brow, three pairs of two-segment legs with wedge feet, rusty branching fire coral with peach amber tips and soft green moss patches. The same animal, realistic stylized DeepDive videogame. New 16:9 landscape two-panel production sheet, same animal at the same scale with nose to the right in both panels, readable even reduced to silhouette, charcoal neutral matte background. Left panel «ШАГ»: 3 near segmented legs staggered in side view, front leg lifts and curls forward, two contact feet kick up tiny low sediment wisps, far-side legs behind, body dome clearly raised above flat ground. Right panel «УКРЫТИЕ»: same dome same size, dome rim actually rests on sediment, all six legs folded fully in beneath lip with no visible protrusions, low eyes mostly in shade, coral visible on top. Teal directional editorial render with restrained highlights. Flat matching floor lines, no dividers over the silhouettes, no extra elements or text.

</details>

<details>
<summary>Кадр из окна</summary>

Use the supplied production sheet as design reference only. Keep the exact overlapping charcoal shale plates, broad stepped lip, tiny paired amber eyes under blunt brow, three pairs of two-segment legs with wedge feet, rusty branching fire coral with peach amber tips and soft green moss patches. The same animal, realistic stylized DeepDive videogame. New wide 16:9 narrative game readability keyframe. Camera inside an original expedition bathyscaphe looking forward through low wide nose viewport, narrow dark warm metal sill and slanted uprights only at the extreme edges, no UI. The living reef creature exactly 6 meters long is 25 meters ahead and has about 16 percent of image width, centered slightly right; it appears in three quarter side profile grazing/on the fine silt floor with several segmented legs visibly supporting the low charcoal dome and the rusty branching reef interrupting the skyline. A cool white headlamp grazes the creature and sand, reveals a few airborne specks and small apricot lights, contrast preserved through dark blue teal underwater haze, broad shadowed rocks and sparse moss. The view must feel at game eye height near the bottom and communicate distance, believable water attenuation, no surface sun, no text. Keep subject and frame safe for 16:9 finishing.

</details>
