class_name GelaendeErzeuger
## Erzeugt das Gelände der Region Drachenstein nach der Karte von Sorrowland.
##
## Maßstab 1:50 (1 km auf der Karte = 20 m im Spiel). Ursprung (0, 0) ist der Kernhof
## der Burgfeste Drachenstein, +x ist Osten, +z ist Süden. Lage der Orte:
##   Burgfeste Drachenstein   (0, 0)        III. Burghof (Hof aus Akt I) auf Höhe 0. Die Anlage nach dem
##                                          Grundriss (daten/drachenstein_plan.json): Burgen auf einem Felsgrat
##                                          von Süden (Vorburg) nach Norden (Kernburg), Stadt und Drachenhafen
##                                          östlich unten in der Ebene am Meer
##   Schwarzer Bergfried       (500, 100)    Insel, von der Hafenmole über drei Inseln erreichbar
##   Gravemarch                (-600, -205)  im Tal unter dem Felssporn, nach dem Grundriss um 180°
##                                          gedreht: Torhaus im Nordosten, Kernburg im Süden
##   Gravecrest                (-675, -365)  auf dem eisigen Felssporn, Höhe 70
## Der Meeresspiegel liegt bei -20.
##
## Ausführen: in Godot werkzeuge/gelaende_erzeugen.gd öffnen und Datei → Ausführen
## (Strg+Umschalt+X). Danach die Szene neu öffnen.

const URSPRUNG := Vector2(-900, -700)
const GROESSE := Vector2(2200, 1450)
const ABSTAND := 2.5
const MEERESSPIEGEL := -20.0

## Ausdehnung und Zielordner. Andere Regionen (z. B. gelaende_riverlock.gd) setzen eigene Werte.
var zielordner := "res://daten/gelaende/"
var ursprung := URSPRUNG
var groesse := GROESSE
var abstand := ABSTAND
var wasserspiegel := MEERESSPIEGEL

const GRAVEMARCH := Vector2(-600, -205)
const BERGFRIED := Vector2(500, 100)
## Umriss der Hauptmauer von Gravemarch (mit dem Verfallenen Vorhof im Osten), relativ zur Mitte.
const GRAVEMARCH_UMRISS := [Vector2(51, -48.1), Vector2(64, -37.7), Vector2(41, -6.5), Vector2(60, -2),
	Vector2(60, 24), Vector2(33, 26), Vector2(31, 37.7), Vector2(22, 50.7), Vector2(4, 54.6), Vector2(-26, 52),
	Vector2(-43, 44.2), Vector2(-54, 39), Vector2(-60, 23.4), Vector2(-63, -11.7), Vector2(-65, -32.5),
	Vector2(-48, -40.3), Vector2(-36, -35), Vector2(-19, -37.7), Vector2(4, -45.5), Vector2(22, -35), Vector2(39, -45.5)]
## Inseln im Graben für das Südliche Vorwerk und das unechte Südtor: [Mitte relativ, Radius].
const GRAVEMARCH_INSELN := [[Vector2(-8, -59), 7.0], [Vector2(-35, -63), 8.0]]
const GRABEN_SOHLE := -13.0
## Inseln zwischen Drachenkai und Bergfried: [Mitte, Radius].
const INSELN := [[Vector2(300, -15), 10.0], [Vector2(382, 22), 9.0], [Vector2(462.4, 60.4), 9.0], [BERGFRIED, 40.0]]
const INSEL_HOEHE := -17.8
## Radius der Grube für den Unterbau des Bergfrieds (liegt innerhalb seiner 10 m dicken Mauer).
const BERGFRIED_GRUBE := 17.0

## Küste: so weit östlich liegt im Mittel die Wasserlinie.
const KUESTE_X := 245.0
const KAI_HOEHE := -17.8
const H_EBENE := -14.0      # Land vor der Ringmauer
const GRUND_VORGEBIRGE := -18.6   # Felsgrund direkt vor den Mauern (über dem Meeresspiegel)
const BECKEN_TIEFE := -27.0

## Wege als Linienzüge.
const WEG_GRAVEMARCH := [Vector2(-26.41, 186.63), Vector2(-35.4, 188.0), Vector2(-52, 190), Vector2(-120, 215), Vector2(-220, 170), Vector2(-300, 80),
	Vector2(-380, -20), Vector2(-460, -150), Vector2(-490, -215), Vector2(-528.8, -265.1)]
## Der Weg nach Gravecrest steigt vom Tal bis zur Zugbrücke auf Höhe 70.
const WEG_GRAVECREST := [Vector2(-460, -150), Vector2(-470, -240), Vector2(-500, -310),
	Vector2(-560, -345), Vector2(-612, -363)]
const GRAVECREST_HOEHE := 70.0
## Landstraßen: Die Nordstraße zweigt im Tal vom Weg nach Gravemarch ab und läuft in weitem Bogen um die Nordsee
## (die Burg steht wie im Referenzbild auf einem Vorgebirge, auf drei Seiten Meer) zum Pass im Norden (nach Riverlock);
## der Küstenweg beginnt am Torhaus West in der Ringmauer und führt über einen Pass im Süden.
const WEG_NORD := [Vector2(-380, -20), Vector2(-390, -130), Vector2(-360, -260), Vector2(-280, -380), Vector2(-150, -460),
		Vector2(20, -480), Vector2(150, -440), Vector2(230, -500)]
const WEG_KUESTE := [Vector2(230.9, 93.9), Vector2(242, 96), Vector2(240, 150), Vector2(238, 215), Vector2(228, 262),
	Vector2(196, 302), Vector2(150, 335), Vector2(122, 390), Vector2(132, 470), Vector2(140, 540)]
## Passstrecken mit fester Steigung: [Linienzug, Höhe am Anfang, Höhe am Ende].
const PASS_NORD := [[Vector2(230, -500), Vector2(150, -560), Vector2(110, -610), Vector2(85, -660)], -4.0, 30.0]
const PASS_SUED := [[Vector2(140, 540), Vector2(150, 615), Vector2(160, 690)], -13.0, 22.0]

