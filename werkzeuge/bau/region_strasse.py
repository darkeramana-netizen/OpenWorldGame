"""Baut die drei Landstraßen als eigene Regionen:
szenen/welt/region_nordstrasse.tscn, region_suedstrasse.tscn, region_kuestenweg.tscn.
Aufruf: python3 werkzeuge/bau/region_strasse.py

Maßstab 1:100 (1 km = 10 m). Gerechnet wird wie im Gelände (werkzeuge/gelaende_strasse.gd) entlang
der Straße: a vom ersten Ende (a = 0) zum zweiten, c quer dazu. Signaltürme stehen wie in der Lore
alle 15 km (hier 150 m) zwischen Straße und Meer.
"""
import sys
from pathlib import Path

STRASSEN = {
    "nordstrasse": dict(
        karte=((272, 491), (640, 255), (1016, 494)),
        name="Nordstraße", laenge=2250.0, entlang_z=False, meer=1.0, moor_ab=-1.0,
        anfang=("drachenstein", "Drachenstein"), ende=("riverlock", "Riverlock"), stunden=216.0,
        text_anfang="Neun Tage auf der Nordstraße nach Westen, vorbei an Dörfern und Bezirksfestungen. Dann über den Pass, und unter dir liegt Drachenstein am Wächtermeer.",
        text_ende="Neun Tage auf der Nordstraße, nachts die Feuer der Signaltürme zur Rechten. Dann öffnet sich die Valnschlucht, und vor dir liegt Riverlock.",
        untertitel="225 km von Drachenstein nach Riverlock, nördlich um das Wächtermeer",
        wald=[(250, 1700)], doerfer=[(420, "Hollmar"), (1250, None), (1900, None)],
        festungen=[(760, "Bezirksfestung Kammfeld"), (1620, "Bezirksfestung Nordwacht")],
        personen=[("Dorfvorsteherin", "dorf", 0, "Dorfvorsteherin Berit Haag", "dorf_nordstrasse", 0, "0.35, 0.3, 0.22, 1"),
                  ("Bezirkswache", "festung", 0, "Bezirkswache Jost Arndt", "bezirkswache", 1, "0.15, 0.15, 0.16, 1")]),
    "suedstrasse": dict(
        karte=((372, 749), (700, 740), (1016, 494)),
        name="Südstraße", laenge=1850.0, entlang_z=False, meer=-1.0, moor_ab=-1.0,
        anfang=("ashenveil", "Ashenveil"), ende=("riverlock", "Riverlock"), stunden=168.0,
        text_anfang="Sieben Tage auf der Südstraße nach Westen, durch die Wälder unter den Nebelhöhen. Am Ende wird der Boden weich, und der Nebel schluckt die Straße bis zum Pfad nach Ashenveil.",
        text_ende="Sieben Tage auf der Südstraße nach Osten, durch die großen Wälder. Dann steigt die Straße zur Valnschlucht an, und vor dir liegt Riverlock.",
        untertitel="185 km von Ashenveil nach Riverlock, südlich um das Wächtermeer",
        wald=[(150, 650), (900, 1850)], doerfer=[(380, None), (1150, "Erlenbrück")],
        festungen=[(820, "Bezirksfestung Erlengrund"), (1520, "Bezirksfestung Waldtor")],
        personen=[("Feuerwart", "turm", 4, "Feuerwart Tobias Wern", "feuerwart_suedstrasse", 1, "0.3, 0.2, 0.12, 1"),
                  ("Bezirkswache", "festung", 0, "Bezirkswache Inga Roth", "bezirkswache", 1, "0.15, 0.15, 0.16, 1")]),
    "kuestenweg": dict(
        karte=((272, 491), (285, 630), (372, 749)),
        name="Küstenweg", laenge=700.0, entlang_z=True, meer=1.0, moor_ab=0.7,
        anfang=("drachenstein", "Drachenstein"), ende=("ashenveil", "Ashenveil"), stunden=72.0,
        text_anfang="Drei Tage auf dem Küstenweg nach Norden, das Wächtermeer zur Rechten. Am dritten Tag führt der Weg über den Pass nach Drachenstein.",
        text_ende="Drei Tage auf dem Küstenweg nach Süden. Das Land wird weich, der Nebel steigt auf, und am Ende des Weges beginnt der Damm nach Ashenveil.",
        untertitel="70 km von Drachenstein nach Ashenveil, an der Westküste entlang",
        wald=[(80, 330)], doerfer=[(250, "Torfwinkel")], festungen=[(430, "Bezirksfestung Seewacht")],
        personen=[("Torfstecherin", "dorf", 0, "Torfstecherin Mara Lind", "dorf_kuestenweg", 0, "0.3, 0.25, 0.18, 1"),
                  ("Bezirkswache", "festung", 0, "Bezirkswache Ole Brandt", "bezirkswache", 1, "0.15, 0.15, 0.16, 1")]),
}

