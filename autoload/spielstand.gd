extends Node
## Alles, was der Orden über den Spieler weiß: Name, Rang, Akte, Flags, Zähler und Ziel,
## dazu Ansehen, Verfahren und die Alarmstufe der Welt.
## Lore: Ränge und Eide (Abschnitt 2), Ordensregel (Abschnitt 2 und 3), Disziplin (3.7), Verteidigung (7).

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
signal ansehen_geaendert(gruppe: String, wert: int)
signal alarm_geaendert(stufe: int)
signal verfahren_geaendert
signal geld_geaendert(heller: int)
## Eine belauschte Zeile (szenen/welt/gespraech.gd), unten im Bild.
signal belauscht(text: String)

## Index = Stufe der Waffenlinie. Stufe 0 ist der Bewerber vor dem Gelöbnis.
const RAENGE: Array[String] = [
	"Bewerber", "Anwärter", "Knappe", "Geselle", "Wächter",
	"Unterhüter", "Hüter", "Obersthüter", "Kammerhüter",
	"Bannerträger", "Wachführer", "Hauptwächter", "Bannerführer",
	"Marschall", "Komtur", "Landkomtur", "Ratsmeister",
	"Großkomtur", "Großmeister",
]

## Gruppen, bei denen der Spieler Ansehen hat (Haltungen 3.7, Außenbeziehungen 6). Werte -100 bis 100.
const GRUPPEN := {
	"treue": "den Treuen", "zweifler": "den Zweiflern", "rufer": "den Rufern",
	"doerfer": "den Dörfern", "riverlock": "Riverlock", "stadt": "der Stadt Drachenstein",
}
## Alarmstufen (Verteidigung 7). 1750 gilt Stufe 1.
const ALARMSTUFEN: Array[String] = ["Stille", "Wachsamkeit", "Ende der Stille", "Die letzte Linie"]
## Strafen nach Stufe (Disziplin 3.7), Index = Stufe.
const STRAFEN: Array[String] = ["", "Verweis", "Degradierung", "Strafversetzung", "Ausstoßung", "Verbannung über Riverlock"]
const START_ALARM := 1
## Münzen der Stadt Drachenstein (Sold 3.8): 1 Gulden = 20 Schillinge, 1 Schilling = 12 Heller.
const HELLER_PRO_SCHILLING := 12
const HELLER_PRO_GULDEN := 240

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
var ansehen: Dictionary = {}
var alarmstufe: int = START_ALARM
## Offenes Verfahren beim Kammerhüter: { "stufe": int, "grund": String }, leer wenn keines läuft.
var verfahren: Dictionary = {}
## Geld in Hellern.
var geld: int = 0


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
	# Wer immer wieder auffällt, kommt vor den Kammerhüter.
	if zaehler_wert("verweise") % 3 == 0:
		anzeige(2, "Drei Verweise")


func geld_aendern(heller: int) -> void:
	geld = maxi(geld + heller, 0)
	geld_geaendert.emit(geld)


## z. B. "1 Gulden, 3 Schillinge, 4 Heller"
func geld_text() -> String:
	var teile: PackedStringArray = []
	var gulden := geld / HELLER_PRO_GULDEN
	var schillinge := (geld % HELLER_PRO_GULDEN) / HELLER_PRO_SCHILLING
	var heller := geld % HELLER_PRO_SCHILLING
	if gulden > 0:
		teile.append("%d Gulden" % gulden)
	if schillinge > 0:
		teile.append("%d Schilling%s" % [schillinge, "" if schillinge == 1 else "e"])
	if heller > 0 or teile.is_empty():
		teile.append("%d Heller" % heller)
	return ", ".join(teile)


func ansehen_wert(gruppe: String) -> int:
	return int(ansehen.get(gruppe, 0))


func ansehen_aendern(gruppe: String, wert: int) -> void:
	if not GRUPPEN.has(gruppe) or wert == 0:
		return
	ansehen[gruppe] = clampi(ansehen_wert(gruppe) + wert, -100, 100)
	ansehen_geaendert.emit(gruppe, ansehen[gruppe])
	meldung.emit("Dein Ansehen bei %s %s." % [GRUPPEN[gruppe], "steigt" if wert > 0 else "sinkt"])


func setze_alarmstufe(stufe: int) -> void:
	stufe = clampi(stufe, 0, ALARMSTUFEN.size() - 1)
	if stufe == alarmstufe:
		return
	var hoeher := stufe > alarmstufe
	alarmstufe = stufe
	alarm_geaendert.emit(alarmstufe)
	akte_eintrag("Alarmstufe %d: %s." % [stufe, ALARMSTUFEN[stufe]])
	if hoeher and stufe == 2:
		blende.emit("Auf allen zweiunddreißig Türmen brennen die Feuer. Der Ring der Feuer ist geschlossen. Die Stille ist zu Ende.", "zwischen")
	elif hoeher and stufe == 3:
		blende.emit("Die letzte Linie. Die Dörfer werden geräumt, die Straßen gehören dem Feuer.", "zwischen")
	else:
		meldung.emit("Alarmstufe %d: %s." % [stufe, ALARMSTUFEN[stufe]])