## Grundriss der Burgfeste (werkzeuge/bau/plan_drachenstein.py schreibt ihn)
var plan: Dictionary = {}
var _zonen: Array = []          # [PackedVector2Array, Höhe, Rand, Weg, Weghöhen] (mit Weg: Höhe des nächsten Wegpunkts)
var _hoefe: Array = []          # Burghöfe (ganz gepflastert, Blau in der Maske)
var _stadt := PackedVector2Array()
var _becken: Array = []         # Hafenbecken, Fahrrinne, Kanal
## Kanten je Becken (Reihenfolge wie _becken), an denen ein Kai liegt: Hafenbecken ohne die Einfahrt (Kante 4), Fahrrinne
## keine, Kanal die beiden Längsseiten
const BECKEN_KAIKANTEN := [[0, 1, 2, 3, 5, 6, 7, 8, 9], [], [0, 2]]
var _markt := PackedVector2Array()
var _anstieg := PackedVector2Array()   # Umriss, zu dem die Stadt ansteigt (die Vorburg)
var _ring := PackedVector2Array()     # Burgbezirk innerhalb der Ringmauer (Grat und Zwinger)
var _hafen := PackedVector2Array()    # Hafenbezirk: Kais
var _bucht := PackedVector2Array()    # Meer um die Burg: Bucht vor dem Hafen, im Osten und Norden um das Vorgebirge
var _firstlinie: Array = []           # Firstlinie des Felsgrats
var _burgwege: Array = []             # [Linienzug, Höhen je Punkt]
var _ringwege: Array = []             # Burgwege, deren Höhe der Grund im Burgbezirk folgt
var stadt_strassen: Array = []

var _rauschen := FastNoiseLite.new()
var _fein := FastNoiseLite.new()
var _grat := FastNoiseLite.new()
var _zacken := FastNoiseLite.new()   # zerklüftete Klippen
var _kamm := FastNoiseLite.new()     # Grate auf dem Hauptkamm (Mängelliste M5)
var _massiv := FastNoiseLite.new()   # große Bergstöcke und Täler dazwischen
var _huegel := FastNoiseLite.new()   # Vorberge
var _versatz := FastNoiseLite.new()  # unregelmäßiger Fuß des Gebirges

## Hänge im Gebirge, die steiler sind als dieser Winkel, rutschen ab (Schutthalden statt Wänden und Nadeln).
## Regionen, die diesen Erzeuger erweitern, schalten das aus.
var erosion_winkel := 45.0
const EROSION_SCHRITTE := 40
var _abtrag := 0.0   # von hoehe(): wie stark die letzte Stelle abgetragen werden darf (0 bis 1)

## Fernberge hinter dem Rand der Region (szenen/welt/fernberge.gd): Bereich (Welt x, z) und Rasterabstand. Leer: keine.
## Regionen, die diesen Erzeuger erweitern, setzen ihn leer.
var fernberge := Rect2(-3600, -3400, 6000, 6800)
const FERN_ABSTAND := 40.0


func _init() -> void:
	var daten: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://daten/drachenstein_plan.json"))
	if daten is Dictionary:
		plan = daten
		var vec := func(liste: Array) -> PackedVector2Array:
			var a := PackedVector2Array()
			for q: Array in liste:
				a.append(Vector2(q[0], q[1]))
			return a
		for z: Dictionary in plan["zonen"]:
			_zonen.append([vec.call(z["punkte"]), float(z["hoehe"]), float(z["rand"]),
					Array(vec.call(z.get("weg", []))), z.get("weg_hoehen", [])])
			if not "Zwinger" in str(z["name"]) and not "Felssockel" in str(z["name"]):
				_hoefe.append(vec.call(z["punkte"]))
		_stadt = vec.call(plan["stadt"])
		_markt = vec.call(plan["markt"])
		if plan.has("stadt_anstieg"):
			_anstieg = vec.call(plan["stadt_anstieg"]["punkte"])
		_ring = vec.call(plan["ring"])
		_hafen = vec.call(plan["hafen"])
		_bucht = vec.call(plan["bucht"])
		_firstlinie = Array(vec.call(plan["grat"]))
		for weg: Array in plan["burgwege"]:
			# [Linienzug, Höhen, folgt der Grund?, Flanke]: Flanke [innen, außen] (Meter), sonst 3,5 bis 7 m Böschung
			_burgwege.append([Array(vec.call(weg[0])), weg[1], weg[3] if weg.size() > 3 else [3.5, 7.0]])
			if weg.size() > 2 and weg[2]:
				_ringwege.append(_burgwege[-1])
		for name in ["hafen_becken", "fahrrinne", "kanal"]:
			_becken.append(vec.call(plan[name]))
		for linie: Array in plan["strassen"]:
			stadt_strassen.append(Array(vec.call(linie)))
	_rauschen.seed = 1750
	_rauschen.frequency = 0.004
	_fein.seed = 940
	_fein.frequency = 0.03
	_grat.seed = 1065
	_grat.frequency = 0.007
	_zacken.seed = 512
	_zacken.frequency = 0.07
	_zacken.fractal_octaves = 3
	_zacken.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_kamm.seed = 2207
	_kamm.frequency = 0.0042
	_kamm.fractal_octaves = 3
	_massiv.seed = 4409
	_massiv.frequency = 0.0017
	_massiv.fractal_octaves = 4
	_massiv.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_kamm.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_huegel.seed = 77
	_huegel.frequency = 0.009
	_huegel.fractal_octaves = 3
	_versatz.seed = 3301
	_versatz.frequency = 0.003


## Erzeugt alle Dateien und gibt die Anzahl der Höhenpunkte zurück.
func erzeuge() -> int:
	var breite := int(groesse.x / abstand) + 1
	var tiefe := int(groesse.y / abstand) + 1
	var hoehen := PackedFloat32Array()
	hoehen.resize(breite * tiefe)
	var maske := Image.create(breite, tiefe, false, Image.FORMAT_RGB8)
	var vorschau := Image.create(breite, tiefe, false, Image.FORMAT_RGB8)

	var abtrag := PackedFloat32Array()
	abtrag.resize(breite * tiefe)
	for iz in tiefe:
		for ix in breite:
			var p := ursprung + Vector2(ix, iz) * abstand
			_abtrag = 0.0
			hoehen[iz * breite + ix] = hoehe(p)
			abtrag[iz * breite + ix] = _abtrag
	if erosion_winkel > 0.0:
		hoehen = _erodiere(hoehen, abtrag, breite, tiefe)   # Packed-Arrays kommen als Kopie an
	for iz in tiefe:
		for ix in breite:
			var p := ursprung + Vector2(ix, iz) * abstand
			var h := hoehen[iz * breite + ix]
			var m := maske_bei(p)
			maske.set_pixel(ix, iz, m)
			vorschau.set_pixel(ix, iz, _vorschaufarbe(h, m))

	DirAccess.make_dir_recursive_absolute(zielordner)
	var datei := FileAccess.open(zielordner + "hoehen.r32", FileAccess.WRITE)
	datei.store_buffer(hoehen.to_byte_array())
	datei.close()
	var info := {
		"breite": breite, "tiefe": tiefe, "abstand": abstand,
		"ursprung_x": ursprung.x, "ursprung_z": ursprung.y,
		"meeresspiegel": wasserspiegel,
	}
	datei = FileAccess.open(zielordner + "hoehen.json", FileAccess.WRITE)
	datei.store_string(JSON.stringify(info, "\t"))
	datei.close()
	maske.save_png(zielordner + "maske.png")
	vorschau.save_png(zielordner + "vorschau.png")
	if fernberge.has_area():
		_erzeuge_fernberge(hoehen, breite, tiefe)
	return breite * tiefe


