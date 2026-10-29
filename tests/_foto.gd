extends SceneTree
## Fotos für die Grafikarbeit. Umgebung: FOTOS="datei|x,y,z|zx,zy,zz|stunde;..." REGION=drachenstein
func _initialize() -> void:
	await process_frame
	var SP = root.get_node("Speicher"); var Z = root.get_node("Spielzeit")
	SP.ordner = "user://speicher_foto/"
	SP.neues_spiel("Ansel")
	await scene_changed
	for i in 5: await process_frame
	current_scene.get_node("Entwickler").ueberspringe_akt1()
	var region := OS.get_environment("REGION")
	if region != "" and region != "drachenstein":
		var alt := current_scene.get_instance_id()
		current_scene.get_node("Entwickler").reise(region)
		while current_scene == null or current_scene.get_instance_id() == alt:
			await process_frame
		for i in 10: await process_frame
	Z.sekunden_pro_tag = 1e9
	for knoten in current_scene.find_children("*", "CanvasLayer", true, false):
		knoten.visible = false
	var kamera := Camera3D.new()
	kamera.fov = 70
	kamera.far = 3000
	current_scene.add_child(kamera)
	kamera.make_current()
	for eintrag in OS.get_environment("FOTOS").split(";", false):
		var t := eintrag.split("|")
		var p := t[1].split_floats(","); var z := t[2].split_floats(",")
		Z.minuten = float(t[3]) * 60.0
		Z.vorspulen(0.0)
		var gl = current_scene.get_node("Gelaende")
		# Höhe mit "~" davor: über dem Boden
		var py: float = gl.hoehe_bei(p[0], p[2]) + float(t[1].split(",")[1].substr(1)) if t[1].split(",")[1].begins_with("~") else p[1]
		var zy: float = gl.hoehe_bei(z[0], z[2]) + float(t[2].split(",")[1].substr(1)) if t[2].split(",")[1].begins_with("~") else z[1]
		kamera.global_position = Vector3(p[0], py, p[2])
		kamera.look_at(Vector3(z[0], zy, z[2]))
		var hinten := kamera.global_position + kamera.global_basis.z.slide(Vector3.UP).normalized() * 4.0
		var g = current_scene.get_node("Gelaende")
		current_scene.get_node("Spieler").global_position = Vector3(hinten.x, g.hoehe_bei(hinten.x, hinten.z) + 0.3, hinten.z)
		for i in 40: await process_frame
		root.get_viewport().get_texture().get_image().save_png(t[0])
		print("FOTO ", t[0])
	quit()
