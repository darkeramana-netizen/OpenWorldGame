@tool
extends Node3D
## Kleinkram, der eine Stadt bewohnt wirken lässt: Marktstände mit Sonnendach und Waren, Fässer, Kisten, Säcke
## und Handkarren. Jede Art wird einmal gebaut und als MultiMesh vielfach gezeichnet; jedes Stück hat eine
## einfache Kollisionsbox. Die Bauskripte (werkzeuge/bau/teil_stadt.py) legen fest, was wo steht.

## Je Stück 5 Werte: Art, x, y (Boden), z, Gier in Grad. Arten: 0 Fass, 1 Kiste, 2 Säcke, 3 Marktstand, 4 Karren,
## 5 Kogge im Hafen (Segel gerefft), 6 Kogge unter vollem Segel, 7 Ruderboot (y ist bei Schiffen die Wasserlinie, der
## Bug zeigt nach lokal -z), 8 Tretradkran (der Ausleger zeigt nach lokal -z), 9 Prahm,
## 10 Ziehbrunnen mit Dach, 11 Holzstapel, 12 Pferdetränke, 13 Waffenständer mit Spießen, 14 Feuerkorb auf einem Pfahl
@export var stuecke := PackedFloat32Array():
	set(w):
		stuecke = w
		if is_inside_tree():
			_baue()

## Ausdehnung der Kollisionsbox je Art (halbe Breite, Höhe, halbe Tiefe)
const KASTEN := [Vector3(0.36, 0.95, 0.36), Vector3(0.38, 0.75, 0.38), Vector3(0.6, 0.6, 0.45), Vector3(1.6, 2.6, 1.1),
	Vector3(0.8, 1.0, 1.5), Vector3(2.6, 3.4, 9.0), Vector3(2.6, 3.4, 9.0), Vector3(0.9, 1.4, 2.6), Vector3(1.6, 9.0, 1.6),
	Vector3(2.1, 2.2, 6.2), Vector3(1.25, 3.4, 1.25), Vector3(1.1, 1.1, 0.7), Vector3(1.2, 0.8, 0.45), Vector3(0.9, 2.3, 0.3),
	Vector3(0.3, 2.3, 0.3)]
## Wasserfahrzeuge: die Kollisionsbox reicht unter die Wasserlinie
const TIEFGANG := {5: 1.6, 6: 1.6, 7: 0.5, 9: 0.8}
## Farben der Markisen
const STOFFE := [Color(0.62, 0.16, 0.12), Color(0.85, 0.78, 0.58), Color(0.2, 0.32, 0.52), Color(0.28, 0.42, 0.22)]

static var _meshes := {}
static var _mats := {}


func _ready() -> void:
	_baue()


func _baue() -> void:
	for k in get_children():
		k.free()
	var je_art := {}
	var i := 0
	while i + 4 < stuecke.size():
		je_art.get_or_add(int(stuecke[i]), []).append(Transform3D(Basis(Vector3.UP, deg_to_rad(stuecke[i + 4])),
			Vector3(stuecke[i + 1], stuecke[i + 2], stuecke[i + 3])))
		i += 5
	var koerper := StaticBody3D.new()
	koerper.name = "Kollision"
	add_child(koerper)
	for art: int in je_art:
		var lagen: Array = je_art[art]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _mesh(art)
		mm.instance_count = lagen.size()
		for k in lagen.size():
			mm.set_instance_transform(k, lagen[k])
			var form := CollisionShape3D.new()
			var box := BoxShape3D.new()
			var e: Vector3 = KASTEN[art]
			box.size = Vector3(e.x * 2.0, e.y, e.z * 2.0)
			form.shape = box
			form.transform = lagen[k] * Transform3D(Basis(), Vector3(0, e.y / 2.0 - TIEFGANG.get(art, 0.0), 0))
			koerper.add_child(form)
		var inst := MultiMeshInstance3D.new()
		inst.name = "Art%d" % art
		inst.multimesh = mm
		inst.visibility_range_end = 220.0
		add_child(inst)


# ---------- Formen ----------

