@tool
extends Node3D
## Bürgerhäuser einer Stadt: Fachwerk über steinernem Erdgeschoss, vorkragende Obergeschosse, steile
## Satteldächer mit Überstand, Fenster, Türen und Schornsteine. Es gibt 24 Hausformen; jede wird einmal
## gebaut und dann als MultiMesh vielfach gezeichnet (das ist schnell). Jedes Haus hat eine Kollisionsbox.
## Die Bauskripte (werkzeuge/bau/teil_drachenstein.py) legen fest, wo welches Haus steht.
## Ein Haus: Ort (x, y, z) ist die Mitte der Grundfläche auf Höhe des Erdgeschossbodens, die Vorderseite
## mit der Tür zeigt nach lokal +z, zur Straße.

## Je Haus (x, y, z, Gier in Grad)
@export var haeuser: PackedVector4Array = PackedVector4Array():
	set(wert):
		haeuser = wert
		if is_inside_tree():
			_baue()
## Je Haus die Nummer der Form (0 bis 23)
@export var formen: PackedInt32Array = PackedInt32Array():
	set(wert):
		formen = wert
		if is_inside_tree():
			_baue()

const EG := 3.2            # Höhe Erdgeschoss
const OG := 2.8            # Höhe Obergeschoss
const VORKRAGUNG := 0.35   # so weit steht jedes Fachwerkgeschoss vor
const DACHNEIGUNG := 52.0
const SOCKEL_TIEFE := 7.0  # Mauern reichen so weit hinunter (Hanglage)

## Formen: [Breite, Tiefe, Obergeschosse, Stil, Giebel zur Straße, Putzfarbe, Dach]
## Stil 0 Fachwerk über Stein, 1 Fachwerk über Putz, 2 ganz Stein, 3 verputzt mit Fensterläden
## Dach 0 Ziegel, 1 Schiefer
const FORMEN := [
	[6.5, 10.0, 2, 0, true, 0, 0], [7.5, 11.0, 2, 1, true, 1, 0], [9.0, 10.0, 1, 3, false, 2, 0],
	[6.0, 9.0, 3, 0, true, 0, 1], [8.0, 12.0, 2, 2, false, 0, 1], [7.0, 10.0, 3, 1, true, 2, 0],
	[9.5, 11.0, 2, 3, false, 1, 0], [6.5, 12.0, 1, 1, true, 0, 0], [8.5, 10.0, 3, 0, false, 1, 1],
	[7.0, 9.0, 2, 3, true, 0, 0], [10.0, 12.0, 2, 2, false, 2, 1], [6.0, 11.0, 2, 1, true, 1, 0],
	[7.5, 10.0, 1, 0, true, 2, 0], [8.0, 9.0, 2, 1, false, 0, 0], [6.5, 10.0, 3, 3, true, 1, 1],
	[9.0, 12.0, 3, 0, false, 2, 0], [7.0, 11.0, 2, 2, true, 0, 0], [8.5, 11.0, 1, 3, false, 1, 0],
	[6.0, 10.0, 2, 0, true, 1, 0], [7.5, 12.0, 3, 1, false, 0, 1], [9.0, 9.0, 2, 3, true, 2, 0],
	[6.5, 11.0, 2, 2, true, 1, 1], [8.0, 10.0, 3, 1, true, 0, 0], [10.0, 11.0, 2, 0, false, 2, 0],
]
const PUTZFARBEN := [Color(1.0, 0.97, 0.9), Color(0.98, 0.86, 0.66), Color(0.92, 0.8, 0.78)]

static var _mesh_cache := {}
static var _mat_cache := {}


func _ready() -> void:
	_baue()


func _baue() -> void:
	for k in get_children():
		k.free()
	if haeuser.is_empty():
		return
	var je_form := {}
	for i in haeuser.size():
		var f := formen[i] if i < formen.size() else i % FORMEN.size()
		je_form.get_or_add(f, []).append(i)
	var koerper := StaticBody3D.new()
	koerper.name = "Kollision"
	add_child(koerper)
	for f: int in je_form:
		var mesh := _form_mesh(f)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = je_form[f].size()
		var form: Array = FORMEN[f]
		var kiste := BoxShape3D.new()
		kiste.size = Vector3(form[0] + 2 * VORKRAGUNG, EG + OG * form[2], form[1] + 2 * VORKRAGUNG)
		for k in je_form[f].size():
			var h: Vector4 = haeuser[je_form[f][k]]
			var t := Transform3D(Basis(Vector3.UP, deg_to_rad(h.w)), Vector3(h.x, h.y, h.z))
			mm.set_instance_transform(k, t)
			var form_k := CollisionShape3D.new()
			form_k.shape = kiste
			form_k.transform = t * Transform3D(Basis(), Vector3(0, kiste.size.y / 2.0, 0))
			koerper.add_child(form_k)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Form%d" % f
		mmi.multimesh = mm
		add_child(mmi)


