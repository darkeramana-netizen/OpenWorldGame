@tool
class_name Tier
extends Node3D
## Ein Tier aus den freien Modellen von Quaternius (CC0; modelle/tiere): Pferd, Kuh, Schaf, Schwein, Hund, Katze,
## Wolf, Lama. Das Modell wird auf die echte Höhe gebracht und eingefärbt; das Tier misst selbst, wie schnell es sich
## bewegt, und steht, geht oder läuft. Füße bei y = 0, Blick nach -z (wie die Figuren).

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

const DATEIEN := ["Horse", "Cow", "Sheep", "Pig", "Dog", "Cat", "Wolf", "Llama"]
## Höhe bis zum höchsten Punkt (Kopf) in Metern
const HOEHEN := [2.1, 1.6, 1.05, 0.95, 0.75, 0.36, 0.95, 1.9]
## Fellfarbe, wenn keine angegeben ist
const FELLE := {4: Color(0.55, 0.4, 0.27), 5: Color(0.78, 0.52, 0.3), 6: Color(0.5, 0.5, 0.52)}

static var _szenen := {}
static var _mats := {}
var _anim: AnimationPlayer
var _namen := {}
var _letzte := Vector3.INF
var _gang := 0.0


func _ready() -> void:
	_baue()


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
	_namen.clear()
	for n in _anim.get_animation_list():
		var kurz := String(n).get_slice("|", 1) if "|" in n else String(n)
		var a := _anim.get_animation(n)
		if kurz in ["Idle", "Idle_2", "Eating", "Walk", "Walking", "WalkSlow", "Run", "Gallop"]:
			a.loop_mode = Animation.LOOP_LINEAR
		if kurz.begins_with("Idle") and not _namen.has("stehen"):
			_namen["stehen"] = n
		elif kurz in ["Walk", "Walking"]:
			_namen["gehen"] = n
		elif kurz == "WalkSlow":
			_namen["langsam"] = n
		elif kurz in ["Run", "Gallop"]:
			_namen["laufen"] = n
	_anim.playback_default_blend_time = 0.3
	if _namen.has("stehen"):
		_anim.play(_namen["stehen"])
		_anim.seek(fmod(absf(global_position.x * 1.7 + global_position.z), 2.0), true)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _anim == null:
		return
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
	var groesse: float = HOEHEN[art]
	if _gang > groesse * 2.2 and _namen.has("laufen"):
		ziel = _namen["laufen"]
		s = _gang / (groesse * 3.0)
	elif _gang > 0.2:
		ziel = _namen.get("gehen", _namen.get("langsam", ziel))
		s = clampf(_gang / maxf(groesse * 0.9, 0.3), 0.4, 1.8)
	if ziel != "" and _anim.current_animation != ziel:
		_anim.play(ziel)
	_anim.speed_scale = s
