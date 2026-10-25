extends StaticBody3D
## Ein Gegenstand, den man liest oder ansieht, z. B. das Namensbuch. Öffnet ein Gespräch
## aus daten/dialoge/, in dem der Gegenstand "spricht" (Erzähltext).

@export var anzeige_name: String = "Buch"
@export var aktion_text: String = "Lesen"
@export var dialog_id: String = ""


func _ready() -> void:
	add_to_group("interagierbar")


func interagieren(_spieler: Node3D) -> void:
	Dialog.starte(dialog_id, anzeige_name)
