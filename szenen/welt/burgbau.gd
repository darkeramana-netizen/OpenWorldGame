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
## Je Rundturm 7 Werte: x, z, unten, oben (Mauerkrone), Radius, Dach (0 Zinnen, 1 Kegeldach), Dachhöhe
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
## Je Treppe 7 Werte: Anfang x, z, y, Ende x, z, y, Breite. Stufen mit Wangen; begehbar ist das Gelände darunter.
@export var treppen := PackedFloat32Array():
	set(w):
		treppen = w
		_neu_bauen()
## Ohne Kollision: nur Optik (z. B. über den alten Hofmauern aus Akt I, deren Körper bleiben)
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
	if _flach.is_empty() and _rund.is_empty():
		return

	var mesh := ArrayMesh.new()
	var fest := ArrayMesh.new()   # nur Stein und Boden: Fallgitter und Schießscharten halten niemanden auf
	for mat: String in _flach:
		var st: SurfaceTool = _flach[mat]
		st.generate_normals()
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material(mat))
		if not mat.begins_with("metall") and mat != "dunkel":
			st.commit(fest)
	for mat: String in _rund:
		var st: SurfaceTool = _rund[mat]
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material(mat))
		if not mat.begins_with("metall") and mat != "dunkel":
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
	var n := (b - a).cross(c - a)
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
		var reihe := [[a, n0], [e, n1], [b, n1], [a, n0], [f, n0], [e, n1]]
		if innen:
			reihe = [[a, n0], [b, n1], [e, n1], [a, n0], [e, n1], [f, n0]]
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
		for v: Array in [[a, n0, Vector2(k * bogen, schraege)], [spitze, nm, Vector2((k + 0.5) * bogen, 0.0)], [b, n1, Vector2((k + 1) * bogen, schraege)]]:
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
	var l := laenge / 2.0 + 0.15      # leicht überlappen, damit keine Fugen klaffen
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
		_mantel(stein, c, r + 0.15, r + 0.15, oben - 0.2, oben + 0.35, teile)
		_ring(stein, c, r, r + 0.15, oben - 0.2, teile, false)
		_ring("dach", c, r - 0.2, r + 0.4, oben + 0.35, teile, false)
		_kegel("dach", c, r + 0.4, oben + 0.35, dachhoehe, teile)
		_kegel("metall", c, 0.25, oben + 0.35 + dachhoehe - 0.3, 1.4, 8)
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
	# Wangen unter dem Kämpfer (falls die Tortürme nicht bis an den Bogen reichen)
	_klotz(stein, c, u, n, w, w + 0.8, -d, d, boden - 0.5, kaempfer)
	_klotz(stein, c, u, n, -w - 0.8, -w, -d, d, boden - 0.5, kaempfer)
	# Bogensteine als Kranz auf beiden Seiten
	for k in teile:
		var wm := PI * (k + 0.5) / teile
		var x := (w + 0.3) * cos(wm)
		var y := kaempfer + (w + 0.3) * sin(wm)
		for seite: float in [-1.0, 1.0]:
			var q := c + u * x + n * (d + 0.04) * seite
			_klotz(stein, q, u, n, -0.32, 0.32, -0.08, 0.08, y - 0.3, y + 0.3)
	# Brustwehr und Zinnen auf dem Bogen
	_klotz(stein, c, u, n, -w - 0.8, w + 0.8, d - BRUSTWEHR_DICKE, d, oben, oben + BRUSTWEHR)
	_zinnen(c, u, n, breite + 1.6, d - BRUSTWEHR_DICKE, d, oben + BRUSTWEHR)
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
	_klotz(stein, c, u, n, -b, b, -t, t, unten, oben)
	# Anlauf rundum
	var vor := clampf(h * 0.08, 0.5, 1.2)
	var hoch := clampf(h * 0.25, 1.5, 5.0)
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
	if dach >= 1.0:
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
	# Wangen: niedrige Mauern zu beiden Seiten, oben schräg mit der Treppe
	for seite: float in [-1.0, 1.0]:
		var teile := maxi(1, int(laenge / 8.0))
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
	var art := int(w[11])
	# Körper und Sockel
	_klotz(wand, c, uz, nx, -L, L, -B, B, unten, traufe)
	_klotz("bruchstein", c, uz, nx, -L - 0.2, L + 0.2, -B - 0.2, B + 0.2, unten, boden + 0.7)
	# Geschosse
	var geschosse := 1 if art == 1 else maxi(1, int(w[7] / 3.6))
	var gh := w[7] / geschosse
	for k in range(1, geschosse):
		var y := boden + k * gh
		_klotz(wand, c, uz, nx, -L - 0.12, L + 0.12, -B - 0.12, B + 0.12, y - 0.15, y + 0.1, true)
	_klotz(wand, c, uz, nx, -L - 0.3, L + 0.3, -B - 0.3, B + 0.3, traufe - 0.4, traufe, true)
	# Fenster auf allen vier Seiten
	for k in geschosse:
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
			# Giebelseiten
			var quer := int((2.0 * B - 1.5) / 3.4)
			for f in quer:
				var pos := -B + 0.75 + (f + 0.5) * (2.0 * B - 1.5) / quer
				if art == 1 and seite > 0 and k == 0 and absf(pos) < 2.0:
					continue
				_fenster(c, nx, -uz, pos, -L * seite, -seite, ym, fb, fh, art == 1)
	# Tür: bei Kirchen in der Giebelseite, sonst mitten in der Längsseite
	if art == 1:
		_tuer(c, nx, uz, 0.0, L, 1.0, boden, 2.4, 4.2)   # Portal in der Giebelseite gegenüber dem Turm
	else:
		_tuer(c, uz, nx, 0.0, B, 1.0, boden, 1.5, 2.5)
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
	if art == 0:
		var sx := L * 0.45
		var sn := B * 0.35
		_klotz("bruchstein", c + uz * sx + nx * sn, uz, nx, -0.4, 0.4, -0.4, 0.4, traufe, first + 1.0)
		_klotz("bruchstein", c + uz * sx + nx * sn, uz, nx, -0.5, 0.5, -0.5, 0.5, first + 0.9, first + 1.15)


