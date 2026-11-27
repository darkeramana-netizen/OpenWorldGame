extends StaticBody3D
## Geheimtür im Untergrund (27.11.2026): eine Steinplatte in einer Wandöffnung, die aussieht wie die Wand daneben
## (gleicher triplanarer Stein). Wer sie findet und dagegen drückt, schiebt sie zur Seite in die Mauer; danach bleibt
## sie offen (Flag im Spielstand). Bis die Bedingung gilt (z. B. ein Hinweis gelesen), merkt man nichts an ihr.
##
## Lokal: x entlang der Wand, y nach oben, z zum Raum hin, aus dem man sie zuerst sieht. Ursprung unten in der Mitte
## der Öffnung, in der Wandfläche.

@export var breite := 1.6
@export var hoehe := 2.6
@export var dicke := 0.5
## Steinart wie in material/ (bruchstein, basalt, mauer, kai)
@export var stein := "bruchstein"
## Flag im Spielstand, das sie offen hält (und beim Öffnen gesetzt wird)
@export var flag := ""
## Erst wenn diese Bedingung gilt, lässt sie sich finden (leer: immer)
@export var bedingung := ""
@export var anzeige_name := "Auffällige Fuge"
@export var meldung_auf := "Der Stein gibt nach und gleitet knirschend zur Seite. Dahinter ist es dunkel."
## Eintrag in die Akte beim Öffnen (leer: keiner)
@export var akte := ""
## Wohin die Platte gleitet: 1 nach +x, -1 nach -x, 0 in den Boden
@export var richtung := 1

var aktion_text := "Dagegen drücken"
var _platte: MeshInstance3D
var _form: CollisionShape3D
var _auf := 0.0
var _ziel := 0.0


func _ready() -> void:
	_baue()
	if Engine.is_editor_hint():
		return
	var stand := get_node_or_null("/root/Spielstand")
	if stand != null:
		if flag != "" and stand.hat_flag(flag):
			_auf = 1.0
			_ziel = 1.0
		stand.flag_geaendert.connect(func(_f: String) -> void: _pruefe())
	_stelle()
	_pruefe()


func _baue() -> void:
	for k in get_children():
		k.free()
	var box := BoxMesh.new()
	box.size = Vector3(breite, hoehe, dicke)
	_platte = MeshInstance3D.new()
	_platte.name = "Platte"
	_platte.mesh = box
	var m := load("res://material/%s.tres" % stein) as Material
	_platte.material_override = m
	add_child(_platte)
	_form = CollisionShape3D.new()
	_form.name = "Form"
	var bs := BoxShape3D.new()
	bs.size = Vector3(breite, hoehe, dicke)
	_form.shape = bs
	add_child(_form)


func _pruefe() -> void:
	var stand := get_node_or_null("/root/Spielstand")
	var findbar: bool = stand == null or bedingung == "" or stand.pruefe_bedingung(bedingung)
	if findbar and _ziel < 0.5:
		add_to_group("interagierbar")
	else:
		remove_from_group("interagierbar")


func ist_offen() -> bool:
	return _auf > 0.98


func interagieren(_spieler: Node3D) -> void:
	if _ziel > 0.5:
		return
	_ziel = 1.0
	remove_from_group("interagierbar")
	var stand := get_node_or_null("/root/Spielstand")
	if stand != null:
		if flag != "":
			stand.setze_flag(flag)
		stand.meldung.emit(meldung_auf)
		if akte != "":
			stand.akte_eintrag(akte)
	var klang := get_node_or_null("/root/Klang")
	if klang != null:
		klang.spiele("stein_schleifen", global_position + Vector3.UP * hoehe * 0.5, 0.0, 30.0, 1.0, false)


func _process(delta: float) -> void:
	if is_equal_approx(_auf, _ziel):
		return
	_auf = move_toward(_auf, _ziel, delta / 2.6)
	_stelle()


func _stelle() -> void:
	if _platte == null:
		return
	var t := _auf * _auf * (3.0 - 2.0 * _auf)
	var weg := Vector3(breite * 0.96 * richtung, 0, 0) if richtung != 0 else Vector3(0, -hoehe * 0.98, 0)
	# erst ein Stück zurück in die Mauer, dann zur Seite
	var zurueck := Vector3(0, 0, -minf(t * 4.0, 1.0) * dicke * 0.3)
	var seit := clampf((t - 0.15) / 0.85, 0.0, 1.0)
	_platte.position = Vector3(0, hoehe / 2.0, -dicke / 2.0) + zurueck + weg * seit
	_form.position = _platte.position
	_form.disabled = _auf > 0.6