if "STRASSE" not in globals():
    # Jede Straße in einem eigenen Namensraum bauen, damit die Szenen sich nichts teilen.
    for name in STRASSEN:
        exec(open(__file__, encoding="utf-8").read(), {"__file__": __file__, "STRASSE": name})
    sys.exit(0)

exec(open(Path(__file__).resolve().parent / "grundlage.py", encoding="utf-8").read())
W = STRASSEN[STRASSE]
L = W["laenge"]
lade_hoehen(f"gelaende_{STRASSE}")
random.seed(sum(map(ord, STRASSE)))

def welt(a, c):
    return (round(c, 2), round(a, 2)) if W["entlang_z"] else (round(a, 2), round(c, 2))

def strassen_c(a):
    enden = smoothstep(0.0, 60.0, a) * smoothstep(L, L - 60.0, a)
    return (28.0 * math.sin(a / 170.0) + 9.0 * math.sin(a / 53.0)) * enden

def smoothstep(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)

def richtung(a):
    """Richtung der Straße bei a in Weltkoordinaten (dx, dz)."""
    x0, z0 = welt(a - 1, strassen_c(a - 1))
    x1, z1 = welt(a + 1, strassen_c(a + 1))
    l = math.hypot(x1 - x0, z1 - z0)
    return (x1 - x0) / l, (z1 - z0) / l

MEER = W["meer"]
LAND = -MEER
grenze = (f"Vector2(-18, -185)", f"Vector2({L + 18}, 185)") if not W["entlang_z"] else (f"Vector2(-185, -18)", f"Vector2(185, {L + 18})")
grundgeruest(f"gelaende_{STRASSE}", f'''region_id = "{STRASSE}"
wasserspiegel = -20.0
wasser_meldung = "Das Wächtermeer ist zu kalt zum Schwimmen."
grenze_min = {grenze[0]}
grenze_max = {grenze[1]}
grenze_meldung = "Bleib auf der Straße. Abseits liegen nur Fels und Wildnis."
karte_ursprung = Vector2{W["karte"][0]}
karte_mitte = Vector2{W["karte"][1]}
karte_ende = Vector2{W["karte"][2]}
karte_strecke = {L}
karte_entlang_z = {"true" if W["entlang_z"] else "false"}''', wasser_groesse=(L + 800, 1200) if not W["entlang_z"] else (1200, L + 800),
             wasser_parameter="\nshader_parameter/loch_radius = 0.0", nebel=0.003 if STRASSE == "kuestenweg" else 0.0018)
S('''[sub_resource type="StandardMaterial3D" id="Material_wald"]
albedo_color = Color(0.16, 0.24, 0.13, 1)
roughness = 1.0''')

def auf_boden(x, z, halb=0.0):
    if halb <= 0:
        return H(x, z)
    return min(H(x + dx, z + dz) for dx in (-halb, 0, halb) for dz in (-halb, 0, halb))

# ---------- Signaltürme alle 150 m zwischen Straße und Meer ----------
N("Signaltuerme", "Node3D", ".")
tuerme = []
for k, a in enumerate(range(75, int(L), 150)):
    x, z = welt(a, strassen_c(a) + MEER * 45)
    y = auf_boden(x, z, 2)
    N(f"Signalturm{k}", "Node3D", "Signaltuerme", T(x, round(y, 2), z))
    box("Turm", f"Signaltuerme/Signalturm{k}", 0, 6, 0, 4, 14, 4, "Material_mauer")
    zyl("Feuerbecken", f"Signaltuerme/Signalturm{k}", 0, 13.4, 0, 1.6, 0.8, "Material_feuer", 8, False)
    tuerme.append((x, round(y, 2), z, a))

