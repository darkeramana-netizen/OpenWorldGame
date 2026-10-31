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
const BECKEN_TIEFE := -27.0

## Wege als Linienzüge.
const WEG_GRAVEMARCH := [Vector2(-27.2, 220.5), Vector2(-45, 225), Vector2(-120, 215), Vector2(-220, 170), Vector2(-300, 80),
	Vector2(-380, -20), Vector2(-460, -150), Vector2(-490, -215), Vector2(-528.8, -265.1)]
## Der Weg nach Gravecrest steigt vom Tal bis zur Zugbrücke auf Höhe 70.
const WEG_GRAVECREST := [Vector2(-460, -150), Vector2(-470, -240), Vector2(-500, -310),
	Vector2(-560, -345), Vector2(-612, -363)]
const GRAVECREST_HOEHE := 70.0
## Landstraßen: Die Nordstraße zweigt vor dem Torhaus Nord vom Weg nach Gravemarch ab, läuft am Fuß des Burgbergs
## entlang (auf der Landseite, die Burg steht an der Klippe zum Meer) und steigt über einen Pass im Norden (nach
## Riverlock); der Küstenweg verlässt die Stadt durch das Torhaus West über einen Pass im Süden.
const WEG_NORD := [Vector2(-45, 225), Vector2(-110, 200), Vector2(-150, 120), Vector2(-160, 0), Vector2(-155, -150),
		Vector2(-130, -300), Vector2(-60, -380), Vector2(40, -410), Vector2(150, -430), Vector2(230, -500)]
const WEG_KUESTE := [Vector2(109.8, 288.8), Vector2(116, 300), Vector2(122, 390), Vector2(132, 470), Vector2(140, 540)]
## Passstrecken mit fester Steigung: [Linienzug, Höhe am Anfang, Höhe am Ende].
const PASS_NORD := [[Vector2(230, -500), Vector2(150, -560), Vector2(110, -610), Vector2(85, -660)], -4.0, 30.0]
const PASS_SUED := [[Vector2(140, 540), Vector2(150, 615), Vector2(160, 690)], -13.0, 22.0]

## Grundriss der Burgfeste (werkzeuge/bau/plan_drachenstein.py schreibt ihn)
var plan: Dictionary = {}
var _zonen: Array = []          # [PackedVector2Array, Höhe, Rand, Weg, Weghöhen] (mit Weg: Höhe des nächsten Wegpunkts)
var _stadt := PackedVector2Array()
var _becken: Array = []         # Hafenbecken, Kanal, Fahrrinne
var _markt := PackedVector2Array()
var _ring := PackedVector2Array()     # Burgbezirk innerhalb der Ringmauer (Grat und Zwinger)
var _hafen := PackedVector2Array()    # Hafenbezirk: Kais
var _bucht := PackedVector2Array()    # Bucht vor dem Hafen
var _felsenhafen := PackedVector2Array()  # Kai im Felsenhafen hinter dem Wassertor (überwölbt)
var _firstlinie: Array = []           # Firstlinie des Felsgrats
var _burgwege: Array = []             # [Linienzug, Höhen je Punkt]
var _ringwege: Array = []             # Burgwege, deren Höhe der Grund im Burgbezirk folgt
var stadt_strassen: Array = []