var _f := {}

func _st(mat: String) -> SurfaceTool:
	if not _f.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_smooth_group(-1)   # kantig: sonst glättet generate_normals über die Kanten hinweg
		_f[mat] = st
	return _f[mat]


func _viereck(mat: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, aussen: Vector3) -> void:
	var st := _st(mat)
	var reihe := [a, c, b, a, d, c] if (b - a).cross(c - a).dot(aussen) > 0.0 else [a, b, c, a, c, d]
	for p in reihe:
		st.add_vertex(p)


func _klotz(mat: String, lo: Vector3, hi: Vector3, gedreht := 0.0) -> void:
	var b := Basis(Vector3.UP, gedreht)
	var m := (lo + hi) / 2.0
	var h := (hi - lo) / 2.0
	var p := func(x: float, y: float, z: float) -> Vector3:
		return m + b * Vector3(h.x * x, h.y * y, h.z * z)
	for achse in 3:
		for s: float in [-1.0, 1.0]:
			var q := []
			for k in 4:
				var u := 1.0 if k == 1 or k == 2 else -1.0
				var v := 1.0 if k >= 2 else -1.0
				match achse:
					0: q.append(p.call(s, u, v))
					1: q.append(p.call(u, s, v))
					2: q.append(p.call(u, v, s))
			var n := Vector3.ZERO
			n[achse] = s
			_viereck(mat, q[0], q[1], q[2], q[3], b * n)


## Zylinder (Fass, Rad) entlang y, glatt genug mit flachen Normalen
func _zylinder(mat: String, mitte: Vector3, r_unten: float, r_mitte: float, hoehe: float, teile: int, achse := Basis()) -> void:
	for k in teile:
		var w0 := TAU * k / teile
		var w1 := TAU * (k + 1) / teile
		var ringe := [[0.0, r_unten], [hoehe / 2.0, r_mitte], [hoehe, r_unten]]
		for j in 2:
			var y0: float = ringe[j][0]
			var y1: float = ringe[j + 1][0]
			var a := mitte + achse * Vector3(cos(w0) * ringe[j][1], y0, sin(w0) * ringe[j][1])
			var b := mitte + achse * Vector3(cos(w1) * ringe[j][1], y0, sin(w1) * ringe[j][1])
			var c := mitte + achse * Vector3(cos(w1) * ringe[j + 1][1], y1, sin(w1) * ringe[j + 1][1])
			var d := mitte + achse * Vector3(cos(w0) * ringe[j + 1][1], y1, sin(w0) * ringe[j + 1][1])
			_viereck(mat, a, b, c, d, achse * Vector3(cos((w0 + w1) / 2.0), 0, sin((w0 + w1) / 2.0)))
		for y: float in [0.0, hoehe]:
			var a := mitte + achse * Vector3(cos(w0) * r_unten, y, sin(w0) * r_unten)
			var b := mitte + achse * Vector3(cos(w1) * r_unten, y, sin(w1) * r_unten)
			var m := mitte + achse * Vector3(0, y, 0)
			var st := _st(mat)
			var aussen := achse * (Vector3.UP if y > 0.0 else Vector3.DOWN)
			var reihe := [m, b, a] if (a - m).cross(b - m).dot(aussen) > 0.0 else [m, a, b]
			for p in reihe:
				st.add_vertex(p)


