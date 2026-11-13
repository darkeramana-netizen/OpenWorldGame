@tool
class_name Tier
extends Node3D
## Ein Tier aus den freien Modellen von Quaternius (CC0; modelle/tiere): Pferd, Kuh, Schaf, Schwein, Hund, Katze,
## Wolf, Lama. Das Modell wird auf die echte Höhe gebracht und eingefärbt. Füße bei y = 0, Blick nach -z.
##
## Verhalten (nur im Spiel): Mit einem Revier (Vieleck in Weltkoordinaten x, z) zieht das Tier darin umher: es steht
## eine Weile (Vieh grast dabei), sucht sich dann ein Ziel, zu dem der Weg frei ist (Strahl gegen Mauern, Zäune,
## Häuser), und geht hin. Scheue Tiere (Schafe, Katzen, Schweine) laufen vor dem Spieler weg, Hunde schließen sich
## ihm manchmal eine Weile an. Ohne Revier bleibt das Tier stehen (angebundene Pferde). Weit weg vom Spieler ruht
## das Verhalten. Eine mitbewegte Kollision hält den Spieler ab (Bodenstrahlen überspringen sie: Meta "tier").

@export_enum("Pferd", "Kuh", "Schaf", "Schwein", "Hund", "Katze", "Wolf", "Lama") var art: int = 0:
	set(wert):
		art = wert
		if is_inside_tree():
			_baue()
## Farbe des Fells (Alpha 0: wie im Modell); bei Pferden und Kühen wird nur der Körper getönt
@export var fell: Color = Color(0, 0, 0, 0):
	set(wert):
		fell = wert
		if is_inside_tree():
			_baue()
## Revier (Welt x, z); leer: bleibt an seinem Platz
@export var revier := PackedVector2Array()

const DATEIEN := ["Horse", "Cow", "Sheep", "Pig", "Dog", "Cat", "Wolf", "Llama"]
## Höhe bis zum höchsten Punkt (Kopf) in Metern
const HOEHEN := [2.1, 1.6, 1.05, 0.95, 0.75, 0.36, 0.95, 1.9]
## Fellfarbe, wenn keine angegeben ist
const FELLE := {4: Color(0.55, 0.4, 0.27), 5: Color(0.78, 0.52, 0.3), 6: Color(0.5, 0.5, 0.52)}
## Gehen und Laufen in m/s
const GEHEN := [1.2, 0.8, 0.9, 0.8, 1.4, 1.0, 1.4, 1.0]
const LAUFEN := [5.0, 3.0, 3.2, 2.8, 4.5, 3.8, 5.0, 3.5]
## Kollision: halbe Breite, Höhe, halbe Länge
const KOERPER := [Vector3(0.35, 1.7, 1.1), Vector3(0.4, 1.4, 1.0), Vector3(0.3, 0.9, 0.55), Vector3(0.3, 0.8, 0.6),
	Vector3(0.18, 0.6, 0.4), Vector3(0.1, 0.3, 0.25), Vector3(0.2, 0.8, 0.5), Vector3(0.3, 1.7, 0.7)]
## Ohne eigenes Gehen leihen sie es von der Kuh (gleiches Skelett)
const OHNE_GEHEN := [2, 3, 7]
const SCHEU := [2, 3, 5]

static var _szenen := {}
static var _mats := {}
static var _geliehen: AnimationLibrary

enum Zustand { STEHEN, GEHEN, FLIEHEN, FOLGEN }

var _anim: AnimationPlayer
var _namen := {}
var _letzte := Vector3.INF
var _gang := 0.0
var _zustand := Zustand.STEHEN
var _ziel := Vector3.ZERO
var _warten := 0.0
var _pruef := 0.0
var _boden_takt := 0.0
var _folgen_bis := 0.0
var _ruhe := false
var _zufall := RandomNumberGenerator.new()


