"""Grundriss der Burgfeste Drachenstein, dritte Fassung (docs/bilder/grundriss-drachenstein-3.webp, 2000 x 1116),
digitalisiert in Bildpunkten dieses Plans (x nach rechts, y nach unten = Plan-Süd).

plan_drachenstein.py rechnet diese Punkte mit einer Ähnlichkeitsabbildung (Maßstab, kleine Drehung, Verschiebung) in
die Planpunkte der zweiten Fassung um, auf die Welt und Gelände abgestimmt sind. So bleiben Meer, Straßen und die
übrigen Orte der Region an ihrem Platz.

Wege (vom Spieler eingezeichnet, blau Hauptweg, rot Nebenwege):
  blau: vom Hafen durch die Stadt nach Nordwesten, an der Westseite der Vorburg hinauf und unter ihrer Südmauer zum
        Vorburgtor; durch das Tor in den Burgbezirk: hinauf über die Treppe in die Vorburg oder an der Mauer entlang
        nach Osten zum Fuß der Rampe; die Rampe hinauf durch das Rampentor in die Mittelburg, gleich rechts durch das
        Zwingertor in den Zwinger an der Südseite der Oberburg, an dessen Ende nach Norden in den Durchgang zwischen
        Oberburg und Palas: links in die Oberburg, rechts in den Palas.
  rot:  das Nordtor in der Ringmauer (Straße nach Gravemarch), das Südtor der Stadt, der Zwingerweg um die Oberburg,
        der Zwinger zwischen den beiden Mauerringen des Palas und der äußere Weg um den Palas bis zum Hafentor.
"""

# ---------- Burghöfe (Umriss der Hofmauer) ----------
VORBURG = [(537, 457), (505, 400), (507, 377), (512, 330), (525, 318), (580, 311), (637, 295), (672, 279), (722, 274),
           (743, 283), (738, 330), (737, 362), (700, 362), (700, 412), (706, 455), (690, 470), (683, 483),
           (558, 467)]
VORBURG_TUERME = [((502, 397), 15), ((537, 457), 23)]          # Rundtürme im Westen
VORBURG_TOR = ((697, 480), 20)                                  # Rundturm am Tor der Vorburg
VORBURGTOR = (668, 482)                                          # in der Südmauer, von der Stadt in die Vorburg
VORBURG_OSTTOR = (700, 395)                                      # aus dem Hof hinab in den Burgbezirk
TREPPE_VORBURG = [(684, 407), (645, 410)]                        # vom Weg am Tor hinauf in den Hof

MITTELBURG = [(740, 287), (763, 272), (887, 232), (907, 220), (932, 268), (938, 330), (946, 400), (948, 440),
              (880, 455), (787, 432), (740, 403), (733, 350)]
MITTELBURG_ECKTURM = ((740, 287), 20)                          # Rundturm zwischen Vorburg und Mittelburg
MITTELBURG_NORDTURM = (907, 217)                                # eckiger Turm an der Nordostecke
RAMPENTOR = (921, 446)                                          # an der Südostecke, oben an der Rampe
ZWINGERTOR = (947, 422)                                         # gleich rechts: in den Zwinger der Oberburg

OBERBURG = [(967, 330), (1025, 235), (1045, 230), (1115, 237), (1175, 255), (1215, 265), (1240, 315), (1247, 430),
            (1180, 437), (1105, 435), (1050, 420), (1020, 400), (980, 375)]
OBERBURG_TORTURM = ((1238, 280), 27)                            # offener Vierkantturm an der Nordostecke
OBERBURG_TOR = (1244, 357)                                      # Torbau an der Ostmauer, vom Durchgang
OBERBURG_SUEDTOR = (1235, 433)                                  # vom Ostende des Zwingers (gebogene Stiege)
OBERBURG_TUERME = [((1117, 422), 12), ((1184, 437), 9), ((1040, 217), 7)]
# Zwingermauer der Oberburg: West- und Südseite, vom Nordturm der Mittelburg bis an den Durchgang zum Palas
OBERBURG_ZWINGER = [(985, 243), (950, 290), (940, 355), (960, 410), (967, 422)]
ZWINGER_SUED = [(935, 445), (1055, 490), (1160, 480), (1172, 505), (1230, 515), (1265, 505)]
ZWINGER_TREPPE = (1203, 482)                                    # die gebogene Stiege am Ostende des Zwingers
DURCHGANG = [(1250, 500), (1258, 430), (1262, 360), (1268, 300)]  # zwischen Oberburg und Palas nach Norden

