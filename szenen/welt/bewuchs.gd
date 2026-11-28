extends Node3D
## Bewuchs einer Region: Nadel- und Laubbäume, Büsche, Felsbrocken und Gras auf dem Gelände.
## Alles entsteht beim Laden aus einem festen Zufall (gleiche Region, gleiche Bäume) und wird als
## MultiMesh gezeichnet, also viele gleiche Dinge in einem Zug. Gras gibt es nur in der Nähe des Spielers.
## Nichts wächst auf Wegen (rote Maske), im Wasser, an steilen Hängen, über der Schneegrenze, unter Bauten
## (ein Strahl von oben trifft dann nicht das Gelände) und in den frei gehaltenen Flächen (Stadt, Burghöfe).

@export var saat: int = 1750
## Anteil der Fläche, auf dem Wald steht (aus Rauschen verteilt), 0 bis 1.
@export_range(0.0, 1.0) var wald_anteil: float = 0.22
## Bäume je Hektar im Wald und auf offenem Land.
@export var wald_dichte: float = 140.0
@export var offen_dichte: float = 3.0
@export_range(0.0, 1.0) var nadel_anteil: float = 0.55
@export var busch_dichte: float = 8.0
@export var fels_dichte: float = 1.0
## Grasbüschel je Quadratmeter in der Nähe des Spielers (0: kein Gras).
@export var gras_dichte: float = 2.5
## Färbung von Gras und Laub (z. B. fahler im Moor).
@export var laub_farbe: Color = Color(1, 1, 1)
@export var schneegrenze: float = 85.0
## Frei gehaltene Flächen: Vielecke aus (x, z) und Kreise (x, z, Radius).
@export var frei_vielecke: Array[PackedVector2Array] = []
## Hier wächst nur Gras, keine Bäume und Büsche (Felder der Flur)
@export var baumfrei_vielecke: Array[PackedVector2Array] = []
@export var frei_kreise: PackedVector3Array = PackedVector3Array()
## Nur in diesem Rechteck (x, z, Breite, Tiefe); leer: das ganze Gelände.
@export var bereich: Rect2 = Rect2()
## Zusätzlich fest gesetzte Bäume (x, y, z, Größe), z. B. die Waldstücke an den Landstraßen; negative Größe: Laubbaum.
@export var feste_baeume: PackedVector4Array = PackedVector4Array()
## Baummodelle aus Fotoscans (werkzeuge/baum_laden.py): Ordner unter modelle/baeume/ mit <name>_nah.gltf,
## <name>_fern.gltf und baum.json. Leer: die einfachen Formen aus diesem Skript. Jeder Baum bekommt nach seinem Ort
## eines der Modelle; bis baum_nah_bis Meter die volle Fassung, dahinter die leichte (Mängelliste M6/M20).
@export var nadel_modelle := PackedStringArray()
@export var laub_modelle := PackedStringArray()
## Höhe eines Baums mit Größe 1 (die Exemplare streuen um 0,75 bis 1,35)
@export var nadel_hoehe := 12.0
@export var laub_hoehe := 9.0
@export var baum_nah_bis := 130.0
## Büsche aus einem Fotoscan (alle Teile des glTF sind Varianten), leer: die einfache Form; sichtbar bis busch_bis
@export var busch_modell := ""
@export var busch_bis := 200.0
@export var busch_groesse := 1.0
## > 0: Kollision der Stämme nach Zellen dieser Größe (Meter) trennen; mit zell_laden_ab > 0 entsteht sie erst, wenn
## der Spieler nah ist (autoload/zellwelt.gd). Die Bäume selbst bleiben immer sichtbar (von weit her zu sehen).
@export var zellgroesse := 0.0
@export var zell_laden_ab := 0.0

const Zellteil := preload("res://szenen/welt/zellteil.gd")
const Baucache := preload("res://szenen/welt/baucache.gd")
## Für Tests: ob die Pflanzen beim letzten Aufbau aus dem Baucache kamen
var aus_cache := false

const RASTER := 4.0             # Prüfraster für Bäume in m
const GRAS_ZELLE := 12.0
const GRAS_RADIUS := 3          # Zellen um den Spieler
const STEIL_BAUM := 0.32        # 1 - Normale.y
const STEIL_GRAS := 0.4

var _gelaende: Node3D
var _boden_rid: RID
var _maske: Image
var _flur: Image             # Felder (teil_flur.py): R Acker, G Getreide, B Weide/Wiese
var _maske_ursprung := Vector2.ZERO
var _maske_groesse := Vector2.ONE
var _meer: float = -20.0
var _rauschen := FastNoiseLite.new()
var _gras_zellen: Dictionary = {}
var _gras_mesh: Mesh
var _gras_material: ShaderMaterial
var _letzte_zelle := Vector2i(999999, 999999)
var anzahl := {}                # für Tests: Art → Anzahl


func _ready() -> void:
	_gelaende = get_tree().get_first_node_in_group("gelaende")
	if _gelaende == null:
		return
	# Warten, bis Gelände und Bauten ihre Kollision haben (CSG baut sie erst nach dem ersten Bild).
	for i in 3:
		await get_tree().physics_frame
	var koerper := _gelaende.get_node_or_null("Kollision") as CollisionObject3D
	if koerper:
		_boden_rid = koerper.get_rid()
	_lies_maske()
	_rauschen.seed = saat
	_rauschen.frequency = 0.004
	_rauschen.fractal_octaves = 3
	await _pflanze()
	_gras_mesh = _grasbueschel()
	_gras_material = _material(0.12, 0.0, 0.0, 0.95)
	_gras_material.set_shader_parameter("spitze_hoehe", 0.5)
	_gras_material.set_shader_parameter("boden_normale", true)
	_gras_material.set_shader_parameter("ausblenden_ab", GRAS_ZELLE * (GRAS_RADIUS - 1.2))
	_gras_material.set_shader_parameter("ausblenden_bis", GRAS_ZELLE * (GRAS_RADIUS - 0.2))


