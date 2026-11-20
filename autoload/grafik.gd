extends Node
## Grafikstufen (docs/06-burg-standard.md): Niedrig, Mittel, Hoch, Episch.
##
## Hoch ist der Stand der Regionsszenen (Grafik-Paket B, docs/03-messgrundlage.md); für Hoch gilt das Budget aus der
## Messgrundlage (60 fps auf der Zielhardware). Episch nimmt alles, was Godot hergibt, und darf auf dem Referenzrechner
## bis 30 fps kosten. Die Stufe wird über die Szenen gelegt, sobald Umgebung und Sonne einer Region in den Baum kommen;
## die Szenen selbst bleiben unverändert.
##
## Wahl: Menü (Hauptmenü, Pause), gespeichert in user://einstellungen.cfg; das Startargument --grafik <stufe> geht vor
## (für Messungen: niedrig, mittel, hoch, episch).

signal geaendert(stufe: int)

enum { NIEDRIG, MITTEL, HOCH, EPISCH }
const NAMEN := ["Niedrig", "Mittel", "Hoch", "Episch"]
const DATEI := "user://einstellungen.cfg"

## Werte je Stufe
const STUFEN := [
	{   # Niedrig
		"msaa": Viewport.MSAA_DISABLED, "fxaa": true, "sdfgi": false, "sdfgi_stufen": 4, "ssao": false, "ssil": false,
		"ssr": false, "lichtnebel": false, "schattenkarte": 2048, "schatten_stufen": 2, "schatten_weite": 200.0,
		"weiche_schatten": 1, "ohne_schatten_unter": 2.0, "lod_schwelle": 2.0, "anisotrop": 2, "fern_schatten": false,
	},
	{   # Mittel
		"msaa": Viewport.MSAA_2X, "fxaa": false, "sdfgi": false, "sdfgi_stufen": 4, "ssao": true, "ssil": false,
		"ssr": false, "lichtnebel": false, "schattenkarte": 4096, "schatten_stufen": 2, "schatten_weite": 300.0,
		"weiche_schatten": 2, "ohne_schatten_unter": 1.0, "lod_schwelle": 1.5, "anisotrop": 4, "fern_schatten": false,
	},
	{   # Hoch: wie die Szenen und project.godot
		"msaa": Viewport.MSAA_2X, "fxaa": false, "sdfgi": true, "sdfgi_stufen": 4, "ssao": true, "ssil": true,
		"ssr": false, "lichtnebel": false, "schattenkarte": 4096, "schatten_stufen": 2, "schatten_weite": 500.0,
		"weiche_schatten": 3, "ohne_schatten_unter": 1.0, "lod_schwelle": 1.0, "anisotrop": 4, "fern_schatten": false,
	},
	{   # Episch
		"msaa": Viewport.MSAA_4X, "fxaa": false, "sdfgi": true, "sdfgi_stufen": 6, "ssao": true, "ssil": true,
		"ssr": true, "lichtnebel": true, "schattenkarte": 8192, "schatten_stufen": 4, "schatten_weite": 800.0,
		"weiche_schatten": 5, "ohne_schatten_unter": 0.0, "lod_schwelle": 0.5, "anisotrop": 16, "fern_schatten": true,
	},
]

var stufe := HOCH


func _ready() -> void:
	stufe = _gespeichert()
	var args := OS.get_cmdline_user_args()
	var i := args.find("--grafik")
	if i >= 0 and i + 1 < args.size():
		var n := NAMEN.map(func(s: String) -> String: return s.to_lower()).find(args[i + 1].to_lower())
		if n >= 0:
			stufe = n
	get_tree().node_added.connect(_bei_knoten)
	_anwenden_global()


## Stufe wählen, anwenden und speichern
func setze(neu: int) -> void:
	stufe = clampi(neu, NIEDRIG, EPISCH)
	_anwenden_global()
	var szene := get_tree().current_scene if is_inside_tree() else null
	if szene != null:
		for n in szene.find_children("*", "", true, false):
			_bei_knoten(n)
	var cfg := ConfigFile.new()
	cfg.load(DATEI)
	cfg.set_value("grafik", "stufe", stufe)
	cfg.save(DATEI)
	geaendert.emit(stufe)


func naechste() -> void:
	setze((stufe + 1) % NAMEN.size())


func name_() -> String:
	return NAMEN[stufe]


func wert(schluessel: String) -> Variant:
	return STUFEN[stufe][schluessel]


func _gespeichert() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(DATEI) != OK:
		return HOCH
	return clampi(int(cfg.get_value("grafik", "stufe", HOCH)), NIEDRIG, EPISCH)