PALAS_HOF = [(1300, 355), (1305, 305), (1318, 275), (1360, 240), (1400, 225), (1462, 192), (1520, 172), (1600, 212),
             (1648, 272), (1642, 340), (1620, 425), (1560, 437), (1500, 445), (1385, 467), (1325, 415)]
PALAS_TOR = (1302, 345)                                         # Westtor, vom Durchgang
PALAS_ZWINGERTOR = (1272, 350)                                  # gegenüber im engen Zwinger
PALAS_ZWINGERPFORTE = (1284, 440)                               # vom Südende des Durchgangs in den engen Zwinger
BERGFRIED = ((1584, 217), 60, 29.5)                               # Mitte, Seite, Drehung (Grad)
PALAS_BAU = [(1450, 205), (1640, 300)]                          # langer Palas an der Nordostmauer (von, bis)
PALAS_TUERME = [((1450, 225), 12), ((1652, 280), 12), ((1617, 420), 10)]
PALAS_ECKBAU = ((1608, 298), 40, 30)                            # Vierkantturm am Südostende des Palas
# Enger Zwinger: zweiter Mauerring dicht um den Palashof, mit Rundtürmen
PALAS_ZWINGER = [(1268, 410), (1272, 300), (1300, 240), (1360, 190), (1460, 150), (1530, 130), (1620, 160),
                 (1690, 210), (1720, 290), (1700, 380), (1660, 450), (1610, 480), (1520, 490), (1390, 505),
                 (1300, 470)]
PALAS_ZWINGER_TUERME = [((1707, 210), 15), ((1730, 340), 12), ((1615, 490), 12)]

# ---------- Ringmauer, Stadtmauer, Burgbezirk ----------
# Ringmauer im Norden und Osten: vom Torhaus im Nordwesten über das Nordtor, dann an die Burg (die Mauern der Vorburg
# und der Mittelburg sind dort die Außenmauer), hinter Oberburg und Palas weiter bis zur Bastion im Südosten
RING_NORD = [(385, 275), (420, 258), (530, 212), (575, 212), (735, 212), (715, 235), (700, 272)]
RING_OST = [(907, 217), (1000, 165), (1040, 135), (1207, 205), (1250, 160), (1385, 95), (1415, 102), (1705, 115),
            (1725, 110), (1838, 168), (1830, 260), (1795, 500), (1765, 560), (1705, 592), (1620, 615), (1500, 630),
            (1400, 635), (1300, 632), (1170, 628), (1155, 620)]
RING_TUERME = [((735, 212), 22), ((1040, 135), 12), ((1207, 205), 22), ((1385, 95), 18),
               ((1725, 110), 15), ((1838, 168), 25), ((1765, 560), 30)]
NORDTOR = (552, 212)                                            # Torhaus in der Ringmauer (rot: nach Gravemarch)
TORHAUS_NW = ((385, 275), 40)                                    # eckiges Torhaus über der Mauer
# Mauer zwischen Stadt und Burgbezirk: vom Vorburgtor bis an das Hafentor
STADT_BURG_MAUER = [(697, 480), (723, 487), (1060, 595)]
HAFENTOR = [(1060, 595), (1155, 620)]                            # Torhaus mit zwei Vierkanttürmen
# Stadtmauer: vom Torhaus im Nordwesten nach Süden um die Stadt bis an den Hafen
STADTMAUER = [(385, 275), (280, 370), (240, 470), (190, 505), (250, 520), (250, 770), (300, 900), (375, 920),
              (410, 940), (600, 1000), (800, 1000), (840, 1025), (875, 995)]
STADT_TUERME = [((190, 505), 30), ((840, 1025), 35)]
TORHAUS_SW = ((375, 920), 40)
SUEDTOR = (765, 1000)                                            # rot: Südtor der Stadt

# ---------- Hafen ----------
HAFENBECKEN = [(850, 650), (1060, 640), (1190, 650), (1200, 810), (1230, 840), (1180, 900), (1060, 920),
               (870, 930), (845, 900)]
HAFEN_TUERME = [((1240, 820), 25), ((1110, 945), 25)]
SPEICHER = ((965, 950), 190, 40, 0)                              # Mitte, Länge, Breite, Drehung

