extends SceneTree
## Tests für die Grafikstufen (autoload/grafik.gd): Hoch lässt die Szene, wie sie ist; Episch schaltet alles ein,
## Niedrig spart; der Wechsel zurück stellt die Werte der Szene wieder her; die Wahl wird gespeichert; eine Region
## bekommt die Stufe beim Laden.
## Starten: godot --headless --path . --script res://tests/test_grafik.gd

const REGION := "res://szenen/welt/region_drachenstein.tscn"

var fehler := 0


func pruefe(bed: bool, was: String) -> void:
	if bed:
		print("OK     ", was)
	else:
		fehler += 1
		print("FEHLER ", was)


func _initialize() -> void:
	var G = root.get_node("Grafik")
	var alt_cfg := FileAccess.get_file_as_string(G.DATEI) if FileAccess.file_exists(G.DATEI) else ""
	await process_frame
	G.setze(G.HOCH)

	# Eine kleine Szene wie eine Region: Umgebung mit den Werten von Hoch, Sonne mit Schatten
	var wurzel := Node3D.new()
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.sdfgi_enabled = true
	env.sdfgi_cascades = 4
	env.ssao_enabled = true
	env.ssil_enabled = true
	we.environment = env
	wurzel.add_child(we)
	var sonne := DirectionalLight3D.new()
	sonne.shadow_enabled = true
	sonne.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sonne.directional_shadow_max_distance = 500.0
	wurzel.add_child(sonne)
	root.add_child(wurzel)
	current_scene = wurzel
	await process_frame
	pruefe(env.sdfgi_enabled and env.sdfgi_cascades == 4 and env.ssao_enabled and env.ssil_enabled and not env.ssr_enabled
		and not env.volumetric_fog_enabled and sonne.directional_shadow_max_distance == 500.0
		and root.msaa_3d == Viewport.MSAA_2X, "Hoch: Szene unverändert (SDFGI 4 Stufen, SSAO, SSIL, Schatten 500 m, MSAA 2×)")

	G.setze(G.EPISCH)
	pruefe(env.sdfgi_cascades == 6 and env.ssr_enabled and env.volumetric_fog_enabled and env.volumetric_fog_density > 0.0
		and sonne.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		and sonne.directional_shadow_max_distance == 800.0 and root.msaa_3d == Viewport.MSAA_4X,
		"Episch: SDFGI 6 Stufen, Spiegelungen, Lichtnebel, Schatten in 4 Stufen bis 800 m, MSAA 4×")

	G.setze(G.NIEDRIG)
	pruefe(not env.sdfgi_enabled and not env.ssao_enabled and not env.ssil_enabled and not env.ssr_enabled
		and not env.volumetric_fog_enabled and sonne.directional_shadow_max_distance == 200.0
		and root.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA,
		"Niedrig: ohne SDFGI, SSAO, SSIL, Spiegelungen und Lichtnebel, Schatten bis 200 m, FXAA")

	G.setze(G.HOCH)
	pruefe(env.sdfgi_enabled and env.sdfgi_cascades == 4 and env.ssao_enabled and env.ssil_enabled and not env.ssr_enabled
		and not env.volumetric_fog_enabled and sonne.directional_shadow_max_distance == 500.0
		and sonne.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
		"Zurück auf Hoch: wieder genau die Werte der Szene")

	G.setze(G.EPISCH)
	pruefe(G._gespeichert() == G.EPISCH, "Die Wahl wird gespeichert (user://einstellungen.cfg)")
	wurzel.free()

	# Eine Region bekommt die Stufe beim Laden
	var r: Node = (load(REGION) as PackedScene).instantiate()
	root.add_child(r)
	current_scene = r
	await process_frame
	var renv: Environment = r.get_node("Umgebung").environment
	var rsonne: DirectionalLight3D = r.get_node("Sonne")
	pruefe(renv.sdfgi_cascades == 6 and renv.ssr_enabled and rsonne.directional_shadow_max_distance == 800.0
		and float(r.get("ohne_schatten_unter")) == 0.0,
		"Drachenstein in Episch geladen: SDFGI 6 Stufen, Spiegelungen, Schatten bis 800 m, auch kleine Dinge mit Schatten")
	G.setze(G.HOCH)
	print("       Region nach Hoch: SDFGI %d Stufen, SSR %s, Schatten %.0f m" % [renv.sdfgi_cascades, renv.ssr_enabled, rsonne.directional_shadow_max_distance])
	pruefe(renv.sdfgi_cascades == 4 and not renv.ssr_enabled and rsonne.directional_shadow_max_distance == 500.0,
		"Drachenstein zurück auf Hoch: Werte der Szene")
	r.free()

	# Einstellungen wie vorher
	if alt_cfg == "":
		DirAccess.remove_absolute(G.DATEI)
	else:
		var f := FileAccess.open(G.DATEI, FileAccess.WRITE)
		f.store_string(alt_cfg)
	print("\nFehler: %d" % fehler)
	quit(1 if fehler > 0 else 0)
