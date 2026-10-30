extends SceneTree
## Prüft die Region Ashenveil mit echtem Gehen und echten Tasten: Ritt mit der Reiterin hin und zurück,
## Damm durch das Nebelmoor, Morast, Fallgitter, hinunter in die Kapelle der Stille, durch den
## Fluchttunnel hinaus ins Moor, Personen, verriegelter Nebeneingang, Speichern und Laden.
## Starten: godot --headless --path . --script res://tests/test_ashenveil.gd

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
	SP.ordner = "user://speicher_test_ashenveil/"
	S.ort_betreten.connect(func(n, _u): orte.append(n))
	S.meldung.connect(func(t): meldungen.append(t))
	D.zeile_gezeigt.connect(func(_s, _t, o): optionen = o)
	SP.neues_spiel("Ansel")
	await scene_changed
	for i in 5: await process_frame

	# --- Die Reiterin nimmt keinen Anwärter mit ---
	var reiterin = current_scene.get_node("Personen/PersonenAmBoden/Reiterin")
	await setze(reiterin.global_position + Vector3(1.2, 0.3, -0.9))
	await rede([KEY_2])
	pruefe(region_id() == "drachenstein", "Reiterin nimmt einen Anwärter nicht mit")

	# --- Als Wächter nach Ashenveil ---
	current_scene.get_node("Entwickler").ueberspringe_akt1()
	var minuten_vorher: float = Z.absolute_minuten()
	var szene_vorher := current_scene.get_instance_id()
	await setze(reiterin.global_position + Vector3(1.2, 0.3, -0.9))
	await rede([KEY_2])
	var gereist := await warte_auf_szene(szene_vorher)
	pruefe(gereist and region_id() == "ashenveil", "Mit der Reiterin nach Ashenveil geritten")
	var ankunft: Vector3 = current_scene.get_node("Ankuenfte/von_drachenstein").global_position
	pruefe(spieler().global_position.distance_to(ankunft) < 1.5, "Am Anfang des Damms angekommen")
	pruefe(Z.absolute_minuten() - minuten_vorher >= 35 * 60, "Der Ritt dauert anderthalb Tage")
	pruefe(await warte_auf_blende(), "Blende nach der Ankunft ist vorbei")
	pruefe(orte.has("Nebelmoor"), "Ortsname beim Betreten: Nebelmoor")

	# --- Der Morast: ein tiefer Tümpel neben dem Damm ---
	var g = current_scene.get_node("Gelaende")
	var tuempel := Vector3.ZERO
	for r in range(8, 60, 2):
		for k in 24:
			var x := ankunft.x + r * cos(k * TAU / 24.0)
			var z := ankunft.z + r * sin(k * TAU / 24.0)
			if tuempel == Vector3.ZERO and g.hoehe_bei(x, z) < -2.6 and z < 188.0:
				tuempel = Vector3(x, -0.5, z)
	meldungen.clear()
	await setze(tuempel)
	for i in 90: await physics_frame
	pruefe(tuempel != Vector3.ZERO and spieler().global_position.y > -1.5 and meldungen.has("Der Morast verschluckt jeden, der den Weg verlässt."),
			"Im Morast versunken und zurückgesetzt")

	# --- Über den Damm, durch das Fallgitter in die Burg ---
	await setze(ankunft + Vector3(0, 0.3, 0))
	var damm := await gehe_ueber([Vector2(-11, 178), Vector2(-14, 172), Vector2(-22, 148), Vector2(6, 128), Vector2(14, 100),
			Vector2(-5, 82), Vector2(-5, 64), Vector2(-5, 50), Vector2(-5, 36), Vector2(-5, 25)], 25.0)
	pruefe(damm and absf(spieler().global_position.y - 0.5) < 0.4, "Über den Damm und durch das Fallgitter in die Burg")
	pruefe(orte.has("Ashenveil"), "Ortsname beim Betreten: Ashenveil")

	# --- Hinunter in die Kapelle der Stille ---
	var hinab := await gehe_ueber([Vector2(-38, 25), Vector2(-38, -3.5), Vector2(-31, -3.5), Vector2(-13, -3.2), Vector2(-8, -3)])
	pruefe(hinab and spieler().global_position.y < -6.0, "Rampe hinunter in die Kapelle der Stille (y=%.1f)" % spieler().global_position.y)
	pruefe(orte.has("Kapelle der Stille"), "Ortsname: Kapelle der Stille")
	await gehe_ueber([Vector2(2.2, -3)])
	await rede([])
	pruefe(S.akte.any(func(e): return "1065" in str(e)), "Gedenkstein gelesen (Akte)")

	# --- Durch den Fluchttunnel hinaus ins Moor ---
	meldungen.clear()
	var tunnel := await gehe_ueber([Vector2(-1, -3), Vector2(-5.5, -3), Vector2(-5.5, -10), Vector2(-5.25, -13), Vector2(-5.25, -79), Vector2(-5.25, -99.5), Vector2(-5.25, -103)], 30.0)
	var p: Vector3 = spieler().global_position
	pruefe(tunnel and p.y > 0.0 and not meldungen.has("Der Morast verschluckt jeden, der den Weg verlässt."),
			"Durch den Fluchttunnel unter Mauer und Graben hinaus ins Moor (z=%.0f, y=%.1f)" % [p.z, p.y])
	pruefe(orte.has("Fluchttunnel"), "Ortsname: Fluchttunnel")

	# --- Personen und der verriegelte Nebeneingang ---
	Z.minuten = 12 * 60.0  # nicht in der Stille-Stunde, da schweigen alle
	Z.vorspulen(0.0)
	for eintrag in [["Komtur", Vector3(0, 0, -1.6), KEY_2], ["TorwacheSued", Vector3(0, 0, 1.5), KEY_1],
			["WacheOst1", Vector3(-1.5, 0, 0), KEY_1], ["WacheOst2", Vector3(-1.5, 0, 0), KEY_1]]:
		var person = current_scene.get_node("Personen/" + eintrag[0])
		await setze(person.global_position + eintrag[1] + Vector3(0, 0.3, 0))
		pruefe(await rede([eintrag[2]]), "Mit E angesprochen: " + person.anzeige_name)
	pruefe(S.akte.any(func(e): return "sieben Jahre" in str(e)), "Lehren aus Ashenveil vom Komtur in der Akte")
	var pforte = current_scene.get_node("Burg/Nebeneingang")
	pruefe(pforte.visible and pforte.is_in_group("interagierbar"), "Nebeneingang bleibt verriegelt")
	pruefe(not current_scene.get_node("Burg/Fallgitter").visible, "Fallgitter ist für Wächter oben")

	# --- Speichern und Laden in Ashenveil ---
	await setze(Vector3(0, 0.8, -10))
	pruefe(SP.speichern("1"), "In Ashenveil gespeichert")
	szene_vorher = current_scene.get_instance_id()
	SP.laden("1")
	await warte_auf_szene(szene_vorher)
	pruefe(region_id() == "ashenveil" and spieler().global_position.distance_to(Vector3(0, 0.5, -10)) < 1.0, "Geladen: wieder im Innenhof von Ashenveil")

	# --- Mit der Reiterin zurück nach Drachenstein ---
	reiterin = current_scene.get_node("Personen/Reiterin")
	await setze(reiterin.global_position + Vector3(0, 0.3, -1.4))
	szene_vorher = current_scene.get_instance_id()
	await rede([KEY_2])
	gereist = await warte_auf_szene(szene_vorher)
	ankunft = current_scene.get_node("Ankuenfte/von_ashenveil").global_position
	pruefe(gereist and region_id() == "drachenstein" and spieler().global_position.distance_to(ankunft) < 1.5,
			"Mit der Reiterin zurück vor das Torhaus West von Drachenstein (%s, %s, Ankunft %s)" % [gereist, region_id(), spieler().global_position.distance_to(ankunft)])

	print("\nFehler: ", fehler)
	quit(fehler)
