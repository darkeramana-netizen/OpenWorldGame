# ---------- Die Stadt Drachenstein: Straßen, Häuserzeilen, äußerer Mauerring (Löwenward) ----------
# Lore (Burgen 4): Drachenstein steigt in Ringen hinab: Drachenhorst → Wolfsfeste (Hof) → Marktviertel
# (innerer Ring) → Löwenward (äußerer Ring) → Drachenkai. Die alte Ringmauer ist jetzt die innere Mauer;
# um sie herum liegen im Norden, Westen und Süden die neuen Viertel der Löwenward.
# Die Häuser stehen dicht an dicht entlang der Straßen, die Tür zur Straße. Sie werden von
# szenen/welt/stadthaeuser.gd gezeichnet; die Hausformen (Breite, Tiefe, Geschosse) stehen dort.
import re

E("Script", "res://szenen/welt/stadthaeuser.gd", "27_stadthaeuser")
HAUSFORMEN = [(float(b), float(t), int(g)) for b, t, g in re.findall(
    r"\[(\d+\.\d+), (\d+\.\d+), (\d), \d, (?:true|false), \d, \d\]",
    (REPO / "szenen" / "welt" / "stadthaeuser.gd").read_text(encoding="utf-8"))]
assert len(HAUSFORMEN) == 24, len(HAUSFORMEN)
VORKRAGUNG = 0.35

# --- Straßen: die Wege im inneren Ring (WEGE) und die neuen Straßen der Löwenward ---
WEGE = [[(0, 40), (0, 56), (44, 46), (58, 22), (75, 4), (98, 0)], [(0, 56), (-25, 52), (-50, 18), (-50, 8)],
        [(0, 80), (-60, 95)], [(-11.2, -49), (-11, -40), (20, -40), (45, -20), (58, 22)],
        [(0, 56), (10, 64), (22, 90), (28, 109.2)]]
NEUE_STRASSEN = [[tuple(p) for p in linie] for linie in
                 json.load(open(REPO / "daten" / "drachenstein_strassen.json", encoding="utf-8"))["strassen"]]
STRASSEN = [list(map(tuple, w)) for w in WEGE] + NEUE_STRASSEN
STRASSE_HALB = 3.6   # halbe Straßenbreite bis zur Hauswand

# --- Äußerer Mauerring: von der inneren Mauer im Nordosten (Küste) über Nord, West, Süd zurück zur Küste ---
AUSSEN = [(128.8, -63), (112, -150), (100, -250), (40, -282), (-40, -276), (-122, -236), (-168, -158),
          (-182, -60), (-176, 40), (-152, 118), (-92, 182), (-10, 214), (62, 226), (104, 196), (112, 150),
          (103.6, 124.6)]

def schnitt(a, b, c, d):
    """Schnittpunkt der Strecken a-b und c-d als Anteil auf a-b, oder None."""
    (x1, z1), (x2, z2), (x3, z3), (x4, z4) = a, b, c, d
    n = (x1 - x2) * (z3 - z4) - (z1 - z2) * (x3 - x4)
    if abs(n) < 1e-9:
        return None
    t = ((x1 - x3) * (z3 - z4) - (z1 - z3) * (x3 - x4)) / n
    u = -((x1 - x2) * (z1 - z3) - (z1 - z2) * (x1 - x3)) / n
    return t if 0 <= t <= 1 and 0 <= u <= 1 else None

# Tore dort, wo eine hinausführende Straße die Mauer kreuzt
HINAUS = {"Äußeres Nordtor (Nordstraße)": [(0, -200), (30, -320)],
          "Äußeres Südtor (Küstenweg)": [(40, 170), (60, 240)],
          "Westtor (Weg nach Gravemarch)": [(-110, 70), (-150, 70), (-260, 10)]}
AUSSEN_TORE = {}
for torname, linie in HINAUS.items():
    for i in range(len(AUSSEN) - 1):
        for c, d in zip(linie, linie[1:]):
            t = schnitt(AUSSEN[i], AUSSEN[i + 1], c, d)
            if t is not None:
                AUSSEN_TORE[i] = (torname, t, 7.0)

AM = DS + "/Loewenward"
N("Loewenward", "Node3D", DS)
ZINNEN = []   # (x, y, z, gier) für das MultiMesh der Zinnen

def zinnen_auf(x1, z1, x2, z2, oben, aussen_x, aussen_z):
    """Zinnen auf der Außenkante eines Mauerstücks (alle 2,4 m eine)."""
    dx, dz = x2 - x1, z2 - z1
    laenge = math.hypot(dx, dz)
    nx, nz = -dz / laenge, dx / laenge
    if nx * aussen_x + nz * aussen_z < 0:
        nx, nz = -nx, -nz
    g = gier_zu(dx, dz)
    for k in range(int(laenge / 2.4)):
        t = (k + 0.5) / int(laenge / 2.4)
        ZINNEN.append((x1 + dx * t + nx * 0.9, oben + 0.6, z1 + dz * t + nz * 0.9, g))

