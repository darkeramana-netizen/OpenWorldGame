"""Baut szenen/welt/region_drachenstein.tscn. Aufruf: python3 werkzeuge/bau/region_drachenstein.py"""
from pathlib import Path
exec(open(Path(__file__).resolve().parent / "grundlage.py", encoding="utf-8").read())
lade_hoehen("gelaende")

grundgeruest("gelaende")

# ---------- Burgfeste Drachenstein ----------
N("BurgHof", None, ".", "", instanz="3_hof")
teil("teil_drachenstein.py")

# ---------- Brücken über die Inseln zum Schwarzen Bergfried ----------
N("Bruecken", "Node3D", ".")
# Von der Südmole über zwei Inseln zum Tor des Bergfrieds (Radius 20 in Richtung der zweiten Insel)
_bfw = math.atan2(95 - 135, 212 - 250)
punkte = [(158, 24), (185, 60), (212, 95), (round(250 + 20*math.cos(_bfw), 2), round(135 + 20*math.sin(_bfw), 2))]
for i in range(3):
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
    box("Pfeiler", pfad, 0, -7, 0, 3, 14, 4, "Material_mauer")

# ---------- Schwarzer Bergfried ----------
teil("teil_bergfried.py")

# ---------- Gravemarch nach dem Grundriss ----------
teil("teil_gravemarch.py")

# ---------- Gravecrest nach dem Grundriss ----------
teil("teil_gravecrest.py")

# ---------- Signaltürme an der Küste ----------
N("Signaltuerme", "Node3D", ".", '''script = ExtResource("11_auf_gelaende")
gelaende = NodePath("../Gelaende")''', extra='node_paths=PackedStringArray("gelaende")')
for i,(x,z) in enumerate([(78,-190),(85,200)]):
    N(f"Signalturm{i+1}", "Node3D", "Signaltuerme", T(x,0,z))
    box("Turm", f"Signaltuerme/Signalturm{i+1}", 0, 5, 0, 4, 14, 4, "Material_mauer")
    zyl("Feuerbecken", f"Signaltuerme/Signalturm{i+1}", 0, 12.4, 0, 1.6, 0.8, "Material_feuer", 8, False)

# ---------- Orte ----------
N("Orte", "Node3D", ".")
for i,(name, untertitel, x,y,z, sx,sy,sz) in enumerate([
    ("Burgfeste Drachenstein", "Drei Burgen, ein Stein, eine Feste.", 35, 0, 14, 250, 140, 230),
    ("Drachenkai", "Hafen am Wächtermeer", 132, -18, -2, 70, 20, 56),
    ("Schwarzer Bergfried", "Gründungsarchiv des Ordens", 232, -10, 115, 110, 80, 100),
    ("Gravemarch", "Nicht das Land schützt Gravemarch, sondern die Zeit, die sie gebaut hat.", -600, -5, -205, 240, 60, 240),
    ("Gravecrest", "Disziplin. Wissen. Ordnung. Sorrow bewahrt.", -694, 72, -366, 140, 40, 46),
]):
    bereich(f"Form_ort{i+1}", sx, sy, sz)
    N(f"Ort{i+1}", "Area3D", "Orte", f'''{T(x,y,z)}
script = ExtResource("13_ort")
ortsname = "{name}"
untertitel = "{untertitel}"''')
    N("Form", "CollisionShape3D", f"Orte/Ort{i+1}", f'shape = SubResource("Form_ort{i+1}")')

