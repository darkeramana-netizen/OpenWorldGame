@tool
extends Node3D
## Bürgerhäuser einer Stadt: Fachwerk über steinernem Erdgeschoss, vorkragende Obergeschosse, steile
## Satteldächer mit Überstand, Fenster, Türen und Schornsteine. Es gibt 24 Hausformen; jede wird einmal
## gebaut und dann als MultiMesh vielfach gezeichnet (das ist schnell). Jedes Haus hat eine Kollisionsbox.
## Die Bauskripte (werkzeuge/bau/teil_drachenstein.py) legen fest, wo welches Haus steht.
## Ein Haus: Ort (x, y, z) ist die Mitte der Grundfläche auf Höhe des Erdgeschossbodens, die Vorderseite
## mit der Tür zeigt nach lokal +z, zur Straße.

## Schattenhülle (eine Oberfläche je Bau, nur für den Sonnenschatten)
const Schattenhuelle := preload("res://szenen/welt/schattenhuelle.gd")
const Baucache := preload("res://szenen/welt/baucache.gd")
const Verdecker := preload("res://szenen/welt/verdecker.gd")

## Je Haus (x, y, z, Gier in Grad)
@export var haeuser: PackedVector4Array = PackedVector4Array():
	set(wert):
		haeuser = wert
		if is_inside_tree():
			_baue()
## Nur Ziegeldächer (die Hofhäuser der Burgfeste wie im Referenzbild: warm braunrot statt Schiefer)
@export var nur_ziegel := false:
	set(wert):
		nur_ziegel = wert
		if is_inside_tree():
			_baue()
## Fachwerk statt Stein und Putz (Stil 2 wird Fachwerk über Stein, Stil 3 Fachwerk über Putz), wie im Referenzbild
@export var nur_fachwerk := false:
	set(wert):
		nur_fachwerk = wert
		if is_inside_tree():
			_baue()
## Begehbar: die Häuser sind hohl (Mauern mit offener Tür, Dielenböden je Geschoss, Treppen auf wechselnden Seiten mit
## Deckenloch und Geländer, Fensterlicht innen, ein Licht je Geschoss); die Kollision folgt der Form. Die Einrichtung
## setzt ein eigener Knoten (burgbau.gd, raeume), dessen Lage hausplan() liefert.
@export var begehbar := false:
	set(wert):
		begehbar = wert
		if is_inside_tree():
			_baue()
## Je Haus die Nummer der Form (0 bis 23)
@export var formen: PackedInt32Array = PackedInt32Array():
	set(wert):
		formen = wert
		if is_inside_tree():
			_baue()

const EG := 3.2            # Höhe Erdgeschoss
const OG := 2.8            # Höhe Obergeschoss
const VORKRAGUNG := 0.35   # so weit steht jedes Fachwerkgeschoss vor
const DACHNEIGUNG := 52.0
const VARIANTEN := 3       # Ausstattungen je Hausform
const SOCKEL_TIEFE := 7.0  # Mauern reichen so weit hinunter (Hanglage)
const WAND := 0.3          # Mauerstärke begehbarer Häuser
const TREPPE_B := 1.0      # Breite der Treppen
## Kachelgröße der MultiMeshes in m (0: eins je Form über die ganze Stadt)
const KACHEL := 128.0

## Formen: [Breite, Tiefe, Obergeschosse, Stil, Giebel zur Straße, Putzfarbe, Dach]
## Stil 0 Fachwerk über Stein, 1 Fachwerk über Putz, 2 ganz Stein, 3 verputzt mit Fensterläden
## Dach 0 Ziegel, 1 Schiefer
const FORMEN := [
	[6.5, 10.0, 2, 0, true, 0, 0], [7.5, 11.0, 2, 1, true, 1, 0], [9.0, 10.0, 1, 3, false, 2, 0],
	[6.0, 9.0, 3, 0, true, 0, 1], [8.0, 12.0, 2, 2, false, 0, 1], [7.0, 10.0, 3, 1, true, 2, 0],
	[9.5, 11.0, 2, 3, false, 1, 0], [6.5, 12.0, 1, 1, true, 0, 0], [8.5, 10.0, 3, 0, false, 1, 1],
	[7.0, 9.0, 2, 3, true, 0, 0], [10.0, 12.0, 2, 2, false, 2, 1], [6.0, 11.0, 2, 1, true, 1, 0],
	[7.5, 10.0, 1, 0, true, 2, 0], [8.0, 9.0, 2, 1, false, 0, 0], [6.5, 10.0, 3, 3, true, 1, 1],
	[9.0, 12.0, 3, 0, false, 2, 0], [7.0, 11.0, 2, 2, true, 0, 0], [8.5, 11.0, 1, 3, false, 1, 0],
	[6.0, 10.0, 2, 0, true, 1, 0], [7.5, 12.0, 3, 1, false, 0, 1], [9.0, 9.0, 2, 3, true, 2, 0],
	[6.5, 11.0, 2, 2, true, 1, 1], [8.0, 10.0, 3, 1, true, 0, 0], [10.0, 11.0, 2, 0, false, 2, 0],
	# kleine, schmale Häuser für die dicht bebauten Hinterhöfe
	[4.5, 7.0, 2, 1, true, 1, 0], [5.0, 8.0, 1, 0, true, 0, 0], [5.5, 7.5, 2, 3, false, 2, 0], [4.5, 8.0, 2, 0, true, 2, 0],
	[5.0, 7.0, 3, 1, true, 0, 0], [5.5, 8.5, 1, 3, true, 1, 0], [4.8, 7.5, 2, 2, false, 0, 0], [5.2, 8.0, 2, 1, true, 2, 0],
]
const PUTZFARBEN := [Color(1.0, 0.97, 0.9), Color(0.98, 0.86, 0.66), Color(0.92, 0.8, 0.78)]

static var _mesh_cache := {}
static var _schornsteine := {}   # Form → Oberkante des Schornsteins (lokal), für den Rauch
static var _mat_cache := {}
static var _form_cache := {}
static var _huellen_cache := {}     # Schlüssel → Schattenhülle (eine Oberfläche, nur Schatten)


func _ready() -> void:
	_baue()


func _baue() -> void:
	for k in get_children():
		k.free()
	if haeuser.is_empty():
		return
	# Beim zweiten Start nur laden statt bauen (szenen/welt/baucache.gd)
	var schl := Baucache.schluessel(self) if Baucache.an(self) else ""
	if schl != "" and Baucache.lade(self, schl, _material):
		_verdecker()
		return
	_baue_neu()
	if schl != "":
		Baucache.speichere(self, schl)
	_verdecker()


## Verdecker für die Verdeckungsprüfung (szenen/welt/verdecker.gd): je Haus ein Quader innerhalb der Mauern, vom
## Erdgeschoss bis unter die Traufe (ohne Dach). Begehbare Häuser bekommen keinen (von innen sieht man hinaus).
func _verdecker() -> void:
	if begehbar or Engine.is_editor_hint():
		return
	var ecken := PackedVector3Array()
	var dreiecke := PackedInt32Array()
	for i in haeuser.size():
		var h: Vector4 = haeuser[i]
		var form: Array = FORMEN[formen[i] if i < formen.size() else i % FORMEN.size()]
		var hoehe: float = EG + OG * float(form[2]) - 0.3
		var t := Transform3D(Basis(Vector3.UP, deg_to_rad(h.w)), Vector3(h.x, h.y + 0.2 + hoehe * 0.5, h.z))
		Verdecker.quader(ecken, dreiecke, t, Vector3(float(form[0]) * 0.5 - 0.2, hoehe * 0.5, float(form[1]) * 0.5 - 0.2))
	var k := Verdecker.knoten(ecken, dreiecke)
	if k != null:
		add_child(k)