def ringmauer(name, eltern, punkte, tore, hoehe, mitte):
    """Mauer mit Toren entlang eines Linienzugs; Türme an den Ecken mit Schieferdach."""
    nr = 0
    for i in range(len(punkte) - 1):
        (x1, z1), (x2, z2) = punkte[i], punkte[i + 1]
        laenge = math.hypot(x2 - x1, z2 - z1)
        abschnitte = [(0.0, 1.0)]
        if i in tore:
            _, anteil, breite = tore[i]
            h = breite / 2 / laenge
            abschnitte = [(0.0, anteil - h), (anteil + h, 1.0)]
        for t0, t1 in abschnitte:
            n = max(1, math.ceil(laenge * (t1 - t0) / 18))
            for k in range(n):
                u0 = t0 + (t1 - t0) * k / n; u1 = t0 + (t1 - t0) * (k + 1) / n
                ax, az = x1 + (x2 - x1) * u0, z1 + (z2 - z1) * u0
                bx, bz = x1 + (x2 - x1) * u1, z1 + (z2 - z1) * u1
                werte = [H(ax + (bx - ax) * s / 6, az + (bz - az) * s / 6) for s in range(7)]
                unten = min(werte) - 2.0
                oben = max(max(werte), KAI_OBEN) + hoehe
                nr += 1
                box(f"{name}{nr}", eltern, round((ax + bx) / 2, 2), round((unten + oben) / 2, 2), round((az + bz) / 2, 2),
                    round(math.hypot(bx - ax, bz - az) + 1.2, 2), round(oben - unten, 2), 3.0, "Material_mauer",
                    gier=round(gier_zu(bx - ax, bz - az), 2))
                zinnen_auf(ax, az, bx, bz, oben, (ax + bx) / 2 - mitte[0], (az + bz) / 2 - mitte[1])
    for i, (x, z) in enumerate(punkte[1:-1]):
        boden = H(x, z)
        unten = min(boden, KAI_OBEN) - 2
        oben = max(boden, KAI_OBEN) + hoehe + 5
        zyl(f"{name}Turm{i + 1}", eltern, x, round((unten + oben) / 2, 2), z, 4.2, round(oben - unten, 2), "Material_mauer", 14)
        turmdach(f"{name}Turm{i + 1}Dach", eltern, x, oben, z, 5.0, 7.0)
    for i, (torname, anteil, breite) in tore.items():
        (ax, az), (bx, bz) = punkte[i], punkte[i + 1]
        tx, tz = ax + (bx - ax) * anteil, az + (bz - az) * anteil
        ux, uz = bx - ax, bz - az; ul = math.hypot(ux, uz); ux, uz = ux / ul, uz / ul
        boden = H(tx, tz)
        for seite in (-1, 1):
            px, pz = tx + ux * (breite / 2 + 3) * seite, tz + uz * (breite / 2 + 3) * seite
            box(f"{name}Torturm{i}_{seite}", eltern, round(px, 2), round(boden + 8, 2), round(pz, 2), 6, 22, 6,
                "Material_mauer", gier=round(gier_zu(ux, uz), 2))
            turmdach(f"{name}Torturm{i}_{seite}Dach", eltern, round(px, 2), boden + 19, round(pz, 2), 4.6, 5.5, kanten=4,
                     gier=gier_zu(ux, uz) + 45)
        box(f"{name}Torbogen{i}", eltern, round(tx, 2), round(boden + hoehe + 2.5, 2), round(tz, 2), breite + 0.6, 4, 3.0,
            "Material_mauer", gier=round(gier_zu(ux, uz), 2))
        schild(f"{name}Schild{i}", eltern, round(tx, 2), round(boden + hoehe + 6, 2), round(tz, 2), torname, 44)

def turmdach(name, eltern, x, y, z, r, h, kanten=12, gier=0.0):
    """Spitzes Kegeldach aus Schiefer auf einem Turm (y = Traufe)."""
    N(name, "CSGCylinder3D", eltern, f"""{T(x, round(y + h / 2, 2), z, gier)}
radius = {r}
height = {h}
sides = {kanten}
cone = true
material = SubResource("Material_dach_schiefer")""")

ringmauer("Mauer", AM, AUSSEN, AUSSEN_TORE, 13.0, (0, -20))

