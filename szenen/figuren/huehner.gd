extends Node3D
## Hühner auf dem Hof: eine kleine Schar (Hennen und ein Hahn) zieht in einem Kreis um den Ort des Knotens umher. Jedes
## Huhn pickt, scharrt mit den Füßen, sieht sich um und trippelt zu einer neuen Stelle, zu der der Weg frei ist (Strahl
## gegen Mauern, Häuser, Zäune). Kommt der Spieler oder eine gehende Person zu nahe, rennen sie mit schlagenden
## Flügeln ein Stück weg und beruhigen sich wieder. Jedes Ziel liegt auf der Oberfläche darunter (Hof, Boden eines
## Baus). Weit weg vom Spieler ruht alles.

@export var anzahl: int = 5
## Radius des Bereichs, in dem sie umherziehen
@export var weite: float = 3.5

const SCHEU := 2.6
const SICHT := 70.0
const GEHEN := 0.45
const RENNEN := 2.6

static var _meshes := {}
static var _mats := {}

var _huehner: Array[Dictionary] = []
var _zufall := RandomNumberGenerator.new()
var _pruef := 0.0
var _bereit := false


func _ready() -> void:
	_zufall.seed = hash(Vector2i(int(global_position.x * 5.0), int(global_position.z * 5.0)))
	for i in anzahl:
		var hahn := i == 0 and anzahl >= 3
		var gefieder: Color = [Color(0.55, 0.32, 0.16), Color(0.86, 0.83, 0.76), Color(0.16, 0.14, 0.13),
			Color(0.62, 0.45, 0.28)][_zufall.randi() % 4]
		if hahn:
			gefieder = Color(0.6, 0.27, 0.1)
		var h := Node3D.new()
		add_child(h)
		var w := _zufall.randf() * TAU
		h.position = Vector3(cos(w), 0, sin(w)) * _zufall.randf_range(0.3, weite * 0.8)
		h.rotation.y = _zufall.randf() * TAU
		var g := 1.15 if hahn else 1.0
		var koerper := _teil(h, "koerper", Vector3(0, 0.24, 0) * g, gefieder, g)
		var hals := _teil(koerper, "hals", Vector3(0, 0.09, -0.12) * g, gefieder, g)
		var kopf := _teil(hals, "kopf", Vector3(0, 0.08, -0.02) * g, gefieder, g)
		_teil(kopf, "schnabel", Vector3(0, -0.01, -0.06) * g, Color(0.85, 0.65, 0.2), g)
		_teil(kopf, "kamm_hahn" if hahn else "kamm", Vector3(0, 0.05, -0.005) * g, Color(0.75, 0.1, 0.08), g)
		_teil(kopf, "lappen", Vector3(0, -0.045, -0.04) * g, Color(0.72, 0.1, 0.08), g)
		var schwanz := _teil(koerper, "schwanz_hahn" if hahn else "schwanz", Vector3(0, 0.07, 0.15) * g,
			Color(0.08, 0.1, 0.09) if hahn else gefieder.darkened(0.15), g)
		schwanz.rotation.x = 0.7 if hahn else 0.45
		var fluegel := []
		for s in [-1.0, 1.0]:
			var gelenk := Node3D.new()
			gelenk.position = Vector3(s * 0.085, 0.04, -0.02) * g
			koerper.add_child(gelenk)
			_teil(gelenk, "fluegel", Vector3(s * 0.01, -0.01, 0.05) * g, gefieder.darkened(0.1), g)
			fluegel.append(gelenk)
		var beine := []
		for s in [-0.035, 0.035]:
			beine.append(_teil(h, "bein", Vector3(s, 0.07, 0.0) * g, Color(0.85, 0.66, 0.25), g))
		_huehner.append({"knoten": h, "koerper": koerper, "kopf": hals, "fluegel": fluegel, "beine": beine,
			"tun": "", "takt": _zufall.randf_range(0.2, 2.0), "dauer": 0.0, "ziel": h.position, "tempo": GEHEN, "phase": 0.0})
	_erde.call_deferred()