## Thermische Erosion: Wo zwei Nachbarpunkte steiler als erosion_winkel zueinander stehen, rutscht Material hinab, bis
## der Hang flacher ist. Nur im Gebirge (abtrag > 0), nicht an Wegen, Pässen und Burgen.
func _erodiere(h: PackedFloat32Array, w: PackedFloat32Array, breite: int, tiefe: int) -> PackedFloat32Array:
	var grenze := tan(deg_to_rad(erosion_winkel)) * abstand
	var stellen := PackedInt32Array()
	for iz in range(1, tiefe - 1):
		for ix in range(1, breite - 1):
			if w[iz * breite + ix] > 0.0:
				stellen.append(iz * breite + ix)
	var nachbarn := [1, -1, breite, -breite]
	var rueckwaerts := stellen.duplicate()
	rueckwaerts.reverse()
	for schritt in EROSION_SCHRITTE:
		# abwechselnd vorwärts und rückwärts, sonst zieht die Reihenfolge Streifen
		for i in (stellen if schritt % 2 == 0 else rueckwaerts):
			for d: int in nachbarn:
				var j := i + d
				var unterschied := h[i] - h[j]
				if unterschied > grenze:
					# nur zwischen zwei Stellen im Gebirge, sonst häuft sich das Material am Fuß zu einem Wall
					var menge := (unterschied - grenze) * 0.25 * minf(w[i], w[j])
					h[i] -= menge
					h[j] += menge
	return h


## Höhen der Fernberge (fernberge.r32, fernberge.json): ein grobes Raster rund um die Region. Auf dem Rand der Region
## gilt die Höhe des Geländes, damit die Fernberge ohne Spalt anschließen; innen wird nichts gezeichnet.
func _erzeuge_fernberge(raster: PackedFloat32Array, breite: int, tiefe: int) -> void:
	var nx := int(fernberge.size.x / FERN_ABSTAND) + 1
	var nz := int(fernberge.size.y / FERN_ABSTAND) + 1
	var werte := PackedFloat32Array()
	werte.resize(nx * nz)
	var innen := Rect2(ursprung, groesse)
	for iz in nz:
		for ix in nx:
			var p := fernberge.position + Vector2(ix, iz) * FERN_ABSTAND
			# innen: Höhe am nächsten Punkt des Rands (dorthin rückt fernberge.gd den Rasterpunkt)
			if innen.has_point(p):
				# Höhe des fertigen Geländes (nach der Erosion) am Rand
				var r := (_auf_rand(p, innen) - ursprung) / abstand
				werte[iz * nx + ix] = raster[clampi(roundi(r.y), 0, tiefe - 1) * breite + clampi(roundi(r.x), 0, breite - 1)]
			else:
				werte[iz * nx + ix] = fernhoehe(p)
	var datei := FileAccess.open(zielordner + "fernberge.r32", FileAccess.WRITE)
	datei.store_buffer(werte.to_byte_array())
	datei.close()
	datei = FileAccess.open(zielordner + "fernberge.json", FileAccess.WRITE)
	datei.store_string(JSON.stringify({"breite": nx, "tiefe": nz, "abstand": FERN_ABSTAND,
		"ursprung_x": fernberge.position.x, "ursprung_z": fernberge.position.y,
		"innen": [innen.position.x, innen.position.y, innen.end.x, innen.end.y]}, "\t"))
	datei.close()


## Höhe außerhalb der Region: die Gebirgszüge laufen weiter und werden nach außen höher (Staffelung zum Horizont);
## im Osten liegt das Meer, dorthin tauchen die Züge ab.
func fernhoehe(p: Vector2) -> float:
	var n := _rauschen.get_noise_2dv(p)
	var b := _gebirgsfaktor(p)
	var land := 3.0 + n * 7.0
	var h := _gebirgshoehe(p, b, n, land)
	# Weiter draußen größere Berge: dieselben Grate dreimal so weit auseinander und höher (das Raster ist dort grob)
	var aussen := maxf(maxf(ursprung.x - p.x, ursprung.y - p.y), p.y - (ursprung.y + groesse.y))
	var gross := clampf(_massiv.get_noise_2dv(p * 0.45 + Vector2(517.0, -311.0)) * 0.5 + 0.5, 0.0, 1.0)
	var grat := clampf(_kamm.get_noise_2dv(p * 0.35 + Vector2(-203.0, 911.0)) * 0.5 + 0.5, 0.0, 1.0)
	var fern := 130.0 + pow(gross, 1.3) * 430.0 + grat * grat * 70.0 + n * 25.0
	h = lerpf(h, maxf(h, fern), smoothstep(100.0, 1100.0, aussen) * b)
	# Ostseite: Meer (wie in der Region östlich der Küste)
	var meer := smoothstep(KUESTE_X - 60.0, KUESTE_X + 140.0, p.x) * (1.0 - b)
	h = lerpf(h, -40.0, meer)
	# Die Passwege laufen hinter dem Rand weiter durch ihr Tal
	for pass_daten: Array in [PASS_NORD, PASS_SUED]:
		var linie: Array = pass_daten[0]
		var ende: Vector2 = linie[-1]
		var richtung: Vector2 = (ende - (linie[-2] as Vector2)).normalized()
		h = _pass(h, p, [[ende, ende + richtung * 900.0], pass_daten[2], float(pass_daten[2]) + 45.0])
	return h


static func _auf_rand(p: Vector2, r: Rect2) -> Vector2:
	var m := minf(minf(p.x - r.position.x, r.end.x - p.x), minf(p.y - r.position.y, r.end.y - p.y))
	if m == p.x - r.position.x:
		return Vector2(r.position.x, p.y)
	if m == r.end.x - p.x:
		return Vector2(r.end.x, p.y)
	if m == p.y - r.position.y:
		return Vector2(p.x, r.position.y)
	return Vector2(p.x, r.end.y)


