extends SceneTree

func _initialize() -> void:
	await process_frame
	var SP = root.get_node("Speicher"); var Z = root.get_node("Spielzeit")
	SP.ordner = "user://speicher_foto/"
	root.get_node("Ladevorhang").aus = true
	SP.neues_spiel("Ansel")
	await scene_changed
	for i in 5: await process_frame
	current_scene.get_node("Entwickler").ueberspringe_akt1()
	Z.sekunden_pro_tag = 1e9
	Z.minuten = 10.5 * 60.0
	Z.vorspulen(0.0)
	var s = current_scene.get_node("Spieler")
	for i in 30: await process_frame
	s.global_position = Vector3(60, -5.5, 24)
	s.velocity = Vector3.ZERO
	s.get_node("KameraDrehpunkt").rotation.y = atan2(-8.0, 22.0)
	for i in 90: await process_frame
	print("POS ", s.global_position)
	var BC = load("res://szenen/welt/baucache.gd")
	print("CACHE treffer=%d gebaut=%d" % [BC.treffer, BC.gebaut])
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("FOTO"))
	quit()
