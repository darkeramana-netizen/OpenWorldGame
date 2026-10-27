"""Baut szenen/welt/region_riverlock.tscn. Aufruf: python3 werkzeuge/bau/region_riverlock.py

Riverlock nach dem Grundriss (docs/bilder/grundriss-riverlock.webp), ohne Drehung: Norden oben,
die Valn fließt von Norden nach Süden. 1 Bildpunkt des Plans = 0,25 m, Ursprung ist die Mitte des
Mittelbaus über dem Fluss (Bildpunkt 810, 420).
"""
from pathlib import Path
exec(open(Path(__file__).resolve().parent / "grundlage.py", encoding="utf-8").read())
lade_hoehen("gelaende_riverlock")

grundgeruest("gelaende_riverlock", '''region_id = "riverlock"
wasserspiegel = -10.0
wasser_meldung = "Die Valn ist zu reißend zum Schwimmen."
grenze_min = Vector2(-290, -190)
grenze_max = Vector2(290, 190)
grenze_meldung = "Hier endet die Valnschlucht. Weiter geht es nur mit Erlaubnis des Landkomturs."
karte_ursprung = Vector2(1016, 494)
karte_meter_pro_pixel = 60.0''', wasser_name="Valn", wasser_hoehe=-10, wasser_groesse=(700, 500),
             wasser_parameter="\nshader_parameter/loch_radius = 0.0")

PX = 0.25
def P(px, py):
    return (round((px - 810) * PX, 2), round((py - 420) * PX, 2))

def lerp2(a, b, t):
    return (round(a[0] + (b[0] - a[0]) * t, 2), round(a[1] + (b[1] - a[1]) * t, 2))

def torhaus(name, eltern, a, b, anteil, breite=5.0, hoehe=13.0):
    """Zwei Tortürme und ein Bogen über einer Lücke in der Mauerkante a-b."""
    mx, mz = lerp2(a, b, anteil)
    ux, uz = b[0] - a[0], b[1] - a[1]; l = math.hypot(ux, uz); ux, uz = ux / l, uz / l
    for seite in (-1, 1):
        box(f"{name}Turm{seite + 1}", eltern, round(mx + ux * (breite / 2 + 2) * seite, 2), hoehe / 2 - 2,
            round(mz + uz * (breite / 2 + 2) * seite, 2), 4, hoehe + 4, 6, "Material_mauer", gier=round(gier_zu(ux, uz), 2))
    box(f"{name}Bogen", eltern, mx, hoehe - 3.5, mz, breite + 0.4, 3, 6, "Material_mauer", gier=round(gier_zu(ux, uz), 2))
    return mx, mz

def burg(name, ecken, luecken, runde_tuerme, tore):
    N(name, "Node3D", ".")
    mauerzug("Mauer", name, ecken, 9, 2.5, luecken=luecken, geschlossen=True)
    for i in runde_tuerme:
        x, z = ecken[i]
        zyl(f"Turm{i}", name, x, 5.5, z, 4.0, 15, "Material_mauer", 12)
    return [torhaus(f"Tor{k}", name, ecken[i], ecken[(i + 1) % len(ecken)], luecken[i][0], luecken[i][1]) for k, i in enumerate(tore)]

# ---------- A: Westburg (Westufer) ----------
WB = "Westburg"
west = [P(298, 115), P(555, 115), P(555, 380), P(552, 480), P(520, 645), P(415, 642), P(395, 625), P(390, 552),
        P(225, 540), P(240, 280), P(282, 268)]
