@tool
extends Node3D
## Kleinkram, der eine Stadt bewohnt wirken lässt: Marktstände mit Sonnendach und Waren, Fässer, Kisten, Säcke
## und Handkarren. Jede Art wird einmal gebaut und als MultiMesh vielfach gezeichnet; jedes Stück hat eine
## einfache Kollisionsbox. Die Bauskripte (werkzeuge/bau/teil_stadt.py) legen fest, was wo steht.

## Je Stück 5 Werte: Art, x, y (Boden), z, Gier in Grad. Arten: 0 Fass, 1 Kiste, 2 Säcke, 3 Marktstand, 4 Karren,
## 5 Kogge im Hafen (Segel gerefft), 6 Kogge unter vollem Segel, 7 Ruderboot (y ist bei Schiffen die Wasserlinie, der
## Bug zeigt nach lokal -z), 8 Tretradkran (der Ausleger zeigt nach lokal -z), 9 Prahm,
## 10 Ziehbrunnen mit Dach, 11 Holzstapel, 12 Pferdetränke, 13 Waffenständer mit Spießen, 14 Feuerkorb auf einem Pfahl,
## 15 Amboss auf dem Klotz, 16 Esse mit Rauchfang, 17 Unterstand (offen nach lokal +z), 18 Heuhaufen, 19 Pferd (Kopf nach
## lokal +z; als lebendes Tier), 20 Wandlaterne (an einer Wand, die lokal bei z = 0 steht; ohne Kollision),
## 22 Hund, 23 Katze, 24 Schwein, 25 Schaf, 26 Kuh (lebende Tiere, tier.gd), 27 Leiter (lehnt nach lokal -z an einer
## Wand), 28 Wäscheleine mit Wäsche, 29 Stroh am Boden, 30 Pfütze, 31 Taube (27 bis 31 ohne Kollision), 32 Zaunfeld
## (3 m), 33 Anbindebalken, 34 Bretterwand eines Schweinekobens (2 m), 35 Gatter (1,5 m, am Pfosten bei x = 0
## angeschlagen), 36 Schlamm, 37 Netzgestell mit Fischernetz (3,2 m), 38 Fischkorb, 21 Schmiede (gemauerte
## Werkstatt mit Pultdach, Rücken an der Hofmauer bei lokal -z, offen nach +z; innen Esse, Amboss, Werkbank)
@export var stuecke := PackedFloat32Array():
	set(w):
		stuecke = w
		if is_inside_tree() and _bereit:
			_baue()
## Beim Start jedes Stück auf die Oberfläche darunter setzen (Gelände, Kai, Hof, Boden eines Baus), damit nichts im
## Boden steckt oder schwebt. Schiffe, Tiere, Wandlaternen, Tauben und die Schmiede behalten ihre Höhe.
@export var auf_boden := true
## > 0: Stücke nach Zellen dieser Größe (Meter, Welt-x/z) trennen, jede Zelle mit eigenen MultiMeshes und eigener
## Kollision. Mit zell_laden_ab > 0 werden die Zellen erst gebaut, wenn der Spieler nah ist (autoload/zellwelt.gd);
## lebende Tiere und große Stücke (FERNSICHT) bleiben immer da. Der Ladeabstand muss über der Sichtweite der Stücke
## (220 m) liegen.
@export var zellgroesse := 0.0
@export var zell_laden_ab := 0.0
const OHNE_BODEN := [5, 6, 7, 9, 19, 20, 21, 22, 23, 24, 25, 26, 31, 39]
const Zellteil := preload("res://szenen/welt/zellteil.gd")
var _bereit := false

## Ausdehnung der Kollisionsbox je Art (halbe Breite, Höhe, halbe Tiefe)
const KASTEN := [Vector3(0.36, 0.95, 0.36), Vector3(0.38, 0.75, 0.38), Vector3(0.6, 0.6, 0.45), Vector3(1.6, 2.6, 1.1),
	Vector3(0.8, 1.0, 1.5), Vector3(2.6, 3.4, 9.0), Vector3(2.6, 3.4, 9.0), Vector3(0.9, 1.4, 2.6), Vector3(1.6, 9.0, 1.6),
	Vector3(2.1, 2.2, 6.2), Vector3(1.25, 3.4, 1.25), Vector3(1.1, 1.1, 0.7), Vector3(1.2, 0.8, 0.45), Vector3(0.9, 2.3, 0.3),
	Vector3(0.3, 2.3, 0.3), Vector3(0.4, 0.95, 0.35), Vector3(0.9, 1.2, 0.7), Vector3(2.2, 2.9, 1.6), Vector3(0.95, 1.1, 0.95),
	Vector3(0.35, 1.7, 1.2), Vector3.ZERO, Vector3.ONE, Vector3.ZERO, Vector3.ZERO, Vector3(0.35, 0.9, 0.7),
	Vector3(0.35, 1.0, 0.65), Vector3(0.45, 1.5, 1.1), Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO,
	Vector3(1.5, 1.15, 0.08), Vector3(1.3, 1.15, 0.08), Vector3(1.0, 0.9, 0.06), Vector3(0.75, 1.15, 0.05), Vector3.ZERO,
	Vector3(1.7, 2.2, 0.12), Vector3(0.3, 0.45, 0.3), Vector3(2.6, 3.4, 9.5)]
## Große Stücke, die das Bild aus der Ferne prägen (Schiffe, Prahme, Kräne): Art → Sichtweite in Metern. Sie bleiben
## immer geladen (nicht in Zellen), sonst fehlte der Hafen in der Gesamtansicht (Mängelliste M10).
const FERNSICHT := {5: 1400.0, 6: 1400.0, 8: 900.0, 9: 900.0, 39: 1400.0}
## Sichtweite aller übrigen Stücke
const SICHTWEITE := 220.0
## Arten, die als lebende Tiere (szenen/figuren/tier.gd) statt als MultiMesh entstehen: Art → Tierart
const TIERE := {19: 0, 22: 4, 23: 5, 24: 3, 25: 2, 26: 1}
## Arten mit mehreren Kollisionskästen (begehbar): je Kasten die Ecken unten und oben (lokal)
const KAESTEN := {21: [
	[Vector3(-3.8, -0.5, -3.5), Vector3(3.8, 4.6, -2.2)],     # Rückwand
	[Vector3(-3.8, -0.5, -2.2), Vector3(-3.3, 4.2, 2.7)],     # Seitenwände
	[Vector3(3.3, -0.5, -2.2), Vector3(3.8, 4.2, 2.7)],
	[Vector3(-3.3, -0.5, 2.2), Vector3(-0.9, 1.0, 2.7)],      # Brüstung links
	[Vector3(-3.3, 2.6, 2.15), Vector3(3.3, 3.4, 2.75)],      # Sturz und Wand darüber
	[Vector3(0.9, -0.5, 2.2), Vector3(3.3, 3.0, 2.7)],        # Wand rechts
	[Vector3(-3.3, -0.5, -2.2), Vector3(-1.2, 0.85, -1.05)],  # Esse
	[Vector3(-1.85, -0.5, -0.35), Vector3(-0.95, 0.9, 0.35)],  # Amboss
	[Vector3(-0.3, -0.5, -2.2), Vector3(0.6, 0.6, -1.55)],    # Löschtrog
	[Vector3(0.9, -0.5, -2.2), Vector3(2.0, 0.6, -1.4)],      # Kohlenkiste
	[Vector3(2.4, -0.5, -1.2), Vector3(3.3, 0.9, 1.4)]]}      # Werkbank
## Wasserfahrzeuge: die Kollisionsbox reicht unter die Wasserlinie
const TIEFGANG := {5: 1.7, 6: 1.7, 7: 0.5, 9: 0.8, 39: 1.7}
## Farben der Markisen
const STOFFE := [Color(0.62, 0.16, 0.12), Color(0.85, 0.78, 0.58), Color(0.2, 0.32, 0.52), Color(0.28, 0.42, 0.22)]

static var _meshes := {}
static var _mats := {}


func _ready() -> void:
	if auf_boden and not Engine.is_editor_hint():
		# erst wenn Gelände und Bauten ihre Kollision haben
		await get_tree().physics_frame
		await get_tree().physics_frame
		_setze_auf_boden()
	_bereit = true
	_baue()


## Höhe jedes Stücks: die Oberfläche unter ihm (Strahl von 1,6 m darüber bis 3 m darunter). Personen, Tiere und
## Fahrzeuge zählen nicht; ohne Treffer bleibt die Höhe.
func _setze_auf_boden() -> void:
	var raum := get_world_3d().direct_space_state
	var neu := stuecke.duplicate()
	var i := 0
	while i + 4 < neu.size():
		if not int(neu[i]) in OHNE_BODEN:
			var p := global_transform * Vector3(neu[i + 1], neu[i + 2], neu[i + 3])
			var y := boden_unter(raum, p, 1.6, 3.0)
			if not is_nan(y):
				neu[i + 2] = (global_transform.affine_inverse() * Vector3(p.x, y, p.z)).y
		i += 5
	stuecke = neu


## Oberfläche unter p (Strahl von oben bis unten), Personen, Tiere und bewegte Körper zählen nicht; NAN ohne Treffer
static func boden_unter(raum: PhysicsDirectSpaceState3D, p: Vector3, oben: float, unten: float,
		ohne: Array[RID] = []) -> float:
	var abfrage := PhysicsRayQueryParameters3D.create(p + Vector3.UP * oben, p + Vector3.DOWN * unten, 1, ohne)
	for versuch in 4:
		var t := raum.intersect_ray(abfrage)
		if t.is_empty():
			return NAN
		var k := t.collider as Node
		if k is CharacterBody3D or k.has_method("unterwegs") or k.has_meta("tier") or (k.get_parent() != null and k.get_parent().has_method("unterwegs")):
			abfrage.exclude = abfrage.exclude + [t.rid]
			continue
		return (t.position as Vector3).y
	return NAN


