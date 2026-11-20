## Formen für die kleinen Vögel (tauben.gd, moewen.gd), statt Quadern (Mängelliste M15): Körper und Kopf als
## Ellipsoid, der Schnabel als Kegel nach vorn (-z), Flügel, Flügelspitzen und Schwanz als flache Federflächen mit
## schmalen Enden, Beine als dünne Zylinder. Jede Form füllt dasselbe Maß aus wie der Quader vorher, so bleiben
## Anordnung und Bewegung der Teile gleich.
extends RefCounted


static func form(art: String, mass: Vector3) -> Mesh:
	match art:
		"koerper", "kopf":
			return _ellipsoid(mass)
		"schnabel":
			return _kegel(mass)
		"bein":
			var z := CylinderMesh.new()
			z.top_radius = mass.x * 0.5
			z.bottom_radius = mass.x * 0.4
			z.height = mass.y
			z.radial_segments = 5
			z.rings = 1
			return z
		_:   # Flügel, Spitze, Schwanz
			return _feder(mass, art == "schwanz")


static func _ellipsoid(mass: Vector3) -> Mesh:
	var k := SphereMesh.new()
	k.radius = 0.5
	k.height = 1.0
	k.radial_segments = 12
	k.rings = 7
	var a := k.get_mesh_arrays()
	var p: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	for i in p.size():
		var q := p[i] * mass
		if q.z > 0.0:   # hinten etwas schmaler (Tropfenform)
			q.x *= 1.0 - 0.25 * (q.z / (mass.z * 0.5))
			q.y *= 1.0 - 0.2 * (q.z / (mass.z * 0.5))
		p[i] = q
		n[i] = (n[i] / mass).normalized()
	a[Mesh.ARRAY_VERTEX] = p
	a[Mesh.ARRAY_NORMAL] = n
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return m


static func _kegel(mass: Vector3) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spitze := Vector3(0, -mass.y * 0.2, -mass.z * 0.5)
	var seiten := 6
	for i in seiten:
		var a1 := TAU * i / seiten
		var a2 := TAU * (i + 1) / seiten
		var p1 := Vector3(cos(a1) * mass.x * 0.5, sin(a1) * mass.y * 0.5, mass.z * 0.5)
		var p2 := Vector3(cos(a2) * mass.x * 0.5, sin(a2) * mass.y * 0.5, mass.z * 0.5)
		st.add_vertex(p1); st.add_vertex(spitze); st.add_vertex(p2)
	st.generate_normals()
	return st.commit()


## Flache Federfläche: in der Mitte am breitesten, zu beiden Enden (x) schmaler; die Vorderkante (-z) gerader als die
## Hinterkante (dort enden die Federn). Schwanz: Fächer, hinten breit.
static func _feder(mass: Vector3, faecher: bool) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var schritte := 8
	var oben := mass.y * 0.5
	var umriss := []   # je Schritt: [x, z vorn, z hinten]
	for i in schritte + 1:
		var t := float(i) / schritte
		var x := (t - 0.5) * mass.x
		var breite: float
		if faecher:
			breite = lerpf(0.55, 1.0, t)
			umriss.append([x * lerpf(0.6, 1.0, t), -mass.z * 0.5, -mass.z * 0.5 + mass.z * breite])
		else:
			breite = sin(t * PI) * 0.85 + 0.15
			umriss.append([x, -mass.z * 0.5 * (0.6 + 0.4 * breite), mass.z * 0.5 * breite])
	for i in schritte:
		var a: Array = umriss[i]
		var b: Array = umriss[i + 1]
		var a0 := Vector3(a[0], oben, a[1]); var a1 := Vector3(a[0], oben, a[2])
		var b0 := Vector3(b[0], oben, b[1]); var b1 := Vector3(b[0], oben, b[2])
		for d in [[a0, b0, b1], [a0, b1, a1]]:
			for p: Vector3 in d:
				st.set_normal(Vector3.UP)
				st.add_vertex(p)
	return st.commit()
