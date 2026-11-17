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
		if is_inside_tree() and not _nur_hoehen:
			_baue()
## Tönung je Modell (weiß = unverändert), damit Scans aus verschiedenen Gegenden zum grauen Fels passen
@export var farben := PackedColorArray()
@export var sichtweite := 2500.0
## > 0: Stücke in Kacheln dieser Größe (Meter) aufteilen, jede Kachel ein eigenes MultiMesh. So gilt die Sichtweite je
## Kachel (für viele kleine Dinge wie Pilze und Farn); sonst gilt sie für das ganze MultiMesh von seinem Mittelpunkt.
@export var kachel := 0.0
## Modelle (Nummern), die keine Kollision bekommen, z. B. die Pfähle unter einem Steg
@export var ohne_kollision := PackedInt32Array()
## Modelle (Nummern), deren Stücke beim Start auf die Oberfläche darunter gesetzt werden (z. B. Fässer und Kisten
## auf einem Kai), damit nichts im Boden steckt oder schwebt
@export var auf_boden := PackedInt32Array()
## Modelle, deren Stücke beim Start nur dann angehoben werden, wenn sie unter einer Oberfläche begraben sind (z. B.
## Pflanzen, über die sich das Felsmassiv legt); was richtig liegt (ein Pilz auf einem Stamm), bleibt
@export var heben := PackedInt32Array()

const SCHRITT := 7

var _nur_hoehen := false
var _wo := {}        # Nummer des Stücks → [MultiMesh, Exemplar, Lage] (zum Nachsetzen der Höhe)
var _formen := {}    # Nummer des Stücks → CollisionShape3D
var _koerper: StaticBody3D


func _ready() -> void:
	_baue()
	if (not auf_boden.is_empty() or not heben.is_empty()) and not Engine.is_editor_hint():
		# Erst wenn die Kollision der Umgebung steht, lässt sich der Boden darunter finden. Dann nur die betroffenen
		# Stücke in der Höhe nachsetzen, statt alles neu zu bauen (das war ein langes Bild gleich nach dem Laden).
		await get_tree().physics_frame
		await get_tree().physics_frame
		if not is_inside_tree():
			return
		var raum := get_world_3d().direct_space_state
		var boden := load("res://szenen/welt/ausstattung.gd") as GDScript
		# die eigene Kollision zählt nicht als Boden (sonst landete ein Fass auf sich selbst)
		var ohne: Array[RID] = []
		if _koerper != null and is_instance_valid(_koerper):
			ohne.append(_koerper.get_rid())
		var neu := stuecke.duplicate()
		var i := 0
		while i + SCHRITT - 1 < neu.size():
			var m := int(neu[i])
			if m in auf_boden or m in heben:
				var p := global_transform * Vector3(neu[i + 1], neu[i + 2], neu[i + 3])
				var y: float = boden.boden_unter(raum, p, 1.6 if m in auf_boden else 3.0, 3.0 if m in auf_boden else 0.2, ohne)
				if not is_nan(y) and (m in auf_boden or y > p.y + 0.3):
					neu[i + 2] = (global_transform.affine_inverse() * Vector3(p.x, y, p.z)).y
					_versetze(i / SCHRITT, neu[i + 2] - stuecke[i + 2])
			i += SCHRITT
		_nur_hoehen = true
		stuecke = neu
		_nur_hoehen = false


## Ein Stück um dy (lokal) anheben oder absenken: Exemplar im MultiMesh und seine Kollisionsform.
func _versetze(nr: int, dy: float) -> void:
	if absf(dy) < 0.0001:
		return
	if _wo.has(nr):
		var t: Transform3D = _wo[nr][2]
		t.origin.y += dy
		_wo[nr][2] = t
		(_wo[nr][0] as MultiMesh).set_instance_transform(_wo[nr][1], t)
	if _formen.has(nr):
		(_formen[nr] as CollisionShape3D).position.y += dy


func _baue() -> void:
	_wo.clear()
	_formen.clear()
	for kind in get_children():
		kind.queue_free()
	var koerper: StaticBody3D = null
	if not Engine.is_editor_hint():
		koerper = StaticBody3D.new()
		koerper.name = "Kollision"
		add_child(koerper)
	_koerper = koerper
	for m in modelle.size():
		var teil_lage := _teil_lage(modelle[m])
		var mesh := _mesh(modelle[m], false)
		if mesh == null:
			continue
		# Die Fotoscans sind hinten offen: beidseitig zeichnen, sonst sieht man schräg von der Seite durch sie hindurch
		# und ihre Ränder wirken wie ausgeschnittene Pappe. Dazu die Tönung je Modell.
		mesh = mesh.duplicate()
		for f in mesh.get_surface_count():
			var mat := mesh.surface_get_material(f)
			if mat is BaseMaterial3D:
				mat = mat.duplicate()
				(mat as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
				if m < farben.size() and farben[m] != Color.WHITE:
					(mat as BaseMaterial3D).albedo_color = farben[m]
				mesh.surface_set_material(f, mat)
		var lagen: Array[Transform3D] = []
		var nummern: Array[int] = []
		var i := 0
		while i + SCHRITT - 1 < stuecke.size():
			if int(stuecke[i]) == m:
				lagen.append(_lage(i) * teil_lage)
				nummern.append(i / SCHRITT)
			i += SCHRITT
		if lagen.is_empty():
			continue
		var gruppen := {}
		var gruppen_nr := {}
		for j in lagen.size():
			var lage := lagen[j]
			var schluessel := Vector2i(0, 0)
			if kachel > 0.0:
				schluessel = Vector2i(floori(lage.origin.x / kachel), floori(lage.origin.z / kachel))
			if not gruppen.has(schluessel):
				gruppen[schluessel] = []
				gruppen_nr[schluessel] = []
			gruppen[schluessel].append(lage)
			gruppen_nr[schluessel].append(nummern[j])
		for schluessel: Vector2i in gruppen:
			var mitte := Vector3((schluessel.x + 0.5) * kachel, 0.0, (schluessel.y + 0.5) * kachel) if kachel > 0.0 else Vector3.ZERO
			var teil: Array = gruppen[schluessel]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = teil.size()
			for k in teil.size():
				var t: Transform3D = teil[k]
				var lokal := Transform3D(t.basis, t.origin - mitte)
				mm.set_instance_transform(k, lokal)
				_wo[gruppen_nr[schluessel][k]] = [mm, k, lokal]
			var inst := MultiMeshInstance3D.new()
			inst.name = "Felsen%d_%d_%d" % [m, schluessel.x, schluessel.y]
			inst.multimesh = mm
			inst.position = mitte
			inst.visibility_range_end = sichtweite
			if sichtweite < 1000.0:
				# weich ausblenden statt aufploppen (Phase 1, docs/03-messgrundlage.md)
				inst.visibility_range_end_margin = sichtweite * 0.12
				inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			add_child(inst)
		if koerper != null and not m in ohne_kollision:
			var form := _mesh(modelle[m], true)
			if form == null:
				continue
			var punkte := form.get_faces()
			for j in lagen.size():
				var lage := lagen[j]
				var shape := ConcavePolygonShape3D.new()
				var flaechen := PackedVector3Array()
				flaechen.resize(punkte.size())
				for k in punkte.size():
					flaechen[k] = lage * punkte[k]
				shape.set_faces(flaechen)
				var cs := CollisionShape3D.new()
				cs.shape = shape
				koerper.add_child(cs)
				_formen[nummern[j]] = cs


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
