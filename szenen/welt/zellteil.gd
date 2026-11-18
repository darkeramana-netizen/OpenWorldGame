extends Node3D
## Platzhalter für eine Zelle eines Baus (docs/05-phase2-zellen.md). Hängt seinen Inhalt ("Inhalt") ein, sobald der
## Spieler näher als der Ladeabstand ist, und gibt ihn mit Abstand wieder frei (autoload/zellwelt.gd).
##
## Der Inhalt kommt aus dem Baucache (eigene Datei je Zelle, wird im Hintergrund vorgeladen und beim Entladen
## freigegeben), ist beim ersten Start frisch gebaut (dann bleibt er abgehängt im Speicher) oder wird bei Bedarf von
## einer Funktion des Baus erzeugt (bauer, z. B. ausstattung.gd) und beim Entladen freigegeben.

## Metadaten am Knoten einer Zelle: ihre Nummer im Raster (Vector2i)
const ZELLE := "zelle"
const Baucache := preload("res://szenen/welt/baucache.gd")

var rechteck := Rect2()
var abstand := 0.0
## Baucache-Datei mit dem Inhalt (leer: Inhalt liegt in vorrat)
var datei := ""
var material: Callable
## Frisch gebauter Inhalt, solange er abgehängt ist
var vorrat: Node = null
## Oder: Funktion, die den Inhalt erzeugt (liefert einen Node3D)
var bauer: Callable

var _inhalt: Node = null


## Ob die Zellen von bau nachgeladen werden (sonst bleiben sie immer geladen).
static func nachladen_an(bau: Node) -> bool:
	var groesse: Variant = bau.get("zellgroesse")
	var laden_ab: Variant = bau.get("zell_laden_ab")
	if Engine.is_editor_hint() or groesse == null or laden_ab == null or float(groesse) <= 0.0 or float(laden_ab) <= 0.0:
		return false
	var zw := bau.get_node_or_null("/root/Zellwelt")
	return zw != null and not zw.aus


static func rechteck_fuer(k: Vector2i, groesse: float) -> Rect2:
	return Rect2(Vector2(k) * groesse, Vector2.ONE * groesse)


## Platzhalter für eine frisch gebaute Zelle (der Knoten mit den Metadaten ZELLE)
static func mit_vorrat(zelle: Node, groesse: float, laden_ab: float) -> Node3D:
	var p: Node3D = (load("res://szenen/welt/zellteil.gd") as GDScript).new()
	p.name = zelle.name
	p.rechteck = rechteck_fuer(zelle.get_meta(ZELLE), groesse)
	p.abstand = laden_ab
	zelle.name = "Inhalt"
	p.vorrat = zelle
	return p


## Platzhalter, dessen Inhalt bauer() bei Bedarf erzeugt
static func mit_bauer(name_: String, k: Vector2i, groesse: float, laden_ab: float, bauer_: Callable) -> Node3D:
	var p: Node3D = (load("res://szenen/welt/zellteil.gd") as GDScript).new()
	p.name = name_
	p.rechteck = rechteck_fuer(k, groesse)
	p.abstand = laden_ab
	p.bauer = bauer_
	return p


## Platzhalter für eine Zelle aus dem Baucache
static func aus_datei(name_: String, k: Vector2i, pfad: String, groesse: float, laden_ab: float, mat: Callable) -> Node3D:
	var p: Node3D = (load("res://szenen/welt/zellteil.gd") as GDScript).new()
	p.name = name_
	p.rechteck = rechteck_fuer(k, groesse)
	p.abstand = laden_ab
	p.datei = pfad
	p.material = mat
	return p


func _ready() -> void:
	var zw := get_node_or_null("/root/Zellwelt")
	if zw != null:
		zw.melde(self)
	else:
		zell_bauen()


func _exit_tree() -> void:
	var zw := get_node_or_null("/root/Zellwelt")
	if zw != null:
		zw.abmelde(self)


func _notification(was: int) -> void:
	if was == NOTIFICATION_PREDELETE and vorrat != null and is_instance_valid(vorrat) and not vorrat.is_inside_tree():
		vorrat.free()


func zell_rechteck() -> Rect2:
	return rechteck


func zell_abstand() -> float:
	return abstand


func zell_dateien() -> PackedStringArray:
	return PackedStringArray([datei]) if datei != "" else PackedStringArray()


func zell_bauen() -> void:
	if _inhalt != null:
		return
	if vorrat != null:
		_inhalt = vorrat
		add_child(vorrat)
		return
	if bauer.is_valid():
		_inhalt = bauer.call()
		_inhalt.name = "Inhalt"
		add_child(_inhalt)
		return
	var daten: Resource = null
	if ResourceLoader.load_threaded_get_status(datei) == ResourceLoader.THREAD_LOAD_LOADED:
		daten = ResourceLoader.load_threaded_get(datei)
	elif FileAccess.file_exists(datei):
		daten = ResourceLoader.load(datei, "", ResourceLoader.CACHE_MODE_IGNORE)
	if daten == null or not "teile" in daten or (daten.teile as Array).is_empty():
		push_warning("Zellteil %s: Inhalt fehlt (%s)" % [get_path(), datei])
		return
	var n: Node = (daten.teile[0] as PackedScene).instantiate()
	Baucache.nachbereite(n, material)
	n.name = "Inhalt"
	_inhalt = n
	add_child(n)


func zell_leeren() -> void:
	if _inhalt == null:
		return
	if _inhalt == vorrat:
		remove_child(vorrat)
	else:
		_inhalt.queue_free()
	_inhalt = null


func ist_geladen() -> bool:
	return _inhalt != null
