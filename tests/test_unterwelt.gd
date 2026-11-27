extends SceneTree
## Untergrund von Drachenstein (szenen/welt/unterwelt.gd, werkzeuge/bau/teil_unterwelt.py): Räume und Gänge sind
## gebaut und begehbar (Boden unter jedem Gang, Decke darüber, frei für eine Person, Treppen nicht zu steil), die
## Abgänge schneiden das Gelände aus, die Geheimtür in der Krypta findet man erst nach dem Hinweis, die Riegeltür zum
## Hafen geht nur von der Burgseite auf, die Archivtür nur mit dem Schlüssel, unter Tage wird erkannt, die Inschriften
## und Fundstücke haben ihre Dialoge.

var fehler := 0


func pruefe(ok: bool, text: String) -> void:
	print(("OK     " if ok else "FEHLER ") + text)
	if not ok:
		fehler += 1


func _initialize() -> void:
	root.get_node("Ladevorhang").aus = true
	var speicher := root.get_node("Speicher")
	speicher.ordner = "user://speicher_test_unterwelt/"
	speicher.region = "drachenstein"
	var stand := root.get_node("Spielstand")
	stand.zuruecksetzen("Prüfling")
	root.get_node("Spielzeit").process_mode = Node.PROCESS_MODE_DISABLED
	var szene: Node = (load(speicher.REGIONEN["drachenstein"]) as PackedScene).instantiate()
	root.add_child(szene)
	current_scene = szene
	for i in 12:
		await physics_frame
	var uw := szene.get_node_or_null("Unterwelt")
	var dinge := szene.get_node_or_null("UnterweltDinge")
	pruefe(uw != null, "Knoten Unterwelt ist da")
	if uw == null:
		quit(1)
		return
	var meshes := uw.find_children("*", "MeshInstance3D", true, false)
	var dreiecke := 0
	for m: MeshInstance3D in meshes:
		if m.mesh != null:
			for s in m.mesh.get_surface_count():
				dreiecke += m.mesh.surface_get_array_len(s) / 3
	pruefe(dreiecke > 20000, "Untergrund gebaut (%d Dreiecke)" % dreiecke)
	var raeume: int = uw.gewoelbe.size() / 11
	var gaenge: int = uw.gaenge.size() / 10
	pruefe(raeume >= 10 and gaenge >= 14, "%d Räume, %d Gänge" % [raeume, gaenge])
	var lichter := uw.find_children("*", "OmniLight3D", true, false).size()
	var sonden := uw.find_children("*", "ReflectionProbe", true, false).size()
	pruefe(lichter >= 20 and sonden >= raeume, "Licht unter Tage: %d Lichter, %d Sonden (Innenraum)" % [lichter, sonden])

	var raum := (szene as Node3D).get_world_3d().direct_space_state
	var tueren: Array[RID] = []
	for t in dinge.find_children("*", "StaticBody3D", true, false):
		if t.get_script() != null and String(t.get_script().resource_path).ends_with("geheimtuer.gd"):
			tueren.append((t as StaticBody3D).get_rid())
	for f in uw.find_children("*", "", true, false) + dinge.find_children("*", "", true, false):
		if f is Fluegel:
			for k in f.find_children("*", "StaticBody3D", true, false):
				tueren.append((k as StaticBody3D).get_rid())
	# Ausstattung (Schutt im verschütteten Gang, Sarkophage) zählt für die Wege nicht
	for k in dinge.find_children("*", "StaticBody3D", true, false):
		if k.get_parent() != null and String(k.get_parent().name).begins_with("UnterweltAusstattung"):
			tueren.append((k as StaticBody3D).get_rid())
	for k in dinge.find_children("UnterweltAusstattung", "", true, false):
		for b in k.find_children("*", "StaticBody3D", true, false):
			tueren.append((b as StaticBody3D).get_rid())
	# Jeder Gang: Boden unter der Mitte (nahe der erwarteten Höhe), Decke darüber, Platz für eine Person
	var kapsel := CapsuleShape3D.new()
	kapsel.radius = 0.3
	kapsel.height = 1.7
	var form := PhysicsShapeQueryParameters3D.new()
	form.shape = kapsel
	form.exclude = tueren
	var ohne_boden: Array[String] = []
	var ohne_decke: Array[String] = []
	var eng: Array[String] = []
	var steil: Array[String] = []
	var g := uw.gaenge as PackedFloat32Array
	var i := 0
	while i + 9 < g.size():
		var a := Vector3(g[i], g[i + 1], g[i + 2])
		var b := Vector3(g[i + 3], g[i + 4], g[i + 5])
		var lang := Vector2(b.x - a.x, b.z - a.z).length()
		var stufen_lauf := maxf(lang - 2.0 * minf(1.1, lang * 0.2), 0.1)
		if absf(b.y - a.y) / stufen_lauf > 0.75:
			steil.append("Gang %d" % (i / 10))
		var quer := Vector3(b.z - a.z, 0, a.x - b.x).normalized() * 0.12
		for t: float in [0.15, 0.5, 0.85]:
			var p := a.lerp(b, t) + quer
			var oben := p + Vector3.UP * 1.5
			var r := raum.intersect_ray(PhysicsRayQueryParameters3D.create(oben, oben + Vector3.DOWN * 3.5, 0xFFFFFFFF, tueren))
			if r.is_empty() or absf((r["position"] as Vector3).y - p.y) > 1.0:
				ohne_boden.append("Gang %d bei %.2f (%s)" % [i / 10, t, "nichts" if r.is_empty() else "%.1f statt %.1f, %s" % [(r["position"] as Vector3).y, p.y, (r["collider"] as Node).name]])
				continue
			var y: float = (r["position"] as Vector3).y
			var d := raum.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, y + 0.3, p.z), Vector3(p.x, y + 6.0, p.z), 0xFFFFFFFF, tueren))
			if d.is_empty() or (d["position"] as Vector3).y - y > g[i + 7] + 0.6:
				ohne_decke.append("Gang %d bei %.2f (%s)" % [i / 10, t, "nichts" if d.is_empty() else "%.1f über dem Boden" % ((d["position"] as Vector3).y - y)])
			form.transform = Transform3D(Basis(), Vector3(p.x, y + 0.3 + 0.85 + 0.05, p.z))
			if not raum.intersect_shape(form, 1).is_empty():
				eng.append("Gang %d bei %.2f (%s, %s)" % [i / 10, t, (instance_from_id(raum.intersect_shape(form, 1)[0]["collider_id"]) as Node).get_path(), form.transform.origin.snapped(Vector3.ONE * 0.1)])
		i += 10
	pruefe(ohne_boden.is_empty(), "Unter jedem Gang ein Boden auf der richtigen Höhe %s" % [ohne_boden])
	pruefe(ohne_decke.is_empty(), "Über jedem Gang eine Decke %s" % [ohne_decke])
	pruefe(eng.is_empty(), "In jedem Gang Platz für eine Person %s" % [eng])
	pruefe(steil.is_empty(), "Keine Treppe steiler als 37° %s" % [steil])
	# Jeder Raum: Boden in der Mitte (bei Zisterne auf dem Steg), Platz zum Stehen
	var leer: Array[String] = []
	var w := uw.gewoelbe as PackedFloat32Array
	i = 0
	while i + 10 < w.size():
		var c := Vector3(w[i], w[i + 5], w[i + 1])
		var art := int(w[i + 8])
		if art == 2:
			var gg := deg_to_rad(w[i + 2])
			c += Vector3(sin(gg), 0, cos(gg)) * (-w[i + 3] / 2.0 + 0.8)
		if art == 5:
			i += 11
			continue
		if art in [0, 2, 3]:
			c += Vector3(0.9, 0, 0.7)
		var r := raum.intersect_ray(PhysicsRayQueryParameters3D.create(c + Vector3.UP * 1.5, c + Vector3.DOWN * 2.0, 0xFFFFFFFF, tueren))
		if r.is_empty() or absf((r["position"] as Vector3).y - c.y) > 0.3:
			leer.append("Raum %d" % (i / 11))
		i += 11
	pruefe(leer.is_empty(), "Jeder Raum hat seinen Boden %s" % [leer])

	# Abgänge: im Häuschen trifft ein Strahl die Treppe, nicht das Gelände
	var ab := uw.abgaenge as PackedFloat32Array
	i = 0
	var gelaende_im_weg := 0
	while i + 6 < ab.size():
		var gg := deg_to_rad(ab[i + 2])
		var p := Vector3(ab[i], ab[i + 3], ab[i + 1]) + Vector3(sin(gg), 0, cos(gg)) * 4.5
		var r := raum.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.5, p + Vector3.DOWN * 6.0, 0xFFFFFFFF, tueren))
		if r.is_empty() or "Gelaende" in str((r["collider"] as Node).get_path()) or (r["position"] as Vector3).y > ab[i + 3] - 1.0:
			gelaende_im_weg += 1
			print("  Abgang %d: %s" % [i / 7, "nichts" if r.is_empty() else "%s bei %.2f" % [(r["collider"] as Node).get_path(), (r["position"] as Vector3).y]])
		i += 7
	pruefe(gelaende_im_weg == 0 and ab.size() >= 14, "Die Treppen in den Abgängen sind frei (das Gelände ist ausgeschnitten)")
	var gel := szene.get_node("Gelaende")
	var neben := Vector3(ab[0], ab[3], ab[1]) + Vector3(sin(deg_to_rad(ab[2])), 0, cos(deg_to_rad(ab[2]))) * -3.0
	var r_neben := raum.intersect_ray(PhysicsRayQueryParameters3D.create(neben + Vector3.UP * 3.0, neben + Vector3.DOWN * 3.0))
	print("  vor dem Gruftabgang: ", "nichts" if r_neben.is_empty() else "%s bei %.2f, Gelände %.2f" % [(r_neben["collider"] as Node).get_path(), (r_neben["position"] as Vector3).y, gel.hoehe_bei(neben.x, neben.z)])
	pruefe(not r_neben.is_empty() and absf((r_neben["position"] as Vector3).y - gel.hoehe_bei(neben.x, neben.z)) < 0.6,
		"Vor dem Gruftabgang ist der Boden noch da")

	# Höhlenmund an der Klippe: von innen frei aufs Meer, Boden im Gang, über der Öffnung und daneben Fels
	var fm := uw.felsmuender as PackedFloat32Array
	pruefe(fm.size() >= 8, "Ein Felsmund (Meereshöhle der Schmuggler)")
	if fm.size() >= 8:
		var mg := deg_to_rad(fm[2])
		var mo := Vector3(sin(mg), 0, cos(mg))
		var innen := Vector3(fm[0], fm[3] + 1.6, fm[1]) - mo * 4.0
		var blick := raum.intersect_ray(PhysicsRayQueryParameters3D.create(innen, innen + mo * 12.0, 0xFFFFFFFF, tueren))
		pruefe(blick.is_empty(), "Aus der Höhle frei hinaus aufs Meer %s" % ("" if blick.is_empty() else str((blick["collider"] as Node).get_path())))
		var bo := raum.intersect_ray(PhysicsRayQueryParameters3D.create(innen, innen + Vector3.DOWN * 3.0, 0xFFFFFFFF, tueren))
		pruefe(not bo.is_empty() and absf((bo["position"] as Vector3).y - fm[3]) < 0.4, "Boden im Gang hinter dem Mund")
		var quer := Vector3(-mo.z, 0, mo.x)
		var aussen_p := Vector3(fm[0], fm[3] + 2.0, fm[1]) + mo * 4.0
		var dicht := 0
		for ziel: Vector3 in [aussen_p - mo * 5.0 + quer * (fm[4] / 2.0 + 1.5), aussen_p - mo * 5.0 - quer * (fm[4] / 2.0 + 1.5),
				aussen_p - mo * 6.75 + Vector3.UP * (fm[5] + 0.6)]:
			if not raum.intersect_ray(PhysicsRayQueryParameters3D.create(aussen_p, ziel)).is_empty():
				dicht += 1
			else:
				print("  Klippe offen: von %s nach %s" % [aussen_p.snapped(Vector3.ONE * 0.1), ziel.snapped(Vector3.ONE * 0.1)])
		pruefe(dicht == 3, "Neben und über der Öffnung ist die Klippe geschlossen (%d von 3)" % dicht)
	pruefe(dinge.get_node_or_null("Schmuggler1") != null and dinge.get_node_or_null("Schmuggler2") != null, "Zwei Schmuggler im Lager")
	var wk := dinge.get_node_or_null("TuerWarenkammer") as Fluegel
	pruefe(wk != null and wk.regel == "schloss" and wk.bedingung == "schluessel_schmuggler", "Warenkammer verschlossen (Schlüssel aus dem Lager)")

	# Stadtkeller: das Kellerhäuschen ist verschlossen (Schlüssel aus der Warenkammer), die Geheimtür erst nach dem Hehlerbuch
	pruefe((uw.abgang_regeln as PackedStringArray).has("schloss:schluessel_hehlerkeller"), "Kellerhäuschen am Vorburgplatz verschlossen")
	var hg := dinge.get_node_or_null("GeheimtuerHehlerkeller")
	pruefe(hg != null and not hg.is_in_group("interagierbar"), "Gang hinter dem Regal: erst nach dem Hehlerbuch zu finden")
	if hg != null:
		stand.setze_flag("hehlerbuch_gelesen")
		await process_frame
		pruefe(hg.is_in_group("interagierbar"), "Nach dem Hehlerbuch fällt das Regal auf")
	var brunnenschacht := 0
	var sch := uw.schaechte as PackedFloat32Array
	for k in range(0, sch.size() - 4, 5):
		var oben_s := Vector3(sch[k], sch[k + 3] - 1.0, sch[k + 1])
		if raum.intersect_ray(PhysicsRayQueryParameters3D.create(oben_s, oben_s + Vector3.UP * (sch[k + 4] - sch[k + 3] + 0.5))).is_empty() == false:
			brunnenschacht += 1
	pruefe(sch.size() >= 10, "Zwei Brunnenschächte (Zisterne, Vorburg)")

	# unter Tage
	var krypta := Vector3(w[0], w[5] + 1.5, w[1])
	pruefe(uw.ist_unter_tage(krypta) and not uw.ist_unter_tage(Vector3(w[0], 20.0, w[1] + 30.0)), "Unter Tage wird erkannt (Krypta ja, Hof nein)")

	# Geheimtür: erst nach dem Hinweis auffindbar, dann geht sie auf und gibt den Weg frei
	var gt := dinge.get_node_or_null("GeheimtuerKrypta")
	pruefe(gt != null and not gt.is_in_group("interagierbar"), "Geheimtür in der Krypta: ohne Hinweis unauffällig")
	if gt != null:
		stand.setze_flag("hinweis_sorrow")
		await process_frame
		pruefe(gt.is_in_group("interagierbar"), "Nach dem Hinweis fällt die Fuge auf")
		gt.interagieren(null)
		await create_timer(3.5).timeout
		pruefe(gt.ist_offen() and stand.hat_flag("geheimgang_krypta"), "Die Geheimtür gleitet auf und bleibt offen (Flag)")
	# Riegeltür zum Hafen: von der Hafenseite nicht, von der Burgseite ja
	var rt := dinge.get_node_or_null("RiegeltuerHafen") as Fluegel
	pruefe(rt != null and rt.regel == "riegel", "Riegeltür im Hafenstollen")
	if rt != null:
		var aussen := Node3D.new()
		szene.add_child(aussen)
		aussen.global_position = rt.global_position - rt.global_basis.z * 1.5
		rt.interagieren(aussen)
		pruefe(not stand.hat_flag("riegel_hafenstollen"), "Von der Hafenseite bleibt sie verriegelt")
		aussen.global_position = rt.global_position + rt.global_basis.z * 1.5
		rt.interagieren(aussen)
		pruefe(stand.hat_flag("riegel_hafenstollen"), "Von der Burgseite lässt sich der Riegel zurückschieben")
	var at := dinge.get_node_or_null("ArchivTuer") as Fluegel
	pruefe(at != null and at.regel == "schloss" and not at._spieler_darf(), "Archivtür: verschlossen ohne Schlüssel")
	if at != null:
		stand.setze_flag("schluessel_sorrow_archiv")
		pruefe(at._spieler_darf(), "Mit dem Schlüssel geht sie auf")

	# Dialoge der Inschriften und Fundstücke
	var fehlende: Array[String] = []
	for k in dinge.find_children("*", "StaticBody3D", true, false):
		var dlg: Variant = k.get("dialog_id")
		if dlg is String and dlg != "":
			var pfad := "res://daten/dialoge/%s.json" % dlg
			if not FileAccess.file_exists(pfad) or JSON.parse_string(FileAccess.get_file_as_string(pfad)) == null:
				fehlende.append(dlg)
	pruefe(fehlende.is_empty(), "Alle Inschriften und Fundstücke haben einen gültigen Dialog %s" % [fehlende])
	var ausst := dinge.get_node_or_null("UnterweltAusstattung")
	pruefe(ausst != null and (ausst.stuecke as PackedFloat32Array).size() >= 5 * 30, "Ausstattung im Untergrund (Sarkophage, Gebeine, Kerzen, Schutt)")
	print("ERGEBNIS: %d Fehler" % fehler)
	quit(1 if fehler > 0 else 0)
