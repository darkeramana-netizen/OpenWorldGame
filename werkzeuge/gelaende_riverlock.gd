class_name GelaendeRiverlock
extends GelaendeErzeuger
## Erzeugt das Gelände der Region Riverlock: die Valnschlucht mit der Valn, die von Norden nach
## Süden fließt, Westburg und Ostburg auf flachen Terrassen am Ufer, dahinter die Felswände.
##
## Maßstab wie der Grundriss: 1 Bildpunkt des Plans = 0,25 m. Ursprung (0, 0) ist die Mitte des
## Mittelbaus über dem Fluss, +x ist Osten (Valdrenn), +z ist Süden. Die Burgterrassen liegen auf
## Höhe 0, der Fluss auf Höhe -10 (Bett -14).
##
## Ausführen: wie das Gelände von Drachenstein über werkzeuge/gelaende_erzeugen.gd.

const FLUSS_SPIEGEL := -10.0
const FLUSS_BETT := -14.0
## Flache Terrassen der beiden Burgen: [Min, Max].
const WESTBURG := [Vector2(-152, -82), Vector2(-52, 62)]
const OSTBURG := [Vector2(52, -66), Vector2(174, 78)]
## Halbe Innenmaße der Hafenhalle unter dem Mittelbau.
const MITTELBAU := Vector2(53, 18)
## Straßen aus den äußeren Toranlagen: nach Westen ins Land (Nordstraße), nach Osten nach Valdrenn.
const WEG_WEST := [Vector2(-95, 58), Vector2(-95, 92), Vector2(-150, 106), Vector2(-220, 112), Vector2(-300, 118)]
const WEG_OST := [Vector2(142, 74), Vector2(142, 98), Vector2(200, 110), Vector2(300, 116)]


func _init() -> void:
	super()
	zielordner = "res://daten/gelaende_riverlock/"
	ursprung = Vector2(-300, -200)
	groesse = Vector2(600, 400)
	abstand = 2.5
	wasserspiegel = FLUSS_SPIEGEL


## Mitte des Flusses (x) bei z.
static func fluss_mitte(z: float) -> float:
	return -1.0 + 6.0 * sin(z / 90.0)


## Halbe Breite des Flusses bis zur Oberkante der Ufer: im Norden eng, unter der Brücke 43 m, im Süden breit.
static func fluss_halbbreite(z: float) -> float:
	var b := lerpf(30.0, 43.0, smoothstep(-90.0, -25.0, z))
	return lerpf(b, 60.0, smoothstep(25.0, 100.0, z))


func hoehe(p: Vector2) -> float:
	var n := _rauschen.get_noise_2dv(p)
	var fein := _fein.get_noise_2dv(p)
	var d := absf(p.x - fluss_mitte(p.y))
	var hb := fluss_halbbreite(p.y)

	# Land neben dem Fluss, nach außen steigen die Wände der Schlucht an.
	var h := 1.0 + n * 2.0 + fein * 0.6
	var wand := smoothstep(hb + 110.0, hb + 190.0, d)
	wand *= smoothstep(8.0, 30.0, minf(_abstand_zu(WEG_WEST, p), _abstand_zu(WEG_OST, p)))
	h += wand * (70.0 + _grat.get_noise_2dv(p) * 25.0)

	# Terrassen der Burgen auf Höhe 0.
	for burg: Array in [WESTBURG, OSTBURG]:
		var r := _rechteck_abstand(p, burg[0], burg[1])
		h = lerpf(h, 0.0, 1.0 - smoothstep(0.0, 18.0, r))

	# Felsufer und Flussbett.
	h = lerpf(FLUSS_BETT + fein * 0.5, h, smoothstep(hb - 7.0, hb + 1.0, d))

	h = _weg_einebnen(h, p, WEG_WEST)
	h = _weg_einebnen(h, p, WEG_OST)

	# Unter dem Mittelbau (110 x 40 m) liegt die Hafenhalle: Hier ist nur Flussbett, die Kais baut die Szene.
	if absf(p.x) < MITTELBAU.x and absf(p.y) < MITTELBAU.y:
		h = minf(h, FLUSS_BETT)
	return h


## Rot = Weg, in den Burghöfen etwas schwächer als Pflaster. Grün bleibt leer (kein Sumpf).
func maske_bei(p: Vector2) -> Color:
	var weg := 1.0 - smoothstep(2.5, 4.5, minf(_abstand_zu(WEG_WEST, p), _abstand_zu(WEG_OST, p)))
	for burg: Array in [WESTBURG, OSTBURG]:
		if _rechteck_abstand(p, burg[0], burg[1]) == 0.0:
			weg = maxf(weg, 0.55)
	return Color(weg, 0.0, 0.0)
