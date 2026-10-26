class_name GelaendeAshenveil
extends GelaendeErzeuger
## Erzeugt das Gelände der Region Ashenveil: das Nebelmoor mit Tümpeln, in der Mitte die Burg auf
## einer flachen Insel mit Wassergraben. Nur ein Damm führt von Süden durch den Sumpf zum Haupttor,
## ein schmaler Pfad von Osten zum Nebeneingang.
##
## Maßstab wie der Grundriss: 1 Bildpunkt des Plans = 0,2 m. Ursprung (0, 0) ist die Mitte der Burg,
## +x ist Osten, +z ist Süden. Die Burginsel liegt auf Höhe 0,5, das Wasser auf -1.
##
## Ausführen: wie das Gelände von Drachenstein über werkzeuge/gelaende_erzeugen.gd.

const WASSER := -1.0
const BURGINSEL_HOEHE := 0.5
## Burginsel [Min, Max]; der Graben liegt 3 bis 16 m davor.
const INSEL := [Vector2(-96, -50), Vector2(96, 44)]
const BURGGRABEN_SOHLE := -3.0
## Der einzige Weg: der Damm von Süden zur Zugbrücke am Haupttor.
const DAMM := [Vector2(-5, 64), Vector2(-5, 82), Vector2(14, 100), Vector2(6, 128), Vector2(-22, 148),
	Vector2(-14, 172), Vector2(0, 198)]
const DAMM_HOEHE := 0.4
## Pfad von Osten (Südstraße nach Riverlock) zur Zugbrücke am Nebeneingang.
const PFAD_OST := [Vector2(113, 3), Vector2(132, 10), Vector2(152, -4), Vector2(176, 6), Vector2(205, 0), Vector2(250, 8)]
## Unterbau: Grube unter dem Innenhof (Kapelle der Stille und Rampe), Graben für den Fluchttunnel,
## Hügel mit dem verdeckten Ausstieg im Moor nördlich der Burg.
const GRUBE := [Vector2(-33, -12), Vector2(3, 6)]
const TUNNEL := [Vector2(-9.5, -101), Vector2(-2.5, -9)]
const AUSSTIEG := Vector2(-6, -102)
const UNTERBAU_SOHLE := -7.3


func _init() -> void:
	super()
	zielordner = "res://daten/gelaende_ashenveil/"
	ursprung = Vector2(-250, -200)
	groesse = Vector2(500, 400)
	abstand = 2.5
	wasserspiegel = WASSER


func hoehe(p: Vector2) -> float:
	var n := _rauschen.get_noise_2dv(p * 2.5)
	var fein := _fein.get_noise_2dv(p)

	# Moor: knapp über dem Wasser, dazwischen tiefe Tümpel. Am Rand der Region etwas höher (Nebelhöhen).
	var h := -0.6 + n * 3.6 + fein * 0.5
	if h < WASSER + 0.2:
		h = WASSER + 0.2 - (WASSER + 0.2 - h) * 3.0
	var rand := maxf(absf(p.x) - 200.0, absf(p.y) - 160.0)
	h = lerpf(h, 6.0 + n * 3.0, smoothstep(0.0, 40.0, rand))

	# Burginsel und Graben.
	var d := _rechteck_abstand(p, INSEL[0], INSEL[1])
	h = lerpf(h, BURGINSEL_HOEHE, 1.0 - smoothstep(0.0, 3.0, d))
	var graben := 1.0 - smoothstep(0.0, 2.0, absf(d - 9.5) - 4.5)
	h = lerpf(h, BURGGRABEN_SOHLE, graben)

	# Damm und Ostpfad: fest und trocken, mit kurzer Böschung.
	h = lerpf(h, DAMM_HOEHE, 1.0 - smoothstep(2.5, 5.0, _abstand_zu(DAMM, p)))
	h = lerpf(h, 0.3, 1.0 - smoothstep(1.8, 4.0, _abstand_zu(PFAD_OST, p)))

	# Hügel mit dem Ausstieg des Fluchttunnels.
	h = lerpf(h, 0.3, 1.0 - smoothstep(10.0, 14.0, p.distance_to(AUSSTIEG)))

	# Unterbau: Grube und Tunnelgraben, abgedeckt von der Szene (Boden, Decken).
	if _rechteck_abstand(p, GRUBE[0], GRUBE[1]) == 0.0 or _rechteck_abstand(p, TUNNEL[0], TUNNEL[1]) == 0.0:
		h = minf(h, UNTERBAU_SOHLE)
	return h


## Rot = Damm und Pfad, Grün = Sumpf (überall außerhalb der Burginsel).
func maske_bei(p: Vector2) -> Color:
	var weg := 1.0 - smoothstep(2.0, 3.5, minf(_abstand_zu(DAMM, p), _abstand_zu(PFAD_OST, p)))
	var sumpf := smoothstep(2.0, 6.0, _rechteck_abstand(p, INSEL[0], INSEL[1]))
	sumpf *= clampf(0.55 + _fein.get_noise_2dv(p * 0.5), 0.0, 1.0)
	return Color(weg, sumpf, 0.0)