func _teil(eltern: Node3D, art: String, ort: Vector3, farbe: Color, g: float) -> Node3D:
	var schluessel := art + farbe.to_html()
	if not _meshes.has(art):
		var m := BoxMesh.new()
		m.size = {"koerper": Vector3(0.18, 0.17, 0.3), "hals": Vector3(0.08, 0.14, 0.08), "kopf": Vector3(0.07, 0.08, 0.09),
			"schnabel": Vector3(0.025, 0.022, 0.04), "kamm": Vector3(0.012, 0.03, 0.05), "kamm_hahn": Vector3(0.014, 0.06, 0.08),
			"lappen": Vector3(0.012, 0.035, 0.02), "schwanz": Vector3(0.1, 0.1, 0.05), "schwanz_hahn": Vector3(0.05, 0.22, 0.14),
			"fluegel": Vector3(0.03, 0.12, 0.22), "bein": Vector3(0.018, 0.14, 0.018)}[art]
		_meshes[art] = m
	if not _mats.has(schluessel):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = farbe
		mat.roughness = 0.95
		_mats[schluessel] = mat
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[art]
	mi.material_override = _mats[schluessel]
	mi.scale = Vector3.ONE * g
	mi.position = ort
	mi.visibility_range_end = SICHT
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if art != "koerper" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	eltern.add_child(mi)
	return mi


## Höhe der Oberfläche unter einem Punkt (lokal), oder NAN
func _boden(lokal: Vector3) -> float:
	var raum := get_world_3d().direct_space_state
	var p := to_global(Vector3(lokal.x, 0.0, lokal.z))
	var y: float = (load("res://szenen/welt/ausstattung.gd") as GDScript).boden_unter(raum, p, 1.2, 3.0)
	return NAN if is_nan(y) else to_local(Vector3(p.x, y, p.z)).y


## Jedes Huhn auf die Oberfläche unter ihm, sobald Gelände und Bauten ihre Kollision haben
func _erde() -> void:
	if not is_inside_tree():
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	for h in _huehner:
		var k: Node3D = h["knoten"]
		var y := _boden(k.position)
		if not is_nan(y):
			k.position.y = y
		h["ziel"] = k.position
	_bereit = true


## Ist der Weg von a nach b (lokal, Bodenhöhe) frei? Strahl knapp über dem Boden gegen Mauern, Häuser, Zäune
func _frei(a: Vector3, b: Vector3) -> bool:
	var raum := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(to_global(a + Vector3.UP * 0.25), to_global(b + Vector3.UP * 0.25), 1)
	var t := raum.intersect_ray(q)
	return t.is_empty() or (t.collider is CharacterBody3D)


func _process(delta: float) -> void:
	if not _bereit:
		return
	var sp := get_tree().get_first_node_in_group("spieler") as Node3D
	if sp == null:
		return
	if sp.global_position.distance_to(global_position) > SICHT:
		return
	_pruef -= delta
	var stoerer: Array[Vector3] = []
	if _pruef <= 0.0:
		_pruef = 0.25
		stoerer.append(to_local(sp.global_position))
		for p in get_tree().get_nodes_in_group("interagierbar"):
			if p.has_method("unterwegs") and p.unterwegs() and (p as Node3D).global_position.distance_to(global_position) < weite + 4.0:
				stoerer.append(to_local((p as Node3D).global_position))
	for h in _huehner:
		var k: Node3D = h["knoten"]
		# zu nahe? weglaufen, vom Störer fort, im Revier (etwas darüber hinaus)
		for s: Vector3 in stoerer:
			var weg := Vector3(k.position.x - s.x, 0, k.position.z - s.z)
			if weg.length() < SCHEU and h["tun"] != "rennen":
				var ziel := k.position + weg.normalized().rotated(Vector3.UP, _zufall.randf_range(-0.6, 0.6)) * _zufall.randf_range(1.8, 3.0)
				if Vector2(ziel.x, ziel.z).length() > weite * 1.3:
					ziel = Vector3(ziel.x, 0, ziel.z).normalized() * weite * 1.3
				_neues_ziel(h, ziel, RENNEN, "rennen")
		_lebe(h, delta)


