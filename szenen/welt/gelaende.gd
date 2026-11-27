@tool
extends Node3D
## Lädt die Höhendaten (daten/gelaende/ oder der Ordner einer anderen Region) und baut daraus Gelände und Kollision.
## Läuft auch im Editor (@tool), damit man das Gelände beim Bauen sieht.
## Neu erzeugen: werkzeuge/gelaende_erzeugen.gd ausführen.

## Quadrate pro Kachel. Kleinere Kacheln = feineres Ausblenden außerhalb des Blickfelds.
const KACHEL := 64
## Bis zu dieser Höhe reichen die Wände am Rand des Geländes hinunter.
const RAND_UNTEN := -45.0
## Rasterpunkte je Zelle des Verdeckers (2,5 m Abstand: 20 m)
const VERDECKER_SCHRITT := 8
const Verdecker := preload("res://szenen/welt/verdecker.gd")
const Terrain3DBau := preload("res://szenen/welt/gelaende_terrain3d.gd")

@export var material: Material
## Ordner mit hoehen.r32 und hoehen.json, für jede Region ein eigener.
@export_dir var daten: String = "res://daten/gelaende/"
## Löcher im Gelände, je Rechteck x0, z0, x1, z1 (Welt): Rasterpunkte darin bekommen weder Fläche noch Kollision,
## z. B. wo ein Tunnel durch einen Steilhang in den Berg führt (darüber und darunter bleibt das Gelände).
@export var loecher := PackedVector4Array()
## Genaue Schnitte (Abgänge in den Untergrund, szenen/welt/unterwelt.gd): je gedrehtes Rechteck 5 Werte x, z (Mitte),
## Gier (Grad), halbe Länge (lokal z), halbe Breite (lokal x). Die Dreiecke werden genau an den Kanten beschnitten
## (Fläche und Kollision); ein Loch über Rasterpunkte (2,5 m) wäre für ein Treppenhäuschen viel zu grob.
@export var schnitte := PackedFloat32Array()
## Wer die Fläche zeichnet: "eigen" (Kacheln aus diesem Skript) oder "terrain3d" (addons/terrain_3d: feines Gitter
## um die Kamera, nach außen gröber). Kollision, hoehe_bei() und Löcher sind in beiden Fällen dieselben.
## Startargumente --terrain3d und --eigenes-gelaende gehen vor (für Vergleichsmessungen).
@export_enum("eigen", "terrain3d") var darstellung := "eigen"
## Gilt für alle Gelände, wenn gesetzt ("eigen" oder "terrain3d"), z. B. in Tests
static var darstellung_vorgabe := ""

var breite: int = 0
var tiefe: int = 0
var abstand: float = 1.0
var ursprung := Vector2.ZERO
var meeresspiegel: float = -20.0
var _hoehen := PackedFloat32Array()
var _loch := PackedByteArray()   # je Rasterpunkt 1 = Loch


func _ready() -> void:
	add_to_group("gelaende")
	if _lade():
		_setze_hoehen_global()
		_markiere_loecher()
		if mit_terrain3d() and not Engine.is_editor_hint():
			if Terrain3DBau.baue(self) == null:
				_baue_kacheln()
		else:
			_baue_kacheln()
		_baue_rand()
		_baue_kollision()
		if not Engine.is_editor_hint() and OS.get_environment("GELAENDE_VERDECKER_AUS") == "":
			_baue_verdecker()


## Höhe des Geländes an einer Weltposition (bilinear). Außerhalb: Rand.
func hoehe_bei(x: float, z: float) -> float:
	if _hoehen.is_empty():
		return 0.0
	var gx := clampf((x - ursprung.x) / abstand, 0.0, breite - 1.001)
	var gz := clampf((z - ursprung.y) / abstand, 0.0, tiefe - 1.001)
	var ix := int(gx)
	var iz := int(gz)
	var fx := gx - ix
	var fz := gz - iz
	var h00 := _h(ix, iz)
	var h10 := _h(ix + 1, iz)
	var h01 := _h(ix, iz + 1)
	var h11 := _h(ix + 1, iz + 1)
	return lerpf(lerpf(h00, h10, fx), lerpf(h01, h11, fx), fz)


## Liegt (x, z) an einem Loch? Strahlen dorthin liefern bei Jolt keine gültige Normale.
func am_loch(x: float, z: float, rand: float = 3.0) -> bool:
	for r: Vector4 in loecher:
		if x > r.x - rand and x < r.z + rand and z > r.y - rand and z < r.w + rand:
			return true
	for sch: Array in _schnitt_ecken():
		var gr: Rect2 = sch[2]
		if gr.grow(rand).has_point(Vector2(x, z)):
			return true
	return false


