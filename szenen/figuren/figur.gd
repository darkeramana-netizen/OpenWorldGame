@tool
class_name Figur
extends Node3D
## Ein Mensch: ein animiertes Modell (Quaternius, CC0; modelle/figuren) aus Körper, Kleidung, Haaren und Bart, oder
## (einfach = true, oder wenn die Modelle fehlen) die alte Figur aus einfachen Formen. Ordensleute (rock) tragen die
## Waldläufer-Tracht mit Gugel und Gürtel, alle anderen das Bauerngewand; die Farben kommen aus Tracht, Haut, Haar
## und Kordel. Die Figur misst selbst, wie schnell sie sich bewegt, und wählt danach Stehen, Gehen, Laufen oder
## Rennen; im Stand die Haltung (reden, sitzen, arbeiten, knien, fackel). Gilt für Personen, Spieler und Gegner.
## Füße bei y = 0, Größe etwa 1,8 m, Blick nach -z.

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
			_plane_bau()
## Langer Rock über den Beinen (Ordenstracht, Gewand)
@export var rock: bool = true:
	set(wert):
		rock = wert
		if is_inside_tree():
			_plane_bau()
@export var kordel_farbe: Color = Color(0, 0, 0, 0):
	set(wert):
		kordel_farbe = wert
		_faerben()
## Breite (Schultern, Hüfte) und Größe als Faktoren
@export var breite: float = 1.0
@export var groesse: float = 1.0
## Alte Figur aus einfachen Formen statt des Modells (z. B. die Strohpuppe)
@export var einfach: bool = false:
	set(wert):
		einfach = wert
		if is_inside_tree():
			_plane_bau()
## -1: aus dem Namen (merkmale_aus), 0 Mann, 1 Frau
@export_range(-1, 1) var weiblich: int = -1:
	set(wert):
		weiblich = wert
		if is_inside_tree():
			_plane_bau()
## Haltung im Stand: "" stehen, "reden", "sitzen", "arbeiten", "knien", "fackel", "schwert"
@export var haltung: String = "":
	set(wert):
		if wert == haltung:
			return
		haltung = wert
		if _modell != null:
			_setze_handding()
@export var bart: bool = false
## Beruf für Kleidung und Zubehör: "schmied", "koch", "magd", "wache", "ritter", "geistlich", "fischer", "knecht",
## "haendler", "kind" oder "" (dann nach dem Namen gemischt)
@export var beruf: String = "":
	set(wert):
		beruf = wert
		if is_inside_tree():
			_plane_bau()

const MODELLE := "res://modelle/figuren/"
## Farben für Hosen und Schuhe (Hemd und Rock kommen aus der Tracht)
const HOSEN := [Color(0.3, 0.25, 0.2), Color(0.22, 0.22, 0.24), Color(0.38, 0.3, 0.2), Color(0.25, 0.28, 0.22),
	Color(0.42, 0.36, 0.3), Color(0.2, 0.17, 0.14)]
const SCHUHE := [Color(0.22, 0.15, 0.1), Color(0.15, 0.11, 0.08), Color(0.3, 0.2, 0.12)]
## Schleifen-Animationen (die Bibliothek setzt sie beim Import nicht alle auf Wiederholen)
const SCHLEIFEN := ["Idle", "Idle_Talking", "Idle_Torch", "Walk", "Walk_Formal", "Jog_Fwd", "Sprint", "Sitting_Idle",
	"Sitting_Talking", "Crouch_Idle", "Crouch_Fwd", "Sword_Idle", "Fixing_Kneeling", "Swim_Idle", "Swim_Fwd", "Push",
	"Driving", "Dance", "Spell_Simple_Idle", "Pistol_Idle"]
const HALTUNGEN := {"": "Idle", "reden": "Idle_Talking", "sitzen": "Sitting_Idle", "sitzend_reden": "Sitting_Talking",
	"arbeiten": "Interact",
	"knien": "Crouch_Idle", "fackel": "Idle_Torch", "schwert": "Sword_Idle"}

static var _szenen := {}
static var _bibliothek: AnimationLibrary
static var _bibliothek_mensch: AnimationLibrary
## Realistische Menschen aus MakeHuman (modelle/figuren/menschen, gebaut mit werkzeuge/mensch_bauen.py) statt der
## Quaternius-Körper, seit 26.11.2026 Standard (docs/grafik-richtung.md). Die alten Figuren zum Vergleich: Umgebungs-
## variable FIGUREN_REALISTISCH=0 (oder Projekteinstellung sorrowland/figuren_realistisch = false).
static var realistisch: bool = _realistisch_schalter()
static func _realistisch_schalter() -> bool:
	var e := OS.get_environment("FIGUREN_REALISTISCH")
	if e != "":
		return e != "0"
	return bool(ProjectSettings.get_setting("sorrowland/figuren_realistisch", true))
const MENSCHEN := "res://modelle/figuren/menschen/"
## Vorrat (werkzeuge/menschen_vorrat.py): nach Geschlecht, Berufe mit eigener Kleidung aus Stoff
const MENSCHEN_MAENNER := ["mann_1", "mann_2", "mann_3", "mann_4", "mann_5", "mann_6"]
const MENSCHEN_FRAUEN := ["frau_1", "frau_2", "frau_3", "frau_4", "frau_5"]
## Körper mit Berufskleidung aus Stoff (Schürze, Lederschürze, Wappenrock mit Kettenhemd, Kutte): Beruf → [Männer, Frauen]
const MENSCHEN_BERUF := {"schmied": [["schmied"], []], "zeugwart": [["schmied"], []],
	"magd": [[], ["magd"]], "koch": [["koch"], ["magd"]], "wache": [["wache_1", "wache_2"], ["wache_frau"]],
	"ritter": [["wache_1", "wache_2"], ["wache_frau"]], "geistlich": [["moench"], []]}
var _stoff_ueber := false
var _wartet_auf_koerper := false   # realistischer Körper lädt noch im Hintergrund     # die Berufskleidung ist schon im Körper (Stoff), keine starren Platten anhängen
static var _modell_mats := {}
static var _koepfe := {}
var _anim: AnimationPlayer
var _modell: Node3D
var _name_text := ""
var _bau_geplant := false
var _einmal := ""        # laufende einmalige Animation (aktion)
var _gehalten: Array[Node3D] = []   # Waffen in der rechten Hand (halte)
var _blick: LookAtModifier3D
var _blickziel: Marker3D
var _anim_rest := 0.0      # noch nicht abgespielte Zeit (Animation in der Ferne seltener)
var _anim_takt := 0
var _stoff: SpringBoneSimulator3D     # schwingender Rock (realistische Menschen), nah aktiv
var _stoff_echt: Array = []           # echte Stoffe (Klasse Stoff aus dem Modul sorrowland), ganz nah statt Federknochen
var _stoff_nah := false
var _stoff_skelett: Skeleton3D        # echter Stoff wird erst eingerichtet, wenn die Figur das erste Mal nah kommt
static var _stoff_einrichtungen := {"bild": -1, "anzahl": 0}
static var _stoff_gewaermt := {}      # Modellpfade, deren Stoff schon einmal eingerichtet wurde
const STOFF_EINRICHTEN_JE_BILD := 2
const STOFF_NAH := 12.0               # bis hier echter Stoff (Rückweg mit 2 m Spielraum)

const HUEFTE := 0.93
const SCHULTER := 1.43
## Sichtweiten (Phase 1, docs/03-messgrundlage.md): Körper und Kleidung blenden bis SICHT_GROSS aus, kleine Teile
## (kürzer als KLEIN: Augen, Brauen, Gürtel, Armschienen, Hüte, Dinge in der Hand) schon bis SICHT_KLEIN und werfen
## keinen Schatten. Die Animation läuft nah jedes Bild, weiter weg seltener (ANIM_STUFEN: bis Abstand → jedes n-te
## Bild), außerhalb der Sichtweite gar nicht.
const SICHT_GROSS := 130.0
const SICHT_KLEIN := 35.0
const SICHT_FERN := 20.0     # realistische Menschen: ab hier die vereinfachte Fassung
const SICHT_RAND := 10.0
const KLEIN := 0.35
const ANIM_STUFEN := [[25.0, 1], [60.0, 2], [SICHT_GROSS, 4]]

var _teile := {}
var _phase: float = 0.0
var _gang: float = 0.0
var _letzte := Vector3.INF
var _atem: float = 0.0
static var _materialien := {}


func _ready() -> void:
	_plane_bau(true)


## Mehrere Eigenschaften ändern sich oft nacheinander (merkmale_aus, Tracht, Rock): einmal am Ende neu bauen.
## Der erste Bau (aus _ready) kommt in eine Warteschlange, die je Bild nur BAU_JE_BILD_US abarbeitet, die nächsten
## Figuren zuerst: Beim Laden einer Region sind es über hundert Figuren, alle in einem Bild gäbe einen Hänger
## (Phase 1, Punkt 2, docs/03-messgrundlage.md).
func _plane_bau(erstbau := false) -> void:
	if _bau_geplant:
		return
	_bau_geplant = true
	if erstbau and not Engine.is_editor_hint() and is_inside_tree():
		_warteschlange.append(self)
		if not get_tree().process_frame.is_connected(_bau_schritt):
			get_tree().process_frame.connect(_bau_schritt)
	else:
		_baue.call_deferred()


const BAU_JE_BILD_US := 4000
static var _warteschlange: Array = []   # Figuren (Node3D) mit geplantem ersten Bau


