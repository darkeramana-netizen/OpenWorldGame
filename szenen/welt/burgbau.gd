@tool
extends Node3D
## Burgmauern, Türme und Tore aus echter Geometrie statt aus Quadern.
## Die Bauskripte (werkzeuge/bau/teil_mauern.py) legen nur Lage und Maße fest; dieses Skript baut daraus beim
## Laden die Meshes und eine Kollisionsform. Alle Materialien sind triplanar in Weltkoordinaten, darum braucht
## die Geometrie keine eigenen UVs.
##
## Ein Mauerstück hat einen Fuß mit Anlauf (schräger Sockel auf der Feldseite), ein Gesims unter dem Wehrgang,
## einen Wehrgang mit Plattenbelag und eine Brustwehr mit Zinnen und Schießscharten. Rundtürme haben Anlauf,
## Gesims und entweder ein Kegeldach mit Traufe oder einen Zinnenkranz auf Kragsteinen (Pechnasen).
## Tore sind Rundbögen durch die Mauer mit halb hochgezogenem Fallgitter; die Tortürme sind eckig.

## Je Mauerstück 10 Werte: ax, az, bx, bz, unten, oben (Wehrgang), Dicke, außen x, außen z, Zinnen (0/1)
@export var mauern := PackedFloat32Array():
	set(w):
		mauern = w
		_neu_bauen()
## Je Rundturm 7 Werte: x, z, unten, oben (Mauerkrone), Radius, Dach (0 Zinnen, 1 Kegeldach, 2 Schalenturm), Dachhöhe
## (beim Schalenturm statt der Dachhöhe die Richtung der offenen Seite in Grad)
@export var tuerme := PackedFloat32Array():
	set(w):
		tuerme = w
		_neu_bauen()
## Je Tor 8 Werte: x, z, Richtung entlang der Mauer x, z, Boden, Breite, Mauerkrone über dem Tor, Dicke
@export var tore := PackedFloat32Array():
	set(w):
		tore = w
		_neu_bauen()
## Je Torturm (auch Bergfried, Kirchturm) 10 Werte: x, z, Richtung x, z (entlang der Mauer), unten, oben, Breite
## (entlang), Tiefe, außen-Vorzeichen, Dach (0 Zinnen, ab 1 Zeltdach; größere Werte machen den Helm steiler)
@export var torbauten := PackedFloat32Array():
	set(w):
		torbauten = w
		_neu_bauen()
## Je Gebäude 12 Werte: x, z, Gier, Breite (lokal x), Länge (lokal z, Firstrichtung), Boden, unten, Traufhöhe über
## dem Boden, Dachhöhe, Wand (0 Stein dieses Baus, 1 hell, 2 Mauer, 3 Holz), Dach (0 Schiefer, 1 Ziegel), Art (0 Wohnbau,
## 1 Kirche/Saal mit hohen Fenstern, 2 Lager ohne Fenster oben)
@export var gebaeude := PackedFloat32Array():
	set(w):
		gebaeude = w
		_neu_bauen()
## Je Treppe 7 Werte: Anfang x, z, y, Ende x, z, y, Breite. Stufen mit Wangen; begehbar über eine unsichtbare Rampe auf den Stufenkanten.
@export var treppen := PackedFloat32Array():
	set(w):
		treppen = w
		_neu_bauen()
## Ohne Kollision: nur Optik (z. B. über den alten Hofmauern aus Akt I, deren Körper bleiben)
## Fahnen und Banner (fahne.gdshader): je 7 Werte x, y, z, Gier, Breite, Länge, Art. Art 0: Fahne an einem Mast
## (y = Fuß des Masts), weht nach lokal +x; Art 1: Banner an einer Wand (y = Oberkante), hängt herab, Wand hinter lokal -z.
@export var fahnen := PackedFloat32Array():
	set(w):
		fahnen = w
		_neu_bauen()
## Hafenhallen (Untergrundhafen): je 13 Werte x, z (Mitte der Mündung), Richtung in den Berg x, z, Länge, Breite,
## Beckenbreite, Kanalbreite, Boden (Kaihöhe), Wandhöhe, Stich des Gewölbes, Breite und Boden des Wassertors davor.
## Eine Halle mit Tonnengewölbe und Gurtbögen über einem Becken, Kais rundum, Lagernischen, ein Gang bis in das Tor.
@export var hallen := PackedFloat32Array():
	set(w):
		hallen = w
		_neu_bauen()
## Meereshöhlen an der Klippe: je 7 Werte x, z (Fuß der Öffnung am Wasser), außen x, z (waagrecht, vom Fels weg), Steigung
## des Felsens (Meter Höhe je Meter in den Fels), Breite, Höhe. Dunkle Öffnung mit Felsrand, die sich an den schrägen
## Fels legt, davor ein Steinpodest knapp über dem Wasser und Stufen am Fels hinauf.
@export var hoehlen := PackedFloat32Array():
	set(w):
		hoehlen = w
		_neu_bauen()
@export var kollision := true:
	set(w):
		kollision = w
		_neu_bauen()
## Steinart der Mauern: Name eines Materials in material/ (mauer, basalt, kai, hell, bruchstein)
@export var stein := "mauer":
	set(w):
		stein = w
		_neu_bauen()

const ZINNE_BREITE := 1.5
const ZINNE_ABSTAND := 2.5
const BRUSTWEHR := 1.1       # Höhe der Brustwehr über dem Wehrgang
const HOHL_WAND := 2.5       # Mauerstärke eines begehbaren Bergfrieds
const HOHL_TUER := 3.0
## Fußboden im Erdgeschoss eines begehbaren Bergfrieds (Torbau mit Dach -2)
@export var hohl_boden := 0.0
const ZINNE_HOEHE := 1.5     # Zinnen darüber
const BRUSTWEHR_DICKE := 0.6
const KAEMPFER := 3.4        # Höhe, in der der Torbogen ansetzt

var _flach := {}   # Material → SurfaceTool, Normalen werden erzeugt (kantig)
var _rund := {}    # Material → SurfaceTool, Normalen von Hand (glatte Rundungen)
var _bereit := false


func _ready() -> void:
	_bereit = true
	_baue()


func _neu_bauen() -> void:
	if _bereit:
		_baue()


func _baue() -> void:
	for k in get_children():
		k.free()
	_flach = {}
	_rund = {}
	var i := 0
	while i + 9 < mauern.size():
		_mauerstueck(Vector2(mauern[i], mauern[i + 1]), Vector2(mauern[i + 2], mauern[i + 3]), mauern[i + 4],
			mauern[i + 5], mauern[i + 6], Vector2(mauern[i + 7], mauern[i + 8]), mauern[i + 9] > 0.5)
		i += 10
	i = 0
	while i + 6 < tuerme.size():
		if int(tuerme[i + 5]) == 2:
			_schalenturm(Vector2(tuerme[i], tuerme[i + 1]), tuerme[i + 2], tuerme[i + 3], tuerme[i + 4], deg_to_rad(tuerme[i + 6]))
		else:
			_rundturm(Vector2(tuerme[i], tuerme[i + 1]), tuerme[i + 2], tuerme[i + 3], tuerme[i + 4], int(tuerme[i + 5]), tuerme[i + 6])
		i += 7
	i = 0
	while i + 7 < tore.size():
		_tor(Vector2(tore[i], tore[i + 1]), Vector2(tore[i + 2], tore[i + 3]), tore[i + 4], tore[i + 5], tore[i + 6], tore[i + 7])
		i += 8
	i = 0
	while i + 9 < torbauten.size():
		_torturm(Vector2(torbauten[i], torbauten[i + 1]), Vector2(torbauten[i + 2], torbauten[i + 3]), torbauten[i + 4],
			torbauten[i + 5], torbauten[i + 6], torbauten[i + 7], torbauten[i + 8], torbauten[i + 9])
		i += 10
	i = 0
	while i + 6 < treppen.size():
		_treppe(Vector3(treppen[i], treppen[i + 2], treppen[i + 1]), Vector3(treppen[i + 3], treppen[i + 5], treppen[i + 4]), treppen[i + 6])
		i += 7
	i = 0
	while i + 11 < gebaeude.size():
		_gebaeude(gebaeude.slice(i, i + 12))
		i += 12
	i = 0
	while i + 12 < hallen.size():
		_halle(hallen.slice(i, i + 13))
		i += 13
	i = 0
	while i + 6 < hoehlen.size():
		_hoehle(hoehlen.slice(i, i + 7))
		i += 7
	_fahnen_bauen()
	if _flach.is_empty() and _rund.is_empty():
		return

	var mesh := ArrayMesh.new()
	var fest := ArrayMesh.new()   # nur Stein und Boden: Fallgitter und Schießscharten halten niemanden auf
	for mat: String in _flach:
		var st: SurfaceTool = _flach[mat]
		if mat == "rampe":
			st.commit(fest)   # unsichtbare Lauffläche über Treppenstufen, nur Kollision
			continue
		st.generate_normals()
		if mat.ends_with("_uv"):
			st.generate_tangents()   # für die Normalenkarte der Dächer
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material(mat))
		if not mat.begins_with("metall") and mat != "dunkel" and not mat.begins_with("zier_"):
			st.commit(fest)
	for mat: String in _rund:
		var st: SurfaceTool = _rund[mat]
		if mat.ends_with("_uv"):
			st.generate_tangents()   # Kegeldächer: ohne Tangenten wird die Schieferstruktur falsch schattiert
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material(mat))
		if not mat.begins_with("metall") and mat != "dunkel" and not mat.begins_with("zier_"):
			st.commit(fest)
	var anzeige := MeshInstance3D.new()
	anzeige.name = "Mesh"
	anzeige.mesh = mesh
	add_child(anzeige)
	if not kollision:
		return
	var koerper := StaticBody3D.new()
	koerper.name = "Kollision"
	var form := CollisionShape3D.new()
	form.shape = fest.create_trimesh_shape()
	koerper.add_child(form)
	add_child(koerper)


## Fahnen: Mast (Holz, mit Knauf) in die Mauerteile, das Tuch als eigenes Mesh mit dem Wind-Shader.
func _fahnen_bauen() -> void:
	var tuecher := {0: SurfaceTool.new(), 1: SurfaceTool.new()}
	var benutzt := {0: false, 1: false}
	for st: SurfaceTool in tuecher.values():
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var i := 0
	while i + 6 < fahnen.size():
		var fuss := Vector3(fahnen[i], fahnen[i + 1], fahnen[i + 2])
		var g := deg_to_rad(fahnen[i + 3])
		var breite := fahnen[i + 4]
		var laenge := fahnen[i + 5]
		var art := int(fahnen[i + 6])
		var ux := Vector3(cos(g), 0, -sin(g))      # lokal x
		var uz := Vector3(sin(g), 0, cos(g))       # lokal z
		var c2 := Vector2(fuss.x, fuss.z)
		var u2 := Vector2(ux.x, ux.z)
		var n2 := Vector2(uz.x, uz.z)
		var oben: float
		var start: Vector3
		var richtung: Vector3
		var quer: Vector3
		if art == 0:
			var mast := laenge * 0.9 + breite + 2.0
			_klotz("holz", c2, u2, n2, -0.09, 0.09, -0.09, 0.09, fuss.y, fuss.y + mast)
			_kegel("metall", c2, 0.16, fuss.y + mast, 0.45, 8)
			oben = fuss.y + mast - 0.25
			start = Vector3(fuss.x, oben, fuss.z)
			richtung = ux * laenge
			quer = Vector3.DOWN * breite
		else:
			# Stange oben an der Wand
			_klotz("holz", c2 + n2 * 0.25, u2, n2, -breite * 0.55, breite * 0.55, -0.05, 0.05, fuss.y - 0.06, fuss.y + 0.06)
			start = Vector3(fuss.x, fuss.y, fuss.z) + uz * 0.25 - ux * breite * 0.5
			richtung = Vector3.DOWN * laenge
			quer = ux * breite
		var st: SurfaceTool = tuecher[art]
		benutzt[art] = true
		var teile_l := 12
		var teile_q := 4
		var normale := uz if art == 1 else Vector3(0, 0, 0) + uz
		for a in teile_l:
			for b in teile_q:
				var p := func(ia: int, ib: int) -> Vector3:
					return start + richtung * (float(ia) / teile_l) + quer * (float(ib) / teile_q)
				var t := func(ia: int, ib: int) -> Vector2:
					return Vector2(float(ia) / teile_l, float(ib) / teile_q)
				for e in [[a, b], [a + 1, b], [a + 1, b + 1], [a, b], [a + 1, b + 1], [a, b + 1]]:
					st.set_normal(normale)
					st.set_uv(t.call(e[0], e[1]))
					st.add_vertex(p.call(e[0], e[1]))
		i += 7
	for art: int in tuecher:
		if not benutzt[art]:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Tuch%d" % art
		mi.mesh = tuecher[art].commit()
		var mat := ShaderMaterial.new()
		mat.shader = load("res://szenen/welt/fahne.gdshader")
		mat.set_shader_parameter("art", float(art))
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		add_child(mi)


# ---------- Grundformen ----------

func _st(mat: String, rund := false) -> SurfaceTool:
	var d := _rund if rund else _flach
	if not d.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		if not rund:
			st.set_smooth_group(-1)   # kantig: sonst glättet generate_normals über die Kanten hinweg
		d[mat] = st
	return d[mat]


## Viereck, die Vorderseite zeigt nach "aussen" (beliebige Richtung, die Reihenfolge wird passend gedreht).
func _viereck(mat: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, aussen: Vector3) -> void:
	var st := _st(mat)
	# Normale über die Diagonalen: bleibt richtig, wenn zwei Ecken zusammenfallen (Kreisscheiben aus _ring mit r0 = 0,
	# z. B. die Turmböden; sonst zeigten sie nach unten und waren von oben unsichtbar)
	var n := (c - a).cross(d - b)
	if n.dot(aussen) > 0.0:
		for p in [a, c, b, a, d, c]:
			st.add_vertex(p)
	else:
		for p in [a, b, c, a, c, d]:
			st.add_vertex(p)


## Viereck mit eigenen UV (in Metern): für Dachflächen, damit Ziegel- und Schieferreihen waagrecht liegen.
func _viereck_uv(mat: String, p: Array, uv: Array, aussen: Vector3) -> void:
	var st := _st(mat + "_uv")
	var reihe := [0, 2, 1, 0, 3, 2] if (p[1] - p[0]).cross(p[2] - p[0]).dot(aussen) > 0.0 else [0, 1, 2, 0, 2, 3]
	for i in reihe:
		st.set_uv(uv[i])
		st.add_vertex(p[i])


func _dreieck_uv(mat: String, p: Array, uv: Array, aussen: Vector3) -> void:
	var st := _st(mat + "_uv")
	var reihe := [0, 2, 1] if (p[1] - p[0]).cross(p[2] - p[0]).dot(aussen) > 0.0 else [0, 1, 2]
	for i in reihe:
		st.set_uv(uv[i])
		st.add_vertex(p[i])


func _dreieck(mat: String, a: Vector3, b: Vector3, c: Vector3, aussen: Vector3) -> void:
	var st := _st(mat)
	if (b - a).cross(c - a).dot(aussen) > 0.0:
		for p in [a, c, b]:
			st.add_vertex(p)
	else:
		for p in [a, b, c]:
			st.add_vertex(p)


## Quader in einem gedrehten Rahmen: Mitte m (x, z), Achsen u und n (Einheitsvektoren in der Ebene),
## Ausdehnung von u0 bis u1 entlang u, n0 bis n1 entlang n, y0 bis y1.
func _klotz(mat: String, m: Vector2, u: Vector2, n: Vector2, u0: float, u1: float, n0: float, n1: float,
		y0: float, y1: float, unterseite := false) -> void:
	var p := func(su: float, sn: float, y: float) -> Vector3:
		var q := m + u * su + n * sn
		return Vector3(q.x, y, q.y)
	var U := Vector3(u.x, 0, u.y)
	var N := Vector3(n.x, 0, n.y)
	_viereck(mat, p.call(u0, n1, y0), p.call(u1, n1, y0), p.call(u1, n1, y1), p.call(u0, n1, y1), N)
	_viereck(mat, p.call(u0, n0, y0), p.call(u1, n0, y0), p.call(u1, n0, y1), p.call(u0, n0, y1), -N)
	_viereck(mat, p.call(u1, n0, y0), p.call(u1, n1, y0), p.call(u1, n1, y1), p.call(u1, n0, y1), U)
	_viereck(mat, p.call(u0, n0, y0), p.call(u0, n1, y0), p.call(u0, n1, y1), p.call(u0, n0, y1), -U)
	_viereck(mat, p.call(u0, n0, y1), p.call(u1, n0, y1), p.call(u1, n1, y1), p.call(u0, n1, y1), Vector3.UP)
	if unterseite:
		_viereck(mat, p.call(u0, n0, y0), p.call(u1, n0, y0), p.call(u1, n1, y0), p.call(u0, n1, y0), Vector3.DOWN)


## Mantel eines Kegelstumpfs mit glatten Normalen (r0 unten bei y0, r1 oben bei y1).
func _mantel(mat: String, c: Vector2, r0: float, r1: float, y0: float, y1: float, teile: int, innen := false) -> void:
	var st := _st(mat, true)
	var steig := (r0 - r1) / maxf(y1 - y0, 0.001)
	for k in teile:
		var w0 := TAU * k / teile
		var w1 := TAU * (k + 1) / teile
		var d0 := Vector3(cos(w0), 0, sin(w0))
		var d1 := Vector3(cos(w1), 0, sin(w1))
		var n0 := (d0 + Vector3(0, steig, 0)).normalized() * (-1.0 if innen else 1.0)
		var n1 := (d1 + Vector3(0, steig, 0)).normalized() * (-1.0 if innen else 1.0)
		var a := Vector3(c.x, y0, c.y) + d0 * r0
		var b := Vector3(c.x, y0, c.y) + d1 * r0
		var e := Vector3(c.x, y1, c.y) + d1 * r1
		var f := Vector3(c.x, y1, c.y) + d0 * r1
		# Vorderseite nach außen (bzw. innen): sonst blendet Godot die Wand aus und man sieht die dunkle Rückwand
		var reihe := [[a, n0], [b, n1], [e, n1], [a, n0], [e, n1], [f, n0]]
		if innen:
			reihe = [[a, n0], [e, n1], [b, n1], [a, n0], [f, n0], [e, n1]]
		for v: Array in reihe:
			st.set_normal(v[1])
			st.add_vertex(v[0])


## Waagrechter Ring (Kreisring) zwischen r0 und r1 in Höhe y, Vorderseite nach oben oder unten.
func _ring(mat: String, c: Vector2, r0: float, r1: float, y: float, teile: int, nach_oben := true) -> void:
	for k in teile:
		var w0 := TAU * k / teile
		var w1 := TAU * (k + 1) / teile
		var d0 := Vector3(cos(w0), 0, sin(w0))
		var d1 := Vector3(cos(w1), 0, sin(w1))
		var m := Vector3(c.x, y, c.y)
		_viereck(mat, m + d0 * r0, m + d1 * r0, m + d1 * r1, m + d0 * r1, Vector3.UP if nach_oben else Vector3.DOWN)


## Kegel (Dach) mit glatten Normalen, Spitze bei y + h.
func _kegel(mat: String, c: Vector2, r: float, y: float, h: float, teile: int) -> void:
	var st := _st(mat + "_uv", true)
	var schraege := Vector2(r, h).length()
	var spitze := Vector3(c.x, y + h, c.y)
	for k in teile:
		var w0 := TAU * k / teile
		var w1 := TAU * (k + 1) / teile
		var d0 := Vector3(cos(w0), 0, sin(w0))
		var d1 := Vector3(cos(w1), 0, sin(w1))
		var n0 := (d0 * h + Vector3(0, r, 0)).normalized()
		var n1 := (d1 * h + Vector3(0, r, 0)).normalized()
		var nm := (n0 + n1).normalized()
		var a := Vector3(c.x, y, c.y) + d0 * r
		var b := Vector3(c.x, y, c.y) + d1 * r
		var bogen := TAU * r / teile
		for v: Array in [[a, n0, Vector2(k * bogen, schraege)], [b, n1, Vector2((k + 1) * bogen, schraege)], [spitze, nm, Vector2((k + 0.5) * bogen, 0.0)]]:
			st.set_normal(v[1])
			st.set_uv(v[2])
			st.add_vertex(v[0])


# ---------- Bauteile ----------

## Zinnen mit Schießscharten entlang einer Linie (außen ist die Feldseite).
func _zinnen(m: Vector2, u: Vector2, n: Vector2, laenge: float, n0: float, n1: float, y: float) -> void:
	var anzahl := int(laenge / ZINNE_ABSTAND)
	if anzahl < 1:
		return
	var rest := (laenge - anzahl * ZINNE_ABSTAND) / 2.0
	for k in anzahl:
		var mitte := -laenge / 2.0 + rest + (k + 0.5) * ZINNE_ABSTAND
		_klotz(stein, m, u, n, mitte - ZINNE_BREITE / 2, mitte + ZINNE_BREITE / 2, n0, n1, y, y + ZINNE_HOEHE)
		# Schießscharte: schmaler dunkler Schlitz auf der Feldseite
		_klotz("dunkel", m, u, n, mitte - 0.07, mitte + 0.07, n1 - 0.02, n1 + 0.015, y + 0.25, y + 1.0)