var _schnitte_cache: Array = []
## Je Schnitt [Ecken (Vector2, Welt x/z), Mitte, Rahmen (Rect2)]
func _schnitt_ecken() -> Array:
	if _schnitte_cache.size() * 5 == schnitte.size() and (not _schnitte_cache.is_empty() or schnitte.is_empty()):
		return _schnitte_cache
	_schnitte_cache = []
	var i := 0
	while i + 4 < schnitte.size():
		var g := deg_to_rad(schnitte[i + 2])
		var u := Vector2(sin(g), cos(g)) * schnitte[i + 3]
		var n := Vector2(cos(g), -sin(g)) * schnitte[i + 4]
		var m := Vector2(schnitte[i], schnitte[i + 1])
		var ecken: Array[Vector2] = [m - u - n, m + u - n, m + u + n, m - u + n]
		var rahmen := Rect2(ecken[0], Vector2.ZERO)
		for e in ecken:
			rahmen = rahmen.expand(e)
		_schnitte_cache.append([ecken, m, rahmen])
		i += 5
	return _schnitte_cache


## Teile eines Dreiecks (Punkte mit Normalen) außerhalb der Schnitte: Liste von Polygonen [[Punkt, Normale], ...]
func _ausschneiden(dreieck: Array, schnitte_: Array) -> Array:
	var stuecke: Array = [dreieck]
	for sch: Array in schnitte_:
		var ecken: Array[Vector2] = sch[0]
		var mitte: Vector2 = sch[1]
		var neu: Array = []
		for poly: Array in stuecke:
			var rest: Array = poly
			for k in 4:
				var a := ecken[k]
				var b := ecken[(k + 1) % 4]
				var innen_seite := signf((b - a).cross(mitte - a))
				var aussen := _halbebene(rest, a, b, -innen_seite)
				if aussen.size() >= 3:
					neu.append(aussen)
				rest = _halbebene(rest, a, b, innen_seite)
				if rest.size() < 3:
					break
		stuecke = neu
	return stuecke


## Sutherland-Hodgman: der Teil eines Polygons auf der Seite vorzeichen der Geraden a→b (in x/z)
static func _halbebene(poly: Array, a: Vector2, b: Vector2, vorzeichen: float) -> Array:
	var aus: Array = []
	var n := poly.size()
	for i in n:
		var p: Array = poly[i]
		var q: Array = poly[(i + 1) % n]
		var pp: Vector3 = p[0]
		var qq: Vector3 = q[0]
		var dp := (b - a).cross(Vector2(pp.x, pp.z) - a) * vorzeichen
		var dq := (b - a).cross(Vector2(qq.x, qq.z) - a) * vorzeichen
		if dp >= 0.0:
			aus.append(p)
		if (dp >= 0.0) != (dq >= 0.0):
			var t := dp / (dp - dq)
			aus.append([pp.lerp(qq, t), (p[1] as Vector3).lerp(q[1] as Vector3, t).normalized()])
	return aus


## Ob die Fläche von Terrain3D gezeichnet wird (Einstellung oder Startargument)
func mit_terrain3d() -> bool:
	var args := OS.get_cmdline_user_args()
	if darstellung_vorgabe != "":
		return darstellung_vorgabe == "terrain3d"
	if "--eigenes-gelaende" in args:
		return false
	return darstellung == "terrain3d" or "--terrain3d" in args


func groesse() -> Vector2:
	return Vector2((breite - 1) * abstand, (tiefe - 1) * abstand)


func _h(ix: int, iz: int) -> float:
	return _hoehen[iz * breite + ix]


func _lade() -> bool:
	var info: Variant = JSON.parse_string(FileAccess.get_file_as_string(daten.path_join("hoehen.json")))
	if not info is Dictionary:
		push_error("Geländedaten fehlen. Bitte werkzeuge/gelaende_erzeugen.gd ausführen.")
		return false
	breite = int(info["breite"])
	tiefe = int(info["tiefe"])
	abstand = float(info["abstand"])
	ursprung = Vector2(info["ursprung_x"], info["ursprung_z"])
	meeresspiegel = float(info["meeresspiegel"])
	_hoehen = FileAccess.get_file_as_bytes(daten.path_join("hoehen.r32")).to_float32_array()
	return _hoehen.size() == breite * tiefe