func _baue() -> void:
	for k in get_children():
		k.free()
	var je_art := {}
	var je_zelle := {}     # Zelle → Art → Lagen (nur mit zellgroesse; Tiere bleiben in je_art)
	var i := 0
	while i + 4 < stuecke.size():
		var art := int(stuecke[i])
		var lage := Transform3D(Basis(Vector3.UP, deg_to_rad(stuecke[i + 4])), Vector3(stuecke[i + 1], stuecke[i + 2], stuecke[i + 3]))
		if zellgroesse > 0.0 and not TIERE.has(art) and not FERNSICHT.has(art):
			var w := global_transform * lage.origin if is_inside_tree() else lage.origin
			var k := Vector2i(floori(w.x / zellgroesse), floori(w.z / zellgroesse))
			(je_zelle.get_or_add(k, {}) as Dictionary).get_or_add(art, []).append(lage)
		else:
			je_art.get_or_add(art, []).append(lage)
		i += 5
	_baue_arten(je_art, self)
	var nachladen := Zellteil.nachladen_an(self)
	# Formen aller Arten jetzt bauen (beim Laden), nicht erst in der ersten Zelle, die eine Art braucht: Das wäre mitten
	# im Spiel ein langes Bild (gemessen 144 ms)
	for k: Vector2i in je_zelle:
		for art: int in je_zelle[k]:
			_mesh(art)
	for k: Vector2i in je_zelle:
		var name_ := "Zelle_%d_%d" % [k.x, k.y]
		if nachladen:
			add_child(Zellteil.mit_bauer(name_, k, zellgroesse, zell_laden_ab, _zellinhalt.bind(je_zelle[k])))
		else:
			var z := _zellinhalt(je_zelle[k])
			z.name = name_
			add_child(z)


## Inhalt einer Zelle: ihre Stücke mit eigener Kollision
func _zellinhalt(je_art: Dictionary) -> Node3D:
	var z := Node3D.new()
	_baue_arten(je_art, z)
	return z


## MultiMeshes, Tiere und Kollision für die Stücke je Art unter ziel
func _baue_arten(je_art: Dictionary, ziel: Node3D) -> void:
	if je_art.is_empty():
		return
	var koerper := StaticBody3D.new()
	koerper.name = "Kollision"
	ziel.add_child(koerper)
	for art: int in je_art:
		var lagen: Array = je_art[art]
		var e_: Vector3 = KASTEN[art]
		if TIERE.has(art):
			# lebende Tiere: Modell mit Animation, Kopf wie bisher nach lokal +z (das Tier blickt nach -z)
			for k in lagen.size():
				var tier: Node3D = load("res://szenen/figuren/tier.gd").new()
				tier.art = TIERE[art]
				tier.transform = lagen[k] * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
				ziel.add_child(tier)
				if e_ != Vector3.ZERO:
					var form_t := CollisionShape3D.new()
					var box_t := BoxShape3D.new()
					box_t.size = Vector3(e_.x * 2.0, e_.y, e_.z * 2.0)
					form_t.shape = box_t
					form_t.transform = lagen[k] * Transform3D(Basis(), Vector3(0, e_.y / 2.0, 0))
					koerper.add_child(form_t)
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _mesh(art)
		mm.instance_count = lagen.size()
		for k in lagen.size():
			mm.set_instance_transform(k, lagen[k])
			if KAESTEN.has(art):
				for ka: Array in KAESTEN[art]:
					var f := CollisionShape3D.new()
					var bx := BoxShape3D.new()
					bx.size = ka[1] - ka[0]
					f.shape = bx
					f.transform = lagen[k] * Transform3D(Basis(), (ka[0] + ka[1]) / 2.0)
					koerper.add_child(f)
				continue
			if e_ == Vector3.ZERO:
				continue          # ohne Kollision (Wandlaterne)
			var form := CollisionShape3D.new()
			var box := BoxShape3D.new()
			var e: Vector3 = KASTEN[art]
			box.size = Vector3(e.x * 2.0, e.y, e.z * 2.0)
			form.shape = box
			form.transform = lagen[k] * Transform3D(Basis(), Vector3(0, e.y / 2.0 - TIEFGANG.get(art, 0.0), 0))
			koerper.add_child(form)
		if art == 21:
			for lage: Transform3D in lagen:
				ziel.add_child(Rauch.erzeuge(lage * Vector3(-2.2, 6.95, -2.85), 1.8))   # die Esse brennt immer
		var inst := MultiMeshInstance3D.new()
		inst.name = "Art%d" % art
		inst.multimesh = mm
		inst.visibility_range_end = FERNSICHT.get(art, SICHTWEITE)
		inst.visibility_range_end_margin = 100.0 if FERNSICHT.has(art) else 25.0
		inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		if art == 30:   # Pfützen liegen flach auf dem Boden: kein Schattenwurf
			inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ziel.add_child(inst)


# ---------- Formen ----------

var _f := {}

