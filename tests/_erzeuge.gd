extends SceneTree
func _init() -> void:
	print("Punkte: ", load("res://werkzeuge/gelaende_erzeuger.gd").new().erzeuge())
	quit()
