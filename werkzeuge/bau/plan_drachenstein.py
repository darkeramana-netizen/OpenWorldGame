"""Grundriss der Burgfeste Drachenstein (docs/bilder/grundriss-drachenstein-2.webp), digitalisiert.

Alle Punkte stehen in Bildpunkten des Plans (x nach rechts, y nach unten). Maßstab: 0,5 m je Bildpunkt (die ganze
Anlage ist rund 650 m lang). Der Plan ist gedreht eingebaut: Plan-Süd (Stadt und Hafen) zeigt in der Welt nach Osten
(+x, zum Wächtermeer), Plan-Ost (Kernburg) nach Norden (-z). Die Mitte des III. Burghofs ist der Weltursprung (0, 0):
Dort liegt der Hof aus Akt I (burg_hof.tscn, Mauern bei ±31 m), angehoben auf HOF_Y.

Aufbau nach dem Plan und den Schnitten A-A und B-B:
  Auf einem Felsgrat liegen hintereinander die I. Vorburg, der II. Burghof, der III. Burghof (Hof aus Akt I) und
  die Kernburg mit Bergfried, Palas, Drachenkapelle, Burgküche und Zeughaus, umgeben von der Zwingermauer.
  Eine Ringmauer (Stadtmauer) mit Torhäusern, Halbturm, Wehrturm, Zwinger und Rondell umschließt den Grat.
  Unten in der Ebene liegen die Stadt mit St. Marien und dem Marktplatz und der Drachenhafen mit Speicher.
  Zugang zur Burg: durch das Hafentor auf den Weg unter den Felsen, über die Rampe hinauf zum II. Burghof.

Höhen (Welt-y, Meer bei -20): Hafen -17,8 · Stadt -16,5 bis -14 · Weg unter den Felsen -16 bis +6 ·
I. Vorburg +8 · II. Burghof +11 · III. Burghof +14 (Hof aus Akt I) · Kernburg +20 · Zwinger der Kernburg +17.
Unter den Burgmauern bricht der Fels steil zum Zwinger ab, außen an der Ringmauer zur Ebene.

Ausführen schreibt daten/drachenstein_plan.json für den Geländeerzeuger (werkzeuge/gelaende_erzeuger.gd).
"""
import json, math
from pathlib import Path

MASSSTAB = 0.5
MITTE = (735.0, 228.0)          # Mitte des III. Burghofs im Plan = Hof aus Akt I


def welt(p):
    """Planpunkt (px, py) → Weltpunkt (x, z)."""
    px, py = p
    return (round((py - MITTE[1]) * MASSSTAB, 2), round(-(px - MITTE[0]) * MASSSTAB, 2))


def welt_liste(punkte):
    return [welt(p) for p in punkte]


def plan(w):
    """Weltpunkt (x, z) → Planpunkt (für Prüfungen)."""
    return (MITTE[0] - w[1] / MASSSTAB, MITTE[1] + w[0] / MASSSTAB)


# ---------- Höhenstufen ----------
H_HAFEN = -17.8
H_STADT_WEST = -14.0      # am Torhaus West
H_STADT_OST = -16.5       # am Hafen
H_MARKT = -15.2
HOF_Y = 14.0              # Höhe des Hofs aus Akt I (III. Burghof); szenen/welt/burg_hof.tscn liegt dort
H_VORBURG = 8.0
H_BURGHOF2 = 11.0
H_KERNHOF = HOF_Y         # III. Burghof
H_KERNBURG = 20.0
H_ZWINGER = 17.0          # Zwinger um die Kernburg
H_EBENE = -14.0           # Land vor der Ringmauer

# ---------- Burgen auf dem Grat ----------
VORBURG = [(318, 250), (360, 232), (445, 212), (458, 270), (450, 330), (420, 352), (350, 358), (312, 300)]
BURGHOF2 = [(458, 270), (445, 212), (472, 215), (530, 192), (600, 182), (636, 160), (636, 290),
            (625, 322), (580, 336), (513, 326), (487, 294)]
BURGHOF3 = [(636, 160), (650, 136), (838, 134), (842, 310), (668, 318), (645, 300), (636, 290)]
KERNBURG = [(878, 255), (878, 185), (912, 138), (965, 126), (1065, 116), (1100, 150), (1102, 280), (1062, 302),
            (950, 302), (896, 288)]
ZWINGER_KERNBURG = [(842, 310), (838, 134), (852, 120), (885, 105), (965, 88), (1085, 92), (1142, 135),
                    (1152, 250), (1112, 322), (1000, 338), (895, 332), (850, 318)]
# Ringmauer (Stadtmauer um den Grat): von Torhaus West über Halbturm, Torhaus Nord, Wehrturm, Zwinger und Rondell
# bis zum Hafentor; der südliche Teil ist zugleich die Mauer zwischen Burgbezirk und Stadt.
RINGMAUER = [(150, 430), (172, 330), (190, 225), (240, 195), (285, 172), (330, 180), (450, 145), (560, 100),
             (640, 72), (720, 76), (800, 95), (880, 60), (960, 36), (1100, 30), (1190, 55), (1230, 140), (1245, 250),
             (1215, 345), (1100, 375), (1000, 393), (900, 405), (785, 412), (700, 403), (600, 390), (470, 373),
             (360, 394), (250, 406)]
