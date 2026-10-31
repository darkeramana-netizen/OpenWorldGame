# ---------- 3D-Felsen an den Klippen von Drachenstein (szenen/welt/felsen.gd) ----------
# Fotoscans von Poly Haven (modelle/felsen/, CC0). Gesucht werden Steilhänge außerhalb der Burgen, der Stadt und des
# Hafens: unter der Ringmauer zum Meer und ins Tal, und die Felsstufen zwischen den Burghöfen. Je nach Höhe der Wand
# kommt ein großes Klippenstück, ein kleineres Felsstück oder ein Brocken; die Front zeigt hangabwärts. Auf Absätzen
# bei den Felsen wachsen Farn, Gras und Moos (modelle/pflanzen/).
# Wird aus region_drachenstein.py nach teil_drachenstein.py ausgeführt (H, PD, W, abstand_linie, im_vieleck).

E("Script", "res://szenen/welt/felsen.gd", "30_felsen")
FELSMODELLE = [
    # Pfad, Breite, Höhe (Meter, Front nach +z)
    ("res://modelle/felsen/coastal_cliff_02/coastal_cliff_02.gltf", 40.9, 10.1),
    ("res://modelle/felsen/namaqualand_cliff_02/namaqualand_cliff_02.gltf", 20.2, 7.2),
    ("res://modelle/felsen/coastal_cliff_04/coastal_cliff_04.gltf", 86.8, 11.0),
    ("res://modelle/felsen/rock_face_02/rock_face_02.gltf", 2.7, 2.5),
] + [(f"res://modelle/felsen/rock_moss_set_02/rock_moss_set_02.gltf#{k}", 1.8, 0.9) for k in range(7)]
GROSS, MITTEL, RIESIG, STUECK = 0, 1, 2, 3
BROCKEN = list(range(4, 11))
# Bewuchs auf den Absätzen der Klippen (modelle/pflanzen/): Farn, Grasbüschel, Moospolster
FARN = len(FELSMODELLE)
FELSMODELLE += [(f"res://modelle/pflanzen/fern_02/fern_02.gltf#{k}", 0, 0) for k in range(4)]
GRAS = len(FELSMODELLE)
FELSMODELLE += [(f"res://modelle/pflanzen/grass_medium_01/grass_medium_01.gltf#{k}", 0, 0) for k in range(17)]
MOOS = len(FELSMODELLE)
FELSMODELLE += [(f"res://modelle/pflanzen/moss_01/moss_01.gltf#{k}", 0, 0) for k in range(12)]
# Tönung: Die Scans aus Südafrika (namaqualand) und das Felsstück sind rötlich, sie passen sich dem grauen Fels an
FARBEN = {MITTEL: "0.74, 0.78, 0.86, 1", STUECK: "0.82, 0.85, 0.9, 1"}

random.seed(4711)
_frei = [WL(PD.VORBURG), WL(PD.BURGHOF2), WL(PD.BURGHOF3), WL(PD.KERNBURG), WL(PD.STADT), WL(PD.HAFEN_BEZIRK),
         WL(PD.FELSENHAFEN)]
_mauern = [WL(PD.RINGMAUER + PD.RINGMAUER[:1]), WL(PD.VORBURG + PD.VORBURG[:1]), WL(PD.BURGHOF2 + PD.BURGHOF2[:1]),
           WL(PD.BURGHOF3), WL(PD.KERNBURG + PD.KERNBURG[:1]), WL(PD.ZWINGER_KERNBURG), WL(PD.STADTMAUER),
           WL(PD.HAFENMAUER_OST)]
_wege = [WL(w) for w in PD.BURGWEGE]


def _gefaelle(x, z):
    """Hangabwärts-Richtung und Steilheit."""
    gx = (H(x + 1.5, z) - H(x - 1.5, z)) / 3.0
    gz = (H(x, z + 1.5) - H(x, z - 1.5)) / 3.0
    s = math.hypot(gx, gz)
    return (-gx / s, -gz / s, s) if s > 1e-6 else (0.0, 0.0, 0.0)


def _abstand(p, linien):
    return min(abstand_linie(l, *p) for l in linien)


kandidaten = []
for x in range(-150, 330, 3):
    for z in range(-330, 330, 3):
        px, pz = x + random.uniform(-1, 1), z + random.uniform(-1, 1)
        dx, dz, s = _gefaelle(px, pz)
        if s < 1.0 or H(px, pz) < -26:
            continue
        if any(im_vieleck((px, pz), v) for v in _frei):
            continue
        if _abstand((px, pz), _mauern) < 4.5 or _abstand((px, pz), _wege) < 7.0:
            continue
        oben = max(H(px - dx * d, pz - dz * d) for d in (3, 6, 10, 14))
        unten = min(H(px + dx * d, pz + dz * d) for d in (3, 6, 10, 14))
        kandidaten.append((oben - unten, px, pz, dx, dz, oben, unten))
