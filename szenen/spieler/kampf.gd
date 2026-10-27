extends Node
## Kampf der Spielfigur (Bewaffnung 7): Säbel für den Nahkampf, Steinschlossmuskete mit einem Schuss
## und langer Ladezeit, ungeladen das Bajonett. Kampf ist selten und gefährlich.
##   F Waffe ziehen/wegstecken · Q Säbel/Muskete · linke Maus Hieb/Schuss/Stoß · rechte Maus blocken (Säbel)
##   R nachladen. Wer zu Boden geht, wird verwundet geborgen: ein halber Tag vergeht.

signal leben_geaendert(leben: float)
signal zustand_geaendert

const LEBEN_MAX := 100.0
## Erholung pro Sekunde, sobald man einige Sekunden nicht getroffen wurde.
const ERHOLUNG := 4.0
const ERHOLUNG_NACH := 6.0
const NACHLADEZEIT := 8.0
## Art → [Schaden, Reichweite in m, Ausholzeit in s, Pause danach in s]
const ANGRIFFE := {
	"hieb": [34.0, 2.4, 0.25, 0.8],
	"bajonett": [28.0, 2.8, 0.3, 1.0],
}
const SCHUSS_SCHADEN := 90.0
const SCHUSS_WEITE := 80.0
## Ein Block mit dem Säbel fängt drei Viertel eines Hiebs von vorn ab, gegen Kugeln hilft er nicht.
const BLOCK_FAKTOR := 0.25

var leben: float = LEBEN_MAX
var waffe: String = "saebel"
var gezogen: bool = false
var geladen: bool = true
var nachladen_rest: float = 0.0
var blockt: bool = false

var _ausholen: float = 0.0
var _angriff: String = ""
var _pause: float = 0.0
var _seit_treffer: float = 99.0

@onready var _spieler: CharacterBody3D = get_parent()
@onready var _koerper: Node3D = get_parent().get_node("Koerper")
@onready var _saebel: Node3D = get_parent().get_node("Koerper/Saebel")
@onready var _muskete: Node3D = get_parent().get_node("Koerper/Muskete")


func _ready() -> void:
	_zeige_waffe()


func _unhandled_input(event: InputEvent) -> void:
	if Dialog.aktiv or Spielstand.eingabe_gesperrt or get_tree().paused:
		return
	if event.is_action_pressed("waffe_ziehen"):
		gezogen = not gezogen
		_zeige_waffe()
	elif event.is_action_pressed("waffe_wechseln") and _ausholen <= 0.0:
		waffe = "muskete" if waffe == "saebel" else "saebel"
		nachladen_rest = 0.0
		gezogen = true
		_zeige_waffe()
	elif event.is_action_pressed("nachladen"):
		nachladen()
	elif event.is_action_pressed("angreifen"):
		angreifen()


func angreifen() -> void:
	if not gezogen or _ausholen > 0.0 or _pause > 0.0 or nachladen_rest > 0.0:
		return
	if waffe == "muskete" and geladen:
		_schiessen()
	else:
		_angriff = "hieb" if waffe == "saebel" else "bajonett"
		_ausholen = ANGRIFFE[_angriff][2]
		var teil := _saebel if waffe == "saebel" else _muskete
		var tween := create_tween()
		tween.tween_property(teil, "rotation:x", -1.2, _ausholen * 0.6)
		tween.tween_property(teil, "rotation:x", 0.0, 0.25)


func nachladen() -> void:
	if waffe == "muskete" and gezogen and not geladen and nachladen_rest <= 0.0:
		nachladen_rest = NACHLADEZEIT
		Spielstand.meldung.emit("Du lädst nach: Pulver, Kugel, Ladestock. Das dauert.")
		zustand_geaendert.emit()


## Langsamer beim Blocken und Nachladen.
func tempo_faktor() -> float:
	return 0.5 if blockt or nachladen_rest > 0.0 else 1.0