func _mesh(art: int) -> ArrayMesh:
	if _meshes.has(art):
		return _meshes[art]
	_f = {}
	match art:
		0:   # Fass mit zwei Eisenreifen
			_zylinder("holz", Vector3.ZERO, 0.3, 0.36, 0.9, 12)
			for y: float in [0.15, 0.7]:
				_zylinder("metall", Vector3(0, y, 0), 0.345, 0.37, 0.07, 12)
		1:   # Kiste mit Leisten
			_klotz("holz", Vector3(-0.36, 0, -0.36), Vector3(0.36, 0.7, 0.36))
			for s: float in [-1.0, 1.0]:
				_klotz("holz_dunkel", Vector3(-0.38, 0.05, s * 0.38 - 0.03), Vector3(0.38, 0.13, s * 0.38 + 0.03))
				_klotz("holz_dunkel", Vector3(-0.38, 0.57, s * 0.38 - 0.03), Vector3(0.38, 0.65, s * 0.38 + 0.03))
		2:   # drei Säcke
			for k in 3:
				var x := -0.32 + k * 0.32
				_klotz("sack", Vector3(x - 0.2, 0, -0.3), Vector3(x + 0.2, 0.42 + 0.06 * (k % 2), 0.3), 0.2 * (k - 1))
			_klotz("sack", Vector3(-0.18, 0.4, -0.25), Vector3(0.22, 0.75, 0.25), 0.4)
		3:   # Marktstand: Tisch, Pfosten, schräge Markise in zwei Farben, Waren
			_klotz("holz", Vector3(-1.5, 0.8, -0.8), Vector3(1.5, 0.9, 0.8))
			for x: float in [-1.4, 1.4]:
				for z: float in [-0.7, 0.7]:
					_klotz("holz_dunkel", Vector3(x - 0.05, 0, z - 0.05), Vector3(x + 0.05, 0.8, z + 0.05))
				_klotz("holz_dunkel", Vector3(x - 0.06, 0, 0.94), Vector3(x + 0.06, 2.5, 1.06))
				_klotz("holz_dunkel", Vector3(x - 0.06, 0, -1.06), Vector3(x + 0.06, 2.2, -0.94))
			for k in 6:
				var x0 := -1.6 + k * (3.2 / 6.0)
				var x1 := x0 + 3.2 / 6.0
				var mat := "markise_a" if k % 2 == 0 else "markise_b"
				_viereck(mat, Vector3(x0, 2.5, 1.1), Vector3(x1, 2.5, 1.1), Vector3(x1, 2.2, -1.25), Vector3(x0, 2.2, -1.25), Vector3(0, 1, -0.1))
				_viereck(mat, Vector3(x0, 2.5, 1.1), Vector3(x1, 2.5, 1.1), Vector3(x1, 2.2, -1.25), Vector3(x0, 2.2, -1.25), Vector3(0, -1, 0.1))
				_viereck(mat, Vector3(x0, 2.2, -1.25), Vector3(x1, 2.2, -1.25), Vector3(x1, 1.95, -1.27), Vector3(x0, 1.95, -1.27), Vector3(0, 0, -1))
			# Waren: Körbe mit Obst und Gemüse, Tuchballen
			_zylinder("korb", Vector3(-0.9, 0.9, 0.1), 0.25, 0.28, 0.22, 10)
			_klotz("ware_rot", Vector3(-1.1, 1.05, -0.1), Vector3(-0.7, 1.18, 0.3))
			_zylinder("korb", Vector3(-0.2, 0.9, -0.3), 0.25, 0.28, 0.22, 10)
			_klotz("ware_gruen", Vector3(-0.4, 1.05, -0.5), Vector3(0.0, 1.18, -0.1))
			_zylinder("ware_tuch", Vector3(0.6, 0.98, 0.2), 0.12, 0.12, 0.8, 8, Basis(Vector3.FORWARD, PI / 2.0))
			_zylinder("ware_tuch2", Vector3(0.6, 1.2, -0.25), 0.12, 0.12, 0.8, 8, Basis(Vector3.FORWARD, PI / 2.0))
			_klotz("holz", Vector3(0.95, 0.9, -0.5), Vector3(1.4, 1.2, 0.0))
		4:   # Handkarren mit zwei Rädern und Deichsel
			_klotz("holz", Vector3(-0.65, 0.55, -0.9), Vector3(0.65, 0.65, 0.9))
			for s: float in [-1.0, 1.0]:
				_klotz("holz", Vector3(s * 0.65 - 0.04, 0.65, -0.9), Vector3(s * 0.65 + 0.04, 0.95, 0.9))
				_zylinder("holz_dunkel", Vector3(s * 0.75, 0.48, 0.2), 0.48, 0.48, 0.08, 14, Basis(Vector3.FORWARD, PI / 2.0 * s))
				_klotz("holz_dunkel", Vector3(s * 0.45 - 0.04, 0.5, 0.9), Vector3(s * 0.45 + 0.04, 0.58, 2.2))
			_klotz("holz", Vector3(-0.65, 0.65, -0.94), Vector3(0.65, 0.95, -0.86))
			_klotz("sack", Vector3(-0.4, 0.65, -0.5), Vector3(0.3, 1.05, 0.3), 0.3)
		5:
			_kogge(false)
		6:
			_kogge(true)
		7:
			_ruderboot()
		8:
			_tretradkran()
		9:
			_prahm()
		10:  # Ziehbrunnen: Steinkranz, zwei Pfosten, Welle mit Kurbel, Satteldach, Eimer
			_zylinder("stein", Vector3.ZERO, 1.15, 1.15, 0.9, 16)
			_zylinder("wasser", Vector3(0, 0.9, 0), 0.88, 0.88, 0.03, 16)
			for s: float in [-1.0, 1.0]:
				_klotz("holz_dunkel", Vector3(s * 1.0 - 0.08, 0.9, -0.08), Vector3(s * 1.0 + 0.08, 2.6, 0.08))
			_zylinder("holz", Vector3(-1.05, 2.1, 0), 0.08, 0.08, 2.1, 8, Basis(Vector3.FORWARD, PI / 2.0))
			_klotz("holz_dunkel", Vector3(1.05, 1.8, -0.03), Vector3(1.12, 2.15, 0.03))
			for s: float in [-1.0, 1.0]:
				_viereck("dach", Vector3(-1.25, 2.6, s * 0.95), Vector3(1.25, 2.6, s * 0.95), Vector3(1.25, 3.3, 0), Vector3(-1.25, 3.3, 0), Vector3(0, 0.8, s * 0.6))
				_viereck("dach", Vector3(-1.25, 2.6, s * 0.95), Vector3(1.25, 2.6, s * 0.95), Vector3(1.25, 3.3, 0), Vector3(-1.25, 3.3, 0), Vector3(0, -0.8, -s * 0.6))
			_zylinder("holz", Vector3(0.0, 1.3, 0), 0.16, 0.19, 0.3, 10)
		11:  # Holzstapel: drei Lagen Scheite quer, an den Enden Pflöcke
			for lage in 4:
				for k in 5 - lage % 2:
					var z := -0.5 + k * 0.25 + (0.12 if lage % 2 == 1 else 0.0)
					_zylinder("holz", Vector3(-1.0, 0.13 + lage * 0.24, z), 0.12, 0.12, 2.0, 7, Basis(Vector3.FORWARD, PI / 2.0))
			for s: float in [-1.0, 1.0]:
				for z: float in [-0.65, 0.65]:
					_klotz("holz_dunkel", Vector3(s * 1.05 - 0.05, 0, z - 0.05), Vector3(s * 1.05 + 0.05, 1.05, z + 0.05))
		12:  # Pferdetränke: Steintrog mit Wasser
			_klotz("stein", Vector3(-1.2, 0, -0.45), Vector3(1.2, 0.75, -0.33))
			_klotz("stein", Vector3(-1.2, 0, 0.33), Vector3(1.2, 0.75, 0.45))
			_klotz("stein", Vector3(-1.2, 0, -0.33), Vector3(-1.08, 0.75, 0.33))
			_klotz("stein", Vector3(1.08, 0, -0.33), Vector3(1.2, 0.75, 0.33))
			_klotz("stein", Vector3(-1.08, 0, -0.33), Vector3(1.08, 0.2, 0.33))
			_klotz("wasser", Vector3(-1.08, 0.2, -0.33), Vector3(1.08, 0.62, 0.33))
		13:  # Waffenständer: Gestell mit fünf Spießen und zwei Schilden
			for s: float in [-1.0, 1.0]:
				_klotz("holz_dunkel", Vector3(s * 0.85 - 0.05, 0, -0.25), Vector3(s * 0.85 + 0.05, 1.3, 0.25))
			_klotz("holz", Vector3(-0.9, 1.0, -0.05), Vector3(0.9, 1.08, 0.05))
			_klotz("holz", Vector3(-0.9, 0.3, -0.25), Vector3(0.9, 0.38, 0.25))
			for k in 5:
				var x := -0.6 + k * 0.3
				_zylinder("holz_dunkel", Vector3(x, 0.32, -0.12), 0.025, 0.025, 1.9, 6)
				_zylinder("metall", Vector3(x, 2.2, -0.12), 0.0, 0.05, 0.2, 6)
			for s: float in [-1.0, 1.0]:
				_zylinder("wimpel", Vector3(s * 0.45, 0.62, 0.12), 0.32, 0.32, 0.05, 12, Basis(Vector3.RIGHT, PI / 2.0))
		14:  # Feuerkorb auf einem Pfahl, darin Glut
			_klotz("holz_dunkel", Vector3(-0.07, 0, -0.07), Vector3(0.07, 1.9, 0.07))
			_zylinder("metall", Vector3(0, 1.9, 0), 0.18, 0.32, 0.35, 10)
			_zylinder("glut", Vector3(0, 2.05, 0), 0.26, 0.24, 0.24, 10)
	var mesh := ArrayMesh.new()
	for mat: String in _f:
		var st: SurfaceTool = _f[mat]
		st.generate_normals()
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material(mat))
	_meshes[art] = mesh
	return mesh


