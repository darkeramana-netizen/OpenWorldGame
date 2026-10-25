class_name MenueStil
## Gemeinsame Bausteine für Haupt- und Pausemenü.


static func knopf(text: String, aktion: Callable, aktiv: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(420, 44)
	b.add_theme_font_size_override("font_size", 20)
	b.disabled = not aktiv
	b.pressed.connect(aktion)
	return b


static func titel(text: String, groesse: int = 28) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", groesse)
	l.add_theme_color_override("font_color", Color(0.85, 0.65, 0.25))
	return l


static func leeren(behaelter: Node) -> void:
	for kind in behaelter.get_children():
		behaelter.remove_child(kind)
		kind.queue_free()
