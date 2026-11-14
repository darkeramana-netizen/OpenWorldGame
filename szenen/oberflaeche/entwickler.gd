extends CanvasLayer
## Entwicklermenü (F10): Sprungpunkte, Tageszeit, Reisen, Alarmstufe, Flugmodus (F11), Tore öffnen, Akt I überspringen.
## Nur verfügbar, wenn das Spiel aus dem Editor läuft (Debug-Build), nicht im fertigen Spiel.

@onready var _fenster: Control = %Fenster
@onready var _liste: VBoxContainer = %Liste


var _ort: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fenster.hide()
	# Im Debug-Spiel unten links die Position der Kamera und ihre Blickrichtung: so steht auf jedem Bildschirmfoto,
	# wo es aufgenommen wurde (für Fehlerberichte)
	if OS.is_debug_build():
		_ort = Label.new()
		_ort.name = "Ort"
		_ort.add_theme_font_size_override("font_size", 13)
		_ort.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
		_ort.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		_ort.add_theme_constant_override("outline_size", 4)
		_ort.anchor_top = 1.0
		_ort.anchor_bottom = 1.0
		_ort.offset_left = 10
		_ort.offset_top = -24
		add_child(_ort)


func _process(_delta: float) -> void:
	if _ort == null:
		return
	var kamera := get_viewport().get_camera_3d()
	if kamera == null:
		_ort.text = ""
		return
	var p := kamera.global_position
	var blick := -kamera.global_basis.z
	_ort.text = "Ort %.0f, %.0f, %.0f · Blick %.0f°, %.0f° geneigt" % [p.x, p.y, p.z,
		rad_to_deg(atan2(blick.x, -blick.z)), rad_to_deg(asin(clampf(blick.y, -1.0, 1.0)))]


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
	var alarm := HBoxContainer.new()
	for stufe in 4:
		alarm.add_child(_knopf("Alarm %d" % stufe, setze_alarm.bind(stufe), 100))
	_liste.add_child(alarm)
	_liste.add_child(_knopf("Flugmodus an/aus (F11)", schalte_flugmodus))
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


func setze_alarm(stufe: int) -> void:
	_schliessen()
	Spielstand.setze_alarmstufe(stufe)


func schalte_flugmodus() -> void:
	var spieler := get_tree().get_first_node_in_group("spieler")
	_schliessen()
	if spieler:
		spieler.schalte_flugmodus(not spieler.fliegt)


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
