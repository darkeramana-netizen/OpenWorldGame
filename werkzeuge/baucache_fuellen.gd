extends SceneTree
## Füllt den Baucache (szenen/welt/baucache.gd) für alle Regionen, ohne Fenster.
##
## Nach jeder Codeänderung passt der Schlüssel nicht mehr, und der erste Start baut alle Bauten neu (Drachenstein:
## Laden 22 s statt 9 s, 1,4 GB statt 0,65 GB Arbeitsspeicher, Messung 25.11.2026 18:41). Die Messwerkzeuge rufen
## dieses Skript nach dem Import auf, damit die erste Messung nicht den Neubau mitmisst.
##   godot --headless --path . --script res://werkzeuge/baucache_fuellen.gd

const Baucache := preload("res://szenen/welt/baucache.gd")


func _initialize() -> void:
	_lauf.call_deferred()


func _lauf() -> void:
	await process_frame
	var speicher: Node = root.get_node("Speicher")
	speicher.ordner = "user://baucache_fuellen_speicher/"
	root.get_node("Spielstand").zuruecksetzen("Baucache")
	for region: String in speicher.REGIONEN:
		var vorher := [Baucache.gebaut, Baucache.treffer]
		var t0 := Time.get_ticks_msec()
		speicher.ausstehender_spieler = {}
		speicher.region = region
		var instanz: Node = (load(speicher.REGIONEN[region]) as PackedScene).instantiate()
		root.add_child(instanz)
		current_scene = instanz
		for i in 5:
			await process_frame
		print("%s: %d gebaut, %d aus dem Cache, %d ms" % [region, Baucache.gebaut - vorher[0],
				Baucache.treffer - vorher[1], Time.get_ticks_msec() - t0])
		instanz.free()
		await process_frame
	quit()
