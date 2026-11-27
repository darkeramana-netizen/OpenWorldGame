extends SceneTree
## Tests für den Baucache (szenen/welt/baucache.gd): Ein Bau aus dem Zwischenspeicher muss genau dem frisch gebauten
## gleichen (Knoten, Lagen, Meshes, Materialien, Kollision, Lichter, Torflügel, Tiere), der Schlüssel muss sich mit den
## Daten ändern, und Felsen, die beim Start auf den Boden gesetzt werden, müssen dabei an derselben Stelle landen.
## Starten: godot --headless --path . --script res://tests/test_baucache.gd

const Baucache := preload("res://szenen/welt/baucache.gd")
const REGION := "res://szenen/welt/region_drachenstein.tscn"

var fehler := 0


func pruefe(bed: bool, was: String) -> void:
	if bed:
		print("OK     ", was)
	else:
		fehler += 1
		print("FEHLER ", was)


func _initialize() -> void:
	Baucache.ordner = "user://baucache_test/"
	root.get_node("Zellwelt").aus = true    # alle Zellen sofort bauen, damit der Vergleich alles sieht
	DirAccess.make_dir_recursive_absolute(Baucache.ordner)
	for f in DirAccess.get_files_at(Baucache.ordner):
		DirAccess.remove_absolute(Baucache.ordner.path_join(f))

	# 1. frisch gebaut (und gespeichert)
	var t0 := Time.get_ticks_msec()
	var r1 := await _lade()
	var t_bau := Time.get_ticks_msec() - t0
	var bild_bau := _bild(r1)
	var b1: Array = await _baeume(r1)
	var gebaut := Baucache.gebaut
	pruefe(gebaut >= 60 and Baucache.treffer == 0, "Erster Start: %d Bauten gebaut und gespeichert, keiner geladen" % gebaut)
	var res := 0
	var tmp := 0
	for f in DirAccess.get_files_at(Baucache.ordner):
		if f.contains(".tmp."):
			tmp += 1
		elif f.ends_with(".res") and not f.contains(".Zelle_"):   # Zellen haben eigene Dateien daneben
			res += 1
	pruefe(res == gebaut, "Je Bau eine Datei (%d)" % res)
	pruefe(tmp == 0, "Keine halb geschriebenen Dateien übrig")
	var bau: Node = r1.get_node("Drachenstein/Burgen/HofhausEinrichtung")
	var schl_vorher := Baucache.schluessel(bau)
	r1.free()

	# 2. aus dem Zwischenspeicher
	t0 = Time.get_ticks_msec()
	var r2 := await _lade()
	var t_cache := Time.get_ticks_msec() - t0
	var bild_cache := _bild(r2)
	var b2: Array = await _baeume(r2)
	pruefe(not b1[2] and b2[2] and b1[0] == b2[0] and b1[1] == b2[1] and b1[1].size() > 500,
		"Bäume beim zweiten Start aus dem Baucache, an denselben Stellen (%s, %d Stämme)" % [str(b2[0]), b1[1].size()])
	pruefe(Baucache.treffer == gebaut and Baucache.gebaut == gebaut,
		"Zweiter Start: alle %d Bauten geladen, keiner neu gebaut" % Baucache.treffer)
	pruefe(t_cache < t_bau, "Zweiter Start schneller (%d ms statt %d ms)" % [t_cache, t_bau])
	pruefe(bild_bau.size() > 1000 and bild_bau.size() == bild_cache.size(),
		"Gleich viele Knoten unter den Bauten (%d / %d)" % [bild_bau.size(), bild_cache.size()])
	var abweichend := 0
	var erste := ""
	for i in mini(bild_bau.size(), bild_cache.size()):
		if bild_bau[i] != bild_cache[i]:
			abweichend += 1
			if erste == "":
				erste = "\n       frisch: %s\n       Cache:  %s" % [bild_bau[i].left(240), bild_cache[i].left(240)]
	pruefe(abweichend == 0, "Bau aus dem Cache gleicht dem frisch gebauten (Lagen, Meshes, Materialien, Kollision, Licht)%s" % erste)
	var ohne_lagen := 0
	var mmis := 0
	for n in r2.find_children("*", "MultiMeshInstance3D", true, false):
		var eltern: Script = n.get_parent().get_script()
		if eltern != null and eltern.resource_path.ends_with("stadthaeuser.gd"):
			mmis += 1
			var lagen: Array = n.get_meta("lagen", [])
			if lagen.size() != (n as MultiMeshInstance3D).multimesh.instance_count or lagen.is_empty() \
					or lagen.all(func(t: Transform3D) -> bool: return t.origin == Vector3.ZERO):
				ohne_lagen += 1
	pruefe(mmis > 0 and ohne_lagen == 0,
		"Häuser (MultiMesh) tragen ihre Lagen in den Daten, auch ohne Grafik (%d MultiMeshes, %d ohne)" % [mmis, ohne_lagen])
	pruefe(_gemeinsame_materialien(r2), "Im Code erzeugte Materialien sind nach dem Laden wieder die gemeinsamen (keine Kopien je Bau)")
	var pferde := 0
	var doppelt := 0
	for n: Node in r2.find_children("*", "", true, false):
		var eltern: Script = n.get_parent().get_script() if n.get_parent() != null else null
		if n.get_script() == null or not n.get_script().resource_path.ends_with("tier.gd") \
				or eltern == null or not eltern.resource_path.ends_with("burgbau.gd"):
			continue
		pferde += 1
		var koerper := 0
		for k in n.get_children():
			if k is CollisionObject3D:
				koerper += 1
		if koerper != 1:
			doppelt += 1
	pruefe(pferde > 0 and doppelt == 0, "Pferde im Stall aus dem Cache: je ein Körper, nichts doppelt (%d Pferde)" % pferde)

	# 3. Schlüssel
	bau = r2.get_node("Drachenstein/Burgen/HofhausEinrichtung")
	pruefe(Baucache.schluessel(bau) == schl_vorher, "Schlüssel bleibt bei gleichen Daten gleich")
	var alt: PackedFloat32Array = bau.raeume
	var neu := alt.duplicate()
	neu[0] += 0.5
	bau.set("raeume", neu)
	pruefe(Baucache.schluessel(bau) != schl_vorher, "Schlüssel ändert sich, wenn sich die Daten des Baus ändern")
	bau.set("raeume", alt)
	Baucache.aus = true
	pruefe(not Baucache.an(bau), "Abschaltbar (aus / --ohne-baucache)")
	Baucache.aus = false
	var lose := Node3D.new()
	r2.add_child(lose)
	pruefe(not Baucache.an(lose), "Knoten ohne Szenendatei werden immer gebaut")
	r2.free()

	# 4. Bäume unabhängig davon, was gerade nachgeladen ist: frisch berechnet, ohne eine einzige geladene Zelle
	var bewuchs_datei := ""
	for f in DirAccess.get_files_at(Baucache.ordner):
		if f.ends_with(".bewuchs"):
			bewuchs_datei = Baucache.ordner + f
	var md5_alle := FileAccess.get_md5(bewuchs_datei)
	DirAccess.remove_absolute(bewuchs_datei)
	var Z := root.get_node("Zellwelt")
	Z.aus = false
	Z.ziel_position = Vector3(5000, 0, 5000)
	var r3 := await _lade()
	var b3: Array = await _baeume(r3)
	pruefe(not b3[2] and b3[0] == b1[0] and FileAccess.get_md5(bewuchs_datei) == md5_alle,
		"Ohne geladene Zellen frisch berechnet: dieselben Bäume (%s)" % str(b3[0]))
	r3.free()
	Z.ziel_position = null
	Z.aus = true

	print("\nFehler: %d" % fehler)
	quit(1 if fehler > 0 else 0)


