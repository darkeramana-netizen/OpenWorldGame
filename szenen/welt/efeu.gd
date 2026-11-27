extends Node3D
## Efeu an den Burgmauern (Grafik, 27.11.2026): An zufälligen, aber festen Stellen wachsen Efeustöcke vom Mauerfuß die
## Wand hinauf, verzweigt, unten dicht und nach oben lichter; an den Ranken sitzen Blätter (efeu.gdshader, Atlas
## texturen/efeu_blatt.png). Die Mauern kommen aus den Bauknoten (burgbau.gd, mauern) unter dem Elternknoten. Wo die
## Wand genau liegt, ermittelt ein Strahl (auch mit Anlauf); wo etwas davor steht (Haus, Schuppen, Treppe) oder ein Tor
## ist, wächst nichts. Je Efeustock ein MultiMesh für die Blätter und ein Mesh für die Ranken, nur bis 90 m sichtbar.

@export var dichte := 0.55            # Anteil der Stellen (alle 18 m Mauer eine), an denen Efeu wächst
@export var samen := 27112026

const ABSTAND_STELLEN := 18.0
const SICHT := 90.0

var _zufall := RandomNumberGenerator.new()
var _blatt_mesh: QuadMesh
var _material: ShaderMaterial
var _ranken_mat: StandardMaterial3D
var anzahl_stoecke := 0
var anzahl_blaetter := 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# erst wenn die Bauten ihre Kollision haben
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_zufall.seed = samen
	var start_ms := Time.get_ticks_msec()
	_blatt_mesh = QuadMesh.new()
	_blatt_mesh.size = Vector2(1, 1)
	_blatt_mesh.center_offset = Vector3(0, 0.5, 0)   # Stiel unten am Ursprung
	_material = ShaderMaterial.new()
	_material.shader = load("res://szenen/welt/efeu.gdshader")
	_material.set_shader_parameter("atlas", load("res://texturen/efeu_blatt.png"))
	_ranken_mat = StandardMaterial3D.new()
	_ranken_mat.albedo_color = Color(0.22, 0.16, 0.11)
	_ranken_mat.roughness = 0.9
	var tore: Array[Vector2] = []
	var bauten := get_parent().find_children("*", "Node3D", true, false).filter(func(n: Node) -> bool:
		var sk: Script = n.get_script()
		return sk != null and sk.resource_path == "res://szenen/welt/burgbau.gd")
	for b in bauten:
		var t: PackedFloat32Array = b.get("tore")
		for i in range(0, t.size() - 7, 8):
			var tg := (b as Node3D).to_global(Vector3(t[i], 0, t[i + 1]))
			tore.append(Vector2(tg.x, tg.z))
	for b in bauten:
		var m: PackedFloat32Array = b.get("mauern")
		for i in range(0, m.size() - 9, 10):
			var a := Vector2(m[i], m[i + 1])
			var e := Vector2(m[i + 2], m[i + 3])
			var laenge := a.distance_to(e)
			if laenge < 5.0:
				continue
			var aussen := Vector2(m[i + 7], m[i + 8])
			var stellen := maxi(1, int(laenge / ABSTAND_STELLEN))
			for k in stellen:
				if _zufall.randf() > dichte:
					continue
				var t := (k + _zufall.randf_range(0.2, 0.8)) / stellen
				var p := a.lerp(e, t)
				var pg := (b as Node3D).to_global(Vector3(p.x, 0, p.y))
				if tore.any(func(q: Vector2) -> bool: return q.distance_to(Vector2(pg.x, pg.z)) < 9.0):
					continue
				# beide Seiten möglich, die Hofseite häufiger
				var seite := -1.0 if _zufall.randf() < 0.7 else 1.0
				_stock(b as Node3D, p, aussen * seite, m[i + 4], m[i + 5], m[i + 6])
	print_verbose("Efeu: %d Stöcke, %d Blätter, %d ms" % [anzahl_stoecke, anzahl_blaetter, Time.get_ticks_msec() - start_ms])


## Ein Efeustock an der Mauer bei p (Raum des Bauknotens), Wand zeigt nach n
func _stock(bau: Node3D, p: Vector2, n: Vector2, unten: float, oben: float, dicke: float) -> void:
	var raum := get_world_3d().direct_space_state
	var n3 := Vector3(n.x, 0, n.y).normalized()
	var mitte := bau.to_global(Vector3(p.x, 0, p.y))
	n3 = (bau.global_basis * n3).normalized()
	# Boden vor der Wand
	var vor := mitte + n3 * (dicke * 0.5 + 0.8)
	var b := raum.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(vor.x, oben + 2.0, vor.z), Vector3(vor.x, unten - 4.0, vor.z)))
	if b.is_empty():
		return
	var boden: float = b["position"].y
	if oben - boden < 2.5:
		return
	# genaue Wandfläche: Strahl von vorn auf die Mauer in 1 m Höhe
	var von := Vector3(vor.x, boden + 1.0, vor.z) + n3 * 1.0
	var w := raum.intersect_ray(PhysicsRayQueryParameters3D.create(von, von - n3 * 3.5))
	if w.is_empty() or (w["normal"] as Vector3).dot(n3) < 0.7:
		return
	var flaeche: Vector3 = w["position"]
	var normale: Vector3 = (w["normal"] as Vector3)
	normale.y = 0.0
	normale = normale.normalized()
	# nichts davor (Haus, Schuppen, Treppe): Strahlen 1,8 m vor der Wand in 1 und 3 m Höhe zu beiden Seiten
	var entlang := normale.cross(Vector3.UP).normalized()
	for h in [1.0, 3.0]:
		for s in [-1.2, 1.2]:
			var q: Vector3 = flaeche + Vector3.UP * (h - 1.0) + normale * 0.1 + entlang * s
			if not raum.intersect_ray(PhysicsRayQueryParameters3D.create(q, q + normale * 1.8)).is_empty():
				return
	var hoehe_max := minf(oben - boden - 0.6, _zufall.randf_range(2.5, 8.5))
	var breite := _zufall.randf_range(1.2, 3.2)
	_wachse(Vector3(flaeche.x, boden, flaeche.z), normale, entlang, hoehe_max, breite)


