"""Baut szenen/welt/region_drachenstein.tscn. Aufruf: python3 werkzeuge/bau/region_drachenstein.py"""
from pathlib import Path
exec(open(Path(__file__).resolve().parent / "grundlage.py", encoding="utf-8").read())
lade_hoehen("gelaende")

grundgeruest("gelaende", region_eigenschaften="grenze_min = Vector2(-880, -680)\ngrenze_max = Vector2(1280, 730)",
             wasser_groesse=(2800, 1800),
             # Loch im Steilhang hinter dem Wassertor (Rasterpunkte am Fuß, x 92,5): Dort führt der Gang unter dem Zwinger
             # in den Untergrundhafen (teil_stadt.py); die Ringmauer und die Kanalmauern decken die Ränder.
             gelaende_extra="\nloecher = PackedVector4Array(91.5, -13.5, 93.5, -4.0)")

# ---------- Burgfeste Drachenstein ----------
import sys
sys.path.insert(0, str(BAU))
import plan_drachenstein as PD
HOF_Y = PD.HOF_Y
# Der Hof aus Akt I ist das Ordensvorwerk vor der Stadt am Küstenweg (nicht in der Burg)
_vwa = math.radians(PD.VORWERK_DREH)
H_VW = PD.H_VORWERK


def VW(lx, lz):
    """Punkt im Hof aus Akt I (lokal wie in burg_hof.tscn) → Welt (x, z)."""
    return (round(PD.VORWERK[0] + lx * math.cos(_vwa) + lz * math.sin(_vwa), 2),
            round(PD.VORWERK[1] - lx * math.sin(_vwa) + lz * math.cos(_vwa), 2))


N("BurgHof", None, ".", T(PD.VORWERK[0], H_VW, PD.VORWERK[1], PD.VORWERK_DREH), instanz="3_hof")
BF_X_NEU, BF_Z_NEU = 500, 100   # Schwarzer Bergfried (werkzeuge/gelaende_erzeuger.gd, BERGFRIED)
teil("teil_drachenstein.py")
teil("teil_felsen.py")   # 3D-Felsen an den Klippen
teil("teil_natur.py")    # Stämme, Pilze, Moos, Sträucher, Farne um Drachenstein
# Gepflastert sind Gassen und Markt in der Stadt, die Kais und die Höfe der Burgen
gelaende_pflaster([STADT_UMRISS, WL(PD.HAFEN_BEZIRK)])   # die Burghöfe pflastert die Geländemaske (Blau)

# ---------- Mole und Brücken über die Inseln zum Schwarzen Bergfried ----------
# Von der Molenpforte am Speicherkai führt eine Mole westlich der Hafeneinfahrt zur ersten Insel, von dort Brücken
# über die Inseln. Die Einfahrt und die Fahrrinne bleiben frei.
N("Bruecken", "Node3D", ".")
_bfw = math.atan2(95 - 135, 212 - 250)
_mole_a = W((755, 652))            # vor der Molenpforte
_mole_b = (300.0, -15.0)             # bis auf die erste Insel, dort beginnt die Brücke
box("Mole0", "Bruecken", round((_mole_a[0] + _mole_b[0]) / 2, 2), -19.0, round((_mole_a[1] + _mole_b[1]) / 2, 2),
    round(math.dist(_mole_a, _mole_b) + 6, 2), 2.4, 7, "Material_kai", gier=round(gier_zu(_mole_b[0] - _mole_a[0], _mole_b[1] - _mole_a[1]), 2))
punkte = [(300, -15), (382, 22), (462.4, 60.4),
          (round(BF_X_NEU + 20*math.cos(_bfw), 2), round(BF_Z_NEU + 20*math.sin(_bfw), 2))]
