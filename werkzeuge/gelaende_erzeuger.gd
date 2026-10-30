class_name GelaendeErzeuger
## Erzeugt das Gelände der Region Drachenstein nach der Karte von Sorrowland.
##
## Maßstab 1:50 (1 km auf der Karte = 20 m im Spiel). Ursprung (0, 0) ist der Kernhof
## der Burgfeste Drachenstein, +x ist Osten, +z ist Süden. Lage der Orte:
##   Burgfeste Drachenstein   (0, 0)        Kernhof (Mittlere Burg) auf Höhe 0. Die ganze Anlage nach dem
##                                          Grundriss 1:1 (daten/drachenstein_plan.json): Oberer Burg oben im
##                                          Westen, Stadt den Hang hinab, Hafen im Osten am Meer
##   Schwarzer Bergfried       (990, 150)    Insel, von der Hafenmole über zwei Inseln erreichbar
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
const BERGFRIED := Vector2(990, 150)
## Umriss der Hauptmauer von Gravemarch (mit dem Verfallenen Vorhof im Osten), relativ zur Mitte.
const GRAVEMARCH_UMRISS := [Vector2(51, -48.1), Vector2(64, -37.7), Vector2(41, -6.5), Vector2(60, -2),
	Vector2(60, 24), Vector2(33, 26), Vector2(31, 37.7), Vector2(22, 50.7), Vector2(4, 54.6), Vector2(-26, 52),
	Vector2(-43, 44.2), Vector2(-54, 39), Vector2(-60, 23.4), Vector2(-63, -11.7), Vector2(-65, -32.5),
	Vector2(-48, -40.3), Vector2(-36, -35), Vector2(-19, -37.7), Vector2(4, -45.5), Vector2(22, -35), Vector2(39, -45.5)]
## Inseln im Graben für das Südliche Vorwerk und das unechte Südtor: [Mitte relativ, Radius].
const GRAVEMARCH_INSELN := [[Vector2(-8, -59), 7.0], [Vector2(-35, -63), 8.0]]
const GRABEN_SOHLE := -13.0
## Inseln zwischen Drachenkai und Bergfried: [Mitte, Radius].
const INSELN := [[Vector2(790, 58), 10.0], [Vector2(872, 82), 9.0], [Vector2(952.4, 110.4), 9.0], [BERGFRIED, 40.0]]
const INSEL_HOEHE := -17.8
## Radius der Grube für den Unterbau des Bergfrieds (liegt innerhalb seiner 10 m dicken Mauer).
const BERGFRIED_GRUBE := 17.0

## Küste: so weit östlich liegt im Mittel die Wasserlinie.
const KUESTE_X := 680.0
const KAI_HOEHE := -17.8
const H_ZWINGER := -3.0     # Äußerer Zwinger: Rand der Burgkuppe
const H_EBENE := -14.0      # Land vor der Löwenward
const BECKEN_TIEFE := -27.0

## Wege als Linienzüge.
const WEG_GRAVEMARCH := [Vector2(-72.6, 181.3), Vector2(-120, 215), Vector2(-220, 170), Vector2(-300, 80),
	Vector2(-380, -20), Vector2(-460, -150), Vector2(-490, -215), Vector2(-528.8, -265.1)]
## Der Weg nach Gravecrest steigt vom Tal bis zur Zugbrücke auf Höhe 70.
const WEG_GRAVECREST := [Vector2(-460, -150), Vector2(-470, -240), Vector2(-500, -310),
	Vector2(-560, -345), Vector2(-612, -363)]
const GRAVECREST_HOEHE := 70.0
## Landstraßen: die Nordstraße verlässt die Stadt durch das Südöstliche Tor (19) und steigt über einen Pass
## im Norden (nach Riverlock), der Küstenweg durch das Westtor der Löwenward über einen Pass im Süden.
const WEG_NORD := [Vector2(474.2, -296.6), Vector2(486, -306), Vector2(430, -380), Vector2(330, -450), Vector2(230, -500)]
const WEG_KUESTE := [Vector2(502.4, 425.0), Vector2(512, 429), Vector2(508, 520), Vector2(515, 600)]
## Passstrecken mit fester Steigung: [Linienzug, Höhe am Anfang, Höhe am Ende].
const PASS_NORD := [[Vector2(230, -500), Vector2(150, -560), Vector2(110, -610), Vector2(85, -660)], -4.0, 30.0]
const PASS_SUED := [[Vector2(515, 600), Vector2(530, 660), Vector2(545, 735)], -8.0, 22.0]

