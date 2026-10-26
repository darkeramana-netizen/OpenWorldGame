class_name GelaendeStrasse
extends GelaendeErzeuger
## Erzeugt das Gelände einer Landstraße als lange, schmale Region (Maßstab 1:100, also 1 km = 10 m).
##
## Gerechnet wird entlang der Straße: "a" läuft vom ersten Ende (a = 0) zum zweiten (a = laenge),
## "c" quer dazu. Auf der einen Seite liegt das Wächtermeer, auf der anderen steigt das Gebirge an.
##   Nordstraße: Drachenstein (Westen, a = 0) → Riverlock (Osten), Meer im Süden, Nordzinnen im Norden
##   Südstraße:  Ashenveil (Westen, a = 0) → Riverlock (Osten), Meer im Norden, Nebelhöhen im Süden
##   Küstenweg:  Drachenstein (Norden, a = 0) → Ashenveil (Süden), Meer im Osten, Eisgrat im Westen
##
## Ausführen: wie das Gelände von Drachenstein über werkzeuge/gelaende_erzeugen.gd.

const BREITE := 400.0
const STRASSEN := {
	"nordstrasse": {"laenge": 2250.0, "entlang_z": false, "meer": 1.0, "moor_ab": 2.0},
	"suedstrasse": {"laenge": 1850.0, "entlang_z": false, "meer": -1.0, "moor_ab": -1.0},
	"kuestenweg": {"laenge": 700.0, "entlang_z": true, "meer": 1.0, "moor_ab": 0.7},
}

var strasse: String
var laenge: float
var entlang_z: bool
## +1: Meer auf der Seite mit positivem c, -1: auf der anderen.
var meer: float
## Ab diesem Anteil der Strecke beginnt das Nebelmoor (nur Küstenweg vor Ashenveil).
var moor_ab: float


func _init(name: String = "nordstrasse") -> void:
	super()
	strasse = name
	var werte: Dictionary = STRASSEN[name]
	laenge = werte["laenge"]
	entlang_z = werte["entlang_z"]
	meer = werte["meer"]
	moor_ab = werte["moor_ab"]
	zielordner = "res://daten/gelaende_%s/" % name
	abstand = 2.5
	wasserspiegel = MEERESSPIEGEL
	if entlang_z:
		ursprung = Vector2(-BREITE / 2.0, -20.0)
		groesse = Vector2(BREITE, laenge + 40.0)
	else:
		ursprung = Vector2(-20.0, -BREITE / 2.0)
		groesse = Vector2(laenge + 40.0, BREITE)


## Weltposition (x, z) → [a, c] entlang und quer zur Straße.
func lokal(p: Vector2) -> Vector2:
	return Vector2(p.y, p.x) if entlang_z else p


## [a, c] → Weltposition (x, z).
func welt(a: float, c: float) -> Vector2:
	return Vector2(c, a) if entlang_z else Vector2(a, c)


## Querlage der Straßenmitte bei a: sanfte Kurven, an beiden Enden genau in der Mitte.
func strassen_c(a: float) -> float:
	var enden := smoothstep(0.0, 60.0, a) * smoothstep(laenge, laenge - 60.0, a)
	return (28.0 * sin(a / 170.0) + 9.0 * sin(a / 53.0)) * enden


## Querlage der Küste bei a.
func kuesten_c(a: float) -> float:
	return meer * (105.0 + 18.0 * sin(a / 140.0 + 1.3))


func hoehe(p: Vector2) -> float:
	var l := lokal(p)
	var a := l.x
	var c := l.y
	var n := _rauschen.get_noise_2dv(p)
	var fein := _fein.get_noise_2dv(p)

	# Hügelland, zum Gebirge hin steiler.
	var h := 2.0 + n * 5.0 + fein * 0.8
	var berg_seite := -meer * c
	var berg := smoothstep(70.0, 185.0, berg_seite)
	h = lerpf(h, 55.0 + (1.0 - absf(_grat.get_noise_2dv(p))) * 45.0 + n * 10.0, berg)

	# Küste: Strand und Meer.
	var d := meer * (c - kuesten_c(a))
	h = lerpf(h, -18.6, smoothstep(-55.0, 0.0, d))
	h -= smoothstep(5.0, 60.0, d) * 15.0

	# Nebelmoor vor Ashenveil: flach und nass.
	if moor_ab >= 0.0:
		var moor := smoothstep(moor_ab * laenge, moor_ab * laenge + 60.0, a)
		h = lerpf(h, -0.6 + n * 1.2, moor * (1.0 - smoothstep(-40.0, 0.0, d)))

	# Straße: geglättet, nie im Wasser.
	var weg := absf(c - strassen_c(a))
	var weg_h := maxf(h - fein * 0.8, -17.0)
	h = lerpf(weg_h, h, smoothstep(4.0, 16.0, weg))
	return h


## Rot = Straße, Grün = Moor.
func maske_bei(p: Vector2) -> Color:
	var l := lokal(p)
	var weg := 1.0 - smoothstep(2.5, 4.5, absf(l.y - strassen_c(l.x)))
	var sumpf := 0.0
	if moor_ab >= 0.0:
		sumpf = smoothstep(moor_ab * laenge, moor_ab * laenge + 60.0, l.x) * clampf(0.5 + _fein.get_noise_2dv(p * 0.5), 0.0, 1.0)
	return Color(weg, sumpf, 0.0)
