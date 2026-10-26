extends Node
## Speichern und Laden. Spielstände liegen als JSON in user://speicher/
## (unter Windows: %APPDATA%/Godot/app_userdata/Sorrowland_ In Silentio/speicher).

const STANDARD_ORDNER := "user://speicher/"
## Die Regionen der Welt. Neue Spiele beginnen in der ersten.
const REGIONEN := {
	"drachenstein": "res://szenen/welt/region_drachenstein.tscn",
	"riverlock": "res://szenen/welt/region_riverlock.tscn",
	"ashenveil": "res://szenen/welt/region_ashenveil.tscn",
	"nordstrasse": "res://szenen/welt/region_nordstrasse.tscn",
	"suedstrasse": "res://szenen/welt/region_suedstrasse.tscn",
	"kuestenweg": "res://szenen/welt/region_kuestenweg.tscn",
}
const START_REGION := "drachenstein"
const HAUPTMENUE := "res://szenen/oberflaeche/hauptmenue.tscn"
## Manuelle Plätze im Pausemenü. "auto" und "schnell" kommen dazu.
const PLAETZE: Array[String] = ["1", "2", "3"]
## 1: Hof als eigene Szene (Akt I). 2: Hof liegt in der Region Drachenstein.
const VERSION := 2

## Position und Blickrichtung des Spielers aus dem geladenen Spielstand.
## Die Spielfigur holt sie sich beim Start ab.
var ausstehender_spieler: Dictionary = {}
## Ordner der Spielstände. Tests setzen einen eigenen, damit echte Spielstände unberührt bleiben.
var ordner: String = STANDARD_ORDNER:
	set(wert):
		ordner = wert
		DirAccess.make_dir_recursive_absolute(ordner)
## Die Region, in der der Spieler gerade ist. Setzt die Region selbst beim Betreten (region.gd).
var region: String = START_REGION
## Name des Ankunftsorts der letzten Reise (z. B. "von_drachenstein"). Übergänge an Wegen
## lassen nur dann Tage vergehen, wenn man am anderen Ende hereingekommen ist.
var letzte_ankunft: String = ""
## Wahr, solange die alte Szene abgebaut wird. Posten werten das Verlassen dann nicht als Fehler.
var wechselt_szene: bool = false

var _autospeichern_vorgemerkt := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(ordner)
	# Nach Rangwechsel und Zeitsprung automatisch speichern,
	# sobald Gespräch und Blende vorbei sind (siehe _process).
	Spielstand.rang_geaendert.connect(func(_r: int) -> void: _autospeichern_vorgemerkt = true)
	Spielstand.blende.connect(func(_t: String, art: String) -> void: _autospeichern_vorgemerkt = art != "spielende")


func _process(_delta: float) -> void:
	if _autospeichern_vorgemerkt and kann_speichern() and not get_tree().paused:
		_autospeichern_vorgemerkt = false
		speichern("auto")


func _unhandled_input(event: InputEvent) -> void:
	if not _im_spiel() or Dialog.aktiv or Spielstand.eingabe_gesperrt or get_tree().paused:
		return
	if event.is_action_pressed("schnellspeichern"):
		if speichern("schnell"):
			Spielstand.meldung.emit("Schnell gespeichert.")
	elif event.is_action_pressed("schnellladen"):
		if existiert("schnell"):
			laden("schnell")
		else:
			Spielstand.meldung.emit("Noch kein Schnellspeicherstand vorhanden.")


func neues_spiel(name: String) -> void:
	_autospeichern_vorgemerkt = false
	Spielstand.zuruecksetzen(name if name.strip_edges() != "" else "Vertriebener")
	Spielzeit.zuruecksetzen()
	ausstehender_spieler = {}
	region = START_REGION
	letzte_ankunft = ""
	_wechsle_zu(REGIONEN[region])


## Reist in eine andere Region, z. B. per Schiff mit der Lotsin. Die Zeit läuft weiter,
## nach der Ankunft erscheint eine Blende (und danach wird automatisch gespeichert).
func reise(ziel: String, ankunft: String, stunden: float = 0.0, text: String = "") -> void:
	if not REGIONEN.has(ziel):
		push_error("Unbekannte Region: " + ziel)
		return
	Dialog.beende()
	Spielzeit.vorspulen(stunden)
	ausstehender_spieler = {"ankunft": ankunft}
	letzte_ankunft = ankunft
	region = ziel
	await _wechsle_zu(REGIONEN[ziel])
	if text != "":
		Spielstand.blende.emit(text, "zwischen")


