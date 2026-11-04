extends SceneTree
func _init():
	var w := EcoWorld.new()
	var k = w.add(EcoKelp.new())
	var kr = w.add(EcoKrab.new(k))
	print("DEN ", kr.crab.den, " out ", kr.crab.out)
	quit()