func _process(delta: float) -> void:
	_detail_aktualisieren(delta)
	if _gras_mesh == null or gras_dichte <= 0.0:
		return
	var spieler := get_tree().get_first_node_in_group("spieler") as Node3D
	if spieler == null:
		return
	var zelle := Vector2i(floori(spieler.global_position.x / GRAS_ZELLE), floori(spieler.global_position.z / GRAS_ZELLE))
	if zelle != _letzte_zelle:
		_letzte_zelle = zelle
		_erneuere_gras(zelle)


# ---------- Wo etwas wachsen darf ----------

func _lies_maske() -> void:
	var material := _gelaende.get("material") as ShaderMaterial
	if material == null:
		return
	var textur := material.get_shader_parameter("maske") as Texture2D
	if textur:
		_maske = textur.get_image()
		if _maske and _maske.is_compressed():
			_maske.decompress()
	var flur_textur := material.get_shader_parameter("flur") as Texture2D
	if flur_textur and material.get_shader_parameter("mit_flur"):
		_flur = flur_textur.get_image()
		if _flur and _flur.is_compressed():
			_flur.decompress()
	_maske_ursprung = material.get_shader_parameter("welt_ursprung")
	_maske_groesse = material.get_shader_parameter("welt_groesse")
	_meer = material.get_shader_parameter("meeresspiegel")


func _maske_bei(x: float, z: float) -> Color:
	if _maske == null:
		return Color(0, 0, 0)
	var u := (Vector2(x, z) - _maske_ursprung) / _maske_groesse
	if u.x < 0.0 or u.y < 0.0 or u.x >= 1.0 or u.y >= 1.0:
		return Color(0, 0, 0)
	return _maske.get_pixel(int(u.x * _maske.get_width()), int(u.y * _maske.get_height()))


func _flur_bei(x: float, z: float) -> Color:
	if _flur == null:
		return Color(0, 0, 0, 0)
	var u := (Vector2(x, z) - _maske_ursprung) / _maske_groesse
	if u.x < 0.0 or u.y < 0.0 or u.x >= 1.0 or u.y >= 1.0:
		return Color(0, 0, 0, 0)
	return _flur.get_pixel(int(u.x * _flur.get_width()), int(u.y * _flur.get_height()))


func _steilheit(x: float, z: float) -> float:
	var hx: float = _gelaende.hoehe_bei(x + 1.0, z) - _gelaende.hoehe_bei(x - 1.0, z)
	var hz: float = _gelaende.hoehe_bei(x, z + 1.0) - _gelaende.hoehe_bei(x, z - 1.0)
	return 1.0 - Vector3(-hx, 2.0, -hz).normalized().y


