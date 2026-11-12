# MOD-023 - revision v21, 2026-11-12

Current submission: **terrasa-vrat-v21.glb**, **preview-v21.png** (1024 x 1024), **overlay-v21.png**, **lods-v21.png**. Versioned filenames preserve all earlier submissions, including the original terrasa-vrat.glb / preview.png. Issue #999, existing PR #1444, branch art/MOD-023-terrasa-vrat. Rules read from origin/main **6478bda891ebde3be78578d5f91ff199228bfea9**. This section supersedes the old 60 x 36 m clearance descriptions below.

## Changes and source

Implemented the 12 November review: passage X -24..24, Y 0..22 m, curved upper opening around 43 m, inward shoulders around 24-30 m, 58 m spike. Existing Meshy v16 geometry, remesh UVs, textures, cup cluster and convex porous lids reused. **No Meshy API operation or download, actual cost this session 0 credits; cumulative order remains 200.** Existing image-to-3D/remesh task IDs, exact prompts, settings and accepted source images are retained in the v16 section below.

The v18 defect was a stale assembly correction that pushed vertices at height 36-38.5 m out to X +/-32.5 for the obsolete 60 x 36 m clearance. Removed it; changed the radial cage and gently offset the upper contour to the right by up to 5 m, matching the painting's asymmetry. The shift fades at the floor and outer root tips. The lower shoulder cage retains clearance with this offset. No new topology or new source art; contact pivots and geometry retained. v19/v20 were local intermediate checks, not submissions.

**overlay-v21.png**: exact projected LOD0 triangles in orange (40% fill plus outline), original accepted ensemble front crop 1054 x 576 underneath; green = 48 x 22 m clearance. One scale on both axes: 968 / 120 = 8.066667 px/m, origin pixel (544,495), width reference endpoints x=60..1028. No independent height scaling or perspective fitting. The original review reference is https://raw.githubusercontent.com/garrimajo5/DeepDive/issue-img/1444/v17-zamer.jpg . The model height is 58 m; the painted spike measures about 56 m at this same scale.

## Technical result

Dimensions x/y/z: **119.964 / 58.115 / 23.521 m** (within 5%). Metres, Y up, approach +Z. Root pivot (0,0,0), node scale 1, no skeleton or animation. LOD totals including shared moving parts **41192 / 11675 / 4798**; moving **1458**. Three static meshes per LOD (one per material), common Stvorka0/1/2 and Diagnostika outside LOD roots. Only one LOD should be shown at once.

Socket centres glTF: (48,1.8,11.8), (52,1.8,11.8), (50,5.264102,11.8), equilateral triangle side 4 m. Lids 1.7 x 1.5 x 0.12 m; pivots (48,2.5,11.19), (52,2.5,11.19), (50,5.964102,11.19). Rotate local X from 0 to -90 degrees: centroid rises 1.4183 m. Diagnostika pivot (54.5,3,11.585), footprint 2.855 x 1.843 m, relief 0.07 m. Cables diameter 0.08 m, lengths 5.967 / 6.065 m. No terrace floor was added.

Three PBR materials: Mineral metallic 0, no emission, 2048-square color/normal/roughness maps; HumanCable constant #9C633D, roughness 0.8; Polyps 512-square mask, dark stalks and emissive tips #67DDEB / #9AD9E8, strength 1. Embedded images now named **terrasa-vrat-color**, **terrasa-vrat-normal**, **terrasa-vrat-orm**, **terrasa-vrat-polyps-emission**. Original remesh-specific UV quadrants preserved; JPEG quality 65. Colour values in compressed emission texture are approximate.

## Evidence and limitations

- validation-v21.json: every exported triangle clipped against the full passage volume (1 mm numerical tolerance), zero intersections for every mesh/LOD; zero degenerate triangles; file/triangle budgets, node scales, maps, pivots, animation/skin absence checked.
- lid-clearance-v21.json: each lid versus every mineral LOD at 0..90 degrees, step 5 degrees; zero intersecting triangle pairs. This is sampled, not a continuous collision proof.
- godot-v21.json: Godot 4.7.2 GLTFDocument import, 13 MeshInstance3D, correct material flags, 3 x 3 passage rays per mesh, no errors. No game code/scenes changed and no device performance measurement claimed.
- shape-v21.json: exported LOD0 cross-sections. Right-body projected widths at heights 10/20/25/30/35/36 m: 15.31 / 13.69 / 18.19 / 13.65 / 13.84 / 14.04 m. The broad shoulder at 25 m is locally thicker; upper projected vertical spans at x=0/10/15/20 are 10.67 / 10.66 / 8.84 / 9.23 m. These are axis-aligned sections, not a uniform wall thickness.
- Visually inspected preview, all three LODs and overlay. Gone: rectangular shoulder protrusions and side strip of v18. Retained: broad roots, upper cloud-shaped opening, side spike, contact cluster with one open lid in preview.

