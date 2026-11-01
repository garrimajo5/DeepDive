class_name EcoGlow
## Биолюминесценция живого мира — один приём свечения (Б1, `docs/grafika-plan-eco.md`, часть 1). Свечение тел со
## светом (пятнышки ледокрыла, светляки, кончики огнецвета и Каменного цветка, обрастание камня, щупальца хватней,
## ленты и трубы растений) идёт через общий кусок GLSL `GLSL`: `EMISSION = eco_bio(…)` умножает своё свечение вида
## на uniform `bio` — одну на всех ручку яркости, что цветёт в bloom (порог `Main` — `env.glow_hdr_threshold`). Числа
## видов (их доли 1,4…1,8) не тронуты: при `gain` = 1 картинка прежняя. Ставит `apply(root)` из `EcoView` (как ободок
## `EcoRim`); свои шейдеры берут uniform, у StandardMaterial3D со свечением (модели художника) — множитель энергии
## свечения. Новое тело со своим свечением — только через `eco_bio`, иначе валит `tests/test_eco_glow.gd`.
## Шейдеров не прибавляет: кусок — в тех же шейдерах. Подсветка камня `fill` (не свечение) — мимо `eco_bio`.
## Прозрачное без света (MIST, SPOT: купола, планктон, споры) — часть 2.

const GLSL := """
uniform float bio = 1.0;
vec3 eco_bio(vec3 e) {
	return e * bio;
}
"""
## Общая яркость свечения мира (1 — числа видов как есть).
const GAIN := 1.0

static var gain := GAIN
## Тронутые материалы: [слабая ссылка, своя энергия свечения у StandardMaterial3D (у шейдера — 1)].
static var _mats: Array = []


## Свечение под root (EcoView): всем материалам со своим свечением — множитель gain. Повторный вызов безопасен.
static func apply(root: Node) -> void:
	if root is GeometryInstance3D:
		for m in EcoRim.materials(root as GeometryInstance3D):
			track(m)
	for c in root.get_children():
		apply(c)


## Один материал: свой шейдер с uniform bio или StandardMaterial3D со свечением. Возвращает, тронут ли.
static func track(m: Material) -> bool:
	if m == null:
		return false
	for e in _mats:
		if e[0].get_ref() == m:
			_put(m, float(e[1]))
			return true
	var base := 1.0
	if m is BaseMaterial3D:
		var b := m as BaseMaterial3D
		if not b.emission_enabled:
			return false
		base = b.emission_energy_multiplier
	elif not (m is ShaderMaterial and has_uniform(m as ShaderMaterial)):
		return false
	_mats.append([weakref(m), base])
	_put(m, base)
	return true


static func _put(m: Material, base: float) -> void:
	if m is BaseMaterial3D:
		(m as BaseMaterial3D).emission_energy_multiplier = base * gain
	elif m is ShaderMaterial:
		(m as ShaderMaterial).set_shader_parameter("bio", gain)


## Есть ли у шейдера материала общий приём свечения.
static func has_uniform(m: ShaderMaterial) -> bool:
	return m.shader != null and m.shader.code.contains("uniform float bio")


## Общая яркость свечения: меняются только числа (шейдер тот же).
static func set_gain(k: float) -> void:
	gain = maxf(k, 0.0)
	var alive: Array = []
	for e in _mats:
		var m: Material = e[0].get_ref()
		if m == null:
			continue
		alive.append(e)
		_put(m, float(e[1]))
	_mats = alive


## Своё свечение вида после приёма (двойник eco_bio).
static func bio(e: Color) -> Color:
	return Color(e.r * gain, e.g * gain, e.b * gain)
