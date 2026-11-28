@tool
extends "res://szenen/welt/burgbau.gd"
## Der Untergrund einer Burg (Drachenstein, 27.11.2026): Gewölberäume, Gänge mit Treppen und die Abgänge, die von
## oben hinunterführen. Baut mit denselben Mitteln wie burgbau.gd (triplanare Steine, Baucache, Kollision), aber mit
## eigenen Bauteilen. Alle Koordinaten sind die dieses Knotens; die Bauskripte stellen ihn in den Weltursprung.
##
## Räume (gewoelbe), je 11 Werte: x, z (Mitte), Gier (Grad; lokal z ist die Länge, lokal x die Breite wie bei T() in
## den Bauskripten), Länge, Breite, Boden, Wandhöhe bis zum Kämpfer, Stich des Gewölbes, Art, Joch, Zier.
##   Art 0 Halle mit Kreuzgewölben auf Pfeilern (Krypta, Beinhaus), 1 Keller mit Tonnengewölbe und Gurtbögen,
##   2 Zisterne (Kreuzgewölbe, Laufsteg an den Wänden, Becken mit Wasser, Stufen hinein), 3 Ruine (älteres
##   Mauerwerk, eingestürzte Joche mit Schutt, geborstene Pfeiler), 5 Wendeltreppe (Länge = Durchmesser innen,
##   Gier = Richtung des unteren Eingangs, Wandhöhe = Höhe der Treppe; der obere Ausgang liegt bei wendel_oben()),
##   4 Höhle (natürlich: unregelmäßige Felswand auf einer Ellipse, Kuppel, Gänge aus jeder Richtung),
##   6 Rundkammer mit Kuppel und Rippen (Länge = Durchmesser; Gänge dürfen aus jeder Richtung kommen: Knotenpunkt).
##   Joch: Seitenlänge eines Gewölbefelds (Kreuzgewölbe) bzw. Abstand der Gurtbögen (Tonne).
##   Zier (Bits): 1 Grabnischen in den Längswänden, 2 Fackeln, 4 Lagernischen, 8 dunkel (nur ein schwaches, kaltes
##   Licht), 16 Brandspuren, 32 spiegelnd (Reflexionen werden gerendert, z. B. über dem Wasser der Zisterne).
## Gänge (gaenge), je 10 Werte: x1, y1, z1, x2, y2, z2 (Boden an den Enden), Breite, Scheitelhöhe, Art (0 gemauert
##   mit Rundbogen, 1 roh in den Fels gehauen, 2 alt und verfallen, 3 gemauert mit flacher Steindecke), Fackeln (0/1). Bei Höhenunterschied Treppen mit
##   je einem ebenen Absatz an den Enden. Endet ein Gang an der Innenseite einer Raumwand, bekommt die Wand dort eine
##   Öffnung mit Rundbogen; endet er nirgends, schließt ihn eine Wand.
## Abgänge (abgaenge), je 7 Werte: x, z (Mitte der Schwelle), Gier (hinein), Boden (Gelände), Breite und Länge innen,
##   Art (0 Steinhäuschen mit Satteldach). Die Treppe darin ist ein Gang, der an der Schwelle beginnt; das Häuschen
##   ist nur die Hülle darüber mit Tür (Regel aus abgang_regeln, fluegel.gd). Das Gelände braucht dort ein Loch.

@export var gewoelbe := PackedFloat32Array():
	set(w):
		gewoelbe = w
		_neu_bauen()
@export var gaenge := PackedFloat32Array():
	set(w):
		gaenge = w
		_neu_bauen()
@export var abgaenge := PackedFloat32Array():
	set(w):
		abgaenge = w
		_neu_bauen()
## Schächte (z. B. vom Ziehbrunnen in die Zisterne): je 5 Werte x, z, Radius, unten, oben. Das Gewölbe bekommt
## dort ein Loch, der Schacht eine runde Wand, ein Seil mit Eimer hängt herab, von oben fällt etwas Tageslicht.
@export var schaechte := PackedFloat32Array():
	set(w):
		schaechte = w
		_neu_bauen()
## Felsmünder: Meereshöhlen an der Klippe, durch die ein Gang hineinführt. Je 8 Werte x, z (Fuß der Öffnung am Wasser),
## Gier nach draußen, Boden, Breite, Höhe, Steigung der Klippe, Tiefe (so weit landeinwärts wird die Klippe nachgebaut).
## Das Gelände ist dort ausgeschnitten (gelaende.gd, schnitte); die Klippe wird hier genau auf den Dreiecken des Geländes
## nachgebaut, nur mit der Öffnung darin, dazu Felsrand, Podest und Stufen wie bei den Meereshöhlen (burgbau.gd).
@export var felsmuender := PackedFloat32Array():
	set(w):
		felsmuender = w
		_neu_bauen()
## Je Abgang die Regel der Tür (fluegel.gd: "tuer", "schloss", "riegel", "offen"; nach einem Doppelpunkt die Bedingung)
@export var abgang_regeln := PackedStringArray()

const WAND_T := 0.8              # Mauerstärke der Räume
const SCHICHT := 0.5             # innere Schicht der Wand (darin die Nischen)
const STUFE := 0.19              # Richtwert für die Stufenhöhe
const W_JE_RUNDE := 18           # Stufen je Umdrehung der Wendeltreppe
const W_SPINDEL := 0.32
const W_ANTRITT := 30.0          # Grad vom unteren Eingang bis zur ersten Stufe
const W_AUSTRITT := 40.0         # Grad von der letzten Stufe bis zur Mitte des oberen Ausgangs
const LICHT_WARM := Color(1.0, 0.64, 0.34)
const LICHT_KALT := Color(0.55, 0.62, 0.75)
const UMGEBUNG := Color(0.045, 0.04, 0.036)
const EIGENE_FARBEN := {"knochen": Color(0.72, 0.68, 0.56), "russ": Color(0.045, 0.04, 0.036),
	"verkohlt": Color(0.08, 0.065, 0.055), "seil": Color(0.48, 0.4, 0.28)}

var _flackern: Array[OmniLight3D] = []
var _grund_energie: Array[float] = []
var _zeit := 0.0
var _bereiche: Array = []        # [Transform3D (Welt → lokal), halbe Größe] je Raum und Gang
var _oeffnungen := {}            # Raum → Liste der Öffnungen [Seite, Lage, Boden, Breite, Höhe]


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	add_to_group("unterwelt")
	_bereiche_berechnen()
	if OS.get_environment("UNTERWELT_OHNE_SONDEN") != "":      # zum Vergleich (Messung, Fehlersuche)
		for sonde in find_children("*", "ReflectionProbe", true, false):
			sonde.free()
	if OS.get_environment("UNTERWELT_OHNE_LICHT") != "":
		for l in find_children("*", "OmniLight3D", true, false):
			l.free()
	for l in find_children("*", "OmniLight3D", true, false):
		if l.has_meta("flackern"):
			_flackern.append(l as OmniLight3D)
			_grund_energie.append((l as OmniLight3D).light_energy)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _flackern.is_empty():
		return
	var kamera := get_viewport().get_camera_3d()
	if kamera == null or not ist_unter_tage(kamera.global_position, 30.0):
		return
	_zeit += delta
	for i in _flackern.size():
		var l := _flackern[i]
		var ph := float(i) * 1.7
		var f := 0.86 + 0.08 * sin(_zeit * 7.3 + ph) + 0.05 * sin(_zeit * 13.1 + ph * 2.3) + 0.03 * sin(_zeit * 23.7 + ph)
		l.light_energy = _grund_energie[i] * f


## Liegt p unter Tage (in einem Raum oder Gang dieses Knotens, mit rand Metern Zugabe)?
func ist_unter_tage(p: Vector3, rand := 0.0) -> bool:
	for b: Array in _bereiche:
		var q: Vector3 = (b[0] as Transform3D) * p
		var h: Vector3 = b[1]
		if absf(q.x) <= h.x + rand and absf(q.y) <= h.y + rand and absf(q.z) <= h.z + rand:
			return true
	return false


func _bereiche_berechnen() -> void:
	_bereiche.clear()
	var i := 0
	while i + 10 < gewoelbe.size():
		var g := deg_to_rad(gewoelbe[i + 2])
		var hoehe := gewoelbe[i + 6] + gewoelbe[i + 7]
		var basis := Basis(Vector3(cos(g), 0, -sin(g)), Vector3.UP, Vector3(sin(g), 0, cos(g)))
		var mitte := global_transform * Vector3(gewoelbe[i], gewoelbe[i + 5] + hoehe / 2.0, gewoelbe[i + 1])
		var halb := Vector3(gewoelbe[i + 4] / 2.0, hoehe / 2.0 + 0.5, gewoelbe[i + 3] / 2.0)
		if int(gewoelbe[i + 8]) == 5:
			halb = Vector3(gewoelbe[i + 3] / 2.0, hoehe / 2.0 + 2.0, gewoelbe[i + 3] / 2.0)
			mitte.y = gewoelbe[i + 5] + gewoelbe[i + 6] / 2.0
		elif int(gewoelbe[i + 8]) == 4:
			halb = Vector3(gewoelbe[i + 4] / 2.0 + 0.5, hoehe / 2.0 + 0.8, gewoelbe[i + 3] / 2.0 + 0.5)
		elif int(gewoelbe[i + 8]) == 6:
			halb = Vector3(gewoelbe[i + 3] / 2.0, hoehe / 2.0 + 0.5, gewoelbe[i + 3] / 2.0)
		_bereiche.append([Transform3D(global_basis * basis, mitte).affine_inverse(), halb])
		i += 11
	i = 0
	while i + 9 < gaenge.size():
		var a := Vector3(gaenge[i], gaenge[i + 1], gaenge[i + 2])
		var b := Vector3(gaenge[i + 3], gaenge[i + 4], gaenge[i + 5])
		var d := Vector2(b.x - a.x, b.z - a.z)
		var laenge := d.length()
		if laenge < 0.01:
			i += 10
			continue
		var w := atan2(d.x, d.y)
		var basis := Basis(Vector3(cos(w), 0, -sin(w)), Vector3.UP, Vector3(sin(w), 0, cos(w)))
		var mitte := global_transform * ((a + b) / 2.0 + Vector3.UP * gaenge[i + 7] / 2.0)
		var halb := Vector3(gaenge[i + 6] / 2.0, absf(b.y - a.y) / 2.0 + gaenge[i + 7] / 2.0, laenge / 2.0)
		_bereiche.append([Transform3D(global_basis * basis, mitte).affine_inverse(), halb])
		i += 10


## Gier (Grad) des oberen Ausgangs einer Wendeltreppe: Eingang unten bei gier, Höhe hoehe (wie in den Bauskripten)
static func wendel_oben(gier: float, hoehe: float) -> float:
	var stufen := maxi(1, int(round(hoehe / 0.2)))
	return gier + W_ANTRITT + (stufen - 1) * 360.0 / W_JE_RUNDE + W_AUSTRITT


# ---------- Ablauf ----------

func _sammle_nachbarn() -> void:
	# Der Untergrund richtet sich nach keinem Nachbarn (und darf die Liste der Burgbauten nicht belegen)
	_nachbarn_mauern = []
	_hohle = []
	_hohle_eckig = []
	_schalen = []
	_koerper = []
	_nachbarn_bauten = []
	_riegel = []