tor1, _ = burg(WB, west, {2: (0.5, 6.0), 4: (0.76, 5.0)}, [0, 1, 4, 8], [4, 2])
ex, ez = P(240, 280)
box("Eckturm", WB, ex, 5, ez, 7, 14, 7, "Material_mauer")
schild("SchildEckturm", WB, ex, 14, ez, "8 · Eckturm", 36)
schild("SchildTor", WB, tor1[0], 13, tor1[1] + 3, "1 · Äußere Toranlage", 40)
gebaeude_lokal("Bergfried", WB, -94, -31, 16, 16, 30, mat="Material_mauer", text="13 · Bergfried")
gebaeude_lokal("GrosserSaal", WB, -94, -14, 22, 10, 10, text="10 · Großer Saal")
gebaeude_lokal("Kuechen", WB, -110, -22, 8, 16, 7, mat="Material_holz", text="11 · Küchen & Vorräte")
gebaeude_lokal("Kapelle", WB, -75, -45, 8, 12, 9, text="9 · Kapelle")
zyl("KapelleTurm", WB, -75, 8, -50, 1.5, 16, "Material_hell", 8)
gebaeude_lokal("Stall1", WB, -104, -65, 14, 7, 6, mat="Material_holz", text="4 · Außenhöfe / Stallungen")
gebaeude_lokal("Stall2", WB, -78, -64, 12, 8, 6, mat="Material_holz")
gebaeude_lokal("Stall3", WB, -127, -56, 7, 10, 6, mat="Material_holz")
gebaeude_lokal("Stall4", WB, -127, -44, 7, 10, 6, mat="Material_holz")
gebaeude_lokal("InnereWache", WB, -118, 14, 8, 10, 7, mat="Material_mauer", text="12 · Innere Wache")
for k, z in enumerate([-6, -2, 2, 6]):
    box(f"Zielscheibe{k}", WB, -136, 1.0, z, 0.3, 2.0, 1.6, "Material_stoff")
schild("SchildWaffenhof", WB, -128, 4, 0, "3 · Waffenhof", 36)
schild("SchildTorhof", WB, -88, 4, 36, "2 · Torhof", 36)
# 5 · Vorwerk: überdachter Durchgang von der Westburg zum Westlichen Tor des Mittelbaus
for k, z in enumerate([-1.25, 6.25]):
    box(f"VorwerkWand{k}", WB, -59.6, 3.5, z, 9.8, 11, 1.5, "Material_mauer")
box("VorwerkDach", WB, -59.6, 6.5, 2.5, 9.8, 1, 9, "Material_mauer")
schild("SchildVorwerk", WB, -59.6, 9.5, 2.5, "5 · Vorwerk", 36)

# ---------- C: Ostburg (Ostufer) ----------
OB = "Ostburg"
ost = [P(1080, 175), P(1400, 175), P(1405, 230), P(1480, 315), P(1485, 480), P(1480, 620), P(1450, 700), P(1090, 660)]
tor23, _ = burg(OB, ost, {6: (0.194, 5.0), 7: (0.474, 6.0)}, [0, 1, 3, 4, 5, 7], [6, 7])
schild("SchildTor", OB, tor23[0], 13, tor23[1] + 3, "23 · Äußere Toranlage", 40)
gebaeude_lokal("Bergfried", OB, 108.75, -22, 16, 16, 30, mat="Material_mauer", text="35 · Bergfried")
gebaeude_lokal("GrosserSaal", OB, 108.75, -5, 22, 10, 10, text="32 · Großer Saal")
gebaeude_lokal("Kuechen", OB, 125, -20, 8, 16, 7, mat="Material_holz", text="33 · Küchen & Vorräte")
gebaeude_lokal("Kapelle", OB, 116, 37.5, 8, 14, 9, text="31 · Kapelle")
zyl("KapelleTurm", OB, 116, 8, 31, 1.5, 16, "Material_hell", 8)
gebaeude_lokal("InnereWache", OB, 121, 20, 10, 8, 7, mat="Material_mauer", text="34 · Innere Wache")
gebaeude_lokal("Stall1", OB, 80, -12, 8, 14, 6, mat="Material_holz", text="26 · Außenhöfe / Stallungen")
gebaeude_lokal("Stall2", OB, 100, -50, 12, 7, 6, mat="Material_holz")
gebaeude_lokal("Stall3", OB, 130, -50, 10, 7, 6, mat="Material_holz")
for k, z in enumerate([-18, -14, -10, -6]):
    box(f"Waffenstaender{k}", OB, 152, 1.0, z, 0.4, 2.0, 2.0, "Material_metall")
schild("SchildWaffenhof", OB, 149, 4, -12, "25 · Waffenhof", 36)
schild("SchildTorhof", OB, 140, 4, 58, "24 · Torhof", 36)
for k, z in enumerate([-1.25, 6.25]):
    box(f"VorwerkWand{k}", OB, 61.7, 3.5, z, 13.4, 11, 1.5, "Material_mauer")
box("VorwerkDach", OB, 61.7, 6.5, 2.5, 13.4, 1, 9, "Material_mauer")
schild("SchildVorwerk", OB, 61.7, 9.5, 2.5, "27 · Vorwerk", 36)

