"""Baut szenen/welt/region_drachenstein.tscn. Aufruf: python3 werkzeuge/bau/region_drachenstein.py"""
from pathlib import Path
exec(open(Path(__file__).resolve().parent / "grundlage.py", encoding="utf-8").read())
lade_hoehen("gelaende")

grundgeruest("gelaende", region_eigenschaften="grenze_min = Vector2(-880, -680)\ngrenze_max = Vector2(1280, 730)",
             wasser_groesse=(2800, 1800),
             # Mängelliste M22: Hafenbecken, Kanal und Untergrundhafen mit trübem, ruhigem Wasser (Becken x 108–188, z −36–56)
             wasser_parameter="\nshader_parameter/hafen = Vector4(30, -40, 192, 60)",
             # Loch im Steilhang hinter dem Wassertor (Rasterpunkte am Fuß, x 92,5): Dort führt der Gang unter dem Zwinger
             # in den Untergrundhafen (teil_stadt.py); die Ringmauer und die Kanalmauern decken die Ränder.
             gelaende_extra="\nloecher = PackedVector4Array(91.5, -13.5, 93.5, -4.0)",
             # Mängelliste M1, M3: Fernmeer bis zum Horizont, halber Dunst, Himmel unter dem Horizont meerfarben
             nebel=0.00025, nebel_hoehe=0.0004, boden_farbe="0.1, 0.2, 0.23", wasser_ohne_schatten=True,
             fernmeer=(16000, -1350, -850, 1350, 850),
             # Schnee nur auf den hohen Gipfeln des Hauptkamms und der Fernberge (M5)
             gelaende_parameter="\nshader_parameter/schneegrenze = 190.0")
# Fernberge hinter dem Rand der Region (Mängelliste M5; Höhen aus werkzeuge/gelaende_erzeuger.gd)
E("Script", "res://szenen/welt/fernberge.gd", "47_fernberge")
N("Fernberge", "MeshInstance3D", ".", '''script = ExtResource("47_fernberge")
gelaende = NodePath("../Gelaende")''')

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
teil("teil_hofdetails.py")  # Regentonnen, Kräuterkübel, Schilder, Pranger, Bienenstand vor und in den Hofhäusern
teil("teil_unterwelt.py")   # Krypta, Zisterne, Gänge, Ruinen von Burg Sorrow (szenen/welt/unterwelt.gd)
teil("teil_felsen.py")   # 3D-Felsen an den Klippen
teil("teil_natur.py")    # Stämme, Pilze, Moos, Sträucher, Farne um Drachenstein
teil("teil_flur.py")     # Äcker, Getreide, Weiden und Wiesen an den Landstraßen (Mängelliste M6)
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
                       WL(PD.VORBURG), WL(PD.ZWINGER_KERNBURG), WL(PD.ZWINGER_III), WL(PD.BURGBEZIRK), WL(PD.RINGMAUER),
                       # das Ordensvorwerk (Hof aus Akt I, halbe Breite 38 m) mit 2 m Rand: dort wuchsen Bäume im Hof
                       [VW(-40, -40), VW(40, -40), VW(40, 40), VW(-40, 40)],
                       # der gepflasterte Weg vor dem Tor des Vorwerks (burg_hof.tscn, "Weg": 5 × 28 m, ohne Kollision)
                       [VW(-3.5, 30), VW(3.5, 30), VW(3.5, 60), VW(-3.5, 60)]],   # im Burgbezirk Felsgrund
        baumfrei_vielecke=FLUR_BLOECKE,   # Felder: Halme ja, Bäume nein
        frei_rechtecke=[(BF_X_NEU, BF_Z_NEU, 90, 90), (-600, -205, 240, 240), (-694, -366, 150, 60)], wald_anteil=0.24,
        zellgroesse=128.0, zell_laden_ab=150.0,
        # Bäume aus Fotoscans (Mängelliste M6/M20, werkzeuge/baum_laden.py)
        nadel_modelle='PackedStringArray("fir_tree_01", "fir_sapling_medium")',
        laub_modelle='PackedStringArray("island_tree_01", "tree_small_02", "island_tree_02")',
        busch_modell='"res://modelle/baeume/island_tree_02_busch/island_tree_02_busch_nah.gltf"', busch_groesse=0.7,
        feste_baeume=STADTBAEUME + BURGBAEUME)   # Hausbäume in den Höfen der Stadt (teil_stadt.py)

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
teil("teil_burgleben.py")   # Wachen auf den Mauern und an den Toren, Gesinde in den Höfen


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

