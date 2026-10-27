extends Node3D
## Ein Gespräch zwischen zwei Personen, das man belauschen kann (Spähwesen 3.11).
## Die beiden sprechen ihre Zeilen immer wieder. Wer in Hörweite ist, ohne bemerkt zu werden, sieht sie
## unten im Bild. Wer alle Zeilen am Stück gehört hat, bekommt das Flag "flag_gehoert" und einen Eintrag
## in der Akte. Wer zu nah kommt oder sich ihnen offen von vorn nähert, wird bemerkt: Sie verstummen.
## Schleichen (Strg) macht das Annähern leichter. In der Stille-Stunde wird nicht gesprochen.

@export var sprecher_a: NodePath
@export var sprecher_b: NodePath
## Jede Zeile beginnt mit "a:" oder "b:", je nachdem, wer spricht.
@export var zeilen: PackedStringArray = []
## Das Gespräch findet nur statt, solange diese Bedingung gilt.
@export var bedingung: String = ""
@export var flag_gehoert: String = ""
@export var akte_text: String = ""
@export var hoerweite: float = 7.0
## Sekunden pro Zeile.
@export var takt: float = 3.5

## Näher als das bemerkt einen jeder, von vorn auch weiter weg (schleichend nur auf kurze Entfernung).
const NAH := 2.2
const SICHT_OFFEN := 7.0
const SICHT_SCHLEICHEND := 3.5
const PAUSE_NACH_ENTDECKUNG := 20.0

var _zeile: int = 0
var _uhr: float = 0.0
var _gehoert: int = 0
var _pause: float = 0.0
@onready var _a: Node3D = get_node_or_null(sprecher_a)
@onready var _b: Node3D = get_node_or_null(sprecher_b)


func _ready() -> void:
	_schaue_einander_an()


func _process(delta: float) -> void:
	if _a == null or _b == null or not _a.visible or not _b.visible or Spielzeit.stille_aktiv or Dialog.aktiv:
		return
	if not Spielstand.pruefe_bedingung(bedingung):
		return
	var spieler := get_tree().get_first_node_in_group("spieler") as Node3D
	if spieler == null:
		return
	if _pause > 0.0:
		_pause -= delta
		return
	_schaue_einander_an()   # wer angesprochen wurde, hat sich zum Spieler gedreht
	if _bemerkt(spieler):
		_pause = PAUSE_NACH_ENTDECKUNG
		_zeile = 0
		_uhr = 0.0
		_gehoert = 0
		Spielstand.meldung.emit("%s und %s bemerken dich und verstummen." % [_a.anzeige_name, _b.anzeige_name])
		return
	_uhr -= delta
	if _uhr > 0.0:
		return
	_uhr = takt
	var zeile := zeilen[_zeile]
	var sprecher := _a if zeile.begins_with("a:") else _b
	var in_hoerweite := spieler.global_position.distance_to(sprecher.global_position) <= hoerweite
	if in_hoerweite:
		Spielstand.belauscht.emit("%s: %s" % [sprecher.anzeige_name, zeile.substr(2).strip_edges()])
		_gehoert += 1
	else:
		_gehoert = 0
	_zeile = (_zeile + 1) % zeilen.size()
	if _gehoert >= zeilen.size() and flag_gehoert != "" and not Spielstand.hat_flag(flag_gehoert):
		Spielstand.setze_flag(flag_gehoert)
		Spielstand.akte_eintrag(akte_text, "beobachtung")
		Spielstand.meldung.emit("Das hast du dir gemerkt. Es steht als Beobachtung in deiner Akte.")


func _bemerkt(spieler: Node3D) -> bool:
	var schleicht: bool = spieler.get("schleicht") == true
	for person: Node3D in [_a, _b]:
		var zu := spieler.global_position - person.global_position
		zu.y = 0.0
		var d := zu.length()
		if d < NAH:
			return true
		var vorn := -person.global_basis.z
		var sicht := SICHT_SCHLEICHEND if schleicht else SICHT_OFFEN
		if d < sicht and vorn.dot(zu.normalized()) > 0.3:
			return true
	return false


func _schaue_einander_an() -> void:
	if _a == null or _b == null:
		return
	_a.look_at(Vector3(_b.global_position.x, _a.global_position.y, _b.global_position.z), Vector3.UP)
	_b.look_at(Vector3(_a.global_position.x, _b.global_position.y, _a.global_position.z), Vector3.UP)