## Grundriss der Burgfeste (werkzeuge/bau/plan_drachenstein.py schreibt ihn)
var plan: Dictionary = {}
var _zonen: Array = []          # [PackedVector2Array, Höhe, Rand]
var _stadt := PackedVector2Array()
var _becken: Array = []         # Hafenbecken, Kanal, Fahrrinne
var _markt := PackedVector2Array()
var _ebene := PackedVector2Array()    # Marktviertel und Hafen: flach
var _kuppe := PackedVector2Array()    # Äußerer Zwinger: Rand der Burgkuppe
var _treppe: Array = []               # [Anfang (x, z, y), Ende (x, z, y)]
var stadt_strassen: Array = []

var _rauschen := FastNoiseLite.new()
var _fein := FastNoiseLite.new()
var _grat := FastNoiseLite.new()


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
			_zonen.append([vec.call(z["punkte"]), float(z["hoehe"]), float(z["rand"])])
		_stadt = vec.call(plan["stadt"])
		_markt = vec.call(plan["markt"])
		_ebene = vec.call(plan["ebene"])
		_kuppe = vec.call(plan["kuppe"])
		_treppe = plan["treppe"]
		for name in ["hafen_becken", "kanal", "fahrrinne"]:
			_becken.append(vec.call(plan[name]))
		for linie: Array in plan["strassen"]:
			stadt_strassen.append(Array(vec.call(linie)))
	_rauschen.seed = 1750
	_rauschen.frequency = 0.004
	_fein.seed = 940
	_fein.frequency = 0.03
	_grat.seed = 1065
	_grat.frequency = 0.007


## Erzeugt alle Dateien und gibt die Anzahl der Höhenpunkte zurück.
func erzeuge() -> int:
	var breite := int(groesse.x / abstand) + 1
	var tiefe := int(groesse.y / abstand) + 1
	var hoehen := PackedFloat32Array()
	hoehen.resize(breite * tiefe)
	var maske := Image.create(breite, tiefe, false, Image.FORMAT_RGB8)
	var vorschau := Image.create(breite, tiefe, false, Image.FORMAT_RGB8)

	for iz in tiefe:
		for ix in breite:
			var p := ursprung + Vector2(ix, iz) * abstand
			var h := hoehe(p)
			hoehen[iz * breite + ix] = h
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
	return breite * tiefe


