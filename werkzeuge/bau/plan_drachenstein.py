"""Grundriss der Burgfeste Drachenstein, digitalisiert.

Burg, Mauern, Stadt und Wege nach der dritten Fassung (docs/bilder/grundriss-drachenstein-3.webp, Punkte in
grundriss3.py), Hafen, Meer und Weltbezug nach der zweiten (docs/bilder/grundriss-drachenstein-2.webp). Alle Punkte
hier stehen in Bildpunkten der zweiten Fassung (x nach rechts, y nach unten), Maßstab 0,5 m je Bildpunkt; die der
dritten werden umgerechnet (g3). Der Plan ist gedreht eingebaut: Plan-Süd (Stadt und Hafen) zeigt in der Welt nach
Osten (+x, zum Wächtermeer), Plan-Ost (Palas) nach Norden (-z).

Aufbau: Auf dem Felsgrat liegen hintereinander die Vorburg, die Mittelburg, die Oberburg und der Palas mit dem
Bergfried in einem engen Zwinger; die Stadt legt sich im Westen und Süden um die Vorburg, davor der Drachenhafen. Im
Norden sind die Mauern der Mittelburg zugleich die Außenmauer, hinter Oberburg und Palas läuft die Ringmauer.
Wege (vom Spieler eingezeichnet): vom Hafen durch die Stadt im Bogen um die Vorburg hinauf zum Vorburgtor, durch den
Hof der Vorburg und ihr Osttor hinab in den Burgbezirk, an der Mauer entlang zur Rampe, durch das Rampentor in die
Mittelburg, gleich rechts durch das Zwingertor in den Zwinger an der Südseite der Oberburg, an dessen Ende in die
Oberburg und über den Durchgang in den Palas. Nebenwege: Nordtor und Südtor der Stadt, der Zwingerweg um die Oberburg,
der enge Zwinger um den Palas und der äußere Weg um ihn bis hinab zum Fuß der Rampe.

Höhen (Welt-y, Meer bei -20): Hafen -17,8 · Stadt -16,5 bis -14, zur Vorburg hin ansteigend · Vorburg -8 · Burgbezirk
unten -9 bis 0 · Mittelburg +6 · Oberburg +14 · Palas +16 (Bergfried bis +76).

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
HOF_Y = 14.0              # Oberburg (hier lag früher der Hof aus Akt I, jetzt das Ordensvorwerk, siehe VORWERK)
H_VORBURG = -8.0          # über der Stadt, das Vorburgtor auf Höhe der obersten Gasse
H_UNTEN = -9.0            # Burgbezirk am Osttor der Vorburg; von dort steigt der Weg an der Mauer zur Rampe
H_RAMPENFUSS = 0.0
H_BURGHOF2 = 6.0          # Mittelburg
H_KERNHOF = HOF_Y         # Oberburg
H_KERNBURG = 16.0         # Palas, fast auf einer Ebene mit der Oberburg
H_ZWINGER_KERNBURG = H_KERNBURG - 0.5
H_EBENE = -14.0           # Land vor der Ringmauer

# ---------- Ordensvorwerk (Akt I) ----------
# Der Hof aus Akt I (szenen/welt/burg_hof.tscn) liegt nicht in der Burg, sondern als Vorwerk des Ordens vor der
# Stadt auf der Hochfläche am Küstenweg: Wer von Valdrenn kommt und dem Orden beitreten will, wird hier geprüft,
# bevor er die Burg betritt. Weltkoordinaten; das Tor (lokal +z) zeigt nach Osten zur Straße.
VORWERK = (75.0, 490.0)
VORWERK_DREH = 90.0
H_VORWERK = 1.0


# ---------- Grundriss, dritte Fassung (grundriss3.py) ----------
# Die Punkte des neuen Plans werden mit einer Ähnlichkeitsabbildung in diese Planpunkte umgerechnet: Maßstab 0,67,
# 4,7° gedreht, so verschoben, dass das Torhaus über dem Wassertor auf dem bisherigen Hafentor liegt. So bleiben Hafen,
# Untergrundhafen, Meer und die Landstraßen an ihrem Platz.
import grundriss3 as G3
_S = complex(0.6700687141452312 * math.cos(math.radians(-4.684566799980108)),
             0.6700687141452312 * math.sin(math.radians(-4.684566799980108)))
_T = complex(754.0, 408.6) - _S * complex(1107, 607)
G3_MASSSTAB = abs(_S)
G3_DREHUNG = -4.684566799980108


def g3(p):
    """Bildpunkt des neuen Plans → Planpunkt."""
    z = _S * complex(*p) + _T
    return (round(z.real, 2), round(z.imag, 2))


def g3l(punkte):
    return [g3(p) for p in punkte]


def g3_bau(bau, h=None):
    """Bau aus grundriss3 ((Mitte), Länge, Breite, Richtung der Länge im Bild) → (Mitte, Länge, Breite, Drehung) im Plan.
    h: Mitte des Hofs (Plan); dann zeigt die Tür (lokal +x, Plan (-sin dreh, cos dreh)) zum Hof."""
    (m, laenge, breite, richtung) = bau
    pm = g3(m)
    dreh = richtung + G3_DREHUNG
    if h is not None:
        a = math.radians(dreh)
        if -math.sin(a) * (h[0] - pm[0]) + math.cos(a) * (h[1] - pm[1]) < 0:
            dreh += 180.0
    return (pm, round(laenge * G3_MASSSTAB, 2), round(breite * G3_MASSSTAB, 2), round(dreh % 360.0, 1))


def schwerpunkt(punkte):
    return (sum(p[0] for p in punkte) / len(punkte), sum(p[1] for p in punkte) / len(punkte))


# ---------- Burghöfe ----------
VORBURG = g3l(G3.VORBURG)
BURGHOF2 = MITTELBURG = g3l(G3.MITTELBURG)
BURGHOF3 = OBERBURG = g3l(G3.OBERBURG)
KERNBURG = PALAS_HOF = g3l(G3.PALAS_HOF)
ZWINGER_KERNBURG = g3l(G3.PALAS_ZWINGER)            # enger Zwinger um den Palas
# Zwinger der Oberburg (West- und Südseite) mit dem Durchgang zum Palas, für das Gelände: außen die Ostmauer der
# Mittelburg, die Zwingermauer im Süden und der Zwinger des Palas, innen die Mauern der Oberburg
ZWINGER_III = g3l([(932, 268), (938, 330), (946, 400), (948, 440), (1055, 490), (1160, 480), (1172, 505), (1230, 515),
                   (1268, 505), (1272, 470), (1273, 360), (1276, 300), (1262, 262), (1250, 298), (1247, 430),
                   (1180, 437), (1105, 435), (1050, 420), (1020, 400), (980, 375), (967, 330), (1025, 235), (985, 243)])
ZWINGERMAUER_SUED = g3l([(948, 440)] + G3.ZWINGER_SUED[1:])
DURCHGANG_NORD, DURCHGANG_SUED = g3l(G3.DURCHGANG_NORD), g3l(G3.DURCHGANG_SUED)
VORTOR, PALASZWINGER_QUER = g3l(G3.VORTOR), g3l(G3.PALASZWINGER_QUER)
MITTE_VORBURG, MITTE_MITTELBURG = schwerpunkt(VORBURG), schwerpunkt(MITTELBURG)
MITTE_OBERBURG, MITTE_PALAS = schwerpunkt(OBERBURG), schwerpunkt(PALAS_HOF)

# ---------- Mauern ----------
RING_NORD = g3l(G3.RING_NORD)                        # vom Torhaus im Nordwesten über das Nordtor an die Vorburg
# Ringmauer im Süden und Osten: vom Rundturm am Vorburgtor an der Stadt entlang zum Hafentor (Wassertor), um Oberburg
# und Palas bis an die Nordostecke der Mittelburg
_MAUER_HAFEN = [(700, 403), (785, 412)]           # am Wassertor wie bisher (Kanal und Untergrundhafen)
RING_SUED_OST = g3l(G3.STADT_BURG_MAUER[:2]) + _MAUER_HAFEN + g3l(G3.RING_OST[::-1][2:])
STADTMAUER = g3l(G3.STADTMAUER[:-2]) + [(600, 664), (640, 645)]  # durch das Südtor bis an die Ecke und an die Speicherkaimauer
# Umriss der ganzen Festung (Küstenfels, Bewuchs): Stadt, Burgbezirk und Hafen
RINGMAUER = (g3l(G3.RING_NORD[:-1] + [(700, 272), (722, 274), (743, 283)] + G3.MITTELBURG[1:4] + G3.RING_OST[1:-1])
             + [(785, 412), (828, 440), (842, 540), (812, 549), (808, 606), (800, 622), (800, 640), (770, 648), (640, 650)]
             + STADTMAUER[::-1][:-1])
# Burgbezirk: zwischen Stadtmauer, Ringmauer und den Burgen (Mittelburg, Oberburg und Palas liegen darin)
BURGBEZIRK = (g3l([G3.VORBURG_TOR[0]] + G3.STADT_BURG_MAUER[1:2]) + _MAUER_HAFEN + g3l(G3.RING_OST[::-1][2:]
                 + [(887, 232), (763, 272), (743, 283), (738, 330), (737, 362), (700, 362), (700, 412),
                    (706, 455), (690, 470)]))
# Stadt mit der Vorburg und dem Streifen nördlich davon (bis an die Ringmauer mit dem Nordtor)
STADT = (g3l(G3.RING_NORD + [(722, 274), (743, 283), (738, 330), (737, 362), (700, 362), (700, 412),
                              (706, 455), G3.VORBURG_TOR[0]] + G3.STADT_BURG_MAUER[1:2]) + _MAUER_HAFEN[:1]
         + [(615, 425), (600, 470), (590, 560), (600, 664)] + STADTMAUER[::-1][1:-1])

# ---------- Tore (Planpunkte) ----------
TORE = {
    "Nordtor": g3(G3.NORDTOR),                       # Ringmauer: Stadt ↔ Weg nach Gravemarch
    "Südtor": g3(G3.SUEDTOR),                        # Stadtmauer: Stadt ↔ Küstenweg
    "Vorburgtor": g3(G3.VORBURGTOR),                 # Stadt ↔ Vorburg
    "Osttor der Vorburg": g3(G3.VORBURG_OSTTOR),     # Vorburg ↔ Burgbezirk
    "Rampentor": g3(G3.RAMPENTOR),                   # oben an der Rampe in die Mittelburg
    "Zwingertor": g3(G3.ZWINGERTOR),                 # Mittelburg ↔ Zwinger der Oberburg
    "Südtor der Oberburg": g3(G3.OBERBURG_SUEDTOR),  # Ostende des Zwingers ↔ Oberburg
    "Tor der Oberburg": g3(G3.OBERBURG_TOR),         # Oberburg ↔ Durchgang
    "Zwingertor des Palas": g3(G3.PALAS_ZWINGERTOR),
    "Palastor": g3(G3.PALAS_TOR),
    "Zwingerpforte des Palas": g3(G3.PALAS_ZWINGERPFORTE),
    "Hafentor": (754, 408.6),                        # Wassertor: niedriger Bogen direkt auf dem Wasser
}

# ---------- Bauten ----------
def _abstand_rand(q, poly):
    """Abstand eines Punkts vom Rand des Vielecks (Plan)."""
    best = 1e9
    for (ax, ay), (bx, by) in zip(poly, poly[1:] + poly[:1]):
        dx, dy = bx - ax, by - ay
        t = max(0.0, min(1.0, ((q[0] - ax) * dx + (q[1] - ay) * dy) / (dx * dx + dy * dy)))
        best = min(best, math.dist(q, (ax + dx * t, ay + dy * t)))
    return best


def _im_vieleck(q, poly):
    x, y = q; innen = False
    for (x1, y1), (x2, y2) in zip(poly, poly[1:] + poly[:1]):
        if (y1 > y) != (y2 > y) and x < x1 + (y - y1) * (x2 - x1) / (y2 - y1):
            innen = not innen
    return innen


def nach_innen(bau, hof, abstand=5.0):
    """Schiebt einen Bau in Richtung seiner Tür (zum Hof), bis alle Ecken im Hof liegen und mindestens 'abstand'
    Planpunkte (2,5 m: halbe Mauerdicke und ein Rand) von der Hofmauer entfernt sind."""
    (pp, laenge, breite, dreh) = bau
    a = math.radians(dreh)
    ux, uy, vx, vy = math.cos(a), math.sin(a), -math.sin(a), math.cos(a)
    for k in range(60):
        m = (pp[0] + vx * k * 0.5, pp[1] + vy * k * 0.5)
        ecken = [(m[0] + ux * sx * laenge / 2 + vx * sy * breite / 2, m[1] + uy * sx * laenge / 2 + vy * sy * breite / 2)
                 for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        if all(_im_vieleck(e, hof) and _abstand_rand(e, hof) >= abstand for e in ecken):
            return ((round(m[0], 2), round(m[1], 2)), laenge, breite, dreh)
    return bau


VORBURG_BAUTEN = [nach_innen(g3_bau(b, MITTE_VORBURG), VORBURG) for b in G3.VORBURG_BAUTEN]
BURGHOF2_BAUTEN = [nach_innen(g3_bau(b, MITTE_MITTELBURG), MITTELBURG) for b in G3.MITTELBURG_BAUTEN]
BURGHOF3_BAUTEN = [nach_innen(g3_bau(b, MITTE_OBERBURG), OBERBURG) for b in G3.OBERBURG_BAUTEN]
PALAS_BAUTEN = [nach_innen(g3_bau(b, MITTE_PALAS), PALAS_HOF) for b in G3.PALAS_BAUTEN]
PALAS = nach_innen(g3_bau(G3.PALAS_LANG, MITTE_PALAS), PALAS_HOF)
BURGKUECHE = PALAS_BAUTEN[2]
DRACHENKAPELLE = PALAS_BAUTEN[3]
ZEUGHAUS = PALAS_BAUTEN[6]
BERGFRIED_KERNBURG = g3(G3.BERGFRIED[0])
BERGFRIED_DREH = G3.BERGFRIED[2] + G3_DREHUNG
BERGFRIED_SEITE = 18.5            # Meter: so wuchtig wie im Referenzbild
BERGFRIED_HOEHE = 56.0            # über H_BERGFRIEDFELS bis zur Plattform
H_BERGFRIEDFELS = H_KERNBURG + 4.0
PALAS_ECKBAU = g3_bau(G3.PALAS_ECKBAU[:1] + (G3.PALAS_ECKBAU[1], G3.PALAS_ECKBAU[1], G3.PALAS_ECKBAU[2]))
ST_MARIEN = g3_bau(G3.ST_MARIEN)
ST_MARIEN_TURM = g3(G3.ST_MARIEN_TURM)
MARKTPLATZ = [(455, 480), (566, 478), (568, 556), (456, 558)]
MARKT_MITTE = (512, 518)
SPEICHER = ((690, 628), 100, 20, 1)
HEILSTUBE = g3((1110, 340))                          # Ankunft nach einer Verwundung: Mitte der Oberburg

# ---------- Wege ----------
# vom Marktplatz zum Westkai des Hafens (der Kai liegt nach der zweiten Fassung)
WEG_HAFEN = g3l(G3.WEG_HAFEN[:-1]) + [(608, 512)]
STRASSEN = [WEG_HAFEN] + [g3l(s) for s in [G3.WEG_STADT[:-2], G3.WEG_NORDTOR[2:], G3.WEG_SUEDTOR[2:]] + G3.GASSEN]
# Anschlüsse der Gassen an den Marktplatz: von der Mitte jeder Seite zum nächsten Punkt einer Gasse
_MARKT_SEITEN = [(458, 518), (563, 500), (512, 483), (512, 552), (563, 555)]
_alle_gassenpunkte = [q for l_ in STRASSEN for q in l_]
STRASSEN += [[m_, min(_alle_gassenpunkte, key=lambda q, m_=m_: math.dist(q, m_))] for m_ in _MARKT_SEITEN]
# Kaiweg im Hafen: vom Ende der Hauptgasse am Becken entlang zum Kai am Kanal
KAIWEG = [(608, 512), (612, 470), (630, 440), (680, 428), (736, 428)]
WEG_STADT = g3l(G3.WEG_STADT)
WEG_VORBURG = g3l(G3.WEG_VORBURG)
WEG_BURG = g3l(G3.WEG_UNTEN + G3.WEG_RAMPE[1:])      # unten an der Mauer zur Rampe, die Rampe hinauf in die Mittelburg
WEG_ZWINGER = g3l(G3.WEG_ZWINGER)
WEG_OBERBURG = g3l(G3.WEG_OBERBURG)
WEG_DURCHGANG = g3l(G3.WEG_DURCHGANG)
WEG_AUSSEN = g3l(G3.WEG_AUSSEN)
WEG_PALASZWINGER = g3l(G3.WEG_PALASZWINGER)
WEG_NORDTOR = g3l(G3.WEG_NORDTOR)
WEG_SUEDTOR = g3l(G3.WEG_SUEDTOR)


# Hafen: Becken mit Kaimauern, östliche Hafenmauer mit Rundturm, Speicherkai im Süden mit Turm
HAFENBECKEN = [(632, 452), (700, 444), (790, 452), (800, 470), (808, 548), (806, 604), (760, 600), (652, 600),
               (634, 560), (622, 486)]
HAFENEINFAHRT = 4         # Kante des Beckens zur offenen See
HAFENMAUER_OST = [(785, 412), (828, 440), (832, 532)]
SPEICHERKAI = [(640, 612), (770, 614), (790, 628), (660, 640), (630, 628)]
HAFEN_BEZIRK = [(615, 425), (785, 412), (828, 440), (842, 540), (812, 549), (808, 606), (800, 622), (800, 640),
                (770, 648), (640, 650), (600, 664), (590, 560), (600, 470)]
FAHRRINNE = [(806, 606), (808, 548), (960, 830), (880, 860)]
# Meer (blau markiert im Grundriss): Es reicht bis an die Klippe unter der Ringmauer zwischen Hafen und Rondell, bis an
# die Hafeneinfahrt und südlich der Stadt bis an die Küste. Neben der Hafenmauer bleibt ein Felsstreifen.
# Meer im Osten und Norden um das Vorgebirge (wie im Referenzbild: die Burg auf drei Seiten vom Meer umgeben), in Welt-
# koordinaten: innen 20 bis 35 m vor der Ringmauer (dort fällt die Klippe ins Meer), außen mit Abstand zum Weg nach
# Gravemarch und zur Nordstraße. Wird zwischen (1250, 425) und (1650, 620) in die Bucht eingesetzt.
MEER_NORD_WELT = [(40, -290), (-30, -300), (-80, -280), (-110, -245), (-125, -190), (-125, -130), (-115, -60),
                  (-110, 20), (-85, 90), (-60, 165),
                  (-130, 150), (-200, 100), (-240, 10), (-290, -150), (-250, -320), (-120, -400), (60, -410), (160, -360)]
BUCHT = [(813, 553), (845, 548), (870, 505), (950, 468), (1100, 436), (1250, 425), (1650, 620),
         (1720, 760), (1720, 950), (280, 950), (280, 760), (450, 748), (600, 735), (670, 712), (720, 682),
         (790, 660), (806, 642), (810, 610)]
_i_ = BUCHT.index((1250, 425)) + 1
BUCHT[_i_:_i_] = [tuple(round(v, 1) for v in plan(w)) for w in MEER_NORD_WELT]
# Wassertor (Hafentor): ein Kanal vom Becken bis an die Ringmauer; hinter dem Fallgitter geht es dunkel in den Berg zum
# Untergrundhafen (der kommt mit Höhlen im Gelände, Terrain3D)
KANAL = [(744, 455), (744, 410), (764, 410), (764, 455)]
# Mole vom Speicherkai (Molenpforte) zur ersten Insel, von dort Brücken zum Schwarzen Bergfried
MOLENPFORTE = (755, 645.5)


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



# ---------- Höhen der Wege ----------
_i = lambda linie, p: linie.index(g3(p))
WEG_VORBURG_HOEHEN = [H_VORBURG] * (len(WEG_VORBURG) - 2) + [H_VORBURG - 0.5, H_UNTEN]
WEG_BURG_HOEHEN = _steigend(WEG_BURG, {0: H_UNTEN, len(G3.WEG_UNTEN) - 1: H_RAMPENFUSS,
                                       _i(WEG_BURG, G3.RAMPENTOR): H_BURGHOF2, len(WEG_BURG) - 1: H_BURGHOF2})
WEG_ZWINGER_HOEHEN = _steigend(WEG_ZWINGER, {0: H_BURGHOF2, 1: H_BURGHOF2, len(WEG_ZWINGER) - 1: H_KERNHOF})
WEG_OBERBURG_HOEHEN = _steigend(WEG_OBERBURG, {0: H_KERNHOF, _i(WEG_OBERBURG, G3.OBERBURG_TOR): H_KERNHOF,
                                               _i(WEG_OBERBURG, G3.PALAS_ZWINGERTOR): H_ZWINGER_KERNBURG,
                                               _i(WEG_OBERBURG, G3.PALAS_TOR): H_KERNBURG, len(WEG_OBERBURG) - 1: H_KERNBURG})
WEG_DURCHGANG_HOEHEN = [H_KERNHOF] * len(WEG_DURCHGANG)
WEG_AUSSEN_HOEHEN = _steigend(WEG_AUSSEN, {0: H_BURGHOF2, _i(WEG_AUSSEN, (1036, 196)): H_KERNHOF,
                                           _i(WEG_AUSSEN, (1612, 565)): H_KERNHOF, len(WEG_AUSSEN) - 1: H_RAMPENFUSS})
WEG_PALASZWINGER_HOEHEN = [H_KERNHOF] + [H_ZWINGER_KERNBURG] * (len(WEG_PALASZWINGER) - 1)
# Die Wege im Burgbezirk und in den Höfen (die Gassen der Stadt stehen in STRASSEN)
BURGWEGE = [WEG_VORBURG, WEG_BURG, WEG_ZWINGER, WEG_OBERBURG, WEG_DURCHGANG, WEG_AUSSEN, WEG_PALASZWINGER]
ZWINGER_FLANKE = [3.0, 4.5]    # Wege zwischen Mauern: 6 m breit eben


HOF_FELSHANG = 2.5        # Meter: das Gelände fällt außen an den Höfen steil ab; den Abhang bildet der Felssockel (teil_felsen.py)


def plan_json():
    # Die Burghöfe stehen auf Felsterrassen: Der Rand (Meter) ist schmal, darunter bricht der Fels steil ab.
    zonen = [
        {"name": "Vorburg", "punkte": welt_liste(VORBURG), "hoehe": H_VORBURG, "rand": HOF_FELSHANG},
        {"name": "Mittelburg", "punkte": welt_liste(MITTELBURG), "hoehe": H_BURGHOF2, "rand": HOF_FELSHANG},
        # Der Zwinger der Oberburg steigt mit seinen Wegen: Höhe des nächsten Wegpunkts
        {"name": "Zwinger der Oberburg", "punkte": welt_liste(ZWINGER_III), "hoehe": H_KERNHOF, "rand": 3.0,
         "weg": welt_liste(WEG_ZWINGER + WEG_DURCHGANG + WEG_AUSSEN[:_i(WEG_AUSSEN, (1036, 196)) + 1]),
         "weg_hoehen": WEG_ZWINGER_HOEHEN + WEG_DURCHGANG_HOEHEN + WEG_AUSSEN_HOEHEN[:_i(WEG_AUSSEN, (1036, 196)) + 1]},
        {"name": "Oberburg", "punkte": welt_liste(OBERBURG), "hoehe": H_KERNHOF, "rand": HOF_FELSHANG},
        {"name": "Zwinger des Palas", "punkte": welt_liste(ZWINGER_KERNBURG), "hoehe": H_ZWINGER_KERNBURG, "rand": 3.0},
        {"name": "Palas", "punkte": welt_liste(PALAS_HOF), "hoehe": H_KERNBURG, "rand": HOF_FELSHANG},
    ]
    return {
        "_hinweis": "Erzeugt von werkzeuge/bau/plan_drachenstein.py aus dem Grundriss. Nicht von Hand ändern.",
        "zonen": zonen,                                  # in dieser Reihenfolge eingeebnet; spätere gewinnen
        "ring": welt_liste(BURGBEZIRK),                  # Burgbezirk: Grund auf der Höhe des nächsten Burgwegs
        "stadt": welt_liste(STADT),
        "hafen": welt_liste(HAFEN_BEZIRK),
        "grat": welt_liste([VORBURG[0], MITTE_MITTELBURG, MITTE_OBERBURG, MITTE_PALAS]),
        "stadt_hoehe": [welt((150, 430))[1], H_STADT_WEST, welt((600, 470))[1], H_STADT_OST],
        # Die Stadt steigt zur Vorburg hin an (dort führen die Gassen im Bogen hinauf zum Vorburgtor)
        "stadt_anstieg": {"punkte": welt_liste(VORBURG), "hoehe": H_VORBURG - 0.5, "weite": 45.0},
        "hafen_hoehe": H_HAFEN,
        # [Linienzug, Höhen, folgt der Burgbezirk diesem Weg?, Flanke]
        "burgwege": [[welt_liste(l), h, r] + rest for l, h, r, *rest in [
            (WEG_VORBURG, WEG_VORBURG_HOEHEN, False, ZWINGER_FLANKE),
            (WEG_BURG, WEG_BURG_HOEHEN, True),
            (WEG_ZWINGER, WEG_ZWINGER_HOEHEN, False, ZWINGER_FLANKE),
            (WEG_OBERBURG, WEG_OBERBURG_HOEHEN, False, ZWINGER_FLANKE),
            (WEG_DURCHGANG, WEG_DURCHGANG_HOEHEN, False, ZWINGER_FLANKE),
            (WEG_AUSSEN, WEG_AUSSEN_HOEHEN, True, ZWINGER_FLANKE),
            (WEG_PALASZWINGER, WEG_PALASZWINGER_HOEHEN, False, ZWINGER_FLANKE)]],
        "hafen_becken": welt_liste(HAFENBECKEN),
        "fahrrinne": welt_liste(FAHRRINNE),
        "kanal": welt_liste(KANAL),
        "bucht": welt_liste(BUCHT),
        "grat_hoehen": [H_VORBURG, H_KERNBURG],
        "grat_abfall": 3.0,
        "abfall": 9.0,               # außen an der Ringmauer bricht der Fels fast senkrecht ab
        "zwinger_hoehen": [-12.0, -2.0],
        "strassen": [welt_liste(s) for s in STRASSEN],
        "markt": welt_liste(MARKTPLATZ),
        "ebene": H_EBENE,
        # eben: der Hof (±halb) und der Weg vom Tor bis zur Straße (lokal z 0 … weg); rand: Übergang ins Gelände
        "vorwerk": {"mitte": list(VORWERK), "dreh": VORWERK_DREH, "hoehe": H_VORWERK, "halb": 38.0, "weg": 66.0,
                    "rand": 24.0},
        # Landstraßen vor den Toren (Weltpunkte, an die Straßen im Geländeerzeuger angeschlossen)
        "nordtor": welt_liste(WEG_NORDTOR[:3]),
        "suedtor": welt_liste(WEG_SUEDTOR[:3]),
    }


if __name__ == "__main__":
    ziel = Path(__file__).resolve().parents[2] / "daten" / "drachenstein_plan.json"
    ziel.write_text(json.dumps(plan_json(), ensure_ascii=False, indent=1), encoding="utf-8")
    print("geschrieben:", ziel)
    for name, p in [("Oberburg", MITTE_OBERBURG), ("Palas", MITTE_PALAS), ("Vorburg", MITTE_VORBURG),
                    ("Mittelburg", MITTE_MITTELBURG), ("Markt", MARKT_MITTE), ("Nordtor", TORE["Nordtor"]),
                    ("Südtor", TORE["Südtor"]), ("Hafentor", TORE["Hafentor"])]:
        print(f"  {name:16s} {welt(p)}")