# Zinnen und Turmdächer auch auf der inneren Mauer
for i in range(len(ecken) - 1):
    a, b = ecken[i], ecken[i + 1]
    if a is None or b is None:
        continue
    werte = [H(a[0] + (b[0] - a[0]) * s / 6, a[1] + (b[1] - a[1]) * s / 6) for s in range(7)]
    zinnen_auf(a[0], a[1], b[0], b[1], max(max(werte), KAI_OBEN) + 9.0, (a[0] + b[0]) / 2 - 30, (a[1] + b[1]) / 2)
for i, e in enumerate(ecken[1:-2]):
    if e is not None:
        turmdach(f"InnererTurm{i + 1}Dach", AM, e[0], max(H(*e), KAI_OBEN) + 12, e[1], 4.0, 6.0)

# --- Häuserzeilen entlang der Straßen ---
def rechteck(x, z, b, t, gier):
    a = math.radians(gier); c, s = math.cos(a), math.sin(a)
    # lokale Achsen: x' = (c, -s), z' = (s, c) wie in T() (Gier um y)
    return [(x + c * px + s * pz, z - s * px + c * pz) for px, pz in [(-b / 2, -t / 2), (b / 2, -t / 2), (b / 2, t / 2), (-b / 2, t / 2)]]

def ueberlappen(r1, r2):
    """Trennende Achse für zwei konvexe Vierecke."""
    for poly in (r1, r2):
        for i in range(4):
            (x1, z1), (x2, z2) = poly[i], poly[(i + 1) % 4]
            nx, nz = z2 - z1, x1 - x2
            p1 = [nx * x + nz * z for x, z in r1]
            p2 = [nx * x + nz * z for x, z in r2]
            if max(p1) <= min(p2) or max(p2) <= min(p1):
                return False
    return True

def im_vieleck(p, poly):
    x, z = p; innen = False
    for (x1, z1), (x2, z2) in zip(poly, poly[1:] + poly[:1]):
        if (z1 > z) != (z2 > z) and x < x1 + (z - z1) * (x2 - x1) / (z2 - z1):
            innen = not innen
    return innen

INNEN_RING = [e for e in ecken if e is not None]
# Umriss der ganzen Stadt: äußerer Ring, dann die Küstenseite der inneren Mauer zurück zum Anfang
STADT_UMRISS = AUSSEN + INNEN_RING[INNEN_RING.index((103.6, 124.6)) + 1:INNEN_RING.index((128.8, -63))]
SPERRFLAECHEN = [   # Rechtecke (Mitte x, z, Breite, Tiefe, Gier), in denen keine Häuser stehen
    (0, 0, 96, 96, 0), (0, 68, 34, 54, 0), (-59.5, -17, 58, 62, 0),     # Hof, Vorplatz, Drachenhorst
    (68, 2, 34, 36, 0), (80, 38, 26, 16, -20), (70.6, 41.6, 10, 10, 0),  # Markt, Kirche, Kirchturm
    (100, -42, 20, 14, 0), (135, 0, 80, 60, 0), (53.2, -99.4, 16, 16, 0), # Rathaus, Hafen, Ölturm
    (78, -190, 10, 10, 0), (85, 200, 10, 10, 0), (-22, 92, 14, 12, 0),   # Signaltürme, Reiterin am Vorburgtor
]
SPERR = [rechteck(x, z, b, t, g) for x, z, b, t, g in SPERRFLAECHEN]
MAUERN = [AUSSEN, INNEN_RING]

def bauplatz_frei(ecken4, haeuser_ecken):
    if not all(im_vieleck(p, STADT_UMRISS) for p in ecken4):
        return False
    for x, z in ecken4:
        if H(x, z) < -17.0:
            return False
        if min(abstand_linie(m, x, z) for m in MAUERN) < 3.5:
            return False
        if min(abstand_linie(s, x, z) for s in STRASSEN) < STRASSE_HALB - 0.3:
            return False
    mx = sum(p[0] for p in ecken4) / 4; mz = sum(p[1] for p in ecken4) / 4
    if min(abstand_linie(s, mx, mz) for s in STRASSEN) < STRASSE_HALB:
        return False
    if any(ueberlappen(ecken4, r) for r in SPERR):
        return False
    return not any(ueberlappen(ecken4, r) for r in haeuser_ecken)

