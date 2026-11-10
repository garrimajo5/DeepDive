# MOD-022 — купольник, итоговая сдача v6

Issue: https://github.com/garrimajo5/DeepDive/issues/920 · PR: https://github.com/garrimajo5/DeepDive/pull/1574

**Использовать `kupolnik.glb`.** Предыдущие `*-draft.glb` оставлены как история, в игру их не переносить.
База ветки: `330f2ff9e60209b79d88af1e6d7f4afafb9090d2`.
Актуальные правила сверены 11.11.2026 с `origin/main b02e5ae77c27a036753fb0459695665df0f34c0d`.

## Комплект
- `kupolnik.glb` — glTF 2.0, 7419 треугольников, около 3,27 МБ; точные байты и SHA256 — `verification-final.json`.
- `preview.png` — 1024×1024: спереди, сбоку, сверху и реальная сетка захвата; линейки в метрах. Голубым выделены существующие рёбра шести петель, это только наложение на диагностическом рендере.
- `panel-valves.png` — оба устья и три складки внутри каждого.
- `kupolnik-source.blend` — одна сетка до триангуляции экспорта, упорядоченные четырёхугольники захватов; без скелета, клипов, камер и света. Для следующего ANIM.
- `verification-final.json`, `godot-verification.json`, `retopology-v5.json`, `landmarks.json`, `pivot-shift.json` — результаты проверок и привязки.
- `reference-front.jpg`, `reference-top-v2.jpg` — компактные копии двух ракурсов, использованных для Meshy. Оригинальные PNG сохранены локально.

## Концепт и происхождение
Принятый ART-081: `docs/concept-art/kupolnik-rakursy.png`, `kupolnik-stvorka.png`, `kupolnik.md`.
Передние захваты расположены поперечным веером по видам спереди и сверху; противоречивое расположение вдоль тела на боковом виде не переносилось.
Ракурсы извлечены из принятого листа: front — Imagegen exec-1d1c91f0-d71c-4b57-828a-a049fa903a2a, top — exec-2ac26d07-8e03-4205-92f7-66b308b4653c. Нового дизайна не заказывалось.

Meshy multi-image-to-3d: `01a1c58f-5908-77ba-aec4-ea6e408a106a`, standard geometry, PBR, 2k, GLB, два изображения; фактически 30 кредитов.
Промпт дословно:
> Matte purple mineral dome with broad longitudinal ribs, soft purple mantle and graspers. Three paired leaf-pad graspers ONLY at front. Two open cylindrical siphons ONLY at rear. Cyan oval photophores along rim. No face eyes or machinery.

Meshy remesh: `01a1c591-5794-74fe-909f-cce9f3bd0aa6`, quad, target3500, GLB/OBJ; фактически 5 кредитов.
Отклонённая первая image-to-3d: `01a1c3d7-b78a-746f-823c-1b85ffe173ed`, 30 кредитов, дублированная задняя тройка захватов.
**Итого по заказу 65 кредитов; этот запуск — 0**, новых запросов Meshy не было. Повторная генерация для скачивания не выполнялась.

## Геометрия и оси
- Габарит GLB x/y/z = **1,802463 × 1,199252 × 2,980245 м** (ширина × высота × длина). В пределах ±10% заказа.
- Pivot (0,0,0) — центр нижней границы общего габарита; минимум Y = 0. Узел без TRS-поправок, scale (1,1,1); Y вверх, перед −Z.
- Низкий продолговатый купол около 2,2 м, мягкая мантия, три парных захвата спереди, два сифона сзади. Створки террасы в файле нет.
- На видимой гибкой части каждого захвата — шесть замкнутых поперечных петель по 16 вершин. После экспорта независимо проверены 18 циклов: по 16 рёбер и степень каждой вершины 2.
- Центровая линия гибкой части включает крепление внутри мягкого тела; длины и точки — `landmarks.json`. Проекция длины каждой пары подушек вдоль модели — 0,45 м.
- На нижней мантии добавлены три поперечных сечения на сгибах. В наружной части каждого сифона — три поперечных ряда, диаметр устья 0,25 м, внутри три складки.
- Клапаны — тонкие двусторонние поверхности отдельными островами внутри общей сетки; это игровая модель, не замкнутая оболочка для печати. Скелет, веса и анимации отсутствуют по уточнению заказчика; веса клапанов и проверка сгиба остаются заказу ANIM.

### Привязки для ANIM (x, y, z в метрах)

Центры креплений внутри мягкого тела; это ориентиры оснастки, не добавленные кости.