func _physics_process(delta: float) -> void:
	_seit_treffer += delta
	if _seit_treffer > ERHOLUNG_NACH and leben < LEBEN_MAX:
		leben = minf(leben + ERHOLUNG * delta, LEBEN_MAX)
		leben_geaendert.emit(leben)
	_pause = maxf(_pause - delta, 0.0)
	var frei := not Dialog.aktiv and not Spielstand.eingabe_gesperrt
	var blockt_vorher := blockt
	blockt = frei and gezogen and waffe == "saebel" and _ausholen <= 0.0 and Input.is_action_pressed("blocken")
	if blockt != blockt_vorher:
		_saebel.rotation.z = 1.2 if blockt else 0.0
		zustand_geaendert.emit()
	if gezogen:
		# Mit gezogener Waffe blickt die Figur dorthin, wohin die Kamera schaut.
		var blick: float = _spieler.get_node("KameraDrehpunkt").rotation.y
		_koerper.rotation.y = lerp_angle(_koerper.rotation.y, blick, 12.0 * delta)
	if nachladen_rest > 0.0:
		nachladen_rest -= delta
		if nachladen_rest <= 0.0:
			nachladen_rest = 0.0
			geladen = true
			Spielstand.meldung.emit("Die Muskete ist geladen.")
			zustand_geaendert.emit()
	if _ausholen > 0.0:
		_ausholen -= delta
		if _ausholen <= 0.0:
			var werte: Array = ANGRIFFE[_angriff]
			_nahkampf(werte[0], werte[1])
			_pause = werte[3]


## Trifft das nächste Ziel in Reichweite vor der Figur.
func _nahkampf(schaden: float, reichweite: float) -> void:
	var vorn := -_koerper.global_basis.z
	var bestes: Node3D = null
	var beste_distanz := reichweite
	for ziel: Node3D in get_tree().get_nodes_in_group("treffbar"):
		var d := ziel.global_position - _spieler.global_position
		d.y = 0.0
		if d.length() <= beste_distanz and vorn.dot(d.normalized()) > 0.5:
			beste_distanz = d.length()
			bestes = ziel
	if bestes:
		bestes.treffer(schaden, _spieler, _angriff)


func _schiessen() -> void:
	geladen = false
	_pause = 1.0
	var kamera := get_viewport().get_camera_3d()
	var von := kamera.global_position
	var richtung := -kamera.global_basis.z
	var abfrage := PhysicsRayQueryParameters3D.create(von, von + richtung * SCHUSS_WEITE, 1 | 4)
	abfrage.exclude = [_spieler.get_rid()]
	var treffer_info := _spieler.get_world_3d().direct_space_state.intersect_ray(abfrage)
	Spielstand.meldung.emit("Der Schuss kracht. Pulverdampf hängt in der Luft.")
	if treffer_info and treffer_info.collider.has_method("treffer"):
		treffer_info.collider.treffer(SCHUSS_SCHADEN, _spieler, "schuss")
	zustand_geaendert.emit()


## Die Figur wird getroffen. art: "hieb", "bajonett" oder "schuss".
func treffer(schaden: float, quelle: Node3D, art: String) -> void:
	if art != "schuss" and blockt and quelle:
		var zu_quelle := (quelle.global_position - _spieler.global_position).normalized()
		if -_koerper.global_basis.z.dot(zu_quelle) > 0.3:
			schaden *= BLOCK_FAKTOR
	leben -= schaden
	_seit_treffer = 0.0
	leben_geaendert.emit(leben)
	if leben <= 0.0:
		_verwundet()


func _verwundet() -> void:
	leben = LEBEN_MAX
	gezogen = false
	_zeige_waffe()
	leben_geaendert.emit(leben)
	Spielzeit.vorspulen(12.0)
	Spielstand.akte_eintrag("Im Kampf schwer verwundet und von Wächtern geborgen.", "verwundung")
	Spielstand.blende.emit("Du gehst zu Boden. Als du wieder zu dir kommst, hat man dich in Sicherheit gebracht und versorgt. Ein halber Tag ist vergangen.", "zwischen")
	_spieler.zur_heilstube()
	get_tree().call_group("gegner", "zuruecksetzen")


func _zeige_waffe() -> void:
	_saebel.visible = gezogen and waffe == "saebel"
	_muskete.visible = gezogen and waffe == "muskete"
	_saebel.rotation = Vector3.ZERO
	_muskete.rotation = Vector3.ZERO
	zustand_geaendert.emit()


func als_dict() -> Dictionary:
	return {"leben": leben, "waffe": waffe, "geladen": geladen}


func aus_dict(daten: Dictionary) -> void:
	leben = float(daten.get("leben", LEBEN_MAX))
	waffe = daten.get("waffe", "saebel")
	geladen = bool(daten.get("geladen", true))
	_zeige_waffe()
