extends SceneTree
## Prüft die Innenräume mit echtem Gehen: Wendelrampe im Bergfried hinauf und hinunter,
## Tore vor und nach dem Öffnen, Torhaus und Donjon von Gravecrest, Gespräche, Entwicklermenü.
## Starten: godot --headless --path . --script res://tests/test_innen.gd

var fehler := 0
var orte: Array = []
var optionen: Array = []
var D; var S; var SP

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

## Richtet die Kamera so aus, dass W in diese Richtung (x, z) läuft.
func blicke(richtung: Vector2) -> void:
	spieler().get_node("KameraDrehpunkt").rotation.y = atan2(-richtung.x, -richtung.y)

## Läuft nacheinander zu den Wegpunkten (nur x und z zählen). Gibt zurück, ob alle erreicht wurden.
func gehe_ueber(punkte: Array, zeit_pro_punkt: float = 20.0) -> bool:
	Input.action_press("vor")
	var alle := true
	for ziel: Vector3 in punkte:
		var ende := Time.get_ticks_msec() + int(zeit_pro_punkt * 1000)
		var erreicht := false
		while Time.get_ticks_msec() < ende:
			var p: Vector3 = spieler().global_position
			var weg := Vector2(ziel.x - p.x, ziel.z - p.z)
			if weg.length() < 0.7:
				erreicht = true
				break
			blicke(weg)
			await physics_frame
		alle = alle and erreicht
		if not erreicht:
			print("       nicht erreicht: Ziel %s, stehe bei %s" % [ziel.snapped(Vector3.ONE * 0.1), spieler().global_position.snapped(Vector3.ONE * 0.1)])
			break
	Input.action_release("vor")
	for i in 3: await physics_frame
	return alle

## Läuft im Treppenhaus eines Turms die Wendelrampe hinauf (richtung 1) oder hinunter (-1),
## bis die Zielhöhe erreicht ist.
func wendel(mitte: Vector3, richtung: int, ziel_y: float, sekunden: float) -> float:
	Input.action_press("vor")
	Input.action_press("rennen")
	var ende := Time.get_ticks_msec() + int(sekunden * 1000)
	while Time.get_ticks_msec() < ende:
		var p: Vector3 = spieler().global_position
		if (richtung > 0 and p.y >= ziel_y) or (richtung < 0 and p.y <= ziel_y):
			break
		var rel := Vector2(p.x - mitte.x, p.z - mitte.z)
		var w := atan2(rel.y, rel.x)
		var tangente := Vector2(-sin(w), cos(w)) * richtung
		var zur_mitte := -rel.normalized() * (rel.length() - 2.75) * 0.6
		blicke(tangente + zur_mitte)
		await physics_frame
	Input.action_release("vor")
	Input.action_release("rennen")
	for i in 3: await physics_frame
	return spieler().global_position.y

func polar(mitte: Vector3, r: float, winkel: float, y: float) -> Vector3:
	return Vector3(mitte.x + r * cos(deg_to_rad(winkel)), y, mitte.z + r * sin(deg_to_rad(winkel)))

## Wegpunkte im Kreis um das Treppenhaus, damit der Weg nicht durch dessen Wand führt.
func ring(mitte: Vector3, r: float, von: float, bis: float) -> Array:
	var punkte := []
	var schritte := maxi(1, int(absf(bis - von) / 30.0))
	for k in schritte + 1:
		punkte.append(polar(mitte, r, lerpf(von, bis, float(k) / schritte), 0))
	return punkte

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

