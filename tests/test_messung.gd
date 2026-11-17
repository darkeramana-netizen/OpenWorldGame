extends SceneTree
## Rauchtest für das Messwerkzeug (werkzeuge/messen/messung.gd): startet es als eigenen Prozess mit der kurzen
## Strecke und der GPU-Aufschlüsselung (wenige Bilder) und prüft, dass die Ergebnisdatei alle Teile mit plausiblen
## Werten enthält.
## Starten: godot --headless --path . --script res://tests/test_messung.gd

var fehler := 0


func pruefe(bed: bool, was: String) -> void:
	if bed:
		print("OK     ", was)
	else:
		fehler += 1
		print("FEHLER ", was)


func _initialize() -> void:
	var ordner := OS.get_user_data_dir().path_join("messung_test")
	DirAccess.make_dir_recursive_absolute(ordner)
	for f in DirAccess.get_files_at(ordner):
		DirAccess.remove_absolute(ordner.path_join(f))
	var ausgabe: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://werkzeuge/messen/messung.gd", "--", "--strecke", "kurz", "--name", "test", "--ausgabe", ordner,
		"--aufschluesselung", "ja", "--bilder", "5"],
		ausgabe, true)
	pruefe(code == 0, "Messwerkzeug läuft durch (Rückgabe %d)" % code)
	var json := ""
	for f in DirAccess.get_files_at(ordner):
		if f.ends_with(".json"):
			json = ordner.path_join(f)
	pruefe(json != "" and FileAccess.file_exists(json.get_basename() + ".txt"), "Ergebnis als .json und .txt geschrieben")
	if json == "":
		print("\n".join(ausgabe))
		print("\nFehler: %d" % fehler)
		quit(1)
		return
	var e: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(json))
	var laden: Dictionary = e.get("laden", {})
	pruefe(float(laden.get("einhaengen_und_ready_ms", 0.0)) > 0.0 and float(laden.get("datei_ms", 0.0)) > 0.0,
		"Ladezeiten gemessen (Datei %.0f ms, _ready %.0f ms)" % [laden.get("datei_ms", 0.0), laden.get("einhaengen_und_ready_ms", 0.0)])
	var bauarten: Array = (e.get("ready_je_bauart", []) as Array).map(func(r: Dictionary) -> String: return r["bauart"])
	pruefe("burgbau" in bauarten and "gelaende" in bauarten, "Ladezeit je Bauart (burgbau, gelaende, ...)")
	var g: Dictionary = (e.get("szene", {}) as Dictionary).get("gesamt", {})
	pruefe(int(g.get("knoten", 0)) > 1000 and int(g.get("dreiecke", 0)) > 100000 and int(g.get("lichter", 0)) > 0,
		"Szene ausgezählt (%d Knoten, %d Dreiecke, %d Lichter)" % [g.get("knoten", 0), g.get("dreiecke", 0), g.get("lichter", 0)])
	var fa: Dictionary = e.get("fahrt", {})
	pruefe(int(fa.get("erreicht", 0)) == 3 and String(fa.get("abbruch", "x")) == "", "Kurze Messfahrt: 3 von 3 Wegpunkten")
	var mf: Dictionary = e.get("messfahrt", {})
	var ft: Dictionary = mf.get("frame_ms", {})
	pruefe(int(mf.get("bilder", 0)) > 30 and float(ft.get("p95", 0.0)) > 0.0 and mf.has("haenger_ueber_50ms"),
		"Frame-Werte der Fahrt (%d Bilder, p95 %.1f ms)" % [mf.get("bilder", 0), ft.get("p95", 0.0)])
	pruefe(int(((e.get("lod", {}) as Dictionary).get("knoten_mit_sichtweite", 0))) > 0, "Sichtweiten-Knoten gezählt")
	var eb: Array = e.get("anlauf_erste_bilder", [])
	pruefe(eb.size() == 12 and (eb[0] as Dictionary).has("neue_pipelines") and (eb[3] as Dictionary).has("zeichnen_ms") and float((eb[0] as Dictionary).get("frame_ms", 0.0)) > 0.0,
		"Erste 12 Bilder nach dem Laden einzeln (Dauer, Pipelines)")
	var vh: Dictionary = e.get("vorhang", {})
	pruefe(int(vh.get("faellt_nach_bildern", -1)) >= 5 and float(vh.get("spielbar_ms", 0.0)) > float(laden.get("einhaengen_und_ready_ms", 0.0)),
		"Ladebildschirm: wann er fiele und das größte Bild danach (%s)" % str(vh))
	var au: Dictionary = e.get("aufschluesselung", {})
	var markt: Array = au.get("Markt", [])
	var namen: Array = markt.map(func(z: Dictionary) -> String: return z["variante"])
	pruefe(au.size() == 3 and au.has("_info") and "SDFGI_Zelle_doppelt" in namen and "Schatten_bis_150m" in namen and "Ueberblendung_aus" in namen and "Schattenhuelle_aus" in namen and "alles" in namen and "SDFGI_aus" in namen and "Sonnenschatten_aus" in namen and "Figuren_aus" in namen
			and "Bewuchs_aus" in namen and "alles_am_ende" in namen,
		"GPU-Aufschlüsselung an %d Blickpunkten mit %d Varianten" % [au.size(), namen.size()])
	print("\nFehler: %d" % fehler)
	quit(1 if fehler > 0 else 0)
