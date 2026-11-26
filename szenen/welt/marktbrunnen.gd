@tool
extends Node3D
## Marktbrunnen (Stockbrunnen, wie in spätmittelalterlichen Städten): zwei achteckige Stufen, ein achteckiges Becken
## aus Werkstein mit vertieften Feldern und profilierter Abdeckplatte, darin Wasser; in der Mitte der Brunnenstock
## (Säule mit Basis, Kapitell und Knauf), aus dem vier eiserne Röhren Wasser in Bögen ins Becken speien; wo die
## Strahlen auftreffen, schäumt es. Der Ursprung liegt auf dem Pflaster in der Mitte. Kollision: Stufen und Becken.
## Geräusch: Plätschern (autoload/klang.gd).

const R_STUFE := [3.75, 3.4]       # Außenradius (Ecke) der beiden Stufen
const H_STUFE := 0.17
const R_BECKEN := 3.05             # Außenradius des Beckens (Ecke)
const WAND := 0.32
const H_BECKEN := 0.8              # Oberkante der Wand über der oberen Stufe
const WASSER := 0.62               # Wasserspiegel über der oberen Stufe
const ROEHRE_Y := 1.75             # Höhe der Röhren über der oberen Stufe
const SAEULE := 0.32               # halbe Breite des Brunnenstocks

var _st := {}


func _ready() -> void:
	_baue()


func _baue() -> void:
	for k in get_children():
		k.free()
	_st = {}
	var y0 := 0.0
	for i in 2:
		_achteck_klotz("stein", R_STUFE[i], y0, y0 + H_STUFE)
		y0 += H_STUFE
	var boden := y0
	# Becken: Wand außen mit vertieften Feldern, innen glatt, oben eine vorstehende Platte mit Fase
	for k in 8:
		var a0 := TAU * (k + 0.5) / 8.0
		var a1 := TAU * (k + 1.5) / 8.0
		_wandfeld(a0, a1, boden)
	_achteck_ring("stein", R_BECKEN + 0.07, R_BECKEN - WAND - 0.04, boden + H_BECKEN, boden + H_BECKEN + 0.12, true)
	_achteck_ring("stein", R_BECKEN + 0.02, R_BECKEN - WAND - 0.02, boden + H_BECKEN - 0.06, boden + H_BECKEN, false)
	# Beckenboden und Wasser
	_achteck_flaeche("stein", R_BECKEN - WAND, boden + 0.08, Vector3.UP)
	_achteck_flaeche("wasser", R_BECKEN - WAND, boden + WASSER, Vector3.UP)
	# Brunnenstock: Sockel, Schaft (achteckig), Kapitell, Knauf
	_achteck_klotz("stein", SAEULE * 1.9, boden + 0.08, boden + WASSER + 0.12)
	_achteck_klotz("stein", SAEULE * 1.45, boden + WASSER + 0.12, boden + WASSER + 0.3)
	_achteck_klotz("stein", SAEULE, boden + WASSER + 0.3, boden + 2.45)
	_achteck_klotz("stein", SAEULE * 1.25, boden + 1.55, boden + 1.95)          # Röhrenstock (Verdickung)
	_achteck_klotz("stein", SAEULE * 1.5, boden + 2.45, boden + 2.62)
	_achteck_klotz("stein", SAEULE * 1.15, boden + 2.62, boden + 2.75)
	_kugel("stein", Vector3(0, boden + 2.98, 0), 0.24, 10)
	_kegel("stein", Vector3(0, boden + 3.18, 0), 0.08, 0.22)
	# Röhren und Wasserstrahlen
	for k in 4:
		var w := TAU * (k + 0.5) / 4.0
		var r := Vector3(cos(w), 0, sin(w))
		var aus := r * (SAEULE * 1.25) + Vector3(0, boden + ROEHRE_Y, 0)
		var spitze := aus + r * 0.42
		_rohr("eisen", aus - r * 0.05, spitze, 0.045)
		_rohr("eisen", spitze, spitze + r * 0.06 + Vector3(0, -0.08, 0), 0.04)
		# Strahl: Wurfparabel bis zum Wasser, aus kurzen Röhrenstücken
		var v0 := 1.6
		var vorher := spitze + r * 0.05 + Vector3(0, -0.1, 0)
		var auftreff := vorher
		for s in range(1, 13):
			var t := s * 0.045
			var q := spitze + r * (0.05 + v0 * t) + Vector3(0, -0.1 - 4.905 * t * t, 0)
			if q.y <= boden + WASSER:
				q.y = boden + WASSER
				_rohr("strahl", vorher, q, 0.028 + 0.004 * s)
				auftreff = q
				break
			_rohr("strahl", vorher, q, 0.028 + 0.004 * s)
			vorher = q
			auftreff = q
		# Schaum, wo der Strahl auftrifft
		_scheibe("schaum", Vector3(auftreff.x, boden + WASSER + 0.004, auftreff.z), 0.32, 12)
		_scheibe("schaum", Vector3(auftreff.x, boden + WASSER + 0.006, auftreff.z), 0.16, 10)
	# Mesh zusammensetzen
	var mesh := ArrayMesh.new()
	for mat: String in _st:
		var st: SurfaceTool = _st[mat]
		st.generate_normals()
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material(mat))
	var mi := MeshInstance3D.new()
	mi.name = "Form"
	mi.mesh = mesh
	add_child(mi)
	# Kollision: Stufen und Becken als Zylinder, der Brunnenstock als Säule
	var koerper := StaticBody3D.new()
	koerper.name = "Kollision"
	add_child(koerper)
	for teil: Array in [[R_STUFE[0] * 0.96, H_STUFE, H_STUFE / 2.0], [R_STUFE[1] * 0.96, H_STUFE * 2.0, H_STUFE],
			[R_BECKEN, H_STUFE * 2.0 + H_BECKEN + 0.12, (H_STUFE * 2.0 + H_BECKEN + 0.12) / 2.0], [SAEULE * 1.6, 3.4, 1.7]]:
		var f := CollisionShape3D.new()
		var z := CylinderShape3D.new()
		z.radius = teil[0]
		z.height = teil[1]
		f.shape = z
		f.position.y = teil[2]
		koerper.add_child(f)
	if not Engine.is_editor_hint():
		var klang := get_node_or_null("/root/Klang")
		if klang != null:
			klang.dauerklang(self, "brunnen", -6.0, 22.0, Vector3(0, boden + WASSER + 0.3, 0))


