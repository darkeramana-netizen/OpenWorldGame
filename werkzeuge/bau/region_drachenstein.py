"""Baut szenen/welt/region_drachenstein.tscn. Aufruf: python3 werkzeuge/bau/region_drachenstein.py"""
from pathlib import Path
exec(open(Path(__file__).resolve().parent / "grundlage.py", encoding="utf-8").read())
lade_hoehen("gelaende")

grundgeruest("gelaende", region_eigenschaften="grenze_min = Vector2(-880, -680)\ngrenze_max = Vector2(1280, 730)",
             wasser_groesse=(2800, 1800))

# ---------- Burgfeste Drachenstein ----------
import sys
sys.path.insert(0, str(BAU))
import plan_drachenstein as PD
HOF_Y = PD.HOF_Y
# Der Hof aus Akt I liegt im III. Burghof oben auf dem Grat
N("BurgHof", None, ".", T(0, HOF_Y, 0), instanz="3_hof")
BF_X_NEU, BF_Z_NEU = 500, 100   # Schwarzer Bergfried (werkzeuge/gelaende_erzeuger.gd, BERGFRIED)
teil("teil_drachenstein.py")
# Gepflastert sind Gassen und Markt in der Stadt, die Kais und die Höfe der Burgen
gelaende_pflaster([STADT_UMRISS, WL(PD.HAFEN_BEZIRK), WL(PD.BURGHOF2 + PD.BURGHOF3[1:6]), WL(PD.KERNBURG)])

# ---------- Mole und Brücken über die Inseln zum Schwarzen Bergfried ----------
# Vom Molentor in der Hafenmauer führt eine Mole ins Meer, von dort Brücken über drei Inseln.
N("Bruecken", "Node3D", ".")
_bfw = math.atan2(95 - 135, 212 - 250)
_mole_a = W((835, 505))            # vor dem Molentor
_mole_knick = (_mole_a[0], -66.0)    # erst vom Tor weg ins Wasser
_mole_b = (240.0, -64.0)             # dann hinaus in die Bucht
for k, (a_, b_) in enumerate([(_mole_a, _mole_knick), (_mole_knick, _mole_b)]):
    box(f"Mole{k}", "Bruecken", round((a_[0] + b_[0]) / 2, 2), -19.0, round((a_[1] + b_[1]) / 2, 2),
        round(math.dist(a_, b_) + 8, 2), 2.4, 8, "Material_kai", gier=round(gier_zu(b_[0] - a_[0], b_[1] - a_[1]), 2))
