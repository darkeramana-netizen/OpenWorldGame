extends SceneTree
## Messgrundlage (Phase 0): misst eine Region, ohne am Spiel etwas zu ändern.
##
## 1. Laden: Datei lesen, Instanziieren, Einhängen; die Zeit jedes _ready() (über das ready-Signal jedes Knotens),
##    zusammengefasst je Bauart (Skript), dazu die ersten Bilder danach (Bewuchs und Ausstattung setzen sich erst dann).
## 2. Szene: Knoten, Meshes, Oberflächen (Obergrenze der Draw Calls), Dreiecke, MultiMesh-Exemplare, Lichter (mit
##    Schatten), Kollisionskörper, Knoten mit Sichtweite (visibility_range), je Bauart.
## 3. Messfahrt: Die Spielfigur rennt eine feste Strecke ab (wie die Tests, mit echter Physik, mit Eid, damit die
##    Torwachen öffnen), am Ende ein Rundblick. Je Bild: echte Frametime (ohne Grafik ist das die CPU-Zeit des
##    Hauptthreads), Draw Calls, Dreiecke, Objekte, Speicher und Grafikspeicher, Renderzeit auf der CPU und auf der
##    Grafikkarte (zeigt, wer bremst), Kameraposition; dazu Godots Prozess-
##    und Physikzeit, die Godot als Spitze der letzten Sekunde meldet (nicht je Bild).
## 4. Auswertung: p50/p95/p99/Max, Hänger über 33 ms und 50 ms (getrennt: Anlauf nach dem Laden und Fahrt),
##    Wechsel der Sichtweiten-Stufen entlang der Kamerafahrt (LOD-Wechsel; nahe Wechsel unter 50 m).
##
## Ohne Grafik (--headless) gibt es keine Render-Werte (Draw Calls, Dreiecke je Bild, Grafikspeicher bleiben 0);
## Ladezeit, CPU und Speicher sind trotzdem gültig. Für die vollen Werte mit Grafik und ohne VSync starten:
##
##   godot --path . --script res://werkzeuge/messen/messung.gd -- --name mein_rechner
##
## GPU-Aufschlüsselung (--aufschluesselung ja, nach der Fahrt; mit --strecke keine allein): An festen Blickpunkten
## wird je eine Sache abgeschaltet (Effekte, Sonnenschatten, Lampen, Objektgruppen) und gemessen, wie viel Zeit die
## Grafikkarte und die CPU-Seite des Renderns dadurch sparen. Ergibt eine Rangliste der Kosten. --bilder N: Bilder je
## Messung (Standard 60).
##
## Weitere Angaben nach "--": --region drachenstein, --strecke stadt_palas|kurz|keine, --aufloesung 1920x1080,
## --ausgabe <Ordner> (Standard user://messungen/). Ergebnis: <Ordner>/messung_<region>_<name>_<Zeit>.json und .txt.

