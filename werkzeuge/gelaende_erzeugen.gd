@tool
extends EditorScript
## Erzeugt das Gelände neu: Datei öffnen und Datei → Ausführen (Strg+Umschalt+X).
## Was erzeugt wird, steht in werkzeuge/gelaende_erzeuger.gd.


func _run() -> void:
	var zeit := Time.get_ticks_msec()
	var punkte := GelaendeErzeuger.new().erzeuge()
	print("Gelände erzeugt: %d Höhenpunkte in %.1f s. Szene neu öffnen, um es zu sehen." % [
		punkte, (Time.get_ticks_msec() - zeit) / 1000.0])
	EditorInterface.get_resource_filesystem().scan()