func _initialize() -> void:
	await process_frame
	D = root.get_node("Dialog"); S = root.get_node("Spielstand"); SP = root.get_node("Speicher")
	SP.ordner = "user://speicher_test_innen/"
	S.ort_betreten.connect(func(n, _u): orte.append(n))
	D.zeile_gezeigt.connect(func(_s, _t, o): optionen = o)
	SP.neues_spiel("Ansel")
	await scene_changed
	for i in 5: await process_frame
	var turm = current_scene.get_node("SchwarzerBergfried")
	var mitte: Vector3 = turm.global_position
	var winkel: float = turm.treppen_winkel

	# --- Bergfried: Tor zu ---
	await setze(polar(mitte, 26, winkel, -17.5))
	await gehe_ueber([polar(mitte, 12, winkel, 0)], 4.0)
	var r := Vector2(spieler().global_position.x - mitte.x, spieler().global_position.z - mitte.z).length()
	pruefe(r > 16.0, "Bergfried: Tor ist ohne Erlaubnis verschlossen (Abstand %.1f m)" % r)
	var waechter = current_scene.get_node("Personen/Bergwaechter")
	await setze(waechter.global_position + Vector3(0.9, 0.3, 0))
	await rede([KEY_1, KEY_4])
	pruefe(not S.hat_flag("bergfried_zugang"), "Bergwächter lässt Anwärter nicht hinein")

	# --- Akt I überspringen über das Entwicklermenü ---
	await druecke(KEY_F10)
	var menue = current_scene.get_node("Entwickler")
	pruefe(menue.get_node("%Fenster").visible, "Entwicklermenü öffnet mit F10")
	menue.ueberspringe_akt1()
	pruefe(S.rang == 4 and S.hat_flag("eid_waechter"), "Entwicklermenü: Akt I übersprungen")
	await setze(waechter.global_position + Vector3(0.9, 0.3, 0))
	await rede([KEY_4])
	pruefe(S.hat_flag("bergfried_zugang"), "Bergwächter öffnet dem Wächter das Tor")

	# --- Hinein und die Wendelrampe hinauf ---
	await setze(polar(mitte, 26, winkel, -17.5))
	var drin := await gehe_ueber([polar(mitte, 9, winkel, 0), polar(mitte, 3.0, winkel, 0)])
	pruefe(drin, "Durch das Tor bis ins Treppenhaus gegangen")
	var oben := await wendel(mitte, 1, mitte.y + 68.0, 70.0)
	pruefe(oben >= mitte.y + 67.5, "Wendelrampe hinauf bis aufs Dach (Höhe %.1f über der Insel)" % (oben - mitte.y))
	pruefe(orte.has("Die Stillebene"), "Auf dem Weg durch die Stillebene gegangen")
	var feuer = turm.get_node("Feuerbecken")
	await gehe_ueber(ring(mitte, 6.0, winkel, winkel + 180.0) + [polar(mitte, 6.9, winkel + 180.0, 0)])
	pruefe(await rede([KEY_1]), "Feuerbecken auf dem Dach angesehen")

	# --- Hinunter bis Ebene 4 (Archive): Namensbuch und Hüterin ---
	await gehe_ueber(ring(mitte, 6.0, winkel + 180.0, winkel) + [polar(mitte, 3.0, winkel, 0)])
	var archiv := await wendel(mitte, -1, mitte.y + 29.2, 40.0)
	pruefe(absf(archiv - mitte.y - 29.0) < 0.6, "Wendelrampe hinunter bis Ebene 4 (Höhe %.1f)" % (archiv - mitte.y))
	await gehe_ueber(ring(mitte, 5.6, winkel, winkel + 180.0) + [polar(mitte, 5.3, winkel + 180.0, 0)])
	await rede([])
	pruefe(S.hat_flag("namensbuch_gelesen"), "Eigenen Namen im Namensbuch gelesen")
	var leofa = turm.get_node("LeofaMarsh")
	var zu_leofa: Vector3 = leofa.global_position - mitte
	zu_leofa.y = 0
	await setze(leofa.global_position - zu_leofa.normalized() * 1.4 + Vector3(0, 0.2, 0))
	pruefe(await rede([KEY_2, KEY_5]), "Mit Hüterin der Stille Leofa Marsh gesprochen")

	# --- Weiter hinunter bis in die Sonderzellen (Ebene -4) ---
	await gehe_ueber(ring(mitte, 5.6, winkel + 150.0, winkel) + [polar(mitte, 3.0, winkel, 0)])
	var keller := await wendel(mitte, -1, mitte.y - 23.8, 60.0)
	pruefe(keller <= mitte.y - 23.5, "Wendelrampe hinunter bis Ebene -4 (Höhe %.1f)" % (keller - mitte.y))

	# --- Gravecrest: Fallgatter, Torhaus, Donjon ---
	S.setze_flag("gravecrest_zugang", false)
	await setze(Vector3(-606, 70.4, -364.8))
	await gehe_ueber([Vector3(-650, 70, -364.8)], 10.0)
	pruefe(spieler().global_position.x > -634.0, "Gravecrest: Fallgatter ist ohne Erlaubnis unten")
	var ulf = current_scene.get_node("Personen/TorwacheGravecrest")
	await setze(ulf.global_position + Vector3(0.9, 0.3, 0.9))
	await rede([KEY_4])
	pruefe(S.hat_flag("gravecrest_zugang"), "Kammbrecher zieht das Fallgatter hoch")
	await setze(Vector3(-606, 70.4, -364.8))
	var hof := await gehe_ueber([Vector3(-650, 70, -364.8), Vector3(-660, 70, -362)])
	pruefe(hof, "Durch das Torhaus in den Unteren Hof gegangen")
	var donjon = current_scene.get_node("Gravecrest/Donjon")
	var dm: Vector3 = donjon.global_position
	var durch := await gehe_ueber([Vector3(-660, 70, -367.5), Vector3(-675, 70, -364.5), dm + Vector3(12, 0, 0)] + ring(dm, 4.7, 0.0, 180.0) + [dm + Vector3(-13, 0, 0)])
	pruefe(durch, "Durch den Donjon vom Unteren in den Oberen Hof gegangen")
	await gehe_ueber(ring(dm, 4.7, 180.0, 90.0) + [polar(dm, 2.4, 90.0, 0)])
	var spitze := await wendel(dm, 1, dm.y + 17.0, 30.0)
	pruefe(spitze >= dm.y + 16.5, "Donjon hinauf bis zur Signalfeuerplattform")
	var torben = current_scene.get_node("Gravecrest/TorbenWick")
	await setze(torben.global_position + Vector3(1.2, 0.2, 0))
	pruefe(await rede([KEY_1, KEY_4]), "Mit Komtur Torben Wick im Audienzsaal gesprochen")

	print("\nFehler: ", fehler)
	quit(fehler)