const STRECKEN := {
	# wie test_region: vom Markt durch die Stadt, Vorburg, Mittelburg, Zwinger und Oberburg hinauf in den Palas
	"stadt_palas": {"region": "drachenstein", "start": Vector3(145.82, -14.0, 142.94), "punkte": [
		Vector2(143.81, 147.13), Vector2(141.34, 166.16), Vector2(135.55, 185.79), Vector2(128.88, 202.81),
		Vector2(122.51, 215.44), Vector2(110.87, 225.13), Vector2(94.36, 232.88), Vector2(82.31, 237.56),
		Vector2(67.97, 239.07), Vector2(47.75, 238.38), Vector2(28.09, 232.25), Vector2(14.66, 224.28),
		Vector2(6.83, 214.84), Vector2(10.28, 207.82), Vector2(21.97, 210.91), Vector2(38.99, 213.54),
		Vector2(52.46, 213.78), Vector2(60.65, 207.06), Vector2(69.1, 191.24), Vector2(70.54, 176), Vector2(67, 161.5),
		Vector2(65.34, 149.53), Vector2(65.66, 141.1), Vector2(60.57, 140.51), Vector2(55.81, 139.89),
		Vector2(52.45, 139.83), Vector2(41.35, 139.73), Vector2(31.67, 136.49), Vector2(30.65, 132.21),
		Vector2(31.29, 127.78), Vector2(41.09, 124.29), Vector2(53.06, 118.6), Vector2(58.5, 111.1),
		Vector2(61.86, 94.69), Vector2(63.34, 75.74), Vector2(67.36, 59.27), Vector2(72.42, 43.06),
		Vector2(77.43, 26.18), Vector2(79.22, 15.27), Vector2(72.43, 14.49), Vector2(67.16, 24), Vector2(57.79, 40.9),
		Vector2(51.79, 49.8), Vector2(46.53, 55.26), Vector2(41.63, 57.01), Vector2(36.7, 58.43), Vector2(33.71, 54.64),
		Vector2(32.91, 48.99), Vector2(32.82, 43.95), Vector2(34.12, 31.07), Vector2(40.83, 10.36),
		Vector2(40.41, -11.12), Vector2(39.76, -23.18), Vector2(43.48, -35.25), Vector2(47.48, -48.01),
		Vector2(40.59, -54.17), Vector2(35.74, -51.75), Vector2(34.32, -48.62), Vector2(28.69, -47.48),
		Vector2(22.74, -46.32), Vector2(11.36, -41.69), Vector2(3.84, -43.09), Vector2(3.08, -48.4),
		Vector2(1.97, -53.69), Vector2(-0.03, -57.56), Vector2(-1.44, -62.49), Vector2(-2.52, -67.44),
		Vector2(-2.62, -76.85), Vector2(-5.2, -100.17)]},
	# kurz (für den Rauchtest tests/test_messung.gd): die ersten Meter vom Markt
	"kurz": {"region": "drachenstein", "start": Vector3(145.82, -14.0, 142.94), "punkte": [
		Vector2(143.81, 147.13), Vector2(141.34, 166.16), Vector2(135.55, 185.79)]},
}
## Blickpunkte der Aufschlüsselung: [Name, Standort (x, z), Blickziel (x, z)]
const BLICKPUNKTE := {"drachenstein": [["Markt", Vector2(145.82, 142.94), Vector2(128.88, 202.81)],
	["Mittelburg", Vector2(40.83, 10.36), Vector2(-2.62, -76.85)]]}
const ANLAUF_S := 10.0          # so lange nach dem Laden gilt als Anlauf (Shader, Bewuchs, Ausstattung)
const RUNDBLICK_S := 8.0
const ZEIT_PRO_PUNKT := 40.0
const NAH := 50.0               # Sichtweiten-Wechsel näher als das
## Ein harter Wechsel (ohne Überblendung) gilt als sichtbares Aufploppen, wenn das Ding dabei größer als etwa 2 Bildpunkte
## ist (1080 Zeilen auf rund 75° Blickwinkel: etwa 825 Bildpunkte je Bogenmaß)
const SICHTBAR := 0.0025

var _args := {}
var _ready_zeiten := {}         # Kategorie → [Anzahl, µs]
var _einzeln: Array = []        # [µs, Kategorie, Pfad]
var _letzt := 0
var _frames: Array = []         # je Bild ein Array (siehe _bild)
var _phase := "laden"
var _t_vorher := 0
var _instanz: Node = null