# ---------- Bauten in den Höfen: (Mitte, Länge, Breite, Richtung der Länge in Grad im Bild) ----------
def _bau(a, b, breite):
    """Bau von a nach b (Längsachse) mit der Breite."""
    import math
    return (((a[0] + b[0]) / 2, (a[1] + b[1]) / 2), math.dist(a, b), breite, math.degrees(math.atan2(b[1] - a[1], b[0] - a[0])))


VORBURG_BAUTEN = [_bau((523, 322), (509, 392), 40), _bau((520, 396), (543, 440), 30),       # Westflügel zwischen den Türmen
                  _bau((550, 333), (578, 330), 30), _bau((578, 326), (645, 310), 42), _bau((645, 304), (673, 293), 28),
                  _bau((675, 290), (718, 285), 32),                                          # Nordflügel
                  _bau((715, 326), (715, 362), 44),                                          # Ostbau (Tür nach Westen)
                  _bau((562, 453), (596, 456), 26), _bau((610, 460), (650, 462), 26)]        # an der Südmauer
MITTELBURG_BAUTEN = [_bau((750, 320), (775, 335), 30), _bau((770, 300), (830, 285), 34), _bau((830, 278), (905, 255), 44),
                     _bau((905, 250), (930, 245), 30),                                       # Nordflügel
                     _bau((757, 345), (762, 380), 34), _bau((768, 390), (800, 415), 34), _bau((805, 420), (860, 428), 34),
                     _bau((862, 432), (900, 440), 36)]                                        # gebogener Südflügel
OBERBURG_BAUTEN = [_bau((975, 325), (1025, 245), 32), _bau((1030, 248), (1112, 250), 30), _bau((1115, 258), (1172, 270), 36),
                   _bau((1175, 275), (1212, 285), 30),                                       # Winkelbau im Nordwesten, Nordflügel
                   _bau((1012, 380), (1040, 392), 26),                                       # kleines Haus im Südwesten
                   _bau((1072, 418), (1108, 420), 24), _bau((1130, 420), (1175, 422), 22), _bau((1197, 417), (1222, 417), 24)]
PALAS_BAUTEN = [_bau((1365, 255), (1430, 235), 40),                                          # Nordwestflügel
                _bau((1318, 300), (1340, 275), 32), _bau((1316, 364), (1320, 402), 30),          # Westflügel (Burgküche südlich des Tors)
                _bau((1335, 395), (1395, 445), 44),                                          # Drachenkapelle im Südwesten
                _bau((1410, 450), (1465, 445), 22), _bau((1470, 440), (1535, 430), 26),          # Südflügel
                _bau((1590, 335), (1600, 410), 34),                                          # Zeughaus im Osten
                _bau((1311, 302), (1313, 330), 30)]                                          # Westflügel nördlich des Tors
PALAS_LANG = _bau((1470, 210), (1585, 275), 42)                                              # der Palas

# ---------- Wege (aus der Zeichnung des Spielers, geglättet) ----------
# blau: vom Kai am Hafen über den Marktplatz (seine Wege stehen in teil_stadtleben.py) und durch die Stadt, im Bogen
# um die Vorburg hinauf zum Vorburgtor
WEG_HAFEN = [(828, 750), (859, 765), (905, 772)]
WEG_STADT = [(640, 735), (628, 728), (572, 716), (515, 694), (466, 670),
             (430, 648), (404, 611), (385, 560), (374, 523), (373, 480), (380, 420), (403, 363), (430, 325), (460, 304),
             (480, 316), (468, 350), (456, 400), (452, 440), (470, 466), (515, 495), (560, 503), (604, 496), (640, 494),
             (665, 497), VORBURGTOR, (671, 468), (672, 458)]
# blau: durch den Hof der Vorburg, zum Osttor hinaus und auf dem gemauerten Weg hinab an den Fuß der Burgmauern
WEG_VORBURG = [(672, 458), (675, 425), (687, 397), VORBURG_OSTTOR, (713, 398), (721, 428), (735, 465), (756, 483)]
# blau: unten an der Stadtmauer entlang bis an den Fuß der Rampe, die Rampe hinauf durch das Rampentor in die Mittelburg
WEG_UNTEN = [(756, 483), (804, 497), (860, 506), (908, 522), (955, 541), (1004, 560), (1036, 568)]
WEG_RAMPE = [(1036, 568), (1040, 548), (1013, 530), (965, 498), (940, 478), (925, 461), RAMPENTOR, (918, 431), (930, 423)]
# blau: gleich rechts durch das Zwingertor, im Zwinger an der Südseite der Oberburg hinauf bis an ihr Ostende
WEG_ZWINGER = [(930, 423), ZWINGERTOR, (962, 423), (1000, 430), (1060, 455), (1124, 459), (1160, 460), (1195, 474),
               (1232, 489)]