## Die Höhen als Textur für die Shader (stein.gdshader: Feuchte am Mauerfuß über dem Gelände).
func _setze_hoehen_global() -> void:
	var bild := Image.create_from_data(breite, tiefe, false, Image.FORMAT_RF, _hoehen.to_byte_array())
	RenderingServer.global_shader_parameter_set("gelaende_hoehe", ImageTexture.create_from_image(bild))
	RenderingServer.global_shader_parameter_set("gelaende_rahmen",
		Vector4(ursprung.x, ursprung.y, (breite - 1) * abstand, (tiefe - 1) * abstand))


func _markiere_loecher() -> void:
	_loch = PackedByteArray()
	_loch.resize(breite * tiefe)
	for r: Vector4 in loecher:
		for iz in range(maxi(ceili((r.y - ursprung.y) / abstand), 0), mini(floori((r.w - ursprung.y) / abstand), tiefe - 1) + 1):
			for ix in range(maxi(ceili((r.x - ursprung.x) / abstand), 0), mini(floori((r.z - ursprung.x) / abstand), breite - 1) + 1):
				_loch[iz * breite + ix] = 1


func _baue_kacheln() -> void:
	for kz in range(0, tiefe - 1, KACHEL):
		for kx in range(0, breite - 1, KACHEL):
			var kachel := MeshInstance3D.new()
			kachel.name = "Kachel_%d_%d" % [kx / KACHEL, kz / KACHEL]
			kachel.mesh = _kachel_mesh(kx, kz, mini(KACHEL, breite - 1 - kx), mini(KACHEL, tiefe - 1 - kz))
			kachel.material_override = material
			add_child(kachel)


