extends CanvasLayer
## Pausemenü auf Esc: Weiter, Speichern, Laden, Hauptmenü, Beenden. Hält das Spiel an.

@onready var _fenster: Control = %Fenster
@onready var _liste: VBoxContainer = %Liste


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fenster.hide()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	get_viewport().set_input_as_handled()
	if _fenster.visible:
		_schliessen()
	elif not Dialog.aktiv and not Spielstand.eingabe_gesperrt:
		_oeffnen()


func _oeffnen() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_fenster.show()
	_zeige_start()


func _schliessen() -> void:
	_fenster.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _zeige_start() -> void:
	MenueStil.leeren(_liste)
	_liste.add_child(MenueStil.titel("Pause"))
	_liste.add_child(MenueStil.knopf("Weiter", _schliessen))
	_liste.add_child(MenueStil.knopf("Speichern", _zeige_speichern))
	_liste.add_child(MenueStil.knopf("Laden", _zeige_laden))
	_liste.add_child(MenueStil.knopf("Hauptmenü", Speicher.zum_hauptmenue))
	_liste.add_child(MenueStil.knopf("Beenden", func() -> void: get_tree().quit()))


func _zeige_speichern() -> void:
	MenueStil.leeren(_liste)
	_liste.add_child(MenueStil.titel("Speichern"))
	for platz in Speicher.PLAETZE:
		_liste.add_child(MenueStil.knopf("Platz %s: %s" % [platz, Speicher.beschreibung(platz)],
			_speichere_auf.bind(platz)))
	_liste.add_child(MenueStil.knopf("Zurück", _zeige_start))


func _speichere_auf(platz: String) -> void:
	if Speicher.speichern(platz):
		Spielstand.meldung.emit("Gespeichert auf Platz %s." % platz)
	_schliessen()


func _zeige_laden() -> void:
	MenueStil.leeren(_liste)
	_liste.add_child(MenueStil.titel("Laden"))
	for platz in ["auto", "schnell"] + Speicher.PLAETZE:
		var name: String = {"auto": "Automatisch", "schnell": "Schnell"}.get(platz, "Platz " + platz)
		_liste.add_child(MenueStil.knopf("%s: %s" % [name, Speicher.beschreibung(platz)],
			func() -> void: Speicher.laden(platz), Speicher.existiert(platz)))
	_liste.add_child(MenueStil.knopf("Zurück", _zeige_start))
