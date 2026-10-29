# ---------- Bausteine für Burgen und Städte auf Terrassen: Mauerzüge mit Toren, Türme, Dächer, Zinnen ----------
# Die Mauern stehen auf dem Gelände (H): unten reichen sie unter den tiefsten Punkt beiderseits der Mauer,
# oben stehen sie "hoehe" Meter über dem höchsten. So decken sie die Kanten zwischen zwei Terrassen ab.
# Kreuzt eine Straße (Linienzüge in "strassen") eine Mauer, entsteht dort von selbst ein Tor.

ZINNEN = []   # (x, y, z, gier) für das MultiMesh aller Zinnen (zinnen_schreiben)


def turmdach(name, eltern, x, y, z, r, h, kanten=12, gier=0.0, mat="Material_dach_schiefer"):
    """Spitzes Kegel- oder Pyramidendach (y = Traufe)."""
    N(name, "CSGCylinder3D", eltern, f"""{T(x, round(y + h / 2, 2), z, gier)}
radius = {r}
height = {h}
sides = {kanten}
cone = true
material = SubResource("{mat}")""")


def satteldach(name, eltern, x, y, z, breite, laenge, hoehe, gier=0.0, mat="Material_dach_schiefer"):
    """Satteldach als Prisma: Traufe auf Höhe y, First entlang der lokalen z-Achse, mit Überstand."""
    b = breite / 2 + 0.5
    a = math.radians(gier)
    # CSGPolygon3D zieht nach lokal -z: um die halbe Länge nach lokal +z verschieben
    vx, vz = math.sin(a) * (laenge + 1.0) / 2, math.cos(a) * (laenge + 1.0) / 2
    N(name, "CSGPolygon3D", eltern, f"""{T(round(x + vx, 2), y, round(z + vz, 2), gier)}
polygon = PackedVector2Array({-b}, -0.3, {b}, -0.3, 0, {hoehe})
depth = {laenge + 1.0}
material = SubResource("{mat}")""")


def zinnen_auf(x1, z1, x2, z2, oben, aussen_x, aussen_z, rand=0.9):
    """Zinnen auf der Außenkante eines Mauerstücks (alle 2,4 m eine)."""
    dx, dz = x2 - x1, z2 - z1
    laenge = math.hypot(dx, dz)
    if laenge < 2.4:
        return
    nx, nz = -dz / laenge, dx / laenge
    if nx * aussen_x + nz * aussen_z < 0:
        nx, nz = -nx, -nz
    g = gier_zu(dx, dz)
    n = int(laenge / 2.4)
    for k in range(n):
        t = (k + 0.5) / n
        ZINNEN.append((x1 + dx * t + nx * rand, oben + 0.6, z1 + dz * t + nz * rand, g))


def zinnen_schreiben(eltern):
    """Alle gesammelten Zinnen als ein MultiMesh (ohne Kollision)."""
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
    N("Zinnen", "MultiMeshInstance3D", eltern, 'multimesh = SubResource("Zinnen")')


def _schnitt(a, b, c, d):
    (x1, z1), (x2, z2), (x3, z3), (x4, z4) = a, b, c, d
    n = (x1 - x2) * (z3 - z4) - (z1 - z2) * (x3 - x4)
    if abs(n) < 1e-9:
        return None
    t = ((x1 - x3) * (z3 - z4) - (z1 - z3) * (x3 - x4)) / n
    u = -((x1 - x2) * (z1 - z3) - (z1 - z2) * (x1 - x3)) / n
    return t if 0 <= t <= 1 and 0 <= u <= 1 else None


E("Script", "res://szenen/welt/burgbau.gd", "28_burgbau")
STEINE = {"Material_mauer": "mauer", "Material_basalt": "basalt", "Material_kai": "kai", "Material_hell": "hell",
          "Material_bruchstein": "bruchstein"}


def _zahlen(werte):
    return ", ".join(f"{v:.5g}" for v in werte)


