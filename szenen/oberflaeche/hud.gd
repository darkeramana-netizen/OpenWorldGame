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

var _meldung_tween: Tween


func _ready() -> void:
	_dialog.hide()
	_akte.hide()
	_stille.hide()
	_meldung.modulate.a = 0.0
	_hinweis.text = ""

	Spielzeit.minute_vergangen.connect(func(_m: int) -> void: _zeige_uhr())
	Spielzeit.abschnitt_gewechselt.connect(func(_a: StringName) -> void: _zeige_uhr())
	Spielzeit.stille_gewechselt.connect(_bei_stille)
	Spielstand.meldung.connect(_zeige_meldung)
	Spielstand.akte_geaendert.connect(_fuelle_akte)
	Spielstand.rang_geaendert.connect(func(_r: int) -> void: _fuelle_akte())
	Dialog.zeile_gezeigt.connect(_zeige_zeile)
	Dialog.beendet.connect(func(_id: String) -> void: _dialog.hide())
	if spieler:
		spieler.ziel_gewechselt.connect(_zeige_hinweis)

	_zeige_uhr()
	_bei_stille(Spielzeit.stille_aktiv)
	_fuelle_akte()


func _unhandled_input(event: InputEvent) -> void:
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
	_uhr.text = "Tag %d · %s\n%s" % [Spielzeit.tag, Spielzeit.uhrzeit_text(), Spielzeit.abschnitt_name()]


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
		zeilen.append("[color=%s]Tag %d, %s: %s[/color]" % [farbe, eintrag["tag"], eintrag["uhrzeit"], eintrag["text"]])
	_akte_text.text = "\n".join(zeilen)