| Точка | x | y | z |
|---|---:|---:|---:|
| Корень захвата слева (−X) | −0,469353 | 0,599252 | −0,269878 |
| Корень среднего захвата | 0,000647 | 0,599252 | −0,409878 |
| Корень захвата справа (+X) | 0,470647 | 0,599252 | −0,269878 |
| Устье сифона слева (−X) | −0,169353 | 0,749252 | 1,490122 |
| Устье сифона справа (+X) | 0,170647 | 0,749252 | 1,490122 |

Длины центровых линий до подушек: 0,7884 / 0,7155 / 0,7930 м. Точки и метод измерения сохранены в `landmarks.json` и `src/landmarks.py`.

## Материал
Один PBR metallic-roughness, четыре встроенные PNG 1024² на единственном UV: цвет, normal, packed roughness/metallic, emissive.
Metallic factor = 0 и канал B = 0. Шероховатость в G = 0,749…0,886. Normal scale = 0,4: уменьшена выраженность артефактов запекания после ремеша.
Фотофоры — только маска кромки купола, 6078 ненулевых пикселей, точный цвет **#67DDEB**, emissiveFactor (1,1,1). Отдельных светящихся мешей и ламп нет. Голубые пятна на подушках удалены из цвета и эмиссии.
Целевая палитра: купол #544773, рёбра #827DA0, мягкое тело #655870, углубления #302C45. Сохранены тональные вариации Meshy; новые гибкие участки используют #655870 с небольшой модуляцией фактуры.

## Проверки и отличия от концепта
Повторный импорт фактической GLB в Blender: одна сетка/материал/primitive, 7419 треугольников, нулевых по площади треугольников нет, 18 замкнутых петель сохранены, все четыре карты 1024², без skins/animations. Проверены реальные данные материала, без подмены шероховатости при рендере.
Godot **4.7.2 stable**: append_error 0, один MeshInstance3D, одна поверхность, 7419 треугольников, metallic 0, emission enabled. Изолированная проверка внутри папки заказа; игровой проект не менялся. Производительность на телефоне не заявляется.
Осмотрены все три основных вида, крупно клапаны и сетка. Силуэт сопоставлен с принятыми фронтом/верхом и боковым профилем купола. В пределах бюджета упрощены мелкие складки, грани купола и рельеф клапанов; новый участок захватов менее фактурен, чем рисованный концепт. Овалы фотофоров сохраняют небольшую нерегулярность генерации.

**Самостоятельные решения:** локальная ретопология поверх результата Meshy, сокращение излишне длинных подушек, реконструкция клапанов по принятой детали, перераспределение геометрии внутри общего бюджета, перенос UV в 960 столбцов атласа и резерв 64 столбцов для новых мягких поверхностей. Дизайн, число частей и лор не менялись.

Воспроизведение: `src/retopo_v5.py` из сохранённого v3 → `src/finalize_v6.py` → `src/verify_final.py`; лист — `src/preview_final.py` и `src/compose_preview.ps1`. Проверка Godot — `qa-godot/audit.gd`. Скрипты имеют рабочие абсолютные пути этой копии.

---
## История работы (старые ограничения ниже сняты итоговой сдачей, если явно не перечислены выше)

# MOD-022 kupolnik — work in progress
Issue: https://github.com/garrimajo5/DeepDive/issues/920
Reference: accepted ART-081 docs/concept-art/kupolnik-rakursy.png, front view extracted with Imagegen. Side view arm positions are explicitly rejected by the order.
Meshy image-to-3d task: 01a1c3d7-b78a-746f-823c-1b85ffe173ed
Settings: standard, textured, PBR, 2k, GLB. Estimate 30 credits; actual pending.
Prompt: Matte purple mineral dome, broad longitudinal ribs, soft purple mantle. Exactly three flexible graspers across front, paired leaf pads. Elongated body extends behind dome with two short open rear siphons. Cyan oval photophores only along dome rim. No eyes face spiral or machinery.
No skeleton/animations per updated issue. Final target <=8000 triangles, one mesh/material, 1024 maps, emission mask #67DDEB. Length 3m width1.8m height1.2m, Y up, front -Z, pivot bottom center. Must verify silhouette, rear siphons, topology loops, UV/maps and dimensions before delivery.
330f2ff9e60209b79d88af1e6d7f4afafb9090d2

