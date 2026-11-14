extends Node3D
## Möwen über dem Hafen: Sie segeln in weiten, verschieden hohen Kreisen um den Ort des Knotens, gleiten meist mit
## ausgebreiteten, leicht angewinkelten Flügeln und schlagen ab und zu ein paar Mal; dabei steigen und sinken sie
## sanft. Mit sitzend = true sitzen sie stattdessen in einer Reihe (entlang lokal x, z. B. auf Pfählen oder einer
## Mauerkrone), putzen sich und fliegen auf, wenn der Spieler nahe kommt; dann kreisen sie eine Weile und kehren zurück.
## Weit weg vom Spieler ruht alles.

@export var anzahl: int = 5
## Fliegend: mittlerer Radius der Kreise; sitzend: Länge der Reihe
@export var weite: float = 30.0
## Fliegend: Höhe über dem Knoten (Mittel)
@export var hoehe: float = 14.0
@export var sitzend: bool = false

const SCHEU := 5.0
const SICHT := 260.0

static var _meshes := {}
static var _mats := {}

var _voegel: Array[Dictionary] = []
var _zufall := RandomNumberGenerator.new()
var _auf := false           # sitzende: gerade in der Luft
var _zeit := 0.0
var _pruef := 0.0
var _geerdet := false       # sitzende: einmal auf die Oberfläche unter ihnen gesetzt


func _ready() -> void:
	_zufall.seed = hash(Vector2i(int(global_position.x * 3.0), int(global_position.z * 3.0)))
	for i in anzahl:
		var v := Node3D.new()
		add_child(v)
		var heim := Vector3((i - (anzahl - 1) / 2.0) * weite / maxf(anzahl, 1), 0, 0) if sitzend else Vector3.ZERO
		var koerper := _teil(v, "koerper", Vector3.ZERO)
		var kopf := _teil(koerper, "kopf", Vector3(0, 0.06, -0.19))
		_teil(kopf, "schnabel", Vector3(0, -0.01, -0.07))
		_teil(koerper, "schwanz", Vector3(0, 0.01, 0.2))
		var fluegel := []
		for s in [-1.0, 1.0]:
			var gelenk := Node3D.new()
			gelenk.position = Vector3(s * 0.07, 0.04, -0.02)
			koerper.add_child(gelenk)
			_teil(gelenk, "fluegel", Vector3(s * 0.25, 0, 0))
			_teil(gelenk, "spitze", Vector3(s * 0.55, 0, 0.03))
			fluegel.append(gelenk)
		var vogel := {"knoten": v, "koerper": koerper, "fluegel": fluegel, "heim": heim,
			"winkel": _zufall.randf() * TAU, "tempo": _zufall.randf_range(0.11, 0.2) * (1.0 if _zufall.randf() < 0.6 else -1.0),
			"radius": weite * _zufall.randf_range(0.5, 1.3), "hoehe": hoehe * _zufall.randf_range(0.7, 1.4),
			"wellen": _zufall.randf() * TAU, "takt": 0.0, "schlagen": 0.0, "pause": _zufall.randf_range(1.0, 6.0),
			"versatz": Vector3(_zufall.randf_range(-0.3, 0.3), 0, _zufall.randf_range(-0.3, 0.3)) * weite}
		_voegel.append(vogel)
		if sitzend:
			v.position = heim
			v.rotation.y = _zufall.randf() * TAU
			_falte(vogel)
		else:
			_setze_kreis(vogel, 0.0)


func _teil(eltern: Node3D, art: String, ort: Vector3) -> Node3D:
	if not _meshes.has(art):
		var m := BoxMesh.new()
		m.size = {"koerper": Vector3(0.13, 0.12, 0.36), "kopf": Vector3(0.09, 0.09, 0.11), "schnabel": Vector3(0.025, 0.025, 0.07),
			"schwanz": Vector3(0.12, 0.025, 0.12), "fluegel": Vector3(0.38, 0.02, 0.17), "spitze": Vector3(0.26, 0.018, 0.12)}[art]
		_meshes[art] = m
		var farbe: Color = {"koerper": Color(0.93, 0.93, 0.92), "kopf": Color(0.95, 0.95, 0.94), "schnabel": Color(0.9, 0.75, 0.2),
			"schwanz": Color(0.92, 0.92, 0.92), "fluegel": Color(0.66, 0.69, 0.72), "spitze": Color(0.12, 0.12, 0.13)}[art]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = farbe
		mat.roughness = 0.85
		_mats[art] = mat
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[art]
	mi.material_override = _mats[art]
	mi.position = ort + (Vector3(0, 0.1, 0) if art == "koerper" else Vector3.ZERO)
	mi.visibility_range_end = SICHT
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	eltern.add_child(mi)
	return mi


