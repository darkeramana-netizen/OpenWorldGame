extends SceneTree
## Foto-Rundgang (docs/06-burg-standard.md, Abnahme): lädt eine Region und macht an festen Blickpunkten je ein Foto.
## Die Blickpunkte stehen als Daten in werkzeuge/rundgang/<region>.json (Kamera von, Ziel auf, Uhrzeit).
##
## Aufruf aus dem Projektordner (mit Grafik, also ohne --headless):
##   godot --path . --script res://werkzeuge/rundgang/rundgang.gd -- --grafik episch
## Weitere Angaben nach --: --region drachenstein, --nur 08_markt (nur Blickpunkte, deren Name so beginnt;
## mehrere mit Komma: --nur 14,15), --aufloesung 1920x1080, --ausgabe <Ordner>. Die Fotos landen in user://rundgang/<region>_<Zeit>/ (unter Windows
## %APPDATA%\Godot\app_userdata\Sorrowland_ In Silentio\rundgang\); der Ordner steht am Ende der Ausgabe.

const WARTEN_MIN := 90       # so viele Bilder je Blickpunkt mindestens (SDFGI, Schatten und Ausblenden setzen sich)
const WARTEN_MAX_S := 20.0

var _args := {}


func _initialize() -> void:
	_lies_args()
	var region: String = _args.get("region", "drachenstein")
	var punkte_datei: String = _args.get("punkte", "res://werkzeuge/rundgang/%s.json" % region)
	var daten: Variant = JSON.parse_string(FileAccess.get_file_as_string(punkte_datei))
	if not daten is Dictionary:
		printerr("Rundgang: Blickpunkte fehlen (%s)" % punkte_datei)
		quit(1)
		return
	var aufl: String = _args.get("aufloesung", "")
	if aufl.contains("x"):
		root.get_window().size = Vector2i(int(aufl.get_slice("x", 0)), int(aufl.get_slice("x", 1)))
	var zeit := Time.get_datetime_string_from_system().replace(":", "-")
	var ausgabe: String = _args.get("ausgabe", "user://rundgang/%s_%s/" % [region, zeit])
	DirAccess.make_dir_recursive_absolute(ausgabe)

	root.get_node("Ladevorhang").aus = true
	var speicher := root.get_node("Speicher")
	var spielzeit := root.get_node("Spielzeit")
	speicher.ordner = "user://rundgang_speicher/"
	speicher.region = region
	spielzeit.process_mode = Node.PROCESS_MODE_DISABLED
	var szene: Node = (load(speicher.REGIONEN[region]) as PackedScene).instantiate()
	root.add_child(szene)
	current_scene = szene
	for i in 10:
		await process_frame
	# Alles auf dem Bildschirm (HUD, Entwickler-Anzeige, Meldungen) und den Spieler ausblenden
	for n in szene.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var spieler := szene.get_node_or_null("Spieler")
	if spieler is Node3D:
		(spieler as Node3D).visible = false
	var gelaende := szene.get_node_or_null("Gelaende")
	var kamera := Camera3D.new()
	kamera.fov = 70.0
	kamera.far = 8000.0
	szene.add_child(kamera)
	kamera.make_current()
	var zw := root.get_node("Zellwelt")

	var nur: String = _args.get("nur", "")
	var liste := PackedStringArray()
	for p: Dictionary in daten["punkte"]:
		if nur != "" and not Array(nur.split(",")).any(func(v: String) -> bool: return String(p["name"]).begins_with(v)):
			continue
		spielzeit.minuten = float(p.get("uhr", 10.0)) * 60.0
		kamera.global_position = _v(p["von"])
		if gelaende != null and gelaende.has_method("hoehe_bei") and not p.get("unter_tage", false):
			var boden: float = gelaende.hoehe_bei(kamera.global_position.x, kamera.global_position.z)
			if kamera.global_position.y < boden + 0.3:
				printerr("Rundgang: %s steht unter dem Gelände (Kamera %.1f, Boden %.1f); bitte in der JSON-Datei anheben"
					% [p["name"], kamera.global_position.y, boden])
		var ziel := _v(p["auf"])
		var oben := Vector3.UP if absf((ziel - kamera.global_position).normalized().y) < 0.99 else Vector3.FORWARD
		var verdeckt := kamera.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(kamera.global_position, ziel))
		if not verdeckt.is_empty() and kamera.global_position.distance_to(verdeckt["position"]) < 6.0:
			printerr("Rundgang: %s blickt nach %.1f m auf %s (steht die Kamera in einem Gebäude?)"
				% [p["name"], kamera.global_position.distance_to(verdeckt["position"]), verdeckt["collider"].name])
		kamera.look_at(ziel, oben)
		zw.pruefe_sofort()
		var ende := Time.get_ticks_msec() + int(WARTEN_MAX_S * 1000.0)
		var bilder := 0
		while (bilder < WARTEN_MIN or zw.wartend() > 0) and Time.get_ticks_msec() < ende:
			await process_frame
			bilder += 1
		var datei: String = ausgabe.path_join(String(p["name"]) + ".png")
		var bild := root.get_viewport().get_texture().get_image()
		if bild == null:
			printerr("Rundgang: kein Bild (ohne Grafik gestartet? Bitte ohne --headless)")
			continue
		bild.save_png(datei)
		liste.append("%s  (Uhr %.1f, Kamera %s → %s)" % [p["name"], float(p.get("uhr", 10.0)), str(p["von"]), str(p["auf"])])
		print("FOTO ", ProjectSettings.globalize_path(datei))
	var info := FileAccess.open(ausgabe.path_join("inhalt.txt"), FileAccess.WRITE)
	info.store_string("Rundgang %s, Grafik %s, %s\n%s\n" % [region, root.get_node("Grafik").name_(), zeit, "\n".join(liste)])
	info.close()
	print("RUNDGANG fertig: %d Fotos in %s" % [liste.size(), ProjectSettings.globalize_path(ausgabe)])
	quit(0)


func _v(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


func _lies_args() -> void:
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i < a.size():
		if a[i].begins_with("--") and i + 1 < a.size() and not a[i + 1].begins_with("--"):
			_args[a[i].substr(2)] = a[i + 1]
			i += 2
		else:
			i += 1
