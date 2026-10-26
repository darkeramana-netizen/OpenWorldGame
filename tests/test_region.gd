extends SceneTree
## Prüft die Region Drachenstein: Gelände, Orte, Meer, Rand, Personen, Karte,
## Laufen über Hof und Brücke, Speichern und Laden, Umzug alter Spielstände.
## Starten: godot --headless --path . --script res://tests/test_region.gd

var fehler := 0
var orte: Array = []
var meldungen: Array = []
var D; var S; var SP

func pruefe(bed: bool, was: String) -> void:
	if bed: print("OK     ", was)
	else:
		fehler += 1
		print("FEHLER ", was)

func spieler() -> Node:
	return current_scene.get_node("Spieler")

func setze(pos: Vector3, blick_grad: float = 0.0) -> void:
	spieler().global_position = pos
	spieler().velocity = Vector3.ZERO
	spieler().get_node("KameraDrehpunkt").rotation.y = deg_to_rad(blick_grad)
	for i in 6: await physics_frame

## Läuft nacheinander zu den Wegpunkten (nur x und z zählen). Gibt zurück, ob alle erreicht wurden.
func gehe_ueber(punkte: Array, zeit_pro_punkt: float = 20.0) -> bool:
	Input.action_press("vor")
	var alle := true
	for ziel: Vector2 in punkte:
		var ende := Time.get_ticks_msec() + int(zeit_pro_punkt * 1000)
		var erreicht := false
		while Time.get_ticks_msec() < ende:
			var p: Vector3 = spieler().global_position
			var weg := Vector2(ziel.x - p.x, ziel.y - p.z)
			if weg.length() < 0.8:
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

func laufe(sekunden: float) -> void:
	Input.action_press("vor")
	var ende := Time.get_ticks_msec() + int(sekunden * 1000)
	while Time.get_ticks_msec() < ende:
		await physics_frame
	Input.action_release("vor")
	for i in 5: await physics_frame

func wechsle(aktion: Callable) -> void:
	aktion.call()
	await scene_changed
	for i in 5: await process_frame

