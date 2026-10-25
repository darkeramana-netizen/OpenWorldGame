extends Node
## Spielzeit und Tagesablauf des Ordens.
## Lore: Alltag und Rituale, Abschnitt 1 (Der Tag) und 1.2 (Die Stille-Stunde).

signal minute_vergangen(minute: int)
signal abschnitt_gewechselt(abschnitt: StringName)
signal stille_gewechselt(aktiv: bool)

## Echte Sekunden für einen ganzen Spieltag. 2400 s = 40 Minuten.
@export var sekunden_pro_tag: float = 2400.0

const STARTJAHR := 1750

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

var jahr: int = STARTJAHR
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


## Spult die Zeit vor (Taste T, Arbeit an der Werkbank).
func vorspulen(stunden: float) -> void:
	minuten += stunden * 60.0
	_tageswechsel()
	minute_vergangen.emit(int(minuten))
	_aktualisiere()


## Springt Jahre weiter, etwa am Ende des Probejahrs. Danach ist es Vormittag.
func zeitsprung(jahre: int) -> void:
	jahr += jahre
	tag = 1
	minuten = 7.0 * 60.0
	minute_vergangen.emit(int(minuten))
	_aktualisiere()


## Fortlaufende Minuten seit Spielbeginn, um Dauern über Mitternacht hinweg zu messen.
func absolute_minuten() -> float:
	return ((jahr - STARTJAHR) * 400 + tag) * 1440.0 + minuten


func uhrzeit_text() -> String:
	var m := int(minuten)
	return "%02d:%02d" % [m / 60, m % 60]


func datum_text() -> String:
	return "Jahr %d, Tag %d" % [jahr, tag]


func abschnitt_name() -> String:
	return ANZEIGENAMEN.get(abschnitt, "")


static func abschnitt_bei(minute: float) -> StringName:
	var ergebnis: StringName = &"nacht"
	for eintrag: Array in ABSCHNITTE:
		if minute >= eintrag[0]:
			ergebnis = eintrag[1]
	return ergebnis


func zuruecksetzen() -> void:
	jahr = STARTJAHR
	tag = 1
	minuten = 6.0 * 60.0
	_aktualisiere(true)


func als_dict() -> Dictionary:
	return {"jahr": jahr, "tag": tag, "minuten": minuten}


func aus_dict(daten: Dictionary) -> void:
	jahr = int(daten.get("jahr", STARTJAHR))
	tag = int(daten.get("tag", 1))
	minuten = float(daten.get("minuten", 360.0))
	_aktualisiere(true)


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
