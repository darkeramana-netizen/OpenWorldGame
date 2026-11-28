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
## Größe der Felsformen: 1 unter den Hofmauern, größer an der hohen Küste (Bänder, Ausbuchtungen und Risse wachsen mit)
@export var massstab := 1.0:
	set(w):
		massstab = w
		if is_inside_tree():
			_baue()

## Fels-Haut aus Fotoscans (Mängelliste M17): Felswand-Stücke liegen in Reihen übereinander vor der Wand und verdecken
## deren glatte Flächen. Modelle wie bei felsen.gd, Front nach lokal +z; je Modell Breite, Höhe und wie weit die Front
## vor dem Ursprung liegt (Meter), dazu eine Tönung. Leer: keine Haut.
@export var haut_modelle := PackedStringArray()
@export var haut_masse := PackedVector3Array()
@export var haut_farben := PackedColorArray()

const SCHRITT := 7
const ZEILE := 0.7          # Höhe einer Zeile im Gitter (Meter)
const ABSTAND := 1.6        # so weit steht die Wand oben vor der Mauerlinie (die Mauer ist 3 m dick)

var _rauschen := FastNoiseLite.new()
var _grob := FastNoiseLite.new()
var _bloecke := FastNoiseLite.new()     # Felsblöcke: je Zelle ein Wert, die Zellen hoch und schmal (Klüfte senkrecht)
var _klueft := FastNoiseLite.new()      # Abstand zur nächsten Zellgrenze: dort reißt der Fels tief ein


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
	for zelle: FastNoiseLite in [_bloecke, _klueft]:
		zelle.seed = 4242
		zelle.noise_type = FastNoiseLite.TYPE_CELLULAR
		zelle.frequency = 0.22
		zelle.cellular_jitter = 0.9
		zelle.fractal_type = FastNoiseLite.FRACTAL_NONE
	_bloecke.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	_klueft.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0xFFFFFFFF)   # Flächen nicht glätten: kantige Bruchflächen wie gespaltener Fels
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
	_baue_haut(n)


## Die Fels-Haut als felsen.gd-Kind: an jeder zweiten Säule eines Abschnitts Stücke von unten nach oben gestapelt, die
## Front knapp vor der Wand; das oberste endet unter der Hofkante, an den Enden eines Abschnitts (Tore, Wege) bleibt frei.
func _baue_haut(n: int) -> void:
	if haut_modelle.is_empty() or haut_masse.size() < haut_modelle.size():
		return
	var zufall := RandomNumberGenerator.new()
	zufall.seed = 9090
	var stuecke := PackedFloat32Array()
	for k in range(2, n - 2, 2):
		var i := k * SCHRITT
		var abschnitt := saeulen[i + 6]
		if saeulen[i - 2 * SCHRITT + 6] != abschnitt or saeulen[i + 2 * SCHRITT + 6] != abschnitt:
			continue
		var oben := saeulen[i + 4]
		var unten := saeulen[i + 5]
		if oben - unten < 2.0:
			continue
		var nx := saeulen[i + 2]
		var nz := saeulen[i + 3]
		var gier := rad_to_deg(atan2(nx, nz))
		var y := unten
		while y < oben - 0.8:
			var m := zufall.randi() % haut_modelle.size()
			var mass: Vector3 = haut_masse[m]
			var groesse := zufall.randf_range(1.0, 1.35) * 3.2 / mass.x      # etwa 3,2 bis 4,3 m breit
			# nicht über die Hofkante
			groesse = minf(groesse, (oben - 0.15 - y) / mass.y)
			if groesse * mass.y < 0.8:
				break
			var t := clampf((oben - (y + mass.y * groesse * 0.5)) / maxf(oben - unten, 0.01), 0.0, 1.0)
			var wand := _punkt(i, t)
			# Front 0,2 m vor der mittleren Wandfläche (ohne die Blöcke der erzeugten Wand)
			var vor := ABSTAND + (oben - (y + mass.y * groesse * 0.5)) * 0.1 + 0.2 - mass.z * groesse
			stuecke.append_array([m, saeulen[i] + nx * vor, y, saeulen[i + 1] + nz * vor,
				gier + zufall.randf_range(-10.0, 10.0), zufall.randf_range(-4.0, 8.0), groesse])
			y += mass.y * groesse * 0.8
			if wand.y < unten:
				break
	if stuecke.is_empty():
		return
	var f: Node3D = (load("res://szenen/welt/felsen.gd") as GDScript).new()
	f.name = "Haut"
	f.set("farben", haut_farben)
	f.set("sichtweite", 600.0)
	f.set("modelle", haut_modelle)
	f.set("stuecke", stuecke)
	add_child(f)


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
	# Rauschen im Maßstab der Felsformen
	var m := massstab
	var rx := x / m
	var ry := y / m
	var rz := z / m
	# Böschung nach unten, dann gespaltener Fels: hohe, schmale Blöcke stehen verschieden weit vor, an ihren Grenzen
	# reißen tiefe senkrechte Klüfte ein; dazu Felsbänder mit vorstehenden Absätzen und eine feine Oberfläche
	var vor := ABSTAND + tiefe * 0.1
	# Hohe Küstenwände (Maßstab über 1): Der Fuß tritt weit vor (Schuttfuß einer Klippe) und entlang der Wand wechseln
	# vorspringende Felsrippen mit Buchten, unter der Hofkante beginnend. Vorher fast senkrecht: aus der Ferne ein
	# grauer Kasten unter der Burg (Fernsicht 28.11.2026)
	if m > 1.0:
		var unten_anteil := clampf(tiefe / maxf(oben - saeulen[i + 5], 1.0), 0.0, 1.0)
		vor += tiefe * 0.16 * unten_anteil
		vor += (_grob.get_noise_2d(rx * 0.35 + 77.0, rz * 0.35) + 0.25) * 2.2 * m * smoothstep(0.05, 0.35, t)
	vor += (_grob.get_noise_3d(rx, ry * 0.6, rz) + 0.4) * 0.6 * m          # große Ausbuchtungen
	vor += (_bloecke.get_noise_3d(rx, ry * 0.3, rz) + 0.3) * 1.5 * m       # Blöcke
	var naht := _klueft.get_noise_3d(rx, ry * 0.3, rz)                      # klein an den Zellgrenzen
	vor -= (1.0 - smoothstep(-0.98, -0.82, naht)) * 1.6 * m                 # tiefe Klüfte zwischen den Blöcken
	vor += _rauschen.get_noise_3d(x * 1.1, y * 1.4, z * 1.1) * 0.3         # feine Oberfläche (immer klein)
	vor -= absf(_rauschen.get_noise_3d(rx * 3.0, ry * 0.25, rz * 3.0)) * 0.5 * m   # feine senkrechte Risse
	vor += _band(rx, ry, rz) * m
	if t == 0.0:
		vor = ABSTAND + maxf(0.0, (_grob.get_noise_3d(rx, ry * 0.6, rz) + 0.4) * 1.0)   # oben dicht an der Mauer
	vor = maxf(vor, 1.55)
	var dy := 0.0 if t == 0.0 else _rauschen.get_noise_3d(rx + 50.0, ry, rz) * 0.25 * m
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