def mauerring(name, eltern, punkte, hoehe, dicke=3.0, geschlossen=False, tore=None, strassen=(), torbreite=6.0,
             turm_r=0.0, turm_extra=5.0, turm_dach=True, mitte=(0, 0), zinnen=True, mat="Material_mauer",
             torname="", hoehe_min=None):
    """Mauer entlang eines Linienzugs (Welt x, z). tore: {Kantenindex: (Anteil, Breite, Name)}; dazu Tore,
    wo Straßen kreuzen. turm_r > 0: Rundtürme an den Ecken. mitte: ein Punkt innerhalb (für die Feldseite).
    Gebaut wird von szenen/welt/burgbau.gd (Anlauf, Gesims, Wehrgang, Zinnen, Rundtürme, Torbögen); hier
    entstehen nur die Maße. Gibt die Liste der Tore zurück: (x, z, Richtung x, Richtung z, Name)."""
    pkt = punkte + [punkte[0]] if geschlossen else list(punkte)
    tore = dict(tore or {})
    for i in range(len(pkt) - 1):
        if i in tore:
            continue
        for s in strassen:
            for c, d in zip(s, s[1:]):
                t = _schnitt(pkt[i], pkt[i + 1], c, d)
                if t is not None and 0.08 < t < 0.92:
                    tore[i] = (t, torbreite, torname)
    mauern, tuerme, torboegen, torbauten = [], [], [], []
    toreliste = []
    for i in range(len(pkt) - 1):
        (x1, z1), (x2, z2) = pkt[i], pkt[i + 1]
        laenge = math.hypot(x2 - x1, z2 - z1)
        if laenge < 0.5:
            continue
        ux, uz = (x2 - x1) / laenge, (z2 - z1) / laenge
        nx, nz = -uz, ux
        abschnitte = [(0.0, 1.0)]
        if i in tore:
            anteil, breite, tname = tore[i]
            h_ = breite / 2 / laenge
            abschnitte = [(0.0, anteil - h_), (anteil + h_, 1.0)]
            toreliste.append((x1 + (x2 - x1) * anteil, z1 + (z2 - z1) * anteil, ux, uz, tname, breite))
        for t0, t1 in abschnitte:
            if t1 - t0 <= 0.001:
                continue
            n = max(1, math.ceil(laenge * (t1 - t0) / 16))
            for k in range(n):
                u0 = t0 + (t1 - t0) * k / n; u1 = t0 + (t1 - t0) * (k + 1) / n
                ax, az = x1 + (x2 - x1) * u0, z1 + (z2 - z1) * u0
                bx, bz = x1 + (x2 - x1) * u1, z1 + (z2 - z1) * u1
                werte = [H(ax + (bx - ax) * s / 4 + nx * o, az + (bz - az) * s / 4 + nz * o)
                         for s in range(5) for o in (-dicke / 2 - 2, 0, dicke / 2 + 2)]
                unten = min(werte) - 2.5
                oben = max(werte) + hoehe
                if hoehe_min is not None:
                    oben = max(oben, hoehe_min)
                mx, mz = (ax + bx) / 2 - mitte[0], (az + bz) / 2 - mitte[1]
                aussen = (nx, nz) if nx * mx + nz * mz > 0 else (-nx, -nz)
                mauern += [ax, az, bx, bz, unten, oben, dicke, aussen[0], aussen[1], 1 if zinnen else 0]
    if turm_r > 0:
        ecken = pkt[:-1] if geschlossen else pkt
        for x, z in ecken:
            werte = [H(x + dx, z + dz) for dx in (-turm_r, 0, turm_r) for dz in (-turm_r, 0, turm_r)]
            unten = min(werte) - 2.5
            oben = max(werte) + hoehe + turm_extra
            tuerme += [x, z, unten, oben, turm_r, 1 if turm_dach else 0, turm_r * 1.8]
    for k, (tx, tz, ux, uz, tname, breite) in enumerate(toreliste):
        nx, nz = -uz, ux
        boden = max(H(tx + ux * s + nx * q, tz + uz * s + nz * q) for s in (-breite, 0, breite) for q in (-4, 0, 4))
        seite = 1 if nx * (tx - mitte[0]) + nz * (tz - mitte[1]) > 0 else -1
        torboegen += [tx, tz, ux, uz, boden, breite, boden + hoehe, dicke]
        for s_ in (-1, 1):
            px, pz = tx + ux * (breite / 2 + 2.6) * s_, tz + uz * (breite / 2 + 2.6) * s_
            unten = min(H(px, pz), boden) - 2.5
            torbauten += [px, pz, ux, uz, unten, boden + hoehe + 6, 5.0, dicke + 2, seite, 1]
        if tname:
            schild(f"{name}Tor{k}Schild", eltern, round(tx, 2), round(boden + hoehe + 4.5, 2), round(tz, 2), tname, 40)
    N(f"{name}Bau", "Node3D", eltern, f"""script = ExtResource("28_burgbau")
mauern = PackedFloat32Array({_zahlen(mauern)})
tuerme = PackedFloat32Array({_zahlen(tuerme)})
tore = PackedFloat32Array({_zahlen(torboegen)})
torbauten = PackedFloat32Array({_zahlen(torbauten)})
stein = \"{STEINE.get(mat, 'mauer')}\"""")
    return [(x, z, ux, uz, n) for x, z, ux, uz, n, _ in toreliste]


WAENDE = {"Material_hell": 1, "Material_mauer": 2, "Material_holz": 3}


def steinbau(name, eltern, x, z, laenge, breite, hoehe, gier=0.0, mat="Material_mauer", dach="Material_dach_schiefer",
             dachhoehe=None, boden=None, kollision=True, art=None):
    """Gebäude mit Satteldach (First entlang der Länge), gebaut von burgbau.gd mit Sockel, Gesimsen, Fenstern,
    Tür und Schornstein. boden: Höhe des Erdgeschosses (sonst Gelände). art: 0 Wohnbau, 1 Kirche/Saal, 2 Lager.
    Gibt die Traufhöhe zurück."""
    a = math.radians(gier)
    ecken = [(x + math.cos(a) * dx + math.sin(a) * dz, z - math.sin(a) * dx + math.cos(a) * dz)
             for dx in (-breite / 2, breite / 2) for dz in (-laenge / 2, laenge / 2)]
    tief = min(H(px, pz) for px, pz in ecken) - 1.5
    b0 = H(x, z) if boden is None else boden
    if art is None:
        art = 1 if hoehe >= 14 and laenge >= 30 else (2 if mat == "Material_holz" else 0)
    werte = [x, z, gier, breite, laenge, b0, tief, hoehe, dachhoehe if dachhoehe is not None else breite * 0.6,
             WAENDE.get(mat, 2), 1 if dach == "Material_dach" else 0, art]
    N(name, "Node3D", eltern, f"""script = ExtResource("28_burgbau")
gebaeude = PackedFloat32Array({_zahlen(werte)})""")
    return b0 + hoehe