func _st(mat: String) -> SurfaceTool:
	if not _f.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		# kantig: sonst glättet generate_normals über die Kanten hinweg; nur die Außenhaut der Rümpfe ist rund
		st.set_smooth_group(0 if mat in ["rumpf", "rumpf_teer"] else -1)
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
			_kogge(0)
		6:
			_kogge(1)
		39:
			_kogge(2)
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
		15:  # Amboss auf einem Holzklotz
			_zylinder("holz_dunkel", Vector3.ZERO, 0.3, 0.33, 0.55, 10)
			_klotz("metall", Vector3(-0.12, 0.55, -0.1), Vector3(0.12, 0.7, 0.1))
			_klotz("metall", Vector3(-0.3, 0.7, -0.14), Vector3(0.22, 0.9, 0.14))
			_zylinder("metall", Vector3(0.22, 0.8, 0), 0.0, 0.1, 0.32, 8, Basis(Vector3.FORWARD, PI / 2.0))
		16:  # Esse: gemauerter Herd mit Glut, darüber ein Rauchfang und der Schlot
			_klotz("stein", Vector3(-0.85, 0, -0.65), Vector3(0.85, 0.85, 0.65))
			_klotz("glut", Vector3(-0.5, 0.85, -0.35), Vector3(0.5, 0.95, 0.35))
			for s: float in [-1.0, 1.0]:
				_klotz("stein", Vector3(s * 0.85 - 0.12, 0.85, -0.65), Vector3(s * 0.85 + 0.12, 1.9, -0.4))
			_viereck("stein", Vector3(-0.95, 1.9, -0.7), Vector3(0.95, 1.9, -0.7), Vector3(0.35, 2.7, -0.4), Vector3(-0.35, 2.7, -0.4), Vector3(0, 0, -1))
			_viereck("stein", Vector3(-0.95, 1.9, 0.6), Vector3(0.95, 1.9, 0.6), Vector3(0.35, 2.7, -0.1), Vector3(-0.35, 2.7, -0.1), Vector3(0, 0.6, 1))
			for s: float in [-1.0, 1.0]:
				_viereck("stein", Vector3(s * 0.95, 1.9, -0.7), Vector3(s * 0.95, 1.9, 0.6), Vector3(s * 0.35, 2.7, -0.1), Vector3(s * 0.35, 2.7, -0.4), Vector3(s, 0.4, 0))
			_klotz("stein", Vector3(-0.35, 2.7, -0.4), Vector3(0.35, 3.8, -0.1))
			_klotz("holz_dunkel", Vector3(0.9, 0.5, -0.3), Vector3(1.5, 0.75, 0.3))      # Blasebalg
		17:  # Unterstand: vier Pfosten, Pultdach nach vorn geneigt, hinten eine Bretterwand
			for x: float in [-2.1, 2.1]:
				for z: float in [-1.5, 1.5]:
					_klotz("holz_dunkel", Vector3(x - 0.1, 0, z - 0.1), Vector3(x + 0.1, 2.8 - (z + 1.5) * 0.2, z + 0.1))
			_viereck("dach", Vector3(-2.4, 2.9, -1.8), Vector3(2.4, 2.9, -1.8), Vector3(2.4, 2.2, 1.8), Vector3(-2.4, 2.2, 1.8), Vector3(0, 1, 0.2))
			_viereck("dach", Vector3(-2.4, 2.9, -1.8), Vector3(2.4, 2.9, -1.8), Vector3(2.4, 2.2, 1.8), Vector3(-2.4, 2.2, 1.8), Vector3(0, -1, -0.2))
			_klotz("holz", Vector3(-2.1, 0.2, -1.6), Vector3(2.1, 2.6, -1.5))
			_klotz("heu", Vector3(-1.9, 0, -1.4), Vector3(-0.4, 0.8, -0.3))
			_klotz("holz", Vector3(0.2, 0, -1.3), Vector3(1.8, 0.3, 0.6))
		18:  # Heuhaufen
			_zylinder("heu", Vector3.ZERO, 0.95, 0.95, 0.45, 12)
			_zylinder("heu", Vector3(0, 0.4, 0), 0.75, 0.8, 0.35, 12)
			_zylinder("heu", Vector3(0, 0.72, 0), 0.4, 0.5, 0.3, 12)
		19:  # Pferd: Rumpf, Hals, Kopf, Beine, Schweif, Mähne
			_klotz("fell", Vector3(-0.32, 0.95, -0.95), Vector3(0.32, 1.55, 0.9))
			_viereck("fell", Vector3(-0.2, 1.3, 0.75), Vector3(0.2, 1.3, 0.75), Vector3(0.18, 2.0, 1.25), Vector3(-0.18, 2.0, 1.25), Vector3(0, -0.6, 1))
			_viereck("fell", Vector3(-0.2, 1.55, 0.6), Vector3(0.2, 1.55, 0.6), Vector3(0.18, 2.15, 1.05), Vector3(-0.18, 2.15, 1.05), Vector3(0, 0.6, -1))
			for s: float in [-1.0, 1.0]:
				_viereck("fell", Vector3(s * 0.2, 1.3, 0.75), Vector3(s * 0.2, 1.55, 0.6), Vector3(s * 0.18, 2.15, 1.05), Vector3(s * 0.18, 2.0, 1.25), Vector3(s, 0, 0))
			_klotz("fell", Vector3(-0.15, 1.75, 1.05), Vector3(0.15, 2.1, 1.65), -0.5)
			_klotz("haar", Vector3(-0.05, 1.6, 0.65), Vector3(0.05, 2.2, 1.1))
			_klotz("haar", Vector3(-0.07, 0.7, -1.1), Vector3(0.07, 1.4, -0.95))
			for x: float in [-0.2, 0.2]:
				for z: float in [-0.75, 0.7]:
					_klotz("fell", Vector3(x - 0.07, 0, z - 0.07), Vector3(x + 0.07, 1.0, z + 0.07))
					_klotz("haar", Vector3(x - 0.08, 0, z - 0.08), Vector3(x + 0.08, 0.12, z + 0.08))
		20:  # Wandlaterne: Ausleger aus der Wand, darunter die Laterne mit Glut
			_klotz("metall", Vector3(-0.03, 2.55, 0.0), Vector3(0.03, 2.6, 0.5))
			_klotz("metall", Vector3(-0.03, 2.2, 0.0), Vector3(0.03, 2.6, 0.05))
			_klotz("metall", Vector3(-0.16, 2.48, 0.32), Vector3(0.16, 2.54, 0.64))
			_klotz("glut", Vector3(-0.11, 2.12, 0.37), Vector3(0.11, 2.48, 0.59))
			_klotz("metall", Vector3(-0.15, 2.07, 0.33), Vector3(0.15, 2.12, 0.63))
		21:
			_schmiede()
		27:  # Leiter: zwei Holme und Sprossen, oben an der Wand
			for x: float in [-0.22, 0.22]:
				_seil("holz_dunkel", Vector3(x, 0, 0), Vector3(x, 4.4, -1.6), 0.035)
			var k := 0.3
			while k < 4.3:
				var z := -1.6 * k / 4.4
				_seil("holz", Vector3(-0.22, k, z), Vector3(0.22, k, z), 0.02)
				k += 0.32
		28:  # Wäscheleine zwischen zwei Pfosten, daran Hemden, Tücher und Laken
			for x: float in [-2.0, 2.0]:
				_klotz("holz_dunkel", Vector3(x - 0.05, 0, -0.05), Vector3(x + 0.05, 1.95, 0.05))
				_klotz("holz_dunkel", Vector3(x - 0.18, 1.85, -0.03), Vector3(x + 0.18, 1.9, 0.03))
			_seil("seil", Vector3(-2.0, 1.88, 0), Vector3(0, 1.78, 0), 0.018)
			_seil("seil", Vector3(0, 1.78, 0), Vector3(2.0, 1.88, 0), 0.018)
			var stuecke := [[-1.5, 0.55, 0.5, "segel"], [-0.8, 0.5, 0.75, "ware_tuch"], [0.0, 0.7, 0.9, "sack"],
				[0.85, 0.45, 0.6, "ware_tuch2"], [1.5, 0.4, 0.45, "markise_b"]]
			for st: Array in stuecke:
				var x: float = st[0]
				var b: float = st[1] / 2.0
				var oben := 1.88 - 0.1 * (1.0 - absf(x) / 2.0)
				_klotz(st[3], Vector3(x - b, oben - st[2], -0.01), Vector3(x + b, oben, 0.01), 0.04 * x)
				_klotz("holz", Vector3(x - b + 0.05, oben - 0.02, -0.02), Vector3(x - b + 0.08, oben + 0.04, 0.02))   # Klammern
				_klotz("holz", Vector3(x + b - 0.08, oben - 0.02, -0.02), Vector3(x + b - 0.05, oben + 0.04, 0.02))
		29:  # verstreutes Stroh: flache, unregelmäßige Büschel
			for i in 9:
				var w := i * 2.39
				var r := 0.15 + (i % 4) * 0.18
				var m := Vector3(cos(w) * r, 0, sin(w) * r)
				_klotz("heu", m + Vector3(-0.28, 0, -0.18), m + Vector3(0.28, 0.04 + (i % 3) * 0.04, 0.18), w)
		30:  # Pfütze: unregelmäßige Wasserflecken mit feuchtem Rand im Pflaster, halb durchsichtig (Mängelliste M16:
			# die harte, fast schwarze Scheibe wirkte wie ein Loch)
			for i in 3:
				var m := Vector3((i - 1) * 0.5, 0.0, (i % 2) * 0.32 - 0.16)
				var r := 0.38 + i * 0.13
				_fleck("pfuetze_rand", m + Vector3(0, 0.008, 0), r * 1.28, i * 1.7)
				_fleck("pfuetze", m + Vector3(0, 0.014 + i * 0.001, 0), r, i * 1.7 + 0.4)
		32:  # Zaunfeld: drei Pfosten, zwei Riegel
			for x: float in [-1.5, 0.0, 1.5]:
				_klotz("holz_dunkel", Vector3(x - 0.06, -0.15, -0.06), Vector3(x + 0.06, 1.18, 0.06), 0.1 * x)
			for y: float in [0.45, 0.95]:
				_klotz("holz", Vector3(-1.55, y, 0.06), Vector3(1.55, y + 0.09, 0.11), 0.0)
		33:  # Anbindebalken: zwei Pfosten, Balken mit Eisenringen und herabhängenden Stricken
			for x: float in [-1.2, 1.2]:
				_klotz("holz_dunkel", Vector3(x - 0.08, -0.15, -0.08), Vector3(x + 0.08, 1.2, 0.08))
			_klotz("holz", Vector3(-1.35, 1.04, -0.07), Vector3(1.35, 1.18, 0.07))
			for x: float in [-0.6, 0.6]:
				_klotz("metall", Vector3(x - 0.05, 0.96, -0.09), Vector3(x + 0.05, 1.04, -0.07))
				_seil("seil", Vector3(x, 0.98, -0.09), Vector3(x + 0.05, 0.62, -0.18), 0.012)
		34:  # Bretterwand eines Kobens: senkrechte Bretter mit Fugen, zwei Querleisten, Pfosten an den Enden
			for k in 8:
				var x := -1.0 + 0.25 * k
				_klotz("holz", Vector3(x + 0.006, 0.0, -0.025), Vector3(x + 0.244, 0.82 + 0.03 * (k % 3), 0.025))
			for y: float in [0.15, 0.62]:
				_klotz("holz_dunkel", Vector3(-1.0, y, 0.025), Vector3(1.0, y + 0.09, 0.06))
			for x: float in [-1.0, 1.0]:
				_klotz("holz_dunkel", Vector3(x - 0.06, -0.15, -0.06), Vector3(x + 0.06, 1.0, 0.06))
		35:  # Gatter: Rahmen mit Strebe, am Pfosten bei x = 0 angeschlagen
			_klotz("holz_dunkel", Vector3(-0.08, -0.15, -0.08), Vector3(0.08, 1.25, 0.08))
			for y: float in [0.2, 1.0]:
				_klotz("holz", Vector3(0.05, y, -0.03), Vector3(1.45, y + 0.09, 0.03))
			for x: float in [0.1, 1.4]:
				_klotz("holz", Vector3(x - 0.04, 0.15, -0.03), Vector3(x + 0.04, 1.1, 0.03))
			_seil("holz", Vector3(0.12, 0.25, 0.0), Vector3(1.38, 1.02, 0.0), 0.03)
			_klotz("metall", Vector3(0.04, 0.95, -0.04), Vector3(0.2, 1.0, 0.04))
			_klotz("metall", Vector3(0.04, 0.25, -0.04), Vector3(0.2, 0.3, 0.04))
		36:  # Schlamm im Koben: dunkle, feuchte Flecken
			for i in 4:
				var m := Vector3((i % 2 - 0.5) * 1.4, 0.01 + i * 0.002, (int(i / 2.0) - 0.5) * 1.2)
				_zylinder("schlamm", m, 0.7 + 0.15 * i, 0.7 + 0.15 * i, 0.006, 12)
			_zylinder("wasser", Vector3(0.3, 0.022, -0.2), 0.35, 0.35, 0.004, 10)
		31:  # Taube: Rumpf, Brust, Kopf mit Schnabel, Schwanz
			_klotz("taube", Vector3(-0.055, 0.05, -0.1), Vector3(0.055, 0.15, 0.1))
			_klotz("taube_hals", Vector3(-0.045, 0.1, -0.13), Vector3(0.045, 0.19, -0.07))
			_klotz("taube", Vector3(-0.035, 0.18, -0.15), Vector3(0.035, 0.24, -0.08))
			_klotz("ware_rot", Vector3(-0.01, 0.2, -0.18), Vector3(0.01, 0.215, -0.15))
			_klotz("taube_dunkel", Vector3(-0.05, 0.07, 0.08), Vector3(0.05, 0.1, 0.2), 0.0)
			_klotz("taube_dunkel", Vector3(-0.06, 0.08, -0.06), Vector3(0.06, 0.14, 0.12))
			for x: float in [-0.02, 0.02]:
				_klotz("ware_rot", Vector3(x - 0.006, 0, -0.02), Vector3(x + 0.006, 0.05, -0.01))
		37:  # Netzgestell: zwei Pfosten, Querstange, darüber ein Fischernetz zum Trocknen (Maschen aus dünnen Schnüren,
			# unten durchhängend), oben Korkschwimmer
			for x: float in [-1.6, 1.6]:
				_klotz("holz_dunkel", Vector3(x - 0.06, -0.2, -0.06), Vector3(x + 0.06, 2.2, 0.06), 0.08 * x)
			_seil("holz_dunkel", Vector3(-1.7, 2.12, 0), Vector3(1.7, 2.12, 0), 0.045)
			var unten := func(x: float) -> float:
				return 0.55 + 0.35 * (x / 1.5) * (x / 1.5)        # der untere Rand hängt in der Mitte durch
			var x := -1.5
			while x <= 1.51:
				_seil("netz", Vector3(x, 2.08, 0.05), Vector3(x + 0.04, unten.call(x), 0.07 + 0.03 * sin(x * 3.0)), 0.006)
				x += 0.12
			var y := 2.0
			while y > 0.55:
				var a := -1.5
				while a < 1.5:
					var b := a + 0.25
					if y > unten.call(a) and y > unten.call(b):
						_seil("netz", Vector3(a, y, 0.06), Vector3(b, y - 0.01, 0.06), 0.005)
					a = b
				y -= 0.12
			x = -1.4
			while x < 1.45:
				_klotz("kork", Vector3(x - 0.05, 2.0, 0.03), Vector3(x + 0.05, 2.08, 0.1))
				x += 0.35
		38:  # Fischkorb: geflochtener Korb, oben Fische
			_zylinder("korb", Vector3(0, 0, 0), 0.24, 0.29, 0.38, 12)
			_zylinder("korb", Vector3(0, 0.36, 0), 0.3, 0.3, 0.04, 12)
			for i in 6:
				var w := i * 1.05
				var m := Vector3(cos(w) * 0.12, 0.38 + (i % 2) * 0.03, sin(w) * 0.12)
				_klotz("fisch", m + Vector3(-0.04, 0, -0.13), m + Vector3(0.04, 0.035, 0.13), w)
				_klotz("fisch_dunkel", m + Vector3(-0.025, 0.035, -0.11), m + Vector3(0.025, 0.045, 0.1), w)
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