func _kachel_mesh(x0: int, z0: int, nx: int, nz: int) -> ArrayMesh:
	var punkte := PackedVector3Array()
	var normalen := PackedVector3Array()
	var indizes := PackedInt32Array()
	punkte.resize((nx + 1) * (nz + 1))
	normalen.resize(punkte.size())
	var i := 0
	for z in range(z0, z0 + nz + 1):
		for x in range(x0, x0 + nx + 1):
			punkte[i] = Vector3(ursprung.x + x * abstand, _h(x, z), ursprung.y + z * abstand)
			# Normale aus den Nachbarhöhen.
			var hl := _h(maxi(x - 1, 0), z)
			var hr := _h(mini(x + 1, breite - 1), z)
			var hu := _h(x, maxi(z - 1, 0))
			var hd := _h(x, mini(z + 1, tiefe - 1))
			normalen[i] = Vector3(hl - hr, 2.0 * abstand, hu - hd).normalized()
			i += 1
	var schnitte_hier: Array = []
	var kachel_rahmen := Rect2(ursprung.x + x0 * abstand, ursprung.y + z0 * abstand, nx * abstand, nz * abstand)
	for sch: Array in _schnitt_ecken():
		if (sch[2] as Rect2).intersects(kachel_rahmen):
			schnitte_hier.append(sch)
	for z in nz:
		for x in nx:
			var a := z * (nx + 1) + x
			var b := a + 1
			var c := a + nx + 1
			var d := c + 1
			# Dreiecke an einem Lochpunkt fallen weg (wie in der Kollision)
			var la := _loch[(z0 + z) * breite + x0 + x] == 1
			var lb := _loch[(z0 + z) * breite + x0 + x + 1] == 1
			var lc := _loch[(z0 + z + 1) * breite + x0 + x] == 1
			var ld := _loch[(z0 + z + 1) * breite + x0 + x + 1] == 1
			for dr: Array in ([[a, b, c]] if not (la or lb or lc) else []) + ([[b, d, c]] if not (lb or ld or lc) else []):
				var teile: Variant = _dreieck_mit_schnitt(punkte, normalen, dr, schnitte_hier)
				if teile == null:
					indizes.append_array(dr)
					continue
				for poly: Array in teile:
					var start := punkte.size()
					for pn: Array in poly:
						punkte.append(pn[0])
						normalen.append(pn[1])
					for k in range(1, poly.size() - 1):
						indizes.append_array([start, start + k, start + k + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = punkte
	arrays[Mesh.ARRAY_NORMAL] = normalen
	arrays[Mesh.ARRAY_INDEX] = indizes
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Teile eines Dreiecks (Indizes) außerhalb der Schnitte als Polygone [[Punkt, Normale], ...]; null: unberührt
func _dreieck_mit_schnitt(punkte: PackedVector3Array, normalen: PackedVector3Array, ecken: Array, schnitte_hier: Array) -> Variant:
	if schnitte_hier.is_empty():
		return null
	var rahmen := Rect2(Vector2(punkte[ecken[0]].x, punkte[ecken[0]].z), Vector2.ZERO)
	for e: int in ecken:
		rahmen = rahmen.expand(Vector2(punkte[e].x, punkte[e].z))
	var betroffen: Array = []
	for sch: Array in schnitte_hier:
		if (sch[2] as Rect2).intersects(rahmen):
			betroffen.append(sch)
	if betroffen.is_empty():
		return null
	var dreieck: Array = []
	for e: int in ecken:
		dreieck.append([punkte[e], normalen[e]])
	return _ausschneiden(dreieck, betroffen)


## Senkrechte Wände an den Rändern, damit das Gelände von außen nicht hohl wirkt.
func _baue_rand() -> void:
	var punkte := PackedVector3Array()
	var raender: Array[Array] = [
		range(breite).map(func(x: int) -> Vector2i: return Vector2i(x, 0)),
		range(breite).map(func(x: int) -> Vector2i: return Vector2i(x, tiefe - 1)),
		range(tiefe).map(func(z: int) -> Vector2i: return Vector2i(0, z)),
		range(tiefe).map(func(z: int) -> Vector2i: return Vector2i(breite - 1, z)),
	]
	for rand in raender:
		for i in rand.size() - 1:
			var a := _punkt(rand[i])
			var b := _punkt(rand[i + 1])
			var a_unten := Vector3(a.x, RAND_UNTEN, a.z)
			var b_unten := Vector3(b.x, RAND_UNTEN, b.z)
			# Beide Seiten, damit die Wand von außen und innen sichtbar ist.
			punkte.append_array([a, b, a_unten, b, b_unten, a_unten, a, a_unten, b, b, a_unten, b_unten])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = punkte
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var rand := MeshInstance3D.new()
	rand.name = "Rand"
	rand.mesh = mesh
	var material_rand := StandardMaterial3D.new()
	material_rand.albedo_color = Color(0.3, 0.29, 0.28)
	rand.material_override = material_rand
	add_child(rand)


func _punkt(gitter: Vector2i) -> Vector3:
	return Vector3(ursprung.x + gitter.x * abstand, _h(gitter.x, gitter.y), ursprung.y + gitter.y * abstand)


func _baue_kollision() -> void:
	var koerper := StaticBody3D.new()
	koerper.name = "Kollision"
	add_child(koerper)
	if loecher.is_empty() and schnitte.is_empty():
		_hoehenform(koerper, 0, 0, breite - 1, tiefe - 1)
		return
	# Mit Löchern: je Kachel eine Höhenkarte, nur Kacheln mit Loch werden Dreiecksformen ohne die Lochdreiecke
	# (NAN in der Höhenkarte gäbe bei Jolt ungültige Kontaktnormalen).
	for kz in range(0, tiefe - 1, KACHEL):
		for kx in range(0, breite - 1, KACHEL):
			var nx := mini(KACHEL, breite - 1 - kx)
			var nz := mini(KACHEL, tiefe - 1 - kz)
			if _hat_loch(kx, kz, nx, nz):
				var form := ConcavePolygonShape3D.new()
				form.set_faces(_kachel_mesh(kx, kz, nx, nz).get_faces())
				var kollision := CollisionShape3D.new()
				kollision.shape = form
				koerper.add_child(kollision)
			else:
				_hoehenform(koerper, kx, kz, nx, nz)


func _hat_loch(x0: int, z0: int, nx: int, nz: int) -> bool:
	var kachel_rahmen := Rect2(ursprung.x + x0 * abstand, ursprung.y + z0 * abstand, nx * abstand, nz * abstand)
	for sch: Array in _schnitt_ecken():
		if (sch[2] as Rect2).intersects(kachel_rahmen):
			return true
	for z in range(z0, z0 + nz + 1):
		for x in range(x0, x0 + nx + 1):
			if _loch[z * breite + x] == 1:
				return true
	return false


## Höhenkarte über nx × nz Quadrate ab Rasterpunkt (x0, z0)
func _hoehenform(koerper: StaticBody3D, x0: int, z0: int, nx: int, nz: int) -> void:
	var form := HeightMapShape3D.new()
	form.map_width = nx + 1
	form.map_depth = nz + 1
	var daten_ := PackedFloat32Array()
	daten_.resize((nx + 1) * (nz + 1))
	for z in nz + 1:
		for x in nx + 1:
			daten_[z * (nx + 1) + x] = _h(x0 + x, z0 + z)
	form.map_data = daten_
	var kollision := CollisionShape3D.new()
	kollision.shape = form
	# Die Höhenkarte ist um ihre Mitte zentriert; das Raster wird mit dem Abstand skaliert.
	kollision.position = Vector3(ursprung.x + (x0 + nx / 2.0) * abstand, 0.0, ursprung.y + (z0 + nz / 2.0) * abstand)
	kollision.scale = Vector3(abstand, 1.0, abstand)
	koerper.add_child(kollision)


## Verdecker für die Verdeckungsprüfung (szenen/welt/verdecker.gd): Hügel und Hänge verdecken, was dahinter liegt.
## Ein grobes Gitter (VERDECKER_SCHRITT), jeder Gitterpunkt auf der tiefsten Höhe der angrenzenden Zellen und 0,3 m
## darunter: Jedes Dreieck bleibt so überall unter der Geländefläche und verdeckt nie mehr als das Gelände selbst.
## Zellen mit Loch (Tunnel) bleiben frei. Ein Verdecker je Kachel.
func _baue_verdecker() -> void:
	var s := VERDECKER_SCHRITT
	var zx := ceili(float(breite - 1) / s)
	var zz := ceili(float(tiefe - 1) / s)
	# tiefste Höhe je Zelle (NAN: Zelle mit Loch)
	var zelle := PackedFloat32Array()
	zelle.resize(zx * zz)
	for cz in zz:
		var z1 := mini((cz + 1) * s, tiefe - 1)
		for cx in zx:
			var x1 := mini((cx + 1) * s, breite - 1)
			var tief := INF
			var loch := false
			for z in range(cz * s, z1 + 1):
				var zeile := z * breite
				for x in range(cx * s, x1 + 1):
					tief = minf(tief, _hoehen[zeile + x])
					if _loch[zeile + x] == 1:
						loch = true
			if not loch and not schnitte.is_empty():
				var zr := Rect2(ursprung.x + cx * s * abstand, ursprung.y + cz * s * abstand, s * abstand, s * abstand)
				for sch: Array in _schnitt_ecken():
					if (sch[2] as Rect2).intersects(zr):
						loch = true
			zelle[cz * zx + cx] = NAN if loch else tief
	# Gitterpunkte: tiefste der bis zu vier angrenzenden Zellen
	var punkt := PackedFloat32Array()
	punkt.resize((zx + 1) * (zz + 1))
	for pz in zz + 1:
		for px in zx + 1:
			var tief := INF
			for dz in [-1, 0]:
				for dx in [-1, 0]:
					var cx: int = px + dx
					var cz: int = pz + dz
					if cx >= 0 and cz >= 0 and cx < zx and cz < zz and not is_nan(zelle[cz * zx + cx]):
						tief = minf(tief, zelle[cz * zx + cx])
			punkt[pz * (zx + 1) + px] = tief - 0.3
	var je := maxi(1, KACHEL / s)   # Zellen je Kachel und Richtung
	for kz in range(0, zz, je):
		for kx in range(0, zx, je):
			var ecken := PackedVector3Array()
			var dreiecke := PackedInt32Array()
			var nummer := {}
			for cz in range(kz, mini(kz + je, zz)):
				for cx in range(kx, mini(kx + je, zx)):
					if is_nan(zelle[cz * zx + cx]):
						continue
					var ids: Array[int] = []
					for e: Vector2i in [Vector2i(cx, cz), Vector2i(cx + 1, cz), Vector2i(cx, cz + 1), Vector2i(cx + 1, cz + 1)]:
						if not nummer.has(e):
							nummer[e] = ecken.size()
							ecken.append(Vector3(ursprung.x + mini(e.x * s, breite - 1) * abstand,
									punkt[e.y * (zx + 1) + e.x],
									ursprung.y + mini(e.y * s, tiefe - 1) * abstand))
						ids.append(nummer[e])
					dreiecke.append_array([ids[0], ids[1], ids[2], ids[1], ids[3], ids[2]])
			var k := Verdecker.knoten(ecken, dreiecke)
			if k != null:
				k.name = "Verdecker_%d_%d" % [kx / je, kz / je]
				add_child(k)