# ---------- Meilensteine mit den echten Entfernungen ----------
N("Meilensteine", "Node3D", ".")
for k, a in enumerate(range(100, int(L), 250)):
    x, z = welt(a, strassen_c(a) + LAND * 5.5)
    y = H(x, z)
    km_anfang, km_ende = round(a / 10), round((L - a) / 10)
    box(f"Stein{k}", "Meilensteine", x, round(y + 0.5, 2), z, 0.5, 1.4, 0.5, "Material_hell")
    schild(f"Schild{k}", "Meilensteine", x, round(y + 2.0, 2), z,
           f"{W['anfang'][1]} {km_anfang} km · {W['ende'][1]} {km_ende} km", 28)

# ---------- Dörfer und Bezirksfestungen auf der Landseite ----------
frei = []   # (x, z, Radius), wo kein Wald wachsen soll
N("Doerfer", "Node3D", ".")
dorf_mitten = []
for i, (a, dorfname) in enumerate(W["doerfer"]):
    cm = strassen_c(a) + LAND * 38
    mx, mz = welt(a, cm)
    dorf_mitten.append((mx, mz, a))
    frei.append((mx, mz, 40))
    pfad = f"Doerfer/Dorf{i}"
    N(f"Dorf{i}", "Node3D", "Doerfer")
    zyl("Brunnen", pfad, mx, round(H(mx, mz) + 0.5, 2), mz, 1.2, 1.0, "Material_mauer", 10)
    for k in range(7):
        w = k * 2 * math.pi / 7 + random.uniform(-0.2, 0.2)
        r = random.uniform(11, 17)
        hx, hz = welt(a + r * math.cos(w), cm + r * math.sin(w))
        if abs(r * math.sin(w) + cm - strassen_c(a + r * math.cos(w))) < 12:
            continue
        gier = round(math.degrees(math.atan2(mx - hx, mz - hz)) / 90) * 90   # Tür zum Brunnen
        N(f"Haus{k}", None, pfad, T(hx, round(auf_boden(hx, hz, 4) + 1.0, 2), hz, gier, 0.8, 0.85, 0.8), instanz="12_haus")
    if dorfname:
        schild("Schild", pfad, mx, round(H(mx, mz) + 7, 2), mz, dorfname, 56)

N("Festungen", "Node3D", ".")
festung_mitten = []
for i, (a, fname) in enumerate(W["festungen"]):
    cm = strassen_c(a) + LAND * 42
    mx, mz = welt(a, cm)
    festung_mitten.append((mx, mz, a))
    frei.append((mx, mz, 30))
    pfad = f"Festungen/Festung{i}"
    y = auf_boden(mx, mz, 12)
    N(f"Festung{i}", "Node3D", "Festungen", T(mx, round(y, 2), mz))
    # Tor zur Straße: die Seite, die zur Straße zeigt, bekommt eine Lücke.
    zur_strasse = -LAND
    seiten = [("N", 0, -11, 24, 2), ("S", 0, 11, 24, 2), ("W", -11, 0, 2, 24), ("O", 11, 0, 2, 24)]
    tor_seite = ("S" if zur_strasse > 0 else "N") if not W["entlang_z"] else ("O" if zur_strasse > 0 else "W")
    for name, x, z, sx, sz in seiten:
        if name == tor_seite:
            if sx > sz:
                box(f"Mauer{name}1", pfad, -7.5, 2.5, z, 9, 9, 2, "Material_mauer")
                box(f"Mauer{name}2", pfad, 7.5, 2.5, z, 9, 9, 2, "Material_mauer")
            else:
                box(f"Mauer{name}1", pfad, x, 2.5, -7.5, 2, 9, 9, "Material_mauer")
                box(f"Mauer{name}2", pfad, x, 2.5, 7.5, 2, 9, 9, "Material_mauer")
        else:
            box(f"Mauer{name}", pfad, x, 2.5, z, sx, 9, sz, "Material_mauer")
    for k, (x, z) in enumerate([(-11, -11), (11, -11), (-11, 11), (11, 11)]):
        zyl(f"Eckturm{k}", pfad, x, 4, z, 2.2, 12, "Material_mauer", 8)
    box("Wohnturm", pfad, 0, 5, 0, 7, 14, 7, "Material_mauer")
    schild("Schild", pfad, 0, 14, 0, fname, 56)

