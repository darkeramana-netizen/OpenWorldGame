extends SceneTree
## Prüft die Region Riverlock und das Reisen zwischen den Regionen mit echtem Gehen und echten Tasten:
## Überfahrt mit der Lotsin hin und zurück, Rampen durch die drei Geschosse des Mittelbaus,
## Wege durch Westburg und Ostburg, Personen, Wasser, Speichern und Laden in Riverlock.
## Starten: godot --headless --path . --script res://tests/test_riverlock.gd

var fehler := 0
var orte: Array = []
var optionen: Array = []
var meldungen: Array = []
var D; var S; var SP; var Z

func pruefe(bed: bool, was: String) -> void:
	if bed: print("OK     ", was)
	else:
		fehler += 1
		print("FEHLER ", was)

func spieler() -> Node:
	return current_scene.get_node("Spieler")

func setze(pos: Vector3) -> void:
	spieler().global_position = pos
	spieler().velocity = Vector3.ZERO
	for i in 4: await physics_frame

## Läuft nacheinander zu den Wegpunkten (x, z). Gibt zurück, ob alle erreicht wurden.
func gehe_ueber(punkte: Array, zeit_pro_punkt: float = 20.0) -> bool:
	Input.action_press("vor")
	var alle := true
	for ziel: Vector2 in punkte:
		var ende := Time.get_ticks_msec() + int(zeit_pro_punkt * 1000)
		var erreicht := false
		while Time.get_ticks_msec() < ende:
			var p: Vector3 = spieler().global_position
			var weg := Vector2(ziel.x - p.x, ziel.y - p.z)
			if weg.length() < 0.7:
				erreicht = true
				break
			spieler().get_node("KameraDrehpunkt").rotation.y = atan2(-weg.x, -weg.y)
			await physics_frame
		alle = alle and erreicht
		if not erreicht:
			print("       nicht erreicht: Ziel %s, stehe bei %s" % [ziel, spieler().global_position.snapped(Vector3.ONE * 0.1)])
			break
	Input.action_release("vor")
	for i in 3: await physics_frame
	return alle

func druecke(code: Key) -> void:
	for gedrueckt in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.pressed = gedrueckt
		Input.parse_input_event(e)
		await process_frame
		await process_frame

## Spricht mit E an und wählt nacheinander die angegebenen Zifferntasten.
## Bei reinem Erzähltext ohne Antworten wird E gedrückt.
func rede(tasten: Array) -> bool:
	await druecke(KEY_E)
	var offen: bool = D.aktiv
	var i := 0
	var n := 0
	while D.aktiv and n < 30:
		n += 1
		if optionen.is_empty():
			await druecke(KEY_E)
		elif i < tasten.size():
			await druecke(tasten[i])
			i += 1
		else:
			break
	if D.aktiv:
		D.beende()
	return offen

## Wartet, bis die Szene gewechselt hat (Reise oder Laden), höchstens einige Sekunden.
## alte_id: get_instance_id() der Szene vor dem Wechsel (die Szene selbst ist danach freigegeben).
func warte_auf_szene(alte_id: int) -> bool:
	for i in 600:
		await process_frame
		if current_scene != null and current_scene.get_instance_id() != alte_id and current_scene.is_node_ready():
			for k in 5: await physics_frame
			return true
	return false

## Wartet, bis eine laufende Blende vorbei ist (höchstens 12 Sekunden).
func warte_auf_blende() -> bool:
	var ende := Time.get_ticks_msec() + 12000
	while S.eingabe_gesperrt and Time.get_ticks_msec() < ende:
		await process_frame
	return not S.eingabe_gesperrt

func region_id() -> String:
	var id = current_scene.get("region_id") if current_scene != null else null
	return id if id != null else ""

