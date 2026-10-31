@tool
extends Node3D
## 3D-Felsen aus Fotoscans (Poly Haven, modelle/felsen/): Klippenstücke und Felsbrocken als MultiMesh, je Modell eins.
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
@export var sichtweite := 2500.0

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
		var mesh := _mesh(modelle[m], false)
		if mesh == null:
			continue
		var lagen: Array[Transform3D] = []
		var i := 0
		while i + SCHRITT - 1 < stuecke.size():
			if int(stuecke[i]) == m:
				lagen.append(_lage(i))
			i += SCHRITT
		if lagen.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = lagen.size()
		for k in lagen.size():
			mm.set_instance_transform(k, lagen[k])
		var inst := MultiMeshInstance3D.new()
		inst.name = "Felsen%d" % m
		inst.multimesh = mm
		inst.visibility_range_end = sichtweite
		add_child(inst)
		if koerper != null:
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