Remaining differences from concept: exterior of the upper ring is fuller to retain body; lower roots/opening and fine asymmetry are an approximation, clearly shown by overlay. Porosity and vein pattern come from Meshy and differ from the painting; LOD2 has visibly coarser holes; close-up contact textures remain coarser. No baked scene lights, ship, labels or seabed in GLB. Artistic acceptance and in-game route/ice/floor testing remain with the reviewer/integration roles; this is the model submission, not their sign-off.

Self-decided within the order: remove obsolete clearance correction; revise cage and asymmetric offset; keep existing Meshy sources and contact system; rename embedded maps. Reproduce in Blender 4.5.9 with src/atlas_arch_v21.py then assemble_details_v21.py and the validation/render scripts; raw-source task IDs below. Godot audit: src/godot_check/audit_v21.gd with GLB/report paths after --.

---

GLB size: **4012216 bytes**.

---

# MOD-023 - revision v16, 2026-11-09 (second review round)

Current review files: **terrasa-vrat-v16.glb**, **preview-v16.png** (1024 square, four views with metre rulers). `view-v16-0..3.png` are individual views; `lods-v16.png` compares all LODs. Previous submissions remain unchanged.
Issue: https://github.com/garrimajo5/DeepDive/issues/999; existing PR: https://github.com/garrimajo5/DeepDive/pull/1444.
Rules and role read from origin/main **459caefa70e6af4e8bca4f98da874eae4fc425e1**. Existing order branch retained.

## Review changes

v15 trial reused the original arch and did not resolve the frontal silhouette. It was not submitted for acceptance. v16 uses a **new Meshy arch generation from the same accepted frontal extraction**, plus three new remeshes. A frontal radial contour cage fits the metric opening and body together, preserving the source pores and each remesh's own UV/map pair. This changes the frontal proportions; it is not the old v10 height-lifting function. Side depth tapers towards the crown. Artist review still determines whether the interpretation is acceptable.

The opening now has lower lateral lobes, inset shoulders around 24-25 m, another widening around 29-30 m, and a central crown. `shape-v16.json` measures the exported LOD0 surface, not control points: side body width at heights 10/20/25/30/35/36 m is approximately **15.8 / 13.8 / 14.3 / 13.0 / 14.7 / 15.3 m**; upper body at x=20/25/30 m is **11.75 / 12.57 / 11.68 m**, excluding the central spike. Opening width at height 36 m is approximately **65 m**. These are projected cross-section measures, not uniform wall thickness or a substitute for visual review.

The three lids now use a **Meshy-generated convex mineral shell with a porous edge**, replacing the procedural sphere/disc. All three share the same new geometry and UV. Bounding size remains 1.7 x 1.5 x 0.12 m. Closed lids sit inside a raised lower/lateral mineral lip; upper relief is recessed for the unchanged arc motion. Local clearance corrections follow each static LOD's simplification. The diagnostic support's radial fan was replaced with an irregular rounded mineral patch; its movable three veins, dimensions and pivot are unchanged.

## Sources, tasks and actual cost

Accepted ART-079: `docs/concept-art/terrasa-vrat-ansambl.png` for shape; `terrasa-vrat-gabarity.png` / issue #999 for measurements; `terrasa-vrat-kontakt.png` for cups/lids and diagnosis. Existing `reference-arch.png` is the extracted front without ship or labels. The lid was extracted from the accepted closed-socket panel via Imagegen; `reference-lid-v15.jpg` is a small JPEG archive of the exact PNG supplied to Meshy. PNG SHA256 is in `lid-generation-v15.json`; the original PNG remains local. No external artwork was used.

| Meshy operation | Task ID | Actual credits |
|---|---|---:|
| Lid image-to-3D, standard, PBR 2k | 01a1c121-2352-77eb-b77c-d6d8043a3efe | 30 |
| Lid triangle remesh, target 500, actual 454 | 01a1c123-7356-7417-826a-e7eff33f92ed | 5 |
| New arch image-to-3D, standard, PBR 2k | 01a1c12a-dab8-719e-a21e-dc6df1502608 | 30 |
| Arch LOD0, target 34000, actual 35513 | 01a1c12c-e244-7077-b1b0-b48da2470830 | 5 |
| Arch LOD1, target 8000, actual 8229 | 01a1c130-da73-7285-acff-61092f9bdc2b | 5 |
| Arch LOD2, target 1500, actual 1499 | 01a1c130-df2e-7274-a4a2-bbeda5fc5597 | 5 |

