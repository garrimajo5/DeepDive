class_name EcoSilhouette
## Читаемый силуэт крупного существа в полумраке (Б4, `docs/grafika-plan-eco.md`): вода вокруг тела рассеивает
## свет, и край тела по касательной к взгляду светится слабым ореолом цвета воды — серпохвост читается формой и
## без луча прожектора, а на мелководье (светло, свет сквозь лёд) ореола почти нет. Ободок света `EcoRim` считается
## от огней и в темноте гаснет — этот приём от огней не зависит.
## Приём — второй проход материала (`next_pass`) у тел серпохвоста (StandardMaterial3D из GLB — своего шейдера нет):
## скин тот же, оболочка чуть раздута по нормали, без света, сложением, тумана Godot нет (сложение с туманом
## осветлило бы воду) — гаснет с расстоянием сам по плотности воды (`fade`, uniform `density`). Материалы GLB общие у
## трёх зверей — проход ставится один раз: +1 шейдер, +1 вызов на сетку (3 на зверя). Ледокрыл светится сам
## (EMISSION в `RayView`) — ему не нужно. «Экономно» — проход снят (`set_lite`): вызовов как раньше.
## Цвет и сила — по глубине корабля (`set_depth` из `EcoView._sync`). Проверяет `tests/test_eco_silhouette.gd`.

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;
uniform vec3 halo_color = vec3(0.0);
uniform float halo = 0.0;
uniform float density = 0.02;
uniform float power = 3.0;
uniform float grow = 0.01;
void vertex() {
	VERTEX += NORMAL * grow;
}
void fragment() {
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), power);
	float dist = length(VERTEX);
	ALBEDO = halo_color * halo * edge * exp(-density * dist);
}
"""

## Существа с ореолом (имена узлов EcoView).
const CREATURES: Array[String] = ["Серпохвосты"]
## Яркость ореола на краю (линейная, самый яркий канал цвета воды), сила на мелководье и в глубине, где растёт.
const LEVEL := 0.7
const SHALLOW := 0.15
const DEEP := 1.0
const FROM := 8.0
const TO := 60.0
## Оболочка раздута по нормали (м) — проход не бьётся с телом по глубине; крутизна края.
const GROW := 0.01
const POWER := 3.0

static var lite := false
## Глубина последней записи в материал (м) и шаг, мельче которого не пишем (каждый кадр не нужно).
static var _depth := -1e9
const DEPTH_STEP := 0.25
static var material: ShaderMaterial
## Тела, которым поставлен проход: [слабая ссылка на материал].
static var _mats: Array = []


## Общий материал ореола.
static func halo_material() -> ShaderMaterial:
	if material == null:
		material = ShaderMaterial.new()
		material.shader = EcoShaders.shader(SHADER)
		material.set_shader_parameter("power", POWER)
		material.set_shader_parameter("grow", GROW)
		set_depth(20.0)
	return material


## Поставить ореол телам крупных существ под root (EcoView). Повторный вызов безопасен.
static func apply(root: Node) -> void:
	for c in root.get_children():
		if String(c.name) in CREATURES:
			for gi in EcoShadows.casters(c):
				for m in EcoRim.materials(gi):
					halo(m)


## Ореол одному материалу: только освещаемое непрозрачное тело. Возвращает, тронут ли материал.
static func halo(m: Material) -> bool:
	if not (m is BaseMaterial3D):
		return false
	var b := m as BaseMaterial3D
	if b.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED \
			or b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return false
	b.next_pass = null if lite else halo_material()
	for e in _mats:
		if e[0].get_ref() == m:
			return true
	_mats.append([weakref(m)])
	return true


## Сила ореола на глубине (м): на мелководье слабая, к темноте — полная.
static func strength(depth: float) -> float:
	return lerpf(SHALLOW, DEEP, HashNoise.smooth(FROM, TO, depth))


## Цвет ореола на глубине: оттенок воды (`Seabed.Water.fog_color`, линейный), самый яркий канал — LEVEL. Вода на
## склоне почти чёрная, но оттенок тот же — ореол не гаснет вместе с ней.
static func color(depth: float) -> Color:
	var c := Seabed.Water.fog_color(depth).srgb_to_linear()
	var top := maxf(c.r, maxf(c.g, c.b))
	if top <= 0.0:
		return Color(0, 0, 0)
	return Color(c.r / top * LEVEL, c.g / top * LEVEL, c.b / top * LEVEL)


## Доля ореола на расстоянии dist (м) при плотности воды density — двойник шейдера.
static func fade(dist: float, density: float) -> float:
	return exp(-density * dist)


## Яркость края (доля 0…1) при косинусе угла нормали к взгляду — двойник шейдера.
static func edge(n_dot_v: float) -> float:
	return pow(1.0 - clampf(n_dot_v, 0.0, 1.0), POWER)


## Глубина корабля (м): цвет, сила и плотность воды в материал.
static func set_depth(depth: float) -> void:
	if material != null and absf(depth - _depth) < DEPTH_STEP:
		return
	_depth = depth
	var m := halo_material()
	var c := color(depth)
	m.set_shader_parameter("halo_color", Vector3(c.r, c.g, c.b))
	m.set_shader_parameter("halo", strength(depth))
	m.set_shader_parameter("density", Seabed.Water.fog_density(depth))


## «Экономно»: снять (или вернуть) проход у всех тел — вызовов как без ореола.
static func set_lite(on: bool) -> void:
	lite = on
	var alive: Array = []
	for e in _mats:
		var m: BaseMaterial3D = e[0].get_ref()
		if m == null:
			continue
		alive.append(e)
		m.next_pass = null if on else halo_material()
	_mats = alive