func _initialize() -> void:
	_lies_args()
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# Renderzeit je Bild messen: CPU-Seite des Renderns und Zeit auf der Grafikkarte (zeigt, wer bremst)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	Engine.max_fps = 0
	if _args.has("aufloesung") and DisplayServer.get_name() != "headless":
		var t: PackedStringArray = String(_args["aufloesung"]).split("x")
		if t.size() == 2:
			DisplayServer.window_set_size(Vector2i(int(t[0]), int(t[1])))
	var region: String = _args.get("region", "drachenstein")
	var speicher: Node = root.get_node("Speicher")
	speicher.ordner = "user://messung_speicher/"
	root.get_node("Spielstand").zuruecksetzen("Messung")
	# mit Eid, damit die Torwachen die Tore der Strecke öffnen (wie test_region)
	root.get_node("Spielstand").setze_flag("eid_waechter", true)
	root.get_node("Spielzeit").zuruecksetzen()
	speicher.ausstehender_spieler = {}
	speicher.region = region
	var pfad: String = speicher.REGIONEN[region]

	# --- 1. Laden ---
	var t0 := Time.get_ticks_usec()
	var ps: PackedScene = ResourceLoader.load(pfad)
	var t1 := Time.get_ticks_usec()
	_instanz = ps.instantiate()
	var t2 := Time.get_ticks_usec()
	var alle: Array[Node] = [_instanz]
	alle.append_array(_instanz.find_children("*", "", true, false))
	for n: Node in alle:
		n.ready.connect(_bei_ready.bind(n), CONNECT_ONE_SHOT)
	# das Ende von enter_tree (alle Knoten, vor dem ersten ready): der letzte Knoten in Baumreihenfolge
	alle[alle.size() - 1].tree_entered.connect(func() -> void: _letzt = Time.get_ticks_usec(), CONNECT_ONE_SHOT)
	_letzt = Time.get_ticks_usec()
	root.add_child(_instanz)
	current_scene = _instanz
	var t3 := Time.get_ticks_usec()
	process_frame.connect(_bild)
	_t_vorher = Time.get_ticks_usec()
	_phase = "anlauf"
	var anlauf_ende := Time.get_ticks_msec() + int(ANLAUF_S * 1000)
	var bereit_us := 0
	var bilder := 0
	while Time.get_ticks_msec() < anlauf_ende:
		await process_frame
		bilder += 1
		if bilder == 5:
			bereit_us = Time.get_ticks_usec()
	var laden := {"datei_ms": (t1 - t0) / 1000.0, "instanziieren_ms": (t2 - t1) / 1000.0,
		"einhaengen_und_ready_ms": (t3 - t2) / 1000.0, "bis_5_bilder_ms": (bereit_us - t0) / 1000.0,
		"gesamt_bis_einhaengen_ms": (t3 - t0) / 1000.0}

	# --- 2. Szene ---
	var szene := _zaehle_szene()

	# --- 3. Messfahrt ---
	var fahrt := {}
	var strecke: String = _args.get("strecke", "stadt_palas")
	if STRECKEN.has(strecke) and STRECKEN[strecke]["region"] == region:
		fahrt = await _fahre(STRECKEN[strecke])
	_phase = "ende"
	process_frame.disconnect(_bild)
	var aufschl := {}
	if String(_args.get("aufschluesselung", "")) in ["ja", "1", "true"]:
		aufschl = await _aufschluesselung(region)

	# --- 4. Auswertung ---
	var ergebnis := {
		"region": region, "strecke": strecke, "name": _args.get("name", "ohne_name"),
		"zeit": Time.get_datetime_string_from_system(), "system": _system(),
		"laden": laden, "ready_je_bauart": _ready_tabelle(), "langsamste_ready": _langsamste(15),
		"szene": szene, "fahrt": fahrt,
		"anlauf": _statistik("anlauf"), "messfahrt": _statistik("fahrt"), "rundblick": _statistik("rundblick"),
		"lod": _lod_wechsel(), "aufschluesselung": aufschl,
	}
	_schreibe(ergebnis)
	quit(0)


func _lies_args() -> void:
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i < a.size():
		if a[i].begins_with("--") and i + 1 < a.size() and not a[i + 1].begins_with("--"):
			_args[a[i].substr(2)] = a[i + 1]
			i += 2
		else:
			i += 1


func _bei_ready(n: Node) -> void:
	var jetzt := Time.get_ticks_usec()
	var dauer := jetzt - _letzt
	_letzt = jetzt
	var k := _kategorie(n)
	var e: Array = _ready_zeiten.get(k, [0, 0])
	e[0] += 1
	e[1] += dauer
	_ready_zeiten[k] = e
	if dauer > 20000:
		_einzeln.append([dauer, k, str(n.get_path())])


## Bauart eines Knotens: Name seines Skripts, sonst seine Klasse
func _kategorie(n: Node) -> String:
	var s: Script = n.get_script()
	if s != null and s.resource_path != "":
		return s.resource_path.get_file().get_basename()
	return n.get_class()


## Bauart des nächsten Vorfahren mit Skript (für Meshes, die ein Bauskript erzeugt)
func _herkunft(n: Node) -> String:
	var p := n
	while p != null and p != _instanz:
		var s: Script = p.get_script()
		if s != null and s.resource_path != "":
			return s.resource_path.get_file().get_basename()
		p = p.get_parent()
	return "ohne Skript"


func _bild() -> void:
	var jetzt := Time.get_ticks_usec()
	var kam := root.get_viewport().get_camera_3d()
	var kp: Vector3 = kam.global_position if kam != null else Vector3.ZERO
	_frames.append([_phase, (jetzt - _t_vorher) / 1000.0,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()) + RenderingServer.get_frame_setup_time_cpu(),
		RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),
		kp])
	_t_vorher = jetzt


