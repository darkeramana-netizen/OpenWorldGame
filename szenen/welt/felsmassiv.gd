@tool
extends Node3D
## Felsmassiv im Burgbezirk (wie im Referenzbild): Der Grund zwischen den Burghöfen, dem Burgweg und der Ringmauer ist
## nackter Fels. Über das Gelände legt sich ein fein aufgelöstes Felsnetz (1 m) aus kantigen Felsbänken: flache Absätze,
## dazwischen fast senkrechte Stufen, die schräg und unregelmäßig laufen, und Klüfte zwischen den Blöcken. Wo der
## Fels hingehört, steht in der Geländemaske (Blau 0,5 = Felsgrund); auf Wegen (Rot) und in den Höfen (Blau 1) taucht
## das Netz unter den Boden, so dass keine Kante zu sehen ist. Der Fels liegt nie unter dem Gelände.

@export var gelaende: NodePath
## Bereich (Welt x, z, Breite, Tiefe), über den das Netz gelegt wird
@export var bereich := Rect2()
@export var material: Material
@export var raster := 1.0
@export var kachel := 32
@export var kollision := true
## Stellen ohne Fels (x, z, Radius), z. B. an den Treppen auf die Mauern
@export var frei := PackedVector3Array()
## Bewuchs auf den flachen Absätzen (wie im Referenzbild: Grasbüschel und Moospolster in Flecken, ab und zu Farn):
## Modelle wie bei felsen.gd ("res://…gltf#n"), je Modell eine Art (0 Gras, 1 Moos, 2 Farn)
@export var bewuchs_modelle := PackedStringArray()
@export var bewuchs_arten := PackedInt32Array()
## Anteil der Absatzfläche (je m²) mit einer Pflanze, in den Flecken
@export var bewuchs_dichte := 0.22

var _g: Node
var _maske: Image
var _m_ursprung := Vector2.ZERO
var _m_groesse := Vector2.ONE
var _band := FastNoiseLite.new()
var _kluft := FastNoiseLite.new()
var _fein := FastNoiseLite.new()
var _block := FastNoiseLite.new()     # Felsblöcke: je Zelle eine Höhe (Zellen entlang des Hangs gestreckt: Rippen)
var _naht := FastNoiseLite.new()      # Zellgrenzen: dort reißt eine Kluft ein
var _flecken := FastNoiseLite.new()   # wo auf den Absätzen etwas wächst
var _zufall := RandomNumberGenerator.new()
var _pflanzen := PackedFloat32Array() # für felsen.gd: Modell, x, y, z, Gier, Neigung, Größe


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_g = get_node_or_null(gelaende)
	if _g == null or bereich.size == Vector2.ZERO:
		return
	var mat: ShaderMaterial = _g.get("material") as ShaderMaterial
	if mat:
		var tex := mat.get_shader_parameter("maske") as Texture2D
		if tex:
			_maske = tex.get_image()
			if _maske and _maske.is_compressed():
				_maske.decompress()
		_m_ursprung = mat.get_shader_parameter("welt_ursprung")
		_m_groesse = mat.get_shader_parameter("welt_groesse")
	if _maske == null:
		return
	_band.seed = 77
	_band.frequency = 0.012
	_kluft.seed = 1234
	_kluft.noise_type = FastNoiseLite.TYPE_CELLULAR
	_kluft.frequency = 0.11
	_kluft.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	_fein.seed = 99
	_fein.frequency = 0.5
	_fein.fractal_octaves = 2
	for z: FastNoiseLite in [_block, _naht]:
		z.seed = 2025
		z.noise_type = FastNoiseLite.TYPE_CELLULAR
		z.frequency = 0.16
		z.cellular_jitter = 1.0
		z.fractal_type = FastNoiseLite.FRACTAL_NONE
	_block.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	_naht.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	_flecken.seed = 515
	_flecken.frequency = 0.07
	_zufall.seed = 8080
	var nx := ceili(bereich.size.x / (kachel * raster))
	var nz := ceili(bereich.size.y / (kachel * raster))
	for kx in nx:
		for kz in nz:
			_baue_kachel(bereich.position + Vector2(kx, kz) * kachel * raster)
	_setze_bewuchs()


## Die Pflanzen als felsen.gd-Kind (MultiMesh je Modell, ohne Kollision, in Kacheln für die Sichtweite)
func _setze_bewuchs() -> void:
	if _pflanzen.is_empty() or bewuchs_modelle.is_empty():
		return
	var f: Node3D = (load("res://szenen/welt/felsen.gd") as GDScript).new()
	f.name = "Bewuchs"
	f.set("farben", PackedColorArray())
	f.set("kachel", 48.0)
	f.set("sichtweite", 260.0)
	var ohne := PackedInt32Array()
	for m in bewuchs_modelle.size():
		ohne.append(m)
	f.set("ohne_kollision", ohne)
	f.set("modelle", bewuchs_modelle)
	f.set("stuecke", _pflanzen)
	add_child(f)


