extends SceneTree
## Prüft Sold, Spähwesen und Bürgschaft mit echtem Gehen und echten Tasten: Sold zum Monatsanfang (im Krieg
## doppelt), Schleichen und Belauschen (bemerkt werden, unbemerkt alles hören), Berichte, Gold über dem Sold
## (melden oder von den Prüfern angezeigt werden), Bürgschaft für einen Bewerber (selbst melden oder haften).
## Starten: godot --headless --path . --script res://tests/test_spaehwesen.gd

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

## Spricht eine Person an und wählt nacheinander die Antworten, deren Text die Teile enthält.
func waehle(person: Node3D, teile: Array, abstand: Vector3 = Vector3(0, 0.3, 1.4)) -> bool:
	await setze(person.global_position + abstand)
	await druecke(KEY_E)
	var gefunden := true
	for teil: String in teile:
		var n := 0
		while D.aktiv and optionen.is_empty() and n < 6:
			await druecke(KEY_E)
			n += 1
		var index := -1
		for i in optionen.size():
			if teil in optionen[i]:
				index = i
		if index < 0:
			print("       Antwort nicht gefunden: ", teil, " in ", optionen)
			gefunden = false
			break
		optionen = []
		await druecke(KEY_1 + index)
	var n := 0
	while D.aktiv and n < 6:
		if not optionen.is_empty():
			break
		await druecke(KEY_E)
		n += 1
	if D.aktiv: D.beende()
	return gefunden

## Wartet (höchstens sekunden), bis ein Flag gesetzt ist.
func warte_auf_flag(flag: String, sekunden: float) -> bool:
	var ende := Time.get_ticks_msec() + int(sekunden * 1000)
	while not S.hat_flag(flag) and Time.get_ticks_msec() < ende:
		await physics_frame
	return S.hat_flag(flag)

func naechster_tag() -> void:
	Z.minuten = 23.9 * 60.0
	Z.vorspulen(0.2)
	await process_frame

