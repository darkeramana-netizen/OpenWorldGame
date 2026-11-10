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
## Nur Ziegeldächer (die Hofhäuser der Burgfeste wie im Referenzbild: warm braunrot statt Schiefer)
@export var nur_ziegel := false:
	set(wert):
		nur_ziegel = wert
		if is_inside_tree():
			_baue()
## Fachwerk statt Stein und Putz (Stil 2 wird Fachwerk über Stein, Stil 3 Fachwerk über Putz), wie im Referenzbild
@export var nur_fachwerk := false:
	set(wert):
		nur_fachwerk = wert
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
const VARIANTEN := 3       # Ausstattungen je Hausform
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
	# kleine, schmale Häuser für die dicht bebauten Hinterhöfe
	[4.5, 7.0, 2, 1, true, 1, 0], [5.0, 8.0, 1, 0, true, 0, 0], [5.5, 7.5, 2, 3, false, 2, 0], [4.5, 8.0, 2, 0, true, 2, 0],
	[5.0, 7.0, 3, 1, true, 0, 0], [5.5, 8.5, 1, 3, true, 1, 0], [4.8, 7.5, 2, 2, false, 0, 0], [5.2, 8.0, 2, 1, true, 2, 0],
]
const PUTZFARBEN := [Color(1.0, 0.97, 0.9), Color(0.98, 0.86, 0.66), Color(0.92, 0.8, 0.78)]

static var _mesh_cache := {}
static var _schornsteine := {}   # Form → Oberkante des Schornsteins (lokal), für den Rauch
static var _mat_cache := {}


func _ready() -> void:
	_baue()


func _baue() -> void:
	for k in get_children():
		k.free()
	if haeuser.is_empty():
		return
	# je Hausform drei Ausstattungen (Balkon, Schild, Laterne, Gaube, Schornstein gewürfelt), je Haus eine davon
	var je_form := {}
	for i in haeuser.size():
		var f := formen[i] if i < formen.size() else i % FORMEN.size()
		je_form.get_or_add(f * VARIANTEN + (i * 7 + 3) % VARIANTEN, []).append(i)
	var koerper := StaticBody3D.new()
	koerper.name = "Kollision"
	add_child(koerper)
	for fv: int in je_form:
		var f := fv / VARIANTEN
		var mesh := _form_mesh(f, fv % VARIANTEN)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = je_form[fv].size()
		var form: Array = FORMEN[f]
		var kiste := BoxShape3D.new()
		kiste.size = Vector3(form[0] + 2 * VORKRAGUNG, EG + OG * form[2], form[1] + 2 * VORKRAGUNG)
		for k in je_form[fv].size():
			var h: Vector4 = haeuser[je_form[fv][k]]
			var t := Transform3D(Basis(Vector3.UP, deg_to_rad(h.w)), Vector3(h.x, h.y, h.z))
			mm.set_instance_transform(k, t)
			var form_k := CollisionShape3D.new()
			form_k.shape = kiste
			form_k.transform = t * Transform3D(Basis(), Vector3(0, kiste.size.y / 2.0, 0))
			koerper.add_child(form_k)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Form%d_%d" % [f, fv % VARIANTEN]
		mmi.multimesh = mm
		add_child(mmi)
		# Rauch aus etwa jedem siebten Schornstein
		for k in je_form[fv].size():
			if je_form[fv][k] % 7 != 3:
				continue
			var h: Vector4 = haeuser[je_form[fv][k]]
			var t := Transform3D(Basis(Vector3.UP, deg_to_rad(h.w)), Vector3(h.x, h.y, h.z))
			add_child(_rauch(t * (_schornsteine[_schluessel(f, fv % VARIANTEN)] as Vector3)))


## Dünner, langsam aufsteigender Rauch über einem Schornstein (wenige weiche Teilchen).
static var _rauch_mesh: QuadMesh = null

