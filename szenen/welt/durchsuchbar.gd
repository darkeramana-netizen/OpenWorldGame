extends StaticBody3D
## Etwas, das man heimlich durchsucht, z. B. ein Schreibpult (Spähwesen 3.11). Steht jemand in der Nähe
## und schaut herüber, geht es nicht. Dann wartet man, schleicht von hinten heran oder lenkt ab.
## Das Durchsuchen selbst ist ein Gespräch aus daten/dialoge/, in dem der Gegenstand "spricht".

@export var anzeige_name: String = "Schreibpult"
@export var aktion_text: String = "Durchsuchen"
@export var dialog_id: String = ""
## Nur solange diese Bedingung gilt, kann man es durchsuchen (sonst ist es nur ein Möbelstück).
@export var bedingung: String = ""
## Wer aufpasst. Sieht diese Person den Spieler, verbietet sich das Durchsuchen.
@export var waechter: NodePath
@export var sichtweite: float = 9.0

const NAH := 2.2


func _ready() -> void:
	Spielstand.flag_geaendert.connect(func(_f: String) -> void: _pruefe())
	_pruefe()


func _pruefe() -> void:
	if Spielstand.pruefe_bedingung(bedingung):
		add_to_group("interagierbar")
	else:
		remove_from_group("interagierbar")


func interagieren(spieler: Node3D) -> void:
	var person := get_node_or_null(waechter) as Node3D
	if person and person.visible and _sieht(person, spieler):
		Spielstand.meldung.emit("%s sieht herüber. Nicht jetzt." % person.anzeige_name)
		return
	Dialog.starte(dialog_id, anzeige_name)


func _sieht(person: Node3D, spieler: Node3D) -> bool:
	var zu := spieler.global_position - person.global_position
	zu.y = 0.0
	if zu.length() < NAH:
		return true
	return zu.length() < sichtweite and (-person.global_basis.z).dot(zu.normalized()) > 0.3
