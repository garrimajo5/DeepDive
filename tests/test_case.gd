class_name TestCase
extends RefCounted
## Основа теста. Файл tests/test_*.gd наследует TestCase, каждый метод test_* — отдельный тест.
## Методы могут быть корутинами (await): сценовым тестам дан tree — дерево сцены раннера.

var tree: SceneTree
var failures: Array[String] = []


## Перед каждым тестом и после него (можно переопределить).
func before() -> void:
	pass


func after() -> void:
	pass


func ok(cond: bool, msg: String = "ожидалось true") -> bool:
	if not cond:
		failures.append(msg)
	return cond


func eq(got: Variant, want: Variant, msg: String = "") -> bool:
	if typeof(got) == typeof(want) and got == want:
		return true
	failures.append("%s: получено %s, ожидалось %s" % [msg if msg else "eq", str(got), str(want)])
	return false


func near(got: float, want: float, eps: float = 1e-6, msg: String = "") -> bool:
	if absf(got - want) <= eps:
		return true
	failures.append("%s: получено %.9f, ожидалось %.9f (±%s)" % [msg if msg else "near", got, want, eps])
	return false


## Ждать n кадров дерева.
func frames(n: int = 1) -> void:
	for i in n:
		await tree.process_frame
