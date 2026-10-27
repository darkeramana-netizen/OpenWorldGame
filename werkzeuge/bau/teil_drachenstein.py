# ---------- Burgfeste Drachenstein nach dem Grundriss ----------
# Gedreht: Süden des Plans liegt im Osten der Welt, der Hafen öffnet sich zum Wächtermeer.
# Der Hof (BurgHof) ist die Mittlere Burg, westlich davon liegt die Oberer Burg (Drachenhorst).
DS = "Drachenstein"
N(DS, "Node3D", ".")

# --- Oberer Burg (Drachenhorst) auf Höhe 8 ---
OB = DS + "/ObererBurg"
N("ObererBurg", "Node3D", DS, T(0, 8, 0))
X0, X1, Z0, Z1 = -86, -33.5, -45, 11
box("MauerNord", OB, (X0+X1)/2, 1.5, Z0, X1-X0+2.5, 9, 2.5, "Material_mauer")
box("MauerWest", OB, X0, 1.5, (Z0+Z1)/2, 2.5, 9, Z1-Z0, "Material_mauer")
box("MauerSuedWest", OB, (X0-52.5)/2, 1.5, Z1, -52.5-X0+1.25, 9, 2.5, "Material_mauer")
box("MauerSuedOst", OB, (-47.5+X1)/2, 1.5, Z1, X1+47.5+1.25, 9, 2.5, "Material_mauer")
box("TorturmWest", OB, -54, 3, Z1, 4, 12, 4, "Material_mauer")
box("TorturmOst", OB, -46, 3, Z1, 4, 12, 4, "Material_mauer")
box("Torbogen", OB, -50, 7.5, Z1, 4, 3, 2.5, "Material_mauer")
schild("SchildTor", OB, -50, 10.5, Z1 + 2, "Tor zur Oberer Burg", 40)
# Brüstung zur Hofmauer mit Durchlass auf den Wehrgang
box("BruestungNord", OB, -34.6, 0.6, (Z0 + -12)/2, 0.6, 1.2, -12 - Z0, "Material_mauer")
box("BruestungSued", OB, -34.6, 0.6, (-7 + Z1)/2, 0.6, 1.2, Z1 + 7, "Material_mauer")
box("Urkern", OB, -62, 15, -17, 12, 30, 12, "Material_basalt")
schild("Schild", OB, -62, 33, -17, "Oberer Burg · Drachenhorst")
zyl("Aussichtsplattform", OB, -86, 8, -17, 4.5, 20, "Material_mauer", 12)
box("Palas", OB, -46, 4.5, -36, 18, 9, 10, "Material_hell")
box("Kapelle", OB, -76, 3.5, -36, 10, 7, 9, "Material_hell")
box("Zeughaus", OB, -76, 3, 1, 12, 6, 8, "Material_mauer")
for i, (x, z) in enumerate([(X0, Z0), (X1, Z0), (X0, Z1), (X1, Z1)]):
    zyl(f"Eckturm{i+1}", OB, x, 4, z, 3, 14, "Material_mauer", 10)
# Übungsplatz mit zwei Puppen für Säbel und Muskete
for k, x in enumerate([-44, -39]):
    gegner(f"Uebungspuppe{k + 1}", OB, x, 0, -14, "Übungspuppe", waffe="puppe", tracht="0.55, 0.45, 0.3, 1")
schild("SchildUebungsplatz", OB, -41.5, 3.5, -10, "Übungsplatz", 40)

# --- Ringmauer der Stadt (Löwenward) ---
RM = DS + "/Ringmauer"
N("Ringmauer", "Node3D", DS)
VORBURGTOR = 1  # Kante mit dem Tor
# Tore in der Ringmauer: Kante → (Name, Lage auf der Kante, Breite). Nordtor und Südtor führen zu den Landstraßen.
TORE = {VORBURGTOR: ("Vorburgtor", 0.827, 7.0), 2: ("Südtor (Küstenweg)", 0.5, 6.0), 14: ("Nordtor (Nordstraße)", 0.5, 6.0)}
ecken = [(-86, 11), (-40.6, 47.6), (-8.4, 91), (64.4, 127.4), (103.6, 124.6), (120.4, 93.8), (140, 57.4),
         (152, 24.5), None, (150, -28), (128.8, -63), (95.2, -88.2), (53.2, -99.4), (22.4, -77), (8.4, -54.6),
         (-30.8, -43.4), (-33.5, -45)]