## Bäume einer Region: [Anzahl je Art, Lagen der Stämme (sortiert), aus dem Baucache?]
func _baeume(r: Node) -> Array:
	var bw: Node = r.get_node("Bewuchs")
	var ende := Time.get_ticks_msec() + 20000
	while (bw.anzahl as Dictionary).is_empty() and Time.get_ticks_msec() < ende:
		await process_frame
	await process_frame
	var lagen: Array[String] = []
	for k in bw.find_children("*", "CollisionShape3D", true, false):
		lagen.append(str(((k as Node3D).global_position * 100.0).round()))
	lagen.sort()
	return [bw.anzahl.duplicate(), lagen, bw.aus_cache]


func _lade() -> Node:
	var r: Node = (load(REGION) as PackedScene).instantiate()
	root.add_child(r)
	for i in 4:
		await process_frame
	return r


## Alles unter den Bauten (Burgbau, Stadthäuser) als Text, je Knoten eine Zeile, sortiert. Automatische Namen (@Typ@n)
## und Objekt-Nummern werden weggelassen, sie unterscheiden sich von Lauf zu Lauf.
func _bild(r: Node) -> PackedStringArray:
	var zeilen := PackedStringArray()
	for n in r.find_children("*", "Node3D", true, false):
		var s: Script = n.get_script()
		if s == null or not (s.resource_path.ends_with("burgbau.gd") or s.resource_path.ends_with("stadthaeuser.gd")):
			continue
		for k: Node in n.find_children("*", "", true, false):
			var z := "%s %s" % [_ohne_auto(str(r.get_path_to(k))), k.get_class()]
			# Türflügel drehen sich, wenn jemand vorbeigeht (fluegel.gd): ihre Drehpunkte nicht vergleichen
			var im_fluegel := k.get_parent() is Fluegel or (k.get_parent() != null and k.get_parent().get_parent() is Fluegel)
			if k is Node3D and not im_fluegel:
				z += " %s" % (k as Node3D).transform
			if k is GeometryInstance3D:
				var gi := k as GeometryInstance3D
				z += " cs=%d vr=%.1f/%.1f" % [gi.cast_shadow, gi.visibility_range_end, gi.visibility_range_end_margin]
			var m: Mesh = null
			if k is MeshInstance3D:
				m = (k as MeshInstance3D).mesh
			elif k is MultiMeshInstance3D and (k as MultiMeshInstance3D).multimesh != null:
				var mm := (k as MultiMeshInstance3D).multimesh
				m = mm.mesh
				var lagen: Array = k.get_meta("lagen", [])
				z += " n=%d lagen=%d %s" % [mm.instance_count, lagen.size(), str(lagen.hash())]
			if m != null:
				for i in m.get_surface_count():
					var mt := m.surface_get_material(i)
					z += " [%d %s]" % [m.surface_get_array_len(i), _material_name(mt)]
			if k is CollisionShape3D and (k as CollisionShape3D).shape != null:
				var sh := (k as CollisionShape3D).shape
				z += " %s" % sh.get_class()
				if sh is ConcavePolygonShape3D:
					var f := (sh as ConcavePolygonShape3D).get_faces()
					z += " %d %s" % [f.size(), f[f.size() / 2] if f.size() > 0 else Vector3.ZERO]
				elif sh is BoxShape3D:
					z += " %s" % (sh as BoxShape3D).size
			if k is OmniLight3D:
				var l := k as OmniLight3D
				z += " %.2f %.2f %s %s" % [l.omni_range, l.light_energy, l.light_color, l.shadow_enabled]
			if k is CollisionObject3D:
				z += " ebene=%d" % (k as CollisionObject3D).collision_layer
			if k.get_script() != null:
				z += " " + k.get_script().resource_path.get_file()
				if k.get("regel") != null:
					z += " %s %s %s" % [k.get("regel"), k.get("bedingung"), k.get("breite")]
				if k.get("fell") != null:
					z += " %s %s" % [k.get("art"), k.get("fell")]
			zeilen.append(z)
	zeilen.sort()
	return zeilen


