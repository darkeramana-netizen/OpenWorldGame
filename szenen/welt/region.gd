class_name Region
extends Node3D
## Wurzel einer Region (Drachenstein, Riverlock, ...): Wasser, Rand und Lage auf der Karte.
## Die Spielfigur und die Karte (M) lesen ihre Werte von hier.

## Kennung für Spielstände, Reisen und Bedingungen in Dialogen ("region=riverlock").
@export var region_id: String = "drachenstein"
## Wer tiefer als einen Meter unter diese Höhe gerät, wird zurückgesetzt.
@export var wasserspiegel: float = -20.0
@export var wasser_meldung: String = "Das Wächtermeer ist zu kalt zum Schwimmen."
## Rechteck (x, z), in dem man sich bewegen darf.
@export var grenze_min: Vector2 = Vector2(-880, -630)
@export var grenze_max: Vector2 = Vector2(430, 330)
@export var grenze_meldung: String = "Hier endet die Region. Dahinter liegt nur Fels."
## Bildpunkt auf der Sorrowland-Karte, der dem Ursprung der Region entspricht.
@export var karte_ursprung: Vector2 = Vector2(272, 491)
@export var karte_meter_pro_pixel: float = 5.0
## Für Landstraßen: Die Straße läuft auf der Karte als Bogen von karte_ursprung über karte_mitte
## nach karte_ende, über die Länge karte_strecke (entlang x oder, mit karte_entlang_z, entlang z).
@export var karte_mitte: Vector2 = Vector2.ZERO
@export var karte_ende: Vector2 = Vector2.ZERO
@export var karte_strecke: float = 0.0
@export var karte_entlang_z: bool = false


func _enter_tree() -> void:
	# Über den Pfad, weil Klassen mit class_name auch ohne geladene Autoloads übersetzt werden.
	get_node("/root/Speicher").region = region_id


## Bildpunkt auf der Sorrowland-Karte für eine Weltposition in dieser Region.
func karten_pixel(p: Vector3) -> Vector2:
	if karte_strecke > 0.0:
		var t := clampf((p.z if karte_entlang_z else p.x) / karte_strecke, 0.0, 1.0)
		return karte_ursprung.lerp(karte_mitte, t).lerp(karte_mitte.lerp(karte_ende, t), t)
	return karte_ursprung + Vector2(p.x, p.z) / karte_meter_pro_pixel


## Die Region, zu der ein Knoten gehört (oder null).
static func von(knoten: Node) -> Region:
	var n := knoten
	while n != null and not n is Region:
		n = n.get_parent()
	return n
