class_name CrewView
extends Node3D
## Фигуры экипажа на корабле: модель MOD-012 (мужская или женская, `Crew.Member.look`), позу считает
## `Crew.Member.joints()`, на скелет её переносит `CrewRig.pose`. Один skinned-меш на фигуру — один вызов отрисовки.
## Свой игрок — копия меша без головы и верха груди (`cut_mesh`: камера в голове, наклон к штурвалу подносит грудь
## к камере), задние грани отсечены; стоя модель чуть позади камеры (OWN_BACK → `Crew.Member.back`). Цвет роли — нашивка на левом плече,
## роль видна по снаряжению MOD-016 (`_dress`: детали на костях, щиток поднят и опущен на сварке).
## Узел живёт в осях корабля, слой света 2 (только плафоны корабля).

const LAYER_SHIP := 2
## Нашивка роли на левом плече (ART-014: роль узнают по снаряжению, цвет — тонкая метка).
const PATCH_SIZE := Vector3(0.012, 0.07, 0.06)
## Свой игрок стоя: модель на 15 см позади камеры (`Crew.Member.back`) — взгляд вниз видит грудь и живот снаружи,
## как глазами, а не изнутри куртки; с руками на посте тоже (кисти в точке хвата). Сидя и при сварке — на месте;
## взглядом вниз — дальше (own_back).
const OWN_BACK := 0.15
## Свой игрок стоя смотрит вниз круче этого (рад, pitch < 0) — меш без груди (`CrewRig.HIDE_TORSO`): видны пояс, ноги
## и ступни, а не грудь вплотную (issue #108). Выше порога грудь в кадр не попадает.
const LEGS_PITCH := -0.6
## Чем круче взгляд вниз, тем дальше фигура позади глаза — как голова, вынесенная вперёд: до DOWN_BACK (м) при
## DOWN_PITCH; иначе пояс у самой камеры заслоняет ступни.
const DOWN_BACK := 0.38
const DOWN_PITCH := -1.3


## Насколько своя фигура стоя позади глаза при наклоне взгляда pitch (рад): OWN_BACK, вниз — плавно до DOWN_BACK.
## Руки на посте — OWN_BACK: фигура не отъезжает от пульта (наклон к нему не растёт), грудь с руками видна.
static func own_back(look_pitch: float, holding: bool = false) -> float:
	if holding:
		return OWN_BACK
	var t := clampf((LEGS_PITCH - look_pitch) / (LEGS_PITCH - DOWN_PITCH), 0.0, 1.0)
	return lerpf(OWN_BACK, DOWN_BACK, t * t * (3.0 - 2.0 * t))

var members: Array = []  ## Crew.Member
var local: Crew.Member  ## свой игрок (без головы)
var figures: Array[Node3D] = []  ## корень модели у каждой фигуры
var skeletons: Array[Skeleton3D] = []
var meshes: Array[MeshInstance3D] = []
var patches: Array[MeshInstance3D] = []
var torches: Array[Node3D] = []  ## резак MOD-013 у каждой фигуры: виден, пока она варит
var looks: Array[int] = []  ## внешность, с которой собрана фигура
var gear: Array = []  ## снаряжение роли у каждой фигуры: имя GLB → узел детали (CrewRig.GEAR)
var gear_roles: Array[int] = []  ## роль, под которую надето снаряжение (-1 — ещё нет)
## Что нарисовано у каждой фигуры: сустав → точка в осях корабля (по костям модели; скрытых нет) — для тестов и сети.
var shown: Array = []
## Фигуры, нарисованные материалом своего игрока (прогрев, #217): `_own_mat` с отсечением граней — отдельный шейдер,
## его видно только взглядом вниз у поста (руки на пульте энергии) — без прогрева он собирался при первом нажатии.
var as_own: Array = []
var alphas: Array[float] = []  ## непрозрачность фигуры i (нет — 1): < 1 — отключившиеся гости у хоста (MateGhost, ART-043)
var pitch := 0.0  ## наклон взгляда своего игрока (рад, вниз < 0) — ставит Main перед apply()
var _rest := {}  ## внешность → CrewRig.Rest
var _own_mat := {}  ## внешность → материал своего игрока: с отсечением задних граней (не видно изнанки у камеры)
var _scenes := {}  ## внешность → PackedScene модели (держим загруженной: новая фигура не грузит её заново)
var _meshes := {}  ## внешность → меши [целый, свой — без головы и верха груди, свой стоя взглядом вниз — без груди]


