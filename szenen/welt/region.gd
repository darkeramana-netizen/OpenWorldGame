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


func _enter_tree() -> void:
	# Über den Pfad, weil Klassen mit class_name auch ohne geladene Autoloads übersetzt werden.
	get_node("/root/Speicher").region = region_id


## Die Region, zu der ein Knoten gehört (oder null).
static func von(knoten: Node) -> Region:
	var n := knoten
	while n != null and not n is Region:
		n = n.get_parent()
	return n
