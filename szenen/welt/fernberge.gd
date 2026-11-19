extends MeshInstance3D
## Fernberge (Mängelliste M5): Die Gebirgszüge laufen hinter dem Rand der Region weiter bis etwa 3,5 km und werden nach
## außen höher, so dass hinter den nahen Bergen gestaffelte Ketten im Dunst stehen statt des leeren Himmels.
## Die Höhen schreibt der Geländeerzeuger (fernberge.r32, fernberge.json im Ordner des Geländes, Raster 40 m).
## Gezeichnet wird mit dem Material des Geländes (ohne Wege und Pflaster), ohne Kollision und ohne Schatten.
## Rasterpunkte innerhalb der Region rücken auf ihren Rand und tragen dort die Höhe des Geländes; die Randwände des
## Geländes (gelaende.gd, RAND_UNTEN) decken die feinen Unterschiede zwischen beiden Rastern ab.

@export var gelaende: NodePath
## Die Fernberge am Rand der Region um so viel tiefer legen (unter die Kante des Geländes)
const RAND_TIEFER := 1.5
## Ganz unter Wasser: nicht zeichnen
const UNTER_WASSER := -23.0


func _ready() -> void:
	var g := get_node_or_null(gelaende)
	if g == null:
		return
	var ordner: String = g.daten
	if not FileAccess.file_exists(ordner + "fernberge.json"):
		return
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ordner + "fernberge.json"))
	var nx := int(info["breite"])
	var nz := int(info["tiefe"])
	var ab := float(info["abstand"])
	var anfang := Vector2(info["ursprung_x"], info["ursprung_z"])
	var i: Array = info["innen"]
	var innen := Rect2(Vector2(i[0], i[1]), Vector2(float(i[2]) - float(i[0]), float(i[3]) - float(i[1])))
	var hoehen := FileAccess.get_file_as_bytes(ordner + "fernberge.r32").to_float32_array()
	if hoehen.size() != nx * nz:
		return
	mesh = _baue(nx, nz, ab, anfang, innen, hoehen)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := (g.material as ShaderMaterial)
	if mat != null:
		mat = mat.duplicate()
		var schwarz := Image.create(1, 1, false, Image.FORMAT_RGB8)
		mat.set_shader_parameter("maske", ImageTexture.create_from_image(schwarz))
		material_override = mat


func _baue(nx: int, nz: int, ab: float, anfang: Vector2, innen: Rect2, h: PackedFloat32Array) -> ArrayMesh:
	var punkte := PackedVector3Array()
	punkte.resize(nx * nz)
	var drin := PackedByteArray()
	drin.resize(nx * nz)
	for z in nz:
		for x in nx:
			var k := z * nx + x
			var p := anfang + Vector2(x, z) * ab
			var y := h[k]
			if innen.has_point(p):
				drin[k] = 1
				p = _auf_rand(p, innen)
				y -= RAND_TIEFER
			punkte[k] = Vector3(p.x, y, p.y)
	var normalen := PackedVector3Array()
	normalen.resize(nx * nz)
	for z in nz:
		for x in nx:
			var hx := h[z * nx + mini(x + 1, nx - 1)] - h[z * nx + maxi(x - 1, 0)]
			var hz := h[mini(z + 1, nz - 1) * nx + x] - h[maxi(z - 1, 0) * nx + x]
			normalen[z * nx + x] = Vector3(-hx, 2.0 * ab, -hz).normalized()
	var indizes := PackedInt32Array()
	for z in nz - 1:
		for x in nx - 1:
			var a := z * nx + x
			var b := a + 1
			var c := a + nx
			var d := c + 1
			if drin[a] and drin[b] and drin[c] and drin[d]:
				continue
			if maxf(maxf(h[a], h[b]), maxf(h[c], h[d])) < UNTER_WASSER:
				continue
			indizes.append_array([a, b, c, b, d, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = punkte
	arrays[Mesh.ARRAY_NORMAL] = normalen
	arrays[Mesh.ARRAY_INDEX] = indizes
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


static func _auf_rand(p: Vector2, r: Rect2) -> Vector2:
	var links := p.x - r.position.x
	var rechts := r.end.x - p.x
	var oben := p.y - r.position.y
	var unten := r.end.y - p.y
	var m := minf(minf(links, rechts), minf(oben, unten))
	if m == links:
		return Vector2(r.position.x, p.y)
	if m == rechts:
		return Vector2(r.end.x, p.y)
	if m == oben:
		return Vector2(p.x, r.position.y)
	return Vector2(p.x, r.end.y)
