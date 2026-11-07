@tool
extends Node3D
## Felssockel unter den Hofmauern (wie im Referenzbild): eine geschlossene, zerklüftete Felswand, die genau unter der
## Mauer am Hofrand entlangläuft und vom Mauerfuß bis unter den Boden reicht. Gebaut wird sie aus Säulen, die die
## Bauskripte (werkzeuge/bau/teil_felsen.py) am Hofrand setzen; benachbarte Säulen desselben Abschnitts werden zu einer
## Wand verbunden. Die Wand ist leicht nach außen geböscht, hat Felsbänder mit vorstehenden Absätzen und eine
## unregelmäßige Oberfläche. An Toren und Wegen beginnt ein neuer Abschnitt, dort bleibt sie offen.

## Je Säule: x, z, Normale x, Normale z (nach außen), oben (knapp unter dem Hofboden), unten (unter dem Gelände), Abschnitt
@export var saeulen := PackedFloat32Array():
	set(w):
		saeulen = w
		if is_inside_tree():
			_baue()
@export var material: Material:
	set(w):
		material = w
		if is_inside_tree():
			_baue()
@export var kollision := true

const SCHRITT := 7
const ZEILE := 0.7          # Höhe einer Zeile im Gitter (Meter)
const ABSTAND := 1.6        # so weit steht die Wand oben vor der Mauerlinie (die Mauer ist 3 m dick)

var _rauschen := FastNoiseLite.new()
var _grob := FastNoiseLite.new()


func _ready() -> void:
	_baue()


func _baue() -> void:
	for kind in get_children():
		kind.free()
	if saeulen.size() < SCHRITT * 2:
		return
	_rauschen.seed = 3141
	_rauschen.frequency = 0.35
	_rauschen.fractal_octaves = 3
	_grob.seed = 2718
	_grob.frequency = 0.06
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	@warning_ignore("integer_division")
	var n := saeulen.size() / SCHRITT
	for k in n - 1:
		var i := k * SCHRITT
		var j := (k + 1) * SCHRITT
		if saeulen[i + 6] != saeulen[j + 6]:
			continue        # anderer Abschnitt: hier bleibt die Wand offen (Tor, Weg)
		var zeilen := maxi(2, ceili(maxf(saeulen[i + 4] - saeulen[i + 5], saeulen[j + 4] - saeulen[j + 5]) / ZEILE))
		var aussen := Vector3(saeulen[i + 2] + saeulen[j + 2], 0.0, saeulen[i + 3] + saeulen[j + 3]).normalized()
		# Deckfläche oben: von der Mauer bis an die Felskante, damit von oben keine Lücke klafft
		_viereck(st, _mauer(i), _mauer(j), _punkt(j, 0.0), _punkt(i, 0.0), Vector3.UP)
		for z in zeilen:
			var t0 := float(z) / zeilen
			var t1 := float(z + 1) / zeilen
			_viereck(st, _punkt(i, t0), _punkt(j, t0), _punkt(j, t1), _punkt(i, t1), aussen)
		# Kappen an den Enden eines Abschnitts: vom Fels zurück an die Mauerlinie, damit man nicht dahinter schaut
		# Richtung weg vom Streifen aus der Geometrie (an Ecken wäre die Kantenrichtung unbestimmt)
		var weg := (_innen(j, 0.5) + _punkt(j, 0.5)) - (_innen(i, 0.5) + _punkt(i, 0.5))
		if k == 0 or saeulen[i - SCHRITT + 6] != saeulen[i + 6]:
			_kappe(st, i, zeilen, -weg)
		if k + 1 == n - 1 or saeulen[j + SCHRITT + 6] != saeulen[j + 6]:
			_kappe(st, j, zeilen, weg)
	st.generate_normals()
	var mesh := st.commit()
	if mesh.get_surface_count() == 0:
		return
	if material:
		mesh.surface_set_material(0, material)
	var anzeige := MeshInstance3D.new()
	anzeige.name = "Mesh"
	anzeige.mesh = mesh
	add_child(anzeige)
	if kollision and not Engine.is_editor_hint():
		var koerper := StaticBody3D.new()
		koerper.name = "Kollision"
		var form := CollisionShape3D.new()
		form.shape = mesh.create_trimesh_shape()
		koerper.add_child(form)
		add_child(koerper)