## Seil oder Stange als dünner Zylinder von a nach b.
func _seil(mat: String, a: Vector3, b: Vector3, r: float) -> void:
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	_zylinder(mat, a, r, r, a.distance_to(b), 5, Basis(x, y, z))


## Rumpf aus Spanten (Querschnitte entlang z), für Kogge und Ruderboot.
func _rumpf(laenge: float, breite: float, stationen: int, tief: float, hoch: float, kastelle: bool) -> void:
	var querschnitt := func(z: float) -> Array:
		var t := absf(z) / (laenge / 2.0)
		var w := breite * sqrt(maxf(1.0 - pow(t, 2.4), 0.0)) + 0.06
		var heck := 0.4 if z > 0.0 and kastelle else 0.0
		var deck := hoch + pow(t, 2.0) * (hoch * 0.5 + heck)
		return [Vector2(-w * 0.98, deck), Vector2(-w, hoch * 0.35), Vector2(-w * 0.85, -tief * 0.4), Vector2(-w * 0.45, -tief * 0.8),
			Vector2(0.0, -tief), Vector2(w * 0.45, -tief * 0.8), Vector2(w * 0.85, -tief * 0.4), Vector2(w, hoch * 0.35), Vector2(w * 0.98, deck)]
	var vorher: Array = []
	var z_vorher := 0.0
	for k in stationen + 1:
		var z := -laenge / 2.0 + laenge * k / stationen
		var q: Array = querschnitt.call(z)
		if k > 0:
			for j in q.size() - 1:
				var a: Vector2 = vorher[j]
				var b: Vector2 = vorher[j + 1]
				var c: Vector2 = q[j + 1]
				var d: Vector2 = q[j]
				var mitte := (a + b + c + d) / 4.0
				var mat := "rumpf_teer" if mitte.y < 0.2 else "holz"
				_viereck(mat, Vector3(a.x, a.y, z_vorher), Vector3(b.x, b.y, z_vorher), Vector3(c.x, c.y, z), Vector3(d.x, d.y, z),
					Vector3(mitte.x, mitte.y + 0.6, 0.0))
				_viereck(mat, Vector3(a.x, a.y, z_vorher), Vector3(b.x, b.y, z_vorher), Vector3(c.x, c.y, z), Vector3(d.x, d.y, z),
					-Vector3(mitte.x, mitte.y + 0.6, 0.0))
			var dv: Vector2 = vorher[0]
			var dq: Vector2 = q[0]
			var yd := minf(dv.y, dq.y) - hoch * 0.32
			_viereck("deck", Vector3(dv.x, yd, z_vorher), Vector3(-dv.x, yd, z_vorher), Vector3(-dq.x, yd, z), Vector3(dq.x, yd, z), Vector3.UP)
		vorher = q
		z_vorher = z