## First generation inspection, 2026-11-10
Task SUCCEEDED, actual consumed_credits=30. Raw GLB saved locally at source-v1/model.glb (32,787,516 bytes), SHA256 c4a6a3fe181716dd2ec981455f9ac79e40290c8903a7b23cddf1fabb6745fee4. Sidecar source-v1/meta.json retained locally, not committed (signed URLs).
Thumbnail visually inspected: three front graspers visible, but dome appears too high and glossy. NOT ready for acceptance. No remesh or final export yet. Rear geometry, loops, dimensions and emission still unverified. Do not use in game. Next: inspect source from side/back, correct silhouette against top/front accepted views, then remesh/retopology and maps. Reuse existing task for downloads.
Raw reference-front.png retained locally; exact source is the extracted front at C:/Users/FEDYA/.codex/generated_images/01a1b3ca-c4e9-7360-a58e-6cb7d9303add/exec-1d1c91f0-d71c-4b57-828a-a049fa903a2a.png.

## 2026-11-10 inspection from four directions
Current rules: origin/main 990c73a. No new Meshy operations, 0 credits this session, order total30.
Imported original GLB in Blender4.5.9: 889712 triangles, 469648 vertices, one mesh. Rendered four orthographic views with metallic0/roughness0.85 for diagnosis only (raw GLB unchanged). File names describe camera coordinates, not verified anatomical orientation.
The top view reveals SIX graspers: the front triplet was mirrored at the rear. Two required rear siphons are absent. Dome is almost round rather than elongated. Therefore this source is rejected as the basis of a final model; merely flattening the dome and remeshing cannot repair missing anatomy. No final GLB or acceptance claim.
Next: use consistent accepted front AND top/rear information in a multi-view Meshy request; inspect anatomy before paying for remesh. Keep this task and raw file for provenance, do not regenerate to download it.

## v2 multi-view generation, 2026-11-10
Rules main ba7fd1a. Resource multi-image-to-3d, task 01a1c58f-5908-77ba-aec4-ea6e408a106a. Accepted front extraction reference-front.png plus top extraction reference-top-v2.png from ART-081. Standard geometry, PBR 2k, GLB.
Prompt: Matte purple mineral dome with broad longitudinal ribs, soft purple mantle and graspers. Three paired leaf-pad graspers ONLY at front. Two open cylindrical siphons ONLY at rear. Cyan oval photophores along rim. No face eyes or machinery.
Estimated30 credits per https://docs.meshy.ai/en/api/pricing (2026-11-10). Actual pending. Inspect anatomy before remesh.

## v2 downloaded and remeshed — DRAFT, not acceptance
Multi-image generation SUCCEEDED, actual30 credits. Remesh resource task 01a1c591-5794-74fe-909f-cce9f3bd0aa6 SUCCEEDED, actual5 credits, quad target3500, glb/obj. This session35 credits, order total65. Raw model/meta/OBJ remain local in source-v2 and remesh-v2; signed URLs not committed.
Inspected source v2 and processed draft from multiple directions: three front graspers and two rear siphons, duplicated rear graspers removed. File kupolnik-v2-draft.glb is 3695476 bytes, 7304 triangles, one mesh/material, scale1. Dimensions glTF x/y/z=1.8/1.2/3m; front -Z after rotation, bottom pivot. Maps resized1024, cyan color-selection emission mask10541 pixels. No rig or animation.
NOT COMPLETE: verify/correct transverse bend loops (4-6 per grasper and2-3 mantle/siphons), threefold siphon valves, actual exported roughness (math-node mapping may not export), mask localization, no degenerate triangles, Godot import. Need final ruler preview1024 and root/mouth coordinates. Diagnostic renders override metallic/roughness, so do NOT prove exported material. Retain draft designation until checks pass.
Scripts prepare_v2.py and inspect_draft_v2.py reproduce draft and diagnostic views. Side shape/proportions and matte material remain subject to artist review. No device performance claim.

## v3 material fix and topology diagnosis, 2026-11-10
Rules checked against origin/main bb30e59 (PASSPORT/AGENTS/ARTIST/world/graphics unchanged from previously read versions). No Meshy operations; session0, order65 credits.
Reimport of v2 proved roughness G ranged0..0.68235: previous node math did not produce the intended matte map. v3 modifies the actual packed map, preserving UV: G=.75+.2*oldG, B=0. Reimport of exported kupolnik-v3-draft.glb verifies G=.74902.. .88627, B=0. Byte quantization explains .74902. One mesh/material,7304 triangles,3422748 bytes, unit node transform, no skin/animation. verification-v3.json records actual exported data.
Wire inspection confirms acceptance blockers: grasper shafts contain irregular diagonals/poles rather than the requested4-6 continuous transverse loops; siphon ends do not show the required threefold valve. wire-v3-graspers.png and wire-v3-siphons.png show actual mesh, not a concept. Geometry unchanged from v2. Needs local retopology with map transfer and valve reconstruction, followed by all final checks and ruler preview. NOT ready for acceptance.