func _mauerstueck(a: Vector2, b: Vector2, unten: float, oben: float, dicke: float, aussen: Vector2, zinnen: bool) -> void:
	var laenge := a.distance_to(b)
	if laenge < 0.2:
		return
	var u := (b - a) / laenge
	var n := Vector2(-u.y, u.x)
	if n.dot(aussen) < 0.0:
		n = -n
	var m := (a + b) / 2.0
	var l := laenge / 2.0 + dicke * 0.5   # an Ecken überlappen, damit keine Lücken klaffen
	var h := oben - unten
	var d := dicke / 2.0
	# Mauerkörper
	_klotz(stein, m, u, n, -l, l, -d, d, unten, oben)
	if not zinnen:
		return
	# Anlauf: schräger Sockel auf der Feldseite
	if h > 4.0:
		var vor := clampf(h * 0.1, 0.6, 1.6)
		var hoch := clampf(h * 0.3, 2.0, 6.0)
		var p := func(su: float, sn: float, y: float) -> Vector3:
			var q := m + u * su + n * sn
			return Vector3(q.x, y, q.y)
		var N := Vector3(n.x, 0, n.y)
		_viereck(stein, p.call(-l, d + vor, unten), p.call(l, d + vor, unten), p.call(l, d, unten + hoch), p.call(-l, d, unten + hoch),
			(N + Vector3.UP * vor / hoch).normalized())
		_dreieck(stein, p.call(-l, d, unten), p.call(-l, d + vor, unten), p.call(-l, d, unten + hoch), Vector3(-u.x, 0, -u.y))
		_dreieck(stein, p.call(l, d, unten), p.call(l, d + vor, unten), p.call(l, d, unten + hoch), Vector3(u.x, 0, u.y))
	# Gesims unter der Brustwehr
	_klotz(stein, m, u, n, -l, l, d - 0.1, d + 0.22, oben - 0.5, oben - 0.2, true)
	# Wehrgang mit Plattenbelag
	_klotz("boden", m, u, n, -l, l, -d + 0.05, d - BRUSTWEHR_DICKE, oben, oben + 0.06)
	# Brustwehr und Zinnen auf der Feldseite, eine niedrige Mauer auf der Hofseite
	_klotz(stein, m, u, n, -l, l, d - BRUSTWEHR_DICKE, d, oben, oben + BRUSTWEHR)
	_klotz(stein, m, u, n, -l, l, -d, -d + 0.35, oben, oben + 0.6)
	_zinnen(m, u, n, laenge, d - BRUSTWEHR_DICKE, d, oben + BRUSTWEHR)


func _rundturm(c: Vector2, unten: float, oben: float, r: float, dach: int, dachhoehe: float) -> void:
	var teile := 28 if r > 4.0 else 20
	var h := oben - unten
	var vor := clampf(h * 0.08, 0.5, 1.5)
	var hoch := clampf(h * 0.25, 2.0, 7.0)
	_mantel(stein, c, r + vor, r, unten, unten + hoch, teile)
	_mantel(stein, c, r, r, unten + hoch, oben, teile)
	# Gesims
	_mantel(stein, c, r + 0.25, r + 0.25, oben - 0.55, oben - 0.25, teile)
	_ring(stein, c, r, r + 0.25, oben - 0.55, teile, false)
	_ring(stein, c, r, r + 0.25, oben - 0.25, teile, true)
	# Schießscharten in zwei Reihen
	for reihe in 2:
		var y := unten + hoch + (h - hoch) * (0.3 + 0.35 * reihe)
		for k in 4:
			var w := TAU * (k + 0.5 * reihe) / 4.0 + 0.4
			var d := Vector2(cos(w), sin(w))
			var t := Vector2(-d.y, d.x)
			_klotz("dunkel", c + d * (r - 0.05), t, d, -0.08, 0.08, 0.0, 0.08, y - 0.6, y + 0.6)
	if dach == 1:
		# Kegeldach mit Traufe und Knauf
		# Traufkranz: ein schmaler Mauerring, auf dem das Dach mit kurzem Überstand sitzt
		_ring("dach", c, r - 0.1, r + 0.35, oben, teile, false)
		_kegel("dach", c, r + 0.35, oben, dachhoehe, teile)
		_kegel("metall", c, 0.25, oben + dachhoehe - 0.3, 1.4, 8)
		_ring(stein, c, 0.0, r, oben, teile, true)
	else:
		# Zinnenkranz auf Kragsteinen
		var ri := r + 0.1
		var ra := r + 0.7
		for k in teile:
			var w := TAU * (k + 0.5) / teile
			var d := Vector2(cos(w), sin(w))
			_klotz(stein, c + d * r, Vector2(-d.y, d.x), d, -0.22, 0.22, -0.1, 0.7, oben - 1.1, oben)
		_mantel(stein, c, ra, ra, oben, oben + BRUSTWEHR, teile)
		_mantel(stein, c, ri, ri, oben, oben + BRUSTWEHR, teile, true)
		_ring(stein, c, ri, ra, oben + BRUSTWEHR, teile, true)
		_ring(stein, c, r, ra, oben, teile, false)
		_ring("boden", c, 0.0, ri, oben + 0.05, teile, true)
		var zinnen := maxi(6, int(TAU * ra / ZINNE_ABSTAND))
		for k in zinnen:
			var w := TAU * k / zinnen
			var d := Vector2(cos(w), sin(w))
			_klotz(stein, c + d * (ri + ra) / 2.0, Vector2(-d.y, d.x), d, -0.65, 0.65, -0.3, 0.3, oben + BRUSTWEHR, oben + BRUSTWEHR + ZINNE_HOEHE)


## Schalenturm (dach 2): halbrund vor die Mauer gestellt und zur Innenseite offen (Richtung innen_winkel), wie an der
## Ringmauer im Referenzbild. Die Schale ist 1,4 m dick, oben ein Zinnenkranz; innen auf Höhe des Wehrgangs (3 m unter
## der Krone) ein Bretterboden, damit der Wehrgang durch den Turm weiterläuft.
func _schalenturm(c: Vector2, unten: float, oben: float, r: float, innen_winkel: float) -> void:
	var teile := 24
	var dicke := 1.4
	var ri := r - dicke
	var st_aussen := _st(stein, true)
	var w_start := innen_winkel + PI * 0.5          # die offene Hälfte zeigt nach innen
	var schritte := teile / 2
	var punkte := func(rad: float, y: float, k: int) -> Vector3:
		var w := w_start + PI * k / schritte
		return Vector3(c.x + cos(w) * rad, y, c.y + sin(w) * rad)
	var anlauf := clampf((oben - unten) * 0.25, 2.0, 6.0)
	for k in schritte:
		var w0 := w_start + PI * k / schritte
		var w1 := w_start + PI * (k + 1) / schritte
		var d0 := Vector3(cos(w0), 0, sin(w0))
		var d1 := Vector3(cos(w1), 0, sin(w1))
		# außen mit Anlauf unten, innen senkrecht
		var g0 := (d0 + Vector3(0, 0.6 / anlauf, 0)).normalized()
		var g1 := (d1 + Vector3(0, 0.6 / anlauf, 0)).normalized()
		for lage: Array in [[unten, unten + anlauf, r + 0.6, r, g0, g1], [unten + anlauf, oben, r, r, d0, d1]]:
			var y0: float = lage[0]
			var y1: float = lage[1]
			var a := Vector3(c.x, y0, c.y) + d0 * float(lage[2])
			var b := Vector3(c.x, y0, c.y) + d1 * float(lage[2])
			var e := Vector3(c.x, y1, c.y) + d1 * float(lage[3])
			var f := Vector3(c.x, y1, c.y) + d0 * float(lage[3])
			var na: Vector3 = lage[4]
			var nb: Vector3 = lage[5]
			for v: Array in [[a, na], [b, nb], [e, nb], [a, na], [e, nb], [f, na]]:
				st_aussen.set_normal(v[1])
				st_aussen.add_vertex(v[0])
		var ia := Vector3(c.x, unten, c.y) + d0 * ri
		var ib := Vector3(c.x, unten, c.y) + d1 * ri
		var ie := Vector3(c.x, oben, c.y) + d1 * ri
		var iff := Vector3(c.x, oben, c.y) + d0 * ri
		for v: Array in [[ia, -d0], [ie, -d1], [ib, -d1], [ia, -d0], [iff, -d0], [ie, -d1]]:
			st_aussen.set_normal(v[1])
			st_aussen.add_vertex(v[0])
		# Mauerkrone der Schale
		_viereck(stein, Vector3(c.x, oben, c.y) + d0 * ri, Vector3(c.x, oben, c.y) + d1 * ri,
			Vector3(c.x, oben, c.y) + d1 * r, Vector3(c.x, oben, c.y) + d0 * r, Vector3.UP)
		# Zinnen auf jeder zweiten Teilung
		if k % 2 == 0:
			var dm := (d0 + d1).normalized()
			var mp := c + Vector2(dm.x, dm.z) * (r - dicke * 0.5)
			_klotz(stein, mp, Vector2(-dm.z, dm.x), Vector2(dm.x, dm.z), -0.7, 0.7, -dicke * 0.5, dicke * 0.5, oben, oben + ZINNE_HOEHE)
	# Stirnflächen der offenen Schale
	for k: int in [0, schritte]:
		var a: Vector3 = punkte.call(ri, unten, k)
		var b: Vector3 = punkte.call(r, unten, k)
		var e: Vector3 = punkte.call(r, oben, k)
		var f: Vector3 = punkte.call(ri, oben, k)
		var aussen := Vector3(cos(innen_winkel), 0, sin(innen_winkel))
		_viereck(stein, a, b, e, f, aussen)
		# Keil des Anlaufs (r bis r + 0,6) an der Stirnseite
		var ka: Vector3 = punkte.call(r, unten, k)
		var kb: Vector3 = punkte.call(r + 0.6, unten, k)
		var kc: Vector3 = punkte.call(r, unten + anlauf, k)
		_dreieck(stein, ka, kb, kc, aussen)
	# Bretterboden auf Höhe des Wehrgangs (halbe Scheibe; die Schale reicht 2,5 m über den Wehrgang)
	var yb := oben - 2.5
	for k in schritte:
		var w0 := w_start + PI * k / schritte
		var w1 := w_start + PI * (k + 1) / schritte
		var m := Vector3(c.x, yb, c.y)
		_dreieck("holz", m, m + Vector3(cos(w0), 0, sin(w0)) * ri, m + Vector3(cos(w1), 0, sin(w1)) * ri, Vector3.UP)
	# Schießscharten
	for k: int in [2, 6, 10]:
		var w: float = w_start + PI * (k + 0.5) / schritte
		var d := Vector2(cos(w), sin(w))
		_klotz("dunkel", c + d * (r - 0.05), Vector2(-d.y, d.x), d, -0.08, 0.08, 0.0, 0.08, yb + 0.4, yb + 1.6)


## Erkertürmchen: rund, unten auf einem kegelförmigen Kragstein, Schießscharten, Gesims und spitzes Kegeldach.
func _erkerturm(c: Vector2, mat: String, unten: float, oben: float, r: float, dachhoehe: float) -> void:
	var teile := 16
	_mantel(mat, c, 0.25, r, unten, unten + 1.8, teile)
	for k in 4:
		var w := TAU * (k + 0.5) / 4.0
		var d := Vector2(cos(w), sin(w))
		_klotz(mat, c + d * r * 0.7, Vector2(-d.y, d.x), d, -0.15, 0.15, -0.2, r * 0.32, unten + 0.6, unten + 1.85)
	_mantel(mat, c, r, r, unten + 1.8, oben, teile)
	_mantel(mat, c, r + 0.18, r + 0.18, oben - 0.4, oben - 0.15, teile)
	_ring(mat, c, r, r + 0.18, oben - 0.4, teile, false)
	for k in 3:
		var w := TAU * k / 3.0 + 0.5
		var d := Vector2(cos(w), sin(w))
		_klotz("dunkel", c + d * (r - 0.04), Vector2(-d.y, d.x), d, -0.06, 0.06, 0.0, 0.06, (unten + oben) / 2.0 - 0.4, (unten + oben) / 2.0 + 0.5)
	_ring("dach", c, r - 0.1, r + 0.3, oben, teile, false)
	_kegel("dach", c, r + 0.3, oben, dachhoehe, teile)
	_kegel("metall", c, 0.12, oben + dachhoehe - 0.2, 0.9, 6)
	_ring(mat, c, 0.0, r, oben, teile, true)


## Untergrundhafen: gewölbte Halle im Fels (lokal: s in den Berg, q quer, y Höhe). Der Fels darüber ist das Gelände;
## die Halle schließt sich nach oben mit einer Platte, damit kein Sonnenlicht hineinfällt. Werte: x, z, Richtung x, z,
## Länge, Breite, Beckenbreite, Kanalbreite (im Gang), Boden, Wandhöhe, Stich, Torbreite, Torboden.
func _halle(w: PackedFloat32Array) -> void:
	var c := Vector2(w[0], w[1])
	var u := Vector2(w[2], w[3]).normalized()
	var n := Vector2(-u.y, u.x)
	var L := w[4]
	var hb := w[5] / 2.0
	var hw := w[6] / 2.0                        # halbes Becken in der Halle
	var hk := w[7] / 2.0                        # halber Kanal im Gang
	var boden := w[8]
	var kaempfer := boden + w[9]
	var stich := w[10]
	var tw := w[11] / 2.0                       # halbe Torbreite
	var tor_k := w[12] + KAEMPFER               # Kämpfer des Torbogens
	var scheitel := kaempfer + stich
	var grund := boden - 6.5                    # Beckengrund
	var kante := 0.6                            # Kantensteine am Wasser
	var be := L - 8.0                           # Ende des Beckens, dahinter der Querkai
	var mauer := 1.5
	var gang := 3.2                             # Gang von der Halle durch die Ringmauer
	var trichter := 5.0                         # bis hier ist das Wasser so schmal wie der Kanal, dann weitet es sich
	var nische_t := 3.2                         # Tiefe der Lagernischen
	var nische_h := 3.4
	var joch := 6.0
	var U := Vector3(u.x, 0, u.y)
	var N := Vector3(n.x, 0, n.y)
	var p := func(su: float, sq: float, y: float) -> Vector3:
		var q := c + u * su + n * sq
		return Vector3(q.x, y, q.y)
	var seitlich := func(sq: float, a: float, b: float) -> Vector2:   # q-Bereich a..b auf der Seite sq
		return Vector2(minf(sq * a, sq * b), maxf(sq * a, sq * b))
	# Beckengrund (bis unter die Kanalmündung)
	_klotz("fels", c, u, n, -gang - 4.5, be, -hw, hw, grund - 0.5, grund)
	for sq: float in [-1.0, 1.0]:
		# Kais: im Gang und bis zum Absatz schmal am Kanal, dahinter breit um das Becken
		var g: Vector2 = seitlich.call(sq, hk + kante, hb)
		_klotz("kai", c, u, n, -gang, trichter, g.x, g.y, grund, boden)
		g = seitlich.call(sq, hk, hk + kante)
		_klotz("kai", c, u, n, -gang, trichter + kante, g.x, g.y, grund, boden - 0.35)
		_klotz("hell", c, u, n, -gang, trichter + kante, g.x, g.y, boden - 0.35, boden)
		g = seitlich.call(sq, hk + kante, hw + kante)
		_klotz("kai", c, u, n, trichter, trichter + kante, g.x, g.y, grund, boden - 0.35)
		_klotz("hell", c, u, n, trichter, trichter + kante, g.x, g.y, boden - 0.35, boden)
		g = seitlich.call(sq, hw + kante, hb)
		_klotz("kai", c, u, n, trichter, L, g.x, g.y, grund, boden)
		g = seitlich.call(sq, hw, hw + kante)
		_klotz("kai", c, u, n, trichter + kante, be, g.x, g.y, grund, boden - 0.35)
		_klotz("hell", c, u, n, trichter + kante, be, g.x, g.y, boden - 0.35, boden)
	_klotz("kai", c, u, n, be + kante, L, -hw - kante, hw + kante, grund, boden)
	_klotz("kai", c, u, n, be, be + kante, -hw, hw, grund, boden - 0.35)
	_klotz("hell", c, u, n, be, be + kante, -hw, hw, boden - 0.35, boden)
	# Seitenwände mit Lagernischen zwischen den Wandpfeilern, Rückwand, Stirnwand neben und über dem Gang
	for sq: float in [-1.0, 1.0]:
		var wand: Vector2 = seitlich.call(sq, hb, hb + mauer)
		_klotz("bruchstein", c, u, n, -mauer, L + mauer, wand.x, wand.y, boden + nische_h, scheitel + 1.2)
		_klotz("bruchstein", c, u, n, -mauer, L + mauer, wand.x, wand.y, grund, boden)
		var s_ := 0.0
		var ende := 0.0
		while s_ < L:
			var a := s_ + 1.0
			var b := minf(s_ + joch - 1.0, L)
			_klotz("bruchstein", c, u, n, ende - (mauer if ende == 0.0 else 0.0), a, wand.x, wand.y, boden, boden + nische_h)
			if b - a > 2.0 and s_ + joch <= L:
				var tief: Vector2 = seitlich.call(sq, hb, hb + nische_t)
				var rueck: Vector2 = seitlich.call(sq, hb + nische_t, hb + nische_t + mauer)
				_klotz("kai", c, u, n, a, b, tief.x, tief.y, grund, boden)
				_klotz("bruchstein", c, u, n, a - 0.4, b + 0.4, rueck.x, rueck.y, boden, boden + nische_h + 0.6)
				_klotz("bruchstein", c, u, n, a - 0.4, a, tief.x, tief.y, boden, boden + nische_h + 0.6)
				_klotz("bruchstein", c, u, n, b, b + 0.4, tief.x, tief.y, boden, boden + nische_h + 0.6)
				_klotz("bruchstein", c, u, n, a, b, tief.x, tief.y, boden + nische_h, boden + nische_h + 0.6, true)
				# Sturz über der Nische in hellem Stein
				_klotz("hell", c, u, n, a - 0.15, b + 0.15, seitlich.call(sq, hb - 0.08, hb + 0.3).x, seitlich.call(sq, hb - 0.08, hb + 0.3).y,
					boden + nische_h - 0.05, boden + nische_h + 0.45, true)
				ende = b
			else:
				ende = a
			s_ += joch
		_klotz("bruchstein", c, u, n, ende, L + mauer, wand.x, wand.y, boden, boden + nische_h)
		_klotz("bruchstein", c, u, n, -mauer, 0.0, seitlich.call(sq, tw, hb).x, seitlich.call(sq, tw, hb).y, boden, scheitel + 1.2)
		# Gangwände unter dem Bogen
		_klotz("bruchstein", c, u, n, -gang, 0.0, seitlich.call(sq, tw, tw + 1.0).x, seitlich.call(sq, tw, tw + 1.0).y, boden, tor_k)
	_klotz("bruchstein", c, u, n, L, L + mauer, -hb - mauer, hb + mauer, grund, scheitel + 1.2)
	# Gangbogen (wie der Torbogen davor) und die Stirnwand darüber
	var teile := 12
	for k in teile:
		var w0 := PI * k / teile
		var w1 := PI * (k + 1) / teile
		var x0 := tw * cos(w0)
		var x1 := tw * cos(w1)
		var y0 := tor_k + tw * sin(w0)
		var y1 := tor_k + tw * sin(w1)
		_viereck("bruchstein", p.call(0.0, x0, y0), p.call(0.0, x1, y1), p.call(0.0, x1, scheitel + 1.2), p.call(0.0, x0, scheitel + 1.2), U)
		var zur_mitte := N * -(x0 + x1) / 2.0 + Vector3.UP * (tor_k - (y0 + y1) / 2.0)
		_viereck("bruchstein", p.call(-gang, x0, y0), p.call(0.0, x0, y0), p.call(0.0, x1, y1), p.call(-gang, x1, y1), zur_mitte)
	# Tonnengewölbe über die ganze Breite, darüber eine Deckplatte
	var gw := 20
	var bogen := func(t: float) -> Vector2:   # t 0..1 über die Breite: (q, y)
		var a := PI * t
		return Vector2(-hb * cos(a), kaempfer + stich * sin(a))
	for k in gw:
		var a: Vector2 = bogen.call(float(k) / gw)
		var b: Vector2 = bogen.call(float(k + 1) / gw)
		var innen := N * -(a.x + b.x) / 2.0 + Vector3.UP * (kaempfer - (a.y + b.y) / 2.0) * hb / maxf(stich, 0.1)
		_viereck("bruchstein", p.call(0.0, a.x, a.y), p.call(L, a.x, a.y), p.call(L, b.x, b.y), p.call(0.0, b.x, b.y), innen)
	_klotz("bruchstein", c, u, n, -mauer, L + mauer, -hb - mauer, hb + mauer, scheitel + 1.2, scheitel + 2.0, true)
	# Gurtbögen auf Wandpfeilern mit Kämpfergesims, Laternen an jedem zweiten Pfeiler, Poller an der Kaikante
	var s_ := joch
	var nr := 0
	while s_ < L - 1.0:
		for k in gw:
			var a: Vector2 = bogen.call(float(k) / gw)
			var b: Vector2 = bogen.call(float(k + 1) / gw)
			var ra := Vector2(a.x * 0.97, kaempfer + (a.y - kaempfer) * 0.93)
			var rb := Vector2(b.x * 0.97, kaempfer + (b.y - kaempfer) * 0.93)
			var innen := N * -(ra.x + rb.x) / 2.0 + Vector3.UP * (kaempfer - (ra.y + rb.y) / 2.0)
			_viereck("mauer", p.call(s_ - 0.5, ra.x, ra.y), p.call(s_ + 0.5, ra.x, ra.y), p.call(s_ + 0.5, rb.x, rb.y), p.call(s_ - 0.5, rb.x, rb.y), innen)
			for seite: float in [-1.0, 1.0]:
				_viereck("mauer", p.call(s_ + 0.5 * seite, a.x, a.y), p.call(s_ + 0.5 * seite, b.x, b.y), p.call(s_ + 0.5 * seite, rb.x, rb.y),
					p.call(s_ + 0.5 * seite, ra.x, ra.y), U * seite)
		for sq: float in [-1.0, 1.0]:
			var pf: Vector2 = seitlich.call(sq, hb - 0.6, hb)
			_klotz("mauer", c, u, n, s_ - 0.5, s_ + 0.5, pf.x, pf.y, boden, kaempfer)
			_klotz("mauer", c, u, n, s_ - 0.65, s_ + 0.65, seitlich.call(sq, hb - 0.75, hb).x, seitlich.call(sq, hb - 0.75, hb).y, boden, boden + 0.5)
			var ks: Vector2 = seitlich.call(sq, hb - 0.8, hb)
			_klotz("hell", c, u, n, s_ - 0.65, s_ + 0.65, ks.x, ks.y, kaempfer - 0.3, kaempfer, true)
			if true:
				var lm := c + u * s_ + n * sq * (hb - 0.6)
				var ni := -n * sq
				var y := boden + 2.6
				_klotz("metall", lm, u, ni, -0.04, 0.04, 0.0, 0.45, y + 0.55, y + 0.62)
				_klotz("metall", lm + ni * 0.45, u, ni, -0.18, 0.18, -0.18, 0.18, y + 0.5, y + 0.56)
				_klotz("glut", lm + ni * 0.45, u, ni, -0.13, 0.13, -0.13, 0.13, y, y + 0.5)
				_klotz("metall", lm + ni * 0.45, u, ni, -0.17, 0.17, -0.17, 0.17, y - 0.06, y)
			if s_ < be and s_ > trichter:
				var pm := c + u * s_ + n * sq * (hw + kante + 0.45)
				_klotz("holz", pm, u, n, -0.17, 0.17, -0.17, 0.17, boden, boden + 0.7)
				_klotz("metall", pm, u, n, -0.21, 0.21, -0.21, 0.21, boden + 0.7, boden + 0.78)
		s_ += joch
		nr += 1
	# Hängeleuchten über dem Becken (alle 12 m an Ketten vom Scheitel)
	var hs := 3.0
	while hs < L:
		var hm := c + u * hs
		_klotz("metall", hm, u, n, -0.03, 0.03, -0.03, 0.03, boden + 7.5, scheitel)
		_klotz("metall", hm, u, n, -0.35, 0.35, -0.35, 0.35, boden + 7.4, boden + 7.5)
		_klotz("glut", hm, u, n, -0.25, 0.25, -0.25, 0.25, boden + 6.8, boden + 7.4)
		_klotz("metall", hm, u, n, -0.3, 0.3, -0.3, 0.3, boden + 6.72, boden + 6.8)
		hs += 12.0
	# Kämpfergesims durchgehend an den Längswänden
	for sq: float in [-1.0, 1.0]:
		var kg: Vector2 = seitlich.call(sq, hb - 0.25, hb)
		_klotz("hell", c, u, n, 0.0, L, kg.x, kg.y, kaempfer - 0.25, kaempfer, true)
	# Tür in der Rückwand: der Weg hinauf in die Burg (noch verschlossen)
	_klotz("dunkel", c, u, n, L - 0.05, L, -1.3, 1.3, boden, boden + 3.2)
	_klotz("holz", c, u, n, L - 0.16, L - 0.05, -1.1, 1.1, boden, boden + 3.0)
	for y_: float in [boden + 0.6, boden + 2.3]:
		_klotz("metall", c, u, n, L - 0.2, L - 0.16, -1.05, 1.05, y_, y_ + 0.1)
	_klotz("hell", c, u, n, L - 0.25, L, -1.6, -1.3, boden, boden + 3.5)
	_klotz("hell", c, u, n, L - 0.25, L, 1.3, 1.6, boden, boden + 3.5)
	_klotz("hell", c, u, n, L - 0.25, L, -1.6, 1.6, boden + 3.2, boden + 3.6)


