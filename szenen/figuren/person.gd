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
## dritten Wegpunkt immer wieder), "blick=180" (Blickrichtung am Ziel), "haltung=sitzen" (Haltung, siehe unten).
## Ein Wegpunkt kann eine Rast haben: "x,y,z,arbeiten,6" (dort 6 Sekunden in dieser Haltung, etwa Wasser schöpfen).
## Abschnitte ohne Zeile ändern nichts. Ist der Spieler weit weg, steht sie gleich am Ziel.
@export var tagesablauf: PackedStringArray = []
## Gehtempo in m/s.
@export var tempo: float = 1.3
## Haltung im Stand (figur.gd): "" stehen, "reden", "sitzen", "arbeiten", "knien", "fackel", "schwert". Im
## Tagesablauf kann jeder Abschnitt eine eigene setzen ("haltung=fackel").
@export var haltung: String = ""

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
var _halte := {}                   # Wegpunkt (gerundet) → [Haltung, Sekunden]
var _rast := 0.0
var _ausweichen := Vector3.ZERO
var _ausweich_takt := 0.0
var _gespraech_bis := 0.0
var _gespraech_takt := 0.0
var _partner: Node3D = null


func _ready() -> void:
	$Name.text = anzeige_name
	var figur = $Figur
	figur.merkmale_aus(anzeige_name)
	figur.tracht = tracht
	figur.rock = kordel != Kordel.KEINE    # Ordensleute tragen den langen Rock der Tracht
	figur.kordel_farbe = KORDELFARBEN[kordel]
	figur.scale *= groesse
	figur.haltung = haltung
	figur.beruf = beruf_aus(anzeige_name, dialog_id)
	add_to_group("personen")
	_gespraech_takt = randf_range(2.0, 8.0)
	Spielstand.flag_geaendert.connect(func(_f: String) -> void: _pruefe_sichtbarkeit())
	Spielstand.alarm_geaendert.connect(func(_s: int) -> void: _pruefe_sichtbarkeit())
	Spielzeit.abschnitt_gewechselt.connect(func(_a: StringName) -> void:
		_folge_ablauf(false)
		_pruefe_sichtbarkeit())
	_ablauf = lies_ablauf(tagesablauf)
	_folge_ablauf(true)
	_pruefe_sichtbarkeit()


static func _schluessel(v: Vector3) -> Vector2i:
	return Vector2i(roundi(v.x * 10.0), roundi(v.z * 10.0))


## Beruf für Kleidung und Zubehör (figur.gd) aus Name und Gespräch
static func beruf_aus(name_: String, dialog: String) -> String:
	var n := name_.to_lower()
	for e: Array in [["schmied", "schmied"], ["koch", "koch"], ["bäcker", "koch"], ["magd", "magd"], ["zeugwart", "zeugwart"],
			["wache", "wache"], ["wächter", "wache"], ["ritter", "ritter"], ["kaplan", "geistlich"], ["küster", "geistlich"],
			["fischer", "fischer"], ["knecht", "knecht"], ["träger", "knecht"], ["händler", "haendler"], ["töpfer", "haendler"]]:
		if e[0] in n:
			return e[1]
	if dialog == "burggesinde":
		return "magd"
	if dialog == "stadt_kind":
		return "kind"
	return ""


## Zerlegt die Zeilen des Tagesablaufs: Abschnitt → {punkte, weg, runde, blick, halte}.
static func lies_ablauf(zeilen: PackedStringArray) -> Dictionary:
	var ergebnis := {}
	for zeile in zeilen:
		var doppelpunkt := zeile.find(":")
		if doppelpunkt < 0:
			continue
		var teile := zeile.substr(doppelpunkt + 1).split("|")
		var punkte: Array[Vector3] = []
		var halte := {}
		for p in teile[0].split(";", false):
			var z := p.split(",")
			if z.size() >= 3:
				var v := Vector3(z[0].to_float(), z[1].to_float(), z[2].to_float())
				punkte.append(v)
				if z.size() >= 5:
					halte[_schluessel(v)] = [z[3].strip_edges(), z[4].to_float()]
		var eintrag := {"punkte": punkte, "weg": false, "runde": -1, "blick": NAN, "halte": halte}
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
			elif zusatz.begins_with("haltung="):
				eintrag["haltung"] = zusatz.substr(8)
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
	$Figur.haltung = eintrag.get("haltung", haltung)
	_halte = eintrag.get("halte", {})
	_rast = 0.0
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
	if _rast > 0.0:
		_rast -= delta
		if _rast <= 0.0:
			$Figur.haltung = _ziel_eintrag.get("haltung", haltung)
		return
	var ziel := _route[0]
	var weg := Vector3(ziel.x - global_position.x, 0.0, ziel.z - global_position.z)
	var schritt := tempo * delta
	# anderen ausweichen (nicht kurz vor dem Ziel, dort soll man genau ankommen)
	_ausweich_takt -= delta
	if _ausweich_takt <= 0.0:
		_ausweich_takt = 0.2
		_ausweichen = _ausweich_richtung(weg)
	if _ausweichen == Vector3.INF:
		return                          # jemand steht direkt im Weg: kurz warten
	if weg.length() <= schritt:
		global_position = Vector3(ziel.x, global_position.y, ziel.z)
		_route.pop_front()
		var halt: Array = _halte.get(_schluessel(ziel), [])
		if not halt.is_empty():
			_rast = float(halt[1])
			$Figur.haltung = String(halt[0])
		if _route.is_empty():
			if not _runde.is_empty():
				_route.assign(_runde)
			else:
				global_position.y = ziel.y
				_angekommen()
				return
	else:
		var richtung := (weg.normalized() + _ausweichen).normalized() if _ausweichen != Vector3.ZERO and weg.length() > 1.5 else weg.normalized()
		global_position += richtung * schritt
		_schaue_zu(global_position + richtung)
	global_position.y = _boden(ziel.y)