func _fahre(s: Dictionary) -> Dictionary:
	var sp := current_scene.get_node("Spieler") as CharacterBody3D
	var dreh := sp.get_node("KameraDrehpunkt") as Node3D
	var g := current_scene.get_tree().get_first_node_in_group("gelaende")
	var start: Vector3 = s["start"]
	if g != null:
		start.y = float(g.hoehe_bei(start.x, start.z)) + 0.3
	_phase = "sprung"
	sp.global_position = start
	sp.velocity = Vector3.ZERO
	for i in 90:
		await physics_frame
	_phase = "fahrt"
	var t0 := Time.get_ticks_msec()
	var erreicht := 0
	var abbruch := ""
	Input.action_press("vor")
	Input.action_press("rennen")
	for ziel: Vector2 in s["punkte"]:
		var ende := Time.get_ticks_msec() + int(ZEIT_PRO_PUNKT * 1000)
		var ok := false
		while Time.get_ticks_msec() < ende:
			var p := sp.global_position
			var weg := Vector2(ziel.x - p.x, ziel.y - p.z)
			if weg.length() < 0.8:
				ok = true
				break
			dreh.rotation.y = atan2(-weg.x, -weg.y)
			await physics_frame
		if not ok:
			abbruch = "Wegpunkt %s nicht erreicht, stehe bei %s" % [ziel, sp.global_position.snapped(Vector3.ONE * 0.1)]
			break
		erreicht += 1
	Input.action_release("vor")
	Input.action_release("rennen")
	var dauer := (Time.get_ticks_msec() - t0) / 1000.0
	# Rundblick vom Ende der Strecke (im Palas bzw. am letzten Punkt)
	_phase = "rundblick"
	var r0 := Time.get_ticks_msec()
	var w0 := dreh.rotation.y
	while Time.get_ticks_msec() - r0 < int(RUNDBLICK_S * 1000):
		dreh.rotation.y = w0 + TAU * (Time.get_ticks_msec() - r0) / (RUNDBLICK_S * 1000.0)
		await process_frame
	return {"punkte": (s["punkte"] as Array).size(), "erreicht": erreicht, "dauer_s": dauer, "abbruch": abbruch}


## Je Blickpunkt: alles an, dann je eine Sache aus (danach wieder an), am Ende noch einmal alles an (Drift)
func _aufschluesselung(region: String) -> Dictionary:
	var sp := current_scene.get_node("Spieler") as CharacterBody3D
	var dreh := sp.get_node("KameraDrehpunkt") as Node3D
	var g := current_scene.get_tree().get_first_node_in_group("gelaende")
	var umg := current_scene.find_children("*", "WorldEnvironment", true, false)
	var env: Environment = (umg[0] as WorldEnvironment).environment if not umg.is_empty() else null
	var sonne := current_scene.find_child("Sonne", true, false) as DirectionalLight3D
	var vp := root.get_viewport()
	var mit_skript := func(namen: Array) -> Array:
		var aus: Array = []
		for n: Node in _instanz.find_children("*", "Node3D", true, false):
			var s: Script = n.get_script()
			if s != null and s.resource_path.get_file().get_basename() in namen:
				aus.append(n)
		return aus
	var gruppen := {
		"Figuren": _instanz.find_children("*", "Figur", true, false),
		"Bewuchs": mit_skript.call(["bewuchs"]),
		"Felsen": mit_skript.call(["felsen", "felsmassiv", "felssockel"]),
		"Haeuser": mit_skript.call(["stadthaeuser"]),
		"Burgbauten": mit_skript.call(["burgbau", "turm"]),
		"Gelaende": current_scene.get_tree().get_nodes_in_group("gelaende"),
		"Lampen": _instanz.find_children("*", "OmniLight3D", true, false) + _instanz.find_children("*", "SpotLight3D", true, false),
	}
	# [Name, abschalten, wieder an]
	var varianten: Array = []
	if env != null:
		for e: Array in [["SDFGI", "sdfgi_enabled"], ["SSAO", "ssao_enabled"], ["SSIL", "ssil_enabled"],
				["Glow", "glow_enabled"], ["Nebel", "fog_enabled"], ["Volumennebel", "volumetric_fog_enabled"]]:
			var feld: String = e[1]
			var vorher: bool = env.get(feld)
			if vorher:
				varianten.append([e[0], func() -> void: env.set(feld, false), func() -> void: env.set(feld, true)])
	var msaa := vp.msaa_3d
	if msaa != Viewport.MSAA_DISABLED:
		varianten.append(["MSAA", func() -> void: vp.msaa_3d = Viewport.MSAA_DISABLED, func() -> void: vp.msaa_3d = msaa])
	if sonne != null:
		var weite := sonne.directional_shadow_max_distance
		varianten.append(["Sonnenschatten", func() -> void:
			sonne.process_mode = Node.PROCESS_MODE_DISABLED
			sonne.shadow_enabled = false,
			func() -> void:
				sonne.shadow_enabled = true
				sonne.process_mode = Node.PROCESS_MODE_INHERIT])
		varianten.append(["Schatten_bis_150m", func() -> void: sonne.directional_shadow_max_distance = 150.0,
			func() -> void: sonne.directional_shadow_max_distance = weite])
	for name_: String in gruppen:
		var knoten: Array = gruppen[name_]
		if knoten.is_empty():
			continue
		varianten.append([name_, func() -> void:
			for k: Node in knoten:
				if is_instance_valid(k):
					(k as Node3D).visible = false,
			func() -> void:
				for k: Node in knoten:
					if is_instance_valid(k):
						(k as Node3D).visible = true])
	var aus := {}
	for bp: Array in BLICKPUNKTE.get(region, []):
		var ort: Vector2 = bp[1]
		var ziel: Vector2 = bp[2]
		var y := float(g.hoehe_bei(ort.x, ort.y)) + 0.3 if g != null else 0.0
		sp.global_position = Vector3(ort.x, y, ort.y)
		sp.velocity = Vector3.ZERO
		dreh.rotation.y = atan2(-(ziel.x - ort.x), -(ziel.y - ort.y))
		for i in 120:
			await process_frame
		var zeilen: Array = []
		var basis := await _messe_bilder("alles")
		zeilen.append(basis)
		for v: Array in varianten:
			(v[1] as Callable).call()
			for i in 20:
				await process_frame
			var z := await _messe_bilder(v[0])
			(v[2] as Callable).call()
			for i in 60:                # SDFGI und Schatten bauen sich nach dem Wiedereinschalten erst auf
				await process_frame
			z["gpu_ersparnis_ms"] = snappedf(float(basis["gpu_ms"]) - float(z["gpu_ms"]), 0.01)
			z["render_cpu_ersparnis_ms"] = snappedf(float(basis["render_cpu_ms"]) - float(z["render_cpu_ms"]), 0.01)
			zeilen.append(z)
		var ende := await _messe_bilder("alles_am_ende")
		zeilen.append(ende)
		aus[bp[0]] = zeilen
	return aus