## Gesims rund um ein Gebäude; bei begehbaren Bauten nur als Band außen an der Mauer (innen liegen Decken und Treppen).
func _gesims(mat: String, c: Vector2, uz: Vector2, nx: Vector2, B: float, L: float, vor: float, y0: float, y1: float, ring: bool) -> void:
	if not ring:
		_klotz(mat, c, uz, nx, -L - vor, L + vor, -B - vor, B + vor, y0, y1, true)
		return
	_klotz(mat, c, uz, nx, -L - vor, L + vor, B - 0.3, B + vor, y0, y1, true)
	_klotz(mat, c, uz, nx, -L - vor, L + vor, -B - vor, -B + 0.3, y0, y1, true)
	_klotz(mat, c, uz, nx, -L - vor, -L + 0.3, -B + 0.3, B - 0.3, y0, y1, true)
	_klotz(mat, c, uz, nx, L - 0.3, L + vor, -B + 0.3, B - 0.3, y0, y1, true)


## Begehbares Gebäude: Mauern als Schale mit offener Tür, Geschossdecken auf Balken, Treppen (abwechselnd an den
## Längswänden, mit einer unsichtbaren Rampe als Lauffläche), Licht und Einrichtung je nach Art.
func _innenraum(c: Vector2, uz: Vector2, nx: Vector2, B: float, L: float, boden: float, unten: float, traufe: float,
		geschosse: int, gh: float, wand: String, art: int, zweck := 0) -> void:
	var t := 0.6                                  # Mauerstärke
	var fb := boden + 0.03                        # Fußboden im Erdgeschoss: ebenerdig, ohne Stufe an der Tür
	var tb := 2.4 if art == 1 else 1.6            # Türbreite
	var th := 4.0 if art == 1 else 2.7
	var iL := L - t
	var iB := B - t
	# Mauern: Längsseite -B, Giebel; die Türseite (+B, bei der Kirche der Giebel +L) mit Öffnung
	if art == 1:
		_klotz(wand, c, uz, nx, -L, L, -B, -iB, unten, traufe)
		_klotz(wand, c, uz, nx, -L, L, iB, B, unten, traufe)
		_klotz(wand, c, uz, nx, -L, -iL, -iB, iB, unten, traufe)
		_klotz(wand, c, uz, nx, iL, L, -iB, -tb / 2.0, unten, traufe)
		_klotz(wand, c, uz, nx, iL, L, tb / 2.0, iB, unten, traufe)
		_klotz(wand, c, uz, nx, iL, L, -tb / 2.0, tb / 2.0, fb + th, traufe)
	else:
		_klotz(wand, c, uz, nx, -L, L, -B, -iB, unten, traufe)
		_klotz(wand, c, uz, nx, -L, -iL, -iB, iB, unten, traufe)
		_klotz(wand, c, uz, nx, iL, L, -iB, iB, unten, traufe)
		_klotz(wand, c, uz, nx, -L, -tb / 2.0, iB, B, unten, traufe)
		_klotz(wand, c, uz, nx, tb / 2.0, L, iB, B, unten, traufe)
		_klotz(wand, c, uz, nx, -tb / 2.0, tb / 2.0, iB, B, fb + th, traufe)
	# Sockel außen nur bis Fußbodenhöhe (sonst stolpert man an der Tür), innen der Fußboden
	_klotz("bruchstein", c, uz, nx, -L - 0.2, L + 0.2, -B - 0.2, B + 0.2, unten, boden + 0.01)
	_klotz("boden", c, uz, nx, -iL, iL, -iB, iB, boden + 0.01, fb)
	# Decke unter dem Dach
	_klotz("holz", c, uz, nx, -iL, iL, -iB, iB, traufe - 0.3, traufe - 0.05, true)
	var licht_hoehen: Array[float] = []
	var stockwerke := 1 if art == 1 else geschosse
	var lauf := gh * 1.75                       # Treppenlauf: etwa 30 Grad
	var stufen := maxi(4, int(round(gh / 0.22)))
	var tritt := lauf / stufen
	var s0 := -iL + 0.9 + tritt                 # Fuß der Rampe bei s0 - tritt, davor ein Absatz am Giebel
	var s1 := s0 + lauf - tritt                 # oberste Stufe endet bei s1 + tritt
	var tb_ := 1.15                             # Treppenbreite
	for k in range(1, stockwerke):
		var y := fb + k * gh                    # Oberkante der Decke k
		var y0 := y - gh                        # Boden darunter
		var seite := -1.0 if k % 2 == 1 else 1.0
		var q0 := -iB if seite < 0 else iB - tb_
		var q1 := q0 + tb_
		var ls := s0 - tritt                    # Loch in der Decke über der Treppe
		var le := s1 + tritt
		# Decke in Teilen um das Loch
		if seite < 0:
			_klotz("holz", c, uz, nx, -iL, iL, q1, iB, y - 0.25, y, true)
		else:
			_klotz("holz", c, uz, nx, -iL, iL, -iB, q0, y - 0.25, y, true)
		_klotz("holz", c, uz, nx, -iL, ls, q0, q1, y - 0.25, y, true)
		_klotz("holz", c, uz, nx, le, iL, q0, q1, y - 0.25, y, true)
		# Balken unter der Decke
		var bs := -iL + 0.8
		while bs < iL - 0.3:
			if bs > ls - 0.2 and bs < le + 0.2:
				if seite < 0:
					_klotz("holz", c, uz, nx, bs - 0.12, bs + 0.12, q1, iB, y - 0.5, y - 0.25, true)
				else:
					_klotz("holz", c, uz, nx, bs - 0.12, bs + 0.12, -iB, q0, y - 0.5, y - 0.25, true)
			else:
				_klotz("holz", c, uz, nx, bs - 0.12, bs + 0.12, -iB, iB, y - 0.5, y - 0.25, true)
			bs += 1.6
		# Stufen und darüber die Rampe (unsichtbar, nur Kollision)
		for i in stufen:
			var vorne := s0 + (i + 1) * tritt     # Vorderkanten liegen auf der Rampe
			var hoch := y0 + gh * float(i + 1) / stufen
			_klotz("holz", c, uz, nx, vorne - tritt, vorne, q0, q1, hoch - 0.12, hoch, true)
			_klotz("hell" if i % 2 == 0 else "holz", c, uz, nx, vorne - tritt - 0.02, vorne - tritt + 0.03, q0, q1, hoch - 0.2, hoch - 0.12)
		var r := func(s: float, q: float, yy: float) -> Vector3:
			var w := c + uz * s + nx * q
			return Vector3(w.x, yy, w.y)
		_viereck("rampe", r.call(s0 - tritt, q0, y0), r.call(s1, q0, y), r.call(s1, q1, y), r.call(s0 - tritt, q1, y0), Vector3.UP)
		# Geländer am offenen Rand des Lochs und an der Treppe
		var qg := q1 if seite < 0 else q0
		var qa := qg - 0.05 if seite < 0 else qg
		_klotz("holz", c, uz, nx, ls, le, qa, qa + 0.05 if seite < 0 else qa + 0.05, y + 0.9, y + 1.0)
		var ps := ls
		while ps <= le + 0.01:
			_klotz("holz", c, uz, nx, ps - 0.05, ps + 0.05, qa, qa + 0.05, y, y + 0.95)
			ps += 1.2
		licht_hoehen.append(y0)
	licht_hoehen.append(fb + (stockwerke - 1) * gh)
	# Einrichtung
	var mitte := c
	for k in stockwerke:
		var y := fb + k * gh
		if art == 1:
			# Kapelle: Altar am Giebel -L, Bankreihen, Kerzen
			_klotz("hell", c, uz, nx, -iL + 0.4, -iL + 1.4, -1.4, 1.4, y, y + 1.0)
			_klotz("hell", c, uz, nx, -iL + 0.3, -iL + 1.5, -1.5, 1.5, y + 1.0, y + 1.12)
			for kk: float in [-1.0, 1.0]:
				_klotz("metall", c + uz * (-iL + 0.9) + nx * kk * 1.1, uz, nx, -0.05, 0.05, -0.05, 0.05, y + 1.12, y + 1.5)
				_klotz("glut", c + uz * (-iL + 0.9) + nx * kk * 1.1, uz, nx, -0.04, 0.04, -0.04, 0.04, y + 1.5, y + 1.62)
			var bs := -iL + 4.0
			while bs < iL - 3.0:
				for qq: float in [-1.0, 1.0]:
					var qa := 1.2 if qq > 0 else -iB + 0.8
					var qe := iB - 0.8 if qq > 0 else -1.2
					_klotz("holz", c, uz, nx, bs - 0.2, bs + 0.2, qa, qe, y + 0.42, y + 0.48)
					_klotz("holz", c, uz, nx, bs + 0.25, bs + 0.32, qa, qe, y + 0.48, y + 0.95)
					_klotz("holz", c, uz, nx, bs - 0.15, bs + 0.15, qa, qa + 0.1, y, y + 0.42)
					_klotz("holz", c, uz, nx, bs - 0.15, bs + 0.15, qe - 0.1, qe, y, y + 0.42)
				bs += 1.6
		elif art == 2:
			# Lager: Kistenstapel und Säcke an den Wänden, frei bleiben Tür und Treppen
			var ks := -iL + lauf + 3.5          # hinter dem Treppenausgang
			var i := 0
			while ks < iL - 1.0:
				if absf(ks) > 2.0:
					for qq: float in [-1.0, 1.0]:
						var qk := qq * (iB - 0.6)
						var hoch := 0.8 * (1 + (i + int(qq > 0)) % 3)
						_klotz("holz", c + uz * ks + nx * qk, uz, nx, -0.5, 0.5, -0.5, 0.5, y, y + hoch)
						_klotz("metall", c + uz * ks + nx * qk, uz, nx, -0.52, 0.52, -0.52, 0.52, y + hoch - 0.08, y + hoch - 0.02)
				ks += 1.6
				i += 1
		else:
			# Wohnbau, Palas, Küche, Zeughaus: in jedem Geschoss ein Tisch mit Bänken, im Erdgeschoss ein Kamin am Giebel +L,
			# in den oberen Geschossen Betten am Giebel +L
			var ts := iL * (0.42 if art == 3 else 0.15)   # im Palas die Tafel hinten, vorn bleibt der Weg zur Treppe frei
			var lang := minf(iL * 0.9, 6.0) if art == 3 else minf(iL * 0.5, 2.4)
			_klotz("holz", c + uz * ts, uz, nx, -lang / 2.0, lang / 2.0, -0.5, 0.5, y + 0.72, y + 0.8)
			for e: float in [-1.0, 1.0]:
				_klotz("holz", c + uz * (ts + e * (lang / 2.0 - 0.3)), uz, nx, -0.08, 0.08, -0.4, 0.4, y, y + 0.72)
				_klotz("holz", c + uz * ts + nx * e * 0.95, uz, nx, -lang / 2.0, lang / 2.0, -0.18, 0.18, y + 0.42, y + 0.48)
				_klotz("holz", c + uz * ts + nx * e * 0.95, uz, nx, -lang / 2.0 + 0.2, -lang / 2.0 + 0.3, -0.15, 0.15, y, y + 0.42)
				_klotz("holz", c + uz * ts + nx * e * 0.95, uz, nx, lang / 2.0 - 0.3, lang / 2.0 - 0.2, -0.15, 0.15, y, y + 0.42)
			_klotz("glut", c + uz * ts, uz, nx, -0.06, 0.06, -0.06, 0.06, y + 0.8, y + 0.98)
			if k == 0 and zweck != 1:
				var km := c + uz * (iL - 0.45)
				_klotz("bruchstein", km, uz, nx, -0.45, 0.45, -1.3, -0.9, y, y + 1.4)
				_klotz("bruchstein", km, uz, nx, -0.45, 0.45, 0.9, 1.3, y, y + 1.4)
				_klotz("bruchstein", km, uz, nx, -0.55, 0.45, -1.4, 1.4, y + 1.4, y + 1.7, true)
				_klotz("bruchstein", km, uz, nx, -0.3, 0.45, -1.0, 1.0, y + 1.7, traufe - 0.3 if stockwerke == 1 else y + gh - 0.25)
				_klotz("glut", km, uz, nx, -0.25, 0.25, -0.6, 0.6, y, y + 0.35)
				_klotz("holz", km, uz, nx, -0.2, 0.15, -0.5, 0.5, y + 0.05, y + 0.25)
			elif k > 0 and not (zweck == 3 and k == stockwerke - 1):
				for e: float in [-1.0, 1.0]:
					var bm := c + uz * (iL - 1.2) + nx * e * minf(iB - 1.2, 2.2)
					_klotz("holz", bm, uz, nx, -1.0, 1.0, -0.5, 0.5, y, y + 0.45)
					_klotz("stoff", bm, uz, nx, -0.95, 0.75, -0.48, 0.48, y + 0.45, y + 0.6)
					_klotz("hell", bm, uz, nx, 0.75, 0.98, -0.4, 0.4, y + 0.45, y + 0.62)
					_klotz("holz", bm, uz, nx, 0.95, 1.05, -0.5, 0.5, y, y + 1.0)
	if zweck > 0:
		_einrichtung(zweck, c, uz, nx, iL, iB, fb, gh, stockwerke, lauf, traufe - 0.3)
	if art != 1:
		_hausrat(zweck, art, c, uz, nx, L, iL, iB, fb, gh, stockwerke, lauf, traufe - 0.3)
	# Licht je Geschoss: Hängeleuchten etwa alle 9 m entlang des Baus (warm, ohne Schatten)
	var anzahl := maxi(1, int(ceil(2.0 * iL / 9.0)))
	for k in stockwerke:
		var y := fb + k * gh
		var decke := traufe - 0.3 if k == stockwerke - 1 else y + gh - 0.5
		for i in anzahl:
			var s_ := -iL + (i + 0.5) * 2.0 * iL / anzahl
			var lp := c + uz * s_
			var hoehe := minf(y + 2.6, decke - 0.4)
			_klotz("metall", lp, uz, nx, -0.02, 0.02, -0.02, 0.02, hoehe + 0.3, decke)
			_klotz("metall", lp, uz, nx, -0.2, 0.2, -0.2, 0.2, hoehe + 0.25, hoehe + 0.3)
			_klotz("glut", lp, uz, nx, -0.14, 0.14, -0.14, 0.14, hoehe - 0.15, hoehe + 0.25)
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.8, 0.55)
			l.light_energy = 1.8
			l.omni_range = clampf(B * 2.2, 8.0, 16.0)
			l.omni_attenuation = 0.8
			l.position = Vector3(lp.x, hoehe - 0.3, lp.y)
			add_child(l)