## Wer oder was steht vorn im Weg? Gibt eine seitliche Ausweichrichtung zurück, INF zum Warten (sehr nah), sonst 0.
func _ausweich_richtung(weg: Vector3) -> Vector3:
	if weg.length() < 0.01:
		return Vector3.ZERO
	var vorn := weg.normalized()
	var seitlich := Vector3(-vorn.z, 0, vorn.x)
	var summe := Vector3.ZERO
	var andere: Array = get_tree().get_nodes_in_group("personen") + get_tree().get_nodes_in_group("tiere")
	var sp := get_tree().get_first_node_in_group("spieler")
	if sp:
		andere.append(sp)
	for o: Node3D in andere:
		if o == self or not o.visible:
			continue
		var d := o.global_position - global_position
		d.y = 0.0
		var abstand := d.length()
		if abstand > 1.6 or abstand < 0.001 or absf(o.global_position.y - global_position.y) > 1.5:
			continue
		var vor := vorn.dot(d / abstand)
		if vor < 0.3:
			continue
		if abstand < 0.55 and vor > 0.85:
			return Vector3.INF
		# nach der Seite, auf der der andere nicht steht
		var seite := -signf(seitlich.dot(d)) if absf(seitlich.dot(d)) > 0.05 else 1.0
		summe += seitlich * seite * (1.6 - abstand)
	return summe.limit_length(0.9)


## Kopf zum Spieler drehen, wenn er nahe ist; Wartende reden miteinander.
func _process(delta: float) -> void:
	if not visible:
		return
	var figur = $Figur
	var sp := get_tree().get_first_node_in_group("spieler") as Node3D
	if sp:
		var d := sp.global_position - global_position
		var nah := d.length() < 5.0 and (-global_basis.z).dot(Vector3(d.x, 0, d.z).normalized()) > -0.2
		figur.schaue_auf(sp.global_position + Vector3.UP * 1.55, 1.0 if nah else 0.0, delta)
		if not nah and _partner != null and is_instance_valid(_partner):
			figur.schaue_auf(_partner.global_position + Vector3.UP * 1.55, 0.8, delta)
	# Gespräche zwischen Wartenden ohne feste Arbeit
	var jetzt := Time.get_ticks_msec() / 1000.0
	if _gespraech_bis > 0.0 and jetzt > _gespraech_bis:
		_gespraech_bis = 0.0
		_partner = null
		if figur.haltung == "reden" and haltung == "" and not _ziel_eintrag.has("haltung"):
			figur.haltung = ""
	_gespraech_takt -= delta
	if _gespraech_takt > 0.0:
		return
	_gespraech_takt = randf_range(3.0, 7.0)
	if not _bereit_zum_reden():
		return
	for o in get_tree().get_nodes_in_group("personen"):
		if o == self or not o.visible or not o.has_method("_bereit_zum_reden") or not o._bereit_zum_reden():
			continue
		if (o as Node3D).global_position.distance_to(global_position) < 2.6 and randf() < 0.5:
			var dauer := randf_range(8.0, 20.0)
			_beginne_gespraech(o, jetzt + dauer)
			o._beginne_gespraech(self, jetzt + dauer)
			break


func _bereit_zum_reden() -> bool:
	return visible and _route.is_empty() and _rast <= 0.0 and _gespraech_bis == 0.0 and not _spricht \
		and $Figur.haltung == "" and not _ziel_eintrag.get("weg", false)


func _beginne_gespraech(mit: Node3D, bis: float) -> void:
	_partner = mit
	_gespraech_bis = bis
	_schaue_zu(mit.global_position)
	$Figur.haltung = "reden"


## Höhe des Bodens unter der Person (Gelände, Böden, Brücken), sonst die des Ziels. Andere Personen sind kein
## Boden: Sonst stiege sie jemandem, der im Weg steht, auf den Kopf.
func _boden(ersatz: float) -> float:
	var von := global_position + Vector3.UP * 1.5
	var abfrage := PhysicsRayQueryParameters3D.create(von, von + Vector3.DOWN * 4.0, 1)
	abfrage.exclude = [get_rid()]
	for versuch in 4:
		var treffer := get_world_3d().direct_space_state.intersect_ray(abfrage)
		if not treffer:
			return ersatz
		if not (treffer.collider is CharacterBody3D or treffer.collider.has_method("unterwegs") or treffer.collider.has_meta("tier")):
			return treffer.position.y
		abfrage.exclude += [treffer.rid]
	return ersatz


## Ob die Person gerade unterwegs ist (für Tests und die Anzeige).
func unterwegs() -> bool:
	return not _route.is_empty()


func interagieren(spieler: Node3D) -> void:
	_schaue_zu(spieler.global_position)
	if Spielzeit.stille_aktiv:
		Spielstand.stille_gebrochen(anzeige_name)
		return
	_spricht = true
	var vorher: String = $Figur.haltung
	if vorher in ["", "arbeiten", "knien"]:
		$Figur.haltung = "reden"          # wer angesprochen wird, unterbricht die Arbeit und redet
	var danach := func(_d: String) -> void:
		_spricht = false
		if $Figur.haltung == "reden" and vorher != "reden":
			$Figur.haltung = vorher
	Dialog.beendet.connect(danach, CONNECT_ONE_SHOT)
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