var _rauschen := FastNoiseLite.new()
var _fein := FastNoiseLite.new()
var _grat := FastNoiseLite.new()
var _zacken := FastNoiseLite.new()   # zerklüftete Klippen


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
		_stadt = vec.call(plan["stadt"])
		_markt = vec.call(plan["markt"])
		_ring = vec.call(plan["ring"])
		_hafen = vec.call(plan["hafen"])
		_bucht = vec.call(plan["bucht"])
		_felsenhafen = vec.call(plan["felsenhafen"])
		_firstlinie = Array(vec.call(plan["grat"]))
		for weg: Array in plan["burgwege"]:
			_burgwege.append([Array(vec.call(weg[0])), weg[1]])
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
	if p.x > -100.0 and p.x < 300.0 and absf(p.y - 60.0) < 300.0:
		for linie: Array in stadt_strassen:
			h = _weg_einebnen(h, p, linie)
	# Bucht vor dem Hafen: offenes Wasser, außerhalb der Mauern
	if not _bucht.is_empty() and p.x > 60.0:
		var db := _polygon_abstand(p, _bucht)
		if db < 14.0 and not Geometry2D.is_point_in_polygon(p, _hafen) and not Geometry2D.is_point_in_polygon(p, _stadt) \
				and not Geometry2D.is_point_in_polygon(p, _ring):
			h = minf(h, lerpf(-24.0, h, smoothstep(0.0, 14.0, db)))
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
		var unten := lerpf(H_EBENE + _fein.get_noise_2dv(p * 0.3) * 1.5, h, smoothstep(60.0, 260.0, aussen))
		# Zum Meer hin bricht die Klippe bis auf den Grund ab, ohne Strand davor
		if not _bucht.is_empty():
			var see := smoothstep(45.0, 0.0, _polygon_abstand(p, _bucht))
			unten = lerpf(unten, -24.0, see)
			abfall = lerpf(abfall, 18.0, see)
		var t := smoothstep(0.0, abfall, aussen)
		# Felswand in Schichten (wie im Grundriss-Referenzbild), zerklüftet; nicht an den Landstraßen vor den Toren
		var klippe := smoothstep(6.0, 18.0, weg)
		h = _schichten(lerpf(am_rand, unten, t), p, klippe * minf(1.0, t * (1.0 - t) * 8.0)) \
				+ _zacke(p) * 2.0 * t * (1.0 - t) * 4.0 * klippe
	# Burgringe als Terrassen, von außen nach innen (der Zwinger steigt mit seinem Weg)
	for zone: Array in _zonen:
		var d := _polygon_abstand(p, zone[0])
		if d < zone[2]:
			var zh: float = zone[1]
			if not zone[3].is_empty():
				zh = _weg_hoehe(p, zone[3], zone[4])[1]
			var t := smoothstep(0.0, zone[2], d)
			h = zh if d <= 0.0 else _schichten(lerpf(zh, h, t), p, minf(1.0, t * (1.0 - t) * 6.0)) + _zacke(p) * 1.0 * t * (1.0 - t) * 4.0
	# Wege im Burgbezirk mit fester Steigung: Burgweg außen herum, vom Torhaus Nord, Zwingerweg, vom Nordtor
	for weg: Array in _burgwege:
		h = _burgweg(h, p, weg[0], weg[1])
	# Kai im Felsenhafen (darüber das Gewölbe), das Wasser schneidet der Kanal hinein
	if Geometry2D.is_point_in_polygon(p, _felsenhafen):
		h = KAI_HOEHE + 0.2
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
		return KAI_HOEHE + 0.2
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


## Höhe der Stadt: vom Torhaus West zum Hafen leicht fallend.
func stadthoehe(p: Vector2) -> float:
	var w: Array = plan["stadt_hoehe"]
	var t := clampf((p.y - float(w[0])) / (float(w[2]) - float(w[0])), 0.0, 1.0)
	return lerpf(float(w[1]), float(w[3]), t)


## Weg mit fester Höhe je Punkt (dazwischen linear), 7 m breit eben, bis 7 m ins Gelände übergehend.
func _burgweg(h: float, p: Vector2, linie: Array, hoehen: Array) -> float:
	var info := _weg_hoehe(p, linie, hoehen)
	if info[0] > 7.0:
		return h
	return lerpf(info[1], h, smoothstep(3.5, 7.0, info[0]))


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


## Farbmaske für den Gelände-Shader: Rot = Weg, Grün = Sumpf.
func maske_bei(p: Vector2) -> Color:
	var weg := INF
	for linie in [WEG_GRAVEMARCH, WEG_GRAVECREST, WEG_NORD, WEG_KUESTE, PASS_NORD[0], PASS_SUED[0]] + stadt_strassen + _burgwege.map(func(w): return w[0]):
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
