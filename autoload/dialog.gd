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
## Eine Reise aus dem Gespräch (Feld "reise"), die beim Ende des Gesprächs beginnt.
var _ausstehende_reise: Dictionary = {}


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
	_ausstehende_reise = {}
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
	if not _ausstehende_reise.is_empty():
		var reise := _ausstehende_reise
		_ausstehende_reise = {}
		Speicher.reise.call_deferred(reise["ziel"], reise["ankunft"], float(reise.get("stunden", 0.0)),
				Spielstand.text_einsetzen(reise.get("text", "")))


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
	zeile_gezeigt.emit(
		knoten.get("sprecher", _gespraechspartner),
		Spielstand.text_einsetzen(_waehle_text(knoten.get("text", ""))),
		Array(texte).map(Spielstand.text_einsetzen))


## "text" darf eine Liste sein: aus den Einträgen, deren Bedingung gilt, wird einer gewählt, fest je
## Gesprächspartner und Tag. So sagen Leute desselben Schlags Verschiedenes, und morgen etwas anderes.
## Ein Eintrag ist ein Text oder {"text": ..., "bedingung": ...}.
func _waehle_text(text: Variant) -> String:
	if typeof(text) != TYPE_ARRAY:
		return str(text)
	var passend: Array[String] = []
	for eintrag: Variant in text:
		if typeof(eintrag) == TYPE_DICTIONARY:
			if Spielstand.pruefe_bedingung(eintrag.get("bedingung", "")):
				passend.append(eintrag["text"])
		else:
			passend.append(str(eintrag))
	if passend.is_empty():
		return ""
	return passend[absi(hash(_gespraechspartner + str(Spielzeit.gesamttag()))) % passend.size()]


func _gehe_weiter(eintrag: Dictionary) -> void:
	if eintrag.has("weiter"):
		_zeige(eintrag["weiter"])
	else:
		beende()


## Wirkungen eines Knotens oder einer Antwort. Alle Felder stehen im README.
func _wende_wirkungen_an(eintrag: Dictionary) -> void:
	for flag: String in eintrag.get("setze", []):
		Spielstand.setze_flag(flag)
	var zaehler: Dictionary = eintrag.get("zaehler", {})
	for name: String in zaehler:
		Spielstand.zaehler_aendern(name, int(zaehler[name]))
	if eintrag.has("rang"):
		Spielstand.setze_rang(int(eintrag["rang"]))
	if eintrag.has("akte"):
		Spielstand.akte_eintrag(Spielstand.text_einsetzen(eintrag["akte"]))
	if eintrag.has("verweis"):
		Spielstand.verweis(eintrag["verweis"])
	if eintrag.has("meldung"):
		Spielstand.meldung.emit(Spielstand.text_einsetzen(eintrag["meldung"]))
	if eintrag.has("ziel"):
		Spielstand.setze_ziel(Spielstand.text_einsetzen(eintrag["ziel"]))
	if eintrag.has("zeitsprung"):
		var sprung: Dictionary = eintrag["zeitsprung"]
		Spielzeit.zeitsprung(int(sprung.get("jahre", 1)))
		Spielstand.blende.emit(Spielstand.text_einsetzen(sprung.get("text", "")), "zwischen")
	if eintrag.has("blende"):
		Spielstand.blende.emit(Spielstand.text_einsetzen(eintrag["blende"]), "zwischen")
	if eintrag.has("akt_ende"):
		Spielstand.blende.emit(Spielstand.text_einsetzen(eintrag["akt_ende"]), "akt_ende")
	if eintrag.has("spielende"):
		Spielstand.blende.emit(Spielstand.text_einsetzen(eintrag["spielende"]), "spielende")
	var ansehen: Dictionary = eintrag.get("ansehen", {})
	for gruppe: String in ansehen:
		Spielstand.ansehen_aendern(gruppe, int(ansehen[gruppe]))
	if eintrag.has("geld"):
		Spielstand.geld_aendern(int(eintrag["geld"]))
	if eintrag.has("merke_tag"):
		# Merkt sich den heutigen Tag in einem Zähler, z. B. für Fristen (ereignisse.gd).
		var name: String = eintrag["merke_tag"]
		Spielstand.zaehler_aendern(name, Spielzeit.gesamttag() - Spielstand.zaehler_wert(name))
	if eintrag.has("alarm"):
		Spielstand.setze_alarmstufe(int(eintrag["alarm"]))
	if eintrag.has("anzeige"):
		Spielstand.anzeige(int(eintrag["anzeige"]["stufe"]), Spielstand.text_einsetzen(eintrag["anzeige"]["grund"]))
	if eintrag.has("urteil"):
		# Erst nach dem Gespräch, damit die Blende (bei Ausstoßung) nicht mitten im Text kommt.
		Spielstand.urteil_vollstrecken.call_deferred()
	if eintrag.has("reise"):
		# Abfahrt erst, wenn das Gespräch zu Ende ist (siehe beende).
		_ausstehende_reise = eintrag["reise"]