## Tür eines Hauses (für Wege): Weltpunkt vor der Tür.
static func tuer(h: Vector4, form: int) -> Vector3:
	var tiefe: float = FORMEN[form][1]
	return Vector3(h.x, h.y, h.z) + Basis(Vector3.UP, deg_to_rad(h.w)) * Vector3(0, 0, tiefe / 2.0 + 0.9)


# ---------- Ein Haus bauen ----------

func _form_mesh(f: int) -> ArrayMesh:
	if _mesh_cache.has(f):
		return _mesh_cache[f]
	var form: Array = FORMEN[f]
	var b: float = form[0]
	var t: float = form[1]
	var og: int = form[2]
	var stil: int = form[3]
	var giebelstaendig: bool = form[4]
	var zufall := RandomNumberGenerator.new()
	zufall.seed = 1750 + f
	var flaechen := {}   # Material → SurfaceTool
	var fachwerk := stil == 0 or stil == 1
	var unten_mat := "quader" if stil in [0, 2] else "putz%d" % form[5]
	var oben_mat := "bruchstein" if stil == 2 else "putz%d" % form[5]

	# Erdgeschoss (reicht in den Hang hinunter)
	_quader(flaechen, unten_mat, Vector3(-b / 2, -SOCKEL_TIEFE, -t / 2), Vector3(b / 2, EG, t / 2))
	# Obergeschosse, im Fachwerk jeweils vorkragend
	var y := EG
	var aus := 0.0
	for g in og:
		if fachwerk:
			aus += VORKRAGUNG
		var lo := Vector3(-b / 2, y, -t / 2 - aus)
		var hi := Vector3(b / 2, y + OG, t / 2 + aus)
		_quader(flaechen, oben_mat, lo, hi)
		if fachwerk:
			_fachwerk(flaechen, lo, hi)
			# Schwelle des vorkragenden Geschosses
			_quader(flaechen, "balken", Vector3(-b / 2 - 0.05, y - 0.22, -t / 2 - aus - 0.05), Vector3(b / 2 + 0.05, y, t / 2 + aus + 0.05))
		y += OG
	var traufe := y
	var front := t / 2 + aus

	# Fenster und Tür
	for seite: int in [1, -1]:
		var z_flaeche := (t / 2) * seite
		var anzahl := maxi(2, int(b / 2.3))
		for g in og + 1:
			var y0 := 0.9 if g == 0 else EG + OG * (g - 1) + 0.75
			var hoehe_f := 1.25 if g == 0 else 1.35
			var z_g := z_flaeche if g == 0 else (t / 2 + (VORKRAGUNG * g if fachwerk else 0.0)) * seite
			for k in anzahl:
				var x := -b / 2 + b * (k + 0.5) / anzahl
				if g == 0 and seite == 1 and absf(x) < b / anzahl * 0.6:
					continue   # dort ist die Tür
				_fenster(flaechen, Vector3(x, y0, z_g), seite, hoehe_f, stil == 3)
	_quader(flaechen, "tuer", Vector3(-0.65, 0.0, t / 2 - 0.05), Vector3(0.65, 2.3, t / 2 + 0.06))
	_quader(flaechen, "balken", Vector3(-0.8, 2.3, t / 2), Vector3(0.8, 2.5, t / 2 + 0.12))
	# Sockelleiste aus Stein
	_quader(flaechen, "quader", Vector3(-b / 2 - 0.08, -0.6, -t / 2 - 0.08), Vector3(b / 2 + 0.08, 0.45, t / 2 + 0.08))

	# Dach: Satteldach mit Überstand; First entlang z (Giebel zur Straße) oder entlang x
	var dach_mat := "dach%d" % form[6]
	var halbe := (b / 2.0 if giebelstaendig else front) + 0.45
	var laenge := (front + 0.35) if giebelstaendig else (b / 2.0 + 0.35)
	var firsthoehe := halbe * tan(deg_to_rad(DACHNEIGUNG))
	_dach(flaechen, dach_mat, oben_mat if not fachwerk else "putz%d" % form[5], traufe, halbe, laenge, firsthoehe,
			giebelstaendig, b / 2.0 if giebelstaendig else front, fachwerk)
	# Schornstein
	var sx := zufall.randf_range(-b * 0.25, b * 0.25) if not giebelstaendig else 0.0
	var sz := 0.0 if not giebelstaendig else zufall.randf_range(-t * 0.25, t * 0.25)
	_quader(flaechen, "bruchstein", Vector3(sx - 0.35, traufe + firsthoehe * 0.4, sz - 0.35), Vector3(sx + 0.35, traufe + firsthoehe + 0.9, sz + 0.35))

	var mesh := ArrayMesh.new()
	for mat: String in flaechen:
		var st: SurfaceTool = flaechen[mat]
		st.generate_normals()
		st.generate_tangents()
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material(mat))
	_mesh_cache[f] = mesh
	return mesh