func _neues_ziel(h: Dictionary, ziel: Vector3, tempo: float, tun: String) -> bool:
	var k: Node3D = h["knoten"]
	var y := _boden(ziel)
	if is_nan(y) or absf(y - k.position.y) > 0.4:
		return false                           # Kante, Stufe, Mauer
	ziel.y = y
	if not _frei(k.position, ziel):
		return false
	h["ziel"] = ziel
	h["tempo"] = tempo
	h["tun"] = tun
	h["dauer"] = 0.0
	return true


func _lebe(h: Dictionary, delta: float) -> void:
	var k: Node3D = h["knoten"]
	var kopf: Node3D = h["kopf"]
	var beine: Array = h["beine"]
	h["dauer"] += delta
	match h["tun"]:
		"gehen", "rennen":
			var ziel: Vector3 = h["ziel"]
			var schritt := ziel - k.position
			if schritt.length() < 0.05:
				h["tun"] = ""
				h["takt"] = _zufall.randf_range(0.3, 1.5)
				for f: Node3D in h["fluegel"]:
					f.rotation.z = 0.0
			else:
				k.position += schritt.limit_length(delta * float(h["tempo"]))
				k.rotation.y = lerp_angle(k.rotation.y, atan2(-schritt.x, -schritt.z), clampf(delta * 10.0, 0.0, 1.0))
				h["phase"] += delta * (14.0 if h["tun"] == "gehen" else 26.0)
				(beine[0] as Node3D).rotation.x = sin(h["phase"]) * 0.6
				(beine[1] as Node3D).rotation.x = -sin(h["phase"]) * 0.6
				kopf.position.z = -0.12 + sin(h["phase"] * 2.0) * 0.015        # Kopfnicken beim Laufen
				if h["tun"] == "rennen":
					var w := sin(h["dauer"] * 22.0) * 0.9
					(h["fluegel"][0] as Node3D).rotation.z = w
					(h["fluegel"][1] as Node3D).rotation.z = -w
		"picken":
			kopf.rotation.x = -absf(sin(h["dauer"] * 8.0)) * 1.1 if h["dauer"] < 1.4 else 0.0
			if h["dauer"] > 1.6:
				h["tun"] = ""
		"scharren":
			(beine[int(h["dauer"] * 3.0) % 2] as Node3D).rotation.x = sin(h["dauer"] * 18.0) * 0.7
			if h["dauer"] > 1.2:
				h["tun"] = ""
				for b: Node3D in beine:
					b.rotation.x = 0.0
		"umsehen":
			kopf.rotation.y = sin(h["dauer"] * 3.0) * 0.7
			if h["dauer"] > 1.5:
				h["tun"] = ""
				kopf.rotation.y = 0.0
		_:
			h["takt"] -= delta
			if h["takt"] <= 0.0:
				var wahl := _zufall.randf()
				h["dauer"] = 0.0
				if wahl < 0.35:
					var gefunden := false
					for versuch in 4:
						var w := _zufall.randf() * TAU
						var ziel := k.position + Vector3(cos(w), 0, sin(w)) * _zufall.randf_range(0.4, 1.4)
						if Vector2(ziel.x, ziel.z).length() > weite:
							ziel = Vector3(ziel.x, 0, ziel.z) * 0.5
						if _neues_ziel(h, ziel, GEHEN, "gehen"):
							gefunden = true
							break
					if not gefunden:
						h["tun"] = "picken"
				elif wahl < 0.65:
					h["tun"] = "picken"
				elif wahl < 0.85:
					h["tun"] = "scharren"
				else:
					h["tun"] = "umsehen"
				h["takt"] = _zufall.randf_range(0.5, 2.5)