random.seed(1754)
HAEUSER = []          # (x, y, z, gier, Abstand zur Straße, Form) – für teil_stadtleben.py
_haus_ecken = []
for strasse in STRASSEN:
    for (x1, z1), (x2, z2) in zip(strasse, strasse[1:]):
        dx, dz = x2 - x1, z2 - z1
        laenge = math.hypot(dx, dz)
        ux, uz = dx / laenge, dz / laenge
        for seite in (-1, 1):
            nx, nz = -uz * seite, ux * seite        # von der Straße weg
            s = 2.0
            while s < laenge - 2.0:
                form = random.randrange(24)
                b, t, _ = HAUSFORMEN[form]
                aussen_t = t + 2 * VORKRAGUNG * 3
                if s + b / 2 > laenge - 1.0:
                    break
                d = STRASSE_HALB + t / 2 + VORKRAGUNG * 2
                hx, hz = x1 + ux * (s + b / 2) + nx * d, z1 + uz * (s + b / 2) + nz * d
                # Vorderseite (+z lokal) zeigt zur Straße, also in Richtung -n
                gier = math.degrees(math.atan2(-nx, -nz))
                ecken4 = rechteck(hx, hz, b + 0.1, t + 2 * VORKRAGUNG, gier)
                if bauplatz_frei(ecken4, _haus_ecken):
                    tx, tz = hx - nx * (t / 2), hz - nz * (t / 2)
                    hoehen = [H(x, z) for x, z in ecken4]
                    y = H(tx, tz)
                    if max(hoehen) - y < 3.5:
                        HAEUSER.append((round(hx, 2), round(y, 2), round(hz, 2), round(gier, 1), STRASSE_HALB, form))
                        _haus_ecken.append(ecken4)
                        s += b + random.choice([0.0, 0.0, 0.0, 0.4, 1.5])
                        continue
                s += 1.5

N("Stadthaeuser", "Node3D", DS, "script = ExtResource(\"27_stadthaeuser\")\n"
  + "haeuser = PackedVector4Array(" + ", ".join(f"{x:.5g}, {y:.5g}, {z:.5g}, {g:.4g}" for x, y, z, g, _, _ in HAEUSER) + ")\n"
  + "formen = PackedInt32Array(" + ", ".join(str(f) for *_, f in HAEUSER) + ")")

# Zinnen als MultiMesh: ein Quader je Zinne
S('''[sub_resource type="BoxMesh" id="Mesh_zinne"]
material = SubResource("Material_mauer")
size = Vector3(1.4, 1.2, 0.7)''')
werte = []
for x, y, z, g in ZINNEN:
    c, s_ = math.cos(math.radians(g)), math.sin(math.radians(g))
    werte += [c, 0, s_, x, 0, 1, 0, y, -s_, 0, c, z]
S(f'''[sub_resource type="MultiMesh" id="Zinnen"]
transform_format = 1
instance_count = {len(ZINNEN)}
mesh = SubResource("Mesh_zinne")
buffer = PackedFloat32Array({", ".join(f"{v:.5g}" for v in werte)})''')
N("Zinnen", "MultiMeshInstance3D", DS, 'multimesh = SubResource("Zinnen")')
print("Stadthäuser:", len(HAEUSER), "Zinnen:", len(ZINNEN), "Tore außen:", [t[0] for t in AUSSEN_TORE.values()])

if os.environ.get("BAU_KARTE"):
    # Lageplan zum Prüfen: python3 … mit BAU_NUR_PRUEFEN=1 BAU_KARTE=datei.png
    from PIL import Image, ImageDraw
    x0, z0, m = -200, -300, 2.0
    bild = Image.new("RGB", (int(360 * m), int(560 * m)), (70, 90, 60))
    zeichnung = ImageDraw.Draw(bild)
    P = lambda p: ((p[0] - x0) * m, (p[1] - z0) * m)
    for j in range(0, bild.height, 4):
        for i in range(0, bild.width, 4):
            if H(x0 + i / m, z0 + j / m) < -19.5:
                zeichnung.rectangle([i, j, i + 3, j + 3], fill=(40, 70, 120))
    for r in SPERR:
        zeichnung.polygon([P(p) for p in r], outline=(200, 200, 0))
    for s in STRASSEN:
        zeichnung.line([P(p) for p in s], fill=(150, 130, 100), width=int(STRASSE_HALB * 2 * m))
    for e in _haus_ecken:
        zeichnung.polygon([P(p) for p in e], fill=(190, 90, 70), outline=(60, 30, 20))
    zeichnung.line([P(p) for p in AUSSEN], fill=(230, 230, 230), width=5)
    zeichnung.line([P(p) for p in INNEN_RING], fill=(200, 200, 200), width=4)
    for z in range(-300, 261, 50):
        zeichnung.text(P((x0 + 2, z)), str(z), fill="white")
    for x in range(-200, 161, 50):
        zeichnung.text(P((x, z0 + 2)), str(x), fill="white")
    bild.save(os.environ["BAU_KARTE"])
