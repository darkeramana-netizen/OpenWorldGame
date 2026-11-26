extends SceneTree
## Wahrnehmung der Leute (person.gd): Gruß, wenn der Spieler nahe kommt; Bürger weichen vor gezogener Waffe zurück,
## Wachen ziehen selbst; Umschauen ohne Fehler.

var fehler := 0

func pruefe(ok: bool, text: String) -> void:
	print(("OK     " if ok else "FEHLER ") + text)
	if not ok:
		fehler += 1

func _initialize() -> void:
	await process_frame
	var welt := Node3D.new()
	root.add_child(welt)
	var boden := StaticBody3D.new()
	var form := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	form.shape = box
	form.position.y = -0.5
	boden.add_child(form)
	welt.add_child(boden)
	var spieler := Node3D.new()
	spieler.add_to_group("spieler")
	var skript := GDScript.new()
	skript.source_code = "extends Node\nvar gezogen := false\n"
	skript.reload()
	var kampf := Node.new()
	kampf.set_script(skript)
	kampf.name = "Kampf"
	spieler.add_child(kampf)
	welt.add_child(spieler)
	spieler.global_position = Vector3(30, 0, 0)
	var szene: PackedScene = load("res://szenen/figuren/person.tscn")
	var buerger: Node3D = szene.instantiate()
	buerger.anzeige_name = "Bürgerin Hanne Probe"
	welt.add_child(buerger)
	var wache: Node3D = szene.instantiate()
	wache.anzeige_name = "Wache Ulf Probe"
	welt.add_child(wache)
	wache.global_position = Vector3(0, 0, 4)
	var kamera := Camera3D.new()
	welt.add_child(kamera)
	kamera.global_position = Vector3(0, 2, 10)
	for i in 10:
		await process_frame
	# Gruß
	spieler.global_position = Vector3(0, 0, -2.0)
	var gegruesst := false
	for i in 40:
		await process_frame
		if buerger._zuruf != null and buerger._zuruf.visible:
			gegruesst = true
	# höchstens 75 % grüßen laut; dann ist _gegruesst_bis gesetzt
	pruefe(gegruesst or buerger._gegruesst_bis > 0.0, "Wer dem Spieler nahe kommt, grüßt (%s)" % (buerger._zuruf.text if buerger._zuruf else "still"))
	# Waffe gezogen
	var vorher := buerger.global_position
	kampf.gezogen = true
	for i in 120:
		await physics_frame
	pruefe(buerger._zuruf != null and buerger._zuruf.visible, "Bei gezogener Waffe ruft die Bürgerin: %s" % (buerger._zuruf.text if buerger._zuruf else "-"))
	pruefe(buerger.global_position.distance_to(vorher) > 1.0 and buerger.global_position.distance_to(spieler.global_position) > vorher.distance_to(spieler.global_position),
		"Sie weicht zurück (%.1f m)" % buerger.global_position.distance_to(vorher))
	pruefe(wache.get_node("Figur").haltung == "schwert", "Die Wache zieht selbst")
	kampf.gezogen = false
	var bis := Time.get_ticks_msec() + 12000      # unter Last (parallele Tests) laufen weniger Bilder
	while wache.get_node("Figur").haltung == "schwert" and Time.get_ticks_msec() < bis:
		await process_frame
	pruefe(wache.get_node("Figur").haltung != "schwert", "Waffe weg: die Wache steckt wieder ein")
	# Werkzeug bei der Arbeit
	var holz: Node3D = szene.instantiate()
	holz.anzeige_name = "Knecht Hinnerk Scheit"
	holz.haltung = "arbeiten"
	welt.add_child(holz)
	holz.global_position = Vector3(10, 0, 0)
	var bis2 := Time.get_ticks_msec() + 20000
	while not holz.get_node("Figur").hat_modell() and Time.get_ticks_msec() < bis2:
		await process_frame
	for i in 5:
		await process_frame
	pruefe(holz.get_node("Figur").werkzeug() == "axt" and holz.find_child("Handding", true, false) != null,
		"Der Holzhacker hält bei der Arbeit seine Axt")
	# Gespräch mit Inhalt: zwei, die nebeneinander stehen, reden; über ihnen erscheinen Zeilen
	var a: Node3D = szene.instantiate()
	a.anzeige_name = "Magd Probe Eins"
	var b: Node3D = szene.instantiate()
	b.anzeige_name = "Knecht Probe Zwei"
	welt.add_child(a)
	welt.add_child(b)
	a.global_position = Vector3(-10, 0, 0)
	b.global_position = Vector3(-10, 0, 1.6)
	spieler.global_position = Vector3(-10, 0, 6)
	var zeilen := {}
	bis2 = Time.get_ticks_msec() + 25000
	while zeilen.size() < 2 and Time.get_ticks_msec() < bis2:
		await process_frame
		for p in [a, b]:
			if p._zuruf != null and p._zuruf.visible and not p._zuruf.text.begins_with("„Gott") and not p._zuruf.text.begins_with("„Gute") \
					and not p._zuruf.text.begins_with("„Grüß"):
				zeilen[p._zuruf.text] = true
	pruefe(zeilen.size() >= 2, "Zwei unterhalten sich hörbar: %s" % " / ".join(zeilen.keys()))
	# Lärm: ein Schuss in 20 m; die Bürgerin läuft fort, die Wache eilt hin
	var buerger2: Node3D = szene.instantiate()
	buerger2.anzeige_name = "Bürgerin Grete Probe"
	welt.add_child(buerger2)
	buerger2.global_position = Vector3(30, 0, 30)
	var wache2: Node3D = szene.instantiate()
	wache2.anzeige_name = "Wache Probe Drei"
	welt.add_child(wache2)
	wache2.global_position = Vector3(30, 0, 34)
	for i in 10:
		await physics_frame
	var schuss := Vector3(30, 0, 10)
	var b_vor := buerger2.global_position.distance_to(schuss)
	var w_vor := wache2.global_position.distance_to(schuss)
	call_group("personen", "hoere_laerm", schuss, "schuss")
	await create_timer(3.0).timeout
	pruefe(buerger2.global_position.distance_to(schuss) > b_vor + 3.0, "Nach dem Schuss läuft die Bürgerin fort (%.1f → %.1f m)" % [b_vor, buerger2.global_position.distance_to(schuss)])
	pruefe(wache2.global_position.distance_to(schuss) < w_vor - 3.0 and wache2.get_node("Figur").haltung == "schwert",
		"Die Wache zieht und eilt hin (%.1f → %.1f m)" % [w_vor, wache2.global_position.distance_to(schuss)])
	print("Fehler: %d" % fehler)
	quit(1 if fehler > 0 else 0)