func _initialize() -> void:
	await process_frame
	D = root.get_node("Dialog"); S = root.get_node("Spielstand"); SP = root.get_node("Speicher"); Z = root.get_node("Spielzeit")
	SP.ordner = "user://speicher_test_riverlock/"
	S.ort_betreten.connect(func(n, _u): orte.append(n))
	S.meldung.connect(func(t): meldungen.append(t))
	D.zeile_gezeigt.connect(func(_s, _t, o): optionen = o)
	SP.neues_spiel("Ansel")
	await scene_changed
	for i in 5: await process_frame
	pruefe(region_id() == "drachenstein" and SP.region == "drachenstein", "Neues Spiel beginnt in der Region Drachenstein")

	# --- Als Anwärter nimmt die Lotsin niemanden mit ---
	var lotsin = current_scene.get_node("Personen/Lotsin")
	await setze(lotsin.global_position + Vector3(0, 0.3, 1.5))
	await rede([KEY_4])
	pruefe(region_id() == "drachenstein", "Lotsin nimmt einen Anwärter nicht mit")

	# --- Als Wächter mit der Lotsin nach Riverlock ---
	current_scene.get_node("Entwickler").ueberspringe_akt1()
	var tag_vorher: int = Z.tag
	var szene_vorher := current_scene.get_instance_id()
	await setze(lotsin.global_position + Vector3(0, 0.3, 1.5))
	await rede([KEY_4])
	var gereist := await warte_auf_szene(szene_vorher)
	pruefe(gereist and region_id() == "riverlock" and SP.region == "riverlock", "Mit der Lotsin nach Riverlock gefahren")
	var ankunft: Vector3 = current_scene.get_node("Ankuenfte/von_drachenstein").global_position
	pruefe(spieler().global_position.distance_to(ankunft) < 1.5, "In der Hafenhalle angekommen")
	pruefe(Z.tag >= tag_vorher + 2, "Die Überfahrt dauert gut zwei Tage (Tag %d → %d)" % [tag_vorher, Z.tag])
	pruefe(await warte_auf_blende(), "Blende nach der Ankunft ist vorbei")

	# --- Durch die drei Geschosse des Mittelbaus ---
	var hinauf := await gehe_ueber([Vector2(-47, 15.8), Vector2(-40, 15.8), Vector2(-40, -13.5), Vector2(-36, -14)])
	pruefe(hinauf and absf(spieler().global_position.y) < 0.3, "Rampe von der Hafenhalle ins Mittelgeschoss")
	var durch := await gehe_ueber([Vector2(-34, 2.5), Vector2(-16, 2.5), Vector2(0, 2.5), Vector2(16, 2.5), Vector2(18.5, 2.5), Vector2(18.5, -16),
			Vector2(47.5, -16), Vector2(47.5, -11)])
	pruefe(durch and absf(spieler().global_position.y - 6.0) < 0.3, "Durch Wachstube, Zoll und Kontrolle, Rampe hinauf ins obere Geschoss")
	var saal := await gehe_ueber([Vector2(40, 0), Vector2(31, 0), Vector2(27, 0), Vector2(20, -8), Vector2(1.5, -8.2)])
	pruefe(saal and orte.has("Großer Saal"), "In den Großen Saal gegangen")
	pruefe(await rede([KEY_3]), "Mit Zollherr Hendrik Falk gesprochen")
	pruefe(S.akte.any(func(e): return "Falk" in str(e)), "Gespräch mit dem Zollherrn steht in der Akte")

	# --- Personen mit E ---
	for eintrag in [["Beobachter", Vector3(0, 0, -1.6)], ["Zoellnerin", Vector3(0, 0, -1.5)], ["TorwacheWestburg", Vector3(0, 0, 1.5)]]:
		var person = current_scene.get_node("Personen/" + eintrag[0])
		await setze(person.global_position + eintrag[1] + Vector3(0, 0.3, 0))
		pruefe(await rede([KEY_1]), "Mit E angesprochen: " + person.anzeige_name)

	# --- Über die Brücke von Burg zu Burg ---
	await setze(Vector3(0, 0.3, 2.5))
	var westen := await gehe_ueber([Vector2(-50, 2.5), Vector2(-66, 2.5), Vector2(-76, 12), Vector2(-88, 40), Vector2(-92.4, 52),
			Vector2(-92.4, 62)])
	pruefe(westen and orte.has("Westburg"), "Vom Mittelbau durch die Westburg zum Äußeren Tor (1)")
	await setze(Vector3(0, 0.3, 2.5))
	var osten := await gehe_ueber([Vector2(52, 2.5), Vector2(70, 2.5), Vector2(90, 20), Vector2(100, 52), Vector2(142.4, 62),
			Vector2(142.4, 80)])
	pruefe(osten and orte.has("Ostburg"), "Vom Mittelbau durch die Ostburg zum Äußeren Tor (23)")

	# --- Wasser und Rand ---
	meldungen.clear()
	await setze(Vector3(0, -12, 70))
	for i in 60: await physics_frame
	pruefe(spieler().global_position.y > -10.5 and meldungen.has("Die Valn ist zu reißend zum Schwimmen."), "Aus der Valn zurückgesetzt")

	# --- Speichern und Laden in Riverlock ---
	await setze(Vector3(-80, 0.3, 0))
	pruefe(SP.speichern("1"), "In Riverlock gespeichert")
	szene_vorher = current_scene.get_instance_id()
	SP.laden("1")
	await warte_auf_szene(szene_vorher)
	pruefe(region_id() == "riverlock" and spieler().global_position.distance_to(Vector3(-80, 0, 0)) < 1.0, "Geladen: wieder in der Westburg von Riverlock")

	# --- Mit der Lotsin zurück nach Drachenkai ---
	lotsin = current_scene.get_node("Personen/Lotsin")
	await setze(lotsin.global_position + Vector3(1.5, 0.3, 0))
	szene_vorher = current_scene.get_instance_id()
	await rede([KEY_4])
	gereist = await warte_auf_szene(szene_vorher)
	ankunft = current_scene.get_node("Ankuenfte/von_riverlock").global_position
	pruefe(gereist and region_id() == "drachenstein" and spieler().global_position.distance_to(ankunft) < 1.5,
			"Mit der Lotsin zurück nach Drachenkai gefahren")
	await warte_auf_blende()

	# --- Entwicklermenü: Reise ohne Schiff ---
	szene_vorher = current_scene.get_instance_id()
	current_scene.get_node("Entwickler").reise("riverlock")
	await warte_auf_szene(szene_vorher)
	pruefe(region_id() == "riverlock", "Entwicklermenü: Reise nach Riverlock")

	print("\nFehler: ", fehler)
	quit(fehler)