func _ist_frei(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	for kreis in frei_kreise:
		if p.distance_to(Vector2(kreis.x, kreis.y)) < kreis.z:
			return true
	for vieleck in frei_vielecke:
		if Geometry2D.is_point_in_polygon(p, vieleck):
			return true
	return false


## So tief muss ein Stamm am Hang einsinken, damit er auch auf der Talseite im Boden steckt: der tiefste Punkt im
## Umkreis r unter dem Mittelpunkt, dazu 10 cm (vorher schwebten Stämme am Hang talseitig über dem Boden)
func _einsinken(x: float, z: float, r: float) -> float:
	var h: float = _gelaende.hoehe_bei(x, z)
	var tiefst: float = h
	for k in 8:
		var w := TAU * k / 8.0
		tiefst = minf(tiefst, _gelaende.hoehe_bei(x + cos(w) * r, z + sin(w) * r))
	return h - tiefst + 0.1


## Darf hier etwas stehen? Gibt die Bodenhöhe zurück oder NAN.
func _platz(x: float, z: float, steil_max: float, raum: float) -> float:
	var h: float = _gelaende.hoehe_bei(x, z)
	if h < _meer + 1.2 or h > schneegrenze - 5.0:
		return NAN
	if _steilheit(x, z) > steil_max:
		return NAN
	var m := _maske_bei(x, z)
	# Rot Weg, Blau Pflaster (Burghöfe, gepflasterte Wege): dort wächst nichts, auch kein Gras (Rückmeldung 28.11.2026:
	# Gras mitten auf dem Pflaster); am Rand eines Wegs schon ab schwachem Anteil frei
	if m.r > 0.12 or m.b > 0.15 or (m.g > 0.5 and raum > 1.0):
		return NAN
	# Bäume und Büsche ragen mit Stamm und Krone über ihren Fußpunkt hinaus: auch der Umkreis bleibt vom Weg frei
	if raum > 1.0:
		for versatz in [Vector2(raum + 1.5, 0), Vector2(-raum - 1.5, 0), Vector2(0, raum + 1.5), Vector2(0, -raum - 1.5)]:
			if _maske_bei(x + versatz.x, z + versatz.y).r > 0.2:
				return NAN
	if _ist_frei(x, z) or _gelaende.am_loch(x, z, raum + 3.0):
		return NAN
	if raum > 0.0:
		for vieleck in baumfrei_vielecke:
			if Geometry2D.is_point_in_polygon(Vector2(x, z), vieleck):
				return NAN
	# Steht etwas darüber oder daneben (Mauer, Haus, Brücke)? Dann trifft der Strahl nicht den Boden.
	var raum_abfrage := get_world_3d().direct_space_state
	for versatz in [Vector2.ZERO, Vector2(raum, 0), Vector2(-raum, 0), Vector2(0, raum), Vector2(0, -raum)]:
		var von := Vector3(x + versatz.x, h + 40.0, z + versatz.y)
		var abfrage := PhysicsRayQueryParameters3D.create(von, von + Vector3.DOWN * 44.0, 1)
		var treffer := raum_abfrage.intersect_ray(abfrage)
		if treffer and treffer.rid != _boden_rid:
			return NAN
		if raum <= 0.0:
			break
	return h


# ---------- Bäume, Büsche, Felsen ----------

## Bäume, Büsche und Felsen setzen. Das Ergebnis hängt nur von Code, Szene und Geländedaten ab und kommt ab dem
## zweiten Start aus dem Baucache (das Berechnen mit den Strahlen kostet sonst gut 0,4 s im ersten Bild).
func _pflanze() -> void:
	var datei := _cache_datei()
	var listen := {}
	aus_cache = false
	if datei != "" and FileAccess.file_exists(datei):
		var f := FileAccess.open(datei, FileAccess.READ)
		var gelesen: Variant = f.get_var() if f != null else null
		if gelesen is Dictionary and (gelesen as Dictionary).has("nadel"):
			listen = gelesen
			aus_cache = true
	if listen.is_empty():
		# Neu berechnen (nur nach einer Änderung an Code, Szene oder Gelände): Erst alles bauen, was in Zellen nachgeladen
		# wird (Ausstattung, Natur), damit die Strahlen es treffen wie ohne Zellen; die Bäume stehen dann überall gleich,
		# egal wo der Spieler startet. Danach gibt die Zellwelt das Ferne wieder frei.
		var zw := get_node_or_null("/root/Zellwelt")
		if zw != null and zw.baue_alle() > 0:
			for i in 2:
				await get_tree().physics_frame
		listen = _berechne_pflanzen()
		if zw != null:
			zw.pruefe_sofort()
		if datei != "":
			DirAccess.make_dir_recursive_absolute(Baucache.ordner)
			Baucache.aufraeumen(self, datei.get_file().get_basename())
			var tmp := datei + ".%d.tmp" % OS.get_process_id()
			var f := FileAccess.open(tmp, FileAccess.WRITE)
			if f != null:
				f.store_var(listen)
				f.close()
				DirAccess.rename_absolute(tmp, datei)
	if nadel_modelle.is_empty():
		_zeige("Nadelbaeume", _nadelbaum(), listen["nadel"], _material(0.012, 0.6, 0.0, 0.85), true)
	else:
		_zeige_modelle("Nadelbaeume", listen["nadel"], nadel_modelle, nadel_hoehe)
	if laub_modelle.is_empty():
		_zeige("Laubbaeume", _laubbaum(), listen["laub"], _material(0.015, 0.6, 0.0, 0.85), true)
	else:
		_zeige_modelle("Laubbaeume", listen["laub"], laub_modelle, laub_hoehe)
	if busch_modell == "":
		_zeige("Buesche", _busch(), listen["busch"], _material(0.04, 0.6, 0.0, 0.9), false)
	else:
		var teile := []
		for m in _modell_meshes(busch_modell):
			teile.append([_mit_wind(m, 2.0, 0.02), null, busch_groesse])
		_zeige_gekachelt("Buesche", listen["busch"], teile, busch_bis)
	_zeige("Felsen", _fels(), listen["fels"], load("res://material/fels.tres"), false)
	for art in listen:
		anzahl[art] = (listen[art] as Array).size()
	_baue_stammkollision(listen["nadel"] + listen["laub"])


## Datei im Baucache: Schlüssel aus Code, Szene und Eigenschaften (Baucache) und den Geländedaten (Höhen, Maske)
func _cache_datei() -> String:
	if not Baucache.an(self):
		return ""
	var zusatz := FileAccess.get_md5(String(_gelaende.get("daten")).path_join("hoehen.r32"))
	var material := _gelaende.get("material") as ShaderMaterial
	var maske := material.get_shader_parameter("maske") as Texture2D if material != null else null
	if maske != null and maske.resource_path != "":
		zusatz += FileAccess.get_md5(maske.resource_path)
	return Baucache.ordner + (Baucache.schluessel(self) + zusatz).md5_text() + ".bewuchs"


func _berechne_pflanzen() -> Dictionary:
	var zufall := RandomNumberGenerator.new()
	zufall.seed = saat
	var flaeche := bereich
	if flaeche.size == Vector2.ZERO:
		flaeche = Rect2(_gelaende.ursprung, _gelaende.groesse())
	var listen := {"nadel": [], "laub": [], "busch": [], "fels": []}
	var zelle_ha := RASTER * RASTER / 10000.0
	# Schwelle so wählen, dass wirklich wald_anteil der Fläche Wald ist (Quantil des Rauschens).
	var proben: Array[float] = []
	for i in 4000:
		proben.append(_rauschen.get_noise_2d(flaeche.position.x + zufall.randf() * flaeche.size.x,
				flaeche.position.y + zufall.randf() * flaeche.size.y))
	proben.sort()
	var schwelle: float = proben[clampi(int((1.0 - wald_anteil) * proben.size()), 0, proben.size() - 1)]
	var x := flaeche.position.x
	while x < flaeche.end.x:
		var z := flaeche.position.y
		while z < flaeche.end.y:
			var px := x + zufall.randf() * RASTER
			var pz := z + zufall.randf() * RASTER
			var wald := 0.0 if wald_anteil <= 0.0 else smoothstep(schwelle - 0.04, schwelle + 0.04, _rauschen.get_noise_2d(px, pz))
			var dichte := lerpf(offen_dichte, wald_dichte, wald)
			var wurf := zufall.randf()
			if wurf < dichte * zelle_ha:
				var h := _platz(px, pz, STEIL_BAUM, 1.6)
				if not is_nan(h):
					var art := "nadel" if zufall.randf() < lerpf(nadel_anteil, minf(nadel_anteil + 0.25, 1.0), wald) else "laub"
					listen[art].append(_exemplar(zufall, px, h - _einsinken(px, pz, 0.6), pz, 0.75, 1.35))
			elif wurf < (dichte + busch_dichte * (1.0 + wald)) * zelle_ha:
				var h := _platz(px, pz, STEIL_BAUM + 0.05, 0.6)
				if not is_nan(h):
					listen["busch"].append(_exemplar(zufall, px, h - _einsinken(px, pz, 0.5), pz, 0.6, 1.4))
			elif wurf < (dichte + busch_dichte * (1.0 + wald) + fels_dichte) * zelle_ha:
				var h := _platz(px, pz, 0.6, 1.0)
				if not is_nan(h):
					listen["fels"].append(_exemplar(zufall, px, h - 0.3, pz, 0.5, 2.2))
			z += RASTER
		x += RASTER
	for b in feste_baeume:
		# negative Größe: sicher ein Laubbaum (z. B. die Hoflinden der Burg)
		var ex := _exemplar(zufall, b.x, b.y, b.z, absf(b.w), absf(b.w))
		listen["laub" if b.w < 0.0 or zufall.randf() >= nadel_anteil else "nadel"].append(ex)
	return listen


func _exemplar(zufall: RandomNumberGenerator, x: float, h: float, z: float, s_min: float, s_max: float) -> Array:
	var s := zufall.randf_range(s_min, s_max)
	var basis := Basis(Vector3.UP, zufall.randf() * TAU).scaled(Vector3(s, s * zufall.randf_range(0.9, 1.15), s))
	var ton := zufall.randf_range(0.8, 1.15)
	var farbe := Color(ton * zufall.randf_range(0.92, 1.05), ton, ton * zufall.randf_range(0.9, 1.05), zufall.randf())
	return [Transform3D(basis, Vector3(x, h, z)), farbe]


## Je Kachel (BAUM_KACHEL) ein MultiMesh: eins über die ganze Region wäre fast immer irgendwo sichtbar und würde nie
## verdeckt. Die Exemplare behalten ihre Weltlage, die Grenzen jedes MultiMeshes ergeben sich daraus.
func _zeige(name_: String, mesh: Mesh, exemplare: Array, material: Material, schatten: bool) -> void:
	if exemplare.is_empty():
		return
	var gruppen := {}
	for ex: Array in exemplare:
		var o: Vector3 = (ex[0] as Transform3D).origin
		(gruppen.get_or_add(Vector2i(floori(o.x / BAUM_KACHEL), floori(o.z / BAUM_KACHEL)), []) as Array).append(ex)
	var knoten := Node3D.new()
	knoten.name = name_
	add_child(knoten)
	for k: Vector2i in gruppen:
		var liste: Array = gruppen[k]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = liste.size()
		for i in liste.size():
			mm.set_instance_transform(i, liste[i][0])
			mm.set_instance_custom_data(i, liste[i][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_%d_%d" % [name_, k.x, k.y]
		mmi.multimesh = mm
		mmi.material_override = material
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if schatten else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		knoten.add_child(mmi)


const BAUM_KACHEL := 128.0


## Bäume aus Modellen: je Modell und Kachel (128 m) zwei MultiMeshes, nah die volle und fern die leichte Fassung,
## mit weichem Übergang (Sichtweite je Kachel). Das Modell eines Baums hängt nur von seinem Ort ab.
func _zeige_modelle(name_: String, exemplare: Array, ordner: PackedStringArray, hoehe: float) -> void:
	if exemplare.is_empty():
		return
	var modelle := []   # [nah, fern, Maßstab]
	for o in ordner:
		var pfad := "res://modelle/baeume/%s/" % o
		var info: Variant = JSON.parse_string(FileAccess.get_file_as_string(pfad + "baum.json"))
		var nah := _modell_mesh(pfad + o + "_nah.gltf")
		var fern := _modell_mesh(pfad + o + "_fern.gltf")
		var detail := _modell_mesh(pfad + o + "_detail.gltf") if OS.get_environment("BAUM_DETAIL_AUS") == "" else null
		if info is Dictionary and nah != null and fern != null:
			var h := float(info["hoehe"])
			modelle.append([_mit_wind(nah, h), _mit_wind(fern, h), hoehe / h, _mit_wind(detail, h) if detail != null else null])
	if modelle.is_empty():
		_zeige(name_, _nadelbaum() if name_ == "Nadelbaeume" else _laubbaum(), exemplare, _material(0.012, 0.6, 0.0, 0.85), true)
		return
	_zeige_gekachelt(name_, exemplare, modelle, baum_nah_bis)


## Exemplare nach Modell (aus dem Ort) und Kachel aufteilen. modelle: [Mesh nah, Mesh fern oder null, Maßstab];
## nah sichtbar bis nah_bis, fern ab dort (ohne Fernfassung endet das Modell bei nah_bis).
var exemplare_je_art := {}        # Name → Exemplare ([Transform, Farbe]), für Prüfungen (tests/)
func _zeige_gekachelt(name_: String, exemplare: Array, modelle: Array, nah_bis: float) -> void:
	exemplare_je_art[name_] = exemplare
	if exemplare.is_empty() or modelle.is_empty():
		return
	var gruppen := {}   # Vector3i(Modell, Kachel x, Kachel z) → Transformationen
	for ex: Array in exemplare:
		var t: Transform3D = ex[0]
		var m := absi(hash(Vector2i(roundi(t.origin.x * 10.0), roundi(t.origin.z * 10.0)))) % modelle.size()
		var k := Vector3i(m, floori(t.origin.x / BAUM_KACHEL), floori(t.origin.z / BAUM_KACHEL))
		(gruppen.get_or_add(k, []) as Array).append(t)
	var knoten := Node3D.new()
	knoten.name = name_
	add_child(knoten)
	for k: Vector3i in gruppen:
		var mitte := Vector3((k.y + 0.5) * BAUM_KACHEL, 0.0, (k.z + 0.5) * BAUM_KACHEL)
		var liste: Array = gruppen[k]
		var massstab: float = modelle[k.x][2]
		for stufe in 2:
			if modelle[k.x][stufe] == null:
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = modelle[k.x][stufe]
			mm.instance_count = liste.size()
			for i in liste.size():
				var t: Transform3D = liste[i]
				mm.set_instance_transform(i, Transform3D(t.basis.scaled(Vector3.ONE * massstab), t.origin - mitte))
			if stufe == 0 and modelle[k.x].size() > 3 and modelle[k.x][3] != null:
				_detail_merken(name_, modelle, k.x, mm, liste, massstab, mitte)
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s_%d_%d_%d" % ["nah" if stufe == 0 else "fern", k.x, k.y, k.z]
			mmi.multimesh = mm
			mmi.position = mitte
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			if stufe == 0:
				mmi.visibility_range_end = nah_bis
				mmi.visibility_range_end_margin = 30.0
			else:
				mmi.visibility_range_begin = nah_bis
				mmi.visibility_range_begin_margin = 30.0
				mmi.add_to_group("fern_schatten")   # Schatten je nach Grafikstufe (autoload/grafik.gd)
			knoten.add_child(mmi)


const BAUM_SHADER := preload("res://szenen/welt/baum.gdshader")


## Kopie des Meshes mit Wind (szenen/welt/baum.gdshader) statt der importierten Standardmaterialien; die Texturen,
## Farben und UV-Verschiebungen bleiben. hoehe: Höhe des Modells in Metern (ungeskaliert).
func _mit_wind(mesh: Mesh, hoehe: float, wiegen := 0.012) -> Mesh:
	var kopie := mesh.duplicate() as Mesh
	for f in kopie.get_surface_count():
		var alt := kopie.surface_get_material(f) as BaseMaterial3D
		if alt == null:
			continue
		var m := ShaderMaterial.new()
		m.shader = BAUM_SHADER
		m.set_shader_parameter("farbe_tex", alt.albedo_texture)
		m.set_shader_parameter("farbe", alt.albedo_color)
		m.set_shader_parameter("uv_massstab", Vector2(alt.uv1_scale.x, alt.uv1_scale.y))
		m.set_shader_parameter("uv_versatz", Vector2(alt.uv1_offset.x, alt.uv1_offset.y))
		if alt.normal_enabled and alt.normal_texture != null:
			m.set_shader_parameter("mit_normal", true)
			m.set_shader_parameter("normal_tex", alt.normal_texture)
			m.set_shader_parameter("normal_staerke", alt.normal_scale)
		if alt.roughness_texture != null:
			m.set_shader_parameter("mit_arm", true)
			m.set_shader_parameter("arm_tex", alt.roughness_texture)
		else:
			m.set_shader_parameter("rauheit", alt.roughness)
		var laub_ := alt.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
		m.set_shader_parameter("laub", laub_)
		if laub_:
			m.set_shader_parameter("alpha_schwelle", alt.alpha_scissor_threshold)
		m.set_shader_parameter("modell_hoehe", hoehe)
		m.set_shader_parameter("wiegen", wiegen)
		kopie.surface_set_material(f, m)
	return kopie


## Alle Teile eines Modells als Meshes (mit ihrer Drehung und Größe im Modell, ohne ihren Versatz)
func _modell_meshes(pfad: String) -> Array:
	var liste := []
	if not ResourceLoader.exists(pfad):
		return liste
	var szene: Node = (load(pfad) as PackedScene).instantiate()
	for mi: MeshInstance3D in szene.find_children("*", "MeshInstance3D", true, false):
		liste.append(mi.mesh)
	szene.free()
	return liste


func _modell_mesh(pfad: String) -> Mesh:
	if not ResourceLoader.exists(pfad):
		return null
	var szene: Node = (load(pfad) as PackedScene).instantiate()
	var teile := szene.find_children("*", "MeshInstance3D", true, false)
	var mesh: Mesh = (teile[0] as MeshInstance3D).mesh if not teile.is_empty() else null
	szene.free()
	return mesh


## Stämme sind fest: ein Körper mit einem Zylinder je Baum (mit zellgroesse ein Körper je Zelle).
func _baue_stammkollision(baeume: Array) -> void:
	if baeume.is_empty():
		return
	var orte := PackedVector3Array()
	for b in baeume:
		orte.append((b[0] as Transform3D).origin)
	if zellgroesse <= 0.0:
		add_child(_staemme(orte))
		return
	var je_zelle := {}     # Zelle → Orte (gepackte Arrays werden kopiert: daher zurückschreiben)
	for p in orte:
		var w := global_transform * p
		var k := Vector2i(floori(w.x / zellgroesse), floori(w.z / zellgroesse))
		var liste: PackedVector3Array = je_zelle.get(k, PackedVector3Array())
		liste.append(p)
		je_zelle[k] = liste
	var nachladen := Zellteil.nachladen_an(self)
	var zellen := Node3D.new()
	zellen.name = "StammZellen"
	add_child(zellen)
	for k: Vector2i in je_zelle:
		var name_ := "Zelle_%d_%d" % [k.x, k.y]
		if nachladen:
			zellen.add_child(Zellteil.mit_bauer(name_, k, zellgroesse, zell_laden_ab, _staemme.bind(je_zelle[k])))
		else:
			var z := _staemme(je_zelle[k])
			z.name = name_
			zellen.add_child(z)


func _staemme(orte: PackedVector3Array) -> StaticBody3D:
	var koerper := StaticBody3D.new()
	koerper.name = "Staemme"
	var form := CylinderShape3D.new()
	form.radius = 0.35
	form.height = 4.0
	for p in orte:
		var k := CollisionShape3D.new()
		k.shape = form
		k.position = p + Vector3(0, 2.0, 0)
		koerper.add_child(k)
	return koerper


func _material(biegsam: float, detail: float, spitze: float, rau: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://szenen/welt/bewuchs.gdshader")
	m.set_shader_parameter("biegsamkeit", biegsam)
	m.set_shader_parameter("detail", load("res://texturen/gras_farbe.jpg"))
	m.set_shader_parameter("detail_staerke", detail)
	m.set_shader_parameter("spitze_hell", spitze)
	m.set_shader_parameter("rauheit", rau)
	return m


# ---------- Gras um den Spieler ----------

func _erneuere_gras(mitte: Vector2i) -> void:
	var noetig := {}
	for dx in range(-GRAS_RADIUS, GRAS_RADIUS + 1):
		for dz in range(-GRAS_RADIUS, GRAS_RADIUS + 1):
			noetig[mitte + Vector2i(dx, dz)] = true
	for zelle in _gras_zellen.keys():
		if not noetig.has(zelle):
			_gras_zellen[zelle].queue_free()
			_gras_zellen.erase(zelle)
	for zelle: Vector2i in noetig:
		if not _gras_zellen.has(zelle):
			_gras_zellen[zelle] = _graszelle(zelle)


func _graszelle(zelle: Vector2i) -> Node3D:
	var zufall := RandomNumberGenerator.new()
	zufall.seed = hash(Vector3i(zelle.x, zelle.y, saat))
	var exemplare := []
	var anzahl_ := int(GRAS_ZELLE * GRAS_ZELLE * gras_dichte * 1.6)   # dichter (die Büschel sind kleiner)
	var grund := Color(1.0, 1.0, 1.0) * laub_farbe
	for i in anzahl_:
		var x := (zelle.x + zufall.randf()) * GRAS_ZELLE
		var z := (zelle.y + zufall.randf()) * GRAS_ZELLE
		if bereich.size != Vector2.ZERO and not bereich.has_point(Vector2(x, z)):
			continue
		var h := _platz(x, z, STEIL_GRAS, 0.0)
		if is_nan(h):
			continue
		# Flur (Mängelliste M6): auf dem Acker kein Gras; im Getreide hohe, goldene Halme (doppelt so dicht);
		# auf der Weide kurz; auf der Wiese hier und da ein blühender Büschel
		var fl := _flur_bei(x, z)
		if fl.r > 0.5:
			continue
		var ex := _exemplar(zufall, x, h - 0.05, z, 0.6, 1.4)
		var c: Color = ex[1]
		var ton := grund
		if fl.g > 0.5:
			ton = Color(1.55, 1.18, 0.5)
			var t: Transform3D = ex[0]
			t.basis = t.basis.scaled(Vector3(0.8, 2.6, 0.8))
			ex[0] = t
			var ex2 := _exemplar(zufall, x + zufall.randf_range(-0.4, 0.4), h - 0.05, z + zufall.randf_range(-0.4, 0.4), 0.7, 1.2)
			var t2: Transform3D = ex2[0]
			t2.basis = t2.basis.scaled(Vector3(0.8, 2.4, 0.8))
			exemplare.append([t2, Color(1.5, 1.14, 0.48, c.a)])
		elif fl.b > 0.3 and fl.b < 0.7:
			var t: Transform3D = ex[0]
			t.basis = t.basis.scaled(Vector3(1.0, 0.55, 1.0))
			ex[0] = t
		elif fl.b >= 0.7 and zufall.randf() < 0.16:
			ton = Color(2.4, 2.1, 0.5) if zufall.randf() < 0.6 else Color(2.5, 2.5, 2.3)
		ex[1] = Color(ton.r * c.r, ton.g * c.g, ton.b * c.b, c.a)
		exemplare.append(ex)
	var knoten := Node3D.new()
	add_child(knoten)
	if not exemplare.is_empty():
		var vorher := get_child_count()
		_zeige("Gras", _gras_mesh, exemplare, _gras_material, false)
		var mmi := get_child(vorher)
		remove_child(mmi)
		knoten.add_child(mmi)
	return knoten


# ---------- Formen ----------

func _kegel(st: SurfaceTool, unten: float, oben: float, r: float, seiten: int, farbe: Color, zufall: RandomNumberGenerator) -> void:
	var spitze := Vector3(zufall.randf_range(-0.15, 0.15), oben, zufall.randf_range(-0.15, 0.15))
	for i in seiten:
		var a1 := TAU * i / seiten
		var a2 := TAU * (i + 1) / seiten
		var r1 := r * zufall.randf_range(0.85, 1.1)
		var p1 := Vector3(cos(a1) * r1, unten - zufall.randf() * 0.3, sin(a1) * r1)
		var p2 := Vector3(cos(a2) * r, unten, sin(a2) * r)
		var c := farbe * zufall.randf_range(0.85, 1.1)
		st.set_color(c * 0.8); st.add_vertex(p1)
		st.set_color(c * 0.8); st.add_vertex(p2)
		st.set_color(c * 1.15); st.add_vertex(spitze)
		# Unterseite
		st.set_color(c * 0.5); st.add_vertex(p2)
		st.set_color(c * 0.5); st.add_vertex(p1)
		st.set_color(c * 0.5); st.add_vertex(Vector3(0, unten + 0.2, 0))


func _zylinder(st: SurfaceTool, unten: float, oben: float, r_unten: float, r_oben: float, seiten: int, farbe: Color) -> void:
	for i in seiten:
		var a1 := TAU * i / seiten
		var a2 := TAU * (i + 1) / seiten
		var u1 := Vector3(cos(a1) * r_unten, unten, sin(a1) * r_unten)
		var u2 := Vector3(cos(a2) * r_unten, unten, sin(a2) * r_unten)
		var o1 := Vector3(cos(a1) * r_oben, oben, sin(a1) * r_oben)
		var o2 := Vector3(cos(a2) * r_oben, oben, sin(a2) * r_oben)
		st.set_color(farbe)
		for p in [u1, o1, u2, u2, o1, o2]:
			st.add_vertex(p)


func _klumpen(st: SurfaceTool, mitte: Vector3, r: Vector3, farbe: Color, zufall: RandomNumberGenerator) -> void:
	# Ikosaeder, einmal unterteilt und verbeult: ein unregelmäßiger Blätterklumpen
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 9
	mesh.rings = 5
	var arr := mesh.get_mesh_arrays()
	var punkte: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var indizes: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var beule := {}
	for i in indizes.size():
		var p: Vector3 = punkte[indizes[i]]
		var schluessel := p.snapped(Vector3.ONE * 0.01)
		if not beule.has(schluessel):
			beule[schluessel] = zufall.randf_range(0.82, 1.12)
		var q: Vector3 = p * float(beule[schluessel]) * r + mitte
		var licht := 0.75 + 0.35 * clampf(p.y * 0.5 + 0.5, 0.0, 1.0)
		st.set_color(farbe * licht)
		st.add_vertex(q)


func _fertig(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals()
	return st.commit()


func _nadelbaum() -> ArrayMesh:
	var zufall := RandomNumberGenerator.new()
	zufall.seed = 11
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_zylinder(st, -0.3, 3.0, 0.28, 0.18, 6, Color(0.36, 0.28, 0.2))
	var gruen := Color(0.2, 0.3, 0.17)
	var stufen := [[1.6, 5.2, 2.6], [3.4, 7.0, 2.1], [5.0, 8.6, 1.6], [6.6, 10.0, 1.1], [8.0, 11.2, 0.65]]
	for s in stufen:
		_kegel(st, s[0], s[1], s[2], 9, gruen * zufall.randf_range(0.9, 1.1), zufall)
	return _fertig(st)


func _laubbaum() -> ArrayMesh:
	var zufall := RandomNumberGenerator.new()
	zufall.seed = 12
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_zylinder(st, -0.3, 4.2, 0.36, 0.22, 7, Color(0.38, 0.31, 0.23))
	_zylinder(st, 3.4, 5.6, 0.16, 0.08, 5, Color(0.38, 0.31, 0.23))
	var gruen := Color(0.3, 0.42, 0.17)
	for k in [[Vector3(0, 6.2, 0), Vector3(2.6, 2.1, 2.6)], [Vector3(1.5, 5.4, 0.6), Vector3(1.8, 1.6, 1.8)],
			[Vector3(-1.4, 5.6, -0.8), Vector3(1.9, 1.7, 1.9)], [Vector3(0.3, 5.0, -1.6), Vector3(1.7, 1.4, 1.7)],
			[Vector3(-0.6, 7.4, 0.7), Vector3(1.6, 1.4, 1.6)]]:
		_klumpen(st, k[0], k[1], gruen * zufall.randf_range(0.85, 1.15), zufall)
	return _fertig(st)


func _busch() -> ArrayMesh:
	var zufall := RandomNumberGenerator.new()
	zufall.seed = 13
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var gruen := Color(0.27, 0.37, 0.16)
	_klumpen(st, Vector3(0, 0.45, 0), Vector3(1.0, 0.75, 1.0), gruen, zufall)
	_klumpen(st, Vector3(0.6, 0.35, 0.3), Vector3(0.7, 0.55, 0.7), gruen * 1.1, zufall)
	return _fertig(st)


func _fels() -> ArrayMesh:
	var zufall := RandomNumberGenerator.new()
	zufall.seed = 14
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_klumpen(st, Vector3(0, 0.3, 0), Vector3(1.2, 0.8, 1.0), Color(1, 1, 1), zufall)
	return _fertig(st)


func _grasbueschel() -> ArrayMesh:
	var zufall := RandomNumberGenerator.new()
	zufall.seed = 15
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Rückmeldung 28.11.2026 (Gras unrealistisch: breite, steife Blätter in einzelnen Büscheln): viele schmale, kurze
	# Halme, die sich zur Spitze hin biegen, dicht wie ein Rasen; Farbe nahe dem Wiesenboden, einige Halme trocken
	var toene := [Color(0.25, 0.33, 0.12), Color(0.21, 0.29, 0.11), Color(0.29, 0.36, 0.14), Color(0.45, 0.43, 0.22)]
	for i in 22:
		var a := zufall.randf() * TAU
		var r := sqrt(zufall.randf()) * 0.32
		var fuss := Vector3(cos(a) * r, 0, sin(a) * r)
		var quer := Vector3(cos(a + 1.3), 0, sin(a + 1.3)) * zufall.randf_range(0.009, 0.018)
		var hoehe := zufall.randf_range(0.12, 0.38) * (1.4 if zufall.randf() < 0.12 else 1.0)
		var biegen := Vector3(cos(a + zufall.randf_range(-0.6, 0.6)), 0, sin(a + zufall.randf_range(-0.6, 0.6))) * hoehe * zufall.randf_range(0.2, 0.7)
		var ton: Color = toene[3] if zufall.randf() < 0.1 else toene[zufall.randi() % 3]
		ton = ton * zufall.randf_range(0.9, 1.1)
		var mitte := fuss + biegen * 0.3 + Vector3(0, hoehe * 0.55, 0)
		var spitze := fuss + biegen + Vector3(0, hoehe * (0.95 - 0.35 * biegen.length() / maxf(hoehe, 0.01)), 0)
		var unten := ton.darkened(0.4)
		var oben := ton.lightened(0.1)
		st.set_color(unten); st.add_vertex(fuss - quer)
		st.set_color(unten); st.add_vertex(fuss + quer)
		st.set_color(ton); st.add_vertex(mitte + quer * 0.7)
		st.set_color(unten); st.add_vertex(fuss - quer)
		st.set_color(ton); st.add_vertex(mitte + quer * 0.7)
		st.set_color(ton); st.add_vertex(mitte - quer * 0.7)
		st.set_color(ton); st.add_vertex(mitte - quer * 0.7)
		st.set_color(ton); st.add_vertex(mitte + quer * 0.7)
		st.set_color(oben); st.add_vertex(spitze)
	return _fertig(st)


# ---------- Detailbäume ----------
# Bäume nahe der Kamera (bis DETAIL_BIS) in der Detailfassung (werkzeuge/baum_laden.py: echte Blätter als einzelne
# Karten, feines Holz). Ihr Exemplar in der Nahfassung wird so lange auf null geschrumpft. Rückmeldung 28.11.2026:
# Äste zu dünn, Blätter wie flache Bilder.
const DETAIL_BIS := 30.0
const DETAIL_RAND := 5.0          # erst jenseits von DETAIL_BIS + DETAIL_RAND wieder zurück (kein Flackern)
const DETAIL_HOECHSTENS := 40     # je Modell
const DETAIL_RASTER := 16.0
var _detail_baeume: Array = []     # [Ort, Schlüssel (Art|Modell), MultiMesh nah, Index, Transform nah, Transform Welt]
var _detail_raster := {}          # Vector2i → Indizes in _detail_baeume
var _detail_mm := {}              # Schlüssel → MultiMesh der Detailfassung
var _detail_aktiv := {}           # Index in _detail_baeume → true
var _detail_takt := 0.0


func _detail_merken(name_: String, modelle: Array, m: int, mm: MultiMesh, liste: Array, massstab: float, mitte: Vector3) -> void:
	var schluessel := "%s|%d" % [name_, m]
	if not _detail_mm.has(schluessel):
		var dm := MultiMesh.new()
		dm.transform_format = MultiMesh.TRANSFORM_3D
		dm.mesh = modelle[m][3]
		dm.instance_count = DETAIL_HOECHSTENS
		dm.visible_instance_count = 0
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Detail_" + schluessel.replace("|", "_")
		mmi.multimesh = dm
		mmi.custom_aabb = AABB(Vector3(-100000, -1000, -100000), Vector3(200000, 4000, 200000))
		add_child(mmi)
		_detail_mm[schluessel] = dm
	for i in liste.size():
		var t: Transform3D = liste[i]
		var lokal := Transform3D(t.basis.scaled(Vector3.ONE * massstab), t.origin - mitte)
		var nr := _detail_baeume.size()
		_detail_baeume.append([t.origin, schluessel, mm, i, lokal, Transform3D(lokal.basis, t.origin)])
		var r := Vector2i(floori(t.origin.x / DETAIL_RASTER), floori(t.origin.z / DETAIL_RASTER))
		(_detail_raster.get_or_add(r, []) as Array).append(nr)


func _detail_aktualisieren(delta: float) -> void:
	if _detail_baeume.is_empty():
		return
	_detail_takt -= delta
	if _detail_takt > 0.0:
		return
	_detail_takt = 0.2
	var kamera := get_viewport().get_camera_3d()
	if kamera == null:
		return
	var k := to_local(kamera.global_position)
	# Kandidaten: nah genug (aktive dürfen bis zum Rand bleiben), je Modell die nächsten
	var je_modell := {}
	var r0 := Vector2i(floori((k.x - DETAIL_BIS - DETAIL_RAND) / DETAIL_RASTER), floori((k.z - DETAIL_BIS - DETAIL_RAND) / DETAIL_RASTER))
	var r1 := Vector2i(floori((k.x + DETAIL_BIS + DETAIL_RAND) / DETAIL_RASTER), floori((k.z + DETAIL_BIS + DETAIL_RAND) / DETAIL_RASTER))
	for rx in range(r0.x, r1.x + 1):
		for rz in range(r0.y, r1.y + 1):
			for nr: int in _detail_raster.get(Vector2i(rx, rz), []):
				var b: Array = _detail_baeume[nr]
				if not is_instance_valid(b[2]):
					continue
				var ab := (b[0] as Vector3).distance_to(k)
				var grenze := DETAIL_BIS + (DETAIL_RAND if _detail_aktiv.has(nr) else 0.0)
				if ab < grenze:
					(je_modell.get_or_add(b[1], []) as Array).append([ab, nr])
	var neu := {}
	for s: String in je_modell:
		var l: Array = je_modell[s]
		l.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
		for j in mini(l.size(), DETAIL_HOECHSTENS):
			neu[l[j][1]] = true
	# zurück in die Nahfassung
	for nr: int in _detail_aktiv:
		if not neu.has(nr):
			var b: Array = _detail_baeume[nr]
			if is_instance_valid(b[2]):
				(b[2] as MultiMesh).set_instance_transform(b[3], b[4])
	# in die Detailfassung
	var zaehler := {}
	for s: String in _detail_mm:
		zaehler[s] = 0
	for nr: int in neu:
		var b: Array = _detail_baeume[nr]
		if not _detail_aktiv.has(nr):
			(b[2] as MultiMesh).set_instance_transform(b[3], Transform3D(Basis().scaled(Vector3.ZERO), (b[4] as Transform3D).origin))
		var dm: MultiMesh = _detail_mm[b[1]]
		dm.set_instance_transform(zaehler[b[1]], b[5])
		zaehler[b[1]] += 1
	for s: String in _detail_mm:
		(_detail_mm[s] as MultiMesh).visible_instance_count = zaehler[s]
	_detail_aktiv = neu