# ---------- Wald aus zwei MultiMeshes (Stämme, Kronen), ohne Kollision ----------
def wald_dichte(x, z):
    return 0.5 + 0.3 * math.sin(x / 37.0) * math.cos(z / 29.0) + 0.2 * math.sin((x + z) / 13.0)

baeume = []
for x in range(int(-20 if not W["entlang_z"] else -195), int((L + 20) if not W["entlang_z"] else 195), 7):
    for z in range(int(-195 if not W["entlang_z"] else -20), int(195 if not W["entlang_z"] else L + 20), 7):
        px, pz = x + random.uniform(-2.5, 2.5), z + random.uniform(-2.5, 2.5)
        a, c = (pz, px) if W["entlang_z"] else (px, pz)
        if not any(a0 <= a <= a1 for a0, a1 in W["wald"]):
            continue
        if abs(c - strassen_c(a)) < 9 or wald_dichte(px, pz) < 0.55 or random.random() < 0.35:
            continue
        if MEER * (c - strassen_c(a)) > 30:   # zum Meer hin bleibt das Land offen (Signaltürme, Küste)
            continue
        if any(math.hypot(px - fx, pz - fz) < fr for fx, fz, fr in frei):
            continue
        h = H(px, pz)
        if h < -15 or h > 70:
            continue
        baeume.append((px, h, pz, random.uniform(0.8, 1.35)))
def multimesh(id_, mesh_id, hoehe_mitte):
    werte = []
    for x, y, z, s in baeume:
        werte += [s, 0, 0, round(x, 2), 0, s, 0, round(y + hoehe_mitte * s, 2), 0, 0, s, round(z, 2)]
    S(f'''[sub_resource type="MultiMesh" id="{id_}"]
transform_format = 1
instance_count = {len(baeume)}
mesh = SubResource("{mesh_id}")
buffer = PackedFloat32Array({", ".join(f"{v:.4g}" for v in werte)})''')
S('''[sub_resource type="CylinderMesh" id="Mesh_stamm"]
material = SubResource("Material_holz")
top_radius = 0.18
bottom_radius = 0.28
height = 3.0
radial_segments = 6''')
S('''[sub_resource type="CylinderMesh" id="Mesh_krone"]
material = SubResource("Material_wald")
top_radius = 0.0
bottom_radius = 1.9
height = 6.0
radial_segments = 7''')
multimesh("Baeume_stamm", "Mesh_stamm", 1.4)
multimesh("Baeume_krone", "Mesh_krone", 5.4)
N("Wald", "Node3D", ".")
N("Staemme", "MultiMeshInstance3D", "Wald", 'multimesh = SubResource("Baeume_stamm")')
N("Kronen", "MultiMeshInstance3D", "Wald", 'multimesh = SubResource("Baeume_krone")')

# ---------- Personen ----------
N("Personen", "Node3D", ".")
for knoten_name, wo, index, anzeige, dialog, kordel, tracht in W["personen"]:
    if wo == "dorf":
        mx, mz, a = dorf_mitten[index]
        px, pz = mx + 2.5, mz
    elif wo == "festung":
        mx, mz, a = festung_mitten[index]
        dx, dz = welt(0, -LAND * 15)
        px, pz = mx + dx, mz + dz   # vor dem Tor, auf der Seite zur Straße
    else:   # am Signalturm, drei Meter neben dem Turm in Richtung der Straße
        dx, dz = welt(0, -MEER * 3.5)
        px, pz = tuerme[index][0] + dx, tuerme[index][2] + dz
    person(knoten_name, "Personen", round(px, 2), round(H(px, pz), 2), round(pz, 2), anzeige, dialog, kordel, tracht)

