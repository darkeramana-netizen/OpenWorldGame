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

const MODELLE := "res://modelle/figuren/"
## Schleifen-Animationen (die Bibliothek setzt sie beim Import nicht alle auf Wiederholen)
const SCHLEIFEN := ["Idle", "Idle_Talking", "Idle_Torch", "Walk", "Walk_Formal", "Jog_Fwd", "Sprint", "Sitting_Idle",
	"Sitting_Talking", "Crouch_Idle", "Crouch_Fwd", "Sword_Idle", "Fixing_Kneeling", "Swim_Idle", "Swim_Fwd", "Push",
	"Driving", "Dance", "Spell_Simple_Idle", "Pistol_Idle"]
const HALTUNGEN := {"": "Idle", "reden": "Idle_Talking", "sitzen": "Sitting_Idle", "sitzend_reden": "Sitting_Talking",
	"arbeiten": "Interact",
	"knien": "Crouch_Idle", "fackel": "Idle_Torch", "schwert": "Sword_Idle"}

static var _szenen := {}
static var _bibliothek: AnimationLibrary
static var _modell_mats := {}
static var _koepfe := {}
var _anim: AnimationPlayer
var _modell: Node3D
var _name_text := ""
var _bau_geplant := false
var _einmal := ""        # laufende einmalige Animation (aktion)
var _gehalten: Array[Node3D] = []   # Waffen in der rechten Hand (halte)

const HUEFTE := 0.93
const SCHULTER := 1.43

var _teile := {}
var _phase: float = 0.0
var _gang: float = 0.0
var _letzte := Vector3.INF
var _atem: float = 0.0
static var _materialien := {}


func _ready() -> void:
	_plane_bau()


## Mehrere Eigenschaften ändern sich oft nacheinander (merkmale_aus, Tracht, Rock): einmal am Ende neu bauen.
func _plane_bau() -> void:
	if _bau_geplant:
		return
	_bau_geplant = true
	_baue.call_deferred()


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
	if not einfach and not Engine.is_editor_hint() and _baue_modell():
		_faerben()
		return
	_baue_einfach()


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
	# Eigene Geschwindigkeit über dem Boden messen
	var p := global_position
	var tempo := 0.0
	if _letzte != Vector3.INF and delta > 0.0:
		tempo = Vector2(p.x - _letzte.x, p.z - _letzte.z).length() / delta
	_letzte = p
	if tempo > 12.0:
		tempo = 0.0   # gesprungen (Laden, Reise): nicht gehen
	if _anim != null:
		_bewege_modell(delta, tempo)
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
		m.metallic = 0.8
		m.roughness = 0.35
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
		m.visibility_range_end = 140.0
	i.free()


func _baue_modell() -> bool:
	var w := ist_weiblich()
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
		m.visibility_range_end = 140.0
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
	match frisur:
		0: haare = "Hair_Buns" if w else "Hair_SimpleParted"
		1: haare = "Hair_Long"
		3: haare = "Hair_BuzzedFemale" if w else "Hair_Buzzed"
	if haare != "":
		_haenge_an(skelett, MODELLE + "haare/" + haare + ".gltf")
	if bart and not w:
		_haenge_an(skelett, MODELLE + "haare/Hair_Beard.gltf")
	if frisur == 3:
		_hut(skelett)
	_setze_handding()
	_halte_alle()
	_anim = AnimationPlayer.new()
	_anim.name = "Anim"
	_modell.add_child(_anim)
	_anim.add_animation_library("", bib)
	_anim.playback_default_blend_time = 0.25
	_anim.play("Idle")
	_anim.seek(fmod(absf(float(hash(_name_text))) * 0.001, 2.0), true)   # nicht alle im Gleichschritt
	return true


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
	var neu := ArrayMesh.new()
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
		neu.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
		neu.surface_set_material(f, mesh.surface_get_material(f))
	_koepfe[mesh] = neu
	return neu


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


## Fackel oder Schwert in der rechten Hand
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
	else:
		teile = [[Vector3(0.035, 0.18, 0.035), Vector3(0, 0.02, 0), "griff"], [Vector3(0.2, 0.03, 0.04), Vector3(0, 0.12, 0), "eisen"],
			[Vector3(0.05, 0.8, 0.012), Vector3(0, 0.53, 0), "eisen"]]
	for t: Array in teile:
		var m := MeshInstance3D.new()
		m.mesh = _quader(t[0])
		m.position = t[1]
		m.set_meta("stoff", t[2])
		halter.add_child(m)


## Breitkrempiger Filzhut am Kopfknochen
func _hut(skelett: Skeleton3D) -> void:
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
				"eisen": Color(0.62, 0.63, 0.66), "glut": Color(1.0, 0.6, 0.25)}.get(st, tracht) as Color
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
				ton = tracht_ton
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


## Einmalige Bewegung (z. B. "Sword_Attack", "Hit_Chest", "Interact", "PickUp_Table", "Death01"); danach geht es mit
## Stehen oder Gehen weiter (außer beim Tod).
func aktion(name_: String) -> void:
	if _anim == null or not _anim.has_animation(name_):
		return
	_einmal = name_
	_anim.play(name_, 0.15)


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
	if _gang > 4.2:
		ziel = "Sprint"
		tempo_anim = _gang / 6.0
	elif _gang > 2.3:
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