func _initialize() -> void:
	await process_frame
	D = root.get_node("Dialog"); S = root.get_node("Spielstand"); SP = root.get_node("Speicher"); Z = root.get_node("Spielzeit")
	SP.ordner = "user://speicher_test_spaehwesen/"
	var zeilen: Array = []
	S.belauscht.connect(func(t): zeilen.append(t))
	S.meldung.connect(func(t): meldungen.append(t))
	D.zeile_gezeigt.connect(func(_s, _t, o): optionen = o)
	SP.neues_spiel("Ansel")
	await scene_changed
	for i in 5: await process_frame
	current_scene.get_node("Entwickler").ueberspringe_akt1()
	Z.minuten = 10 * 60.0
	Z.vorspulen(0.0)

	# --- Sold zum Monatsanfang ---
	Z.tag = 30
	await naechster_tag()
	pruefe(S.geld == 36 and "3 Schillinge" in S.geld_text(), "Monatsanfang: drei Schillinge Sold für einen Wächter")
	S.setze_alarmstufe(2)
	Z.tag = 60
	await naechster_tag()
	pruefe(S.geld == 36 + 72, "Im Krieg verdoppelt sich der Sold")
	S.setze_alarmstufe(1)
	for i in 30: await process_frame
	while S.eingabe_gesperrt: await process_frame
	Z.minuten = 10 * 60.0
	Z.vorspulen(0.0)

	# --- Bürgschaft für einen Bewerber ---
	var kerrin_tor = current_scene.get_node("Personen/KerrinVorTor")
	pruefe(kerrin_tor.visible, "Nach dem Haupteid wartet ein Bewerber an der Schwelle")
	pruefe(await waehle(kerrin_tor, ["Ich bürge"]), "Bürgschaft angeboten")
	var kerrin = current_scene.get_node("Personen/KerrinImHof")
	pruefe(S.hat_flag("kerrin_anwaerter") and kerrin.visible and not kerrin_tor.visible, "Kerrin Fahl ist jetzt Anwärter im Hof, du bist sein Bürge")

	# --- Belauschen: offen von vorn wird man bemerkt ---
	var gespraech = current_scene.get_node("Gespraeche/KerrinUndTilo")
	meldungen.clear()
	await setze(Vector3(22, 0.3, -4.5))
	await warte(4.0)
	pruefe(meldungen.any(func(m): return "verstummen" in m) and not S.hat_flag("beobachtung_kerrin"), "Offen von vorn: Sie bemerken dich und verstummen")
	gespraech._pause = 0.0   # für den Test nicht zwanzig Sekunden warten

	# --- Schleichend von der Seite: alles gehört ---
	zeilen.clear()
	await setze(Vector3(17, 0.3, 1.1))
	Input.action_press("schleichen")
	await warte(0.2)
	pruefe(spieler().schleicht, "Strg: geduckt schleichen")
	var gehoert := await warte_auf_flag("beobachtung_kerrin", 22.0)
	Input.action_release("schleichen")
	pruefe(gehoert and zeilen.size() >= 4 and S.akte.back()["art"] == "beobachtung", "Unbemerkt belauscht: Kerrin fragt nach den Fluchtgängen (Beobachtung in der Akte)")
	pruefe("Fluchtgänge" in zeilen[0] or zeilen.any(func(z): return "Ashenveil" in z), "Die belauschten Zeilen erscheinen unten im Bild")

	# --- Als Bürge selbst melden ---
	var treue: int = S.ansehen_wert("treue")
	var kammerhueter = current_scene.get_node("BurgHof/Personen/Kammerhueter")
	pruefe(await waehle(kammerhueter, ["Kerrin Fahl fragt"]), "Beim Kammerhüter gemeldet")
	pruefe(S.hat_flag("kerrin_gefasst") and S.zaehler_wert("verweise") == 0 and S.ansehen_wert("treue") == treue + 5 and not kerrin.visible,
			"Kerrin wird gefasst, gegen den Bürgen gibt es kein Verfahren")

	# --- Riverlock: Gold über dem Sold und ein belauschtes Angebot ---
	var alt := current_scene.get_instance_id()
	current_scene.get_node("Entwickler").reise("riverlock")
	await warte_auf_szene(alt)
	Z.minuten = 10 * 60.0
	Z.vorspulen(0.0)
	var gesandter = current_scene.get_node("Personen/Gesandter")
	var geld: int = S.geld
	pruefe(await waehle(gesandter, ["Was wollt Ihr", "Ich nehme"], Vector3(0, 0.3, -1.4)), "Mit dem Gesandten gesprochen")
	pruefe(S.geld == geld + 240 and S.hat_flag("gold_angenommen"), "Einen Gulden vom Gesandten angenommen")
	await setze(Vector3(135, 0.3, 21.1))
	# Wer eben direkt neben ihnen stand, wurde bemerkt: Für den Test nicht zwanzig Sekunden warten.
	current_scene.get_node("Gespraeche/GesandterUndSchreiber")._pause = 0.0
	Input.action_press("schleichen")
	var kette := await warte_auf_flag("beobachtung_kette", 22.0)
	Input.action_release("schleichen")
	pruefe(kette, "Gesandten und Schreiber belauscht: Gold für die Kette")
	var beobachter = current_scene.get_node("Personen/Beobachter")
	pruefe(await waehle(beobachter, ["Gold für die Kette"], Vector3(0, 0.3, -1.6)) and S.hat_flag("bericht_kette"), "Bericht an den Beobachter")
	pruefe(await waehle(beobachter, ["Gulden gegeben"], Vector3(0, 0.3, -1.6)) and S.hat_flag("gold_gemeldet") and S.geld == geld,
			"Das Gold gemeldet und abgegeben")
	await naechster_tag()
	await naechster_tag()
	await naechster_tag()
	pruefe(S.verfahren.is_empty(), "Gemeldetes Gold: kein Verfahren")

	# --- Speichern und Laden ---
	pruefe(SP.speichern("1"), "Gespeichert")
	alt = current_scene.get_instance_id()
	S.geld = 0
	SP.laden("1")
	await warte_auf_szene(alt)
	pruefe(S.geld == geld and S.hat_flag("beobachtung_kette"), "Geladen: Geld und Beobachtungen sind da")

	# --- Wer Gold nicht meldet, wird von den Prüfern angezeigt ---
	S.setze_flag("gold_gemeldet", false)
	S.zaehler_aendern("gold_tag", Z.gesamttag() - S.zaehler_wert("gold_tag"))
	await naechster_tag()
	await naechster_tag()
	pruefe(S.verfahren.is_empty(), "Zwei Tage lang merkt noch niemand etwas")
	await naechster_tag()
	pruefe(int(S.verfahren.get("stufe", 0)) == 3 and "Gold" in S.verfahren["grund"], "Nach drei Tagen: Anzeige auf Strafversetzung (Gold über dem Sold)")

	# --- Wer als Bürge schweigt, haftet mit ---
	S.setze_flag("kerrin_gefasst", false)
	S.zaehler_aendern("kerrin_tag", Z.gesamttag() - S.zaehler_wert("kerrin_tag"))
	var verweise: int = S.zaehler_wert("verweise")
	for i in 4:
		await naechster_tag()
	pruefe(S.hat_flag("kerrin_gefasst") and S.zaehler_wert("verweise") == verweise + 1, "Die Prüfer fassen den Bewerber: Verweis für den Bürgen")

	print("\nFehler: ", fehler)
	quit(fehler)