## Auf einem flachen Absatz (Dreieck abc mit nach oben weisender Normale) vielleicht eine Pflanze
func _bewuchs_auf(a: Vector3, b: Vector3, c: Vector3, w: float) -> void:
	if bewuchs_modelle.is_empty() or w < 0.6:
		return
	var n := (b - a).cross(c - a).normalized()
	if absf(n.y) < 0.88:
		return                                   # Stufen und Klüfte bleiben kahl
	var m_ := (a + b + c) / 3.0
	var fleck := _flecken.get_noise_2d(m_.x, m_.z)
	if fleck < 0.05 or _zufall.randf() > bewuchs_dichte * 2.0 * smoothstep(0.05, 0.45, fleck):
		return
	# Stelle im Dreieck
	var r1 := _zufall.randf()
	var r2 := _zufall.randf()
	if r1 + r2 > 1.0:
		r1 = 1.0 - r1
		r2 = 1.0 - r2
	var q := a + (b - a) * r1 + (c - a) * r2
	# Art: Gras am häufigsten, dann Moos, selten Farn
	var wurf := _zufall.randf()
	var art := 0 if wurf < 0.55 else (1 if wurf < 0.9 else 2)
	var wahl: Array[int] = []
	for k in bewuchs_arten.size():
		if bewuchs_arten[k] == art:
			wahl.append(k)
	if wahl.is_empty():
		return
	var modell: int = wahl[_zufall.randi() % wahl.size()]
	var groesse := [_zufall.randf_range(0.7, 1.2), _zufall.randf_range(20.0, 34.0), _zufall.randf_range(0.7, 1.1)][art] as float
	_pflanzen.append_array([modell, q.x, q.y - 0.04, q.z, _zufall.randf_range(0.0, 360.0), 0.0, groesse])


## Wie stark hier Fels ist (0 bis 1): Felsgrund laut Maske, nicht auf Wegen
func _gewicht(x: float, z: float) -> float:
	var u := (Vector2(x, z) - _m_ursprung) / _m_groesse * Vector2(_maske.get_width(), _maske.get_height()) - Vector2(0.5, 0.5)
	var ix := clampi(int(floor(u.x)), 0, _maske.get_width() - 2)
	var iz := clampi(int(floor(u.y)), 0, _maske.get_height() - 2)
	var fx := clampf(u.x - ix, 0.0, 1.0)
	var fz := clampf(u.y - iz, 0.0, 1.0)
	var c := _maske.get_pixel(ix, iz).lerp(_maske.get_pixel(ix + 1, iz), fx).lerp(
		_maske.get_pixel(ix, iz + 1).lerp(_maske.get_pixel(ix + 1, iz + 1), fx), fz)
	var fels := smoothstep(0.3, 0.45, c.b) * (1.0 - smoothstep(0.6, 0.8, c.b))
	# An Löchern im Gelände (Gang zum Untergrundhafen) bleibt der Fels weg, sonst spannt er sich über die Öffnung
	if _g.am_loch(x, z, 4.0):
		return 0.0
	for f in frei:
		if Vector2(x - f.x, z - f.y).length() < f.z:
			return 0.0
	return fels * (1.0 - smoothstep(0.08, 0.35, c.r))