## Höhe an einer Stelle der Welt (x, z).
func hoehe(p: Vector2) -> float:
	var n := _rauschen.get_noise_2dv(p)
	var fein := _fein.get_noise_2dv(p)

	# Hügeliges Land um Drachenstein.
	var h := 3.0 + n * 7.0 + fein * 0.8

	# Gebirge: Eisgrat im Westen, Ränder der Region im Norden und Süden (Vorberge, dahinter der Hauptkamm).
	var berg := _gebirgsfaktor(p)

	# Das Tal nach Gravemarch hält das Gebirge zurück.
	var tal_abstand := _abstand_zu([Vector2(-200, 190), Vector2(-300, 80), Vector2(-380, -20), Vector2(-460, -150), GRAVEMARCH], p)
	# Das Tal zieht sich bis unter den Felssporn von Gravecrest.
	tal_abstand = minf(tal_abstand, _abstand_zu([GRAVEMARCH, Vector2(-560, -300), Vector2(-660, -380), Vector2(-740, -420)], p))
	var tal := 1.0 - smoothstep(60.0, 240.0, tal_abstand)
	var talboden := lerpf(0.0, -8.0, smoothstep(-260.0, -560.0, p.x)) + n * 2.0
	berg *= 1.0 - tal
	h = lerpf(h, talboden, tal)
	h = _gebirgshoehe(p, berg, n, h)
	# Erosion nur im Gebirge, nicht an Pässen, am Weg nach Gravecrest und am Felssporn
	_abtrag = smoothstep(0.25, 0.7, berg)
	if _abtrag > 0.0:
		var frei := minf(minf(_abstand_zu(PASS_NORD[0], p), _abstand_zu(PASS_SUED[0], p)), _abstand_zu(WEG_GRAVECREST, p))
		frei = minf(frei, Vector2(clampf(p.x, -860.0, -600.0), -365.0).distance_to(p) - 30.0)
		_abtrag *= smoothstep(45.0, 90.0, frei)

	# Felssporn von Gravecrest: schmaler Grat mit flacher Krone auf Höhe 70.
	if p.x < -625.0 and p.x > -860.0:
		# Die Krone ist flach und breit genug für die Burg nach Grundriss (130 x 36 m).
		var quer := absf(p.y - (-365.0))
		var flanke := 1.0 - smoothstep(19.0, 50.0, quer)
		var krone := GRAVECREST_HOEHE + maxf(0.0, -p.x - 775.0) * 0.8
		h = lerpf(h, maxf(h, krone), flanke)

	# Küste: Das Land fällt zum Wächtermeer hin ab. Fern vom Küstenweg als Felsküste (Mängelliste M8): Das Land bleibt
	# 8 bis 17 m über dem Wasser und bricht mit ausgefranster Kante als Klippe ab; dazwischen kleine Buchten mit Strand.
	var kueste := KUESTE_X + 20.0 * sin(p.y / 110.0) + _versatz.get_noise_2dv(p * 3.0) * 18.0
	var d := p.x - kueste
	var flach := lerpf(h, -18.6, smoothstep(-110.0, 0.0, d) * (1.0 - berg))
	var kliff_anteil := smoothstep(30.0, 70.0, _abstand_zu(WEG_KUESTE, p)) * (1.0 - _strand(p)) * (1.0 - berg)
	if kliff_anteil > 0.0:
		var kante := -12.0 + (_huegel.get_noise_2dv(p * 0.6) * 0.5 + 0.5) * 9.0
		var kliff := lerpf(h, kante, smoothstep(-120.0, -25.0, d))
		kliff = lerpf(kliff, -24.0, smoothstep(-7.0, -1.0, d + _zacke(p) * 3.0))
		h = lerpf(flach, kliff, kliff_anteil)
	else:
		h = flach
	h -= smoothstep(5.0, 70.0, d) * 15.0

	# Burgfeste Drachenstein nach dem Grundriss: Burgberg, Stadt, Burgringe, Hafen.
	h = _drachenstein(h, p)

	# Gravemarch auf einem aufgeschütteten Hügel im Sumpf.
	var gm := p.distance_to(GRAVEMARCH)
	h = lerpf(h, -9.0 + fein * 0.6, 1.0 - smoothstep(110.0, 145.0, gm))  # Sumpfsenke
	h = _gravemarch(h, p)

	# Wege glätten das Gelände.
	h = _weg_einebnen(h, p, WEG_GRAVEMARCH)
	h = _weg_gravecrest(h, p)
	h = _weg_einebnen(h, p, WEG_NORD)
	h = _weg_einebnen(h, p, WEG_KUESTE)
	h = _vorwerk(h, p)
	if p.x > -100.0 and p.x < 300.0 and absf(p.y - 60.0) < 300.0 and not stadt_strassen.is_empty():
		if Geometry2D.is_point_in_polygon(p, _stadt):
			# In der Stadt nur einmal glätten, nach der nächsten Gasse: Je Gasse erneut geglättet, zog jede Kreuzung das
			# feine Rauschen mehrfach ab und hob die Gasse an (Buckel von 1,5 m auf der Marktstraße). Die Stadthöhe ist
			# ohnehin glatt; die Gasse nimmt nur das feine Rauschen aus _drachenstein heraus.
			var naechste := INF
			for linie: Array in stadt_strassen:
				naechste = minf(naechste, _abstand_zu(linie, p))
			h -= _fein.get_noise_2dv(p) * 0.25 * (1.0 - smoothstep(4.0, 14.0, naechste))
		else:
			# außerhalb wie bisher (darauf stehen Vorburg, Wege und Rampen)
			for linie: Array in stadt_strassen:
				h = _weg_einebnen(h, p, linie)
	# Bucht vor dem Hafen: offenes Wasser, außerhalb der Mauern
	if not _bucht.is_empty() and p.x > -320.0:
		var db := _polygon_abstand(p, _bucht)
		# Felsufer: am Ufer fern der Wege steigt das Land um 3 bis 9 m an (Landzungen), damit eine Klippe entsteht
		if db > 0.0 and db < 40.0 and not Geometry2D.is_point_in_polygon(p, _hafen) and not Geometry2D.is_point_in_polygon(p, _stadt) \
				and not Geometry2D.is_point_in_polygon(p, _ring):
			var kopf := (3.0 + maxf(0.0, _huegel.get_noise_2dv(p * 0.6)) * 6.0) * (1.0 - _strand(p))
			h += kopf * smoothstep(45.0, 8.0, db) * smoothstep(25.0, 45.0, _naechster_weg(p))
		if db < 14.0 and not Geometry2D.is_point_in_polygon(p, _hafen) and not Geometry2D.is_point_in_polygon(p, _stadt) \
				and not Geometry2D.is_point_in_polygon(p, _ring) and _abstand_zu(WEG_KUESTE, p) > 8.0:
			# Felsküste mit ausgefranster Kante (M8); in kleinen Buchten und an den Wegen ein flaches Ufer
			var strand := maxf(_strand(p), 1.0 - smoothstep(14.0, 28.0, _naechster_weg(p)))
			var ufer := smoothstep(0.0, lerpf(3.5, 14.0, strand), db - _zacke(p) * 2.5 * (1.0 - strand))
			h = minf(h, lerpf(-24.0, h, ufer))
	# Inseln zum Bergfried, nach Burgberg und Bucht, damit beide sie nicht einebnen.
	for insel: Array in INSELN:
		var r: float = insel[1]
		var abstand := p.distance_to(insel[0])
		var insel_h := lerpf(INSEL_HOEHE, -32.0, smoothstep(r * 0.8, r * 1.4, abstand))
		h = maxf(h, insel_h)

	# Grube unter dem Schwarzen Bergfried: Dort liegt sein Unterbau mit vier Ebenen.
	if p.distance_to(BERGFRIED) < BERGFRIED_GRUBE:
		h = -50.0

	# Hafenbecken und Fahrrinne zuletzt, damit nichts sie wieder auffüllt
	# Am Kai bleibt innen ein Rand von 1 m auf Kaihöhe: So liegt der Abbruch ins Becken ganz unter der 4 m dicken
	# Kaimauer (das Raster hat 2,5 m), und neben der Mauer klafft keine Lücke.
	var tief := false
	var am_rand := false
	for k in _becken.size():
		var becken: PackedVector2Array = _becken[k]
		if not Geometry2D.is_point_in_polygon(p, becken):
			continue
		var rand := INF
		for i: int in BECKEN_KAIKANTEN[k] if k < BECKEN_KAIKANTEN.size() else []:
			rand = minf(rand, p.distance_to(Geometry2D.get_closest_point_to_segment(p, becken[i], becken[(i + 1) % becken.size()])))
		if rand > 1.0:
			tief = true
		else:
			am_rand = true
	if tief:
		h = minf(h, BECKEN_TIEFE)
	elif am_rand:
		h = KAI_HOEHE
	h = _pass(h, p, PASS_NORD)
	h = _pass(h, p, PASS_SUED)

	# Rückseite des Felsens hinter dem Palas: Hier hängt der Flaschenzug über dem Abgrund.
	if p.x > -805.0 and p.x < -772.0 and absf(p.y + 365.0) < 40.0:
		h = minf(h, 25.0)

	# Abgrund vor dem Torhaus von Gravecrest, die Zugbrücke führt darüber.
	if p.x > -629.0 and p.x < -613.0 and absf(p.y + 364.0) < 30.0:
		h = minf(h, 10.0)
	return h


