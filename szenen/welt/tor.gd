extends StaticBody3D
## Ein Tor, das geschlossen bleibt, bis eine Bedingung gilt (z. B. ein Flag aus einem Gespräch).
## Offen: unsichtbar und ohne Kollision. Kinder (Mesh, CSG) bilden das Aussehen.

## Schreibweise wie in den Dialogen, z. B. "bergfried_zugang".
@export var bedingung: String = ""
@export var anzeige_name: String = "Tor"
## Was beim Ansprechen des geschlossenen Tors erscheint.
@export var text_geschlossen: String = "Das Tor ist verschlossen."

var aktion_text: String = "Untersuchen"


func _ready() -> void:
	Spielstand.flag_geaendert.connect(func(_f: String) -> void: _pruefe())
	_pruefe()


func interagieren(_spieler: Node3D) -> void:
	Spielstand.meldung.emit(text_geschlossen)


func ist_offen() -> bool:
	return Spielstand.pruefe_bedingung(bedingung)


func _pruefe() -> void:
	var offen := ist_offen()
	visible = not offen
	for kind in get_children():
		if kind is CollisionShape3D:
			kind.set_deferred("disabled", offen)
	if offen:
		remove_from_group("interagierbar")
	else:
		add_to_group("interagierbar")
