extends SceneTree
## Prüft Stufe 4 mit echten Tasten und Mausklicks: Ansehen, Alarmstufen (Ring der Feuer, leere Märkte,
## keine Boote), Kampf (Säbel, Muskete, Bajonett, Nachladen, Block), Gesetzlose und Auftrag, Verwundung,
## Verfahren beim Kammerhüter bis zur Ausstoßung, Speichern und Laden.
## Starten: godot --headless --path . --script res://tests/test_stufe4.gd

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

func warte_auf_blende() -> bool:
	var ende := Time.get_ticks_msec() + 12000
	while S.eingabe_gesperrt and Time.get_ticks_msec() < ende:
		await process_frame
	return not S.eingabe_gesperrt

func region_id() -> String:
	var id = current_scene.get("region_id") if current_scene != null else null
	return id if id != null else ""

func reise(ziel: String) -> void:
	var alt := current_scene.get_instance_id()
	current_scene.get_node("Entwickler").reise(ziel)
	await warte_auf_szene(alt)
	Z.minuten = 12 * 60.0  # nicht in der Stille-Stunde, da schweigen alle
	Z.vorspulen(0.0)

func kampf() -> Node:
	return spieler().get_node("Kampf")

func klick(knopf: MouseButton) -> void:
	for gedrueckt in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = knopf
		e.pressed = gedrueckt
		Input.parse_input_event(e)
		await process_frame
		await process_frame

func warte(sekunden: float) -> void:
	var ende := Time.get_ticks_msec() + int(sekunden * 1000)
	while Time.get_ticks_msec() < ende:
		await physics_frame

## Stellt die Figur vor ein Ziel (abstand Meter, von Süden) und dreht Kamera und Körper nach Norden.
func vor_ziel(ziel: Node3D, abstand: float, seitlich: float = 0.0) -> void:
	await setze(ziel.global_position + Vector3(seitlich, 0.3, abstand))
	spieler().get_node("KameraDrehpunkt").rotation = Vector3(0, 0, 0)
	spieler().get_node("Koerper").rotation.y = 0.0
	for i in 4: await physics_frame

## Zieht die Waffe, falls nötig, und wählt sie.
func waffe(art: String) -> void:
	if not kampf().gezogen:
		await druecke(KEY_F)
	if kampf().waffe != art:
		await druecke(KEY_Q)

func optionen_von(person: Node3D) -> Array:
	await setze(person.global_position + Vector3(0, 0.3, 1.4))
	await druecke(KEY_E)
	var n := 0
	while D.aktiv and optionen.is_empty() and n < 5:
		await druecke(KEY_E)
		n += 1
	var texte := optionen.duplicate()
	if D.aktiv: D.beende()
	return texte

