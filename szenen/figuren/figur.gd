@tool
class_name Figur
extends Node3D
## Ein Mensch aus einfachen Formen: Kopf mit Haar, Rumpf, Arme und Beine mit Gelenken, auf Wunsch ein
## langer Rock (die Tracht des Ordens). Die Figur misst selbst, wie schnell sie sich bewegt, und geht dann:
## Beine und Arme schwingen gegeneinander, beim Stehen atmet sie. Gilt für Personen, Spieler und Gegner.
## Füße bei y = 0, Größe etwa 1,8 m.

@export var tracht: Color = Color(0.15, 0.15, 0.17):
	set(wert):
		tracht = wert
		_faerben()
@export var haut: Color = Color(0.78, 0.6, 0.48):
	set(wert):
		haut = wert
		_faerben()
@export var haar: Color = Color(0.25, 0.18, 0.12):
	set(wert):
		haar = wert
		_faerben()
## 0 kurz, 1 lang, 2 Kapuze, 3 Hut, 4 Glatze
@export_range(0, 4) var frisur: int = 0:
	set(wert):
		frisur = wert
		if is_inside_tree():
			_baue()
## Langer Rock über den Beinen (Ordenstracht, Gewand)
@export var rock: bool = true:
	set(wert):
		rock = wert
		if is_inside_tree():
			_baue()
@export var kordel_farbe: Color = Color(0, 0, 0, 0):
	set(wert):
		kordel_farbe = wert
		_faerben()
## Breite (Schultern, Hüfte) und Größe als Faktoren
@export var breite: float = 1.0
@export var groesse: float = 1.0

const HUEFTE := 0.93
const SCHULTER := 1.43

var _teile := {}
var _phase: float = 0.0
var _gang: float = 0.0
var _letzte := Vector3.INF
var _atem: float = 0.0
static var _materialien := {}


func _ready() -> void:
	_baue()