func _st(flaechen: Dictionary, mat: String) -> SurfaceTool:
	if not flaechen.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		flaechen[mat] = st
	return flaechen[mat]


## Viereck a-b-c-d (gegen den Uhrzeigersinn von außen gesehen), UV in Metern aus der Lage.
## Godot zeichnet Dreiecke im Uhrzeigersinn als Vorderseite, darum werden sie umgekehrt eingetragen.
func _viereck(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	for p in [a, c, b, a, d, c]:
		st.set_uv(_uv(p, n))
		st.add_vertex(p)


func _viereck_uv(st: SurfaceTool, p: Array, uv: Array) -> void:
	for i in [0, 2, 1, 0, 3, 2]:
		st.set_uv(uv[i])
		st.add_vertex(p[i])


func _dreieck(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	for p in [a, c, b]:
		st.set_uv(_uv(p, n))
		st.add_vertex(p)


func _uv(p: Vector3, n: Vector3) -> Vector2:
	var a := n.abs()
	if a.y > a.x and a.y > a.z:
		return Vector2(p.x, p.z)
	if a.x > a.z:
		return Vector2(p.z, -p.y)
	return Vector2(p.x, -p.y)


func _quader(flaechen: Dictionary, mat: String, lo: Vector3, hi: Vector3) -> void:
	var st := _st(flaechen, mat)
	var p := [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z),
		Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]
	_viereck(st, p[4], p[5], p[6], p[7])   # +z
	_viereck(st, p[1], p[0], p[3], p[2])   # -z
	_viereck(st, p[5], p[1], p[2], p[6])   # +x
	_viereck(st, p[0], p[4], p[7], p[3])   # -x
	_viereck(st, p[7], p[6], p[2], p[3])   # oben
	_viereck(st, p[0], p[1], p[5], p[4])   # unten


## Fachwerk auf allen vier Seiten eines Geschosses: Schwelle, Rähm, Ständer, Streben an den Ecken
func _fachwerk(flaechen: Dictionary, lo: Vector3, hi: Vector3) -> void:
	var d := 0.06    # so weit stehen die Balken vor
	var s := 0.11    # Balkenbreite
	for seite: int in [1, -1]:
		var z := hi.z if seite == 1 else lo.z
		var zz := z + d * seite
		var breite := hi.x - lo.x
		# Rähm (oben), Riegel (Mitte)
		_quader(flaechen, "balken", Vector3(lo.x, hi.y - s, minf(z, zz)), Vector3(hi.x, hi.y, maxf(z, zz)))
		_quader(flaechen, "balken", Vector3(lo.x, lo.y + 0.7, minf(z, zz)), Vector3(hi.x, lo.y + 0.7 + s, maxf(z, zz)))
		var felder := maxi(3, int(breite / 1.15))
		for k in felder + 1:
			var x := lo.x + breite * k / felder
			_quader(flaechen, "balken", Vector3(x - s / 2, lo.y, minf(z, zz)), Vector3(x + s / 2, hi.y, maxf(z, zz)))
		# Streben in den äußeren Feldern (Mann-Figur angedeutet)
		for ecke: int in [0, felder - 1]:
			var x0 := lo.x + breite * ecke / felder
			var x1 := lo.x + breite * (ecke + 1) / felder
			_strebe(flaechen, Vector3(x0, lo.y + 0.7, z), Vector3(x1, hi.y - s, z), seite * d)
	for seite: int in [1, -1]:
		var x := hi.x if seite == 1 else lo.x
		var xx := x + d * seite
		_quader(flaechen, "balken", Vector3(minf(x, xx), hi.y - s, lo.z), Vector3(maxf(x, xx), hi.y, hi.z))
		var felder := maxi(3, int((hi.z - lo.z) / 1.2))
		for k in felder + 1:
			var z := lo.z + (hi.z - lo.z) * k / felder
			_quader(flaechen, "balken", Vector3(minf(x, xx), lo.y, z - s / 2), Vector3(maxf(x, xx), hi.y, z + s / 2))


func _strebe(flaechen: Dictionary, a: Vector3, b: Vector3, vor: float) -> void:
	var st := _st(flaechen, "balken")
	var s := 0.06
	var u := Vector3(0, s, 0)
	var z0 := a.z
	var z1 := a.z + vor
	var p := [Vector3(a.x, a.y, z1) - u, Vector3(b.x, b.y, z1) - u, Vector3(b.x, b.y, z1) + u, Vector3(a.x, a.y, z1) + u]
	if vor > 0:
		_viereck(st, p[0], p[1], p[2], p[3])
	else:
		_viereck(st, p[1], p[0], p[3], p[2])


func _fenster(flaechen: Dictionary, mitte: Vector3, seite: int, hoehe: float, laeden: bool) -> void:
	var w := 0.85
	var z := mitte.z + 0.02 * seite
	var a := Vector3(mitte.x - w / 2, mitte.y, z)
	var b := Vector3(mitte.x + w / 2, mitte.y, z)
	var st := _st(flaechen, "glas")
	if seite == 1:
		_viereck(st, a, b, b + Vector3(0, hoehe, 0), a + Vector3(0, hoehe, 0))
	else:
		_viereck(st, b, a, a + Vector3(0, hoehe, 0), b + Vector3(0, hoehe, 0))
	# Rahmen, Sprosse, Fensterbank
	var r := 0.07
	var z0 := minf(z, z + 0.08 * seite)
	var z1 := maxf(z, z + 0.08 * seite)
	_quader(flaechen, "rahmen", Vector3(a.x - r, a.y - r, z0), Vector3(b.x + r, a.y, z1 + 0.06))
	_quader(flaechen, "rahmen", Vector3(a.x - r, a.y + hoehe, z0), Vector3(b.x + r, a.y + hoehe + r, z1))
	_quader(flaechen, "rahmen", Vector3(a.x - r, a.y, z0), Vector3(a.x, a.y + hoehe, z1))
	_quader(flaechen, "rahmen", Vector3(b.x, a.y, z0), Vector3(b.x + r, a.y + hoehe, z1))
	_quader(flaechen, "rahmen", Vector3(mitte.x - 0.025, a.y, z0), Vector3(mitte.x + 0.025, a.y + hoehe, z1))
	_quader(flaechen, "rahmen", Vector3(a.x, a.y + hoehe * 0.55, z0), Vector3(b.x, a.y + hoehe * 0.55 + 0.05, z1))
	if laeden:
		for s: int in [-1, 1]:
			var x0 := mitte.x + s * (w / 2 + r)
			var x1 := x0 + s * w * 0.5
			_quader(flaechen, "laden", Vector3(minf(x0, x1), a.y, z0), Vector3(maxf(x0, x1), a.y + hoehe, z0 + 0.04 * seite if seite > 0 else z0 + 0.04))


## Satteldach. Ist der Giebel zur Straße (First entlang z), sind die Dachflächen links und rechts.
func _dach(flaechen: Dictionary, mat: String, giebel_mat: String, traufe: float, halbe: float, laenge: float,
		hoehe: float, giebelstaendig: bool, wand_halbe: float, fachwerk: bool) -> void:
	var st := _st(flaechen, mat)
	var dicke := 0.18
	# Punkte in einem Rahmen, in dem der First entlang "l" liegt und die Dachflächen nach ±"q" fallen.
	var punkt := func(q: float, l: float, y: float) -> Vector3:
		return Vector3(q, y, l) if giebelstaendig else Vector3(l, y, q)
	var unten := traufe - 0.35
	for s: int in [1, -1]:
		var a: Vector3 = punkt.call(s * halbe, -laenge, unten)
		var b: Vector3 = punkt.call(s * halbe, laenge, unten)
		var c: Vector3 = punkt.call(0.0, laenge, traufe + hoehe)
		var d: Vector3 = punkt.call(0.0, -laenge, traufe + hoehe)
		# Oberseite (nach außen) und Unterseite
		var oben := [a + Vector3(0, dicke, 0), b + Vector3(0, dicke, 0), c + Vector3(0, dicke, 0), d + Vector3(0, dicke, 0)]
		var gerade := (s == 1) != giebelstaendig
		# UV entlang des Firsts und die Dachfläche hinab, damit die Ziegelreihen waagrecht liegen
		var schraege := Vector2(halbe, hoehe + 0.35).length()
		var uv_a := Vector2(-laenge, schraege)
		var uv_b := Vector2(laenge, schraege)
		var uv_c := Vector2(laenge, 0.0)
		var uv_d := Vector2(-laenge, 0.0)
		if gerade:
			_viereck_uv(st, [oben[0], oben[1], oben[2], oben[3]], [uv_a, uv_b, uv_c, uv_d])
			_viereck_uv(st, [b, a, d, c], [uv_b, uv_a, uv_d, uv_c])
		else:
			_viereck_uv(st, [oben[1], oben[0], oben[3], oben[2]], [uv_b, uv_a, uv_d, uv_c])
			_viereck_uv(st, [a, b, c, d], [uv_a, uv_b, uv_c, uv_d])
		# Traufkante
		_viereck(_st(flaechen, "balken"), a, b, oben[1], oben[0]) if gerade else _viereck(_st(flaechen, "balken"), b, a, oben[0], oben[1])
	# Giebelwände (Dreiecke) an beiden Enden, etwas hinter der Dachkante
	var gs := _st(flaechen, giebel_mat)
	for e: int in [1, -1]:
		var l := (laenge - 0.35) * e
		var p1: Vector3 = punkt.call(-wand_halbe, l, traufe)
		var p2: Vector3 = punkt.call(wand_halbe, l, traufe)
		var p3: Vector3 = punkt.call(0.0, l, traufe + (hoehe * wand_halbe / halbe))
		var aussen := (e == 1) == giebelstaendig
		if aussen:
			_dreieck(gs, p1, p2, p3)
		else:
			_dreieck(gs, p2, p1, p3)
		if fachwerk:
			# Ständer und Kehlbalken im Giebel
			var n := 4
			for k in range(1, n):
				var q := -wand_halbe + 2 * wand_halbe * k / n
				var hoch := (hoehe * wand_halbe / halbe) * (1.0 - absf(q) / wand_halbe)
				var v := 0.06 * (1 if aussen else -1) * (1 if giebelstaendig else 1)
				var lo: Vector3 = punkt.call(q - 0.055, l, traufe)
				var hi: Vector3 = punkt.call(q + 0.055, l, traufe + hoch)
				var off: Vector3 = punkt.call(0.0, v, 0.0)
				_quader(flaechen, "balken", Vector3(minf(lo.x, hi.x + off.x), lo.y, minf(lo.z, hi.z + off.z)),
						Vector3(maxf(lo.x, hi.x + off.x), hi.y, maxf(lo.z, hi.z + off.z)))


# ---------- Materialien ----------

func _material(name_: String) -> Material:
	if _mat_cache.has(name_):
		return _mat_cache[name_]
	var m := StandardMaterial3D.new()
	# Textur und Meter je Kachel (Fotoscans, echte Größe siehe texturen/groessen.json)
	var tex := {"quader": ["quader", 2.5], "bruchstein": ["bruchstein", 2.0], "dach0": ["dach", 2.0],
		"dach1": ["schiefer", 3.0], "balken": ["holz", 2.0], "tuer": ["holz", 1.5], "laden": ["holz", 1.5],
		"rahmen": ["holz", 2.0]}
	if name_.begins_with("putz"):
		tex[name_] = ["putz", 1.6]
	if tex.has(name_):
		var t: String = tex[name_][0]
		m.albedo_texture = load("res://texturen/%s_farbe.jpg" % t)
		m.normal_enabled = true
		m.normal_texture = load("res://texturen/%s_normal.jpg" % t)
		m.roughness_texture = load("res://texturen/%s_rau.jpg" % t)
		var s := 1.0 / float(tex[name_][1])
		m.uv1_scale = Vector3(s, s, s)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	match name_:
		"balken", "rahmen":
			m.albedo_color = Color(0.62, 0.5, 0.4)
		"tuer":
			m.albedo_color = Color(0.7, 0.5, 0.35)
		"laden":
			m.albedo_color = Color(0.45, 0.6, 0.5)
		"glas":
			m.albedo_color = Color(0.08, 0.1, 0.12)
			m.metallic = 0.4
			m.roughness = 0.15
	if name_.begins_with("putz"):
		m.albedo_color = PUTZFARBEN[int(name_.substr(4))]
	_mat_cache[name_] = m
	return m