static func _bau_schritt() -> void:
	var baum := Engine.get_main_loop() as SceneTree
	var start := Time.get_ticks_usec()
	# ohne Typ: gelöschte Figuren ließen sich sonst nicht einmal übergeben
	_warteschlange = _warteschlange.filter(func(f: Variant) -> bool: return is_instance_valid(f) and f._bau_geplant)
	var kamera := baum.root.get_viewport().get_camera_3d()
	if kamera != null and _warteschlange.size() > 1:
		var k := kamera.global_position
		_warteschlange.sort_custom(func(a: Node3D, b: Node3D) -> bool:
			return a.global_position.distance_squared_to(k) < b.global_position.distance_squared_to(k))
	# mindestens eine je Bild, dann bis das Zeitbudget aufgebraucht ist
	while not _warteschlange.is_empty():
		var f = _warteschlange.pop_front()
		if is_instance_valid(f) and f._bau_geplant:
			f._baue()
		if Time.get_ticks_usec() - start > BAU_JE_BILD_US:
			break
	if _warteschlange.is_empty() and baum.process_frame.is_connected(_bau_schritt):
		baum.process_frame.disconnect(_bau_schritt)


func _baue() -> void:
	_bau_geplant = false
	# gehaltene Waffen retten, bevor das alte Modell verschwindet
	for w in _gehalten:
		if is_instance_valid(w) and w.get_parent() != self:
			w.get_parent().remove_child(w)
			add_child(w)
	for k in get_children():
		if k.has_meta("figur_teil"):
			k.free()
	_teile.clear()
	_modell = null
	_anim = null
	_blick = null
	_stoff = null
	_stoff_echt = []
	_stoff_nah = false
	_stoff_skelett = null
	if not einfach and not Engine.is_editor_hint() and _baue_modell():
		if _wartet_auf_koerper:
			return
		_faerben()
		_sichtweiten()
		return
	_baue_einfach()
	_sichtweiten()


## Erzeugt die Figur aus Formen. Aufbau: Glieder hängen an Gelenk-Knoten (Hüfte, Knie, Schulter, Ellbogen).
func _baue_einfach() -> void:
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
	if Engine.is_editor_hint() or (_teile.is_empty() and _anim == null):
		return
	# Eigene Geschwindigkeit über dem Boden messen: nur wenn sich die Lage geändert hat, über die Zeit seit der letzten
	# Änderung. Wer im Physiktakt bewegt wird (die Spielfigur, 60 je Sekunde), steht bei mehr Bildern je Sekunde in
	# manchen Bildern still; sonst sprang das Tempo zwischen 0 und dem Doppelten, die Animation wechselte an der Grenze
	# zum Sprint ständig und die Figur glitt (Rückmeldung 26.11.2026).
	var p := global_position
	_mess_zeit += delta
	if _letzte == Vector3.INF:
		_letzte = p
		_mess_zeit = 0.0
	elif p != _letzte:
		_tempo = Vector2(p.x - _letzte.x, p.z - _letzte.z).length() / maxf(_mess_zeit, 0.001)
		_letzte = p
		_mess_zeit = 0.0
		if _tempo > 12.0:
			_tempo = 0.0   # gesprungen (Laden, Reise): nicht gehen
	elif _mess_zeit > 0.12:
		_tempo = 0.0
	var tempo := _tempo
	if _anim != null:
		_bewege_modell(delta, tempo)
		_spiele_animation(delta)
		_schritte(delta, tempo)
		return
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
	if _modell != null:
		_faerbe_modell()
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
	if stoff == "eisen":
		# geschmiedetes Eisen: Hammerschlag und Gebrauchsspuren aus der Metalltextur, matt mit hellen Kanten statt
		# glattem Chrom (dreiplanar im Raum des Teils, wandert also mit)
		# die Farbtextur ist rostig; gepflegtes Eisen der Wachen bekommt nur Rauheit und Relief daraus, die Farbe ist
		# Stahlgrau
		m.albedo_color = Color(farbe.r * 0.8, farbe.g * 0.8, farbe.b * 0.82)
		m.metallic = 0.85
		m.roughness = 1.0
		m.roughness_texture = load("res://texturen/metall_rau.jpg")
		m.normal_enabled = true
		m.normal_texture = load("res://texturen/metall_normal.jpg")
		m.normal_scale = 0.8
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(5, 5, 5)
	if stoff == "glut":
		m.emission_enabled = true
		m.emission = Color(1.0, 0.55, 0.2)
		m.emission_energy_multiplier = 3.0
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
	_name_text = text
	bart = (h / 13) % 3 == 0
	haut = haeute[h % haeute.size()]
	haar = haare[(h / 7) % haare.size()]
	frisur = [0, 0, 1, 1, 3, 4][(h / 31) % 6]
	breite = 0.92 + ((h / 101) % 17) / 100.0
	groesse = 0.94 + ((h / 211) % 11) / 100.0
	scale = Vector3(breite, groesse, breite)


# ---------- Modell (Quaternius, CC0) ----------

static func _szene(pfad: String) -> PackedScene:
	if not _szenen.has(pfad):
		_szenen[pfad] = load(pfad) if ResourceLoader.exists(pfad) else null
	return _szenen[pfad]


static func _animationen() -> AnimationLibrary:
	if _bibliothek == null:
		var s := _szene(MODELLE + "animationen.glb")
		if s == null:
			return null
		var i := s.instantiate()
		var ap: AnimationPlayer = i.get_node("AnimationPlayer")
		_bibliothek = ap.get_animation_library("")
		for n in _bibliothek.get_animation_list():
			_bibliothek.get_animation(n).loop_mode = Animation.LOOP_LINEAR if n in SCHLEIFEN else Animation.LOOP_NONE
		i.free()
	return _bibliothek


## Ob die Figur eine Frau ist: ausdrücklich gesetzt oder aus dem Vornamen geraten (Endung -a, -e, -i, -ke,
## oder ein Titel auf -in wie Ritterin, Händlerin).
func ist_weiblich() -> bool:
	if weiblich >= 0:
		return weiblich == 1
	var worte := _name_text.split(" ", false)
	if worte.is_empty():
		return false
	if worte[0].ends_with("in") and worte.size() > 1:
		return true
	var vorname: String = worte[-2] if worte.size() >= 2 else worte[0]
	vorname = vorname.to_lower()
	if vorname in ["uwe", "ove", "ole", "kalle", "jorin", "benedikt", "arne", "uwe", "jesse", "mike"]:
		return false
	return vorname.ends_with("a") or vorname.ends_with("e") or vorname.ends_with("i") or vorname.ends_with("ke")


## Hängt die Meshes einer glTF-Szene an das Skelett der Figur (gleiche Knochen); filter: nur Meshes mit diesem
## Namensteil, ohne: alle außer denen mit diesem Namensteil.
func _haenge_an(skelett: Skeleton3D, pfad: String, filter := "", ohne := "") -> void:
	var s := _szene(pfad)
	if s == null:
		return
	var i := s.instantiate()
	for m: MeshInstance3D in i.find_children("*", "MeshInstance3D", true, false):
		if filter != "" and not filter in String(m.name):
			continue
		if ohne != "" and ohne in String(m.name):
			continue
		m.owner = null
		m.get_parent().remove_child(m)
		skelett.add_child(m)
		m.skeleton = NodePath("..")
	i.free()


func _baue_modell() -> bool:
	var w := ist_weiblich()
	if realistisch and beruf != "kind":
		return _baue_mensch(w)
	var koerper_szene := _szene(MODELLE + ("Superhero_Female_FullBody.gltf" if w else "Superhero_Male_FullBody.gltf"))
	var bib := _animationen()
	if koerper_szene == null or bib == null:
		return false
	_modell = koerper_szene.instantiate()
	_modell.name = "Modell"
	_modell.set_meta("figur_teil", true)
	_modell.rotation.y = PI          # die Modelle blicken nach +z, die Figur nach -z
	add_child(_modell)
	var skelett: Skeleton3D = _modell.get_node("Armature/Skeleton3D")
	for m: MeshInstance3D in skelett.find_children("*", "MeshInstance3D", false, false):
		if m.name.begins_with("SuperHero") or m.name.begins_with("Superhero") or m.name.begins_with("Sphere"):
			m.mesh = _nur_kopf(m.mesh, m.skin, skelett)   # der Rumpf steckt in der Kleidung
	var g := "Female_" if w else "Male_"
	if rock:
		_haenge_an(skelett, MODELLE + g + "Ranger.gltf", "", "" if frisur == 2 else "Hood")
	else:
		_haenge_an(skelett, MODELLE + g + "Peasant.gltf")
		if frisur == 2:
			_haenge_an(skelett, MODELLE + g + "Ranger.gltf", "Hood")
	# Haare unter der Gugel weglassen; die Glatze hat keine
	var haare := ""
	var bedeckt := _kopfbedeckung(w) != ""
	match (4 if bedeckt and frisur == 1 else frisur):
		0: haare = "Hair_Buns" if w else "Hair_SimpleParted"
		1: haare = "Hair_Long"
		3: haare = "Hair_BuzzedFemale" if w else "Hair_Buzzed"
	if haare != "":
		_haenge_an(skelett, MODELLE + "haare/" + haare + ".gltf")
	if bart and not w:
		_haenge_an(skelett, MODELLE + "haare/Hair_Beard.gltf")
	if frisur == 3 and beruf in ["", "haendler"]:
		_hut(skelett)
	_zubehoer(skelett, w)
	_blick_einrichten(skelett)
	_setze_handding()
	_halte_alle()
	_anim = AnimationPlayer.new()
	_anim.name = "Anim"
	_modell.add_child(_anim)
	_anim.add_animation_library("", bib)
	_anim.playback_default_blend_time = 0.25
	_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL   # siehe _spiele_animation
	_anim_takt = absi(hash(_name_text + str(get_instance_id()))) % 4                    # nicht alle im selben Bild
	_anim.play("Idle")
	_anim.seek(fmod(absf(float(hash(_name_text))) * 0.001, 2.0), true)   # nicht alle im Gleichschritt
	return true