## Kleine Buchten mit Strand zwischen den Klippen (0 Klippe, 1 Strand), Flecken von etwa 80 m
func _strand(p: Vector2) -> float:
	return smoothstep(0.62, 0.78, _versatz.get_noise_2dv(p * 4.0 + Vector2(91.0, -47.0)) * 0.5 + 0.5)


## Abstand zur nächsten Landstraße außerhalb der Mauern
func _naechster_weg(p: Vector2) -> float:
	var w := INF
	for linie: Array in [WEG_GRAVEMARCH, WEG_NORD, WEG_KUESTE]:
		w = minf(w, _abstand_zu(linie, p))
	return w


## Wie weit eine Stelle im Gebirge liegt (0 Land, 1 Hauptkamm). Der Fuß läuft nicht gerade: Er springt um bis zu
## 90 m nach innen zurück (nie nach außen, dort liegen die Wege).
func _gebirgsfaktor(p: Vector2) -> float:
	var v := (_versatz.get_noise_2dv(p) * 0.5 + 0.5) * 90.0
	# Volle Höhe erst am Rand der Region: So steigen die Berge über die ganze Breite an statt als Wand
	var b := smoothstep(-330.0 - v, -830.0 - v * 0.3, p.x)
	# Der Nordzug taucht im Osten ins Meer ab, statt am Rand der Region abzubrechen
	b = maxf(b, smoothstep(-470.0 - v * 0.6, -705.0 - v * 0.2, p.y) * (1.0 - smoothstep(700.0 + v * 3.0, 1250.0 + v * 3.0, p.x)))
	b = maxf(b, smoothstep(600.0 + v * 0.8, 755.0 + v * 0.1, p.y) * smoothstep(760.0 - v * 2.5, 560.0 - v * 2.5, p.x))
	b = maxf(b, smoothstep(-800.0, -880.0, p.x))
	return b


## Höhe im Gebirge (Mängelliste M5): statt einer gleich hohen Hochfläche hinter einer geraden Wand erst Vorberge
## (10 bis 70 m), dahinter der Hauptkamm mit einzelnen Gipfeln und Graten (120 bis 380 m), der nach außen noch
## ansteigt. An den Pässen senkt er sich zu einem Sattel. land: Höhe ohne Gebirge.
func _gebirgshoehe(p: Vector2, b: float, n: float, land: float) -> float:
	if b <= 0.0:
		return land
	var huegel := _huegel.get_noise_2dv(p) * 0.5 + 0.5
	var vorberge := 8.0 + huegel * 40.0 + n * 6.0
	# Grate und Täler mit geschwungenem Verlauf: die Koordinaten großräumig verzerrt
	var q := p + Vector2(_versatz.get_noise_2dv(p * 2.5), _versatz.get_noise_2dv(p * 2.5 + Vector2(733.0, 151.0))) * 140.0
	var massiv := clampf(_massiv.get_noise_2dv(q) * 0.5 + 0.5, 0.0, 1.0)
	var grat := clampf(_kamm.get_noise_2dv(q) * 0.5 + 0.5, 0.0, 1.0)
	var aussen := maxf(maxf(-830.0 - p.x, -705.0 - p.y), p.y - 755.0)   # Meter hinter der vollen Höhe
	# In der Region bleibt der Kamm mittelhoch (der Streifen für das Gebirge ist nur 130 bis 230 m breit, höher gäbe
	# eine Wand); nach außen steigt er weiter an, die hohen Gipfel stehen in den Fernbergen.
	var kamm := 45.0 + pow(massiv, 1.3) * 125.0 + grat * grat * 25.0 + clampf(aussen, 0.0, 400.0) * 0.25 + n * 8.0
	# Sättel an den Pässen
	var pass_nah := minf(_abstand_zu(PASS_NORD[0], p), _abstand_zu(PASS_SUED[0], p))
	var sattel := 1.0 - smoothstep(40.0, 260.0, pass_nah)
	kamm = lerpf(kamm, 50.0 + huegel * 40.0, sattel * 0.85)
	vorberge = lerpf(vorberge, 25.0 + huegel * 20.0, sattel * 0.6)
	var h := lerpf(land, vorberge, smoothstep(0.0, 0.3, b))
	return lerpf(h, kamm, smoothstep(0.15, 1.0, b))