for i in range(len(punkte) - 1):
    (x1,z1),(x2,z2) = punkte[i], punkte[i+1]
    dx, dz = x2-x1, z2-z1
    laenge = math.hypot(dx, dz) + 6
    gier = -math.degrees(math.atan2(dz, dx))
    cx, cz = (x1+x2)/2, (z1+z2)/2
    pfad = f"Bruecken/Bruecke{i+1}"
    N(f"Bruecke{i+1}", "Node3D", "Bruecken", T(cx, -18.1, cz, gier))
    box("Deck", pfad, 0, 0, 0, round(laenge,2), 0.6, 5, "Material_holz")
    box("GelaenderNord", pfad, 0, 0.8, -2.4, round(laenge,2), 1.0, 0.25, "Material_holz")
    box("GelaenderSued", pfad, 0, 0.8, 2.4, round(laenge,2), 1.0, 0.25, "Material_holz")
    for k in range(max(1, int(laenge // 30))):
        box(f"Pfeiler{k}", pfad, round(-laenge / 2 + laenge * (k + 1) / (int(laenge // 30) + 1), 2), -7, 0, 3, 14, 4, "Material_mauer")

# ---------- Schwarzer Bergfried ----------
teil("teil_bergfried.py")

# ---------- Gravemarch nach dem Grundriss ----------
teil("teil_gravemarch.py")

# ---------- Gravecrest nach dem Grundriss ----------
teil("teil_gravecrest.py")

# ---------- Signaltürme an der Küste ----------
N("Signaltuerme", "Node3D", ".", '''script = ExtResource("11_auf_gelaende")
gelaende = NodePath("../Gelaende")''', extra='node_paths=PackedStringArray("gelaende")')
for i,(x,z) in enumerate([(115,-418),(170,380)]):   # der erste auf der Landzunge am Ostmeer
    N(f"Signalturm{i+1}", "Node3D", "Signaltuerme", T(x,0,z))
    box("Turm", f"Signaltuerme/Signalturm{i+1}", 0, 5, 0, 4, 14, 4, "Material_mauer")
    zyl("Feuerbecken", f"Signaltuerme/Signalturm{i+1}", 0, 12.4, 0, 1.6, 0.8, "Material_feuer", 8, False)
    signalfeuer(f"Signaltuerme/Signalturm{i+1}", 12.8)

# ---------- Orte ----------
N("Orte", "Node3D", ".")


def ort_kasten(poly, h):
    """Bereich eines Hofs: Mitte (x, y, z) und Größe (x, y, z) um seinen Umriss in der Welt."""
    w_ = WL(poly)
    xs_, zs_ = [q[0] for q in w_], [q[1] for q in w_]
    return ((min(xs_) + max(xs_)) / 2, h + 3, (min(zs_) + max(zs_)) / 2, max(xs_) - min(xs_) - 4, 16, max(zs_) - min(zs_) - 4)


WL = PD.welt_liste
_orte = [
    ("Burgfeste Drachenstein", "Drei Burgen, ein Stein, eine Feste.", 60, 10, 20, 520, 140, 700),
    *[(name_, text_, *ort_kasten(poly_, h_)) for name_, text_, poly_, h_ in [
        ("Palas · Drachenhorst", "Bergfried, Palas und Drachenkapelle.", PD.PALAS_HOF, PD.H_KERNBURG),
        ("Oberburg · Wolfsfeste", "Die Schwelle des Ordens.", PD.OBERBURG, PD.H_KERNHOF),
        ("Mittelburg", "Vierzehntes Jahrhundert.", PD.MITTELBURG, PD.H_BURGHOF2),
        ("Vorburg", "Der älteste Teil der Feste.", PD.VORBURG, PD.H_VORBURG)]],
    ("Festungsstadt", "St. Marien, Markt und Fachwerkhäuser.", 140, -15, 160, 150, 16, 230),
    ("Drachenhafen", "Hafen am Wächtermeer", 150, -17, -5, 110, 12, 110),
    ("Untergrundhafen", "Unter dem Zwinger, im Fels der Feste.", 75, -14, -9.5, 26, 8, 26),
    ("Schwarzer Bergfried", "Gründungsarchiv des Ordens", 485, -10, 85, 110, 80, 100),
    ("Gravemarch", "Nicht das Land schützt Gravemarch, sondern die Zeit, die sie gebaut hat.", -600, -5, -205, 240, 60, 240),
    ("Gravecrest", "Disziplin. Wissen. Ordnung. Sorrow bewahrt.", -694, 72, -366, 140, 40, 46),
]
for i,(name, untertitel, x,y,z, sx,sy,sz) in enumerate(_orte):
    bereich(f"Form_ort{i+1}", sx, sy, sz)
    N(f"Ort{i+1}", "Area3D", "Orte", f'''{T(x,y,z)}
script = ExtResource("13_ort")
ortsname = "{name}"
untertitel = "{untertitel}"''')
    N("Form", "CollisionShape3D", f"Orte/Ort{i+1}", f'shape = SubResource("Form_ort{i+1}")')

# ---------- Bewuchs: Wälder, Büsche, Gras; Stadt, Burgen und Hafen bleiben frei ----------
bewuchs(frei_vielecke=[STADT_UMRISS, WL(PD.HAFEN_BEZIRK), WL(PD.BURGHOF2), WL(PD.BURGHOF3), WL(PD.KERNBURG),
                       WL(PD.VORBURG), WL(PD.ZWINGER_KERNBURG), WL(PD.ZWINGER_III), WL(PD.BURGBEZIRK), WL(PD.RINGMAUER)],   # im Burgbezirk Felsgrund
        frei_rechtecke=[(BF_X_NEU, BF_Z_NEU, 90, 90), (-600, -205, 240, 240), (-694, -366, 150, 60)], wald_anteil=0.24,
        feste_baeume=STADTBAEUME)   # Hausbäume in den Höfen der Stadt (teil_stadt.py)

# ---------- Personen der Region ----------
N("Personen", "Node3D", ".")
for k_, (x_, y_, z_, g_) in enumerate(MAUERWACHEN):
    person(f"Mauerwache{k_}", "Personen", x_, y_, z_, ["Mauerwache Rolf Behn", "Mauerwache Ida Kern", "Mauerwache Hagen Lutz",
           "Mauerwache Wenke Ohm", "Mauerwache Arnd Fels", "Mauerwache Liv Sander", "Mauerwache Jost Brandt", "Mauerwache Ebba Holm"][k_ % 8],
           "mauerwache", 1, "0.27, 0.24, 0.2, 1", gier=g_)
_bw = polar(23.5, BF_WINKEL + 14, -17.8)
person("Bergwaechter", "Personen", BF_X + _bw[0], -17.8, BF_Z + _bw[2], "Bergwächter Tjark Halm", "bergwaechter", 2, "0.05, 0.05, 0.06, 1", gier=round(-BF_WINKEL - 90, 1))
_lotsin = W((705, 434))   # am Nordkai, nah am Becken, mit Abstand zu den Fischern
person("Lotsin", "Personen", _lotsin[0], -17.6, _lotsin[1], "Lotsin Wenna Kroll", "lotsin", 0, "0.2, 0.24, 0.3, 1", gier=-90)
person("TorwacheGravemarch", "Personen", round(ESME[0], 2), round(ESME[1], 2), round(ESME[2], 2), "Wächterin Esme Rauh", "torwache_gravemarch", 1, "0.15, 0.15, 0.16, 1", gier=round(math.degrees(math.atan2(-nx, -nz)), 1))
person("ArchivarinGravemarch", "Personen", *ARCHIVARIN, "Archivarin Ysolde Brack", "archivarin_gravemarch", 2, "0.3, 0.26, 0.2, 1", gier=180)
person("TorwacheGravecrest", "Personen", -608, 70, -359, "Kammbrecher Ulf Haskel", "torwache_gravecrest", 2, "0.2, 0.2, 0.22, 1", gier=-90)
N("PersonenAmBoden", "Node3D", "Personen", '''script = ExtResource("11_auf_gelaende")
gelaende = NodePath("../../Gelaende")''', extra='node_paths=PackedStringArray("gelaende")')
# Bürgschaft (Regel 10): Nach dem Haupteid wartet ein Bewerber an der Schwelle. Bürgt man für ihn, steht er
# im Hof und fragt einen Knappen nach den Fluchtgängen aus. Wer das belauscht, kann ihn melden.
person("KerrinVorTor", "Personen", *(lambda q: (q[0], H_VW, q[1]))(VW(-4, 40)), "Bewerber Kerrin Fahl", "bewerber_kerrin", 0, "0.4, 0.33, 0.25, 1", gier=180 + PD.VORWERK_DREH,
       sichtbar_wenn="eid_waechter,!kerrin_entschieden")
person("KerrinImHof", "Personen", *(lambda q: (q[0], H_VW, q[1]))(VW(22, 0)), "Anwärter Kerrin Fahl", "bewerber_kerrin", 0, "0.27, 0.24, 0.2, 1", gier=PD.VORWERK_DREH,
       sichtbar_wenn="kerrin_anwaerter,!kerrin_gefasst")
person("TiloBrenn", "Personen", *(lambda q: (q[0], H_VW, q[1]))(VW(22, 2.2)), "Knappe Tilo Brenn", "knappe_tilo", 1, "0.27, 0.24, 0.2, 1", gier=PD.VORWERK_DREH,
       sichtbar_wenn="kerrin_anwaerter,!kerrin_gefasst")
gespraech("KerrinUndTilo", "KerrinImHof", "TiloBrenn", [
    ("a", "Du warst doch schon im Bergfried. Stimmt es, dass es unter Ashenveil Gänge bis in die Sümpfe gibt?"),
    ("b", "Woher soll ich das wissen? Und warum willst du das wissen?"),
    ("a", "Nur so. Und hier in Drachenstein? Unter der Oberer Burg, wo kommt man da heraus?"),
    ("b", "Frag den Kammerhüter, wenn du es so genau wissen willst."),
], "kerrin_anwaerter,!kerrin_gefasst", "beobachtung_kerrin",
   "Belauscht im Hof: Kerrin Fahl, für den du bürgst, fragt den Knappen Tilo Brenn nach den Fluchtgängen. Ein Warnzeichen.",
   (lambda q: (q[0], H_VW + 1, q[1]))(VW(22, 1.1)))
# Reiterin aus Ashenveil innen am Südtor (neben der Gasse): nimmt Wächter über den Küstenweg mit
REITERIN = W(PD.g3((757, 950)))   # neben dem Weg, das Pferd weiter vom Weg weg
person("Reiterin", "Personen/PersonenAmBoden", REITERIN[0], 0, REITERIN[1], "Reiterin Ilka Sand", "reiterin_ashenveil", 2, "0.25, 0.22, 0.18, 1", gier=-54)
pferd("PferdReiterin", "Personen", round(REITERIN[0] - 3.5, 2), round(H(REITERIN[0] - 3.5, REITERIN[1] + 2), 2), round(REITERIN[1] + 2, 2), 36)
# Bei Alarm leeren sich die Märkte (Konzept: Eine Welt, die kippen kann).
_grete = W((483, 496))
person("Haendlerin", "Personen/PersonenAmBoden", _grete[0], 0, _grete[1], "Händlerin Grete Lohm", "haendlerin", 0, "0.45, 0.3, 0.2, 1", sichtbar_wenn="alarm<2")
teil("teil_stadtleben.py")


# ---------- Sprungpunkte (Entwicklermenü, F10) ----------
N("Sprungpunkte", "Node3D", ".")
_bf = lambda r, w, y: (round(BF_X + r*math.cos(math.radians(BF_WINKEL + w)), 1), y, round(BF_Z + r*math.sin(math.radians(BF_WINKEL + w)), 1))
_sp = lambda pp, dy=0.5: (lambda p: (round(p[0], 1), round(H(*p) + dy, 1), round(p[1], 1)))(W(pp))
for name, x, y, z in [("Ordensvorwerk, Hof", *(lambda q: (q[0], H_VW + 0.5, q[1]))(VW(0, 20))), ("Ordensvorwerk, vor dem Tor", *(lambda q: (q[0], H_VW + 0.5, q[1]))(VW(0, 46))),
                      ("Oberburg", *_sp(PD.HEILSTUBE)), ("Palas", *_sp(PD.g3((1420, 345)))), ("Übungsplatz", round(UEB[0] + 4, 1), PD.H_KERNBURG + 0.5, round(UEB[1], 1)),
                      ("Mittelburg", *_sp(PD.g3((850, 360)))), ("Vorburg", *_sp(PD.g3((620, 400)))), ("Fuß der Rampe", *_sp(PD.g3((1036, 568)))),
                      ("Nordtor", *_sp(PD.g3((545, 250)))), ("Südtor", *_sp(PD.g3((745, 960)))),
                      ("Wassertor", *(lambda p: (round(p[0], 1), -17.3, round(p[1], 1)))(W((736, 428)))), ("Marktplatz", *_sp((512, 530))), ("St. Marien", *_sp(PD.g3((560, 700)))),
                      ("Drachenkai", _lotsin[0] + 2, -17.3, _lotsin[1]), ("Untergrundhafen", 72.0, -17.2, -2.0), ("Bergfried, Tor", *_bf(24, 0, -17.4)),
                      ("Bergfried, Schwelle (Ebene 0)", *_bf(8.5, 4, -17.4)), ("Bergfried, Archive (Ebene 4)", *_bf(8.6, -53, 11.4)),
                      ("Bergfried, Dach", *_bf(8.9, 189, 50.6)), ("Gravemarch, Brückenpforte", round(ESME[0] - ux * 3, 1), round(ESME[1] + 0.5, 1), round(ESME[2] - uz * 3, 1)), ("Gravemarch, Burghof", -614, -3.5, -180),
                      ("Gravecrest, Zugbrücke", -605, 70.5, -362), ("Gravecrest, Unterer Hof", -663, 70.5, -368),
                      ("Gravecrest, Palas", -735, 70.5, -365.5)]:
    N(name.replace(",", "").replace(" ", "_").replace("(", "").replace(")", ""), "Marker3D", "Sprungpunkte", f'{T(x, y, z)}\nmetadata/anzeige = "{name}"')

# ---------- Ankunft per Schiff, Spieler und Oberfläche ----------
N("Ankuenfte", "Node3D", ".")
N("von_riverlock", "Marker3D", "Ankuenfte", T(round(_lotsin[0] + 3, 2), -17.5, round(_lotsin[1], 2), 90), extra='groups=["ankunft"]')
_ank = W(PD.g3((743, 935)))     # auf der Gasse vom Südtor, neben der Reiterin
N("von_ashenveil", "Marker3D", "Ankuenfte", T(round(_ank[0], 2), round(H(*_ank) + 0.2, 2), round(_ank[1], 2), -53.4), extra='groups=["ankunft"]')
ankunft("von_nordstrasse", 112, -608, 145)
ankunft("von_kuestenweg", 152, 640, 10)
ankunft("heilstube", *W(PD.HEILSTUBE))
schild("SchildNordstrasse", ".", 160, round(H(160, -555) + 3, 2), -555, "Nordstraße → Riverlock 225 km", 48)
schild("SchildKuestenweg", ".", 158, round(H(158, 600) + 3, 2), 600, "Küstenweg → Ashenveil 70 km", 48)
# Am Ende der Pässe beginnen die Landstraßen
uebergang("ZurNordstrasse", (88, H(88, -652) + 2, -652), (30, 40, 16), "nordstrasse", "von_drachenstein",
          (112, round(H(112, -608) + 0.5, 2), -608))
uebergang("ZumKuestenweg", (161, H(161, 700) + 2, 700), (30, 40, 20), "kuestenweg", "von_drachenstein",
          (152, round(H(152, 640) + 0.5, 2), 640))
spieler_und_oberflaeche(*(lambda q: (q[0], H_VW, q[1]))(VW(0, 46)))

# Person "kordel": person.tscn nutzt KEINE=0, SCHWARZ=1, GRAU=2, GOLDEN=3
schreibe("region_drachenstein.tscn")
