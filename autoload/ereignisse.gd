extends Node
## Was mit der Zeit geschieht, auch wenn der Spieler nicht hinsieht: der Sold zum Monatsanfang,
## die Prüfer, die Gold über dem Sold bemerken, und die Folgen einer Bürgschaft.
## Lore: Sold und Versorgung (3.8), Spähwesen und Prüfung (3.11), Bürgschaft (3.7).

## Sold im Monat in Schillingen, Index = Rang (Anwärter keiner, Knappe und Geselle 1, Wächter 3,
## Unteroffiziere 4–6, Offiziere 6–12, Marschall und Komtur 15–20, Ordensleitung 30).
const SOLD: Array[int] = [0, 0, 1, 1, 3, 4, 5, 6, 6, 6, 8, 10, 12, 15, 20, 30, 30, 30, 30]
const MONAT := 30
## Nach so vielen Tagen bemerken die Prüfer Gold, das nicht gemeldet wurde.
const PRUEFER_TAGE := 3
## Nach so vielen Tagen wird ein Bewerber, der nach den Fluchtgängen fragt, von den Prüfern gefasst.
const BEWERBER_TAGE := 4


func _ready() -> void:
	Spielzeit.neuer_tag.connect(_bei_neuem_tag)


func _bei_neuem_tag(_tag: int) -> void:
	if Spielzeit.tag % MONAT == 1:
		_zahle_sold()
	_pruefe_gold()
	_pruefe_bewerber()


func _zahle_sold() -> void:
	var schillinge: int = SOLD[clampi(Spielstand.rang, 0, SOLD.size() - 1)]
	if schillinge == 0:
		return
	if Spielstand.alarmstufe >= 2:
		schillinge *= 2   # Im Krieg verdoppelt sich der Sold.
	Spielstand.geld_aendern(schillinge * Spielstand.HELLER_PRO_SCHILLING)
	Spielstand.meldung.emit("Monatsanfang: %d Schilling%s Sold." % [schillinge, "" if schillinge == 1 else "e"])


## Gold über dem Sold ist ein Warnzeichen. Wer es nicht meldet, wird angezeigt.
func _pruefe_gold() -> void:
	if not Spielstand.hat_flag("gold_angenommen") or Spielstand.hat_flag("gold_gemeldet") or Spielstand.hat_flag("gold_angezeigt"):
		return
	if Spielzeit.gesamttag() - Spielstand.zaehler_wert("gold_tag") >= PRUEFER_TAGE:
		Spielstand.setze_flag("gold_angezeigt")
		Spielstand.anzeige(3, "Gold über dem Sold angenommen und nicht gemeldet")


## Der Bürge haftet: Fasst man den Bewerber, bevor der Bürge ihn meldet, trifft es den Bürgen mit.
func _pruefe_bewerber() -> void:
	if not Spielstand.hat_flag("kerrin_anwaerter") or Spielstand.hat_flag("kerrin_gefasst"):
		return
	if Spielzeit.gesamttag() - Spielstand.zaehler_wert("kerrin_tag") >= BEWERBER_TAGE:
		Spielstand.setze_flag("kerrin_gefasst")
		Spielstand.verweis("Als Bürge für Kerrin Fahl mitverhandelt: Er hat nach den Fluchtgängen gefragt, und du hast es nicht gemeldet.")
		Spielstand.ansehen_aendern("treue", -5)
		Spielstand.meldung.emit("Die Prüfer haben Kerrin Fahl festgenommen. Als sein Bürge stehst du mit in der Akte.")
