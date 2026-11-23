extends RefCounted
## Verdecker für Godots Verdeckungsprüfung (Occlusion Culling): Was hinter Mauern und Häusern liegt, wird nicht
## gezeichnet. Ein Verdecker ist eine schlichte, etwas zu kleine Form innerhalb eines dichten Baus (ohne Dach, Zinnen,
## Fenster): Er darf nie mehr verdecken als der Bau selbst, sonst verschwinden sichtbare Dinge.
## Alle Quader eines Baus kommen in einen ArrayOccluder3D (ein Knoten je Bau).

## Quader hinzufügen: t ist die Lage der Quadermitte, halb die halben Kantenlängen
static func quader(ecken: PackedVector3Array, dreiecke: PackedInt32Array, t: Transform3D, halb: Vector3) -> void:
	if halb.x <= 0.05 or halb.y <= 0.05 or halb.z <= 0.05:
		return
	var b := ecken.size()
	for i in 8:
		ecken.append(t * Vector3(halb.x if i & 1 else -halb.x, halb.y if i & 2 else -halb.y, halb.z if i & 4 else -halb.z))
	# sechs Seiten je zwei Dreiecke
	for s: Array in [[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5]]:
		dreiecke.append_array([b + s[0], b + s[1], b + s[2], b + s[0], b + s[2], b + s[3]])


## Ein Verdeckerknoten aus den gesammelten Quadern (oder null, wenn keiner da ist)
static func knoten(ecken: PackedVector3Array, dreiecke: PackedInt32Array) -> OccluderInstance3D:
	if dreiecke.is_empty():
		return null
	var o := ArrayOccluder3D.new()
	o.set_arrays(ecken, dreiecke)
	var k := OccluderInstance3D.new()
	k.name = "Verdecker"
	k.occluder = o
	return k


## Mauerstück von a nach b (x, z), Fuß unten, Wehrgang oben, Dicke; luecken sind Bereiche entlang der Mauer
## (Abstand von a in m: [von, bis]), die frei bleiben (Tore, Türme)
static func mauer(ecken: PackedVector3Array, dreiecke: PackedInt32Array, a: Vector2, b: Vector2, unten: float,
		oben: float, dicke: float, luecken: Array) -> void:
	var laenge := a.distance_to(b)
	if laenge < 1.0:
		return
	var u := (b - a) / laenge
	var stuecke: Array = [[0.0, laenge]]
	for l: Array in luecken:
		var neu: Array = []
		for s: Array in stuecke:
			if l[1] <= s[0] or l[0] >= s[1]:
				neu.append(s)
				continue
			if l[0] > s[0]:
				neu.append([s[0], l[0]])
			if l[1] < s[1]:
				neu.append([l[1], s[1]])
		stuecke = neu
	var hoch := oben - unten - 0.15          # knapp unter dem Wehrgang
	var halbe_dicke := dicke * 0.5 - 0.1     # etwas innerhalb der Mauerflächen
	for s: Array in stuecke:
		var von: float = s[0] + 0.15
		var bis: float = s[1] - 0.15
		if bis - von < 0.8:
			continue
		var mitte := a + u * (von + bis) * 0.5
		var basis := Basis(Vector3(u.x, 0, u.y), Vector3.UP, Vector3(-u.y, 0, u.x))
		var t := Transform3D(basis, Vector3(mitte.x, unten + hoch * 0.5, mitte.y))
		quader(ecken, dreiecke, t, Vector3((bis - von) * 0.5, hoch * 0.5, halbe_dicke))
