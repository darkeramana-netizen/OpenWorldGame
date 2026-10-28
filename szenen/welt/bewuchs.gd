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
@export var frei_kreise: PackedVector3Array = PackedVector3Array()
## Nur in diesem Rechteck (x, z, Breite, Tiefe); leer: das ganze Gelände.
@export var bereich: Rect2 = Rect2()
## Zusätzlich fest gesetzte Bäume (x, y, z, Größe), z. B. die Waldstücke an den Landstraßen.
@export var feste_baeume: PackedVector4Array = PackedVector4Array()

const RASTER := 4.0             # Prüfraster für Bäume in m
const GRAS_ZELLE := 12.0
const GRAS_RADIUS := 3          # Zellen um den Spieler
const STEIL_BAUM := 0.32        # 1 - Normale.y
const STEIL_GRAS := 0.4

var _gelaende: Node3D
var _boden_rid: RID
var _maske: Image
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
	_pflanze()
	_gras_mesh = _grasbueschel()
	_gras_material = _material(0.12, 0.0, 0.0, 0.95)
	_gras_material.set_shader_parameter("spitze_hoehe", 0.5)
	_gras_material.set_shader_parameter("boden_normale", true)
	_gras_material.set_shader_parameter("ausblenden_ab", GRAS_ZELLE * (GRAS_RADIUS - 1.2))
	_gras_material.set_shader_parameter("ausblenden_bis", GRAS_ZELLE * (GRAS_RADIUS - 0.2))


func _process(_delta: float) -> void:
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


## Darf hier etwas stehen? Gibt die Bodenhöhe zurück oder NAN.
func _platz(x: float, z: float, steil_max: float, raum: float) -> float:
	var h: float = _gelaende.hoehe_bei(x, z)
	if h < _meer + 1.2 or h > schneegrenze - 5.0:
		return NAN
	if _steilheit(x, z) > steil_max:
		return NAN
	var m := _maske_bei(x, z)
	if m.r > 0.2 or (m.g > 0.5 and raum > 1.0):
		return NAN
	if _ist_frei(x, z):
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

func _pflanze() -> void:
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
					listen[art].append(_exemplar(zufall, px, h, pz, 0.75, 1.35))
			elif wurf < (dichte + busch_dichte * (1.0 + wald)) * zelle_ha:
				var h := _platz(px, pz, STEIL_BAUM + 0.05, 0.6)
				if not is_nan(h):
					listen["busch"].append(_exemplar(zufall, px, h, pz, 0.6, 1.4))
			elif wurf < (dichte + busch_dichte * (1.0 + wald) + fels_dichte) * zelle_ha:
				var h := _platz(px, pz, 0.6, 1.0)
				if not is_nan(h):
					listen["fels"].append(_exemplar(zufall, px, h - 0.3, pz, 0.5, 2.2))
			z += RASTER
		x += RASTER
	for b in feste_baeume:
		var ex := _exemplar(zufall, b.x, b.y, b.z, b.w, b.w)
		listen["nadel" if zufall.randf() < nadel_anteil else "laub"].append(ex)
	_zeige("Nadelbaeume", _nadelbaum(), listen["nadel"], _material(0.012, 0.6, 0.0, 0.85), true)
	_zeige("Laubbaeume", _laubbaum(), listen["laub"], _material(0.015, 0.6, 0.0, 0.85), true)
	_zeige("Buesche", _busch(), listen["busch"], _material(0.04, 0.6, 0.0, 0.9), false)
	_zeige("Felsen", _fels(), listen["fels"], load("res://material/fels.tres"), false)
	for art in listen:
		anzahl[art] = listen[art].size()
	_baue_stammkollision(listen["nadel"] + listen["laub"])


