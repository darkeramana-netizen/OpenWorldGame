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
	await create_timer(4.5).timeout
	pruefe(wache.get_node("Figur").haltung == "", "Waffe weg: die Wache steckt wieder ein")
	print("Fehler: %d" % fehler)
	quit(1 if fehler > 0 else 0)