## Die Burgfeste nach dem Grundriss: Der Burgberg steigt von Stadt und Hafen nach Osten bis zur Kernburg an der Klippe
## über dem Meer; die Burgen stehen als Terrassen auf ihren Höhen, außen fällt der Berg steil ins Tal.
func _drachenstein(h: float, p: Vector2) -> float:
	# so weit, dass die Ebene um den Burgberg (bis 260 m vor den Mauern) stufenlos ins übrige Land übergeht
	if p.x < -360.0 or p.x > 490.0 or p.y < -520.0 or p.y > 555.0:
		return h
	# Nach dem Grundriss und den Schnitten: Die Burgen liegen auf einem Felsgrat, innerhalb der Ringmauer fallen die
	# Zwinger von den Burgmauern ab. Stadt und Hafen liegen unten in der Ebene. Außen bricht der Fels steil zur Ebene ab;
	# an den Wegen vor den Toren führen flache Rampen hinunter.
	var innen := _innen_hoehe(p)
	if not is_nan(innen):
		h = innen + _fein.get_noise_2dv(p) * 0.25
	else:
		var aussen := minf(_polygon_abstand(p, _ring), minf(_polygon_abstand(p, _stadt), _polygon_abstand(p, _hafen)))
		var rand := p
		var bester := INF
		for vieleck: PackedVector2Array in [_ring, _stadt, _hafen]:
			var q := _naechster_randpunkt(p, vieleck)
			if p.distance_to(q) < bester:
				bester = p.distance_to(q)
				rand = q
		var am_rand := _innen_hoehe(rand + (rand - p).normalized() * 2.0)
		if is_nan(am_rand):
			am_rand = H_EBENE
		var weg := INF
		for linie in [WEG_GRAVEMARCH, WEG_NORD, WEG_KUESTE]:
			weg = minf(weg, _naechster_punkt(linie, p)[0])
		var abfall := lerpf(60.0, float(plan.get("abfall", 14.0)), smoothstep(8.0, 22.0, weg))
		# Vor den Mauern liegt ein tiefer Felsgrund knapp über dem Meer (wie ein Vorgebirge): Die Burg steht hoch über
		# der Ebene; an den Landstraßen vor den Toren bleibt die Ebene auf ihrer Höhe, dort führen die Rampen hinunter.
		var tiefgrund := lerpf(GRUND_VORGEBIRGE, H_EBENE, smoothstep(25.0, 150.0, aussen))
		tiefgrund = lerpf(H_EBENE, tiefgrund, smoothstep(10.0, 40.0, weg))
		var unten := lerpf(tiefgrund + _fein.get_noise_2dv(p * 0.3) * 1.5, h, smoothstep(60.0, 260.0, aussen))
		# Zum Meer hin bricht die Klippe bis auf den Grund ab, ohne Strand davor
		if not _bucht.is_empty():
			# an den Landstraßen vor den Toren (Küstenweg am Südtor) bleibt ein Uferstreifen über dem Wasser
			var see := smoothstep(45.0, 0.0, _polygon_abstand(p, _bucht)) * smoothstep(6.0, 16.0, weg)
			unten = lerpf(unten, -24.0, see)
			abfall = lerpf(abfall, 3.0, see)   # zum Meer hin steil: die Felswand bildet der Küstenfels (teil_felsen.py)
		var t := smoothstep(0.0, abfall, aussen)
		# Felswand in Schichten (wie im Grundriss-Referenzbild), zerklüftet; nicht an den Landstraßen vor den Toren
		var klippe := smoothstep(6.0, 18.0, weg)
		h = _schichten(lerpf(am_rand, unten, t), p, klippe * minf(1.0, t * (1.0 - t) * 8.0)) \
				+ _zacke(p) * 2.0 * t * (1.0 - t) * 4.0 * klippe
	# Burgringe als Terrassen, von außen nach innen (der Zwinger steigt mit seinem Weg). Der felsige Abhang einer
	# Terrasse (rand) gilt nur außerhalb aller Höfe, sonst liefe er in den Nachbarhof hinein.
	var in_hof := false
	for zone: Array in _zonen:
		if Geometry2D.is_point_in_polygon(p, zone[0]):
			in_hof = true
	for zone: Array in _zonen:
		var d := _polygon_abstand(p, zone[0])
		if d < zone[2] and (d <= 0.0 or not in_hof):
			var zh: float = zone[1]
			if not zone[3].is_empty():
				zh = _weg_hoehe(p, zone[3], zone[4])[1]
			var t := smoothstep(0.0, zone[2], d)
			h = zh if d <= 0.0 else _schichten(lerpf(zh, h, t), p, minf(1.0, t * (1.0 - t) * 6.0)) + _zacke(p) * 1.0 * t * (1.0 - t) * 4.0
	# Wege im Burgbezirk mit fester Steigung: Burgweg außen herum, vom Torhaus Nord, Zwingerrampe, vom Nordtor
	for weg: Array in _burgwege:
		h = _burgweg(h, p, weg[0], weg[1], weg[2])
	# Kais auf Höhe der Hafenmauern rings um die Becken
	for becken: PackedVector2Array in _becken:
		var d := _polygon_abstand(p, becken)
		if d > 0.0 and d < 14.0 and Geometry2D.is_point_in_polygon(p, _hafen):
			h = lerpf(KAI_HOEHE, h, smoothstep(9.0, 14.0, d))
	return h