## Einrichtung nach dem Zweck des Baus (Gebäudewert Art // 100): 1 Küche, 2 Zeughaus, 3 Palas (oben der Rittersaal), 4 Stall,
## 5 Gesindehaus, 6 Kapelle.
## Die Möbel stehen an den Wänden; Tür (Mitte der Längsseite +B), Treppen (am Giebel -L) und die Mitte bleiben frei.
func _einrichtung(zweck: int, c: Vector2, uz: Vector2, nx: Vector2, iL: float, iB: float, fb: float, gh: float, stockwerke: int,
		lauf: float, decke_oben: float) -> void:
	var frei_s := -iL + 0.9 + lauf + 2.8 if stockwerke > 1 else -iL + 0.6   # dahinter sind Treppe und Austritt frei
	for k in stockwerke:
		var y := fb + k * gh
		var decke := decke_oben if k == stockwerke - 1 else y + gh - 0.5
		match zweck:
			1:   # Küche: großer Herd mit Rauchfang und Kessel am Giebel +L, Arbeitstische, Regale mit Töpfen, Fässer
				if k == 0:
					var hm := c + uz * (iL - 0.9)
					_klotz("bruchstein", hm, uz, nx, -0.9, 0.9, -2.2, 2.2, y, y + 0.8)
					_klotz("glut", hm, uz, nx, -0.6, 0.5, -1.4, 1.4, y + 0.8, y + 0.95)
					_klotz("bruchstein", hm, uz, nx, -1.1, 0.9, -2.4, 2.4, y + 2.2, y + 2.5, true)
					_klotz("bruchstein", hm, uz, nx, -0.2, 0.9, -1.6, 1.6, y + 2.5, decke)
					for e: float in [-1.0, 1.0]:
						_klotz("bruchstein", hm, uz, nx, -0.9, 0.9, e * 2.2 - 0.2, e * 2.2 + 0.2, y + 0.8, y + 2.2)
					# Kessel an einer Kette über dem Feuer
					_klotz("metall", hm, uz, nx, -0.03, 0.03, -0.03, 0.03, y + 1.6, y + 2.2)
					_klotz("metall", hm, uz, nx, -0.38, 0.38, -0.38, 0.38, y + 1.0, y + 1.6)
					_klotz("holz", hm, uz, nx, -0.4, 0.4, -0.4, 0.4, y + 1.6, y + 1.63)
				for e: float in [-1.0, 1.0]:
					var ts := iL * 0.35
					_klotz("holz", c + uz * ts + nx * e * (iB - 0.5), uz, nx, -1.4, 1.4, -0.45, 0.45, y + 0.85, y + 0.92)
					for f: float in [-1.0, 1.0]:
						_klotz("holz", c + uz * (ts + f * 1.25) + nx * e * (iB - 0.5), uz, nx, -0.07, 0.07, -0.4, 0.4, y, y + 0.85)
					# Töpfe, Krüge und Brotlaibe auf dem Tisch
					for i in 4:
						var tp := c + uz * (ts - 1.0 + i * 0.65) + nx * e * (iB - 0.5)
						_klotz("metall" if i % 2 == 0 else "hell", tp, uz, nx, -0.13, 0.13, -0.13, 0.13, y + 0.92, y + 1.15 + 0.08 * (i % 3))
				_regal(c + uz * (-iL * 0.1) + nx * -(iB - 0.25), uz, nx, -1.0, y, 1.8, 2.2)
			2:   # Zeughaus: Waffenständer mit Spießen, Rüstungsständer, Schilde an der Wand, Kisten
				var s_ := frei_s
				var i := 0
				while s_ < iL - 1.0:
					if absf(s_) > 1.8:
						for e: float in [-1.0, 1.0]:
							var wm := c + uz * s_ + nx * e * (iB - 0.35)
							if i % 2 == 0:
								_klotz("holz", wm, uz, nx, -0.9, 0.9, -0.2, 0.2, y + 0.3, y + 0.4)
								_klotz("holz", wm, uz, nx, -0.9, 0.9, -0.2, 0.2, y + 1.3, y + 1.38)
								for sp in 7:
									var px := -0.75 + sp * 0.25
									_klotz("holz", wm, uz, nx, px - 0.025, px + 0.025, -0.03, 0.03, y, y + 2.6)
									_klotz("metall", wm, uz, nx, px - 0.04, px + 0.04, -0.015, 0.015, y + 2.6, y + 2.9)
							else:
								# Rüstung auf einem Ständer: Brustpanzer, Helm, Schild an der Wand dahinter
								_klotz("holz", wm, uz, nx, -0.04, 0.04, -0.04, 0.04, y, y + 1.6)
								_klotz("metall", wm, uz, nx, -0.25, 0.25, -0.14, 0.14, y + 1.0, y + 1.55)
								_klotz("metall", wm, uz, nx, -0.13, 0.13, -0.13, 0.13, y + 1.62, y + 1.9)
								var sm := c + uz * s_ + nx * e * (iB - 0.03)
								_klotz("stoff", sm, uz, nx, -0.35, 0.35, -0.03, 0.03, y + 1.9, y + 2.7)
								_klotz("metall", sm, uz, nx, -0.08, 0.08, -0.05, 0.05, y + 2.22, y + 2.38)
					s_ += 1.8
					i += 1
				# Schleifstein, Pfeilbündel und Pechfässer an der Giebelwand +L
				if k == 0:
					var gm := c + uz * (iL - 1.0)
					_klotz("holz", gm + nx * 1.6, uz, nx, -0.3, 0.3, -0.5, 0.5, y, y + 0.7)
					_klotz("bruchstein", gm + nx * 1.6, uz, nx, -0.07, 0.07, -0.45, 0.45, y + 0.5, y + 1.3)
					for i2 in 4:
						var pm := gm + nx * (-0.4 - i2 * 0.7)
						_klotz("holz", pm, uz, nx, -0.2, 0.2, -0.2, 0.2, y, y + 0.9)
						_klotz("metall", pm, uz, nx, -0.22, 0.22, -0.22, 0.22, y + 0.85, y + 0.9)
			3:   # Palas: Teppich, Thron am Giebel +L, Wandteppiche, Kerzenständer
				_klotz("stoff", c, uz, nx, -iL * 0.6, iL * 0.6, -1.3, 1.3, y, y + 0.02)
				if k == stockwerke - 1 or stockwerke == 1:
					var th := c + uz * (iL - 1.0)
					_klotz("hell", th, uz, nx, -0.9, 0.9, -1.4, 1.4, y, y + 0.3)
					_klotz("holz", th, uz, nx, -0.35, 0.35, -0.4, 0.4, y + 0.3, y + 0.8)
					_klotz("holz", th, uz, nx, 0.25, 0.4, -0.4, 0.4, y + 0.8, y + 2.0)
					_klotz("stoff", th, uz, nx, -0.33, 0.25, -0.36, 0.36, y + 0.8, y + 0.88)
					for e: float in [-1.0, 1.0]:
						_klotz("holz", th, uz, nx, -0.35, 0.25, e * 0.4 - 0.05, e * 0.4 + 0.05, y + 0.8, y + 1.2)
				var ws := -iL + 3.0
				while ws < iL - 2.0:
					if absf(ws) > 2.0 and ws > frei_s:
						for e: float in [-1.0, 1.0]:
							var wm := c + uz * ws + nx * e * (iB - 0.03)
							_klotz("stoff", wm, uz, nx, -0.8, 0.8, -0.03, 0.03, y + 1.0, minf(y + 3.6, decke - 0.4))
							_klotz("holz", wm, uz, nx, -0.95, 0.95, -0.06, 0.06, minf(y + 3.6, decke - 0.4), minf(y + 3.6, decke - 0.4) + 0.08)
					ws += 6.0
				for e: float in [-1.0, 1.0]:
					_leuchter(c + uz * (iL * 0.42 + e * 3.5) + nx * 1.6, uz, nx, y)
				if k == stockwerke - 1:
					# Rittersaal: zwei lange Tafeln an den Längswänden mit Bänken, Krüge und Teller darauf, dazwischen
					# der Teppich zum Thron; ein großer Kamin in der Mitte der Längswand -B, Kronleuchter an Ketten
					var t0 := frei_s + 0.8
					var t1 := iL - 3.2
					if t1 - t0 > 3.0:
						for e: float in [-1.0, 1.0]:
							var q := e * (iB - 1.9)
							var tm := c + uz * ((t0 + t1) / 2.0) + nx * q
							var tl := (t1 - t0) / 2.0
							_klotz("holz", tm, uz, nx, -tl, tl, -0.55, 0.55, y + 0.74, y + 0.82)
							var bs := -tl + 0.3
							while bs < tl:
								_klotz("holz", tm + uz * bs, uz, nx, -0.08, 0.08, -0.45, 0.45, y, y + 0.74)
								bs += 2.4
							for f: float in [-1.0, 1.0]:
								_klotz("holz", tm + nx * f * 0.95, uz, nx, -tl, tl, -0.17, 0.17, y + 0.42, y + 0.48)
							var gs := -tl + 0.6
							var gi := 0
							while gs < tl - 0.3:
								_klotz("metall" if gi % 3 == 0 else "hell", tm + uz * gs + nx * (0.25 if gi % 2 == 0 else -0.25), uz, nx,
									-0.1, 0.1, -0.1, 0.1, y + 0.82, y + 0.86 + 0.14 * float(gi % 3 == 0))
								gs += 0.8
								gi += 1
						var km := c + uz * ((t0 + t1) / 2.0) + nx * -(iB - 0.45)
						_klotz("bruchstein", km, uz, nx, -1.8, -1.3, -0.45, 0.45, y, y + 1.8)
						_klotz("bruchstein", km, uz, nx, 1.3, 1.8, -0.45, 0.45, y, y + 1.8)
						_klotz("bruchstein", km, uz, nx, -2.0, 2.0, -0.6, 0.45, y + 1.8, y + 2.2, true)
						_klotz("bruchstein", km, uz, nx, -1.2, 1.2, -0.3, 0.45, y + 2.2, decke)
						_klotz("glut", km, uz, nx, -1.1, 1.1, -0.3, 0.3, y, y + 0.4)
						for e: float in [-0.5, 0.5]:
							var lm := c + uz * (t0 + (t1 - t0) * (0.5 + e * 0.6))
							var ly := minf(y + 3.6, decke - 1.0)
							_klotz("metall", lm, uz, nx, -0.02, 0.02, -0.02, 0.02, ly + 0.2, decke)
							for w in 8:
								var a := TAU * w / 8.0
								var rp := lm + uz * cos(a) * 0.9 + nx * sin(a) * 0.9
								_klotz("metall", rp, uz, nx, -0.06, 0.06, -0.06, 0.06, ly, ly + 0.08)
								_klotz("glut", rp, uz, nx, -0.02, 0.02, -0.02, 0.02, ly + 0.08, ly + 0.22)
							var kl := OmniLight3D.new()
							kl.light_color = Color(1.0, 0.78, 0.5)
							kl.light_energy = 2.2
							kl.omni_range = 11.0
							kl.position = Vector3(lm.x, ly - 0.2, lm.y)
							add_child(kl)
			6:   # Kapelle: Altarbild, zwei Kerzenleuchter am Altar, Taufstein beim Eingang, Banner an den Wänden
				var am := c + uz * (-iL + 0.08)
				_klotz("stoff", am, uz, nx, -0.04, 0.04, -1.6, 1.6, y + 1.8, y + 4.6)
				_klotz("holz", am, uz, nx, -0.08, 0.1, -1.75, 1.75, y + 4.6, y + 4.8)
				_klotz("hell", am, uz, nx, -0.06, 0.06, -0.12, 0.12, y + 2.6, y + 4.1)
				_klotz("hell", am, uz, nx, -0.06, 0.06, -0.75, 0.75, y + 3.5, y + 3.74)
				for e: float in [-1.0, 1.0]:
					_leuchter(c + uz * (-iL + 1.9) + nx * e * 2.2, uz, nx, y)
				var fm := c + uz * (iL - 2.2) + nx * (iB - 1.4)
				_klotz("hell", fm, uz, nx, -0.3, 0.3, -0.3, 0.3, y, y + 0.7)
				_klotz("hell", fm, uz, nx, -0.5, 0.5, -0.5, 0.5, y + 0.7, y + 1.0)
				var ws := -iL + 4.5
				while ws < iL - 4.0:
					for e: float in [-1.0, 1.0]:
						_klotz("stoff", c + uz * ws + nx * e * (iB - 0.04), uz, nx, -0.6, 0.6, -0.03, 0.03, y + 2.5, y + 5.5)
					ws += 5.0
			4:   # Stall: Boxen mit Trennwänden und Krippen an der Längswand -B, Heu und Stroh
				if k == 0:
					var s_ := frei_s
					while s_ < iL - 2.0:
						var bm := c + uz * s_ + nx * -(iB - 1.4)
						_klotz("holz", bm, uz, nx, -0.05, 0.05, -1.4, 1.4, y, y + 1.4)
						_klotz("holz", bm + uz * 1.4, uz, nx, -0.7, 0.7, -1.4 + 0.05, -1.0, y + 0.6, y + 1.0)
						_klotz("stroh", bm + uz * 1.4, uz, nx, -1.35, 1.35, -1.0, 1.4, y, y + 0.06)
						s_ += 2.8
					# Heuballen in den Ecken an der Türseite, nicht vor der Tür
					for e in 3:
						var hs := (iL - 0.8) * (1.0 if e != 1 else -1.0)
						var hq := iB - (0.8 if e < 2 else 2.0)
						var hm := c + uz * hs + nx * hq
						_klotz("stroh", hm, uz, nx, -0.6, 0.6, -0.45, 0.45, y, y + 0.5 + 0.5 * (e % 2))
			5:   # Gesindehaus: Truhen am Fußende der Betten, Wandbretter mit Krügen
				_regal(c + uz * (iL * 0.5) + nx * -(iB - 0.25), uz, nx, -1.0, y, 1.6, 1.8)
				_klotz("holz", c + uz * (iL - 2.6), uz, nx, -0.35, 0.35, -0.5, 0.5, y, y + 0.55)
				_klotz("metall", c + uz * (iL - 2.6), uz, nx, -0.37, 0.37, -0.52, 0.52, y + 0.42, y + 0.47)


## Hausrat an den freien Wandstrecken der Längsseiten, je nach Zweck des Baus: Truhen, Schränke, Fässer, Säcke,
## Wandbänke, Wandbretter mit Krügen, Kleiderhaken, Kräuterbündel, Sättel; dazu Wandleuchter. Frei bleiben Tür,
## Treppen (bis frei_s), der Giebel +L (Kamin, Herd, Betten, Thron) und die Plätze, die _einrichtung belegt;
## hohe Möbel stehen nicht vor Fenstern.
func _hausrat(zweck: int, art: int, c: Vector2, uz: Vector2, nx: Vector2, L: float, iL: float, iB: float, fb: float,
		gh: float, stockwerke: int, lauf: float, decke_oben: float) -> void:
	if zweck == 6:
		return   # die Kapelle ist schon voll (Bänke, Altar, Taufstein)
	var frei_s := -iL + 0.9 + lauf + 1.2 if stockwerke > 1 else -iL + 0.6
	var fenster: Array[float] = []
	var fenster_halb := 0.8
	if art == 3:
		var achsen := maxi(5, int((2.0 * L - 2.0) / 4.4))
		for f in achsen:
			fenster.append(-L + 1.0 + (f + 0.5) * (2.0 * L - 2.0) / achsen)
		fenster_halb = 1.4
	else:
		var anzahl := int((2.0 * L - 2.0) / 3.4)
		for f in anzahl:
			fenster.append(-L + 1.0 + (f + 0.5) * (2.0 * L - 2.0) / anzahl)
	var zufall := RandomNumberGenerator.new()
	zufall.seed = hash(Vector2i(int(c.x * 10.0), int(c.y * 10.0)))
	for k in stockwerke:
		var y := fb + k * gh
		var decke := decke_oben if k == stockwerke - 1 else y + gh - 0.5
		var ende := iL - (2.4 if k > 0 or zweck == 1 else 1.1)
		# Längsseiten mit Treppe auf diesem Geschoss: hinauf (zu Decke k + 1) und herauf (durch das Loch in Decke k)
		var treppen_seiten: Array[float] = []
		if k < stockwerke - 1:
			treppen_seiten.append(-1.0 if (k + 1) % 2 == 1 else 1.0)
		if k > 0:
			treppen_seiten.append(-1.0 if k % 2 == 1 else 1.0)
		for e: float in [-1.0, 1.0]:
			# an der Seite ohne Treppe darf der Hausrat bis an den Giebel -L stehen
			var start := frei_s if e in treppen_seiten else -iL + 0.7
			# Brüstungshöhe der Fenster auf dieser Wand (über dem Boden); ohne Fenster beliebig hoch
			var bruestung := 99.0
			if art == 3:
				if k > 0:
					bruestung = gh * 0.18 - 0.2 if e > 0 else gh * 0.3 - 0.15
			elif not (art == 2 and k > 0):
				bruestung = gh * 0.55 - minf(1.7, gh * 0.48) / 2.0 - 0.15
			# gesperrte Strecken entlang s auf dieser Wand
			var sperren: Array[Vector2] = []
			if k == 0 and e > 0:
				sperren.append(Vector2(-1.9, 1.9))                       # Tür
			var ts := iL * (0.42 if art == 3 else 0.15)
			var lang := minf(iL * 0.9, 6.0) if art == 3 else minf(iL * 0.5, 2.4)
			if iB < 2.3:
				sperren.append(Vector2(ts - lang / 2.0 - 0.3, ts + lang / 2.0 + 0.3))   # Tisch in der Mitte reicht bis an die Wand
			match zweck:
				1:
					sperren.append(Vector2(iL * 0.35 - 1.6, iL * 0.35 + 1.6))
					if e < 0:
						sperren.append(Vector2(-iL * 0.1 - 1.0, -iL * 0.1 + 1.0))
				3:
					if k == stockwerke - 1:
						sperren.append(Vector2(frei_s, iL))              # Rittersaal: Tafeln an beiden Wänden
				4:
					if k == 0 and e < 0:
						continue                                         # Pferdeboxen
				5:
					if e < 0:
						sperren.append(Vector2(iL * 0.5 - 0.9, iL * 0.5 + 0.9))
					sperren.append(Vector2(iL - 3.1, iL))
			var s_ := start
			var i := 0
			while zweck != 2 and s_ < ende:   # im Zeughaus stehen an den Wänden schon die Ständer
				# bis zu sechs Versuche: vor einem Fenster passt oft ein niedriges Stück, wo ein hohes nicht passt
				var stueck: Array = []
				var a := s_
				var b := s_
				var frei := false
				for versuch in 6:
					stueck = _hausrat_wahl(zweck, k, zufall)
					var br_: float = stueck[1]
					var hoch: bool = float(stueck[2]) > bruestung - 0.05
					a = s_
					b = s_ + br_
					frei = b <= ende
					for sp: Vector2 in sperren:
						if b > sp.x and a < sp.y:
							frei = false
					if frei and hoch:
						for fp: float in fenster:
							if b > fp - fenster_halb and a < fp + fenster_halb:
								frei = false
					if frei:
						break
				if not frei:
					s_ += 0.5
					continue
				var breite: float = stueck[1]
				var m := c + uz * ((a + b) / 2.0) + nx * e * iB
				_hausrat_stueck(stueck[0], m, uz, nx * -e, breite, y, decke, zufall)
				s_ = b + zufall.randf_range(0.2, 0.7)
				i += 1
			# Wandleuchter zwischen den Fenstern
			for f in fenster.size() - 1:
				var ws := (fenster[f] + fenster[f + 1]) / 2.0
				if ws < start or ws > ende:
					continue
				var gesperrt := false
				for sp: Vector2 in sperren:
					if ws > sp.x - 0.3 and ws < sp.y + 0.3:
						gesperrt = true
				if gesperrt or zweck == 2 or zufall.randf() < 0.4:
					continue
				var lm := c + uz * ws + nx * e * iB
				var n := nx * -e
				var ly := y + minf(2.3, decke - y - 0.6)
				_klotz("metall", lm, uz, n, -0.08, 0.08, 0.0, 0.04, ly - 0.25, ly + 0.05)
				_klotz("metall", lm, uz, n, -0.02, 0.02, 0.0, 0.25, ly - 0.05, ly - 0.01)
				_klotz("metall", lm, uz, n, -0.06, 0.06, 0.19, 0.31, ly - 0.01, ly + 0.02)
				_klotz("hell", lm, uz, n, -0.025, 0.025, 0.225, 0.275, ly + 0.02, ly + 0.17)
				_klotz("glut", lm, uz, n, -0.012, 0.012, 0.238, 0.262, ly + 0.17, ly + 0.22)
			# Raummitte: Möbel zwischen dem Hausrat an der Wand und dem freien Mittelgang (|q| < 0,9)
			var qm := iB - 1.55
			if qm >= 1.5 and not (zweck == 3 and k == stockwerke - 1):
				var sm := start + 0.8
				while sm < ende - 0.7:
					var st_ := _mitte_wahl(zweck, zufall)
					var br: float = st_[1]
					var a := sm
					var b := sm + br
					var frei := b <= ende
					for sp: Vector2 in sperren:
						if b > sp.x - 0.4 and a < sp.y + 0.4:
							frei = false
					if b > ts - lang / 2.0 - 0.9 and a < ts + lang / 2.0 + 0.9:
						frei = false   # Tisch mit Bänken in der Mitte
					if not frei:
						sm += 0.5
						continue
					_mitte_stueck(st_[0], c + uz * ((a + b) / 2.0) + nx * e * qm, uz, nx * -e, br, y, zufall)
					sm = b + zufall.randf_range(0.5, 1.1)


## Möbel für die Raummitte: [Name, Breite entlang des Baus]
func _mitte_wahl(zweck: int, zufall: RandomNumberGenerator) -> Array:
	var liste: Array
	match zweck:
		1:
			liste = [["arbeitstisch", 1.7], ["koerbe", 1.3], ["zuber", 1.1]]
		2:
			liste = [["waffenkiste", 1.3], ["ruestbock", 1.0], ["pfeilfass", 0.9], ["arbeitstisch", 1.7]]
		3:
			liste = [["pult", 1.2], ["schach", 1.5], ["truhe", 1.2], ["kohlebecken", 0.9]]
		4:
			liste = [["heu", 1.7], ["karre", 1.5], ["koerbe", 1.3]]
		_:
			liste = [["webstuhl", 1.7], ["spinnrad", 1.4], ["arbeitstisch", 1.7], ["zuber", 1.1], ["kohlebecken", 0.9],
				["koerbe", 1.3]]
	return liste[zufall.randi() % liste.size()]


