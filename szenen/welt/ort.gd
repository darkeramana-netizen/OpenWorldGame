extends Area3D
## Ein benannter Ort. Betritt der Spieler den Bereich, erscheint der Name groß im Bild.

@export var ortsname: String = "Drachenstein"
@export var untertitel: String = ""


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # nur der Spieler
	monitorable = false
	body_entered.connect(func(koerper: Node3D) -> void:
		if koerper.is_in_group("spieler") and not Speicher.wechselt_szene:
			Spielstand.ort_betreten.emit(ortsname, untertitel))
