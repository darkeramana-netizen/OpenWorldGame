extends Node3D
## Ein Bereich unter dem Wasserspiegel der Region, in dem die Spielfigur nicht zurückgesetzt wird,
## z. B. eine Kapelle oder ein Tunnel unter der Erde. Quader mit der Mitte an diesem Knoten.

@export var groesse: Vector3 = Vector3(10, 10, 10)


func _ready() -> void:
	add_to_group("wasserdicht")


func enthaelt(punkt: Vector3) -> bool:
	var rel := to_local(punkt)
	return absf(rel.x) <= groesse.x / 2.0 and absf(rel.y) <= groesse.y / 2.0 and absf(rel.z) <= groesse.z / 2.0