# ---------- B: Mittelbau über dem Fluss ----------
# Unten (-14 bis 0): Hafenhalle mit Kais und Stegen, Schiffsdurchfahrt durch Bögen im Süden.
# Mitte (0 bis 6): Zoll und Kontrolle, der Weg von Tor zu Tor. Oben (ab 6): Großer Saal und Wehrgang.
MB = "Mittelbau"
N(MB, "Node3D", ".")
X0, X1, Z0, Z1 = -55, 55, -20, 20
D = 1.5
box("Nordwand", MB, 0, -4, Z0 + D / 2, X1 - X0, 20, D, "Material_mauer")
N("Suedwand", "CSGCombiner3D", MB, "use_collision = true")
box("Wand", MB + "/Suedwand", 0, -4, Z1 - D / 2, X1 - X0, 20, D, "Material_mauer", kollision=False)
for k, x in enumerate([-24, -12, 0, 12, 24]):
    N(f"Bogen{k}", "CSGBox3D", MB + "/Suedwand", f"{T(x, -9, Z1 - D / 2)}\noperation = 2\nsize = Vector3(9, 10, 3)")
schild("SchildBoegen", MB, 0, -2.5, Z1 + 1.5, "15 · Einfahrbogen / Schiffsdurchfahrt", 36)
for name, x, tor in [("Westwand", X0 + D / 2, "14 · Westliches Tor"), ("Ostwand", X1 - D / 2, "22 · Östliches Tor")]:
    N(name, "CSGCombiner3D", MB, "use_collision = true")
    box("Wand", f"{MB}/{name}", x, -4, 0, D, 20, Z1 - Z0, "Material_mauer", kollision=False)
    N("Tor", "CSGBox3D", f"{MB}/{name}", f"{T(x, 2.25, 2.5)}\noperation = 2\nsize = Vector3(3, 4.5, 5)")
    schild(f"Schild{name}", MB, x + (-2 if x < 0 else 2), 6.8, 2.5, f"{tor} (Kettensperre)", 32)
for k, (x, z) in enumerate([(-52.5, -19.5), (51, -19.5), (-52, 18.75), (50.5, 18.75)]):
    zyl(f"Eckturm{k}", MB, x, 2, z, 4.5, 32, "Material_mauer", 12)

# Unteres Geschoss: Kais, Steg an der Nordwand, zwei Bootsstege
KAI = -8.5
box("KaiWest", MB, -43.75, (KAI - 14) / 2, 0, 19.5, KAI + 14, 37, "Material_kai")
box("KaiOst", MB, 43.75, (KAI - 14) / 2, 0, 19.5, KAI + 14, 37, "Material_kai")
box("KaiNord", MB, 0, (KAI - 14) / 2, -16.75, 68, KAI + 14, 3.5, "Material_kai")
for k, x in enumerate([-10, 10]):
    box(f"Steg{k}", MB, x, KAI - 0.3, -2.5, 3, 0.6, 25, "Material_holz")
    for j, z in enumerate([-8, 2, 9]):
        zyl(f"Pfahl{k}_{j}", MB, x + 1.6, -11.5, z, 0.25, 6, "Material_holz", 6)
schild("SchildHafenhalle", MB, 0, -3, -12, "16 · Hafenhalle (unteres Geschoss)", 40)
for k, x in enumerate([-40, 0, 40]):
    licht(f"LichtUnten{k}", MB, x, -3, 0, 22)
for k, (x, z, g) in enumerate([(0, -1, 90), (-21, -3, 90)]):
    box(f"Boot{k}", MB, x, -9.7, z, 12, 1.6, 3.4, "Material_holz", gier=g)
    zyl(f"Mast{k}", MB, x, -5.5, z, 0.2, 7, "Material_holz", 6, False)
for k, (x, z) in enumerate([(-48, -14), (-48, -10), (-50, -12), (47, 12), (49, 12), (48, 9)]):
    box(f"Fass{k}", MB, x, KAI + 0.6, z, 1.2, 1.2, 1.2, "Material_holz")
# Rampe vom Westkai hinauf ins Mittelgeschoss, mit Loch im Boden und Geländer
rampe("RampeUnten", MB, (-40, KAI, 14), (-40, 0, -12), 3.2)