# Freie Mauerenden an die Ecken benachbarter Ringe ziehen (durchgehende Wehrgänge)
_verb, _doppelt, _geteilt = mauern_verbinden()
for _v in _verb:
    print("Mauerende verbunden: %s -> %s" % (tuple(round(x, 2) for x in _v[3]), tuple(round(x, 2) for x in _v[4])))
print("Doppelmauern entfallen: %d, an der Flanke geteilt: %d" % (_doppelt, _geteilt))
# Mauerstummel, die als Pfeiler aus einem Turm ragen, sinken auf den tieferen Wehrgang (Tür unten im Turm)
for _t, _s, _alt, _neu, _riegel in stummel_an_tuermen():
    print("Stummel am Turm %s: Krone %.2f -> %.2f, %s" % (tuple(round(x, 2) for x in _t), _alt, _neu,
                                                       "verriegelte Tür (Turm steckt im Hang)" if _riegel else "Untergeschoss"))
    for j_, k_ in enumerate(knoten):
        m_ = re.search(r'\ntuerme = PackedFloat32Array\(([^)]*)\)', k_)
        if not m_:
            continue
        t_ = [float(v_) for v_ in m_.group(1).split(",") if v_.strip()]
        r_ = [t_[i_ + 4] for i_ in range(0, len(t_) - 6, 7) if math.dist(t_[i_:i_ + 2], _t) < 0.05]
        if not r_:
            continue
        if _riegel:
            # der Turm baut an diesem Wehrgang eine verriegelte Tür statt eines Untergeschosses
            knoten[j_] = k_ + "\nriegel_tuerme = PackedVector2Array(%.3f, %.3f)" % _t
        else:
            # der Turm ist bis auf diesen Wehrgang hinab hohl: kein Felsmassiv in seinem Untergeschoss
            for j2_, k2_ in enumerate(knoten):
                if 'name="Felsmassiv"' in k2_:
                    knoten[j2_] = re.sub(r'\nfrei = PackedVector3Array\(([^)]*)\)', lambda m2_: "\nfrei = PackedVector3Array(%s, %.2f, %.2f, %.2f)"
                                         % (m2_.group(1), _t[0], _t[1], r_[0] + 0.5), k2_)
# An einer Ecke der Vorburg liegen 12 m zwischen den Wehrgängen: ein Treppenturm verbindet sie
print("Treppenturm Vorburg: Wehrgänge auf %.2f und %.2f" % treppenturm("TreppenturmVorburg", "Drachenstein/Burgen", TREPPENTURM_VORBURG))
# In der Burg keine schwebenden Tornamen (wie bei Höfen und Bauten zeigt die Oberfläche den Ort beim Betreten an)
_tornamen = 0
for j_, k_ in enumerate(knoten):
    if re.search(r'\[node name="\w+Tor\d+Schild" type="Label3D" parent="Drachenstein/Burgen"\]', k_):
        knoten[j_] = ""
        _tornamen += 1
print("Tornamen in der Burg entfallen:", _tornamen)
# Banner an der Wand (Fahnen Art 1), die in einem Torbau oder Turm hingen (z. B. über einem Tor, hinter dem ein hohler
# Torbau steht): vor dessen Wand rücken, in ihrer eigenen Richtung, so dass das Tuch vor der Fläche hängt
_eckig, _rund = [], []
for k_ in knoten:
    m_ = re.search(r'\ntorbauten = PackedFloat32Array\(([^)]*)\)', k_)
    if m_ and m_.group(1).strip():
        t_ = [float(v_) for v_ in m_.group(1).split(",")]
        _eckig += [t_[i_:i_ + 10] for i_ in range(0, len(t_) - 9, 10)]
    m_ = re.search(r'\ntuerme = PackedFloat32Array\(([^)]*)\)', k_)
    if m_ and m_.group(1).strip():
        t_ = [float(v_) for v_ in m_.group(1).split(",")]
        _rund += [t_[i_:i_ + 7] for i_ in range(0, len(t_) - 6, 7)]
    m_ = re.search(r'\ngebaeude = PackedFloat32Array\(([^)]*)\)', k_)
    if m_ and m_.group(1).strip():
        t_ = [float(v_) for v_ in m_.group(1).split(",")]
        for i_ in range(0, len(t_) - 11, 12):
            g_ = math.radians(t_[i_ + 2])     # wie burgbau.gd: x entlang (cos, -sin), z entlang (sin, cos)
            _eckig.append([t_[i_], t_[i_ + 1], math.cos(g_), -math.sin(g_), t_[i_ + 5], t_[i_ + 5] + t_[i_ + 7] + 3.0,
                           t_[i_ + 3], t_[i_ + 4]])