## Ruderboot: kleiner Rumpf, drei Ducht-Bänke, zwei Riemen.
func _ruderboot() -> void:
	_rumpf(5.0, 0.75, 8, 0.45, 0.55, false)
	for z: float in [-1.2, 0.0, 1.2]:
		_klotz("holz", Vector3(-0.68, 0.3, z - 0.12), Vector3(0.68, 0.36, z + 0.12))
	for s: float in [-1.0, 1.0]:
		_seil("holz_dunkel", Vector3(s * 0.3, 0.45, 0.1), Vector3(s * 2.1, -0.05, 0.6), 0.035)


## Prahm: flacher Lastkahn ohne Mast (passt unter das Gewölbe des Untergrundhafens), beladen mit Kisten, Fässern
## und Säcken, dazu ein Staken.
func _prahm() -> void:
	_rumpf(12.0, 2.1, 10, 0.8, 1.0, false)
	_klotz("holz", Vector3(-1.9, 0.55, -5.0), Vector3(1.9, 0.65, 5.0))
	for z: float in [-3.6, -2.4, 2.6]:
		_klotz("holz", Vector3(-0.9, 0.65, z - 0.4), Vector3(-0.1, 1.35, z + 0.4))
		_klotz("holz_dunkel", Vector3(-0.92, 1.1, z - 0.42), Vector3(-0.08, 1.18, z + 0.42))
	_klotz("holz", Vector3(0.2, 1.35, -3.4), Vector3(0.9, 1.95, -2.7))
	for z: float in [-0.6, 0.4, 1.4]:
		_zylinder("holz", Vector3(0.7, 0.65, z), 0.3, 0.36, 0.9, 12)
		_zylinder("metall", Vector3(0.7, 0.8, z), 0.345, 0.37, 0.07, 12)
	for k in 3:
		_klotz("sack", Vector3(-1.2 + k * 0.45, 0.65, 3.9), Vector3(-0.8 + k * 0.45, 1.1, 4.5), 0.2 * (k - 1))
	_seil("holz_dunkel", Vector3(1.6, 0.7, -4.6), Vector3(1.75, 4.2, 4.2), 0.05)


