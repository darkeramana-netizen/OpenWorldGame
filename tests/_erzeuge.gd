extends SceneTree
func _initialize() -> void:
	print("lade")
	var e = load("res://werkzeuge/gelaende_ashenveil.gd").new()
	print("neu")
	var t := Time.get_ticks_msec()
	for i in 1000: e.hoehe(Vector2(i % 400 - 200, i / 5 - 100))
	print("1000 Punkte: ", Time.get_ticks_msec() - t, " ms")
	quit()