# blau: über die gebogene Stiege durch das Südtor in die Oberburg; quer durch den Hof, zum Osttor hinaus und über den
# Durchgang durch beide Tore in den Palas
WEG_OBERBURG = [(1232, 489), (1236, 455), OBERBURG_SUEDTOR, (1233, 415), (1222, 380), (1228, 358), OBERBURG_TOR,
                (1260, 355), PALAS_ZWINGERTOR, (1287, 347), PALAS_TOR, (1330, 347), (1400, 345)]
# der Durchgang zwischen Oberburg und Palas, vom Ostende des Zwingers nach Norden
WEG_DURCHGANG = [(1232, 489), (1252, 462), (1258, 410), (1260, 355), (1262, 300), (1262, 262)]
# rot: Zwingerweg um die Oberburg (West- und Nordseite) und außen um den Palas, im Süden an der Mauer hinab zum Fuß
# der Rampe
WEG_AUSSEN = [(962, 423), (960, 400), (958, 370), (952, 330), (958, 295), (968, 275), (990, 245), (1010, 210),
              (1036, 196), (1050, 188), (1092, 196), (1125, 205), (1160, 219), (1200, 244), (1240, 245), (1262, 262),
              (1285, 215), (1300, 188), (1340, 162), (1390, 137), (1435, 131), (1500, 121), (1564, 125), (1627, 138),
              (1700, 168), (1750, 198), (1785, 237), (1804, 284), (1789, 332), (1760, 403), (1742, 453), (1707, 499),
              (1661, 533), (1612, 565), (1564, 595), (1500, 610), (1412, 612), (1316, 606), (1220, 600), (1162, 591),
              (1099, 571), (1036, 568)]
# rot: im engen Zwinger einmal um den Palas
WEG_PALASZWINGER = [(1252, 462), (1273, 446), PALAS_ZWINGERPFORTE, (1295, 434), (1327, 450), (1388, 486), (1451, 477),
                    (1524, 466), (1587, 456), (1640, 440), (1658, 398), (1675, 347), (1684, 284), (1660, 235),
                    (1635, 195), (1600, 172), (1575, 163), (1545, 158), (1483, 164), (1428, 187), (1379, 208),
                    (1338, 233), (1304, 268), (1288, 315), (1287, 347)]
# rot: vom Nordtor in die Stadt, vom Südtor in die Stadt
WEG_NORDTOR = [(548, 140), (550, 185), NORDTOR, (550, 240), (537, 265), (510, 280), (480, 298), (460, 304)]
WEG_SUEDTOR = [(774, 1045), SUEDTOR, (772, 975), (747, 948), (736, 900), (738, 840), (744, 812)]

# ---------- Gassen der Stadt (dazu WEG_STADT und die Wege von Nord- und Südtor) ----------
GASSEN = [
    [(395, 292), (345, 330), (312, 390), (300, 440), (305, 520), (312, 620), (322, 700), (350, 790), (420, 850),
     (520, 838), (620, 840), (700, 838), (738, 840)],                                          # außen an der Mauer
    [(312, 390), (380, 420)], [(305, 520), (374, 523)], [(312, 620), (404, 611)], [(350, 790), (430, 648)],
    [(470, 590), (560, 592), (660, 590), (730, 605), (790, 600)],                               # nördlich der Kirche
    [(466, 670), (470, 590), (470, 540), (515, 495)], [(512, 618), (470, 590)],               # zum Portal von St. Marien
    [(660, 590), (604, 496)], [(790, 600), (830, 560)],
    [(640, 492), (700, 505), (780, 525), (880, 560), (940, 580)],                               # an der Burgmauer
    [(815, 672), (840, 630), (880, 560)],                                                       # schräg zum Hafen
    [(560, 760), (628, 728)], [(560, 760), (520, 838)], [(625, 800), (628, 728)], [(625, 800), (700, 838)],
]
MARKT = [(610, 690), (775, 690), (778, 745), (612, 748)]
ST_MARIEN = _bau((524, 632), (612, 664), 50)                    # Langhaus, der Turm im Osten
ST_MARIEN_TURM = (628, 668)
