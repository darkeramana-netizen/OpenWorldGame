@tool
extends Node3D
## Setzt alle direkten Kinder auf die Geländehöhe (x und z bleiben, y wird angepasst).
## Praktisch für Häuser, Türme und Personen: im Editor verschieben, sie folgen dem Boden.
## Ein Kind mit dem Metadatum "hoehe_fest" behält seine Höhe.

@export var gelaende: Node3D
## Zusätzlicher Abstand nach oben, z. B. für Fundamente.
@export var versatz: float = 0.0
@export var im_editor_aktualisieren: bool = false:
	set(wert):
		_setze_alle()


func _ready() -> void:
	# Das Gelände baut sich in seinem eigenen _ready auf, das vorher läuft.
	_setze_alle()


func _setze_alle() -> void:
	if gelaende == null or not gelaende.has_method("hoehe_bei"):
		return
	for kind in get_children():
		if kind is Node3D and not kind.has_meta("hoehe_fest"):
			var p: Vector3 = kind.global_position
			kind.global_position = Vector3(p.x, gelaende.hoehe_bei(p.x, p.z) + versatz, p.z)
