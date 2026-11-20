extends SceneTree
## Tests für Bauten in Zellen (burgbau.gd zellgroesse/zell_laden_ab, szenen/welt/zellteil.gd, Baucache je Zelle):
## In Zellen getrennt enthält ein Bau dasselbe wie am Stück (Flächen je Material, Lichter, Kollision), frisch gebaut
## und aus dem Baucache; nachgeladen wird nur, was nah ist, und Fernes wird wieder freigegeben.
## Starten: godot --headless --path . --script res://tests/test_zellen_bau.gd

const Baucache := preload("res://szenen/welt/baucache.gd")
const REGION := "res://szenen/welt/region_drachenstein.tscn"
const BAU := "Drachenstein/Burgen/HofhausEinrichtung"
const AUSSTATTUNG := "Drachenstein/Burgen/BurgAusstattung"
const NATUR := "Drachenstein/Natur"

var fehler := 0
var Z: Node


func pruefe(bed: bool, was: String) -> void:
	if bed:
		print("OK     ", was)
	else:
		fehler += 1
		print("FEHLER ", was)


func _initialize() -> void:
	Z = root.get_node("Zellwelt")
	Baucache.ordner = "user://baucache_zellen_test/"
	DirAccess.make_dir_recursive_absolute(Baucache.ordner)
	for f in DirAccess.get_files_at(Baucache.ordner):
		DirAccess.remove_absolute(Baucache.ordner.path_join(f))

	# 1. Am Stück (ohne Zellen)
	Z.aus = true
	var r := await _lade(0.0)
	var am_stueck := _inhalt(r.get_node(BAU))
	r.free()
	pruefe(am_stueck["flaechen"] > 10000 and am_stueck["kollision"] > 1000, "Einrichtung am Stück: %d Ecken, %d Lichter, %d Kollisionsdreiecke"
		% [am_stueck["flaechen"], am_stueck["lichter"], am_stueck["kollision"]])

	# 2. In Zellen, frisch gebaut, alle geladen
	r = await _lade(-1.0)
	var bau := r.get_node(BAU)
	var zellen := bau.get_children().filter(func(k: Node) -> bool: return k.name.begins_with("Zelle_"))
	pruefe(zellen.size() >= 6, "In %d Zellen getrennt" % zellen.size())
	var in_zellen := _inhalt(bau)
	pruefe(in_zellen == am_stueck, "In Zellen dasselbe wie am Stück (%s)" % _unterschied(am_stueck, in_zellen))
	var schl := Baucache.schluessel(bau)
	r.free()
	var dateien := DirAccess.get_files_at(Baucache.ordner)
	var zelldateien := Array(dateien).filter(func(f: String) -> bool: return f.begins_with(schl + ".Zelle_")).size()
	pruefe(zelldateien == zellen.size() and (schl + ".res") in dateien, "Baucache: eine Datei je Zelle (%d) und eine Hauptdatei" % zelldateien)

	# 3. Aus dem Baucache, alle geladen
	r = await _lade(-1.0)
	var aus_cache := _inhalt(r.get_node(BAU))
	pruefe(aus_cache == am_stueck, "Aus dem Baucache dasselbe (%s)" % _unterschied(am_stueck, aus_cache))
	r.free()

	# 4. Nachladen: weit weg nichts, nah die Zellen im Ladeabstand, dann wieder frei
	Z.aus = false
	Z.ziel_position = Vector3(5000, 0, 5000)
	r = await _lade(-1.0)
	bau = r.get_node(BAU)
	var platzhalter := bau.get_children().filter(func(k: Node) -> bool: return k.has_method("ist_geladen"))
	pruefe(platzhalter.size() == zellen.size() and _geladen(bau) == 0, "Weit weg: %d Platzhalter, keiner geladen" % platzhalter.size())
	Z.ziel_position = Vector3(10, 0, 0)
	Z.pruefe_sofort()
	await _warte(func() -> bool: return Z.wartend() == 0)
	var nah := 0
	for p: Node in platzhalter:
		if Z.abstand_zu(p.zell_rechteck(), Vector3(10, 0, 0)) <= p.zell_abstand():
			nah += 1
	pruefe(_geladen(bau) == nah and nah > 0 and nah < platzhalter.size(), "Am Ursprung: die %d nahen Zellen geladen, die fernen nicht" % nah)
	var mit_inhalt := platzhalter.filter(func(p: Node) -> bool: return p.ist_geladen() and p.get_node_or_null("Inhalt") != null).size()
	pruefe(mit_inhalt == nah, "Geladene Zellen haben ihren Inhalt aus der Datei")
	Z.ziel_position = Vector3(5000, 0, 5000)
	Z.pruefe_sofort()
	await process_frame
	await process_frame
	var leer := platzhalter.filter(func(p: Node) -> bool: return p.get_child_count() == 0).size()
	pruefe(_geladen(bau) == 0 and leer == platzhalter.size(), "Weit weg wieder freigegeben (%d leer)" % leer)
	r.free()

	# 5. Ausstattung: in Zellen dieselben Stücke und Kollisionen, Tiere immer da, Fernes nicht gebaut
	Z.aus = true
	r = await _lade(0.0, AUSSTATTUNG)
	await _warte(func() -> bool: return r.get_node(AUSSTATTUNG).get_child_count() > 0)
	var a_stueck := _stuecke(r.get_node(AUSSTATTUNG))
	r.free()
	r = await _lade(-1.0)
	await _warte(func() -> bool: return r.get_node(AUSSTATTUNG).get_child_count() > 0)
	var a_zellen := _stuecke(r.get_node(AUSSTATTUNG))
	var a_namen := r.get_node(AUSSTATTUNG).get_children().filter(func(k: Node) -> bool: return k.name.begins_with("Zelle_")).size()
	r.free()
	pruefe(a_stueck["exemplare"] > 100 and a_zellen == a_stueck and a_namen >= 4,
		"Ausstattung in %d Zellen: dieselben Stücke (%s / %s)" % [a_namen, str(a_stueck), str(a_zellen)])
	Z.aus = false
	Z.ziel_position = Vector3(5000, 0, 5000)
	r = await _lade(-1.0)
	var aus_ := r.get_node(AUSSTATTUNG)
	await _warte(func() -> bool: return aus_.get_child_count() > 0)
	var fern := _stuecke(aus_)
	pruefe(fern["exemplare"] == 0 and fern["tiere"] == a_stueck["tiere"], "Weit weg: keine Stücke gebaut, die %d Tiere sind da" % fern["tiere"])
	Z.ziel_position = Vector3(0, 0, 0)
	Z.pruefe_sofort()
	await _warte(func() -> bool: return Z.wartend() == 0)
	var nah_a := _stuecke(aus_)
	pruefe(nah_a["exemplare"] > 0, "Am Ursprung gebaut: %d Stücke" % nah_a["exemplare"])
	r.free()

	# 6. Natur (felsen.gd): in Zellen dieselben Stücke und Kollisionsformen, nur Nahes gebaut, nachher frei
	Z.aus = true
	r = await _lade(0.0, NATUR)
	var n_stueck := _stuecke(r.get_node(NATUR))
	r.free()
	r = await _lade(-1.0)
	var n_zellen := _stuecke(r.get_node(NATUR))
	var n_namen := r.get_node(NATUR).get_children().filter(func(k: Node) -> bool: return k.name.begins_with("Zelle_")).size()
	r.free()
	pruefe(n_stueck["exemplare"] > 1000 and n_zellen == n_stueck and n_namen >= 10,
		"Natur in %d Zellen: dieselben Stücke (%s / %s)" % [n_namen, str(n_stueck), str(n_zellen)])
	Z.aus = false
	Z.ziel_position = Vector3(5000, 0, 5000)
	r = await _lade(-1.0)
	var natur := r.get_node(NATUR)
	pruefe(_stuecke(natur)["exemplare"] == 0, "Natur weit weg: nichts gebaut")
	Z.ziel_position = Vector3(0, 0, 0)
	Z.pruefe_sofort()
	await _warte(func() -> bool: return Z.wartend() == 0)
	var n_nah := _stuecke(natur)
	pruefe(n_nah["exemplare"] > 0 and n_nah["exemplare"] < n_stueck["exemplare"], "Natur am Ursprung: %d von %d Stücken gebaut" % [n_nah["exemplare"], n_stueck["exemplare"]])
	r.free()

	# 7. Stämme der Bäume: Kollision in Zellen, alle Stämme da (wenn alles geladen), die Bäume selbst immer sichtbar
	Z.aus = true
	r = await _lade(-1.0)
	var bw := r.get_node("Bewuchs")
	await _warte(func() -> bool: return bw.get_node_or_null("StammZellen") != null)
	var staemme_alle := bw.find_children("*", "CollisionShape3D", true, false).size()
	var baeume: int = bw.anzahl.get("nadel", 0) + bw.anzahl.get("laub", 0)
	pruefe(staemme_alle == baeume and baeume > 500, "Alle %d Stämme haben Kollision (in %d Zellen)" % [baeume, bw.get_node("StammZellen").get_child_count()])
	r.free()
	Z.aus = false
	Z.ziel_position = Vector3(0, 0, 0)
	r = await _lade(-1.0)
	bw = r.get_node("Bewuchs")
	await _warte(func() -> bool: return bw.get_node_or_null("StammZellen") != null)
	Z.pruefe_sofort()
	await _warte(func() -> bool: return Z.wartend() == 0)
	var staemme_nah := bw.find_children("*", "CollisionShape3D", true, false).size()
	# Arten: einfache Formen als MultiMesh direkt am Bewuchs, Modellbäume in Gruppen je Art (Kacheln darunter)
	var arten := func(k: Node) -> bool: return k is MultiMeshInstance3D or (k.name in ["Nadelbaeume", "Laubbaeume", "Buesche"] and k.get_child_count() > 0)
	var sichtbar := bw.get_children().filter(arten).size()
	pruefe(staemme_nah < staemme_alle and sichtbar >= 2, "Am Ursprung nur nahe Stämme mit Kollision (%d von %d), Bäume sichtbar (%d Arten)" % [staemme_nah, staemme_alle, sichtbar])
	r.free()
	Z.ziel_position = null
	print("\nFehler: %d" % fehler)
	quit(1 if fehler > 0 else 0)