stueck_nr = 0
def mauerstueck(x1, z1, x2, z2):
    global stueck_nr
    dx, dz = x2 - x1, z2 - z1
    laenge = math.hypot(dx, dz)
    werte = [H(x1 + dx*t/8, z1 + dz*t/8) for t in range(9)]
    unten = min(werte) - 2.0
    oben = max(max(werte), KAI_OBEN) + 9.0
    stueck_nr += 1
    box(f"Mauer{stueck_nr}", RM, round((x1+x2)/2, 2), round((unten+oben)/2, 2), round((z1+z2)/2, 2),
        round(laenge + 1.2, 2), round(oben - unten, 2), 2.5, "Material_mauer", gier=round(gier_zu(dx, dz), 2))
    return oben
KAI_OBEN = -17.8
def mauerkante(a, b, luecke=None):
    """Mauer von a nach b in Stücken bis 20 m; luecke = (Anteil, Breite) für ein Tor."""
    (x1, z1), (x2, z2) = a, b
    laenge = math.hypot(x2 - x1, z2 - z1)
    abschnitte = [(0.0, 1.0)]
    if luecke:
        mitte, breite = luecke
        h = breite / 2 / laenge
        abschnitte = [(0.0, mitte - h), (mitte + h, 1.0)]
    for t0, t1 in abschnitte:
        n = max(1, math.ceil(laenge * (t1 - t0) / 20))
        for k in range(n):
            u0 = t0 + (t1 - t0) * k / n; u1 = t0 + (t1 - t0) * (k + 1) / n
            mauerstueck(x1 + (x2-x1)*u0, z1 + (z2-z1)*u0, x1 + (x2-x1)*u1, z1 + (z2-z1)*u1)
for i in range(len(ecken) - 1):
    a, b = ecken[i], ecken[i+1]
    if a is None or b is None:
        continue
    mauerkante(a, b, TORE[i][1:] if i in TORE else None)
# Ecktürme
for i, e in enumerate(ecken[1:-2]):
    if e is None:
        continue
    boden = H(*e)
    unten = min(boden, KAI_OBEN) - 2
    oben = max(boden, KAI_OBEN) + 12
    zyl(f"Turm{i+1}", RM, e[0], round((unten+oben)/2, 2), e[1], 3.2, round(oben-unten, 2), "Material_mauer", 10)
# Ölturm an der Nordspitze
oel = (53.2, -99.4)
zyl("Oelturm", RM, oel[0], round(H(*oel) + 8, 2), oel[1], 5, 22, "Material_mauer", 12)
schild("SchildOelturm", RM, oel[0], round(H(*oel) + 21, 2), oel[1], "Ölturm", 48)
# Tortürme und Bögen: Vorburgtor (Weg nach Gravemarch), Nordtor und Südtor (Landstraßen)
for kante, (torname, anteil, breite) in TORE.items():
    (ax, az), (bx, bz) = ecken[kante], ecken[kante + 1]
    tor = (ax + (bx-ax)*anteil, az + (bz-az)*anteil)
    ux, uz = (bx-ax), (bz-az); ul = math.hypot(ux, uz); ux, uz = ux/ul, uz/ul
    torboden = H(*tor)
    vor = "" if kante == VORBURGTOR else f"Tor{kante}"
    for seite, name in [(-1, "TorturmWest"), (1, "TorturmOst")]:
        box(vor + name, RM, round(tor[0] + ux*(breite/2 + 2)*seite, 2), round(torboden + 5, 2), round(tor[1] + uz*(breite/2 + 2)*seite, 2),
            5, 16, 5, "Material_mauer", gier=round(gier_zu(ux, uz), 2))
    box(vor + "Torbogen", RM, round(tor[0], 2), round(torboden + 10.5, 2), round(tor[1], 2), breite + 0.4, 3, 2.5, "Material_mauer",
        gier=round(gier_zu(ux, uz), 2))
    schild("Schild" + (vor or "Vorburgtor"), RM, round(tor[0] - uz*2, 2), round(torboden + 13.5, 2), round(tor[1] + ux*2, 2), torname, 48)