# ---------- Orte ----------
N("Orte", "Node3D", ".")
orte = [(W["name"], W["untertitel"], *welt(L / 2, 0), L + 30, 200, 380)]
for (mx, mz, a), (_, dorfname) in zip(dorf_mitten, W["doerfer"]):
    if dorfname:
        orte.append((dorfname, "Dorf an der " + W["name"] if W["name"] != "Küstenweg" else "Dorf am Küstenweg", mx, mz, 50, 40, 50))
for (mx, mz, a), (_, fname) in zip(festung_mitten, W["festungen"]):
    orte.append((fname, "Bezirksfestung des Ordens. Hier wird jeder Fremde gemeldet.", mx, mz, 34, 40, 34))
for i, (name, untertitel, x, z, sx, sy, sz) in enumerate(orte):
    if i == 0 and W["entlang_z"]:
        sx, sz = sz, sx
    bereich(f"Form_ort{i+1}", sx, sy, sz)
    N(f"Ort{i+1}", "Area3D", "Orte", f'''{T(x, round(H(x, z), 1), z)}
script = ExtResource("13_ort")
ortsname = "{name}"
untertitel = "{untertitel}"''')
    N("Form", "CollisionShape3D", f"Orte/Ort{i+1}", f'shape = SubResource("Form_ort{i+1}")')

# ---------- Enden: Ankünfte und Übergänge ----------
(von_a, name_a), (von_e, name_e) = W["anfang"], W["ende"]
ax_, az_ = welt(8, strassen_c(8))
ex_, ez_ = welt(L - 8, strassen_c(L - 8))
blick_anfang = -90.0 if not W["entlang_z"] else 180.0   # Blick in Richtung wachsendes a
blick_ende = 90.0 if not W["entlang_z"] else 0.0
ankunft(f"von_{von_a}", ax_, az_, blick_anfang)
ankunft(f"von_{von_e}", ex_, ez_, blick_ende)
zone_a = welt(-10, 0)
zone_e = welt(L + 10, 0)
groesse_zone = (12, 60, 120) if not W["entlang_z"] else (120, 60, 12)
r_a = welt(14, strassen_c(14))
r_e = welt(L - 14, strassen_c(L - 14))
uebergang(f"Nach{name_a}", (zone_a[0], round(H(*zone_a) + 2, 2), zone_a[1]), groesse_zone, von_a, f"von_{STRASSE}",
          (r_a[0], round(H(*r_a) + 0.5, 2), r_a[1]), W["stunden"], f"von_{von_e}", W["text_anfang"], bedingung="")
uebergang(f"Nach{name_e}", (zone_e[0], round(H(*zone_e) + 2, 2), zone_e[1]), groesse_zone, von_e, f"von_{STRASSE}",
          (r_e[0], round(H(*r_e) + 0.5, 2), r_e[1]), W["stunden"], f"von_{von_a}", W["text_ende"], bedingung="")
for name, (x, z), text in [("SchildAnfang", welt(2, strassen_c(2) + LAND * 6), f"← {name_a}"),
                           ("SchildEnde", welt(L - 2, strassen_c(L - 2) + LAND * 6), f"{name_e} →")]:
    schild(name, ".", x, round(H(x, z) + 3, 2), z, text, 64)

# ---------- Sprungpunkte ----------
N("Sprungpunkte", "Node3D", ".")
punkte = [(f"Anfang ({name_a})", ax_, az_), (f"Ende ({name_e})", ex_, ez_)]
punkte += [(dorfname or f"Dorf {i + 1}", mx + 5, mz) for i, ((mx, mz, a), (_, dorfname)) in enumerate(zip(dorf_mitten, W["doerfer"]))]
punkte += [(fname, *welt(a, strassen_c(a))) for (mx, mz, a), (_, fname) in zip(festung_mitten, W["festungen"])]
for name, x, z in punkte:
    N(name.replace(",", "").replace(" ", "_").replace("(", "").replace(")", ""), "Marker3D", "Sprungpunkte",
      f'{T(round(x, 2), round(H(x, z) + 0.5, 2), round(z, 2))}\nmetadata/anzeige = "{name}"')

spieler_und_oberflaeche(ax_, round(H(ax_, az_) + 0.3, 2), az_)
print(STRASSE, "– Bäume:", len(baeume), "Dörfer:", len(dorf_mitten), "Festungen:", len(festung_mitten))
schreibe(f"region_{STRASSE}.tscn")