## Was für den ganzen Bildschirm gilt (Fenster, RenderingServer)
func _anwenden_global() -> void:
	var w: Dictionary = STUFEN[stufe]
	var vp := get_viewport() if is_inside_tree() else null
	if vp == null:
		return
	vp.msaa_3d = w["msaa"]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if w["fxaa"] else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.mesh_lod_threshold = w["lod_schwelle"]
	if "anisotropic_filtering_level" in vp:
		vp.set("anisotropic_filtering_level", {2: 1, 4: 2, 8: 3, 16: 4}.get(int(w["anisotrop"]), 2))
	RenderingServer.directional_shadow_atlas_set_size(int(w["schattenkarte"]), true)
	RenderingServer.directional_soft_shadow_filter_set_quality(int(w["weiche_schatten"]))
	RenderingServer.positional_soft_shadow_filter_set_quality(int(w["weiche_schatten"]))
	if stufe == EPISCH:
		RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_ULTRA, false, 0.5, 3, 50.0, 300.0)
		RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_ULTRA, false, 0.5, 4, 50.0, 300.0)
		RenderingServer.environment_set_sdfgi_ray_count(RenderingServer.ENV_SDFGI_RAY_COUNT_64)
		RenderingServer.environment_set_volumetric_fog_volume_size(160, 128)
		RenderingServer.environment_set_volumetric_fog_filter_active(true)
	else:
		# Werte aus project.godot (Hoch und darunter)
		RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_HIGH, true, 0.5, 2, 50.0, 300.0)
		RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_MEDIUM, true, 0.5, 4, 50.0, 300.0)
		RenderingServer.environment_set_sdfgi_ray_count(RenderingServer.ENV_SDFGI_RAY_COUNT_16)
		RenderingServer.environment_set_volumetric_fog_volume_size(64, 64)


## Umgebung, Sonne und Region einer Szene anpassen, sobald sie in den Baum kommen
func _bei_knoten(n: Node) -> void:
	var w: Dictionary = STUFEN[stufe]
	if n is WorldEnvironment and (n as WorldEnvironment).environment != null:
		var env := (n as WorldEnvironment).environment
		if not env.has_meta("grafik_hoch"):
			# die Werte der Szene merken (das ist Hoch), damit der Wechsel zurück sie wiederherstellt
			env.set_meta("grafik_hoch", {"sdfgi": env.sdfgi_enabled, "sdfgi_stufen": env.sdfgi_cascades,
				"ssao": env.ssao_enabled, "ssil": env.ssil_enabled, "ssr": env.ssr_enabled,
				"lichtnebel": env.volumetric_fog_enabled})
		var hoch: Dictionary = env.get_meta("grafik_hoch")
		env.sdfgi_enabled = hoch["sdfgi"] and w["sdfgi"]
		env.sdfgi_cascades = w["sdfgi_stufen"] if stufe == EPISCH else hoch["sdfgi_stufen"]
		env.ssao_enabled = hoch["ssao"] and w["ssao"]
		env.ssil_enabled = hoch["ssil"] and w["ssil"]
		env.ssr_enabled = w["ssr"] or hoch["ssr"]
		if w["ssr"]:
			env.ssr_max_steps = 96
			env.ssr_fade_in = 0.15
			env.ssr_fade_out = 2.0
			env.ssr_depth_tolerance = 0.25
		env.volumetric_fog_enabled = w["lichtnebel"] or hoch["lichtnebel"]
		if w["lichtnebel"] and not hoch["lichtnebel"]:
			# zarter Lichtnebel: Sonnenstrahlen in Durchgängen und über dem Wasser, ohne die Fernsicht zu nehmen
			env.volumetric_fog_density = 0.004
			env.volumetric_fog_albedo = Color(0.95, 0.9, 0.82)
			env.volumetric_fog_anisotropy = 0.6
			env.volumetric_fog_length = 180.0
			env.volumetric_fog_detail_spread = 2.0
			env.volumetric_fog_sky_affect = 0.0
	elif n is DirectionalLight3D:     # auch wenn das Tageslicht die Schatten gerade abgeschaltet hat (Nacht)
		var l := n as DirectionalLight3D
		l.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if int(w["schatten_stufen"]) == 4 \
			else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		l.directional_shadow_max_distance = w["schatten_weite"]
	elif n is GeometryInstance3D and n.is_in_group("fern_schatten"):
		# Fernfassung der Bäume: Schatten nur in Episch (die Laubkarten in allen Schattenstufen kosten viel)
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if w["fern_schatten"] \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	elif n.has_method("_schatten_pruefen") and "ohne_schatten_unter" in n:
		n.set("ohne_schatten_unter", w["ohne_schatten_unter"])