## Список экипажа; local — тот, чьими глазами смотрит камера.
func set_members(list: Array, me: Crew.Member) -> void:
	members = list
	local = me
	while figures.size() < members.size():
		figures.append(null)
		skeletons.append(null)
		meshes.append(null)
		patches.append(null)
		looks.append(-1)
		gear.append({})
		gear_roles.append(-1)
		var t: Node3D = load("res://models/rezak.glb").instantiate()
		t.name = "Резак"
		t.visible = false
		_to_ship_layer(t)
		add_child(t)
		torches.append(t)
	for i in figures.size():
		if i < members.size():
			_build(i, members[i].look)
			figures[i].name = "Фигура %s" % members[i].name
		if figures[i] != null:
			figures[i].visible = i < members.size()
		torches[i].visible = false


## Модель фигуры i нужной внешности (пересобирается, если внешность сменилась).
func _build(i: int, look: int) -> void:
	look = clampi(look, 0, CrewRig.MODELS.size() - 1)
	if looks[i] == look and figures[i] != null:
		return
	if figures[i] != null:
		figures[i].queue_free()
	if not _scenes.has(look):
		_scenes[look] = load(CrewRig.MODELS[look])
	var root: Node3D = _scenes[look].instantiate()
	_to_ship_layer(root)
	add_child(root)
	var sk: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	var mi: MeshInstance3D = sk.find_children("*", "MeshInstance3D", true, false)[0]
	if not _rest.has(look):
		_rest[look] = rest_of(sk)
		var mat: Material = mi.mesh.surface_get_material(0).duplicate()
		if mat is BaseMaterial3D:
			(mat as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_BACK
		_own_mat[look] = mat
		_meshes[look] = [mi.mesh, cut_mesh(mi.mesh, mi.skin, sk, CrewRig.HIDE_HEAD + CrewRig.HIDE_CHEST, 0.15),
			cut_mesh(mi.mesh, mi.skin, sk, CrewRig.HIDE_HEAD + CrewRig.HIDE_TORSO, 0.15)]
	var att := BoneAttachment3D.new()
	att.bone_name = "LeftArm"
	sk.add_child(att)
	var patch := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = PATCH_SIZE
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.6
	box.material = mat
	patch.mesh = box
	patch.layers = LAYER_SHIP
	att.add_child(patch)
	figures[i] = root
	skeletons[i] = sk
	meshes[i] = mi
	patches[i] = patch
	looks[i] = look
	gear[i] = {}
	gear_roles[i] = -1


## Снаряжение роли на фигуре i (MOD-016): каждая деталь — BoneAttachment3D на своей кости, слой 2.
func _dress(i: int, role: int) -> void:
	if gear_roles[i] == role:
		return
	for n in gear[i].values():
		(n as Node).get_parent().queue_free()
	gear[i] = {}
	var rest: CrewRig.Rest = _rest[looks[i]]
	for g in CrewRig.ROLE_GEAR[clampi(role, 0, CrewRig.ROLE_GEAR.size() - 1)]:
		var att := BoneAttachment3D.new()
		att.bone_name = CrewRig.GEAR[g][0]
		skeletons[i].add_child(att)
		var node: Node3D = load("res://models/%s.glb" % g).instantiate()
		node.name = g
		node.transform = CrewRig.gear_xform(rest, g, looks[i])
		_to_ship_layer(node)
		att.add_child(node)
		gear[i][g] = node
	gear_roles[i] = role


## Покой скелета для CrewRig.
static func rest_of(sk: Skeleton3D) -> CrewRig.Rest:
	var names := PackedStringArray()
	var parents := PackedInt32Array()
	var local_rest: Array[Transform3D] = []
	for b in sk.get_bone_count():
		names.append(sk.get_bone_name(b))
		parents.append(sk.get_bone_parent(b))
		local_rest.append(sk.get_bone_rest(b))
	return CrewRig.Rest.new(names, parents, local_rest)


## Копия меша без треугольников, вершины которых больше чем наполовину держат кости hide (свой игрок не видит
## свою голову и грудь). Кости не трогаем: сжатые кости тянули бы за собой соседние вершины.
static func cut_mesh(mesh: Mesh, skin: Skin, sk: Skeleton3D, hide: Array, limit: float = 0.5) -> ArrayMesh:
	var hidden := {}
	for b in skin.get_bind_count():
		var bone := skin.get_bind_bone(b)
		var n: String = skin.get_bind_name(b) if bone < 0 else sk.get_bone_name(bone)
		if n in hide:
			hidden[b] = true
	var out := ArrayMesh.new()
	for si in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(si)
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var nv: int = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var per := bones.size() / maxi(nv, 1)
		var gone := PackedByteArray()
		gone.resize(nv)
		for v in nv:
			var w := 0.0
			for k in per:
				if hidden.has(bones[v * per + k]):
					w += weights[v * per + k]
			gone[v] = 1 if w > limit else 0
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var keep := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			if gone[idx[t]] == 0 and gone[idx[t + 1]] == 0 and gone[idx[t + 2]] == 0:
				keep.append_array([idx[t], idx[t + 1], idx[t + 2]])
		arr[Mesh.ARRAY_INDEX] = keep
		var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if per == 8 else 0
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
		out.surface_set_material(si, mesh.surface_get_material(si))
	return out


static func _to_ship_layer(n: Node) -> void:
	for m in n.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).layers = LAYER_SHIP