## Fenster in einer Wand: Laibung dunkel, Rahmen, Sohlbank und Sturz aus Stein. u entlang der Wand, n nach außen.
func _fenster(c: Vector2, u: Vector2, n: Vector2, pos: float, abstand: float, seite: float, ym: float, fb: float,
		fh: float, hoch: bool) -> void:
	var nn := n * signf(seite)
	var m := c + u * pos + n * abstand
	var b := fb / 2.0
	_klotz("dunkel", m, u, nn, -b, b, -0.05, 0.02, ym - fh / 2.0, ym + fh / 2.0)
	_klotz("hell", m, u, nn, -b - 0.18, b + 0.18, -0.02, 0.14, ym - fh / 2.0 - 0.2, ym - fh / 2.0, true)
	_klotz("hell", m, u, nn, -b - 0.18, b + 0.18, -0.02, 0.1, ym + fh / 2.0, ym + fh / 2.0 + (0.45 if hoch else 0.25), true)
	_klotz("hell", m, u, nn, -b - 0.16, -b, -0.02, 0.08, ym - fh / 2.0, ym + fh / 2.0)
	_klotz("hell", m, u, nn, b, b + 0.16, -0.02, 0.08, ym - fh / 2.0, ym + fh / 2.0)
	if not hoch:
		# Fensterkreuz
		_klotz("holz", m, u, nn, -0.05, 0.05, -0.03, 0.04, ym - fh / 2.0, ym + fh / 2.0)
		_klotz("holz", m, u, nn, -b, b, -0.03, 0.04, ym + fh * 0.1 - 0.05, ym + fh * 0.1 + 0.05)


func _tuer(c: Vector2, u: Vector2, n: Vector2, pos: float, abstand: float, seite: float, boden: float, tb: float, th: float) -> void:
	var nn := n * signf(seite)
	var m := c + u * pos + n * abstand
	var b := tb / 2.0
	_klotz("holz", m, u, nn, -b, b, -0.06, 0.04, boden, boden + th)
	_klotz("hell", m, u, nn, -b - 0.3, -b, -0.02, 0.15, boden, boden + th + 0.3)
	_klotz("hell", m, u, nn, b, b + 0.3, -0.02, 0.15, boden, boden + th + 0.3)
	_klotz("hell", m, u, nn, -b - 0.3, b + 0.3, -0.02, 0.18, boden + th, boden + th + 0.45, true)
	_klotz("metall", m, u, nn, -b * 0.8, b * 0.8, 0.04, 0.07, boden + th * 0.3, boden + th * 0.3 + 0.08)
	_klotz("metall", m, u, nn, -b * 0.8, b * 0.8, 0.04, 0.07, boden + th * 0.75, boden + th * 0.75 + 0.08)


# ---------- Materialien ----------

static var _materialien := {}

func _material(name_: String) -> Material:
	if _materialien.has(name_):
		return _materialien[name_]
	if name_.ends_with("_uv"):
		var basis: StandardMaterial3D = _material(name_.trim_suffix("_uv")).duplicate()
		basis.uv1_triplanar = false
		basis.uv1_world_triplanar = false
		_materialien[name_] = basis
		return basis
	var m: Material
	if name_ == "dunkel":
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