## Geschichteter Fels: Die Höhe wird in Bänder von etwa 5 m geteilt, je Band ein schmaler Absatz und eine steile Wand;
## die Kanten der Bänder laufen unregelmäßig. staerke 0 lässt die Höhe, wie sie ist.
func _schichten(h: float, p: Vector2, staerke: float) -> float:
	if staerke <= 0.0:
		return h
	var band := 5.0 + _fein.get_noise_2dv(p * 0.2) * 1.5
	var versatz := _zacken.get_noise_2dv(p * 0.5) * 1.8
	var q := (h + versatz) / band
	var stufe := (floorf(q) + smoothstep(0.3, 0.85, q - floorf(q))) * band - versatz
	return lerpf(h, stufe, staerke * 0.8)


## Zerklüfteter Fels: Grate und Rinnen (etwa -1 bis 1), für Klippen und Felsstufen.
func _zacke(p: Vector2) -> float:
	return _zacken.get_noise_2dv(p) * 1.4 + _fein.get_noise_2dv(p * 2.3) * 0.4


## Höhe innerhalb der Mauern (NAN außerhalb): Hafen und Stadt in der Ebene, im Burgbezirk der Hang des Grats.
func _innen_hoehe(p: Vector2) -> float:
	if Geometry2D.is_point_in_polygon(p, _hafen):
		return KAI_HOEHE
	if Geometry2D.is_point_in_polygon(p, _stadt):
		return stadthoehe(p)
	if Geometry2D.is_point_in_polygon(p, _ring) and not _ringwege.is_empty():
		# Zwischen den Burgen und der Ringmauer liegt der Grund auf der Höhe des nächsten Burgwegs; die Burgen stehen
		# als Felsen darüber (Zonen mit steilem Rand)
		var naechst := [INF, 0.0]
		for weg: Array in _ringwege:
			var info := _weg_hoehe(p, weg[0], weg[1])
			if info[0] < naechst[0]:
				naechst = info
		return float(naechst[1]) + _fein.get_noise_2dv(p * 0.5) * 1.2
	if Geometry2D.is_point_in_polygon(p, _ring):
		# Unter den Burgmauern bricht der Fels steil ab, darunter liegt der Zwinger vor der Ringmauer
		var info := _naechster_punkt(_firstlinie, p)
		var gh: Array = plan["grat_hoehen"]
		var zh: Array = plan["zwinger_hoehen"]
		var first := lerpf(float(gh[0]), float(gh[1]), float(info[1]))
		var zwinger := lerpf(float(zh[0]), float(zh[1]), float(info[1])) + _fein.get_noise_2dv(p * 0.5) * 1.2
		return maxf(first - maxf(0.0, float(info[0]) - 26.0) * float(plan.get("grat_abfall", 1.3)), zwinger)
	return NAN


## Höhe der Stadt: von Westen zum Hafen leicht fallend, zur Vorburg hin ansteigend (die Gassen führen im Bogen hinauf
## zum Vorburgtor).
func stadthoehe(p: Vector2) -> float:
	var w: Array = plan["stadt_hoehe"]
	var t := clampf((p.y - float(w[0])) / (float(w[2]) - float(w[0])), 0.0, 1.0)
	var h := lerpf(float(w[1]), float(w[3]), t)
	if not _anstieg.is_empty():
		var a: Dictionary = plan["stadt_anstieg"]
		var d := maxf(0.0, _polygon_abstand(p, _anstieg))
		h = lerpf(float(a["hoehe"]), h, smoothstep(0.0, float(a["weite"]), d))
	return h


## Weg mit fester Höhe je Punkt (dazwischen linear), 7 m breit eben, bis 7 m ins Gelände übergehend.
func _burgweg(h: float, p: Vector2, linie: Array, hoehen: Array, flanke: Array = [3.5, 7.0]) -> float:
	var info := _weg_hoehe(p, linie, hoehen)
	if info[0] > float(flanke[1]):
		return h
	return lerpf(info[1], h, smoothstep(float(flanke[0]), float(flanke[1]), info[0]))


## [Abstand, Höhe] des nächsten Punkts auf einem Weg mit Höhen je Punkt.
func _weg_hoehe(p: Vector2, linie: Array, hoehen: Array) -> Array:
	var bester := INF
	var hw := 0.0
	for i in linie.size() - 1:
		var a: Vector2 = linie[i]
		var b: Vector2 = linie[i + 1]
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		var d := p.distance_to(q)
		if d < bester:
			bester = d
			hw = lerpf(float(hoehen[i]), float(hoehen[i + 1]), a.distance_to(q) / maxf(a.distance_to(b), 0.01))
	return [bester, hw]


## Nächster Punkt auf dem Rand eines Vielecks.
func _naechster_randpunkt(p: Vector2, ecken: PackedVector2Array) -> Vector2:
	var bester := INF
	var punkt := p
	for i in ecken.size():
		var q := Geometry2D.get_closest_point_to_segment(p, ecken[i], ecken[(i + 1) % ecken.size()])
		if p.distance_to(q) < bester:
			bester = p.distance_to(q)
			punkt = q
	return punkt


## Gravemarch: aufgeschütteter Hügel in der Form der Hauptmauer, darum ein Wassergraben.
## Auf der Seite der Kernburg (Süden) gibt es keinen Graben, wie im Grundriss.
func _gravemarch(h: float, p: Vector2) -> float:
	var lokal := p - GRAVEMARCH
	if lokal.length() > 120.0:
		return h
	var d := _polygon_abstand(lokal, GRAVEMARCH_UMRISS)
	h = lerpf(h, -4.0, 1.0 - smoothstep(6.0, 14.0, d))
	var graben := 1.0 - smoothstep(0.0, 3.0, absf(d - 11.5) - 2.0)
	graben *= 1.0 - smoothstep(25.0, 40.0, lokal.y)
	h = lerpf(h, minf(h, GRABEN_SOHLE), graben)
	for insel: Array in GRAVEMARCH_INSELN:
		var r: float = insel[1]
		h = lerpf(h, -4.0, 1.0 - smoothstep(r, r + 3.0, lokal.distance_to(insel[0])))
	return h