func _baue_neu() -> void:
	# je Hausform drei Ausstattungen (Balkon, Schild, Laterne, Gaube, Schornstein gewürfelt), je Haus eine davon
	# und je Kachel (KACHEL): ein MultiMesh über die ganze Stadt wäre fast immer irgendwo sichtbar und würde nie verdeckt
	var je_form := {}
	for i in haeuser.size():
		var f := formen[i] if i < formen.size() else i % FORMEN.size()
		var h: Vector4 = haeuser[i]
		var kx := floori(h.x / KACHEL) if KACHEL > 0.0 else 0
		var kz := floori(h.z / KACHEL) if KACHEL > 0.0 else 0
		je_form.get_or_add(Vector3i(f * VARIANTEN + (i * 7 + 3) % VARIANTEN, kx, kz), []).append(i)
	var koerper := StaticBody3D.new()
	koerper.name = "Kollision"
	add_child(koerper)
	for gruppe: Vector3i in je_form:
		var fv := gruppe.x
		var f := fv / VARIANTEN
		var mesh := _form_mesh(f, fv % VARIANTEN)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = je_form[gruppe].size()
		var form: Array = FORMEN[f]
		var kiste := BoxShape3D.new()
		kiste.size = Vector3(form[0] + 2 * VORKRAGUNG, EG + OG * form[2], form[1] + 2 * VORKRAGUNG)
		var lagen: Array[Transform3D] = []
		for k in je_form[gruppe].size():
			var h: Vector4 = haeuser[je_form[gruppe][k]]
			var t := Transform3D(Basis(Vector3.UP, deg_to_rad(h.w)), Vector3(h.x, h.y, h.z))
			mm.set_instance_transform(k, t)
			lagen.append(t)
			var form_k := CollisionShape3D.new()
			if begehbar:
				form_k.shape = _form_cache[_schluessel(f, fv % VARIANTEN)]
				form_k.transform = t
				# ein Licht je Geschoss, warm, ohne Schatten, in der Ferne ausgeblendet
				for g in int(form[2]) + 1:
					var licht := OmniLight3D.new()
					licht.position = t * Vector3(0, (0.0 if g == 0 else EG + OG * (g - 1)) + 2.1, 0)
					licht.light_color = Color(1.0, 0.8, 0.55)
					licht.light_energy = 0.9
					licht.omni_range = maxf(form[0], form[1]) * 0.75
					licht.distance_fade_enabled = true
					licht.distance_fade_begin = 28.0
					licht.distance_fade_length = 8.0
					add_child(licht)
			else:
				form_k.shape = kiste
				form_k.transform = t * Transform3D(Basis(), Vector3(0, kiste.size.y / 2.0, 0))
			koerper.add_child(form_k)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Form%d_%d_%d_%d" % [f, fv % VARIANTEN, gruppe.y, gruppe.z]
		mmi.multimesh = mm
		mmi.set_meta(Baucache.LAGEN, lagen)    # die Lagen gehören in die Daten (siehe baucache.gd)
		add_child(mmi)
		var huelle: ArrayMesh = _huellen_cache.get(_schluessel(f, fv % VARIANTEN))
		if huelle != null:
			add_child(Schattenhuelle.zwilling(mmi, huelle))
		# Rauch aus etwa jedem dritten Schornstein (dort brennt ein Herdfeuer)
		for k in je_form[gruppe].size():
			if je_form[gruppe][k] % 3 != 1:
				continue
			var h: Vector4 = haeuser[je_form[gruppe][k]]
			var t := Transform3D(Basis(Vector3.UP, deg_to_rad(h.w)), Vector3(h.x, h.y, h.z))
			add_child(Rauch.erzeuge(t * (_schornsteine[_schluessel(f, fv % VARIANTEN)] as Vector3)))


## Tür eines Hauses (für Wege): Weltpunkt vor der Tür.
static func tuer(h: Vector4, form: int) -> Vector3:
	var tiefe: float = FORMEN[form][1]
	return Vector3(h.x, h.y, h.z) + Basis(Vector3.UP, deg_to_rad(h.w)) * Vector3(0, 0, tiefe / 2.0 + 0.9)


# ---------- Ein Haus bauen ----------

## Schlüssel für die gemeinsamen Modelle: Form, Ausstattung und die Einstellungen dieses Knotens (sonst teilen sich
## Knoten mit verschiedenen Einstellungen dieselben Modelle)
func _schluessel(f: int, variante: int) -> int:
	return (f * VARIANTEN + variante) * 8 + (1 if nur_ziegel else 0) + (2 if nur_fachwerk else 0) + (4 if begehbar else 0)


## Lage der Treppen eines begehbaren Hauses der Form f (lokal): je Geschoss k (bis auf das oberste) [Seite (-1/+1),
## z am oberen Ende, z am Fuß, Boden unten, Steighöhe]. Die Treppen liegen abwechselnd an der linken und rechten
## Seitenwand: die geraden steigen von vorn nach hinten, die ungeraden von hinten nach vorn. So kommt man hinten an
## und geht an der Rückwand entlang zum Fuß der nächsten Treppe; die Mitte des Geschosses bleibt frei für Möbel.
static func treppen(f: int) -> Array:
	var form: Array = FORMEN[f]
	var t: float = form[1]
	var liste := []
	for k in int(form[2]):
		var r := EG if k == 0 else OG
		var lauf := r * 1.5
		var boden := 0.0 if k == 0 else EG + OG * (k - 1)
		if k % 2 == 0:
			var z_hoch := -t / 2.0 + WAND + 0.3
			liste.append([-1.0, z_hoch, z_hoch + lauf, boden, r])
		else:
			var z_fuss := -t / 2.0 + WAND + 1.0
			liste.append([1.0, z_fuss + lauf, z_fuss, boden, r])
	return liste


## Dach einer Hausform (Mängelliste M4): Schiefer, wo die Form ihn vorsieht (nicht bei nur_ziegel), sonst Ziegel in
## drei Tönungen je Variante (rotbraun, dunkel gealtert, heller orange), damit die Dächer nicht gleichförmig wirken.
func _dachmaterial(form: Array, variante: int) -> String:
	if not nur_ziegel and form[6] == 1:
		return "dach1"
	return ["dach0", "dach2", "dach3"][variante % 3]