## Ein Möbelstück in der Raummitte: m die Mitte, u entlang des Baus, n zur Raummitte; Ausdehnung ±breite/2 und ±0,6.
func _mitte_stueck(name_: String, m: Vector2, u: Vector2, n: Vector2, breite: float, y: float,
		zufall: RandomNumberGenerator) -> void:
	var b := breite / 2.0 - 0.05
	match name_:
		"arbeitstisch":
			_klotz("holz", m, u, n, -b, b, -0.42, 0.42, y + 0.82, y + 0.9, true)
			for su: float in [-1.0, 1.0]:
				for sn: float in [-1.0, 1.0]:
					_klotz("holz", m + u * su * (b - 0.1) + n * sn * 0.32, u, n, -0.05, 0.05, -0.05, 0.05, y, y + 0.82)
			_klotz("holz", m, u, n, -b + 0.1, b - 0.1, -0.03, 0.03, y + 0.18, y + 0.24)
			var t := -b + 0.25
			while t < b - 0.2:
				match zufall.randi() % 4:
					0: _mantel("stroh", m + u * t, 0.14, 0.18, y + 0.9, y + 1.08, 8)          # Korb
					1: _mantel("hell", m + u * t + n * 0.15, 0.07, 0.1, y + 0.9, y + 1.15, 8)   # Krug
					2: _klotz("stroh", m + u * t, u, n, -0.15, 0.15, -0.09, 0.09, y + 0.9, y + 0.98)   # Brot
					3: _klotz("metall", m + u * t - n * 0.1, u, n, -0.13, 0.13, -0.13, 0.13, y + 0.9, y + 0.93)   # Teller
				t += zufall.randf_range(0.3, 0.45)
			_mantel("holz", m - n * 0.75 + u * 0.3, 0.17, 0.17, y, y + 0.45, 8)          # Schemel
			_ring("holz", m - n * 0.75 + u * 0.3, 0.0, 0.17, y + 0.45, 8)
		"koerbe":
			for i in 3:
				var km := m + u * (-b + 0.3 + i * (2.0 * b - 0.6) / 2.0) + n * (0.15 if i % 2 == 0 else -0.2)
				var r := zufall.randf_range(0.2, 0.28)
				_mantel("stroh", km, r * 0.85, r, y, y + 0.38, 10)
				_ring(["stroh", "holz", "stoff"][i], km, 0.0, r * 0.95, y + 0.34, 10)
		"zuber":
			_mantel("holz", m, 0.42, 0.47, y, y + 0.5, 12)
			_ring("wasser_innen", m, 0.0, 0.44, y + 0.44, 12)
			for ry: float in [0.08, 0.38]:
				_mantel("metall", m, 0.44, 0.46, y + ry, y + ry + 0.04, 12)
			_klotz("holz", m + u * 0.35 + n * 0.05, u, n, -0.02, 0.02, -0.18, 0.18, y + 0.3, y + 0.8)   # Waschbrett
			_klotz("stoff", m - u * 0.2, u, n, -0.25, 0.25, -0.3, 0.3, y + 0.5, y + 0.53)
		"kohlebecken":
			for w in 3:
				var a := TAU * w / 3.0
				_klotz("metall", m + u * cos(a) * 0.22 + n * sin(a) * 0.22, u, n, -0.025, 0.025, -0.025, 0.025, y, y + 0.6)
			_mantel("metall", m, 0.18, 0.3, y + 0.55, y + 0.75, 10)
			_ring("glut", m, 0.0, 0.27, y + 0.72, 10)
		"webstuhl":
			for su: float in [-1.0, 1.0]:
				for sn: float in [-0.35, 0.45]:
					_klotz("holz", m + u * su * (b - 0.08) + n * sn, u, n, -0.05, 0.05, -0.05, 0.05, y, y + 1.75)
				_klotz("holz", m + u * su * (b - 0.08), u, n, -0.04, 0.04, -0.35, 0.45, y + 1.68, y + 1.75)
			_klotz("holz", m + n * -0.35, u, n, -b, b, -0.06, 0.06, y + 0.82, y + 0.92)   # Brustbaum
			_klotz("holz", m + n * 0.45, u, n, -b, b, -0.07, 0.07, y + 0.78, y + 0.92)   # Kettbaum
			_klotz("stoff", m + n * -0.12, u, n, -b + 0.12, b - 0.12, -0.2, 0.2, y + 0.9, y + 0.91)   # gewebtes Tuch
			_klotz("hell", m + n * 0.25, u, n, -b + 0.12, b - 0.12, -0.2, 0.2, y + 0.9, y + 0.905)    # Kettfäden
			_klotz("holz", m + n * 0.05, u, n, -b + 0.1, b - 0.1, -0.02, 0.02, y + 1.0, y + 1.05)    # Webschaft
			_klotz("holz", m + n * 0.05, u, n, -b + 0.1, b - 0.1, -0.02, 0.02, y + 1.45, y + 1.5)
			_klotz("holz", m, u, n, -b, b, -0.04, 0.04, y + 1.68, y + 1.75)
			_klotz("holz", m + n * -0.65, u, n, -b + 0.2, b - 0.2, -0.15, 0.15, y + 0.45, y + 0.5)   # Bank
			for su: float in [-1.0, 1.0]:
				_klotz("holz", m + n * -0.65 + u * su * (b - 0.3), u, n, -0.04, 0.04, -0.12, 0.12, y, y + 0.45)
		"spinnrad":
			var sm := m + u * -0.2
			_klotz("holz", sm, u, n, -0.4, 0.4, -0.12, 0.12, y + 0.3, y + 0.38)
			for su: float in [-0.35, 0.35]:
				_klotz("holz", sm + u * su, u, n, -0.03, 0.03, -0.03, 0.03, y, y + 0.3)
			_klotz("holz", sm + u * -0.15, u, n, -0.02, 0.02, -0.02, 0.02, y + 0.38, y + 0.8)
			for w in 14:
				var a := TAU * w / 14.0
				_klotz("holz", sm + u * (-0.15 + cos(a) * 0.3), u, n, -0.03, 0.03, -0.02, 0.02,
					y + 0.8 + sin(a) * 0.3 - 0.03, y + 0.8 + sin(a) * 0.3 + 0.03)
			_klotz("holz", sm + u * 0.3, u, n, -0.015, 0.015, -0.015, 0.015, y + 0.38, y + 1.2)   # Rocken
			_klotz("stroh", sm + u * 0.3, u, n, -0.06, 0.06, -0.06, 0.06, y + 0.95, y + 1.18)
			_mantel("holz", m + u * 0.4 - n * 0.4, 0.16, 0.16, y, y + 0.42, 8)          # Schemel
			_ring("holz", m + u * 0.4 - n * 0.4, 0.0, 0.16, y + 0.42, 8)
			_mantel("stroh", m + u * 0.45 + n * 0.3, 0.16, 0.2, y, y + 0.25, 8)          # Korb mit Wolle
			_ring("hell", m + u * 0.45 + n * 0.3, 0.0, 0.19, y + 0.22, 8)
		"pult":
			for su: float in [-1.0, 1.0]:
				_klotz("holz", m + u * su * 0.4, u, n, -0.04, 0.04, -0.2, 0.2, y, y + 1.0)
			var p := func(su: float, sn: float, yy: float) -> Vector3:
				var q := m + u * su + n * sn
				return Vector3(q.x, yy, q.y)
			_viereck("holz", p.call(-0.5, -0.25, y + 1.0), p.call(0.5, -0.25, y + 1.0), p.call(0.5, 0.25, y + 1.2),
				p.call(-0.5, 0.25, y + 1.2), Vector3(n.x, 3, n.y) * -1.0 + Vector3(0, 6, 0))
			_klotz("holz", m, u, n, -0.5, 0.5, 0.2, 0.3, y + 1.0, y + 1.22)
			_viereck("hell", p.call(-0.3, -0.15, y + 1.07), p.call(0.3, -0.15, y + 1.07), p.call(0.3, 0.15, y + 1.19),
				p.call(-0.3, 0.15, y + 1.19), Vector3(0, 1, 0))                                     # aufgeschlagenes Buch
			_klotz("stoff", m + u * 0.42, u, n, -0.05, 0.05, 0.22, 0.28, y + 1.22, y + 1.26)
			_klotz("hell", m + u * 0.4 + n * 0.25, u, n, -0.02, 0.02, -0.02, 0.02, y + 1.26, y + 1.4)
			_klotz("glut", m + u * 0.4 + n * 0.25, u, n, -0.01, 0.01, -0.01, 0.01, y + 1.4, y + 1.44)
			_mantel("holz", m - n * 0.55, 0.17, 0.17, y, y + 0.6, 8)
			_ring("holz", m - n * 0.55, 0.0, 0.17, y + 0.6, 8)
		"schach":
			_klotz("holz", m, u, n, -0.38, 0.38, -0.38, 0.38, y + 0.68, y + 0.74, true)
			_klotz("holz", m, u, n, -0.06, 0.06, -0.06, 0.06, y, y + 0.68)
			_klotz("holz", m, u, n, -0.25, 0.25, -0.25, 0.25, y, y + 0.05)
			for i in 4:
				for j in 4:
					_klotz("hell" if (i + j) % 2 == 0 else "holz", m + u * (-0.21 + i * 0.14) + n * (-0.21 + j * 0.14), u, n,
						-0.07, 0.07, -0.07, 0.07, y + 0.74, y + 0.75)
			for i in 5:
				_klotz("hell" if i < 3 else "dunkel", m + u * zufall.randf_range(-0.25, 0.25) + n * zufall.randf_range(-0.25, 0.25),
					u, n, -0.02, 0.02, -0.02, 0.02, y + 0.75, y + 0.83)
			for su: float in [-1.0, 1.0]:
				_klotz("holz", m + u * su * 0.6, u, n, -0.18, 0.18, -0.2, 0.2, y + 0.42, y + 0.47)
				_klotz("holz", m + u * su * 0.6, u, n, -0.13, 0.13, -0.14, 0.14, y, y + 0.42)
		"truhe":
			_hausrat_stueck("truhe", m - n * 0.3, u, n, breite - 0.1, y, y + 3.0, zufall)
		"waffenkiste":
			_klotz("holz", m, u, n, -b, b, -0.35, 0.35, y, y + 0.6)
			_klotz("holz", m, u, n, -b, b, 0.35, 0.4, y + 0.55, y + 1.2)   # offener Deckel
			for i in 5:
				var t := -b + 0.15 + i * (2.0 * b - 0.3) / 4.0
				_klotz("metall", m + u * t, u, n, -0.015, 0.015, -0.12, 0.12, y + 0.6, y + 0.63)
				_klotz("stoff_leder", m + u * t, u, n, -0.02, 0.02, -0.02, 0.02, y + 0.63, y + 0.85)
			for q: float in [-0.6, 0.6]:
				_klotz("metall", m + u * q * b, u, n, -0.04, 0.04, -0.37, 0.37, y + 0.1, y + 0.5)
		"ruestbock":
			_klotz("holz", m, u, n, -0.3, 0.3, -0.3, 0.3, y, y + 0.06)
			_klotz("holz", m, u, n, -0.04, 0.04, -0.04, 0.04, y, y + 1.65)
			_klotz("holz", m, u, n, -0.3, 0.3, -0.03, 0.03, y + 1.45, y + 1.5)
			_klotz("metall", m, u, n, -0.24, 0.24, -0.15, 0.15, y + 0.95, y + 1.5)
			_klotz("metall", m, u, n, -0.27, 0.27, -0.16, 0.16, y + 0.85, y + 0.98)
			_klotz("metall", m, u, n, -0.13, 0.13, -0.14, 0.14, y + 1.6, y + 1.88)
			_klotz("dunkel", m, u, n, -0.09, 0.09, 0.14, 0.15, y + 1.7, y + 1.74)
			_klotz("stoff", m, u, n, -0.22, 0.22, 0.15, 0.17, y + 0.95, y + 1.45)   # Wappenrock
		"pfeilfass":
			_mantel("holz", m, 0.24, 0.28, y, y + 0.7, 10)
			_ring("holz", m, 0.0, 0.24, y + 0.7, 10)
			for i in 9:
				var a := TAU * i / 9.0
				var pm := m + u * cos(a) * 0.13 + n * sin(a) * 0.13
				_klotz("holz", pm, u, n, -0.007, 0.007, -0.007, 0.007, y + 0.7, y + 1.15)
				_klotz("hell", pm, u, n, -0.025, 0.025, -0.004, 0.004, y + 1.05, y + 1.15)
		"heu":
			_klotz("stroh", m, u, n, -b, b, -0.5, 0.5, y, y + 0.45, true)
			_klotz("stroh", m + u * 0.1, u, n, -b + 0.3, b - 0.2, -0.4, 0.45, y + 0.45, y + 0.85, true)
			_klotz("holz", m + n * -0.5, u, n, -0.015, 0.015, -0.015, 0.015, y, y + 1.6)   # Heugabel
			_klotz("metall", m + n * -0.5, u, n, -0.1, 0.1, -0.01, 0.01, y + 1.55, y + 1.85)
		"karre":
			_klotz("holz", m + u * 0.15, u, n, -0.5, 0.45, -0.32, 0.32, y + 0.3, y + 0.62)
			_klotz("stroh", m + u * 0.15, u, n, -0.45, 0.4, -0.28, 0.28, y + 0.62, y + 0.7)
			for w in 10:
				var a := TAU * w / 10.0
				_klotz("holz", m + u * (0.65 + cos(a) * 0.2), u, n, -0.03, 0.03, -0.03, 0.03, y + 0.22 + sin(a) * 0.2 - 0.03,
					y + 0.22 + sin(a) * 0.2 + 0.03)
			for sn: float in [-0.25, 0.25]:
				_klotz("holz", m + n * sn, u, n, -0.75, 0.65, -0.025, 0.025, y + 0.4, y + 0.45)
				_klotz("holz", m + n * sn + u * -0.2, u, n, -0.025, 0.025, -0.025, 0.025, y, y + 0.32)


## Wählt ein Stück Hausrat: [Name, Breite entlang der Wand, Höhe (höher als die Brüstung: nicht vor Fenstern)]
func _hausrat_wahl(zweck: int, k: int, zufall: RandomNumberGenerator) -> Array:
	var liste: Array
	match zweck:
		1:   # Küche und Vorrat
			liste = [["faesser", 1.4, 0.95], ["saecke", 1.3, 0.85], ["wandbrett", 1.6, 2.25], ["kraeuter", 1.4, 2.06],
				["hackklotz", 0.8, 0.82], ["bottich", 1.0, 0.55], ["kisten", 1.0, 1.0], ["pfannen", 1.2, 2.25]]
		3:   # Palas: Truhen, Kredenz, Wandbänke
			liste = [["truhe", 1.1, 0.65], ["kredenz", 1.6, 2.1], ["wandbank", 2.0, 1.0], ["truhe", 1.1, 0.65],
				["schrank", 1.3, 2.1]]
		4:   # Stall: Sättel, Zaumzeug, Futterkisten, Heugabeln
			liste = [["saettel", 1.6, 1.88], ["futter", 1.2, 0.95], ["geraet", 1.0, 2.0], ["saecke", 1.3, 0.85]]
		_:   # Wohn- und Gesindehaus
			liste = [["truhe", 1.1, 0.65], ["schrank", 1.3, 2.1], ["haken", 1.2, 1.85], ["wandbank", 1.8, 1.0],
				["wandbrett", 1.6, 2.25], ["faesser", 1.4, 0.95], ["strohlager", 2.1, 0.34] if k == 0 else ["truhe", 1.1, 0.65],
				["kisten", 1.0, 1.0]]
	return liste[zufall.randi() % liste.size()]


## Ein Stück Hausrat an der Wand: m auf der Wandfläche, n zeigt in den Raum, u entlang der Wand.
func _hausrat_stueck(name_: String, m: Vector2, u: Vector2, n: Vector2, breite: float, y: float, decke: float,
		zufall: RandomNumberGenerator) -> void:
	var b := breite / 2.0
	match name_:
		"truhe":
			_klotz("holz", m, u, n, -b + 0.05, b - 0.05, 0.05, 0.6, y, y + 0.5)
			_klotz("holz", m, u, n, -b + 0.03, b - 0.03, 0.03, 0.62, y + 0.5, y + 0.6, true)
			for q: float in [-0.6, 0.0, 0.6]:
				_klotz("metall", m + u * q * (b - 0.1), u, n, -0.04, 0.04, 0.02, 0.64, y + 0.05, y + 0.62)
			_klotz("metall", m, u, n, -0.07, 0.07, 0.62, 0.65, y + 0.38, y + 0.52)
		"schrank":
			_klotz("holz", m, u, n, -b + 0.05, b - 0.05, 0.02, 0.55, y, y + 2.0)
			_klotz("holz", m, u, n, -b, b, 0.0, 0.6, y + 2.0, y + 2.1, true)
			_klotz("holz", m, u, n, -b + 0.02, b - 0.02, 0.0, 0.58, y, y + 0.12)
			_klotz("dunkel", m, u, n, -0.01, 0.01, 0.55, 0.56, y + 0.15, y + 1.95)
			for q: float in [-1.0, 1.0]:
				_klotz("metall", m + u * q * 0.08, u, n, -0.015, 0.015, 0.55, 0.6, y + 1.0, y + 1.15)
				for hy: float in [0.4, 1.6]:
					_klotz("metall", m + u * q * (b - 0.25), u, n, -0.2, 0.2, 0.55, 0.57, y + hy, y + hy + 0.05)
		"kredenz":
			_klotz("holz", m, u, n, -b + 0.05, b - 0.05, 0.02, 0.5, y, y + 0.95)
			_klotz("holz", m, u, n, -b, b, 0.0, 0.55, y + 0.95, y + 1.02, true)
			_klotz("holz", m, u, n, -b + 0.05, b - 0.05, 0.0, 0.25, y + 1.02, y + 2.1)
			for br: float in [1.5, 2.0]:
				_klotz("holz", m, u, n, -b + 0.05, b - 0.05, 0.0, 0.3, y + br, y + br + 0.04)
			for t in 5:
				var tp := m + u * (-b + 0.3 + t * (breite - 0.6) / 4.0)
				_klotz("metall", tp, u, n, -0.09, 0.09, 0.08, 0.22, y + 1.02, y + 1.3 if t % 2 == 0 else y + 1.1)
				_klotz("metall", tp, u, n, -0.07, 0.07, 0.08, 0.2, y + 1.54, y + 1.72)
			_klotz("stoff", m, u, n, -b + 0.1, b - 0.1, 0.48, 0.51, y + 0.55, y + 1.0)
		"wandbank":
			_klotz("holz", m, u, n, -b, b, 0.0, 0.45, y + 0.42, y + 0.48)
			for q: float in [-1.0, 1.0]:
				_klotz("holz", m + u * q * (b - 0.15), u, n, -0.05, 0.05, 0.05, 0.4, y, y + 0.42)
			_klotz("holz", m, u, n, -b, b, 0.0, 0.06, y + 0.48, y + 1.0)
			_klotz("stoff", m + u * zufall.randf_range(-b + 0.4, b - 0.4), u, n, -0.25, 0.25, 0.08, 0.4, y + 0.48, y + 0.56)
		"wandbrett", "pfannen":
			for hy: float in [1.4, 1.9]:
				_klotz("holz", m, u, n, -b, b, 0.0, 0.28, y + hy - 0.04, y + hy, true)
				for q: float in [-1.0, 1.0]:
					_klotz("holz", m + u * q * (b - 0.15), u, n, -0.03, 0.03, 0.0, 0.25, y + hy - 0.25, y + hy - 0.04)
				var t := -b + 0.2
				while t < b - 0.15:
					var hoehe := zufall.randf_range(0.12, 0.3)
					_klotz("hell" if zufall.randf() < 0.5 else "metall", m + u * t, u, n, -0.08, 0.08, 0.06, 0.22, y + hy, y + hy + hoehe)
					t += zufall.randf_range(0.22, 0.38)
			if name_ == "pfannen":
				# Pfannen und Kellen an Haken unter dem Brett
				var t2 := -b + 0.25
				while t2 < b - 0.2:
					_klotz("metall", m + u * t2, u, n, -0.015, 0.015, 0.02, 0.05, y + 0.9, y + 1.3)
					_klotz("metall", m + u * t2, u, n, -0.15, 0.15, 0.02, 0.06, y + 0.6, y + 0.9)
					t2 += 0.4
			else:
				_klotz("holz", m, u, n, -b + 0.1, b - 0.1, 0.05, 0.5, y, y + 0.7)   # Unterschrank
		"kraeuter":
			_klotz("holz", m, u, n, -b, b, 0.02, 0.08, y + 2.0, y + 2.06)
			var t := -b + 0.15
			while t < b - 0.1:
				_klotz("stroh" if zufall.randf() < 0.5 else "stoff", m + u * t, u, n, -0.06, 0.06, 0.04, 0.14, y + 1.55, y + 2.0)
				t += 0.25
			_klotz("holz", m, u, n, -b + 0.1, b - 0.1, 0.05, 0.5, y, y + 0.7)
			_klotz("holz", m, u, n, -b + 0.05, b - 0.05, 0.03, 0.55, y + 0.7, y + 0.78, true)
		"faesser":
			for q: float in [-0.35, 0.35]:
				var fm := m + u * q + n * 0.38
				_mantel("holz", fm, 0.28, 0.33, y, y + 0.45, 10)
				_mantel("holz", fm, 0.33, 0.28, y + 0.45, y + 0.9, 10)
				_ring("holz", fm, 0.0, 0.28, y + 0.9, 10)
				for ry: float in [0.15, 0.75]:
					_mantel("metall", fm, 0.32, 0.33, y + ry, y + ry + 0.05, 10)
			_klotz("holz", m + n * 0.38, u, n, -0.25, 0.25, -0.2, 0.2, y + 0.9, y + 0.95)
		"saecke":
			for t in 3:
				var q := -b + 0.25 + t * (breite - 0.5) / 2.0
				_klotz("stroh", m + u * q, u, n, -0.22, 0.22, 0.05, 0.5, y, y + 0.5 + 0.08 * (t % 2), true)
			_klotz("stroh", m + u * 0.1, u, n, -0.2, 0.2, 0.08, 0.45, y + 0.5, y + 0.85, true)
		"kisten":
			_klotz("holz", m, u, n, -0.42, 0.42, 0.05, 0.85, y, y + 0.7)
			_klotz("metall", m, u, n, -0.44, 0.44, 0.04, 0.87, y + 0.6, y + 0.66)
			_klotz("holz", m + u * 0.05, u, n, -0.3, 0.3, 0.15, 0.7, y + 0.7, y + 1.0)
		"hackklotz":
			_mantel("holz", m + n * 0.45, 0.32, 0.32, y, y + 0.7, 10)
			_ring("holz", m + n * 0.45, 0.0, 0.32, y + 0.7, 10)
			_klotz("metall", m + n * 0.45, u, n, -0.02, 0.12, -0.02, 0.02, y + 0.7, y + 0.82)
			_klotz("holz", m + n * 0.45 + u * 0.12, u, n, 0.0, 0.35, -0.015, 0.015, y + 0.75, y + 0.78)
		"bottich":
			_mantel("holz", m + n * 0.45, 0.4, 0.44, y, y + 0.55, 12)
			_ring("wasser_innen", m + n * 0.45, 0.0, 0.4, y + 0.5, 12)
			_mantel("metall", m + n * 0.45, 0.43, 0.445, y + 0.4, y + 0.45, 12)
		"haken":
			_klotz("holz", m, u, n, -b, b, 0.0, 0.05, y + 1.75, y + 1.85)
			var t := -b + 0.2
			while t < b - 0.1:
				_klotz("holz", m + u * t, u, n, -0.02, 0.02, 0.05, 0.15, y + 1.78, y + 1.82)
				if zufall.randf() < 0.7:
					_klotz("stoff", m + u * t, u, n, -0.18, 0.18, 0.06, 0.16, y + 0.9, y + 1.8)
				t += 0.35
			_klotz("holz", m, u, n, -b + 0.1, b - 0.1, 0.0, 0.35, y + 0.4, y + 0.46)   # Schuhbank
		"strohlager":
			_klotz("stroh", m, u, n, -b + 0.05, b - 0.05, 0.05, 0.95, y, y + 0.22)
			_klotz("stoff", m, u, n, -b + 0.3, b - 0.15, 0.1, 0.9, y + 0.22, y + 0.28)
			_klotz("hell", m + u * (-b + 0.3), u, n, -0.2, 0.15, 0.2, 0.8, y + 0.22, y + 0.34)
		"saettel":
			for t in 2:
				var sm := m + u * (-b / 2.0 + t * b)
				_klotz("holz", sm, u, n, -0.04, 0.04, 0.0, 0.55, y + 1.1, y + 1.18)
				_klotz("stoff_leder", sm, u, n, -0.3, 0.3, 0.05, 0.55, y + 1.18, y + 1.32, true)
				_klotz("stoff_leder", sm, u, n, -0.3, 0.3, 0.05, 0.1, y + 0.7, y + 1.18)
				_klotz("metall", sm, u, n, -0.03, 0.03, 0.04, 0.1, y + 0.5, y + 0.7)
			_klotz("holz", m, u, n, -b + 0.1, b - 0.1, 0.0, 0.05, y + 1.8, y + 1.88)
			var t2 := -b + 0.25
			while t2 < b - 0.2:
				_klotz("stoff_leder", m + u * t2, u, n, -0.03, 0.03, 0.04, 0.08, y + 1.2, y + 1.85)   # Zaumzeug
				t2 += 0.45
		"futter":
			_klotz("holz", m, u, n, -b + 0.05, b - 0.05, 0.05, 0.75, y, y + 0.8)
			_klotz("holz", m, u, n, -b + 0.05, b - 0.05, 0.05, 0.75, y + 0.8, y + 0.86, true)
			_klotz("stroh", m + u * 0.2, u, n, -0.4, 0.3, 0.2, 0.6, y + 0.86, y + 0.95)
		"geraet":
			for t in 3:
				var gm := m + u * (-0.35 + t * 0.35)
				_klotz("holz", gm, u, n, -0.02, 0.02, 0.08, 0.12, y, y + 1.7)
				_klotz("metall", gm, u, n, -0.12, 0.12, 0.08, 0.14, y + 1.7, y + 1.75)
				for z: float in [-0.1, 0.0, 0.1]:
					_klotz("metall", gm + u * z, u, n, -0.01, 0.01, 0.08, 0.14, y + 1.75, y + 2.0)