## Erzeugt die Figur aus Formen. Aufbau: Glieder hängen an Gelenk-Knoten (Hüfte, Knie, Schulter, Ellbogen).
func _baue() -> void:
	for k in get_children():
		if k.has_meta("figur_teil"):
			k.free()
	_teile.clear()
	scale = Vector3(breite, groesse, breite)
	var b := 1.0
	# Beine: Hüftgelenk → Oberschenkel, Kniegelenk → Unterschenkel, Stiefel
	for seite in [-1, 1]:
		var huefte := _gelenk("Huefte%d" % seite, self, Vector3(0.1 * seite, HUEFTE, 0))
		_glied(huefte, "hose", Vector3(0, -0.22, 0), _kapsel(0.085, 0.5))
		var knie := _gelenk("Knie%d" % seite, huefte, Vector3(0, -0.44, 0))
		_glied(knie, "hose", Vector3(0, -0.2, 0), _kapsel(0.07, 0.44))
		_glied(knie, "stiefel", Vector3(0, -0.36, 0), _kapsel(0.075, 0.24))
		_glied(knie, "stiefel", Vector3(0, -0.46, -0.06), _quader(Vector3(0.11, 0.07, 0.24)))
		_teile["huefte%d" % seite] = huefte
		_teile["knie%d" % seite] = knie
	# Rumpf, Gürtel, Rock
	var rumpf := _gelenk("Rumpf", self, Vector3(0, HUEFTE, 0))
	_teile["rumpf"] = rumpf
	_glied(rumpf, "tracht", Vector3(0, 0.28, 0), _rumpfform())
	_glied(rumpf, "guertel", Vector3(0, 0.05, 0), _zylinder(0.17, 0.17, 0.07))
	if rock:
		_glied(rumpf, "tracht", Vector3(0, -0.22, 0), _zylinder(0.18, 0.29, 0.5))
	# Kordel am Kragen (Rangabzeichen)
	_glied(rumpf, "kordel", Vector3(0, 0.5, -0.02), _zylinder(0.11, 0.13, 0.035))
	# Hals und Kopf
	var kopf := _gelenk("Kopf", rumpf, Vector3(0, SCHULTER - HUEFTE + 0.07, 0))
	_teile["kopf"] = kopf
	_glied(kopf, "haut", Vector3(0, 0.03, 0), _zylinder(0.05, 0.055, 0.1))
	_glied(kopf, "haut", Vector3(0, 0.17, 0), _kugel(0.105, 0.24))
	_glied(kopf, "haut", Vector3(0, 0.16, -0.1), _quader(Vector3(0.03, 0.05, 0.04)))   # Nase: zeigt, wohin sie schaut
	match frisur:
		0:
			_glied(kopf, "haar", Vector3(0, 0.22, 0.015), _kugel(0.112, 0.17))
		1:
			_glied(kopf, "haar", Vector3(0, 0.21, 0.02), _kugel(0.114, 0.2))
			_glied(kopf, "haar", Vector3(0, 0.08, 0.07), _quader(Vector3(0.2, 0.26, 0.07)))
		2:
			_glied(kopf, "tracht", Vector3(0, 0.19, 0.02), _kugel(0.13, 0.3))
			_glied(kopf, "tracht", Vector3(0, 0.06, 0.06), _zylinder(0.12, 0.17, 0.14))
		3:
			_glied(kopf, "haar", Vector3(0, 0.22, 0.015), _kugel(0.112, 0.17))
			_glied(kopf, "hut", Vector3(0, 0.28, 0), _zylinder(0.2, 0.2, 0.025))
			_glied(kopf, "hut", Vector3(0, 0.33, 0), _zylinder(0.1, 0.11, 0.1))
	# Arme: Schulter → Oberarm, Ellbogen → Unterarm, Hand
	for seite in [-1, 1]:
		var schulter := _gelenk("Schulter%d" % seite, rumpf, Vector3(0.21 * seite, SCHULTER - HUEFTE, 0))
		_glied(schulter, "tracht", Vector3(0, -0.14, 0), _kapsel(0.06, 0.32))
		var ellbogen := _gelenk("Ellbogen%d" % seite, schulter, Vector3(0, -0.28, 0))
		_glied(ellbogen, "tracht", Vector3(0, -0.12, 0), _kapsel(0.05, 0.28))
		_glied(ellbogen, "haut", Vector3(0, -0.28, 0), _kugel(0.045, 0.1))
		_teile["schulter%d" % seite] = schulter
		_teile["ellbogen%d" % seite] = ellbogen
	_faerben()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _teile.is_empty():
		return
	# Eigene Geschwindigkeit über dem Boden messen
	var p := global_position
	var tempo := 0.0
	if _letzte != Vector3.INF and delta > 0.0:
		tempo = Vector2(p.x - _letzte.x, p.z - _letzte.z).length() / delta
	_letzte = p
	if tempo > 12.0:
		tempo = 0.0   # gesprungen (Laden, Reise): nicht gehen
	_gang = lerpf(_gang, clampf(tempo / 1.6, 0.0, 1.6), clampf(delta * 8.0, 0.0, 1.0))
	_phase = fmod(_phase + delta * (2.2 + tempo * 2.4) * minf(_gang * 4.0, 1.0), TAU)
	_atem += delta
	var schwung := sin(_phase) * 0.55 * minf(_gang, 1.3)
	var beuge := maxf(0.0, -cos(_phase)) * 0.7 * minf(_gang, 1.3)
	var beuge2 := maxf(0.0, cos(_phase)) * 0.7 * minf(_gang, 1.3)
	_teile["huefte-1"].rotation.x = schwung
	_teile["huefte1"].rotation.x = -schwung
	_teile["knie-1"].rotation.x = -beuge
	_teile["knie1"].rotation.x = -beuge2
	_teile["schulter-1"].rotation.x = -schwung * 0.8
	_teile["schulter1"].rotation.x = schwung * 0.8
	_teile["schulter-1"].rotation.z = -0.08
	_teile["schulter1"].rotation.z = 0.08
	_teile["ellbogen-1"].rotation.x = 0.25 + maxf(0.0, schwung) * 0.4
	_teile["ellbogen1"].rotation.x = 0.25 + maxf(0.0, -schwung) * 0.4
	# Auf und ab beim Gehen, Atmen im Stand
	_teile["rumpf"].position.y = HUEFTE + absf(cos(_phase)) * 0.03 * minf(_gang, 1.0)
	_teile["rumpf"].rotation.x = 0.05 * minf(_gang, 1.0)
	_teile["kopf"].rotation.x = sin(_atem * 1.1) * 0.02