## Medianwerte über N Bilder
func _messe_bilder(name_: String) -> Dictionary:
	var anzahl := int(_args.get("bilder", "60"))
	var rid := root.get_viewport_rid()
	var spalten := {"gpu_ms": [], "render_cpu_ms": [], "frame_ms": [], "draw_calls": [], "dreiecke": []}
	var t := Time.get_ticks_usec()
	for i in anzahl:
		await process_frame
		var jetzt := Time.get_ticks_usec()
		(spalten["frame_ms"] as Array).append((jetzt - t) / 1000.0)
		t = jetzt
		(spalten["gpu_ms"] as Array).append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		(spalten["render_cpu_ms"] as Array).append(RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu())
		(spalten["draw_calls"] as Array).append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		(spalten["dreiecke"] as Array).append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var z := {"variante": name_}
	for k: String in spalten:
		var w := PackedFloat64Array(spalten[k] as Array)
		w.sort()
		z[k] = snappedf(_q(w, 0.5), 0.01)
	return z


func _zaehle_szene() -> Dictionary:
	var je: Dictionary = {}     # Herkunft → Zählwerte
	var gesamt := {"knoten": 0, "meshes": 0, "oberflaechen": 0, "dreiecke": 0, "multimesh": 0, "exemplare": 0,
		"exemplar_dreiecke": 0, "lichter": 0, "lichter_mit_schatten": 0, "kollisionskoerper": 0, "mit_sichtweite": 0}
	var alle := _instanz.find_children("*", "", true, false)
	gesamt["knoten"] = alle.size()
	for n: Node in alle:
		var k := _herkunft(n)
		if not je.has(k):
			je[k] = {"meshes": 0, "oberflaechen": 0, "dreiecke": 0, "exemplare": 0, "lichter": 0}
		var e: Dictionary = je[k]
		if n is GeometryInstance3D and ((n as GeometryInstance3D).visibility_range_end > 0.0 or (n as GeometryInstance3D).visibility_range_begin > 0.0):
			gesamt["mit_sichtweite"] += 1
		if n is MultiMeshInstance3D:
			var mm := (n as MultiMeshInstance3D).multimesh
			gesamt["multimesh"] += 1
			if mm != null:
				var anz := mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
				gesamt["exemplare"] += anz
				e["exemplare"] += anz
				if mm.mesh != null:
					gesamt["exemplar_dreiecke"] += _dreiecke(mm.mesh) * anz
		elif n is MeshInstance3D:
			var m := (n as MeshInstance3D).mesh
			gesamt["meshes"] += 1
			e["meshes"] += 1
			if m != null:
				var d := _dreiecke(m)
				gesamt["oberflaechen"] += m.get_surface_count()
				gesamt["dreiecke"] += d
				e["oberflaechen"] += m.get_surface_count()
				e["dreiecke"] += d
		elif n is Light3D:
			gesamt["lichter"] += 1
			e["lichter"] += 1
			if (n as Light3D).shadow_enabled:
				gesamt["lichter_mit_schatten"] += 1
		elif n is CollisionObject3D:
			gesamt["kollisionskoerper"] += 1
	return {"gesamt": gesamt, "je_herkunft": je}