**This run: 80 credits; cumulative order: 200 (120 previous + 80).** All tasks succeeded. No operation exceeded 100 credits; no regeneration was used for downloading. The connected cup cluster from task `01a1c060-da0f-720a-87db-15296c81a17d` was reused without charge. Raw large GLBs and signed URL sidecars are not committed.

Lid prompt: `Thin slightly convex oval blue gray mineral shell with grown porous rim. Preserve pores, seams and matte stone material from reference. Single lid only, no supporting rock, nonmetal, no emission.`

Arch prompt: `Grown porous matte blue gray mineral arch. Preserve thick folded body, wide spreading roots, two lobed shoulders in the cloud shaped opening, and tall sharp central spike exactly as the reference. The central passage is completely empty. No membranes, no floor, no cables, no emission, no metal.`

## Final GLB

**4,012,232 bytes**, glTF 2.0 binary. Overall x/y/z **120.588 / 58.136 / 23.518 m**, within issue tolerance. Metres; Y up; approach +Z; root pivot (0,0,0); every node scale 1. No skins or animations.

LOD totals including shared moving parts: **41192 / 11675 / 4798** (caps 42000/12000/5000). Shared moving parts: **1458** (cap 2000). Static meshes: one per material under each LOD root, three per LOD. Display only one LOD; Stvorka0/1/2 and Diagnostika stay outside those roots.

Socket centres glTF: (48,1.8,11.8), (52,1.8,11.8), (50,5.264102,11.8), equilateral 4 m. Mouth about 1.6 m with irregular grown lip; cup recess capped at 0.35 m. Lid pivots exactly retained: (48,2.5,11.19), (52,2.5,11.19), (50,5.964102,11.19). Rotation local X 0 to -90 degrees; vertex-centroid lift **1.418300 m** (about 1.4; slight asymmetry of the generated lid). Diagnostika pivot (54.5,3,11.585), footprint 2.855 x 1.843 m, relief 0.07 m. Cables diameter 0.08 m, length 5.967 and 6.065 m.

Three materials, unchanged semantics:
- Mineral: metallic 0; embedded 2048-square base color, tangent normal, metallic-roughness; no emission. Own 1024-square quadrant for each arch remesh, cup cluster 512 x 1024, new lid 512 x 768; remaining area for diagnostic stone. JPEG quality 65.
- HumanCable: constant PBR #9C633D, roughness 0.8, no emission or image map.
- Polyps: eight sparse colonies, 512-square emission mask, dark stalks and luminous tips, #67DDEB / #9AD9E8 source colours (JPEG approximates them), strength 1. No other emission. Palette also #0B1C24/#395361/#82999D/#86BCCB.

## Validation and limitations

`validation-v16.json`: full exported triangle clipping against x +/-30, y 0..36 (1 mm tolerance), zero passage intersections for every LOD; zero degenerate triangles; budgets, unit scales, dimensions, map sizes, pivots, no skins/animations checked.
`lid-clearance-v16.json`: all three lids against all three static mineral LODs at 5-degree steps from 0 to 90; zero overlapping triangle pairs. Sampled test, not continuous proof.
`godot-v16.json`: Godot 4.7.2 direct GLTFDocument import, 13 MeshInstance3D, correct maps/emission flags, unit scales, passage ray grid, no errors. No game scene changed, no on-device FPS measurement claimed.
Visually inspected the four views and all LOD silhouettes. The reference front crop from the review is paired with the new front in the PR.

Differences from the painting: wider upper passage to meet the metric clearance; different pores/asymmetry from Meshy; reduced pore detail in LOD2; contact surface and lid pores remain coarse at close distance. Clearance recesses affect the upper rim. No ship, ground terrace, sea floor or environment included. Numerical checks do not imply artistic acceptance.

Reproduce in Blender 4.5.9: restore Meshy files by the IDs into folders named in the scripts, run `atlas_arch_v16.py`, `assemble_details_v16.py`, then render/validation scripts. Existing standalone Godot audit remains in this order's art folder.

---

## Previous submissions (preserved history)

# MOD-023 - revision v14, 2026-11-09

Current review asset: **terrasa-vrat-v14.glb**; **preview-v14.png** (1024 x 1024, front/side/three-quarter/contact with one lid open and metre rulers). Previous `terrasa-vrat.glb` and `preview.png` remain unchanged as v10.
Issue https://github.com/garrimajo5/DeepDive/issues/999; existing PR https://github.com/garrimajo5/DeepDive/pull/1444.
Rules re-read from origin/main **98a5d9dd18bdb6ccc513c9363a6a31b3cdf028de**. Existing order branch retained.

## Changes against the review

