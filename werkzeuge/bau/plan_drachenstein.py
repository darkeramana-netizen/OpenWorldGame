"""Grundriss der Burgfeste Drachenstein (docs/bilder/grundriss-drachenstein.webp), digitalisiert.

Alle Punkte stehen in Bildpunkten des Plans (x nach rechts, y nach unten). Maßstab laut Leiste:
200 m = 179 px, also 1,117 m je Bildpunkt (1:1 übernommen). Der Plan ist gedreht eingebaut:
Plan-Süd (Hafen) zeigt in der Welt nach Osten (+x, zum Wächtermeer), Plan-Ost nach Norden (-z).
Die Mitte des Kernhofs (2) ist der Weltursprung (0, 0), dort liegt der Hof aus Akt I.

Höhen (Welt-y, Meer bei -20): Hafen -17,8 · Marktviertel -16 bis -6 · Äußerer Zwinger -3 ·
Kernhof 0 · Hoher Zwinger +18 · Oberer Burg +34 · Urkern +46 (Aussichtsplattform darüber).

Ausführen schreibt daten/drachenstein_plan.json für den Geländeerzeuger (werkzeuge/gelaende_erzeuger.gd).
"""
import json, math
from pathlib import Path

MASSSTAB = 200.0 / 179.0
MITTE = (565.0, 322.0)          # Kernhof (2) im Plan


def welt(p):
    """Planpunkt (px, py) → Weltpunkt (x, z)."""
    px, py = p
    return (round((py - MITTE[1]) * MASSSTAB, 2), round(-(px - MITTE[0]) * MASSSTAB, 2))


def welt_liste(punkte):
    return [welt(p) for p in punkte]


# ---------- Höhenstufen ----------
H_HAFEN = -17.8
H_MARKT_OBEN = -6.0       # am Treppentor unter dem Äußeren Zwinger
H_MARKT_UNTEN = -15.0     # am Hafenbecken
H_ZWINGER = -3.0
H_KERNHOF = 0.0
H_MITTLERER_ZWINGER = 1.5
H_HOHER_ZWINGER = 18.0
H_OBERE_BURG = 34.0
H_URKERN = 46.0
H_OSTTERRASSE = -2.0      # spätmittelalterliche Verdichtung (4) und Mittlerer Burghof (5)
H_VORBURG = -4.0          # Gärten der Vorburg (36, 37)

# ---------- Mauerringe (Planpunkte, im Uhrzeigersinn) ----------
URKERN = [(585, 112), (618, 92), (668, 112), (677, 150), (652, 172), (612, 180), (585, 165), (578, 140)]
KAPELLE_URKERN = [(540, 125), (578, 125), (578, 168), (540, 168)]          # Kapelle (7)
OBERE_BURG = [(512, 195), (502, 105), (560, 75), (612, 55), (695, 78), (712, 125), (722, 185)]
HOHER_ZWINGER = [(512, 195), (540, 172), (585, 168), (652, 175), (680, 158), (722, 185), (700, 248),
                 (652, 298), (605, 250), (533, 212)]
# Im Plan etwas größer als gezeichnet (Faktor 1,18), damit der quadratische Innere Burghof (4) aus Akt I
# mit Abstand hineinpasst.
KERNHOF = [(round(MITTE[0] + (x - MITTE[0]) * 1.18, 1), round(MITTE[1] + (y - MITTE[1]) * 1.18, 1))
           for x, y in [(518, 292), (560, 280), (608, 300), (612, 345), (590, 365), (545, 365), (520, 342)]]
INNERER_BURGHOF = [(-33, -33), (33, -33), (33, 33), (-33, 33)]   # Welt, burg_hof.tscn (Mauern bei ±31)
MITTLERE_BURG = [(533, 212), (605, 250), (652, 298), (640, 420), (565, 400), (492, 350), (497, 262)]
AEUSSERER_ZWINGER = [(502, 105), (470, 140), (440, 190), (418, 250), (415, 330), (420, 395), (520, 440),
                     (548, 466), (634, 450), (690, 420), (705, 300), (722, 185), (712, 125)]
OSTTERRASSE = [(712, 125), (745, 150), (790, 290), (850, 430), (780, 420), (720, 445), (690, 420),
               (705, 300), (722, 185)]
