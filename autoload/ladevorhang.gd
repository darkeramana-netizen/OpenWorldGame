extends CanvasLayer
## Ladebildschirm beim Wechsel in eine Region (Phase 1, Punkt 2, docs/03-messgrundlage.md).
##
## Ablauf (Speicher._wechsle_zu):
## 1. zeige(): Der Vorhang deckt das Bild ab, die Eingabe ist gesperrt.
## 2. Die Szene wird im Hintergrund geladen (Fortschritt sichtbar), dann aufgebaut (dabei steht das Bild still).
## 3. warte_und_blende_aus(): Die Welt läuft hinter dem Vorhang schon. In den ersten Bildern entstehen die
##    Render-Pipelines (Shader-Varianten); das kostet auf dem Referenzrechner gut 2 s in einem Bild. Der Vorhang bleibt,
##    bis RUHIG_BILDER Bilder in Folge keine neuen Pipelines brachten und schneller als RUHIG_MS waren, die Figuren
##    gebaut sind und mindestens MIN_BILDER Bilder gezeichnet wurden (höchstens MAX_S). Dann blendet er aus.

const MIN_BILDER := 5
const RUHIG_BILDER := 5
const RUHIG_MS := 50.0
const MAX_S := 15.0
const AUSBLENDEN_S := 0.6

const REGION_NAMEN := {
	"drachenstein": "Drachenstein", "riverlock": "Riverlock", "ashenveil": "Ashenveil",
	"nordstrasse": "Die Nordstraße", "suedstrasse": "Die Südstraße", "kuestenweg": "Der Küstenweg",
}
const HINWEISE := [
	"Mit M öffnest du die Karte, mit Tab deine Akte.",
	"F5 speichert schnell, F9 lädt den Schnellspeicherstand.",
	"Mit Strg schleichst du, mit Umschalt rennst du.",
	"Mit E sprichst du Leute an, öffnest Türen und hebst Dinge auf.",
	"F zieht die Waffe, Q wechselt sie, R lädt die Muskete nach.",
	"Wachen schließen die Tore bei Nacht. Wer dann noch hinein will, braucht einen guten Grund.",
]
const GOLD := Color(0.85, 0.65, 0.25)
const FigurSkript := preload("res://szenen/figuren/figur.gd")

## true: kein Vorhang (für Werkzeuge, die selbst messen)
var aus := false
## Ob der Vorhang gerade steht (auch während des Ausblendens)
var sichtbar := false
## Dauer des letzten Ladens vom Zeigen bis zum Ausblenden (ms), für Tests
var letzte_ladezeit_ms := 0.0

signal weg

var _wurzel: Control
var _region: Label
var _schritt: Label
var _hinweis: Label
var _balken: ProgressBar
var _start_us := 0
var _hinweis_nr := 0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_baue()
	_wurzel.visible = false


## Vorhang zeigen (wartet, bis er wirklich auf dem Bild ist).
func zeige(region: String) -> void:
	_start_us = Time.get_ticks_usec()
	sichtbar = true
	Spielstand.eingabe_gesperrt = true
	_region.text = REGION_NAMEN.get(region, region.capitalize())
	_hinweis.text = HINWEISE[_hinweis_nr % HINWEISE.size()]
	_hinweis_nr += 1
	_wurzel.modulate.a = 1.0
	_wurzel.visible = true
	schritt("Lade die Karte …", 0.0)
	await get_tree().process_frame
	await get_tree().process_frame


func schritt(text: String, anteil: float) -> void:
	_schritt.text = text
	_balken.value = clampf(anteil, 0.0, 1.0) * 100.0