kandidaten.sort(reverse=True)

# In Lagen über die ganze Wand: Jedes Stück sitzt mit seiner Mitte auf dem Hang, so groß wie die Wand an dieser Stelle
# (höchstens etwa 20 m hoch), und wird zur Hangneigung nach hinten gekippt. Abstände zählen auch in der Höhe.
FELSSTUECKE = []
_gesetzt = []   # (x, y, z, Radius)
for hoehe, px, pz, dx, dz, oben, unten in kandidaten:
    if hoehe > 18:
        m = random.choice([GROSS, GROSS, GROSS, MITTEL, RIESIG])
    elif hoehe > 7:
        m = random.choice([GROSS, MITTEL])
    elif hoehe > 2.5:
        m = STUECK
    else:
        m = random.choice(BROCKEN)
    _, breite, mh = FELSMODELLE[m]
    groesse = max(0.6, min(hoehe * 0.8, 20.0) / mh)
    groesse = min(groesse, 1.6 if m == RIESIG else 2.6)
    h0 = H(px, pz)
    y = h0 - mh * groesse * 0.5
    radius = breite * groesse * 0.38
    if any(math.dist((px, y * 1.6, pz), (qx, qy * 1.6, qz)) < max(radius, r) * 0.8 for qx, qy, qz, r in _gesetzt):
        continue
    # nicht über die obere Kante hinaus (dort stehen die Mauern)
    if y + mh * groesse > oben + 0.5:
        groesse = (oben + 0.5 - y) / mh
        if groesse < 0.5:
            continue
    # die ganze Breite muss am Steilhang liegen, sonst ragt das Stück über das Ende der Klippe auf flaches Land
    for _ in range(4):
        halb = breite * groesse * 0.4
        if all(_gefaelle(px - dz * t * halb, pz + dx * t * halb)[2] > 0.7 for t in (-1.0, -0.5, 0.5, 1.0)):
            break
        groesse *= 0.7
    else:
        continue
    y = h0 - mh * groesse * 0.5
    neigung = max(0.0, min(30.0, 90.0 - math.degrees(math.atan(_gefaelle(px, pz)[2])))) * 0.7
    gier = math.degrees(math.atan2(dx, dz)) + random.uniform(-15, 15)
    FELSSTUECKE.append((m, round(px, 2), round(y, 2), round(pz, 2), round(gier, 1), round(neigung + random.uniform(-4, 4), 1),
                        round(groesse, 2)))
    _gesetzt.append((px, y, pz, radius))

# Bewuchs: auf Absätzen und Kanten bei den Felsen (nicht zu steil), Farn und Gras in Gruppen, dazu Moos und Brocken
_felsen = [(x, z) for m, x, y, z, *_ in FELSSTUECKE if m in (GROSS, MITTEL, RIESIG)]
_bewuchs = 0
for x in range(-150, 330, 2):
    for z in range(-330, 330, 2):
        px, pz = x + random.uniform(-0.9, 0.9), z + random.uniform(-0.9, 0.9)
        dx, dz, s = _gefaelle(px, pz)
        h0 = H(px, pz)
        if not 0.2 < s < 0.85 or h0 < -18.5 or random.random() > 0.45:
            continue
        if not any(abs(px - fx) < 22 and abs(pz - fz) < 22 for fx, fz in _felsen):
            continue
        if any(im_vieleck((px, pz), v) for v in _frei) or _abstand((px, pz), _mauern) < 3.0 or _abstand((px, pz), _wege) < 4.5:
            continue
        wurf = random.random()
        if wurf < 0.35:
            m, g = FARN + random.randrange(4), random.uniform(0.9, 1.5)
        elif wurf < 0.8:
            m, g = GRAS + random.randrange(17), random.uniform(0.8, 1.3)
        elif wurf < 0.95:
            m, g = MOOS + random.randrange(12), random.uniform(2.5, 4.5)
        else:
            m, g = random.choice(BROCKEN), random.uniform(0.8, 1.8)
        FELSSTUECKE.append((m, round(px, 2), round(h0 - 0.08, 2), round(pz, 2), round(random.uniform(0, 360), 1), 0.0, round(g, 2)))
        _bewuchs += 1

N("Felsen", "Node3D", DS, f"""script = ExtResource("30_felsen")
modelle = PackedStringArray({", ".join(f'"{p}"' for p, _, _ in FELSMODELLE)})
farben = PackedColorArray({", ".join(FARBEN.get(m, "1, 1, 1, 1") for m in range(len(FELSMODELLE)))})
stuecke = PackedFloat32Array({", ".join(f"{v:.6g}" for st in FELSSTUECKE for v in st)})""")
print("Felsen:", len(FELSSTUECKE) - _bewuchs, "aus", len(kandidaten), "Steilstellen, Bewuchs:", _bewuchs,
      {FELSMODELLE[m][0].split("/")[-1]: sum(1 for s in FELSSTUECKE if s[0] == m) for m in range(4)})