## Region laden; zellgroesse >= 0 setzt die Zellgröße der Einrichtung vor dem Aufbau (0: am Stück), -1 lässt sie.
func _lade(zellgroesse: float, pfad := BAU) -> Node:
	var r: Node = (load(REGION) as PackedScene).instantiate()
	if zellgroesse >= 0.0:
		r.get_node(pfad).set("zellgroesse", zellgroesse)
	root.add_child(r)
	for i in 4:
		await process_frame
	return r


func _warte(bed: Callable) -> void:
	var ende := Time.get_ticks_msec() + 20000
	while not bed.call() and Time.get_ticks_msec() < ende:
		await process_frame


func _geladen(bau: Node) -> int:
	return bau.get_children().filter(func(k: Node) -> bool: return k.has_method("ist_geladen") and k.ist_geladen()).size()


## Was ein Bau enthält: Ecken je Material, Lichter (gerundete Lagen), Dreiecke der Kollision
func _inhalt(bau: Node) -> Dictionary:
	var je_mat := {}
	var flaechen := 0
	var lichter: Array[String] = []
	var kollision := 0
	for n in bau.find_children("*", "", true, false):
		if n is MeshInstance3D and n.name == "Mesh":
			var m: Mesh = (n as MeshInstance3D).mesh
			for i in m.get_surface_count():
				var mat := m.surface_get_material(i)
				var name_: String = mat.resource_name if mat != null else "?"
				var ecken: int = (m.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
				je_mat[name_] = je_mat.get(name_, 0) + ecken
				flaechen += ecken
		elif n is OmniLight3D:
			lichter.append(str(((n as Node3D).global_position * 10.0).round()))
		elif n is CollisionShape3D and (n as CollisionShape3D).shape is ConcavePolygonShape3D:
			kollision += ((n as CollisionShape3D).shape as ConcavePolygonShape3D).get_faces().size() / 3
	lichter.sort()
	return {"flaechen": flaechen, "je_material": je_mat, "lichter": lichter.size(), "lichtlagen": lichter, "kollision": kollision}


## Stücke einer Ausstattung: Exemplare in MultiMeshes, Kollisionsformen, lebende Tiere
func _stuecke(a: Node) -> Dictionary:
	var ex := 0
	var formen := 0
	var tiere := 0
	for n in a.find_children("*", "", true, false):
		if n is MultiMeshInstance3D:
			ex += (n as MultiMeshInstance3D).multimesh.instance_count
		elif n is CollisionShape3D:
			formen += 1
		elif n.get_script() != null and String(n.get_script().resource_path).ends_with("tier.gd"):
			tiere += 1
	return {"exemplare": ex, "formen": formen, "tiere": tiere}


func _unterschied(a: Dictionary, b: Dictionary) -> String:
	if a == b:
		return "gleich"
	return "Ecken %d/%d, Lichter %d/%d, Kollision %d/%d" % [a["flaechen"], b["flaechen"], a["lichter"], b["lichter"], a["kollision"], b["kollision"]]
