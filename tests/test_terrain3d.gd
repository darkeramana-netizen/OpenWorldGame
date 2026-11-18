extends SceneTree
## Tests für die Darstellung des Geländes mit Terrain3D (szenen/welt/gelaende_terrain3d.gd): dieselben Höhen wie das
## eigene Gelände, Löcher an denselben Stellen, außerhalb der Daten kein Gelände, Kollision und hoehe_bei() unverändert,
## das feine Gitter folgt der Kamera. Und: ohne Einstellung bleibt alles beim eigenen Gelände.
## Starten: godot --headless --path . --script res://tests/test_terrain3d.gd

const Gelaende := preload("res://szenen/welt/gelaende.gd")
const Terrain3DBau := preload("res://szenen/welt/gelaende_terrain3d.gd")
const REGION := "res://szenen/welt/region_drachenstein.tscn"

var fehler := 0


func pruefe(bed: bool, was: String) -> void:
	if bed:
		print("OK     ", was)
	else:
		fehler += 1
		print("FEHLER ", was)


func _initialize() -> void:
	pruefe(Terrain3DBau.verfuegbar(), "Terrain3D geladen (%s)" % ("ja" if ClassDB.class_exists("Terrain3D") else "nein"))

	# 1. Ohne Einstellung: eigenes Gelände wie bisher
	var r1 := await _lade()
	var g1: Node3D = r1.get_node("Gelaende")
	var kacheln := g1.get_children().filter(func(k: Node) -> bool: return k.name.begins_with("Kachel_")).size()
	pruefe(not g1.mit_terrain3d() and kacheln > 100 and g1.get_node_or_null("Terrain3D") == null,
		"Standard: eigenes Gelände (%d Kacheln, kein Terrain3D)" % kacheln)
	var kollision1 := g1.get_node("Kollision").get_child_count()
	r1.free()

	# 2. Mit Terrain3D
	Gelaende.darstellung_vorgabe = "terrain3d"
	var r := await _lade()
	var g: Node3D = r.get_node("Gelaende")
	var t: Node3D = g.get_node_or_null("Terrain3D")
	pruefe(g.mit_terrain3d() and t != null, "Terrain3D-Knoten unter dem Gelände")
	if t == null:
		_ende()
		return
	kacheln = g.get_children().filter(func(k: Node) -> bool: return k.name.begins_with("Kachel_")).size()
	pruefe(kacheln == 0, "Keine eigenen Kacheln (%d)" % kacheln)
	pruefe(g.get_node("Kollision").get_child_count() == kollision1 and g.get_node_or_null("Rand") != null,
		"Kollision (%d Formen) und Randwände wie beim eigenen Gelände" % kollision1)
	var daten: Object = t.get("data")
	pruefe(int(daten.call("get_region_count")) > 0, "%d Regionen à %d Punkte, Abstand %.1f m"
		% [daten.call("get_region_count"), t.get("region_size"), t.get("vertex_spacing")])

	# Höhen an allen Rasterpunkten einer Stichprobe gleich
	var zufall := RandomNumberGenerator.new()
	zufall.seed = 7
	var max_abw := 0.0
	var loch_falsch := 0
	for i in 4000:
		var ix := zufall.randi_range(0, g.breite - 1)
		var iz := zufall.randi_range(0, g.tiefe - 1)
		var p := Vector3(g.ursprung.x + ix * g.abstand, 0.0, g.ursprung.y + iz * g.abstand)
		var loch: bool = g._loch[iz * g.breite + ix] == 1
		if bool(daten.call("get_control_hole", p)) != loch:
			loch_falsch += 1
		if not loch:
			max_abw = maxf(max_abw, absf(float(daten.call("get_height", p)) - g._h(ix, iz)))
	pruefe(max_abw < 0.001, "Höhen an 4000 Rasterpunkten gleich (größte Abweichung %.4f m)" % max_abw)
	pruefe(loch_falsch == 0, "Löcher an denselben Rasterpunkten (%d abweichend)" % loch_falsch)
	var loch_mitte := Vector3((g.loecher[0].x + g.loecher[0].z) / 2.0, 0.0, (g.loecher[0].y + g.loecher[0].w) / 2.0)
	pruefe(bool(daten.call("get_control_hole", loch_mitte)), "Tunnel-Loch %s ist offen" % loch_mitte)

	# Rand: ein Rasterpunkt mit Randhöhe, dahinter Loch
	var ecke := Vector3(g.ursprung.x - g.abstand, 0.0, g.ursprung.y + 100.0 * g.abstand)
	var aussen := Vector3(g.ursprung.x - 3.0 * g.abstand, 0.0, ecke.z)
	var hinten := Vector3(g.ursprung.x + (g.breite + 2) * g.abstand, 0.0, ecke.z)
	pruefe(not bool(daten.call("get_control_hole", ecke))
		and absf(float(daten.call("get_height", ecke)) - g.hoehe_bei(g.ursprung.x, ecke.z)) < 0.001,
		"Ein Randpunkt außen mit der Randhöhe")
	pruefe(bool(daten.call("get_control_hole", aussen)) and bool(daten.call("get_control_hole", hinten)),
		"Weiter außen kein Gelände (Loch), auf beiden Seiten")

	# Kollision unverändert: Strahl von oben trifft auf hoehe_bei
	var raum := (r as Node3D).get_world_3d().direct_space_state
	var treffer := 0
	for p: Vector2 in [Vector2(0, 0), Vector2(-300, 120), Vector2(250, -200), Vector2(-600, 400)]:
		var anfrage := PhysicsRayQueryParameters3D.create(Vector3(p.x, 400, p.y), Vector3(p.x, -100, p.y))
		anfrage.collision_mask = 0xFFFFFFFF
		var e := raum.intersect_ray(anfrage)
		if not e.is_empty() and absf(e.position.y - g.hoehe_bei(p.x, p.y)) < 0.05:
			treffer += 1
		elif not e.is_empty():
			print("       Strahl bei %s traf %s auf %.2f (Gelände %.2f)" % [p, e.collider, e.position.y, g.hoehe_bei(p.x, p.y)])
	pruefe(treffer >= 3, "Kollision des Geländes wie bisher (%d von 4 Strahlen auf Geländehöhe, Rest auf Bauten)" % treffer)

	# Das Gitter folgt der Kamera
	var kamera := r.get_viewport().get_camera_3d()
	for i in 20:
		await process_frame
	pruefe(kamera != null and t.call("get_camera") == kamera, "Terrain3D folgt der aktiven Kamera")
	pruefe(int(t.get("collision_mode")) == 0, "Terrain3D baut keine eigene Kollision")
	var mat: Resource = t.get("material")
	pruefe(bool(mat.get("shader_override_enabled")) and (mat.get("shader_override") as Shader).resource_path.ends_with("gelaende_t3d.gdshader"),
		"Unser Geländematerial als Shader von Terrain3D")
	pruefe(not bool(mat.get("show_checkered")), "Kein Karomuster (Platzhalter von Terrain3D ohne Texturen)")
	r.free()
	Gelaende.darstellung_vorgabe = ""
	_ende()


func _ende() -> void:
	print("\nFehler: %d" % fehler)
	quit(1 if fehler > 0 else 0)


func _lade() -> Node:
	var r: Node = (load(REGION) as PackedScene).instantiate()
	root.add_child(r)
	for i in 4:
		await process_frame
	return r