## Realistischer Mensch (Prototyp): fertiger Körper mit Kleidung aus modelle/figuren/menschen, am selben Skelett wie
## die Quaternius-Figuren; Hut, Zubehör, Blick und Handgriffe wie dort.
func _baue_mensch(w: bool) -> bool:
	var vorrat: Array = MENSCHEN_FRAUEN if w else MENSCHEN_MAENNER
	_stoff_ueber = false
	if MENSCHEN_BERUF.has(beruf) and not (MENSCHEN_BERUF[beruf][1 if w else 0] as Array).is_empty():
		vorrat = MENSCHEN_BERUF[beruf][1 if w else 0]
		_stoff_ueber = true
	var name_: String = vorrat[absi(hash(_name_text)) % vorrat.size()]
	var pfad := MENSCHEN + name_ + "/" + name_ + ".gltf"
	# Messung 22.11.2026: das erste Laden eines Menschen kostet 100 bis 1300 ms. Alle werden im Hintergrund geladen;
	# bis ihr Körper da ist, wartet die Figur (kein Stocken im Spiel).
	if not _szenen.has(pfad):
		_menschen_vorladen()
		var stand := ResourceLoader.load_threaded_get_status(pfad)
		if stand == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			get_tree().create_timer(0.25).timeout.connect(func() -> void:
				if is_instance_valid(self):
					_plane_bau(true))
			_wartet_auf_koerper = true
			return true
		if stand == ResourceLoader.THREAD_LOAD_LOADED:
			_szenen[pfad] = ResourceLoader.load_threaded_get(pfad)
	_wartet_auf_koerper = false
	var s := _szene(pfad)
	var bib := _animationen_mensch()
	if s == null or bib == null:
		return false
	_modell = s.instantiate()
	_modell.name = "Modell"
	_modell.set_meta("figur_teil", true)
	_modell.rotation.y = PI
	add_child(_modell)
	var skelett: Skeleton3D = _modell.get_node("Armature/Skeleton3D")
	# Natürliche Größe: Die Körper sind so skaliert, dass das Becken so hoch sitzt wie beim Skelett der Animationen;
	# Frauen (tieferes Becken) wurden dadurch 1,86 m groß, größer als die Männer (1,79 m). Das ganze Modell samt
	# Animation wird auf etwa 1,62 m (Frauen) bzw. 1,74 m (Männer) gebracht, die Streuung kommt von groesse.
	var oben := _kopf_oben(skelett)
	if oben > 1.0:
		_modell.scale = Vector3.ONE * ((1.62 if w else 1.74) / oben)
	# 2,5 cm höher: Die Leute stehen auf der Kollision des Geländes, das gezeichnete Netz liegt an Hängen etwas höher
	# (andere Dreiecksteilung), dazu das Relief des Pflasters; vorher verschwanden die Füße fast im Boden
	_modell.position.y = 0.025
	for k in skelett.get_children():
		if String(k.name).ends_with("_voll"):   # nur Quelle des echten Stoffs (stoff_echt_einrichten)
			k.visible = false
	_stoff = stoff_einrichten(skelett)
	# echter Stoff erst nah (_stoff_umschalten): spart Einrichtung und Speicher für alle Figuren in der Ferne
	_stoff_skelett = skelett if ClassDB.class_exists("Stoff") and OS.get_environment("STOFF_AUS") == "" else null
	# Die erste Figur je Modell richtet ihn gleich beim Bau ein (meist hinter dem Ladevorhang): Danach liegt alles im
	# Zwischenspeicher des Moduls, und spätere Figuren brauchen unter 1 ms statt 6 bis 14 ms.
	if _stoff_skelett != null and not _stoff_gewaermt.has(pfad):
		_stoff_gewaermt[pfad] = true
		stoff_daten_vorgeben(pfad, skelett)
		_stoff_echt = stoff_echt_einrichten(skelett)
		if _stoff_echt.is_empty():
			_stoff_skelett = null
	haut_verfeinern(_modell)
	if _stoff != null:
		_stoff.reset.call_deferred()          # nach dem Aufstellen nicht vom Sprung an den Platz losschwingen
	if frisur == 3 and beruf in ["", "haendler"]:
		_hut(skelett)
	_zubehoer(skelett, w)
	# unter dem Eisenhut trägt man eine Polsterhaube: keine Haare, die durch die Glocke stechen
	if _kopfbedeckung(w) == "eisenhut":
		for k in skelett.get_children():
			if k is MeshInstance3D and String(k.name).begins_with("Haare"):
				k.visible = false
	_blick_einrichten(skelett)
	_setze_handding()
	_halte_alle()
	if getragen != "":
		trage.call_deferred(getragen)
	_anim = AnimationPlayer.new()
	_anim.name = "Anim"
	_modell.add_child(_anim)
	_anim.add_animation_library("", bib)
	_anim.playback_default_blend_time = 0.25
	_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_anim_takt = absi(hash(_name_text + str(get_instance_id()))) % 4
	_anim.play("Idle")
	_anim.seek(fmod(absf(float(hash(_name_text))) * 0.001, 2.0), true)
	return true


## Stoff, der schwingt (realistische Menschen): Der Rock hängt an Knochenketten rock_<Kette>_<Glied>
## (werkzeuge/mensch_bauen.py). Ein SpringBoneSimulator3D lässt sie mit Schwerkraft, Trägheit und Luftwiderstand
## nachschwingen; Kapseln an Ober- und Unterschenkeln schieben den Stoff vor den Beinen her. Gibt den Simulator zurück
## (oder null, wenn das Modell keinen Rock hat).
static func stoff_einrichten(skelett: Skeleton3D) -> SpringBoneSimulator3D:
	# Ketten aller Stoffteile: Rock, Schürzen, Wappenrock vorn und hinten (rock_0_0 … <Präfix>_<Kette>_<Glied>)
	var ketten: Array = []      # [Wurzel, Ende]
	for praefix in ["rock", "schuerze", "lederschuerze", "wvorn", "whinten"]:
		var c := 0
		while skelett.find_bone("%s_%d_0" % [praefix, c]) >= 0:
			var g := 0
			while skelett.find_bone("%s_%d_%d" % [praefix, c, g + 1]) >= 0:
				g += 1
			ketten.append(["%s_%d_0" % [praefix, c], "%s_%d_%d" % [praefix, c, g]])
			c += 1
	if ketten.is_empty():
		return null
	var sim := SpringBoneSimulator3D.new()
	sim.name = "Stoff"
	skelett.add_child(sim)
	sim.setting_count = ketten.size()
	var kurve := Curve.new()
	kurve.add_point(Vector2(0.0, 1.0))
	kurve.add_point(Vector2(1.0, 0.3))
	for c in ketten.size():
		var leder: bool = String(ketten[c][0]).begins_with("lederschuerze")
		sim.set_root_bone_name(c, ketten[c][0])
		sim.set_end_bone_name(c, ketten[c][1])
		sim.set_extend_end_bone(c, true)
		sim.set_end_bone_direction(c, SkeletonModifier3D.BONE_DIRECTION_PLUS_Y)
		sim.set_end_bone_length(c, 0.05)
		sim.set_radius(c, 0.012)
		# oben fast fest, zum Saum hin weich: so schwingt der Stoff unten, nicht als Ganzes; Leder ist steifer
		sim.set_stiffness(c, 6.0 if leder else 4.0)
		sim.set_stiffness_damping_curve(c, kurve)
		sim.set_drag(c, 0.7 if leder else 0.6)
		sim.set_gravity(c, 1.0)
		sim.set_enable_all_child_collisions(c, true)
	# Beine als Kapseln (entlang der Knochenachse y)
	for b: Array in [["thigh_l", 0.065], ["thigh_r", 0.065], ["calf_l", 0.05], ["calf_r", 0.05]]:
		var i := skelett.find_bone(b[0])
		var kind := skelett.find_bone("calf_l" if b[0] == "thigh_l" else "calf_r" if b[0] == "thigh_r" else
			"foot_l" if b[0] == "calf_l" else "foot_r")
		if i < 0 or kind < 0:
			continue
		var laenge := skelett.get_bone_rest(kind).origin.length()
		var k := SpringBoneCollisionCapsule3D.new()
		k.bone_name = b[0]
		k.radius = b[1]
		# am Oberschenkel erst unterhalb der Hüfte, sonst läge die Kapsel schon im Stand im Rock
		var anfang := laenge * (0.3 if b[0].begins_with("thigh") else 0.0)
		k.height = laenge - anfang + 2.0 * float(b[1])
		k.position_offset = Vector3(0, (anfang + laenge) * 0.5, 0)
		sim.add_child(k)
	return sim


