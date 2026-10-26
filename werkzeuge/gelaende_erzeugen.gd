@tool
extends EditorScript
## Erzeugt das Gelände neu: Datei öffnen und Datei → Ausführen (Strg+Umschalt+X).
## Was erzeugt wird, steht in werkzeuge/gelaende_erzeuger.gd (Region Drachenstein)
## werkzeuge/gelaende_riverlock.gd (Riverlock), werkzeuge/gelaende_ashenveil.gd (Ashenveil)
## und werkzeuge/gelaende_strasse.gd (die drei Landstraßen).


func _run() -> void:
	for erzeuger: GelaendeErzeuger in [GelaendeErzeuger.new(), GelaendeRiverlock.new(), GelaendeAshenveil.new(),
			GelaendeStrasse.new("nordstrasse"), GelaendeStrasse.new("suedstrasse"), GelaendeStrasse.new("kuestenweg")]:
		var zeit := Time.get_ticks_msec()
		var punkte := erzeuger.erzeuge()
		print("Gelände %s erzeugt: %d Höhenpunkte in %.1f s. Szene neu öffnen, um es zu sehen." % [
			erzeuger.zielordner, punkte, (Time.get_ticks_msec() - zeit) / 1000.0])
	EditorInterface.get_resource_filesystem().scan()