## Anzeige beim Kammerhüter (Verfahren 3.7). Ein laufendes Verfahren wird höchstens schwerer.
func anzeige(stufe: int, grund: String) -> void:
	stufe = clampi(stufe, 2, STRAFEN.size() - 1)
	if not verfahren.is_empty() and int(verfahren["stufe"]) >= stufe:
		return
	verfahren = {"stufe": stufe, "grund": grund}
	akte_eintrag("Anzeige (Stufe %d, %s): %s" % [stufe, STRAFEN[stufe], grund], "anzeige")
	meldung.emit("Gegen dich ist Anzeige erstattet. Der Kammerhüter erwartet dich in Drachenstein.")
	setze_ziel("Stell dich dem Verfahren beim Kammerhüter in der Burgfeste Drachenstein.")
	verfahren_geaendert.emit()


## Urteil im Verfahren vollstrecken (aufgerufen aus dem Gespräch mit dem Kammerhüter).
func urteil_vollstrecken() -> void:
	if verfahren.is_empty():
		return
	var stufe: int = verfahren["stufe"]
	var grund: String = verfahren["grund"]
	akte_eintrag("Urteil (Stufe %d, %s) wegen: %s. Verlesen im Hof, eingetragen im Archiv, gesiegelt." % [stufe, STRAFEN[stufe], grund], "urteil")
	akte_eintrag("Bürge %s im selben Verfahren mitverhandelt." % buerge)
	match stufe:
		2:
			setze_rang(maxi(rang - 1, 1))
			ansehen_aendern("treue", -5)
		3:
			setze_flag("strafversetzt")
			ansehen_aendern("treue", -10)
		4:
			setze_flag("ausgestossen")
			blende.emit("Dein Namensstein wird von der Ordenswand geschlagen. Du bist ausgestoßen.", "spielende")
		5:
			setze_flag("verbannt")
			blende.emit("Man bringt dich über die Brücke von Riverlock. Hinter dir fällt die Kette.", "spielende")
	verfahren = {}
	setze_ziel("")
	verfahren_geaendert.emit()


## Setzt Platzhalter in Dialogtexte ein.
func text_einsetzen(text: String) -> String:
	return text.replace("{name}", spieler_name).replace("{buerge}", buerge)


## Zahlenwerte für Bedingungen: Rang, Alarmstufe, Ansehen ("ansehen_doerfer"), Stufe des
## laufenden Verfahrens ("verfahren_stufe") oder ein Zähler.
func zahlenwert(name: String) -> int:
	if name == "rang":
		return rang
	if name == "alarm":
		return alarmstufe
	if name == "verfahren_stufe":
		return int(verfahren.get("stufe", 0))
	if name.begins_with("ansehen_"):
		return ansehen_wert(name.substr(8))
	return zaehler_wert(name)


## Prüft eine Bedingung aus den Dialogdateien.
## Erlaubt: "flag", "!flag", "zaehler>=3", "rang>=2", "alarm<2", "ansehen_doerfer>=10",
## "verfahren_stufe>=4", "abschnitt=nacht", "abschnitt!=nacht", "region=riverlock",
## mehrere durch Komma getrennt (alle müssen gelten). Eine leere Bedingung gilt immer.
func pruefe_bedingung(bedingung: String) -> bool:
	for teil in bedingung.split(",", false):
		teil = teil.strip_edges()
		if ">=" in teil:
			var stuecke := teil.split(">=")
			if zahlenwert(stuecke[0].strip_edges()) < int(stuecke[1]):
				return false
		elif "<" in teil:
			var stuecke := teil.split("<")
			if zahlenwert(stuecke[0].strip_edges()) >= int(stuecke[1]):
				return false
		elif teil.begins_with("region="):
			if Speicher.region != teil.substr(7):
				return false
		elif teil.begins_with("abschnitt!="):
			if String(Spielzeit.abschnitt) == teil.substr(11):
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
	ansehen = {}
	alarmstufe = START_ALARM
	verfahren = {}
	geld = 0


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
		"ansehen": ansehen,
		"alarmstufe": alarmstufe,
		"verfahren": verfahren,
		"geld": geld,
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
	ansehen = {}
	var gespeichertes_ansehen: Dictionary = daten.get("ansehen", {})
	for gruppe: String in gespeichertes_ansehen:
		ansehen[gruppe] = int(gespeichertes_ansehen[gruppe])
	alarmstufe = int(daten.get("alarmstufe", START_ALARM))
	verfahren = daten.get("verfahren", {})
	geld = int(daten.get("geld", 0))
	if verfahren.has("stufe"):
		verfahren["stufe"] = int(verfahren["stufe"])