## Echter Stoff (Modul sorrowland, docs/technik-weg.md): Rock, Schürzen, Wappenrock und Kettenhemd-Schoß werden nah
## als Tuch gerechnet (jede Stoffecke einzeln, Kollision mit den Beinen), weiter weg bleibt es bei den Federknochen.
## Ohne Bibliothek gibt es eine leere Liste, und alles bleibt wie bisher.
## Je Teil: [Nachgiebigkeit der Biegung, Dämpfung, Radius der Beinkapseln oben, unten, Bewegungsraum am Saum in m].
## Was über dem Rock hängt, hat dickere Kapseln (der Rock liegt dazwischen) und wenig Bewegungsraum: Bahnen sind flach
## und würden sonst hinter das Bein rutschen. Leder und Kettengeflecht sind schwer und steif.
## Dämpfung 26.11.2026 etwa verdoppelt und der Bewegungsraum des Rocks kleiner: Der Stoff schwang zu stark hin und her
## (dazu die Zeitkorrektur im Modul gegen das Zittern bei schwankender Bildzeit)
const STOFF_TEILE := {
	"Kittelrock": [0.0003, 0.13, 0.075, 0.055, 0.15],
	"Kettenhemd_rock": [0.00008, 0.22, 0.085, 0.06, 0.08],
	"Schuerze": [0.0003, 0.16, 0.1, 0.075, 0.06],
	"Lederschuerze": [0.00005, 0.22, 0.105, 0.08, 0.05],
	"Wappenrock": [0.0002, 0.16, 0.105, 0.08, 0.06],
	"Wappenrock_hinten": [0.0002, 0.16, 0.105, 0.08, 0.06],
}
## Teil → mögliche Unterlagen (die erste vorhandene zählt)
const STOFF_LAGEN := {
	"Schuerze": ["Kittelrock"],
	"Lederschuerze": ["Kittelrock"],
	"Wappenrock": ["Kettenhemd_rock", "Kittelrock"],
	"Wappenrock_hinten": ["Kettenhemd_rock", "Kittelrock"],
	"Kettenhemd_rock": ["Kittelrock"],
}
## Unter Bahnen hat der Rock eine Aussparung (werkzeuge/mensch_bauen.py, hinter_bahn), unter dem Kettenhemd ist er nur
## ein schmaler Streifen: dann bleibt er nah an seinem Platz.
const STOFF_RAUM_RUHIG := 0.07
static func stoff_echt_einrichten(skelett: Skeleton3D) -> Array:
	var stoffe: Array = []
	if not ClassDB.class_exists("Stoff"):
		return stoffe
	var huefte_knochen := skelett.find_bone("thigh_l")
	var huefte := skelett.get_bone_global_rest(huefte_knochen).origin.y if huefte_knochen >= 0 else 0.9
	for teil: String in STOFF_TEILE:
		var sichtbar := skelett.find_child(teil, false, false) as MeshInstance3D
		if sichtbar == null or sichtbar.mesh == null:
			continue
		# unter Bahnen gibt es den Rock auch ohne Aussparung (<Teil>_voll): Quelle des Stoffs
		var quelle := skelett.find_child(teil + "_voll", false, false) as MeshInstance3D
		if quelle == null or quelle.mesh == null:
			quelle = sichtbar
		var werte: Array = STOFF_TEILE[teil]
		var raum: float = werte[4]
		if teil == "Kittelrock" and (skelett.has_node("Schuerze") or skelett.has_node("Lederschuerze") or
				skelett.has_node("Wappenrock") or skelett.has_node("Kettenhemd_rock")):
			raum = STOFF_RAUM_RUHIG
		var stoff: MeshInstance3D = ClassDB.instantiate("Stoff")
		stoff.set("spielraum", raum)
		stoff.name = "Stoff_" + teil
		stoff.set("selbst_rechnen", false)
		stoff.set("biegung", werte[0])
		stoff.set("daempfung", werte[1])
		stoff.set_meta("stoff_echt", true)
		stoff.set_meta("quelle", teil)
		skelett.add_child(stoff)
		# Haftung: oben fest am Körper bis zur Hüfte (oder ab der Oberkante, wenn das Teil erst tiefer beginnt), dann
		# ein Übergang; der schmale Streifen unter dem Kettenhemd haftet nur oben (sonst kippt er als steifer Ring mit)
		var rampe := 0.04 if teil == "Kittelrock" and skelett.has_node("Kettenhemd_rock") else 0.12
		var ok: bool = stoff.call("einrichten_huefte", quelle, huefte, rampe)
		if quelle != sichtbar:
			quelle.visible = false
		if not ok:
			stoff.free()
			sichtbar.visible = true
			continue
		for b: Array in [["thigh_l", "calf_l", werte[2]], ["thigh_r", "calf_r", werte[2]],
				["calf_l", "foot_l", werte[3]], ["calf_r", "foot_r", werte[3]]]:
			stoff.call("kapsel_hinzufuegen", b[0], b[1], b[2])
		# zu Beginn fern: Teil mit Federknochen sichtbar, der Stoff wartet
		stoff.visible = false
		sichtbar.visible = true
		stoffe.append(stoff)
	# Flicken auf dem Rock hängen am Rockstoff (sonst blieben sie beim echten Stoff an den Rockknochen zurück)
	for st: Node in stoffe:
		if String(st.get_meta("quelle")) != "Kittelrock":
			continue
		for k in skelett.get_children():
			if k is MeshInstance3D and String(k.name).begins_with("Flicken") and not String(k.name).ends_with("_fern") \
					and k.get_aabb().get_center().y < 0.9:
				if st.call("anhaengen", k):
					k.visible = true   # fern weiter mit Federknochen; nah blendet _stoff_umschalten ihn aus
	# Lagen: was darüber hängt, bleibt vor dem Stoff darunter (sonst sticht der Rock durch die Schürze)
	var nach_teil := {}
	for st: Node in stoffe:
		nach_teil[String(st.get_meta("quelle"))] = st
	for oben: String in STOFF_LAGEN:
		for unten: String in STOFF_LAGEN[oben]:
			if nach_teil.has(oben) and nach_teil.has(unten):
				nach_teil[oben].call("unterlage_setzen", nach_teil[unten])
				break
	return stoffe


## Nah echter Stoff, fern Federknochen; beim Wechsel nach nah setzt sich der Stoff an seinen Platz am Körper.
func _stoff_umschalten(d: float) -> void:
	var nah := d < (STOFF_NAH + 2.0 if _stoff_nah else STOFF_NAH)
	if nah == _stoff_nah:
		return
	if nah and _stoff_echt.is_empty():
		# höchstens STOFF_EINRICHTEN_JE_BILD Figuren je Bild einrichten (sonst ein Hänger, wenn viele zugleich nah kommen)
		var bild := Engine.get_process_frames()
		if _stoff_einrichtungen["bild"] != bild:
			_stoff_einrichtungen["bild"] = bild
			_stoff_einrichtungen["anzahl"] = 0
		if _stoff_einrichtungen["anzahl"] >= STOFF_EINRICHTEN_JE_BILD:
			return
		_stoff_einrichtungen["anzahl"] += 1
		_stoff_echt = stoff_echt_einrichten(_stoff_skelett)
		if _stoff_echt.is_empty():
			_stoff_skelett = null   # nichts zu rechnen (kein Rock): bei den Federknochen bleiben
			return
	_stoff_nah = nah
	if nah:
		_stoff_takt_sicher()
	var skelett: Node = (_stoff_echt[0] as Node).get_parent()
	for st: MeshInstance3D in _stoff_echt:
		var quelle := skelett.get_node_or_null(String(st.get_meta("quelle"))) as MeshInstance3D
		if quelle != null:
			quelle.visible = not nah
			if nah:   # gefärbt wird erst nach dem Bau (Tracht): das Material des Teils übernehmen
				st.call("material_setzen", quelle.get_active_material(0))
		st.visible = nah
		if nah:
			st.call("zuruecksetzen")
	# Flicken auf dem Rock hängen an den Rockknochen und gingen beim echten Stoff nicht mit: nah ausblenden
	for k in skelett.get_children():
		if k is MeshInstance3D and String(k.name).begins_with("Flicken") and k.get_aabb().get_center().y < 0.9:
			k.visible = not nah
	if _stoff != null:
		_stoff.active = not nah


## Ein Takt für alle Stoffe (Modul sorrowland): rechnet am Ende jedes Bildes alle vorgemerkten Stoffe gemeinsam.
static var _stoff_takt: Node
func _stoff_takt_sicher() -> void:
	if is_instance_valid(_stoff_takt):   # (frisch angelegt hängt er erst am Ende des Bildes im Baum)
		return
	_stoff_takt = ClassDB.instantiate("StoffTakt")
	_stoff_takt.name = "StoffTakt"
	get_tree().root.add_child.call_deferred(_stoff_takt)


## Haut und Augen der realistischen Menschen: Licht scheint durch die Haut (Subsurface Scattering im Hautmodus, an
## Ohren und Nase stärker), Augen glänzen feucht. Die Materialien werden je Vorlage einmal angelegt und geteilt.
static var _haut_mats := {}
static func haut_verfeinern(modell: Node) -> void:
	for m: MeshInstance3D in modell.find_children("*", "MeshInstance3D", true, false):
		for i in m.mesh.get_surface_count():
			var basis := m.mesh.surface_get_material(i) as StandardMaterial3D
			if basis == null or not basis.resource_name in ["Haut", "Augen", "Haare", "Bart", "Brauen", "Wimpern"]:
				continue
			if not _haut_mats.has(basis.get_instance_id()):
				var neu: StandardMaterial3D = basis.duplicate()
				if basis.resource_name == "Haut":
					neu.subsurf_scatter_enabled = true
					neu.subsurf_scatter_skin_mode = true
					neu.subsurf_scatter_strength = 0.35
				elif basis.resource_name == "Augen":
					neu.roughness = 0.3
				else:
					# Haar: weiche Kanten statt harter Schnitte (Alpha zu Abdeckung), leichter Glanz entlang der Strähnen
					neu.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE_AND_TO_ONE
					neu.alpha_scissor_threshold = 0.3
					if basis.resource_name == "Haare":
						neu.anisotropy_enabled = true
						neu.anisotropy = 0.4
				_haut_mats[basis.get_instance_id()] = neu
			m.set_surface_override_material(i, _haut_mats[basis.get_instance_id()])