# ---------- Formen ----------

func _s(mat: String) -> SurfaceTool:
	if not _st.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_smooth_group(0 if mat in ["strahl", "eisen"] else -1)
		_st[mat] = st
	return _st[mat]


func _viereck(mat: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, aussen: Vector3) -> void:
	var st := _s(mat)
	var reihe := [a, c, b, a, d, c] if (c - a).cross(d - b).dot(aussen) > 0.0 else [a, b, c, a, c, d]
	for p: Vector3 in reihe:
		st.add_vertex(p)


func _ecke(r: float, k: float, y: float) -> Vector3:
	var w := TAU * (k + 0.5) / 8.0
	return Vector3(cos(w) * r, y, sin(w) * r)


func _achteck_klotz(mat: String, r: float, y0: float, y1: float) -> void:
	for k in 8:
		var a := _ecke(r, k, y0)
		var b := _ecke(r, k + 1, y0)
		_viereck(mat, a, b, _ecke(r, k + 1, y1), _ecke(r, k, y1), (a + b) * Vector3(1, 0, 1))
	_achteck_flaeche(mat, r, y1, Vector3.UP)


func _achteck_flaeche(mat: String, r: float, y: float, aussen: Vector3) -> void:
	var st := _s(mat)
	for k in 8:
		var a := _ecke(r, k, y)
		var b := _ecke(r, k + 1, y)
		var m := Vector3(0, y, 0)
		var reihe := [m, b, a] if (a - m).cross(b - m).dot(aussen) > 0.0 else [m, a, b]
		for p: Vector3 in reihe:
			st.add_vertex(p)