func _rauch(p: Vector3) -> GPUParticles3D:
	if _rauch_mesh == null:
		_rauch_mesh = QuadMesh.new()
		_rauch_mesh.size = Vector2(1.2, 1.2)
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		var verlauf := Gradient.new()
		verlauf.set_color(0, Color(1, 1, 1, 1))
		verlauf.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = verlauf
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		m.albedo_texture = tex
		_rauch_mesh.material = m
	var t := GPUParticles3D.new()
	t.amount = 14
	t.lifetime = 7.0
	t.preprocess = 7.0
	t.position = p
	t.draw_pass_1 = _rauch_mesh
	t.visibility_range_end = 260.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.2, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.0
	pm.gravity = Vector3(0.12, 0.05, 0.04)
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	var groesse := Curve.new()
	groesse.add_point(Vector2(0, 0.5))
	groesse.add_point(Vector2(1, 2.6))
	var gt := CurveTexture.new()
	gt.curve = groesse
	pm.scale_curve = gt
	var farbe := Gradient.new()
	farbe.set_color(0, Color(0.55, 0.53, 0.5, 0.0))
	farbe.add_point(0.15, Color(0.55, 0.53, 0.5, 0.32))
	farbe.set_color(farbe.get_point_count() - 1, Color(0.7, 0.7, 0.7, 0.0))
	var ft := GradientTexture1D.new()
	ft.gradient = farbe
	pm.color_ramp = ft
	t.process_material = pm
	return t


## Tür eines Hauses (für Wege): Weltpunkt vor der Tür.
static func tuer(h: Vector4, form: int) -> Vector3:
	var tiefe: float = FORMEN[form][1]
	return Vector3(h.x, h.y, h.z) + Basis(Vector3.UP, deg_to_rad(h.w)) * Vector3(0, 0, tiefe / 2.0 + 0.9)


# ---------- Ein Haus bauen ----------

## Schlüssel für die gemeinsamen Modelle: Form, Ausstattung und die Einstellungen dieses Knotens (sonst teilen sich
## Knoten mit verschiedenen Einstellungen dieselben Modelle)
func _schluessel(f: int, variante: int) -> int:
	return (f * VARIANTEN + variante) * 4 + (1 if nur_ziegel else 0) + (2 if nur_fachwerk else 0)