def _im_bau(x_, y_, z_):
    for q_ in _eckig:
        l_ = math.hypot(q_[2], q_[3])
        ux_, uz_ = q_[2] / l_, q_[3] / l_
        a_, b_ = (x_ - q_[0]) * ux_ + (z_ - q_[1]) * uz_, (x_ - q_[0]) * -uz_ + (z_ - q_[1]) * ux_
        if abs(a_) < q_[6] / 2 + 0.3 and abs(b_) < q_[7] / 2 + 0.3 and q_[4] - 1 < y_ < q_[5] + 1:
            return True
    return any(math.dist((x_, z_), q_[:2]) < q_[4] + 0.3 and q_[2] - 1 < y_ < q_[3] + 1 for q_ in _rund)


for j_, k_ in enumerate(knoten):
    if 'name="Fahnen"' not in k_:
        continue
    m_ = re.search(r'\nfahnen = PackedFloat32Array\(([^)]*)\)', k_)
    f_ = [float(v_) for v_ in m_.group(1).split(",")]
    for i_ in range(0, len(f_) - 6, 7):
        if int(f_[i_ + 6]) != 1:
            continue
        g_ = math.radians(f_[i_ + 3])
        vx_, vz_ = math.sin(g_), math.cos(g_)
        schub_ = 0.0
        while schub_ < 12.0 and _im_bau(f_[i_] + vx_ * (schub_ + 0.25), f_[i_ + 1] - f_[i_ + 5] / 2, f_[i_ + 2] + vz_ * (schub_ + 0.25)):
            schub_ += 0.1
        if schub_ > 0.0:
            print("Banner vor die Wand gerückt: %.1f m (%.1f, %.1f)" % (schub_, f_[i_], f_[i_ + 2]))
            f_[i_] = round(f_[i_] + vx_ * schub_, 2)
            f_[i_ + 2] = round(f_[i_ + 2] + vz_ * schub_, 2)
    knoten[j_] = k_.replace(m_.group(0), "\nfahnen = PackedFloat32Array(%s)" % _zahlen(f_))
# Sitzende Taubenreihen auf den Mauerkronen: keine Taube in einem Turm oder Bau (die Reihe lag zufällig dort, wo die
# Mauer in einem Turm endet): die Reihe rückt auf der Mauer entlang heraus, sonst entfällt sie
_tauben_weg = 0
for j_, k_ in enumerate(knoten):
    if 'name="Schwarm' not in k_ or "\nsitzend = true" not in k_:
        continue
    m_ = re.search(r'transform = Transform3D\(([^)]*)\)', k_)
    t_ = [float(v_) for v_ in m_.group(1).split(",")]
    xx_, xz_ = t_[0], t_[6]                 # x-Achse (Text: Zeilen der Basis)
    ox_, oy_, oz_ = t_[9], t_[10], t_[11]
    n_ = int(re.search(r'\nanzahl = (\d+)', k_).group(1))
    w_ = float(re.search(r'\nweite = ([0-9.]+)', k_).group(1))
    reihe_ = [(i_ - (n_ - 1) / 2) * w_ / max(n_, 1) for i_ in range(n_)]

    def _frei(s_):
        return not any(_im_bau(ox_ + xx_ * (s_ + r_), oy_, oz_ + xz_ * (s_ + r_)) for r_ in reihe_)
    schub_ = next((s_ for d_ in range(0, 25) for s_ in (d_ * 0.25, -d_ * 0.25) if _frei(s_)), None)
    if schub_ is None:
        knoten[j_] = ""                        # der Knoten entfällt
        _tauben_weg += 1
    elif schub_ != 0.0:
        t_[9], t_[11] = round(ox_ + xx_ * schub_, 2), round(oz_ + xz_ * schub_, 2)
        knoten[j_] = k_.replace(m_.group(0), "transform = Transform3D(%s)" % ", ".join(f"{v_:.5g}" for v_ in t_))
        print("Taubenreihe aus Turm/Bau gerückt: %.2f m" % schub_)
print("Taubenreihen entfallen:", _tauben_weg)
wehrgang_wachen()   # die Streifen der Mauerwachen folgen den endgültigen Mauerstücken
# Person "kordel": person.tscn nutzt KEINE=0, SCHWARZ=1, GRAU=2, GOLDEN=3
schreibe("region_drachenstein.tscn")