## Schmiede: Bruchsteinwände an die Hofmauer gelehnt, vorn eine Brüstung mit Pfosten, darüber ein hochgeklappter
## Laden, rechts gemauert mit kleinem Fenster; Pultdach aus Ziegeln auf Sparren, Schlot über der Esse.
func _schmiede() -> void:
	var dach_y := func(z: float) -> float:
		return 4.9 + (z + 3.5) * (3.35 - 4.9) / 7.0
	# Wände
	_klotz("bruchstein", Vector3(-3.8, -0.5, -3.5), Vector3(3.8, 4.6, -2.2))
	for s_: float in [-1.0, 1.0]:
		var x0 := s_ * 3.3
		var x1 := s_ * 3.8
		_klotz("bruchstein", Vector3(minf(x0, x1), -0.5, -2.2), Vector3(maxf(x0, x1), 3.3, 2.7))
		# Giebeldreieck bis unter das Dach
		for x: float in [x0, x1]:
			_viereck("bruchstein", Vector3(x, 3.3, -2.2), Vector3(x, 3.3, 2.7), Vector3(x, dach_y.call(2.7), 2.7),
				Vector3(x, dach_y.call(-2.2), -2.2), Vector3(signf(x - (x0 + x1) / 2.0), 0, 0))
		_viereck("bruchstein", Vector3(x0, dach_y.call(-2.2), -2.2), Vector3(x1, dach_y.call(-2.2), -2.2),
			Vector3(x1, dach_y.call(2.7), 2.7), Vector3(x0, dach_y.call(2.7), 2.7), Vector3(0, 1, 0.2))
		# Eckquader vorn
		var y := 0.0
		var lang := true
		while y < 3.2:
			var w := 0.75 if lang else 0.45
			_klotz("quader", Vector3(minf(x1, x1 - s_ * w), y, 2.25 if lang else 2.0), Vector3(maxf(x1, x1 - s_ * w) + (0.02 if s_ > 0 else -0.0), y + 0.4, 2.74))
			y += 0.42
			lang = not lang
	# Vorderseite: Brüstung links, Türöffnung, Wand rechts mit Fenster, darüber Sturzbalken und Mauerband
	_klotz("bruchstein", Vector3(-3.3, -0.5, 2.2), Vector3(-0.9, 1.0, 2.7))
	_klotz("quader", Vector3(-3.35, 1.0, 2.15), Vector3(-0.85, 1.12, 2.82))
	_klotz("bruchstein", Vector3(0.9, -0.5, 2.2), Vector3(1.6, 2.6, 2.7))
	_klotz("bruchstein", Vector3(2.6, -0.5, 2.2), Vector3(3.3, 2.6, 2.7))
	_klotz("bruchstein", Vector3(1.6, -0.5, 2.2), Vector3(2.6, 1.2, 2.7))
	_klotz("bruchstein", Vector3(1.6, 2.1, 2.2), Vector3(2.6, 2.6, 2.7))
	_klotz("quader", Vector3(1.5, 1.08, 2.15), Vector3(2.7, 1.2, 2.86))
	_klotz("quader", Vector3(1.5, 2.1, 2.15), Vector3(2.7, 2.28, 2.8))
	_klotz("glas", Vector3(1.6, 1.2, 2.4), Vector3(2.6, 2.1, 2.45))
	_klotz("holz_dunkel", Vector3(2.07, 1.2, 2.45), Vector3(2.13, 2.1, 2.5))
	for k in 5:
		_klotz("metall", Vector3(1.6, 1.32 + k * 0.17, 2.6), Vector3(2.6, 1.35 + k * 0.17, 2.64))   # Gitterstäbe
	for x: float in [-0.9, 0.9, -2.1]:
		_klotz("holz_dunkel", Vector3(x - 0.13, 0.0 if absf(x) < 1.0 else 1.0, 2.2), Vector3(x + 0.13, 2.6, 2.72))
	_klotz("holz_dunkel", Vector3(-3.4, 2.6, 2.15), Vector3(3.4, 2.92, 2.78))
	_klotz("bruchstein", Vector3(-3.3, 2.92, 2.2), Vector3(3.3, 3.4, 2.7))
	_klotz("quader", Vector3(-1.0, -0.02, 2.1), Vector3(1.0, 0.08, 2.85))                       # Schwelle
	# hochgeklappter Laden über der linken Öffnung, auf zwei Stangen gestützt
	var l0 := Vector3(-3.15, 2.6, 2.78)
	var l1 := Vector3(-3.15, 2.05, 3.85)
	for d: float in [0.0, 0.06]:
		_viereck("holz", l0 + Vector3(0, d, 0), Vector3(-1.05, l0.y + d, l0.z), Vector3(-1.05, l1.y + d, l1.z), l1 + Vector3(0, d, 0),
			Vector3(0, 1, 0.5) if d > 0.0 else Vector3(0, -1, -0.5))
	for x: float in [-2.8, -1.4]:
		_seil("holz_dunkel", Vector3(x, 1.12, 2.75), Vector3(x, 2.1, 3.8), 0.03)
		_klotz("holz_dunkel", Vector3(x - 0.04, 2.02, 2.8), Vector3(x + 0.04, 2.6, 3.8))   # Leisten auf dem Laden
	# Dach: Ziegelfläche, Unterseite und Sparren, Stirnbrett
	var dz0 := -3.6
	var dz1 := 3.5
	for s_: float in [1.0, -1.0]:
		var o := 0.16 if s_ > 0 else 0.0
		_viereck("ziegel" if s_ > 0 else "holz_dunkel", Vector3(-4.1, dach_y.call(dz0) + o, dz0), Vector3(4.1, dach_y.call(dz0) + o, dz0),
			Vector3(4.1, dach_y.call(dz1) + o, dz1), Vector3(-4.1, dach_y.call(dz1) + o, dz1), Vector3(0, s_, s_ * 0.22))
	_klotz("holz_dunkel", Vector3(-4.15, dach_y.call(dz1) - 0.12, dz1 - 0.05), Vector3(4.15, dach_y.call(dz1) + 0.2, dz1 + 0.03))
	for s_: float in [-1.0, 1.0]:
		var x := s_ * 4.1
		_viereck("holz_dunkel", Vector3(x, dach_y.call(dz0), dz0), Vector3(x, dach_y.call(dz1), dz1),
			Vector3(x, dach_y.call(dz1) + 0.16, dz1), Vector3(x, dach_y.call(dz0) + 0.16, dz0), Vector3(s_, 0, 0))
	var sx := -3.0
	while sx <= 3.05:
		var a := Vector3(sx, dach_y.call(-2.2) - 0.02, -2.2)
		var e := Vector3(sx, dach_y.call(3.3) - 0.02, 3.3)
		for d: float in [0.0, -0.16]:
			_viereck("holz_dunkel", a + Vector3(-0.07, d, 0), e + Vector3(-0.07, d, 0), e + Vector3(0.07, d, 0), a + Vector3(0.07, d, 0),
				Vector3(0, -1 if d < 0 else 1, 0))
		for q: float in [-0.07, 0.07]:
			_viereck("holz_dunkel", a + Vector3(q, 0, 0), e + Vector3(q, 0, 0), e + Vector3(q, -0.16, 0), a + Vector3(q, -0.16, 0),
				Vector3(signf(q), 0, 0))
		sx += 0.75
	_klotz("holz_dunkel", Vector3(-3.3, 2.6, 0.2), Vector3(3.3, 2.82, 0.42))   # Unterzug
	# Schlot über der Esse, durch das Dach, mit Abdeckplatte
	_klotz("bruchstein", Vector3(-2.75, 3.0, -3.4), Vector3(-1.65, 6.6, -2.3))
	_klotz("quader", Vector3(-2.85, 6.6, -3.5), Vector3(-1.55, 6.75, -2.2))
	_klotz("quader", Vector3(-2.6, 6.75, -3.25), Vector3(-1.8, 6.85, -2.45))
	# Esse: gemauerter Herd, Feuergrube mit Glut, Rauchhaube bis zum Schlot
	_klotz("bruchstein", Vector3(-3.3, 0.0, -2.2), Vector3(-1.2, 0.85, -1.05))
	_klotz("quader", Vector3(-3.32, 0.85, -2.2), Vector3(-1.18, 0.95, -1.0))
	_klotz("glut", Vector3(-2.75, 0.9, -1.95), Vector3(-1.7, 1.0, -1.3))
	_klotz("kohle", Vector3(-2.85, 0.95, -2.05), Vector3(-2.75, 1.05, -1.2))
	_klotz("kohle", Vector3(-1.7, 0.95, -2.05), Vector3(-1.6, 1.05, -1.2))
	# Feuerwand hinter der Glut (hellere Ziegel), Feuerbock und Schürhaken
	_klotz("ziegelstein", Vector3(-2.9, 0.95, -2.2), Vector3(-1.5, 1.9, -2.12))
	_klotz("metall", Vector3(-2.3, 0.95, -2.12), Vector3(-2.1, 1.05, -1.95))   # Düse des Blasebalgs
	_seil("metall", Vector3(-1.55, 0.97, -1.4), Vector3(-1.0, 1.25, -0.8), 0.012)
	_seil("metall", Vector3(-1.6, 0.97, -1.6), Vector3(-0.95, 1.2, -1.15), 0.014)
	# Rauchhaube: vierseitiger Trichter aus Bruchstein, unten ein Rahmen aus Quadern mit Eisenband,
	# oben der Hals in den Schlot (innen und außen sichtbar)
	var hu := [Vector3(-3.3, 2.2, -2.2), Vector3(-1.1, 2.2, -2.2), Vector3(-1.1, 2.2, -0.95), Vector3(-3.3, 2.2, -0.95)]
	var ho := [Vector3(-2.75, 3.5, -2.2), Vector3(-1.65, 3.5, -2.2), Vector3(-1.65, 3.5, -1.7), Vector3(-2.75, 3.5, -1.7)]
	for k in [1, 2, 3]:   # rechts, vorn, links (hinten ist die Wand)
		var a0: Vector3 = hu[k]
		var a1: Vector3 = hu[(k + 1) % 4]
		var b1: Vector3 = ho[(k + 1) % 4]
		var b0: Vector3 = ho[k]
		var mitte := (a0 + a1 + b0 + b1) / 4.0
		var aussen := (mitte - Vector3(-2.2, 3.2, -1.95)).normalized()
		_viereck("bruchstein", a0, a1, b1, b0, aussen)
		_viereck("ruß", a0 - aussen * 0.02, a1 - aussen * 0.02, b1 - aussen * 0.02, b0 - aussen * 0.02, -aussen)
	_klotz("bruchstein", Vector3(-2.75, 3.5, -2.3), Vector3(-1.65, 4.45, -1.7))     # Hals bis unter das Dach
	_klotz("quader", Vector3(-3.3, 1.95, -1.08), Vector3(-1.0, 2.25, -0.88))         # Rahmen vorn
	_klotz("quader", Vector3(-1.2, 1.95, -2.2), Vector3(-1.0, 2.25, -0.88))          # Rahmen rechts
	_klotz("metall", Vector3(-3.3, 2.02, -0.89), Vector3(-0.99, 2.08, -0.86))        # Eisenband
	_klotz("metall", Vector3(-1.01, 2.02, -2.2), Vector3(-0.98, 2.08, -0.86))
	for x: float in [-3.25, -1.15]:
		_klotz("metall", Vector3(x - 0.04, 0.95, -1.05), Vector3(x + 0.04, 1.95, -0.97))   # Eisenstützen der Haube
	# Haken am Rahmen mit Zangen und einem Schöpflöffel
	for k in 4:
		var x := -3.0 + k * 0.5
		_klotz("metall", Vector3(x - 0.015, 1.75, -0.86), Vector3(x + 0.015, 1.95, -0.83))
		if k % 2 == 0:
			_klotz("metall", Vector3(x - 0.04, 1.2, -0.85), Vector3(x - 0.015, 1.78, -0.83))
			_klotz("metall", Vector3(x + 0.015, 1.2, -0.85), Vector3(x + 0.04, 1.78, -0.83))
		else:
			_klotz("holz_dunkel", Vector3(x - 0.015, 1.35, -0.85), Vector3(x + 0.015, 1.78, -0.83))
			_klotz("metall", Vector3(x - 0.07, 1.25, -0.88), Vector3(x + 0.07, 1.35, -0.78))
	# Wassereimer und Kohlenschaufel neben der Esse
	_zylinder("holz", Vector3(-3.0, 0, -0.6), 0.17, 0.19, 0.38, 8)
	_klotz("wasser", Vector3(-3.13, 0.35, -0.73), Vector3(-2.87, 0.36, -0.47))
	_seil("holz_dunkel", Vector3(-3.2, 0.0, -0.25), Vector3(-3.25, 1.2, -0.3), 0.02)
	_klotz("metall", Vector3(-3.3, 0.0, -0.36), Vector3(-3.1, 0.25, -0.2))
	# Blasebalg neben der Esse mit Hebelstange
	_viereck("stoff_leder", Vector3(-1.15, 0.6, -2.1), Vector3(-0.35, 0.6, -2.1), Vector3(-0.35, 0.95, -2.1), Vector3(-1.15, 0.7, -2.1), Vector3(0, 0, -1))
	_klotz("holz_dunkel", Vector3(-1.15, 0.55, -2.15), Vector3(-0.35, 0.6, -1.55))
	_klotz("stoff_leder", Vector3(-1.1, 0.6, -2.1), Vector3(-0.4, 0.82, -1.6))
	_klotz("holz_dunkel", Vector3(-1.15, 0.82, -2.15), Vector3(-0.35, 0.87, -1.55))
	_klotz("holz_dunkel", Vector3(-1.2, 0.0, -2.1), Vector3(-1.1, 0.55, -2.0))
	_klotz("holz_dunkel", Vector3(-0.45, 0.0, -2.1), Vector3(-0.35, 0.55, -2.0))
	_seil("holz_dunkel", Vector3(-0.4, 0.87, -1.85), Vector3(-0.1, 1.9, -1.85), 0.035)
	_klotz("metall", Vector3(-0.15, 1.85, -1.95), Vector3(-0.05, 2.1, -1.75))
	# Amboss auf dem Klotz, daneben Zangen und Hammer
	_zylinder("holz_dunkel", Vector3(-1.4, 0, 0), 0.34, 0.37, 0.55, 10)
	_klotz("metall", Vector3(-1.52, 0.55, -0.1), Vector3(-1.28, 0.7, 0.1))
	_klotz("metall", Vector3(-1.72, 0.7, -0.15), Vector3(-1.15, 0.9, 0.15))
	_zylinder("metall", Vector3(-1.15, 0.8, 0), 0.0, 0.1, 0.34, 8, Basis(Vector3.FORWARD, PI / 2.0))
	_klotz("metall", Vector3(-1.62, 0.9, -0.05), Vector3(-1.35, 0.94, 0.0))     # Werkstück
	_klotz("glut", Vector3(-1.4, 0.9, -0.05), Vector3(-1.3, 0.94, 0.0))
	# Löschtrog mit Wasser
	_klotz("holz_dunkel", Vector3(-0.3, 0.0, -2.2), Vector3(0.6, 0.6, -1.55))
	_klotz("wasser", Vector3(-0.24, 0.6, -2.14), Vector3(0.54, 0.61, -1.61))
	# Werkzeugwand: Brett mit Zangen, Hämmern und Hufeisen
	_klotz("holz", Vector3(0.7, 1.0, -2.2), Vector3(3.1, 2.4, -2.14))
	_klotz("holz_dunkel", Vector3(0.7, 2.25, -2.14), Vector3(3.1, 2.3, -2.08))
	for k in 6:
		var x := 0.95 + k * 0.38
		match k % 3:
			0:   # Zange
				_klotz("metall", Vector3(x - 0.06, 1.35, -2.13), Vector3(x - 0.03, 2.2, -2.1), 0.0)
				_klotz("metall", Vector3(x + 0.03, 1.35, -2.13), Vector3(x + 0.06, 2.2, -2.1), 0.0)
				_klotz("metall", Vector3(x - 0.07, 2.0, -2.13), Vector3(x + 0.07, 2.06, -2.09))
			1:   # Hammer
				_klotz("holz_dunkel", Vector3(x - 0.02, 1.55, -2.13), Vector3(x + 0.02, 2.2, -2.1))
				_klotz("metall", Vector3(x - 0.1, 1.48, -2.14), Vector3(x + 0.1, 1.58, -2.07))
			2:   # Hufeisen
				_klotz("metall", Vector3(x - 0.09, 1.9, -2.13), Vector3(x - 0.06, 2.1, -2.1))
				_klotz("metall", Vector3(x + 0.06, 1.9, -2.13), Vector3(x + 0.09, 2.1, -2.1))
				_klotz("metall", Vector3(x - 0.09, 1.87, -2.13), Vector3(x + 0.09, 1.9, -2.1))
				_klotz("metall", Vector3(x - 0.09, 1.4, -2.13), Vector3(x + 0.09, 1.6, -2.1))
	# Kohlenkiste
	_klotz("holz_dunkel", Vector3(0.9, 0.0, -2.2), Vector3(2.0, 0.6, -1.4))
	_klotz("kohle", Vector3(0.95, 0.6, -2.15), Vector3(1.95, 0.66, -1.45))
	_klotz("kohle", Vector3(1.2, 0.66, -2.0), Vector3(1.7, 0.72, -1.6))
	# Werkbank an der rechten Wand mit Schraubstock, Klingen, Kette
	_klotz("holz", Vector3(2.4, 0.78, -1.2), Vector3(3.3, 0.9, 1.4))
	for z: float in [-1.1, 1.25]:
		for x: float in [2.5, 3.15]:
			_klotz("holz_dunkel", Vector3(x - 0.05, 0.0, z - 0.05), Vector3(x + 0.05, 0.78, z + 0.05))
	_klotz("holz_dunkel", Vector3(2.45, 0.2, -1.1), Vector3(3.2, 0.26, 1.3))
	_klotz("metall", Vector3(2.4, 0.9, 0.9), Vector3(2.62, 1.1, 1.15))
	_klotz("metall", Vector3(2.3, 0.98, 1.0), Vector3(2.4, 1.02, 1.05))
	for k in 3:
		_klotz("metall", Vector3(2.6, 0.9, -0.9 + k * 0.25), Vector3(3.2, 0.92, -0.84 + k * 0.25), 0.05 * k)
	for k in 6:
		_klotz("metall", Vector3(2.7 + k * 0.07, 0.9, 0.3), Vector3(2.75 + k * 0.07, 0.93, 0.36))
	# Fass mit Eisenstangen, Stapel Roheisen
	_zylinder("holz", Vector3(2.85, 0, 2.0), 0.28, 0.32, 0.8, 10)
	for k in 5:
		_seil("metall", Vector3(2.8 + (k % 3) * 0.05, 0.3, 1.95 + int(k / 3.0) * 0.08), Vector3(2.75 + k * 0.04, 1.8, 1.9 + k * 0.03), 0.015)
	for k in 4:
		_klotz("metall", Vector3(0.1, k * 0.08, -0.6 + (k % 2) * 0.05), Vector3(0.9, k * 0.08 + 0.07, -0.45 + (k % 2) * 0.05))
	# Zunftschild am Ausleger vorn rechts
	_klotz("metall", Vector3(3.05, 3.05, 2.7), Vector3(3.11, 3.11, 3.6))
	_klotz("metall", Vector3(3.05, 2.6, 2.7), Vector3(3.11, 3.1, 2.76))
	for z: float in [2.95, 3.45]:
		_klotz("metall", Vector3(3.07, 2.85, z - 0.01), Vector3(3.09, 3.05, z + 0.01))
	_klotz("holz", Vector3(3.04, 2.3, 2.85), Vector3(3.12, 2.85, 3.55))
	_klotz("metall", Vector3(3.0, 2.45, 3.05), Vector3(3.16, 2.52, 3.35))
	_klotz("metall", Vector3(3.0, 2.52, 3.13), Vector3(3.16, 2.68, 3.27))
	_klotz("metall", Vector3(3.0, 2.68, 3.02), Vector3(3.16, 2.75, 3.38))
	# Boden aus gestampftem Lehm mit Schlacke
	_klotz("lehm", Vector3(-3.3, -0.3, -2.2), Vector3(3.3, 0.02, 2.2))