# Mittleres Geschoss: Boden mit zwei Durchbrüchen für die Rampen
N("BodenMitte", "CSGCombiner3D", MB, "use_collision = true")
box("Platte", MB + "/BodenMitte", 0, -0.3, 0, X1 - X0 - 2 * D, 0.6, Z1 - Z0 - 2 * D, "Material_boden", kollision=False)
N("Loch", "CSGBox3D", MB + "/BodenMitte", f"{T(-40, -0.3, -7.5)}\noperation = 2\nsize = Vector3(3.6, 2, 9)")
box("GelaenderW", MB, -42.05, 0.55, -7.35, 0.3, 1.1, 9.3, "Material_holz")
box("GelaenderO", MB, -37.95, 0.55, -7.35, 0.3, 1.1, 9.3, "Material_holz")
box("GelaenderS", MB, -40, 0.55, -2.85, 4.4, 1.1, 0.3, "Material_holz")
# Trennwände mit Türen auf der Linie des Weges (z = 2.5); bei x = 30 zusätzlich Platz für die Rampe nach oben
for k, x in enumerate([-30, -16, 16, 30]):
    pfad = f"{MB}/Trennwand{k}"
    N(f"Trennwand{k}", "CSGCombiner3D", MB, "use_collision = true")
    z0 = -14 if x == 30 else Z0 + D
    box("Wand", pfad, x, 3, (z0 + Z1 - D) / 2, 0.6, 6, Z1 - D - z0, "Material_hell", kollision=False)
    N("Tuer", "CSGBox3D", pfad, f"{T(x, 1.5, 2.5)}\noperation = 2\nsize = Vector3(2, 3, 3)")
for name, x, text in [("Lager", -42, "17 · Lager & Kontrollräume"), ("Wachstube", -23, "18 · Wachstube"),
                      ("Verwaltung", 0, "19 · Zoll & Verwaltung"), ("Kontrolle", 23, "17 · Kontrollraum"),
                      ("LagerOst", 42, "17 · Lager")]:
    schild(f"Schild{name}", MB, x, 4.6, 10, text, 32)
    licht(f"Licht{name}", MB, x, 4.6, 6, 16)
for k, (x, z) in enumerate([(-50, 12), (-48, 15), (-46, 12), (-50, -15), (36, 12), (38, 15), (48, 14)]):
    box(f"Kiste{k}", MB, x, 0.6, z, 1.6, 1.2, 1.6, "Material_holz")
box("Wachtisch", MB, -23, 0.45, -8, 3, 0.9, 1.4, "Material_holz")
box("Waffenregal", MB, -28.5, 1.0, -12, 0.5, 2.0, 4, "Material_metall")
box("Zolltisch", MB, 0, 0.45, -4.5, 6, 0.9, 1.2, "Material_holz")
box("Waage", MB, 23, 0.6, -6, 2.0, 1.2, 2.0, "Material_metall")
# Rampe im östlichen Lager an der Nordwand hinauf ins obere Geschoss
rampe("RampeOben", MB, (20, 0, -16), (46, 6, -16), 3.2)

# Oberes Geschoss: Großer Saal (Ratssaal) in der Mitte, rundum der Wehrgang
N("BodenOben", "CSGCombiner3D", MB, "use_collision = true")
box("Platte", MB + "/BodenOben", 0, 5.7, 0, X1 - X0 - 2 * D, 0.6, Z1 - Z0 - 2 * D, "Material_boden", kollision=False)
N("Loch", "CSGBox3D", MB + "/BodenOben", f"{T(40.1, 5.7, -16)}\noperation = 2\nsize = Vector3(12.2, 2, 3.8)")
box("GelaenderObenS", MB, 40, 6.55, -13.95, 12.4, 1.1, 0.3, "Material_holz")
box("GelaenderObenW", MB, 33.85, 6.55, -16.2, 0.3, 1.1, 4.5, "Material_holz")
for name, x, z, sx, sz in [("BrustwehrNord", 0, Z0 + 0.4, X1 - X0, 0.8), ("BrustwehrSued", 0, Z1 - 0.4, X1 - X0, 0.8),
                           ("BrustwehrWest", X0 + 0.4, 0, 0.8, Z1 - Z0), ("BrustwehrOst", X1 - 0.4, 0, 0.8, Z1 - Z0)]:
    box(name, MB, x, 6.6, z, sx, 1.2, sz, "Material_mauer")
