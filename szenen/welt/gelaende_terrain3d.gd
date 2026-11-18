extends RefCounted
## Baut die Darstellung des Geländes mit Terrain3D (addons/terrain_3d) aus denselben Höhendaten wie das eigene
## Gelände (szenen/welt/gelaende.gd). Terrain3D zeichnet ein Gitter um die Kamera, das nach außen gröber wird
## (Detailstufen auf der Grafikkarte, ohne Aufploppen); die Höhen liegen als Texturen auf der Grafikkarte.
##
## Nur die Darstellung kommt von Terrain3D: Kollision, hoehe_bei() und die Löcher (Tunnel) baut weiter gelaende.gd,
## damit Personen, Tiere und alles, was auf den Boden gesetzt wird, genau wie bisher funktionieren.
## Farbe und Normalen kommen aus unserem Geländematerial (gelaende_t3d.gdshader, erzeugt von
## werkzeuge/gelaende_t3d_shader.gd), die Parameter aus dem Material des Geländeknotens.

const SHADER := "res://szenen/welt/gelaende_t3d.gdshader"
## Größe einer Terrain3D-Region in Rasterpunkten (64 bis 2048)
const REGION := 256
## Bit "Loch" in der Steuerkarte von Terrain3D
const LOCH_BIT := 4


static func verfuegbar() -> bool:
	return ClassDB.class_exists("Terrain3D") and ResourceLoader.exists(SHADER)


## Legt den Terrain3D-Knoten unter g (gelaende.gd) an und gibt ihn zurück (null, wenn Terrain3D fehlt).
static func baue(g: Node3D) -> Node3D:
	if not verfuegbar():
		push_warning("Terrain3D ist nicht verfügbar, das Gelände wird selbst gebaut.")
		return null
	var t: Node3D = ClassDB.instantiate("Terrain3D")
	t.name = "Terrain3D"
	t.set("debug_level", 0)
	t.set("region_size", REGION)
	t.set("vertex_spacing", g.abstand)
	t.set("free_editor_textures", false)
	t.set("assets", _assets_mit_platzhalter())
	var m: Resource = t.get("material")
	m.set("world_background", 0)              # NONE: außerhalb der Daten kein Gelände
	m.set("auto_shader_enabled", false)
	m.set("shader_override", load(SHADER))
	m.set("shader_override_enabled", true)
	g.add_child(t)
	t.set("collision_mode", 0)                # DISABLED: die Kollision baut gelaende.gd (geht erst im Baum)
	_uebernimm_parameter(m, g.material)
	_lade_hoehen(t, g)
	_folge_kamera.call_deferred(t)
	return t


## Terrain3D legt ein Karomuster über das Gelände, solange seine Texturliste leer ist, auch über einen eigenen
## Shader. Wir zeichnen mit unserem Material und brauchen die Liste nicht; ein winziger Platzhalter hält sie besetzt.
static func _assets_mit_platzhalter() -> Resource:
	var assets: Resource = ClassDB.instantiate("Terrain3DAssets")
	var farbe := Image.create(4, 4, true, Image.FORMAT_RGBA8)
	farbe.fill(Color(0.5, 0.5, 0.5, 0.5))
	farbe.generate_mipmaps()
	var normale := Image.create(4, 4, true, Image.FORMAT_RGBA8)
	normale.fill(Color(0.5, 0.5, 1.0, 0.8))
	normale.generate_mipmaps()
	var platzhalter: Resource = ClassDB.instantiate("Terrain3DTextureAsset")
	platzhalter.set("name", "Platzhalter")
	platzhalter.set("albedo_texture", ImageTexture.create_from_image(farbe))
	platzhalter.set("normal_texture", ImageTexture.create_from_image(normale))
	assets.call("set_texture_asset", 0, platzhalter)
	return assets


