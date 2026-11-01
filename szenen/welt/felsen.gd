@tool
extends Node3D
## 3D-Felsen und Pflanzen aus Fotoscans (Poly Haven, modelle/felsen/, modelle/pflanzen/) als MultiMesh, je Modell eins.
## Die Bauskripte (werkzeuge/bau/teil_felsen.py) setzen sie an Steilhänge und Klippen; die Front der Modelle zeigt
## nach lokal +z und wird hangabwärts gedreht. Zur Kollision dient eine stark vereinfachte Form (<name>_form.gltf).

## Modelle als "res://…/name.gltf" oder "res://…/name.gltf#n" (n-tes Mesh einer Sammlung)
@export var modelle := PackedStringArray():
	set(w):
		modelle = w
		if is_inside_tree():
			_baue()
## je Stück: Modell, x, y, z, Gier (Grad), Neigung (Grad, Front nach hinten gekippt), Größe
@export var stuecke := PackedFloat32Array():
	set(w):
		stuecke = w
		if is_inside_tree():
			_baue()
## Tönung je Modell (weiß = unverändert), damit Scans aus verschiedenen Gegenden zum grauen Fels passen
@export var farben := PackedColorArray()
@export var sichtweite := 2500.0
## > 0: Stücke in Kacheln dieser Größe (Meter) aufteilen, jede Kachel ein eigenes MultiMesh. So gilt die Sichtweite je
## Kachel (für viele kleine Dinge wie Pilze und Farn); sonst gilt sie für das ganze MultiMesh von seinem Mittelpunkt.
@export var kachel := 0.0
## Modelle (Nummern), die keine Kollision bekommen, z. B. die Pfähle unter einem Steg
@export var ohne_kollision := PackedInt32Array()

const SCHRITT := 7


func _ready() -> void:
	_baue()


func _baue() -> void:
	for kind in get_children():
		kind.queue_free()
	var koerper: StaticBody3D = null
	if not Engine.is_editor_hint():
		koerper = StaticBody3D.new()
		koerper.name = "Kollision"
		add_child(koerper)
	for m in modelle.size():
		var teil_lage := _teil_lage(modelle[m])
		var mesh := _mesh(modelle[m], false)
		if mesh == null:
			continue
		if m < farben.size() and farben[m] != Color.WHITE:
			mesh = mesh.duplicate()
			for f in mesh.get_surface_count():
				var mat := mesh.surface_get_material(f)
				if mat is BaseMaterial3D:
					mat = mat.duplicate()
					(mat as BaseMaterial3D).albedo_color = farben[m]
					mesh.surface_set_material(f, mat)
		var lagen: Array[Transform3D] = []
		var i := 0
		while i + SCHRITT - 1 < stuecke.size():
			if int(stuecke[i]) == m:
				lagen.append(_lage(i) * teil_lage)
			i += SCHRITT
		if lagen.is_empty():
			continue
		var gruppen := {}
		for lage in lagen:
			var schluessel := Vector2i(0, 0)
			if kachel > 0.0:
				schluessel = Vector2i(floori(lage.origin.x / kachel), floori(lage.origin.z / kachel))
			if not gruppen.has(schluessel):
				gruppen[schluessel] = []
			gruppen[schluessel].append(lage)
		for schluessel: Vector2i in gruppen:
			var mitte := Vector3((schluessel.x + 0.5) * kachel, 0.0, (schluessel.y + 0.5) * kachel) if kachel > 0.0 else Vector3.ZERO
			var teil: Array = gruppen[schluessel]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = teil.size()
			for k in teil.size():
				var t: Transform3D = teil[k]
				mm.set_instance_transform(k, Transform3D(t.basis, t.origin - mitte))
			var inst := MultiMeshInstance3D.new()
			inst.name = "Felsen%d_%d_%d" % [m, schluessel.x, schluessel.y]
			inst.multimesh = mm
			inst.position = mitte
			inst.visibility_range_end = sichtweite
			add_child(inst)
		if koerper != null and not m in ohne_kollision:
			var form := _mesh(modelle[m], true)
			if form == null:
				continue
			var punkte := form.get_faces()
			for lage in lagen:
				var shape := ConcavePolygonShape3D.new()
				var flaechen := PackedVector3Array()
				flaechen.resize(punkte.size())
				for k in punkte.size():
					flaechen[k] = lage * punkte[k]
				shape.set_faces(flaechen)
				var cs := CollisionShape3D.new()
				cs.shape = shape
				koerper.add_child(cs)


## Lage eines Stücks: drehen (Front hangabwärts), nach hinten kippen, vergrößern
func _lage(i: int) -> Transform3D:
	var b := Basis(Vector3.UP, deg_to_rad(stuecke[i + 4])) * Basis(Vector3.RIGHT, deg_to_rad(-stuecke[i + 5]))
	return Transform3D(b.scaled(Vector3.ONE * stuecke[i + 6]), Vector3(stuecke[i + 1], stuecke[i + 2], stuecke[i + 3]))


## Drehung und Größe des Meshes im Modell (bei Sammlungen sind die Teile gedreht und skaliert): gilt für jedes Stück.
func _teil_lage(pfad: String) -> Transform3D:
	var teile := pfad.split("#")
	if not ResourceLoader.exists(teile[0]):
		return Transform3D.IDENTITY
	var szene: Node3D = (load(teile[0]) as PackedScene).instantiate()
	var meshes := szene.find_children("*", "MeshInstance3D", true, false)
	var nr := int(teile[1]) if teile.size() > 1 else 0
	var lage := Transform3D.IDENTITY
	if nr < meshes.size():
		var k: Node = meshes[nr]
		while k != szene:
			lage = (k as Node3D).transform * lage
			k = k.get_parent()
	szene.free()
	# nur Drehung und Größe: Die Teile einer Sammlung stehen im Modell nebeneinander, hier sitzt jedes an seinem Platz
	return Transform3D(lage.basis, Vector3.ZERO)


func _mesh(pfad: String, form: bool) -> Mesh:
	var teile := pfad.split("#")
	var datei := teile[0]
	if form:
		datei = datei.replace(".gltf", "_form.gltf")
	if not ResourceLoader.exists(datei):
		return null
	var szene: Node = (load(datei) as PackedScene).instantiate()
	var meshes := szene.find_children("*", "MeshInstance3D", true, false)
	var nr := int(teile[1]) if teile.size() > 1 else 0
	var mesh: Mesh = (meshes[nr] as MeshInstance3D).mesh if nr < meshes.size() else null
	szene.free()
	return mesh