# Stadt: von Torhaus West nach Süden, an der Hafenmauer hinauf zur Mauer unter dem Grat
STADTMAUER = [(150, 430), (180, 500), (240, 600), (330, 665), (420, 674), (560, 674), (600, 664), (590, 560),
              (600, 470), (615, 425)]
STADT = STADTMAUER + [(470, 373), (360, 394), (250, 406)]
# Hafen: Becken mit Kaimauern, östliche Hafenmauer mit Rundturm, Speicherkai im Süden mit Turm
HAFENBECKEN = [(632, 452), (700, 444), (790, 452), (812, 472), (820, 560), (800, 598), (760, 610), (652, 608),
               (634, 560), (622, 486)]
HAFENMAUER_OST = [(785, 412), (828, 440), (832, 532)]
SPEICHERKAI = [(640, 612), (770, 614), (790, 628), (660, 640), (630, 628)]
HAFEN_BEZIRK = [(615, 425), (785, 412), (828, 440), (842, 548), (842, 600), (800, 640), (770, 646), (640, 650),
                (600, 664), (590, 560), (600, 470)]
FAHRRINNE = [(790, 590), (830, 575), (960, 830), (900, 860)]
# Bucht vor dem Hafen: offenes Wasser bis zur Küste, darin Mole und Brücken
BUCHT = [(845, 455), (845, 600), (800, 650), (700, 700), (680, 900), (1100, 900), (1100, 455)]

# ---------- Tore ----------
# Tore als (Kantenindex im jeweiligen Linienzug, Anteil, Breite, Name); die Punkte im Plan stehen dahinter
TORE = {
    "Torhaus West": (157.5, 447.5),      # in der Stadtmauer: Stadt ↔ Küstenweg
    "Torhaus Nord": (294, 173.6),        # in der Ringmauer: Burgbezirk ↔ Weg nach Gravemarch
    "Hafentor": (750, 408),              # Hafen ↔ Weg unter den Felsen zur Burg
    "Nordtor": (1238, 195),              # am Zwinger, zur Nordstraße
    "Tor zur Vorburg": (385, 355),       # vom Weg in die I. Vorburg
    "Tor des II. Burghofs": (455.4, 258.4),  # zwischen I. Vorburg und II. Burghof
    "Rampentor": (540, 331),             # II. Burghof ↔ Rampe hinab zum Weg
    "Tor des III. Burghofs": (636, 228), # II. ↔ III. Burghof, vor dem Tor des Hofs aus Akt I
    "Burgtor": (840, 222),               # III. Burghof ↔ Zwinger der Kernburg
    "Kernburgtor": (878, 222),           # Zwinger ↔ Kernburg
    "Hafenpforte": (596, 500),           # Stadt ↔ Hafenkai
}
# Weg unter den Felsen: vom Hafentor nach Westen zur Vorburg, mit der Rampe hinauf zum II. Burghof
WEG_UNTEN = [(750, 422), (750, 396), (700, 390), (600, 376), (470, 359), (440, 360), (420, 361), (385, 362)]
RAMPE_BURGHOF2 = [(440, 360), (466, 343), (528, 343), (540, 335)]

# ---------- Bauten ----------
# (Mitte, Länge, Breite, Drehung in Grad) in Bildpunkten; Länge entlang Plan-x bei Drehung 0
BERGFRIED_KERNBURG = (1075, 140)
PALAS = ((995, 155), 120, 32, 4)
DRACHENKAPELLE = ((1075, 215), 22, 80, 0)
BURGKUECHE = ((905, 252), 52, 30, -25)
ZEUGHAUS = ((1030, 260), 56, 26, -3)
VORBURG_BAUTEN = [((392, 236), 90, 20, -12), ((330, 300), 22, 50, 0)]
BURGHOF2_BAUTEN = [((565, 198), 70, 20, -8), ((585, 318), 60, 22, -10)]
ST_MARIEN = ((410, 500), 76, 34, 0)      # Langhaus von West nach Ost, Turm im Osten
ST_MARIEN_TURM = (444, 494)
MARKTPLATZ = [(455, 480), (566, 478), (568, 556), (456, 558)]
MARKT_MITTE = (512, 518)
SPEICHER = ((705, 627), 120, 22, 1)
WEHRTURM = (800, 95)
HALBTURM = (190, 225)
RONDELL = (1215, 345)

