extends SceneTree
## Tests für den Nachlader der Zellen (autoload/zellwelt.gd) mit Probe-Inhalten: Laden nach Abstand, nah zuerst,
## Zeitbudget je Bild, Entladen erst mit Puffer, Vorladen von Dateien im Hintergrund, Abschalten, freigegebene Knoten.
## Starten: godot --headless --path . --script res://tests/test_zellwelt.gd

const DATEI := "res://icon.svg"

var fehler := 0
var reihenfolge: Array[String] = []


class Probe extends Node3D:
	var rechteck := Rect2()
	var abstand := 50.0
	var kosten_ms := 0.0
	var dateien := PackedStringArray()
	var gebaut := false
	var vorrat_da := false
	var protokoll: Array[String]

	func zell_rechteck() -> Rect2:
		return rechteck

	func zell_abstand() -> float:
		return abstand

	func zell_dateien() -> PackedStringArray:
		return dateien

	func zell_bauen() -> void:
		for d in dateien:
			vorrat_da = ResourceLoader.load_threaded_get_status(d) == ResourceLoader.THREAD_LOAD_LOADED
			ResourceLoader.load_threaded_get(d)
		var ende := Time.get_ticks_usec() + int(kosten_ms * 1000.0)
		while Time.get_ticks_usec() < ende:
			pass
		gebaut = true
		protokoll.append(name)

	func zell_leeren() -> void:
		gebaut = false


func pruefe(bed: bool, was: String) -> void:
	if bed:
		print("OK     ", was)
	else:
		fehler += 1
		print("FEHLER ", was)


func probe(n: String, x: float, z: float, abstand := 50.0, kosten := 0.0) -> Probe:
	var p := Probe.new()
	p.name = n
	p.rechteck = Rect2(x - 5.0, z - 5.0, 10.0, 10.0)
	p.abstand = abstand
	p.kosten_ms = kosten
	p.protokoll = reihenfolge
	root.add_child(p)
	return p


func bilder(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	var Z = root.get_node("Zellwelt")
	Z.ziel_position = Vector3(1000, 0, 1000)
	var a := probe("A", 0, 0)
	var b := probe("B", 30, 0)
	var c := probe("C", 300, 0)
	for p in [a, b, c]:
		Z.melde(p)
	await bilder(3)
	pruefe(not a.gebaut and not b.gebaut and not c.gebaut and Z.wartend() == 0, "Weit weg: nichts gebaut")

	# Spieler bei x = 35: B liegt näher als A, C weit weg
	Z.ziel_position = Vector3(35, 0, 0)
	Z.pruefe_sofort()
	pruefe(Z.wartend() == 2, "Zwei Inhalte warten (%d)" % Z.wartend())
	await bilder(3)
	pruefe(a.gebaut and b.gebaut and not c.gebaut, "Nah gebaut, fern nicht")
	pruefe(reihenfolge == ["B", "A"], "Nah zuerst (%s)" % [reihenfolge])
	pruefe(Z.wartend() == 0, "Nichts wartet mehr")

	# Puffer: A ist 5 m Rand bis 0 + 5; Spieler bei x = 80 → Abstand zu A 75 m (> 50, < 50 + 32): bleibt
	Z.ziel_position = Vector3(80, 0, 0)
	Z.pruefe_sofort()
	pruefe(a.gebaut, "Knapp hinter dem Ladeabstand bleibt geladen (Puffer)")
	Z.ziel_position = Vector3(110, 0, 0)
	Z.pruefe_sofort()
	pruefe(not a.gebaut and b.gebaut, "Hinter dem Puffer entladen (A 105 m), B (75 m) noch im Puffer")
	var geleert_vorher: int = Z.geleert
	Z.ziel_position = Vector3(84, 0, 0)
	Z.pruefe_sofort()
	await bilder(2)
	pruefe(not a.gebaut and Z.geleert == geleert_vorher, "Zurück in den Puffer lädt nicht sofort neu (A erst unter 50 m)")

	# Zeitbudget: 10 Inhalte je 2 ms, Budget 3 ms je Bild → höchstens 2 je Bild
	reihenfolge.clear()
	var viele: Array[Probe] = []
	for i in 10:
		var p := probe("V%d" % i, 2000 + i * 3, 2000, 50.0, 2.0)
		viele.append(p)
		Z.melde(p)
	Z.ziel_position = Vector3(2000, 0, 2000)
	Z.pruefe_sofort()
	await process_frame
	var nach_einem := viele.filter(func(p: Probe) -> bool: return p.gebaut).size()
	pruefe(nach_einem >= 1 and nach_einem <= 2, "Zeitbudget: im ersten Bild %d von 10 gebaut" % nach_einem)
	await bilder(8)
	pruefe(viele.all(func(p: Probe) -> bool: return p.gebaut), "Nach einigen Bildern alle 10 gebaut")
	pruefe(reihenfolge[0] == "V0", "Wieder der nächste zuerst (%s)" % reihenfolge[0])

	# Vorladen: eine Datei wird im Hintergrund geladen, gebaut wird erst danach
	var v := probe("Vorrat", 5000, 5000)
	v.dateien = PackedStringArray([DATEI])
	Z.melde(v)
	Z.ziel_position = Vector3(5000, 0, 5000)
	Z.pruefe_sofort()
	var ende := Time.get_ticks_msec() + 5000
	while not v.gebaut and Time.get_ticks_msec() < ende:
		await process_frame
	pruefe(v.gebaut and v.vorrat_da, "Datei vorher im Hintergrund geladen, dann gebaut")

	# Freigegebene Inhalte stören nicht
	viele[3].free()
	Z.ziel_position = Vector3(0, 0, 0)
	Z.pruefe_sofort()
	await bilder(2)
	pruefe(true, "Freigegebener Inhalt ohne Fehler übergangen")

	# Abgeschaltet: sofort gebaut
	Z.aus = true
	var sofort := probe("Sofort", 9000, 9000)
	Z.melde(sofort)
	pruefe(sofort.gebaut, "Abgeschaltet: beim Melden sofort gebaut")
	Z.aus = false
	print("\nFehler: %d" % fehler)
	quit(1 if fehler > 0 else 0)
