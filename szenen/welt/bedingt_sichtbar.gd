extends Node3D
## Sichtbar, solange eine Bedingung gilt (Schreibweise wie in den Dialogen), z. B. das Feuer auf
## einem Signalturm ab Alarmstufe 2 ("alarm>=2"): Dann brennt der Ring der Feuer.

@export var bedingung: String = ""


func _ready() -> void:
	Spielstand.alarm_geaendert.connect(func(_s: int) -> void: _pruefe())
	Spielstand.flag_geaendert.connect(func(_f: String) -> void: _pruefe())
	_pruefe()


func _pruefe() -> void:
	visible = Spielstand.pruefe_bedingung(bedingung)