## Höhe an einer Stelle der Welt (x, z).
func hoehe(p: Vector2) -> float:
	var n := _rauschen.get_noise_2dv(p)
	var fein := _fein.get_noise_2dv(p)

	# Hügeliges Land um Drachenstein.
	var h := 3.0 + n * 7.0 + fein * 0.8

	# Gebirge: Eisgrat im Westen, Ränder der Region im Norden und Süden.
	var grat := 1.0 - absf(_grat.get_noise_2dv(p))
	var gebirge := 120.0 + grat * 70.0 + n * 20.0
	var berg := smoothstep(-330.0, -560.0, p.x)
	berg = maxf(berg, smoothstep(-470.0, -600.0, p.y))
	berg = maxf(berg, smoothstep(600.0, 700.0, p.y) * smoothstep(760.0, 560.0, p.x))
	berg = maxf(berg, smoothstep(-800.0, -880.0, p.x))

	# Das Tal nach Gravemarch hält das Gebirge zurück.
	var tal_abstand := _abstand_zu([Vector2(-200, 190), Vector2(-300, 80), Vector2(-380, -20), Vector2(-460, -150), GRAVEMARCH], p)
	# Das Tal zieht sich bis unter den Felssporn von Gravecrest.
	tal_abstand = minf(tal_abstand, _abstand_zu([GRAVEMARCH, Vector2(-560, -300), Vector2(-660, -380), Vector2(-740, -420)], p))
	var tal := 1.0 - smoothstep(70.0, 170.0, tal_abstand)
	var talboden := lerpf(0.0, -8.0, smoothstep(-260.0, -560.0, p.x)) + n * 2.0
	berg *= 1.0 - tal
	h = lerpf(h, talboden, tal)
	h = lerpf(h, gebirge, berg)

	# Felssporn von Gravecrest: schmaler Grat mit flacher Krone auf Höhe 70.
	if p.x < -625.0 and p.x > -860.0:
		# Die Krone ist flach und breit genug für die Burg nach Grundriss (130 x 36 m).
		var quer := absf(p.y - (-365.0))
		var flanke := 1.0 - smoothstep(19.0, 50.0, quer)
		var krone := GRAVECREST_HOEHE + maxf(0.0, -p.x - 775.0) * 0.8
		h = lerpf(h, maxf(h, krone), flanke)

	# Küste: Das Land fällt zum Wächtermeer hin ab.
	var kueste := KUESTE_X + 20.0 * sin(p.y / 110.0)
	var d := p.x - kueste
	h = lerpf(h, -18.6, smoothstep(-110.0, 0.0, d) * (1.0 - berg))
	h -= smoothstep(5.0, 70.0, d) * 15.0

	# Inseln zum Bergfried.
	for insel: Array in INSELN:
		var r: float = insel[1]
		var abstand := p.distance_to(insel[0])
		var insel_h := lerpf(INSEL_HOEHE, -32.0, smoothstep(r * 0.8, r * 1.4, abstand))
		h = maxf(h, insel_h)

	# Grube unter dem Schwarzen Bergfried: Dort liegt sein Unterbau mit vier Ebenen.
	if p.distance_to(BERGFRIED) < BERGFRIED_GRUBE:
		h = -50.0

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
	if p.x > -350.0 and p.x < 720.0 and absf(p.y - 60.0) < 500.0:
		for linie: Array in stadt_strassen:
			h = _weg_einebnen(h, p, linie)
	# Hafenbucht vor Schiffstor und Hafentor: offenes Wasser für Fahrrinne und Mole
	if p.x > 600.0 and not Geometry2D.is_point_in_polygon(p, _stadt):
		var bucht := maxf(645.0 - p.x, absf(p.y - 5.0) - 75.0)
		if bucht < 0.0:
			h = minf(h, lerpf(-24.0, h, smoothstep(-12.0, 0.0, bucht)))
	# Hafenbecken und Fahrrinne zuletzt, damit nichts sie wieder auffüllt
	for becken: PackedVector2Array in _becken:
		if Geometry2D.is_point_in_polygon(p, becken):
			h = minf(h, BECKEN_TIEFE)
	h = _pass(h, p, PASS_NORD)
	h = _pass(h, p, PASS_SUED)

	# Rückseite des Felsens hinter dem Palas: Hier hängt der Flaschenzug über dem Abgrund.
	if p.x > -805.0 and p.x < -772.0 and absf(p.y + 365.0) < 40.0:
		h = minf(h, 25.0)

	# Abgrund vor dem Torhaus von Gravecrest, die Zugbrücke führt darüber.
	if p.x > -629.0 and p.x < -613.0 and absf(p.y + 364.0) < 30.0:
		h = minf(h, 10.0)
	return h