func _form_mesh(f: int, variante := 0) -> ArrayMesh:
	# Die Einstellungen gehören in den Schlüssel, sonst teilen sich Knoten mit verschiedenen Einstellungen die Modelle
	var schluessel := _schluessel(f, variante)
	if _mesh_cache.has(schluessel):
		return _mesh_cache[schluessel]
	var form: Array = FORMEN[f]
	var b: float = form[0]
	var t: float = form[1]
	var og: int = form[2]
	var stil: int = form[3]
	if nur_fachwerk and stil >= 2:
		stil -= 2
	var giebelstaendig: bool = form[4]
	var zufall := RandomNumberGenerator.new()
	zufall.seed = 1750 + f + 977 * variante
	var flaechen := {}   # Material → SurfaceTool
	var fachwerk := stil == 0 or stil == 1
	var unten_mat := "quader" if stil in [0, 2] else "putz%d" % form[5]
	var oben_mat := "bruchstein" if stil == 2 else "putz%d" % form[5]

	# Erdgeschoss (reicht in den Hang hinunter)
	if begehbar:
		_quader(flaechen, unten_mat, Vector3(-b / 2, -SOCKEL_TIEFE, -t / 2), Vector3(b / 2, -0.12, t / 2))
		_hohl(flaechen, unten_mat, Vector3(-b / 2, -0.12, -t / 2), Vector3(b / 2, EG, t / 2), true)
		_boden(flaechen, f, 0, b, t, 0.0, 0.0)
	else:
		_quader(flaechen, unten_mat, Vector3(-b / 2, -SOCKEL_TIEFE, -t / 2), Vector3(b / 2, EG, t / 2))
	# Obergeschosse, im Fachwerk jeweils vorkragend
	var y := EG
	var aus := 0.0
	for g in og:
		if fachwerk:
			aus += VORKRAGUNG
		var lo := Vector3(-b / 2, y, -t / 2 - aus)
		var hi := Vector3(b / 2, y + OG, t / 2 + aus)
		if begehbar:
			_hohl(flaechen, oben_mat, lo, hi, false)
			_boden(flaechen, f, g + 1, b, t, y, aus)
		else:
			_quader(flaechen, oben_mat, lo, hi)
		if fachwerk:
			_fachwerk(flaechen, lo, hi)
			# Schwelle des vorkragenden Geschosses, darunter ein abgesetztes Füllholz und die Köpfe der Deckenbalken
			# (im begehbaren Haus nur als Kranz an den Außenwänden, sonst schlössen sie das Treppenloch)
			var innen := Rect2(-b / 2 + WAND, -t / 2 - aus + WAND, b - 2 * WAND, t + 2 * aus - 2 * WAND) if begehbar else Rect2()
			_kranz(flaechen, "balken", Vector3(-b / 2 - 0.05, y - 0.22, -t / 2 - aus - 0.05), Vector3(b / 2 + 0.05, y, t / 2 + aus + 0.05), innen)
			_kranz(flaechen, "balken", Vector3(-b / 2 - 0.02, y - 0.3, -t / 2 - aus - 0.01), Vector3(b / 2 + 0.02, y - 0.22, t / 2 + aus + 0.01), innen)
			var bx := -b / 2 + 0.3
			while bx < b / 2 - 0.2:
				for sz: int in [1, -1]:
					var z0 := (t / 2 + aus - VORKRAGUNG - 0.02) * sz
					var z1 := (t / 2 + aus + 0.03) * sz
					_quader(flaechen, "balken", Vector3(bx - 0.07, y - 0.46, minf(z0, z1)), Vector3(bx + 0.07, y - 0.3, maxf(z0, z1)))
				bx += 0.6
		y += OG
	var traufe := y
	var front := t / 2 + aus
	if begehbar:
		# Decke unter dem Dach, Treppen, Fensterlicht innen
		_quader(flaechen, "dielen", Vector3(-b / 2 + WAND, traufe - 0.25, -front + WAND), Vector3(b / 2 - WAND, traufe, front - WAND))
		for tr: Array in treppen(f):
			var sx: float = tr[0]
			var x0 := sx * (b / 2 - WAND - TREPPE_B)
			var x1 := sx * (b / 2 - WAND)
			var zh: float = tr[1]
			var zv: float = tr[2]
			var y0: float = tr[3]
			var r: float = tr[4]
			var n := int(ceil(r / 0.2))
			var tritt := (zv - zh) / n
			for i in n:
				var za := zv - tritt * (i + 1)
				var zb := zv - tritt * i
				_quader(flaechen, "balken", Vector3(minf(x0, x1), y0, minf(za, zb) - 0.01), Vector3(maxf(x0, x1), y0 + r * (i + 1) / n, maxf(za, zb) + 0.01))
			# unsichtbare Lauffläche über die Stufenkanten (nur Kollision): ein Tritt vor der ersten Stufe vom Boden
			# aus, durch alle Vorderkanten bis auf die oberste Stufe, dann eben bis an ihr Ende (zh: oberes Ende,
			# zv: Fuß; tritt zeigt vom oberen Ende zum Fuß)
			var rs := _st(flaechen, "rampe")
			var xa := minf(x0, x1)
			var xb := maxf(x0, x1)
			var z_vorn := zv + tritt
			_viereck(rs, Vector3(xa, y0 + 0.02, z_vorn), Vector3(xb, y0 + 0.02, z_vorn),
				Vector3(xb, y0 + r + 0.02, zh + tritt), Vector3(xa, y0 + r + 0.02, zh + tritt))
			_viereck(rs, Vector3(xa, y0 + r + 0.02, zh + tritt), Vector3(xb, y0 + r + 0.02, zh + tritt),
				Vector3(xb, y0 + r + 0.02, zh), Vector3(xa, y0 + r + 0.02, zh))
		for seite: int in [1, -1]:
			var anzahl := maxi(2, int(b / 2.3))
			for g in og + 1:
				var y0 := 0.9 if g == 0 else EG + OG * (g - 1) + 0.75
				var hf := 1.25 if g == 0 else 1.35
				var zi := (t / 2 + (VORKRAGUNG * g if fachwerk else 0.0) - WAND - 0.01) * seite
				for k in anzahl:
					var x := -b / 2 + b * (k + 0.5) / anzahl
					if g == 0 and seite == 1 and absf(x) < b / anzahl * 0.6:
						continue
					var fs := _st(flaechen, "fensterlicht")
					var a := Vector3(x - 0.4, y0, zi)
					var c_ := Vector3(x + 0.4, y0 + hf, zi)
					if seite == 1:
						_viereck(fs, Vector3(c_.x, a.y, zi), a, Vector3(a.x, c_.y, zi), c_)
					else:
						_viereck(fs, a, Vector3(c_.x, a.y, zi), c_, Vector3(a.x, c_.y, zi))
					# Rahmen, Sprossenkreuz und Bleiruten vor der Scheibe, eine Fensterbank darunter
					var zr := zi - seite * 0.02
					var zr2 := zi - seite * 0.06
					var zlo := minf(zr, zr2)
					var zhi := maxf(zr, zr2)
					_quader(flaechen, "rahmen", Vector3(x - 0.46, y0 - 0.06, zlo), Vector3(x + 0.46, y0, zhi))
					_quader(flaechen, "rahmen", Vector3(x - 0.46, y0 + hf, zlo), Vector3(x + 0.46, y0 + hf + 0.06, zhi))
					for e_: float in [-1.0, 1.0]:
						_quader(flaechen, "rahmen", Vector3(x + e_ * 0.43 - 0.03, y0, zlo), Vector3(x + e_ * 0.43 + 0.03, y0 + hf, zhi))
					_quader(flaechen, "rahmen", Vector3(x - 0.025, y0, zlo), Vector3(x + 0.025, y0 + hf, zhi))
					_quader(flaechen, "rahmen", Vector3(x - 0.4, y0 + hf * 0.55 - 0.025, zlo), Vector3(x + 0.4, y0 + hf * 0.55 + 0.025, zhi))
					var blei := 0.2
					while blei < hf - 0.05:
						_quader(flaechen, "metall", Vector3(x - 0.4, y0 + blei - 0.006, zlo + 0.01), Vector3(x + 0.4, y0 + blei + 0.006, zhi - 0.01))
						blei += 0.2
					_quader(flaechen, "balken", Vector3(x - 0.55, y0 - 0.12, minf(zi, zi - seite * 0.25)), Vector3(x + 0.55, y0 - 0.06, maxf(zi, zi - seite * 0.25)))

	# Fenster und Tür
	for seite: int in [1, -1]:
		var z_flaeche := (t / 2) * seite
		var anzahl := maxi(2, int(b / 2.3))
		for g in og + 1:
			var y0 := 0.9 if g == 0 else EG + OG * (g - 1) + 0.75
			var hoehe_f := 1.25 if g == 0 else 1.35
			var z_g := z_flaeche if g == 0 else (t / 2 + (VORKRAGUNG * g if fachwerk else 0.0)) * seite
			for k in anzahl:
				var x := -b / 2 + b * (k + 0.5) / anzahl
				if g == 0 and seite == 1 and absf(x) < b / anzahl * 0.6:
					continue   # dort ist die Tür
				_fenster(flaechen, Vector3(x, y0, z_g), seite, hoehe_f, stil == 3)
	if begehbar:
		_quader(flaechen, "tuer", Vector3(0.65, 0.0, t / 2 - WAND - 1.3), Vector3(0.71, 2.25, t / 2 - WAND))   # offen, innen an der Wand
	else:
		_quader(flaechen, "tuer", Vector3(-0.65, 0.0, t / 2 - 0.05), Vector3(0.65, 2.3, t / 2 + 0.06))
	_quader(flaechen, "balken", Vector3(-0.8, 2.3, t / 2), Vector3(0.8, 2.5, t / 2 + 0.12))
	# Wandlaterne neben der Tür (bei etwa jedem zweiten Haus), leuchtet warm
	if zufall.randf() < 0.5:
		var lx := 1.05 * (1.0 if zufall.randf() < 0.5 else -1.0)
		_quader(flaechen, "metall", Vector3(lx - 0.03, 2.35, t / 2), Vector3(lx + 0.03, 2.41, t / 2 + 0.32))
		_quader(flaechen, "metall", Vector3(lx - 0.13, 2.28, t / 2 + 0.2), Vector3(lx + 0.13, 2.32, t / 2 + 0.46))
		_quader(flaechen, "glut", Vector3(lx - 0.1, 1.95, t / 2 + 0.23), Vector3(lx + 0.1, 2.28, t / 2 + 0.43))
		_quader(flaechen, "metall", Vector3(lx - 0.12, 1.9, t / 2 + 0.21), Vector3(lx + 0.12, 1.95, t / 2 + 0.45))
	# Ladenschild an einem Ausleger neben der Tür (bei etwa jedem dritten Haus)
	if zufall.randf() < 0.35:
		var sx_ := (b * 0.3) * (1.0 if zufall.randf() < 0.5 else -1.0)
		_quader(flaechen, "balken", Vector3(sx_ - 0.05, 2.75, t / 2), Vector3(sx_ + 0.05, 2.85, t / 2 + 1.0))
		_quader(flaechen, "balken", Vector3(sx_ - 0.04, 2.45, t / 2), Vector3(sx_ + 0.04, 2.8, t / 2 + 0.08))
		_quader(flaechen, "rahmen", Vector3(sx_ - 0.01, 2.68, t / 2 + 0.85), Vector3(sx_ + 0.01, 2.75, t / 2 + 0.87))
		_quader(flaechen, "laden", Vector3(sx_ - 0.03, 2.15, t / 2 + 0.5), Vector3(sx_ + 0.03, 2.68, t / 2 + 0.95))
	# Holzbalkon vor dem ersten Obergeschoss (bei etwa jedem vierten Haus mit Obergeschoss), mit Knaggen und Geländer
	if og >= 1 and zufall.randf() < 0.28:
		var z0 := t / 2 + (VORKRAGUNG if fachwerk else 0.0)
		var bb := minf(b * 0.32, 1.8)
		var by := EG + 0.02
		_quader(flaechen, "balken", Vector3(-bb, by - 0.12, z0), Vector3(bb, by + 0.06, z0 + 0.95))
		for k in 3:
			var kx := -bb + 0.15 + k * (2.0 * bb - 0.3) / 2.0
			_quader(flaechen, "balken", Vector3(kx - 0.07, by - 0.7, z0), Vector3(kx + 0.07, by - 0.12, z0 + 0.2))
			_quader(flaechen, "balken", Vector3(kx - 0.06, by - 0.45, z0 + 0.2), Vector3(kx + 0.06, by - 0.12, z0 + 0.6))
		var px_ := -bb
		while px_ <= bb + 0.01:
			_quader(flaechen, "rahmen", Vector3(px_ - 0.035, by + 0.06, z0 + 0.86), Vector3(px_ + 0.035, by + 0.95, z0 + 0.93))
			px_ += 0.3
		_quader(flaechen, "balken", Vector3(-bb - 0.05, by + 0.92, z0 + 0.83), Vector3(bb + 0.05, by + 1.0, z0 + 0.97))
		for e: float in [-1.0, 1.0]:
			_quader(flaechen, "rahmen", Vector3(e * bb - 0.035, by + 0.06, z0), Vector3(e * bb + 0.035, by + 0.95, z0 + 0.93))
			_quader(flaechen, "balken", Vector3(e * bb - 0.04, by + 0.92, z0), Vector3(e * bb + 0.04, by + 1.0, z0 + 0.93))
	# Vordach über der Tür (bei etwa jedem dritten Haus): Pultdach auf zwei Knaggen
	if zufall.randf() < 0.38:
		var vb := 1.15
		var vy := 2.62
		var vt := 0.95
		_quader(flaechen, "balken", Vector3(-vb, vy - 0.08, t / 2), Vector3(vb, vy + 0.04, t / 2 + 0.12))
		for e: float in [-1.0, 1.0]:
			_quader(flaechen, "balken", Vector3(e * (vb - 0.12) - 0.05, vy - 0.55, t / 2), Vector3(e * (vb - 0.12) + 0.05, vy, t / 2 + 0.12))
			_knagge(flaechen, e * (vb - 0.12), vy - 0.55, vy, t / 2, t / 2 + vt - 0.1)
		var vs := _st(flaechen, _dachmaterial(form, variante))
		var d0 := Vector3(-vb - 0.1, vy + 0.45, t / 2 + 0.02)
		var d1 := Vector3(vb + 0.1, vy + 0.45, t / 2 + 0.02)
		var d2 := Vector3(vb + 0.1, vy + 0.02, t / 2 + vt)
		var d3 := Vector3(-vb - 0.1, vy + 0.02, t / 2 + vt)
		_viereck(vs, d0, d1, d2, d3)
		_viereck(vs, d3, d2, d1, d0)
	# Erker am obersten Geschoss (bei etwa jedem vierten Haus mit mindestens zwei Obergeschossen): Fachwerkkasten an
	# einer Ecke der Vorderseite, auf Knaggen, mit eigenem Pultdach
	if og >= 2 and b >= 6.0 and zufall.randf() < 0.3:
		var ex := (b / 2 - 1.1) * (1.0 if zufall.randf() < 0.5 else -1.0)
		var ez := t / 2 + aus
		var ey0 := EG + OG * (og - 1) + 0.15
		var ey1 := ey0 + OG - 0.35
		var ew := 0.85
		var et := 0.75
		_quader(flaechen, "putz%d" % form[5], Vector3(ex - ew, ey0, ez), Vector3(ex + ew, ey1, ez + et))
		_fachwerk(flaechen, Vector3(ex - ew, ey0, ez), Vector3(ex + ew, ey1, ez + et))
		_fenster(flaechen, Vector3(ex, ey0 + 0.6, ez + et), 1, 1.2, false)
		_quader(flaechen, "balken", Vector3(ex - ew - 0.05, ey0 - 0.18, ez), Vector3(ex + ew + 0.05, ey0, ez + et + 0.05))
		for e: float in [-1.0, 1.0]:
			_knagge(flaechen, ex + e * (ew - 0.15), ey0 - 0.9, ey0 - 0.15, ez, ez + et - 0.1)
		var es := _st(flaechen, _dachmaterial(form, variante))
		var r0 := Vector3(ex - ew - 0.15, ey1 + 0.55, ez)
		var r1 := Vector3(ex + ew + 0.15, ey1 + 0.55, ez)
		var r2 := Vector3(ex + ew + 0.15, ey1 - 0.05, ez + et + 0.2)
		var r3 := Vector3(ex - ew - 0.15, ey1 - 0.05, ez + et + 0.2)
		_viereck(es, r0, r1, r2, r3)
		_viereck(es, r3, r2, r1, r0)
	# Sockelleiste aus Stein (begehbar: nur ein Ring außen um die Mauer, an der Tür offen)
	if begehbar:
		var sl := 0.08
		_quader(flaechen, "quader", Vector3(-b / 2 - sl, -0.6, -t / 2 - sl), Vector3(b / 2 + sl, 0.45, -t / 2 + 0.02))
		_quader(flaechen, "quader", Vector3(-b / 2 - sl, -0.6, t / 2 - 0.02), Vector3(-0.65, 0.45, t / 2 + sl))
		_quader(flaechen, "quader", Vector3(0.65, -0.6, t / 2 - 0.02), Vector3(b / 2 + sl, 0.45, t / 2 + sl))
		for e: float in [-1.0, 1.0]:
			_quader(flaechen, "quader", Vector3(minf(e * (b / 2 - 0.02), e * (b / 2 + sl)), -0.6, -t / 2),
				Vector3(maxf(e * (b / 2 - 0.02), e * (b / 2 + sl)), 0.45, t / 2))
	else:
		_quader(flaechen, "quader", Vector3(-b / 2 - 0.08, -0.6, -t / 2 - 0.08), Vector3(b / 2 + 0.08, 0.45, t / 2 + 0.08))

	# Dach: Satteldach mit Überstand; First entlang z (Giebel zur Straße) oder entlang x
	var dach_mat := _dachmaterial(form, variante)
	var halbe := (b / 2.0 if giebelstaendig else front) + 0.45
	var laenge := (front + 0.35) if giebelstaendig else (b / 2.0 + 0.35)
	var firsthoehe := halbe * tan(deg_to_rad(DACHNEIGUNG))
	_dach(flaechen, dach_mat, oben_mat if not fachwerk else "putz%d" % form[5], traufe, halbe, laenge, firsthoehe,
			giebelstaendig, b / 2.0 if giebelstaendig else front, fachwerk)
	# Schornstein
	var sx := zufall.randf_range(-b * 0.25, b * 0.25) if not giebelstaendig else 0.0
	var sz := 0.0 if not giebelstaendig else zufall.randf_range(-t * 0.25, t * 0.25)
	_quader(flaechen, "bruchstein", Vector3(sx - 0.35, traufe + firsthoehe * 0.4, sz - 0.35), Vector3(sx + 0.35, traufe + firsthoehe + 0.9, sz + 0.35))
	_quader(flaechen, "bruchstein", Vector3(sx - 0.42, traufe + firsthoehe + 0.82, sz - 0.42), Vector3(sx + 0.42, traufe + firsthoehe + 0.95, sz + 0.42))
	_schornsteine[schluessel] = Vector3(sx, traufe + firsthoehe + 1.0, sz)
	# Dachgaube auf der vorderen Dachfläche traufständiger Häuser (Breite ab 7 m): Fensterkasten mit eigenem Satteldach
	if not giebelstaendig and b >= 6.8 and zufall.randf() < 0.7:
		var neig := tan(deg_to_rad(DACHNEIGUNG))
		var zf := halbe - 1.4
		var y0 := traufe - 0.35 + (halbe - zf) * neig - 0.1
		var y1 := y0 + 1.5
		var zb := halbe - (y1 + 0.6 - (traufe - 0.35)) / neig
		var gw := 0.85
		_quader(flaechen, oben_mat, Vector3(-gw, y0 - 1.0, zb), Vector3(gw, y1, zf))
		_quader(flaechen, "rahmen", Vector3(-0.5, y0 + 0.3, zf - 0.02), Vector3(0.5, y1 - 0.25, zf + 0.04))
		_quader(flaechen, "glas", Vector3(-0.42, y0 + 0.38, zf + 0.04), Vector3(0.42, y1 - 0.33, zf + 0.06))
		_quader(flaechen, "rahmen", Vector3(-0.04, y0 + 0.38, zf + 0.06), Vector3(0.04, y1 - 0.33, zf + 0.08))
		var gs_ := _st(flaechen, dach_mat)
		var first_ := Vector3(0, y1 + 0.75, 0)
		for e: float in [-1.0, 1.0]:
			var a1 := Vector3(e * (gw + 0.25), y1 - 0.05, zf + 0.25)
			var a2 := Vector3(e * (gw + 0.25), y1 - 0.05, zb)
			var f1 := Vector3(0, first_.y, zf + 0.25)
			var f2 := Vector3(0, first_.y, zb)
			if e > 0:
				_viereck(gs_, a1, a2, f2, f1)
			else:
				_viereck(gs_, a2, a1, f1, f2)
		_dreieck(_st(flaechen, oben_mat), Vector3(-gw, y1, zf), Vector3(gw, y1, zf), Vector3(0, y1 + 0.7, zf))

	var mesh := ArrayMesh.new()
	var fest := ArrayMesh.new()
	var namen := PackedStringArray()
	for mat: String in flaechen:
		var st: SurfaceTool = flaechen[mat]
		if mat == "rampe":
			st.commit(fest)
			continue
		st.generate_normals()
		st.generate_tangents()
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material(mat))
		namen.append(mat)
		if begehbar and mat not in ["glas", "glut", "fensterlicht", "laden"]:
			st.commit(fest)
	if begehbar:
		var sh := ConcavePolygonShape3D.new()
		sh.set_faces(fest.get_faces())
		sh.backface_collision = true
		_form_cache[schluessel] = sh
	_mesh_cache[schluessel] = mesh
	# Schattenhülle: eine Oberfläche statt eine je Material (Glas, Glut, Fensterlicht und Dielen innen ohne Schatten)
	_huellen_cache[schluessel] = Schattenhuelle.aus(mesh, namen, func(m: String) -> bool:
		return m in ["glas", "glut", "fensterlicht", "dielen"])
	return mesh