schild("SchildWehrgang", MB, -42, 9, 10, "21 · Wehrgang", 36)
OBEN = MB + "/Oben"
N("Oben", "Node3D", MB, T(0, 6, 0))
raum_lokal("GrosserSaal", OBEN, -30, -12, 30, 12, 7, [("W", 0), ("O", 0)], schild_text="20 · Großer Saal / Ratssaal", licht=True)
box("Ratstisch", OBEN, 0, 0.45, -3, 14, 0.9, 3, "Material_holz")
for k in range(6):
    box(f"StuhlN{k}", OBEN, -6 + k * 2.4, 0.55, -5.2, 0.8, 1.1, 0.8, "Material_holz")
    box(f"StuhlS{k}", OBEN, -6 + k * 2.4, 0.55, -0.8, 0.8, 1.1, 0.8, "Material_holz")
box("Wandteppich", OBEN, 0, 3.5, -11.3, 8, 3, 0.1, "Material_stoff", kollision=False)
licht("LichtSaal2", OBEN, 18, 5.5, 0, 16)
licht("LichtSaal3", OBEN, -18, 5.5, 0, 16)

# Kettensperren von den südlichen Tortürmen zu den Ufern (zur Zierde, ohne Kollision)
for k, (a, b) in enumerate([((-52, -2, 19), (-62.5, -9.6, 86)), ((50.5, -2, 19), (57.5, -9.6, 86))]):
    dx, dy, dz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
    waag = math.hypot(dx, dz)
    N(f"Kette{k}", "CSGBox3D", MB, f"""{T_kipp(round((a[0] + b[0]) / 2, 2), round((a[1] + b[1]) / 2, 2), round((a[2] + b[2]) / 2, 2), gier_zu(dx / waag, dz / waag), math.degrees(math.atan2(dy, waag)))}
size = Vector3({round(math.hypot(waag, dy), 2)}, 0.35, 0.35)
material = SubResource("Material_metall")""")
    zyl(f"Anker{k}", MB, b[0], -8.5, b[2], 0.8, 3, "Material_mauer", 8)
for k, (x, z, g) in enumerate([(-18, 55, 80), (24, 72, 100)]):
    box(f"Flussboot{k}", MB, x, -9.7, z, 12, 1.6, 3.4, "Material_holz", gier=g)
    zyl(f"FlussbootMast{k}", MB, x, -5.5, z, 0.2, 7, "Material_holz", 6, False)

# ---------- Personen ----------
N("Personen", "Node3D", ".")
person("Lotsin", "Personen", -44, KAI, 8, "Lotsin Wenna Kroll", "lotsin", 0, "0.2, 0.24, 0.3, 1", gier=-90)
person("TorwacheWestburg", "Personen", -89, 0, 49, "Torwächter Joost Mahr", "torwache_riverlock", 0, "0.35, 0.3, 0.15, 1", gier=180)
person("Zoellnerin", "Personen", 0, 0, -6.6, "Zöllnerin Mette Ruhl", "zoellnerin_riverlock", 0, "0.3, 0.32, 0.2, 1", gier=180)
person("ZollherrFalk", "Personen", 0, 6, -6.4, "Zollherr Hendrik Falk", "zollherr_falk", 0, "0.4, 0.3, 0.12, 1", gier=180)
# Ein Gesandter aus Valdrenn (als Salzhändler) verhandelt in der Ostburg mit dem Schreiber des Zollherrn.
person("Gesandter", "Personen", 140, 0, 20, "Orm Velsch, Händler aus Salzhain", "gesandter_valdrenn", 0, "0.45, 0.38, 0.22, 1")
person("Schreiber", "Personen", 140, 0, 22.2, "Schreiber Lukas Dorn", "schreiber_falk", 0, "0.3, 0.28, 0.24, 1")
gespraech("GesandterUndSchreiber", "Gesandter", "Schreiber", [
    ("a", "Der König zahlt in Gold, nicht in Versprechen. Hundert Gulden für eine Nacht, in der die Kette im Wasser liegt."),
    ("b", "Der Zollherr sagt weder ja noch nein. Er will wissen, wann."),
    ("a", "Wenn das Korn reif ist. Und wenn der Beobachter des Ordens in Drachenstein sitzt statt hier."),
    ("b", "Dann sorgt dafür, dass er gerufen wird. Ich habe nichts gesagt."),
], "", "beobachtung_kette",
   "Belauscht in Riverlock: Ein Gesandter aus Valdrenn bietet hundert Gulden für eine Nacht, in der die Kette im Wasser liegt. Der Schreiber des Zollherrn verhandelt mit.",
   (140, 1, 21.1))