# ---------- Straßen und Gassen der Stadt (Planpunkte) ----------
STRASSEN = [
    # Hauptstraße vom Torhaus West zum Markt, Fachwerkhäuser zu beiden Seiten
    [(162, 432), (230, 440), (300, 447), (370, 455), (455, 480)],
    # Gasse innen an der Mauer unter dem Grat
    [(230, 440), (262, 418), (350, 410), (470, 404), (560, 414), (600, 440)],
    [(370, 455), (350, 410)],
    [(566, 478), (600, 440)],
    # Westviertel: Bogen an der Stadtmauer entlang und Gasse um St. Marien zum Markt
    [(230, 440), (215, 495), (250, 555), (300, 610), (350, 640)],
    [(300, 447), (295, 525), (330, 585), (400, 590), (456, 558)],
    [(250, 555), (295, 525)],
    # Südviertel zwischen Markt und Stadtmauer
    [(456, 558), (440, 610), (430, 645)],
    [(512, 556), (510, 645)],
    [(568, 556), (575, 645)],
    [(400, 590), (440, 610), (510, 612), (575, 612)],
    # Vom Markt zum Hafen, zum Portal von St. Marien
    [(566, 500), (606, 500)],
    [(370, 455), (366, 500)],
]
# Kaiweg im Hafen: von der Hafenpforte am Becken entlang zum Hafentor
KAIWEG = [(606, 500), (612, 470), (630, 440), (680, 428), (750, 424)]
# Weg vom Torhaus Nord im Zwinger westlich der Vorburg hinab zum Tor der Vorburg
WEG_NORDWEST = [(294, 160), (294, 186), (296, 250), (300, 320), (322, 372), (352, 380), (385, 362)]
# Durch das Nordtor in den Zwinger
WEG_NORDTOR = [(1254, 195), (1225, 197), (1180, 215)]
# Die Rampe hinauf und die Wege im Zwinger sind keine Stadtgassen, gehören aber ins Wegenetz
BURGWEGE = [WEG_UNTEN, RAMPE_BURGHOF2, WEG_NORDWEST]


def plan_json():
    zonen = [
        {"name": "I. Vorburg", "punkte": welt_liste(VORBURG), "hoehe": H_VORBURG, "rand": 6.0},
        {"name": "II. Burghof", "punkte": welt_liste(BURGHOF2), "hoehe": H_BURGHOF2, "rand": 4.0},
        {"name": "III. Burghof", "punkte": welt_liste(BURGHOF3), "hoehe": H_KERNHOF, "rand": 4.0},
        {"name": "Zwinger der Kernburg", "punkte": welt_liste(ZWINGER_KERNBURG), "hoehe": H_ZWINGER, "rand": 6.0},
        {"name": "Kernburg", "punkte": welt_liste(KERNBURG), "hoehe": H_KERNBURG, "rand": 3.0},
    ]
    return {
        "_hinweis": "Erzeugt von werkzeuge/bau/plan_drachenstein.py aus dem Grundriss. Nicht von Hand ändern.",
        "zonen": zonen,                                  # in dieser Reihenfolge eingeebnet; spätere gewinnen
        "ring": welt_liste(RINGMAUER),                   # Burgbezirk: Grat mit Zwingern
        "stadt": welt_liste(STADT + []),                 # Stadt in der Ebene
        "hafen": welt_liste(HAFEN_BEZIRK),
        "grat": welt_liste([VORBURG[0], (445, 212), (636, 160), (842, 222), (1100, 200)]),
        "stadt_hoehe": [welt((150, 430))[1], H_STADT_WEST, welt((600, 470))[1], H_STADT_OST],
        "hafen_hoehe": H_HAFEN,
        "weg_unten": [list(welt(p)) for p in WEG_UNTEN],
        "weg_unten_hoehen": [-17.6, -16.0, -14.5, -9.0, -1.5, 0.5, 2.5, 6.5],
        "weg_nordwest": [list(welt(p)) for p in WEG_NORDWEST],
        "weg_nordwest_hoehen": [-12.5, -11.0, -6.0, -1.0, 3.0, 5.0, 6.5],
        "weg_nordtor": [list(welt(p)) for p in WEG_NORDTOR],
        "weg_nordtor_hoehen": [-14.0, -9.5, -6.0],
        "rampe": [list(welt(p)) for p in RAMPE_BURGHOF2],
        "rampe_hoehen": [0.5, 4.5, 8.5, H_BURGHOF2],
        "hafen_becken": welt_liste(HAFENBECKEN),
        "fahrrinne": welt_liste(FAHRRINNE),
        "bucht": welt_liste(BUCHT),
        "grat_hoehen": [H_VORBURG, H_KERNBURG],
        "zwinger_hoehen": [-9.0, -2.0],
        "strassen": [welt_liste(s) for s in STRASSEN],
        "markt": welt_liste(MARKTPLATZ),
        "ebene": H_EBENE,
    }


if __name__ == "__main__":
    ziel = Path(__file__).resolve().parents[2] / "daten" / "drachenstein_plan.json"
    ziel.write_text(json.dumps(plan_json(), ensure_ascii=False, indent=1), encoding="utf-8")
    print("geschrieben:", ziel)
    for name, p in [("III. Burghof", MITTE), ("Kernburg", (990, 220)), ("I. Vorburg", (385, 290)),
                    ("Markt", MARKT_MITTE), ("Hafenmitte", (720, 530)), ("Hafenausfahrt", (830, 600)),
                    ("Torhaus West", TORE["Torhaus West"]), ("Torhaus Nord", TORE["Torhaus Nord"]),
                    ("Hafentor", TORE["Hafentor"]), ("Nordtor", TORE["Nordtor"])]:
        print(f"  {name:16s} {welt(p)}")
