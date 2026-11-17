extends SceneTree
## Tests für den Ladebildschirm (autoload/ladevorhang.gd) beim Wechsel in eine Region über Speicher.
## Starten: godot --headless --path . --script res://tests/test_ladevorhang.gd

var fehler := 0


func pruefe(bed: bool, was: String) -> void:
	if bed:
		print("OK     ", was)
	else:
		fehler += 1
		print("FEHLER ", was)


func _initialize() -> void:
	var SP = root.get_node("Speicher")
	var S = root.get_node("Spielstand")
	var L = root.get_node("Ladevorhang")
	SP.ordner = "user://speicher_test_vorhang/"
	await process_frame
	change_scene_to_file("res://szenen/oberflaeche/hauptmenue.tscn")
	await scene_changed
	for i in 3:
		await process_frame
	pruefe(not L.sichtbar, "Kein Vorhang im Hauptmenü")

	SP.neues_spiel("Test")
	await process_frame
	pruefe(L.sichtbar and S.eingabe_gesperrt, "Neues Spiel: Vorhang steht sofort, Eingabe gesperrt")
	var region_beim_wechsel := ""
	await scene_changed
	region_beim_wechsel = current_scene.scene_file_path
	pruefe(region_beim_wechsel.ends_with("region_drachenstein.tscn"), "Region im Hintergrund geladen und aufgebaut")
	pruefe(L.sichtbar and S.eingabe_gesperrt, "Nach dem Aufbau steht der Vorhang noch (Pipelines, Figuren)")
	await L.weg
	pruefe(not L.sichtbar and not S.eingabe_gesperrt, "Danach ist er weg und die Eingabe frei")
	pruefe(L.letzte_ladezeit_ms > 0.0, "Ladezeit gemessen (%.0f ms)" % L.letzte_ladezeit_ms)
	pruefe(L.figuren_wartend() == 0, "Alle Figuren gebaut, bevor der Vorhang fällt")

	# Reise in eine andere Region: wieder mit Vorhang, die Blende danach erst ohne ihn
	var blende_bei_vorhang := []
	S.blende.connect(func(_t: String, _a: String) -> void: blende_bei_vorhang.append(L.sichtbar))
	SP.reise("riverlock", "von_drachenstein", 0.0, "Ankunft")
	await process_frame
	pruefe(L.sichtbar, "Reise: Vorhang steht")
	await L.weg
	await process_frame
	pruefe(current_scene.scene_file_path.ends_with("region_riverlock.tscn"), "Reise: in Riverlock angekommen")
	pruefe(blende_bei_vorhang == [false], "Die Ankunftsblende kommt erst, wenn der Vorhang weg ist")

	SP.zum_hauptmenue()
	await scene_changed
	await process_frame
	pruefe(not L.sichtbar, "Zurück ins Hauptmenü ohne Vorhang")
	print("\nFehler: %d" % fehler)
	quit(1 if fehler > 0 else 0)
