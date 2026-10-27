extends SceneTree
## Prüft Akt II, Teil 1 „Die Nachrichtenkette“ mit echtem Gehen und echten Tasten: Zeitsprung beim Komtur,
## Siegelhülse bei Leofa Marsh, der Beobachter in Riverlock, das Pult des Schreibers (tagsüber bewacht, nachts
## frei), und die Ausgänge: Falk liefert aus, Falk verweigert, Dorn flieht, Bestechung (Anzeige nach fünf Tagen).
## Starten: godot --headless --path . --script res://tests/test_akt2.gd


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
	SP.ordner = "user://speicher_test_akt2/"
	S.meldung.connect(func(t): meldungen.append(t))
	D.zeile_gezeigt.connect(func(_s, _t, o): optionen = o)
	SP.neues_spiel("Ansel")
	await scene_changed
	for i in 5: await process_frame
	current_scene.get_node("Entwickler").ueberspringe_akt1()
	Z.minuten = 10 * 60.0
	Z.vorspulen(0.0)

	# --- Der Komtur eröffnet Akt II mit einem Zeitsprung ---
	var komtur = current_scene.get_node("BurgHof/Personen/Komtur")
	await setze(komtur.global_position + Vector3(0, 0.3, 1.4))
	await druecke(KEY_E)
	pruefe(D.aktiv and S.eingabe_gesperrt, "Komtur angesprochen, die Blende beginnt")
	pruefe(await warte_auf_blende(), "Die Blende „Akt II · Wachsamkeit“ läuft durch")
	var n := 0
	while D.aktiv and n < 10:
		await druecke(KEY_E)
		n += 1
	pruefe(Z.jahr == 1754, "Ein Jahr ist vergangen: Frühjahr 1754 (ist %d)" % Z.jahr)
	pruefe(S.hat_flag("akt2_begonnen") and "Leofa Marsh" in S.ziel, "Auftrag: die Nachrichtenkette, zuerst zu Leofa Marsh")
	var vorher: Array = await optionen_von(komtur)
	pruefe(vorher.any(func(o): return "Noch nichts" in o), "Ohne Beweis: der Komtur wartet")

	# --- Leofa Marsh zeigt die Siegelhülse ---
	var leofa = current_scene.get_node("SchwarzerBergfried/LeofaMarsh")
	var vor_ihr: Vector3 = -leofa.global_basis.z * 1.4 + Vector3(0, 0.3, 0)
	await waehle(leofa, [], vor_ihr)
	pruefe(S.hat_flag("siegel_gesehen") and "Beobachter" in S.ziel, "Leofa: Die Hülse wurde mit Zollwachs aus Riverlock neu gesiegelt")

	# --- Riverlock: Der Beobachter weist auf den Schreiber ---
	await reise("riverlock")
	pruefe(region_id() == "riverlock", "Nach Riverlock gereist")
	var pult = current_scene.get_node("Personen/PultDorn")
	pruefe(not pult.is_in_group("interagierbar"), "Das Pult ist zuerst nur ein Möbelstück")
	pruefe(await waehle(current_scene.get_node("Personen/Beobachter"), ["neu gesiegelt"]), "Beim Beobachter nachgefragt")
	pruefe(S.hat_flag("kette_beobachter") and pult.is_in_group("interagierbar"), "Der Beobachter nennt Lukas Dorn und sein Pult im Zoll")

	# --- Tagsüber sieht die Zöllnerin herüber ---
	var zoellnerin = current_scene.get_node("Personen/Zoellnerin")
	meldungen.clear()
	await vor_ziel(pult, -1.4)
	await druecke(KEY_E)
	pruefe(not D.aktiv and not S.hat_flag("beweis_entwurf") and meldungen.any(func(m): return "Nicht jetzt" in m),
			"Tagsüber: Die Zöllnerin sieht herüber, durchsuchen geht nicht")
	if D.aktiv: D.beende()

	# --- Nachts ist der Zoll geschlossen ---
	Z.minuten = 23 * 60.0
	Z.vorspulen(0.0)
	await process_frame
	pruefe(not zoellnerin.visible, "Nachts ist die Zöllnerin nicht da")
	await vor_ziel(pult, -1.4)
	pruefe(spieler().ziel == pult, "Das Pult ist das nächste Ziel")
	await rede([])
	pruefe(S.hat_flag("beweis_entwurf") and not pult.is_in_group("interagierbar"), "Nachts das Pult durchsucht: Entwurf des gefälschten Berichts gefunden")
	pruefe(S.akte.any(func(e): return "Siegelstempel" in e["text"]), "Der Fund steht in der Akte")
	Z.minuten = 12 * 60.0
	Z.vorspulen(0.0)
	await process_frame
	pruefe(zoellnerin.visible, "Am Tag sitzt die Zöllnerin wieder am Zoll")

	# --- Speichern und Laden mitten in der Kette ---
	pruefe(SP.speichern("1"), "Gespeichert mit dem Beweis in der Tasche")

	# --- Ausgang A: Falk liefert aus ---
	var falk = current_scene.get_node("Personen/ZollherrFalk")
	var riverlock: int = S.ansehen_wert("riverlock")
	pruefe(await waehle(falk, ["gefälscht"]), "Zollherr Falk den Beweis gezeigt")
	pruefe(S.hat_flag("dorn_ausgeliefert") and S.ansehen_wert("riverlock") == riverlock + 5, "Falk liefert seinen Schreiber aus (Riverlock +5)")
	for i in 3: await process_frame
	pruefe(not current_scene.get_node("Personen/Schreiber").visible, "Der Schreiber ist fort")
	await reise("drachenstein")
	komtur = current_scene.get_node("BurgHof/Personen/Komtur")
	var treue: int = S.ansehen_wert("treue")
	pruefe(await waehle(komtur, ["selbst ausgeliefert"]), "Dem Komtur berichtet")
	pruefe(S.hat_flag("kette_abgeschlossen") and S.ansehen_wert("treue") == treue + 5 and S.ziel == "",
			"Nachrichtenkette abgeschlossen: Falk hat geliefert (Treue +5)")

	# --- Laden: Ausgang B, der Komtur entscheidet ---
	var alt := current_scene.get_instance_id()
	SP.laden("1")
	await warte_auf_szene(alt)
	Z.minuten = 12 * 60.0
	Z.vorspulen(0.0)
	pruefe(region_id() == "riverlock" and S.hat_flag("beweis_entwurf") and not S.hat_flag("kette_entschieden"), "Geladen: wieder in Riverlock mit dem Beweis")
	await reise("drachenstein")
	komtur = current_scene.get_node("BurgHof/Personen/Komtur")
	pruefe(await waehle(komtur, ["Entscheidet Ihr", "Wie geht es weiter"]), "Den Beweis dem Komtur übergeben")
	pruefe(S.hat_flag("rat_entschied") and S.hat_flag("kette_abgeschlossen"), "Der Rat zwingt Falk mit Siegel, der Faden ist abgeschlossen")

	# --- Ausgang C: Falk verweigert, wenn Riverlock dem Wächter nicht traut ---
	alt = current_scene.get_instance_id()
	SP.laden("1")
	await warte_auf_szene(alt)
	Z.minuten = 12 * 60.0
	Z.vorspulen(0.0)
	S.ansehen_aendern("riverlock", -10)
	falk = current_scene.get_node("Personen/ZollherrFalk")
	pruefe(await waehle(falk, ["gefälscht"]), "Falk den Beweis gezeigt, obwohl Riverlock dir misstraut")
	pruefe(S.hat_flag("dorn_geflohen") and not S.hat_flag("dorn_ausgeliefert"), "Falk weigert sich, Dorn flieht über die Brücke")

	# --- Ausgang D: Dorn bietet Gold ---
	alt = current_scene.get_instance_id()
	SP.laden("1")
	await warte_auf_szene(alt)
	Z.minuten = 12 * 60.0
	Z.vorspulen(0.0)
	var geld: int = S.geld
	var schreiber = current_scene.get_node("Personen/Schreiber")
	pruefe(await waehle(schreiber, ["Entwurf gefunden", "Ich nehme das Gold"], Vector3(0, 0.3, 1.4)), "Den Schreiber gestellt, das Gold genommen")
	pruefe(S.geld == geld + 1200 and S.hat_flag("dorn_bestochen") and "5 Gulden" in S.geld_text(), "Fünf Gulden in der Tasche")
	for t in 4:
		await naechster_tag()
	pruefe(S.verfahren.is_empty(), "Vier Tage lang merkt niemand etwas")
	await naechster_tag()
	pruefe(S.hat_flag("dorn_angezeigt") and int(S.verfahren.get("stufe", 0)) == 5, "Nach fünf Tagen: Anzeige auf Stufe 5 (Hilfe für Valdrenn)")

	# --- Ausgang D', gestehen statt schweigen ---
	alt = current_scene.get_instance_id()
	SP.laden("1")
	await warte_auf_szene(alt)
	Z.minuten = 12 * 60.0
	Z.vorspulen(0.0)
	schreiber = current_scene.get_node("Personen/Schreiber")
	await waehle(schreiber, ["Entwurf gefunden", "Ich nehme das Gold"], Vector3(0, 0.3, 1.4))
	await reise("drachenstein")
	var kammerhueter = current_scene.get_node("BurgHof/Personen/Kammerhueter")
	pruefe(await waehle(kammerhueter, ["fünf Gulden"]), "Dem Kammerhüter gestanden")
	pruefe(S.hat_flag("dorn_gestanden") and S.geld == geld and int(S.verfahren.get("stufe", 0)) == 3, "Gold abgegeben, Anzeige nur auf Stufe 3")
	for t in 6:
		await naechster_tag()
	pruefe(not S.hat_flag("dorn_angezeigt"), "Wer gesteht, wird nicht noch einmal angezeigt")
	komtur = current_scene.get_node("BurgHof/Personen/Komtur")
	pruefe(await waehle(komtur, ["nichts gefunden"]), "Dem Komtur gesagt: nichts gefunden")
	pruefe(S.hat_flag("kette_abgeschlossen"), "Auch so endet der Faden, aber die Akte weiß es besser")

	print("
Fehler: ", fehler)
	quit(fehler)
