extends SceneTree
## Prüft die Landwege mit echtem Gehen: einmal um das Wächtermeer herum, von Drachenstein über die
## Nordstraße nach Riverlock, über die Südstraße nach Ashenveil und über den Küstenweg zurück.
## Dazu: Anwärter bleiben in der Burgfeste, Tage vergehen nur auf dem ganzen Weg, Personen an der
## Straße, Karte, Wald, Speichern und Laden unterwegs.
## Starten: godot --headless --path . --script res://tests/test_landwege.gd

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

## Läuft vom Ankunftsort (oder einem anderen Marker) in einen Übergang und wartet auf die neue Region.
func durch_uebergang(start: Vector3, uebergang_pfad: String) -> bool:
	var zone: Node3D = current_scene.get_node("Uebergaenge/" + uebergang_pfad)
	await setze(start + Vector3(0, 0.3, 0))
	var alte_id := current_scene.get_instance_id()
	Input.action_press("vor")
	var gewechselt := false
	for i in 900:
		if current_scene == null or current_scene.get_instance_id() != alte_id:
			gewechselt = true
			break
		var p: Vector3 = spieler().global_position
		var weg := Vector2(zone.global_position.x - p.x, zone.global_position.z - p.z)
		spieler().get_node("KameraDrehpunkt").rotation.y = atan2(-weg.x, -weg.y)
		await physics_frame
	Input.action_release("vor")
	if gewechselt:
		await warte_auf_szene(alte_id)
	return gewechselt

func marke(name: String) -> Vector3:
	return current_scene.get_node("Ankuenfte/" + name).global_position

func am_ort(name: String) -> bool:
	return spieler().global_position.distance_to(marke(name)) < 1.5