func _initialize() -> void:
	await process_frame
	D = root.get_node("Dialog"); S = root.get_node("Spielstand"); SP = root.get_node("Speicher")
	SP.ordner = "user://speicher_test_region/"
	for p in ["auto", "schnell", "1", "2", "3"]: DirAccess.remove_absolute(SP._pfad(p))
	S.ort_betreten.connect(func(n, _u): orte.append(n))
	S.meldung.connect(func(t): meldungen.append(t))

	await wechsle(func(): SP.neues_spiel("Wanderer"))
	var g = current_scene.get_node("Gelaende")
	pruefe(g.breite > 500 and g.tiefe > 400, "Gelände geladen (%d x %d Punkte)" % [g.breite, g.tiefe])
	pruefe(absf(spieler().global_position.y - g.hoehe_bei(0, 46)) < 0.5, "Spieler steht am Start auf dem Boden")

	# Laufen: vom Vorplatz durch das Tor in den Hof
	var vorher: Vector3 = spieler().global_position
	await laufe(3.0)
	pruefe(vorher.z - spieler().global_position.z > 8.0 and absf(spieler().global_position.y) < 0.6, "Mit W durch das Tor in den Hof gelaufen")

	# Rampen im Hof: zum Wehrgang und weiter auf den Wachturm, mit echtem Gehen
	await setze(Vector3(-6, 0.3, 28.5), 90.0)
	await laufe(6.5)
	pruefe(spieler().global_position.y > 7.8, "Rampe zum Wehrgang hinaufgelaufen (y=%.1f)" % spieler().global_position.y)
	spieler().get_node("KameraDrehpunkt").rotation.y = PI
	await laufe(1.0)
	pruefe(spieler().global_position.z > 30.0 and spieler().global_position.y > 7.8, "Von der Rampe auf den Wehrgang getreten")
	await setze(Vector3(-31, 8.3, 0), 0.0)
	await laufe(6.0)
	pruefe(spieler().global_position.y > 11.5, "Rampe auf den Wachturm hinaufgelaufen (y=%.1f)" % spieler().global_position.y)

	# Orte
	# Wege der Burgfeste nach dem Grundriss
	await setze(Vector3(0, 0.3, 46))
	var hinauf := await gehe_ueber([Vector2(0, 56), Vector2(-25, 52), Vector2(-50, 18), Vector2(-50, 2)])
	pruefe(hinauf and spieler().global_position.y > 7.5, "Weg hinauf durch das Tor in die Oberer Burg (y=%.1f)" % spieler().global_position.y)
	await setze(Vector3(0, 0.3, 46))
	var hinab := await gehe_ueber([Vector2(0, 56), Vector2(44, 46), Vector2(58, 22), Vector2(75, 4), Vector2(97, 0),
			Vector2(98, 19.5), Vector2(125, 20.5)])
	pruefe(hinab and absf(spieler().global_position.y + 17.8) < 0.5, "Durch die Stadt über den Markt hinunter zum Kai gelaufen")
	await setze(Vector3(0, 0.3, 56))
	pruefe(await gehe_ueber([Vector2(-14, 83.5), Vector2(-30, 95)]), "Durch das Vorburgtor hinaus gelaufen")
	# Gravemarch nach dem Grundriss: von der Brückenpforte bis in den Burghof, durch Zwinger und geknicktes Tor
	var esme: Node3D = current_scene.get_node("Personen/TorwacheGravemarch")
	await setze(esme.global_position + Vector3(-2, 0.3, 0))
	var gm_mitte := Vector2(-600, -205)
	var labyrinth := []
	for punkt in [Vector2(58, -44), Vector2(45, -28), Vector2(35, -8), Vector2(32.5, 18), Vector2(20, 16), Vector2(0, 10),
			Vector2(-11, 8), Vector2(-11, 14.2), Vector2(-17.5, 14.2), Vector2(-17.5, 19), Vector2(-10, 24)]:
		labyrinth.append(gm_mitte + punkt)
	var im_hof := await gehe_ueber([Vector2(esme.global_position.x - 4, esme.global_position.z + 4)] + labyrinth)
	pruefe(im_hof and absf(spieler().global_position.y + 4.0) < 0.6, "Gravemarch: über die Brücke durch das Labyrinth bis in den Burghof")
	await setze(Vector3(-560, g.hoehe_bei(-560, -200) + 0.5, -200))
	pruefe(orte.has("Gravemarch"), "Ortsname beim Betreten: Gravemarch")
	await setze(Vector3(-650, 70.5, -364))
	pruefe(orte.has("Gravecrest"), "Ortsname beim Betreten: Gravecrest")

	# Hafen: über den Kai der Südmole bis an die erste Brücke, dann über die Inseln
	await setze(Vector3(125, -17.5, 21), 0.0)
	pruefe(orte.has("Drachenkai"), "Ortsname beim Betreten: Drachenkai")
	await setze(Vector3(155, -17.5, 21.5), rad_to_deg(atan2(-27.0, -36.0)))
	await laufe(6.0)
	pruefe(spieler().global_position.z > 32.0 and spieler().global_position.y > -18.2, "Von der Südmole auf die erste Brücke gelaufen")
	await setze(Vector3(185, -17.5, 60), rad_to_deg(atan2(-27.0, -35.0)))
	await laufe(6.0)
	var p: Vector3 = spieler().global_position
	pruefe(p.z > 78.0 and p.y > -18.5, "Über die Brücke zur zweiten Insel gelaufen (z=%.0f, y=%.1f)" % [p.z, p.y])
	pruefe(orte.has("Schwarzer Bergfried"), "Ortsname beim Betreten: Schwarzer Bergfried")

	# Meer: Wer hineinfällt, landet wieder an Land
	meldungen.clear()
	await setze(Vector3(300, -15, 20))
	for i in 120: await physics_frame
	pruefe(spieler().global_position.y > -19.0 and meldungen.has("Das Wächtermeer ist zu kalt zum Schwimmen."), "Aus dem Meer zurückgesetzt")
	meldungen.clear()
	await setze(Vector3(-895, 200, 0))
	pruefe(spieler().global_position.x > -880.0 and meldungen.size() > 0, "Am Rand der Region zurückgesetzt")

	# Personen der Region mit echter Taste E
	for eintrag in [["Bergwaechter", Vector3(-1.5, 0, 0)], ["Lotsin", Vector3(0, 0, 1.5)],
			["TorwacheGravecrest", Vector3(1.5, 0, 0)], ["PersonenAmBoden/Haendlerin", Vector3(0, 0, 1.6)],
			["TorwacheGravemarch", Vector3(1.0, 0, 1.0)], ["ArchivarinGravemarch", Vector3(0, 0, -1.4)]]:
		var person = current_scene.get_node("Personen/" + eintrag[0])
		var ziel: Vector3 = person.global_position + eintrag[1]
		ziel.y = maxf(ziel.y, g.hoehe_bei(ziel.x, ziel.z)) + 0.3
		await setze(ziel)
		await druecke(KEY_E)
		var offen: bool = D.aktiv
		# Alle Fragen durchgehen: immer die erste, bis nur noch der Abschied übrig ist.
		var n := 0
		while D.aktiv and n < 30:
			await druecke(KEY_1 if n < 6 else KEY_4)
			n += 1
		if D.aktiv: D.beende()
		pruefe(offen and person.visible, "Mit E angesprochen: " + person.anzeige_name)

	# Karte
	await setze(Vector3(0, 0.3, 46))
	var hud = current_scene.get_node("HUD")
	await druecke(KEY_M)
	pruefe(hud.get_node("%Karte").visible, "Karte mit M geöffnet")
	await process_frame
	var bild: TextureRect = hud.get_node("%KarteBild")
	var marke: Label = hud.get_node("%KarteMarke")
	var massstab := minf(bild.size.x / bild.texture.get_width(), bild.size.y / bild.texture.get_height())
	var versatz := (bild.size - bild.texture.get_size() * massstab) / 2.0
	var erwartet := bild.position + versatz + (Vector2(272, 491) + Vector2(0, 46) / 5.0) * massstab
	pruefe((marke.position + marke.size / 2.0).distance_to(erwartet) < 2.0, "Markierung auf der Karte bei Drachenstein")
	await druecke(KEY_M)
	pruefe(not hud.get_node("%Karte").visible, "Karte mit M geschlossen")

	# Speichern und Laden in der Region
	var gm := Vector3(-560, g.hoehe_bei(-560, -205) + 0.2, -205)
	await setze(gm)
	pruefe(SP.speichern("1"), "In Gravemarch gespeichert")
	await setze(Vector3(0, 0.3, 46))
	await wechsle(func(): SP.laden("1"))
	pruefe(spieler().global_position.distance_to(gm) < 1.0, "Geladen: wieder vor Gravemarch")

	# Umzug eines Spielstands aus Akt I (Version 1, Hof als eigene Szene)
	var alt := {
		"version": 1,
		"spielstand": {"spieler_name": "Alt", "rang": 1, "flags": {"geloebnis": true, "aufgabe_steine": true},
			"zaehler": {"bruchsteine": 1}, "akte": [], "aufgehoben": ["/root/Hof/Bauhof/Bruchstein1"]},
		"spielzeit": {"jahr": 1750, "tag": 1, "minuten": 600},
		"spieler": {"position": [-10, 0, 10], "koerper": 0, "kamera": [0, 0]},
	}
	var datei := FileAccess.open(SP._pfad("2"), FileAccess.WRITE)
	datei.store_string(JSON.stringify(alt))
	datei.close()
	await wechsle(func(): SP.laden("2"))
	var steine := get_nodes_in_group("interagierbar").filter(func(n): return n.get("zaehler_name") == "bruchsteine")
	pruefe(steine.size() == 2 and not current_scene.has_node("BurgHof/Bauhof/Bruchstein1"), "Alter Spielstand: aufgehobener Stein bleibt weg")
	pruefe(spieler().global_position.distance_to(Vector3(-10, 0, 10)) < 1.0 and S.spieler_name == "Alt", "Alter Spielstand: Position im Hof stimmt")

	print("\nFehler: ", fehler)
	quit(fehler)
