@tool
extends Node3D
## Kleinkram, der eine Stadt bewohnt wirken lässt: Marktstände mit Sonnendach und Waren, Fässer, Kisten, Säcke
## und Handkarren. Jede Art wird einmal gebaut und als MultiMesh vielfach gezeichnet; jedes Stück hat eine
## einfache Kollisionsbox. Die Bauskripte (werkzeuge/bau/teil_stadt.py) legen fest, was wo steht.

## Je Stück 5 Werte: Art, x, y (Boden), z, Gier in Grad. Arten: 0 Fass, 1 Kiste, 2 Säcke, 3 Marktstand, 4 Karren,
## 5 Kogge (y ist dann die Wasserlinie, der Bug zeigt nach lokal -z)
@export var stuecke := PackedFloat32Array():
	set(w):
		stuecke = w
		if is_inside_tree():
			_baue()

## Ausdehnung der Kollisionsbox je Art (halbe Breite, Höhe, halbe Tiefe)
const KASTEN := [Vector3(0.36, 0.95, 0.36), Vector3(0.38, 0.75, 0.38), Vector3(0.6, 0.6, 0.45), Vector3(1.6, 2.6, 1.1),
	Vector3(0.8, 1.0, 1.5), Vector3(2.6, 3.4, 9.0)]
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
			form.transform = lagen[k] * Transform3D(Basis(), Vector3(0, e.y / 2.0 - (1.6 if art == 5 else 0.0), 0))
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
			_kogge()
	var mesh := ArrayMesh.new()
	for mat: String in _f:
		var st: SurfaceTool = _f[mat]
		st.generate_normals()
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material(mat))
	_meshes[art] = mesh
	return mesh


## Kogge: bauchiger Rumpf aus Spanten, Deck, Achter- und Vorderkastell, Mast mit gerefftem Segel, Ruder.
func _kogge() -> void:
	var laenge := 18.0
	var breite := 2.7
	var stationen := 14
	var querschnitt := func(z: float) -> Array:
		var t := absf(z) / (laenge / 2.0)
		var w := breite * sqrt(maxf(1.0 - pow(t, 2.4), 0.0)) + 0.12
		var heck := 0.4 if z > 0.0 else 0.0     # das Heck ist voller und höher
		var deck := 1.7 + pow(t, 2.0) * (0.9 + heck)
		return [Vector2(-w * 0.98, deck), Vector2(-w, 0.6), Vector2(-w * 0.85, -0.6), Vector2(-w * 0.45, -1.3),
			Vector2(0.0, -1.6), Vector2(w * 0.45, -1.3), Vector2(w * 0.85, -0.6), Vector2(w, 0.6), Vector2(w * 0.98, deck)]
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
				var mat := "rumpf_teer" if mitte.y < 0.3 else "holz"
				_viereck(mat, Vector3(a.x, a.y, z_vorher), Vector3(b.x, b.y, z_vorher), Vector3(c.x, c.y, z), Vector3(d.x, d.y, z),
					Vector3(mitte.x, mitte.y + 0.6, 0.0))
				_viereck(mat, Vector3(a.x, a.y, z_vorher), Vector3(b.x, b.y, z_vorher), Vector3(c.x, c.y, z), Vector3(d.x, d.y, z),
					-Vector3(mitte.x, mitte.y + 0.6, 0.0))
			# Deck etwas unter der Reling
			var dv: Vector2 = vorher[0]
			var dq: Vector2 = q[0]
			var yd := minf(dv.y, dq.y) - 0.55
			_viereck("deck", Vector3(dv.x, yd, z_vorher), Vector3(-dv.x, yd, z_vorher), Vector3(-dq.x, yd, z), Vector3(dq.x, yd, z), Vector3.UP)
		vorher = q
		z_vorher = z
	# Achterkastell und Vorderkastell
	_klotz("holz", Vector3(-2.3, 2.3, 4.6), Vector3(2.3, 2.45, 8.2))
	for x: float in [-2.3, 2.2]:
		_klotz("holz", Vector3(x, 2.45, 4.6), Vector3(x + 0.1, 3.4, 8.2))
	_klotz("holz", Vector3(-2.3, 2.45, 4.6), Vector3(2.3, 3.4, 4.7))
	_klotz("holz", Vector3(-1.4, 2.6, -8.6), Vector3(1.4, 2.75, -6.4))
	_klotz("holz", Vector3(-1.4, 2.75, -6.5), Vector3(1.4, 3.4, -6.4))
	# Mast, Rahe mit gerefftem Segel, Bugspriet, Ruder
	_zylinder("holz_dunkel", Vector3(0, 1.0, -0.5), 0.2, 0.22, 16.0, 8)
	_zylinder("holz_dunkel", Vector3(-5.0, 14.2, -0.5), 0.12, 0.14, 10.0, 6, Basis(Vector3.FORWARD, -PI / 2.0))
	_zylinder("segel", Vector3(-4.6, 13.75, -0.5), 0.32, 0.4, 9.2, 8, Basis(Vector3.FORWARD, -PI / 2.0))
	_zylinder("holz_dunkel", Vector3(0, 2.6, -8.8), 0.1, 0.12, 4.5, 6, Basis(Vector3.RIGHT, -PI / 2.6))
	_klotz("holz_dunkel", Vector3(-0.08, -1.4, 8.9), Vector3(0.08, 2.4, 9.8))
	_zylinder("holz_dunkel", Vector3(0, 15.6, -0.5), 0.55, 0.6, 0.7, 8)   # Mastkorb


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
			if not name_ in ["holz_dunkel", "korb", "rumpf_teer", "deck"]:
				s.albedo_texture = load("res://texturen/stoff_farbe.jpg")
				s.uv1_triplanar = true
				s.uv1_scale = Vector3(3, 3, 3)
			else:
				s.albedo_texture = load("res://texturen/holz_farbe.jpg")
				s.uv1_triplanar = true
				s.uv1_scale = Vector3(0.6, 0.6, 0.6)
			s.albedo_color = {"holz_dunkel": Color(0.45, 0.36, 0.3), "korb": Color(0.85, 0.68, 0.42),
				"rumpf_teer": Color(0.22, 0.17, 0.13), "deck": Color(0.8, 0.68, 0.52), "segel": Color(0.9, 0.85, 0.72),
				"sack": Color(0.85, 0.76, 0.58), "markise_a": STOFFE[0], "markise_b": STOFFE[1],
				"ware_rot": Color(0.75, 0.18, 0.1), "ware_gruen": Color(0.3, 0.5, 0.15),
				"ware_tuch": STOFFE[2], "ware_tuch2": STOFFE[3]}.get(name_, Color(0.6, 0.6, 0.6))
			if name_.begins_with("markise"):
				s.cull_mode = BaseMaterial3D.CULL_DISABLED
			m = s
	_mats[name_] = m
	return m