person("Beobachter", "Personen", -9, 6, -6.4, "Beobachter Aldo Venn", "beobachter_riverlock", 2, "0.1, 0.1, 0.12, 1", gier=180)

# ---------- Orte ----------
N("Orte", "Node3D", ".")
for i, (name, untertitel, x, y, z, sx, sy, sz) in enumerate([
    ("Riverlock", "Tor und Mund. Die Brücke ist der einzige Übergang.", 10, 0, 0, 340, 80, 170),
    ("Westburg", "Riverlock, Westufer", -100, 2, -10, 100, 20, 145),
    ("Ostburg", "Riverlock, Ostufer. Hier beginnt die Straße nach Valdrenn.", 115, 2, 5, 110, 20, 145),
    ("Mittelbau", "Zoll und Kontrolle über der Valn", 0, 3, 0, 108, 5.6, 38),
    ("Hafenhalle", "Unter der Brücke legen die Boote an.", 0, -6, 0, 106, 6, 38),
    ("Großer Saal", "Hier verhandelt der Zollherr. Der Beobachter des Ordens hört zu.", 0, 9, 0, 58, 6, 22),
]):
    bereich(f"Form_ort{i+1}", sx, sy, sz)
    N(f"Ort{i+1}", "Area3D", "Orte", f'''{T(x, y, z)}
script = ExtResource("13_ort")
ortsname = "{name}"
untertitel = "{untertitel}"''')
    N("Form", "CollisionShape3D", f"Orte/Ort{i+1}", f'shape = SubResource("Form_ort{i+1}")')

# ---------- Sprungpunkte (Entwicklermenü, F10) ----------
N("Sprungpunkte", "Node3D", ".")
for name, x, y, z in [("Hafenhalle (Ankunft)", -46, -8.0, 4), ("Mittelbau, Zoll", 0, 0.5, 8), ("Großer Saal", -20, 6.5, 6),
                      ("Westburg, Tor", -90, 0.5, 46), ("Westburg, Hof", -80, 0.5, 0), ("Ostburg, Hof", 90, 0.5, 22),
                      ("Ostburg, Tor", 141, 0.5, 64)]:
    N(name.replace(",", "").replace(" ", "_").replace("(", "").replace(")", ""), "Marker3D", "Sprungpunkte",
      f'{T(x, y, z)}\nmetadata/anzeige = "{name}"')

# ---------- Ankunft per Schiff, Spieler und Oberfläche ----------
N("Ankuenfte", "Node3D", ".")
N("von_drachenstein", "Marker3D", "Ankuenfte", T(-46, KAI + 0.2, 4, 180), extra='groups=["ankunft"]')
N("von_ashenveil", "Marker3D", "Ankuenfte", T(-92.4, round(H(-92.4, 70) + 0.2, 2), 70), extra='groups=["ankunft"]')
ankunft("von_nordstrasse", -262, 115.6, -90)
ankunft("heilstube", -80, 0)
ankunft("von_suedstrasse", -163, 165, 0)
uebergang("ZurNordstrasse", (-280, round(H(-280, 116.5) + 2, 2), 116.5), (16, 40, 30), "nordstrasse", "von_riverlock",
          (-255, round(H(-255, 115) + 0.5, 2), 115), bedingung="")
uebergang("ZurSuedstrasse", (-161.6, round(H(-161.6, 184) + 2, 2), 184), (30, 40, 16), "suedstrasse", "von_riverlock",
          (-164, round(H(-164, 158) + 0.5, 2), 158), bedingung="")
schild("SchildNordstrasse", ".", -250, round(H(-250, 108) + 3, 2), 108, "Nordstraße → Drachenstein 225 km", 48)
schild("SchildSuedstrasse", ".", -172, round(H(-172, 150) + 3, 2), 150, "Südstraße → Ashenveil 185 km", 48)
spieler_und_oberflaeche(-80, 0, 0)
schreibe("region_riverlock.tscn")
