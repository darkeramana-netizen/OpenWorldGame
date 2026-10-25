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

var aktion_text: String = "Sprechen"


func _ready() -> void:
	add_to_group("interagierbar")
	$Name.text = anzeige_name
	$Mesh.material_override = _material(tracht)
	$Kordel.visible = kordel != Kordel.KEINE
	$Kordel.material_override = _material(KORDELFARBEN[kordel])


func interagieren(spieler: Node3D) -> void:
	_schaue_zu(spieler.global_position)
	if Spielzeit.stille_aktiv:
		Spielstand.stille_gebrochen(anzeige_name)
		return
	Dialog.starte(dialog_id, anzeige_name)


func _schaue_zu(punkt: Vector3) -> void:
	var ziel := Vector3(punkt.x, global_position.y, punkt.z)
	if global_position.distance_to(ziel) > 0.01:
		look_at(ziel, Vector3.UP)


func _material(farbe: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = farbe
	material.roughness = 0.9
	return material