- Replaced v10's height lifting at the passage with a horizontal mineral-body profile: wider lower lobes, inset shoulders and a curved upper opening. Heights below 36 m are unchanged from the normalized source. Long source edges were subdivided before shaping the crown; only the crown above 36 m was curved, with the apex retained near 58 m. Side thickness now tapers from the base to a pointed crown.
- Replaced separate procedural socket washers with one image-to-3D porous mineral cluster. Rear mass intersects the support; the three bowls share folded mineral tissue. Preserved the three specified centres and all lid pivots/axes. Local circular scaling, socket depth limit and clearance recesses are in the assembly script.
- Lids are 32-segment lenticular shells (192 triangles each), 1.7 x 1.5 x 0.12 m; planar UVs avoid the old sphere-UV streaking. The movement stays local X from 0 to -90 degrees, rise 1.400004 m.
- Each original arch remesh retains its own UV/map pair. New cluster also retains the UV/map pair of its own fine remesh. Local simplifications preserve these UVs.

## Meshy provenance and actual cost

Accepted inputs: ART-079 `docs/concept-art/terrasa-vrat-ansambl.png`, `terrasa-vrat-kontakt.png`; dimensions from `terrasa-vrat-gabarity.png` and issue #999. Original arch extraction `reference-arch.png` and original image-to-3D `01a1b410-e1f4-75a8-baf8-0cb2b9ca718c` reused; its three existing remesh IDs are recorded below in v10 history. No repeated generation for downloading.

This run used Imagegen to extract the accepted contact design, removing labels, people, cables and separate moving lids. `reference-socket-v13.png` was tried first; three separate copies looked disconnected and were rejected. `reference-cluster-v14.png` retains all three open sockets and their continuous mineral base. These are derived references, not new accepted concept sheets.

| Operation | Task ID | Actual credits |
|---|---|---:|
| Single socket, standard image-to-3D, PBR 2k | 01a1c04e-2d68-77d9-bf7c-39f48e8a8ef5 | 30 |
| Single socket, triangle remesh target 450 | 01a1c051-4bc8-761d-95bf-4413671d011d | 5 |
| Connected cluster, standard image-to-3D, PBR 2k | 01a1c05b-e2b5-73c7-abd7-9b7ca083388d | 30 |
| Cluster, triangle remesh target 1400 (too coarse at rims) | 01a1c05d-f08d-70a1-a3bc-4095d5dacbe0 | 5 |
| Cluster, triangle remesh target 3600 (used) | 01a1c060-da0f-720a-87db-15296c81a17d | 5 |

**This run: 75 credits. Order cumulative: 120 credits (previous 45 + 75).** All tasks succeeded; each operation was below the owner's 100-credit threshold. Exact prompts/settings/dispositions are in `socket-generation-v13.json` and `cluster-generation-v14.json`. Raw downloaded GLBs and signed metadata are intentionally not committed; reuse the IDs via Meshy CLI to restore them.

Cluster prompt: `Three recessed mineral contact bowls joined by one continuous porous blue gray grown rock base. Preserve triangular layout, three ports inside each bowl, folded organic rims and natural holes. Matte nonmetal stone, no lids, no cables, no lights, no emission.`

## Final metrics and materials

GLB glTF 2.0, **4,597,380 bytes**; overall x/y/z **119.574 / 58.174 / 23.248 m**. Y up, approach +Z per order, root pivot (0,0,0), all node scales 1. No skeleton or animations.
LOD totals including the shared moving parts: **41523 / 11967 / 4946**, within 42000 / 12000 / 5000. Moving total **672** (three lids and Diagnostika).
Three static meshes per LOD, one per material; shared moving nodes outside LOD roots. Display one LOD at a time.

- Mineral: metallic 0, embedded base color, tangent normal and metallic-roughness atlas 2048 x 2048; no emission. Arch LODs use separate 1024-square quadrants; the cluster uses 768 x 1024 within the fourth quadrant; remaining strip is procedural lid/diagnostic stone. JPEG image quality 65.
- HumanCable: constant PBR ochre #9C633D, roughness 0.8, no emission; two cables 0.08 m diameter, lengths 5.967 / 6.065 m. Unchanged from accepted technical v10 setup.
- Polyps: embedded 512 x 512 emission mask, stalks dark, tips #67DDEB / #9AD9E8 (JPEG encoding approximates the source colours), strength 1. No other material emits. Eight sparse colonies.

Socket centres in glTF: (48,1.8,11.8), (52,1.8,11.8), (50,5.264102,11.8): equilateral 4 m. Target bowl mouth about 1.6 m, recess limited to 0.35 m. Irregular grown rim is not a machined circle.
Lid pivots: (48,2.5,11.19), (52,2.5,11.19), (50,5.964102,11.19). Diagnostika pivot (54.5,3,11.585), relief 0.07 m, footprint 2.855 x 1.843 m. Exact exported pivots and dimensions in validation report.