func _initialize() -> void:
	await process_frame
	D = root.get_node("Dialog"); S = root.get_node("Spielstand"); SP = root.get_node("Speicher"); Z = root.get_node("Spielzeit")
	SP.ordner = "user://speicher_test_landwege/"
	S.ort_betreten.connect(func(n, _u): orte.append(n))
	S.meldung.connect(func(t): meldungen.append(t))
	D.zeile_gezeigt.connect(func(_s, _t, o): optionen = o)
	SP.neues_spiel("Ansel")
	await scene_changed
	for i in 5: await process_frame

	# --- Anwärter bleiben in der Burgfeste ---
	meldungen.clear()
	var weg_frei := await durch_uebergang(marke("von_nordstrasse"), "ZurNordstrasse")
	pruefe(not weg_frei and region_id() == "drachenstein" and meldungen.has("Ein Anwärter verlässt die Burgfeste nicht ohne Auftrag."),
			"Anwärter wird am Pass zurückgeschickt")
	current_scene.get_node("Entwickler").ueberspringe_akt1()

	# --- Vor dem Torhaus Nord auf die Nordstraße, am Fuß des Burgbergs entlang ---
	await setze(Vector3(-45, current_scene.get_node("Gelaende").hoehe_bei(-45, 225) + 0.3, 225))
	pruefe(await gehe_ueber([Vector2(-110, 200), Vector2(-150, 120), Vector2(-160, 0), Vector2(-155, -150), Vector2(-130, -300),
			Vector2(-60, -380), Vector2(40, -410)], 40.0), "Vom Torhaus Nord am Burgberg entlang auf die Nordstraße")

	# --- Drachenstein → Nordstraße ---
	var start: float = Z.absolute_minuten()
	pruefe(await durch_uebergang(marke("von_nordstrasse"), "ZurNordstrasse") and region_id() == "nordstrasse" and am_ort("von_drachenstein"),
			"Vom Pass auf die Nordstraße")
	pruefe(Z.absolute_minuten() - start < 60, "Beim Betreten der Straße vergeht noch keine Zeit")
	var region = current_scene
	var karte_anfang: Vector2 = region.karten_pixel(marke("von_drachenstein"))
	var karte_ende: Vector2 = region.karten_pixel(marke("von_riverlock"))
	pruefe(karte_anfang.distance_to(Vector2(272, 491)) < 10 and karte_ende.distance_to(Vector2(1016, 494)) < 10, "Karte: Pfeil wandert die Nordstraße entlang")
	var bewuchs = current_scene.get_node("Bewuchs")
	for i in 120:
		if not bewuchs.anzahl.is_empty():
			break
		await physics_frame
	pruefe(bewuchs.anzahl.get("nadel", 0) + bewuchs.anzahl.get("laub", 0) > 500, "Wald an der Nordstraße (%s)" % bewuchs.anzahl)
	await gehe_ueber([Vector2(marke("von_drachenstein").x + 40, marke("von_drachenstein").z)])
	pruefe(orte.has("Nordstraße"), "Ortsname: Nordstraße")
	for eintrag in [["Dorfvorsteherin", KEY_3], ["Bezirkswache", KEY_3]]:
		var person = current_scene.get_node("Personen/" + eintrag[0])
		await setze(person.global_position + Vector3(1.4, 0.4, 0))
		pruefe(await rede([eintrag[1]]), "Mit E angesprochen: " + person.anzeige_name)
	pruefe(S.akte.any(func(e): return "Silas Holt" in str(e)), "Dorfvorsteherin erzählt von den Rufern (Akte)")

	# --- Nordstraße → Riverlock: neun Tage ---
	start = Z.absolute_minuten()
	pruefe(await durch_uebergang(marke("von_riverlock"), "NachRiverlock") and region_id() == "riverlock" and am_ort("von_nordstrasse"),
			"Am Ende der Nordstraße in Riverlock angekommen")
	pruefe(Z.absolute_minuten() - start >= 215 * 60, "Die Nordstraße dauert neun Tage")
	await warte_auf_blende()

	# --- Riverlock → Südstraße → Ashenveil: sieben Tage ---
	pruefe(await durch_uebergang(marke("von_suedstrasse"), "ZurSuedstrasse") and region_id() == "suedstrasse" and am_ort("von_riverlock"),
			"Von Riverlock auf die Südstraße")
	Z.minuten = 12 * 60.0
	Z.vorspulen(0.0)
	var wart = current_scene.get_node("Personen/Feuerwart")
	await setze(wart.global_position + Vector3(0, 0.4, 1.4))
	pruefe(await rede([KEY_1]), "Mit E angesprochen: " + wart.anzeige_name)
	start = Z.absolute_minuten()
	pruefe(await durch_uebergang(marke("von_ashenveil"), "NachAshenveil") and region_id() == "ashenveil" and am_ort("von_suedstrasse"),
			"Am Ende der Südstraße in Ashenveil angekommen")
	pruefe(Z.absolute_minuten() - start >= 167 * 60, "Die Südstraße dauert sieben Tage")
	await warte_auf_blende()

	# --- Ashenveil → Küstenweg → Drachenstein: drei Tage ---
	pruefe(await durch_uebergang(marke("von_kuestenweg"), "ZumKuestenweg") and region_id() == "kuestenweg" and am_ort("von_ashenveil"),
			"Vom Damm auf den Küstenweg")
	Z.minuten = 12 * 60.0
	Z.vorspulen(0.0)
	var torf = current_scene.get_node("Personen/Torfstecherin")
	await setze(torf.global_position + Vector3(0, 0.4, 1.4))
	pruefe(await rede([KEY_1]), "Mit E angesprochen: " + torf.anzeige_name)
	await setze(marke("von_ashenveil") + Vector3(0, 0.3, -30))
	pruefe(SP.speichern("1"), "Auf dem Küstenweg gespeichert")
	var szene_vorher := current_scene.get_instance_id()
	SP.laden("1")
	await warte_auf_szene(szene_vorher)
	pruefe(region_id() == "kuestenweg" and SP.letzte_ankunft == "von_ashenveil", "Geladen: wieder auf dem Küstenweg, Herkunft gemerkt")
	start = Z.absolute_minuten()
	pruefe(await durch_uebergang(marke("von_drachenstein"), "NachDrachenstein") and region_id() == "drachenstein" and am_ort("von_kuestenweg"),
			"Über den Küstenweg zurück nach Drachenstein")
	pruefe(Z.absolute_minuten() - start >= 71 * 60, "Der Küstenweg dauert drei Tage")
	await warte_auf_blende()

	# --- Umkehren kostet keine Tage ---
	pruefe(await durch_uebergang(marke("von_kuestenweg"), "ZumKuestenweg") and region_id() == "kuestenweg", "Wieder auf den Küstenweg")
	start = Z.absolute_minuten()
	pruefe(await durch_uebergang(marke("von_drachenstein"), "NachDrachenstein") and region_id() == "drachenstein", "Gleich wieder umgekehrt")
	pruefe(Z.absolute_minuten() - start < 60, "Wer umkehrt, verliert keine Tage")
	await setze(marke("von_kuestenweg") + Vector3(0, 0.3, 0))
	pruefe(await gehe_ueber([Vector2(150, 615), Vector2(140, 540), Vector2(132, 470), Vector2(122, 390), Vector2(116, 300),
			Vector2(109.8, 288.8), Vector2(104, 280), Vector2(106, 252.5)], 30.0), "Über den Pass und durch das Torhaus West in die Stadt")

	print("\nFehler: ", fehler)
	quit(fehler)