func _exemplar(zufall: RandomNumberGenerator, x: float, h: float, z: float, s_min: float, s_max: float) -> Array:
	var s := zufall.randf_range(s_min, s_max)
	var basis := Basis(Vector3.UP, zufall.randf() * TAU).scaled(Vector3(s, s * zufall.randf_range(0.9, 1.15), s))
	var ton := zufall.randf_range(0.8, 1.15)
	var farbe := Color(ton * zufall.randf_range(0.92, 1.05), ton, ton * zufall.randf_range(0.9, 1.05), zufall.randf())
	return [Transform3D(basis, Vector3(x, h, z)), farbe]


func _zeige(name_: String, mesh: Mesh, exemplare: Array, material: Material, schatten: bool) -> void:
	if exemplare.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = exemplare.size()
	for i in exemplare.size():
		mm.set_instance_transform(i, exemplare[i][0])
		mm.set_instance_custom_data(i, exemplare[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = name_
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if schatten else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


## Stämme sind fest: ein Körper mit einem Zylinder je Baum.
func _baue_stammkollision(baeume: Array) -> void:
	if baeume.is_empty():
		return
	var koerper := StaticBody3D.new()
	koerper.name = "Staemme"
	var form := CylinderShape3D.new()
	form.radius = 0.35
	form.height = 4.0
	for b in baeume:
		var t: Transform3D = b[0]
		var k := CollisionShape3D.new()
		k.shape = form
		k.position = t.origin + Vector3(0, 2.0, 0)
		koerper.add_child(k)
	add_child(koerper)


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
	var anzahl_ := int(GRAS_ZELLE * GRAS_ZELLE * gras_dichte)
	var grund := Color(1.0, 1.0, 1.0) * laub_farbe
	for i in anzahl_:
		var x := (zelle.x + zufall.randf()) * GRAS_ZELLE
		var z := (zelle.y + zufall.randf()) * GRAS_ZELLE
		if bereich.size != Vector2.ZERO and not bereich.has_point(Vector2(x, z)):
			continue
		var h := _platz(x, z, STEIL_GRAS, 0.0)
		if is_nan(h):
			continue
		var ex := _exemplar(zufall, x, h - 0.05, z, 0.6, 1.4)
		var c: Color = ex[1]
		ex[1] = Color(grund.r * c.r, grund.g * c.g, grund.b * c.b, c.a)
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
	for i in 14:
		var a := zufall.randf() * TAU
		var r := zufall.randf() * 0.3
		var fuss := Vector3(cos(a) * r, 0, sin(a) * r)
		var richtung := Vector3(cos(a + 1.3), 0, sin(a + 1.3)) * 0.05
		var hoehe := zufall.randf_range(0.25, 0.55)
		var neigung := Vector3(cos(a), 0, sin(a)) * zufall.randf_range(0.08, 0.3)
		var mitte := fuss + neigung * 0.4 + Vector3(0, hoehe * 0.55, 0)
		# Halm aus zwei Stücken, unten breit, oben spitz und hell
		st.set_color(Color(0.24, 0.31, 0.12)); st.add_vertex(fuss - richtung)
		st.set_color(Color(0.24, 0.31, 0.12)); st.add_vertex(fuss + richtung)
		st.set_color(Color(0.33, 0.41, 0.16)); st.add_vertex(mitte + richtung * 0.6)
		st.set_color(Color(0.24, 0.31, 0.12)); st.add_vertex(fuss - richtung)
		st.set_color(Color(0.33, 0.41, 0.16)); st.add_vertex(mitte + richtung * 0.6)
		st.set_color(Color(0.33, 0.41, 0.16)); st.add_vertex(mitte - richtung * 0.6)
		st.set_color(Color(0.33, 0.41, 0.16)); st.add_vertex(mitte - richtung * 0.6)
		st.set_color(Color(0.33, 0.41, 0.16)); st.add_vertex(mitte + richtung * 0.6)
		st.set_color(Color(0.44, 0.48, 0.22)); st.add_vertex(fuss + neigung + Vector3(0, hoehe, 0))
	return _fertig(st)