static func _dreiecke(m: Mesh) -> int:
	var summe := 0
	for s in m.get_surface_count():
		var a := m.surface_get_arrays(s)
		var idx: Variant = a[Mesh.ARRAY_INDEX]
		if idx != null and (idx as PackedInt32Array).size() > 0:
			summe += (idx as PackedInt32Array).size() / 3
		else:
			summe += (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return summe


func _ready_tabelle() -> Array:
	var t: Array = []
	for k: String in _ready_zeiten:
		var e: Array = _ready_zeiten[k]
		t.append({"bauart": k, "anzahl": e[0], "ms": snappedf(float(e[1]) / 1000.0, 0.1)})
	t.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["ms"]) > float(b["ms"]))
	return t


func _langsamste(anzahl: int) -> Array:
	_einzeln.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
	var t: Array = []
	for e: Array in _einzeln.slice(0, anzahl):
		t.append({"ms": snappedf(float(e[0]) / 1000.0, 0.1), "bauart": e[1], "knoten": e[2]})
	return t


## p50/p95/p99/Max je Messwert einer Phase, Hänger über 33 und 50 ms
func _statistik(phase: String) -> Dictionary:
	var spalten := ["frame_ms", "prozess_spitze_ms", "physik_spitze_ms", "draw_calls", "dreiecke", "objekte", "speicher_mb", "grafikspeicher_mb", "render_cpu_ms", "gpu_ms"]
	# (gepackte Arrays sind Werte: erst als Array sammeln, dann umwandeln)
	var werte: Array = []
	for i in spalten.size():
		werte.append([])
	for f: Array in _frames:
		if f[0] == phase:
			for i in spalten.size():
				(werte[i] as Array).append(float(f[i + 1]))
	var aus := {"bilder": (werte[0] as Array).size()}
	if (werte[0] as Array).is_empty():
		return aus
	for i in spalten.size():
		var w := PackedFloat64Array(werte[i] as Array)
		w.sort()
		aus[spalten[i]] = {"p50": snappedf(_q(w, 0.5), 0.01), "p95": snappedf(_q(w, 0.95), 0.01),
			"p99": snappedf(_q(w, 0.99), 0.01), "max": snappedf(w[w.size() - 1], 0.01)}
	var ft := PackedFloat64Array(werte[0] as Array)
	var ueber33 := 0
	var ueber50 := 0
	for v in ft:
		if v > 33.3:
			ueber33 += 1
		if v > 50.0:
			ueber50 += 1
	var summe := 0.0
	for v in ft:
		summe += v
	aus["dauer_s"] = snappedf(summe / 1000.0, 0.1)
	aus["haenger_ueber_33ms"] = ueber33
	aus["haenger_ueber_50ms"] = ueber50
	aus["fps_mittel"] = snappedf(ft.size() / maxf(summe / 1000.0, 0.001), 0.1)
	return aus


static func _q(w: PackedFloat64Array, q: float) -> float:
	return w[clampi(int(round(q * (w.size() - 1))), 0, w.size() - 1)]