static var _vorladen_gestartet := false
## Alle realistischen Menschen im Hintergrund laden (einmal, beim ersten Bedarf).
static func _menschen_vorladen() -> void:
	if _vorladen_gestartet:
		return
	_vorladen_gestartet = true
	var namen: Array = MENSCHEN_MAENNER + MENSCHEN_FRAUEN
	for liste: Array in MENSCHEN_BERUF.values():
		for teil: Array in liste:
			namen += teil
	for n: String in namen:
		var pfad := MENSCHEN + n + "/" + n + ".gltf"
		if ResourceLoader.exists(pfad) and not _szenen.has(pfad):
			ResourceLoader.load_threaded_request(pfad)
			if ResourceLoader.exists(_stoff_daten_pfad(pfad)):
				ResourceLoader.load_threaded_request(_stoff_daten_pfad(pfad))


static func _stoff_daten_pfad(modell: String) -> String:
	return modell.get_base_dir() + "/stoff_daten.res"


## Daten der Stoffquellen aus der Datei dem Modul vorgeben (werkzeuge/stoff_daten.gd). Sonst liest der Stoff sie beim
## ersten Mal von der Grafikkarte zurück und wartet dafür eine ganze Bildzeit der Grafikkarte (Messung 24.11.2026).
## Passt eine Angabe nicht zum Modell, nimmt das Modul sie nicht an und liest wie früher zurück.
static func stoff_daten_vorgeben(modell: String, skelett: Skeleton3D) -> void:
	var pfad := _stoff_daten_pfad(modell)
	var daten: Resource
	if ResourceLoader.load_threaded_get_status(pfad) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		daten = ResourceLoader.load_threaded_get(pfad)
	elif ResourceLoader.exists(pfad):
		daten = load(pfad)
	if daten == null or not daten.has_meta("teile"):
		return
	var teile: Dictionary = daten.get_meta("teile")
	var stoff: Object = ClassDB.instantiate("Stoff")
	for teil: String in teile:
		var m := skelett.get_node_or_null(teil) as MeshInstance3D
		if m != null and m.mesh != null:
			stoff.call("quelle_vorgeben", m.mesh, teile[teil])
	stoff.free()


## Die Animationen für die MakeHuman-Körper: ohne Positionsspuren außer Wurzel und Becken, sonst zögen sie die
## Gelenke auf die Proportionen der Quaternius-Figur.
static func _animationen_mensch() -> AnimationLibrary:
	if _bibliothek_mensch == null:
		var bib := _animationen()
		if bib == null:
			return null
		_bibliothek_mensch = AnimationLibrary.new()
		for n in bib.get_animation_list():
			var an: Animation = bib.get_animation(n).duplicate(true)
			for t in range(an.get_track_count() - 1, -1, -1):
				if an.track_get_type(t) == Animation.TYPE_POSITION_3D:
					var pfad := String(an.track_get_path(t))
					if not (pfad.ends_with(":root") or pfad.ends_with(":pelvis")):
						an.remove_track(t)
			_bibliothek_mensch.add_animation(n, an)
	return _bibliothek_mensch