## Tretradkran wie an Hansehäfen: Holzbock, Pfosten mit schrägem Ausleger, großes Laufrad, Seil mit Haken.
func _tretradkran() -> void:
	# Grundkreuz und Streben
	_klotz("holz_dunkel", Vector3(-1.6, 0.0, -0.2), Vector3(1.6, 0.35, 0.2))
	_klotz("holz_dunkel", Vector3(-0.2, 0.0, -1.6), Vector3(0.2, 0.35, 1.6))
	_klotz("holz_dunkel", Vector3(-0.25, 0.0, -0.25), Vector3(0.25, 8.0, 0.25))
	for d: Vector3 in [Vector3(1.5, 0.3, 0), Vector3(-1.5, 0.3, 0), Vector3(0, 0.3, 1.5), Vector3(0, 0.3, -1.5)]:
		_seil("holz_dunkel", d, Vector3(0, 4.0, 0), 0.1)
	# Ausleger nach vorn (lokal -z) mit Strebe
	_seil("holz_dunkel", Vector3(0, 7.6, 0.4), Vector3(0, 8.6, -6.5), 0.16)
	_seil("holz_dunkel", Vector3(0, 5.0, 0), Vector3(0, 8.2, -4.0), 0.1)
	# Laufrad seitlich am Pfosten: zwei Kränze aus Speichen, Lauflatten dazwischen
	var mitte := Vector3(0, 3.0, 1.2)
	for x: float in [-0.9, 0.9]:
		for k in 8:
			var w := TAU * k / 8.0
			_seil("holz", mitte + Vector3(x, 0, 0), mitte + Vector3(x, sin(w) * 2.6, cos(w) * 2.6), 0.06)
		for k in 24:
			var w0 := TAU * k / 24.0
			var w1 := TAU * (k + 1) / 24.0
			_seil("holz", mitte + Vector3(x, sin(w0) * 2.6, cos(w0) * 2.6), mitte + Vector3(x, sin(w1) * 2.6, cos(w1) * 2.6), 0.08)
	for k in 24:
		var w := TAU * (k + 0.5) / 24.0
		_klotz("holz", mitte + Vector3(-0.9, sin(w) * 2.55 - 0.05, cos(w) * 2.55 - 0.15), mitte + Vector3(0.9, sin(w) * 2.55 + 0.05, cos(w) * 2.55 + 0.15))
	_seil("holz_dunkel", mitte + Vector3(-1.1, 0, 0), mitte + Vector3(1.1, 0, 0), 0.12)
	# Seil vom Auslegerende mit Haken und einem Ballen
	_seil("seil", Vector3(0, 8.55, -6.4), Vector3(0, 3.0, -6.4), 0.025)
	_klotz("metall", Vector3(-0.08, 2.75, -6.48), Vector3(0.08, 3.0, -6.32))
	_klotz("sack", Vector3(-0.45, 1.95, -6.85), Vector3(0.45, 2.75, -5.95))


