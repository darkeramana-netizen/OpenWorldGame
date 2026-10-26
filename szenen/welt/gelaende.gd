@tool
extends Node3D
## Lädt die Höhendaten (daten/gelaende/ oder der Ordner einer anderen Region) und baut daraus Gelände und Kollision.
## Läuft auch im Editor (@tool), damit man das Gelände beim Bauen sieht.
## Neu erzeugen: werkzeuge/gelaende_erzeugen.gd ausführen.

## Quadrate pro Kachel. Kleinere Kacheln = feineres Ausblenden außerhalb des Blickfelds.
const KACHEL := 64
## Bis zu dieser Höhe reichen die Wände am Rand des Geländes hinunter.
const RAND_UNTEN := -45.0

@export var material: Material
## Ordner mit hoehen.r32 und hoehen.json, für jede Region ein eigener.
@export_dir var daten: String = "res://daten/gelaende/"

var breite: int = 0
var tiefe: int = 0
var abstand: float = 1.0
var ursprung := Vector2.ZERO
var meeresspiegel: float = -20.0
var _hoehen := PackedFloat32Array()


func _ready() -> void:
	add_to_group("gelaende")
	if _lade():
		_baue_kacheln()
		_baue_rand()
		_baue_kollision()


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
	for z in nz:
		for x in nx:
			var a := z * (nx + 1) + x
			var b := a + 1
			var c := a + nx + 1
			var d := c + 1
			indizes.append_array([a, b, c, b, d, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = punkte
	arrays[Mesh.ARRAY_NORMAL] = normalen
	arrays[Mesh.ARRAY_INDEX] = indizes
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


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
	var form := HeightMapShape3D.new()
	form.map_width = breite
	form.map_depth = tiefe
	form.map_data = _hoehen
	var kollision := CollisionShape3D.new()
	kollision.shape = form
	# Die Höhenkarte ist um ihre Mitte zentriert und hat 1 m Rasterabstand.
	kollision.position = Vector3(ursprung.x + groesse().x / 2.0, 0.0, ursprung.y + groesse().y / 2.0)
	kollision.scale = Vector3(abstand, 1.0, abstand)
	koerper.add_child(kollision)
	add_child(koerper)