## Vom Grundkörper nur Kopf und Hals behalten: Dreiecke, deren Ecken alle überwiegend an Kopf- oder Halsknochen
## hängen. Einmal je Mesh berechnet und für alle Figuren geteilt.
static func _nur_kopf(mesh: Mesh, skin: Skin, skelett: Skeleton3D) -> Mesh:
	if _koepfe.has(mesh):
		return _koepfe[mesh]
	var behalten := {}
	for b in skin.get_bind_count():
		var name_ := String(skin.get_bind_name(b))
		if name_ == "":
			name_ = skelett.get_bone_name(skin.get_bind_bone(b))
		if name_ in ["Head", "neck_01"]:
			behalten[b] = true
	var neu := ImporterMesh.new()     # damit die Köpfe Detailstufen bekommen wie die importierte Kleidung
	for f in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(f)
		var knochen: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var gewichte: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var je := knochen.size() / maxi(1, (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var neu_idx := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			if _am_kopf(idx[t], je, knochen, gewichte, behalten) and _am_kopf(idx[t + 1], je, knochen, gewichte, behalten) \
					and _am_kopf(idx[t + 2], je, knochen, gewichte, behalten):
				neu_idx.append(idx[t])
				neu_idx.append(idx[t + 1])
				neu_idx.append(idx[t + 2])
		arr[Mesh.ARRAY_INDEX] = neu_idx
		for c in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
			arr[c] = null
		var flags: int = mesh.surface_get_format(f) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		neu.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, mesh.surface_get_material(f), "", flags)
	neu.generate_lods(25.0, 60.0, [])
	var fertig := neu.get_mesh()
	_koepfe[mesh] = fertig
	return fertig


static func _am_kopf(v: int, je: int, knochen: PackedInt32Array, gewichte: PackedFloat32Array, behalten: Dictionary) -> bool:
	var bester := -1
	var g := -1.0
	for k in je:
		if gewichte[v * je + k] > g:
			g = gewichte[v * je + k]
			bester = knochen[v * je + k]
	return behalten.has(bester)


## Waffe (Säbel, Muskete, Klinge eines Gegners) in die rechte Hand: der Knoten hängt an einem Griff am Handknochen,
## seine eigene Drehung (Ausholen, Blocken in kampf.gd) bleibt frei. Die Klinge zeigt beim Knoten nach -z.
func halte(waffe: Node3D) -> void:
	if einfach or waffe == null:
		return
	if not waffe in _gehalten:
		_gehalten.append(waffe)
	if _modell != null:
		_halte_alle()


func _halte_alle() -> void:
	if _modell == null:
		return
	var skelett: Skeleton3D = _modell.get_node("Armature/Skeleton3D")
	var griff := skelett.get_node_or_null("Waffenhand/Griff")
	if griff == null:
		var halter := BoneAttachment3D.new()
		halter.name = "Waffenhand"
		halter.bone_name = "hand_r"
		skelett.add_child(halter)
		griff = Node3D.new()
		griff.name = "Griff"
		griff.position = Vector3(0.0, 0.09, 0.03)
		griff.rotation = Vector3(PI / 2.0, 0.0, 0.0)   # -z der Waffe zeigt aus der Faust (+y der Hand)
		halter.add_child(griff)
	for w in _gehalten:
		if is_instance_valid(w) and w.get_parent() != griff:
			w.get_parent().remove_child(w)
			griff.add_child(w)
			w.position = Vector3.ZERO


## Fackel oder Schwert der Haltung in die rechte Hand (vorheriges entfernen)
func _setze_handding() -> void:
	var skelett: Skeleton3D = _modell.get_node("Armature/Skeleton3D")
	var alt := skelett.get_node_or_null("Handding")
	if alt:
		alt.free()
	if haltung in ["fackel", "schwert"]:
		_in_hand(skelett, haltung)
		_faerben()
		_sichtweiten()
	elif haltung == "arbeiten" and werkzeug() != "":
		_in_hand(skelett, werkzeug())
		_faerben()
		_sichtweiten()


## Etwas in der linken Hand tragen (Leute mit Arbeitsgängen, person.gd): "eimer" (mit Wasser), "kiste", "holz"
## (Scheite unter dem Arm), "sack"; "" legt es ab
var getragen := ""
func trage(was: String) -> void:
	getragen = was
	if _modell == null:
		return
	var skelett: Skeleton3D = _modell.get_node_or_null("Armature/Skeleton3D")
	if skelett == null:
		return
	var alt := skelett.get_node_or_null("Tragding")
	if alt:
		alt.free()
	if was == "":
		return
	var halter := BoneAttachment3D.new()
	halter.name = "Tragding"
	halter.bone_name = "hand_l"
	skelett.add_child(halter)
	var teile: Array = []        # [Mesh, Ort, Stoff]; lokal +y zeigt zu den Fingern (hinab)
	match was:
		"eimer":
			var z := CylinderMesh.new()
			z.top_radius = 0.15
			z.bottom_radius = 0.12
			z.height = 0.27
			z.radial_segments = 12
			teile.append([z, Vector3(0, 0.3, 0), "holz"])
			var w := CylinderMesh.new()
			w.top_radius = 0.135
			w.bottom_radius = 0.135
			w.height = 0.01
			teile.append([w, Vector3(0, 0.19, 0), "wasser"])
			teile.append([_quader(Vector3(0.3, 0.015, 0.015)), Vector3(0, 0.04, 0), "eisen"])
		"kiste":
			teile.append([_quader(Vector3(0.4, 0.3, 0.3)), Vector3(0, 0.2, 0.12), "holz"])
		"sack":
			var k := SphereMesh.new()
			k.radius = 0.2
			k.height = 0.5
			teile.append([k, Vector3(0, 0.28, 0.05), "leinen"])
		"holz":
			for i in 4:
				var sch := CylinderMesh.new()
				sch.top_radius = 0.05
				sch.bottom_radius = 0.05
				sch.height = 0.45
				sch.radial_segments = 6
				teile.append([sch, Vector3((i % 2) * 0.1 - 0.05, 0.12, 0.08 + (i / 2) * 0.09), "holz"])
	for t: Array in teile:
		var m := MeshInstance3D.new()
		m.mesh = t[0]
		m.position = t[1]
		if was == "holz":
			m.rotation.x = PI / 2.0
		m.set_meta("stoff", t[2])
		halter.add_child(m)
	_faerben()
	_sichtweiten()


## Werkzeug bei der Arbeit (Haltung "arbeiten"): nach Beruf und Name
func werkzeug() -> String:
	var n := _name_text.to_lower()
	for e: Array in [["holzhacker", "axt"], ["hinnerk scheit", "axt"], ["zimmermann", "hammer"], ["lehrling", "hammer"],
			["steinmetz", "hammer"], ["schmied", "hammer"], ["gärtner", "hacke"], ["kaplan", "buch"], ["schreiber", "buch"],
			["küster", "buch"], ["koch", "loeffel"], ["bäcker", "loeffel"], ["magd", "besen"], ["knecht", "forke"],
			["fischer", "netz"], ["stallknecht", "forke"]]:
		if e[0] in n:
			return e[1]
	match beruf:
		"schmied", "zeugwart":
			return "hammer"
		"magd":
			return "besen"
		"koch":
			return "loeffel"
		"knecht":
			return "forke"
		"geistlich":
			return "buch"
	return ""


## Fackel, Schwert oder Werkzeug in der rechten Hand
func _in_hand(skelett: Skeleton3D, was: String) -> void:
	var halter := BoneAttachment3D.new()
	halter.name = "Handding"
	halter.bone_name = "hand_r"
	skelett.add_child(halter)
	var teile: Array = []
	if was == "fackel":
		teile = [[Vector3(0.025, 0.55, 0.025), Vector3(0, 0.12, 0), "holz"], [Vector3(0.07, 0.12, 0.07), Vector3(0, 0.42, 0), "glut"]]
		var licht := OmniLight3D.new()
		licht.light_color = Color(1.0, 0.65, 0.35)
		licht.light_energy = 1.2
		licht.omni_range = 6.0
		licht.position = Vector3(0, 0.55, 0)
		halter.add_child(licht)
	elif was == "schwert":
		teile = [[Vector3(0.035, 0.18, 0.035), Vector3(0, 0.02, 0), "griff"], [Vector3(0.2, 0.03, 0.04), Vector3(0, 0.12, 0), "eisen"],
			[Vector3(0.05, 0.8, 0.012), Vector3(0, 0.53, 0), "eisen"]]
	else:
		# Werkzeug: Stiel entlang der Hand (lokal y), gehalten etwas unter der Mitte
		match was:
			"hammer":
				teile = [[Vector3(0.03, 0.34, 0.03), Vector3(0, 0.1, 0), "holz"], [Vector3(0.05, 0.05, 0.13), Vector3(0, 0.27, 0.0), "eisen"]]
			"axt":
				teile = [[Vector3(0.035, 0.7, 0.035), Vector3(0, 0.2, 0), "holz"], [Vector3(0.025, 0.1, 0.16), Vector3(0, 0.5, 0.07), "eisen"]]
			"hacke":
				teile = [[Vector3(0.03, 1.1, 0.03), Vector3(0, 0.3, 0), "holz"], [Vector3(0.12, 0.03, 0.16), Vector3(0, 0.84, 0.07), "eisen"]]
			"forke":
				teile = [[Vector3(0.03, 1.2, 0.03), Vector3(0, 0.35, 0), "holz"], [Vector3(0.18, 0.03, 0.03), Vector3(0, 0.95, 0), "eisen"]]
				for z: float in [-0.07, 0.0, 0.07]:
					teile.append([Vector3(0.012, 0.22, 0.012), Vector3(z, 1.07, 0), "eisen"])
			"besen":
				teile = [[Vector3(0.03, 1.2, 0.03), Vector3(0, 0.25, 0), "holz"], [Vector3(0.12, 0.3, 0.12), Vector3(0, 0.95, 0), "stroh"]]   # lokal +y zeigt zu den Fingern (hinab)
			"loeffel":
				teile = [[Vector3(0.02, 0.45, 0.02), Vector3(0, 0.12, 0), "holz"], [Vector3(0.07, 0.09, 0.025), Vector3(0, 0.37, 0), "holz"]]
			"buch":
				teile = [[Vector3(0.17, 0.23, 0.045), Vector3(0, 0.08, 0.06), "leder"], [Vector3(0.155, 0.215, 0.05), Vector3(0.008, 0.08, 0.06), "leinen"]]
			"netz":
				teile = [[Vector3(0.25, 0.4, 0.05), Vector3(0, -0.12, 0.05), "netz"]]
	for t: Array in teile:
		var m := MeshInstance3D.new()
		m.mesh = _quader(t[0])
		m.position = t[1]
		m.set_meta("stoff", t[2])
		halter.add_child(m)


## Welche Kopfbedeckung der Beruf mit sich bringt ("" keine)
func _kopfbedeckung(w: bool) -> String:
	match beruf:
		"magd":
			return "kopftuch" if w else ""
		"koch":
			return "muetze"
		"wache":
			return "eisenhut"
		"fischer", "knecht":
			return "strohhut"
		"haendler":
			return "haube" if w else ""
	return ""


func _kopftuch_farbe() -> Color:
	var farben := [Color(0.82, 0.78, 0.68), Color(0.55, 0.2, 0.15), Color(0.3, 0.38, 0.5), Color(0.6, 0.55, 0.3)]
	return farben[absi(hash(_name_text + "t")) % farben.size()]


## Ein Teil am Knochen befestigen; ort und dreh sind im Raum des Skeletts gemeint (Blick nach +z), der Halter
## rechnet sie in den Raum des Knochens um, damit das Teil der Bewegung folgt.
func _anhaengen(skelett: Skeleton3D, knochen: String, mesh: Mesh, stoff: String, ort: Vector3, dreh := Basis()) -> void:
	var i := skelett.find_bone(knochen)
	if i < 0:
		return
	var halter := skelett.get_node_or_null("Zubehoer_" + knochen) as BoneAttachment3D
	if halter == null:
		halter = BoneAttachment3D.new()
		halter.name = "Zubehoer_" + knochen
		halter.bone_name = knochen
		skelett.add_child(halter)
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.set_meta("stoff", stoff)
	m.transform = skelett.get_bone_global_rest(i).affine_inverse() * Transform3D(dreh, ort)
	halter.add_child(m)


func _knochen_ort(skelett: Skeleton3D, knochen: String) -> Vector3:
	var i := skelett.find_bone(knochen)
	return skelett.get_bone_global_rest(i).origin if i >= 0 else Vector3.ZERO


## Kleidung und Zubehör nach Beruf: Schürzen, Kopftuch, Helm, Hüte, Wappenrock, Talar, Gürteltasche
func _zubehoer(skelett: Skeleton3D, w: bool) -> void:
	var becken := _knochen_ort(skelett, "pelvis")
	var brust := _knochen_ort(skelett, "spine_03")
	var kopf := _knochen_ort(skelett, "Head")
	var h := absi(hash(_name_text))
	var kasten := func(groesse_: Vector3) -> BoxMesh:
		var b := BoxMesh.new()
		b.size = groesse_
		return b
	# Realistische Menschen tragen Berufskleidung aus Stoff (Körper aus MENSCHEN_BERUF); wo es keinen gibt, bleibt es
	# beim Kittel: keine starren Platten als Schürze, Wappenrock oder Talar (sahen aus wie aufgeklebt)
	var platten := beruf
	if _stoff_ueber or (realistisch and beruf != "kind" and beruf != "haendler"):
		platten = ""
	match platten:
		"schmied", "zeugwart":
			_anhaengen(skelett, "spine_02", kasten.call(Vector3(0.4, 0.95, 0.02)), "leder", Vector3(0, brust.y - 0.42, 0.16))
			_anhaengen(skelett, "spine_03", kasten.call(Vector3(0.36, 0.02, 0.02)), "leder", Vector3(0, brust.y + 0.05, 0.15))
		"koch", "magd":
			_anhaengen(skelett, "pelvis", kasten.call(Vector3(0.38, 0.6, 0.015)), "leinen", Vector3(0, becken.y - 0.26, 0.14))
		"wache", "ritter":
			for seite: float in [1.0, -1.0]:
				_anhaengen(skelett, "spine_02", kasten.call(Vector3(0.42, 0.85, 0.02)), "wappen",
					Vector3(0, brust.y - 0.3, 0.155 * seite))
			_anhaengen(skelett, "spine_02", kasten.call(Vector3(0.12, 0.16, 0.012)), "zeichen", Vector3(0, brust.y - 0.05, 0.168))
		"geistlich":
			var talar := CylinderMesh.new()
			talar.top_radius = 0.2
			talar.bottom_radius = 0.34
			talar.height = becken.y - 0.05
			talar.radial_segments = 14
			_anhaengen(skelett, "pelvis", talar, "talar", Vector3(0, becken.y / 2.0 + 0.02, 0))
		"haendler":
			_anhaengen(skelett, "pelvis", kasten.call(Vector3(0.13, 0.16, 0.06)), "leder", Vector3(0.2, becken.y - 0.05, 0.06))
	# Gürteltasche bei manchen anderen auch
	if beruf in ["", "knecht", "fischer"] and h % 3 == 0:
		_anhaengen(skelett, "pelvis", kasten.call(Vector3(0.12, 0.14, 0.06)), "leder", Vector3(-0.2, becken.y - 0.05, 0.05))
	var oben := _kopf_oben(skelett)
	match _kopfbedeckung(w):
		"kopftuch":
			# eine Halbkugel, die Scheitel und Hinterkopf umschließt (vorher eine Kugel um den Scheitel: Sie schwebte halb
			# über dem Kopf, Rückmeldung 27.11.2026), dazu der Zipfel im Nacken
			var tuch := SphereMesh.new()
			tuch.radius = 0.104
			tuch.height = 0.104
			tuch.is_hemisphere = true
			tuch.radial_segments = 24
			tuch.rings = 8
			_anhaengen(skelett, "Head", tuch, "kopftuch", Vector3(0, oben - 0.1, -0.02),
				Basis(Vector3.RIGHT, deg_to_rad(-30)).scaled(Vector3(0.98, 1.2, 1.12)))
			_anhaengen(skelett, "Head", kasten.call(Vector3(0.16, 0.2, 0.02)), "kopftuch", Vector3(0, oben - 0.17, -0.1))
		"muetze":
			var m := CylinderMesh.new()
			m.top_radius = 0.12
			m.bottom_radius = 0.105
			m.height = 0.16
			_anhaengen(skelett, "Head", m, "leinen", Vector3(0, oben + 0.0, -0.01))
		"eisenhut":
			# etwas länger als breit (wie ein Kopf) und nach hinten gesetzt, sonst sticht der Hinterkopf durch
			_anhaengen(skelett, "Head", _eisenhut(), "eisen", Vector3(0, oben - 0.072, -0.028),
				Basis().scaled(Vector3(1.04, 1.0, 1.1)))
			# Polsterhaube aus Leinen darunter: bedeckt Scheitel, Hinterkopf und Ohren, das Gesicht bleibt frei
			var haube := SphereMesh.new()
			haube.radius = 0.1
			haube.height = 0.1
			haube.is_hemisphere = true
			haube.radial_segments = 24
			haube.rings = 8
			_anhaengen(skelett, "Head", haube, "leinen", Vector3(0, oben - 0.112, -0.025),
				Basis(Vector3.RIGHT, deg_to_rad(-38)).scaled(Vector3(0.95, 1.25, 1.12)))
		"strohhut":
			var krempe2 := CylinderMesh.new()
			krempe2.top_radius = 0.26
			krempe2.bottom_radius = 0.28
			krempe2.height = 0.025
			_anhaengen(skelett, "Head", krempe2, "stroh", Vector3(0, oben - 0.02, -0.01))
			var kegel := CylinderMesh.new()
			kegel.top_radius = 0.05
			kegel.bottom_radius = 0.12
			kegel.height = 0.12
			_anhaengen(skelett, "Head", kegel, "stroh", Vector3(0, oben + 0.05, -0.01))
		"haube":
			var haube := SphereMesh.new()
			haube.radius = 0.106
			haube.height = 0.106
			haube.is_hemisphere = true
			haube.radial_segments = 24
			haube.rings = 8
			_anhaengen(skelett, "Head", haube, "leinen", Vector3(0, oben - 0.1, -0.02),
				Basis(Vector3.RIGHT, deg_to_rad(-25)).scaled(Vector3(1.0, 1.15, 1.12)))


## Oberkante des Kopfes im Raum des Skeletts: bei realistischen Menschen der Scheitel des Körpers (ohne Haare), sonst
## wie bisher 12 cm über dem Kopfknochen (Quaternius)
func _kopf_oben(skelett: Skeleton3D) -> float:
	var koerper := skelett.get_node_or_null("Koerper") as MeshInstance3D
	if koerper != null and koerper.mesh != null:
		return koerper.mesh.get_aabb().end.y
	return _knochen_ort(skelett, "Head").y + 0.12


## Eisenhut (Kesselhut, 13.–15. Jh.): gewölbte Glocke mit leichtem Grat, Verstärkungsband mit Nieten, abfallende
## Krempe mit gerolltem Rand. Ein Drehkörper aus einem geschlossenen Profil (außen, Rand, unten, innen), damit man
## auch von unten keine Lücke sieht. Der Ursprung liegt auf Höhe des Bandes.
static var _eisenhut_mesh: ArrayMesh
static func _eisenhut() -> ArrayMesh:
	if _eisenhut_mesh != null:
		return _eisenhut_mesh
	var profil: Array[Vector2] = []       # (Radius, Höhe), von der Spitze außen herum bis zur Spitze innen
	for k in 13:                          # Glocke: oben leicht spitz (Grat), unten fast senkrecht
		var t := float(k) / 12.0
		var w := t * PI / 2.0
		profil.append(Vector2(0.122 * sin(w), 0.004 + 0.128 * pow(cos(w), 0.85)))
	profil.append_array([Vector2(0.127, 0.0), Vector2(0.13, -0.006), Vector2(0.128, -0.014),       # Band
		Vector2(0.16, -0.026), Vector2(0.19, -0.04), Vector2(0.212, -0.051),                           # Krempe
		Vector2(0.219, -0.056), Vector2(0.218, -0.063), Vector2(0.211, -0.062),                        # Rollrand
		Vector2(0.188, -0.047), Vector2(0.158, -0.032), Vector2(0.124, -0.018)])                       # unten zurück
	for k in range(12, -1, -1):           # innen, 4 mm dünner
		var t := float(k) / 12.0
		var w := t * PI / 2.0
		profil.append(Vector2(0.118 * sin(w), -0.012 + 0.14 * pow(cos(w), 0.85)))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEG := 40
	for i in SEG:
		var a0 := TAU * i / SEG
		var a1 := TAU * (i + 1) / SEG
		for k in profil.size() - 1:
			var p := profil[k]
			var q := profil[k + 1]
			var ecken := [Vector3(cos(a0) * p.x, p.y, sin(a0) * p.x), Vector3(cos(a0) * q.x, q.y, sin(a0) * q.x),
				Vector3(cos(a1) * q.x, q.y, sin(a1) * q.x), Vector3(cos(a1) * p.x, p.y, sin(a1) * p.x)]
			for j: int in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(ecken[j])
	st.generate_normals()
	_eisenhut_mesh = st.commit()
	# Nieten am Band (eigene Fläche: SurfaceTool mischt Ecken ohne und mit Normalen nicht)
	var niete := SphereMesh.new()
	niete.radius = 0.0055
	niete.height = 0.008
	niete.radial_segments = 6
	niete.rings = 3
	var st2 := SurfaceTool.new()
	for i in 12:
		var a := TAU * (i + 0.5) / 12.0
		st2.append_from(niete, 0, Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * 0.131, -0.007, sin(a) * 0.131)))
	st2.commit(_eisenhut_mesh)
	return _eisenhut_mesh


