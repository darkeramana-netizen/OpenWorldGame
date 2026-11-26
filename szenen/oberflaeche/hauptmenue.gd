extends Control
## Hauptmenü: Fortsetzen, neues Spiel mit Namen, Laden, Beenden.

@onready var _liste: VBoxContainer = %Liste


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_zeige_start()


func _zeige_start() -> void:
	MenueStil.leeren(_liste)
	var neuester := Speicher.neuester_platz()
	if neuester != "":
		_liste.add_child(MenueStil.knopf("Fortsetzen", func() -> void: Speicher.laden(neuester)))
	_liste.add_child(MenueStil.knopf("Neues Spiel", _zeige_neues_spiel))
	_liste.add_child(MenueStil.knopf("Laden", _zeige_laden, neuester != ""))
	# Grafikstufe (autoload/grafik.gd): jeder Druck schaltet eine Stufe weiter
	var grafik := MenueStil.knopf("Grafik: " + Grafik.name_(), func() -> void: pass)
	grafik.pressed.connect(func() -> void:
		Grafik.naechste()
		grafik.text = "Grafik: " + Grafik.name_())
	_liste.add_child(grafik)
	# Lautstärke (autoload/klang.gd): jeder Druck eine Stufe leiser, nach „aus“ wieder voll
	var ton := MenueStil.knopf("Ton: " + Klang.lautstaerke_text(), func() -> void: pass)
	ton.pressed.connect(func() -> void:
		Klang.naechste_lautstaerke()
		ton.text = "Ton: " + Klang.lautstaerke_text())
	_liste.add_child(ton)
	_liste.add_child(MenueStil.knopf("Mitwirkende", _zeige_mitwirkende))
	_liste.add_child(MenueStil.knopf("Beenden", func() -> void: get_tree().quit()))
	_liste.get_child(0).grab_focus()


func _zeige_neues_spiel() -> void:
	MenueStil.leeren(_liste)
	_liste.add_child(MenueStil.titel("Wie heißt du?", 22))
	var eingabe := LineEdit.new()
	eingabe.placeholder_text = "Dein Name"
	eingabe.max_length = 24
	eingabe.custom_minimum_size = Vector2(420, 44)
	eingabe.add_theme_font_size_override("font_size", 20)
	eingabe.alignment = HORIZONTAL_ALIGNMENT_CENTER
	eingabe.text_submitted.connect(func(t: String) -> void: Speicher.neues_spiel(t))
	_liste.add_child(eingabe)
	_liste.add_child(MenueStil.knopf("An die Schwelle treten", func() -> void: Speicher.neues_spiel(eingabe.text)))
	_liste.add_child(MenueStil.knopf("Zurück", _zeige_start))
	eingabe.grab_focus()


func _zeige_laden() -> void:
	MenueStil.leeren(_liste)
	_liste.add_child(MenueStil.titel("Laden", 22))
	for platz in ["auto", "schnell"] + Speicher.PLAETZE:
		var name: String = {"auto": "Automatisch", "schnell": "Schnell"}.get(platz, "Platz " + platz)
		_liste.add_child(MenueStil.knopf("%s: %s" % [name, Speicher.beschreibung(platz)],
			func() -> void: Speicher.laden(platz), Speicher.existiert(platz)))
	_liste.add_child(MenueStil.knopf("Zurück", _zeige_start))


## Mitwirkende und freie Quellen (Namensnennung, wo die Lizenz sie verlangt; alles andere ist CC0)
func _zeige_mitwirkende() -> void:
	MenueStil.leeren(_liste)
	_liste.add_child(MenueStil.titel("Mitwirkende", 26))
	for zeile: String in [
			"Modelle und Texturen: Poly Haven, ambientCG (CC0)",
			"Menschen: MakeHuman (CC0), Figuren und Tiere: Quaternius (CC0)",
			"Geräusche: Kenney, artisticdude, „Dog sounds“ (CC0)",
			"Hühner: „Chicken Sound Effect“ von IMadeIt (CC-BY 3.0)",
			"Weitere Geräusche selbst erzeugt"]:
		var l := MenueStil.titel(zeile, 16)
		_liste.add_child(l)
	_liste.add_child(MenueStil.knopf("Zurück", _zeige_start))
	_liste.get_child(_liste.get_child_count() - 1).grab_focus()