## Die Burgfeste: Ein Grat steigt vom Eisgrat zum Drachenhorst und fällt zum Kernhof ab. In der Löwenward
## fällt die Stadt vom Treppentor zum Hafen; die Burgringe sind Terrassen auf ihren Höhen (Grundriss).
func _drachenstein(h: float, p: Vector2) -> float:
	if p.x < -480.0 or p.x > 760.0 or p.y < -540.0 or p.y > 660.0:
		return h
	# Nach den Schnitten A-A und B-B: Die Burgen liegen auf einer Felskuppe. Innerhalb der Löwenward fallen Gärten
	# und Terrassen von der Kuppe ab, nur Marktviertel und Hafen liegen in der Ebene. Außen an der Löwenward bricht
	# der Fels steil zur Ebene ab; an den Wegen vor den Toren führen flache Rampen hinunter.
	if Geometry2D.is_point_in_polygon(p, _stadt):
		h = _innen_hoehe(p) + _fein.get_noise_2dv(p) * 0.25
	else:
		var aussen := _polygon_abstand(p, _stadt)
		var rand := _naechster_randpunkt(p, _stadt)
		var innen := _innen_hoehe(rand + (rand - p).normalized() * 2.0)
		if p.x > 60.0:
			# zur Küste hin: wie bisher sanft auf die Höhe der Stadt
			var ziel := innen + aussen * 0.06
			if h > ziel:
				h = lerpf(ziel, h, smoothstep(10.0, 160.0, aussen))
		else:
			var weg := INF
			for linie in [WEG_GRAVEMARCH, WEG_NORD, WEG_KUESTE]:
				weg = minf(weg, _naechster_punkt(linie, p)[0])
			var abfall := lerpf(60.0, 14.0, smoothstep(8.0, 22.0, weg))
			var fels := _fein.get_noise_2dv(p * 0.7) * 2.5
			var unten := lerpf(H_EBENE + _fein.get_noise_2dv(p * 0.3) * 1.5, h, smoothstep(60.0, 260.0, aussen))
			h = lerpf(innen + fels * (1.0 - smoothstep(0.0, abfall, aussen)), unten, smoothstep(0.0, abfall, aussen))
	# Burgringe als Terrassen, von außen nach innen
	for zone: Array in _zonen:
		var d := _polygon_abstand(p, zone[0])
		if d <= 0.0:
			h = zone[1]
		elif d < zone[2]:
			h = lerpf(zone[1], h, smoothstep(0.0, zone[2], d))
	# Die große Treppe vom Markt hinauf zum Äußeren Zwinger: gerade Rampe im Gelände
	if not _treppe.is_empty():
		var a := Vector2(_treppe[0][0], _treppe[0][1])
		var b := Vector2(_treppe[1][0], _treppe[1][1])
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		var d := p.distance_to(q)
		if d < 9.0:
			var t := (q - a).length() / maxf((b - a).length(), 0.01)
			h = lerpf(lerpf(float(_treppe[0][2]), float(_treppe[1][2]), t), h, smoothstep(5.0, 9.0, d))
	# Kais auf Höhe der Hafenmauern rings um die Becken
	for becken: PackedVector2Array in _becken:
		var d := _polygon_abstand(p, becken)
		if d > 0.0 and d < 14.0 and Geometry2D.is_point_in_polygon(p, _stadt):
			h = lerpf(KAI_HOEHE, h, smoothstep(9.0, 14.0, d))
	return h


## Höhe innerhalb der Löwenward: in der Ebene das Marktviertel, sonst der Hang der Burgkuppe.
func _innen_hoehe(p: Vector2) -> float:
	if Geometry2D.is_point_in_polygon(p, _ebene):
		return stadthoehe(p)
	return H_ZWINGER - 7.0 * pow(smoothstep(0.0, 130.0, _polygon_abstand(p, _kuppe)), 0.8)


## Höhe der Ebene: am Fuß der Treppe (Markt oben) bis zum Hafen (Markt unten), weiter bis an die Kais.
func stadthoehe(p: Vector2) -> float:
	var oben: Array = plan["markt_oben"]
	var unten: Array = plan["markt_unten"]
	var t := clampf((p.x - float(oben[0])) / (float(unten[0]) - float(oben[0])), 0.0, 1.0)
	var hh := lerpf(float(oben[1]), float(unten[1]), t)
	if p.x > float(unten[0]):
		hh = lerpf(float(unten[1]), KAI_HOEHE + 0.8, clampf((p.x - float(unten[0])) / 220.0, 0.0, 1.0))
	return hh


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


## Farbmaske für den Gelände-Shader: Rot = Weg, Grün = Sumpf.
func maske_bei(p: Vector2) -> Color:
	var weg := INF
	for linie in [WEG_GRAVEMARCH, WEG_GRAVECREST, WEG_NORD, WEG_KUESTE, PASS_NORD[0], PASS_SUED[0]] + stadt_strassen:
		weg = minf(weg, _abstand_zu(linie, p))
	if not _markt.is_empty() and Geometry2D.is_point_in_polygon(p, _markt):
		weg = 0.0
	var gm := p.distance_to(GRAVEMARCH)
	var sumpf := (1.0 - smoothstep(115.0, 140.0, gm)) * smoothstep(17.0, 26.0, _polygon_abstand(p - GRAVEMARCH, GRAVEMARCH_UMRISS))
	sumpf *= clampf(0.6 + _fein.get_noise_2dv(p * 0.5), 0.0, 1.0)
	return Color(1.0 - smoothstep(2.5, 4.5, weg), sumpf, 0.0)


func _weg_einebnen(h: float, p: Vector2, linie: Array) -> float:
	var abstand := _abstand_zu(linie, p)
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