## Kopf dreht sich zu einem Ziel (schaue_auf), weich und innerhalb natürlicher Grenzen
func _blick_einrichten(skelett: Skeleton3D) -> void:
	var ziel := get_node_or_null("Blickziel") as Marker3D
	if ziel == null:
		ziel = Marker3D.new()
		ziel.name = "Blickziel"
		add_child(ziel)
	var blick := LookAtModifier3D.new()
	blick.name = "Blick"
	blick.bone_name = "Head"
	blick.forward_axis = SkeletonModifier3D.BONE_AXIS_PLUS_Z
	blick.primary_rotation_axis = Vector3.AXIS_Y
	blick.use_angle_limitation = true
	blick.symmetry_limitation = true
	blick.primary_limit_angle = deg_to_rad(140.0)
	blick.secondary_limit_angle = deg_to_rad(50.0)
	blick.duration = 0.5
	blick.influence = 0.0
	skelett.add_child(blick)
	blick.target_node = blick.get_path_to(ziel)
	_blick = blick
	_blickziel = ziel


## Den Kopf zu einem Punkt drehen (staerke 0 bis 1; 0: geradeaus)
func schaue_auf(punkt: Vector3, staerke: float, delta: float) -> void:
	if _blick == null or not is_instance_valid(_blick):
		return
	if staerke > 0.0:
		_blickziel.global_position = punkt
	_blick.influence = move_toward(_blick.influence, staerke, delta * 2.0)


## Breitkrempiger Filzhut am Kopfknochen
func _hut(skelett: Skeleton3D) -> void:
	# realistische Menschen: auf den Scheitel des Körpers (wie die anderen Kopfbedeckungen)
	if skelett.get_node_or_null("Koerper") != null:
		var oben := _kopf_oben(skelett)
		_anhaengen(skelett, "Head", _zylinder(0.2, 0.2, 0.02), "hut", Vector3(0, oben - 0.045, -0.01))
		_anhaengen(skelett, "Head", _zylinder(0.1, 0.115, 0.11), "hut", Vector3(0, oben + 0.005, -0.01))
		return
	var halter := BoneAttachment3D.new()
	halter.bone_name = "Head"
	skelett.add_child(halter)
	for teil: Array in [[0.2, 0.2, 0.02, 0.17], [0.1, 0.115, 0.11, 0.235]]:
		var m := MeshInstance3D.new()
		m.mesh = _zylinder(teil[0], teil[1], teil[2])
		m.position = Vector3(0, teil[3], 0.01)
		m.set_meta("stoff", "hut")
		halter.add_child(m)


