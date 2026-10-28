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
## Größe als Faktor, z. B. 0.65 für Kinder.
@export var groesse: float = 1.0
## Die Person ist nur da, solange diese Bedingung gilt (Schreibweise wie in den Dialogen).
@export var sichtbar_wenn: String = ""
## Tagesablauf: eine Zeile je Tagesabschnitt, "abschnitt: x,y,z; x,y,z; … | Zusatz | Zusatz".
## Beginnt der Abschnitt, geht die Person die Wegpunkte ab. Zusätze: "weg" (danach ist sie fort, etwa im
## Haus), "runde" (die Wegpunkte immer wieder, etwa eine Streife; "runde=2": erst hingehen, dann ab dem
## dritten Wegpunkt immer wieder), "blick=180" (Blickrichtung am Ziel).
## Abschnitte ohne Zeile ändern nichts. Ist der Spieler weit weg, steht sie gleich am Ziel.
@export var tagesablauf: PackedStringArray = []
## Gehtempo in m/s.
@export var tempo: float = 1.3

## Weiter weg als das sieht der Spieler niemanden gehen: Die Person steht dann gleich am Ziel.
const SICHTWEITE_GEHEN := 45.0
const REIHENFOLGE: Array[String] = ["morgengrauen", "vormittag", "mittag", "nachmittag", "stille_stunde", "nacht"]

var aktion_text: String = "Sprechen"
var _ablauf: Dictionary = {}
var _route: Array[Vector3] = []
var _runde: Array[Vector3] = []
var _ziel_eintrag: Dictionary = {}
var _im_haus: bool = false
var _spricht: bool = false


func _ready() -> void:
	$Name.text = anzeige_name
	var figur = $Figur
	figur.merkmale_aus(anzeige_name)
	figur.tracht = tracht
	figur.rock = kordel != Kordel.KEINE    # Ordensleute tragen den langen Rock der Tracht
	figur.kordel_farbe = KORDELFARBEN[kordel]
	figur.scale *= groesse
	Spielstand.flag_geaendert.connect(func(_f: String) -> void: _pruefe_sichtbarkeit())
	Spielstand.alarm_geaendert.connect(func(_s: int) -> void: _pruefe_sichtbarkeit())
	Spielzeit.abschnitt_gewechselt.connect(func(_a: StringName) -> void:
		_folge_ablauf(false)
		_pruefe_sichtbarkeit())
	_ablauf = lies_ablauf(tagesablauf)
	_folge_ablauf(true)
	_pruefe_sichtbarkeit()


## Zerlegt die Zeilen des Tagesablaufs: Abschnitt → {punkte, weg, runde, blick}.
static func lies_ablauf(zeilen: PackedStringArray) -> Dictionary:
	var ergebnis := {}
	for zeile in zeilen:
		var doppelpunkt := zeile.find(":")
		if doppelpunkt < 0:
			continue
		var teile := zeile.substr(doppelpunkt + 1).split("|")
		var punkte: Array[Vector3] = []
		for p in teile[0].split(";", false):
			var z := p.split(",")
			if z.size() == 3:
				punkte.append(Vector3(z[0].to_float(), z[1].to_float(), z[2].to_float()))
		var eintrag := {"punkte": punkte, "weg": false, "runde": -1, "blick": NAN}
		for zusatz in teile.slice(1):
			zusatz = zusatz.strip_edges()
			if zusatz == "weg":
				eintrag["weg"] = true
			elif zusatz == "runde":
				eintrag["runde"] = 0
			elif zusatz.begins_with("runde="):
				eintrag["runde"] = zusatz.substr(6).to_int()
			elif zusatz.begins_with("blick="):
				eintrag["blick"] = zusatz.substr(6).to_float()
		ergebnis[zeile.substr(0, doppelpunkt).strip_edges()] = eintrag
	return ergebnis


