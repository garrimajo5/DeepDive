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