func _faerbe_modell() -> void:
	var klar := func(c: Color, k: float) -> Color:
		return Color(clampf(c.r * k, 0.0, 1.6), clampf(c.g * k, 0.0, 1.6), clampf(c.b * k, 0.0, 1.6))
	var tracht_ton: Color = klar.call(tracht, 2.3)
	for m: MeshInstance3D in _modell.find_children("*", "MeshInstance3D", true, false):
		if m.has_meta("stoff"):
			var st: String = m.get_meta("stoff")
			var farbe := {"hut": tracht.darkened(0.3), "holz": Color(0.35, 0.24, 0.14), "griff": Color(0.25, 0.16, 0.1),
				"eisen": Color(0.62, 0.63, 0.66), "glut": Color(1.0, 0.6, 0.25), "leder": Color(0.3, 0.19, 0.11),
				"leinen": Color(0.86, 0.83, 0.75), "stroh": Color(0.8, 0.68, 0.38), "kopftuch": _kopftuch_farbe(),
				"wappen": Color(0.55, 0.08, 0.06), "zeichen": Color(0.85, 0.65, 0.2),
				"talar": tracht.darkened(0.2), "netz": Color(0.45, 0.4, 0.3), "wasser": Color(0.12, 0.16, 0.16)}.get(st, tracht) as Color
			m.material_override = _material(farbe, st)
			continue
		var name_ := String(m.name)
		for i in m.mesh.get_surface_count():
			var basis := m.mesh.surface_get_material(i) as StandardMaterial3D
			if basis == null:
				continue
			var mat_name := basis.resource_name
			var ton := Color.WHITE
			if "Hair" in mat_name or "Hair" in name_ or "Eyebrows" in name_:
				ton = klar.call(haar, 2.4)
			elif "Superhero" in mat_name or "Regular" in mat_name:
				ton = klar.call(haut, 1.15)
			elif "Belt" in name_ and kordel_farbe.a > 0.0:
				ton = klar.call(kordel_farbe, 1.6)
			elif "Peasant" in mat_name or "Ranger" in mat_name:
				var h := absi(hash(_name_text))
				if "Legs" in name_:
					ton = klar.call(HOSEN[(h / 3) % HOSEN.size()], 2.3)
				elif "Feet" in name_:
					ton = klar.call(SCHUHE[(h / 5) % SCHUHE.size()], 2.3)
				else:
					ton = tracht_ton
			elif mat_name == "Kittel":          # realistischer Mensch: Stoffe sind grau, die Tracht färbt
				ton = klar.call(tracht, 1.7)
			elif mat_name == "Schuerze":
				ton = Color(0.86, 0.83, 0.75)
			elif mat_name == "Wappen":
				ton = klar.call(Color(0.55, 0.08, 0.06), 1.5)
			elif mat_name == "Beinlinge":
				ton = klar.call(HOSEN[(absi(hash(_name_text)) / 3) % HOSEN.size()], 1.4)
			elif mat_name == "Leder" and kordel_farbe.a > 0.0 and "Guertel" in name_:
				ton = klar.call(kordel_farbe, 1.6)
			elif mat_name in ["Haut", "Augen", "Brauen", "Wimpern", "Leder", "Schuhleder", "Haare", "Lederbahn", "Bart", "Kettenhemd", "Flicken"]:
				continue
			elif "Eye" in mat_name:
				continue
			var schluessel := "%d|%s" % [basis.get_instance_id(), ton.to_html()]
			if not _modell_mats.has(schluessel):
				var neu: StandardMaterial3D = basis.duplicate()
				neu.albedo_color = ton
				_modell_mats[schluessel] = neu
			m.set_surface_override_material(i, _modell_mats[schluessel])


func hat_modell() -> bool:
	return _anim != null


## Spielt die Animation weiter: nah jedes Bild, weiter weg nur jedes n-te Bild (mit der aufgelaufenen Zeit), außerhalb
## der Sichtweite gar nicht (die Zeit läuft auf, damit die Bewegung beim Wiederauftauchen stimmt; höchstens 1 s).
func _spiele_animation(delta: float) -> void:
	_anim_rest = minf(_anim_rest + delta, 1.0)
	var kamera := get_viewport().get_camera_3d()
	var n := 1
	if kamera != null:
		var d := kamera.global_position.distance_to(global_position)
		if _stoff_skelett != null:
			_stoff_umschalten(d)
		if _stoff != null and not _stoff_nah:
			_stoff.active = d < 30.0      # schwingender Stoff nur nah
		n = 0
		for stufe: Array in ANIM_STUFEN:
			if d < float(stufe[0]):
				n = stufe[1]
				break
	if n == 0:
		return
	_anim_takt += 1
	if _anim_takt % n == 0:
		var schritt := _anim_rest
		_anim.advance(_anim_rest)
		_anim_rest = 0.0
		if _stoff_nah:
			# gerechnet wird am Ende des Bildes für alle Figuren gemeinsam, verteilt auf alle Kerne (StoffTakt)
			for st in _stoff_echt:
				st.vormerken(schritt)


## Sichtweiten und Schatten aller Teile (nach jedem Bau): kleine Teile ohne Schatten und nur nah, große mit weichem
## Ausblenden am Ende der Sichtweite.
func _sichtweiten() -> void:
	for m: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if m.mesh == null or m.has_meta("stoff_echt") or String(m.name).ends_with("_voll"):
			continue
		var klein := m.mesh.get_aabb().get_longest_axis_size() < KLEIN
		m.visibility_range_end = SICHT_KLEIN if klein else SICHT_GROSS
		m.visibility_range_end_margin = SICHT_RAND * (0.4 if klein else 1.0)
		m.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		# realistische Menschen: nah die volle Fassung, ab SICHT_FERN die vereinfachte (<Teil>_fern)
		var name_ := String(m.name)
		if name_.ends_with("_fern"):
			m.visibility_range_begin = SICHT_FERN
			m.visibility_range_begin_margin = 2.0
		elif m.get_parent() != null and m.get_parent().has_node(name_ + "_fern"):
			m.visibility_range_end = SICHT_FERN
			m.visibility_range_end_margin = 2.0
		if klein:
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Einmalige Bewegung (z. B. "Sword_Attack", "Hit_Chest", "Interact", "PickUp_Table", "Death01"); danach geht es mit
## Stehen oder Gehen weiter (außer beim Tod).
func aktion(name_: String) -> void:
	if _anim == null or not _anim.has_animation(name_):
		return
	_einmal = name_
	_anim.play(name_, 0.15)


## Schritte (autoload/klang.gd) genau dann, wenn ein Fuß aufsetzt: Die Höhe der Fußknochen kommt aus der Animation;
## sinkt ein Fuß und steht dann (tiefster Punkt nahe seiner Ruhehöhe), ist das ein Schritt. Für Leute nur nahe der
## Kamera; die Spielfigur stellt Lautstärke und Untergrund selbst ein (schritt_laut, schritt_untergrund).
var _tempo := 0.0
var _mess_zeit := 0.0
var schritt_laut := -6.0
var schritt_untergrund := Callable()
var _fuss_y := [INF, INF]
var _fuss_sinkt := [false, false]
var _fuss_knochen := [-1, -1]
var _fuss_ruhe := [0.0, 0.0]
var _fuss_skelett: Skeleton3D = null
func _schritte(_delta: float, tempo: float) -> void:
	if tempo < 0.4 or _modell == null:
		_fuss_y = [INF, INF]
		return
	if schritt_untergrund.is_null():
		var kamera := get_viewport().get_camera_3d()
		if kamera == null or kamera.global_position.distance_squared_to(global_position) > 196.0:
			return
	if _fuss_skelett == null or not is_instance_valid(_fuss_skelett):
		_fuss_skelett = _modell.find_child("Skeleton3D", true, false) as Skeleton3D
		if _fuss_skelett == null:
			return
		for i in 2:
			_fuss_knochen[i] = _fuss_skelett.find_bone(["foot_l", "foot_r"][i])
			if _fuss_knochen[i] >= 0:
				_fuss_ruhe[i] = _fuss_skelett.get_bone_global_rest(_fuss_knochen[i]).origin.y
	for i in 2:
		if _fuss_knochen[i] < 0:
			continue
		var y := _fuss_skelett.get_bone_global_pose(_fuss_knochen[i]).origin.y
		if _fuss_y[i] != INF:
			var dy: float = y - _fuss_y[i]
			if _fuss_sinkt[i] and dy >= -0.0005 and y < _fuss_ruhe[i] + 0.06:
				_schritt_hoeren(i)
			_fuss_sinkt[i] = dy < -0.002
		_fuss_y[i] = y


func _schritt_hoeren(fuss: int) -> void:
	var klang := get_node_or_null("/root/Klang")
	if klang == null:
		return
	var ort := global_position
	if _fuss_skelett != null:
		ort = _fuss_skelett.global_transform * _fuss_skelett.get_bone_global_pose(_fuss_knochen[fuss]).origin
	var spieler := schritt_untergrund.is_valid()
	# Leute nur in der Nähe hören (sonst klappert es bei zweihundert Figuren überall), leiser als der Spieler
	if not spieler:
		var kamera := get_viewport().get_camera_3d() if get_viewport() != null else null
		if kamera == null or kamera.global_position.distance_squared_to(ort) > 196.0:
			return
	var untergrund: String = schritt_untergrund.call() if spieler else klang.untergrund_gelaende(ort)
	klang.schritt(ort, untergrund, schritt_laut, 22.0 if spieler else 14.0)


func _bewege_modell(delta: float, tempo: float) -> void:
	if _einmal != "":
		if _anim.current_animation == _einmal and _anim.is_playing():
			return
		if _einmal == "Death01":
			return
		_einmal = ""
	_gang = lerpf(_gang, tempo, clampf(delta * 6.0, 0.0, 1.0))
	var ziel := HALTUNGEN.get(haltung, "Idle") as String
	var tempo_anim := 1.0
	# mit Spielraum an den Grenzen (sonst wechselt die Animation hin und her)
	var jetzt := _anim.current_animation
	if _gang > (4.0 if jetzt == "Sprint" else 4.5):
		ziel = "Sprint"
		tempo_anim = _gang / 6.0
	elif _gang > (2.1 if jetzt in ["Jog_Fwd", "Sprint"] else 2.5):
		ziel = "Jog_Fwd"
		tempo_anim = _gang / 3.4
	elif _gang > 0.25:
		ziel = "Walk"
		tempo_anim = clampf(_gang / 1.45, 0.4, 1.6)
	elif haltung == "arbeiten":
		tempo_anim = 0.8
	if _anim.current_animation != ziel:
		_anim.play(ziel)
	_anim.speed_scale = tempo_anim