## Die Parameter unseres Geländematerials (Texturen, Maske, Pflasterflächen, Färbung) in das Terrain3D-Material
static func _uebernimm_parameter(m: Resource, quelle: Material) -> void:
	var sm := quelle as ShaderMaterial
	if sm == null or sm.shader == null:
		return
	for u: Dictionary in sm.shader.get_shader_uniform_list():
		var wert: Variant = sm.get_shader_parameter(u["name"])
		if wert != null:
			m.call("set_shader_param", u["name"], wert)


## Höhen und Löcher als Bilder in Terrain3D. Das Bild deckt ganze Regionen ab; um die Daten herum liegt ein Rand von
## einem Rasterpunkt mit der Randhöhe, alles weiter außen ist Loch (sonst stünde dort Gelände auf Höhe 0).
static func _lade_hoehen(t: Node3D, g: Node3D) -> void:
	var br: int = g.breite
	var tf: int = g.tiefe
	var ox := roundi(g.ursprung.x / g.abstand)
	var oz := roundi(g.ursprung.y / g.abstand)
	var ax := floori((ox - 1) / float(REGION)) * REGION
	var az := floori((oz - 1) / float(REGION)) * REGION
	var w := ceili((ox + br + 1) / float(REGION)) * REGION - ax
	var d := ceili((oz + tf + 1) / float(REGION)) * REGION - az
	var x0 := ox - ax - 1                      # erste Spalte mit Gelände (Rand)
	var z0 := oz - az - 1
	var hoehen: PackedFloat32Array = g._hoehen

	# Höhen: Zeile für Zeile, links und rechts um je einen Randpunkt verlängert
	var leer_h := PackedFloat32Array()
	leer_h.resize(w)
	var h_bytes := PackedByteArray()
	for z in d:
		var dz := z - z0 - 1
		if dz < -1 or dz > tf:
			h_bytes.append_array(leer_h.to_byte_array())
			continue
		var reihe := clampi(dz, 0, tf - 1)
		var zeile := PackedFloat32Array()
		zeile.resize(x0)
		zeile.append(hoehen[reihe * br])
		zeile.append_array(hoehen.slice(reihe * br, (reihe + 1) * br))
		zeile.append(hoehen[reihe * br + br - 1])
		zeile.resize(w)
		h_bytes.append_array(zeile.to_byte_array())

	# Steuerkarte: überall Loch, außer im Datenbereich mit Rand; dazu die Löcher aus gelaende.gd
	var loch_zeile := PackedByteArray()
	loch_zeile.resize(w * 4)
	for x in w:
		loch_zeile.encode_u32(x * 4, LOCH_BIT)
	var daten_zeile := loch_zeile.duplicate()
	for x in range(x0, x0 + br + 2):
		daten_zeile.encode_u32(x * 4, 0)
	var s_bytes := PackedByteArray()
	for z in d:
		s_bytes.append_array(daten_zeile if z >= z0 and z < z0 + tf + 2 else loch_zeile)
	var lochmaske: PackedByteArray = g._loch
	for dz in tf:
		for dx in br:
			if lochmaske[dz * br + dx] == 1:
				s_bytes.encode_u32(((dz + z0 + 1) * w + dx + x0 + 1) * 4, LOCH_BIT)

	var hoehe_bild := Image.create_from_data(w, d, false, Image.FORMAT_RF, h_bytes)
	var steuer_bild := Image.create_from_data(w, d, false, Image.FORMAT_RF, s_bytes)
	var daten: Object = t.get("data")
	daten.call("import_images", [hoehe_bild, steuer_bild, null], Vector3(ax * g.abstand, 0.0, az * g.abstand), 0.0, 1.0)


## Terrain3D richtet das feine Gitter an der Kamera aus; die Kamera kann wechseln (Spieler, Messfahrt, Entwickler).
static func _folge_kamera(t: Node3D) -> void:
	if not is_instance_valid(t) or not t.is_inside_tree():
		return
	var kamera := t.get_viewport().get_camera_3d()
	if kamera != null and t.call("get_camera") != kamera:
		t.call("set_camera", kamera)
	t.get_tree().create_timer(0.25).timeout.connect(_folge_kamera.bind(t))
