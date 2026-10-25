extends Area3D
## Ein Wachposten: Der Spieler muss im Bereich bleiben, bis die Ablösung kommt.
## Wer vorher geht, bekommt einen Verweis (Eid des Gesellen: „Nicht früher, nicht später.“).

## Der Posten zählt nur, wenn diese Bedingung gilt (z. B. "aufgabe_torwache,!torwache_erledigt").
@export var bedingung: String = ""
## Dieses Flag wird gesetzt, wenn die Wache gehalten wurde.
@export var erledigt_flag: String = ""
## Wachdauer in Spielminuten. 0 = bis zum Tagesabschnitt "bis_abschnitt".
@export var dauer_minuten: float = 120.0
@export var bis_abschnitt: StringName = &""
@export_multiline var text_beginn: String = "Du stehst auf dem Posten. Bleib, bis die Ablösung kommt."
@export_multiline var text_mitte: String = ""
@export_multiline var text_ende: String = "Die Ablösung kommt."
@export var akte_ende: String = ""
@export var verweis_text: String = "Posten vor der Ablösung verlassen."

var _aktiv := false
var _beginn := 0.0
var _mitte_gezeigt := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # nur der Spieler
	monitorable = false
	body_entered.connect(_bei_betreten)
	body_exited.connect(_bei_verlassen)
	Spielzeit.minute_vergangen.connect(func(_m: int) -> void: _pruefe())


func _bei_betreten(koerper: Node3D) -> void:
	if not koerper.is_in_group("spieler") or _aktiv:
		return
	if not Spielstand.pruefe_bedingung(bedingung) or Spielstand.hat_flag(erledigt_flag):
		return
	_aktiv = true
	_mitte_gezeigt = false
	_beginn = Spielzeit.absolute_minuten()
	Spielstand.meldung.emit(text_beginn)


func _bei_verlassen(koerper: Node3D) -> void:
	if not koerper.is_in_group("spieler") or not _aktiv:
		return
	_aktiv = false
	if Speicher.wechselt_szene:
		return  # Laden oder Hauptmenü: Das ist kein Verlassen des Postens.
	Spielstand.verweis(verweis_text)
	Spielstand.meldung.emit("Du hast den Posten zu früh verlassen. Ein Verweis wird eingetragen.")


func _pruefe() -> void:
	if not _aktiv:
		return
	var vergangen := Spielzeit.absolute_minuten() - _beginn
	var fertig := false
	if bis_abschnitt != &"":
		fertig = Spielzeit.abschnitt == bis_abschnitt and vergangen > 30.0
	else:
		fertig = vergangen >= dauer_minuten
	if fertig:
		_aktiv = false
		Spielstand.setze_flag(erledigt_flag)
		if akte_ende != "":
			Spielstand.akte_eintrag(akte_ende)
		Spielstand.meldung.emit(text_ende)
	elif text_mitte != "" and not _mitte_gezeigt and vergangen >= 180.0:
		_mitte_gezeigt = true
		Spielstand.meldung.emit(text_mitte)
