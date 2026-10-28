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


def mauerring(name, eltern, punkte, hoehe, dicke=3.0, geschlossen=False, tore=None, strassen=(), torbreite=6.0,
             turm_r=0.0, turm_extra=5.0, turm_dach=True, mitte=(0, 0), zinnen=True, mat="Material_mauer",
             torname="", hoehe_min=None):
    """Mauer entlang eines Linienzugs (Welt x, z). tore: {Kantenindex: (Anteil, Breite, Name)}; dazu Tore,
    wo Straßen kreuzen. turm_r > 0: Rundtürme an den Ecken. mitte: ein Punkt innerhalb (für die Zinnen).
    Gibt die Liste der Tore zurück: (x, z, Richtung x, Richtung z, Name)."""
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
    stuecke = 0
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
                stuecke += 1
                box(f"{name}{stuecke}", eltern, round((ax + bx) / 2, 2), round((unten + oben) / 2, 2), round((az + bz) / 2, 2),
                    round(math.hypot(bx - ax, bz - az) + dicke * 0.4, 2), round(oben - unten, 2), dicke, mat,
                    gier=round(gier_zu(bx - ax, bz - az), 2))
                if zinnen:
                    zinnen_auf(ax, az, bx, bz, oben, (ax + bx) / 2 - mitte[0], (az + bz) / 2 - mitte[1], dicke * 0.35)
    if turm_r > 0:
        ecken = pkt[:-1] if geschlossen else pkt
        for i, (x, z) in enumerate(ecken):
            werte = [H(x + dx, z + dz) for dx in (-turm_r, 0, turm_r) for dz in (-turm_r, 0, turm_r)]
            unten = min(werte) - 2.5
            oben = max(werte) + hoehe + turm_extra
            zyl(f"{name}Turm{i + 1}", eltern, x, round((unten + oben) / 2, 2), z, turm_r, round(oben - unten, 2), mat, 14)
            if turm_dach:
                turmdach(f"{name}Turm{i + 1}Dach", eltern, x, oben, z, turm_r + 0.8, turm_r * 1.6)
            else:
                for k in range(8):
                    w = 2 * math.pi * k / 8
                    ZINNEN.append((x + math.cos(w) * (turm_r - 0.4), oben + 0.6, z + math.sin(w) * (turm_r - 0.4),
                                   gier_zu(-math.sin(w), math.cos(w))))
    for k, (tx, tz, ux, uz, tname, breite) in enumerate(toreliste):
        boden = max(H(tx + ux * s, tz + uz * s) for s in (-breite, 0, breite))
        for seite in (-1, 1):
            px, pz = tx + ux * (breite / 2 + 2.6) * seite, tz + uz * (breite / 2 + 2.6) * seite
            unten = min(H(px, pz), boden) - 2.5
            hoch = boden + hoehe + 6
            box(f"{name}Tor{k}Turm{seite}", eltern, round(px, 2), round((unten + hoch) / 2, 2), round(pz, 2), 5, round(hoch - unten, 2),
                dicke + 2, mat, gier=round(gier_zu(ux, uz), 2))
            turmdach(f"{name}Tor{k}Turm{seite}Dach", eltern, round(px, 2), hoch, round(pz, 2), 3.8, 4.5, kanten=4,
                     gier=gier_zu(ux, uz) + 45)
        box(f"{name}Tor{k}Bogen", eltern, round(tx, 2), round(boden + 5.2 + 1.8, 2), round(tz, 2), breite + 0.5, 3.6, dicke,
            mat, gier=round(gier_zu(ux, uz), 2))
        if tname:
            schild(f"{name}Tor{k}Schild", eltern, round(tx, 2), round(boden + 10.5, 2), round(tz, 2), tname, 40)
    return [(x, z, ux, uz, n) for x, z, ux, uz, n, _ in toreliste]


def steinbau(name, eltern, x, z, laenge, breite, hoehe, gier=0.0, mat="Material_mauer", dach="Material_dach_schiefer",
             dachhoehe=None, boden=None, kollision=True):
    """Gebäude als Block mit Satteldach (First entlang der Länge). boden: Höhe des Erdgeschosses (sonst Gelände)."""
    a = math.radians(gier)
    ecken = [(x + math.cos(a) * dx + math.sin(a) * dz, z - math.sin(a) * dx + math.cos(a) * dz)
             for dx in (-breite / 2, breite / 2) for dz in (-laenge / 2, laenge / 2)]
    tief = min(H(px, pz) for px, pz in ecken) - 1.5
    b0 = H(x, z) if boden is None else boden
    oben = b0 + hoehe
    box(name, eltern, round(x, 2), round((tief + oben) / 2, 2), round(z, 2), breite, round(oben - tief, 2), laenge, mat,
        gier=round(gier, 2), kollision=kollision)
    satteldach(name + "Dach", eltern, x, round(oben, 2), z, breite, laenge,
               dachhoehe if dachhoehe is not None else breite * 0.6, gier=gier, mat=dach)
    return oben
