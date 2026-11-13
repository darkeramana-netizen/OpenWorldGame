@tool
extends Node3D
class_name Fluegel
## Bewegliche Tür- und Torflügel aus Bohlen mit Eisenbändern, Querleisten und Strebe.
##
## Lokal: x entlang der Mauer, y nach oben, z zeigt in die Seite, nach der die Flügel aufgehen (Hof, Rauminneres).
## Der Ursprung liegt in der Mitte der Öffnung auf Bodenhöhe, in der Ebene der geschlossenen Flügel. Ein Türblatt ist
## bei -x angeschlagen; zwei Torflügel sind bei -x und +x angeschlagen und treffen sich in der Mitte.
##
## Regeln (regel):
## - "tuer": geht auf, wenn jemand herankommt (Spieler oder eine gehende Person), und fällt danach wieder zu.
## - "tag": tagsüber offen; nachts (ab 20 Uhr bis zum Morgengrauen) und bei Alarm schließen die Wachen. Dann öffnen
##   sie nur Leuten der Burg und dem Spieler, wenn für ihn die Bedingung gilt.
## - "zu": immer zu; die Wache öffnet Leuten der Burg und dem Spieler, wenn für ihn die Bedingung gilt.
## - "offen": steht offen.
## Geschlossen hält der Flügel auf (Kollision); während er sich bewegt und solange er offen ist, nicht.

@export var breite := 1.6
## Höhe einer rechteckigen Öffnung
@export var hoehe := 2.7
## > 0: Rundbogen, der in dieser Höhe ansetzt (Scheitel = kaempfer + breite / 2)
@export var kaempfer := 0.0
@export var anzahl := 1
## So viel größer als die Öffnung (Torflügel hinter dem Bogen decken die Öffnung von innen ab)
@export var ueberstand := 0.0
@export var staerke := 0.1
@export var winkel_offen := 90.0
@export var regel := "tuer"
## Pruefbedingung wie in den Dialogen (_stand().pruefe_bedingung), z. B. "eid_waechter"
@export var bedingung := ""
@export var anzeige_name := "Tor"
## So nah muss jemand kommen, damit geöffnet wird (waagrecht gemessen)
@export var reichweite := 2.2
@export var mat_holz: Material
@export var mat_metall: Material

var aktion_text := "Um Einlass bitten"

static var _lokal := {}

var _auf := 0.0
var _ziel := 0.0
var _pruef := 0.0
var _zuletzt := -100.0
var _drehpunkte: Array[Node3D] = []
var _seiten: Array[float] = []
var _formen: Array[CollisionShape3D] = []
var _war_grund_offen := true
var _hat_gemeldet := false


func _ready() -> void:
	_baue()
	if regel == "offen" or Engine.is_editor_hint():
		_auf = 1.0 if regel == "offen" else 0.0
	else:
		_auf = 1.0 if _grund_offen() else 0.0
		_war_grund_offen = _auf > 0.5
	_ziel = _auf
	_stelle()


## Halber Rundbogen (mit Überstand) oder rechteckige Höhe an der Stelle x (Mitte der Öffnung = 0)
func _oben_bei(x: float) -> float:
	var r := breite / 2.0 + ueberstand
	if kaempfer > 0.0:
		return kaempfer + sqrt(maxf(r * r - x * x, 0.0))
	return hoehe + ueberstand


