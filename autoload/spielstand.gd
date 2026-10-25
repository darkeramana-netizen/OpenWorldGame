extends Node
## Alles, was der Orden über den Spieler weiß: Rang, Akte, Flags und Zähler.
## Lore: Ränge und Eide (Abschnitt 2), Ordensregel (Abschnitt 2 und 3).

signal akte_geaendert
signal rang_geaendert(rang: int)
## Kurze Einblendung im HUD.
signal meldung(text: String)

## Index = Stufe der Waffenlinie. Stufe 0 ist der Bewerber vor dem Gelöbnis.
const RAENGE: Array[String] = [
	"Bewerber", "Anwärter", "Knappe", "Geselle", "Wächter",
	"Unterhüter", "Hüter", "Obersthüter", "Kammerhüter",
	"Bannerträger", "Wachführer", "Hauptwächter", "Bannerführer",
	"Marschall", "Komtur", "Landkomtur", "Ratsmeister",
	"Großkomtur", "Großmeister",
]

var rang: int = 0
var buerge: String = "Hauptwächter Bertil Rask"
var flags: Dictionary = {}
var zaehler: Dictionary = {}
## Einträge: { "text": String, "art": String, "tag": int, "uhrzeit": String }
var akte: Array[Dictionary] = []
var stille_brueche: int = 0


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


func hat_flag(name: String) -> bool:
	return flags.get(name, false)


func zaehler_wert(name: String) -> int:
	return zaehler.get(name, 0)


func zaehler_aendern(name: String, wert: int) -> void:
	zaehler[name] = zaehler_wert(name) + wert


func akte_eintrag(text: String, art: String = "eintrag") -> void:
	akte.append({
		"text": text,
		"art": art,
		"tag": Spielzeit.tag,
		"uhrzeit": Spielzeit.uhrzeit_text(),
	})
	akte_geaendert.emit()


## Prüft eine Bedingung aus den Dialogdateien.
## Erlaubt: "flag", "!flag", "zaehler>=3", mehrere durch Komma getrennt (alle müssen gelten).
## Eine leere Bedingung gilt immer.
func pruefe_bedingung(bedingung: String) -> bool:
	for teil in bedingung.split(",", false):
		teil = teil.strip_edges()
		if ">=" in teil:
			var stuecke := teil.split(">=")
			if zaehler_wert(stuecke[0].strip_edges()) < int(stuecke[1]):
				return false
		elif teil.begins_with("!"):
			if hat_flag(teil.substr(1)):
				return false
		elif not hat_flag(teil):
			return false
	return true


## Wer während der Stille-Stunde spricht, bekommt beim zweiten Mal einen Verweis (Strafstufe 1).
func stille_gebrochen(wer: String) -> void:
	stille_brueche += 1
	if stille_brueche == 1:
		meldung.emit("%s legt den Finger an die Lippen. Bei Dämmerung schweigt die Burg." % wer)
	else:
		akte_eintrag("Verweis (Stufe 1): Stille-Stunde gebrochen.", "verweis")
		meldung.emit("%s schweigt. Ein Verweis wird in deine Akte eingetragen." % wer)
