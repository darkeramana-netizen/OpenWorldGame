extends Resource
## Zwischenspeicher für Bauten, die beim Laden aus Daten gebaut werden (Phase 1, Punkt 2, docs/03-messgrundlage.md).
##
## Ein Burgbau erzeugt seine Geometrie (Mauern, Türme, Häuser, Einrichtung) beim Start in GDScript aus den Maßen, die
## die Bauskripte festlegen. Das Ergebnis hängt nur vom Code und von diesen Daten ab, nicht vom Spielstand oder vom
## Zufall. Darum wird es nach dem ersten Bau als Ressource gespeichert (user://baucache/) und bei jedem weiteren Start
## nur noch geladen.
##
## Der Schlüssel einer Datei setzt sich zusammen aus: Godot-Version, Inhalt aller Skripte (res://szenen/, res://autoload/),
## Inhalt der Szenendatei, in der der Knoten steht (darin stehen auch die Nachbarn, nach denen sich ein Bau richtet),
## dem Pfad des Knotens darin und seinen gespeicherten Eigenschaften. Ändert sich eins davon, wird neu gebaut. Im Editor,
## für Knoten, die nicht aus einer Szenendatei stammen, und mit dem Startargument --ohne-baucache wird immer gebaut.
##
## Gespeichert wird je direktem Kind des Baus eine Teilszene. Knoten mit eigenem Skript (Torflügel, Tiere) werden nur
## mit ihren Eigenschaften gespeichert; was sie selbst in _ready bauen, bauen sie beim Laden wieder selbst.
## Materialien aus Dateien bleiben Verweise. Im Code erzeugte Materialien tragen ihren Namen (resource_name) und werden
## beim Laden wieder gegen das gemeinsame Material getauscht, damit nicht jeder Bau eigene Kopien hat.

const VERSION := 1     # erhöhen, wenn sich das Dateiformat ändert

static var ordner := "user://baucache/"   # Tests nehmen einen eigenen
static var aus := false                    # true: immer bauen (wie --ohne-baucache)
static var treffer := 0                    # geladene Bauten (für Tests und die Messung)
static var gebaut := 0                     # gebaute und gespeicherte Bauten

@export var teile: Array[PackedScene] = []

static var _code := ""
static var _szenen := {}


## Ob für diesen Knoten der Zwischenspeicher gilt.
static func an(knoten: Node) -> bool:
	if aus or Engine.is_editor_hint() or "--ohne-baucache" in OS.get_cmdline_user_args():
		return false
	return knoten.owner != null and _szene_md5(knoten.owner.scene_file_path) != ""