## Seitliche Kappe einer Säule: Fläche zwischen der Felsfront und der Mauerlinie über die ganze Höhe
func _kappe(st: SurfaceTool, i: int, zeilen: int, aussen: Vector3) -> void:
	for z in zeilen:
		var t0 := float(z) / zeilen
		var t1 := float(z + 1) / zeilen
		_viereck(st, _innen(i, t0), _punkt(i, t0), _punkt(i, t1), _innen(i, t1), aussen)


## Punkt auf der Mauerlinie (innen, hinter der Felsfront) bei t
func _innen(i: int, t: float) -> Vector3:
	var y := lerpf(saeulen[i + 4], saeulen[i + 5], t)
	return Vector3(saeulen[i] + saeulen[i + 2] * 0.9, y, saeulen[i + 1] + saeulen[i + 3] * 0.9)


## Punkt an der Mauer (oben, auf der Mauerlinie), dort beginnt die Deckfläche
func _mauer(i: int) -> Vector3:
	return Vector3(saeulen[i] + saeulen[i + 2] * 0.9, saeulen[i + 4], saeulen[i + 1] + saeulen[i + 3] * 0.9)


## Punkt der Felswand in Säule i bei t (0 oben, 1 unten)
func _punkt(i: int, t: float) -> Vector3:
	var x := saeulen[i]
	var z := saeulen[i + 1]
	var nx := saeulen[i + 2]
	var nz := saeulen[i + 3]
	var oben := saeulen[i + 4]
	var y := lerpf(oben, saeulen[i + 5], t)
	var tiefe := oben - y
	# Böschung nach unten, grobe Ausbuchtungen, feine Zerklüftung und Felsbänder mit vorstehenden Absätzen
	var vor := ABSTAND + tiefe * 0.1
	vor += (_grob.get_noise_3d(x, y * 0.6, z) + 0.4) * 1.3          # große Ausbuchtungen
	vor += _rauschen.get_noise_3d(x, y * 1.3, z) * 0.7              # Zerklüftung
	vor -= absf(_rauschen.get_noise_3d(x * 3.0, y * 0.25, z * 3.0)) * 0.9   # senkrechte Risse
	vor += _band(x, y, z)
	if t == 0.0:
		vor = ABSTAND + maxf(0.0, (_grob.get_noise_3d(x, y * 0.6, z) + 0.4) * 1.0)   # oben dicht an der Mauer
	vor = maxf(vor, 1.55)
	var dy := 0.0 if t == 0.0 else _rauschen.get_noise_3d(x + 50.0, y, z) * 0.25
	return Vector3(x + nx * vor, y + dy, z + nz * vor)


## Felsbänder: etwa alle 3 m ein Absatz, der bis 0,7 m vorsteht, nicht überall; die Bänder laufen schräg und unregelmäßig
func _band(x: float, y: float, z: float) -> float:
	var hoehe := 3.2 + _grob.get_noise_2d(x * 0.7, z * 0.7) * 1.2
	var f := fposmod(y + _grob.get_noise_2d(x * 1.3 + 100.0, z * 1.3) * 3.5, hoehe) / hoehe
	var staerke := clampf(0.5 + _grob.get_noise_2d(x * 2.1 + 40.0, z * 2.1) * 1.2, 0.0, 1.0)   # nicht überall ein Absatz
	return (smoothstep(0.75, 0.95, f) * 0.7 - smoothstep(0.0, 0.2, f) * 0.15) * staerke


func _viereck(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, aussen: Vector3) -> void:
	var nrm := (b - a).cross(d - a)
	if nrm.dot(aussen) > 0.0:
		for p in [a, c, b, a, d, c]:
			st.add_vertex(p)
	else:
		for p in [a, b, c, a, c, d]:
			st.add_vertex(p)