## Kogge: bauchiger Rumpf aus Spanten, Deck, Achter- und Vorderkastell, Mast mit Takelage und Wimpel; im Hafen ist
## das Segel an der Rahe gerefft, unter Segel hängt es voll und vom Wind gebläht.
func _kogge(unter_segel: bool) -> void:
	_rumpf(18.0, 2.7, 14, 1.6, 1.7, true)
	# Achterkastell und Vorderkastell
	_klotz("holz", Vector3(-2.3, 2.3, 4.6), Vector3(2.3, 2.45, 8.2))
	for x: float in [-2.3, 2.2]:
		_klotz("holz", Vector3(x, 2.45, 4.6), Vector3(x + 0.1, 3.4, 8.2))
	_klotz("holz", Vector3(-2.3, 2.45, 4.6), Vector3(2.3, 3.4, 4.7))
	_klotz("holz", Vector3(-1.4, 2.6, -8.6), Vector3(1.4, 2.75, -6.4))
	_klotz("holz", Vector3(-1.4, 2.75, -6.5), Vector3(1.4, 3.4, -6.4))
	# Mast, Rahe (im Hafen mit gerefftem Segel), Bugspriet, Ruder
	_zylinder("holz_dunkel", Vector3(0, 1.0, -0.5), 0.2, 0.22, 16.0, 8)
	# liegend quer zum Schiff: Der Zylinder wächst vom Fuß nach lokal -x, also beginnt er rechts vom Mast
	_zylinder("holz_dunkel", Vector3(5.0, 14.2, -0.5), 0.12, 0.14, 10.0, 6, Basis(Vector3.FORWARD, -PI / 2.0))
	if not unter_segel:
		_zylinder("segel", Vector3(4.6, 13.75, -0.5), 0.32, 0.4, 9.2, 8, Basis(Vector3.FORWARD, -PI / 2.0))
	_zylinder("holz_dunkel", Vector3(0, 2.6, -8.8), 0.1, 0.12, 4.5, 6, Basis(Vector3.RIGHT, -PI / 2.6))
	_klotz("holz_dunkel", Vector3(-0.08, -1.4, 8.9), Vector3(0.08, 2.4, 9.8))
	_zylinder("holz_dunkel", Vector3(0, 15.6, -0.5), 0.55, 0.6, 0.7, 8)   # Mastkorb
	# Takelage: Wanten zu beiden Seiten, Vor- und Achterstag
	var top := Vector3(0, 15.4, -0.5)
	for s: float in [-1.0, 1.0]:
		for dz: float in [-1.2, 0.0, 1.2]:
			_seil("seil", top, Vector3(s * 2.55, 2.2, -0.5 + dz), 0.03)
	_seil("seil", top, Vector3(0, 3.0, -10.6), 0.035)
	_seil("seil", top, Vector3(0, 3.5, 8.6), 0.035)
	# Wimpel am Masttopp (rot, nach achtern wehend)
	_viereck("wimpel", Vector3(0, 17.0, -0.5), Vector3(0, 16.4, -0.5), Vector3(0.0, 16.75, 2.6), Vector3(0.0, 16.75, 2.6), Vector3.RIGHT)
	_viereck("wimpel", Vector3(0, 17.0, -0.5), Vector3(0, 16.4, -0.5), Vector3(0.0, 16.75, 2.6), Vector3(0.0, 16.75, 2.6), Vector3.LEFT)
	if unter_segel:
		# volles Rahsegel unter der Rahe, nach vorn gebläht (in Teilen, damit es sich wölbt)
		var teile := 8
		for i in teile:
			for j in 6:
				var p := func(ii: int, jj: int) -> Vector3:
					var u := float(ii) / teile * 2.0 - 1.0
					var v := float(jj) / 6.0
					var bauch := (1.0 - u * u) * sin(v * PI) * 1.4
					return Vector3(u * 4.5, 14.0 - v * 9.5, -0.9 - bauch)
				_viereck("segel", p.call(i, j), p.call(i + 1, j), p.call(i + 1, j + 1), p.call(i, j + 1), Vector3(0, 0, -1))
				_viereck("segel", p.call(i, j), p.call(i + 1, j), p.call(i + 1, j + 1), p.call(i, j + 1), Vector3(0, 0, 1))


