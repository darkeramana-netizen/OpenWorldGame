class_name GelaendeErzeuger
## Erzeugt das Gelände der Region Drachenstein nach der Karte von Sorrowland.
##
## Maßstab 1:50 (1 km auf der Karte = 20 m im Spiel). Ursprung (0, 0) ist der Hof
## der Burgfeste Drachenstein, +x ist Osten, +z ist Süden. Lage der Orte:
##   Burgfeste Drachenstein   (0, 0)        Hof (Mittlere Burg) auf Höhe 0, nach dem Grundriss
##                                          gedreht: Oberer Burg im Westen, Hafen im Osten
##   Schwarzer Bergfried       (250, 135)    Insel, von der Südmole über zwei Inseln erreichbar
##   Gravemarch                (-600, -205)  im Tal unter dem Felssporn
##   Gravecrest                (-675, -365)  auf dem eisigen Felssporn, Höhe 70
## Der Meeresspiegel liegt bei -20.
##
## Ausführen: in Godot werkzeuge/gelaende_erzeugen.gd öffnen und Datei → Ausführen
## (Strg+Umschalt+X). Danach die Szene neu öffnen.

const ZIELORDNER := "res://daten/gelaende/"
const URSPRUNG := Vector2(-900, -650)
const GROESSE := Vector2(1350, 1000)
const ABSTAND := 2.5
const MEERESSPIEGEL := -20.0

const GRAVEMARCH := Vector2(-600, -205)
const BERGFRIED := Vector2(250, 135)
## Inseln zwischen Drachenkai und Bergfried: [Mitte, Radius].
const INSELN := [[Vector2(185, 60), 10.0], [Vector2(212, 95), 9.0], [BERGFRIED, 40.0]]
const INSEL_HOEHE := -17.8
## Radius der Grube für den Unterbau des Bergfrieds (liegt innerhalb seiner 10 m dicken Mauer).
const BERGFRIED_GRUBE := 17.0

## Oberer Burg (Drachenhorst) westlich vom Hof, auf Höhe der Hofmauerkrone.
const OBERE_BURG_MIN := Vector2(-86, -45)
const OBERE_BURG_MAX := Vector2(-33.5, 11)
const OBERE_BURG_HOEHE := 8.0
## Hafen im Osten: Kais auf Höhe -17.8, Becken (offen nach Osten) zwischen Nord- und Südmole.
const KAI_HOEHE := -17.8
const BECKEN_MIN := Vector2(101, -19)
const BECKEN_MAX := Vector2(173, 16)
const BECKEN_TIEFE := -27.0
const MOLE_ENDE := 166.0

## Wege als Linienzüge.
const WEG_HAFEN := [Vector2(0, 40), Vector2(0, 56), Vector2(44, 46), Vector2(58, 22), Vector2(75, 4), Vector2(98, 0)]
const WEG_DRACHENHORST := [Vector2(0, 56), Vector2(-25, 52), Vector2(-50, 18), Vector2(-50, 8)]
const WEG_GRAVEMARCH := [Vector2(0, 80), Vector2(-60, 95), Vector2(-150, 70), Vector2(-260, 10),
	Vector2(-360, -70), Vector2(-460, -150), Vector2(-548, -200)]
## Der Weg nach Gravecrest steigt vom Tal bis zur Zugbrücke auf Höhe 70.
const WEG_GRAVECREST := [Vector2(-460, -150), Vector2(-470, -240), Vector2(-500, -310),
	Vector2(-560, -345), Vector2(-612, -363)]
const GRAVECREST_HOEHE := 70.0

var _rauschen := FastNoiseLite.new()
var _fein := FastNoiseLite.new()
var _grat := FastNoiseLite.new()


func _init() -> void:
	_rauschen.seed = 1750
	_rauschen.frequency = 0.004
	_fein.seed = 940
	_fein.frequency = 0.03
	_grat.seed = 1065
	_grat.frequency = 0.007


