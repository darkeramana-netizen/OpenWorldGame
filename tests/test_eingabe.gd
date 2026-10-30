extends SceneTree
## Prüft echte Tastendrücke (E, Zifferntasten) statt direkter Funktionsaufrufe.
## Starten: godot --headless --path . --script res://tests/test_eingabe.gd

var fehler := 0

func pruefe(bed: bool, was: String) -> void:
	if bed: print("OK     ", was)
	else:
		fehler += 1
		print("FEHLER ", was)

func druecke(code: Key) -> void:
	for gedrueckt in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.pressed = gedrueckt
		Input.parse_input_event(e)
		await process_frame
		await process_frame

func _initialize() -> void:
	var SP = root.get_node("Speicher"); var D = root.get_node("Dialog"); var S = root.get_node("Spielstand")
	SP.ordner = "user://speicher_test_e/"
	await process_frame
	change_scene_to_file("res://szenen/oberflaeche/hauptmenue.tscn")
	await scene_changed
	for i in 5: await process_frame
	SP.neues_spiel("Test")
	await scene_changed
	for i in 5: await process_frame
	var sp = current_scene.get_node("Spieler")
	var hinweis = current_scene.get_node("HUD/Hinweis")
	sp.global_position = Vector3(3, 14.1, 36.5)
	for i in 5: await physics_frame
	pruefe(hinweis.text == "[E] Sprechen – Kammerhüter Wendel Groth", "Hinweis beim Kammerhüter")
	await druecke(KEY_E)
	pruefe(D.aktiv, "E öffnet das Gespräch")
	for i in 8:
		await druecke(KEY_1)
	pruefe(not D.aktiv and S.rang == 1, "Mit Taste 1 durch das Vorgespräch bis zum Gelöbnis")
	S.setze_flag("aufgabe_steine")
	sp.global_position = Vector3(17, 14.1, 8.5)
	for i in 5: await physics_frame
	pruefe(hinweis.text == "[E] Aufheben – Bruchstein", "Hinweis beim Bruchstein")
	await druecke(KEY_E)
	pruefe(S.zaehler_wert("bruchsteine") == 1, "E hebt den Stein auf")
	sp.global_position = Vector3(-12, 22.2, 31)
	for i in 5: await physics_frame
	pruefe(hinweis.text == "[E] Sprechen – Hüter Anselm Kray", "Hinweis oben auf dem Wehrgang")
	sp.global_position = Vector3(-14, 14.1, 26)
	for i in 5: await physics_frame
	pruefe(hinweis.text == "", "Kein Ansprechen durch die Mauer von unten")
	print("\nFehler: ", fehler)
	quit(fehler)
