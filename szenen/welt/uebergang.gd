extends Area3D
## Übergang am Ende eines Weges in eine andere Region, z. B. vom Rand von Drachenstein auf die Nordstraße.
## Wer hineinläuft, reist in die Zielregion und kommt am Marker "ankunft" an.

@export var ziel: String = ""
@export var ankunft: String = ""
## Spielzeit für den ganzen Weg. Sie vergeht nur, wenn man am anderen Ende hereingekommen ist
## (zeit_nur_von = Name der Ankunft dort). Wer umkehrt, verliert keine Tage.
@export var stunden: float = 0.0
@export var zeit_nur_von: String = ""
@export_multiline var text: String = ""
## Wer die Bedingung nicht erfüllt, wird an "rueckweg" zurückgestellt.
@export var bedingung: String = "eid_waechter"
@export var text_gesperrt: String = "Ein Anwärter verlässt die Burgfeste nicht ohne Auftrag."
@export var rueckweg: Vector3 = Vector3.ZERO


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # nur der Spieler
	monitorable = false
	body_entered.connect(_bei_betreten)


func _bei_betreten(koerper: Node3D) -> void:
	if not koerper.is_in_group("spieler") or Speicher.wechselt_szene:
		return
	if not Spielstand.pruefe_bedingung(bedingung):
		Spielstand.meldung.emit(text_gesperrt)
		koerper.set_deferred("global_position", rueckweg)
		koerper.set_deferred("velocity", Vector3.ZERO)
		return
	var zeit := stunden if zeit_nur_von == "" or Speicher.letzte_ankunft == zeit_nur_von else 0.0
	Speicher.reise.call_deferred(ziel, ankunft, zeit, text if zeit > 0.0 else "")