## Regal an der Wand (Seite -1/1 über nx), Breite entlang uz, mit Krügen und Töpfen auf den Brettern.
func _regal(m: Vector2, uz: Vector2, nx: Vector2, seite: float, y: float, breite: float, hoehe: float) -> void:
	var n := nx * seite
	var b := breite / 2.0
	for e: float in [-1.0, 1.0]:
		_klotz("holz", m + uz * e * (b - 0.04), uz, n, -0.04, 0.04, -0.2, 0.2, y, y + hoehe)
	var brett := 0.4
	var i := 0
	while brett < hoehe:
		_klotz("holz", m, uz, n, -b, b, -0.2, 0.2, y + brett - 0.04, y + brett)
		for t in 3:
			var tp := m + uz * (-b + 0.3 + t * (breite - 0.6) / 2.0)
			_klotz("hell" if (t + i) % 2 == 0 else "metall", tp, uz, n, -0.1, 0.1, -0.1, 0.1, y + brett, y + brett + 0.18 + 0.06 * ((t + i) % 2))
		brett += 0.6
		i += 1


## Kerzenleuchter auf dem Boden: Fuß, Schaft, drei Kerzen
func _leuchter(m: Vector2, uz: Vector2, nx: Vector2, y: float) -> void:
	_klotz("metall", m, uz, nx, -0.2, 0.2, -0.2, 0.2, y, y + 0.06)
	_klotz("metall", m, uz, nx, -0.03, 0.03, -0.03, 0.03, y + 0.06, y + 1.5)
	_klotz("metall", m, uz, nx, -0.3, 0.3, -0.03, 0.03, y + 1.5, y + 1.54)
	for e: float in [-0.27, 0.0, 0.27]:
		_klotz("hell", m + uz * e, uz, nx, -0.03, 0.03, -0.03, 0.03, y + 1.54, y + 1.72)
		_klotz("glut", m + uz * e, uz, nx, -0.015, 0.015, -0.015, 0.015, y + 1.72, y + 1.77)


## Fenster von innen: helle Scheibe (Tageslicht) mit Bleiruten, tiefe Nische mit Gewände, Sitzbank und Sturz.
## seite zeigt in den Raum.
func _fenster_innen(c: Vector2, u: Vector2, n: Vector2, pos: float, abstand: float, seite: float, ym: float, fb: float, fh: float) -> void:
	var nn := n * signf(seite)
	var m := c + u * pos + n * abstand
	var b := fb / 2.0
	var y0 := ym - fh / 2.0
	var y1 := ym + fh / 2.0
	_klotz("fensterlicht", m, u, nn, -b, b, 0.005, 0.025, y0, y1)
	_bleiglas(m, u, nn, -b, b, y0, y1, 0.03, "metall")
	_klotz("zier_hell", m, u, nn, -b - 0.2, b + 0.2, 0.0, 0.3, y0 - 0.1, y0, true)
	_klotz("zier_hell", m, u, nn, -b - 0.2, -b, 0.0, 0.22, y0, y1)
	_klotz("zier_hell", m, u, nn, b, b + 0.2, 0.0, 0.22, y0, y1)
	_klotz("zier_hell", m, u, nn, -b - 0.25, b + 0.25, 0.0, 0.24, y1, y1 + 0.22, true)
	_klotz("zier_holz", m, u, nn, -0.04, 0.04, 0.025, 0.07, y0, y1)
	_klotz("zier_holz", m, u, nn, -b, b, 0.025, 0.07, y0 + fh * 0.64 - 0.04, y0 + fh * 0.64 + 0.04)
	# Riegel am Fensterflügel
	_klotz("metall", m, u, nn, 0.05, 0.16, 0.07, 0.09, ym - 0.03, ym + 0.03)


func _hoehle(w: PackedFloat32Array) -> void:
	var o := Vector3(w[2], 0, w[3]).normalized()
	var steig := w[4]
	var b := w[5] / 2.0
	var h := w[6]
	var fuss := Vector3(w[0], -19.4, w[1])
	var r := Vector3(-o.z, 0, o.x)
	var t := (Vector3.UP * steig - o).normalized()             # am Fels hinauf
	var nrm := (o * steig + Vector3.UP).normalized()            # aus dem Fels heraus
	var pt := func(u: float, v: float, ab: float) -> Vector3:
		return fuss + r * u + t * v + nrm * ab
	# Umriss: gerade Seiten bis 45 % der Höhe, darüber ein Bogen
	var hv := h * 0.45
	var umriss: Array[Vector2] = [Vector2(-b, 0), Vector2(-b, hv)]
	for k in range(1, 12):
		var a := PI - PI * k / 12.0
		umriss.append(Vector2(b * cos(a), hv + (h - hv) * sin(a)))
	umriss.append_array([Vector2(b, hv), Vector2(b, 0)])
	var mitte: Vector3 = pt.call(0.0, h * 0.4, 1.0)
	for k in umriss.size() - 1:
		var a: Vector2 = umriss[k]
		var e: Vector2 = umriss[k + 1]
		_dreieck("dunkel", mitte, pt.call(a.x, a.y, 1.0), pt.call(e.x, e.y, 1.0), nrm)
		# Felsrand: innen weit vorstehend, außen flach in den Fels
		var aa := Vector2(a.x * 1.35, a.y * 1.2)
		var ee := Vector2(e.x * 1.35, e.y * 1.2)
		_viereck("fels", pt.call(a.x, a.y, 1.6), pt.call(e.x, e.y, 1.6), pt.call(ee.x, ee.y, -0.4), pt.call(aa.x, aa.y, -0.4), nrm + t * 0.3)
		_viereck("fels", pt.call(a.x, a.y, 1.6), pt.call(e.x, e.y, 1.6), pt.call(e.x, e.y, 0.95), pt.call(a.x, a.y, 0.95), -nrm)
	# Steinpodest vor der Öffnung, knapp über dem Wasser
	var c2 := Vector2(fuss.x, fuss.z) + Vector2(o.x, o.z) * 1.0
	_klotz("bruchstein", c2, Vector2(r.x, r.z), Vector2(o.x, o.z), -b - 1.2, b + 3.5, -1.2, 1.8, -21.5, -19.45)
	# Stufen seitlich am Fels hinauf
	for k in 8:
		var y := -19.45 + (k + 1) * 0.28
		var s_ := b + 1.2 + k * 0.42
		var m := Vector2(fuss.x, fuss.z) + Vector2(r.x, r.z) * s_
		var hinten := -(y + 19.4) / maxf(steig, 0.5) - 0.6
		_klotz("bruchstein", m, Vector2(r.x, r.z), Vector2(o.x, o.z), -0.21, 0.21, hinten, 0.9, -21.5, y)


## Torbogen: Mauerblock über der Durchfahrt mit rundem Bogen und halb hochgezogenem Fallgitter.
func _tor(c: Vector2, u: Vector2, boden: float, breite: float, oben: float, dicke: float) -> void:
	u = u.normalized()
	var n := Vector2(-u.y, u.x)
	var w := breite / 2.0
	var kaempfer := boden + KAEMPFER
	var scheitel := kaempfer + w
	if oben < scheitel + 1.0:
		oben = scheitel + 1.0
	var d := dicke / 2.0 + 0.2
	var teile := 12
	var p := func(su: float, sn: float, y: float) -> Vector3:
		var q := c + u * su + n * sn
		return Vector3(q.x, y, q.y)
	var N := Vector3(n.x, 0, n.y)
	for k in teile:
		var w0 := PI * k / teile
		var w1 := PI * (k + 1) / teile
		var x0 := w * cos(w0)
		var x1 := w * cos(w1)
		var y0 := kaempfer + w * sin(w0)
		var y1 := kaempfer + w * sin(w1)
		for seite: float in [-1.0, 1.0]:
			_viereck(stein, p.call(x0, d * seite, y0), p.call(x1, d * seite, y1), p.call(x1, d * seite, oben), p.call(x0, d * seite, oben), N * seite)
		# Bogenlaibung, die Vorderseite zeigt zur Bogenmitte
		var zur_mitte := Vector3(u.x, 0, u.y) * -(x0 + x1) / 2.0 + Vector3.UP * (kaempfer - (y0 + y1) / 2.0)
		_viereck(stein, p.call(x0, -d, y0), p.call(x1, -d, y1), p.call(x1, d, y1), p.call(x0, d, y0), zur_mitte)
	# Wangen beiderseits bis unter die Brustwehr: Sie decken auch die Fuge zu den Mauerstücken (deren Enden liegen
	# wegen gerundeter Koordinaten um Millimeter neben dem Bogen, sonst sähe man dort einen Spalt Himmel)
	_klotz(stein, c, u, n, w, w + 0.8, -d, d, boden - 0.5, oben)
	_klotz(stein, c, u, n, -w - 0.8, -w, -d, d, boden - 0.5, oben)
	# Bogensteine als Kranz auf beiden Seiten
	for k in teile:
		var wm := PI * (k + 0.5) / teile
		var x := (w + 0.3) * cos(wm)
		var y := kaempfer + (w + 0.3) * sin(wm)
		for seite: float in [-1.0, 1.0]:
			var q := c + u * x + n * (d + 0.04) * seite
			_klotz(stein, q, u, n, -0.32, 0.32, -0.08, 0.08, y - 0.3, y + 0.3)
	# Laternen beiderseits des Bogens, auf beiden Seiten der Mauer
	for seite: float in [-1.0, 1.0]:
		for su: float in [-1.0, 1.0]:
			var lm := c + u * su * (w + 1.3) + n * (d + 0.05) * seite
			var y := kaempfer + 0.4
			_klotz("metall", lm, u, n * seite, -0.04, 0.04, 0.0, 0.45, y + 0.55, y + 0.62)
			_klotz("metall", lm + n * seite * 0.45, u, n * seite, -0.18, 0.18, -0.18, 0.18, y + 0.5, y + 0.56)
			_klotz("glut", lm + n * seite * 0.45, u, n * seite, -0.13, 0.13, -0.13, 0.13, y, y + 0.5)
			_klotz("metall", lm + n * seite * 0.45, u, n * seite, -0.17, 0.17, -0.17, 0.17, y - 0.06, y)
	# Brustwehr und Zinnen auf dem Bogen
	_klotz(stein, c, u, n, -w - 0.8, w + 0.8, d - BRUSTWEHR_DICKE, d, oben, oben + BRUSTWEHR)
	_zinnen(c, u, n, breite + 1.6, d - BRUSTWEHR_DICKE, d, oben + BRUSTWEHR)
	# Torflügel aus Bohlen mit Eisenbändern, geöffnet: zu beiden Seiten an die Laibung geklappt (ohne Kollision, damit
	# sie den Durchgang nicht verengen)
	var fl := minf(w - 0.1, 2.0 * d - 0.4)
	for seite: float in [-1.0, 1.0]:
		var x := seite * (w - 0.1)
		_klotz("holz", c, u, n, x - 0.06, x + 0.06, -d + 0.15, -d + 0.15 + fl, boden + 0.05, kaempfer + w * 0.6, true)
		for y: float in [boden + 0.6, kaempfer - 0.3, kaempfer + w * 0.4]:
			_klotz("metall", c, u, n, x - seite * 0.08 - 0.02, x - seite * 0.08 + 0.02, -d + 0.15, -d + 0.15 + fl * 0.85, y, y + 0.12, true)
	# Fallgitter, hochgezogen: nur die Spitzen schauen unter dem Bogen hervor
	var unterkante := maxf(kaempfer + w * 0.45, boden + 3.2)
	var stab := -w + 0.25
	while stab < w - 0.1:
		var oberkante := kaempfer + sqrt(maxf(w * w - stab * stab, 0.0)) - 0.05
		if oberkante > unterkante + 0.3:
			_klotz("metall", c, u, n, stab - 0.05, stab + 0.05, d * 0.4 - 0.05, d * 0.4 + 0.05, unterkante, oberkante, true)
			_klotz("metall", c, u, n, stab - 0.09, stab + 0.09, d * 0.4 - 0.06, d * 0.4 + 0.06, unterkante - 0.25, unterkante, true)
		stab += 0.45
	var quer := unterkante + 0.3
	while quer < scheitel - 0.3:
		var halb := sqrt(maxf(w * w - pow(quer - kaempfer, 2.0), 0.0)) if quer > kaempfer else w
		_klotz("metall", c, u, n, -halb + 0.05, halb - 0.05, d * 0.4 - 0.04, d * 0.4 + 0.04, quer, quer + 0.08, true)
		quer += 0.5


## Eckiger Torturm mit Anlauf, Gesims, Pechnasen zur Feldseite und Zeltdach oder Zinnen.
func _torturm(c: Vector2, u: Vector2, unten: float, oben: float, breite: float, tiefe: float, aussen: float, dach: float) -> void:
	u = u.normalized()
	var n := Vector2(-u.y, u.x) * signf(aussen if aussen != 0.0 else 1.0)
	var b := breite / 2.0
	var t := tiefe / 2.0
	var h := oben - unten
	var hohl := dach <= -1.5          # begehbarer Bergfried: Mauern mit Tür zur Hofseite (-n), innen baut turm.gd
	if hohl:
		_hohl(c, u, n, b, t, HOHL_WAND, unten, oben, hohl_boden)
	else:
		_klotz(stein, c, u, n, -b, b, -t, t, unten, oben)
	# Anlauf rundum
	var vor := clampf(h * 0.08, 0.5, 1.2)
	var hoch := clampf(h * 0.25, 1.5, 5.0)
	if hohl:
		_hohl(c, u, n, b + vor * 0.5, t + vor * 0.5, HOHL_WAND + vor * 0.5, unten, unten + hoch * 0.5, hohl_boden)
	else:
		_klotz(stein, c, u, n, -b - vor * 0.5, b + vor * 0.5, -t - vor * 0.5, t + vor * 0.5, unten, unten + hoch * 0.5)
	# Ecksteine (Eckquaderung) in hellerem Stein
	var y := unten + hoch
	var wechsel := false
	while y < oben - 1.0:
		for su: float in [-1.0, 1.0]:
			for sn: float in [-1.0, 1.0]:
				var lu := 0.9 if wechsel else 0.5
				var ln := 0.5 if wechsel else 0.9
				_klotz(stein, c, u, n, su * b - (lu if su > 0 else -0.06), su * b + (0.06 if su > 0 else lu),
					sn * t - (ln if sn > 0 else -0.06), sn * t + (0.06 if sn > 0 else ln), y, y + 0.46)
		y += 0.5
		wechsel = not wechsel
	# Gesims
	if hohl:
		_hohl(c, u, n, b + 0.2, t + 0.2, 0.6, oben - 0.5, oben - 0.2, -1000.0)
	else:
		_klotz(stein, c, u, n, -b - 0.2, b + 0.2, -t - 0.2, t + 0.2, oben - 0.5, oben - 0.2, true)
	# Pechnasen: Kragsteine und vorkragende Brustwehr auf der Feldseite
	var k := -b + 0.4
	while k < b - 0.2:
		_klotz(stein, c, u, n, k - 0.18, k + 0.18, t, t + 0.75, oben - 1.3, oben + 0.1)
		k += 0.9
	_klotz(stein, c, u, n, -b, b, t + 0.1, t + 0.75, oben + 0.1, oben + 1.3, true)
	# Schießscharten
	for seite: float in [-1.0, 1.0]:
		_klotz("dunkel", c, u, n, -0.08, 0.08, seite * t - 0.02 if seite > 0 else -t - 0.015, seite * t + 0.015 if seite > 0 else -t + 0.02,
			unten + h * 0.55, unten + h * 0.55 + 1.2)
	if dach < 0.0:
		_bergfried_krone(c, u, n, b, t, unten, oben, hohl)
	elif dach >= 1.0:
		# Mauerband rundum bis unter das Dach, sonst schwebt es über dem Turm
		_klotz(stein, c, u, n, -b, b, -t, t, oben, oben + 1.3)
		var ue := 0.9
		var spitze := Vector3(c.x, oben + 1.3 + maxf(breite, tiefe) * 0.9 * dach, c.y)
		var p := func(su: float, sn: float) -> Vector3:
			var q := c + u * su + n * sn
			return Vector3(q.x, oben + 1.3, q.y)
		var ecken := [p.call(-b - ue, -t - ue), p.call(b + ue, -t - ue), p.call(b + ue, t + ue + 0.65), p.call(-b - ue, t + ue + 0.65)]
		for i in 4:
			var a: Vector3 = ecken[i]
			var e: Vector3 = ecken[(i + 1) % 4]
			var mitte := (a + e) / 2.0
			var kante := a.distance_to(e)
			var schraege := mitte.distance_to(spitze)
			_dreieck_uv("dach", [a, e, spitze], [Vector2(0, schraege), Vector2(kante, schraege), Vector2(kante / 2.0, 0)],
				(mitte - Vector3(c.x, mitte.y, c.y)).normalized() + Vector3.UP * 0.5)
		_viereck("dach", ecken[0], ecken[1], ecken[2], ecken[3], Vector3.DOWN)
		_kegel("metall", c, 0.2, spitze.y - 0.3, 1.2, 8)
	else:
		# Plattform mit Brustwehr rundum und Zinnen auf allen vier Seiten
		_klotz("boden", c, u, n, -b, b, -t, t, oben, oben + 0.05)
		_klotz(stein, c, u, n, -b, b, -t - 0.0, -t + BRUSTWEHR_DICKE, oben, oben + 1.3)
		_klotz(stein, c, u, n, -b, -b + BRUSTWEHR_DICKE, -t, t, oben, oben + 1.3)
		_klotz(stein, c, u, n, b - BRUSTWEHR_DICKE, b, -t, t, oben, oben + 1.3)
		_zinnen(c, u, n, breite, t + 0.1, t + 0.75, oben + 1.3)
		_zinnen(c, -u, -n, breite, t - BRUSTWEHR_DICKE, t, oben + 1.3)
		_zinnen(c, n, -u, tiefe, b - BRUSTWEHR_DICKE, b, oben + 1.3)
		_zinnen(c, -n, u, tiefe, b - BRUSTWEHR_DICKE, b, oben + 1.3)


