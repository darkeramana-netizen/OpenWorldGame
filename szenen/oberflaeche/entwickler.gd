extends CanvasLayer
## Entwicklermenü (F10): Sprungpunkte, Tageszeit, Reisen, Tore öffnen, Akt I überspringen.
## Nur verfügbar, wenn das Spiel aus dem Editor läuft (Debug-Build), nicht im fertigen Spiel.

@onready var _fenster: Control = %Fenster
@onready var _liste: VBoxContainer = %Liste


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fenster.hide()


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not event.is_action_pressed("entwickler"):
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
	_fuelle()


func _schliessen() -> void:
	_fenster.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _fuelle() -> void:
	MenueStil.leeren(_liste)
	_liste.add_child(MenueStil.titel("Entwicklermenü", 22))
	for punkt in get_tree().current_scene.get_node("Sprungpunkte").get_children():
		_liste.add_child(_knopf("→ " + String(punkt.get_meta("anzeige", punkt.name)), springe.bind(punkt.global_position)))
	var zeiten := HBoxContainer.new()
	for eintrag in [["06:00", 6.0], ["12:00", 12.0], ["19:00", 19.0], ["22:00", 22.0]]:
		zeiten.add_child(_knopf(eintrag[0], setze_zeit.bind(eintrag[1]), 100))
	_liste.add_child(zeiten)
	for region: String in Speicher.REGIONEN:
		if region != Speicher.region:
			_liste.add_child(_knopf("Reise nach " + region.capitalize(), reise.bind(region)))
	_liste.add_child(_knopf("Alle Tore öffnen", oeffne_tore))
	_liste.add_child(_knopf("Akt I überspringen (Wächter)", ueberspringe_akt1))
	_liste.add_child(_knopf("Schließen (F10)", _schliessen))


func _knopf(text: String, aktion: Callable, breite: float = 420) -> Button:
	var b := MenueStil.knopf(text, aktion)
	b.custom_minimum_size = Vector2(breite, 34)
	b.add_theme_font_size_override("font_size", 16)
	return b


func springe(ziel: Vector3) -> void:
	var spieler := get_tree().get_first_node_in_group("spieler")
	spieler.global_position = ziel
	spieler.velocity = Vector3.ZERO
	_schliessen()


func setze_zeit(stunde: float) -> void:
	Spielzeit.minuten = stunde * 60.0
	Spielzeit.vorspulen(0.0)
	_schliessen()


## Reist ohne Zeitverlust in eine andere Region, an den Ort, an dem auch das Schiff ankommt.
func reise(region: String) -> void:
	_schliessen()
	Speicher.reise(region, "von_" + Speicher.region)


func oeffne_tore() -> void:
	Spielstand.setze_flag("bergfried_zugang")
	Spielstand.setze_flag("gravecrest_zugang")
	Spielstand.meldung.emit("Entwicklermenü: Alle Tore sind offen.")
	_schliessen()


## Setzt den Spielstand auf das Ende von Akt I (Fenn gemeldet, Wächter, Herbst 1753).
func ueberspringe_akt1() -> void:
	for flag in ["geloebnis", "aufgabe_steine", "steine_abgegeben", "aufgabe_kueche", "kueche_erledigt",
			"pruefung_knappe", "pruefung_lesen", "pruefung_handwerk", "pruefung_nachtwache", "knappe",
			"lehrjahre_vorbei", "aufgabe_torwache", "torwache_erledigt", "torwache_gemeldet", "geselle",
			"fenn_fragte", "fenn_gemeldet", "aufgabe_turmwache", "turmwache_erledigt",
			"zustimmung_hueter", "zustimmung_wachfuehrer", "eid_waechter", "akt1_ende"]:
		Spielstand.setze_flag(flag)
	Spielstand.setze_rang(4)
	Spielzeit.jahr = Spielzeit.STARTJAHR + 3
	Spielstand.akte_eintrag("Entwicklermenü: Akt I übersprungen.")
	Spielstand.setze_ziel("Akt I ist abgeschlossen.")
	_schliessen()
