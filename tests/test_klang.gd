extends SceneTree
## Geräusche (autoload/klang.gd, klaenge/): Dateien da und ladbar, Schleifen laufen endlos, Varianten werden gefunden,
## der Untergrund wird erkannt, Schritte, Tore und die Schmiede lösen Geräusche aus, ohne Fehler auch ohne Tonausgabe.

var fehler := 0

func pruefe(ok: bool, text: String) -> void:
	print(("OK     " if ok else "FEHLER ") + text)
	if not ok:
		fehler += 1

func _initialize() -> void:
	await process_frame
	var klang := root.get_node_or_null("Klang")
	pruefe(klang != null, "Autoload Klang ist da")
	if klang == null:
		quit(1)
		return
	var noetig := ["wind_sanft", "wind_stark", "feuer", "brandung", "amboss_1", "glocke_gross", "glocke_klein", "schuss",
		"schritt_stein_1", "schritt_gras_1", "schritt_erde_1", "schritt_holz_1", "tuer_auf_1", "tuer_zu_1", "tor_auf_1",
		"tor_zu", "riegel", "vogel_amsel_1", "schwung_1", "metall_1", "metall_klingt", "schwert_ziehen_1", "leder"]
	var fehlen := noetig.filter(func(n: String) -> bool: return klang.stream(n) == null)
	pruefe(fehlen.is_empty(), "Alle %d Geräusche laden (fehlen: %s)" % [noetig.size(), fehlen])
	var schleifen := ["wind_sanft", "wind_stark", "feuer", "brandung"].filter(func(n: String) -> bool:
		var s = klang.stream(n)
		return s is AudioStreamOggVorbis and s.loop)
	pruefe(schleifen.size() == 4, "Wind, Feuer und Brandung laufen als Schleife")
	pruefe(klang.varianten("schritt_stein") >= 8 and klang.varianten("vogel_amsel") == 2 and klang.varianten("tor_zu") == 0,
		"Varianten: %d Steinschritte, %d Amselrufe" % [klang.varianten("schritt_stein"), klang.varianten("vogel_amsel")])
	# Untergrund: ohne Region Gras, auf einem Bau Stein, auf einem Steg Holz
	var bau := StaticBody3D.new()
	bau.name = "Mauer"
	var steg := StaticBody3D.new()
	steg.name = "StegBoden1"
	root.add_child(bau)
	root.add_child(steg)
	pruefe(klang.untergrund(bau, Vector3.ZERO) == "stein" and klang.untergrund(steg, Vector3.ZERO) == "holz"
		and klang.untergrund(null, Vector3.ZERO) == "gras", "Untergrund: Bau Stein, Steg Holz, ohne Körper Gras")
	# Geräusche abspielen (ohne Tonausgabe: nur ohne Fehler)
	var kamera := Camera3D.new()
	root.add_child(kamera)
	kamera.make_current()
	klang.spiele("tuer_auf", Vector3(1, 0, 1))
	klang.schritt(Vector3.ZERO, "stein")
	var feuer: AudioStreamPlayer3D = klang.dauerklang(kamera, "feuer")
	pruefe(feuer != null and feuer.stream != null, "Dauerklang Feuer hängt am Ding")
	for i in 30:
		await process_frame
	var spielt := 0
	for p in klang.get_children():
		if p is AudioStreamPlayer3D and p.playing:
			spielt += 1
	pruefe(spielt >= 1, "Geräusche im Pool spielen (%d)" % spielt)
	# Schmiede: eine Marke in der Gruppe klang_amboss, tagsüber hämmert es
	var amboss := Node3D.new()
	amboss.add_to_group("klang_amboss")
	root.add_child(amboss)
	root.get_node("Spielzeit").minuten = 10.0 * 60.0
	var vorher: int = klang._naechster
	for i in 120:
		await process_frame
	pruefe(klang._naechster != vorher, "Am Amboss wird tagsüber gehämmert")
	# Volle Stunde: Glocken schlagen die Stunde (ohne Region: keine Glocke, kein Fehler)
	klang._glocken = [[Vector3(0, 10, 0), true]]
	klang._minute(15 * 60)
	pruefe(klang._glocken_noch == 3, "Um 15 Uhr schlägt die Glocke dreimal")
	# Lautstärke im Menü: fünf Stufen bis „aus“, dann wieder voll
	var texte := []
	for i in 5:
		klang.naechste_lautstaerke()
		texte.append(klang.lautstaerke_text())
	pruefe(texte == ["75 %", "50 %", "25 %", "aus", "100 %"] and not AudioServer.is_bus_mute(0),
		"Ton im Menü: %s" % ", ".join(texte))
	print("Fehler: %d" % fehler)
	quit(1 if fehler > 0 else 0)