## Erzeugt alle Dateien und gibt die Anzahl der Höhenpunkte zurück.
func erzeuge() -> int:
	var breite := int(GROESSE.x / ABSTAND) + 1
	var tiefe := int(GROESSE.y / ABSTAND) + 1
	var hoehen := PackedFloat32Array()
	hoehen.resize(breite * tiefe)
	var maske := Image.create(breite, tiefe, false, Image.FORMAT_RGB8)
	var vorschau := Image.create(breite, tiefe, false, Image.FORMAT_RGB8)

	for iz in tiefe:
		for ix in breite:
			var p := URSPRUNG + Vector2(ix, iz) * ABSTAND
			var h := hoehe(p)
			hoehen[iz * breite + ix] = h
			var m := maske_bei(p)
			maske.set_pixel(ix, iz, m)
			vorschau.set_pixel(ix, iz, _vorschaufarbe(h, m))

	DirAccess.make_dir_recursive_absolute(ZIELORDNER)
	var datei := FileAccess.open(ZIELORDNER + "hoehen.r32", FileAccess.WRITE)
	datei.store_buffer(hoehen.to_byte_array())
	datei.close()
	var info := {
		"breite": breite, "tiefe": tiefe, "abstand": ABSTAND,
		"ursprung_x": URSPRUNG.x, "ursprung_z": URSPRUNG.y,
		"meeresspiegel": MEERESSPIEGEL,
	}
	datei = FileAccess.open(ZIELORDNER + "hoehen.json", FileAccess.WRITE)
	datei.store_string(JSON.stringify(info, "\t"))
	datei.close()
	maske.save_png(ZIELORDNER + "maske.png")
	vorschau.save_png(ZIELORDNER + "vorschau.png")
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
	berg = maxf(berg, smoothstep(230.0, 330.0, p.y) * smoothstep(250.0, 100.0, p.x))
	berg = maxf(berg, smoothstep(-800.0, -880.0, p.x))

	# Das Tal nach Gravemarch hält das Gebirge zurück.
	var tal_abstand := _abstand_zu([Vector2(-260, 10), Vector2(-360, -70), Vector2(-460, -150), GRAVEMARCH], p)
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
	var kueste := 115.0 + 20.0 * sin(p.y / 110.0)
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

	# Plateau des Hofs (64 x 64 m) mit Vorplatz vor dem Tor, Höhe 0.
	var hof := _rechteck_abstand(p, Vector2(-42, -42), Vector2(42, 42))
	hof = minf(hof, _rechteck_abstand(p, Vector2(-14, 42), Vector2(14, 92)))
	h = lerpf(h, 0.0, 1.0 - smoothstep(0.0, 30.0, hof))

	# Oberer Burg (Drachenhorst) westlich vom Hof auf Höhe der Mauerkrone. Zum Hof hin
	# endet das Plateau scharf an der Westmauer, sonst fällt es in 16 m ab.
	if p.x <= -32.0:
		var horst := _rechteck_abstand(p, OBERE_BURG_MIN, OBERE_BURG_MAX)
		h = lerpf(h, OBERE_BURG_HOEHE, 1.0 - smoothstep(0.0, 16.0, horst))

	# Stadt am Hang: vom Hof hinunter über den Marktplatz zu den Kais.
	h = _stadthang(h, p)

	# Gravemarch auf einem aufgeschütteten Hügel im Sumpf.
	var gm := p.distance_to(GRAVEMARCH)
	h = lerpf(h, -9.0 + fein * 0.6, 1.0 - smoothstep(110.0, 145.0, gm))  # Sumpfsenke
	h = lerpf(h, -4.0, 1.0 - smoothstep(68.0, 78.0, gm))  # Hügel der Burg

	# Wege glätten das Gelände.
	h = _weg_einebnen(h, p, WEG_HAFEN)
	h = _weg_einebnen(h, p, WEG_DRACHENHORST)
	h = _weg_einebnen(h, p, WEG_GRAVEMARCH)
	h = _weg_gravecrest(h, p)

	# Rückseite des Felsens hinter dem Palas: Hier hängt der Flaschenzug über dem Abgrund.
	if p.x > -805.0 and p.x < -772.0 and absf(p.y + 365.0) < 40.0:
		h = minf(h, 25.0)

	# Abgrund vor dem Torhaus von Gravecrest, die Zugbrücke führt darüber.
	if p.x > -629.0 and p.x < -613.0 and absf(p.y + 364.0) < 30.0:
		h = minf(h, 10.0)
	return h


## Hang der Stadt zwischen Hof und Hafen mit dem Marktplatz als flacher Stufe. Ausgefahren
## wird er nur in einem Band um den Hafen, nach Osten laufen nur die schmalen Molen ins Meer.
func _stadthang(h: float, p: Vector2) -> float:
	if p.x < 28.0:
		return h
	var profil: float
	if p.x < 42.0:
		profil = 0.0
	elif p.x < 58.0:
		profil = lerpf(0.0, -7.5, (p.x - 42.0) / 16.0)
	elif p.x < 80.0:
		profil = lerpf(-7.5, -8.5, (p.x - 58.0) / 22.0)  # Marktplatz
	elif p.x < 95.0:
		profil = lerpf(-8.5, KAI_HOEHE, (p.x - 80.0) / 15.0)
	else:
		profil = KAI_HOEHE
	var quer := absf(p.y + 2.0)
	var rand := lerpf(24.0, 1.0, smoothstep(100.0, 115.0, p.x))
	var anteil := (1.0 - smoothstep(26.0, 26.0 + rand, quer)) * smoothstep(28.0, 42.0, p.x)
	anteil *= 1.0 - smoothstep(MOLE_ENDE, MOLE_ENDE + 3.0, p.x)
	h = lerpf(h, profil, anteil)
	# Hafenbecken mit senkrechten Kaimauern (die Mauern selbst baut die Szene).
	if p.x > BECKEN_MIN.x and p.x < BECKEN_MAX.x and p.y > BECKEN_MIN.y and p.y < BECKEN_MAX.y:
		h = minf(h, BECKEN_TIEFE)
	return h


## Farbmaske für den Gelände-Shader: Rot = Weg, Grün = Sumpf.
func maske_bei(p: Vector2) -> Color:
	var weg := INF
	for linie in [WEG_HAFEN, WEG_DRACHENHORST, WEG_GRAVEMARCH, WEG_GRAVECREST]:
		weg = minf(weg, _abstand_zu(linie, p))
	var gm := p.distance_to(GRAVEMARCH)
	var sumpf := (1.0 - smoothstep(115.0, 140.0, gm)) * smoothstep(74.0, 84.0, gm)
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
	if h < MEERESSPIEGEL:
		farbe = Color(0.25, 0.4, 0.55).darkened(clampf((MEERESSPIEGEL - h) / 20.0, 0.0, 0.6))
	elif h > 100.0:
		farbe = Color(0.9, 0.92, 0.95)
	elif h > 40.0:
		farbe = Color(0.5, 0.48, 0.45)
	else:
		farbe = Color(0.35, 0.45, 0.25).lightened(clampf((h + 20.0) / 120.0, 0.0, 0.4))
	farbe = farbe.lerp(Color(0.3, 0.33, 0.2), m.g)
	return farbe.lerp(Color(0.6, 0.5, 0.35), m.r)