func _material(name_: String) -> Material:
	if _mats.has(name_):
		return _mats[name_]
	var m: Material
	match name_:
		"holz":
			m = load("res://material/holz.tres")
		"metall":
			m = load("res://material/metall.tres")
		_:
			var s := StandardMaterial3D.new()
			s.roughness = 0.9
			if name_ == "stein":
				s.albedo_texture = load("res://texturen/klippe_farbe.jpg")
				s.uv1_triplanar = true
				s.uv1_scale = Vector3(0.5, 0.5, 0.5)
			elif name_ in ["glut", "wasser"]:
				pass
			elif not name_ in ["holz_dunkel", "korb", "rumpf_teer", "deck"]:
				s.albedo_texture = load("res://texturen/stoff_farbe.jpg")
				s.uv1_triplanar = true
				s.uv1_scale = Vector3(3, 3, 3)
			else:
				s.albedo_texture = load("res://texturen/holz_farbe.jpg")
				s.uv1_triplanar = true
				s.uv1_scale = Vector3(0.6, 0.6, 0.6)
			if name_ == "glut":
				s.emission_enabled = true
				s.emission = Color(1.0, 0.55, 0.2)
				s.emission_energy_multiplier = 3.0
			if name_ == "wasser":
				s.roughness = 0.1
				s.metallic = 0.3
			s.albedo_color = {"holz_dunkel": Color(0.45, 0.36, 0.3), "glut": Color(1.0, 0.5, 0.15), "wasser": Color(0.18, 0.28, 0.3),
				"stein": Color(0.62, 0.58, 0.52), "dach": Color(0.45, 0.25, 0.18), "korb": Color(0.85, 0.68, 0.42),
				"rumpf_teer": Color(0.22, 0.17, 0.13), "deck": Color(0.8, 0.68, 0.52), "segel": Color(0.9, 0.85, 0.72),
				"sack": Color(0.85, 0.76, 0.58), "markise_a": STOFFE[0], "markise_b": STOFFE[1],
				"ware_rot": Color(0.75, 0.18, 0.1), "ware_gruen": Color(0.3, 0.5, 0.15),
				"ware_tuch": STOFFE[2], "ware_tuch2": STOFFE[3], "seil": Color(0.5, 0.42, 0.3),
				"wimpel": Color(0.65, 0.08, 0.06)}.get(name_, Color(0.6, 0.6, 0.6))
			if name_.begins_with("markise") or name_ in ["segel", "wimpel"]:
				s.cull_mode = BaseMaterial3D.CULL_DISABLED
			m = s
	_mats[name_] = m
	return m