func _form_mesh(f: int, variante := 0) -> ArrayMesh:
	# Die Einstellungen gehören in den Schlüssel, sonst teilen sich Knoten mit verschiedenen Einstellungen die Modelle
	var schluessel := _schluessel(f, variante)
	if _mesh_cache.has(schluessel):
		return _mesh_cache[schluessel]
	var form: Array = FORMEN[f]
	var b: float = form[0]
	var t: float = form[1]
	var og: int = form[2]
	var stil: int = form[3]
	if nur_fachwerk and stil >= 2:
		stil -= 2
	var giebelstaendig: bool = form[4]
	var zufall := RandomNumberGenerator.new()
	zufall.seed = 1750 + f + 977 * variante
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
	# Wandlaterne neben der Tür (bei etwa jedem zweiten Haus), leuchtet warm
	if zufall.randf() < 0.5:
		var lx := 1.05 * (1.0 if zufall.randf() < 0.5 else -1.0)
		_quader(flaechen, "metall", Vector3(lx - 0.03, 2.35, t / 2), Vector3(lx + 0.03, 2.41, t / 2 + 0.32))
		_quader(flaechen, "metall", Vector3(lx - 0.13, 2.28, t / 2 + 0.2), Vector3(lx + 0.13, 2.32, t / 2 + 0.46))
		_quader(flaechen, "glut", Vector3(lx - 0.1, 1.95, t / 2 + 0.23), Vector3(lx + 0.1, 2.28, t / 2 + 0.43))
		_quader(flaechen, "metall", Vector3(lx - 0.12, 1.9, t / 2 + 0.21), Vector3(lx + 0.12, 1.95, t / 2 + 0.45))
	# Ladenschild an einem Ausleger neben der Tür (bei etwa jedem dritten Haus)
	if zufall.randf() < 0.35:
		var sx_ := (b * 0.3) * (1.0 if zufall.randf() < 0.5 else -1.0)
		_quader(flaechen, "balken", Vector3(sx_ - 0.05, 2.75, t / 2), Vector3(sx_ + 0.05, 2.85, t / 2 + 1.0))
		_quader(flaechen, "balken", Vector3(sx_ - 0.04, 2.45, t / 2), Vector3(sx_ + 0.04, 2.8, t / 2 + 0.08))
		_quader(flaechen, "rahmen", Vector3(sx_ - 0.01, 2.68, t / 2 + 0.85), Vector3(sx_ + 0.01, 2.75, t / 2 + 0.87))
		_quader(flaechen, "laden", Vector3(sx_ - 0.03, 2.15, t / 2 + 0.5), Vector3(sx_ + 0.03, 2.68, t / 2 + 0.95))
	# Holzbalkon vor dem ersten Obergeschoss (bei etwa jedem vierten Haus mit Obergeschoss), mit Knaggen und Geländer
	if og >= 1 and zufall.randf() < 0.28:
		var z0 := t / 2 + (VORKRAGUNG if fachwerk else 0.0)
		var bb := minf(b * 0.32, 1.8)
		var by := EG + 0.02
		_quader(flaechen, "balken", Vector3(-bb, by - 0.12, z0), Vector3(bb, by + 0.06, z0 + 0.95))
		for k in 3:
			var kx := -bb + 0.15 + k * (2.0 * bb - 0.3) / 2.0
			_quader(flaechen, "balken", Vector3(kx - 0.07, by - 0.7, z0), Vector3(kx + 0.07, by - 0.12, z0 + 0.2))
			_quader(flaechen, "balken", Vector3(kx - 0.06, by - 0.45, z0 + 0.2), Vector3(kx + 0.06, by - 0.12, z0 + 0.6))
		var px_ := -bb
		while px_ <= bb + 0.01:
			_quader(flaechen, "rahmen", Vector3(px_ - 0.035, by + 0.06, z0 + 0.86), Vector3(px_ + 0.035, by + 0.95, z0 + 0.93))
			px_ += 0.3
		_quader(flaechen, "balken", Vector3(-bb - 0.05, by + 0.92, z0 + 0.83), Vector3(bb + 0.05, by + 1.0, z0 + 0.97))
		for e: float in [-1.0, 1.0]:
			_quader(flaechen, "rahmen", Vector3(e * bb - 0.035, by + 0.06, z0), Vector3(e * bb + 0.035, by + 0.95, z0 + 0.93))
			_quader(flaechen, "balken", Vector3(e * bb - 0.04, by + 0.92, z0), Vector3(e * bb + 0.04, by + 1.0, z0 + 0.93))
	# Vordach über der Tür (bei etwa jedem dritten Haus): Pultdach auf zwei Knaggen
	if zufall.randf() < 0.38:
		var vb := 1.15
		var vy := 2.62
		var vt := 0.95
		_quader(flaechen, "balken", Vector3(-vb, vy - 0.08, t / 2), Vector3(vb, vy + 0.04, t / 2 + 0.12))
		for e: float in [-1.0, 1.0]:
			_quader(flaechen, "balken", Vector3(e * (vb - 0.12) - 0.05, vy - 0.55, t / 2), Vector3(e * (vb - 0.12) + 0.05, vy, t / 2 + 0.12))
			_knagge(flaechen, e * (vb - 0.12), vy - 0.55, vy, t / 2, t / 2 + vt - 0.1)
		var vs := _st(flaechen, "dach0" if nur_ziegel else "dach%d" % form[6])
		var d0 := Vector3(-vb - 0.1, vy + 0.45, t / 2 + 0.02)
		var d1 := Vector3(vb + 0.1, vy + 0.45, t / 2 + 0.02)
		var d2 := Vector3(vb + 0.1, vy + 0.02, t / 2 + vt)
		var d3 := Vector3(-vb - 0.1, vy + 0.02, t / 2 + vt)
		_viereck(vs, d0, d1, d2, d3)
		_viereck(vs, d3, d2, d1, d0)
	# Erker am obersten Geschoss (bei etwa jedem vierten Haus mit mindestens zwei Obergeschossen): Fachwerkkasten an
	# einer Ecke der Vorderseite, auf Knaggen, mit eigenem Pultdach
	if og >= 2 and b >= 6.0 and zufall.randf() < 0.3:
		var ex := (b / 2 - 1.1) * (1.0 if zufall.randf() < 0.5 else -1.0)
		var ez := t / 2 + aus
		var ey0 := EG + OG * (og - 1) + 0.15
		var ey1 := ey0 + OG - 0.35
		var ew := 0.85
		var et := 0.75
		_quader(flaechen, "putz%d" % form[5], Vector3(ex - ew, ey0, ez), Vector3(ex + ew, ey1, ez + et))
		_fachwerk(flaechen, Vector3(ex - ew, ey0, ez), Vector3(ex + ew, ey1, ez + et))
		_fenster(flaechen, Vector3(ex, ey0 + 0.6, ez + et), 1, 1.2, false)
		_quader(flaechen, "balken", Vector3(ex - ew - 0.05, ey0 - 0.18, ez), Vector3(ex + ew + 0.05, ey0, ez + et + 0.05))
		for e: float in [-1.0, 1.0]:
			_knagge(flaechen, ex + e * (ew - 0.15), ey0 - 0.9, ey0 - 0.15, ez, ez + et - 0.1)
		var es := _st(flaechen, "dach0" if nur_ziegel else "dach%d" % form[6])
		var r0 := Vector3(ex - ew - 0.15, ey1 + 0.55, ez)
		var r1 := Vector3(ex + ew + 0.15, ey1 + 0.55, ez)
		var r2 := Vector3(ex + ew + 0.15, ey1 - 0.05, ez + et + 0.2)
		var r3 := Vector3(ex - ew - 0.15, ey1 - 0.05, ez + et + 0.2)
		_viereck(es, r0, r1, r2, r3)
		_viereck(es, r3, r2, r1, r0)
	# Sockelleiste aus Stein
	_quader(flaechen, "quader", Vector3(-b / 2 - 0.08, -0.6, -t / 2 - 0.08), Vector3(b / 2 + 0.08, 0.45, t / 2 + 0.08))

	# Dach: Satteldach mit Überstand; First entlang z (Giebel zur Straße) oder entlang x
	var dach_mat := "dach0" if nur_ziegel else "dach%d" % form[6]
	var halbe := (b / 2.0 if giebelstaendig else front) + 0.45
	var laenge := (front + 0.35) if giebelstaendig else (b / 2.0 + 0.35)
	var firsthoehe := halbe * tan(deg_to_rad(DACHNEIGUNG))
	_dach(flaechen, dach_mat, oben_mat if not fachwerk else "putz%d" % form[5], traufe, halbe, laenge, firsthoehe,
			giebelstaendig, b / 2.0 if giebelstaendig else front, fachwerk)
	# Schornstein
	var sx := zufall.randf_range(-b * 0.25, b * 0.25) if not giebelstaendig else 0.0
	var sz := 0.0 if not giebelstaendig else zufall.randf_range(-t * 0.25, t * 0.25)
	_quader(flaechen, "bruchstein", Vector3(sx - 0.35, traufe + firsthoehe * 0.4, sz - 0.35), Vector3(sx + 0.35, traufe + firsthoehe + 0.9, sz + 0.35))
	_quader(flaechen, "bruchstein", Vector3(sx - 0.42, traufe + firsthoehe + 0.82, sz - 0.42), Vector3(sx + 0.42, traufe + firsthoehe + 0.95, sz + 0.42))
	_schornsteine[schluessel] = Vector3(sx, traufe + firsthoehe + 1.0, sz)
	# Dachgaube auf der vorderen Dachfläche traufständiger Häuser (Breite ab 7 m): Fensterkasten mit eigenem Satteldach
	if not giebelstaendig and b >= 6.8 and zufall.randf() < 0.7:
		var neig := tan(deg_to_rad(DACHNEIGUNG))
		var zf := halbe - 1.4
		var y0 := traufe - 0.35 + (halbe - zf) * neig - 0.1
		var y1 := y0 + 1.5
		var zb := halbe - (y1 + 0.6 - (traufe - 0.35)) / neig
		var gw := 0.85
		_quader(flaechen, oben_mat, Vector3(-gw, y0 - 1.0, zb), Vector3(gw, y1, zf))
		_quader(flaechen, "rahmen", Vector3(-0.5, y0 + 0.3, zf - 0.02), Vector3(0.5, y1 - 0.25, zf + 0.04))
		_quader(flaechen, "glas", Vector3(-0.42, y0 + 0.38, zf + 0.04), Vector3(0.42, y1 - 0.33, zf + 0.06))
		_quader(flaechen, "rahmen", Vector3(-0.04, y0 + 0.38, zf + 0.06), Vector3(0.04, y1 - 0.33, zf + 0.08))
		var gs_ := _st(flaechen, dach_mat)
		var first_ := Vector3(0, y1 + 0.75, 0)
		for e: float in [-1.0, 1.0]:
			var a1 := Vector3(e * (gw + 0.25), y1 - 0.05, zf + 0.25)
			var a2 := Vector3(e * (gw + 0.25), y1 - 0.05, zb)
			var f1 := Vector3(0, first_.y, zf + 0.25)
			var f2 := Vector3(0, first_.y, zb)
			if e > 0:
				_viereck(gs_, a1, a2, f2, f1)
			else:
				_viereck(gs_, a2, a1, f1, f2)
		_dreieck(_st(flaechen, oben_mat), Vector3(-gw, y1, zf), Vector3(gw, y1, zf), Vector3(0, y1 + 0.7, zf))

	var mesh := ArrayMesh.new()
	for mat: String in flaechen:
		var st: SurfaceTool = flaechen[mat]
		st.generate_normals()
		st.generate_tangents()
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material(mat))
	_mesh_cache[schluessel] = mesh
	return mesh