## Flacher, unregelmäßiger Fleck (Pfütze, feuchter Rand): Scheibe mit welligem Umriss, nach oben gewandt.
func _fleck(mat: String, mitte: Vector3, r: float, phase: float) -> void:
	var st := _st(mat)
	var teile := 20
	for k in teile:
		var w0 := TAU * k / teile
		var w1 := TAU * (k + 1) / teile
		var r0 := r * (1.0 + 0.22 * sin(w0 * 3.0 + phase) + 0.1 * sin(w0 * 5.0 + phase * 2.0))
		var r1 := r * (1.0 + 0.22 * sin(w1 * 3.0 + phase) + 0.1 * sin(w1 * 5.0 + phase * 2.0))
		st.add_vertex(mitte)   # Reihenfolge wie in _viereck: so zeigt die Vorderseite nach oben
		st.add_vertex(mitte + Vector3(cos(w0) * r0, 0, sin(w0) * r0 * 0.8))
		st.add_vertex(mitte + Vector3(cos(w1) * r1, 0, sin(w1) * r1 * 0.8))


## Seil oder Stange als dünner Zylinder von a nach b.
func _seil(mat: String, a: Vector3, b: Vector3, r: float) -> void:
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	_zylinder(mat, a, r, r, a.distance_to(b), 5, Basis(x, y, z))