static func schluessel(knoten: Node) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(("%d|%s|%s|%s|%s|" % [VERSION, Engine.get_version_info().string, _code_md5(),
		_szene_md5(knoten.owner.scene_file_path), knoten.owner.get_path_to(knoten)]).to_utf8_buffer())
	for p in knoten.get_property_list():
		if not (p.usage & PROPERTY_USAGE_STORAGE) or not (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var w: Variant = knoten.get(p.name)
		if w is Object:
			w = (w as Resource).resource_path if w is Resource else ""
		ctx.update(String(p.name).to_utf8_buffer())
		ctx.update(var_to_bytes(w))
	return ctx.finish().hex_encode()


## Lädt den gespeicherten Bau unter knoten. material(Name) liefert das gemeinsame Material zu einem Namen.
static func lade(knoten: Node, schl: String, material: Callable) -> bool:
	var pfad := ordner + schl + ".res"
	if not FileAccess.file_exists(pfad):
		return false
	var daten := ResourceLoader.load(pfad, "", ResourceLoader.CACHE_MODE_IGNORE)
	if daten == null or not "teile" in daten:
		return false
	for ps: PackedScene in daten.teile:
		var n := ps.instantiate()
		if n == null:
			continue
		_materialien_zurueck(n, material)
		knoten.add_child(n)
	treffer += 1
	return true


## Speichert die Kinder von knoten (gerade gebaut) unter dem Schlüssel.
static func speichere(knoten: Node, schl: String) -> void:
	var daten := (load("res://szenen/welt/baucache.gd") as GDScript).new() as Resource
	for kind in knoten.get_children():
		var gesetzt: Array[Node] = []
		if kind.get_script() == null:    # Torflügel, Tiere: nur sie selbst, ihre Kinder bauen sie in _ready
			for k in kind.get_children():
				_besitzer(k, kind, gesetzt)
		var ps := PackedScene.new()
		var ok := ps.pack(kind)
		for n in gesetzt:
			n.owner = null
		if ok != OK:
			push_warning("Baucache: %s lässt sich nicht speichern" % kind.get_path())
			return
		daten.teile.append(ps)
	DirAccess.make_dir_recursive_absolute(ordner)
	_aufraeumen(knoten, schl)
	# erst unter einem eigenen Namen schreiben, dann umbenennen: Ein zweites Spiel (oder ein Test daneben) liest nie
	# eine halb geschriebene Datei
	var tmp := ordner + "%s.%d.tmp.res" % [schl, OS.get_process_id()]
	if ResourceSaver.save(daten, tmp, ResourceSaver.FLAG_COMPRESS) == OK:
		DirAccess.rename_absolute(tmp, ordner + schl + ".res")
		gebaut += 1
	else:
		DirAccess.remove_absolute(tmp)


static func _besitzer(n: Node, wurzel: Node, gesetzt: Array[Node]) -> void:
	n.owner = wurzel
	gesetzt.append(n)
	if n.get_script() != null:
		return    # baut seine Kinder selbst
	for k in n.get_children():
		_besitzer(k, wurzel, gesetzt)


static func _materialien_zurueck(n: Node, material: Callable) -> void:
	var mesh: Mesh = null
	if n is MeshInstance3D:
		mesh = (n as MeshInstance3D).mesh
	elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh != null:
		mesh = (n as MultiMeshInstance3D).multimesh.mesh
	if mesh != null:
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			# eingebettet (Pfad leer oder "datei::id"), nicht aus einer Datei unter res://
			if m != null and m.resource_name != "" and not m.resource_path.begins_with("res://"):
				mesh.surface_set_material(i, material.call(m.resource_name))
	if n.get_script() != null:
		return
	for k in n.get_children():
		_materialien_zurueck(k, material)


## Je Knoten bleibt nur die neueste Datei; sonst sammeln sich bei jeder Änderung am Code alte an. Ein Merker je Knoten
## (Szene und Pfad) hält fest, welcher Schlüssel zuletzt gespeichert wurde.
static func _aufraeumen(knoten: Node, schl: String) -> void:
	var merker := ordner + "%s.knoten" % String(knoten.owner.scene_file_path + "|" + str(knoten.owner.get_path_to(knoten))).md5_text()
	if FileAccess.file_exists(merker):
		var alt := FileAccess.get_file_as_string(merker).strip_edges()
		if alt != "" and FileAccess.file_exists(ordner + alt + ".res"):
			DirAccess.remove_absolute(ordner + alt + ".res")
	var f := FileAccess.open(merker, FileAccess.WRITE)
	if f:
		f.store_string(schl)


static func _code_md5() -> String:
	if _code == "":
		var dateien := PackedStringArray()
		for wurzel in ["res://szenen", "res://autoload"]:
			_sammle(wurzel, dateien)
		dateien.sort()
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_MD5)
		for d in dateien:
			ctx.update((d + FileAccess.get_md5(d)).to_utf8_buffer())
		_code = ctx.finish().hex_encode()
	return _code


static func _sammle(verz: String, dateien: PackedStringArray) -> void:
	for d in DirAccess.get_directories_at(verz):
		_sammle(verz.path_join(d), dateien)
	for f in DirAccess.get_files_at(verz):
		if f.ends_with(".gd") or f.ends_with(".gdc"):
			dateien.append(verz.path_join(f))


static func _szene_md5(pfad: String) -> String:
	if pfad == "":
		return ""
	if not _szenen.has(pfad):
		_szenen[pfad] = FileAccess.get_md5(pfad)
	return _szenen[pfad]
