extends StaticBody3D
## Ein Gegenstand, den man aufheben kann. Er erhöht einen Zähler im Spielstand.

@export var anzeige_name: String = "Bruchstein"
@export var zaehler_name: String = "bruchsteine"
## Nur aufhebbar, wenn diese Bedingung gilt (gleiche Schreibweise wie in den Dialogen).
@export var bedingung: String = ""

var aktion_text: String = "Aufheben"


func _ready() -> void:
	# Schon in einem früheren Spielstand aufgehoben?
	if Spielstand.ist_aufgehoben(str(get_path())):
		queue_free()
		return
	add_to_group("interagierbar")


func interagieren(_spieler: Node3D) -> void:
	if Spielzeit.stille_aktiv:
		Spielstand.meldung.emit("Während der Stille-Stunde ruht die Arbeit.")
		return
	if not Spielstand.pruefe_bedingung(bedingung):
		Spielstand.meldung.emit("Das ist nicht deine Aufgabe. Noch nicht.")
		return
	Spielstand.zaehler_aendern(zaehler_name, 1)
	Spielstand.aufgehoben.append(str(get_path()))
	Spielstand.meldung.emit("%s aufgehoben (%d)." % [anzeige_name, Spielstand.zaehler_wert(zaehler_name)])
	remove_from_group("interagierbar")
	queue_free()