## Какой меш у фигуры: 0 — целый (другие), 1 — свой без головы и верха груди, 2 — свой стоя взглядом вниз, без груди
## (сидя, на сварке и с руками на посте — 1: руки держатся за плечи).
static func mesh_kind(m: Crew.Member, own: bool, look_pitch: float) -> int:
	if not own:
		return 0
	return 2 if not m.seated and not m.welding() and not m.holding() and look_pitch < LEGS_PITCH else 1


func apply() -> void:
	for i in members.size():
		var m: Crew.Member = members[i]
		_build(i, m.look)
		var own: bool = m == local
		var j := m.joints()
		var g := CrewRig.pose(_rest[looks[i]], j, CrewRig.SEAT_BEND if m.seated else 0.0)
		var sk := skeletons[i]
		for b in g.size():
			var p := sk.get_bone_parent(b)
			var lp: Transform3D = g[b] if p < 0 else g[p].affine_inverse() * g[b]
			sk.set_bone_pose_position(b, lp.origin)
			sk.set_bone_pose_rotation(b, lp.basis.get_rotation_quaternion())
		figures[i].position = Vector3.ZERO   # свой игрок стоя позади камеры — Crew.Member.back
		var like_own: bool = own or m in as_own
		var kind := 1 if like_own and not own else mesh_kind(m, own, pitch)
		meshes[i].mesh = _meshes[looks[i]][kind]
		meshes[i].material_override = _own_mat[looks[i]] if like_own else null
		patches[i].visible = not own  # своя нашивка у самой камеры
		_dress(i, m.role)
		for gn in gear[i]:
			var node: Node3D = gear[i][gn]
			node.visible = not (own and gn in CrewRig.GEAR_OWN_HIDDEN)
			if gn == "gear-shchitok":   # щиток поднят, на сварке опущен
				node.transform = CrewRig.visor_xform(_rest[looks[i]], looks[i], not m.welding())
		(patches[i].mesh.material as StandardMaterial3D).albedo_color = Crew.role_color(m.role)
		var rest: CrewRig.Rest = _rest[looks[i]]
		var at := {}
		for pair in [["hip", "Hips"], ["neck", "neck"], ["shoulder_l", "LeftArm"],
				["shoulder_r", "RightArm"], ["elbow_l", "LeftForeArm"], ["elbow_r", "RightForeArm"],
				["wrist_l", "LeftHand"], ["wrist_r", "RightHand"], ["knee_l", "LeftLeg"], ["knee_r", "RightLeg"],
				["ankle_l", "LeftFoot"], ["ankle_r", "RightFoot"], ["toe_l", "LeftToeBase"], ["toe_r", "RightToeBase"]]:
			var bn: String = pair[1]
			if own and (bn in CrewRig.HIDE_HEAD or bn in CrewRig.HIDE_CHEST):
				continue
			at[pair[0]] = g[rest.idx(bn)].origin + figures[i].position
		if not own:  # середина головы — между основанием и макушкой
			at["head"] = (g[rest.idx("Head")].origin + g[rest.idx("head_end")].origin) * 0.5
		for k in ["l", "r"]:  # середина кисти — для хвата
			at["hand_" + k] = g[rest.idx("LeftHand" if k == "l" else "RightHand")] * Vector3(0.0, CrewRig.GRIP, 0.0) \
				+ figures[i].position
		if shown.size() <= i:
			shown.resize(i + 1)
		shown[i] = at
		torches[i].visible = m.welding()
		if torches[i].visible:
			torches[i].transform = m.torch_xform()
		if i < alphas.size():
			_fade(i, alphas[i])


## Фигура i со снаряжением и резаком — полупрозрачная (`alphas`): копии её материалов с прозрачностью на поверхностях
## узлов (общие материалы моделей не трогаем), дальше меняется только альфа цвета.
func _fade(i: int, alpha: float) -> void:
	for root: Node in [figures[i], torches[i]]:
		for n: Node in root.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi.mesh == null:
				continue
			if not mi.has_meta("fade"):
				var mats: Array[BaseMaterial3D] = []
				for k in mi.mesh.get_surface_count():
					var src := mi.get_active_material(k)
					if src is BaseMaterial3D:
						var d: BaseMaterial3D = src.duplicate()
						d.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
						mi.set_surface_override_material(k, d)
						mats.append(d)
				mi.set_meta("fade", mats)
			for d: BaseMaterial3D in mi.get_meta("fade"):
				d.albedo_color.a = alpha