## Rumpf aus Spanten (Querschnitte entlang z), für Kogge, Ruderboot und Prahm. Bug und Heck laufen in geraden, schräg
## gestellten Steven aus (der Kiel ist um `steven` kürzer als das Deck); die Bordwand ist geklinkert: Jeder Plankengang
## liegt mit der Unterkante etwas außen über dem darunter. Barghölzer laufen außen entlang, bei der Kogge ragen die
## Decksbalken durch die Bordwand. Rückgabe: Funktion t (−1 Bug … 1 Heck) → [Breite, Deckshöhe, z an der Reling].
func _rumpf(laenge: float, breite: float, stationen: int, tief: float, hoch: float, kastelle: bool, steven := 0.22) -> Callable:
	var lk := laenge * (1.0 - steven)
	var weite := func(t: float) -> float:
		return breite * pow(maxf(1.0 - pow(absf(t), 2.6), 0.0), 0.6) + 0.05
	var oben := func(t: float) -> float:
		return hoch + t * t * hoch * 0.45 + (t * t * 0.4 if kastelle and t > 0.0 else 0.0)
	# Querschnitt vom Kiel zur Reling: (Anteil der Breite, Höhe: < 0 Anteil des Tiefgangs, > 0 Anteil der Deckshöhe)
	var profil := [Vector2(0.0, -1.0), Vector2(0.34, -0.97), Vector2(0.64, -0.84), Vector2(0.85, -0.6), Vector2(0.96, -0.3),
		Vector2(1.0, 0.05), Vector2(1.0, 0.4), Vector2(0.99, 0.72), Vector2(0.97, 1.0)]
	var punkt := func(t: float, i: int, s: float) -> Vector3:
		var f: Vector2 = profil[i]
		var d: float = oben.call(t)
		var y := f.y * tief if f.y < 0.0 else f.y * d
		var z := t * (lk / 2.0 + (y + tief) / (d + tief) * (laenge - lk) / 2.0)
		return Vector3(s * f.x * float(weite.call(t)), y, z)
	var klinker := breite * 0.014
	for s: float in [-1.0, 1.0]:
		for k in stationen:
			var t0 := -1.0 + 2.0 * k / stationen
			var t1 := -1.0 + 2.0 * (k + 1) / stationen
			for i in profil.size() - 1:
				var a: Vector3 = punkt.call(t0, i, s)
				var b: Vector3 = punkt.call(t1, i, s)
				var c: Vector3 = punkt.call(t1, i + 1, s)
				var d: Vector3 = punkt.call(t0, i + 1, s)
				var ri := Vector2(c.x - b.x, c.y - b.y)
				var aussen := Vector3(ri.y * s, -ri.x * s, 0.0).normalized()
				if aussen == Vector3.ZERO:
					aussen = Vector3(s, 0, 0)
				if i > 0:   # Klinker: die Unterkante liegt außen auf dem Gang darunter
					a += aussen * klinker
					b += aussen * klinker
				var mat := "rumpf_teer" if (a.y + d.y) / 2.0 < 0.1 else "rumpf"
				_viereck(mat, a, b, c, d, aussen)
				_viereck("rumpf_innen", a - aussen * 0.06, b - aussen * 0.06, c - aussen * 0.06, d - aussen * 0.06, -aussen)
		# Barghölzer: eines an der Reling, eines halb hoch, bei der Kogge ein drittes
		for i: int in ([8, 6, 5] if kastelle else [8, 6]):
			for k in stationen:
				var t0 := -1.0 + 2.0 * k / stationen
				var t1 := -1.0 + 2.0 * (k + 1) / stationen
				var r := breite * (0.03 if i == 8 else 0.036)
				_seil("holz_dunkel", punkt.call(t0, i, s) + Vector3(s * r, 0, 0), punkt.call(t1, i, s) + Vector3(s * r, 0, 0), r)
	# Deck (bzw. Bodenbretter) unter der Reling
	var tiefer := 0.95 if kastelle else hoch * 0.32
	for k in stationen:
		var t0 := -1.0 + 2.0 * k / stationen
		var t1 := -1.0 + 2.0 * (k + 1) / stationen
		if absf(t0) > 0.93 or absf(t1) > 0.93:
			continue
		var y0: float = oben.call(t0) - tiefer
		var y1: float = oben.call(t1) - tiefer
		var w0: float = weite.call(t0) * 0.985
		var w1: float = weite.call(t1) * 0.985
		var z0 := t0 * (lk / 2.0 + (y0 + tief) / (float(oben.call(t0)) + tief) * (laenge - lk) / 2.0)
		var z1 := t1 * (lk / 2.0 + (y1 + tief) / (float(oben.call(t1)) + tief) * (laenge - lk) / 2.0)
		_viereck("deck", Vector3(-w0, y0, z0), Vector3(w0, y0, z0), Vector3(w1, y1, z1), Vector3(-w1, y1, z1), Vector3.UP)
	# Kiel und Steven
	_klotz("holz_dunkel", Vector3(-breite * 0.05, -tief - breite * 0.06, -lk / 2.0), Vector3(breite * 0.05, -tief + 0.05, lk / 2.0))
	for e: float in [-1.0, 1.0]:
		_seil("holz_dunkel", Vector3(0, -tief - breite * 0.04, e * lk / 2.0),
			Vector3(0, float(oben.call(e)) + breite * 0.12, e * (laenge / 2.0 + breite * 0.05)), breite * 0.045)
	if kastelle:   # Decksbalken, die durch die Bordwand ragen
		for t: float in [-0.62, -0.38, -0.12, 0.2, 0.42]:
			var y: float = oben.call(t) * 0.62
			var w: float = weite.call(t)
			var z := t * (lk / 2.0 + (y + tief) / (float(oben.call(t)) + tief) * (laenge - lk) / 2.0)
			_klotz("holz_dunkel", Vector3(-w - 0.38, y - 0.14, z - 0.14), Vector3(w + 0.38, y + 0.14, z + 0.14))
	return func(t: float) -> Array:
		var d: float = oben.call(t)
		return [weite.call(t), d, t * laenge / 2.0]


