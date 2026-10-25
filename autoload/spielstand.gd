extends Node
## Alles, was der Orden über den Spieler weiß: Name, Rang, Akte, Flags, Zähler und Ziel.
## Lore: Ränge und Eide (Abschnitt 2), Ordensregel (Abschnitt 2 und 3).

signal akte_geaendert
signal rang_geaendert(rang: int)
signal flag_geaendert(name: String)
signal ziel_geaendert(text: String)
## Kurze Einblendung im HUD.
signal meldung(text: String)
## Schwarze Blende mit Text, z. B. bei Zeitsprüngen.
## art: "zwischen" (blendet wieder auf), "akt_ende" (dauert länger), "spielende" (zurück ins Hauptmenü).
signal blende(text: String, art: String)
## Der Spieler hat einen benannten Ort betreten.
signal ort_betreten(name: String, untertitel: String)

## Index = Stufe der Waffenlinie. Stufe 0 ist der Bewerber vor dem Gelöbnis.
const RAENGE: Array[String] = [
	"Bewerber", "Anwärter", "Knappe", "Geselle", "Wächter",
	"Unterhüter", "Hüter", "Obersthüter", "Kammerhüter",
	"Bannerträger", "Wachführer", "Hauptwächter", "Bannerführer",
	"Marschall", "Komtur", "Landkomtur", "Ratsmeister",
	"Großkomtur", "Großmeister",
]

var spieler_name: String = "Vertriebener"
var rang: int = 0
var buerge: String = "Hauptwächter Bertil Rask"
var ziel: String = ""
var flags: Dictionary = {}
var zaehler: Dictionary = {}
## Einträge: { "text": String, "art": String, "datum": String, "uhrzeit": String }
var akte: Array[Dictionary] = []
var stille_brueche: int = 0
## Pfade aufgehobener Gegenstände, damit sie nach dem Laden fehlen.
var aufgehoben: Array[String] = []
## Während einer Blende darf der Spieler nichts tun.
var eingabe_gesperrt: bool = false


func rang_name() -> String:
	return RAENGE[rang]


## Farbe der Kordel am Kragen (Alltag 1.3).
func kordel_name() -> String:
	if rang <= 1:
		return "keine"
	if rang <= 4:
		return "schwarz"
	if rang <= 8:
		return "grau"
	if rang <= 14:
		return "golden"
	return "doppelt golden"


func setze_rang(neuer_rang: int) -> void:
	rang = clampi(neuer_rang, 0, RAENGE.size() - 1)
	rang_geaendert.emit(rang)


func setze_flag(name: String, wert: bool = true) -> void:
	flags[name] = wert
	flag_geaendert.emit(name)


func hat_flag(name: String) -> bool:
	return flags.get(name, false)


func zaehler_wert(name: String) -> int:
	return zaehler.get(name, 0)


func zaehler_aendern(name: String, wert: int) -> void:
	zaehler[name] = zaehler_wert(name) + wert


func setze_ziel(text: String) -> void:
	ziel = text
	ziel_geaendert.emit(ziel)
	if text != "":
		meldung.emit("Neues Ziel: " + text)


func akte_eintrag(text: String, art: String = "eintrag") -> void:
	akte.append({
		"text": text,
		"art": art,
		"datum": Spielzeit.datum_text(),
		"uhrzeit": Spielzeit.uhrzeit_text(),
	})
	akte_geaendert.emit()


## Ein Verweis (Strafstufe 1) zählt mit, die Versammlung sieht ihn bei jeder Beförderung.
func verweis(text: String) -> void:
	zaehler_aendern("verweise", 1)
	akte_eintrag("Verweis (Stufe 1): " + text, "verweis")


## Setzt Platzhalter in Dialogtexte ein.
func text_einsetzen(text: String) -> String:
	return text.replace("{name}", spieler_name).replace("{buerge}", buerge)


## Prüft eine Bedingung aus den Dialogdateien.
## Erlaubt: "flag", "!flag", "zaehler>=3", "rang>=2", "abschnitt=nacht",
## mehrere durch Komma getrennt (alle müssen gelten). Eine leere Bedingung gilt immer.
func pruefe_bedingung(bedingung: String) -> bool:
	for teil in bedingung.split(",", false):
		teil = teil.strip_edges()
		if ">=" in teil:
			var stuecke := teil.split(">=")
			var name := stuecke[0].strip_edges()
			var wert := rang if name == "rang" else zaehler_wert(name)
			if wert < int(stuecke[1]):
				return false
		elif teil.begins_with("abschnitt="):
			if String(Spielzeit.abschnitt) != teil.substr(10):
				return false
		elif teil.begins_with("!"):
			if hat_flag(teil.substr(1)):
				return false
		elif not hat_flag(teil):
			return false
	return true


## Wer während der Stille-Stunde spricht, wird zuerst ermahnt, danach bekommt er einen Verweis.
func stille_gebrochen(wer: String) -> void:
	stille_brueche += 1
	if stille_brueche == 1:
		meldung.emit("%s legt den Finger an die Lippen. Bei Dämmerung schweigt die Burg." % wer)
	else:
		verweis("Stille-Stunde gebrochen.")
		meldung.emit("%s schweigt. Ein Verweis wird in deine Akte eingetragen." % wer)


func ist_aufgehoben(pfad: String) -> bool:
	return pfad in aufgehoben


func zuruecksetzen(name: String = "Vertriebener") -> void:
	spieler_name = name
	rang = 0
	buerge = "Hauptwächter Bertil Rask"
	ziel = "Sprich mit dem Kammerhüter an der Schwelle der Burg."
	flags = {}
	zaehler = {}
	akte = []
	stille_brueche = 0
	aufgehoben = []
	eingabe_gesperrt = false


func als_dict() -> Dictionary:
	return {
		"spieler_name": spieler_name,
		"rang": rang,
		"buerge": buerge,
		"ziel": ziel,
		"flags": flags,
		"zaehler": zaehler,
		"akte": akte,
		"stille_brueche": stille_brueche,
		"aufgehoben": aufgehoben,
	}


func aus_dict(daten: Dictionary) -> void:
	spieler_name = daten.get("spieler_name", "Vertriebener")
	rang = int(daten.get("rang", 0))
	buerge = daten.get("buerge", "Hauptwächter Bertil Rask")
	ziel = daten.get("ziel", "")
	flags = daten.get("flags", {})
	zaehler = {}
	var gespeicherte_zaehler: Dictionary = daten.get("zaehler", {})
	for name: String in gespeicherte_zaehler:
		zaehler[name] = int(gespeicherte_zaehler[name])  # JSON liefert Kommazahlen
	akte.assign(daten.get("akte", []))
	stille_brueche = int(daten.get("stille_brueche", 0))
	aufgehoben.assign(daten.get("aufgehoben", []))
	eingabe_gesperrt = false
