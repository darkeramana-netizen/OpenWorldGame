extends StaticBody3D
## Eine Stelle, an der gearbeitet wird, z. B. die Werkbank im Bauhof.
## Jeder Arbeitsgang kostet Spielzeit und erhöht einen Zähler bis zum Ziel.

@export var anzeige_name: String = "Werkbank"
@export var aktion_text: String = "Arbeiten"
@export var zaehler_name: String = "eckstein"
@export var ziel_anzahl: int = 3
## Nur nutzbar, wenn diese Bedingung gilt.
@export var bedingung: String = ""
@export var stunden_pro_gang: float = 1.0
@export var text_gang: String = "Du arbeitest"
@export var text_fertig: String = "Fertig."


func _ready() -> void:
	add_to_group("interagierbar")


func interagieren(_spieler: Node3D) -> void:
	if not Spielstand.pruefe_bedingung(bedingung):
		Spielstand.meldung.emit("Hier hast du nichts zu tun. Noch nicht.")
		return
	if Spielzeit.stille_aktiv or Spielzeit.abschnitt == &"nacht":
		Spielstand.meldung.emit("Jetzt wird nicht gearbeitet.")
		return
	if Spielstand.zaehler_wert(zaehler_name) >= ziel_anzahl:
		Spielstand.meldung.emit(text_fertig)
		return
	Spielstand.zaehler_aendern(zaehler_name, 1)
	Spielzeit.vorspulen(stunden_pro_gang)
	var stand := Spielstand.zaehler_wert(zaehler_name)
	if stand >= ziel_anzahl:
		Spielstand.meldung.emit(text_fertig)
	else:
		Spielstand.meldung.emit("%s (%d/%d)." % [text_gang, stand, ziel_anzahl])