## Wechsel der Sichtweiten-Stufen (visibility_range) entlang der aufgezeichneten Kamerafahrt: wie oft ein Knoten
## ein- oder ausgeblendet wird, und wie oft das näher als NAH Meter geschieht (sichtbares Aufploppen).
func _lod_wechsel() -> Dictionary:
	var knoten: Array = []
	for n: Node in _instanz.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		if gi.visibility_range_end > 0.0 or gi.visibility_range_begin > 0.0:
			knoten.append([gi.global_position, gi.visibility_range_begin, gi.visibility_range_end,
				gi.get_aabb().get_longest_axis_size() * gi.global_basis.get_scale().abs().x,
				gi.visibility_range_fade_mode != GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED])
	var bahn: Array = []
	var t := 0.0
	for f: Array in _frames:
		if f[0] != "fahrt":
			continue
		t += float(f[1])
		if t >= 100.0 or bahn.is_empty():         # alle 0,1 s ein Punkt
			bahn.append(f[11])
			t = 0.0
	var wechsel := 0
	var nah := 0
	var sichtbar_hart := 0       # ohne Überblendung und auf dem Bild größer als SICHTBAR (Bogenmaß): echtes Aufploppen
	var weich := 0
	if bahn.size() >= 2:
		for k: Array in knoten:
			var p: Vector3 = k[0]
			var b: float = k[1]
			var e: float = k[2]
			var groesse: float = k[3]
			var blendet: bool = k[4]
			var vorher := -1
			for c: Vector3 in bahn:
				var d := c.distance_to(p)
				var an := 1 if d >= b and (e <= 0.0 or d < e) else 0
				if vorher >= 0 and an != vorher:
					wechsel += 1
					if d < NAH:
						nah += 1
					if blendet:
						weich += 1
					elif groesse / maxf(d, 0.1) > SICHTBAR:
						sichtbar_hart += 1
				vorher = an
	var sek := bahn.size() * 0.1
	return {"knoten_mit_sichtweite": knoten.size(), "bahnpunkte": bahn.size(), "wechsel": wechsel,
		"wechsel_pro_s": snappedf(wechsel / maxf(sek, 0.1), 0.01), "nahe_wechsel_unter_50m": nah,
		"weich_ueberblendet": weich, "sichtbar_hart": sichtbar_hart}


