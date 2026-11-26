extends RefCounted
## Themen für Gespräche zwischen Leuten (person.gd): kurze Wortwechsel, die man im Vorbeigehen hört. Jedes Thema ist
## eine Liste von Zeilen [Sprecher (0 der Anfangende, 1 der andere), Text]. Welche Themen in Frage kommen, hängt von
## Tageszeit, Alarmstufe, Ort und Beruf ab (passende()).

const ALLGEMEIN := [
	[[0, "Der Wind kommt heute vom Meer."], [1, "Dann regnet's bis zum Abend, wirst sehen."]],
	[[0, "Hast du gehört? Das Salz ist wieder teurer geworden."], [1, "Seit die Koggen aus Riverlock ausbleiben …"], [0, "Irgendwer verdient immer daran."]],
	[[0, "Mein Rücken bringt mich noch um."], [1, "Dann heb nicht immer die schweren Säcke allein."]],
	[[0, "Die Tochter vom Böttcher heiratet im Herbst."], [1, "Den Fischer? Na, Gott steh ihr bei."]],
	[[0, "Der Komtur war heute früh schlecht gelaunt."], [1, "Wann ist er das nicht?"], [0, "Pst. Nicht so laut."]],
	[[0, "Was gibt's heute in der Küche?"], [1, "Grütze. Wie gestern."], [0, "Und morgen auch, nehm ich an."]],
	[[0, "Die Mauer an der Mittelburg bröckelt wieder."], [1, "Darum stehen die Steinmetze da oben auf dem Gerüst."]],
	[[0, "Man sagt, im Nebelmoor gehen wieder Lichter um."], [1, "Ach, Moorgas. Oder die Alten erzählen Märchen."], [0, "Ich geh da jedenfalls nicht hin."]],
	[[0, "Mein Junge will zum Orden."], [1, "Die Prüfung schafft nicht jeder."], [0, "Er ist zäh. Wie sein Vater."]],
	[[0, "Hast du den neuen Knappen gesehen?"], [1, "Den, der überall herumstreift? Ja."], [0, "Der hat die Augen überall."]],
	[[0, "Die Hühner legen kaum noch."], [1, "Es wird kalt. Das merken die zuerst."]],
	[[0, "Gestern ist eine Kogge eingelaufen. Tuch aus Ashenveil."], [1, "Teuer, wie immer?"], [0, "Teurer."]],
]
const MORGEN := [
	[[0, "Früh auf heute."], [1, "Die Glocke hat mich geweckt."]],
	[[0, "Schon Wasser geholt?"], [1, "Zweimal. Der Brunnen ist kalt wie Eis."]],
]
const ABEND := [
	[[0, "Bald läutet's zur Stille."], [1, "Dann schnell noch heim."]],
	[[0, "Langer Tag."], [1, "Wie jeder."], [0, "Morgen wird's besser."]],
]
const NACHT := [
	[[0, "Hörst du das?"], [1, "Nur der Wind in den Zinnen."], [0, "Hoffentlich."]],
	[[0, "Kalt heute Nacht."], [1, "Bleib bei der Fackel."]],
]
const ALARM := [
	[[0, "Hast du die Wachen gesehen? Doppelt so viele wie sonst."], [1, "Man sagt, Späher am Nordpass."], [0, "Heilige Mutter …"]],
	[[0, "Warum sind die Tore zu?"], [1, "Alarm. Frag nicht, geh heim."]],
	[[0, "Was ist da los?"], [1, "Weiß nicht. Aber ich will's auch nicht wissen."]],
]
const WACHE := [
	[[0, "Ablösung kommt erst in zwei Stunden."], [1, "Dann steh gerade, der Hauptmann schaut."]],
	[[0, "Am Nordtor war gestern einer ohne Siegel."], [1, "Hast ihn durchgelassen?"], [0, "Bin ich verrückt?"]],
	[[0, "Die Klinge braucht wieder Öl."], [1, "Deine Klinge braucht vor allem Übung."]],
]
const HANDWERK := [
	[[0, "Das Eisen ist diesmal schlecht. Voller Schlacke."], [1, "Dann schlag fester."]],
	[[0, "Reich mir mal den Hammer."], [1, "Wo hast du deinen gelassen?"], [0, "Frag nicht."]],
	[[0, "Der Balken ist krumm."], [1, "Dann wird's eben ein krummes Dach."]],
]
const MARKT := [
	[[0, "Drei Heller für den Fisch? Halsabschneider!"], [1, "Frisch von heute früh, gute Frau!"], [0, "Zwei. Und keinen mehr."]],
	[[0, "Habt Ihr noch Zwiebeln?"], [1, "Die letzten. Für Euch zum halben Preis."]],
	[[0, "Der Töpfer hat neue Krüge."], [1, "Die alten sind auch schon beim ersten Wein gesprungen."]],
]
const STILLE := [
	[[0, "(flüstert) Still jetzt."], [1, "(flüstert) Ich weiß."]],
]


## Ein passendes Thema für zwei Leute (Liste der Zeilen). beruf_a, beruf_b: Berufe aus figur.gd; ort: Weltposition.
static func passendes(abschnitt: String, alarm: int, beruf_a: String, beruf_b: String, am_markt: bool) -> Array:
	var vorrat: Array = ALLGEMEIN.duplicate()
	if abschnitt == "morgengrauen":
		vorrat += MORGEN + MORGEN
	elif abschnitt == "stille_stunde":
		return STILLE[randi() % STILLE.size()]
	elif abschnitt == "nacht":
		vorrat = NACHT + NACHT + ALLGEMEIN.slice(0, 3)
	elif abschnitt == "nachmittag":
		vorrat += ABEND
	if alarm >= 2:
		vorrat = ALARM + ALARM + vorrat.slice(0, 2)
	var wachen := ["wache", "ritter"]
	if beruf_a in wachen and beruf_b in wachen:
		vorrat = WACHE + WACHE + vorrat.slice(0, 3)
	if beruf_a in ["schmied", "zeugwart", "knecht"] or beruf_b in ["schmied", "zeugwart", "knecht"]:
		vorrat += HANDWERK
	if am_markt:
		vorrat = MARKT + MARKT + vorrat
	return vorrat[randi() % vorrat.size()]