func _fertige(flach: Dictionary, rund: Dictionary, ziel: Node3D) -> void:
	super._fertige(flach, rund, ziel)
	# Die Flächen zeigen nach innen; die Hülle muss von beiden Seiten Schatten werfen, sonst scheint die Sonne herein
	for k in ziel.get_children():
		if String(k.name).ends_with("_Schatten"):
			(k as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		# nicht in die globale Beleuchtung (SDFGI): Die Räume liegen knapp unter dem dünnen Geländeboden und dunkelten
		# darüber den Hof in Rechtecken ab (Rückmeldung 27.11.2026); unten leuchten die Fackeln
		if k is GeometryInstance3D:
			(k as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED


func _material(name_: String) -> Material:
	# die nachgebaute Klippe am Felsmund trägt das Material des Geländes (gleiche Felsen, gleiche Farben)
	if name_ == "gelaende":
		var gel := get_parent().get_node_or_null("Gelaende") if get_parent() != null else null
		if gel != null and gel.get("material") is Material:
			return gel.get("material")
		return super._material("fels")
	if EIGENE_FARBEN.has(name_) and not _materialien.has(name_):
		var m := StandardMaterial3D.new()
		m.albedo_color = EIGENE_FARBEN[name_]
		m.roughness = 0.95
		m.resource_name = name_
		_materialien[name_] = m
	return super._material(name_)


func _baue_zusatz() -> void:
	_oeffnungen = _oeffnungen_suchen()
	var m := 0
	while m + 7 < felsmuender.size():
		_setze_zelle(Vector2(felsmuender[m], felsmuender[m + 1]))
		_felsmund(felsmuender.slice(m, m + 8))
		m += 8
	var j := 0
	while j + 4 < schaechte.size():
		_setze_zelle(Vector2(schaechte[j], schaechte[j + 1]))
		_schacht(schaechte.slice(j, j + 5))
		j += 5
	var i := 0
	while i + 10 < gewoelbe.size():
		_setze_zelle(Vector2(gewoelbe[i], gewoelbe[i + 1]))
		var art := int(gewoelbe[i + 8])
		var w := gewoelbe.slice(i, i + 11)
		var oeff: Array = _oeffnungen.get(i / 11, [])
		if art == 5:
			_wendeltreppe(w, oeff)
		elif art == 6:
			_rundkammer(w, oeff)
		elif art == 4:
			_hoehlenraum(w, oeff)
		else:
			_raum_unter(w, oeff)
		i += 11
	i = 0
	while i + 9 < gaenge.size():
		_setze_zelle(Vector2(gaenge[i], gaenge[i + 2]))
		_gang(gaenge.slice(i, i + 10), i / 10)
		i += 10
	i = 0
	while i + 6 < abgaenge.size():
		_setze_zelle(Vector2(abgaenge[i], abgaenge[i + 1]))
		_abgang(abgaenge.slice(i, i + 7), abgang_regeln[i / 7] if i / 7 < abgang_regeln.size() else "tuer")
		i += 7


## Achsen eines Raums: u entlang der Länge (lokal z), n quer (lokal x)
static func _achsen(gier_grad: float) -> Array[Vector2]:
	var g := deg_to_rad(gier_grad)
	return [Vector2(sin(g), cos(g)), Vector2(cos(g), -sin(g))]


## Wo die Gänge auf Raumwände treffen: Raum → [[Seite ("+u", "-u", "+n", "-n", "rund"), Lage entlang der Wand
## (bei "rund" der Winkel), Boden, Breite, Höhe]]
func _oeffnungen_suchen() -> Dictionary:
	var aus := {}
	var enden: Array = []       # [Punkt, Breite, Höhe]
	var i := 0
	while i + 9 < gaenge.size():
		enden.append([Vector3(gaenge[i], gaenge[i + 1], gaenge[i + 2]), gaenge[i + 6], gaenge[i + 7], int(gaenge[i + 8])])
		enden.append([Vector3(gaenge[i + 3], gaenge[i + 4], gaenge[i + 5]), gaenge[i + 6], gaenge[i + 7], int(gaenge[i + 8])])
		i += 10
	var r := 0
	while r * 11 + 10 < gewoelbe.size():
		var w := gewoelbe.slice(r * 11, r * 11 + 11)
		var c := Vector2(w[0], w[1])
		var ach := _achsen(w[2])
		var hl := w[3] / 2.0
		var hb := w[4] / 2.0
		var liste: Array = []
		for e: Array in enden:
			var p: Vector3 = e[0]
			var d := Vector2(p.x, p.z) - c
			if int(w[8]) in [5, 6]:
				if d.length() < hl + 0.6 and p.y > w[5] - 0.5 and p.y < w[5] + w[6] + 0.5:
					liste.append(["rund", atan2(d.x, d.y), p.y, e[1], e[2], e[3]])
				continue
			if int(w[8]) == 4:
				var eu := d.dot(ach[0]) / hl
				var en := d.dot(ach[1]) / hb
				if eu * eu + en * en < 1.35 and p.y > w[5] - 1.0 and p.y < w[5] + w[6] + 0.5:
					liste.append(["rund", atan2(d.x, d.y), p.y, e[1], e[2], e[3]])
				continue
			var lu := d.dot(ach[0])
			var ln := d.dot(ach[1])
			if absf(lu - hl) < 0.45 and absf(ln) < hb:
				liste.append(["+u", ln, p.y, e[1], e[2], e[3]])
			elif absf(lu + hl) < 0.45 and absf(ln) < hb:
				liste.append(["-u", ln, p.y, e[1], e[2], e[3]])
			elif absf(ln - hb) < 0.45 and absf(lu) < hl:
				liste.append(["+n", lu, p.y, e[1], e[2], e[3]])
			elif absf(ln + hb) < 0.45 and absf(lu) < hl:
				liste.append(["-n", lu, p.y, e[1], e[2], e[3]])
		if not liste.is_empty():
			aus[r] = liste
		r += 1
	return aus


## Ob ein Gangende an einem Raum, einem anderen Gang oder einer Schwelle liegt (sonst wird es zugemauert)
func _ende_offen(p: Vector3, eigener: int) -> bool:
	var fm := 0
	while fm + 7 < felsmuender.size():
		var g := deg_to_rad(felsmuender[fm + 2])
		var mund := Vector2(felsmuender[fm], felsmuender[fm + 1]) + Vector2(sin(g), cos(g))
		if mund.distance_to(Vector2(p.x, p.z)) < 1.5:
			return true
		fm += 8
	var i := 0
	while i + 9 < gaenge.size():
		if i / 10 != eigener:
			for k: int in [0, 3]:
				if Vector3(gaenge[i + k], gaenge[i + k + 1], gaenge[i + k + 2]).distance_to(p) < 0.4:
					return true
		i += 10
	i = 0
	while i + 6 < abgaenge.size():
		if Vector2(abgaenge[i], abgaenge[i + 1]).distance_to(Vector2(p.x, p.z)) < 0.4 and absf(abgaenge[i + 3] - p.y) < 0.5:
			return true
		i += 7
	var r := 0
	while r * 11 + 10 < gewoelbe.size():
		var w := gewoelbe.slice(r * 11, r * 11 + 11)
		var d := Vector2(p.x, p.z) - Vector2(w[0], w[1])
		var ach := _achsen(w[2])
		var halb := Vector2(w[3] / 2.0 + 0.45, w[4] / 2.0 + 0.45) if not int(w[8]) in [5, 6] else Vector2(w[3] / 2.0 + 0.6, w[3] / 2.0 + 0.6)
		if int(w[8]) == 4:
			halb = Vector2(w[3] / 2.0 + 0.8, w[4] / 2.0 + 0.8)
		if absf(d.dot(ach[0])) <= halb.x and absf(d.dot(ach[1])) <= halb.y and p.y > w[5] - 0.5 and p.y < w[5] + w[6] + w[7] + 0.5:
			return true
		r += 1
	return false


# ---------- Grundformen mit eigenen Normalen ----------

func _dreieck_n(mat: String, a: Vector3, na: Vector3, b: Vector3, nb: Vector3, c: Vector3, nc: Vector3) -> void:
	var st := _st(mat, true)
	var ecken: Array[Vector3] = [a, b, c]
	var normalen: Array[Vector3] = [na, nb, nc]
	var reihe: Array[int] = [0, 1, 2]
	if (b - a).cross(c - a).dot(na + nb + nc) > 0.0:
		reihe = [0, 2, 1]
	for j in reihe:
		st.set_normal(normalen[j])
		st.add_vertex(ecken[j])


func _viereck_n(mat: String, a: Vector3, na: Vector3, b: Vector3, nb: Vector3, c: Vector3, nc: Vector3, d: Vector3, nd: Vector3) -> void:
	_dreieck_n(mat, a, na, b, nb, c, nc)
	_dreieck_n(mat, a, na, c, nc, d, nd)


## Band entlang einer Kurve (Rippe, Gurtbogen): punkte mit der Richtung ins Rauminnere (innen); Breite quer, Tiefe
## zum Raum hin. Zwei Seiten und die Unterseite.
func _band(mat: String, punkte: Array[Vector3], innen: Array[Vector3], breite: float, tiefe: float) -> void:
	for k in punkte.size() - 1:
		var t := (punkte[k + 1] - punkte[k]).normalized()
		var s0 := t.cross(innen[k]).normalized() * breite * 0.5
		var s1 := t.cross(innen[k + 1]).normalized() * breite * 0.5
		var a0 := punkte[k] - innen[k] * 0.03
		var a1 := punkte[k + 1] - innen[k + 1] * 0.03
		var b0 := punkte[k] + innen[k] * tiefe
		var b1 := punkte[k + 1] + innen[k + 1] * tiefe
		_viereck(mat, b0 + s0, b1 + s1, b1 - s1, b0 - s0, innen[k])
		_viereck(mat, a0 + s0, a1 + s1, b1 + s1, b0 + s0, s0)
		_viereck(mat, a0 - s0, a1 - s1, b1 - s1, b0 - s0, -s0)


## Punkt im Rahmen eines Raums
static func _p(c: Vector2, u: Vector2, n: Vector2, su: float, sn: float, y: float) -> Vector3:
	var q := c + u * su + n * sn
	return Vector3(q.x, y, q.y)


## Haufen aus Schutt oder Fels: unregelmäßiger Kegel (Mitte m auf dem Boden), dazu ein paar Brocken
func _haufen(mat: String, m: Vector3, r: float, h: float, saat: float) -> void:
	var teile := 10
	var ringe: Array = []
	for j in 4:
		var f := float(j) / 3.0                 # 0 unten, 1 Spitze
		var ring: Array[Vector3] = []
		for k in teile:
			var w := TAU * k / teile + saat
			var z := _h01(Vector2(m.x + k * 3.1 + j, m.z + saat * 7.0))
			var rr := r * (1.0 - f) * (0.75 + 0.5 * z) + 0.05
			ring.append(Vector3(m.x + cos(w) * rr, m.y + h * pow(f, 0.8) * (0.85 + 0.3 * z) - (0.15 if j == 0 else 0.0), m.z + sin(w) * rr))
		ringe.append(ring)
	for j in 3:
		var a: Array[Vector3] = ringe[j]
		var b: Array[Vector3] = ringe[j + 1]
		for k in teile:
			var k1 := (k + 1) % teile
			var aussen := ((a[k] + a[k1]) / 2.0 - Vector3(m.x, a[k].y, m.z)).normalized() + Vector3.UP * 0.6
			_viereck(mat, a[k], a[k1], b[k1], b[k], aussen)
	var spitze := m + Vector3.UP * h
	var oben: Array[Vector3] = ringe[3]
	for k in teile:
		_dreieck(mat, oben[k], oben[(k + 1) % teile], spitze, Vector3.UP)
	# Brocken ringsum
	for k in 5:
		var z := _h01(Vector2(m.x * 1.3 + k * 5.7, m.z - saat - k))
		var w := TAU * z + k
		var q := Vector2(m.x, m.z) + Vector2(cos(w), sin(w)) * r * (0.9 + 0.4 * z)
		var g := Vector2(cos(w * 3.0), sin(w * 3.0))
		var s := 0.18 + 0.25 * z
		_klotz(mat, q, g, Vector2(-g.y, g.x), -s, s, -s * 0.8, s * 0.8, m.y - 0.1, m.y + s * 1.1, false)


# ---------- Räume ----------

func _raum_unter(w: PackedFloat32Array, oeff: Array) -> void:
	var c := Vector2(w[0], w[1])
	var ach := _achsen(w[2])
	var u := ach[0]
	var n := ach[1]
	var L := w[3]
	var B := w[4]
	var hl := L / 2.0
	var hb := B / 2.0
	var boden := w[5]
	var kaempfer := boden + w[6]
	var stich := w[7]
	var art := int(w[8])
	var joch := maxf(w[9], 1.5)
	var zier := int(w[10])
	var scheitel := kaempfer + stich
	var mat_wand := "bruchstein"
	var mat_gew := "mauer"
	var mat_zier := "hell"
	var mat_boden := "boden"
	match art:
		1:
			mat_gew = "bruchstein"
			mat_zier = "mauer"
		2:
			mat_wand = "kai"
			mat_zier = "kai"
		3:
			mat_wand = "basalt"
			mat_gew = "basalt"
			mat_zier = "bruchstein"
			mat_boden = "erde"
	# Felder des Gewölbes
	var nu := maxi(1, int(round(L / joch)))
	var nb := 1 if art == 1 else maxi(1, int(round(B / joch)))
	var su := L / nu
	var sb := B / nb
	var nischen := _nischen(zier, nu, su, nb, sb, hl, hb, boden, kaempfer, oeff)
	# Wände mit Türöffnungen (Rundbogen) und Nischen
	_waende(mat_wand, c, u, n, hl, hb, boden - 0.4, scheitel + 0.5, oeff, nischen)
	for o: Array in oeff:
		_bogenzwickel(mat_wand, c, u, n, hl, hb, o)
	_nischen_ausstatten(c, u, n, hl, hb, nischen, zier)
	# Boden
	if art == 2:
		_zisterne_boden(c, u, n, hl, hb, boden, oeff)
	else:
		_klotz(mat_boden, c, u, n, -hl, hl, -hb, hb, boden - 0.4, boden)
	var pfeiler_fuss := boden - 1.6 if art == 2 else boden
	# Gewölbe
	if art == 1:
		_tonne(mat_gew, mat_zier, c, u, n, hl, hb, kaempfer, stich, nu, su, boden)
	else:
		for i in nu:
			for j in nb:
				var bu := -hl + (i + 0.5) * su
				var bn := -hb + (j + 0.5) * sb
				var weg := art == 3 and _h01(c + u * bu * 1.7 + n * bn * 2.3) < 0.3 and (i + j) % 2 == 1
				_kreuzjoch(mat_gew, c, u, n, bu, bn, su / 2.0, sb / 2.0, kaempfer, stich, weg)
				if weg:
					# eingestürzt: Fels darüber, Schutt darunter
					var rand_ := Vector2(su, sb) * 0.55
					_klotz("fels", c, u, n, bu - rand_.x, bu + rand_.x, bn - rand_.y, bn + rand_.y, scheitel + 0.8, scheitel + 2.2, true)
					_haufen("bruchstein", _p(c, u, n, bu, bn, pfeiler_fuss), minf(su, sb) * 0.45, stich * 0.9 + 0.4, float(i * 3 + j))
		_rippen(mat_zier, c, u, n, hl, hb, nu, nb, su, sb, kaempfer, stich, art == 3)
		# Pfeiler
		for i in range(1, nu):
			for j in range(1, nb):
				var pu := -hl + i * su
				var pn := -hb + j * sb
				var hoch := kaempfer
				if art == 3 and _h01(c + u * pu * 0.9 + n * pn * 1.1) < 0.35:
					hoch = pfeiler_fuss + 0.8 + 1.6 * _h01(c + u * pn + n * pu)
					# herabgefallene Trommel daneben
					var g := Vector2(cos(pu * 3.0 + pn), sin(pu * 3.0 + pn))
					_klotz(mat_zier, c + u * (pu + 1.1) + n * pn, g, Vector2(-g.y, g.x), -0.5, 0.5, -0.3, 0.3, pfeiler_fuss, pfeiler_fuss + 0.6, false)
				_pfeiler(mat_zier, _p(c, u, n, pu, pn, 0.0), u, n, pfeiler_fuss, hoch, kaempfer, minf(su, sb))
		# Wandvorlagen an den Feldgrenzen
		for i in range(0, nu + 1):
			for s: float in [-1.0, 1.0]:
				_vorlage(mat_zier, c, u, n, -hl + i * su, s * hb, -s, boden, kaempfer, oeff, "+n" if s > 0 else "-n")
		for j in range(1, nb):
			for s: float in [-1.0, 1.0]:
				_vorlage(mat_zier, c, n, u, -hb + j * sb, s * hl, -s, boden, kaempfer, oeff, "+u" if s > 0 else "-u")
	# Kämpfergesims an den Längswänden
	if art != 3:
		for s: float in [-1.0, 1.0]:
			_klotz(mat_zier, c, u, n, -hl, hl, s * hb - 0.12 * s if s > 0 else -hb, hb if s > 0 else -hb + 0.12, kaempfer - 0.18, kaempfer, true)
	if zier & 16:
		_brandspuren(c, u, n, hl, hb, boden, kaempfer, oeff)
	_lichter_raum(c, u, n, hl, hb, nu, su, boden, kaempfer, zier, oeff, art)
	_sonde(Vector3(c.x, (boden + scheitel) / 2.0 - (0.8 if art == 2 else 0.0), c.y), u, Vector3(B + 1.0, scheitel - boden + 2.5, L + 1.0), zier & 32 != 0)


## Wände eines Raums: je Seite eine innere Schicht (mit Nischen und Türen) und eine äußere (nur Türen)
func _waende(mat: String, c: Vector2, u: Vector2, n: Vector2, hl: float, hb: float, y0: float, y1: float, oeff: Array,
		nischen: Dictionary) -> void:
	var t := WAND_T
	for seite: String in ["+u", "-u", "+n", "-n"]:
		var tueren: Array = []
		for o: Array in oeff:
			if o[0] == seite:
				var b: float = o[3]
				tueren.append(Rect2(float(o[1]) - b / 2.0 - 0.02, float(o[2]) - 0.45, b + 0.04, float(o[4]) + 0.47))
		var innen: Array = tueren + nischen.get(seite, [])
		var s := 1.0 if seite.begins_with("+") else -1.0
		if seite.ends_with("u"):
			var d0 := hl
			_klotz_mit_loechern(mat, c, n, u, -hb - t, hb + t, minf(s * d0, s * (d0 + SCHICHT)), maxf(s * d0, s * (d0 + SCHICHT)), y0, y1, innen)
			_klotz_mit_loechern(mat, c, n, u, -hb - t, hb + t, minf(s * (d0 + SCHICHT), s * (d0 + t)), maxf(s * (d0 + SCHICHT), s * (d0 + t)), y0, y1, tueren)
		else:
			var d0 := hb
			_klotz_mit_loechern(mat, c, u, n, -hl, hl, minf(s * d0, s * (d0 + SCHICHT)), maxf(s * d0, s * (d0 + SCHICHT)), y0, y1, innen)
			_klotz_mit_loechern(mat, c, u, n, -hl, hl, minf(s * (d0 + SCHICHT), s * (d0 + t)), maxf(s * (d0 + SCHICHT), s * (d0 + t)), y0, y1, tueren)
	# Deckel über dem Ganzen (Schatten, und damit man von oben nicht hineinsieht)
	_klotz(mat, c, u, n, -hl - t, hl + t, -hb - t, hb + t, y1, y1 + 0.4, true)


## Zwickel über einer Türöffnung: zwischen dem Rundbogen und der Oberkante der rechteckigen Öffnung, an der
## Innenseite der Wand, dazu ein Bogen aus hellem Stein
func _bogenzwickel(mat: String, c: Vector2, u: Vector2, n: Vector2, hl: float, hb: float, o: Array) -> void:
	var seite: String = o[0]
	if seite == "rund" or int(o[5]) == 3:
		return
	var lage: float = o[1]
	var y: float = o[2]
	var hb_t: float = float(o[3]) / 2.0
	var kaempfer := y + float(o[4]) - hb_t
	var oben := y + float(o[4]) + 0.03
	var s := 1.0 if seite.begins_with("+") else -1.0
	var entlang := n if seite.ends_with("u") else u
	var tief := u if seite.ends_with("u") else n
	var d0 := (hl if seite.ends_with("u") else hb) * s
	var innen3 := Vector3(-tief.x * s, 0, -tief.y * s)
	var teile := 12
	for k in teile:
		var w0 := PI * k / teile
		var w1 := PI * (k + 1) / teile
		var x0 := lage + (hb_t + 0.02) * cos(w0)
		var x1 := lage + (hb_t + 0.02) * cos(w1)
		var y0 := kaempfer + (hb_t + 0.02) * sin(w0)
		var y1 := kaempfer + (hb_t + 0.02) * sin(w1)
		var p := func(x: float, yy: float, d: float) -> Vector3:
			var q := c + entlang * x + tief * d
			return Vector3(q.x, yy, q.y)
		_viereck(mat, p.call(x0, y0, d0), p.call(x1, y1, d0), p.call(x1, oben, d0), p.call(x0, oben, d0), innen3)
		if int(o[5]) == 2:
			continue                # alte Gänge (und Geheimtüren): ohne hellen Bogen
		# Bogensteine, etwas vor der Wand
		var r0 := hb_t + 0.02
		var r1 := hb_t + 0.3
		var dv := d0 - s * 0.06
		_viereck("hell", p.call(lage + r0 * cos(w0), kaempfer + r0 * sin(w0), dv), p.call(lage + r0 * cos(w1), kaempfer + r0 * sin(w1), dv),
			p.call(lage + r1 * cos(w1), kaempfer + r1 * sin(w1), dv), p.call(lage + r1 * cos(w0), kaempfer + r1 * sin(w0), dv), innen3)
		_viereck("hell", p.call(lage + r1 * cos(w0), kaempfer + r1 * sin(w0), d0), p.call(lage + r1 * cos(w1), kaempfer + r1 * sin(w1), d0),
			p.call(lage + r1 * cos(w1), kaempfer + r1 * sin(w1), dv), p.call(lage + r1 * cos(w0), kaempfer + r1 * sin(w0), dv),
			Vector3(0, 1, 0) * sin((w0 + w1) / 2.0) + Vector3(entlang.x, 0, entlang.y) * cos((w0 + w1) / 2.0))
		_viereck("hell", p.call(lage + r0 * cos(w0), kaempfer + r0 * sin(w0), d0), p.call(lage + r0 * cos(w1), kaempfer + r0 * sin(w1), d0),
			p.call(lage + r0 * cos(w1), kaempfer + r0 * sin(w1), dv), p.call(lage + r0 * cos(w0), kaempfer + r0 * sin(w0), dv),
			-(Vector3(0, 1, 0) * sin((w0 + w1) / 2.0) + Vector3(entlang.x, 0, entlang.y) * cos((w0 + w1) / 2.0)))


## Grab- oder Lagernischen: Seite → Liste von Rect2 (Lage entlang der Wand, Höhe)
func _nischen(zier: int, nu: int, su: float, nb: int, sb: float, hl: float, hb: float, boden: float, kaempfer: float,
		oeff: Array) -> Dictionary:
	var aus := {}
	if zier & 5 == 0:
		return aus
	for seite: String in ["+n", "-n"]:
		var liste: Array = []
		for i in nu:
			var mitte := -hl + (i + 0.5) * su
			var frei := true
			for o: Array in oeff:
				if o[0] == seite and absf(float(o[1]) - mitte) < su / 2.0 + float(o[3]) / 2.0:
					frei = false
			if not frei:
				continue
			if zier & 1:
				var lang := minf(2.1, su - 1.1)
				if lang < 1.6:
					continue
				for reihe in 3:
					var y := boden + 0.35 + reihe * 0.78
					if y + 0.58 > kaempfer - 0.3:
						break
					liste.append(Rect2(mitte - lang / 2.0, y, lang, 0.58))
			else:
				var b := minf(2.4, su - 1.2)
				if b > 1.0:
					liste.append(Rect2(mitte - b / 2.0, boden + 0.02, b, minf(2.4, kaempfer - boden - 0.5)))
		aus[seite] = liste
	return aus


## In die Grabnischen: Gebeine oder eine Verschlussplatte, in die Lagernischen nichts (die Bauskripte stellen Fässer)
func _nischen_ausstatten(c: Vector2, u: Vector2, n: Vector2, hl: float, hb: float, nischen: Dictionary, zier: int) -> void:
	if zier & 1 == 0:
		return
	for seite: String in nischen:
		var s := 1.0 if seite.begins_with("+") else -1.0
		for r: Rect2 in nischen[seite]:
			var mitte := r.position.x + r.size.x / 2.0
			var tief := hb + SCHICHT * 0.5
			var z := _h01(c + u * mitte * 1.3 + n * r.position.y * 2.1)
			var y := r.position.y
			if z < 0.35:
				# verschlossen: Platte mit Rahmen
				_klotz("hell", c, u, n, r.position.x + 0.02, r.end.x - 0.02, s * (hb + 0.06) - 0.03, s * (hb + 0.06) + 0.03, y + 0.02, r.end.y - 0.02)
				_klotz("mauer", c, u, n, mitte - 0.25, mitte + 0.25, s * (hb + 0.02) - 0.02, s * (hb + 0.02) + 0.02, y + 0.2, y + 0.38, true)
				continue
			# offen: Leichentuch oder Gebeine
			if z < 0.6:
				_klotz("leinen", c, u, n, r.position.x + 0.18, r.end.x - 0.18, s * tief - 0.2, s * tief + 0.2, y, y + 0.18)
				_klotz("leinen", c, u, n, r.position.x + 0.12, r.position.x + 0.42, s * tief - 0.14, s * tief + 0.14, y + 0.1, y + 0.26)
			else:
				# Schädel und lange Knochen
				var ks := r.position.x + 0.3 + z * 0.4
				_klotz("zier_knochen", c, u, n, ks - 0.09, ks + 0.09, s * tief - 0.1, s * tief + 0.1, y, y + 0.17)
				for auge: float in [-0.035, 0.035]:
					_klotz("zier_russ", c, u, n, ks + auge - 0.022, ks + auge + 0.022, minf(s * (tief - 0.105), s * (tief - 0.095)),
						maxf(s * (tief - 0.105), s * (tief - 0.095)), y + 0.07, y + 0.11)
				for k in 4:
					var g := 0.3 * sin(z * 20.0 + k)
					var ru := u.rotated(g)
					var mu := ks + 0.45 + k * 0.22
					_klotz("zier_knochen", c + u * mu + n * s * (tief - 0.12 + k * 0.07), ru, Vector2(-ru.y, ru.x), -0.24, 0.24, -0.025, 0.025, y, y + 0.045)


## Kreuzgewölbe eines Felds (Mitte bu, bn; halbe Seiten au, an): Fläche y = Kämpfer + Stich · max(√(1 - x²/au²),
## √(1 - z²/an²)), glatt schattiert, die Grate scharf
func _kreuzjoch(mat: String, c: Vector2, u: Vector2, n: Vector2, bu: float, bn: float, au: float, an: float, kaempfer: float,
		stich: float, weg: bool) -> void:
	if weg:
		return
	var m := 6
	var U := Vector3(u.x, 0, u.y)
	var N := Vector3(n.x, 0, n.y)
	var fx := func(x: float) -> float:
		return stich * sqrt(maxf(1.0 - (x / au) * (x / au), 0.0))
	var fz := func(z: float) -> float:
		return stich * sqrt(maxf(1.0 - (z / an) * (z / an), 0.0))
	var punkt := func(i: int, j: int) -> Vector3:
		var x := -au + 2.0 * au * i / (2 * m)
		var z := -an + 2.0 * an * j / (2 * m)
		return _p(c, u, n, bu + x, bn + z, kaempfer + maxf(fx.call(x), fz.call(z)))
	# Normale (zum Raum hin) für den Zweig, der von x (bzw. z) abhängt
	var nx := func(x: float) -> Vector3:
		var t := clampf(x / au, -0.985, 0.985)
		var d := -stich * t / (au * sqrt(1.0 - t * t))
		return (U * d - Vector3.UP).normalized()
	var nz := func(z: float) -> Vector3:
		var t := clampf(z / an, -0.985, 0.985)
		var d := -stich * t / (an * sqrt(1.0 - t * t))
		return (N * d - Vector3.UP).normalized()
	for i in 2 * m:
		for j in 2 * m:
			var haupt := (i < m) == (j < m)
			var dreiecke: Array = []
			if haupt:
				dreiecke = [[[i, j], [i + 1, j], [i + 1, j + 1]], [[i, j], [i + 1, j + 1], [i, j + 1]]]
			else:
				dreiecke = [[[i, j], [i + 1, j], [i, j + 1]], [[i + 1, j], [i + 1, j + 1], [i, j + 1]]]
			for d: Array in dreiecke:
				var xs := 0.0
				var zs := 0.0
				for e: Array in d:
					xs += -au + 2.0 * au * int(e[0]) / (2 * m)
					zs += -an + 2.0 * an * int(e[1]) / (2 * m)
				xs /= 3.0
				zs /= 3.0
				var mitte_w := c + u * (bu + xs) + n * (bn + zs)
				if _im_schacht(mitte_w):
					continue
				var zweig_x: bool = fx.call(xs) >= fz.call(zs)
				var ecken: Array[Vector3] = []
				var normalen: Array[Vector3] = []
				for e: Array in d:
					ecken.append(punkt.call(int(e[0]), int(e[1])))
					var x := -au + 2.0 * au * int(e[0]) / (2 * m)
					var z := -an + 2.0 * an * int(e[1]) / (2 * m)
					normalen.append(nx.call(x) if zweig_x else nz.call(z))
				_dreieck_n(mat, ecken[0], normalen[0], ecken[1], normalen[1], ecken[2], normalen[2])


## Rippen auf den Graten und Gurtbögen zwischen den Feldern (auch an den Wänden als Schildbögen)
func _rippen(mat: String, c: Vector2, u: Vector2, n: Vector2, hl: float, hb: float, nu: int, nb: int, su: float, sb: float,
		kaempfer: float, stich: float, ruine: bool) -> void:
	var U := Vector3(u.x, 0, u.y)
	var N := Vector3(n.x, 0, n.y)
	var teile := 14
	for i in nu:
		for j in nb:
			var bu := -hl + (i + 0.5) * su
			var bn := -hb + (j + 0.5) * sb
			var au := su / 2.0
			var an := sb / 2.0
			if ruine and _h01(c + u * bu * 1.7 + n * bn * 2.3) < 0.3 and (i + j) % 2 == 1:
				continue
			# Grate: von den vier Ecken zur Mitte
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					var pkt: Array[Vector3] = []
					var inn: Array[Vector3] = []
					for k in teile + 1:
						var f := float(k) / teile        # 0 Ecke, 1 Mitte
						var t := clampf(1.0 - f, 0.0, 0.985)
						var y := kaempfer + stich * sqrt(1.0 - t * t)
						pkt.append(_p(c, u, n, bu + sx * au * (1.0 - f), bn + sz * an * (1.0 - f), y))
						var d := stich * t / sqrt(1.0 - t * t)
						var na := (U * (-sx) * d / au - Vector3.UP).normalized()
						var nzv := (N * (-sz) * d / an - Vector3.UP).normalized()
						inn.append((na + nzv).normalized())
					_band(mat, pkt, inn, 0.2, 0.12)
			# Gurtbögen an den Feldrändern: x = ±au (Bogen über z) und z = ±an (Bogen über x)
			for kante in 4:
				var bei_x := kante < 2
				var s := -1.0 if kante % 2 == 0 else 1.0
				if s < 0.0 and ((bei_x and i > 0) or (not bei_x and j > 0)):
					continue                          # die gemeinsame Kante baut das Nachbarfeld
				var pkt: Array[Vector3] = []
				var inn: Array[Vector3] = []
				var halb := an if bei_x else au
				for k in teile * 2 + 1:
					var q := -halb + 2.0 * halb * k / (teile * 2)
					var t := clampf(q / halb, -0.985, 0.985)
					var y := kaempfer + stich * sqrt(1.0 - t * t)
					var d := -stich * t / (halb * sqrt(1.0 - t * t))
					if bei_x:
						pkt.append(_p(c, u, n, bu + s * au, bn + q, y))
						inn.append((N * d - Vector3.UP).normalized())
					else:
						pkt.append(_p(c, u, n, bu + q, bn + s * an, y))
						inn.append((U * d - Vector3.UP).normalized())
				var am_rand := (bei_x and ((s < 0 and i == 0) or (s > 0 and i == nu - 1))) or \
					(not bei_x and ((s < 0 and j == 0) or (s > 0 and j == nb - 1)))
				_band(mat, pkt, inn, 0.22 if am_rand else 0.34, 0.1 if am_rand else 0.16)


## Achteckiger Pfeiler mit Basis, Kapitell und Deckplatte
func _pfeiler(mat: String, p: Vector3, u: Vector2, n: Vector2, fuss: float, oben: float, kaempfer: float, feld: float) -> void:
	var c := Vector2(p.x, p.z)
	var r := clampf(feld * 0.075, 0.24, 0.42)
	_klotz(mat, c, u, n, -r - 0.18, r + 0.18, -r - 0.18, r + 0.18, fuss - 0.1, fuss + 0.28)
	_klotz(mat, c, u, n, -r - 0.1, r + 0.1, -r - 0.1, r + 0.1, fuss + 0.28, fuss + 0.38)
	var schaft_oben := minf(oben, kaempfer - 0.42)
	_mantel(mat, c, r, r * 0.94, fuss + 0.38, schaft_oben, 8)
	if oben < kaempfer - 0.1:
		_ring(mat, c, 0.0, r * 0.94, schaft_oben, 8)       # Bruchfläche
		return
	# Kapitell: nach oben breiter (Kelch), Deckplatte
	_mantel(mat, c, r * 0.96, r + 0.16, kaempfer - 0.42, kaempfer - 0.14, 8)
	_klotz(mat, c, u, n, -r - 0.24, r + 0.24, -r - 0.24, r + 0.24, kaempfer - 0.14, kaempfer + 0.02, true)


## Wandvorlage (halber Pfeiler) an der Wand bei lage (entlang a), Wandfläche bei d0 (entlang d), zum Raum hin innen
func _vorlage(mat: String, c: Vector2, a: Vector2, d: Vector2, lage: float, d0: float, innen: float, boden: float,
		kaempfer: float, oeff: Array, seite: String) -> void:
	for o: Array in oeff:
		if o[0] == seite and absf(float(o[1]) - lage) < float(o[3]) / 2.0 + 0.5:
			return
	var t0 := d0
	var t1 := d0 + innen * 0.24
	_klotz(mat, c, a, d, lage - 0.28, lage + 0.28, minf(t0, t1), maxf(t0, t1), boden - 0.05, kaempfer - 0.14)
	var k1 := d0 + innen * 0.36
	_klotz(mat, c, a, d, lage - 0.4, lage + 0.4, minf(t0, k1), maxf(t0, k1), kaempfer - 0.36, kaempfer + 0.02, true)
	var s1 := d0 + innen * 0.34
	_klotz(mat, c, a, d, lage - 0.38, lage + 0.38, minf(t0, s1), maxf(t0, s1), boden - 0.05, boden + 0.3)


## Tonnengewölbe entlang u mit Gurtbögen alle su Meter, darunter Wandvorlagen
func _tonne(mat: String, mat_gurt: String, c: Vector2, u: Vector2, n: Vector2, hl: float, hb: float, kaempfer: float,
		stich: float, nu: int, su: float, boden: float) -> void:
	var N := Vector3(n.x, 0, n.y)
	var teile := 16
	var bogen := func(k: int) -> Array:
		var a := PI * k / teile
		var q := -hb * cos(a)
		var y := kaempfer + stich * sin(a)
		var t := clampf(q / hb, -0.985, 0.985)
		var d := -stich * t / (hb * sqrt(1.0 - t * t))
		return [q, y, (N * d - Vector3.UP).normalized()]
	var stuecke := maxi(nu * 2, 2)
	for k in teile:
		var a: Array = bogen.call(k)
		var b: Array = bogen.call(k + 1)
		for i in stuecke:
			var s0 := -hl + 2.0 * hl * i / stuecke
			var s1 := -hl + 2.0 * hl * (i + 1) / stuecke
			_viereck_n(mat, _p(c, u, n, s0, a[0], a[1]), a[2], _p(c, u, n, s1, a[0], a[1]), a[2],
				_p(c, u, n, s1, b[0], b[1]), b[2], _p(c, u, n, s0, b[0], b[1]), b[2])
	for i in range(1, nu):
		var s := -hl + i * su
		var pkt: Array[Vector3] = []
		var inn: Array[Vector3] = []
		for k in teile + 1:
			var a: Array = bogen.call(k)
			pkt.append(_p(c, u, n, s, a[0], a[1]))
			inn.append(a[2])
		_band(mat_gurt, pkt, inn, 0.5, 0.2)
		for sq: float in [-1.0, 1.0]:
			var t0 := sq * hb
			var t1 := sq * (hb - 0.2)
			_klotz(mat_gurt, c, u, n, s - 0.25, s + 0.25, minf(t0, t1), maxf(t0, t1), boden - 0.05, kaempfer)


## Boden der Zisterne: Laufsteg an den Wänden, Becken in der Mitte mit Wasser, Stufen hinein an der Stirnseite -u
func _zisterne_boden(c: Vector2, u: Vector2, n: Vector2, hl: float, hb: float, boden: float, oeff: Array) -> void:
	var steg := 1.6
	var grund := boden - 1.6
	var wasser := boden - 0.55
	_klotz("kai", c, u, n, -hl, hl, -hb, -hb + steg, grund - 0.3, boden)
	_klotz("kai", c, u, n, -hl, hl, hb - steg, hb, grund - 0.3, boden)
	_klotz("kai", c, u, n, -hl, -hl + steg, -hb + steg, hb - steg, grund - 0.3, boden)
	_klotz("kai", c, u, n, hl - steg, hl, -hb + steg, hb - steg, grund - 0.3, boden)
	# Kantensteine am Becken (auf dem Steg, an der Kante)
	var ki := hb - steg
	var ku := hl - steg
	_klotz("hell", c, u, n, -ku - 0.3, ku + 0.3, ki, ki + 0.3, boden - 0.25, boden + 0.02)
	_klotz("hell", c, u, n, -ku - 0.3, ku + 0.3, -ki - 0.3, -ki, boden - 0.25, boden + 0.02)
	_klotz("hell", c, u, n, ku, ku + 0.3, -ki, ki, boden - 0.25, boden + 0.02)
	_klotz("hell", c, u, n, -ku - 0.3, -ku, -ki, -0.7, boden - 0.25, boden + 0.02)
	_klotz("hell", c, u, n, -ku - 0.3, -ku, 0.7, ki, boden - 0.25, boden + 0.02)
	_klotz("kai", c, u, n, -hl + steg, hl - steg, -hb + steg, hb - steg, grund - 0.4, grund)
	# Wasser (ohne Kollision) und ein dunkler Grund
	_viereck("zier_wasser_innen", _p(c, u, n, -hl + steg, -hb + steg, wasser), _p(c, u, n, hl - steg, -hb + steg, wasser),
		_p(c, u, n, hl - steg, hb - steg, wasser), _p(c, u, n, -hl + steg, hb - steg, wasser), Vector3.UP)
	# Stufen ins Becken: von der Stirnseite -u hinab
	var breite := 1.3
	var stufen := 7
	var tritt := 0.32
	for k in stufen:
		var y := boden - (k + 1) * (boden - grund) / stufen
		var s0 := -hl + steg + k * tritt
		_klotz("kai", c, u, n, s0, s0 + tritt + 0.02, -breite / 2.0, breite / 2.0, grund - 0.3, y)
	_viereck("rampe", _p(c, u, n, -hl + steg, -breite / 2.0, boden + 0.02), _p(c, u, n, -hl + steg + stufen * tritt, -breite / 2.0, grund + 0.02),
		_p(c, u, n, -hl + steg + stufen * tritt, breite / 2.0, grund + 0.02), _p(c, u, n, -hl + steg, breite / 2.0, boden + 0.02), Vector3.UP)


## Ruß an den Wänden: von unten nach oben auslaufende dunkle Zungen (der Brand um 940)
func _brandspuren(c: Vector2, u: Vector2, n: Vector2, hl: float, hb: float, boden: float, kaempfer: float, oeff: Array) -> void:
	for seite: String in ["+n", "-n", "+u", "-u"]:
		var s := 1.0 if seite.begins_with("+") else -1.0
		var entlang := u if seite.ends_with("n") else n
		var tief := n if seite.ends_with("n") else u
		var halb := hl if seite.ends_with("n") else hb
		var d0 := (hb if seite.ends_with("n") else hl) * s - s * 0.02
		var innen3 := -Vector3(tief.x, 0, tief.y) * s
		var x := -halb + 0.6
		var k := 0
		while x < halb - 0.6:
			var z := _h01(c + entlang * x * 1.9 + tief * float(k))
			var b := 0.5 + z * 1.1
			var h := 1.2 + z * (kaempfer - boden - 0.8)
			var frei := true
			for o: Array in oeff:
				if o[0] == seite and absf(float(o[1]) - x) < float(o[3]) / 2.0 + b:
					frei = false
			if frei and z > 0.25:
				var p := func(xx: float, yy: float) -> Vector3:
					var q := c + entlang * xx + tief * d0
					return Vector3(q.x, yy, q.y)
				_viereck("zier_russ", p.call(x - b / 2.0, boden), p.call(x + b / 2.0, boden), p.call(x + b * 0.12, boden + h),
					p.call(x - b * 0.12, boden + h), innen3)
			x += b * 0.9 + z * 0.8
			k += 1


## Fackeln und Licht in einem Raum; die Lichter flackern (_process)
func _lichter_raum(c: Vector2, u: Vector2, n: Vector2, hl: float, hb: float, nu: int, su: float, boden: float, kaempfer: float,
		zier: int, oeff: Array, art: int) -> void:
	if zier & 8:
		_licht(Vector3(c.x, kaempfer, c.y), LICHT_KALT, 0.35, maxf(hl, hb) * 1.6, false)
		return
	if zier & 2 == 0:
		return
	var plaetze: Array = []     # [Lage entlang u, Seite]
	if nu >= 2:
		for i in range(1, nu):
			plaetze.append([-hl + i * su, 1.0 if i % 2 == 0 else -1.0])
	else:
		plaetze.append([0.0, 1.0])
		plaetze.append([0.0, -1.0])
	for pl: Array in plaetze:
		var lage: float = pl[0]
		var s: float = pl[1]
		var seite := "+n" if s > 0 else "-n"
		var frei := true
		for o: Array in oeff:
			if o[0] == seite and absf(float(o[1]) - lage) < float(o[3]) / 2.0 + 0.7:
				frei = false
		if not frei:
			if nu < 2:
				continue
			s = -s
		var vor := 0.24 if nu >= 2 else 0.0      # vor der Wandvorlage
		var wand := c + u * lage + n * s * (hb - vor)
		_fackel(wand, -n * s, boden + 2.1, true)


## Fackel in einem eisernen Halter an der Wand (wand: Punkt auf der Wandfläche, innen: Richtung in den Raum)
func _fackel(wand: Vector2, innen: Vector2, y: float, schatten: bool) -> void:
	var quer := Vector2(-innen.y, innen.x)
	_klotz("metall", wand, quer, innen, -0.06, 0.06, 0.0, 0.03, y - 0.25, y + 0.05)
	_klotz("metall", wand, quer, innen, -0.025, 0.025, 0.0, 0.3, y - 0.05, y - 0.01)
	var halter := wand + innen * 0.26
	_klotz("metall", halter, quer, innen, -0.06, 0.06, -0.06, 0.06, y - 0.06, y + 0.02)
	_klotz("holz", halter + innen * 0.03, quer, innen, -0.03, 0.03, -0.03, 0.03, y - 0.35, y + 0.22)
	_klotz("glut", halter + innen * 0.05, quer, innen, -0.05, 0.05, -0.05, 0.05, y + 0.22, y + 0.38)
	_licht(Vector3(halter.x + innen.x * 0.15, y + 0.45, halter.y + innen.y * 0.15), LICHT_WARM, 1.5, 10.0, schatten)


func _licht(p: Vector3, farbe: Color, energie: float, reichweite: float, schatten: bool) -> void:
	var l := OmniLight3D.new()
	l.name = "Licht%d" % get_child_count()
	l.position = p
	l.light_color = farbe
	l.light_energy = energie
	l.omni_range = reichweite
	l.omni_attenuation = 1.4
	l.shadow_enabled = schatten
	l.distance_fade_enabled = true
	l.distance_fade_begin = 45.0
	l.distance_fade_length = 10.0
	if farbe == LICHT_WARM:
		l.set_meta("flackern", true)
	_haenge_an(l)


## Reflexionssonde als Innenraum: dunkles Umgebungslicht statt Himmel (sonst leuchtete der Himmel unter die Erde)
func _sonde(m: Vector3, u: Vector2, groesse: Vector3, spiegelnd: bool) -> void:
	var s := ReflectionProbe.new()
	s.name = "Sonde%d" % get_child_count()
	var w := atan2(u.x, u.y)
	s.transform = Transform3D(Basis(Vector3.UP, w), m)
	s.size = groesse
	s.interior = true
	s.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	s.ambient_color = UMGEBUNG
	s.ambient_color_energy = 1.0
	s.update_mode = ReflectionProbe.UPDATE_ONCE
	s.intensity = 0.6 if spiegelnd else 0.25
	s.max_distance = maxf(groesse.x, groesse.z) + 4.0
	s.blend_distance = 0.8
	if not spiegelnd:
		s.cull_mask = 0
	_haenge_an(s)


# ---------- Wendeltreppe ----------

func _wendeltreppe(w: PackedFloat32Array, oeff: Array) -> void:
	var c := Vector2(w[0], w[1])
	var R := w[3] / 2.0
	var unten := w[5]
	var hoehe := w[6]
	var zier := int(w[10])
	var stufen := maxi(1, int(round(hoehe / 0.2)))
	var steig := hoehe / stufen
	var delta := TAU / W_JE_RUNDE
	var start := deg_to_rad(w[2] + W_ANTRITT)
	var oben := unten + hoehe
	var decke := oben + 3.0
	var richtung := func(a: float) -> Vector2:
		return Vector2(sin(a), cos(a))
	# Wand: innen glatt (rund), mit Öffnungen an den Gängen
	var teile := 48
	_runde_wand("bruchstein", c, R, unten - 0.6, decke + 0.3, oeff)
	# Boden unten, Decke oben, Spindel
	_ring("boden", c, 0.0, R + 0.05, unten, teile, true)
	_klotz("boden", c, Vector2(1, 0), Vector2(0, 1), -R, R, -R, R, unten - 0.5, unten - 0.02)
	_ring("mauer", c, 0.0, R + 0.05, decke, teile, false)
	_klotz("bruchstein", c, Vector2(1, 0), Vector2(0, 1), -R - 0.8, R + 0.8, -R - 0.8, R + 0.8, decke + 0.02, decke + 0.5, true)
	_mantel("hell", c, W_SPINDEL, W_SPINDEL, unten, decke, 10)
	# Stufen: Keile von der Spindel bis zur Wand, je 0,3 m stark; die letzte ist der obere Absatz
	for k in stufen:
		var a0 := start + k * delta
		var a1 := a0 + delta + (deg_to_rad(W_AUSTRITT * 2.0 + 10.0) if k == stufen - 1 else 0.02)
		var y := unten + (k + 1) * steig
		_stufenkeil("hell" if k % 2 == 0 else "boden", c, W_SPINDEL - 0.02, R + 0.05, a0, a1, y - 0.32, y)
	# unsichtbare Lauffläche über den Stufenkanten (Wendel), im Gehbereich
	var r0 := W_SPINDEL + 0.45
	for k in range(-1, stufen):
		var a0 := start + k * delta
		var a1 := a0 + delta
		var y0 := unten + (k + 1) * steig + 0.04
		var y1 := y0 + steig
		if k == stufen - 1:
			y1 = y0
		var q00: Vector2 = c + richtung.call(a0) * r0
		var q01: Vector2 = c + richtung.call(a0) * (R + 0.05)
		var q10: Vector2 = c + richtung.call(a1) * r0
		var q11: Vector2 = c + richtung.call(a1) * (R + 0.05)
		_viereck("rampe", Vector3(q00.x, y0, q00.y), Vector3(q01.x, y0, q01.y), Vector3(q11.x, y1, q11.y), Vector3(q10.x, y1, q10.y), Vector3.UP)
	# Fackeln: etwa eine je Umlauf
	if zier & 2:
		var a := start + PI * 0.6
		while true:
			var stufe_hier := unten + steig * ((a - start) / delta + 1.0)
			if stufe_hier > oben - 0.5:
				break
			var d: Vector2 = richtung.call(a)
			_fackel(c + d * R, -d, stufe_hier + 1.9, false)
			a += PI * 1.5
	_sonde(Vector3(c.x, (unten + decke) / 2.0, c.y), Vector2(0, 1), Vector3(2.0 * R + 1.0, decke - unten + 1.0, 2.0 * R + 1.0), false)


## Gewände an einer Öffnung in einer runden Wand: eine Steinfläche am Ende des Gangs (er ragt 0,25 m in den Raum),
## die die Lücken zwischen dem Gang und dem Ausschnitt in der Rundung deckt; Rundbogen oder Sturz
func _gewaende_rund(c: Vector2, R: float, o: Array, mat := "hell", hinterlegt := false) -> void:
	var w: float = o[1]
	var d := Vector2(sin(w), cos(w))
	var q := Vector2(-d.y, d.x)
	var m := c + d * (R - 0.25)
	var y: float = o[2]
	var hb := float(o[3]) / 2.0
	var h: float = o[4]
	var eckig := int(o[5]) == 3
	var kaempfer := y + (h if eckig else h - hb)
	var oben := y + h + 0.35
	var seite := 0.35
	var unten := y - 0.05
	# Höhlen: Die Wand fehlt um den Gang herum in ganzen Stücken (breiter und höher als der Gang), dahinter liegt nur
	# der leere Raum unter dem Gelände. Die Einfassung steht dort hinter der Wand und deckt die ganze Lücke (Rückmeldung
	# 28.11.2026: neben dem Gang zum Meer sah man den Himmel)
	if hinterlegt:
		m = c + d * (R + 0.2)
		seite = 4.0
		oben = y + h + 3.0
		unten = y - 1.0
	var innen := -Vector3(d.x, 0, d.y)
	var p := func(x: float, yy: float) -> Vector3:
		var r := m + q * x
		return Vector3(r.x, yy, r.y)
	for s: float in [-1.0, 1.0]:
		_viereck(mat, p.call(s * hb, unten), p.call(s * (hb + seite), unten), p.call(s * (hb + seite), oben), p.call(s * hb, oben), innen)
	if eckig:
		_viereck(mat, p.call(-hb, kaempfer), p.call(hb, kaempfer), p.call(hb, oben), p.call(-hb, oben), innen)
		return
	var teile := 12
	for k in teile:
		var w0 := PI * k / teile
		var w1 := PI * (k + 1) / teile
		_viereck(mat, p.call(hb * cos(w0), kaempfer + hb * sin(w0)), p.call(hb * cos(w1), kaempfer + hb * sin(w1)),
			p.call(hb * cos(w1), oben), p.call(hb * cos(w0), oben), innen)


## Runde Wand (innen glatt) von unten bis oben mit Ausschnitten für die Öffnungen
func _runde_wand(mat: String, c: Vector2, R: float, unten: float, oben: float, oeff: Array) -> void:
	var teile := 48
	for k in teile:
		var a0 := TAU * k / teile
		var a1 := TAU * (k + 1) / teile
		var bereiche: Array[Vector2] = [Vector2(unten, oben)]
		for o: Array in oeff:
			var halb := asin(clampf((float(o[3]) / 2.0 + 0.05) / R, 0.0, 1.0))
			if absf(angle_difference((a0 + a1) / 2.0, float(o[1]))) < halb + PI / teile:
				var neu: Array[Vector2] = []
				for b: Vector2 in bereiche:
					var y0: float = float(o[2]) - 0.3
					var y1: float = float(o[2]) + float(o[4]) + 0.05
					if y1 <= b.x or y0 >= b.y:
						neu.append(b)
						continue
					if y0 > b.x:
						neu.append(Vector2(b.x, y0))
					if y1 < b.y:
						neu.append(Vector2(y1, b.y))
				bereiche = neu
		var d0 := Vector2(sin(a0), cos(a0))
		var d1 := Vector2(sin(a1), cos(a1))
		var n0 := -Vector3(d0.x, 0, d0.y)
		var n1 := -Vector3(d1.x, 0, d1.y)
		var p0 := c + d0 * R
		var p1 := c + d1 * R
		for b: Vector2 in bereiche:
			_viereck_n(mat, Vector3(p0.x, b.x, p0.y), n0, Vector3(p1.x, b.x, p1.y), n1, Vector3(p1.x, b.y, p1.y), n1,
				Vector3(p0.x, b.y, p0.y), n0)
	for o: Array in oeff:
		_gewaende_rund(c, R, o)


## Rundkammer (Art 6): runde Wand, Kuppel mit sechs Rippen und Schlussstein, Fackeln zwischen den Öffnungen
func _rundkammer(w: PackedFloat32Array, oeff: Array) -> void:
	var c := Vector2(w[0], w[1])
	var R := w[3] / 2.0
	var boden := w[5]
	var kaempfer := boden + w[6]
	var stich := w[7]
	var zier := int(w[10])
	_runde_wand("bruchstein", c, R, boden - 0.4, kaempfer + 0.05, oeff)
	_ring("boden", c, 0.0, R + 0.05, boden, 48, true)
	_klotz("boden", c, Vector2(1, 0), Vector2(0, 1), -R, R, -R, R, boden - 0.5, boden - 0.02)
	# Kuppel (Kugelkappe, glatt)
	var ringe := 8
	var teile := 40
	for j in ringe:
		var f0 := PI / 2.0 * j / ringe
		var f1 := PI / 2.0 * (j + 1) / ringe
		for k in teile:
			var a0 := TAU * k / teile
			var a1 := TAU * (k + 1) / teile
			var pkt := func(f: float, a: float) -> Vector3:
				return Vector3(c.x + sin(a) * R * cos(f), kaempfer + stich * sin(f), c.y + cos(a) * R * cos(f))
			var nrm := func(f: float, a: float) -> Vector3:
				return -Vector3(sin(a) * cos(f) / R, sin(f) / maxf(stich, 0.1), cos(a) * cos(f) / R).normalized()
			var mitte_q := c + Vector2(sin((a0 + a1) / 2.0), cos((a0 + a1) / 2.0)) * R * cos((f0 + f1) / 2.0)
			if _im_schacht(mitte_q):
				continue
			_viereck_n("mauer", pkt.call(f0, a0), nrm.call(f0, a0), pkt.call(f0, a1), nrm.call(f0, a1), pkt.call(f1, a1), nrm.call(f1, a1),
				pkt.call(f1, a0), nrm.call(f1, a0))
	# Rippen und Kämpferring
	for r in 6:
		var a := TAU * r / 6.0 + PI / 6.0
		var pkt: Array[Vector3] = []
		var inn: Array[Vector3] = []
		for j in 13:
			var f := PI / 2.0 * j / 12.0
			pkt.append(Vector3(c.x + sin(a) * R * cos(f), kaempfer + stich * sin(f), c.y + cos(a) * R * cos(f)))
			inn.append(-Vector3(sin(a) * cos(f) / R, sin(f) / maxf(stich, 0.1), cos(a) * cos(f) / R).normalized())
		_band("hell", pkt, inn, 0.2, 0.12)
	_mantel("hell", c, R - 0.12, R - 0.12, kaempfer - 0.2, kaempfer, 40, true)
	_ring("hell", c, R - 0.12, R + 0.01, kaempfer - 0.2, 40, false)
	if not _im_schacht(c):
		_mantel("hell", c, 0.32, 0.26, kaempfer + stich - 0.28, kaempfer + stich + 0.05, 10)
		_ring("hell", c, 0.0, 0.26, kaempfer + stich - 0.28, 10, false)
		_klotz("bruchstein", c, Vector2(1, 0), Vector2(0, 1), -R - 0.8, R + 0.8, -R - 0.8, R + 0.8, kaempfer + stich + 0.3, kaempfer + stich + 0.7, true)
	# Fackeln: zwei gegenüber, abseits der Öffnungen
	if zier & 2:
		var gesetzt := 0
		for k in 12:
			if gesetzt >= 2:
				break
			var a := TAU * k / 12.0 + PI / 12.0
			var frei := true
			for o: Array in oeff:
				if absf(angle_difference(a, float(o[1]))) < 0.75:
					frei = false
			if not frei:
				continue
			var d := Vector2(sin(a), cos(a))
			_fackel(c + d * R, -d, boden + 2.1, gesetzt == 0)
			gesetzt += 1
	elif zier & 8:
		_licht(Vector3(c.x, kaempfer, c.y), LICHT_KALT, 0.3, R * 3.0, false)
	_sonde(Vector3(c.x, boden + (w[6] + stich) / 2.0, c.y), Vector2(0, 1), Vector3(2.0 * R + 1.0, w[6] + stich + 1.5, 2.0 * R + 1.0), false)


## Radius einer Höhle (Ellipse mit halben Achsen hl entlang u, hb entlang n) in Richtung d (Welt, Einheitsvektor)
static func _ellipse_r(d: Vector2, u: Vector2, n: Vector2, hl: float, hb: float) -> float:
	var cu := d.dot(u) / hl
	var cn := d.dot(n) / hb
	return 1.0 / sqrt(maxf(cu * cu + cn * cn, 0.0001))


## Abstand (Bogenmaß) von Winkel a zum Rand der nächsten Öffnung (negativ: in der Öffnung); r: Radius dort
static func _abstand_oeffnung(oeff: Array, a: float, r: float) -> float:
	var best := 10.0
	for o: Array in oeff:
		var halb := (float(o[3]) / 2.0 + 0.4) / maxf(r, 0.5)
		best = minf(best, absf(angle_difference(a, float(o[1]))) - halb)
	return best


## Höhle (Art 4): Felswand auf einer Ellipse, nach oben eine unregelmäßige Kuppel, rauer Boden mit Brocken. Die Wand
## buchtet zufällig aus (fest je Ort), an den Öffnungen glatt, damit die Gänge (mit einer Felsleibung) anschließen.
func _hoehlenraum(w: PackedFloat32Array, oeff: Array) -> void:
	var c := Vector2(w[0], w[1])
	var ach := _achsen(w[2])
	var u := ach[0]
	var n := ach[1]
	var hl := w[3] / 2.0
	var hb := w[4] / 2.0
	var boden := w[5]
	var kaempfer := boden + w[6]
	var stich := w[7]
	var zier := int(w[10])
	var teile := 64
	# Ringe: Höhe und Radiusfaktor; erst die Wand, dann die Kuppel
	var ringe: Array[Vector2] = [Vector2(boden - 0.8, 1.0), Vector2(boden + w[6] * 0.35, 1.0), Vector2(boden + w[6] * 0.7, 1.0),
		Vector2(kaempfer, 1.0)]
	for f in range(1, 6):
		var a := PI / 2.0 * f / 6.0
		ringe.append(Vector2(kaempfer + stich * sin(a), cos(a)))
	var punkte: Array = []
	for ri in ringe.size():
		var reihe: Array[Vector3] = []
		for k in teile:
			var phi := TAU * k / teile
			var d := (u * cos(phi) + n * sin(phi)).normalized()
			var r := _ellipse_r(d, u, n, hl, hb)
			var glatt := clampf(_abstand_oeffnung(oeff, atan2(d.x, d.y), r) / 0.45, 0.0, 1.0)
			var q := c + d * r
			var z := _h01(Vector2(q.x * 0.71 + ringe[ri].x * 0.37, q.y * 0.83 - ringe[ri].x * 0.21)) - 0.5
			var z2 := _h01(Vector2(q.x * 0.23 + 5.1, q.y * 0.19 - 1.7)) - 0.5
			var aus := 1.0 + (z * 0.16 + z2 * 0.2 + 0.08) * glatt * (0.4 if ri == 0 else 1.0)
			var rr := r * ringe[ri].y * aus
			var y := ringe[ri].x + (z * 0.1 * stich if ri >= 4 else 0.0)
			reihe.append(Vector3(c.x + d.x * rr, y, c.y + d.y * rr))
		punkte.append(reihe)
	for ri in ringe.size() - 1:
		var unten: Array[Vector3] = punkte[ri]
		var oben: Array[Vector3] = punkte[ri + 1]
		for k in teile:
			var k1 := (k + 1) % teile
			var mitte := (unten[k] + unten[k1] + oben[k] + oben[k1]) / 4.0
			# Öffnung: Wandstücke im Bereich eines Gangs bleiben weg
			var a := atan2(mitte.x - c.x, mitte.z - c.y)
			var r := Vector2(mitte.x - c.x, mitte.z - c.y).length()
			var y0 := minf(unten[k].y, unten[k1].y)
			var y1 := maxf(oben[k].y, oben[k1].y)
			var offen := false
			for o: Array in oeff:
				var halb := (float(o[3]) / 2.0 + 0.05) / maxf(r, 0.5)
				if absf(angle_difference(a, float(o[1]))) < halb + PI / teile and y1 > float(o[2]) - 0.3 \
						and y0 < float(o[2]) + float(o[4]) + 0.05:
					offen = true
			if offen:
				continue
			_viereck("fels", unten[k], unten[k1], oben[k1], oben[k], Vector3(c.x, kaempfer, c.y) - mitte)
	var spitze := Vector3(c.x, kaempfer + stich, c.y)
	var letzte: Array[Vector3] = punkte[ringe.size() - 1]
	for k in teile:
		_dreieck("fels", letzte[k], letzte[(k + 1) % teile], spitze, Vector3.DOWN)
	for o: Array in oeff:
		var d := Vector2(sin(float(o[1])), cos(float(o[1])))
		_gewaende_rund(c, _ellipse_r(d, u, n, hl, hb), o, "fels", true)
	# Boden: eben (Erde), an der Wand Brocken
	_klotz("erde", c, u, n, -hl - 1.0, hl + 1.0, -hb - 1.0, hb + 1.0, boden - 0.8, boden)
	for k in 9:
		var phi := TAU * (k + 0.37) / 9.0
		var d := (u * cos(phi) + n * sin(phi)).normalized()
		var r := _ellipse_r(d, u, n, hl, hb)
		if _abstand_oeffnung(oeff, atan2(d.x, d.y), r) < 0.5:
			continue
		var q := c + d * (r - 0.7)
		_haufen("fels", Vector3(q.x, boden, q.y), 0.5 + 0.4 * _h01(q), 0.4 + 0.5 * _h01(q * 1.3), float(k))
	if zier & 2:
		var gesetzt := 0
		for k in 8:
			if gesetzt >= 2:
				break
			var phi := TAU * k / 8.0 + 0.4
			var d := (u * cos(phi) + n * sin(phi)).normalized()
			var r := _ellipse_r(d, u, n, hl, hb)
			if _abstand_oeffnung(oeff, atan2(d.x, d.y), r) < 0.8:
				continue
			_fackel(c + d * (r - 0.1), -d, boden + 2.0, gesetzt == 0)
			gesetzt += 1
	elif zier & 8:
		_licht(Vector3(c.x, kaempfer, c.y), LICHT_KALT, 0.3, maxf(hl, hb) * 2.0, false)
	_sonde(Vector3(c.x, boden + (w[6] + stich) / 2.0, c.y), u, Vector3(2.0 * hb + 1.5, w[6] + stich + 2.0, 2.0 * hl + 1.5),
		zier & 32 != 0)


## Felsmund: die Klippe um eine Meereshöhle genau auf den Dreiecken des Geländes nachgebaut, mit der Öffnung darin
func _felsmund(w: PackedFloat32Array) -> void:
	var fuss := Vector2(w[0], w[1])
	var g := deg_to_rad(w[2])
	var o := Vector2(sin(g), cos(g))
	var r := Vector2(-o.y, o.x)
	var boden := w[3]
	var b := w[4] / 2.0
	var h := w[5]
	var steig := w[6]
	var tief := w[7]
	_hoehle(PackedFloat32Array([fuss.x, fuss.y, o.x, o.y, steig, w[4], h]), false, "gelaende")
	var gel := get_parent().get_node_or_null("Gelaende") if get_parent() != null else null
	if gel == null or not gel.has_method("hoehe_dreieck"):
		return
	var P := b + 3.0
	var nq := int(ceil(2.0 * P / 0.33))
	var nd := int(ceil((tief + 1.6) / 0.33))
	var punkt := func(iq: int, id: int) -> Vector3:
		var q := -P + 2.0 * P * iq / nq
		var d := -tief + (tief + 1.6) * id / nd
		var xz := fuss + r * q + o * d
		return Vector3(xz.x, gel.hoehe_dreieck(xz.x, xz.y), xz.y)
	for iq in nq:
		for id in nd:
			var a: Vector3 = punkt.call(iq, id)
			var bb: Vector3 = punkt.call(iq + 1, id)
			var cc: Vector3 = punkt.call(iq + 1, id + 1)
			var dd: Vector3 = punkt.call(iq, id + 1)
			var qc := -P + 2.0 * P * (iq + 0.5) / nq
			var dc := -tief + (tief + 1.6) * (id + 0.5) / nd
			var y0 := minf(minf(a.y, bb.y), minf(cc.y, dd.y))
			var y1 := maxf(maxf(a.y, bb.y), maxf(cc.y, dd.y))
			# das Loch etwas kleiner als der Gang (der ist breiter): keine Spalten am Rand
			var bl := b - 0.15
			var scheitel := boden + maxf(h - b, 1.2) + sqrt(maxf(bl * bl - qc * qc, 0.0)) - 0.1
			if absf(qc) < bl and dc < 1.3 and y1 > boden - 0.3 and y0 < scheitel:
				continue
			_viereck("gelaende", a, bb, cc, dd, Vector3.UP)
	# Tageslicht im Mund
	var innen := fuss - o * 1.5
	_licht(Vector3(innen.x, boden + h * 0.7, innen.y), LICHT_KALT, 1.4, 16.0, false)


func _im_schacht(p: Vector2) -> bool:
	var j := 0
	while j + 4 < schaechte.size():
		if p.distance_to(Vector2(schaechte[j], schaechte[j + 1])) < schaechte[j + 2]:
			return true
		j += 5
	return false


## Schacht: runde Wand, Seil mit Eimer, ein schwacher Lichtschein von oben
func _schacht(w: PackedFloat32Array) -> void:
	var c := Vector2(w[0], w[1])
	var r := w[2]
	var unten := w[3]
	var oben := w[4]
	_mantel("bruchstein", c, r, r, unten, oben, 16, true)
	_mantel("hell", c, r + 0.25, r, unten - 0.12, unten + 0.02, 16, true)
	# Seil bis knapp über das Wasser, Eimer daran
	var ende := unten - 2.2
	_klotz("seil", c, Vector2(1, 0), Vector2(0, 1), -0.015, 0.015, -0.015, 0.015, ende + 0.45, oben)
	_klotz("holz", c, Vector2(1, 0), Vector2(0, 1), -0.16, 0.16, -0.16, 0.16, ende, ende + 0.32)
	_klotz("metall", c, Vector2(1, 0), Vector2(0, 1), -0.165, 0.165, -0.165, 0.165, ende + 0.22, ende + 0.26)
	_klotz("metall", c, Vector2(1, 0), Vector2(0, 1), -0.17, 0.17, -0.008, 0.008, ende + 0.32, ende + 0.45)
	_licht(Vector3(c.x, unten - 0.3, c.y), LICHT_KALT, 0.7, 7.0, false)


## Keil zwischen zwei Radien und zwei Winkeln (Stufe einer Wendeltreppe)
func _stufenkeil(mat: String, c: Vector2, r0: float, r1: float, a0: float, a1: float, y0: float, y1: float) -> void:
	var teile := maxi(1, int(ceil((a1 - a0) / deg_to_rad(10.0))))
	for k in teile:
		var w0 := a0 + (a1 - a0) * k / teile
		var w1 := a0 + (a1 - a0) * (k + 1) / teile
		var d0 := Vector2(sin(w0), cos(w0))
		var d1 := Vector2(sin(w1), cos(w1))
		var p := func(d: Vector2, r: float, y: float) -> Vector3:
			return Vector3(c.x + d.x * r, y, c.y + d.y * r)
		_viereck(mat, p.call(d0, r0, y1), p.call(d1, r0, y1), p.call(d1, r1, y1), p.call(d0, r1, y1), Vector3.UP)
		_viereck(mat, p.call(d0, r0, y0), p.call(d1, r0, y0), p.call(d1, r1, y0), p.call(d0, r1, y0), Vector3.DOWN)
	var dv := Vector2(sin(a0), cos(a0))
	var dh := Vector2(sin(a1), cos(a1))
	var vorn := -Vector3(cos(a0), 0, -sin(a0))
	_viereck(mat, Vector3(c.x + dv.x * r0, y0, c.y + dv.y * r0), Vector3(c.x + dv.x * r1, y0, c.y + dv.y * r1),
		Vector3(c.x + dv.x * r1, y1, c.y + dv.y * r1), Vector3(c.x + dv.x * r0, y1, c.y + dv.y * r0), vorn)
	_viereck(mat, Vector3(c.x + dh.x * r0, y0, c.y + dh.y * r0), Vector3(c.x + dh.x * r1, y0, c.y + dh.y * r1),
		Vector3(c.x + dh.x * r1, y1, c.y + dh.y * r1), Vector3(c.x + dh.x * r0, y1, c.y + dh.y * r0), -vorn)


# ---------- Gänge ----------

## Querschnitt eines Gangs: Punkte (quer, Höhe über dem Boden) von links unten über den Bogen nach rechts unten
static func _profil(breite: float, hoehe: float, eckig := false) -> Array[Vector2]:
	var hb := breite / 2.0
	if eckig:
		return [Vector2(-hb, -0.7), Vector2(-hb, 0.0), Vector2(-hb, hoehe * 0.5), Vector2(-hb, hoehe), Vector2(0.0, hoehe),
			Vector2(hb, hoehe), Vector2(hb, hoehe * 0.5), Vector2(hb, 0.0), Vector2(hb, -0.7)]
	var wh := maxf(hoehe - hb, 1.2)
	var aus: Array[Vector2] = [Vector2(-hb, -0.7), Vector2(-hb, 0.0), Vector2(-hb, wh * 0.5), Vector2(-hb, wh)]
	var teile := 10
	for k in range(1, teile):
		var a := PI - PI * k / teile
		aus.append(Vector2(hb * cos(a), wh + hb * sin(a)))
	aus += [Vector2(hb, wh), Vector2(hb, wh * 0.5), Vector2(hb, 0.0), Vector2(hb, -0.7)]
	return aus


func _gang(w: PackedFloat32Array, index: int) -> void:
	var a := Vector3(w[0], w[1], w[2])
	var b := Vector3(w[3], w[4], w[5])
	var breite := w[6]
	var hoehe := w[7]
	var art := int(w[8])
	var fackeln := w[9] > 0.5
	var d := Vector2(b.x - a.x, b.z - a.z)
	var lang := d.length()
	if lang < 0.2:
		return
	var u := d / lang
	var n := Vector2(-u.y, u.x)
	var ca := Vector2(a.x, a.z)
	# Abschnitte: eben, Treppe, eben
	var abschnitte: Array = []      # [s0, s1, y0, y1]
	if absf(b.y - a.y) < 0.05:
		abschnitte.append([0.0, lang, a.y, b.y])
	else:
		var absatz := minf(1.1, lang * 0.2)
		abschnitte = [[0.0, absatz, a.y, a.y], [absatz, lang - absatz, a.y, b.y], [lang - absatz, lang, b.y, b.y]]
	var mat_wand := "bruchstein"
	var mat_boden := "boden"
	var mat_bogen := "mauer"
	if art == 1:
		mat_wand = "fels"
		mat_boden = "fels"
		mat_bogen = "fels"
	elif art == 2:
		mat_wand = "basalt"
		mat_boden = "erde"
		mat_bogen = "basalt"
	var profil := _profil(breite, hoehe, art == 3)
	# beginnt der Gang an der Schwelle eines Abgangs oder an einem Felsmund (Oberfläche)?
	var an_abgang := false
	var ia := 0
	while ia + 6 < abgaenge.size():
		for e: Vector3 in [a, b]:
			if Vector2(abgaenge[ia], abgaenge[ia + 1]).distance_to(Vector2(e.x, e.z)) < 0.5:
				an_abgang = true
		ia += 7
	var im := 0
	while im + 7 < felsmuender.size():
		var gm := deg_to_rad(felsmuender[im + 2])
		var mund := Vector2(felsmuender[im], felsmuender[im + 1]) + Vector2(sin(gm), cos(gm))
		for e: Vector3 in [a, b]:
			if mund.distance_to(Vector2(e.x, e.z)) < 1.5:
				an_abgang = true
		im += 8
	for ab: Array in abschnitte:
		var s0: float = ab[0]
		var s1: float = ab[1]
		var y0: float = ab[2]
		var y1: float = ab[3]
		if s1 - s0 < 0.01:
			continue
		# Boden oder Stufen
		if absf(y1 - y0) < 0.01:
			_klotz(mat_boden, ca, u, n, s0 - 0.02, s1 + 0.02, -breite / 2.0, breite / 2.0, y0 - 0.5, y0)
		else:
			_stufen(ca, u, n, s0, s1, y0, y1, breite, "hell" if art == 0 else mat_boden, mat_boden)
		# Hülle, in Stücken von höchstens 1 m (der Fels wird unregelmäßig)
		var stuecke := maxi(1, int(ceil((s1 - s0) / 0.9)))
		for i in stuecke:
			var t0 := float(i) / stuecke
			var t1 := float(i + 1) / stuecke
			var sa := lerpf(s0, s1, t0)
			var sb := lerpf(s0, s1, t1)
			var ya := lerpf(y0, y1, t0)
			var yb := lerpf(y0, y1, t1)
			for k in profil.size() - 1:
				var pa := _gangpunkt(ca, u, n, sa, ya, profil[k], art, lang)
				var pb := _gangpunkt(ca, u, n, sb, yb, profil[k], art, lang)
				var pc := _gangpunkt(ca, u, n, sb, yb, profil[k + 1], art, lang)
				var pd := _gangpunkt(ca, u, n, sa, ya, profil[k + 1], art, lang)
				var mitte_q := (profil[k] + profil[k + 1]) / 2.0
				var wh := maxf(hoehe - breite / 2.0, 1.2) if art != 3 else hoehe - 0.01
				var innen := Vector3(-n.x * mitte_q.x, wh - mitte_q.y if mitte_q.y > wh else 0.0, -n.y * mitte_q.x)
				if art == 3 and mitte_q.y > wh:
					innen = Vector3.DOWN
				var mat := mat_bogen if mitte_q.y > wh + 0.01 else mat_wand
				_viereck(mat, pa, pb, pc, pd, innen)
		# Deckel (Schatten); nicht über der Treppe eines Abgangs, die beginnt an der Oberfläche
		var dy := maxf(y0, y1)
		if not an_abgang:
			_klotz("fels", ca, u, n, s0, s1, -breite / 2.0 - 0.4, breite / 2.0 + 0.4, dy + hoehe + 0.6, dy + hoehe + 1.0, true)
	# Deckenbalken aus Stein im Gang mit flacher Decke
	if art == 3:
		var s := 0.6
		while s < lang - 0.3:
			var y := _gangboden(abschnitte, s)
			_klotz("hell", ca + u * s, u, n, -0.2, 0.2, -breite / 2.0, breite / 2.0, y + hoehe - 0.18, y + hoehe, true)
			s += 1.2
	# Gurtbögen im gemauerten Gang alle 3 m
	elif art != 1:
		var s := 2.0
		while s < lang - 1.5:
			var y := _gangboden(abschnitte, s)
			var pkt: Array[Vector3] = []
			var inn: Array[Vector3] = []
			var hb := breite / 2.0
			var wh := maxf(hoehe - hb, 1.2)
			for k in 11:
				var an := PI - PI * k / 10.0
				var q := hb * cos(an)
				pkt.append(_p(ca, u, n, s, q, y + wh + hb * sin(an)))
				inn.append(-(Vector3(n.x, 0, n.y) * cos(an) + Vector3.UP * sin(an)))
			_band("hell" if art == 0 else "bruchstein", pkt, inn, 0.3, 0.08)
			s += 3.0
	# Enden ohne Anschluss zumauern
	for ende in 2:
		var p := a if ende == 0 else b
		if not _ende_offen(p, index):
			var s := 0.0 if ende == 0 else lang
			var dicke := 0.4 * (1.0 if ende == 1 else -1.0)
			_klotz(mat_wand, ca, u, n, minf(s, s + dicke), maxf(s, s + dicke), -breite / 2.0 - 0.1, breite / 2.0 + 0.1, p.y - 0.6, p.y + hoehe + 0.2)
	if not fackeln and art == 2:
		# alte Gänge: nur ein fahler Schein (wie durch Risse im Fels)
		var s := 4.0
		while s < lang - 2.0:
			var y := _gangboden(abschnitte, s)
			_licht(Vector3(ca.x + u.x * s, y + hoehe - 0.4, ca.y + u.y * s), LICHT_KALT, 0.22, 7.0, false)
			s += 10.0
	if fackeln:
		var s := 2.5
		var seite := 1.0
		while s < lang - 1.0:
			var y := _gangboden(abschnitte, s)
			_fackel(ca + u * s + n * seite * breite / 2.0, -n * seite, y + 1.9, false)
			s += 9.0
			seite = -seite
	if not an_abgang:
		_sonde(Vector3((a.x + b.x) / 2.0, (a.y + b.y) / 2.0 + hoehe / 2.0, (a.z + b.z) / 2.0), u,
			Vector3(breite + 0.6, absf(b.y - a.y) + hoehe + 1.0, lang + 0.4), false)


## Boden eines Gangs bei s (über die Abschnitte)
static func _gangboden(abschnitte: Array, s: float) -> float:
	for ab: Array in abschnitte:
		if s >= float(ab[0]) - 0.001 and s <= float(ab[1]) + 0.001:
			var t := (s - float(ab[0])) / maxf(float(ab[1]) - float(ab[0]), 0.001)
			return lerpf(float(ab[2]), float(ab[3]), t)
	return float(abschnitte[-1][3])


## Punkt der Ganghülle; im Fels unregelmäßig (an den Enden glatt, damit er an Räume und Gänge anschließt)
func _gangpunkt(ca: Vector2, u: Vector2, n: Vector2, s: float, y: float, q: Vector2, art: int, lang: float) -> Vector3:
	var p := _p(ca, u, n, s, q.x, y + q.y)
	if art == 0 or q.y < 0.0:
		return p
	var rand_ := clampf(minf(s, lang - s) / 1.2, 0.0, 1.0)
	var z := _h01(Vector2(p.x * 1.31 + p.y * 0.7, p.z * 1.17 - p.y * 0.3)) - 0.5
	var z2 := _h01(Vector2(p.z * 0.43 + 3.1, p.x * 0.37 - p.y)) - 0.5
	var staerke := (0.22 if art == 1 else 0.07) * rand_
	var aussen := Vector3(n.x * signf(q.x), 0, n.y * signf(q.x)) * absf(q.x) + Vector3.UP * maxf(q.y - 1.0, 0.0)
	# nur nach außen ausbuchten: der Gang bleibt so breit wie angegeben
	return p + aussen.normalized() * maxf(z + z2 * 0.6 + 0.35, 0.0) * staerke * 1.6


## Treppe in einem Gang von s0 bis s1 (Boden y0 nach y1); gebaut immer von unten nach oben
func _stufen(ca: Vector2, u: Vector2, n: Vector2, s0: float, s1: float, y0: float, y1: float, breite: float, mat_kante: String,
		mat: String) -> void:
	var unten_s := s0 if y0 < y1 else s1
	var oben_s := s1 if y0 < y1 else s0
	var y_u := minf(y0, y1)
	var y_o := maxf(y0, y1)
	var richt := signf(oben_s - unten_s)
	var lauf := absf(oben_s - unten_s)
	var anzahl := maxi(1, int(round((y_o - y_u) / STUFE)))
	var steig := (y_o - y_u) / anzahl
	var tritt := lauf / anzahl
	var hb := breite / 2.0
	for k in anzahl:
		var a := unten_s + richt * k * tritt
		var e := unten_s + richt * (k + 1) * tritt
		var y := y_u + (k + 1) * steig
		_klotz(mat, ca, u, n, minf(a, e) - 0.02, maxf(a, e) + 0.02, -hb, hb, y - 0.5 - steig, y)
		_klotz(mat_kante, ca + u * a, u, n, -0.06, 0.06, -hb, hb, y - steig * 0.9, y - 0.01)
	# Lauffläche über den Stufenkanten
	var r0 := unten_s - richt * tritt
	var r1 := oben_s - richt * tritt
	_viereck("rampe", _p(ca, u, n, r0, -hb, y_u + 0.03), _p(ca, u, n, r1, -hb, y_o + 0.03), _p(ca, u, n, r1, hb, y_o + 0.03),
		_p(ca, u, n, r0, hb, y_u + 0.03), Vector3.UP)
	_viereck("rampe", _p(ca, u, n, r1, -hb, y_o + 0.03), _p(ca, u, n, oben_s, -hb, y_o + 0.03), _p(ca, u, n, oben_s, hb, y_o + 0.03),
		_p(ca, u, n, r1, hb, y_o + 0.03), Vector3.UP)


# ---------- Abgänge ----------

func _abgang(w: PackedFloat32Array, regel_: String) -> void:
	var c := Vector2(w[0], w[1])
	var ach := _achsen(w[2])
	var u := ach[0]
	var n := ach[1]
	var boden := w[3]
	var bi := w[4] / 2.0 + 0.06       # halbe Breite innen (knapp hinter den Wänden des Gangs)
	var li := w[5]
	var t := 0.5
	var traufe := boden + 3.3
	var ueber := 0.35
	var halb_aussen := bi + t + ueber
	var first := traufe + halb_aussen * 0.85
	var gang_b := w[4]
	# Gang an der Schwelle finden (Breite und Höhe der Tür)
	var tuer_h := 2.8
	var i := 0
	while i + 9 < gaenge.size():
		for k: int in [0, 3]:
			if Vector2(gaenge[i + k], gaenge[i + k + 2]).distance_to(c) < 0.4:
				gang_b = gaenge[i + 6]
				tuer_h = gaenge[i + 7]
		i += 10
	var tb := gang_b / 2.0
	var tk := boden + maxf(tuer_h - tb, 1.2)
	# Wände: vorn mit der Tür (Rundbogen), hinten über dem Gang, seitlich tief in den Boden
	_klotz_mit_loechern("bruchstein", c, n, u, -bi - t, bi + t, -t, 0.0, boden - 1.2, traufe, [Rect2(-tb - 0.02, boden, gang_b + 0.04, tuer_h + 0.03)])
	for s: float in [-1.0, 1.0]:
		var a0 := s * bi
		var a1 := s * (bi + t)
		_klotz("bruchstein", c, u, n, -t, li + t, minf(a0, a1), maxf(a0, a1), boden - 3.0, traufe)
	_klotz("bruchstein", c, u, n, li, li + t, -bi, bi, boden - 0.4, traufe)
	# Sockel außen und Eckquader
	for s_: float in [-1.0, 1.0]:
		_klotz("hell", c, u, n, -t - 0.08, li + t + 0.08, minf(s_ * bi, s_ * (bi + t + 0.08)), maxf(s_ * bi, s_ * (bi + t + 0.08)),
			boden - 0.3, boden + 0.35)
	_klotz("hell", c, u, n, li, li + t + 0.08, -bi, bi, boden - 0.3, boden + 0.35)
	_klotz("hell", c, n, u, -bi - t - 0.08, -tb - 0.02, -t - 0.08, 0.0, boden - 0.3, boden + 0.35)
	_klotz("hell", c, n, u, tb + 0.02, bi + t + 0.08, -t - 0.08, 0.0, boden - 0.3, boden + 0.35)
	for su: float in [-t, li + t]:
		for s: float in [-1.0, 1.0]:
			var e := s * (bi + t)
			_klotz("hell", c, u, n, su - 0.3, su + 0.3, e - 0.3, e + 0.3, boden + 0.35, traufe, false)
	# Rundbogen über der Tür (außen) mit Zwickeln, Bogensteine
	var teile := 12
	for k in teile:
		var w0 := PI * k / teile
		var w1 := PI * (k + 1) / teile
		var r0 := tb + 0.02
		var r1 := tb + 0.32
		var p := func(q: float, y: float, s_: float) -> Vector3:
			return _p(c, u, n, s_, q, y)
		_viereck("bruchstein", p.call(r0 * cos(w0), tk + r0 * sin(w0), -t), p.call(r0 * cos(w1), tk + r0 * sin(w1), -t),
			p.call(r0 * cos(w1), boden + tuer_h + 0.05, -t), p.call(r0 * cos(w0), boden + tuer_h + 0.05, -t), -Vector3(u.x, 0, u.y))
		_viereck("hell", p.call(r0 * cos(w0), tk + r0 * sin(w0), -t - 0.06), p.call(r0 * cos(w1), tk + r0 * sin(w1), -t - 0.06),
			p.call(r1 * cos(w1), tk + r1 * sin(w1), -t - 0.06), p.call(r1 * cos(w0), tk + r1 * sin(w0), -t - 0.06), -Vector3(u.x, 0, u.y))
		_viereck("hell", p.call(r1 * cos(w0), tk + r1 * sin(w0), -t - 0.06), p.call(r1 * cos(w1), tk + r1 * sin(w1), -t - 0.06),
			p.call(r1 * cos(w1), tk + r1 * sin(w1), -t), p.call(r1 * cos(w0), tk + r1 * sin(w0), -t),
			Vector3(n.x, 0, n.y) * cos((w0 + w1) / 2.0) + Vector3.UP * sin((w0 + w1) / 2.0))
	for s: float in [-1.0, 1.0]:
		_klotz("hell", c, u, n, -t - 0.06, -t + 0.02, s * tb - 0.15, s * tb + 0.15, boden, tk, false)
	# Giebel und Satteldach (First entlang u)
	for su: float in [-t, li + t]:
		var aussen := -Vector3(u.x, 0, u.y) if su < 0.0 else Vector3(u.x, 0, u.y)
		_dreieck("bruchstein", _p(c, u, n, su, -bi - t, traufe), _p(c, u, n, su, bi + t, traufe), _p(c, u, n, su, 0.0, first - 0.15), aussen)
	for s: float in [-1.0, 1.0]:
		var e := _p(c, u, n, -t - ueber, s * halb_aussen, traufe - ueber * 0.85)
		var f := _p(c, u, n, li + t + ueber, s * halb_aussen, traufe - ueber * 0.85)
		var g := _p(c, u, n, li + t + ueber, 0.0, first)
		var h := _p(c, u, n, -t - ueber, 0.0, first)
		var schraeg := Vector2(halb_aussen, first - traufe + ueber * 0.85).length()
		var aussen := (Vector3(n.x, 0, n.y) * s * (first - traufe) + Vector3.UP * halb_aussen).normalized()
		_viereck_uv("dach", [e, f, g, h], [Vector2(0, schraeg), Vector2(li + 2 * (t + ueber), schraeg), Vector2(li + 2 * (t + ueber), 0), Vector2(0, 0)], aussen)
		_viereck("holz", e - Vector3.UP * 0.08, f - Vector3.UP * 0.08, g - Vector3.UP * 0.08, h - Vector3.UP * 0.08, -aussen)
		_klotz("holz", c, u, n, -t - ueber, li + t + ueber, s * halb_aussen - 0.08, s * halb_aussen + 0.08, traufe - ueber * 0.85 - 0.16, traufe - ueber * 0.85 + 0.02)
	_klotz("hell", c, u, n, -t - ueber - 0.05, li + t + ueber + 0.05, -0.12, 0.12, first - 0.02, first + 0.14)
	# Tür in der Laibung (Rundbogen), geht nach innen auf
	var tuer := Fluegel.new()
	var teile_regel := regel_.split(":")
	tuer.regel = teile_regel[0]
	tuer.bedingung = teile_regel[1] if teile_regel.size() > 1 else ""
	tuer.breite = gang_b - 0.06
	tuer.kaempfer = tk - boden
	tuer.anzahl = 1
	tuer.staerke = 0.08
	tuer.winkel_offen = 95.0
	tuer.reichweite = 2.2
	tuer.anzeige_name = "Die Tür"
	tuer.mat_holz = _material("holz")
	tuer.mat_metall = _material("metall")
	_setze(tuer, c - u * (t * 0.5), boden, n, u)
	# Laterne über der Tür
	var lw := c - u * (t + 0.02)
	_klotz("metall", lw, n, -u, -0.03, 0.03, 0.0, 0.35, boden + tuer_h + 0.75, boden + tuer_h + 0.8)
	_klotz("metall", lw - u * 0.35, n, -u, -0.1, 0.1, -0.1, 0.1, boden + tuer_h + 0.38, boden + tuer_h + 0.42)
	_klotz("glut", lw - u * 0.35, n, -u, -0.08, 0.08, -0.08, 0.08, boden + tuer_h + 0.42, boden + tuer_h + 0.66)
	_klotz("metall", lw - u * 0.35, n, -u, -0.11, 0.11, -0.11, 0.11, boden + tuer_h + 0.66, boden + tuer_h + 0.72)
