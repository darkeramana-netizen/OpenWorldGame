extends SceneTree
## Spielt Akt I vollständig durch und prüft Spielstand, Speichern und Laden.
## Starten (im Projektordner):
##   godot --headless --script res://tests/test_akt1.gd
## Benutzt einen eigenen Speicherordner, echte Spielstände bleiben unberührt.

var fehler := 0
var zeile := {}
var blenden: Array = []
var D; var S; var Z; var SP

func pruefe(bed: bool, was: String) -> void:
	if bed: print("OK     ", was)
	else:
		fehler += 1
		print("FEHLER ", was, "   | zeile=", zeile.get("t", "").left(70), " flags=", S.flags.keys())

func hof() -> Node:
	return current_scene.get_node("BurgHof")

func person(name: String) -> Node:
	return hof().get_node("Personen/" + name)

func spieler() -> Node:
	return current_scene.get_node("Spieler")

## Spricht eine Person an und wählt die Antworten der Reihe nach. Danach "Weiter" bis zum Ende.
func rede(name: String, wahl: Array = []) -> void:
	person(name).interagieren(spieler())
	var i := 0
	var n := 0
	while D.aktiv and n < 40:
		n += 1
		if zeile.o.is_empty():
			D.waehle(0)
		elif i < wahl.size():
			D.waehle(wahl[i]); i += 1
		else:
			break
	if D.aktiv:
		print("       (Gespräch mit ", name, " wartet auf Antwort: ", zeile.o, ")")
		D.beende()

func zeit(stunde: float) -> void:
	Z.minuten = stunde * 60.0
	Z.vorspulen(0.0)

func gehe_zu(pos: Vector3) -> void:
	spieler().global_position = pos
	spieler().velocity = Vector3.ZERO
	for i in 4: await physics_frame

func bis_morgengrauen() -> void:
	var n := 0
	while Z.abschnitt != &"morgengrauen" and n < 20:
		Z.vorspulen(1.0); n += 1
	Z.vorspulen(1.0)

func warte_blenden() -> void:
	var n := 0
	while S.eingabe_gesperrt and n < 2000:
		await process_frame; n += 1

func wechsle(aktion: Callable) -> void:
	aktion.call()
	await scene_changed
	for i in 3: await process_frame

