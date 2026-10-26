extends CanvasLayer
## Bildschirmanzeige: Uhrzeit, Stille-Stunde, Hinweise, Gespräche und die eigene Akte.

@export var spieler: Node

@onready var _uhr: Label = %Uhr
@onready var _stille: Label = %Stille
@onready var _hinweis: Label = %Hinweis
@onready var _meldung: Label = %Meldung
@onready var _dialog: PanelContainer = %DialogFenster
@onready var _sprecher: Label = %Sprecher
@onready var _text: Label = %Text
@onready var _optionen: VBoxContainer = %Optionen
@onready var _akte: PanelContainer = %AkteFenster
@onready var _akte_text: RichTextLabel = %AkteText
@onready var _ziel: Label = %Ziel
@onready var _blende: ColorRect = %Blende
@onready var _blende_text: Label = %BlendeText
@onready var _blende_hinweis: Label = %BlendeHinweis
@onready var _ort: Label = %Ort
@onready var _karte: Control = %Karte
@onready var _karte_bild: TextureRect = %KarteBild
@onready var _karte_marke: Label = %KarteMarke

## Lage von Drachenstein auf der Karte (Pixel) und Maßstab: 1 Kartenpixel = 5 m im Spiel.
const KARTE_METER_PRO_PIXEL := 5.0

var _meldung_tween: Tween
var _ort_tween: Tween
## Wartende Blenden als [text, art], sie laufen nacheinander ab.
var _blenden: Array = []
var _blende_laeuft := false
var _warte_auf_taste := false


func _ready() -> void:
	_dialog.hide()
	_akte.hide()
	_stille.hide()
	_blende.hide()
	_karte.hide()
	_ort.modulate.a = 0.0
	_meldung.modulate.a = 0.0
	_hinweis.text = ""

	Spielzeit.minute_vergangen.connect(func(_m: int) -> void: _zeige_uhr())
	Spielzeit.abschnitt_gewechselt.connect(func(_a: StringName) -> void: _zeige_uhr())
	Spielzeit.stille_gewechselt.connect(_bei_stille)
	Spielstand.meldung.connect(_zeige_meldung)
	Spielstand.akte_geaendert.connect(_fuelle_akte)
	Spielstand.rang_geaendert.connect(func(_r: int) -> void: _fuelle_akte())
	Spielstand.ziel_geaendert.connect(_zeige_ziel)
	Spielstand.blende.connect(_bei_blende)
	Spielstand.ort_betreten.connect(_zeige_ort)
	Dialog.zeile_gezeigt.connect(_zeige_zeile)
	Dialog.beendet.connect(func(_id: String) -> void: _dialog.hide())
	if spieler:
		spieler.ziel_gewechselt.connect(_zeige_hinweis)

	_zeige_uhr()
	_zeige_ziel(Spielstand.ziel)
	_bei_stille(Spielzeit.stille_aktiv)
	_fuelle_akte()


func _unhandled_input(event: InputEvent) -> void:
	if Spielstand.eingabe_gesperrt:
		# Während einer Blende wird jede Eingabe geschluckt. Am Spielende führt sie ins Hauptmenü.
		if _warte_auf_taste and event.is_pressed() and not event.is_echo():
			Speicher.zum_hauptmenue()
		if event is InputEventKey or event is InputEventMouseButton:
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("karte_zeigen") and not Dialog.aktiv:
		_karte.visible = not _karte.visible
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("akte_zeigen"):
		_akte.visible = not _akte.visible
		get_viewport().set_input_as_handled()
		return
	if not Dialog.aktiv:
		return
	# Antworten auch mit den Zifferntasten 1 bis 9 wählen, "Weiter" mit E oder Leertaste.
	if event is InputEventKey and event.pressed and not event.echo:
		var ziffer: int = event.physical_keycode - KEY_1
		if ziffer >= 0 and ziffer < _optionen.get_child_count():
			_optionen.get_child(ziffer).emit_signal("pressed")
			get_viewport().set_input_as_handled()
		elif event.is_action("interagieren") or event.is_action("springen"):
			if _optionen.get_child_count() == 1:
				_optionen.get_child(0).emit_signal("pressed")
				get_viewport().set_input_as_handled()


func _zeige_uhr() -> void:
	_uhr.text = "%s · %s\n%s" % [Spielzeit.datum_text(), Spielzeit.uhrzeit_text(), Spielzeit.abschnitt_name()]