# ---------- Bausteine ----------

func _gelenk(name_: String, eltern: Node3D, ort: Vector3) -> Node3D:
	var g := Node3D.new()
	g.name = name_
	g.position = ort
	g.set_meta("figur_teil", true)
	eltern.add_child(g)
	return g


func _glied(eltern: Node3D, stoff: String, ort: Vector3, mesh: Mesh) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = ort
	m.set_meta("stoff", stoff)
	m.set_meta("figur_teil", true)
	eltern.add_child(m)
	return m


func _kapsel(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 10
	m.rings = 3
	return m


func _kugel(r: float, h: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 14
	m.rings = 8
	return m


func _zylinder(oben: float, unten: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = oben
	m.bottom_radius = unten
	m.height = h
	m.radial_segments = 12
	m.rings = 1
	return m


func _quader(groesse_: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = groesse_
	return m


## Rumpf: oben breiter (Schultern), unten schmaler, vorn und hinten flacher
func _rumpfform() -> Mesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.2
	m.bottom_radius = 0.16
	m.height = 0.56
	m.radial_segments = 12
	m.rings = 2
	return m


# ---------- Farben ----------

func _faerben() -> void:
	if not is_inside_tree():
		return
	var farben := {
		"tracht": tracht,
		"hose": tracht.darkened(0.35) if rock else tracht.darkened(0.15),
		"stiefel": Color(0.13, 0.1, 0.08),
		"guertel": Color(0.22, 0.15, 0.09),
		"haut": haut,
		"haar": haar,
		"hut": tracht.darkened(0.3),
		"kordel": kordel_farbe,
	}
	for m in find_children("*", "MeshInstance3D", true, false):
		if not m.has_meta("stoff"):
			continue
		var stoff: String = m.get_meta("stoff")
		var farbe: Color = farben.get(stoff, tracht)
		if stoff == "kordel":
			m.visible = farbe.a > 0.0
		m.material_override = _material(farbe, stoff)


static func _material(farbe: Color, stoff: String) -> StandardMaterial3D:
	var schluessel := "%s|%s" % [farbe.to_html(), stoff]
	if _materialien.has(schluessel):
		return _materialien[schluessel]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(farbe, 1.0)
	m.roughness = 0.55 if stoff == "haut" else (0.4 if stoff in ["stiefel", "guertel"] else 0.9)
	if stoff in ["tracht", "hose", "hut"]:
		# Gewebestruktur nur als Normalenkarte, die Farbe kommt aus der Tracht
		m.normal_enabled = true
		m.normal_texture = load("res://texturen/stoff_normal.jpg")
		m.normal_scale = 0.6
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(6, 6, 6)
	_materialien[schluessel] = m
	return m


## Zufällige, aber feste Merkmale aus einem Text (z. B. dem Namen): Haut, Haar, Frisur.
func merkmale_aus(text: String) -> void:
	var h := absi(hash(text))
	var haeute := [Color(0.86, 0.68, 0.55), Color(0.78, 0.6, 0.48), Color(0.68, 0.5, 0.38), Color(0.55, 0.4, 0.3), Color(0.9, 0.74, 0.62)]
	var haare := [Color(0.2, 0.14, 0.09), Color(0.35, 0.24, 0.14), Color(0.55, 0.4, 0.22), Color(0.12, 0.1, 0.09), Color(0.6, 0.55, 0.5), Color(0.5, 0.25, 0.12)]
	haut = haeute[h % haeute.size()]
	haar = haare[(h / 7) % haare.size()]
	frisur = [0, 0, 1, 1, 3, 4][(h / 31) % 6]
	breite = 0.92 + ((h / 101) % 17) / 100.0
	groesse = 0.94 + ((h / 211) % 11) / 100.0
	scale = Vector3(breite, groesse, breite)