## Ruderboot: kleiner Rumpf, drei Ducht-Bänke, zwei Riemen.
func _ruderboot() -> void:
	_rumpf(5.0, 0.75, 12, 0.45, 0.55, false, 0.16)
	for z: float in [-1.2, 0.0, 1.2]:
		_klotz("holz", Vector3(-0.68, 0.3, z - 0.12), Vector3(0.68, 0.36, z + 0.12))
	for s: float in [-1.0, 1.0]:
		_seil("holz_dunkel", Vector3(s * 0.3, 0.45, 0.1), Vector3(s * 2.1, -0.05, 0.6), 0.035)


## Prahm: flacher Lastkahn ohne Mast (passt unter das Gewölbe des Untergrundhafens), beladen mit Kisten, Fässern
## und Säcken, dazu ein Staken.
func _prahm() -> void:
	_rumpf(12.0, 2.1, 14, 0.8, 1.0, false, 0.1)
	# Die Ladung steht auf dem Deck des Rumpfs (eine eigene, rechteckige Ladefläche ragte an Bug und Heck aus dem
	# spitz zulaufenden Rumpf heraus)
	for z: float in [-3.6, -2.4, 2.6]:
		_klotz("holz", Vector3(-0.9, 0.65, z - 0.4), Vector3(-0.1, 1.35, z + 0.4))
		_klotz("holz_dunkel", Vector3(-0.92, 1.1, z - 0.42), Vector3(-0.08, 1.18, z + 0.42))
	_klotz("holz", Vector3(0.2, 1.35, -3.4), Vector3(0.9, 1.95, -2.7))
	for z: float in [-0.6, 0.4, 1.4]:
		_zylinder("holz", Vector3(0.7, 0.65, z), 0.3, 0.36, 0.9, 12)
		_zylinder("metall", Vector3(0.7, 0.8, z), 0.345, 0.37, 0.07, 12)
	for k in 3:
		_klotz("sack", Vector3(-1.2 + k * 0.45, 0.65, 3.9), Vector3(-0.8 + k * 0.45, 1.1, 4.5), 0.2 * (k - 1))
	_seil("holz_dunkel", Vector3(1.3, 0.76, -3.8), Vector3(1.25, 0.8, 3.8), 0.05)   # Staken, längs abgelegt


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


## Kogge: bauchiger, geklinkerter Rumpf mit geraden Steven, durchgesteckte Decksbalken, Achter- und Vorderkastell
## mit Reling, Heckruder mit Pinne, Mast mit Mastkorb, Wanten mit Webeleinen, Stagen und Wimpel.
## segel: 0 im Hafen an der Rahe aufgetucht, 1 voll gesetzt und gebläht (in der Bucht), 2 lose zum Trocknen gesetzt.
## Das Segel ist gestreift (Leinen und Rotbraun), wie auf den Siegeln der Hansestädte.
func _kogge(segel: int) -> void:
	var laenge := 19.0
	var r: Callable = _rumpf(laenge, 2.8, 20, 1.7, 1.8, true)
	# Achterkastell: Plattform über dem Heck, Front mit Tür zum Deck, Reling mit Pfosten
	var ka := 3.15
	_kastell(Vector3(0, ka, 4.0), [Vector2(-2.55, 4.0), Vector2(2.55, 4.0), Vector2(1.75, 9.6), Vector2(-1.75, 9.6)], 1.05)
	_klotz("holz", Vector3(-2.45, 0.9, 3.9), Vector3(2.45, ka, 4.05))
	_klotz("holz_dunkel", Vector3(-0.5, 0.95, 3.82), Vector3(0.5, 2.6, 3.9))
	for x: float in [-2.2, 2.2]:
		_klotz("holz_dunkel", Vector3(x - 0.12, 0.9, 3.85), Vector3(x + 0.12, ka + 1.15, 4.1))
	# Vorderkastell: dreieckig, über den Vorsteven hinaus
	var kv := 3.45
	_kastell(Vector3(0, kv, -6.2), [Vector2(-2.3, -6.2), Vector2(2.3, -6.2), Vector2(0.35, -10.9), Vector2(-0.35, -10.9)], 0.95)
	for x: float in [-1.6, 1.6]:
		_klotz("holz_dunkel", Vector3(x - 0.12, 1.3, -6.35), Vector3(x + 0.12, kv, -6.1))
	# Heckruder am Achtersteven, Pinne ins Kastell
	var fuss := Vector3(0, -1.7, laenge * 0.78 / 2.0)
	var kopf := Vector3(0, float(r.call(1.0)[1]) + 0.2, laenge / 2.0 + 0.1)
	var blatt := func(u: float, hinten: float) -> Vector3:
		return fuss.lerp(kopf, u) + Vector3(0, 0, 0.18 + hinten)
	for x: float in [-0.09, 0.09]:
		_viereck("holz_dunkel", blatt.call(0.0, 0.0) + Vector3(x, 0, 0), blatt.call(0.0, 1.5) + Vector3(x, 0, 0),
			blatt.call(0.55, 0.45) + Vector3(x, 0, 0), blatt.call(0.55, 0.0) + Vector3(x, 0, 0), Vector3(signf(x), 0, 0))
	_seil("holz_dunkel", blatt.call(0.0, 0.0), blatt.call(0.9, 0.0), 0.12)
	_seil("holz_dunkel", blatt.call(0.0, 1.5), blatt.call(0.55, 0.45), 0.05)
	_seil("holz_dunkel", blatt.call(0.85, 0.0), Vector3(0, ka - 0.4, 7.2), 0.07)
	# Mast mit Mastkorb, Rahe, Bugspriet
	var mz := -0.6
	_zylinder("holz_dunkel", Vector3(0, 0.9, mz), 0.22, 0.25, 17.2, 10)
	_zylinder("holz", Vector3(0, 16.0, mz), 0.62, 0.68, 0.85, 10)
	_zylinder("holz_dunkel", Vector3(0, 16.0, mz), 0.7, 0.7, 0.08, 10)
	var ry := 15.0 if segel != 2 else 14.2
	_zylinder("holz_dunkel", Vector3(5.6, ry, mz), 0.13, 0.16, 11.2, 8, Basis(Vector3.FORWARD, -PI / 2.0))
	_seil("holz_dunkel", Vector3(0, 3.0, -9.4), Vector3(0, 5.4, -14.2), 0.13)
	# Wanten mit Webeleinen (Sprossen aus Tauwerk), Vor- und Achterstag, Brassen von den Nocken der Rahe
	var top := Vector3(0, 15.6, mz)
	for s: float in [-1.0, 1.0]:
		var fuesse: Array[Vector3] = []
		for t: float in [-0.16, -0.06, 0.04]:
			var q: Array = r.call(t)
			fuesse.append(Vector3(s * (float(q[0]) + 0.12), float(q[1]) - 0.05, float(q[2])))
		for f in fuesse:
			_seil("seil", top, f, 0.032)
			_klotz("holz_dunkel", f - Vector3(0.06, 0.5, 0.12), f + Vector3(0.06, 0.1, 0.12))
		var u := 0.08
		while u < 0.62:
			for j in fuesse.size() - 1:
				_seil("seil", fuesse[j].lerp(top, u), fuesse[j + 1].lerp(top, u), 0.016)
			u += 0.045
		_seil("seil", Vector3(s * 5.5, ry, mz), Vector3(s * 1.6, ka + 1.0, 8.6), 0.022)
	_seil("seil", top, Vector3(0, 5.3, -14.0), 0.04)
	_seil("seil", top + Vector3(0, 0.3, 0), Vector3(0, ka + 1.1, 9.4), 0.04)
	_seil("seil", Vector3(0, 16.4, mz), Vector3(0, ry + 0.15, mz), 0.06)   # Fall der Rahe
	# Wimpel am Masttopp (rot, nach achtern wehend), Laterne am Heck
	var wz := mz
	_viereck("wimpel", Vector3(0, 17.9, wz), Vector3(0, 17.3, wz), Vector3(0.0, 17.65, wz + 3.0), Vector3(0.0, 17.65, wz + 3.0), Vector3.RIGHT)
	_viereck("wimpel", Vector3(0, 17.9, wz), Vector3(0, 17.3, wz), Vector3(0.0, 17.65, wz + 3.0), Vector3(0.0, 17.65, wz + 3.0), Vector3.LEFT)
	_zylinder("holz_dunkel", Vector3(0, 16.85, wz), 0.06, 0.06, 1.1, 6)
	_klotz("metall", Vector3(-0.18, ka + 1.2, 9.25), Vector3(0.18, ka + 1.65, 9.6))
	# Segel: 10 Bahnen im Wechsel hell und rotbraun
	var bahnen := 10
	var bahn := func(i: int) -> String:
		return "segel_streifen" if i % 2 == 1 else "segel"
	match segel:
		0:   # aufgetucht: ein dicker, faltiger Wulst unter der Rahe, mit Zeisingen festgebunden
			var x := -5.2
			while x < 5.2:
				var r0 := 0.34 + 0.12 * sin(x * 2.3) + 0.08 * (1.0 - absf(x) / 5.5)
				_zylinder(bahn.call(int((x + 5.5) / 1.1)), Vector3(x + 0.55, ry - 0.42, mz + 0.05), r0, r0 + 0.1, 0.55, 8, Basis(Vector3.FORWARD, -PI / 2.0))
				x += 0.55
			for zx: float in [-4.2, -2.6, -1.0, 1.0, 2.6, 4.2]:
				_zylinder("seil", Vector3(zx + 0.05, ry - 0.4, mz + 0.05), 0.5, 0.5, 0.1, 8, Basis(Vector3.FORWARD, -PI / 2.0))
		1, 2:  # voll gesetzt (gebläht nach vorn) oder lose hängend (leichte Falten, unten durchhängend)
			var reihen := 8
			var unten := 4.4 if segel == 1 else 6.4
			for i in bahnen:
				for j in reihen:
					var p := func(ii: int, jj: int) -> Vector3:
						var u := float(ii) / bahnen * 2.0 - 1.0
						var v := float(jj) / reihen
						var y := ry - 0.15 - v * (ry - 0.15 - unten)
						if segel == 1:
							var bauch := (1.0 - u * u * 0.85) * sin(v * PI * 0.92) * 1.7
							return Vector3(u * 5.3 * (1.0 - v * 0.06), y + u * u * v * 0.5, mz - 0.25 - bauch)
						var falte := sin(u * 13.0 + v * 2.0) * 0.12 * v + v * v * 0.35
						return Vector3(u * 5.3 * (1.0 - v * 0.08), y + (1.0 - u * u) * v * v * -0.4, mz - 0.2 - falte)
					var aussen := Vector3(0, 0, -1)
					_viereck(bahn.call(i), p.call(i, j), p.call(i + 1, j), p.call(i + 1, j + 1), p.call(i, j + 1), aussen)
			# Schoten von den Schothörnern nach achtern an Deck
			for sx: float in [-1.0, 1.0]:
				var horn := Vector3(sx * 5.3 * (1.0 - (0.06 if segel == 1 else 0.08)), unten + (0.5 if segel == 1 else 0.0), mz - 0.25)
				_seil("seil", horn, Vector3(sx * 2.2, 2.7, 3.2), 0.025)
				_seil("seil", Vector3(sx * 4.0, unten + 0.3, mz - 0.4), Vector3(sx * 1.4, 3.4, -6.0), 0.02)