## Abstand zu einem geschlossenen Vieleck, innen 0.
func _polygon_abstand(p: Vector2, ecken: Array) -> float:
	if Geometry2D.is_point_in_polygon(p, PackedVector2Array(ecken)):
		return 0.0
	var bester := INF
	for i in ecken.size():
		var a: Vector2 = ecken[i]
		var b: Vector2 = ecken[(i + 1) % ecken.size()]
		bester = minf(bester, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return bester


## Farbmaske für den Gelände-Shader: Rot = Weg, Grün = Sumpf, Blau = gepflasterter Burghof.
func maske_bei(p: Vector2) -> Color:
	var weg := INF
	for linie in [WEG_GRAVEMARCH, WEG_GRAVECREST, WEG_NORD, WEG_KUESTE, PASS_NORD[0], PASS_SUED[0]] + stadt_strassen + _burgwege.map(func(w): return w[0]):
		weg = minf(weg, _abstand_zu(linie, p))
	if not _markt.is_empty() and Geometry2D.is_point_in_polygon(p, _markt):
		weg = 0.0
	var gm := p.distance_to(GRAVEMARCH)
	var sumpf := (1.0 - smoothstep(115.0, 140.0, gm)) * smoothstep(17.0, 26.0, _polygon_abstand(p - GRAVEMARCH, GRAVEMARCH_UMRISS))
	sumpf *= clampf(0.6 + _fein.get_noise_2dv(p * 0.5), 0.0, 1.0)
	var hof := 0.0
	for vieleck: PackedVector2Array in _hoefe:
		if Geometry2D.is_point_in_polygon(p, vieleck):
			hof = 1.0
	# Felsgrund im Burgbezirk außerhalb der Höfe (Zwinger, Absätze zwischen den Terrassen)
	if hof < 0.5 and not _ring.is_empty() and Geometry2D.is_point_in_polygon(p, _ring) \
			and not Geometry2D.is_point_in_polygon(p, _stadt) and not Geometry2D.is_point_in_polygon(p, _hafen):
		hof = 0.5
	return Color(1.0 - smoothstep(2.5, 4.5, weg), sumpf, hof)


## Ordensvorwerk (Hof aus Akt I) vor der Stadt am Küstenweg: ein ebener, gedrehter Platz mit dem Weg vom Tor
## (lokal +z) zur Straße. Maße aus daten/drachenstein_plan.json ("vorwerk").
func _vorwerk(h: float, p: Vector2) -> float:
	var vw: Dictionary = plan.get("vorwerk", {})
	if vw.is_empty():
		return h
	var d := p - Vector2(vw["mitte"][0], vw["mitte"][1])
	var a := deg_to_rad(float(vw["dreh"]))
	# Welt → lokal (Drehung um y wie in Godot: lokal +z zeigt nach (sin a, cos a))
	var lokal := Vector2(d.x * cos(a) - d.y * sin(a), d.x * sin(a) + d.y * cos(a))
	var halb := float(vw["halb"])
	var abstand := minf(_rechteck_abstand(lokal, Vector2(-halb, -halb), Vector2(halb, halb)),
			_rechteck_abstand(lokal, Vector2(-4.0, 0.0), Vector2(4.0, float(vw["weg"]))))
	var rand := float(vw["rand"])
	if abstand >= rand:
		return h
	return lerpf(float(vw["hoehe"]), h, smoothstep(0.0, rand, abstand))


func _weg_einebnen(h: float, p: Vector2, linie: Array) -> float:
	return _einebnen_bei(h, p, _abstand_zu(linie, p))


func _einebnen_bei(h: float, p: Vector2, abstand: float) -> float:
	if abstand > 14.0:
		return h
	# Auf dem Weg wird das Gelände geglättet: Höhe ohne feines Rauschen.
	var glatt := h - _fein.get_noise_2dv(p) * 0.8
	return lerpf(glatt, h, smoothstep(4.0, 14.0, abstand))


## Der Weg nach Gravecrest bekommt eine feste Steigung vom Tal bis auf Höhe 70.
func _weg_gravecrest(h: float, p: Vector2) -> float:
	var info := _naechster_punkt(WEG_GRAVECREST, p)
	var abstand: float = info[0]
	if abstand > 30.0:
		return h
	var anteil: float = info[1]
	var weg_h := lerpf(hoehe_tal_start(), GRAVECREST_HOEHE, smoothstep(0.0, 1.0, anteil))
	return lerpf(weg_h, h, smoothstep(5.0, 30.0, abstand))


## Ein Weg über einen Pass: feste Steigung, das Gebirge daneben wird zu einem Tal ausgeräumt.
func _pass(h: float, p: Vector2, pass_daten: Array) -> float:
	var info := _naechster_punkt(pass_daten[0], p)
	var abstand: float = info[0]
	if abstand > 40.0:
		return h
	var weg_h := lerpf(pass_daten[1], pass_daten[2], smoothstep(0.0, 1.0, info[1]))
	return lerpf(weg_h, h, smoothstep(6.0, 40.0, abstand))


func hoehe_tal_start() -> float:
	return -4.0


## Abstand zu einem Linienzug.
func _abstand_zu(linie: Array, p: Vector2) -> float:
	return _naechster_punkt(linie, p)[0]


## [Abstand, Anteil der Weglänge 0..1] zum nächsten Punkt auf dem Linienzug.
func _naechster_punkt(linie: Array, p: Vector2) -> Array:
	var gesamt := 0.0
	for i in linie.size() - 1:
		gesamt += (linie[i] as Vector2).distance_to(linie[i + 1])
	var bester := INF
	var bester_anteil := 0.0
	var bisher := 0.0
	for i in linie.size() - 1:
		var a: Vector2 = linie[i]
		var b: Vector2 = linie[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var abstand := p.distance_to(a + ab * t)
		if abstand < bester:
			bester = abstand
			bester_anteil = (bisher + ab.length() * t) / gesamt
		bisher += ab.length()
	return [bester, bester_anteil]


func _rechteck_abstand(p: Vector2, minimum: Vector2, maximum: Vector2) -> float:
	var dx := maxf(maxf(minimum.x - p.x, 0.0), p.x - maximum.x)
	var dz := maxf(maxf(minimum.y - p.y, 0.0), p.y - maximum.y)
	return sqrt(dx * dx + dz * dz)


func _vorschaufarbe(h: float, m: Color) -> Color:
	var farbe: Color
	if h < wasserspiegel:
		farbe = Color(0.25, 0.4, 0.55).darkened(clampf((wasserspiegel - h) / 20.0, 0.0, 0.6))
	elif h > 100.0:
		farbe = Color(0.9, 0.92, 0.95)
	elif h > 40.0:
		farbe = Color(0.5, 0.48, 0.45)
	else:
		farbe = Color(0.35, 0.45, 0.25).lightened(clampf((h + 20.0) / 120.0, 0.0, 0.4))
	farbe = farbe.lerp(Color(0.3, 0.33, 0.2), m.g)
	return farbe.lerp(Color(0.6, 0.5, 0.35), m.r)