## Krone eines Bergfrieds (dach < 0): Zinnenplattform, vier Ecktürmchen mit Kegeldach auf Kragsteinen, Reihen von
## Schießscharten und oben große Bogenfenster.
func _bergfried_krone(c: Vector2, u: Vector2, n: Vector2, b: float, t: float, unten: float, oben: float, hohl := false) -> void:
	# Schlichter Vierkantturm wie im Referenzbild: Bogenfries unter einer leicht vorkragenden Brustwehr mit Zinnen,
	# oben auf jeder Seite ein gekuppeltes Rundbogenfenster, darunter nur Schlitze.
	var vor := 0.35
	if not hohl:
		_klotz("boden", c, u, n, -b, b, -t, t, oben, oben + 0.05)     # hohl: das Dach mit dem Treppenloch baut turm.gd
	for seite in [[u, n, b, t], [-u, -n, b, t], [n, -u, t, b], [-n, u, t, b]]:
		var su: Vector2 = seite[0]
		var sn: Vector2 = seite[1]
		var lb: float = seite[2]
		var lt: float = seite[3]
		# Bogenfries: kleine Konsolen, darüber die vorkragende Brustwehr
		var k := -lb + 0.45
		while k < lb - 0.3:
			_klotz(stein, c, su, sn, k - 0.18, k + 0.18, lt - 0.02, lt + vor, oben - 1.2, oben - 0.2)
			k += 0.9
		_klotz(stein, c, su, sn, -lb - vor, lb + vor, lt - BRUSTWEHR_DICKE, lt + vor, oben - 0.2, oben + 1.3, true)
		_zinnen(c, su, sn, lb * 2.0 + vor * 2.0 - 1.0, lt + vor - BRUSTWEHR_DICKE, lt + vor, oben + 1.3)
		# gekuppeltes Rundbogenfenster unter der Krone
		var m: Vector2 = c + sn * lt
		var yf := oben - 6.5
		for e: float in [-0.75, 0.75]:
			var fm := m + su * e
			_klotz("dunkel", fm, su, sn, -0.45, 0.45, -0.05, 0.02, yf, yf + 2.2)
			for kk in 6:
				var w0 := PI * kk / 6.0
				var w1 := PI * (kk + 1) / 6.0
				var p0 := fm + su * (0.45 * cos(w0)) + sn * 0.03
				var p1 := fm + su * (0.45 * cos(w1)) + sn * 0.03
				_dreieck("dunkel", Vector3(fm.x + sn.x * 0.03, yf + 2.2, fm.y + sn.y * 0.03), Vector3(p0.x, yf + 2.2 + 0.45 * sin(w0), p0.y),
					Vector3(p1.x, yf + 2.2 + 0.45 * sin(w1), p1.y), Vector3(sn.x, 0, sn.y))
		_klotz("hell", m, su, sn, -0.08, 0.08, -0.02, 0.1, yf, yf + 2.4)          # Mittelsäule
		_klotz("hell", m, su, sn, -1.4, 1.4, -0.02, 0.2, yf - 0.25, yf, true)    # Sohlbank
	# Gliederung wie im Referenzbild: geböschter Sockel, ein Gesimsband unter dem Obergeschoss, darunter auf jeder
	# Seite ein einzelnes Rundbogenfenster
	if hohl:
		_hohl(c, u, n, b + 0.6, t + 0.6, HOHL_WAND + 0.6, unten, unten + 5.5, hohl_boden)
		_hohl(c, u, n, b + 0.7, t + 0.7, 0.7, unten + 5.5, unten + 5.85, hohl_boden)
	else:
		_klotz(stein, c, u, n, -b - 0.6, b + 0.6, -t - 0.6, t + 0.6, unten, unten + 5.5, true)
		_klotz("hell", c, u, n, -b - 0.7, b + 0.7, -t - 0.7, t + 0.7, unten + 5.5, unten + 5.85, true)
	if hohl:
		_hohl(c, u, n, b + 0.18, t + 0.18, 0.5, oben - 9.6, oben - 9.25, -1000.0)
	else:
		_klotz("hell", c, u, n, -b - 0.18, b + 0.18, -t - 0.18, t + 0.18, oben - 9.6, oben - 9.25, true)
	for seite in [[u, n, b, t], [-u, -n, b, t], [n, -u, t, b], [-n, u, t, b]]:
		_rundbogen(c + seite[1] * (seite[3] + 0.02), seite[0], seite[1], oben - 16.5, 1.0, 2.4, 0.22)
	# Schlitze in Reihen
	var y := unten + 9.0
	while y < oben - 19.0:
		for seite in [[u, n, b, t], [-u, -n, b, t], [n, -u, t, b], [-n, u, t, b]]:
			_klotz("dunkel", c + seite[1] * seite[3], seite[0], seite[1], -0.09, 0.09, -0.04, 0.02, y, y + 1.4)
		y += 7.0


## Hohler Turmkörper: vier Mauern der Stärke dicke um die Mitte, auf der Seite -n eine Tür (HOHL_TUER breit, unten
## ab tuer_boden 3,6 m hoch) mit einem Rahmen aus hellem Stein.
func _hohl(c: Vector2, u: Vector2, n: Vector2, b: float, t: float, dicke: float, unten: float, oben: float, tuer_boden: float) -> void:
	_klotz(stein, c, u, n, -b, b, t - dicke, t, unten, oben)
	_klotz(stein, c, u, n, -b, -b + dicke, -t + dicke, t - dicke, unten, oben)
	_klotz(stein, c, u, n, b - dicke, b, -t + dicke, t - dicke, unten, oben)
	var w := HOHL_TUER / 2.0
	var th := tuer_boden + 3.6
	_klotz(stein, c, u, n, -b, -w, -t, -t + dicke, unten, oben)
	_klotz(stein, c, u, n, w, b, -t, -t + dicke, unten, oben)
	if oben > th:
		_klotz(stein, c, u, n, -w, w, -t, -t + dicke, maxf(unten, th), oben)
	if unten < tuer_boden:
		_klotz(stein, c, u, n, -w, w, -t, -t + dicke, unten, minf(oben, tuer_boden))
	if unten <= th and oben >= th:
		_klotz("hell", c, u, n, -w - 0.3, w + 0.3, -t - 0.12, -t + 0.05, th, th + 0.4)


## Treppe aus Steinstufen (je 0,25 m) zwischen zwei Wangenmauern, alle 16 Stufen ein Absatz.
func _treppe(a: Vector3, b: Vector3, breite: float) -> void:
	var waag := Vector2(b.x - a.x, b.z - a.z)
	var laenge := waag.length()
	var u := waag / laenge
	var n := Vector2(-u.y, u.x)
	var steig := b.y - a.y
	var stufen := maxi(1, int(absf(steig) / 0.25))
	var hb := breite / 2.0
	var c0 := Vector2(a.x, a.z)
	for k in stufen:
		var t0 := float(k) / stufen
		var t1 := float(k + 1) / stufen
		var y := a.y + steig * t1
		var m := c0 + u * laenge * (t0 + t1) / 2.0
		_klotz("boden", m, u, n, -laenge / stufen / 2.0 - 0.02, laenge / stufen / 2.0 + 0.02, -hb, hb, y - 0.6, y)
		# Stufenkante etwas heller und vorstehend
		_klotz("hell", c0 + u * laenge * t0, u, n, -0.12, 0.12, -hb, hb, y - 0.25, y - 0.02)
	# Unsichtbare Rampe über den Stufenkanten: Darauf läuft die Figur hinauf, ohne an jeder Stufe hängen zu bleiben
	# über die Vorderkanten der Stufen: eine Trittlänge vor der ersten Stufe bis zur Vorderkante der obersten
	# 10 cm über den Kanten (sonst stehen die Kantenleisten bei steilen Treppen als Lippen über die Rampe); dafür setzt
	# die Rampe früher am Boden an, damit unten keine Kante bleibt
	var vor := laenge / stufen if steig > 0.0 else 0.0
	var anlauf := 0.1 * laenge / steig if steig > 0.0 else 0.0
	var s0 := c0 - u * (vor + anlauf)
	var s1 := c0 + u * (laenge - vor)
	var r0 := s0 - n * hb
	var r1 := s0 + n * hb
	var e0 := s1 - n * hb
	var e1 := s1 + n * hb
	var dy := 0.1 if steig > 0.0 else 0.02
	_viereck("rampe", Vector3(r0.x, a.y + 0.02, r0.y), Vector3(e0.x, b.y + dy, e0.y), Vector3(e1.x, b.y + dy, e1.y),
		Vector3(r1.x, a.y + 0.02, r1.y), Vector3.UP)
	# Wangen: niedrige Mauern zu beiden Seiten, oben schräg mit der Treppe
	for seite: float in [-1.0, 1.0]:
		var teile := maxi(1, int(laenge / 1.0))   # kurze Stücke: die Wange folgt der Steigung
		for k in teile:
			var t0 := float(k) / teile
			var t1 := float(k + 1) / teile
			var m := c0 + u * laenge * (t0 + t1) / 2.0
			var y_unten := a.y + steig * t0 - 3.0
			var y_oben := a.y + steig * t1 + 0.9
			_klotz(stein, m + n * seite * (hb + 0.4), u, n, -laenge / teile / 2.0 - 0.05, laenge / teile / 2.0 + 0.05, -0.4, 0.4,
				y_unten, y_oben)


## Gebäude mit Sockel, Stockwerksgesimsen, Fenstern mit Steinrahmen, Tür, Traufgesims und Satteldach mit Überstand,
## Firstziegeln und Schornstein.
func _gebaeude(w: PackedFloat32Array) -> void:
	var c := Vector2(w[0], w[1])
	var g := deg_to_rad(w[2])
	var nx := Vector2(cos(g), -sin(g))       # lokal x (Breite)
	var uz := Vector2(sin(g), cos(g))        # lokal z (Länge, First)
	var B := w[3] / 2.0
	var L := w[4] / 2.0
	var boden := w[5]
	var unten := w[6]
	var traufe := boden + w[7]
	var dh := w[8]
	var wand: String = [stein, "hell", "mauer", "holz"][clampi(int(w[9]), 0, 3)]
	var dach := "dach" if int(w[10]) == 0 else "ziegel"
	var roh := int(w[11])
	var art := roh % 10
	var begehbar := (roh / 10) % 10 >= 1   # Art + 10: innen hohl, mit offener Tür, Geschossen und Treppen
	var zweck := roh / 100                 # + 100 × Zweck: Einrichtung (siehe _einrichtung)
	if (roh / 10) % 10 == 2:               # Art + 20: ebenso, die Tür auf der anderen Seite (Bau um 180° gedreht)
		nx = -nx
		uz = -uz
	var geschosse := 1 if art == 1 else maxi(1, int(w[7] / (4.6 if art == 3 else 3.6)))
	var gh := w[7] / geschosse
	# Körper und Sockel
	if begehbar:
		_innenraum(c, uz, nx, B, L, boden, unten, traufe, geschosse, gh, wand, art, zweck)
	else:
		_klotz(wand, c, uz, nx, -L, L, -B, B, unten, traufe)
		_klotz("bruchstein", c, uz, nx, -L - 0.2, L + 0.2, -B - 0.2, B + 0.2, unten, boden + 0.7)
	for k in range(1, geschosse):
		var y := boden + k * gh
		_gesims(wand, c, uz, nx, B, L, 0.12, y - 0.15, y + 0.1, begehbar)
	_gesims(wand, c, uz, nx, B, L, 0.3, traufe - 0.4, traufe, begehbar)
	if art == 3:
		_palas_fassade(c, uz, nx, B, L, boden, gh, geschosse, traufe, dh, begehbar)
	# Fenster auf allen vier Seiten
	for k in (0 if art == 3 else geschosse):
		if art == 2 and k > 0:
			break
		var fh := gh * 0.62 if art == 1 else minf(1.7, gh * 0.48)
		var fb := 1.3 if art == 1 else 1.0
		var ym := boden + k * gh + gh * (0.5 if art == 1 else 0.55)
		for seite: float in [-1.0, 1.0]:
			# Längsseiten
			var anzahl := int((2.0 * L - 2.0) / (4.5 if art == 1 else 3.4))
			for f in anzahl:
				var pos := -L + 1.0 + (f + 0.5) * (2.0 * L - 2.0) / anzahl
				if k == 0 and seite > 0 and absf(pos) < 1.8 and art != 1:
					continue   # dort ist die Tür
				_fenster(c, uz, nx, pos, B * seite, seite, ym, fb, fh, art == 1)
				if begehbar:
					_fenster_innen(c, uz, nx, pos, (B - 0.6) * seite, -seite, ym, fb, fh)
			# Giebelseiten
			var quer := int((2.0 * B - 1.5) / 3.4)
			for f in quer:
				var pos := -B + 0.75 + (f + 0.5) * (2.0 * B - 1.5) / quer
				if art == 1 and seite > 0 and k == 0 and absf(pos) < 2.0:
					continue
				_fenster(c, nx, -uz, pos, -L * seite, -seite, ym, fb, fh, art == 1)
				if begehbar:
					_fenster_innen(c, nx, -uz, pos, -(L - 0.6) * seite, seite, ym, fb, fh)
	# Tür: bei Kirchen in der Giebelseite, sonst mitten in der Längsseite
	var fb_ := boden + 0.03 if begehbar else boden
	if art == 1:
		_tuer(c, nx, uz, 0.0, L, 1.0, fb_, 2.4, 4.0, begehbar)   # Portal in der Giebelseite gegenüber dem Turm
	else:
		_tuer(c, uz, nx, 0.0, B, 1.0, fb_, 1.6, 2.7, begehbar)
	# Dach
	var ue := 0.55
	var gu := 0.45
	var neig := dh / B
	var p := func(su: float, sn: float, y: float) -> Vector3:
		var q := c + uz * su + nx * sn
		return Vector3(q.x, y, q.y)
	var first := traufe + dh
	var y_rand := traufe - ue * neig
	for seite: float in [-1.0, 1.0]:
		var aussen := Vector3(nx.x * seite, 0, nx.y * seite) + Vector3.UP * B / maxf(dh, 0.1)
		var schraege := Vector2(B + ue, first - y_rand).length()
		_viereck_uv(dach, [p.call(-L - gu, (B + ue) * seite, y_rand), p.call(L + gu, (B + ue) * seite, y_rand),
			p.call(L + gu, 0.0, first), p.call(-L - gu, 0.0, first)],
			[Vector2(-L - gu, schraege), Vector2(L + gu, schraege), Vector2(L + gu, 0), Vector2(-L - gu, 0)], aussen)
		_viereck(dach, p.call(-L - gu, (B + ue) * seite, y_rand - 0.22), p.call(L + gu, (B + ue) * seite, y_rand - 0.22),
			p.call(L + gu, 0.0, first - 0.22), p.call(-L - gu, 0.0, first - 0.22), -aussen)
		_viereck(dach, p.call(-L - gu, (B + ue) * seite, y_rand), p.call(L + gu, (B + ue) * seite, y_rand),
			p.call(L + gu, (B + ue) * seite, y_rand - 0.22), p.call(-L - gu, (B + ue) * seite, y_rand - 0.22), Vector3(nx.x, 0, nx.y) * seite)
		for ende: float in [-1.0, 1.0]:
			var e := (L + gu) * ende
			_viereck(dach, p.call(e, (B + ue) * seite, y_rand), p.call(e, 0.0, first), p.call(e, 0.0, first - 0.22),
				p.call(e, (B + ue) * seite, y_rand - 0.22), Vector3(uz.x, 0, uz.y) * ende)
		# Giebeldreieck
		_dreieck(wand, p.call(L * seite, -B, traufe), p.call(L * seite, B, traufe), p.call(L * seite, 0.0, first - 0.1),
			Vector3(uz.x, 0, uz.y) * seite)
	_klotz(dach, c, uz, nx, -L - gu, L + gu, -0.22, 0.22, first - 0.15, first + 0.12)
	# Schornstein
	if art == 0 or art == 3:
		var sx := L * 0.45
		var sn := B * 0.35
		_klotz("bruchstein", c + uz * sx + nx * sn, uz, nx, -0.4, 0.4, -0.4, 0.4, traufe, first + 1.0)
		_klotz("bruchstein", c + uz * sx + nx * sn, uz, nx, -0.5, 0.5, -0.5, 0.5, first + 0.9, first + 1.15)


## Palas wie im Referenzbild: zum Hof (+B) unten eine Arkade aus Rundbögen, darüber Reihen von Rundbogenfenstern
## zwischen Lisenen, unter der Traufe ein Bogenfries, auf dem Dach zwei Gauben; hinten und an den Giebeln kleinere
## Rundbogenfenster; Eckquader in hellem Stein.
func _palas_fassade(c: Vector2, uz: Vector2, nx: Vector2, B: float, L: float, boden: float, gh: float, geschosse: int,
		traufe: float, dh: float, begehbar := false) -> void:
	var achsen := maxi(5, int((2.0 * L - 2.0) / 4.4))
	var abst := (2.0 * L - 2.0) / achsen
	for f in achsen:
		var pos := -L + 1.0 + (f + 0.5) * abst
		var m := c + uz * pos + nx * B
		# Arkadenbogen im Erdgeschoss (in der Mitte die Tür)
		if absf(pos) > abst * 0.6:
			_rundbogen(m, uz, nx, boden + 0.15, 2.6, gh * 0.62, 0.35)
		# Gekuppelte Rundbogenfenster in den Obergeschossen (wie im Referenzbild): zwei hohe Bögen, dazwischen
		# eine Säule, darunter eine durchgehende Sohlbank
		for k in range(1, geschosse):
			var fu := boden + k * gh + gh * 0.18
			var fh := gh * 0.62
			for e: float in [-1.0, 1.0]:
				_rundbogen(m + uz * e * 0.52, uz, nx, fu, 0.8, fh, 0.2)
			_klotz("hell", m, uz, nx, -0.09, 0.09, -0.04, 0.1, fu, fu + fh - 0.45)
			_klotz("hell", m, uz, nx, -0.16, 0.16, -0.04, 0.14, fu + fh - 0.45, fu + fh - 0.32)
			_klotz("hell", m, uz, nx, -1.15, 1.15, -0.02, 0.18, fu - 0.16, fu)
			_klotz("zier_hell", m, uz, nx, -1.25, 1.25, -0.02, 0.32, fu - 0.26, fu - 0.12, true)   # Sohlbank vorstehend
			for e: float in [-1.0, 1.0]:
				_klotz("zier_hell", m + uz * e * 1.12, uz, nx, -0.12, 0.12, -0.02, 0.26, fu - 0.5, fu - 0.26, true)   # Konsolen
			if begehbar:
				for e: float in [-1.0, 1.0]:
					_fenster_innen(c, uz, nx, pos + e * 0.52, B - 0.6, -1.0, fu + (fh - 0.4) / 2.0, 0.8, fh - 0.4)
		# Rückseite und Giebel: kleinere Fenster
		for k in range(1, geschosse):
			_rundbogen(c + uz * pos - nx * B, uz, -nx, boden + k * gh + gh * 0.3, 0.9, gh * 0.38, 0.2)
			if begehbar:
				_fenster_innen(c, uz, nx, pos, -(B - 0.6), 1.0, boden + k * gh + gh * 0.3 + (gh * 0.38 - 0.45) / 2.0, 0.9,
					gh * 0.38 - 0.45)
	# Lisenen zwischen den Achsen, vom ersten Obergeschoss bis unter den Fries
	for f in achsen + 1:
		var pos := -L + 1.0 + f * abst
		_klotz("hell", c + uz * pos + nx * B, uz, nx, -0.3, 0.3, -0.02, 0.14, boden + gh - 0.2, traufe - 0.9)
	# Stockwerksgesims über der Arkade
	_klotz("hell", c, uz, nx, -L, L, B - 0.02, B + 0.22, boden + gh - 0.35, boden + gh - 0.1, true)
	# Bogenfries unter der Traufe auf beiden Längsseiten
	for seite: float in [-1.0, 1.0]:
		var k := -L + 0.6
		while k < L - 0.4:
			_klotz("hell", c + uz * k + nx * B * seite, uz, nx * seite, -0.22, 0.22, -0.02, 0.2, traufe - 0.9, traufe - 0.45, true)
			k += 1.1
	for seite: float in [-1.0, 1.0]:
		for f in 3:
			var pos := (f - 1) * B * 0.55
			_rundbogen(c + uz * L * seite + nx * pos, nx, uz * seite, boden + gh + gh * 0.3, 0.9, gh * 0.38, 0.2)
	# Gauben auf der Hofseite des Daches (wie im Referenzbild zwei kräftige Steingauben mit Rundbogenfenster und
	# eigenem Satteldach)
	var neig := dh / B
	for e: float in [-0.4, 0.4]:
		var gm := c + uz * (e * L) + nx * (B * 0.55)
		var gy := traufe + (B - B * 0.55) * neig - 0.4
		var gb := 1.5      # halbe Breite
		var gt := 3.2      # Tiefe in das Dach
		_klotz(stein, gm, uz, nx, -gb, gb, -gt, 0.05, gy - 2.2, gy + 2.0)
		_klotz("hell", gm, uz, nx, -gb - 0.08, gb + 0.08, -0.02, 0.14, gy + 1.85, gy + 2.05, true)
		_rundbogen(gm + nx * 0.05, uz, nx, gy - 0.6, 1.1, 2.0, 0.2)
		for s2: float in [-1.0, 1.0]:
			_viereck("dach", Vector3(gm.x + uz.x * s2 * (gb + 0.25) + nx.x * 0.35, gy + 2.0, gm.y + uz.y * s2 * (gb + 0.25) + nx.y * 0.35),
				Vector3(gm.x + nx.x * 0.35, gy + 3.4, gm.y + nx.y * 0.35), Vector3(gm.x - nx.x * gt, gy + 3.4, gm.y - nx.y * gt),
				Vector3(gm.x + uz.x * s2 * (gb + 0.25) - nx.x * gt, gy + 2.0, gm.y + uz.y * s2 * (gb + 0.25) - nx.y * gt), Vector3(uz.x * s2, 1, uz.y * s2))
		# Giebeldreieck über dem Fenster
		_viereck(stein, Vector3(gm.x + uz.x * gb + nx.x * 0.05, gy + 2.0, gm.y + uz.y * gb + nx.y * 0.05),
			Vector3(gm.x + nx.x * 0.05, gy + 3.3, gm.y + nx.y * 0.05), Vector3(gm.x - uz.x * gb + nx.x * 0.05, gy + 2.0, gm.y - uz.y * gb + nx.y * 0.05),
			Vector3(gm.x - uz.x * gb + nx.x * 0.05, gy + 2.0, gm.y - uz.y * gb + nx.y * 0.05), Vector3(nx.x, 0, nx.y))
	# Eckquader
	var y := boden
	var wechsel := false
	while y < traufe - 0.6:
		for su: float in [-1.0, 1.0]:
			for sn: float in [-1.0, 1.0]:
				var lu := 0.9 if wechsel else 0.5
				var ln := 0.5 if wechsel else 0.9
				_klotz("hell", c, uz, nx, su * L - (lu if su > 0 else -0.06), su * L + (0.06 if su > 0 else lu),
					sn * B - (ln if sn > 0 else -0.06), sn * B + (0.06 if sn > 0 else ln), y, y + 0.46)
		y += 0.5
		wechsel = not wechsel