## Hohler Geschosskasten von lo bis hi mit Mauern der Stärke WAND; mit Tür: Öffnung 1,3 m × 2,3 m in der Mitte der
## Vorderseite (+z), deren Unterkante auf dem Fußboden (y = 0)
## Quader von lo bis hi; ist innen (x/z) nicht leer, nur der Kranz darum (vier Stücke)
func _kranz(flaechen: Dictionary, mat: String, lo: Vector3, hi: Vector3, innen: Rect2) -> void:
	if innen.size == Vector2.ZERO:
		_quader(flaechen, mat, lo, hi)
		return
	var ix0 := innen.position.x
	var ix1 := innen.end.x
	var iz0 := innen.position.y
	var iz1 := innen.end.y
	_quader(flaechen, mat, lo, Vector3(hi.x, hi.y, iz0))
	_quader(flaechen, mat, Vector3(lo.x, lo.y, iz1), hi)
	_quader(flaechen, mat, Vector3(lo.x, lo.y, iz0), Vector3(ix0, hi.y, iz1))
	_quader(flaechen, mat, Vector3(ix1, lo.y, iz0), Vector3(hi.x, hi.y, iz1))


func _hohl(flaechen: Dictionary, mat: String, lo: Vector3, hi: Vector3, tuer: bool) -> void:
	_quader(flaechen, mat, Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z + WAND))
	if tuer:
		_quader(flaechen, mat, Vector3(lo.x, lo.y, hi.z - WAND), Vector3(-0.65, hi.y, hi.z))
		_quader(flaechen, mat, Vector3(0.65, lo.y, hi.z - WAND), Vector3(hi.x, hi.y, hi.z))
		_quader(flaechen, mat, Vector3(-0.65, 2.3, hi.z - WAND), Vector3(0.65, hi.y, hi.z))
		_quader(flaechen, "balken", Vector3(-0.65, 2.22, hi.z - WAND - 0.02), Vector3(0.65, 2.3, hi.z + 0.02))
	else:
		_quader(flaechen, mat, Vector3(lo.x, lo.y, hi.z - WAND), Vector3(hi.x, hi.y, hi.z))
	_quader(flaechen, mat, Vector3(lo.x, lo.y, lo.z + WAND), Vector3(lo.x + WAND, hi.y, hi.z - WAND))
	_quader(flaechen, mat, Vector3(hi.x - WAND, lo.y, lo.z + WAND), Vector3(hi.x, hi.y, hi.z - WAND))