## Checks and limits

- `validation-v14.json`: actual exported triangle counts, file bytes, dimensions, unit scales, maps, pivots; every triangle clipped against the through-passage x +/-30, y 0..36 with 1 mm tolerance: zero intersections on every LOD; zero degenerate triangles; no skins/animations.
- `lid-clearance-v14.json`: all three lids against each LOD's mineral, 0..90 degrees at 5-degree steps: zero overlapping triangle pairs. This is sampled motion validation, not continuous collision proof.
- `godot-v14.json`: direct GLTFDocument import in Godot 4.7.2, 13 mesh instances, correct normal/roughness/emission flags, unit scales, 3 x 3 passage rays per mesh, no errors. No game scene or code changed; no device FPS claim.
- Visually inspected four views in `preview-v14.png` and LOD silhouettes in `lods-v14.png`. Reference sheet and individual views are linked side-by-side in the PR.

Differences from concept: metric passage governs the opening; no ship, ground terrace or seabed is part of this asset. Meshy's pore arrangement and asymmetry differ from the painting; contact relief remains coarse at close range and is simpler in LOD1/2. Lid travel requires clearance recesses above the cups. These implementation choices were made within the model role; artistic acceptance remains with review.

Reproduction: restore each Meshy remesh in the source folders named in the scripts; run `atlas_arch_v14.py`, then `assemble_details_v14.py` in Blender 4.5.9; validation/render scripts read `terrasa-vrat-v14.glb`. Godot audit is the existing standalone script under this order's art folder.

---

## Preserved v10 history

# MOD-023 — сдача 09.11.2026 (v10)

Актуальные файлы: **terrasa-vrat.glb**, **preview.png**. Исторические черновики ниже не являются файлами для встраивания.
Issue: https://github.com/garrimajo5/DeepDive/issues/999 · PR #1444.
Ветка начата от main `64bce68`; правила повторно прочитаны из `origin/main` `486032dc83bac4249aea6ae5954d11f921492060` 09.11.2026.

## Исходники и Meshy

Принятый ART-079: `docs/concept-art/terrasa-vrat-ansambl.png` (форма, источник генерации), `terrasa-vrat-gabarity.png` (размеры), `terrasa-vrat-kontakt.png` (детали), `terrasa-vrat.md`. Из ансамбля Imagegen выделил фронтальную арку без корабля, надписей и окружения: локальный `reference-arch.png`. Исходный лист находится в main; изображение передано Meshy с разрешения владельца.

Image-to-3D `01a1b410-e1f4-75a8-baf8-0cb2b9ca718c`: standard, PBR, текстуры 2k, 30 кредитов.
Промпт: `Matte dark blue gray grown mineral, fine organic folds and porous stone, no metal, no emission, no lights, no cables, neutral albedo without baked shadows. Preserve all holes and the open central passage.`

| Ремеш | Task ID | Цель | Получено | Кредиты |
|---|---|---:|---:|---:|
| LOD0 | 01a1b666-3fdc-7097-b138-8d8a4ac14a71 | 38000 | 39557 | 5 |
| LOD1 | 01a1b666-5c0e-73fa-ae8b-8050a996a334 | 9000 | 9135 | 5 |
| LOD2 | 01a1b666-72af-72d3-b208-d9d6bb13a628 | 3000 | 2988 | 5 |

Итого фактически **45 кредитов**; в запуске 09.11 — **0**. Новых задач и повторных генераций ради скачивания не было. Большие исходные GLB и `meta.json` с временными URL не публикуются; для повторения скачать результаты существующих task ID через Meshy CLI в `lod0-source/model.glb`…`lod2-source/model.glb`.

## Геометрия, оси, узлы

GLB glTF 2.0, **4 527 868 байт**, без скелета и анимаций. Метры, Y вверх, подход с **+Z**. Общий pivot `(0,0,0)` — центр прохода на полу. Масштаб всех узлов `(1,1,1)`.
Габарит X/Y/Z: **120 × 58 × 23,541 м** с контактами и кабелями (основная арка 120 × 58 × 23 м). Глубина с деталями отклоняется на 2,35 %, в пределах ±5 %.
Пол террасы не добавлен. Свободный объём X −30…30, Y 0…36 проверен насквозь по Z.

| Уровень | Минерал | Кабели | Полипы | Общие подвижные части | Всего | Бюджет |
|---|---:|---:|---:|---:|---:|---:|
| LOD0 | 40397 | 360 | 128 | 576 | **41461** | 42000 |
| LOD1 | 9975 | 360 | 128 | 576 | **11039** | 12000 |
| LOD2 | 3828 | 360 | 128 | 576 | **4892** | 5000 |

