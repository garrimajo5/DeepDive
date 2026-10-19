class_name Deck
## Палуба «Ковчега-7»: где можно стоять, посты кнопки действия и игрок на ногах.
## Оси корабля: нос в −Z, пол y = 0, правый борт (лицом к носу) — +X.
## Мостик по ART-002: 10 × 8 × 3,2 м, x −5…5, z −6…2 (носовая стена изнутри на z −5,9).

const BRIDGE_MIN := Vector2(-5.0, -6.0)  ## (x, z)
const BRIDGE_MAX := Vector2(5.0, 2.0)
const CEILING := 3.2
const NOSE_INNER := -5.9

## Препятствия на полу мостика: центр (x, z) и радиус. Голостол сонара — круг ~1,2 м.
const OBSTACLES: Array = [[Vector2(0.0, -1.2), 0.75]]


## Пост кнопки действия: точка на полу, радиус, подпись.
class Post:
	var at := Vector2.ZERO
	var r := 1.0
	var label := ""
	var id := ""

	func _init(post_id: String, p: Vector2, radius: float, text: String) -> void:
		id = post_id
		at = p
		r = radius
		label = text


static func can_stand(x: float, z: float, radius: float = Walker.RADIUS) -> bool:
	if x < BRIDGE_MIN.x + radius or x > BRIDGE_MAX.x - radius:
		return false
	if z < BRIDGE_MIN.y + radius or z > BRIDGE_MAX.y - radius:
		return false
	for o in OBSTACLES:
		if Vector2(x, z).distance_to(o[0]) < float(o[1]) + radius:
			return false
	return true


## Посты мостика. Штурвал: стоя у кресла пилота.
static func posts() -> Array[Post]:
	return [Post.new("helm", Vector2(0.0, -3.6), 1.0, "Штурвал")]


## Ближайший пост, в радиус которого попал игрок, или null.
static func nearest(posts_list: Array[Post], x: float, z: float) -> Post:
	var best: Post = null
	var bd := INF
	for p in posts_list:
		var d := p.at.distance_to(Vector2(x, z))
		if d <= p.r and d < bd:
			best = p
			bd = d
	return best


## Игрок на палубе. yaw — как rotation.y камеры: 0 — лицом к носу (−Z), растёт — поворот влево.
## Взгляд вверх — pitch > 0.
class Walker:
	const SPEED := 2.4
	const RADIUS := 0.35
	const EYE := 1.65
	const MAX_PITCH := 1.45
	const LOOK_SENS := 0.0055  ## радиан на «точку» экрана (1/160 дюйма), как в браузере

	var x := 0.0
	var z := -3.0
	var yaw := 0.0
	var pitch := -0.08
	var stand: Callable = Deck.can_stand

	func reset() -> void:
		x = 0.0
		z = -3.0
		yaw = 0.0
		pitch = -0.08

	func forward() -> Vector2:
		return Vector2(-sin(yaw), -cos(yaw))

	func right() -> Vector2:
		return Vector2(cos(yaw), -sin(yaw))

	## Крестовина: m.y — вперёд/назад, m.x — вправо/влево. Вдоль стены скользит по одной оси.
	func walk(m: Vector2, dt: float) -> void:
		if m.length() <= 0.0:
			return
		m = m.normalized()
		var d := (forward() * m.y + right() * m.x) * SPEED * dt
		if stand.call(x + d.x, z):
			x += d.x
		if stand.call(x, z + d.y):
			z += d.y

	## Свайп в «точках» экрана: палец вправо — поворот вправо, палец вверх (dy < 0) — взгляд вверх.
	func look(d: Vector2) -> void:
		yaw = wrapf(yaw - d.x * LOOK_SENS, -PI, PI)
		pitch = clampf(pitch - d.y * LOOK_SENS, -MAX_PITCH, MAX_PITCH)