func _system() -> Dictionary:
	var v := Engine.get_version_info()
	return {"godot": "%d.%d.%d.%s" % [v["major"], v["minor"], v["patch"], v["status"]], "os": OS.get_name(),
		"cpu": OS.get_processor_name(), "kerne": OS.get_processor_count(),
		"grafik": RenderingServer.get_video_adapter_name(), "grafik_hersteller": RenderingServer.get_video_adapter_vendor(),
		"anzeige": DisplayServer.get_name(), "fenster": str(DisplayServer.window_get_size()),
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method"))}


func _schreibe(e: Dictionary) -> void:
	var ordner: String = _args.get("ausgabe", "user://messungen/")
	if not ordner.ends_with("/"):
		ordner += "/"
	DirAccess.make_dir_recursive_absolute(ordner)
	var stempel := Time.get_datetime_string_from_system().replace(":", "-")
	var basis := "%smessung_%s_%s_%s" % [ordner, e["region"], e["name"], stempel]
	var f := FileAccess.open(basis + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(e, "\t"))
	f.close()
	var text := _zusammenfassung(e)
	f = FileAccess.open(basis + ".txt", FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print(text)
	print("MESSUNG geschrieben: %s.json (%s)" % [basis, ProjectSettings.globalize_path(basis + ".json")])


func _zusammenfassung(e: Dictionary) -> String:
	var z: PackedStringArray = []
	var sy: Dictionary = e["system"]
	z.append("Messung %s, Region %s, Strecke %s, %s" % [e["name"], e["region"], e["strecke"], e["zeit"]])
	z.append("System: Godot %s, %s, %s (%d Kerne), Grafik: %s, Anzeige %s %s" % [sy["godot"], sy["os"], sy["cpu"],
		sy["kerne"], sy["grafik"], sy["anzeige"], sy["fenster"]])
	var l: Dictionary = e["laden"]
	z.append("Laden: Datei %.0f ms, Instanziieren %.0f ms, Einhängen+_ready %.0f ms, bis 5 Bilder %.0f ms" % [
		l["datei_ms"], l["instanziieren_ms"], l["einhaengen_und_ready_ms"], l["bis_5_bilder_ms"]])
	z.append("  _ready je Bauart (die größten):")
	for r: Dictionary in (e["ready_je_bauart"] as Array).slice(0, 10):
		z.append("    %-22s %5d Knoten %9.1f ms" % [r["bauart"], r["anzahl"], r["ms"]])
	var g: Dictionary = (e["szene"] as Dictionary)["gesamt"]
	z.append("Szene: %d Knoten, %d Meshes (%d Oberflächen, %d Dreiecke), %d MultiMesh (%d Exemplare, %d Dreiecke), %d Lichter (%d mit Schatten), %d Kollisionskörper, %d mit Sichtweite" % [
		g["knoten"], g["meshes"], g["oberflaechen"], g["dreiecke"], g["multimesh"], g["exemplare"],
		g["exemplar_dreiecke"], g["lichter"], g["lichter_mit_schatten"], g["kollisionskoerper"], g["mit_sichtweite"]])
	var fa: Dictionary = e["fahrt"]
	if not fa.is_empty():
		z.append("Fahrt: %d von %d Wegpunkten in %.0f s%s" % [fa["erreicht"], fa["punkte"], fa["dauer_s"],
			"" if fa["abbruch"] == "" else " (" + String(fa["abbruch"]) + ")"])
	for ph: String in ["anlauf", "messfahrt", "rundblick"]:
		var s: Dictionary = e[ph]
		if not s.has("frame_ms"):
			continue
		var ft: Dictionary = s["frame_ms"]
		z.append("%s: %d Bilder, %.1f fps; Frame p50 %.1f / p95 %.1f / p99 %.1f / max %.1f ms; Hänger >33 ms: %d, >50 ms: %d" % [
			ph.capitalize(), s["bilder"], s["fps_mittel"], ft["p50"], ft["p95"], ft["p99"], ft["max"],
			s["haenger_ueber_33ms"], s["haenger_ueber_50ms"]])
		z.append("    Render-CPU p50 %.1f / p95 %.1f ms, Grafikkarte p50 %.1f / p95 %.1f ms" % [
			(s["render_cpu_ms"] as Dictionary)["p50"], (s["render_cpu_ms"] as Dictionary)["p95"],
			(s["gpu_ms"] as Dictionary)["p50"], (s["gpu_ms"] as Dictionary)["p95"]])
		z.append("    Prozess-Spitze/s p50 %.1f ms, Physik-Spitze/s p50 %.1f ms, Draw Calls p95 %.0f, Dreiecke p95 %.0f, Objekte p95 %.0f, Speicher max %.0f MB, Grafikspeicher max %.0f MB" % [
			(s["prozess_spitze_ms"] as Dictionary)["p50"], (s["physik_spitze_ms"] as Dictionary)["p50"], (s["draw_calls"] as Dictionary)["p95"],
			(s["dreiecke"] as Dictionary)["p95"], (s["objekte"] as Dictionary)["p95"], (s["speicher_mb"] as Dictionary)["max"],
			(s["grafikspeicher_mb"] as Dictionary)["max"]])
	var lo: Dictionary = e["lod"]
	z.append("Sichtweiten-Wechsel (LOD): %d Knoten mit Sichtweite, %d Wechsel (%.2f/s), davon %d näher als 50 m, %d weich überblendet, %d hart und sichtbar (Aufploppen)" % [
		lo["knoten_mit_sichtweite"], lo["wechsel"], lo["wechsel_pro_s"], lo["nahe_wechsel_unter_50m"], lo["weich_ueberblendet"], lo["sichtbar_hart"]])
	var au: Dictionary = e.get("aufschluesselung", {})
	for bp: String in au:
		var zeilen: Array = au[bp]
		var b: Dictionary = zeilen[0]
		z.append("Aufschlüsselung %s: alles an: Grafikkarte %.2f ms, Render-CPU %.2f ms, Frame %.2f ms, %d Draw Calls, %.1f Mio. Dreiecke; am Ende wieder %.2f ms (Drift)" % [
			bp, b["gpu_ms"], b["render_cpu_ms"], b["frame_ms"], b["draw_calls"], float(b["dreiecke"]) / 1e6, (zeilen[zeilen.size() - 1] as Dictionary)["gpu_ms"]])
		var rang := zeilen.slice(1, zeilen.size() - 1)
		rang.sort_custom(func(a: Dictionary, c: Dictionary) -> bool: return float(a["gpu_ersparnis_ms"]) > float(c["gpu_ersparnis_ms"]))
		for r: Dictionary in rang:
			z.append("    ohne %-18s Grafikkarte −%5.2f ms (%4.1f %%), Render-CPU −%5.2f ms, Draw Calls %6d, Dreiecke %5.1f Mio." % [
				r["variante"], r["gpu_ersparnis_ms"], 100.0 * float(r["gpu_ersparnis_ms"]) / maxf(float(b["gpu_ms"]), 0.001),
				r["render_cpu_ersparnis_ms"], r["draw_calls"], float(r["dreiecke"]) / 1e6])
	if DisplayServer.get_name() == "headless":
		z.append("Hinweis: ohne Grafik gemessen, Draw Calls, Dreiecke je Bild und Grafikspeicher sind 0.")
	return "\n".join(z) + "\n"
