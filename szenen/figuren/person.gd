extends StaticBody3D
## Eine Person, die man ansprechen kann. Während der Stille-Stunde schweigt sie.

enum Kordel { KEINE, SCHWARZ, GRAU, GOLDEN }

const KORDELFARBEN := {
	Kordel.KEINE: Color(0, 0, 0, 0),
	Kordel.SCHWARZ: Color(0.05, 0.05, 0.05),
	Kordel.GRAU: Color(0.55, 0.55, 0.58),
	Kordel.GOLDEN: Color(0.85, 0.65, 0.2),
}

@export var anzeige_name: String = "Wächter"
## Dateiname ohne Endung in res://daten/dialoge/.
@export var dialog_id: String = ""
## Rangabzeichen am Kragen (Alltag 1.3).
@export var kordel: Kordel = Kordel.SCHWARZ
@export var tracht: Color = Color(0.15, 0.15, 0.17)
## Die Person ist nur da, solange diese Bedingung gilt (Schreibweise wie in den Dialogen).
@export var sichtbar_wenn: String = ""

var aktion_text: String = "Sprechen"


func _ready() -> void:
	$Name.text = anzeige_name
	$Mesh.material_override = _material(tracht)
	$Kordel.visible = kordel != Kordel.KEINE
	$Kordel.material_override = _material(KORDELFARBEN[kordel])
	Spielstand.flag_geaendert.connect(func(_f: String) -> void: _pruefe_sichtbarkeit())
	Spielstand.alarm_geaendert.connect(func(_s: int) -> void: _pruefe_sichtbarkeit())
	_pruefe_sichtbarkeit()


func interagieren(spieler: Node3D) -> void:
	_schaue_zu(spieler.global_position)
	if Spielzeit.stille_aktiv:
		Spielstand.stille_gebrochen(anzeige_name)
		return
	Dialog.starte(dialog_id, anzeige_name)


func _pruefe_sichtbarkeit() -> void:
	var da := Spielstand.pruefe_bedingung(sichtbar_wenn)
	visible = da
	$Kollision.set_deferred("disabled", not da)
	if da:
		add_to_group("interagierbar")
		add_to_group("treffbar")
	else:
		remove_from_group("interagierbar")
		remove_from_group("treffbar")


## Der Spieler hebt die Waffe gegen diese Person (kampf.gd). Personen wehren ab und werden nicht verletzt,
## aber es hat Folgen (Disziplin 3.7): gegen Ordensleute ein Verweis, gegen Leute ohne Kordel erst eine
## Anzeige, beim zweiten Mal eine Anzeige auf Ausstoßung ("Waffe gegen Dorfbewohner").
func treffer(_schaden: float, quelle: Node3D, _art: String) -> void:
	if quelle == null or not quelle.is_in_group("spieler"):
		return
	_schaue_zu(quelle.global_position)
	if kordel != Kordel.KEINE:
		Spielstand.meldung.emit("%s pariert: „Steck das weg, sonst stehst du vor dem Kammerhüter.“" % anzeige_name)
		Spielstand.verweis("Waffe gegen %s erhoben." % anzeige_name)
		Spielstand.ansehen_aendern("treue", -5)
		return
	var gruppe := {"drachenstein": "stadt", "riverlock": "riverlock"}.get(Speicher.region, "doerfer") as String
	Spielstand.ansehen_aendern(gruppe, -15)
	if Spielstand.hat_flag("zivilist_bedroht"):
		Spielstand.meldung.emit("%s schreit um Hilfe. Das wird dich teuer zu stehen kommen." % anzeige_name)
		Spielstand.anzeige(4, "Waffe gegen Dorfbewohner erhoben (%s)" % anzeige_name)
	else:
		Spielstand.setze_flag("zivilist_bedroht")
		Spielstand.meldung.emit("%s weicht zurück: „Bist du von Sinnen? Ich zeige dich an!“" % anzeige_name)
		Spielstand.anzeige(2, "Waffe gegen %s gezogen" % anzeige_name)


func _schaue_zu(punkt: Vector3) -> void:
	var ziel := Vector3(punkt.x, global_position.y, punkt.z)
	if global_position.distance_to(ziel) > 0.01:
		look_at(ziel, Vector3.UP)


func _material(farbe: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = farbe
	material.roughness = 0.9
	return material