## Dielenboden im Geschoss g (Boden y, Vorkragung aus): bis an die Mauern, mit dem Loch über der Treppe, die aus dem
## Geschoss darunter heraufkommt, und einem Geländer am Loch (an seinem hinteren Ende offen: dort tritt man heraus)
func _boden(flaechen: Dictionary, f: int, g: int, b: float, t: float, y: float, aus: float) -> void:
	var x0 := -b / 2 + WAND
	var x1 := b / 2 - WAND
	var z0 := -t / 2 - aus + WAND
	var z1 := t / 2 + aus - WAND
	var tr: Array = treppen(f)
	if g == 0 or g - 1 >= tr.size():
		# im Erdgeschoss 3 cm über dem Gelände (sonst flimmert das Pflaster des Hofs durch)
		var yb := y + (0.03 if g == 0 else 0.0)
		_quader(flaechen, "dielen", Vector3(x0, yb - 0.25, z0), Vector3(x1, yb, z1))
		return
	var unten: Array = tr[g - 1]
	var sx: float = unten[0]
	var hinten_oben: bool = float(unten[1]) < float(unten[2])     # die Treppe kommt hinten herauf
	var zh: float = minf(unten[1], unten[2]) - 0.05
	var zv: float = maxf(unten[1], unten[2]) + 0.05
	var lx0 := sx * (b / 2 - WAND - TREPPE_B - 0.05)
	# Fläche ohne die Spalte der Treppe, dann die Spalte vor und hinter dem Loch
	if sx < 0.0:
		_quader(flaechen, "dielen", Vector3(lx0, y - 0.25, z0), Vector3(x1, y, z1))
		_quader(flaechen, "dielen", Vector3(x0, y - 0.25, zv), Vector3(lx0, y, z1))
		_quader(flaechen, "dielen", Vector3(x0, y - 0.25, z0), Vector3(lx0, y, zh))
	else:
		_quader(flaechen, "dielen", Vector3(x0, y - 0.25, z0), Vector3(lx0, y, z1))
		_quader(flaechen, "dielen", Vector3(lx0, y - 0.25, zv), Vector3(x1, y, z1))
		_quader(flaechen, "dielen", Vector3(lx0, y - 0.25, z0), Vector3(x1, y, zh))
	# Geländer: an der langen Innenkante (am oberen Ende der Treppe 1,5 m offen: dort tritt man heraus) und quer am
	# Ende über dem Fuß
	var gx := lx0 - sx * 0.04
	var g0 := zh + 1.5 if hinten_oben else zh
	var g1 := zv if hinten_oben else zv - 1.5
	var zq := zv if hinten_oben else zh
	_quader(flaechen, "rahmen", Vector3(gx - 0.04, y + 0.9, g0), Vector3(gx + 0.04, y + 0.98, g1))
	var xw := sx * (b / 2 - WAND)
	_quader(flaechen, "rahmen", Vector3(minf(gx, xw), y + 0.9, zq - 0.04), Vector3(maxf(gx, xw), y + 0.98, zq + 0.04))
	var pz := g0
	while pz <= g1 + 0.01:
		_quader(flaechen, "rahmen", Vector3(gx - 0.035, y, pz - 0.035), Vector3(gx + 0.035, y + 0.9, pz + 0.035))
		pz += 0.8
	_quader(flaechen, "rahmen", Vector3(gx - 0.035, y, g1 - 0.035), Vector3(gx + 0.035, y + 0.9, g1 + 0.035))


func _st(flaechen: Dictionary, mat: String) -> SurfaceTool:
	if not flaechen.has(mat):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_smooth_group(-1)   # kantig: sonst glättet generate_normals über die Kanten hinweg
		flaechen[mat] = st
	return flaechen[mat]


## true: alle Punkte um 90° um die Hochachse gedreht, (x, y, z) → (z, y, -x). So bauen dieselben Funktionen, die
## Flächen nach ±z legen (Fenster, Fachwerk), auch die Seiten nach ±x (Mängelliste M14).
var _quer := false


func _q(p: Vector3) -> Vector3:
	return Vector3(p.z, p.y, -p.x) if _quer else p


