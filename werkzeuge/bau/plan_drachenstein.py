"""Grundriss der Burgfeste Drachenstein (docs/bilder/grundriss-drachenstein-2.webp), digitalisiert.

Alle Punkte stehen in Bildpunkten des Plans (x nach rechts, y nach unten). Maßstab: 0,5 m je Bildpunkt (die ganze
Anlage ist rund 650 m lang). Der Plan ist gedreht eingebaut: Plan-Süd (Stadt und Hafen) zeigt in der Welt nach Osten
(+x, zum Wächtermeer), Plan-Ost (Kernburg) nach Norden (-z). Die Mitte des III. Burghofs ist der Weltursprung (0, 0):
Dort liegt der Hof aus Akt I (burg_hof.tscn, Mauern bei ±31 m), angehoben auf HOF_Y.

Aufbau nach dem Plan und den Schnitten A-A und B-B:
  Auf einem Felsgrat liegen hintereinander die I. Vorburg, der II. Burghof, der III. Burghof (Hof aus Akt I) und
  die Kernburg mit Bergfried, Palas, Drachenkapelle, Burgküche und Zeughaus, umgeben von der Zwingermauer.
  Eine Ringmauer (Stadtmauer) mit Torhäusern, Halbturm, Wehrturm, Zwinger und Rondell umschließt den Grat.
  Unten in der Ebene liegen die Stadt mit St. Marien und dem Marktplatz und der Drachenhafen mit Speicher; die
  Hafeneinfahrt zwischen dem Rundturm der Hafenmauer und dem Turm am Speicherkai ist offen zum Meer. Das Hafentor
  in der Ringmauer ist ein Wassertor: Ein Kanal führt die Schiffe in den Felsenhafen unter der Burg.
  Zugang zur Burg (blaue Linie): vom Hafen oder vom Torhaus West durch die Stadt, durch das Burgstraßentor in der
  Ringmauer, am Halbturm vorbei hinauf (dort kommt der Weg vom Torhaus Nord dazu) und dann außen um die ganze Burg
  bis unter den II. Burghof, wo eine Rampe durch das Rampentor hinaufführt. Unten zweigt ein Weg zum Südtor der
  Vorburg ab. In die Kernburg steigt der Weg im Zwinger einmal um sie herum zum Kernburgtor.

Höhen (Welt-y, Meer bei -20), gestaffelt wie im Schnitt B-B: Hafen -17,8 · Stadt -16,5 bis -14 ·
I. Vorburg 0 · II. Burghof +6 · III. Burghof +14 (Hof aus Akt I) · Kernburg +38 (Bergfried bis +76).
Zwischen den Burgen und zur Ebene bricht der Fels steil ab.

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
H_VORBURG = 0.0
H_BURGHOF2 = 6.0
H_KERNHOF = HOF_Y         # III. Burghof
H_KERNBURG = 38.0         # auf dem höchsten Fels; der Zwinger steigt vom III. Burghof hinauf
H_EBENE = -14.0           # Land vor der Ringmauer

# ---------- Burgen auf dem Grat ----------
VORBURG = [(318, 250), (360, 232), (445, 212), (458, 270), (450, 330), (420, 352), (350, 358), (312, 300)]
BURGHOF2 = [(458, 270), (445, 212), (472, 215), (530, 192), (600, 182), (636, 160), (636, 290),
            (625, 322), (580, 336), (513, 326), (487, 294)]
BURGHOF3 = [(636, 160), (650, 136), (838, 134), (842, 310), (668, 318), (645, 300), (636, 290)]
KERNBURG = [(878, 255), (878, 185), (912, 138), (965, 126), (1065, 116), (1100, 150), (1102, 280), (1062, 302),
            (950, 302), (896, 288)]
ZWINGER_KERNBURG = [(842, 310), (838, 134), (852, 120), (885, 105), (965, 88), (1095, 82), (1152, 130),
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
HAFENBECKEN = [(632, 452), (700, 444), (790, 452), (812, 472), (822, 548), (806, 604), (760, 600), (652, 600),
               (634, 560), (622, 486)]
HAFENEINFAHRT = 4         # Kante des Beckens zur offenen See
HAFENMAUER_OST = [(785, 412), (828, 440), (832, 532)]
SPEICHERKAI = [(640, 612), (770, 614), (790, 628), (660, 640), (630, 628)]
HAFEN_BEZIRK = [(615, 425), (785, 412), (828, 440), (842, 540), (824, 552), (808, 606), (800, 622), (800, 640),
                (770, 648), (640, 650), (600, 664), (590, 560), (600, 470)]
FAHRRINNE = [(806, 606), (822, 548), (960, 830), (880, 860)]
# Meer (blau markiert im Grundriss): Es reicht bis an die Klippe unter der Ringmauer zwischen Hafen und Rondell, bis an
# die Hafeneinfahrt und südlich der Stadt bis an die Küste. Neben der Hafenmauer bleibt ein Felsstreifen.
BUCHT = [(826, 556), (845, 548), (870, 505), (950, 468), (1100, 436), (1250, 425), (1450, 440), (1650, 620),
         (1720, 760), (1720, 950), (280, 950), (280, 760), (450, 748), (600, 735), (670, 712), (720, 682),
         (790, 660), (806, 642), (810, 610)]
# Wassertor (Hafentor) und Felsenhafen unter der Burg: ein Kanal vom Becken durch die Ringmauer in den Fels,
# darin ein Kai an der Westseite; der Felsenhafen ist überwölbt (teil_stadt.py)
KANAL = [(744, 455), (744, 352), (764, 352), (764, 455)]
FELSENHAFEN = [(722, 410), (722, 348), (772, 348), (772, 411)]
# Mole vom Speicherkai (Molenpforte) zur ersten Insel, von dort Brücken zum Schwarzen Bergfried
MOLENPFORTE = (755, 645.5)

# ---------- Tore ----------
# Tore als (Kantenindex im jeweiligen Linienzug, Anteil, Breite, Name); die Punkte im Plan stehen dahinter
TORE = {
    "Torhaus West": (157.5, 447.5),      # in der Stadtmauer: Stadt ↔ Küstenweg
    "Torhaus Nord": (294, 173.6),        # in der Ringmauer: Burgbezirk ↔ Weg nach Gravemarch
    "Hafentor": (748, 408),              # Wassertor: Kanal vom Hafen in den Felsenhafen, daneben der Kai
    "Burgstraßentor": (233, 410.1),      # Stadt ↔ Burgweg (in der Ringmauer westlich des Grats)
    "Tor zur Vorburg": (436.8, 339.7),   # Südtor der Vorburg, vom Weg unter der Vorburg
    "Rampentor": (628.5, 311.8),         # Südtor des II. Burghofs, am Ende des Burgwegs um die Burg
    "Tor des II. Burghofs": (455.4, 258.4),  # zwischen I. Vorburg und II. Burghof
    "Tor des III. Burghofs": (636, 228), # II. ↔ III. Burghof, vor dem Tor des Hofs aus Akt I
    "Burgtor": (840, 222),               # III. Burghof ↔ Zwinger der Kernburg
    "Kernburgtor": (1082, 291),          # Zwinger ↔ Kernburg, am Ende des Zwingerwegs
    "Hafenpforte": (596, 500),           # Stadt ↔ Hafenkai
}

# ---------- Bauten ----------
# (Mitte, Länge, Breite, Drehung in Grad) in Bildpunkten; Länge entlang Plan-x bei Drehung 0
BERGFRIED_KERNBURG = (1075, 140)
PALAS = ((995, 155), 120, 32, 4)
DRACHENKAPELLE = ((1075, 215), 22, 80, 0)
BURGKUECHE = ((905, 252), 52, 30, -25)
ZEUGHAUS = ((1030, 260), 56, 26, -3)
VORBURG_BAUTEN = [((410, 228), 60, 18, -13), ((330, 300), 22, 50, 0)]
BURGHOF2_BAUTEN = [((565, 198), 70, 20, -8), ((585, 318), 60, 22, -10)]
ST_MARIEN = ((410, 500), 76, 34, 0)      # Langhaus von West nach Ost, Turm im Osten
ST_MARIEN_TURM = (444, 494)
MARKTPLATZ = [(455, 480), (566, 478), (568, 556), (456, 558)]
MARKT_MITTE = (512, 518)
SPEICHER = ((690, 628), 100, 20, 1)
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
# Kaiweg im Hafen: von der Hafenpforte am Becken entlang zum Kai am Kanal
KAIWEG = [(606, 500), (612, 470), (630, 440), (680, 428), (736, 428)]
# Burgweg (blaue Linie im Grundriss): von der Gasse an der Mauer durch das Burgstraßentor, im Westen am Halbturm
# vorbei hinauf, wo der Weg vom Torhaus Nord dazukommt; dann außen um die ganze Burg: im Norden zwischen den Burgen und
# der Ringmauer am Wehrturm vorbei, um den Zwinger der Kernburg, am Rondell vorbei und im Süden unter den Burgen zurück
# über den Felsenhafen; zuletzt die Rampe hinauf durch das Rampentor in den II. Burghof und weiter in den III. Burghof.
WEG_BURG = [(230, 440), (233, 410.1), (237, 380), (240, 300), (262, 240), (300, 205), (360, 198), (450, 178),
            (530, 162), (600, 140), (650, 112), (700, 106), (760, 108), (800, 116), (850, 95), (900, 78), (965, 62),
            (1030, 58), (1100, 56), (1160, 85), (1197, 140), (1195, 205), (1180, 290), (1150, 335), (1050, 357),
            (950, 368), (870, 375), (800, 352), (785, 336), (720, 334), (668, 330), (645, 322), (628.5, 311.8),
            (612, 300), (600, 290), (560, 285), (540, 262), (600, 245), (625, 230), (636, 228), (650, 228)]
# Unten im Westen zweigt der Weg zur Vorburg ab: unter der Vorburg nach Osten zu ihrem Südtor, durch die Vorburg und
# das Tor des II. Burghofs zurück auf den Burgweg
WEG_VORBURG = [(237, 380), (300, 388), (380, 382), (430, 376), (441, 356), (436.8, 339.7), (430, 325), (400, 300),
               (412, 280), (432, 264), (455.4, 258.4), (470, 256), (540, 262)]
# Vom Torhaus Nord hinab auf den Burgweg
WEG_TORHAUS_NORD = [(294, 160), (294, 180), (300, 205)]
# Zwingerweg: vom Burgtor einmal um die Kernburg herum hinauf zum Kernburgtor
WEG_ZWINGER = [(840, 222), (856, 222), (859, 160), (880, 128), (930, 110), (1000, 104), (1080, 104), (1118, 138),
               (1130, 200), (1128, 260), (1108, 302), (1087, 300), (1082, 291), (1075, 276)]


def _laengen(linie):
    erg = [0.0]
    for a, b in zip(linie, linie[1:]):
        erg.append(erg[-1] + math.dist(a, b))
    return erg


def _steigend(linie, feste):
    """Höhen je Punkt: feste = {Index: Höhe}; dazwischen gleichmäßig nach der Weglänge."""
    s = _laengen(linie)
    idx = sorted(feste)
    erg = []
    for i in range(len(linie)):
        if i <= idx[0]:
            erg.append(feste[idx[0]]); continue
        if i >= idx[-1]:
            erg.append(feste[idx[-1]]); continue
        a = max(k for k in idx if k <= i); b = min(k for k in idx if k >= i)
        t = 0.0 if a == b else (s[i] - s[a]) / (s[b] - s[a])
        erg.append(round(feste[a] + (feste[b] - feste[a]) * t, 2))
    return erg


def hoehe_auf(linie, hoehen, p):
    """Höhe des Wegs am nächsten Punkt zu p (alles im Plan)."""
    bester = None
    for i, (a, b) in enumerate(zip(linie, linie[1:])):
        dx, dy = b[0] - a[0], b[1] - a[1]
        t = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / (dx * dx + dy * dy)))
        d = math.dist(p, (a[0] + dx * t, a[1] + dy * t))
        if bester is None or d < bester[0]:
            bester = (d, hoehen[i] + (hoehen[i + 1] - hoehen[i]) * t)
    return bester[1]


# Der Berg steigt vom Hafen und der Stadt nach Osten: Der Burgweg klettert im Norden hinauf, am höchsten ist er im
# Osten an der Kernburg über der Klippe, im Süden fällt er wieder zum Rampentor.
_i = WEG_BURG.index
WEG_BURG_HOEHEN = _steigend(WEG_BURG, {0: -14.3, 1: -14.0, _i((300, 205)): -9.0, _i((650, 112)): 2.0,
                                       _i((1100, 56)): 20.0, _i((1197, 140)): 24.0, _i((1180, 290)): 24.0,
                                       _i((950, 368)): 16.0, _i((785, 336)): 8.0,
                                       _i(TORE["Rampentor"]): H_BURGHOF2, _i((540, 262)): H_BURGHOF2,
                                       _i(TORE["Tor des III. Burghofs"]): H_KERNHOF, len(WEG_BURG) - 1: H_KERNHOF})
WEG_VORBURG_HOEHEN = _steigend(WEG_VORBURG, {0: hoehe_auf(WEG_BURG, WEG_BURG_HOEHEN, (237, 380)),
                                             5: H_VORBURG, 7: H_VORBURG, 10: H_BURGHOF2, 12: H_BURGHOF2})
WEG_TORHAUS_NORD_HOEHEN = [-12.5, -11.0, -9.0]
WEG_ZWINGER_HOEHEN = _steigend(WEG_ZWINGER, {1: H_KERNHOF, 12: H_KERNBURG})
WEG_ZWINGER_HOEHEN[0] = H_KERNHOF
# Die Wege im Burgbezirk sind keine Stadtgassen, gehören aber ins Wegenetz
BURGWEGE = [WEG_BURG, WEG_VORBURG, WEG_TORHAUS_NORD, WEG_ZWINGER]


def plan_json():
    zonen = [
        {"name": "I. Vorburg", "punkte": welt_liste(VORBURG), "hoehe": H_VORBURG, "rand": 6.0},
        {"name": "II. Burghof", "punkte": welt_liste(BURGHOF2), "hoehe": H_BURGHOF2, "rand": 6.0},
        {"name": "III. Burghof", "punkte": welt_liste(BURGHOF3), "hoehe": H_KERNHOF, "rand": 6.0},
        # Der Zwinger steigt mit dem Zwingerweg: Höhe des nächsten Wegpunkts
        {"name": "Zwinger der Kernburg", "punkte": welt_liste(ZWINGER_KERNBURG), "hoehe": H_KERNHOF, "rand": 6.0,
         "weg": welt_liste(WEG_ZWINGER), "weg_hoehen": WEG_ZWINGER_HOEHEN},
        {"name": "Kernburg", "punkte": welt_liste(KERNBURG), "hoehe": H_KERNBURG, "rand": 7.0},
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
        # [Linienzug, Höhen, folgt der Burgbezirk diesem Weg?] – der Grund zwischen Burgen und Ringmauer liegt auf
        # der Höhe des nächsten Burgwegs; die Burgen stehen darüber auf ihren Felsen
        "burgwege": [[welt_liste(l), h, r] for l, h, r in [(WEG_BURG, WEG_BURG_HOEHEN, True),
                                                           (WEG_VORBURG, WEG_VORBURG_HOEHEN, True),
                                                           (WEG_TORHAUS_NORD, WEG_TORHAUS_NORD_HOEHEN, True),
                                                           (WEG_ZWINGER, WEG_ZWINGER_HOEHEN, False)]],
        "hafen_becken": welt_liste(HAFENBECKEN),
        "fahrrinne": welt_liste(FAHRRINNE),
        "kanal": welt_liste(KANAL),
        "felsenhafen": welt_liste(FELSENHAFEN),
        "bucht": welt_liste(BUCHT),
        "grat_hoehen": [H_VORBURG, H_KERNBURG],
        "grat_abfall": 3.0,
        "abfall": 26.0,              # außen an der Ringmauer fällt der Berg steil ins Tal
        "zwinger_hoehen": [-12.0, -2.0],
        "strassen": [welt_liste(s) for s in STRASSEN],
        "markt": welt_liste(MARKTPLATZ),
        "ebene": H_EBENE,
    }


if __name__ == "__main__":
    ziel = Path(__file__).resolve().parents[2] / "daten" / "drachenstein_plan.json"
    ziel.write_text(json.dumps(plan_json(), ensure_ascii=False, indent=1), encoding="utf-8")
    print("geschrieben:", ziel)
    for name, p in [("III. Burghof", MITTE), ("Kernburg", (990, 220)), ("I. Vorburg", (385, 290)),
                    ("Markt", MARKT_MITTE), ("Hafenmitte", (720, 530)), ("Hafeneinfahrt", (814, 578)),
                    ("Torhaus West", TORE["Torhaus West"]), ("Torhaus Nord", TORE["Torhaus Nord"]),
                    ("Hafentor", TORE["Hafentor"])]:
        print(f"  {name:16s} {welt(p)}")
