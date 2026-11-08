extends SceneTree
## Prüft die Region Drachenstein: Gelände, Orte, Meer, Rand, Personen, Karte,
## Laufen über Hof und Brücke, Speichern und Laden, Umzug alter Spielstände.
## Starten: godot --headless --path . --script res://tests/test_region.gd

var fehler := 0
var orte: Array = []
var meldungen: Array = []
var D; var S; var SP


## Punkt im Hof aus Akt I (lokal wie in burg_hof.tscn, y über dem Hofboden) → Welt. Der Hof ist das Ordensvorwerk.
func hp(x: float, y: float, z: float) -> Vector3:
	return current_scene.get_node("BurgHof").to_global(Vector3(x, y, z))

## Spielerposition im Hof aus Akt I (lokal)
func im_hof() -> Vector3:
	return current_scene.get_node("BurgHof").to_local(spieler().global_position)

## Blickrichtung im Hof (lokal, Grad) → Welt
func hof_blick(grad: float) -> float:
	return grad + current_scene.get_node("BurgHof").rotation_degrees.y

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
func gehe_ueber(punkte: Array, zeit_pro_punkt: float = 20.0, genau: float = 0.8) -> bool:
	Input.action_press("vor")
	var alle := true
	for ziel: Vector2 in punkte:
		var ende := Time.get_ticks_msec() + int(zeit_pro_punkt * 1000)
		var erreicht := false
		while Time.get_ticks_msec() < ende:
			var p: Vector3 = spieler().global_position
			var weg := Vector2(ziel.x - p.x, ziel.y - p.z)
			if weg.length() < genau:
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
	var start: Vector3 = spieler().global_position
	pruefe(start.distance_to(hp(0, 0, 46)) < 0.5 and absf(start.y - g.hoehe_bei(start.x, start.z)) < 0.5, "Spieler steht am Start vor dem Tor des Ordensvorwerks auf dem Boden")

	# Laufen: vom Vorplatz durch das Tor in den Hof
	spieler().get_node("KameraDrehpunkt").rotation.y = deg_to_rad(hof_blick(0.0))
	var vorher: Vector3 = im_hof()
	await laufe(3.0)
	pruefe(vorher.z - im_hof().z > 8.0 and absf(im_hof().y) < 0.6, "Mit W durch das Tor in den Hof gelaufen")

	# Rampen im Hof: zum Wehrgang und weiter auf den Wachturm, mit echtem Gehen
	await setze(hp(-6, 0.3, 28.5), hof_blick(90.0))
	await laufe(6.5)
	pruefe(im_hof().y > 7.8, "Rampe zum Wehrgang hinaufgelaufen (y=%.1f)" % im_hof().y)
	spieler().get_node("KameraDrehpunkt").rotation.y = deg_to_rad(hof_blick(180.0))
	await laufe(1.0)
	pruefe(im_hof().z > 30.0 and im_hof().y > 7.6, "Von der Rampe auf den Wehrgang getreten (%s)" % im_hof().snapped(Vector3.ONE * 0.1))
	await setze(hp(-31, 8.3, 0), hof_blick(0.0))
	await laufe(6.0)
	pruefe(im_hof().y > 11.5, "Rampe auf den Wachturm hinaufgelaufen (y=%.1f)" % im_hof().y)

	# Orte
	# Die Stadtleute gehen dieselben Wege; damit keiner dem Testläufer im Weg steht, sind sie hier durchlässig
	# (ihre Wege prüft test_leben.gd).
	for p in current_scene.get_node("Personen/Stadtleben").get_children():
		if p is CollisionObject3D:
			p.collision_layer = 0
	# Wege der Burgfeste nach dem Grundriss (docs/bilder/grundriss-drachenstein-3.webp, die Wege hat der Spieler
	# eingezeichnet): vom Marktplatz durch die Stadt im Bogen um die Vorburg hinauf zum Vorburgtor, durch den Hof und das
	# Osttor hinab in den Burgbezirk, an der Mauer zur Rampe, durch das Rampentor in die Mittelburg, gleich rechts durch
	# das Zwingertor, im Zwinger an der Oberburg hinauf, durch ihr Südtor und ihr Tor zum Durchgang in den Palas
	await setze(Vector3(145.82, g.hoehe_bei(145.82, 142.94) + 0.3, 142.94))
	var hinauf := await gehe_ueber([Vector2(143.81, 147.13), Vector2(141.34, 166.16), Vector2(135.55, 185.79), Vector2(128.88, 202.81), Vector2(122.51, 215.44), Vector2(110.87, 225.13), Vector2(94.36, 232.88), Vector2(82.31, 237.56), Vector2(67.97, 239.07), Vector2(47.75, 238.38), Vector2(28.09, 232.25), Vector2(14.66, 224.28), Vector2(6.83, 214.84), Vector2(10.28, 207.82), Vector2(21.97, 210.91), Vector2(38.99, 213.54), Vector2(52.46, 213.78), Vector2(60.65, 207.06), Vector2(69.1, 191.24), Vector2(70.54, 176), Vector2(67, 161.5), Vector2(65.34, 149.53), Vector2(65.66, 141.1), Vector2(60.57, 140.51), Vector2(55.81, 139.89), Vector2(52.45, 139.83), Vector2(41.35, 139.73), Vector2(31.67, 136.49), Vector2(30.65, 132.21), Vector2(31.29, 127.78), Vector2(41.09, 124.29), Vector2(53.06, 118.6), Vector2(58.5, 111.1), Vector2(61.86, 94.69), Vector2(63.34, 75.74), Vector2(67.36, 59.27), Vector2(72.42, 43.06), Vector2(77.43, 26.18), Vector2(79.22, 15.27), Vector2(72.43, 14.49), Vector2(67.16, 24), Vector2(57.79, 40.9), Vector2(51.79, 49.8), Vector2(46.53, 55.26), Vector2(41.63, 57.01), Vector2(36.7, 58.43), Vector2(33.71, 54.64), Vector2(32.91, 48.99), Vector2(32.82, 43.95), Vector2(34.12, 31.07), Vector2(40.83, 10.36), Vector2(40.41, -11.12), Vector2(39.76, -23.18), Vector2(43.48, -35.25), Vector2(47.48, -48.01), Vector2(40.59, -54.17), Vector2(35.74, -51.75), Vector2(34.32, -48.62), Vector2(28.69, -47.48), Vector2(22.74, -46.32), Vector2(11.36, -41.69), Vector2(3.84, -43.09), Vector2(3.08, -48.4), Vector2(1.97, -53.69), Vector2(-0.03, -57.56), Vector2(-1.44, -62.49), Vector2(-2.52, -67.44), Vector2(-2.62, -76.85), Vector2(-5.2, -100.17)], 40.0)
	pruefe(hinauf and spieler().global_position.y > 15.5, "Durch Stadt, Vorburg, Mittelburg und Oberburg hinauf in den Palas (y=%.1f)" % spieler().global_position.y)
	pruefe(orte.has("Vorburg") and orte.has("Mittelburg") and orte.has("Oberburg · Wolfsfeste") and orte.has("Palas · Drachenhorst"),
			"Ortsnamen: Vorburg, Mittelburg, Oberburg, Palas")
	# Gelb: aus dem Palas zurück in den engen Zwinger, einmal außen um den Palas und durch die Pforte an das Ende des
	# Zwingers der Oberburg (eine Mauer trennt diesen Weg vom Durchgang zwischen den Toren)
	var gelb := await gehe_ueber([Vector2(-2.52, -67.44), Vector2(-1.44, -62.49), Vector2(-12.16, -61.95), Vector2(-28.29, -66), Vector2(-40.91, -76.4), Vector2(-50.38, -89.4), Vector2(-58.73, -105.19), Vector2(-67.91, -122.93), Vector2(-71.62, -143.47), Vector2(-70.77, -153.62), Vector2(-68.44, -162.22), Vector2(-61.72, -174.53), Vector2(-49.05, -183.98), Vector2(-33.34, -193.33), Vector2(-12.06, -192.05), Vector2(5.44, -187.77), Vector2(19.95, -182.9), Vector2(26.75, -165.65), Vector2(31.81, -144.88), Vector2(37.48, -120.81), Vector2(42.21, -100.02), Vector2(31.85, -78.67), Vector2(27.39, -67.54), Vector2(29.69, -64.04), Vector2(32, -60.52), Vector2(36.31, -57.18), Vector2(42.48, -55.67), Vector2(47.48, -48.01)], 40.0)
	pruefe(gelb and absf(spieler().global_position.y - 14.0) < 1.5, "Im engen Zwinger um den Palas an das Ende des Zwingers (y=%.1f)" % spieler().global_position.y)
	# Grün: durch den Zwinger hinab bis vor das Zwingertor der Mittelburg, im Zwinger an der Westseite der Oberburg nach
	# Norden, hinter Oberburg und Palas entlang und im Süden an der Ringmauer hinab an den Fuß der Rampe
	var gruen := await gehe_ueber([Vector2(43.48, -35.25), Vector2(39.76, -23.18), Vector2(40.41, -11.12), Vector2(40.83, 10.36), Vector2(34.12, 31.07), Vector2(32.82, 43.95), Vector2(32.91, 48.99), Vector2(33.71, 54.64), Vector2(32.82, 43.95), Vector2(25.2, 45.25), Vector2(15.24, 46.74), Vector2(2.05, 49.83), Vector2(-9.81, 48.79), Vector2(-16.75, 46), Vector2(-27.38, 39.48), Vector2(-39.61, 33.75), Vector2(-45, 25.45), Vector2(-48.05, 21), Vector2(-46.53, 6.75), Vector2(-44.42, -4.51), Vector2(-40.71, -16.58), Vector2(-33.45, -30.62), Vector2(-34.22, -44), Vector2(-38.16, -51.08), Vector2(-45.47, -58.21), Vector2(-54.89, -62.48), Vector2(-64.67, -75.12), Vector2(-74.38, -91.14), Vector2(-77.62, -106), Vector2(-82.73, -127.43), Vector2(-83.15, -148.91), Vector2(-80.53, -170.3), Vector2(-72.52, -195.5), Vector2(-63.87, -213.01), Vector2(-51.8, -225.77), Vector2(-36.62, -233.4), Vector2(-20.19, -229.71), Vector2(4.31, -221.97), Vector2(21.5, -217.32), Vector2(37.82, -206.89), Vector2(50.43, -192.47), Vector2(62.46, -176.98), Vector2(73.79, -161.77), Vector2(80.55, -140.81), Vector2(83.62, -111.48), Vector2(84.25, -79.26), Vector2(84.87, -47.04), Vector2(83.45, -27.43), Vector2(78.5, -5.85), Vector2(79.22, 15.27)], 40.0)
	pruefe(gruen and absf(spieler().global_position.y) < 1.5, "Außen um Oberburg und Palas hinab zum Fuß der Rampe (y=%.1f)" % spieler().global_position.y)
	# Vom Marktplatz auf den Westkai und über den Kai bis an den Kanal vor dem Wassertor
	await setze(Vector3(136, g.hoehe_bei(136, 86) + 0.3, 86))
	var fels := await gehe_ueber([Vector2(145.69, 79.75), Vector2(149.85, 68.99), Vector2(142, 63.5), Vector2(121, 61.5), Vector2(106, 52.5), Vector2(100, 27.5), Vector2(100, -0.5)], 30.0)
	pruefe(fels and absf(spieler().global_position.y + 17.4) < 0.6, "Über den Kai an den Kanal vor dem Wassertor (y=%.1f)" % spieler().global_position.y)
	pruefe(orte.has("Drachenhafen"), "Ortsname: Drachenhafen")
	# Vom Nordkai auf den Landungssteg bis an sein Ende (über dem Wasser, nicht hineingefallen)
	var steg := await gehe_ueber([Vector2(100, 17.5), Vector2(108, 17.5), Vector2(122, 17.5)], 20.0)
	pruefe(steg and absf(spieler().global_position.y + 17.4) < 0.5, "Auf dem Landungssteg bis an sein Ende (y=%.1f)" % spieler().global_position.y)
	await gehe_ueber([Vector2(108, 17.5), Vector2(100, 17.5), Vector2(100, -0.5)], 20.0)
	# Über die Krone der Kanalmauer durch das Wassertor in den Untergrundhafen, um das Becken herum und auf der anderen
	# Seite wieder hinaus auf den Ostkai zu den beiden Kränen
	var uh := await gehe_ueber([Vector2(97, -5.5), Vector2(89, -5.5), Vector2(85.5, -1), Vector2(34.5, -1), Vector2(34.5, -18),
			Vector2(85.5, -18), Vector2(89, -13.5), Vector2(97, -13.5)], 30.0)
	pruefe(uh and absf(spieler().global_position.y + 17.4) < 0.5 and orte.has("Untergrundhafen"),
			"Durch den Untergrundhafen auf die andere Seite des Kanals (y=%.1f)" % spieler().global_position.y)
	var kraene := await gehe_ueber([Vector2(101, -20), Vector2(103, -21.5), Vector2(110, -33), Vector2(116, -41), Vector2(126, -38.5), Vector2(132, -39)], 30.0)
	pruefe(kraene and absf(spieler().global_position.y + 17.4) < 0.5, "Über den Ostkai zu den Kränen (y=%.1f)" % spieler().global_position.y)
	await gehe_ueber([Vector2(126, -38.5), Vector2(116, -41), Vector2(110, -33), Vector2(101, -20), Vector2(97, -13.5), Vector2(89, -13.5), Vector2(85.5, -18),
			Vector2(34.5, -18), Vector2(34.5, -1), Vector2(85.5, -1), Vector2(89, -5.5), Vector2(97, -5.5), Vector2(100, -0.5)], 30.0)
	# Begehbare Gebäude (burgbau.gd, Art ab 10): von draußen durch die Tür hinein, bei mehreren Geschossen die erste
	# Treppe hinauf. Die Lage steht in den Werten des Baus.
	var gebaeude_ok := 0
	var gebaeude_alle := 0
	for bau in current_scene.find_children("*", "Node3D", true, false):
		if not is_instance_valid(bau) or not "gebaeude" in bau or not "hallen" in bau:
			continue
		var w: PackedFloat32Array = bau.gebaeude
		if w.size() < 12 or int(w[11]) < 10:
			continue
		gebaeude_alle += 1
		var art := int(w[11]) % 10
		var gr := deg_to_rad(w[2])
		var nx := Vector2(cos(gr), -sin(gr))
		var uz := Vector2(sin(gr), cos(gr))
		if (int(w[11]) / 10) % 10 == 2:
			nx = -nx
			uz = -uz
		var c := Vector2(w[0], w[1])
		var B := w[3] / 2.0
		var L := w[4] / 2.0
		var fb := w[5] + 0.03
		var aus := uz if art == 1 else nx
		var tief := L if art == 1 else B
		var draussen := c + aus * (tief + 2.5)
		await setze(Vector3(draussen.x, maxf(g.hoehe_bei(draussen.x, draussen.y), fb) + 0.4, draussen.y))
		var drin := c + aus * (tief - 1.8)
		var ok := await gehe_ueber([c + aus * (tief + 0.5), drin], 15.0) and absf(spieler().global_position.y - fb) < 0.4
		var geschosse := 1 if art == 1 else maxi(1, int(w[7] / (4.6 if art == 3 else 3.6)))
		if ok and geschosse > 1:
			var gh := w[7] / geschosse
			var iL := L - 0.6
			var iB := B - 0.6
			var lauf := gh * 1.75
			var fuss := -iL + 0.9                 # Fuß der Treppe, davor ein Absatz am Giebel
			var q := -iB + 0.575                  # Mitte der Treppe
			ok = await gehe_ueber([c, c + uz * (fuss - 0.45) + nx * (q + 1.6), c + uz * (fuss - 0.45) + nx * q], 15.0, 0.3) \
					and await gehe_ueber([c + uz * (fuss + lauf + 1.0) + nx * q], 15.0, 0.4) \
					and absf(spieler().global_position.y - (fb + gh)) < 0.4
		if ok:
			gebaeude_ok += 1
		else:
			print("       Gebäude nicht begehbar: %s (stehe bei %s)" % [bau.name, spieler().global_position.snapped(Vector3.ONE * 0.1)])
	pruefe(gebaeude_alle >= 8 and gebaeude_ok == gebaeude_alle,
			"Begehbare Gebäude: %d von %d durch die Tür betreten, Treppen hinauf" % [gebaeude_ok, gebaeude_alle])
	await setze(Vector3(100, g.hoehe_bei(100, -0.5) + 0.3, -0.5))   # zurück auf den Nordkai für den Weg zur Mole
	# Zurück zum Becken, über den Westkai zum Speicherkai, durch die Molenpforte über Mole und Brücken zu den Inseln
	var mole := await gehe_ueber([Vector2(100, -0.5), Vector2(100, 27.5), Vector2(106, 52.5),
			Vector2(121, 61.5), Vector2(166, 61.5), Vector2(186, 56.5), Vector2(191.5, 47.5), Vector2(191.5, 17.5), Vector2(191.5, -8.5), Vector2(201, -10),
			Vector2(212, -10), Vector2(292, -15.5), Vector2(300, -15), Vector2(382, 22), Vector2(450, 55)], 30.0)
	pruefe(mole and spieler().global_position.y > -18.5, "Durch die Molenpforte über Mole und Brücken zu den Inseln")
	pruefe(orte.has("Schwarzer Bergfried"), "Ortsname beim Betreten: Schwarzer Bergfried")
	# Landwege: durch das Nordtor herein und hinab in die Stadt; durch das Südtor in die Stadt
	await setze(Vector3(-50.34, g.hoehe_bei(-50.34, 189.94) + 0.3, 189.94))
	pruefe(await gehe_ueber([Vector2(-35.37, 188.04), Vector2(-26.41, 186.63), Vector2(-17, 186.53), Vector2(-8.3, 190.19), Vector2(-2.56, 198.79), Vector2(4.28, 208.32), Vector2(6.83, 214.84), Vector2(14.66, 224.28), Vector2(28.09, 232.25), Vector2(47.75, 238.38), Vector2(67.97, 239.07)], 30.0) and orte.has("Festungsstadt"), "Landweg: durch das Nordtor in die Stadt")
	await setze(Vector3(240.5, g.hoehe_bei(240.5, 118) + 0.3, 118))   # auf dem Küstenweg vor dem Südtor
	pruefe(await gehe_ueber([Vector2(242, 98), Vector2(236, 95), Vector2(230.88, 93.94), Vector2(222.35, 92.29), Vector2(214.01, 101.38), Vector2(198.29, 106.37), Vector2(178.2, 107.34), Vector2(168.69, 106.1)], 30.0), "Landweg: durch das Südtor in die Stadt")
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

	# Meer: Wer hineinfällt, landet wieder an Land
	meldungen.clear()
	await setze(Vector3(420, -15, -150))
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
	await setze(Vector3(0, 14.3, 46))
	var hud = current_scene.get_node("HUD")
	await druecke(KEY_M)
	pruefe(hud.get_node("%Karte").visible, "Karte mit M geöffnet")
	await process_frame
	var bild: TextureRect = hud.get_node("%KarteBild")
	var marke: Label = hud.get_node("%KarteMarke")
	var massstab := minf(bild.size.x / bild.texture.get_width(), bild.size.y / bild.texture.get_height())
	var versatz := (bild.size - bild.texture.get_size() * massstab) / 2.0
	var erwartet := bild.position + versatz + (Vector2(272, 491) + Vector2(spieler().global_position.x, spieler().global_position.z) / 5.0) * massstab
	pruefe((marke.position + marke.size / 2.0).distance_to(erwartet) < 2.0, "Markierung auf der Karte bei Drachenstein")
	await druecke(KEY_M)
	pruefe(not hud.get_node("%Karte").visible, "Karte mit M geschlossen")

	# Speichern und Laden in der Region
	var gm := Vector3(-560, g.hoehe_bei(-560, -205) + 0.2, -205)
	await setze(gm)
	pruefe(SP.speichern("1"), "In Gravemarch gespeichert")
	await setze(Vector3(0, 14.3, 46))
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
	pruefe(spieler().global_position.distance_to(hp(-10, 0, 10)) < 1.0 and S.spieler_name == "Alt", "Alter Spielstand: Position im Hof (jetzt im Ordensvorwerk) stimmt")

	print("\nFehler: ", fehler)
	quit(fehler)