## Ring zwischen zwei Achtecken (außen r0, innen r1) von y0 bis y1; fase: Oberkante außen abgeschrägt
func _achteck_ring(mat: String, r0: float, r1: float, y0: float, y1: float, fase: bool) -> void:
	for k in 8:
		var aa := _ecke(r0, k, y0)
		var ab := _ecke(r0, k + 1, y0)
		var aussen := (aa + ab) * Vector3(1, 0, 1)
		var r_oben := r0 - (0.05 if fase else 0.0)
		_viereck(mat, aa, ab, _ecke(r0, k + 1, y1 - (0.04 if fase else 0.0)), _ecke(r0, k, y1 - (0.04 if fase else 0.0)), aussen)
		if fase:
			_viereck(mat, _ecke(r0, k, y1 - 0.04), _ecke(r0, k + 1, y1 - 0.04), _ecke(r_oben, k + 1, y1), _ecke(r_oben, k, y1),
				aussen + Vector3.UP * 2.0)
		_viereck(mat, _ecke(r1, k, y0), _ecke(r1, k + 1, y0), _ecke(r1, k + 1, y1), _ecke(r1, k, y1), -aussen)
		_viereck(mat, _ecke(r_oben, k, y1), _ecke(r_oben, k + 1, y1), _ecke(r1, k + 1, y1), _ecke(r1, k, y1), Vector3.UP)
		_viereck(mat, aa, ab, _ecke(r1, k + 1, y0), _ecke(r1, k, y0), Vector3.DOWN)


## Eine Seite des Beckens: außen ein Rahmen und ein 4 cm vertieftes Feld, innen glatt
func _wandfeld(a0: float, a1: float, boden: float) -> void:
	var k0 := a0 / (TAU / 8.0) - 0.5
	var k1 := k0 + 1.0
	var ra := R_BECKEN
	var ri := R_BECKEN - WAND
	var y1 := boden + H_BECKEN - 0.06
	var A := _ecke(ra, k0, boden)
	var B := _ecke(ra, k1, boden)
	var aussen := (A + B) * Vector3(1, 0, 1)
	var nrm := aussen.normalized()
	var p := func(t: float, y: float, tief: float) -> Vector3:
		return A.lerp(B, t) * Vector3(1, 0, 1) + Vector3(0, y, 0) - nrm * tief
	# Rahmen (vier Streifen) und das vertiefte Feld
	var t0 := 0.12
	var t1 := 0.88
	var yu := boden + 0.14
	var yo := y1 - 0.12
	_viereck("stein", p.call(0.0, boden, 0.0), p.call(1.0, boden, 0.0), p.call(1.0, yu, 0.0), p.call(0.0, yu, 0.0), aussen)
	_viereck("stein", p.call(0.0, yo, 0.0), p.call(1.0, yo, 0.0), p.call(1.0, y1, 0.0), p.call(0.0, y1, 0.0), aussen)
	_viereck("stein", p.call(0.0, yu, 0.0), p.call(t0, yu, 0.0), p.call(t0, yo, 0.0), p.call(0.0, yo, 0.0), aussen)
	_viereck("stein", p.call(t1, yu, 0.0), p.call(1.0, yu, 0.0), p.call(1.0, yo, 0.0), p.call(t1, yo, 0.0), aussen)
	_viereck("stein", p.call(t0, yu, 0.04), p.call(t1, yu, 0.04), p.call(t1, yo, 0.04), p.call(t0, yo, 0.04), aussen)
	# Laibungen des Feldes
	_viereck("stein", p.call(t0, yu, 0.0), p.call(t1, yu, 0.0), p.call(t1, yu, 0.04), p.call(t0, yu, 0.04), Vector3.UP)
	_viereck("stein", p.call(t0, yo, 0.0), p.call(t1, yo, 0.0), p.call(t1, yo, 0.04), p.call(t0, yo, 0.04), Vector3.DOWN)
	_viereck("stein", p.call(t0, yu, 0.0), p.call(t0, yo, 0.0), p.call(t0, yo, 0.04), p.call(t0, yu, 0.04), B - A)
	_viereck("stein", p.call(t1, yu, 0.0), p.call(t1, yo, 0.0), p.call(t1, yo, 0.04), p.call(t1, yu, 0.04), A - B)
	# Innenseite
	var C := _ecke(ri, k0, boden)
	var D := _ecke(ri, k1, boden)
	_viereck("stein", C, D, D + Vector3(0, y1 - boden, 0), C + Vector3(0, y1 - boden, 0), -aussen)


