extends Node3D
## Ein Taubenschwarm: am Boden (Markt, Hof) picken und hüpfen die Tauben in einem Kreis um den Ort des Knotens; auf
## einer Mauer (sitzend) sitzen sie in einer Reihe entlang lokal x, drehen sich und putzen sich. Kommt der Spieler
## (oder eine gehende Person) zu nahe, fliegt der ganze Schwarm mit schlagenden Flügeln auf, kreist eine Weile
## über dem Ort und landet wieder, wenn es ruhig ist. Weit weg vom Spieler ruht alles.

@export var anzahl: int = 6
## Am Boden: Radius, in dem sie picken; sitzend: Länge der Reihe
@export var weite: float = 2.5
@export var sitzend: bool = false

const SCHEU_BODEN := 4.5
const SCHEU_SITZEND := 3.0

enum Zustand { RUHE, AUF, KREISEN, LANDEN }

static var _meshes := {}
static var _mats := {}

var _tauben: Array[Dictionary] = []
var _zustand := Zustand.RUHE
var _zeit := 0.0
var _zufall := RandomNumberGenerator.new()
var _pruef := 0.0


func _ready() -> void:
	_zufall.seed = hash(Vector2i(int(global_position.x * 7.0), int(global_position.z * 7.0)))
	for i in anzahl:
		var t := Node3D.new()
		add_child(t)
		var heim: Vector3
		if sitzend:
			heim = Vector3((i - (anzahl - 1) / 2.0) * weite / maxf(anzahl, 1), 0, 0)
		else:
			var w := _zufall.randf() * TAU
			heim = Vector3(cos(w), 0, sin(w)) * _zufall.randf_range(0.2, weite)
		t.position = heim
		t.rotation.y = _zufall.randf() * TAU
		var koerper := _teil(t, "koerper", Vector3.ZERO)
		var kopf := _teil(koerper, "kopf", Vector3(0, 0.07, -0.1))
		_teil(kopf, "schnabel", Vector3(0, -0.005, -0.05))
		_teil(koerper, "schwanz", Vector3(0, 0.02, 0.13))
		var fluegel := []
		for s in [-1.0, 1.0]:
			var gelenk := Node3D.new()
			gelenk.position = Vector3(s * 0.05, 0.03, -0.01)
			koerper.add_child(gelenk)
			_teil(gelenk, "fluegel", Vector3(s * 0.08, 0, 0.02))
			fluegel.append(gelenk)
		for s in [-0.02, 0.02]:
			_teil(koerper, "bein", Vector3(s, -0.075, -0.01))
		_tauben.append({"knoten": t, "koerper": koerper, "kopf": kopf, "fluegel": fluegel, "heim": heim,
			"takt": _zufall.randf_range(0.2, 2.0), "tun": "", "dauer": 0.0, "von": heim, "nach": heim, "flug": 0.0,
			"winkel": _zufall.randf() * TAU, "hoehe": _zufall.randf_range(6.0, 10.0), "radius": _zufall.randf_range(5.0, 9.0)})


func _teil(eltern: Node3D, art: String, ort: Vector3) -> Node3D:
	if not _meshes.has(art):
		var m := BoxMesh.new()
		m.size = {"koerper": Vector3(0.11, 0.1, 0.21), "kopf": Vector3(0.065, 0.065, 0.075), "schnabel": Vector3(0.018, 0.015, 0.035),
			"schwanz": Vector3(0.09, 0.025, 0.11), "fluegel": Vector3(0.16, 0.018, 0.13), "bein": Vector3(0.012, 0.05, 0.012)}[art]
		_meshes[art] = m
		var farbe: Color = {"koerper": Color(0.55, 0.57, 0.62), "kopf": Color(0.4, 0.46, 0.5), "schnabel": Color(0.7, 0.35, 0.3),
			"schwanz": Color(0.3, 0.31, 0.35), "fluegel": Color(0.48, 0.5, 0.55), "bein": Color(0.75, 0.3, 0.3)}[art]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = farbe
		mat.roughness = 0.9
		_mats[art] = mat
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[art]
	mi.material_override = _mats[art]
	mi.position = ort + (Vector3(0, 0.1, 0) if art == "koerper" else Vector3.ZERO)
	mi.visibility_range_end = 70.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	eltern.add_child(mi)
	return mi