func _initialize() -> void:
	await process_frame
	D = root.get_node("Dialog"); S = root.get_node("Spielstand"); SP = root.get_node("Speicher"); Z = root.get_node("Spielzeit")
	SP.ordner = "user://speicher_test_stufe4/"
	var blenden: Array = []
	S.blende.connect(func(t, art): blenden.append([t, art]))
	S.meldung.connect(func(t): meldungen.append(t))
	D.zeile_gezeigt.connect(func(_s, _t, o): optionen = o)
	SP.neues_spiel("Ansel")
	await scene_changed
	for i in 5: await process_frame
	current_scene.get_node("Entwickler").ueberspringe_akt1()
	pruefe(S.alarmstufe == 1 and "Alarmstufe 1" in current_scene.get_node("HUD/Alarm").text, "1750 gilt Alarmstufe 1 (Wachsamkeit), oben rechts angezeigt")

	# --- Ansehen: Haltung gegenüber Riverlock im Gespräch mit dem Zollherrn ---
	await reise("riverlock")
	var falk = current_scene.get_node("Personen/ZollherrFalk")
	await setze(falk.global_position + Vector3(1.5, 0.3, -1.6))
	await rede([KEY_4])
	pruefe(S.ansehen_wert("riverlock") == 8 and S.pruefe_bedingung("ansehen_riverlock>=8"), "Ansehen bei Riverlock steigt durch die Antwort an Falk")
	pruefe(not (await optionen_von(falk)).has("Riverlock ist frei. Der Orden achtet das."), "Die Haltung zählt nur einmal")

	# --- Gesetzlose an der Südstraße: Auftrag, Kampf, Meldung ---
	await reise("suedstrasse")
	var wache = current_scene.get_node("Personen/Bezirkswache")
	await setze(wache.global_position + Vector3(0, 0.3, 1.4))
	await rede([KEY_4])
	pruefe(S.hat_flag("auftrag_gesetzlose") and "Gesetzlosen" in S.ziel, "Auftrag der Bezirkswache: das Lager der Gesetzlosen räumen")
	var g1 = current_scene.get_node("Lager/Gesetzloser1")
	await setze(g1.global_position + Vector3(0, 0.3, 4))
	var ende := Time.get_ticks_msec() + 5000
	while kampf().leben >= kampf().LEBEN_MAX and Time.get_ticks_msec() < ende:
		await physics_frame
	pruefe(g1.wach and kampf().leben < kampf().LEBEN_MAX, "Die Gesetzlosen bemerken dich, greifen an und treffen (Leben %d)" % kampf().leben)
	await waffe("saebel")
	Input.action_press("blocken")
	await warte(0.3)
	pruefe(kampf().blockt, "Mit dem Säbel blocken (rechte Maustaste)")
	Input.action_release("blocken")
	kampf().leben = 100000.0  # für den Test: nicht verwundet werden
	for k in 3:
		var g = current_scene.get_node("Lager/Gesetzloser%d" % (k + 1))
		var n := 0
		while not g.besiegt and n < 30:
			await vor_ziel(g, 1.7)
			await klick(MOUSE_BUTTON_LEFT)
			await warte(0.9)
			n += 1
	pruefe(S.zaehler_wert("gesetzlose_besiegt") == 3 and S.hat_flag("gesetzlose_3"), "Alle drei Gesetzlosen mit dem Säbel besiegt")
	kampf().leben = kampf().LEBEN_MAX
	await druecke(KEY_F)
	var doerfer_vorher: int = S.ansehen_wert("doerfer")
	await setze(wache.global_position + Vector3(0, 0.3, 1.4))
	await rede([KEY_4])
	pruefe(S.hat_flag("gesetzlose_gemeldet") and S.ansehen_wert("doerfer") == doerfer_vorher + 10, "Gemeldet: Ansehen bei den Dörfern steigt")
	pruefe(SP.speichern("1"), "Nach dem Kampf gespeichert")
	var alt := current_scene.get_instance_id()
	SP.laden("1")
	await warte_auf_szene(alt)
	pruefe(current_scene.get_node("Lager/Gesetzloser1").besiegt and S.ansehen_wert("riverlock") == 8, "Geladen: Besiegte liegen noch, Ansehen ist gespeichert")

	# --- Verwundung ---
	var minuten: float = Z.absolute_minuten()
	kampf().leben = 5.0
	kampf().treffer(45.0, null, "schuss")
	await warte(0.2)
	var heil: Vector3 = current_scene.get_node("Ankuenfte/heilstube").global_position
	pruefe(spieler().global_position.distance_to(heil) < 1.5 and kampf().leben == kampf().LEBEN_MAX and Z.absolute_minuten() - minuten >= 11 * 60,
			"Schwer verwundet: geborgen in der Bezirksfestung, ein halber Tag vergeht")
	pruefe(S.akte.back()["art"] == "verwundung" or S.akte.any(func(e): return e["art"] == "verwundung"), "Verwundung steht in der Akte")
	await warte_auf_blende()

	# --- Alarmstufe 2: Ring der Feuer, leere Märkte, keine Boote ---
	await reise("drachenstein")
	var feuer = current_scene.get_node("Signaltuerme/Signalturm1/Feuer")
	var haendlerin = current_scene.get_node("Personen/PersonenAmBoden/Haendlerin")
	pruefe(not feuer.visible and haendlerin.visible, "Bei Alarmstufe 1 brennen keine Feuer, der Markt ist offen")
	blenden.clear()
	current_scene.get_node("Entwickler").setze_alarm(2)
	await process_frame
	pruefe(feuer.visible and not haendlerin.visible and blenden.size() > 0 and "Ring der Feuer" in blenden[0][0], "Alarmstufe 2: Der Ring der Feuer brennt, der Markt leert sich")
	await warte_auf_blende()
	var lotsen_optionen: Array = await optionen_von(current_scene.get_node("Personen/Lotsin"))
	pruefe(lotsen_optionen.has("Fahren noch Boote?") and not lotsen_optionen.has("Bring mich nach Riverlock."), "Bei Alarm fährt kein Boot")
	current_scene.get_node("Entwickler").setze_alarm(1)
	await process_frame
	pruefe(not feuer.visible and haendlerin.visible, "Zurück auf Stufe 1: Feuer aus, Markt offen")

	# --- Übungsplatz: Säbel, Muskete, Bajonett, Nachladen ---
	var puppe = current_scene.get_node("Drachenstein/ObererBurg/Uebungspuppe1")
	await vor_ziel(puppe, 2.0)
	await waffe("saebel")
	var treffer_vorher: int = S.zaehler_wert("uebungstreffer")
	await klick(MOUSE_BUTTON_LEFT)
	await warte(1.2)   # Ausholen und kurze Pause nach dem Hieb
	pruefe(S.zaehler_wert("uebungstreffer") == treffer_vorher + 1, "Säbelhieb trifft die Übungspuppe")
	await vor_ziel(puppe, 2.0, -0.6)   # die Kamera sitzt 0,6 m rechts der Figur
	await waffe("muskete")
	pruefe(kampf().geladen and current_scene.get_node("HUD/Fadenkreuz").visible, "Muskete gezogen: geladen, Fadenkreuz sichtbar")
	await klick(MOUSE_BUTTON_LEFT)
	await warte(1.2)
	pruefe(S.zaehler_wert("uebungstreffer") == treffer_vorher + 2 and not kampf().geladen, "Schuss trifft, die Muskete ist leer")
	await klick(MOUSE_BUTTON_LEFT)
	await warte(0.6)
	pruefe(S.zaehler_wert("uebungstreffer") == treffer_vorher + 3, "Ungeladen: Stoß mit dem Bajonett")
	await druecke(KEY_R)
	pruefe(kampf().nachladen_rest > 7.0 and not kampf().geladen, "Nachladen mit R dauert")
	await warte(8.3)
	pruefe(kampf().geladen, "Nach acht Sekunden ist die Muskete wieder geladen")

	# --- Waffe gegen einen Bruder: Verweise, nach dem dritten ein Verfahren ---
	var kammerhueter = current_scene.get_node("BurgHof/Personen/Kammerhueter")
	await waffe("saebel")
	for k in 3:
		await vor_ziel(kammerhueter, 1.5)
		await klick(MOUSE_BUTTON_LEFT)
		await warte(1.0)
	pruefe(S.zaehler_wert("verweise") == 3 and int(S.verfahren.get("stufe", 0)) == 2 and "Kammerhüter" in S.ziel,
			"Drei Verweise für die erhobene Waffe: Anzeige, Verfahren Stufe 2")
	await druecke(KEY_F)
	await setze(kammerhueter.global_position + Vector3(0, 0.3, 1.4))
	await rede([KEY_1, KEY_1])
	await process_frame
	pruefe(S.rang == 3 and S.verfahren.is_empty() and S.akte.any(func(e): return e["art"] == "urteil"), "Verfahren beim Kammerhüter: Degradierung zum Gesellen")
	pruefe(S.akte.any(func(e): return "mitverhandelt" in str(e["text"]) and "Bürge" in str(e["text"])), "Der Bürge wird mitverhandelt")

	# --- Waffe gegen Dorfbewohner: erst Anzeige, beim zweiten Mal Ausstoßung ---
	var stadt_vorher: int = S.ansehen_wert("stadt")
	await waffe("saebel")
	await vor_ziel(haendlerin, 1.5)
	await klick(MOUSE_BUTTON_LEFT)
	await warte(1.0)
	pruefe(int(S.verfahren.get("stufe", 0)) == 2 and S.ansehen_wert("stadt") < stadt_vorher, "Waffe gegen die Händlerin gezogen: Anzeige, Ansehen in der Stadt sinkt")
	await vor_ziel(haendlerin, 1.5)
	await klick(MOUSE_BUTTON_LEFT)
	await warte(1.0)
	pruefe(int(S.verfahren.get("stufe", 0)) == 4, "Beim zweiten Mal: Anzeige auf Ausstoßung")
	await druecke(KEY_F)
	blenden.clear()
	await setze(kammerhueter.global_position + Vector3(0, 0.3, 1.4))
	await rede([KEY_1, KEY_1])
	await process_frame
	pruefe(S.hat_flag("ausgestossen") and blenden.any(func(b): return b[1] == "spielende"), "Urteil: Ausstoßung, das Spiel endet")

	print("\nFehler: ", fehler)
	quit(fehler)