## Was der Tagesablauf für den jetzigen Abschnitt vorsieht. sofort: ohne zu gehen (Szenenstart, Laden).
func _folge_ablauf(sofort: bool) -> void:
	# Es gilt die Zeile des jetzigen Abschnitts oder, wenn es keine gibt, die letzte davor. Wurde diese
	# schon befolgt, ändert sich nichts. Wurde ein Abschnitt übersprungen (Zeitsprung), steht man gleich am Ziel.
	var eintrag: Dictionary = {}
	var i := REIHENFOLGE.find(String(Spielzeit.abschnitt))
	for k in REIHENFOLGE.size():
		eintrag = _ablauf.get(REIHENFOLGE[(i - k + REIHENFOLGE.size()) % REIHENFOLGE.size()], {})
		if not eintrag.is_empty():
			sofort = sofort or k > 0
			break
	if eintrag.is_empty() or eintrag["punkte"].is_empty() or (eintrag == _ziel_eintrag and not sofort):
		return
	if eintrag == _ziel_eintrag and _route.is_empty() and eintrag["runde"] < 0:
		return
	_ziel_eintrag = eintrag
	var punkte: Array[Vector3] = eintrag["punkte"]
	var ab: int = eintrag["runde"]
	_runde.assign(punkte.slice(ab) if ab >= 0 else [])
	var spieler := get_tree().get_first_node_in_group("spieler") as Node3D if is_inside_tree() else null
	var weit := spieler == null or spieler.global_position.distance_to(global_position) > SICHTWEITE_GEHEN
	if _im_haus:
		# Aus dem Haus kommt man an der Tür heraus, also am ersten Wegpunkt.
		global_position = punkte[0]
		_im_haus = false
	if sofort or weit:
		_route.clear()
		global_position = punkte[ab] if ab >= 0 else punkte.back()
		if ab >= 0:
			_route.assign(_runde)
		else:
			_angekommen()
	else:
		_route.assign(punkte)


func _angekommen() -> void:
	if not is_nan(_ziel_eintrag.get("blick", NAN)):
		rotation_degrees.y = _ziel_eintrag["blick"]
	if _ziel_eintrag.get("weg", false):
		_im_haus = true
		_pruefe_sichtbarkeit()


func _physics_process(delta: float) -> void:
	if _route.is_empty() or not visible or (_spricht and Dialog.aktiv):
		return
	var ziel := _route[0]
	var weg := Vector3(ziel.x - global_position.x, 0.0, ziel.z - global_position.z)
	var schritt := tempo * delta
	if weg.length() <= schritt:
		global_position = Vector3(ziel.x, global_position.y, ziel.z)
		_route.pop_front()
		if _route.is_empty():
			if not _runde.is_empty():
				_route.assign(_runde)
			else:
				global_position.y = ziel.y
				_angekommen()
				return
	else:
		global_position += weg.normalized() * schritt
		_schaue_zu(global_position + weg)
	global_position.y = _boden(ziel.y)


## Höhe des Bodens unter der Person (Gelände, Böden, Brücken), sonst die des Ziels.
func _boden(ersatz: float) -> float:
	var von := global_position + Vector3.UP * 1.5
	var abfrage := PhysicsRayQueryParameters3D.create(von, von + Vector3.DOWN * 4.0, 1)
	abfrage.exclude = [get_rid()]
	var treffer := get_world_3d().direct_space_state.intersect_ray(abfrage)
	return treffer.position.y if treffer else ersatz


## Ob die Person gerade unterwegs ist (für Tests und die Anzeige).
func unterwegs() -> bool:
	return not _route.is_empty()


func interagieren(spieler: Node3D) -> void:
	_schaue_zu(spieler.global_position)
	if Spielzeit.stille_aktiv:
		Spielstand.stille_gebrochen(anzeige_name)
		return
	_spricht = true
	Dialog.beendet.connect(func(_d: String) -> void: _spricht = false, CONNECT_ONE_SHOT)
	Dialog.starte(dialog_id, anzeige_name)


func _pruefe_sichtbarkeit() -> void:
	var da := Spielstand.pruefe_bedingung(sichtbar_wenn) and not _im_haus
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