## Ranken und Blätter wachsen lassen (in der Wandebene: u entlang, v hinauf)
func _wachse(fuss: Vector3, normale: Vector3, entlang: Vector3, hoehe_max: float, breite: float) -> void:
	var lagen: Array[Transform3D] = []
	var farben: PackedColorArray = []
	var felder: PackedFloat32Array = []
	var ranken := SurfaceTool.new()
	ranken.begin(Mesh.PRIMITIVE_TRIANGLES)
	var offen: Array = []          # [u, v, Richtung u, Dicke, Länge übrig]
	var triebe := _zufall.randi_range(9, 16)
	for i in triebe:
		offen.append([_zufall.randf_range(-breite * 0.5, breite * 0.5), 0.0, _zufall.randf_range(-0.3, 0.3), 0.02, hoehe_max * _zufall.randf_range(0.5, 1.0)])
	var schritte := 0
	while not offen.is_empty() and schritte < 4000:
		var r: Array = offen.pop_back()
		var u: float = r[0]
		var v: float = r[1]
		var ru: float = r[2]
		var dick: float = r[3]
		var rest: float = r[4]
		while rest > 0.0 and v < hoehe_max and schritte < 4000:
			schritte += 1
			var schritt := 0.14
			ru = clampf(ru + _zufall.randf_range(-0.25, 0.25), -0.9, 0.9)
			var u2 := u + ru * schritt
			var v2 := v + schritt * (1.0 - absf(ru) * 0.4)
			var a := fuss + entlang * u + Vector3.UP * v + normale * 0.025
			var e := fuss + entlang * u2 + Vector3.UP * v2 + normale * 0.025
			_ranke(ranken, a, e, normale, dick)
			# Blätter: unten dicht, oben lichter
			var dichte_hier := lerpf(5.0, 2.2, v / maxf(hoehe_max, 0.1))
			var anzahl := int(dichte_hier) + (1 if _zufall.randf() < fmod(dichte_hier, 1.0) else 0)
			for k in anzahl:
				var g := _zufall.randf_range(0.1, 0.19) * lerpf(1.25, 0.85, v / maxf(hoehe_max, 0.1))
				var ort := e + entlang * _zufall.randf_range(-0.16, 0.16) + Vector3.UP * _zufall.randf_range(-0.07, 0.07) \
					+ normale * _zufall.randf_range(0.03, 0.12)
				# Blatt steht von der Wand ab, die Spitze zeigt schräg nach unten-außen bis seitlich
				var dreh := _zufall.randf_range(-1.2, 1.2)
				var unten := Basis(normale, dreh) * Vector3.DOWN
				var y_achse := (-unten * 0.85 + normale * 0.3).normalized()     # Blattlänge, fast flach an der Wand
				var x_achse := y_achse.cross(normale).normalized()
				var z_achse := x_achse.cross(y_achse).normalized()
				var basis := Basis(x_achse * g, y_achse * g, z_achse * g)
				lagen.append(Transform3D(basis, ort - global_position))
				var ton := _zufall.randf_range(0.85, 1.3)
				farben.append(Color(ton * _zufall.randf_range(0.9, 1.05), ton, ton * _zufall.randf_range(0.85, 1.0)))
				felder.append(float(_zufall.randi() % 4) / 4.0)
			# verzweigen
			if _zufall.randf() < 0.07 and offen.size() < 30:
				offen.append([u2, v2, -ru + _zufall.randf_range(-0.3, 0.3), dick * 0.7, rest * 0.6])
			u = u2
			v = v2
			rest -= schritt
	if lagen.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _blatt_mesh
	mm.instance_count = lagen.size()
	for i in lagen.size():
		mm.set_instance_transform(i, lagen[i])
		mm.set_instance_color(i, farben[i])
		mm.set_instance_custom_data(i, Color(felder[i], 0, 0, 0))
	var blaetter := MultiMeshInstance3D.new()
	blaetter.name = "Efeu%d" % anzahl_stoecke
	blaetter.multimesh = mm
	blaetter.material_override = _material
	blaetter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blaetter.visibility_range_end = SICHT
	blaetter.visibility_range_end_margin = 10.0
	blaetter.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(blaetter)
	ranken.generate_normals()
	var rm := MeshInstance3D.new()
	rm.name = "Ranken%d" % anzahl_stoecke
	rm.mesh = ranken.commit()
	rm.material_override = _ranken_mat
	rm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rm.visibility_range_end = SICHT * 0.6
	rm.position = Vector3.ZERO
	rm.top_level = true
	add_child(rm)
	anzahl_stoecke += 1
	anzahl_blaetter += lagen.size()


## Ein Rankenstück als flaches, zur Wand liegendes Band (zwei Dreiecke) in Weltkoordinaten
func _ranke(st: SurfaceTool, a: Vector3, e: Vector3, normale: Vector3, dick: float) -> void:
	var quer := (e - a).cross(normale).normalized() * dick * 0.5
	for q in [a - quer, e - quer, e + quer, a - quer, e + quer, a + quer]:
		st.add_vertex(q + normale * 0.01)
