extends SceneTree
## Prüft das Leben in Drachenstein: Stadtleute mit Tagesablauf (Markt am Vormittag, nachts im Haus),
## Gehen vor den Augen des Spielers (dem Boden folgend), Streifen in Runden, Stehenbleiben im Gespräch,
## wechselnde Zeilen je Person, leere Märkte bei Alarm, Speichern und Laden.
## Starten: godot --headless --path . --script res://tests/test_leben.gd



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

var zeilen: Array = []

func stadt(name: String) -> Node3D:
	return current_scene.get_node("Personen/Stadtleben/" + name)

func setze_zeit(stunde: float) -> void:
	Z.minuten = stunde * 60.0
	Z.vorspulen(0.0)
	for i in 3: await physics_frame

func flach(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)

## Bodenhöhe unter einem Punkt (Strahl nach unten), um Schweben und Versinken zu erkennen.
func boden_unter(p: Vector3, ausnahme: Node3D) -> float:
	var abfrage := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.5, p + Vector3.DOWN * 4.0, 1)
	abfrage.exclude = [ausnahme.get_rid()]
	var t: Dictionary = current_scene.get_world_3d().direct_space_state.intersect_ray(abfrage)
	return t.position.y if t else NAN

func _initialize() -> void:
	await process_frame
	D = root.get_node("Dialog"); S = root.get_node("Spielstand"); SP = root.get_node("Speicher"); Z = root.get_node("Spielzeit")
	SP.ordner = "user://speicher_test_leben/"
	S.meldung.connect(func(t): meldungen.append(t))
	D.zeile_gezeigt.connect(func(_s, t, o):
		optionen = o
		zeilen.append(t))
	SP.neues_spiel("Ansel")
	await scene_changed
	for i in 5: await process_frame
	current_scene.get_node("Entwickler").ueberspringe_akt1()
	await setze_zeit(10.0)

	# --- Wie viele Leute leben in der Region? ---
	var personen := 0
	var mit_ablauf := 0
	for knoten in current_scene.find_children("*", "StaticBody3D", true, false):
		if knoten.has_method("unterwegs"):
			personen += 1
			if not knoten.tagesablauf.is_empty():
				mit_ablauf += 1
	pruefe(current_scene.get_node("Personen/Stadtleben").get_child_count() >= 30, "Mindestens 30 Stadtleute in Drachenstein")
	pruefe(personen >= 50, "Mindestens 50 Personen in der Region (sind %d)" % personen)
	pruefe(mit_ablauf >= 25, "Mindestens 25 davon mit Tagesablauf (sind %d)" % mit_ablauf)

	# --- Vormittag: Bürger auf dem Markt, Händler am Stand, Kinder um den Brunnen ---
	var hedda := stadt("BuergerHedda")
	var marit := stadt("Fischhaendlerin")
	var pim := stadt("KindPim")
	pruefe(hedda.visible and flach(hedda.global_position).distance_to(Vector2(130.5, 123.7)) < 1.0, "Vormittags ist Hedda Korn auf dem Markt")
	pruefe(marit.visible and flach(marit.global_position).distance_to(Vector2(130.5, 101.7)) < 1.0, "Marit Hoff steht an ihrem Fischstand")
	pruefe(pim.visible and pim.unterwegs(), "Pim rennt um den Brunnen")
	var p0 := pim.global_position
	await warte(1.0)
	pruefe(pim.global_position.distance_to(p0) > 1.0 and absf(pim.global_position.y - boden_unter(pim.global_position, pim)) < 0.3,
			"… und folgt dabei dem Boden")

	# --- Nachts: alle im Haus, die Nachtstreife unterwegs ---
	await setze(Vector3(-10, 14.3, 15))
	await setze_zeit(23.0)
	pruefe(not hedda.visible and not marit.visible and not pim.visible, "Nachts sind Bürger, Händler und Kinder im Haus")
	pruefe(stadt("StreifeMarten").visible and stadt("StreifeMarten").unterwegs(), "Die Nachtstreife geht ihre Runde")
	pruefe(not stadt("StreifeHahn").visible, "Die Tagstreife ist in der Burg")
	pruefe(not hedda.is_in_group("interagierbar") and not hedda.is_in_group("treffbar"), "Wer im Haus ist, kann nicht angesprochen werden")

	# --- Morgens kommt die Tagstreife heraus, Händler gehen zu ihren Ständen ---
	await setze_zeit(6.0)
	pruefe(stadt("StreifeHahn").visible and not stadt("StreifeMarten").visible, "Wachwechsel bei Morgengrauen")
	pruefe(marit.visible and flach(marit.global_position).distance_to(Vector2(130.5, 101.7)) < 1.0, "Bei Morgengrauen steht die Händlerin schon am Stand (Spieler weit weg)")

	# --- Vor den Augen des Spielers wird gegangen ---
	await setze_zeit(10.0)
	await setze(Vector3(133, hedda.global_position.y + 0.5, 126))
	await setze_zeit(11.99)
	await warte(1.2)   # Mittag beginnt
	var start := hedda.global_position
	pruefe(hedda.unterwegs(), "Mittag: Hedda geht vom Markt zum Brunnen, während der Spieler zusieht")
	var ende := Time.get_ticks_msec() + 180000
	var schwebt := false
	while hedda.unterwegs() and Time.get_ticks_msec() < ende:
		await physics_frame
		var b := boden_unter(hedda.global_position, hedda)
		if not is_nan(b) and absf(hedda.global_position.y - b) > 0.4:
			schwebt = true
	pruefe(not hedda.unterwegs() and flach(hedda.global_position).distance_to(Vector2(141.6, 111.5)) < 0.5, "… und kommt am Brunnen an (steht bei %s)" % flach(hedda.global_position))
	pruefe(hedda.global_position.distance_to(start) > 2.0 and not schwebt, "… ohne zu schweben oder zu versinken")

	# --- Wer angesprochen wird, bleibt stehen ---
	var sanne := stadt("StreifeKiel")
	await setze(sanne.global_position + Vector3(0, 0.3, 1.2))
	await warte(0.3)
	await setze(sanne.global_position + Vector3(0, 0.3, 1.2))
	zeilen.clear()
	await druecke(KEY_E)
	pruefe(D.aktiv, "Streife angesprochen")
	var andere := stadt("StreifeHahn")
	if andere._spricht:   # beide Streifen kommen zusammen aus dem Burgtor
		andere = sanne
		sanne = stadt("StreifeHahn")
	var steht := sanne.global_position
	await warte(1.5)
	pruefe(sanne.global_position.distance_to(steht) < 0.05, "Im Gespräch bleibt sie stehen")
	var a0 := andere.global_position
	await warte(0.5)
	pruefe(andere.global_position.distance_to(a0) > 0.3, "Die andere Streife geht derweil weiter")
	D.beende()
	await warte(1.0)
	pruefe(sanne.global_position.distance_to(steht) > 0.5, "Nach dem Gespräch geht sie weiter")

	# --- Leute desselben Schlags sagen Verschiedenes ---
	var gruesse := {}
	for name in ["BuergerHedda", "BuergerWilm", "BuergerFenja", "BuergerGerd", "BuergerLiese", "BuergerKonrad", "BuergerAlke", "BuergerRuben"]:
		zeilen.clear()
		D.starte("stadt_buerger", stadt(name).anzeige_name)
		gruesse[zeilen[0]] = true
		D.beende()
	pruefe(gruesse.size() >= 3, "Acht Bürger, mindestens drei verschiedene Grüße (sind %d)" % gruesse.size())
	zeilen.clear()
	D.starte("stadt_buerger", "Hedda Korn")
	var heute: String = zeilen[0]
	D.beende()
	var tag_vorher: int = Z.tag
	var anders := false
	for t in 6:
		Z.tag = tag_vorher + 1 + t
		zeilen.clear()
		D.starte("stadt_buerger", "Hedda Korn")
		anders = anders or zeilen[0] != heute
		D.beende()
	Z.tag = tag_vorher
	pruefe(anders, "Hedda sagt nicht jeden Tag dasselbe")
	pruefe(await waehle(hedda, ["Was hört man"]) and zeilen.size() >= 2 and zeilen[-1] != "", "Gerüchte aus der Stadt")

	# --- Alarm: Märkte leer, Streifen bleiben ---
	S.setze_alarmstufe(2)
	for i in 30: await process_frame
	while S.eingabe_gesperrt: await process_frame
	pruefe(not marit.visible and not hedda.visible and not pim.visible, "Bei Alarm sind Markt und Brunnen leer")
	pruefe(stadt("StreifeKiel").visible and stadt("Schmied").visible, "Streife und Handwerker bleiben")
	S.setze_alarmstufe(1)
	for i in 30: await process_frame
	while S.eingabe_gesperrt: await process_frame
	pruefe(marit.visible, "Nach dem Alarm ist der Markt wieder offen")

	# --- Stille-Stunde: heim, nur der Küster bleibt bis zur Nacht ---
	await setze(Vector3(-10, 14.3, 15))
	await setze_zeit(19.2)
	pruefe(not marit.visible and not hedda.visible and stadt("Kuester").visible, "Zur Stille-Stunde gehen alle heim, der Küster bleibt an der Kirche")

	# --- Speichern und Laden in der Nacht ---
	await setze_zeit(22.0)
	pruefe(SP.speichern("1"), "Nachts gespeichert")
	var alt := current_scene.get_instance_id()
	SP.laden("1")
	await warte_auf_szene(alt)
	pruefe(not stadt("BuergerHedda").visible and stadt("StreifeStrom").visible, "Nach dem Laden: nachts im Haus, die Nachtstreife unterwegs")
	await setze_zeit(10.0)
	pruefe(stadt("BuergerHedda").visible and flach(stadt("BuergerHedda").global_position).distance_to(Vector2(130.5, 123.7)) < 1.0,
			"Am Vormittag ist Hedda wieder auf dem Markt")

	print("\nFehler: ", fehler)
	quit(fehler)