## Viereck a-b-c-d (gegen den Uhrzeigersinn von außen gesehen), UV in Metern aus der Lage.
## Godot zeichnet Dreiecke im Uhrzeigersinn als Vorderseite, darum werden sie umgekehrt eingetragen.
func _viereck(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	a = _q(a); b = _q(b); c = _q(c); d = _q(d)
	var n := (b - a).cross(c - a).normalized()
	for p in [a, c, b, a, d, c]:
		st.set_uv(_uv(p, n))
		st.add_vertex(p)


func _viereck_uv(st: SurfaceTool, p: Array, uv: Array) -> void:
	for i in [0, 2, 1, 0, 3, 2]:
		st.set_uv(uv[i])
		st.add_vertex(_q(p[i]))


func _dreieck(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	a = _q(a); b = _q(b); c = _q(c)
	var n := (b - a).cross(c - a).normalized()
	for p in [a, c, b]:
		st.set_uv(_uv(p, n))
		st.add_vertex(p)


func _uv(p: Vector3, n: Vector3) -> Vector2:
	var a := n.abs()
	if a.y > a.x and a.y > a.z:
		return Vector2(p.x, p.z)
	if a.x > a.z:
		return Vector2(p.z, -p.y)
	return Vector2(p.x, -p.y)


func _quader(flaechen: Dictionary, mat: String, lo: Vector3, hi: Vector3) -> void:
	var st := _st(flaechen, mat)
	var p := [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z),
		Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]
	_viereck(st, p[4], p[5], p[6], p[7])   # +z
	_viereck(st, p[1], p[0], p[3], p[2])   # -z
	_viereck(st, p[5], p[1], p[2], p[6])   # +x
	_viereck(st, p[0], p[4], p[7], p[3])   # -x
	_viereck(st, p[7], p[6], p[2], p[3])   # oben
	_viereck(st, p[0], p[1], p[5], p[4])   # unten


## Fachwerk auf allen vier Seiten eines Geschosses: Schwelle, Rähm, Riegel, Ständer, Streben an den Ecken,
## Kopfbänder und Andreaskreuze in den Brüstungen. Die Seiten nach ±x baut dieselbe Funktion gedreht (_quer).
func _fachwerk(flaechen: Dictionary, lo: Vector3, hi: Vector3) -> void:
	_fachwerk_seiten(flaechen, lo, hi)
	_quer = true
	_fachwerk_seiten(flaechen, Vector3(-hi.z, lo.y, lo.x), Vector3(-lo.z, hi.y, hi.x))
	_quer = false


## Fachwerk der beiden Seiten nach ±z
func _fachwerk_seiten(flaechen: Dictionary, lo: Vector3, hi: Vector3) -> void:
	var d := 0.06    # so weit stehen die Balken vor
	var s := 0.11    # Balkenbreite
	for seite: int in [1, -1]:
		var z := hi.z if seite == 1 else lo.z
		var zz := z + d * seite
		var breite := hi.x - lo.x
		# Rähm (oben), Riegel (Brüstung)
		_quader(flaechen, "balken", Vector3(lo.x, hi.y - s, minf(z, zz)), Vector3(hi.x, hi.y, maxf(z, zz)))
		_quader(flaechen, "balken", Vector3(lo.x, lo.y + 0.7, minf(z, zz)), Vector3(hi.x, lo.y + 0.7 + s, maxf(z, zz)))
		var felder := maxi(3, int(breite / 1.15))
		var zm := z + d * 0.5 * seite
		for k in felder + 1:
			var x := lo.x + breite * k / felder
			_quader(flaechen, "balken", Vector3(x - s / 2, lo.y, minf(z, zz)), Vector3(x + s / 2, hi.y, maxf(z, zz)))
			# Holznägel an Riegel und Rähm
			for yn: float in [lo.y + 0.7 + s / 2, hi.y - s / 2]:
				var zn := z + (d + 0.012) * seite
				_quader(flaechen, "nagel", Vector3(x - 0.02, yn - 0.02, minf(zz, zn)), Vector3(x + 0.02, yn + 0.02, maxf(zz, zn)))
			# Kopfbänder an den inneren Ständern
			if k > 0 and k < felder:
				for e: float in [-1.0, 1.0]:
					_balken(flaechen, "balken", Vector3(x + e * s / 2, hi.y - s - 0.42, zm), Vector3(x + e * 0.45, hi.y - s, zm), d, 0.09)
			# Andreaskreuz in der Brüstung jedes zweiten inneren Feldes
			if k > 0 and k < felder - 1 and k % 2 == 1:
				var xb := lo.x + breite * (k + 1) / felder
				_balken(flaechen, "balken", Vector3(x + s / 2, lo.y + 0.08, zm), Vector3(xb - s / 2, lo.y + 0.7, zm), d, 0.08)
				_balken(flaechen, "balken", Vector3(xb - s / 2, lo.y + 0.08, zm), Vector3(x + s / 2, lo.y + 0.7, zm), d, 0.08)
		# Streben in den äußeren Feldern (Mann-Figur): vom Fuß des Eckständers zum Rähm, als echte Balken
		for ecke: int in [0, felder - 1]:
			var x0 := lo.x + breite * ecke / felder
			var x1 := lo.x + breite * (ecke + 1) / felder
			var xa := x0 if ecke == 0 else x1
			var xb := x1 if ecke == 0 else x0
			_balken(flaechen, "balken", Vector3(xa, lo.y + s, zm), Vector3(xb, hi.y - s, zm), d, s)


## Knagge: schräge Stütze unter einem vorstehenden Bauteil, als Treppe aus vier Klötzen von (x, y0, z0) an der Wand
## bis (x, y1, z1) unter dem Bauteil
func _knagge(flaechen: Dictionary, x: float, y0: float, y1: float, z0: float, z1: float) -> void:
	for k in 4:
		var t0 := float(k) / 4.0
		var t1 := float(k + 1) / 4.0
		_quader(flaechen, "balken", Vector3(x - 0.06, y0 + (y1 - y0) * t0, z0), Vector3(x + 0.06, y0 + (y1 - y0) * t1, z0 + (z1 - z0) * t1))


func _strebe(flaechen: Dictionary, a: Vector3, b: Vector3, vor: float) -> void:
	var st := _st(flaechen, "balken")
	var s := 0.06
	var u := Vector3(0, s, 0)
	var z0 := a.z
	var z1 := a.z + vor
	var p := [Vector3(a.x, a.y, z1) - u, Vector3(b.x, b.y, z1) - u, Vector3(b.x, b.y, z1) + u, Vector3(a.x, a.y, z1) + u]
	if vor > 0:
		_viereck(st, p[0], p[1], p[2], p[3])
	else:
		_viereck(st, p[1], p[0], p[3], p[2])


func _fenster(flaechen: Dictionary, mitte: Vector3, seite: int, hoehe: float, laeden: bool) -> void:
	var w := 0.85
	var z := mitte.z + 0.02 * seite
	var a := Vector3(mitte.x - w / 2, mitte.y, z)
	var b := Vector3(mitte.x + w / 2, mitte.y, z)
	# hinter der Scheibe ein gedachter Raum (szenen/welt/fensterraum.gdshader), je Fenster anders
	var st := _st(flaechen, "fensterraum")
	var idf := float(absi(int(mitte.x * 13.0 + mitte.y * 7.0 + mitte.z * 3.0)) % 50)
	var uv := [Vector2(idf, 1.0), Vector2(idf + 1.0, 1.0), Vector2(idf + 1.0, 0.0), Vector2(idf, 0.0)]
	var oben := Vector3(0, hoehe, 0)
	if seite == 1:
		_viereck_uv(st, [a, b, b + oben, a + oben], uv)
	else:
		_viereck_uv(st, [b, a, a + oben, b + oben], uv)
	# Bleiruten in Rauten
	var blei := _st(flaechen, "metall")
	var zb := z + 0.012 * seite
	var d := 0.22
	var k := -w / 2 - hoehe
	while k < w / 2 + hoehe:
		for r: float in [1.0, -1.0]:
			var ta := maxf(0.0, -w / 2 - k) if r > 0 else maxf(0.0, k - w / 2)
			var tb := minf(hoehe, w / 2 - k) if r > 0 else minf(hoehe, k + w / 2)
			if tb - ta < 0.02:
				continue
			var pa := Vector3(mitte.x + k + r * ta, mitte.y + ta, zb)
			var pb := Vector3(mitte.x + k + r * tb, mitte.y + tb, zb)
			var q := Vector3(-0.008, 0.008 * r, 0)
			if seite == 1:
				_viereck(blei, pa - q, pb - q, pb + q, pa + q)
			else:
				_viereck(blei, pa + q, pb + q, pb - q, pa - q)
		k += d
	# Rahmen tief aus der Wand: Pfosten, Riegel, Sprosse, Kämpfer
	var r := 0.09
	var t := 0.16
	var z0 := minf(z - 0.02 * seite, z + t * seite)
	var z1 := maxf(z - 0.02 * seite, z + t * seite)
	_quader(flaechen, "rahmen", Vector3(a.x - r, a.y + hoehe, z0), Vector3(b.x + r, a.y + hoehe + r, z1))
	_quader(flaechen, "rahmen", Vector3(a.x - r, a.y, z0), Vector3(a.x, a.y + hoehe, z1))
	_quader(flaechen, "rahmen", Vector3(b.x, a.y, z0), Vector3(b.x + r, a.y + hoehe, z1))
	var zm0 := minf(z, z + 0.08 * seite)
	var zm1 := maxf(z, z + 0.08 * seite)
	_quader(flaechen, "rahmen", Vector3(mitte.x - 0.03, a.y, zm0), Vector3(mitte.x + 0.03, a.y + hoehe, zm1))
	_quader(flaechen, "rahmen", Vector3(a.x, a.y + hoehe * 0.62, zm0), Vector3(b.x, a.y + hoehe * 0.62 + 0.06, zm1))
	# Sturzbrett mit kleiner Verdachung darüber
	var zv := z + 0.24 * seite
	_quader(flaechen, "rahmen", Vector3(a.x - r - 0.08, a.y + hoehe + r, minf(z, zv)), Vector3(b.x + r + 0.08, a.y + hoehe + r + 0.07, maxf(z, zv)))
	# Fensterbank aus einem Brett auf zwei Knaggen
	var zs := z + 0.28 * seite
	_quader(flaechen, "rahmen", Vector3(a.x - r - 0.06, a.y - 0.07, minf(z, zs)), Vector3(b.x + r + 0.06, a.y, maxf(z, zs)))
	for x_: float in [a.x - 0.02, b.x - 0.06]:
		_quader(flaechen, "rahmen", Vector3(x_, a.y - 0.3, minf(z, z + 0.2 * seite)), Vector3(x_ + 0.08, a.y - 0.07, maxf(z, z + 0.2 * seite)))
		_quader(flaechen, "rahmen", Vector3(x_, a.y - 0.42, minf(z, z + 0.08 * seite)), Vector3(x_ + 0.08, a.y - 0.3, maxf(z, z + 0.08 * seite)))
	# Blumenkasten auf der Fensterbank (Obergeschosse, etwa jedes dritte Fenster): Kasten, Erde, Kräuter, ein paar Blüten
	var hfenster := absi(int(mitte.x * 17.0 + mitte.y * 31.0 + mitte.z * 11.0))
	if mitte.y > 2.5 and hfenster % 3 == 0:
		var kz0 := minf(z + 0.06 * seite, z + 0.27 * seite)
		var kz1 := maxf(z + 0.06 * seite, z + 0.27 * seite)
		_quader(flaechen, "balken", Vector3(a.x - 0.02, a.y, kz0), Vector3(b.x + 0.02, a.y + 0.18, kz1))
		_quader(flaechen, "erde", Vector3(a.x + 0.02, a.y + 0.18, kz0 + 0.03), Vector3(b.x - 0.02, a.y + 0.19, kz1 - 0.03))
		for i in 9:
			var px := a.x + 0.06 + (w - 0.12) * (i + 0.5) / 9.0
			var ph := 0.12 + 0.12 * float((hfenster >> i) % 3) / 2.0
			var pz := (kz0 + kz1) / 2.0 + (0.04 if i % 2 == 0 else -0.04)
			_quader(flaechen, "kraut", Vector3(px - 0.05, a.y + 0.18, pz - 0.05), Vector3(px + 0.05, a.y + 0.18 + ph, pz + 0.05))
			if (hfenster >> i) % 4 == 0:
				_quader(flaechen, "bluete" if i % 3 else "bluete_gelb", Vector3(px - 0.03, a.y + 0.18 + ph, pz - 0.03),
					Vector3(px + 0.03, a.y + 0.22 + ph, pz + 0.03))
	if laeden:
		for s_: int in [-1, 1]:
			var x0 := mitte.x + s_ * (w / 2 + r + 0.02)
			var x1 := x0 + s_ * w * 0.5
			var lo := minf(x0, x1)
			var hi := maxf(x0, x1)
			var la := minf(z + 0.04 * seite, z + 0.09 * seite)
			var lb := maxf(z + 0.04 * seite, z + 0.09 * seite)
			var br := (hi - lo) / 3.0
			for n_ in 3:
				_quader(flaechen, "laden", Vector3(lo + n_ * br + 0.006, a.y, la), Vector3(lo + (n_ + 1) * br - 0.006, a.y + hoehe, lb))
			for qy: float in [0.15, 0.85]:
				var yq := a.y + hoehe * qy
				var ea := minf(z + 0.09 * seite, z + 0.12 * seite)
				var eb := maxf(z + 0.09 * seite, z + 0.12 * seite)
				_quader(flaechen, "laden", Vector3(lo + 0.03, yq - 0.05, ea), Vector3(hi - 0.03, yq + 0.05, eb))
				_quader(flaechen, "metall", Vector3(minf(x0 - s_ * 0.1, x1 - s_ * 0.08), yq - 0.02, minf(z + 0.12 * seite, z + 0.135 * seite)),
					Vector3(maxf(x0 - s_ * 0.1, x1 - s_ * 0.08), yq + 0.02, maxf(z + 0.12 * seite, z + 0.135 * seite)))


## Satteldach. Ist der Giebel zur Straße (First entlang z), sind die Dachflächen links und rechts.
func _dach(flaechen: Dictionary, mat: String, giebel_mat: String, traufe: float, halbe: float, laenge: float,
		hoehe: float, giebelstaendig: bool, wand_halbe: float, fachwerk: bool) -> void:
	var st := _st(flaechen, mat)
	var dicke := 0.18
	# Punkte in einem Rahmen, in dem der First entlang "l" liegt und die Dachflächen nach ±"q" fallen.
	var punkt := func(q: float, l: float, y: float) -> Vector3:
		return Vector3(q, y, l) if giebelstaendig else Vector3(l, y, q)
	var unten := traufe - 0.35
	for s: int in [1, -1]:
		var a: Vector3 = punkt.call(s * halbe, -laenge, unten)
		var b: Vector3 = punkt.call(s * halbe, laenge, unten)
		var c: Vector3 = punkt.call(0.0, laenge, traufe + hoehe)
		var d: Vector3 = punkt.call(0.0, -laenge, traufe + hoehe)
		# Oberseite (nach außen) und Unterseite
		var oben := [a + Vector3(0, dicke, 0), b + Vector3(0, dicke, 0), c + Vector3(0, dicke, 0), d + Vector3(0, dicke, 0)]
		var gerade := (s == 1) != giebelstaendig
		# UV entlang des Firsts und die Dachfläche hinab, damit die Ziegelreihen waagrecht liegen
		var schraege := Vector2(halbe, hoehe + 0.35).length()
		var uv_a := Vector2(-laenge, schraege)
		var uv_b := Vector2(laenge, schraege)
		var uv_c := Vector2(laenge, 0.0)
		var uv_d := Vector2(-laenge, 0.0)
		if gerade:
			_viereck_uv(st, [oben[0], oben[1], oben[2], oben[3]], [uv_a, uv_b, uv_c, uv_d])
			_viereck_uv(st, [b, a, d, c], [uv_b, uv_a, uv_d, uv_c])
		else:
			_viereck_uv(st, [oben[1], oben[0], oben[3], oben[2]], [uv_b, uv_a, uv_d, uv_c])
			_viereck_uv(st, [a, b, c, d], [uv_a, uv_b, uv_c, uv_d])
		# Traufkante
		_viereck(_st(flaechen, "balken"), a, b, oben[1], oben[0]) if gerade else _viereck(_st(flaechen, "balken"), b, a, oben[0], oben[1])
	_dach_details(flaechen, mat, punkt, traufe, unten, halbe, laenge, hoehe, dicke, wand_halbe)
	# Giebelwände (Dreiecke) an beiden Enden, etwas hinter der Dachkante
	var gs := _st(flaechen, giebel_mat)
	# Die Giebelwand reicht bis an die Unterseite des Dachs (vorher ein Dreieck bis unter den First: zwischen Wand und
	# Dach klaffte an der Spitze ein halber Meter, von vorn sah das Dach aus, als schwebe es, Rückmeldung 26.11.2026)
	var dach_unten := func(q: float) -> float:
		return unten + (traufe + hoehe - unten) * (1.0 - absf(q) / halbe) - 0.01
	for e: int in [1, -1]:
		var l := (laenge - 0.35) * e
		var p1: Vector3 = punkt.call(-wand_halbe, l, traufe)
		var p2: Vector3 = punkt.call(wand_halbe, l, traufe)
		var p1o: Vector3 = punkt.call(-wand_halbe, l, dach_unten.call(wand_halbe))
		var p2o: Vector3 = punkt.call(wand_halbe, l, dach_unten.call(wand_halbe))
		var p3: Vector3 = punkt.call(0.0, l, dach_unten.call(0.0))
		var aussen := (e == 1) == giebelstaendig
		if aussen:
			_dreieck(gs, p1o, p2o, p3)
			_dreieck(gs, p1, p2, p2o)
			_dreieck(gs, p1, p2o, p1o)
		else:
			_dreieck(gs, p2o, p1o, p3)
			_dreieck(gs, p2, p1, p1o)
			_dreieck(gs, p2, p1o, p2o)
		# Fenster im Giebel (Dachboden): eines, bei breiten Giebeln zwei nebeneinander (M14)
		var gh := hoehe * wand_halbe / halbe
		if gh > 2.4:
			var reihe := [0.0] if wand_halbe < 3.4 else [-wand_halbe * 0.32, wand_halbe * 0.32]
			_quer = not giebelstaendig
			for q: float in reihe:
				var fh := minf(1.1, gh * (1.0 - absf(q) / wand_halbe) - 1.2)
				if fh < 0.6:
					continue
				# gedreht: (x, y, z) → (z, y, -x), also liegt q bei -x und die Giebelwand bei z = l
				var mitte := Vector3(q, traufe + 0.45, l) if giebelstaendig else Vector3(-q, traufe + 0.45, l)
				_fenster(flaechen, mitte, e, fh, false)
			_quer = false
		if fachwerk:
			# Ständer und Kehlbalken im Giebel
			var n := 4
			for k in range(1, n):
				var q := -wand_halbe + 2 * wand_halbe * k / n
				var hoch: float = dach_unten.call(q) - traufe
				var v := 0.06 * (1 if aussen else -1) * (1 if giebelstaendig else 1)
				var lo: Vector3 = punkt.call(q - 0.055, l, traufe)
				var hi: Vector3 = punkt.call(q + 0.055, l, traufe + hoch)
				var off: Vector3 = punkt.call(0.0, v, 0.0)
				_quader(flaechen, "balken", Vector3(minf(lo.x, hi.x + off.x), lo.y, minf(lo.z, hi.z + off.z)),
						Vector3(maxf(lo.x, hi.x + off.x), hi.y, maxf(lo.z, hi.z + off.z)))


## Ziegelreihen (jede Reihe steht vor), Firstkappen, Ortgangbretter, Sparrenköpfe und Regenrinnen eines Satteldachs.
func _dach_details(flaechen: Dictionary, mat: String, punkt: Callable, traufe: float, unten: float, halbe: float,
		laenge: float, hoehe: float, dicke: float, wand_halbe: float) -> void:
	var st := _st(flaechen, mat)
	var oben := traufe + hoehe
	var L: Vector3 = punkt.call(0.0, 1.0, 0.0) - punkt.call(0.0, 0.0, 0.0)
	var schritt := 0.24 if mat == "dach1" else 0.3
	for s: int in [1, -1]:
		var D: Vector3 = (punkt.call(s * halbe, 0.0, unten) - punkt.call(0.0, 0.0, oben)).normalized()   # hinab
		var N := D.cross(L).normalized()
		if N.y < 0.0:
			N = -N
		var lang := Vector2(halbe, oben - unten).length()
		var t := schritt
		while t < lang - 0.15:
			var f0 := 1.0 - t / lang
			var f1 := 1.0 - (t + schritt) / lang
			var a0: Vector3 = punkt.call(s * halbe * f0, -laenge, unten + (oben - unten) * (1.0 - f0) + dicke)
			var b0: Vector3 = punkt.call(s * halbe * f0, laenge, unten + (oben - unten) * (1.0 - f0) + dicke)
			var a1: Vector3 = punkt.call(s * halbe * f1, -laenge, unten + (oben - unten) * (1.0 - f1) + dicke)
			var b1: Vector3 = punkt.call(s * halbe * f1, laenge, unten + (oben - unten) * (1.0 - f1) + dicke)
			var hub := N * 0.035
			_vier(st, a0, b0, b0 + hub, a0 + hub, D)
			_vier(st, a0 + hub, b0 + hub, b1 + N * 0.003, a1 + N * 0.003, N)
			t += schritt
		# Ortgangbretter
		for e: int in [1, -1]:
			var l := (laenge + 0.03) * e
			_balken(flaechen, "balken", punkt.call(s * halbe, l, unten + dicke - 0.08), punkt.call(0.0, l, oben + dicke - 0.08), 0.05, 0.3)
		# Sparrenköpfe unter dem Überstand
		if halbe > wand_halbe + 0.25:
			var sp := -laenge + 0.4
			while sp < laenge - 0.3:
				var q0 := wand_halbe * s
				var q1 := (halbe - 0.06) * s
				var y0 := unten + (oben - unten) * (1.0 - wand_halbe / halbe) - 0.1
				var y1 := unten + (oben - unten) * (0.06 / halbe) - 0.1
				_balken(flaechen, "balken", punkt.call(q0, sp, y0), punkt.call(q1, sp, y1), 0.1, 0.14)
				sp += 0.8
		# Regenrinne an der Traufe mit kurzem Rohrstutzen an einem Ende
		var r0: Vector3 = punkt.call((halbe + 0.03) * s, -laenge, unten - 0.16)
		var r1: Vector3 = punkt.call((halbe + 0.2) * s, laenge, unten + 0.02)
		_quader(flaechen, "metall", Vector3(minf(r0.x, r1.x), r0.y, minf(r0.z, r1.z)), Vector3(maxf(r0.x, r1.x), r1.y, maxf(r0.z, r1.z)))
		var p0: Vector3 = punkt.call((halbe + 0.07) * s, laenge - 0.5, unten - 0.9)
		var p1: Vector3 = punkt.call((halbe + 0.17) * s, laenge - 0.4, unten - 0.1)
		_quader(flaechen, "metall", Vector3(minf(p0.x, p1.x), p0.y, minf(p0.z, p1.z)), Vector3(maxf(p0.x, p1.x), p1.y, maxf(p0.z, p1.z)))
	# Firstkappen
	var f := -laenge
	while f < laenge - 0.1:
		_balken(flaechen, mat, punkt.call(0.0, f, oben + dicke + 0.06), punkt.call(0.0, minf(f + 0.44, laenge), oben + dicke + 0.03), 0.3, 0.12)
		f += 0.4


## Viereck mit Vorderseite nach "aussen" (Reihenfolge wird passend gedreht).
func _vier(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, aussen: Vector3) -> void:
	if (b - a).cross(c - a).dot(aussen) >= 0.0:
		_viereck(st, a, b, c, d)
	else:
		_viereck(st, a, d, c, b)


## Balken (Quader) von a nach b, Querschnitt breite × hoehe, die Höhe möglichst nach oben.
func _balken(flaechen: Dictionary, mat: String, a: Vector3, b: Vector3, breite: float, hoehe: float) -> void:
	var st := _st(flaechen, mat)
	var d := (b - a).normalized()
	var sd := d.cross(Vector3.UP)
	if sd.length() < 0.01:
		sd = d.cross(Vector3.RIGHT)
	sd = sd.normalized()
	var o := sd.cross(d).normalized()
	if o.y < 0.0:
		o = -o
	var bs := sd * breite / 2.0
	var ho := o * hoehe / 2.0
	_vier(st, a - bs + ho, b - bs + ho, b + bs + ho, a + bs + ho, o)
	_vier(st, a - bs - ho, b - bs - ho, b + bs - ho, a + bs - ho, -o)
	_vier(st, a + bs - ho, b + bs - ho, b + bs + ho, a + bs + ho, sd)
	_vier(st, a - bs - ho, b - bs - ho, b - bs + ho, a - bs + ho, -sd)
	_vier(st, a - bs - ho, a + bs - ho, a + bs + ho, a - bs + ho, -d)
	_vier(st, b - bs - ho, b + bs - ho, b + bs + ho, b - bs + ho, d)


# ---------- Materialien ----------

## Parallax-Tiefe je Textur (Godot: Hundertstel einer Kachel)
const PARALLAX := {"quader": 1.6, "bruchstein": 2.4, "dach": 3.0, "schiefer": 2.2, "holz": 0.8, "putz": 0.6}


func _material(name_: String) -> Material:
	if _mat_cache.has(name_):
		return _mat_cache[name_]
	if name_ == "fensterraum":
		var fr := ShaderMaterial.new()
		fr.shader = load("res://szenen/welt/fensterraum.gdshader")
		fr.resource_name = name_    # für den Baucache (gemeinsames Material beim Laden)
		_mat_cache[name_] = fr
		return fr
	var m := StandardMaterial3D.new()
	# Textur und Meter je Kachel (Fotoscans, echte Größe siehe texturen/groessen.json)
	var tex := {"quader": ["quader", 2.5], "bruchstein": ["bruchstein", 2.0], "dach0": ["dach", 2.0],
		"dach2": ["dach", 2.0], "dach3": ["dach", 2.0], "dach1": ["schiefer", 3.0], "balken": ["holz", 2.0], "tuer": ["holz", 1.5], "laden": ["holz", 1.5],
		"rahmen": ["holz", 2.0]}
	if name_.begins_with("putz"):
		tex[name_] = ["putz", 1.6]
	if tex.has(name_):
		var t: String = tex[name_][0]
		m.albedo_texture = load("res://texturen/%s_farbe.jpg" % t)
		m.normal_enabled = true
		m.normal_texture = load("res://texturen/%s_normal.jpg" % t)
		m.roughness_texture = load("res://texturen/%s_rau.jpg" % t)
		var s := 1.0 / float(tex[name_][1])
		m.uv1_scale = Vector3(s, s, s)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		# Parallax aus der Höhenkarte: Fugen, Ziegelreihen und Holzmaserung mit echter Tiefe
		if PARALLAX.has(t) and name_ not in ["tuer", "laden", "rahmen"]:
			m.heightmap_enabled = true
			m.heightmap_texture = load("res://texturen/%s_hoehe.jpg" % t)
			m.heightmap_scale = PARALLAX[t]
			m.heightmap_deep_parallax = true
			m.heightmap_min_layers = 6
			m.heightmap_max_layers = 16
	match name_:
		# Ziegel kräftiger als die Textur (deren helle Fugen und Flechten mitteln sich aus der Ferne zu Beige)
		"dach0":
			m.albedo_color = Color(0.92, 0.6, 0.48)
		"dach2":
			m.albedo_color = Color(0.7, 0.47, 0.38)
		"dach3":
			m.albedo_color = Color(1.0, 0.72, 0.55)
		"dach1":
			m.albedo_color = Color(0.85, 0.88, 0.95)
		"quader", "bruchstein":
			m.albedo_color = Color(1.25, 1.18, 1.05)   # heller, warmer Kalkstein wie an den Burgmauern
		"balken", "rahmen":
			m.albedo_color = Color(0.62, 0.5, 0.4)
		"nagel":
			m.albedo_color = Color(0.2, 0.15, 0.11)
			m.roughness = 0.9
		"tuer":
			m.albedo_color = Color(0.7, 0.5, 0.35)
		"laden":
			m.albedo_color = Color(0.45, 0.6, 0.5)
		"glut":
			m.albedo_color = Color(1.0, 0.78, 0.45)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.62, 0.28)
			m.emission_energy_multiplier = 2.0
		"metall":
			m.albedo_color = Color(0.12, 0.12, 0.13)
			m.metallic = 0.6
			m.roughness = 0.5
		"fensterlicht":
			m.albedo_color = Color(0.62, 0.7, 0.74)
			m.emission_enabled = true
			m.emission = Color(0.62, 0.7, 0.78)
			m.emission_energy_multiplier = 0.45
		"dielen":
			m.albedo_texture = load("res://texturen/holz_farbe.jpg")
			m.albedo_color = Color(0.7, 0.55, 0.42)
			m.uv1_scale = Vector3(0.5, 0.5, 0.5)
		"erde":
			m.albedo_color = Color(0.2, 0.14, 0.09)
			m.roughness = 1.0
		"kraut":
			m.albedo_color = Color(0.2, 0.36, 0.12)
			m.roughness = 0.85
		"bluete":
			m.albedo_color = Color(0.65, 0.16, 0.24)
		"bluete_gelb":
			m.albedo_color = Color(0.88, 0.7, 0.18)
		"glas":
			m.albedo_color = Color(0.08, 0.1, 0.12)
			m.metallic = 0.4
			m.roughness = 0.15
	if name_.begins_with("putz"):
		m.albedo_color = PUTZFARBEN[int(name_.substr(4))]
	m.resource_name = name_    # für den Baucache (gemeinsames Material beim Laden)
	_mat_cache[name_] = m
	return m
