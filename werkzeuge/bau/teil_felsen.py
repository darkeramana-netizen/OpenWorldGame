# ---------- 3D-Felsen an den Klippen von Drachenstein (szenen/welt/felsen.gd) ----------
# Fotoscans von Poly Haven (modelle/felsen/, CC0). Gesucht werden Steilhänge außerhalb der Burgen, der Stadt und des
# Hafens: unter der Ringmauer zum Meer und ins Tal, und die Felsstufen zwischen den Burghöfen. Je nach Höhe der Wand
# kommt ein großes Klippenstück, ein kleineres Felsstück oder ein Brocken; die Front zeigt hangabwärts.
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

FELSSTUECKE = []
_gesetzt = []   # (x, z, Radius)
for hoehe, px, pz, dx, dz, oben, unten in kandidaten:
    if hoehe > 16:
        m = random.choice([GROSS, GROSS, MITTEL, RIESIG])
    elif hoehe > 6:
        m = random.choice([MITTEL, MITTEL, GROSS])
    elif hoehe > 2.5:
        m = STUECK
    else:
        m = random.choice(BROCKEN)
    _, breite, mh = FELSMODELLE[m]
    groesse = max(0.6, min(3.2 if m != RIESIG else 2.0, hoehe * 0.95 / mh))
    radius = breite * groesse * 0.42
    if any(math.dist((px, pz), (qx, qz)) < max(radius, r) * 0.85 for qx, qz, r in _gesetzt):
        continue
    # Fuß unter dem unteren Rand, die Oberkante nicht über die Kante oben (dort stehen die Mauern)
    y = unten - mh * groesse * 0.12
    groesse = min(groesse, (oben + 0.3 - y) / mh)
    if groesse < 0.5:
        continue
    gier = math.degrees(math.atan2(dx, dz)) + random.uniform(-12, 12)
    FELSSTUECKE.append((m, round(px, 2), round(y, 2), round(pz, 2), round(gier, 1), round(random.uniform(0, 8), 1),
                        round(groesse, 2)))
    _gesetzt.append((px, pz, breite * groesse * 0.42))

N("Felsen", "Node3D", DS, f"""script = ExtResource("30_felsen")
modelle = PackedStringArray({", ".join(f'"{p}"' for p, _, _ in FELSMODELLE)})
stuecke = PackedFloat32Array({", ".join(f"{v:.6g}" for st in FELSSTUECKE for v in st)})""")
print("Felsen:", len(FELSSTUECKE), "aus", len(kandidaten), "Steilstellen",
      {FELSMODELLE[m][0].split("/")[-1]: sum(1 for s in FELSSTUECKE if s[0] == m) for m in range(4)})