func _baue() -> void:
	for k in get_children():
		k.free()
	_drehpunkte.clear()
	_seiten.clear()
	_formen.clear()
	var r := breite / 2.0 + ueberstand
	var seiten: Array[float] = [-1.0]
	if anzahl > 1:
		seiten.append(1.0)
	for s in seiten:
		var dreh := Node3D.new()
		dreh.position = Vector3(s * r, 0.0, 0.0)
		add_child(dreh)
		_drehpunkte.append(dreh)
		_seiten.append(s)
		var laenge := (2.0 * r - 0.02) if anzahl <= 1 else (r - 0.01)
		var holz := SurfaceTool.new()
		var eisen := SurfaceTool.new()
		holz.begin(Mesh.PRIMITIVE_TRIANGLES)
		eisen.begin(Mesh.PRIMITIVE_TRIANGLES)
		# lx: Abstand vom Angelpunkt; die Öffnung hat dort x = s * r - s * lx
		var oben := func(lx: float) -> float:
			return _oben_bei(s * r - s * lx) - 0.02
		var h := staerke / 2.0
		# Senkrechte Bohlen, oben dem Bogen nach geschnitten
		var bohlen := maxi(2, int(round(laenge / 0.28)))
		for k in bohlen:
			var a := laenge * k / bohlen + 0.006
			var b := laenge * (k + 1) / bohlen - 0.006
			_prisma(holz, s, a, b, 0.03, oben.call(a), oben.call(b), -h, h)
		var hoch_min: float = oben.call(laenge)
		# Feldseite (-z): drei Eisenbänder, zur Mitte hin kürzer, damit sie unter dem Bogen bleiben
		for f: float in [0.12, 0.5, 0.82]:
			var y := 0.03 + (minf(oben.call(0.0), oben.call(laenge)) - 0.03) * f
			var ende := laenge * 0.88
			while ende > 0.2 and oben.call(ende) < y + 0.2:
				ende -= 0.05
			_prisma(eisen, s, 0.02, ende, y, y + 0.09, y + 0.09, -h - 0.018, -h)
			_prisma(eisen, s, 0.0, 0.06, y - 0.03, y + 0.12, y + 0.12, -h - 0.03, h + 0.03)   # Angel
		# Innenseite (+z): zwei Querleisten und eine Strebe dazwischen
		var unten_l := 0.35
		var oben_l: float = minf(hoch_min, oben.call(0.0)) - 0.45
		for y: float in [unten_l, oben_l]:
			_prisma(holz, s, 0.08, laenge - 0.08, y - 0.1, y + 0.1, y + 0.1, h, h + 0.05)
		_strebe(holz, s, Vector2(laenge - 0.15, unten_l + 0.1), Vector2(0.15, oben_l - 0.1), 0.16, h, h + 0.05)
		# Ring als Griff
		_prisma(eisen, s, laenge - 0.32, laenge - 0.22, 1.05, 1.17, 1.17, h + 0.05, h + 0.09)
		var mesh := ArrayMesh.new()
		for paar: Array in [[holz, _lokal_mat(mat_holz)], [eisen, _lokal_mat(mat_metall)]]:
			var st: SurfaceTool = paar[0]
			st.generate_normals()
			st.commit(mesh)
			if paar[1] != null:
				mesh.surface_set_material(mesh.get_surface_count() - 1, paar[1])
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		dreh.add_child(mi)
		# Kollision: ein Kasten über das ganze Blatt
		var hmax: float = maxf(oben.call(0.0), oben.call(laenge))
		var koerper := StaticBody3D.new()
		var form := CollisionShape3D.new()
		var kasten := BoxShape3D.new()
		kasten.size = Vector3(laenge, hmax, staerke + 0.06)
		form.shape = kasten
		form.position = Vector3(-s * laenge / 2.0, hmax / 2.0, 0.0)
		koerper.add_child(form)
		dreh.add_child(koerper)
		_formen.append(form)


## Holz und Eisen bewegen sich mit: Die Texturen hängen am Flügel, nicht an der Welt (sonst rutschen sie beim Drehen)
func _lokal_mat(m: Material) -> Material:
	if m == null:
		return null
	if not _lokal.has(m):
		var k: Material = m.duplicate()
		if k is BaseMaterial3D:
			(k as BaseMaterial3D).uv1_world_triplanar = false
		_lokal[m] = k
	return _lokal[m]


## Prisma im Flügel: lx von a bis b (vom Angelpunkt weg in Richtung -s · x), unten y0, oben schräg von ya bis yb,
## Dicke z0 bis z1
func _prisma(st: SurfaceTool, s: float, a: float, b: float, y0: float, ya: float, yb: float, z0: float, z1: float) -> void:
	if b - a < 0.005 or minf(ya, yb) - y0 < 0.005:
		return
	var p := func(lx: float, y: float, z: float) -> Vector3:
		return Vector3(-s * lx, y, z)
	var e := [p.call(a, y0, z0), p.call(b, y0, z0), p.call(b, yb, z0), p.call(a, ya, z0),
		p.call(a, y0, z1), p.call(b, y0, z1), p.call(b, yb, z1), p.call(a, ya, z1)]
	var mitte := Vector3(-s * (a + b) / 2.0, (y0 + (ya + yb) / 2.0) / 2.0, (z0 + z1) / 2.0)
	for f: Array in [[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0]]:
		_viereck(st, e[f[0]], e[f[1]], e[f[2]], e[f[3]], mitte)


## Schräge Leiste von a nach b (in lx, y), Breite quer zur Richtung
func _strebe(st: SurfaceTool, s: float, a: Vector2, b: Vector2, breite_: float, z0: float, z1: float) -> void:
	var d := (b - a).normalized()
	var q := Vector2(-d.y, d.x) * breite_ / 2.0
	var p := func(v: Vector2, z: float) -> Vector3:
		return Vector3(-s * v.x, v.y, z)
	var e := [p.call(a - q, z0), p.call(b - q, z0), p.call(b + q, z0), p.call(a + q, z0),
		p.call(a - q, z1), p.call(b - q, z1), p.call(b + q, z1), p.call(a + q, z1)]
	var mitte: Vector3 = (p.call(a, z0) + p.call(b, z1)) / 2.0
	for f: Array in [[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0]]:
		_viereck(st, e[f[0]], e[f[1]], e[f[2]], e[f[3]], mitte)