## Nach dem Aufbau: warten, bis die Darstellung ruhig läuft, dann ausblenden und die Eingabe freigeben.
func warte_und_blende_aus() -> void:
	schritt("Bereite die Darstellung vor …", 0.8)
	var ende := Time.get_ticks_msec() + int(MAX_S * 1000.0)
	var bilder := 0
	var ruhig := 0
	var pipelines := pipelines_bisher()
	var t := Time.get_ticks_usec()
	while Time.get_ticks_msec() < ende:
		await get_tree().process_frame
		var jetzt := Time.get_ticks_usec()
		var p := pipelines_bisher()
		bilder += 1
		if p == pipelines and (jetzt - t) / 1000.0 < RUHIG_MS and figuren_wartend() == 0:
			ruhig += 1
		else:
			ruhig = 0
		pipelines = p
		t = jetzt
		schritt("Bereite die Darstellung vor …", 0.8 + 0.2 * minf(float(ruhig) / RUHIG_BILDER, 1.0))
		if bilder >= MIN_BILDER and ruhig >= RUHIG_BILDER:
			break
	letzte_ladezeit_ms = (Time.get_ticks_usec() - _start_us) / 1000.0
	Spielstand.eingabe_gesperrt = false
	var tw := create_tween()
	tw.tween_property(_wurzel, "modulate:a", 0.0, AUSBLENDEN_S)
	await tw.finished
	_wurzel.visible = false
	sichtbar = false
	weg.emit()


## Bisher erzeugte Render-Pipelines (alle Quellen); steigt, wenn neue Materialien zum ersten Mal gezeichnet werden.
static func pipelines_bisher() -> float:
	return (Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS)
		+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH)
		+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)
		+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)
		+ Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION))


## Figuren, deren erster Bau noch aussteht (szenen/figuren/figur.gd, Warteschlange)
static func figuren_wartend() -> int:
	return FigurSkript._warteschlange.size()


func _baue() -> void:
	_wurzel = Control.new()
	_wurzel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wurzel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_wurzel)
	var grund := ColorRect.new()
	grund.color = Color(0.045, 0.04, 0.035)
	grund.set_anchors_preset(Control.PRESET_FULL_RECT)
	grund.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wurzel.add_child(grund)

	var mitte := VBoxContainer.new()
	mitte.set_anchors_preset(Control.PRESET_CENTER)
	mitte.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mitte.grow_vertical = Control.GROW_DIRECTION_BOTH
	mitte.alignment = BoxContainer.ALIGNMENT_CENTER
	mitte.add_theme_constant_override("separation", 6)
	_wurzel.add_child(mitte)
	var titel := _label("SORROWLAND", 44, GOLD)
	mitte.add_child(titel)
	mitte.add_child(_label("In Silentio", 20, Color(0.7, 0.62, 0.5)))
	var abstand := Control.new()
	abstand.custom_minimum_size = Vector2(0, 40)
	mitte.add_child(abstand)
	_region = _label("", 30, Color(0.9, 0.86, 0.78))
	mitte.add_child(_region)

	var unten := VBoxContainer.new()
	unten.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	unten.grow_horizontal = Control.GROW_DIRECTION_BOTH
	unten.grow_vertical = Control.GROW_DIRECTION_BEGIN
	unten.offset_bottom = -48
	unten.custom_minimum_size = Vector2(560, 0)
	unten.offset_left = -280
	unten.offset_right = 280
	unten.add_theme_constant_override("separation", 10)
	_wurzel.add_child(unten)
	_hinweis = _label("", 17, Color(0.72, 0.68, 0.6))
	_hinweis.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	unten.add_child(_hinweis)
	_balken = ProgressBar.new()
	_balken.show_percentage = false
	_balken.custom_minimum_size = Vector2(560, 6)
	var leer := StyleBoxFlat.new()
	leer.bg_color = Color(1, 1, 1, 0.08)
	var voll := StyleBoxFlat.new()
	voll.bg_color = GOLD
	_balken.add_theme_stylebox_override("background", leer)
	_balken.add_theme_stylebox_override("fill", voll)
	unten.add_child(_balken)
	_schritt = _label("", 14, Color(0.55, 0.52, 0.47))
	unten.add_child(_schritt)


static func _label(text: String, groesse: int, farbe: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", groesse)
	l.add_theme_color_override("font_color", farbe)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