# --- Hafen (Drachenkai) im Osten ---
HF = DS + "/Drachenkai"
N("Drachenkai", "Node3D", DS)
# Kaimauern um das Becken (Oberkante -17.8), sie decken die steilen Geländekanten ab
box("KaimauerNord", HF, 134, -22.9, -18.75, 66, 10.2, 2.5, "Material_kai")
box("KaimauerSued", HF, 134, -22.9, 16.25, 66, 10.2, 2.5, "Material_kai")
box("KaimauerWest", HF, 101.25, -22.9, -1.25, 2.5, 10.2, 37.5, "Material_kai")
box("MoleNord", HF, 160, -22.9, -24.5, 14, 10.2, 9, "Material_kai")
box("MoleSued", HF, 160, -22.9, 21, 14, 10.2, 7.5, "Material_kai")
zyl("Hafentor", HF, 165, -11, -23.5, 3.5, 22, "Material_mauer", 10)
zyl("Schiffstor", HF, 165, -11, 20, 3.5, 22, "Material_mauer", 10)
schild("SchildHafentor", HF, 165, 1.5, -23.5, "Hafentor", 40)
schild("SchildSchiffstor", HF, 165, 1.5, 20, "Schiffstor", 40)
box("Zollhaus", HF, 154, -15.3, -24.5, 10, 5, 6, "Material_hell")
schild("SchildZoll", HF, 154, -11.5, -21, "Zollhaus", 40)
box("Dockspeicher", HF, 114, -14.3, -24.5, 16, 7, 6.5, "Material_holz")
for i, (x, z, g) in enumerate([(118, -8, 4), (140, 6, -6), (152, -9, 10)]):
    box(f"Schiff{i+1}", HF, x, -19.6, z, 16, 3, 5, "Material_holz", gier=g)
    zyl(f"Mast{i+1}", HF, x, -10, z, 0.3, 16, "Material_holz", 6, False)
for i, x in enumerate([108, 126, 144]):
    zyl(f"Poller{i+1}", HF, x, -17.3, 15.6, 0.3, 1.0, "Material_metall", 8)
schild("SchildKai", HF, 130, -9, -1, "Drachenkai")

# --- Marktplatz, Kirche, Rathaus ---
MK = DS + "/Marktplatz"
N("Marktplatz", "Node3D", DS)
mb = H(68, 2)
zyl("Brunnen", MK, 68, round(mb + 0.4, 2), 2, 2.4, 1.2, "Material_hell", 12)
zyl("BrunnenWasser", MK, 68, round(mb + 0.95, 2), 2, 2.0, 0.1, "Material_wasser_becken", 12, False)
for i, (x, z) in enumerate([(60, -8), (72, -9), (62, 13), (76, 12)]):
    y = H(x, z)
    box(f"Stand{i+1}", MK, x, round(y + 0.5, 2), z, 3, 1.0, 2, "Material_holz")
    box(f"StandDach{i+1}", MK, x, round(y + 2.4, 2), z, 3.4, 0.15, 2.4, "Material_stoff", kollision=False)
schild("SchildMarkt", MK, 68, round(mb + 6, 2), 2, "Marktplatz")

def gebaeude(name, x, z, sx, sy, sz, mat, gier=0.0):
    lo, hi = H_bereich(x, z, sx/2, sz/2, gier)
    unten = lo - 1.5
    oben = hi + sy
    box(name, DS, x, round((unten+oben)/2, 2), z, sx, round(oben-unten, 2), sz, mat, gier=gier)
    return hi
kh = gebaeude("KircheStGeorg", 80, 38, 20, 10, 10, "Material_hell", gier=-20)
lo, hi = H_bereich(70, 42, 3, 3)
box("Kirchturm", DS, 70.6, round((lo - 1 + hi + 26)/2, 2), 41.6, 6, round(hi + 26 - lo + 1, 2), 6, "Material_hell")
schild("SchildKirche", DS, 70.6, round(hi + 28, 2), 41.6, "Kirche St. Georg", 48)
rh = gebaeude("Rathaus", 100, -42, 16, 10, 10, "Material_hell")
schild("SchildRathaus", DS, 100, round(rh + 12, 2), -42, "Rathaus", 48)