punkte = [_mole_b, (300, -15), (382, 22), (462.4, 60.4),
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
for i,(x,z) in enumerate([(120,-320),(170,380)]):
    N(f"Signalturm{i+1}", "Node3D", "Signaltuerme", T(x,0,z))
    box("Turm", f"Signaltuerme/Signalturm{i+1}", 0, 5, 0, 4, 14, 4, "Material_mauer")
    zyl("Feuerbecken", f"Signaltuerme/Signalturm{i+1}", 0, 12.4, 0, 1.6, 0.8, "Material_feuer", 8, False)
    signalfeuer(f"Signaltuerme/Signalturm{i+1}", 12.8)

# ---------- Orte ----------
N("Orte", "Node3D", ".")
_orte = [
    ("Burgfeste Drachenstein", "Drei Burgen, ein Stein, eine Feste.", 60, 10, 20, 520, 140, 700),
    ("Kernburg · Drachenhorst", "Bergfried, Palas und Drachenkapelle.", -4, 22, -127, 110, 30, 140),
    ("III. Burghof · Wolfsfeste", "Die Schwelle des Ordens.", 0, 17, 0, 95, 20, 100),
    ("II. Burghof", "Vierzehntes Jahrhundert.", 15, 13, 75, 80, 16, 90),
    ("I. Vorburg", "Der älteste Teil am Fuß des Grats.", 31, 10, 175, 70, 16, 75),
    ("Festungsstadt", "St. Marien, Markt und Fachwerkhäuser.", 140, -15, 160, 150, 16, 230),
    ("Drachenhafen", "Hafen am Wächtermeer", 150, -17, -5, 110, 12, 110),
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
bewuchs(frei_vielecke=[STADT_UMRISS, WL(PD.HAFEN_BEZIRK), WL(PD.BURGHOF2 + PD.BURGHOF3[1:6]), WL(PD.KERNBURG),
                       WL(PD.VORBURG), WL(PD.ZWINGER_KERNBURG)],
        frei_rechtecke=[(BF_X_NEU, BF_Z_NEU, 90, 90), (-600, -205, 240, 240), (-694, -366, 150, 60)], wald_anteil=0.24)

# ---------- Personen der Region ----------
N("Personen", "Node3D", ".")
_bw = polar(23.5, BF_WINKEL + 14, -17.8)
person("Bergwaechter", "Personen", BF_X + _bw[0], -17.8, BF_Z + _bw[2], "Bergwächter Tjark Halm", "bergwaechter", 2, "0.05, 0.05, 0.06, 1", gier=round(-BF_WINKEL - 90, 1))
_lotsin = W((690, 438))   # am Nordkai, nah am Becken
person("Lotsin", "Personen", _lotsin[0], -17.6, _lotsin[1], "Lotsin Wenna Kroll", "lotsin", 0, "0.2, 0.24, 0.3, 1", gier=-90)
person("TorwacheGravemarch", "Personen", round(ESME[0], 2), round(ESME[1], 2), round(ESME[2], 2), "Wächterin Esme Rauh", "torwache_gravemarch", 1, "0.15, 0.15, 0.16, 1", gier=round(math.degrees(math.atan2(-nx, -nz)), 1))
person("ArchivarinGravemarch", "Personen", *ARCHIVARIN, "Archivarin Ysolde Brack", "archivarin_gravemarch", 2, "0.3, 0.26, 0.2, 1", gier=180)
person("TorwacheGravecrest", "Personen", -608, 70, -359, "Kammbrecher Ulf Haskel", "torwache_gravecrest", 2, "0.2, 0.2, 0.22, 1", gier=-90)
N("PersonenAmBoden", "Node3D", "Personen", '''script = ExtResource("11_auf_gelaende")
gelaende = NodePath("../../Gelaende")''', extra='node_paths=PackedStringArray("gelaende")')
# Bürgschaft (Regel 10): Nach dem Haupteid wartet ein Bewerber an der Schwelle. Bürgt man für ihn, steht er
# im Hof und fragt einen Knappen nach den Fluchtgängen aus. Wer das belauscht, kann ihn melden.
person("KerrinVorTor", "Personen", -4, HOF_Y, 40, "Bewerber Kerrin Fahl", "bewerber_kerrin", 0, "0.4, 0.33, 0.25, 1", gier=180,
       sichtbar_wenn="eid_waechter,!kerrin_entschieden")
person("KerrinImHof", "Personen", 22, HOF_Y, 0, "Anwärter Kerrin Fahl", "bewerber_kerrin", 0, "0.27, 0.24, 0.2, 1",
       sichtbar_wenn="kerrin_anwaerter,!kerrin_gefasst")
person("TiloBrenn", "Personen", 22, HOF_Y, 2.2, "Knappe Tilo Brenn", "knappe_tilo", 1, "0.27, 0.24, 0.2, 1",
       sichtbar_wenn="kerrin_anwaerter,!kerrin_gefasst")
gespraech("KerrinUndTilo", "KerrinImHof", "TiloBrenn", [
    ("a", "Du warst doch schon im Bergfried. Stimmt es, dass es unter Ashenveil Gänge bis in die Sümpfe gibt?"),
    ("b", "Woher soll ich das wissen? Und warum willst du das wissen?"),
    ("a", "Nur so. Und hier in Drachenstein? Unter der Oberer Burg, wo kommt man da heraus?"),
    ("b", "Frag den Kammerhüter, wenn du es so genau wissen willst."),
], "kerrin_anwaerter,!kerrin_gefasst", "beobachtung_kerrin",
   "Belauscht im Hof: Kerrin Fahl, für den du bürgst, fragt den Knappen Tilo Brenn nach den Fluchtgängen. Ein Warnzeichen.",
   (22, HOF_Y + 1, 1.1))
# Reiterin aus Ashenveil am Torhaus West: nimmt Wächter über den Küstenweg mit
REITERIN = W((205, 440))
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
for name, x, y, z in [("Hof der Burgfeste", 0, HOF_Y + 0.5, 20), ("Vor dem Tor", 0, HOF_Y + 0.5, 46), ("Kernburg", *_sp((975, 225))), ("Übungsplatz", round(UEB[0] + 4, 1), PD.H_KERNBURG + 0.5, round(UEB[1], 1)),
                      ("II. Burghof", *_sp((560, 262))), ("I. Vorburg", *_sp((390, 300))), ("Weg unter den Felsen", *_sp((600, 378))),
                      ("Hafentor", *_sp((750, 428))), ("Marktplatz", *_sp((512, 530))), ("St. Marien", *_sp((410, 530))),
                      ("Drachenkai", _lotsin[0] + 2, -17.3, _lotsin[1]), ("Bergfried, Tor", *_bf(24, 0, -17.4)),
                      ("Bergfried, Schwelle (Ebene 0)", *_bf(8.5, 4, -17.4)), ("Bergfried, Archive (Ebene 4)", *_bf(8.6, -53, 11.4)),
                      ("Bergfried, Dach", *_bf(8.9, 189, 50.6)), ("Gravemarch, Brückenpforte", round(ESME[0] - ux * 3, 1), round(ESME[1] + 0.5, 1), round(ESME[2] - uz * 3, 1)), ("Gravemarch, Burghof", -614, -3.5, -180),
                      ("Gravecrest, Zugbrücke", -605, 70.5, -362), ("Gravecrest, Unterer Hof", -663, 70.5, -368),
                      ("Gravecrest, Palas", -735, 70.5, -365.5)]:
    N(name.replace(",", "").replace(" ", "_").replace("(", "").replace(")", ""), "Marker3D", "Sprungpunkte", f'{T(x, y, z)}\nmetadata/anzeige = "{name}"')

# ---------- Ankunft per Schiff, Spieler und Oberfläche ----------
N("Ankuenfte", "Node3D", ".")
N("von_riverlock", "Marker3D", "Ankuenfte", T(round(_lotsin[0] + 3, 2), -17.5, round(_lotsin[1], 2), 90), extra='groups=["ankunft"]')
N("von_ashenveil", "Marker3D", "Ankuenfte", T(round(REITERIN[0] + 3, 2), round(H(REITERIN[0] + 3, REITERIN[1]) + 0.2, 2), round(REITERIN[1], 2), -53.4), extra='groups=["ankunft"]')
ankunft("von_nordstrasse", 112, -608, 145)
ankunft("von_kuestenweg", 152, 640, 10)
ankunft("heilstube", -10, 15)
schild("SchildNordstrasse", ".", 160, round(H(160, -555) + 3, 2), -555, "Nordstraße → Riverlock 225 km", 48)
schild("SchildKuestenweg", ".", 158, round(H(158, 600) + 3, 2), 600, "Küstenweg → Ashenveil 70 km", 48)
# Am Ende der Pässe beginnen die Landstraßen
uebergang("ZurNordstrasse", (88, H(88, -652) + 2, -652), (30, 40, 16), "nordstrasse", "von_drachenstein",
          (112, round(H(112, -608) + 0.5, 2), -608))
uebergang("ZumKuestenweg", (161, H(161, 700) + 2, 700), (30, 40, 20), "kuestenweg", "von_drachenstein",
          (152, round(H(152, 640) + 0.5, 2), 640))
spieler_und_oberflaeche(0, HOF_Y, 46)

# Person "kordel": person.tscn nutzt KEINE=0, SCHWARZ=1, GRAU=2, GOLDEN=3
schreibe("region_drachenstein.tscn")