## Kastell: Plattform (Umriss in x/z auf Höhe mitte.y) mit Brüstung aus Planken zwischen Pfosten und einem Handlauf.
func _kastell(mitte: Vector3, umriss: Array, hoehe: float) -> void:
	var y := mitte.y
	var p := func(i: int, dy: float) -> Vector3:
		var v: Vector2 = umriss[i % umriss.size()]
		return Vector3(v.x, y + dy, v.y)
	var n := umriss.size()
	# Boden (oben Deck, unten dunkles Holz)
	_viereck("deck", p.call(0, 0.0), p.call(1, 0.0), p.call(2, 0.0), p.call(3, 0.0), Vector3.UP)
	_viereck("holz_dunkel", p.call(0, -0.18), p.call(1, -0.18), p.call(2, -0.18), p.call(3, -0.18), Vector3.DOWN)
	var schwerpunkt := Vector3.ZERO
	for i in n:
		schwerpunkt += p.call(i, 0.0) / n
	for i in n:
		var a: Vector3 = p.call(i, 0.0)
		var b: Vector3 = p.call(i + 1, 0.0)
		if i == 0:
			continue   # zur Schiffsmitte hin offen (dort steht die Front)
		var aussen := ((a + b) / 2.0 - schwerpunkt) * Vector3(1, 0, 1)
		# Randbalken unter der Plattform, Brüstung aus Planken, Handlauf
		_viereck("holz_dunkel", a + Vector3(0, -0.18, 0), b + Vector3(0, -0.18, 0), b + Vector3(0, -0.45, 0), a + Vector3(0, -0.45, 0), aussen)
		_viereck("holz", a, b, b + Vector3(0, hoehe * 0.8, 0), a + Vector3(0, hoehe * 0.8, 0), aussen)
		_viereck("rumpf_innen", a, b, b + Vector3(0, hoehe * 0.8, 0), a + Vector3(0, hoehe * 0.8, 0), -aussen)
		_seil("holz_dunkel", a + Vector3(0, hoehe, 0), b + Vector3(0, hoehe, 0), 0.07)
		var l := a.distance_to(b)
		var stueck := int(l / 0.9)
		for k in stueck + 1:
			var q := a.lerp(b, float(k) / maxf(stueck, 1))
			_klotz("holz_dunkel", q - Vector3(0.07, 0.45, 0.07), q + Vector3(0.07, hoehe, 0.07))
	# Brüstung vorn zur Schiffsmitte: nur ein Handlauf mit Pfosten
	var a0: Vector3 = p.call(0, 0.0)
	var b0: Vector3 = p.call(1, 0.0)
	_seil("holz_dunkel", a0 + Vector3(0, hoehe, 0), b0 + Vector3(0, hoehe, 0), 0.06)
	for k in 5:
		var q := a0.lerp(b0, k / 4.0)
		_klotz("holz_dunkel", q - Vector3(0.05, 0.0, 0.05), q + Vector3(0.05, hoehe, 0.05))


func _material(name_: String) -> Material:
	if _mats.has(name_):
		return _mats[name_]
	var m: Material
	match name_:
		"holz":
			m = load("res://material/holz.tres")
		"metall":
			m = load("res://material/metall.tres")
		"bruchstein":
			m = load("res://material/bruchstein.tres")
		"quader":
			m = load("res://material/hell.tres")
		"ziegel":
			m = load("res://material/dach.tres")
		"ziegelstein":
			var zs: StandardMaterial3D = load("res://material/dach.tres").duplicate()
			zs.albedo_color = Color(0.85, 0.55, 0.4)
			zs.uv1_scale = Vector3(1.2, 1.2, 1.2)
			m = zs
		_:
			var s := StandardMaterial3D.new()
			s.roughness = 0.9
			if name_ == "stein":
				s.albedo_texture = load("res://texturen/klippe_farbe.jpg")
				s.uv1_triplanar = true
				s.uv1_scale = Vector3(0.5, 0.5, 0.5)
			elif name_ in ["glut", "wasser", "glas", "kohle", "lehm", "stoff_leder", "ruß", "schlamm", "netz", "fisch", "fisch_dunkel", "kork", "pfuetze", "pfuetze_rand"]:
				pass
			elif name_ in ["fell", "haar", "taube", "taube_hals", "taube_dunkel"]:
				pass
			elif not name_ in ["holz_dunkel", "korb", "rumpf_teer", "deck", "rumpf", "rumpf_innen"]:
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
			if name_ in ["wasser", "glas"]:
				s.roughness = 0.04
				s.metallic = 0.55
			s.albedo_color = {"holz_dunkel": Color(0.45, 0.36, 0.3), "glut": Color(1.0, 0.5, 0.15), "wasser": Color(0.1, 0.12, 0.12),
				"stein": Color(0.62, 0.58, 0.52), "dach": Color(0.45, 0.25, 0.18), "heu": Color(0.82, 0.7, 0.36),
				"fell": Color(0.36, 0.22, 0.13), "haar": Color(0.12, 0.09, 0.07), "korb": Color(0.85, 0.68, 0.42),
				"rumpf_teer": Color(0.2, 0.16, 0.13), "deck": Color(0.8, 0.68, 0.52), "segel": Color(0.86, 0.8, 0.66),
				"segel_streifen": Color(0.56, 0.17, 0.1), "rumpf": Color(0.58, 0.45, 0.33), "rumpf_innen": Color(0.5, 0.4, 0.3),
				"sack": Color(0.85, 0.76, 0.58), "markise_a": STOFFE[0], "markise_b": STOFFE[1],
				"ware_rot": Color(0.75, 0.18, 0.1), "ware_gruen": Color(0.3, 0.5, 0.15),
				"ware_tuch": STOFFE[2], "ware_tuch2": STOFFE[3], "seil": Color(0.5, 0.42, 0.3),
				"wimpel": Color(0.65, 0.08, 0.06), "glas": Color(0.1, 0.13, 0.13), "kohle": Color(0.05, 0.05, 0.05),
				"lehm": Color(0.32, 0.27, 0.22), "stoff_leder": Color(0.35, 0.22, 0.12),
				"schlamm": Color(0.2, 0.15, 0.1), "taube": Color(0.55, 0.57, 0.62), "taube_hals": Color(0.35, 0.45, 0.42), "taube_dunkel": Color(0.32, 0.33, 0.37),
				"ruß": Color(0.07, 0.06, 0.055), "netz": Color(0.3, 0.26, 0.2), "kork": Color(0.62, 0.45, 0.26),
				"fisch": Color(0.68, 0.72, 0.74), "fisch_dunkel": Color(0.3, 0.34, 0.38)}.get(name_, Color(0.6, 0.6, 0.6))
			if name_ in ["pfuetze", "pfuetze_rand"]:
				# halb durchsichtig: das Pflaster scheint durch, die Pfütze spiegelt den Himmel, der Rand ist nur feucht
				s.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				s.albedo_color = Color(0.18, 0.21, 0.23, 0.55) if name_ == "pfuetze" else Color(0.08, 0.07, 0.06, 0.32)
				s.roughness = 0.04 if name_ == "pfuetze" else 0.35
				s.metallic_specular = 0.9 if name_ == "pfuetze" else 0.5
			if name_ == "fisch":
				s.metallic = 0.45
				s.roughness = 0.35
			if name_.begins_with("markise") or name_ in ["segel", "segel_streifen", "wimpel"]:
				s.cull_mode = BaseMaterial3D.CULL_DISABLED
			m = s
	_mats[name_] = m
	return m