Статика — три сетки под каждым `LOD0/LOD1/LOD2`, по одной на материал. При встраивании показывать один уровень, остальные скрывать; GLB хранит все три, автоматического переключателя в нём нет. Общие `Stvorka0`, `Stvorka1`, `Stvorka2`, `Diagnostika` находятся вне групп LOD и не должны скрываться вместе с ними. При одном LOD — семь сеток/материальных поверхностей.

Координаты ниже **в осях glTF/Godot**, не Blender:

| Узел | Центр гнезда / поверхность | Pivot |
|---|---|---|
| Stvorka0 | (48; 1,8; 11,8) | (48; 2,5; 11,19) |
| Stvorka1 | (52; 1,8; 11,8) | (52; 2,5; 11,19) |
| Stvorka2 | (50; 5,264102; 11,8) | (50; 5,964102; 11,19) |
| Diagnostika | (54,5; 3; 11,585) | (54,5; 3; 11,585) |

Тройка гнёзд — равносторонний треугольник 4 м, внутренняя кромка Ø 1,6 м (небольшая органическая волнистость ±2,5 %), чаша 0,35 м. Гнездо собрано из расширяющегося минерального ободка, чаши и трёх внутренних пор. Створки — тонкие линзовидные оболочки **1,7 × 1,5 × 0,12 м**, по 160 треугольников. Открывание: вращение вокруг **локальной X от 0 до −90°**; подъём центра **1,39997 м**, дуга выходит к наблюдателю и возвращается по Z. Файл сохранён с закрытыми створками; открытая — только на превью.

Диагностика: три сходящиеся жилы, отдельный узел, **2,855 × 1,843 × 0,070 м**, 96 треугольников. Для отклика двигать по локальной +Z (к подходу), базовый рельеф 0–0,07 м над минеральной поверхностью. Кабели Ø 0,08 м, длины **5,967 / 6,065 м**, с охристыми наконечниками/хомутами; всё вне прохода.

## Материалы и UV

Ровно три материала. `Mineral`: metallic 0, без emission, встроенные **base color / tangent normal / metallic-roughness**, атласы 2048². Каждый ремеш использует собственные исходные текстуры и UV, перенесённые в отдельную четверть атласа (эффективно 1024² на LOD). Четвёртая четверть — процедурная минеральная фактура новых деталей, без заимствованных картинок. Совпадающие геометрические вершины объединены, нормали сглажены; UV-швы сохранены. Карты JPEG quality 78 внутри GLB, поэтому мелкая фактура мягче оригинала.

`HumanCable`: постоянный PBR-цвет #9C633D (линейный RGB около 0,332/0,125/0,047), roughness 0,8, без текстур и свечения — отдельный атлас для одноцветных кабелей не нужен.
`Polyps`: восемь редких колоний; встроенная маска emission **512²**, тёмные основания, светятся верхушки, цвета **#67DDEB / #9AD9E8**. Интенсивность 1; минеральные детали и кабели не светятся. В Godot проверены `emission_enabled` и наличие `emission_texture` только у Polyps.
Палитра проекта: #0B1C24, #395361, #82999D, #86BCCB, #67DDEB, #9AD9E8, #9C633D.

## Проверки и самостоятельные решения

- `validation-v10.json`: повторный импорт экспортированного GLB; все треугольники отсечены по четырём плоскостям свободного прохода с допуском 1 мм — **0 пересечений на каждом LOD**; 0 вырожденных треугольников; габариты, единичный масштаб, бюджеты, три материала, отсутствие skins/animations.
- `godot-v10.json`: прямой импорт GLTFDocument в **Godot 4.7.2**, 13 MeshInstance3D, нужные normal/roughness/emission maps; сетка лучей 3×3 через каждый меш, ошибок/перекрытий нет. Это проверка ассета, не тест FPS или прохождения на телефоне.
- `lid-clearance-v10.json`: BVH-пересечения трёх створок с минералом LOD0 в семи положениях 0/15/30/45/60/75/90° — 0 пар пересекающихся треугольников. Между этими положениями непрерывная коллизия не рассчитывалась.
- Визуально осмотрены `preview.png` (1024²: фронт, бок, три четверти, контакты с открытой створкой и линейки) и `lods-v10.png` (все три уровня). Задний план — тёмный; вода, туман и игровой bloom не добавлялись.