func _ready() -> void:
	_baue()
	if Engine.is_editor_hint():
		return
	add_to_group("tiere")
	_zufall.seed = hash(Vector2i(int(global_position.x * 10.0), int(global_position.z * 10.0)))
	_warten = _zufall.randf_range(1.0, 8.0)
	# mitbewegte Kollision (wie bei Gegnern auf Ebene 3): Spieler und Leute laufen nicht durch
	var k := AnimatableBody3D.new()
	k.name = "Koerper"
	k.collision_layer = 1
	k.collision_mask = 0
	k.set_meta("tier", true)     # Bodenstrahlen von Leuten und Tieren überspringen Tierkörper
	var form := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var e: Vector3 = KOERPER[art]
	box.size = Vector3(e.x * 2.0, e.y, e.z * 2.0)
	form.shape = box
	form.position = Vector3(0, e.y / 2.0, 0)
	k.add_child(form)
	add_child(k)


func _baue() -> void:
	for k in get_children():
		if k.has_meta("tier_teil"):
			k.free()
	_anim = null
	var pfad := "res://modelle/tiere/%s.fbx" % DATEIEN[art]
	if not _szenen.has(pfad):
		_szenen[pfad] = load(pfad) if ResourceLoader.exists(pfad) else null
	var s: PackedScene = _szenen[pfad]
	if s == null:
		return
	var m: Node3D = s.instantiate()
	m.set_meta("tier_teil", true)
	m.rotation.y = PI
	add_child(m)
	# auf die echte Höhe bringen
	var hoehe := 0.0
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (m.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		hoehe = maxf(hoehe, box.end.y)
		mi.visibility_range_end = 160.0
	if hoehe > 0.001:
		m.scale = Vector3.ONE * (HOEHEN[art] / hoehe)
	# einfärben
	var farbe: Color = fell if fell.a > 0.0 else FELLE.get(art, Color(0, 0, 0, 0))
	if farbe.a > 0.0:
		for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
			var basis := mi.mesh.surface_get_material(0) as StandardMaterial3D
			if basis == null:
				continue
			var schluessel := "%d|%s" % [basis.get_instance_id(), farbe.to_html()]
			if not _mats.has(schluessel):
				var neu: StandardMaterial3D = basis.duplicate()
				neu.albedo_color = Color(basis.albedo_color.r * farbe.r * 1.6, basis.albedo_color.g * farbe.g * 1.6,
					basis.albedo_color.b * farbe.b * 1.6) if art <= 1 else farbe
				_mats[schluessel] = neu
			mi.set_surface_override_material(0, _mats[schluessel])
	# Animationen: Stehen, Gehen, Laufen (Namen wie "Armature|Idle")
	var aps := m.find_children("*", "AnimationPlayer", true, false)
	if aps.is_empty():
		return
	_anim = aps[0]
	if art in OHNE_GEHEN and _leihe_gehen() != null:
		_anim.add_animation_library("geliehen", _geliehen)
	_namen.clear()
	for n in _anim.get_animation_list():
		var kurz := String(n).get_slice("|", 1) if "|" in n else String(n).get_slice("/", 1) if "/" in n else String(n)
		var a := _anim.get_animation(n)
		if kurz in ["Idle", "Walk", "Walking", "WalkSlow", "Run"]:
			a.loop_mode = Animation.LOOP_LINEAR
		if kurz == "Idle" and not _namen.has("stehen"):
			_namen["stehen"] = n
		elif kurz in ["Walk", "Walking"]:
			_namen["gehen"] = n
		elif kurz == "WalkSlow":
			_namen["langsam"] = n
		elif kurz == "Run":
			_namen["laufen"] = n
	_anim.playback_default_blend_time = 0.3
	if _namen.has("stehen"):
		_anim.play(_namen["stehen"])
		_anim.seek(fmod(absf(global_position.x * 1.7 + global_position.z), 2.0), true)


## Gehen und Laufen der Kuh, nur mit Drehungen (die Proportionen der anderen Tiere sind anders)
static func _leihe_gehen() -> AnimationLibrary:
	if _geliehen != null:
		return _geliehen
	var pfad := "res://modelle/tiere/Cow.fbx"
	if not ResourceLoader.exists(pfad):
		return null
	var kuh: Node = load(pfad).instantiate()
	var ap: AnimationPlayer = kuh.find_children("*", "AnimationPlayer", true, false)[0]
	_geliehen = AnimationLibrary.new()
	for n in ["Armature|Walk", "Armature|Run"]:
		if not ap.has_animation(n):
			continue
		var a: Animation = ap.get_animation(n).duplicate(true)
		for t in range(a.get_track_count() - 1, -1, -1):
			if a.track_get_type(t) != Animation.TYPE_ROTATION_3D:
				a.remove_track(t)
		a.loop_mode = Animation.LOOP_LINEAR
		_geliehen.add_animation(n.get_slice("|", 1), a)
	kuh.free()
	return _geliehen


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _anim == null:
		return
	_verhalten(delta)
	var p := global_position
	var tempo := 0.0
	if _letzte != Vector3.INF and delta > 0.0:
		tempo = Vector2(p.x - _letzte.x, p.z - _letzte.z).length() / delta
	_letzte = p
	if tempo > 15.0:
		tempo = 0.0
	_gang = lerpf(_gang, tempo, clampf(delta * 6.0, 0.0, 1.0))
	var ziel: String = _namen.get("stehen", "")
	var s := 1.0
	if _gang > GEHEN[art] * 1.8 and _namen.has("laufen"):
		ziel = _namen["laufen"]
		s = _gang / LAUFEN[art]
	elif _gang > 0.15:
		ziel = _namen.get("gehen", _namen.get("langsam", ziel))
		s = clampf(_gang / maxf(GEHEN[art], 0.3), 0.5, 1.8)
	if _gang <= 0.15 and _ruhe and _namen.has("stehen"):
		s = 0.6                     # grasend: ruhiger Atem
	if ziel != "" and _anim.current_animation != ziel:
		_anim.play(ziel)
	_anim.speed_scale = s


# ---------- Verhalten ----------

func _spieler() -> Node3D:
	return get_tree().get_first_node_in_group("spieler") as Node3D


func _verhalten(delta: float) -> void:
	var sp := _spieler()
	var weit := sp == null or sp.global_position.distance_to(global_position) > 70.0
	if weit or revier.size() < 3:
		return
	var zum_spieler := sp.global_position - global_position
	zum_spieler.y = 0.0
	var abstand := zum_spieler.length()
	# scheue Tiere laufen vor dem Spieler weg
	if art in SCHEU and abstand < 3.2 and _zustand != Zustand.FLIEHEN:
		var weg := -zum_spieler.normalized() * 5.0
		var z := _im_revier(global_position + weg)
		if _frei_bis(z):
			_zustand = Zustand.FLIEHEN
			_ziel = z
	# Hunde schließen sich dem Spieler manchmal an
	if art == 4 and _zustand == Zustand.STEHEN and abstand < 6.0 and _zufall.randf() < delta * 0.15:
		_zustand = Zustand.FOLGEN
		_folgen_bis = Time.get_ticks_msec() / 1000.0 + _zufall.randf_range(15.0, 35.0)
	match _zustand:
		Zustand.STEHEN:
			_warten -= delta
			_ruhe = art in [0, 1, 2, 3, 7]
			if _warten <= 0.0:
				_neues_ziel()
		Zustand.GEHEN, Zustand.FLIEHEN:
			var tempo: float = LAUFEN[art] if _zustand == Zustand.FLIEHEN else GEHEN[art]
			_gehe(delta, _ziel, tempo, 0.3)
		Zustand.FOLGEN:
			if Time.get_ticks_msec() / 1000.0 > _folgen_bis or abstand > 14.0:
				_zustand = Zustand.STEHEN
				_warten = _zufall.randf_range(3.0, 8.0)
			elif abstand > 2.4:
				_gehe(delta, _im_revier(sp.global_position - zum_spieler.normalized() * 1.8), GEHEN[art] * (2.0 if abstand > 5.0 else 1.0), 0.2)
			else:
				_schaue_zu(sp.global_position, delta)
	# Boden unter den Füßen
	_boden_takt -= delta
	if _boden_takt <= 0.0:
		_boden_takt = 0.3
		var von := global_position + Vector3.UP * 1.2
		var abfrage := PhysicsRayQueryParameters3D.create(von, von + Vector3.DOWN * 3.0, 1)
		for versuch in 3:
			var treffer := get_world_3d().direct_space_state.intersect_ray(abfrage)
			if not treffer:
				break
			if treffer.collider.has_meta("tier"):
				abfrage.exclude += [treffer.rid]
				continue
			global_position.y = treffer.position.y
			break


func _neues_ziel() -> void:
	for versuch in 8:
		var p := _zufallspunkt()
		if p.distance_to(global_position) < 1.5:
			continue
		if _frei_bis(p):
			_ziel = p
			_zustand = Zustand.GEHEN
			_ruhe = false
			return
	_warten = _zufall.randf_range(2.0, 5.0)


func _gehe(delta: float, ziel: Vector3, tempo: float, toleranz: float) -> void:
	var d := ziel - global_position
	d.y = 0.0
	if d.length() < toleranz:
		if _zustand != Zustand.FOLGEN:
			_zustand = Zustand.STEHEN
			_warten = _zufall.randf_range(4.0, 14.0)
		return
	var r := d.normalized()
	# Hindernis direkt voraus (anderes Tier, Mensch, Mauer): stehen bleiben und neu überlegen
	_pruef -= delta
	if _pruef <= 0.0:
		_pruef = 0.25
		if not _frei_bis(global_position + r * 1.2, true):
			_zustand = Zustand.STEHEN
			_warten = _zufall.randf_range(1.0, 3.0)
			return
	global_position += r * minf(tempo * delta, d.length())
	_schaue_zu(global_position + r, delta * 3.0)


func _schaue_zu(p: Vector3, delta: float) -> void:
	var d := p - global_position
	if Vector2(d.x, d.z).length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), clampf(delta * 4.0, 0.0, 1.0))


