extends Node
## Führt Gespräche aus den JSON-Dateien in res://daten/dialoge/.
## Aufbau einer Datei: siehe README.md, Abschnitt "Dialoge schreiben".

signal gestartet(dialog_id: String)
## optionen: Array[String]. Ist es leer, geht es mit "Weiter" voran.
signal zeile_gezeigt(sprecher: String, text: String, optionen: Array)
signal beendet(dialog_id: String)

const ORDNER := "res://daten/dialoge/"

var aktiv: bool = false

var _id: String = ""
var _gespraechspartner: String = ""
var _daten: Dictionary = {}
var _knoten: Dictionary = {}
var _sichtbare_optionen: Array = []


func starte(dialog_id: String, gespraechspartner: String) -> void:
	var pfad := ORDNER + dialog_id + ".json"
	if not FileAccess.file_exists(pfad):
		push_error("Dialog nicht gefunden: " + pfad)
		return
	var daten: Variant = JSON.parse_string(FileAccess.get_file_as_string(pfad))
	if typeof(daten) != TYPE_DICTIONARY:
		push_error("Dialog ist kein gültiges JSON: " + pfad)
		return
	_id = dialog_id
	_gespraechspartner = gespraechspartner
	_daten = daten
	aktiv = true
	gestartet.emit(_id)

	var start := "start"
	for einstieg: Dictionary in _daten.get("einstieg", []):
		if Spielstand.pruefe_bedingung(einstieg.get("bedingung", "")):
			start = einstieg["knoten"]
			break
	_zeige(start)


## Wählt eine Antwort. Ohne Antworten geht es einfach weiter.
func waehle(index: int) -> void:
	if not aktiv:
		return
	if _sichtbare_optionen.is_empty():
		_gehe_weiter(_knoten)
		return
	if index < 0 or index >= _sichtbare_optionen.size():
		return
	var option: Dictionary = _sichtbare_optionen[index]
	_wende_wirkungen_an(option)
	_gehe_weiter(option)


func beende() -> void:
	if not aktiv:
		return
	aktiv = false
	beendet.emit(_id)


func _zeige(knoten_id: String) -> void:
	var knoten: Dictionary = _daten.get("knoten", {}).get(knoten_id, {})
	if knoten.is_empty():
		push_error("Knoten '%s' fehlt in Dialog '%s'" % [knoten_id, _id])
		beende()
		return
	_knoten = knoten
	_wende_wirkungen_an(knoten)

	_sichtbare_optionen.clear()
	var texte: Array[String] = []
	for option: Dictionary in knoten.get("optionen", []):
		if Spielstand.pruefe_bedingung(option.get("bedingung", "")):
			_sichtbare_optionen.append(option)
			texte.append(option["text"])
	zeile_gezeigt.emit(knoten.get("sprecher", _gespraechspartner), knoten.get("text", ""), texte)


func _gehe_weiter(eintrag: Dictionary) -> void:
	if eintrag.has("weiter"):
		_zeige(eintrag["weiter"])
	else:
		beende()


## Wirkungen eines Knotens oder einer Antwort: Flags, Akte, Zähler, Rang, Meldung.
func _wende_wirkungen_an(eintrag: Dictionary) -> void:
	for flag: String in eintrag.get("setze", []):
		Spielstand.setze_flag(flag)
	var zaehler: Dictionary = eintrag.get("zaehler", {})
	for name: String in zaehler:
		Spielstand.zaehler_aendern(name, int(zaehler[name]))
	if eintrag.has("rang"):
		Spielstand.setze_rang(int(eintrag["rang"]))
	if eintrag.has("akte"):
		Spielstand.akte_eintrag(eintrag["akte"])
	if eintrag.has("meldung"):
		Spielstand.meldung.emit(eintrag["meldung"])
