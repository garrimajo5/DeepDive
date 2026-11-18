extends SceneTree
## Полный цикл смены поста и возвращения к управлению в соло на макете ART-085 v3 — проверка ГД
## (#1788, 18.11): «проверить полный цикл смены поста и возвращения к управлению в соло».
## Пилот сидит (глаз EYE, рукоятки на подлокотниках) → встал → дошёл до поста капсулой игрока →
## занял пост (поза оператора, орган в досягаемости) → встал → вернулся → сел, рукоятки в зоне кисти.
## Счётно (`Maket085.walk` + `seat_check`), покрыто `test_maket085.test_post_cycle`. Headless.
##   godot --headless --path . -s tools/maket085_cycle.gd

const Maket := preload("res://tools/maket085.gd")


func _init() -> void:
	print("Цикл смены поста в соло, макет ART-085 v3: капсула Ø %.1f м, %.1f м/с; посадка/вставание — по %.1f с (допущение)." % [
			Maket.WALK_R * 2.0, Maket.WALK_SPEED, Maket.SIT_T])
	print("Досягаемость: комфорт %.2f м, предел %.2f м от плеча (UX Р-2)." % [Maket.REACH_OK, Maket.REACH_MAX])
	print("\nПилот в кресле v3: глаз %s, рукоятки на подлокотниках (±%.2f; %.2f; %.2f), худшая досягаемость %.2f м." % [
			Maket.EYE, Maket.ARMREST_X, Maket.GRIP_Y, Maket.GRIP_Z, Maket.pilot_grip_reach()])
	print("\nцикл пилот ↔ пост | туда, с | обратно, с | посадка, м | орган, м | цикл, с | итог")
	var all_ok := true
	var res := Maket.cycle_all()
	for pname: String in res:
		var c: Dictionary = res[pname]
		all_ok = all_ok and c["ok"]
		var note := "ок"
		if not c["seat_clear"]:
			note = "ЛИНИЯ ПОСАДКИ РЕЖЕТ КОНСОЛЬ"
		elif c["seat_dist"] > 0.9:
			note = "посадка дальше шага"
		elif c["reach"] > Maket.REACH_MAX:
			note = "ОРГАН ВНЕ ДОСЯГАЕМОСТИ"
		elif c["reach"] > Maket.REACH_OK:
			note = "на пределе досягаемости"
		print("%-22s | %8.1f | %11.1f | %10.2f | %9.2f | %8.1f | %s" % [
				"пилот ↔ " + pname, c["t_out"], c["t_back"], c["seat_dist"], c["reach"], c["t_cycle"], note])
	var tour := Maket.tour_all()
	print("\nПолный обход (пилот → инженер → биолог → сонар → пилот): %.1f с с посадками, %s." % [
			tour["time"], "проходим" if tour["ok"] else "НЕ ПРОХОДИМ"])
	print("\nВозврат к управлению: стояние пилота → кресло %.2f м, линия чиста; рукоятки %.2f м от плеча (зона кисти ≤ %.2f)." % [
			Maket.seat_check(Maket.POST_PILOT, Maket.STAND_PILOT)["dist"],
			Maket.pilot_grip_reach(), Maket.REACH_OK])
	print("\nВсе циклы проходимы и в досягаемости: %s." % ("да" if all_ok else "НЕТ"))
	quit()