func _process(delta: float) -> void:
	var sp := get_tree().get_first_node_in_group("spieler") as Node3D
	if sp == null:
		return
	var abstand := Vector2(sp.global_position.x - global_position.x, sp.global_position.z - global_position.z).length()
	if abstand > 60.0 and _zustand == Zustand.RUHE:
		return
	_zeit += delta
	var scheu := SCHEU_SITZEND if sitzend else SCHEU_BODEN + weite
	_pruef -= delta
	var gestoert := false
	if _pruef <= 0.0:
		_pruef = 0.2
		gestoert = abstand < scheu or _person_nah()
	match _zustand:
		Zustand.RUHE:
			if gestoert:
				_auffliegen()
			else:
				for t in _tauben:
					_ruhe(t, delta)
		Zustand.AUF:
			var fertig := true
			for t in _tauben:
				t["flug"] = minf(t["flug"] + delta / 2.6, 1.0)
				_fliege(t, delta, t["flug"])
				fertig = fertig and t["flug"] >= 1.0
			if fertig:
				_zustand = Zustand.KREISEN
				_zeit = 0.0
		Zustand.KREISEN:
			for t in _tauben:
				t["winkel"] += delta * 0.9
				var ziel := Vector3(cos(t["winkel"]) * t["radius"], t["hoehe"], sin(t["winkel"]) * t["radius"])
				var k: Node3D = t["knoten"]
				var schritt := ziel - k.position
				k.position += schritt * clampf(delta * 1.5, 0.0, 1.0)
				_schaue(k, schritt)
				_schlage(t, delta, 0.6)
			if _zeit > 8.0 and abstand > scheu + 4.0 and not _person_nah():
				_zustand = Zustand.LANDEN
				for t in _tauben:
					t["von"] = (t["knoten"] as Node3D).position
					t["nach"] = t["heim"]
					t["flug"] = 0.0
		Zustand.LANDEN:
			var fertig := true
			for t in _tauben:
				t["flug"] = minf(t["flug"] + delta / 3.2, 1.0)
				_fliege(t, delta, t["flug"])
				fertig = fertig and t["flug"] >= 1.0
			if gestoert:
				_auffliegen()
			elif fertig:
				_zustand = Zustand.RUHE
				for t in _tauben:
					for f: Node3D in t["fluegel"]:
						f.rotation.z = 0.0


## Ob eine Person nahe vorbeigeht (gehende Leute scheuchen den Schwarm auf)
func _person_nah() -> bool:
	for p in get_tree().get_nodes_in_group("interagierbar"):
		if p.has_method("unterwegs") and p.unterwegs():
			if (p as Node3D).global_position.distance_to(global_position) < weite + 1.5:
				return true
	return false


func _auffliegen() -> void:
	_zustand = Zustand.AUF
	_zeit = 0.0
	for t in _tauben:
		var k: Node3D = t["knoten"]
		t["von"] = k.position
		var w := _zufall.randf() * TAU
		t["winkel"] = w
		t["nach"] = Vector3(cos(w) * t["radius"], t["hoehe"], sin(w) * t["radius"])
		t["flug"] = -_zufall.randf_range(0.0, 0.25)      # nicht alle im selben Augenblick


## Flug von "von" nach "nach" auf einem Bogen; beim Landen zuletzt mit gespreizten, ruhigen Flügeln
func _fliege(t: Dictionary, delta: float, f: float) -> void:
	var k: Node3D = t["knoten"]
	var g := clampf(f, 0.0, 1.0)
	var von: Vector3 = t["von"]
	var nach: Vector3 = t["nach"]
	var glatt := g * g * (3.0 - 2.0 * g)
	var p := von.lerp(nach, glatt)
	p.y += sin(g * PI) * 1.5
	var schritt := p - k.position
	k.position = p
	if schritt.length() > 0.001:
		_schaue(k, schritt)
	_schlage(t, delta, 1.0 if g < 0.85 else 0.3)
	(t["koerper"] as Node3D).rotation.x = -0.4 if g < 0.85 else 0.0


func _schlage(t: Dictionary, delta: float, staerke: float) -> void:
	t["takt"] += delta * 14.0
	var w := sin(t["takt"]) * 1.1 * staerke
	var f: Array = t["fluegel"]
	(f[0] as Node3D).rotation.z = w
	(f[1] as Node3D).rotation.z = -w


func _schaue(k: Node3D, richtung: Vector3) -> void:
	if Vector2(richtung.x, richtung.z).length() < 0.001:
		return
	k.rotation.y = atan2(-richtung.x, -richtung.z)


## Am Boden: picken, ein paar Schritte hüpfen, sich drehen; sitzend: drehen, putzen, picken
func _ruhe(t: Dictionary, delta: float) -> void:
	var k: Node3D = t["knoten"]
	var kopf: Node3D = t["kopf"]
	t["takt"] -= delta
	if t["takt"] <= 0.0:
		var wahl := _zufall.randf()
		if not sitzend and wahl < 0.35:
			t["tun"] = "huepfen"
			var w := _zufall.randf() * TAU
			var ziel: Vector3 = k.position + Vector3(cos(w), 0, sin(w)) * _zufall.randf_range(0.15, 0.45)
			if Vector2(ziel.x, ziel.z).length() > weite:
				ziel = Vector3(ziel.x, 0, ziel.z) * 0.6
			t["von"] = k.position
			t["nach"] = Vector3(ziel.x, 0, ziel.z)
			t["dauer"] = 0.0
			_schaue(k, t["nach"] - k.position)
		elif wahl < 0.7:
			t["tun"] = "picken"
			t["dauer"] = 0.0
		else:
			t["tun"] = "drehen"
			t["dauer"] = 0.0
			t["nach_dreh"] = k.rotation.y + _zufall.randf_range(-1.6, 1.6)
		t["takt"] = _zufall.randf_range(0.6, 2.5)
	t["dauer"] += delta
	match t["tun"]:
		"huepfen":
			var f := clampf(t["dauer"] / 0.35, 0.0, 1.0)
			var p: Vector3 = (t["von"] as Vector3).lerp(t["nach"], f)
			p.y = sin(f * PI) * 0.08
			k.position = p
		"picken":
			kopf.rotation.x = -absf(sin(t["dauer"] * 9.0)) * 0.9 if t["dauer"] < 1.2 else 0.0
		"drehen":
			k.rotation.y = lerp_angle(k.rotation.y, t.get("nach_dreh", k.rotation.y), clampf(delta * 5.0, 0.0, 1.0))