# --- Stadthäuser auf einem Raster innerhalb der Ringmauer ---
ring = [e for e in ecken if e is not None]
def im_ring(x, z):
    innen = False
    for i in range(len(ring)):
        (x1, z1), (x2, z2) = ring[i], ring[(i+1) % len(ring)]
        if (z1 > z) != (z2 > z) and x < x1 + (z - z1) * (x2 - x1) / (z2 - z1):
            innen = not innen
    return innen
WEGE = [[(0, 40), (0, 56), (44, 46), (58, 22), (75, 4), (98, 0)], [(0, 56), (-25, 52), (-50, 18), (-50, 8)],
        [(0, 80), (-60, 95)], [(-11.2, -49), (-11, -40), (20, -40), (45, -20), (58, 22)],
        [(0, 56), (10, 64), (22, 90), (28, 109.2)]]
FREI = [(-44, -44, 44, 44), (-18, 36, 18, 92), (-90, -50, -30, 16), (88, -32, 170, 28), (50, -16, 88, 22),
        (64, 24, 94, 52), (90, -52, 112, -30)]
SH = DS + "/Stadthaeuser"
N("Stadthaeuser", "Node3D", DS)
random.seed(1750)
anzahl = 0
HAEUSER = []   # (x, y, z, gier, Abstand zum Weg) für die Wohnungen der Stadtleute (teil_stadtleben.py)
gaerten = 0
GARTENMAUER = [(-86, 11), (-40.6, 47.6), (-8.4, 91), (64.4, 127.4)]
S('''[sub_resource type="StandardMaterial3D" id="Material_garten"]
albedo_color = Color(0.3, 0.42, 0.2, 1)
roughness = 1.0''')
for gx in range(-80, 160, 13):
    for gz in range(-100, 130, 13):
        x = gx + random.uniform(-2, 2); z = gz + random.uniform(-2, 2)
        if not im_ring(x, z) or any(a <= x <= c and b <= z <= d for a, b, c, d in FREI):
            continue
        if min(abstand_linie(ring + [ring[0]], x, z), min(abstand_linie(w, x, z) for w in WEGE)) < 8:
            continue
        # Tür zum nächsten Weg drehen (auf 90° gerastert)
        naechst = min(WEGE, key=lambda w: abstand_linie(w, x, z))
        best = None
        for (x1, z1), (x2, z2) in zip(naechst, naechst[1:]):
            dx, dz = x2-x1, z2-z1
            t = max(0, min(1, ((x-x1)*dx + (z-z1)*dz) / (dx*dx + dz*dz)))
            px, pz = x1 + dx*t, z1 + dz*t
            if best is None or math.hypot(px-x, pz-z) < best[0]:
                best = (math.hypot(px-x, pz-z), px, pz)
        gier = round(math.degrees(math.atan2(best[1] - x, best[2] - z)) / 90) * 90
        lo, hi = H_bereich(x, z, 5, 5, gier)
        if hi - lo > 4.0 or lo < -19.0:
            continue
        y = min(lo + 1.8, (lo + hi) / 2)
        if abstand_linie(GARTENMAUER, x, z) < 24:
            # Terrassengärten (36, 37) an der Ringmauer im Süden, wie im Plan
            gaerten += 1
            box(f"Garten{gaerten}", SH, round(x, 2), round(lo - 0.6 + 0.35, 2), round(z, 2), 9, 1.2, 9, "Material_garten", gier=gier)
            continue
        anzahl += 1
        HAEUSER.append((x, y, z, gier, best[0]))
        N(f"Haus{anzahl}", None, SH, T(round(x, 2), round(y, 2), round(z, 2), gier, 1, 1 + 0.15*(anzahl % 3), 1),
          instanz="12_haus")
print("Stadthäuser:", anzahl, "Gärten:", gaerten)
schild("SchildGaerten", DS, 20, round(H(20, 72) + 4, 2), 72, "Terrassengärten", 40)