static func _material_name(mt: Material) -> String:
	if mt == null:
		return "-"
	if mt.resource_path.begins_with("res://"):
		return mt.resource_path
	return "code:" + mt.resource_name


static func _ohne_auto(pfad: String) -> String:
	var re := RegEx.create_from_string("@([A-Za-z0-9]+)@\\d+")
	return re.sub(pfad, "@$1@", true)


## Jedes im Code erzeugte Material (mit Namen) kommt in allen Bauten als dasselbe Objekt vor.
func _gemeinsame_materialien(r: Node) -> bool:
	var je_name := {}
	for n in r.find_children("*", "GeometryInstance3D", true, false):
		var m: Mesh = null
		if n is MeshInstance3D:
			m = (n as MeshInstance3D).mesh
		elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh != null:
			m = (n as MultiMeshInstance3D).multimesh.mesh
		if m == null:
			continue
		var p := n.get_parent()
		var s: Script = p.get_script() if p != null else null
		if s == null or not (s.resource_path.ends_with("burgbau.gd") or s.resource_path.ends_with("stadthaeuser.gd")):
			continue
		for i in m.get_surface_count():
			var mt := m.surface_get_material(i)
			if mt == null or mt.resource_path.begins_with("res://") or mt.resource_name == "":
				continue
			var schl := s.resource_path + ":" + mt.resource_name
			if not je_name.has(schl):
				je_name[schl] = {}
			je_name[schl][mt.get_instance_id()] = true
	if je_name.is_empty():
		return false
	for schl in je_name:
		if (je_name[schl] as Dictionary).size() != 1:
			print("       mehrfach: ", schl, " ", (je_name[schl] as Dictionary).size())
			return false
	return true
