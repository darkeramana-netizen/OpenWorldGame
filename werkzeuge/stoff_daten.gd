extends SceneTree
## Schreibt je Menschenmodell die Daten der Stoffquellen (Rock, Schürzen, Wappenrock, Kettenhemd-Schoß, Flicken) in
## modelle/figuren/menschen/<name>/stoff_daten.res.
##
## Godot hält Mesh-Daten nur auf der Grafikkarte. Der Stoff (Modul sorrowland) müsste sie sonst beim ersten Stoff eines
## Modells zurücklesen und dafür warten, bis die Grafikkarte alles Bisherige fertig hat: Messung 24.11.2026 18 Uhr,
## im Anlauf eine ganze Bildzeit der Grafikkarte zusätzlich in jedem Bild, in dem ein Modell zum ersten Mal Stoff
## bekam. figur.gd gibt die Daten dem Modul vor (Stoff.quelle_vorgeben), bevor es den ersten Stoff einrichtet.
##
## Nach jedem Bau der Menschen (werkzeuge/menschen_vorrat.py) und dem Import in Godot:
##   godot --headless --path . --script res://werkzeuge/stoff_daten.gd
## Passen die Daten nicht mehr zum Modell (andere Eckenzahl), liest der Stoff wie früher zurück; nichts bricht.

const MENSCHEN := "res://modelle/figuren/menschen/"
const Figur := preload("res://szenen/figuren/figur.gd")
## Was der Stoff aus der Quelle braucht (Modul: einrichten, anhaengen); alles andere bleibt weg
const FELDER := [Mesh.ARRAY_VERTEX, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_COLOR, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS,
		Mesh.ARRAY_INDEX]


func _initialize() -> void:
	var anzahl := 0
	for name_ in DirAccess.get_directories_at(MENSCHEN):
		var pfad := MENSCHEN + name_ + "/" + name_ + ".gltf"
		if not ResourceLoader.exists(pfad):
			continue
		var szene: PackedScene = load(pfad)
		var modell := szene.instantiate()
		var skelett := modell.get_node_or_null("Armature/Skeleton3D") as Skeleton3D
		var teile := {}
		if skelett != null:
			for k in skelett.get_children():
				if k is MeshInstance3D and (k as MeshInstance3D).mesh != null and ist_quelle(String(k.name)):
					teile[String(k.name)] = nur_noetiges((k as MeshInstance3D).mesh.surface_get_arrays(0))
		modell.free()
		var ziel := MENSCHEN + name_ + "/stoff_daten.res"
		if teile.is_empty():
			if FileAccess.file_exists(ziel):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(ziel))
			continue
		var daten := Resource.new()
		daten.set_meta("teile", teile)
		var fehler := ResourceSaver.save(daten, ziel, ResourceSaver.FLAG_COMPRESS)
		print("%s: %d Teile (%s) %s" % [name_, teile.size(), ", ".join(teile.keys()),
				"gespeichert" if fehler == OK else "FEHLER %d" % fehler])
		anzahl += 1
	print("Stoffdaten für %d Modelle" % anzahl)
	quit()


static func ist_quelle(n: String) -> bool:
	if n.begins_with("Flicken"):
		return not n.ends_with("_fern")
	return Figur.STOFF_TEILE.has(n.trim_suffix("_voll"))


static func nur_noetiges(arr: Array) -> Array:
	var aus := []
	aus.resize(Mesh.ARRAY_MAX)
	for f: int in FELDER:
		aus[f] = arr[f]
	return aus