func _process(_delta: float) -> void:
	if _karte.visible and spieler:
		# Spielerposition auf der Karte: Pfeil zeigt in Blickrichtung.
		var p: Vector3 = spieler.global_position
		var pixel := Region.von(self).karten_pixel(p)
		var faktor := _karte_bild.size / _karte_bild.texture.get_size()
		var massstab := minf(faktor.x, faktor.y)
		var versatz := (_karte_bild.size - _karte_bild.texture.get_size() * massstab) / 2.0
		_karte_marke.position = _karte_bild.position + versatz + pixel * massstab - _karte_marke.size / 2.0
		_karte_marke.pivot_offset = _karte_marke.size / 2.0
		_karte_marke.rotation = -spieler.get_node("Koerper").rotation.y


func _zeige_ort(name: String, untertitel: String) -> void:
	_ort.text = name if untertitel == "" else "%s\n%s" % [name, untertitel]
	if _ort_tween:
		_ort_tween.kill()
	_ort_tween = create_tween()
	_ort_tween.tween_property(_ort, "modulate:a", 1.0, 0.8)
	_ort_tween.tween_interval(3.0)
	_ort_tween.tween_property(_ort, "modulate:a", 0.0, 1.5)


func _zeige_ziel(text: String) -> void:
	_ziel.text = "Ziel: " + text if text != "" else ""


func _bei_blende(text: String, art: String) -> void:
	_blenden.append([text, art])
	Spielstand.eingabe_gesperrt = true
	if not _blende_laeuft:
		_naechste_blende()


func _naechste_blende() -> void:
	if _blenden.is_empty():
		_blende_laeuft = false
		Spielstand.eingabe_gesperrt = false
		return
	_blende_laeuft = true
	var eintrag: Array = _blenden.pop_front()
	var art: String = eintrag[1]
	_blende_text.text = eintrag[0]
	_blende_hinweis.visible = false
	_blende.modulate.a = 0.0
	_blende.show()
	var tween := create_tween()
	tween.tween_property(_blende, "modulate:a", 1.0, 0.8)
	tween.tween_interval(6.0 if art == "akt_ende" else 3.5)
	if art == "spielende":
		tween.tween_callback(func() -> void:
			_blende_hinweis.visible = true
			_warte_auf_taste = true)
		return
	tween.tween_property(_blende, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func() -> void:
		_blende.hide()
		_naechste_blende())


func _bei_stille(aktiv: bool) -> void:
	_stille.visible = aktiv
	if aktiv:
		_zeige_meldung("Die Dämmerung kommt. Die Burg schweigt eine Stunde lang.")


func _zeige_hinweis(ziel: Node) -> void:
	if ziel == null:
		_hinweis.text = ""
	else:
		_hinweis.text = "[E] %s – %s" % [ziel.aktion_text, ziel.anzeige_name]


func _zeige_meldung(text: String) -> void:
	_meldung.text = text
	if _meldung_tween:
		_meldung_tween.kill()
	_meldung.modulate.a = 1.0
	_meldung_tween = create_tween()
	_meldung_tween.tween_interval(4.0)
	_meldung_tween.tween_property(_meldung, "modulate:a", 0.0, 1.0)


func _zeige_zeile(sprecher: String, text: String, optionen: Array) -> void:
	_dialog.show()
	_hinweis.text = ""
	_sprecher.text = sprecher
	_text.text = text
	for kind in _optionen.get_children():
		_optionen.remove_child(kind)
		kind.queue_free()
	if optionen.is_empty():
		_neuer_knopf("Weiter  [E]", 0)
	else:
		for i in optionen.size():
			_neuer_knopf("%d.  %s" % [i + 1, optionen[i]], i)


func _neuer_knopf(beschriftung: String, index: int) -> void:
	var knopf := Button.new()
	knopf.text = beschriftung
	knopf.alignment = HORIZONTAL_ALIGNMENT_LEFT
	knopf.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	knopf.focus_mode = Control.FOCUS_NONE
	knopf.pressed.connect(func() -> void: Dialog.waehle(index))
	_optionen.add_child(knopf)


func _fuelle_akte() -> void:
	var zeilen: PackedStringArray = [
		"[b]Dienstakte[/b]",
		"Rang: %s" % Spielstand.rang_name(),
		"Kordel: %s" % Spielstand.kordel_name(),
		"Bürge: %s" % Spielstand.buerge,
		"",
	]
	if Spielstand.akte.is_empty():
		zeilen.append("[i]Noch keine Einträge.[/i]")
	for eintrag in Spielstand.akte:
		var farbe := "#e07a5f" if eintrag["art"] == "verweis" else "#e8dcc4"
		zeilen.append("[color=%s]%s, %s: %s[/color]" % [farbe, eintrag.get("datum", ""), eintrag["uhrzeit"], eintrag["text"]])
	_akte_text.text = "\n".join(zeilen)