## Ist der Weg dorthin frei? Strahl in Kniehöhe gegen Mauern, Zäune und Häuser (und auf Wunsch Leute und Tiere).
func _frei_bis(p: Vector3, auch_leute := false) -> bool:
	var h := clampf(HOEHEN[art] * 0.4, 0.2, 0.7)
	var von := global_position + Vector3.UP * h
	var nach := Vector3(p.x, global_position.y + h, p.z)
	var abfrage := PhysicsRayQueryParameters3D.create(von, nach, 1 | 2 | 4 if auch_leute else 1)
	var eigen := get_node_or_null("Koerper")
	if eigen:
		abfrage.exclude = [eigen.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(abfrage).is_empty()


func _zufallspunkt() -> Vector3:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for q in revier:
		lo = lo.min(q)
		hi = hi.max(q)
	for versuch in 20:
		var q := Vector2(_zufall.randf_range(lo.x, hi.x), _zufall.randf_range(lo.y, hi.y))
		if Geometry2D.is_point_in_polygon(q, revier):
			return Vector3(q.x, global_position.y, q.y)
	return global_position


func _im_revier(p: Vector3) -> Vector3:
	var q := Vector2(p.x, p.z)
	if Geometry2D.is_point_in_polygon(q, revier):
		return p
	# auf den nächsten Randpunkt ziehen
	var bester := q
	var beste_d := INF
	for i in revier.size():
		var a := revier[i]
		var b := revier[(i + 1) % revier.size()]
		var r := Geometry2D.get_closest_point_to_segment(q, a, b)
		if r.distance_to(q) < beste_d:
			beste_d = r.distance_to(q)
			bester = r
	var mitte := Vector2.ZERO
	for v in revier:
		mitte += v
	mitte /= revier.size()
	bester = bester.lerp(mitte, 0.08)
	return Vector3(bester.x, p.y, bester.y)