# ---------- Personen der Region ----------
N("Personen", "Node3D", ".")
_bw = polar(23.5, BF_WINKEL + 14, -17.8)
person("Bergwaechter", "Personen", 250 + _bw[0], -17.8, 135 + _bw[2], "Bergwächter Tjark Halm", "bergwaechter", 2, "0.05, 0.05, 0.06, 1", gier=round(-BF_WINKEL - 90, 1))
person("Lotsin", "Personen", 128, -17.8, 20, "Lotsin Wenna Kroll", "lotsin", 0, "0.2, 0.24, 0.3, 1")
person("TorwacheGravemarch", "Personen", round(ESME[0], 2), round(ESME[1], 2), round(ESME[2], 2), "Wächterin Esme Rauh", "torwache_gravemarch", 1, "0.15, 0.15, 0.16, 1", gier=round(math.degrees(math.atan2(-nx, -nz)), 1))
person("ArchivarinGravemarch", "Personen", *ARCHIVARIN, "Archivarin Ysolde Brack", "archivarin_gravemarch", 2, "0.3, 0.26, 0.2, 1", gier=180)
person("TorwacheGravecrest", "Personen", -608, 70, -359, "Kammbrecher Ulf Haskel", "torwache_gravecrest", 2, "0.2, 0.2, 0.22, 1", gier=-90)
N("PersonenAmBoden", "Node3D", "Personen", '''script = ExtResource("11_auf_gelaende")
gelaende = NodePath("../../Gelaende")''', extra='node_paths=PackedStringArray("gelaende")')
# Reiterin aus Ashenveil vor dem Vorburgtor: nimmt Wächter über den Küstenweg mit
person("Reiterin", "Personen/PersonenAmBoden", -22, 0, 92, "Reiterin Ilka Sand", "reiterin_ashenveil", 2, "0.25, 0.22, 0.18, 1", gier=-54)
pferd("PferdReiterin", "Personen", -25.5, round(H(-25.5, 94), 2), 94, 36)
person("Haendlerin", "Personen/PersonenAmBoden", 64, 0, -4, "Händlerin Grete Lohm", "haendlerin", 0, "0.45, 0.3, 0.2, 1")


# ---------- Sprungpunkte (Entwicklermenü, F10) ----------
N("Sprungpunkte", "Node3D", ".")
_bf = lambda r, w, y: (round(250 + r*math.cos(math.radians(BF_WINKEL + w)), 1), y, round(135 + r*math.sin(math.radians(BF_WINKEL + w)), 1))
for name, x, y, z in [("Hof der Burgfeste", 0, 0.5, 20), ("Vor dem Tor", 0, 0.5, 46), ("Oberer Burg", -50, 8.5, 0),
                      ("Vorburgtor", -10, round(H(-10, 78) + 0.5, 1), 78), ("Marktplatz", 66, round(H(66, -2) + 0.5, 1), -2),
                      ("Drachenkai", 125, -17.3, 21), ("Bergfried, Tor", *_bf(24, 0, -17.4)),
                      ("Bergfried, Schwelle (Ebene 0)", *_bf(8.5, 4, -17.4)), ("Bergfried, Archive (Ebene 4)", *_bf(8.6, -53, 11.4)),
                      ("Bergfried, Dach", *_bf(8.9, 189, 50.6)), ("Gravemarch, Brückenpforte", round(ESME[0] - ux * 3, 1), round(ESME[1] + 0.5, 1), round(ESME[2] - uz * 3, 1)), ("Gravemarch, Burghof", -614, -3.5, -180),
                      ("Gravecrest, Zugbrücke", -605, 70.5, -362), ("Gravecrest, Unterer Hof", -663, 70.5, -368),
                      ("Gravecrest, Palas", -735, 70.5, -365.5)]:
    N(name.replace(",", "").replace(" ", "_").replace("(", "").replace(")", ""), "Marker3D", "Sprungpunkte", f'{T(x, y, z)}\nmetadata/anzeige = "{name}"')

# ---------- Ankunft per Schiff, Spieler und Oberfläche ----------
N("Ankuenfte", "Node3D", ".")
N("von_riverlock", "Marker3D", "Ankuenfte", T(125, -17.5, 23), extra='groups=["ankunft"]')
N("von_ashenveil", "Marker3D", "Ankuenfte", T(-18.5, round(H(-18.5, 89) + 0.2, 2), 89, -53.4), extra='groups=["ankunft"]')
spieler_und_oberflaeche(0, 0, 46)

# Person "kordel": person.tscn nutzt KEINE=0, SCHWARZ=1, GRAU=2, GOLDEN=3
schreibe("region_drachenstein.tscn")