func kann_speichern() -> bool:
	return _im_spiel() and not Dialog.aktiv and not Spielstand.eingabe_gesperrt


func speichern(platz: String) -> bool:
	if not kann_speichern():
		return false
	var daten := {
		"version": VERSION,
		"gespeichert": Time.get_datetime_string_from_system(false, true),
		"spielstand": Spielstand.als_dict(),
		"spielzeit": Spielzeit.als_dict(),
		"spieler": _spieler_daten(),
		"region": region,
		"letzte_ankunft": letzte_ankunft,
	}
	var datei := FileAccess.open(_pfad(platz), FileAccess.WRITE)
	if datei == null:
		push_error("Speichern fehlgeschlagen: %s" % error_string(FileAccess.get_open_error()))
		return false
	datei.store_string(JSON.stringify(daten, "\t"))
	return true


func laden(platz: String) -> bool:
	var daten := _lies(platz)
	if daten.is_empty():
		return false
	_autospeichern_vorgemerkt = false
	Dialog.beende()
	_ziehe_um(daten)
	Spielstand.aus_dict(daten.get("spielstand", {}))
	Spielzeit.aus_dict(daten.get("spielzeit", {}))
	ausstehender_spieler = daten.get("spieler", {})
	region = daten.get("region", START_REGION)
	letzte_ankunft = daten.get("letzte_ankunft", "")
	if not REGIONEN.has(region):
		region = START_REGION
	_wechsle_zu(REGIONEN[region])
	return true


func existiert(platz: String) -> bool:
	return FileAccess.file_exists(_pfad(platz))


## Kurzbeschreibung für die Menüs, z. B. "Anwärter Ansel · Jahr 1750, Tag 2 · 12.03.2027 14:05".
func beschreibung(platz: String) -> String:
	var daten := _lies(platz)
	if daten.is_empty():
		return "leer"
	var stand: Dictionary = daten.get("spielstand", {})
	var zeit: Dictionary = daten.get("spielzeit", {})
	var rang: int = clampi(int(stand.get("rang", 0)), 0, Spielstand.RAENGE.size() - 1)
	return "%s %s · Jahr %d, Tag %d · %s" % [
		Spielstand.RAENGE[rang], stand.get("spieler_name", "?"),
		int(zeit.get("jahr", Spielzeit.STARTJAHR)), int(zeit.get("tag", 1)),
		String(daten.get("gespeichert", "")).replace("T", " ").left(16)]


## Der zuletzt geschriebene Spielstand, für "Fortsetzen" im Hauptmenü. Leer, wenn es keinen gibt.
func neuester_platz() -> String:
	var bester := ""
	var beste_zeit := 0
	for platz in ["auto", "schnell"] + PLAETZE:
		if existiert(platz):
			var zeit := FileAccess.get_modified_time(_pfad(platz))
			if zeit > beste_zeit:
				beste_zeit = zeit
				bester = platz
	return bester


func zum_hauptmenue() -> void:
	Dialog.beende()
	Spielstand.eingabe_gesperrt = false
	_wechsle_zu(HAUPTMENUE)


func _wechsle_zu(szene: String) -> void:
	wechselt_szene = true
	get_tree().paused = false
	get_tree().change_scene_to_file(szene)
	await get_tree().scene_changed
	wechselt_szene = false


## Bringt ältere Spielstände auf den aktuellen Aufbau der Welt.
func _ziehe_um(daten: Dictionary) -> void:
	if int(daten.get("version", 1)) < 2:
		# Der Hof war die Hauptszene, jetzt liegt er als "BurgHof" in der Region.
		# Seine Koordinaten sind gleich geblieben, nur die Knotenpfade ändern sich.
		var stand: Dictionary = daten.get("spielstand", {})
		var pfade: Array = stand.get("aufgehoben", [])
		for i in pfade.size():
			pfade[i] = String(pfade[i]).replace("/root/Hof/", "/root/Region/BurgHof/")


func _spieler_daten() -> Dictionary:
	var spieler := get_tree().get_first_node_in_group("spieler")
	if spieler == null:
		return {}
	return spieler.als_dict()


func _im_spiel() -> bool:
	return get_tree().get_first_node_in_group("spieler") != null


func _lies(platz: String) -> Dictionary:
	if not existiert(platz):
		return {}
	var daten: Variant = JSON.parse_string(FileAccess.get_file_as_string(_pfad(platz)))
	return daten if daten is Dictionary else {}


func _pfad(platz: String) -> String:
	return ordner + "platz_%s.json" % platz