## Viereck, die Vorderseite zeigt vom Punkt innen weg (Godot: Vorderseite im Uhrzeigersinn)
func _viereck(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, innen: Vector3) -> void:
	var normale := (b - a).cross(c - a)
	if normale.length_squared() < 1e-12:
		normale = (c - a).cross(d - a)
	var aussen := (a + b + c + d) / 4.0 - innen
	var reihe := [a, b, c, a, c, d] if normale.dot(aussen) < 0.0 else [a, c, b, a, d, c]
	for v: Vector3 in reihe:
		st.add_vertex(v)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or regel == "offen":
		return
	_pruef -= delta
	if _pruef <= 0.0:
		_pruef = 0.25
		_entscheide()
	if not is_equal_approx(_auf, _ziel):
		var dauer := 0.9 if regel == "tuer" else 3.5
		_auf = move_toward(_auf, _ziel, delta / dauer)
		_stelle()


func _entscheide() -> void:
	var jetzt := Time.get_ticks_msec() / 1000.0
	var grund := _grund_offen()
	var sp := get_tree().get_first_node_in_group("spieler") as Node3D
	var spieler_nah := sp != null and _nah(sp, reichweite)
	if _jemand_kommt(sp, spieler_nah):
		_zuletzt = jetzt
	var offen := grund or jetzt - _zuletzt < (2.0 if regel == "tuer" else 6.0)
	# Die Wachen schließen bei Einbruch der Nacht; wer in der Nähe ist, bekommt es mit
	if _war_grund_offen and not grund and sp != null and _nah(sp, 30.0):
		if _stand().alarmstufe >= 2:
			_stand().meldung.emit("Alarm! Die Torwachen schließen %s." % _mit_artikel())
		else:
			_stand().meldung.emit("Die Torwachen schließen %s für die Nacht." % _mit_artikel())
	_war_grund_offen = grund
	# Die Wache öffnet dem, der hinein darf
	if not grund and spieler_nah and _spieler_darf() and regel != "tuer" and not _hat_gemeldet:
		_stand().meldung.emit("Die Torwache erkennt dich und öffnet %s." % _mit_artikel())
		_hat_gemeldet = true
	if not spieler_nah:
		_hat_gemeldet = false
	_ziel = 1.0 if offen else 0.0
	var ansprechbar := regel != "tuer" and not offen and not _spieler_darf()
	if ansprechbar and not is_in_group("interagierbar"):
		add_to_group("interagierbar")
	elif not ansprechbar and is_in_group("interagierbar"):
		remove_from_group("interagierbar")


## Spielstand und Spielzeit über den Baum (nicht über ihre Namen): So lässt sich das Skript auch übersetzen, bevor es
## die Autoloads gibt (z. B. wenn ein Testskript die Klasse Fluegel kennt).
func _stand() -> Node:
	return get_tree().root.get_node("Spielstand")


func _zeit() -> Node:
	return get_tree().root.get_node("Spielzeit")


func _mit_artikel() -> String:
	return "die Pforte" if "Pforte" in anzeige_name else "das Tor"


func _grund_offen() -> bool:
	match regel:
		"offen":
			return true
		"tag":
			return _zeit().abschnitt != &"nacht" and _stand().alarmstufe < 2
	return false


func _spieler_darf() -> bool:
	return regel == "tuer" or (bedingung != "" and _stand().pruefe_bedingung(bedingung))


func _nah(k: Node3D, weite: float) -> bool:
	var d := k.global_position - global_position
	return absf(d.y) < 3.0 and Vector2(d.x, d.z).length() < weite


## Kommt jemand, dem geöffnet wird? Der Spieler, wenn er darf; Leute der Burg, wenn sie gehen (wer still daneben
## steht, wie die Torwache, hält das Tor nicht offen).
func _jemand_kommt(sp: Node3D, spieler_nah: bool) -> bool:
	if spieler_nah and _spieler_darf():
		return true
	for p: Node3D in get_tree().get_nodes_in_group("personen"):
		if p.visible and p.has_method("unterwegs") and p.unterwegs() and _nah(p, reichweite):
			return true
	return false


func _stelle() -> void:
	var t := _auf * _auf * (3.0 - 2.0 * _auf)
	for i in _drehpunkte.size():
		_drehpunkte[i].rotation.y = deg_to_rad(_seiten[i] * winkel_offen * t)
	for f in _formen:
		f.disabled = _auf > 0.02


func ist_offen() -> bool:
	return _auf > 0.98


func interagieren(_spieler: Node3D) -> void:
	if regel == "tag" and _stand().alarmstufe >= 2:
		_stand().meldung.emit("Wegen des Alarms bleibt %s zu. Die Torwache lässt nur Ordensleute ein." % _mit_artikel())
	elif regel == "tag":
		_stand().meldung.emit("Nachts bleibt %s zu. Die Torwache lässt nur Ordensleute ein." % _mit_artikel())
	else:
		_stand().meldung.emit("Die Torwache lässt dich nicht durch %s. Weiter dürfen nur Ordensleute." % _mit_artikel())
