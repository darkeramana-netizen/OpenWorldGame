extends CharacterBody3D
## Die Spielfigur: Laufen, Kamera, Ansprechen von Personen und Dingen.

signal ziel_gewechselt(ziel: Node)

@export var gehen: float = 4.0
@export var rennen: float = 7.0
@export var sprungkraft: float = 4.5
@export var maus_empfindlichkeit: float = 0.003

## Das Objekt, das mit E angesprochen wird (Person oder Gegenstand).
var ziel: Node = null

var _schwerkraft: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _kamera_drehpunkt: Node3D = $KameraDrehpunkt
@onready var _koerper: Node3D = $Koerper
@onready var _interaktionsbereich: Area3D = $Interaktionsbereich


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Dialog.gestartet.connect(func(_id: String) -> void: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE)
	Dialog.beendet.connect(func(_id: String) -> void: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_kamera_drehpunkt.rotation.y -= event.relative.x * maus_empfindlichkeit
		_kamera_drehpunkt.rotation.x = clampf(
			_kamera_drehpunkt.rotation.x - event.relative.y * maus_empfindlichkeit,
			deg_to_rad(-60.0), deg_to_rad(30.0))
	elif event.is_action_pressed("maus_freigeben"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and not Dialog.aktiv:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("interagieren") and ziel != null and not Dialog.aktiv:
		get_viewport().set_input_as_handled()
		ziel.interagieren(self)
	elif event.is_action_pressed("zeit_vorspulen") and not Dialog.aktiv:
		Spielzeit.vorspulen(1.0)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _schwerkraft * delta

	var eingabe := Vector2.ZERO
	if not Dialog.aktiv:
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
	_aktualisiere_ziel()


## Sucht das nächste ansprechbare Objekt im Interaktionsbereich.
func _aktualisiere_ziel() -> void:
	var naechstes: Node3D = null
	var beste_distanz := INF
	for koerper in _interaktionsbereich.get_overlapping_bodies():
		if not koerper.is_in_group("interagierbar"):
			continue
		var distanz := global_position.distance_squared_to(koerper.global_position)
		if distanz < beste_distanz:
			beste_distanz = distanz
			naechstes = koerper
	if naechstes != ziel:
		ziel = naechstes
		ziel_gewechselt.emit(ziel)