# Löwenward: äußerer Artillerie-Ring (V), vom Drachenhorst im Westen (Plan-Nord) über Plan-West,
# Plan-Süd (Hafen) und Plan-Ost zurück zum Drachenhorst. Die Lücke am Hafen ist das Schiffstor.
LOEWENWARD = [(502, 105), (418, 195), (358, 190), (320, 255), (325, 300), (210, 437), (100, 632), (165, 765),
              (362, 833), (435, 880), (500, 900)]
LOEWENWARD_OST = [(640, 890), (700, 850), (845, 735), (885, 670), (915, 555), (890, 490), (850, 430),
                  (830, 320), (790, 270), (745, 150), (712, 125)]
# Innere Mauer der Vorburg zwischen den Gärten (37) und dem Marktviertel, und um den Garten 36
VORBURG_INNEN = [(398, 385), (300, 510), (220, 690), (362, 833)]
VORBURG_GARTEN = [(325, 300), (400, 268), (418, 195)]
# Mauer zwischen Burg und Marktviertel, mit dem Durchgang zum Markt
STADTMAUER_NORD = [(300, 508), (440, 505), (520, 505)]
STADTMAUER_NORD_OST = [(580, 505), (700, 510), (790, 505), (850, 470)]
# Hafen (VI): Kaimauern um das Becken (31), Docks (33), Kanal (32), Schiffstor (34), Hafentor (20), Zollhaus (35)
HAFENBECKEN = [(522, 705), (608, 705), (612, 900), (588, 912), (542, 912), (518, 900)]
KANALBECKEN = [(612, 780), (680, 780), (690, 860), (612, 860)]
KAI_WEST = [(470, 700), (522, 705), (518, 900), (500, 900), (470, 870)]
DOCK_OST = [(608, 705), (720, 720), (730, 790), (612, 780)]

# ---------- Plätze, Gebäude, Tore ----------
MARKTPLATZ = [(500, 494), (600, 494), (602, 700), (498, 700)]
KIRCHE = ((420, 610), 60, 28, 0)              # Mitte, Länge (Plan-y), Breite (Plan-x), Drehung
KIRCHTURM = (420, 572)
RATHAUS = ((717, 683), 34, 22)
BADEHAUS = ((745, 575), 26, 20)
MUEHLE = ((770, 600), 20, 20)
SCHMIEDE = ((595, 675), 18, 16)
ZOLLHAUS = (650, 885)
PALAS = ((548, 300), 40, 16)                  # im Kernhof an der Nordwestseite (6)
BRUNNENHAUS = (685, 250)                      # (15)
ZISTERNE = (657, 205)                         # (9)
AUSSICHTSPLATTFORM = (612, 55)                # Turm mit Spitzdach (28 im Bild)
TREPPENTOR = (539.6, 458.2)                   # vom Markt in den Äußeren Zwinger (16), auf der Mauer zwischen (520, 440) und (548, 466)
TORE = {
    "Treppentor": TREPPENTOR,
    "Kernhoftor": (565, 365),                 # vom Äußeren Zwinger in den Kernhof
    "Zwingertor": (605, 250),                 # vom Kernhof hinauf in den Hohen Zwinger
    "Urkerntor": (612, 180),
    "Vorburgtor": (403, 257),                 # (11) zum Weg nach Gravemarch
    "Westtor": (185, 772),                    # in der Löwenward, zum Küstenweg
    "Südöstliches Tor": (830, 746),           # (19) zur Nordstraße
    "Schiffstor": (565, 912),                 # (34)
}