## Rundbogenöffnung in einer Wand (Mitte m auf der Außenfläche, n nach außen): dunkle Fläche mit Halbkreis oben,
## Gewände und Bogensteine in hellem Stein.
func _rundbogen(m: Vector2, u: Vector2, n: Vector2, unten: float, breite: float, hoehe: float, rahmen: float) -> void:
	var b := breite / 2.0
	var kaempfer := unten + hoehe - b
	var glas := rahmen < 0.3      # schmale Rahmen: Fenster mit Bleiglas, breite: dunkle Arkade
	var fuell := "zier_glas" if glas else "dunkel"
	_klotz(fuell, m, u, n, -b, b, -0.06, 0.02, unten, kaempfer)
	if glas:
		_bleiglas(m, u, n, -b, b, unten, kaempfer, 0.03, "metall")
		# tiefe Laibung: das Gewände steht weit vor
		_klotz("zier_hell", m, u, n, -b - rahmen, -b, 0.1, 0.24, unten, kaempfer)
		_klotz("zier_hell", m, u, n, b, b + rahmen, 0.1, 0.24, unten, kaempfer)
	var N3 := Vector3(n.x, 0, n.y)
	var mitte := Vector3(m.x + n.x * 0.02, kaempfer, m.y + n.y * 0.02)
	for k in 8:
		var w0 := PI * k / 8.0
		var w1 := PI * (k + 1) / 8.0
		var p0 := m + u * (b * cos(w0)) + n * 0.02
		var p1 := m + u * (b * cos(w1)) + n * 0.02
		_dreieck(fuell, mitte, Vector3(p0.x, kaempfer + b * sin(w0), p0.y), Vector3(p1.x, kaempfer + b * sin(w1), p1.y), N3)
		var wm := PI * (k + 0.5) / 8.0
		var q := m + u * ((b + rahmen * 0.5) * cos(wm))
		_klotz("hell", q, u, n, -0.18, 0.18, -0.02, 0.24 if glas else 0.1, kaempfer + (b + rahmen * 0.5) * sin(wm) - rahmen * 0.5,
			kaempfer + (b + rahmen * 0.5) * sin(wm) + rahmen * 0.5)
	_klotz("hell", m, u, n, -b - rahmen, -b, -0.02, 0.1, unten, kaempfer)
	_klotz("hell", m, u, n, b, b + rahmen, -0.02, 0.1, unten, kaempfer)


## Fenster des Palas: unten kleine Rechteckfenster, darüber gotische Doppelfenster (zwei Spitzbögen unter einem
## Bogenfeld) mit Steinrahmen; dazu Eckquader in hellem Stein.
func _palas_fenster(c: Vector2, uz: Vector2, nx: Vector2, B: float, L: float, boden: float, gh: float, geschosse: int,
		wand: String) -> void:
	for k in geschosse:
		var ym := boden + k * gh + gh * 0.52
		for seite: float in [-1.0, 1.0]:
			var anzahl := int((2.0 * L - 3.0) / 4.2)
			for f in anzahl:
				var pos := -L + 1.5 + (f + 0.5) * (2.0 * L - 3.0) / anzahl
				if k == 0:
					if seite > 0 and absf(pos) < 2.0:
						continue
					_fenster(c, uz, nx, pos, B * seite, seite, ym, 0.8, 1.2, false)
				else:
					_doppelfenster(c + uz * pos + nx * B * seite, uz, nx * seite, ym, gh * 0.62)
			var quer := int((2.0 * B - 3.0) / 4.2)
			for f in quer:
				var pos := -B + 1.5 + (f + 0.5) * (2.0 * B - 3.0) / quer
				if k > 0:
					_doppelfenster(c + nx * pos - uz * L * seite, -nx * seite, -uz * seite, ym, gh * 0.62)
	# Eckquader
	var y := boden
	var wechsel := false
	while y < boden + gh * geschosse - 0.6:
		for su: float in [-1.0, 1.0]:
			for sn: float in [-1.0, 1.0]:
				var lu := 0.9 if wechsel else 0.5
				var ln := 0.5 if wechsel else 0.9
				_klotz("hell", c, uz, nx, su * L - (lu if su > 0 else -0.06), su * L + (0.06 if su > 0 else lu),
					sn * B - (ln if sn > 0 else -0.06), sn * B + (0.06 if sn > 0 else ln), y, y + 0.46)
		y += 0.5
		wechsel = not wechsel


func _doppelfenster(m: Vector2, u: Vector2, n: Vector2, ym: float, fh: float) -> void:
	var y0 := ym - fh / 2.0
	var y1 := ym + fh / 2.0 - 0.6
	for seite: float in [-1.0, 1.0]:
		var mx := seite * 0.48
		_klotz("zier_glas", m + u * mx, u, n, -0.32, 0.32, -0.05, 0.02, y0, y1)
		_bleiglas(m + u * mx, u, n, -0.32, 0.32, y0, y1, 0.025, "metall")
		var a := m + u * (mx - 0.32) + n * 0.03
		var e := m + u * (mx + 0.32) + n * 0.03
		var s_ := m + u * mx + n * 0.03
		_dreieck("zier_glas", Vector3(a.x, y1, a.y), Vector3(e.x, y1, e.y), Vector3(s_.x, y1 + 0.6, s_.y), Vector3(n.x, 0, n.y))
	# Mittelpfosten, Rahmen, Sohlbank und Bogenfeld
	_klotz("hell", m, u, n, -0.16, 0.16, -0.02, 0.08, y0, y1 + 0.3)
	_klotz("hell", m, u, n, -0.98, -0.8, -0.02, 0.1, y0, y1 + 0.2)
	_klotz("hell", m, u, n, 0.8, 0.98, -0.02, 0.1, y0, y1 + 0.2)
	_klotz("hell", m, u, n, -1.05, 1.05, -0.02, 0.16, y0 - 0.22, y0, true)
	_klotz("hell", m, u, n, -0.98, 0.98, -0.02, 0.12, y1 + 0.75, y1 + 0.95, true)


## Fenster in einer Wand, u entlang der Wand, n nach außen. Glas mit Bleiverglasung in Rauten, tiefes Gewände aus
## Quadern (wirkt wie eine Laibung in der Mauer), steinernes Fensterkreuz, Sohlbank mit Wasserschräge und Konsolen,
## Sturz mit Verdachung und Endsteinen, dazu aufgeklappte Bretterläden mit Eisenbändern. "hoch" (Kirchen):
## Spitzbogen aus gestuften Steinen statt Läden. Zierteile ohne Kollision (Präfix "zier_").
func _fenster(c: Vector2, u: Vector2, n: Vector2, pos: float, abstand: float, seite: float, ym: float, fb: float,
		fh: float, hoch: bool) -> void:
	var nn := n * signf(seite)
	var m := c + u * pos + n * abstand
	var b := fb / 2.0
	var y0 := ym - fh / 2.0
	var y1 := ym + fh / 2.0
	var T := 0.3   # Tiefe des Gewändes
	_klotz("zier_glas", m, u, nn, -b, b, -0.04, 0.01, y0, y1)
	_bleiglas(m, u, nn, -b, b, y0, y1, 0.015, "metall")
	# Gewände: Quader im Wechsel lang und kurz, mit Fugen; innen eine Stufe (Fase)
	var y := y0
	var lang := true
	while y < y1 - 0.05:
		var oben := minf(y + 0.36, y1)
		var w := 0.36 if lang else 0.24
		for s_: float in [-1.0, 1.0]:
			_klotz("zier_hell", m, u, nn, (b + 0.07) if s_ > 0 else -b - w, (b + w) if s_ > 0 else -b - 0.07, -0.02, T,
				y, oben - 0.025)
			_klotz("zier_hell", m, u, nn, b if s_ > 0 else -b - 0.07, (b + 0.07) if s_ > 0 else -b, -0.02, T - 0.1, y, oben)
		y = oben
		lang = not lang
	# Sohlbank mit Wasserschräge (vorstehende Platte), darunter eine Schicht und zwei Konsolen
	_klotz("zier_hell", m, u, nn, -b - 0.32, b + 0.32, -0.02, T + 0.14, y0 - 0.12, y0, true)
	_klotz("zier_hell", m, u, nn, -b - 0.28, b + 0.28, -0.02, T + 0.02, y0 - 0.24, y0 - 0.12, true)
	for s_: float in [-1.0, 1.0]:
		var k0 := s_ * (b + 0.08)
		var k1 := s_ * (b + 0.26)
		_klotz("zier_hell", m, u, nn, minf(k0, k1), maxf(k0, k1), -0.02, T, y0 - 0.42, y0 - 0.24, true)
		_klotz("zier_hell", m, u, nn, minf(k0, k1) + 0.03, maxf(k0, k1) - 0.03, -0.02, T - 0.12, y0 - 0.56, y0 - 0.42, true)
	if hoch:
		# Spitzbogen: Glas als Dreieck, darüber gestufte Bogensteine und ein Schlussstein
		var spitze := b * 1.2
		var g0 := m + u * -b + nn * 0.005
		var g1 := m + u * b + nn * 0.005
		var gs := m + nn * 0.005
		_dreieck("zier_glas", Vector3(g0.x, y1, g0.y), Vector3(g1.x, y1, g1.y), Vector3(gs.x, y1 + spitze, gs.y),
			Vector3(nn.x, 0, nn.y))
		var stufen := 5
		for k in stufen:
			var t0 := float(k) / stufen
			var t1 := float(k + 1) / stufen
			var innen_ := b * (1.0 - t1)
			for s_: float in [-1.0, 1.0]:
				var a0 := s_ * innen_
				var a1 := s_ * (innen_ + 0.3)
				_klotz("zier_hell", m, u, nn, minf(a0, a1), maxf(a0, a1), -0.02, T, y1 + spitze * t0, y1 + spitze * t1 + 0.04)
		_klotz("zier_hell", m, u, nn, -0.18, 0.18, -0.02, T + 0.06, y1 + spitze - 0.05, y1 + spitze + 0.3, true)
		# Mittelpfosten mit kleinem Kapitell
		_klotz("zier_hell", m, u, nn, -0.06, 0.06, -0.02, 0.14, y0, y1)
		_klotz("zier_hell", m, u, nn, -0.1, 0.1, -0.02, 0.18, y1 - 0.12, y1, true)
		# Tropfleiste über dem Bogen
		_klotz("zier_hell", m, u, nn, -b - 0.42, b + 0.42, -0.02, T + 0.12, y1 - 0.1, y1, true)
		return
	# Sturz aus einem Block, darüber die Verdachung mit herabhängenden Endsteinen
	_klotz("zier_hell", m, u, nn, -b - 0.3, b + 0.3, -0.02, T, y1, y1 + 0.32, true)
	_klotz("zier_hell", m, u, nn, -b - 0.44, b + 0.44, -0.02, T + 0.12, y1 + 0.32, y1 + 0.44, true)
	for s_: float in [-1.0, 1.0]:
		var k0 := s_ * (b + 0.3)
		var k1 := s_ * (b + 0.44)
		_klotz("zier_hell", m, u, nn, minf(k0, k1), maxf(k0, k1), -0.02, T + 0.12, y1 + 0.02, y1 + 0.32, true)
	# Fensterkreuz aus Stein (bei breiten Fenstern), sonst nur ein Kämpfer
	if fb >= 0.9:
		_klotz("zier_hell", m, u, nn, -0.06, 0.06, -0.02, 0.12, y0, y1)
	var kh := y0 + fh * 0.64
	_klotz("zier_hell", m, u, nn, -b, b, -0.02, 0.12, kh - 0.06, kh + 0.06, true)
	# Wirbel (Ladenhalter) und aufgeklappte Läden: drei Bretter mit Fugen, zwei Leisten, Strebe, Eisenbänder
	for s_: float in [-1.0, 1.0]:
		var a0 := s_ * (b + 0.4)
		var a1 := s_ * (b + 0.4 + b + 0.05)
		var lo := minf(a0, a1)
		var hi := maxf(a0, a1)
		var brett := (hi - lo) / 3.0
		for k in 3:
			_klotz("zier_holz", m, u, nn, lo + k * brett + 0.008, lo + (k + 1) * brett - 0.008, 0.05, 0.1, y0 + 0.02,
				y1 - 0.02, true)
		for q: float in [0.18, 0.82]:
			var yq := y0 + fh * q
			_klotz("zier_holz", m, u, nn, lo + 0.05, hi - 0.05, 0.1, 0.14, yq - 0.055, yq + 0.055)
			# Langband aus Eisen bis zum Gewände, mit Kloben
			var b0 := s_ * (b + 0.3)
			_klotz("metall", m, u, nn, minf(b0, a1 - s_ * 0.12), maxf(b0, a1 - s_ * 0.12), 0.14, 0.16, yq - 0.025, yq + 0.025)
			_klotz("metall", m, u, nn, minf(b0, b0 + s_ * 0.1), maxf(b0, b0 + s_ * 0.1), T, T + 0.04, yq - 0.04, yq + 0.04)
		_strebe("zier_holz", m, u, nn, Vector2(lo + 0.1, y0 + fh * 0.18), Vector2(hi - 0.1, y0 + fh * 0.82), 0.09, 0.12)
		# Halter am Mauerwerk neben dem Laden
		_klotz("metall", m, u, nn, hi + 0.02 if s_ > 0 else lo - 0.06, hi + 0.06 if s_ > 0 else lo - 0.02, 0.0, 0.12,
			ym - 0.04, ym + 0.04)


## Bleiverglasung in Rauten: dünne flache Bleiruten, auf das Rechteck (u0..u1, y0..y1) zugeschnitten.
func _bleiglas(m: Vector2, u: Vector2, nn: Vector2, u0: float, u1: float, y0: float, y1: float, ab: float, mat: String) -> void:
	var h := y1 - y0
	var d := 0.24
	var N := Vector3(nn.x, 0, nn.y)
	var punkt := func(s_: float, t: float) -> Vector3:
		var q := m + u * s_ + nn * ab
		return Vector3(q.x, y0 + t, q.y)
	var k := u0 - h
	while k < u1 + h:
		# s = t + k und s = -t + k, jeweils zugeschnitten
		for richtung: float in [1.0, -1.0]:
			var ta := maxf(0.0, (u0 - k) * richtung)
			var tb := minf(h, (u1 - k) * richtung)
			if richtung < 0:
				ta = maxf(0.0, (k - u1))
				tb = minf(h, (k - u0))
			if tb - ta < 0.02:
				continue
			var pa: Vector3 = punkt.call(k + richtung * ta, ta)
			var pb: Vector3 = punkt.call(k + richtung * tb, tb)
			var quer := Vector3(u.x, 0, u.y) * 0.009 * -richtung + Vector3.UP * 0.009
			_viereck(mat, pa - quer, pb - quer, pb + quer, pa + quer, N)
		k += d
	# Rahmen aus Blei rundherum
	for t: float in [0.0, h]:
		var pa: Vector3 = punkt.call(u0, t)
		var pb: Vector3 = punkt.call(u1, t)
		_viereck(mat, pa - Vector3.UP * 0.015, pb - Vector3.UP * 0.015, pb + Vector3.UP * 0.015, pa + Vector3.UP * 0.015, N)


## Schräge Leiste in der Wandebene von a nach e (je (u, y)), Breite b, vor der Wand von n0 bis n1.
func _strebe(mat: String, m: Vector2, u: Vector2, nn: Vector2, a: Vector2, e: Vector2, b: float, n1: float) -> void:
	var U := Vector3(u.x, 0, u.y)
	var N := Vector3(nn.x, 0, nn.y)
	var r := (e - a).normalized()
	var q := Vector2(-r.y, r.x) * b / 2.0
	var p := func(v: Vector2, ab: float) -> Vector3:
		var g := m + nn * ab
		return Vector3(g.x, 0, g.y) + U * v.x + Vector3.UP * v.y
	_viereck(mat, p.call(a - q, n1), p.call(e - q, n1), p.call(e + q, n1), p.call(a + q, n1), N)
	for s_: float in [-1.0, 1.0]:
		var aussen := (U * q.x + Vector3.UP * q.y) * s_
		_viereck(mat, p.call(a + q * s_, n1 - 0.04), p.call(e + q * s_, n1 - 0.04), p.call(e + q * s_, n1),
			p.call(a + q * s_, n1), aussen)


func _tuer(c: Vector2, u: Vector2, n: Vector2, pos: float, abstand: float, seite: float, boden: float, tb: float, th: float,
		offen := false) -> void:
	var nn := n * signf(seite)
	var m := c + u * pos + n * abstand
	var b := tb / 2.0
	if offen:
		# Türflügel nach innen aufgeschlagen, an der Laibung
		_klotz("holz", m + u * (b + 0.05), u, nn, -0.06, 0.04, -0.6 - tb * 0.9, -0.6, boden, boden + th - 0.05)
	else:
		_klotz("holz", m, u, nn, -b, b, -0.06, 0.04, boden, boden + th)
		# Eisenbänder auf dem geschlossenen Türblatt
		_klotz("metall", m, u, nn, -b * 0.8, b * 0.8, 0.04, 0.07, boden + th * 0.3, boden + th * 0.3 + 0.08)
		_klotz("metall", m, u, nn, -b * 0.8, b * 0.8, 0.04, 0.07, boden + th * 0.75, boden + th * 0.75 + 0.08)
	_klotz("hell", m, u, nn, -b - 0.3, -b, -0.02, 0.15, boden, boden + th + 0.3)
	_klotz("hell", m, u, nn, b, b + 0.3, -0.02, 0.15, boden, boden + th + 0.3)
	_klotz("hell", m, u, nn, -b - 0.3, b + 0.3, -0.02, 0.18, boden + th, boden + th + 0.45, true)


# ---------- Materialien ----------

static var _materialien := {}

func _material(name_: String) -> Material:
	if _materialien.has(name_):
		return _materialien[name_]
	if name_.begins_with("zier_"):
		_materialien[name_] = _material(name_.trim_prefix("zier_"))   # gleiche Optik, aber ohne Kollision
		return _materialien[name_]
	if name_.ends_with("_uv"):
		var basis: StandardMaterial3D = _material(name_.trim_suffix("_uv")).duplicate()
		basis.uv1_triplanar = false
		basis.uv1_world_triplanar = false
		# Dächer: Ziegel- und Schieferreihen mit echter Tiefe (Parallax, braucht die Tangenten der _uv-Flächen)
		var hk := {"dach": ["schiefer", 2.2], "ziegel": ["dach", 3.0]}
		var basisname := name_.trim_suffix("_uv")
		if hk.has(basisname):
			basis.heightmap_enabled = true
			basis.heightmap_texture = load("res://texturen/%s_hoehe.jpg" % hk[basisname][0])
			basis.heightmap_scale = hk[basisname][1]
			basis.heightmap_deep_parallax = true
			basis.heightmap_min_layers = 6
			basis.heightmap_max_layers = 16
		_materialien[name_] = basis
		return basis
	var m: Material
	if name_ == "glut":
		var g := StandardMaterial3D.new()
		g.albedo_color = Color(1.0, 0.75, 0.4)
		g.emission_enabled = true
		g.emission = Color(1.0, 0.6, 0.25)
		g.emission_energy_multiplier = 2.5
		m = g
	elif name_ == "fensterlicht":
		var f := StandardMaterial3D.new()
		f.albedo_color = Color(0.78, 0.84, 0.9)
		f.emission_enabled = true
		f.emission = Color(0.7, 0.78, 0.88)
		f.emission_energy_multiplier = 0.9
		m = f
	elif name_ == "stroh":
		var h := StandardMaterial3D.new()
		h.albedo_color = Color(0.74, 0.62, 0.32)
		h.roughness = 1.0
		m = h
	elif name_ == "wasser_innen":
		var wi := StandardMaterial3D.new()
		wi.albedo_color = Color(0.12, 0.18, 0.2)
		wi.roughness = 0.05
		wi.metallic = 0.3
		m = wi
	elif name_ == "stoff_leder":
		var le := StandardMaterial3D.new()
		le.albedo_color = Color(0.33, 0.2, 0.11)
		le.roughness = 0.7
		m = le
	elif name_ == "glas":
		var gl := StandardMaterial3D.new()
		gl.albedo_color = Color(0.1, 0.13, 0.13)
		gl.metallic = 0.4
		gl.roughness = 0.1
		gl.metallic_specular = 0.9
		m = gl
	elif name_ == "dunkel":
		var s := StandardMaterial3D.new()
		s.albedo_color = Color(0.03, 0.03, 0.035)
		s.roughness = 1.0
		m = s
	elif name_ == "dach":
		m = load("res://material/dach_schiefer.tres")
	elif name_ == "ziegel":
		m = load("res://material/dach.tres")
	else:
		m = load("res://material/%s.tres" % name_)
	_materialien[name_] = m
	return m