func _process(delta: float) -> void:
	var sp := get_tree().get_first_node_in_group("spieler") as Node3D
	if sp == null:
		return
	var abstand := sp.global_position.distance_to(global_position)
	if abstand > SICHT and not _auf:
		return
	_zeit += delta
	if sitzend and not _geerdet:
		_erde()
	if sitzend:
		_pruef -= delta
		if _pruef <= 0.0:
			_pruef = 0.25
			if not _auf and abstand < SCHEU + weite * 0.5:
				_auf = true
				_zeit = 0.0
		if not _auf:
			for v in _voegel:
				_putze(v, delta)
			return
		# in der Luft: kreisen, nach einer Weile (wenn der Spieler weg ist) wieder auf den Platz
		var zurueck := _zeit > 12.0 and abstand > SCHEU + weite * 0.5 + 4.0
		var fertig := true
		for v in _voegel:
			var k: Node3D = v["knoten"]
			if zurueck:
				var ziel: Vector3 = v["heim"]
				var schritt := ziel - k.position
				if schritt.length() > 0.05:
					fertig = false
					k.position += schritt.limit_length(delta * 5.0)
					_schaue(k, schritt)
					_flattern(v, delta, 0.5)
				else:
					k.position = ziel
					_falte(v)
			else:
				fertig = false
				_kreise(v, delta, 6.0, 3.5)
		if zurueck and fertig:
			_auf = false
		return
	for v in _voegel:
		_kreise(v, delta, v["radius"], v["hoehe"])


## Segeln auf einem Kreis (Mitte: versetzt um den Knoten), sanft auf und ab; ab und zu ein paar Flügelschläge
func _kreise(v: Dictionary, delta: float, radius: float, h: float) -> void:
	v["winkel"] += delta * v["tempo"] * (30.0 / maxf(radius, 4.0))
	v["wellen"] += delta * 0.4
	_setze_kreis(v, delta, radius, h)
	v["pause"] -= delta
	if v["pause"] <= 0.0:
		v["schlagen"] = _zufall.randf_range(1.0, 2.2)
		v["pause"] = _zufall.randf_range(3.0, 9.0)
	if v["schlagen"] > 0.0:
		v["schlagen"] -= delta
		_flattern(v, delta, 1.0)
	else:
		_gleite(v, delta)


func _setze_kreis(v: Dictionary, _delta: float, radius := -1.0, h := -1.0) -> void:
	if radius < 0.0:
		radius = v["radius"]
		h = v["hoehe"]
	var w: float = v["winkel"]
	var k: Node3D = v["knoten"]
	var mitte: Vector3 = v["versatz"] if not sitzend else Vector3.ZERO
	var p := mitte + Vector3(cos(w) * radius, h + sin(v["wellen"]) * 1.5, sin(w) * radius)
	var schritt := p - k.position
	k.position = p
	if schritt.length() > 0.0005:
		_schaue(k, schritt)
		# in die Kurve legen
		(v["koerper"] as Node3D).rotation.z = -0.35 * signf(v["tempo"])


func _flattern(v: Dictionary, delta: float, staerke: float) -> void:
	v["takt"] += delta * 9.0
	var w := sin(v["takt"]) * 0.8 * staerke
	var f: Array = v["fluegel"]
	(f[0] as Node3D).rotation = Vector3(0, 0, w)
	(f[1] as Node3D).rotation = Vector3(0, 0, -w)


func _gleite(v: Dictionary, delta: float) -> void:
	# Flügel ausgebreitet, leicht nach oben angewinkelt (V-Form), zur Ruhe kommend
	var f: Array = v["fluegel"]
	for i in 2:
		var g: Node3D = f[i]
		var ziel := 0.12 * (1.0 if i == 0 else -1.0)
		g.rotation = Vector3(0, 0, lerpf(g.rotation.z, ziel, clampf(delta * 3.0, 0.0, 1.0)))


func _falte(v: Dictionary) -> void:
	# Sitzend: Flügel eng am Körper (nach hinten geklappt), aufrecht
	var f: Array = v["fluegel"]
	(f[0] as Node3D).rotation = Vector3(0, -1.35, 0.15)
	(f[1] as Node3D).rotation = Vector3(0, 1.35, -0.15)
	(v["koerper"] as Node3D).rotation = Vector3.ZERO


func _putze(v: Dictionary, delta: float) -> void:
	v["pause"] -= delta
	if v["pause"] <= 0.0:
		v["pause"] = _zufall.randf_range(2.0, 7.0)
		var k: Node3D = v["knoten"]
		k.rotation.y += _zufall.randf_range(-1.2, 1.2)


func _schaue(k: Node3D, richtung: Vector3) -> void:
	if Vector2(richtung.x, richtung.z).length() < 0.0005:
		return
	k.rotation.y = atan2(-richtung.x, -richtung.z)


## Sitzende: jede auf die Oberfläche unter ihrem Platz (Mauerkrone, Kai, Pfahl), Personen zählen nicht
func _erde() -> void:
	_geerdet = true
	var raum := get_world_3d().direct_space_state
	for v in _voegel:
		var k: Node3D = v["knoten"]
		var oben := k.global_position + Vector3.UP * 3.0
		var abfrage := PhysicsRayQueryParameters3D.create(oben, oben + Vector3.DOWN * 8.0, 1)
		var treffer := raum.intersect_ray(abfrage)
		if treffer and not (treffer.collider is CharacterBody3D or (treffer.collider as Node).has_method("unterwegs")):
			k.global_position.y = (treffer.position as Vector3).y - 0.08
			v["heim"] = k.position