func _st(flaechen: Dictionary, mat: String) -> SurfaceTool:
	if not flaechen.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_smooth_group(-1)   # kantig: sonst glättet generate_normals über die Kanten hinweg
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


## Knagge: schräge Stütze unter einem vorstehenden Bauteil, als Treppe aus vier Klötzen von (x, y0, z0) an der Wand
## bis (x, y1, z1) unter dem Bauteil
func _knagge(flaechen: Dictionary, x: float, y0: float, y1: float, z0: float, z1: float) -> void:
	for k in 4:
		var t0 := float(k) / 4.0
		var t1 := float(k + 1) / 4.0
		_quader(flaechen, "balken", Vector3(x - 0.06, y0 + (y1 - y0) * t0, z0), Vector3(x + 0.06, y0 + (y1 - y0) * t1, z0 + (z1 - z0) * t1))


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
	# Bleiruten in Rauten
	var blei := _st(flaechen, "metall")
	var zb := z + 0.012 * seite
	var d := 0.22
	var k := -w / 2 - hoehe
	while k < w / 2 + hoehe:
		for r: float in [1.0, -1.0]:
			var ta := maxf(0.0, -w / 2 - k) if r > 0 else maxf(0.0, k - w / 2)
			var tb := minf(hoehe, w / 2 - k) if r > 0 else minf(hoehe, k + w / 2)
			if tb - ta < 0.02:
				continue
			var pa := Vector3(mitte.x + k + r * ta, mitte.y + ta, zb)
			var pb := Vector3(mitte.x + k + r * tb, mitte.y + tb, zb)
			var q := Vector3(-0.008, 0.008 * r, 0)
			if seite == 1:
				_viereck(blei, pa - q, pb - q, pb + q, pa + q)
			else:
				_viereck(blei, pa + q, pb + q, pb - q, pa - q)
		k += d
	# Rahmen tief aus der Wand: Pfosten, Riegel, Sprosse, Kämpfer
	var r := 0.09
	var t := 0.16
	var z0 := minf(z - 0.02 * seite, z + t * seite)
	var z1 := maxf(z - 0.02 * seite, z + t * seite)
	_quader(flaechen, "rahmen", Vector3(a.x - r, a.y + hoehe, z0), Vector3(b.x + r, a.y + hoehe + r, z1))
	_quader(flaechen, "rahmen", Vector3(a.x - r, a.y, z0), Vector3(a.x, a.y + hoehe, z1))
	_quader(flaechen, "rahmen", Vector3(b.x, a.y, z0), Vector3(b.x + r, a.y + hoehe, z1))
	var zm0 := minf(z, z + 0.08 * seite)
	var zm1 := maxf(z, z + 0.08 * seite)
	_quader(flaechen, "rahmen", Vector3(mitte.x - 0.03, a.y, zm0), Vector3(mitte.x + 0.03, a.y + hoehe, zm1))
	_quader(flaechen, "rahmen", Vector3(a.x, a.y + hoehe * 0.62, zm0), Vector3(b.x, a.y + hoehe * 0.62 + 0.06, zm1))
	# Sturzbrett mit kleiner Verdachung darüber
	var zv := z + 0.24 * seite
	_quader(flaechen, "rahmen", Vector3(a.x - r - 0.08, a.y + hoehe + r, minf(z, zv)), Vector3(b.x + r + 0.08, a.y + hoehe + r + 0.07, maxf(z, zv)))
	# Fensterbank aus einem Brett auf zwei Knaggen
	var zs := z + 0.28 * seite
	_quader(flaechen, "rahmen", Vector3(a.x - r - 0.06, a.y - 0.07, minf(z, zs)), Vector3(b.x + r + 0.06, a.y, maxf(z, zs)))
	for x_: float in [a.x - 0.02, b.x - 0.06]:
		_quader(flaechen, "rahmen", Vector3(x_, a.y - 0.3, minf(z, z + 0.2 * seite)), Vector3(x_ + 0.08, a.y - 0.07, maxf(z, z + 0.2 * seite)))
		_quader(flaechen, "rahmen", Vector3(x_, a.y - 0.42, minf(z, z + 0.08 * seite)), Vector3(x_ + 0.08, a.y - 0.3, maxf(z, z + 0.08 * seite)))
	if laeden:
		for s_: int in [-1, 1]:
			var x0 := mitte.x + s_ * (w / 2 + r + 0.02)
			var x1 := x0 + s_ * w * 0.5
			var lo := minf(x0, x1)
			var hi := maxf(x0, x1)
			var la := minf(z + 0.04 * seite, z + 0.09 * seite)
			var lb := maxf(z + 0.04 * seite, z + 0.09 * seite)
			var br := (hi - lo) / 3.0
			for n_ in 3:
				_quader(flaechen, "laden", Vector3(lo + n_ * br + 0.006, a.y, la), Vector3(lo + (n_ + 1) * br - 0.006, a.y + hoehe, lb))
			for qy: float in [0.15, 0.85]:
				var yq := a.y + hoehe * qy
				var ea := minf(z + 0.09 * seite, z + 0.12 * seite)
				var eb := maxf(z + 0.09 * seite, z + 0.12 * seite)
				_quader(flaechen, "laden", Vector3(lo + 0.03, yq - 0.05, ea), Vector3(hi - 0.03, yq + 0.05, eb))
				_quader(flaechen, "metall", Vector3(minf(x0 - s_ * 0.1, x1 - s_ * 0.08), yq - 0.02, minf(z + 0.12 * seite, z + 0.135 * seite)),
					Vector3(maxf(x0 - s_ * 0.1, x1 - s_ * 0.08), yq + 0.02, maxf(z + 0.12 * seite, z + 0.135 * seite)))


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
		"quader", "bruchstein":
			m.albedo_color = Color(1.25, 1.18, 1.05)   # heller, warmer Kalkstein wie an den Burgmauern
		"balken", "rahmen":
			m.albedo_color = Color(0.62, 0.5, 0.4)
		"tuer":
			m.albedo_color = Color(0.7, 0.5, 0.35)
		"laden":
			m.albedo_color = Color(0.45, 0.6, 0.5)
		"glut":
			m.albedo_color = Color(1.0, 0.78, 0.45)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.62, 0.28)
			m.emission_energy_multiplier = 2.0
		"metall":
			m.albedo_color = Color(0.12, 0.12, 0.13)
			m.metallic = 0.6
			m.roughness = 0.5
		"glas":
			m.albedo_color = Color(0.08, 0.1, 0.12)
			m.metallic = 0.4
			m.roughness = 0.15
	if name_.begins_with("putz"):
		m.albedo_color = PUTZFARBEN[int(name_.substr(4))]
	_mat_cache[name_] = m
	return m