func _initialize() -> void:
	Engine.time_scale = 30.0
	await process_frame
	D = root.get_node("Dialog"); S = root.get_node("Spielstand"); Z = root.get_node("Spielzeit"); SP = root.get_node("Speicher")
	SP.ordner = "user://speicher_test/"
	for p in ["auto", "schnell", "1", "2", "3"]: DirAccess.remove_absolute(SP._pfad(p))
	D.zeile_gezeigt.connect(func(s, t, o): zeile = {"s": s, "t": t, "o": o})
	S.blende.connect(func(t, a): blenden.append(a))

	await wechsle(func(): SP.neues_spiel("Ansel"))
	pruefe(S.spieler_name == "Ansel" and S.rang == 0 and S.ziel.begins_with("Sprich mit dem Kammerhüter"), "Neues Spiel mit Name und Startziel")

	rede("Kammerhueter", [0, 0, 0, 1, 0])
	pruefe(S.rang == 1 and S.hat_flag("geloebnis"), "Gelöbnis: Anwärter")
	rede("Fenn", [2])
	pruefe(S.hat_flag("fenn_fragte") and S.hat_flag("fenn_vertrauen"), "Fenn fragt, Spieler deckt ihn")

	rede("MarenSell", [1])
	for s in get_nodes_in_group("interagierbar").filter(func(n): return n.get("zaehler_name") == "bruchsteine"): s.interagieren(spieler())
	await process_frame
	rede("MarenSell")
	pruefe(S.hat_flag("aufgabe_kueche"), "Steine abgegeben, Küche als Nächstes")

	zeit(9)
	rede("IlseDorn")
	pruefe(not S.hat_flag("kueche_erledigt") and "Mittag" in zeile.t, "Küche nur zum Mittag")
	zeit(12.2)
	rede("IlseDorn", [0])
	pruefe(S.hat_flag("kueche_erledigt"), "Küchendienst beim Mahl")

	rede("MarenSell")
	pruefe(Z.jahr == 1751 and S.hat_flag("pruefung_knappe") and blenden.has("zwischen"), "Probejahr: Zeitsprung nach 1751")
	await warte_blenden()
	pruefe(SP.speichern("1"), "Speichern auf Platz 1")

	rede("OdoHesse", [0])
	pruefe(not S.hat_flag("pruefung_lesen"), "Lesen: falsche Antwort fällt durch")
	rede("OdoHesse", [1, 0, 2])
	pruefe(S.hat_flag("pruefung_lesen"), "Lesen bestanden")

	rede("HeddaBrunn")
	var bank = hof().get_node("Bauhof/Werkbank")
	zeit(22); bank.interagieren(spieler())
	pruefe(S.zaehler_wert("eckstein") == 0, "Werkbank nachts gesperrt")
	zeit(8); for i in 3: bank.interagieren(spieler())
	pruefe(S.zaehler_wert("eckstein") == 3 and Z.minuten >= 11 * 60, "Drei Arbeitsgänge, drei Stunden")
	rede("HeddaBrunn")
	pruefe(S.hat_flag("pruefung_handwerk"), "Handwerk bestanden")

	rede("AnselmKray")
	zeit(14); await gehe_zu(Vector3(-12, 22.3, 31))
	pruefe(not hof().get_node("Posten/NachtwacheKnappe")._aktiv, "Nachtwache beginnt nicht am Tag")
	await gehe_zu(Vector3(0, 14.2, 10)); zeit(21); await gehe_zu(Vector3(-12, 22.3, 31))
	pruefe(hof().get_node("Posten/NachtwacheKnappe")._aktiv, "Nachtwache auf dem Wehrgang beginnt nachts")
	await bis_morgengrauen()
	pruefe(S.hat_flag("pruefung_nachtwache"), "Nachtwache bis zum Morgengrauen gehalten")

	await gehe_zu(Vector3(-15, 14.2, 4))
	rede("MarenSell", [0, 0])
	pruefe(S.rang == 2 and Z.jahr == 1753 and S.hat_flag("lehrjahre_vorbei"), "Knappen-Eid und zwei Lehrjahre")
	await warte_blenden()
	pruefe(SP.speichern("2"), "Speichern auf Platz 2")

	# --- Laden ---
	await wechsle(func(): SP.laden("1"))
	pruefe(S.rang == 1 and Z.jahr == 1751 and not S.hat_flag("pruefung_lesen"), "Platz 1 geladen: Anwärter 1751")
	pruefe(get_nodes_in_group("interagierbar").filter(func(n): return n.get("zaehler_name") == "bruchsteine").is_empty(), "Aufgehobene Steine bleiben weg")
	pruefe(spieler().global_position.distance_to(Vector3(-15, 14, 4)) > 1.0, "Spielerposition aus Platz 1")
	await wechsle(func(): SP.laden("2"))
	pruefe(S.rang == 2 and Z.jahr == 1753 and S.hat_flag("pruefung_nachtwache"), "Platz 2 geladen: Knappe 1753")
	pruefe(spieler().global_position.distance_to(Vector3(-15, 14, 4)) < 0.5, "Spielerposition aus Platz 2")

	# --- Torwache ---
	rede("IvoGrend")
	zeit(9); await gehe_zu(Vector3(-2.4, 14.2, 34.6))
	await gehe_zu(Vector3(0, 14.2, 40))
	pruefe(S.zaehler_wert("verweise") == 1 and S.akte.back()["art"] == "verweis", "Posten zu früh verlassen: Verweis")
	await gehe_zu(Vector3(-2.4, 14.2, 34.6))
	Z.vorspulen(1.0); Z.vorspulen(1.0); Z.vorspulen(0.1)
	pruefe(S.hat_flag("torwache_erledigt"), "Torwache bis zur Ablösung")
	await gehe_zu(Vector3(4, 14.2, 28))
	rede("IvoGrend")
	rede("MarenSell", [0])
	pruefe(S.rang == 3 and S.hat_flag("geselle"), "Gesellen-Eid")

	# --- Fenn: drei Ausgänge ---
	rede("MarenSell")
	pruefe(S.ziel.begins_with("Sprich mit Fenn"), "Maren schickt zu Fenn")
	await warte_blenden()
	SP.speichern("3")
	rede("Fenn", [1, 1])
	pruefe(S.hat_flag("fenn_aufgeloest") and S.zaehler_wert("verweise") == 2 and not person("Fenn").visible, "Geschwiegen: Fenn gefasst, Verweis, Bürge mitverhandelt")

	# --- Weg zum Haupteid ---
	await warte_blenden()
	rede("MarenSell")
	pruefe(S.hat_flag("aufgabe_turmwache"), "Aufgabe: allein auf dem Turm")
	rede("Komtur")
	pruefe("Nachtwache allein" in zeile.t, "Komtur verlangt erst Turm und Zustimmungen")
	rede("IvoGrend", [0])
	pruefe(not S.hat_flag("zustimmung_wachfuehrer"), "Ivo: falsche Antwort")
	rede("IvoGrend", [2, 0])
	pruefe(S.hat_flag("zustimmung_wachfuehrer"), "Ivo stimmt zu")
	zeit(21); await gehe_zu(Vector3(-27, 26.3, -27))
	pruefe(hof().get_node("Posten/Turmwache")._aktiv, "Turmwache beginnt")
	await bis_morgengrauen()
	pruefe(S.hat_flag("turmwache_erledigt"), "Turmwache allein gehalten")
	await gehe_zu(Vector3(0, 14.2, -14))
	rede("MarenSell")
	pruefe(S.hat_flag("zustimmung_hueter"), "Maren stimmt zu")
	blenden.clear()
	rede("Komtur", [0, 0, 0])
	pruefe(S.rang == 4 and S.hat_flag("eid_waechter") and S.hat_flag("akt1_ende"), "Haupteid: Wächter, Ende von Akt I")
	pruefe(blenden == ["zwischen", "akt_ende"], "Blenden: Namensstein und Akt-Ende")
	var wand = hof().get_node("Ordenswand")
	pruefe(wand.get_children().any(func(n): return n is Label3D and n.text == "Ansel"), "Eigener Namensstein in der Ordenswand")
	await warte_blenden()
	await process_frame
	pruefe(SP.existiert("auto") and SP.beschreibung("auto").begins_with("Wächter Ansel"), "Automatisch gespeichert: " + SP.beschreibung("auto"))
	pruefe(SP.neuester_platz() == "auto", "Fortsetzen nimmt den neuesten Stand")

	# --- Verrat ---
	await wechsle(func(): SP.laden("3"))
	blenden.clear()
	rede("Fenn", [1, 2])
	pruefe(blenden.has("spielende") and S.hat_flag("fenn_geholfen"), "Verrat führt zum Spielende")

	# --- Melden ---
	await warte_blenden()
	await wechsle(func(): SP.laden("3"))
	rede("Fenn", [1, 0])
	rede("Kammerhueter", [0])
	pruefe(S.hat_flag("fenn_aufgeloest") and S.zaehler_wert("verweise") == 1, "Gemeldet: Fenn gefasst, kein Verweis")

	print("\nAkte von Ansel (Platz 3 + Meldung):")
	for e in S.akte: print("  ", e.datum, " ", e.uhrzeit, "  ", e.text)
	print("\nFehler: ", fehler)
	quit(fehler)