func _rohr(mat: String, a: Vector3, b: Vector3, r: float) -> void:
	var achse := (b - a)
	if achse.length() < 0.001:
		return
	var y := achse.normalized()
	var x := y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y)
	const T := 8
	for k in T:
		var w0 := TAU * k / T
		var w1 := TAU * (k + 1) / T
		var o0 := (x * cos(w0) + z * sin(w0)) * r
		var o1 := (x * cos(w1) + z * sin(w1)) * r
		_viereck(mat, a + o0, a + o1, b + o1, b + o0, (o0 + o1))


func _kugel(mat: String, m: Vector3, r: float, teile: int) -> void:
	for i in teile:
		var b0 := PI * i / teile - PI / 2.0
		var b1 := PI * (i + 1) / teile - PI / 2.0
		for k in teile * 2:
			var l0 := TAU * k / (teile * 2)
			var l1 := TAU * (k + 1) / (teile * 2)
			var q := func(b: float, l: float) -> Vector3:
				return m + Vector3(cos(b) * cos(l), sin(b), cos(b) * sin(l)) * r
			var a: Vector3 = q.call(b0, l0)
			_viereck(mat, a, q.call(b0, l1), q.call(b1, l1), q.call(b1, l0), a - m)


func _kegel(mat: String, unten: Vector3, r: float, h: float) -> void:
	var st := _s(mat)
	for k in 8:
		var a := unten + Vector3(cos(TAU * k / 8.0) * r, 0, sin(TAU * k / 8.0) * r)
		var b := unten + Vector3(cos(TAU * (k + 1) / 8.0) * r, 0, sin(TAU * (k + 1) / 8.0) * r)
		var s := unten + Vector3(0, h, 0)
		var reihe := [a, b, s] if (b - a).cross(s - a).dot(a + b - unten * 2.0) < 0.0 else [a, s, b]
		for p: Vector3 in reihe:
			st.add_vertex(p)


func _scheibe(mat: String, m: Vector3, r: float, teile: int) -> void:
	var st := _s(mat)
	for k in teile:
		var a := m + Vector3(cos(TAU * k / teile) * r, 0, sin(TAU * k / teile) * r)
		var b := m + Vector3(cos(TAU * (k + 1) / teile) * r, 0, sin(TAU * (k + 1) / teile) * r)
		for p: Vector3 in [m, b, a]:
			st.add_vertex(p)


func _material(name_: String) -> Material:
	match name_:
		"stein":
			return load("res://material/hell.tres")
		"eisen":
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.22, 0.2, 0.18)
			m.metallic = 0.8
			m.roughness = 0.55
			return m
		"wasser":
			var w := StandardMaterial3D.new()
			w.albedo_color = Color(0.08, 0.12, 0.11, 0.86)
			w.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			w.roughness = 0.03
			w.metallic = 0.3
			w.metallic_specular = 0.8
			return w
		"strahl":
			var s := StandardMaterial3D.new()
			s.albedo_color = Color(0.75, 0.82, 0.85, 0.45)
			s.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			s.roughness = 0.05
			s.metallic_specular = 0.9
			s.rim_enabled = true
			s.rim = 0.6
			return s
		"schaum":
			var f := StandardMaterial3D.new()
			f.albedo_color = Color(0.9, 0.93, 0.94, 0.55)
			f.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			f.roughness = 0.6
			return f
	return StandardMaterial3D.new()
