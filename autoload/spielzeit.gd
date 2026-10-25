extends Node
## Spielzeit und Tagesablauf des Ordens.
## Lore: Alltag und Rituale, Abschnitt 1 (Der Tag) und 1.2 (Die Stille-Stunde).

signal minute_vergangen(minute: int)
signal abschnitt_gewechselt(abschnitt: StringName)
signal stille_gewechselt(aktiv: bool)

## Echte Sekunden für einen ganzen Spieltag. 2400 s = 40 Minuten.
@export var sekunden_pro_tag: float = 2400.0

## Beginn jedes Tagesabschnitts in Minuten nach Mitternacht.
const ABSCHNITTE: Array = [
	[0, &"nacht"],
	[5 * 60, &"morgengrauen"],
	[7 * 60, &"vormittag"],
	[12 * 60, &"mittag"],
	[13 * 60, &"nachmittag"],
	[19 * 60, &"stille_stunde"],
	[20 * 60, &"nacht"],
]

const ANZEIGENAMEN: Dictionary = {
	&"nacht": "Nacht – Nachtwache",
	&"morgengrauen": "Morgengrauen – Wachwechsel",
	&"vormittag": "Vormittag – Arbeit",
	&"mittag": "Mittag – gemeinsames Mahl",
	&"nachmittag": "Nachmittag – Arbeit und Übung",
	&"stille_stunde": "Dämmerung – Stille-Stunde",
}

var tag: int = 1
var minuten: float = 6.0 * 60.0
var abschnitt: StringName = &""
var stille_aktiv: bool = false


func _ready() -> void:
	_aktualisiere(true)


func _process(delta: float) -> void:
	var vorher := int(minuten)
	minuten += delta * 1440.0 / sekunden_pro_tag
	_tageswechsel()
	if int(minuten) != vorher:
		minute_vergangen.emit(int(minuten))
		_aktualisiere()


## Spult die Zeit vor. Nur zum Testen (Taste T).
func vorspulen(stunden: float) -> void:
	minuten += stunden * 60.0
	_tageswechsel()
	_aktualisiere()


func uhrzeit_text() -> String:
	var m := int(minuten)
	return "%02d:%02d" % [m / 60, m % 60]


func abschnitt_name() -> String:
	return ANZEIGENAMEN.get(abschnitt, "")


static func abschnitt_bei(minute: float) -> StringName:
	var ergebnis: StringName = &"nacht"
	for eintrag: Array in ABSCHNITTE:
		if minute >= eintrag[0]:
			ergebnis = eintrag[1]
	return ergebnis


func _tageswechsel() -> void:
	while minuten >= 1440.0:
		minuten -= 1440.0
		tag += 1


func _aktualisiere(erzwingen: bool = false) -> void:
	var neu := abschnitt_bei(minuten)
	if neu != abschnitt or erzwingen:
		abschnitt = neu
		abschnitt_gewechselt.emit(abschnitt)
	var stille := abschnitt == &"stille_stunde"
	if stille != stille_aktiv or erzwingen:
		stille_aktiv = stille
		stille_gewechselt.emit(stille_aktiv)
