extends CharacterBody3D
## Die Spielfigur: Laufen, Kamera, Ansprechen von Personen und Dingen.

signal ziel_gewechselt(ziel: Node)

@export var gehen: float = 4.0
@export var rennen: float = 7.0
@export var sprungkraft: float = 4.5
@export var maus_empfindlichkeit: float = 0.003
## Wie nah man an Personen und Dinge herangehen muss, um sie mit E anzusprechen (Meter).
@export var reichweite: float = 3.0

const KORDELFARBEN := {
	"schwarz": Color(0.05, 0.05, 0.05),
	"grau": Color(0.55, 0.55, 0.58),
	"golden": Color(0.85, 0.65, 0.2),
	"doppelt golden": Color(1.0, 0.8, 0.3),
}

## Wasser und Rand der Region: Wer hineingerät, wird zur letzten sicheren Stelle zurückgesetzt.
const MEERESSPIEGEL := -20.0
const GRENZE_MIN := Vector2(-880.0, -630.0)
const GRENZE_MAX := Vector2(430.0, 330.0)

## Das Objekt, das mit E angesprochen wird (Person oder Gegenstand).
var ziel: Node = null
var _sichere_position := Vector3.ZERO

var _schwerkraft: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _kamera_drehpunkt: Node3D = $KameraDrehpunkt
@onready var _koerper: Node3D = $Koerper
@onready var _kordel: MeshInstance3D = $Koerper/Kordel


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Dialog.gestartet.connect(_bei_dialogstart)
	Dialog.beendet.connect(_bei_dialogende)
	Spielstand.rang_geaendert.connect(func(_r: int) -> void: _zeige_kordel())
	_zeige_kordel()
	# Nach dem Laden eines Spielstands an die gespeicherte Stelle setzen.
	if not Speicher.ausstehender_spieler.is_empty():
		aus_dict(Speicher.ausstehender_spieler)
		Speicher.ausstehender_spieler = {}
	# Nie unter der Geländeoberfläche beginnen, sonst kann die Figur durchfallen.
	var gelaende := get_tree().get_first_node_in_group("gelaende")
	if gelaende != null:
		var boden: float = gelaende.hoehe_bei(global_position.x, global_position.z)
		if global_position.y < boden + 0.05:
			global_position.y = boden + 0.05
	_sichere_position = global_position


func _unhandled_input(event: InputEvent) -> void:
	if Dialog.aktiv or Spielstand.eingabe_gesperrt:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_kamera_drehpunkt.rotation.y -= event.relative.x * maus_empfindlichkeit
		_kamera_drehpunkt.rotation.x = clampf(
			_kamera_drehpunkt.rotation.x - event.relative.y * maus_empfindlichkeit,
			deg_to_rad(-60.0), deg_to_rad(30.0))
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("interagieren") and ziel != null:
		get_viewport().set_input_as_handled()
		ziel.interagieren(self)
	elif event.is_action_pressed("zeit_vorspulen"):
		Spielzeit.vorspulen(1.0)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _schwerkraft * delta

	var eingabe := Vector2.ZERO
	if not Dialog.aktiv and not Spielstand.eingabe_gesperrt:
		eingabe = Input.get_vector("links", "rechts", "vor", "zurueck")
		if Input.is_action_just_pressed("springen") and is_on_floor():
			velocity.y = sprungkraft

	# Bewegung relativ zur Blickrichtung der Kamera.
	var richtung := (Basis(Vector3.UP, _kamera_drehpunkt.rotation.y) * Vector3(eingabe.x, 0.0, eingabe.y)).normalized()
	var tempo := rennen if Input.is_action_pressed("rennen") else gehen
	if richtung != Vector3.ZERO:
		velocity.x = richtung.x * tempo
		velocity.z = richtung.z * tempo
		_koerper.rotation.y = lerp_angle(_koerper.rotation.y, atan2(-richtung.x, -richtung.z), 10.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, tempo * 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, tempo * 10.0 * delta)

	move_and_slide()
	_pruefe_grenzen()
	_aktualisiere_ziel()


func _in_wasserdichtem_bau(p: Vector3) -> bool:
	for bau in get_tree().get_nodes_in_group("wasserdicht"):
		if bau.enthaelt(p):
			return true
	return false


func _pruefe_grenzen() -> void:
	var p := global_position
	var draussen := p.x < GRENZE_MIN.x or p.z < GRENZE_MIN.y or p.x > GRENZE_MAX.x or p.z > GRENZE_MAX.y
	var unter_wasser := p.y < MEERESSPIEGEL - 1.0 and not _in_wasserdichtem_bau(p)
	if unter_wasser or draussen:
		global_position = _sichere_position
		velocity = Vector3.ZERO
		if draussen:
			Spielstand.meldung.emit("Hier endet die Region. Dahinter liegt nur Fels.")
		else:
			Spielstand.meldung.emit("Das Wächtermeer ist zu kalt zum Schwimmen.")
	elif is_on_floor() and p.y > MEERESSPIEGEL + 0.3:
		_sichere_position = p


func als_dict() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"koerper": _koerper.rotation.y,
		"kamera": [_kamera_drehpunkt.rotation.x, _kamera_drehpunkt.rotation.y],
	}


func aus_dict(daten: Dictionary) -> void:
	var p: Array = daten.get("position", [])
	if p.size() == 3:
		global_position = Vector3(p[0], p[1], p[2])
	_koerper.rotation.y = daten.get("koerper", 0.0)
	var k: Array = daten.get("kamera", [])
	if k.size() == 2:
		_kamera_drehpunkt.rotation = Vector3(k[0], k[1], 0.0)


func _bei_dialogstart(_id: String) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _bei_dialogende(_id: String) -> void:
	if not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _zeige_kordel() -> void:
	var farbe: Variant = KORDELFARBEN.get(Spielstand.kordel_name())
	_kordel.visible = farbe != null
	if farbe != null:
		var material := StandardMaterial3D.new()
		material.albedo_color = farbe
		_kordel.material_override = material


## Sucht das nächste ansprechbare Objekt in Reichweite.
## Bewusst über den Abstand statt über einen Area3D-Bereich: Die Physik-Engine Jolt
## (Standard seit Godot 4.6) meldet StaticBody3D in Bereichen nicht.
func _aktualisiere_ziel() -> void:
	var naechstes: Node3D = null
	var beste_distanz := reichweite * reichweite
	for kandidat: Node3D in get_tree().get_nodes_in_group("interagierbar"):
		var distanz := global_position.distance_squared_to(kandidat.global_position)
		if distanz < beste_distanz:
			beste_distanz = distanz
			naechstes = kandidat
	if naechstes != ziel:
		ziel = naechstes
		ziel_gewechselt.emit(ziel)
