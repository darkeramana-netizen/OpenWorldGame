extends CharacterBody3D
## Ein Gegner: Gesetzlose an den Straßen (Säbel oder Muskete) oder eine Übungspuppe.
## Angriffe kündigen sich an: Wer ausholt oder anlegt, braucht einen Moment. Man kann zurückweichen
## oder mit dem Säbel blocken. Besiegte bleiben liegen, auch nach dem Laden (über flag_besiegt).

@export var anzeige_name: String = "Gesetzloser"
@export_enum("saebel", "muskete", "puppe") var waffe: String = "saebel"
@export var leben_max: float = 80.0
@export var tracht: Color = Color(0.32, 0.26, 0.2)
## Wird beim Sieg gesetzt. Ist es schon gesetzt, liegt der Gegner von Anfang an am Boden.
@export var flag_besiegt: String = ""
## Zähler, der beim Sieg um eins steigt, z. B. für einen Auftrag.
@export var zaehler: String = ""
## Ab dieser Entfernung bemerkt der Gegner den Spieler.
@export var sicht: float = 16.0

const TEMPO := 3.2
## [Schaden, Reichweite, Ausholzeit, Pause danach]
const HIEB := [16.0, 2.3, 0.8, 1.6]
const STOSS := [14.0, 2.6, 0.8, 1.8]
const SCHUSS_SCHADEN := 40.0
const ZIELZEIT := 1.6
const NACHLADEZEIT := 8.0
const SCHUSSWEITE := 28.0

var leben: float
var besiegt: bool = false
var wach: bool = false

var _heimat := Vector3.ZERO
var _ausholen: float = 0.0
var _werte: Array = HIEB
var _pause: float = 0.0
var _zielen: float = 0.0
var _geladen: bool = true
var _nachladen: float = 0.0
var _schwerkraft: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _koerper: Node3D = $Koerper
@onready var _waffe: Node3D = $Koerper/Waffe


func _ready() -> void:
	add_to_group("gegner")
	add_to_group("treffbar")
	collision_layer = 4
	collision_mask = 1
	_heimat = global_position
	leben = leben_max
	$Name.text = anzeige_name
	var material := StandardMaterial3D.new()
	material.albedo_color = tracht
	$Koerper/Mesh.material_override = material
	_waffe.visible = waffe != "puppe"
	if waffe == "muskete":
		_waffe.scale = Vector3(1.4, 1.4, 1.6)
	if flag_besiegt != "" and Spielstand.hat_flag(flag_besiegt):
		_liegen()


## Getroffen vom Spieler (kampf.gd).
func treffer(schaden: float, _quelle: Node3D, _art: String) -> void:
	if besiegt:
		return
	if waffe == "puppe":
		Spielstand.zaehler_aendern("uebungstreffer", 1)
		Spielstand.meldung.emit("Treffer an der Übungspuppe (%d)." % schaden)
		return
	leben -= schaden
	wach = true
	var tween := create_tween()
	tween.tween_property(_koerper, "scale", Vector3(1.15, 0.9, 1.15), 0.08)
	tween.tween_property(_koerper, "scale", Vector3.ONE, 0.12)
	if leben <= 0.0:
		_besiegen()


func _besiegen() -> void:
	if flag_besiegt != "":
		Spielstand.setze_flag(flag_besiegt)
	if zaehler != "":
		Spielstand.zaehler_aendern(zaehler, 1)
	Spielstand.meldung.emit("%s geht zu Boden und bleibt liegen." % anzeige_name)
	_liegen()


func _liegen() -> void:
	besiegt = true
	wach = false
	remove_from_group("treffbar")
	_koerper.rotation.x = -PI / 2.0
	_koerper.position.y = 0.3
	_waffe.visible = false
	$Kollision.set_deferred("disabled", true)
	$Name.visible = false
	set_physics_process(false)


## Nachdem der Spieler verwundet geborgen wurde: zurück an den Ausgangsort, frisch.
func zuruecksetzen() -> void:
	if besiegt:
		return
	leben = leben_max
	wach = false
	global_position = _heimat
	velocity = Vector3.ZERO
	_ausholen = 0.0
	_zielen = 0.0
	_geladen = true
	_nachladen = 0.0


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _schwerkraft * delta
	var spieler := get_tree().get_first_node_in_group("spieler") as Node3D
	if waffe == "puppe" or spieler == null or Spielstand.eingabe_gesperrt:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	var zu := spieler.global_position - global_position
	zu.y = 0.0
	var d := zu.length()
	if not wach and d < sicht:
		wach = true
		Spielstand.meldung.emit("%s hat dich gesehen!" % anzeige_name)
	elif wach and d > sicht * 2.5:
		wach = false

	_pause = maxf(_pause - delta, 0.0)
	if _nachladen > 0.0:
		_nachladen -= delta
		if _nachladen <= 0.0:
			_geladen = true
	var bewegung := Vector3.ZERO
	if wach:
		rotation.y = atan2(-zu.x, -zu.z)
		if _ausholen > 0.0:
			_ausholen -= delta
			if _ausholen <= 0.0:
				_waffe.rotation.x = 0.0
				if d <= _werte[1]:
					spieler.treffer(_werte[0], self, "hieb")
				_pause = _werte[3]
		elif _zielen > 0.0:
			_zielen -= delta
			if _zielen <= 0.0:
				_feuern(spieler, d)
		elif waffe == "muskete":
			if _geladen and d <= SCHUSSWEITE and d > 3.5:
				_zielen = ZIELZEIT
				Spielstand.meldung.emit("%s legt auf dich an!" % anzeige_name)
			elif d <= STOSS[1] - 0.3:
				if _pause <= 0.0:
					_hole_aus(STOSS)
			elif not _geladen:
				if d < 8.0:
					bewegung = -zu.normalized()   # Abstand halten, während er nachlädt
			elif d > SCHUSSWEITE:
				bewegung = zu.normalized()
		else:
			if d > HIEB[1] - 0.4:
				bewegung = zu.normalized()
			elif _pause <= 0.0:
				_hole_aus(HIEB)
	else:
		var heim := _heimat - global_position
		heim.y = 0.0
		if heim.length() > 1.5:
			bewegung = heim.normalized()
			rotation.y = atan2(-heim.x, -heim.z)
	velocity.x = bewegung.x * TEMPO
	velocity.z = bewegung.z * TEMPO
	move_and_slide()


func _hole_aus(werte: Array) -> void:
	_werte = werte
	_ausholen = werte[2]
	_waffe.rotation.x = -1.2   # sichtbar ausholen: jetzt zurückweichen oder blocken


func _feuern(spieler: Node3D, d: float) -> void:
	_geladen = false
	_nachladen = NACHLADEZEIT
	var schnell: bool = Vector2(spieler.velocity.x, spieler.velocity.z).length() > 5.0
	var chance := clampf(0.85 - d * 0.02 - (0.25 if schnell else 0.0), 0.15, 0.9)
	if randf() < chance:
		spieler.treffer(SCHUSS_SCHADEN, self, "schuss")
		Spielstand.meldung.emit("Ein Schuss! Die Kugel trifft dich.")
	else:
		Spielstand.meldung.emit("Ein Schuss! Die Kugel pfeift an dir vorbei.")