Решено самостоятельно в пределах заказа: заменить общий овальный щит v6 отдельными основаниями; собрать статику по материалам; разделить атлас по исходным UV; изменить высоты исходного Meshy-каркаса для свободного прямоугольного прохода. Горизонтально расплющенные варианты v8/v9 отклонены. В v10 нижние боковые дуги выше, верхние лопасти компактнее художественного ансамбля, но тройной силуэт и боковые пустоты сохранены. Две длинные грани LOD2 потребовали локального отвода вершины от прохода. **Контактные основания и внутренние поры значительно проще концепта**, фактура арки у контактов растянута; на LOD2 мелкие отверстия упрощены. Эти различия вынесены в PR для художественной приёмки, не скрыты как точное совпадение с концептом.

Повторение: Blender 4.5.9, последовательно `src/atlas_arch_v10.py` → `src/assemble_details_v10.py` → `src/validate_v10.py`; результат `terrasa-draft-v10.glb` копируется в `terrasa-vrat.glb`. `src/render_preview_v10.py`, `src/render_lods_v10.py`, `src/check_lids_v10.py` — визуальная/кинематическая проверка. Изолированный `src/godot_check/audit.gd` принимает абсолютные пути GLB и JSON-отчёта через аргументы после `--`. Код игры, сцены и документы проекта не менялись.

---

# История предварительных итераций (сохранена)

# MOD-023 — сохранённая генерация (не сдача)

Issue #999. База main: 64bce68. Ветка art/MOD-023-terrasa-vrat.
Владелец в чате явно разрешил передачу reference-arch.png в Meshy и основную генерацию около 30 кредитов.
Meshy image-to-3d task: 01a1b410-e1f4-75a8-baf8-0cb2b9ca718c; SUCCEEDED; фактически 30 кредитов.
Исходник: принятый ART-079, terrasa-vrat-ansambl.png; Imagegen выделил фронтальную арку без корабля и подписей в reference-arch.png.
Настройки: standard, текстура 2k, PBR, GLB.
Промпт: Matte dark blue gray grown mineral, fine organic folds and porous stone, no metal, no emission, no lights, no cables, neutral albedo without baked shadows. Preserve all holes and the open central passage.

Сохранены meshy-source/model.glb (76 708 552 байта), thumbnail.png и служебный meta.json. Последний содержит временные URL, не публиковать. Исходный GLB превышает лимит репозитория, не коммитить.
Превью осмотрено: силуэт трёхлопастной арки и открытая середина узнаваемы. Это не проверка прохода и размеров.
Измерено CLI inspect faces: 2 247 424 треугольника, одна mesh instance. Лимит LOD0 42 000 не пройден.
Осталось: ремеш LOD0/1/2 (целевые бюджеты с запасом на детали), размеры 120x58x23 м и пустой проход 60x36 м, контактный узел со створками и диагностикой, материалы/полипы, финальный GLB <=5 МБ, проверка и превью.
По тарифам Meshy от 07.11.2026 три ремеша стоят ориентировочно 15 кредитов (5 каждый). Дополнительный расход ещё не разрешён; новый платный запрос не делался.

## Ремеш и разрешение владельца, 07.11.2026
Владелец в чате: «Да, разрешаю тратить кредиты, спрашивай разрешения только если сразу требуется более 100 за раз». Сохранено в плановом задании 3d; не дробить операции для обхода порога.
Ресурс remesh, родитель image-to-3d 01a1b410-e1f4-75a8-baf8-0cb2b9ca718c:
- LOD0 01a1b666-3fdc-7097-b138-8d8a4ac14a71: цель 38000, измерено 39557, 5 кредитов, 21835808 байт.
- LOD1 01a1b666-5c0e-73fa-ae8b-8050a996a334: цель 9000, измерено 9135, 5 кредитов, 19200412 байта.
- LOD2 01a1b666-72af-72d3-b208-d9d6bb13a628: цель 3000, измерено 2988, 5 кредитов, 17643240 байт.
Все SUCCEEDED и сохранены в lodN-source/. Превью осмотрены: силуэт сохраняется, LOD2 заметно грубее. Числа треугольников проверены inspect faces, укладываются в бюджеты арки. Файлы ещё превышают 5 МБ, не коммитить исходные GLB и meta.json с временными URL. Общий подтверждённый расход 45 кредитов. Следующий этап: сборка и оптимизация текстур, контактный узел, размеры/проход и проверки. Blender: D:/AI/DashaBD/tools/blender-4.5.9-windows-x64/blender.exe. Заказ не готов к приёмке.

## Локальная сборка 07.11, 20:56 МСК
Создан arch-draft.glb, 4 761 264 байта, три LOD; скрипты src/assemble_arch.py и src/check_clearance.py. Текстуры сведены к 1024, JPEG quality 80. Пройдён только лимит размера предварительной арки, не итогового комплекта.
Повторный импорт выявил нарушение прохода: 18 907 / 5 029 / 1 542 вершин в объёме |X|<30, 0<Y<36 (в Blender Z — высота). Сначала проверить ориентацию исходных сеток и преобразования, затем форму прохода; этот файл не сдавать и в игру не переносить. Материалы LOD объединены предварительно, совпадение UV требует проверки. Контактных деталей пока нет. Новых кредитов не потрачено, общий расход 45.