## Höhe der Felsoberfläche (ohne Rand-Überblendung)
func _fels(x: float, z: float, h: float) -> float:
	# Felsbänke: etwa alle 3,4 m eine Stufe; die Stufen laufen schräg (Verwerfung) und unregelmäßig
	var stufe := 3.4 + _band.get_noise_2d(x * 2.0, z * 2.0) * 1.0
	var schief := _band.get_noise_2d(x, z) * stufe * 0.9 + x * 0.03 - z * 0.02
	var b := (h + schief) / stufe
	var f := b - floorf(b)
	# unten in jeder Bank die steile Stufe, darüber der fast flache Absatz (leicht nach außen geneigt)
	var y := (floorf(b) + smoothstep(0.0, 0.1, f) - (1.0 - f) * 0.04) * stufe - schief
	# Klüfte zwischen den Blöcken
	var k := _kluft.get_noise_2d(x, z)
	y -= (1.0 - smoothstep(-0.95, -0.75, k)) * 0.9
	# Kanten und Flächen nicht glatt
	y += _fein.get_noise_2d(x, z) * 0.18
	# Auf steilem Grund (an den Mauern in schmalen Zwingern) würden die Stufen zu schmalen, hohen Zähnen:
	# dort nur flache Stufen und raue Oberfläche
	var gx: float = _g.hoehe_bei(x + 1.0, z) - _g.hoehe_bei(x - 1.0, z)
	var gz: float = _g.hoehe_bei(x, z + 1.0) - _g.hoehe_bei(x, z - 1.0)
	var steil := sqrt(gx * gx + gz * gz) * 0.5
	var staerke := 1.0 - smoothstep(0.35, 0.9, steil)
	y = h + (y - h) * staerke
	# Felsblöcke (wie im Modell des Spielers): Jede Zelle steht verschieden hoch, an den Grenzen reißt der Fels ein. Auf
	# steilem Grund (an den Felswänden unter den Höfen) werden daraus höhere Felszacken.
	var q := Vector2(x, z)
	var blockhoehe := (_block.get_noise_2d(q.x, q.y) + 1.0) * 0.5            # 0 bis 1
	var kluft := 1.0 - smoothstep(-0.97, -0.8, _naht.get_noise_2d(q.x, q.y))  # 1 in der Kluft
	var relief := lerpf(1.3, 2.6, 1.0 - staerke)
	y += blockhoehe * relief - kluft * 0.9 + _fein.get_noise_2d(x * 2.0, z * 2.0) * 0.15
	# nie mehr als 4,5 m über dem Gelände
	return clampf(y, h + 0.05, h + 4.5)


func _punkt(x: float, z: float) -> Vector3:
	var h: float = _g.hoehe_bei(x, z)
	var w := _gewicht(x, z)
	if w <= 0.001:
		return Vector3(x, h - 0.8, z)
	return Vector3(x, lerpf(h - 0.8, _fels(x, z, h), smoothstep(0.0, 0.6, w)), z)


func _baue_kachel(start: Vector2) -> void:
	var n := kachel + 1
	var punkte: Array[Vector3] = []
	var gew := PackedFloat32Array()
	var irgendwo := false
	for iz in n:
		for ix in n:
			var x := start.x + ix * raster
			var z := start.y + iz * raster
			var w := _gewicht(x, z)
			gew.append(w)
			if w > 0.001:
				irgendwo = true
	if not irgendwo:
		return
	for iz in n:
		for ix in n:
			var k := iz * n + ix
			var x := start.x + ix * raster
			var z := start.y + iz * raster
			# nur Punkte in der Nähe von Fels brauchen die genaue Höhe
			var nah := gew[k] > 0.001
			if not nah:
				for d in [[-1, 0], [1, 0], [0, -1], [0, 1], [-1, -1], [1, -1], [-1, 1], [1, 1]]:
					var jx: int = ix + d[0]
					var jz: int = iz + d[1]
					if jx >= 0 and jx < n and jz >= 0 and jz < n and gew[jz * n + jx] > 0.001:
						nah = true
			# auch Punkte ohne Fels liegen auf ihrer echten Höhe (knapp unter dem Gelände), sonst entstehen Spitzen
			punkte.append(_punkt(x, z) if nah else Vector3(x, _g.hoehe_bei(x, z) - 0.8, z))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0xFFFFFFFF)   # kantige Bruchflächen statt weicher Hügel
	var dreiecke := 0
	for iz in kachel:
		for ix in kachel:
			var a := iz * n + ix
			var b := a + 1
			var c := a + n
			var d := c + 1
			if gew[a] <= 0.001 and gew[b] <= 0.001 and gew[c] <= 0.001 and gew[d] <= 0.001:
				continue
			# im Uhrzeigersinn von oben gesehen (Vorderseite nach oben)
			for i in [a, b, d, a, d, c]:
				st.add_vertex(punkte[i])
			dreiecke += 2
			_bewuchs_auf(punkte[a], punkte[b], punkte[d], minf(gew[a], minf(gew[b], gew[d])))
			_bewuchs_auf(punkte[a], punkte[d], punkte[c], minf(gew[a], minf(gew[d], gew[c])))
	if dreiecke == 0:
		return
	st.generate_normals()
	var mesh := st.commit()
	if material:
		mesh.surface_set_material(0, material)
	var anzeige := MeshInstance3D.new()
	anzeige.name = "Fels_%d_%d" % [int(start.x), int(start.y)]
	anzeige.mesh = mesh
	add_child(anzeige)
	if kollision:
		var koerper := StaticBody3D.new()
		var form := CollisionShape3D.new()
		form.shape = mesh.create_trimesh_shape()
		koerper.add_child(form)
		anzeige.add_child(koerper)