# ---------- Straßen (Planpunkte) ----------
STRASSEN = [
    # Marktviertel West: Bögen parallel zur Vorburgmauer und Querstraßen zum Markt
    [(500, 540), (420, 535), (330, 545), (270, 575)],
    [(500, 600), (455, 585), (445, 650), (370, 655), (320, 640), (250, 680)],
    [(500, 680), (440, 700), (360, 710), (290, 740), (230, 700)],
    [(498, 700), (470, 760), (420, 800), (362, 820)],
    [(330, 545), (320, 640), (360, 710), (420, 800)],
    [(420, 535), (455, 585)],
    # Marktviertel Ost
    [(600, 530), (690, 535), (780, 540), (850, 580), (880, 650)],
    [(600, 600), (700, 610), (790, 625), (860, 660)],
    [(602, 690), (700, 710), (790, 720), (830, 746)],
    [(690, 535), (700, 610), (700, 710)],
    [(780, 540), (790, 625), (790, 720)],
    # Hinauf zur Burg: vom Markt durch das Treppentor in den Äußeren Zwinger und zum Kernhoftor
    [(550, 494), TREPPENTOR, (552, 440), (565, 380)],
    # Vom Marktviertel durch die Vorburg zum Vorburgtor (Weg nach Gravemarch)
    [(330, 545), (360, 470), (390, 400), (405, 330), (403, 257)],
    # Durch die Gärten zum Westtor (Küstenweg)
    [(290, 740), (240, 722), (185, 772)],
]


def plan_json():
    zonen = [
        {"name": "Urkern", "punkte": welt_liste(URKERN), "hoehe": H_URKERN, "rand": 2.5},
        {"name": "Kapelle", "punkte": welt_liste(KAPELLE_URKERN), "hoehe": H_URKERN, "rand": 2.5},
        {"name": "Obere Burg", "punkte": welt_liste(OBERE_BURG), "hoehe": H_OBERE_BURG, "rand": 2.5},
        {"name": "Hoher Zwinger", "punkte": welt_liste(HOHER_ZWINGER), "hoehe": H_HOHER_ZWINGER, "rand": 2.5},
        {"name": "Mittlere Burg", "punkte": welt_liste(MITTLERE_BURG), "hoehe": H_MITTLERER_ZWINGER, "rand": 6.0},
        {"name": "Kernhof", "punkte": welt_liste(KERNHOF), "hoehe": H_KERNHOF, "rand": 4.0},
        {"name": "Äußerer Zwinger", "punkte": welt_liste(AEUSSERER_ZWINGER), "hoehe": H_ZWINGER, "rand": 8.0},
        {"name": "Ostterrasse", "punkte": welt_liste(OSTTERRASSE), "hoehe": H_OSTTERRASSE, "rand": 8.0},
    ]
    stadt = welt_liste(LOEWENWARD + [(520, 905), (612, 905)] + LOEWENWARD_OST)
    return {
        "_hinweis": "Erzeugt von werkzeuge/bau/plan_drachenstein.py aus dem Grundriss. Nicht von Hand ändern.",
        # Zonen werden in dieser Reihenfolge eingeebnet; spätere (innere) gewinnen.
        "zonen": [zonen[i] for i in (6, 7, 4, 5, 3, 2, 1, 0)],
        "stadt": stadt,
        "markt_oben": [welt((550, 494))[0], H_MARKT_OBEN],
        "markt_unten": [welt((550, 700))[0], H_MARKT_UNTEN],
        "hafen_becken": welt_liste(HAFENBECKEN),
        # Fahrrinne vom Becken durch das Schiffstor ins offene Meer
        "fahrrinne": welt_liste([(540, 900), (590, 900), (595, 990), (535, 990)]),
        "kanal": welt_liste(KANALBECKEN),
        "hafen_hoehe": H_HAFEN,
        "vorburg_hoehe": H_VORBURG,
        "strassen": [welt_liste(s) for s in STRASSEN],
        "markt": welt_liste(MARKTPLATZ),
    }


if __name__ == "__main__":
    ziel = Path(__file__).resolve().parents[2] / "daten" / "drachenstein_plan.json"
    ziel.write_text(json.dumps(plan_json(), ensure_ascii=False, indent=1), encoding="utf-8")
    print("geschrieben:", ziel)
    for name, p in [("Urkern", (628, 138)), ("Aussichtsplattform", AUSSICHTSPLATTFORM), ("Kernhof", MITTE),
                    ("Treppentor", TREPPENTOR), ("Markt Mitte", (550, 597)), ("Hafenausfahrt", (565, 915)),
                    ("Löwenward West", (100, 632)), ("Löwenward Ost", (915, 555)), ("Tor 19", (845, 735))]:
        print(f"  {name:20s} {welt(p)}")