## Диагностика 08.11, 01:00 МСК
Габариты повторного импорта подтверждены: Blender 120x23x58 (glTF 120x58x23), матрицы единичные. Рендер diagnostic-front.png осмотрен: причина нарушения прохода — сама форма внутренних выступов, не оси. Подготовлен отдельный arch-draft-v2.glb с расширением по X (src/widen_arch.py). Остаток вторжения по вершинам: LOD0 10, LOD1/2 0. Это ещё не доказательство пустого прохода: нужны проверка треугольников/лучей, визуальная проверка новой формы, исправление остатка LOD0. Исходные файлы не изменялись. Контактный узел и финальная сдача остаются впереди. Новых расходов нет.

## 08.11, 14:30 МСК: проход v4
v3 отклонена визуально: глобальное растяжение испортило верхушку. v4 ограничивает деформацию нижней частью с плавным затуханием к 46 м, исходная верхушка сохранена. После повторного импорта проверены все треугольники отсечением по четырём плоскостям прохода: 0 пересечений на каждом LOD (допуск 1 мм). Фронтальный рендер v4 сохранён. Это предварительная арка, контактные детали, свечение полипов, UV LOD и итоговое превью ещё не готовы. Расход 45 кредитов без изменений.

## 08.11, 18:25 МСК: сборка v5, НЕ ГОТОВА
terrasa-draft-v5.glb: 4 890 284 байта. Добавлены три гнезда и чаши, Stvorka0/1/2 с отдельными pivot, Diagnostika, два кабеля и черновые полипы. Скрипт assemble_details_v5.py; счётчики assembly-v5.json. Створки и диагностика вместе 912 треугольников. Кредиты не расходовались.
Остаток: геометрия контактного узла пока из простых форм, посадка на поверхность не проверена; кабели нуждаются в точном замере длины; полипы пока без требуемой маски и атласа; статика ещё не объединена по материалу, суммарные LOD с деталями требуют оптимизации. UV трёх LOD нельзя считать проверенными после объединения материалов. Итоговые ракурсы и Godot-проверка ещё впереди. Не встраивать.

## 08.11, 22:29 МСК: контактный узел v6 — отклонён
Крупный план v5 показал утопленные гнёзда. Проба v6 выносит узел на отдельный минеральный нарост и уменьшает детали: общая добавка 2132 треугольника; LOD0 41689, LOD1 11267, LOD2 5120 (превышение 120). Размер 4 836 148 байт. Рендер contact-v6.png осмотрен: результат НЕ подходит — нарост выглядит отдельным овальным щитом, гнёзда частично утоплены, текстура растянута. Не использовать v6 как принятую основу. Следующее действие: отдельные небольшие основания каждого гнезда с привязкой к поверхности, UV и каменная фактура под масштаб, затем маска полипов и объединение статики. Кредиты не потрачены (всего 45).

## 12.11.2026 — промежуточный v17, НЕ сдача
Изменён внутренний радиальный контур в src/atlas_arch_v17.py на исходных Meshy LOD v16. Новых генераций нет, расход 0. terrasa-vrat-v17.glb — черновик 4012236 байт, LOD 41192/11675/4798, подвижные 1458. validate_v17.py проверяет X ±24, Y 0..22: пересечений 0; check_lids_v17.py: пересечений 0. preview-v17.png осмотрено: внешний контур верхних плеч слишком широк относительно ансамбля, требуется уменьшить внешний радиальный профиль oa/orr; сейчас на высоте 25..35 м ширина тела ~30 м вместо требуемых ~13..16. До сдачи: исправить внешний контур, сделать наложение на фронт ансамбля в одном масштабе, повторить проверки/рендер и переименовать встроенные карты по правилу роли. Старые файлы сохранены. На приёмку не передано.

## 12.11, 19:28 МСК — проба v18, не сдача
Внешний профиль сужен по ансамблю; результат terrasa-vrat-v18.glb (4012204 байт), LOD 41192/11675/4798, габариты 119.989 × 58.096 × 23.520 м. Проверки прохода 48 × 22 и створок завершены, overlaps []. Визуально НЕ принят: у плеч плоские выступы, на боковом виде тёмная поперечная полоса. Следующий шаг: проверить радиальное отображение исходной сетки, локальное схлопывание/инверсии и соответствие внутренних/внешних профилей, исправить без потери UV; затем наложение на концепт, карты и окончательная сдача. Новых генераций Meshy нет, расход 0. v17 сохранена.
