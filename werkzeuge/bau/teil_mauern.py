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


MAUERSTUECKE = []   # (Name, ax, az, bx, bz, Wehrgang, Dicke, außen) aller Mauerstücke, z. B. für Wachen auf der Mauer


def _drin_poly(q, poly):
    x, z = q; innen = False
    for (x1, z1), (x2, z2) in zip(poly, poly[1:] + poly[:1]):
        if (z1 > z) != (z2 > z) and x < x1 + (z - z1) * (x2 - x1) / (z2 - z1):
            innen = not innen
    return innen


def mauerring(name, eltern, punkte, hoehe, dicke=3.0, geschlossen=False, tore=None, strassen=(), torbreite=6.0,
             turm_r=0.0, turm_extra=5.0, turm_dach=True, mitte=(0, 0), zinnen=True, mat="Material_mauer",
             torname="", hoehe_min=None, oben_fest=None, aussparen=(), tor_regel="offen"):
    """Mauer entlang eines Linienzugs (Welt x, z). tore: {Kantenindex: (Anteil, Breite, Name)}; dazu Tore,
    wo Straßen kreuzen. turm_r > 0: Rundtürme an den Ecken. mitte: ein Punkt innerhalb (für die Feldseite).
    Gebaut wird von szenen/welt/burgbau.gd (Anlauf, Gesims, Wehrgang, Zinnen, Rundtürme, Torbögen); hier
    entstehen nur die Maße. Gibt die Liste der Tore zurück: (x, z, Richtung x, Richtung z, Name).
    oben_fest: Mauerkrone auf genau dieser Höhe (Kaimauern bündig mit dem Kai).
    aussparen: Vielecke (Welt), in denen keine Mauer steht (dort steht z. B. ein begehbarer Turm mit eigenen Mauern).
    tor_regel: Torflügel aller Tore ohne eigene Regel (szenen/welt/fluegel.gd: "offen", "tag", "zu", mit ":Bedingung")."""
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
            anteil, breite, tname = tore[i][:3]
            boden_fest = tore[i][3] if len(tore[i]) > 3 else None   # z. B. ein Wassertor auf dem Wasser
            mit_tuermen = tore[i][4] if len(tore[i]) > 4 else boden_fest is None
            regel = tore[i][5] if len(tore[i]) > 5 and tore[i][5] else tor_regel
            h_ = (breite / 2 + dicke / 2) / laenge     # die Mauerstücke überlappen an ihren Enden um die halbe Dicke
            abschnitte = [(0.0, anteil - h_), (anteil + h_, 1.0)]
            toreliste.append((x1 + (x2 - x1) * anteil, z1 + (z2 - z1) * anteil, ux, uz, tname, breite, boden_fest, mit_tuermen, regel))
        for t0, t1 in abschnitte:
            if t1 - t0 <= 0.001:
                continue
            nah = any(min(math.dist(q_, (x1 + (x2 - x1) * f_, z1 + (z2 - z1) * f_)) for f_ in (0, 0.25, 0.5, 0.75, 1))
                      < laenge + 30 for poly_ in aussparen for q_ in poly_)
            n = max(1, math.ceil(laenge * (t1 - t0) / (1.0 if nah else 16)))
            for k in range(n):
                u0 = t0 + (t1 - t0) * k / n; u1 = t0 + (t1 - t0) * (k + 1) / n
                ax, az = x1 + (x2 - x1) * u0, z1 + (z2 - z1) * u0
                bx, bz = x1 + (x2 - x1) * u1, z1 + (z2 - z1) * u1
                if any(_drin_poly(((ax + bx) / 2, (az + bz) / 2), poly_) for poly_ in aussparen):
                    continue
                werte = [H(ax + (bx - ax) * s / 4 + nx * o, az + (bz - az) * s / 4 + nz * o)
                         for s in range(5) for o in (-dicke / 2 - 2, 0, dicke / 2 + 2)]
                unten = min(werte) - 2.5
                oben = max(werte) + hoehe
                if hoehe_min is not None:
                    oben = max(oben, hoehe_min)
                if oben_fest is not None:
                    oben = oben_fest
                mx, mz = (ax + bx) / 2 - mitte[0], (az + bz) / 2 - mitte[1]
                aussen = (nx, nz) if nx * mx + nz * mz > 0 else (-nx, -nz)
                mauern += [ax, az, bx, bz, unten, oben, dicke, aussen[0], aussen[1], 1 if zinnen else 0]
                MAUERSTUECKE.append((name, ax, az, bx, bz, oben, dicke, aussen))
    if turm_r > 0:
        ecken = pkt[:-1] if geschlossen else pkt
        for x, z in ecken:
            werte = [H(x + dx, z + dz) for dx in (-turm_r, 0, turm_r) for dz in (-turm_r, 0, turm_r)]
            unten = min(werte) - 2.5
            oben = max(werte) + hoehe + turm_extra
            tuerme += [x, z, unten, oben, turm_r, 1 if turm_dach else 0, turm_r * 1.8]
    regeln = []
    for k, (tx, tz, ux, uz, tname, breite, boden_fest, mit_tuermen, regel) in enumerate(toreliste):
        regeln.append(regel)
        nx, nz = -uz, ux
        rings = [H(tx + ux * s + nx * q, tz + uz * s + nz * q) for s in (-breite, 0, breite) for q in (-4, 0, 4)]
        boden = max(rings) if boden_fest is None else boden_fest
        seite = 1 if nx * (tx - mitte[0]) + nz * (tz - mitte[1]) > 0 else -1
        # Der Torbau reicht so hoch wie die Mauer daneben, sonst bleibt über dem Bogen eine Lücke
        oben_tor = max(boden + hoehe, max(rings) + hoehe)
        torboegen += [tx, tz, ux, uz, boden, breite, oben_tor, dicke]
        for s_ in ((-1, 1) if mit_tuermen else ()):   # ein Wassertor unten in der Mauer hat keine Tortürme
            px, pz = tx + ux * (breite / 2 + 2.6) * s_, tz + uz * (breite / 2 + 2.6) * s_
            unten = min(H(px, pz), boden) - 2.5
            torbauten += [px, pz, ux, uz, unten, oben_tor + 6, 5.0, dicke + 2, seite, 1]
        if tname:
            schild(f"{name}Tor{k}Schild", eltern, round(tx, 2), round(boden + hoehe + 4.5, 2), round(tz, 2), tname, 40)
    N(f"{name}Bau", "Node3D", eltern, f"""script = ExtResource("28_burgbau")
mauern = PackedFloat32Array({_zahlen(mauern)})
tuerme = PackedFloat32Array({_zahlen(tuerme)})
tore = PackedFloat32Array({_zahlen(torboegen)})
torbauten = PackedFloat32Array({_zahlen(torbauten)})
tor_regeln = PackedStringArray({", ".join('"%s"' % r_ for r_ in regeln)})
stein = \"{STEINE.get(mat, 'mauer')}\"""")
    return [(x, z, ux, uz, n) for x, z, ux, uz, n, *_ in toreliste]


WAENDE = {"Material_hell": 1, "Material_mauer": 2, "Material_holz": 3}


def steinbau(name, eltern, x, z, laenge, breite, hoehe, gier=0.0, mat="Material_mauer", dach="Material_dach_schiefer",
             dachhoehe=None, boden=None, kollision=True, art=None, begehbar=False, tuer_hinten=False, zweck=0):
    """Gebäude mit Satteldach (First entlang der Länge), gebaut von burgbau.gd mit Sockel, Gesimsen, Fenstern,
    Tür und Schornstein. boden: Höhe des Erdgeschosses (sonst Gelände). art: 0 Wohnbau, 1 Kirche/Saal, 2 Lager, 3 Palas.
    begehbar: innen hohl mit offener Tür, Geschossdecken, Treppen, Licht und Einrichtung; tuer_hinten: die Tür auf der
    anderen Längsseite. zweck (Einrichtung): 1 Küche, 2 Zeughaus, 3 Palas, 4 Stall, 5 Gesindehaus.
    Gibt die Traufhöhe zurück."""
    a = math.radians(gier)
    ecken = [(x + math.cos(a) * dx + math.sin(a) * dz, z - math.sin(a) * dx + math.cos(a) * dz)
             for dx in (-breite / 2, breite / 2) for dz in (-laenge / 2, laenge / 2)]
    tief = min(H(px, pz) for px, pz in ecken) - 1.5
    b0 = H(x, z) if boden is None else boden
    if art is None:
        art = 1 if hoehe >= 14 and laenge >= 30 else (2 if mat == "Material_holz" else 0)
    werte = [x, z, gier, breite, laenge, b0, tief, hoehe, dachhoehe if dachhoehe is not None else breite * 0.6,
             WAENDE.get(mat, 2), 1 if dach == "Material_dach" else 0, art + ((20 if tuer_hinten else 10) if begehbar else 0) + 100 * zweck]
    N(name, "Node3D", eltern, f"""script = ExtResource("28_burgbau")
gebaeude = PackedFloat32Array({_zahlen(werte)})""")
    return b0 + hoehe


def mauern_verbinden(fang=3.0):
    """Ein freies Mauerende (an dem kein anderes Stück endet), das knapp neben der Ecke eines anderen Mauerrings
    aufhört, wird an diese Ecke gezogen: so stoßen die Wehrgänge aneinander, statt sich halb zu überlappen oder eine
    Engstelle zu lassen. Ändert die Knoten mit "mauern" (und einen Turm genau am alten Ende) nach dem Bau aller Ringe."""
    stuecke = []   # [Knotenindex, Stückindex, werte]
    werte_je = {}
    for k, text in enumerate(knoten):
        m = re.search(r'\nmauern = PackedFloat32Array\(([^)]*)\)', text)
        if not m:
            continue
        w = [float(x) for x in m.group(1).split(",") if x.strip()]
        werte_je[k] = w
        for i in range(0, len(w) - 9, 10):
            if w[i + 9] > 0.5:
                stuecke.append((k, i))

    def ende(k, i, e):
        w = werte_je[k]
        return (w[i + 2 * e], w[i + 2 * e + 1])

    def richtung(k, i):
        (ax, az), (bx, bz) = ende(k, i, 0), ende(k, i, 1)
        l_ = math.hypot(bx - ax, bz - az)
        return ((bx - ax) / l_, (bz - az) / l_, l_) if l_ > 0.01 else (1.0, 0.0, 0.0)

    # Doppelmauern: Zwei Ringe, deren Mauern Rücken an Rücken (Feldseiten entgegengesetzt) dieselbe Grenze ziehen,
    # teilen sich eine Mauer: das niedrigere Stück, das fast ganz von der anderen gedeckt ist, entfällt
    weg = set()
    for (k, i) in stuecke:
        w = werte_je[k]
        ux, uz, l_ = richtung(k, i)
        if l_ < 1.0:
            continue
        (ax, az) = ende(k, i, 0)
        gedeckt = 0.0
        hoechste = -1e9
        for (k2, i2) in stuecke:
            w2 = werte_je[k2]
            if k2 == k or (k2, i2) in weg or w2[i2 + 7] * w[i + 7] + w2[i2 + 8] * w[i + 8] >= 0.0:
                continue
            vx, vz, l2 = richtung(k2, i2)
            if l2 < 1.0 or abs(ux * vx + uz * vz) < 0.97:
                continue
            mx, mz = (w2[i2] + w2[i2 + 2]) / 2, (w2[i2 + 1] + w2[i2 + 3]) / 2
            quer = abs((mx - ax) * -uz + (mz - az) * ux)
            if quer > (w[i + 6] + w2[i2 + 6]) / 2:
                continue
            s0 = (w2[i2] - ax) * ux + (w2[i2 + 1] - az) * uz
            s1 = (w2[i2 + 2] - ax) * ux + (w2[i2 + 3] - az) * uz
            gedeckt += max(0.0, min(l_, max(s0, s1)) - max(0.0, min(s0, s1)))
            hoechste = max(hoechste, w2[i2 + 5])
        if gedeckt > 0.7 * l_ and w[i + 5] <= hoechste:
            weg.add((k, i))
    stuecke = [st for st in stuecke if st not in weg]

    def stoesse(p, ausser):
        return sum(1 for (k, i) in stuecke for e in (0, 1) if (k, i) != ausser and math.dist(ende(k, i, e), p) < 0.05)

    verschoben = []
    teilung = []
    for (k, i) in stuecke:
        for e in (0, 1):
            p = ende(k, i, e)
            if stoesse(p, (k, i)) > 0:
                continue
            bestes = None
            for (k2, i2) in stuecke:
                if k2 == k:
                    continue
                for e2 in (0, 1):
                    q = ende(k2, i2, e2)
                    d = math.dist(p, q)
                    if 0.05 < d < fang and stoesse(q, (k2, i2)) > 0 and (bestes is None or d < bestes[0]):
                        bestes = (d, q)
            if bestes:
                verschoben.append((k, i, e, p, bestes[1]))
                continue
            # sonst: endet es an der Flanke einer anderen Mauer, wird diese dort geteilt (ein Stoß wie ein T)
            for (k2, i2) in stuecke:
                if k2 == k:
                    continue
                w2 = werte_je[k2]
                vx, vz, l2 = richtung(k2, i2)
                (cx, cz) = ende(k2, i2, 0)
                entlang = (p[0] - cx) * vx + (p[1] - cz) * vz
                quer = abs((p[0] - cx) * -vz + (p[1] - cz) * vx)
                if 2.0 < entlang < l2 - 2.0 and quer < w2[i2 + 6] / 2 + 1.0 and abs(w2[i2 + 5] - werte_je[k][i + 5]) <= 3.0:
                    x = (cx + vx * entlang, cz + vz * entlang)
                    teilung.append((k2, i2, x))
                    verschoben.append((k, i, e, p, x))
                    break
    for (k, i, e, p, q) in verschoben:
        w = werte_je[k]
        w[i + 2 * e], w[i + 2 * e + 1] = q
        for j, m_ in enumerate(MAUERSTUECKE):
            if math.dist(m_[1:3], p) < 0.01 or math.dist(m_[3:5], p) < 0.01:
                m_ = list(m_)
                if math.dist(m_[1:3], p) < 0.01:
                    m_[1:3] = q
                else:
                    m_[3:5] = q
                MAUERSTUECKE[j] = tuple(m_)
    # geteilte Stücke (T-Stöße) und entfallene Doppelmauern in die Werte übernehmen
    for k in werte_je:
        w = werte_je[k]
        neu = []
        for i in range(0, len(w) - 9, 10):
            if (k, i) in weg:
                continue
            stueck = w[i:i + 10]
            for (k2, i2, x) in teilung:
                if (k2, i2) == (k, i):
                    neu += stueck[:2] + list(x) + stueck[4:]
                    stueck = list(x) + stueck[2:]
            neu += stueck
        werte_je[k] = neu
    for k, w in werte_je.items():
        text = re.sub(r'\nmauern = PackedFloat32Array\([^)]*\)', "\nmauern = PackedFloat32Array(%s)" % _zahlen(w), knoten[k])
        for (k_, i, e, p, q) in verschoben:
            if k_ != k:
                continue
            m = re.search(r'\ntuerme = PackedFloat32Array\(([^)]*)\)', text)
            if m:
                t = [float(x) for x in m.group(1).split(",") if x.strip()]
                for j in range(0, len(t) - 6, 7):
                    if math.dist((t[j], t[j + 1]), p) < 0.05:
                        t[j], t[j + 1] = q
                text = text.replace(m.group(0), "\ntuerme = PackedFloat32Array(%s)" % _zahlen(t))
        knoten[k] = text
    return verschoben, len(weg), len(teilung)


def wehrgang_netz():
    """Die fertigen Mauerstücke mit Wehrgang (nach mauern_verbinden) und alle Türme, aus den Knoten gelesen:
    Stücke als dict (a, b, oben, dicke, aussen), Türme als (x, z, Radius, oben, rund und hohl)."""
    stuecke, tuerme = [], []
    for text in knoten:
        m = re.search(r'\nmauern = PackedFloat32Array\(([^)]*)\)', text)
        if m and m.group(1).strip():
            w = [float(x) for x in m.group(1).split(",")]
            for i in range(0, len(w) - 9, 10):
                if w[i + 9] > 0.5 and math.dist(w[i:i + 2], w[i + 2:i + 4]) > 0.3:
                    stuecke.append({"a": (w[i], w[i + 1]), "b": (w[i + 2], w[i + 3]), "oben": w[i + 5], "dicke": w[i + 6],
                                    "aussen": (w[i + 7], w[i + 8])})
        m = re.search(r'\ntuerme = PackedFloat32Array\(([^)]*)\)', text)
        if m and m.group(1).strip():
            t = [float(x) for x in m.group(1).split(",")]
            for j in range(0, len(t) - 6, 7):
                tuerme.append((t[j], t[j + 1], t[j + 4], t[j + 3], int(t[j + 5]) != 2))
        m = re.search(r'\ntorbauten = PackedFloat32Array\(([^)]*)\)', text)
        if m and m.group(1).strip():
            t = [float(x) for x in m.group(1).split(",")]
            for j in range(0, len(t) - 9, 10):
                # eckige Türme (Tortürme, Ecktürme): ein Kreis um die Ecken, man geht nicht hindurch
                tuerme.append((t[j], t[j + 1], math.hypot(t[j + 6], t[j + 7]) / 2, t[j + 5], False))
    return stuecke, tuerme


def wehrgang_runde(stuecke, tuerme, start, oben, weit=60.0):
    """Streife auf dem Wehrgang ab dem Punkt start (x, z) auf dem Stück mit der Krone oben: in beide Richtungen bis
    zu weit Meter die Mitte des Wehrgangs entlang, über Fugen (auch Treppen zu höheren oder tieferen Stücken, bis
    12 m) und durch hohle Türme, durch die die Mauer mitten hindurch läuft; Schluss an einem freien Mauerende, an
    einem Turm in einer Ecke, an einem Tor. Gibt (Mitte, vorwärts, rückwärts) als Punktlisten (x, y, z) zurück."""
    def richtung(s):
        (ax, az), (bx, bz) = s["a"], s["b"]
        l_ = math.hypot(bx - ax, bz - az)
        return (bx - ax) / l_, (bz - az) / l_, l_

    def mitte(s):
        # Mitte des Wehrgangs: 0,125 m von der Achse zur Hofseite (zwischen Hofmauer und Brustwehr)
        return -s["aussen"][0] * 0.125, -s["aussen"][1] * 0.125

    def punkt(s, t):
        ux, uz, _ = richtung(s)
        ox, oz = mitte(s)
        return (round(s["a"][0] + ux * t + ox, 2), round(s["oben"] + 0.06, 2), round(s["a"][1] + uz * t + oz, 2))

    s0 = min(stuecke, key=lambda s: abstand_linie([s["a"], s["b"]], *start) + abs(s["oben"] - oben) * 10)
    ux, uz, l0 = richtung(s0)
    t0 = min(max((start[0] - s0["a"][0]) * ux + (start[1] - s0["a"][1]) * uz, 1.0), l0 - 1.0)

    def treppe_moeglich(s, s2):
        """Wie in burgbau.gd: bis 1 m eine Rampe, darüber eine Treppe, mindestens 1,15 m lang je Meter Höhe, auf dem
        tieferen Stück vor dem Körper des höheren"""
        tief, hoch = (s, s2) if s["oben"] <= s2["oben"] else (s2, s)
        dh = hoch["oben"] - tief["oben"]
        if dh <= 1.0:
            return True
        frei = math.dist(tief["a"], tief["b"]) - hoch["dicke"] / 2 - 0.3
        return dh <= 12.0 and frei >= dh * 1.15

    def turm_auf(s):
        """Türme auf dem Stück: (Abstand vom Anfang, Radius, mitten hindurch?)"""
        ux_, uz_, l_ = richtung(s)
        auf = []
        for (tx, tz, r, t_oben, rund) in tuerme:
            if t_oben < s["oben"] + 1.0:
                continue
            entlang = (tx - s["a"][0]) * ux_ + (tz - s["a"][1]) * uz_
            quer = abs((tx - s["a"][0]) * -uz_ + (tz - s["a"][1]) * ux_)
            if -r - 1.0 < entlang < l_ + r + 1.0 and quer < r + s["dicke"] / 2:
                hindurch = rund and quer < 0.6 and r + 1.0 < entlang < l_ - r - 1.0
                auf.append((entlang, r, hindurch))
        return auf

    def weiter(s, vor, besucht):
        """Das Stück, das s an seinem Ende (vor: b, sonst a) am geradesten fortsetzt und erreichbar ist, oder None;
        dazu, ob dort überhaupt ein anderes Stück endet."""
        ux_, uz_, _ = richtung(s)
        sgn = 1.0 if vor else -1.0
        fuge = s["b"] if vor else s["a"]
        beste = None
        nachbar = False
        for s2 in stuecke:
            if s2 is s:
                continue
            for e2 in ("a", "b"):
                if math.dist(s2[e2], fuge) < 0.05:
                    nachbar = True
                    if id(s2) in besucht or not treppe_moeglich(s, s2):
                        continue
                    vx, vz, _ = richtung(s2)
                    d2 = (vx, vz) if e2 == "a" else (-vx, -vz)
                    gerade = d2[0] * ux_ * sgn + d2[1] * uz_ * sgn
                    if gerade > -0.2 and (beste is None or gerade > beste[0]):
                        beste = (gerade, s2, e2 == "a")
        return beste, nachbar

    def lauf(vor):
        punkte = []
        s, t, rest = s0, t0, weit
        besucht = {id(s0)}
        while True:
            ux_, uz_, l_ = richtung(s)
            sgn = 1.0 if vor else -1.0
            beste, nachbar = weiter(s, vor, besucht)
            # Schluss vor dem Ende: an einem freien Ende, einem Tor oder einem zu hohen Nachbarn (dessen Körper bis in
            # die Ecke reicht) ...
            halt = None if beste else (l_ if vor else 0.0) - sgn * (3.0 if nachbar else 1.2)
            # ... oder vor einem Turm, durch den man nicht hindurch kann
            for (e, r, hindurch) in turm_auf(s):
                if (e - t) * sgn > 0 and not hindurch:
                    grenze = e - sgn * (r + 1.2)
                    if halt is None or (grenze - halt) * sgn < 0:
                        halt = grenze
            if halt is not None and (halt - t) * sgn < 0.3:
                return punkte                  # schon da
            ziel = halt if halt is not None else (l_ if vor else 0.0)
            weg = abs(ziel - t)
            if weg >= rest:
                punkte.append(punkt(s, t + sgn * rest))
                return punkte
            rest -= weg
            if halt is not None:
                punkte.append(punkt(s, halt))
                return punkte
            # an der Fuge weiter auf dem nächsten Stück; Eckpunkt: Schnitt der beiden Mittellinien
            _, s2, vor2 = beste
            fuge = s["b"] if vor else s["a"]
            ox, oz = mitte(s)
            px, pz = fuge[0] + ox, fuge[1] + oz
            vx, vz, l2 = richtung(s2)
            ox2, oz2 = mitte(s2)
            qx, qz = fuge[0] + ox2, fuge[1] + oz2
            nenner = ux_ * vz - uz_ * vx
            if abs(nenner) > 0.17:
                k_ = ((qx - px) * vz - (qz - pz) * vx) / nenner
                px, pz = px + ux_ * k_, pz + uz_ * k_
            punkte.append((round(px, 2), round(max(s["oben"], s2["oben"]) + 0.06, 2), round(pz, 2)))
            besucht.add(id(s2))
            s, vor = s2, vor2
            t = 0.0 if vor else l2

    return punkt(s0, t0), lauf(True), lauf(False)


def treppenturm(name, eltern, punkt, r=5.0, mat="Material_mauer"):
    """Achteckiger Treppenturm (turm.gd) an einer Fuge, an der zwei Wehrgänge zu weit auseinander liegen für eine
    Treppe: Die beiden Mauern enden an seiner Wand (samt ihrer Überlappung), je eine Tür auf Höhe ihres Wehrgangs,
    innen eine Wendelrampe (zwei Windungen je Geschoss), oben eine Plattform mit Zinnen. Nach mauern_verbinden
    aufrufen. Gibt die Höhen der beiden Wehrgänge zurück."""
    apothem = r * math.cos(math.pi / 8)
    enden = []      # (Knoten, Stückindex, Ende, Richtung vom Turm weg, Krone, Dicke)
    for k, text in enumerate(knoten):
        m = re.search(r'\nmauern = PackedFloat32Array\(([^)]*)\)', text)
        if not m or not m.group(1).strip():
            continue
        w = [float(x) for x in m.group(1).split(",")]
        for i in range(0, len(w) - 9, 10):
            for e in (0, 1):
                if math.dist(w[i + 2 * e:i + 2 * e + 2], punkt) < 0.05:
                    ox, oz = w[i + 2 * (1 - e)], w[i + 2 * (1 - e) + 1]
                    l_ = math.dist((ox, oz), punkt)
                    enden.append((k, i, e, ((ox - punkt[0]) / l_, (oz - punkt[1]) / l_), w[i + 5], w[i + 6]))
    assert len(enden) == 2, f"Treppenturm {name}: an {punkt} enden {len(enden)} Mauerstücke"
    for (k, i, e, (dx, dz), oben, dicke) in enden:
        m = re.search(r'\nmauern = PackedFloat32Array\(([^)]*)\)', knoten[k])
        w = [float(x) for x in m.group(1).split(",")]
        # der Mauerkörper überlappt um die halbe Dicke über das Ende hinaus: er soll in der Turmwand enden
        ab = apothem + dicke / 2 - 0.3
        w[i + 2 * e], w[i + 2 * e + 1] = punkt[0] + dx * ab, punkt[1] + dz * ab
        knoten[k] = knoten[k].replace(m.group(0), "\nmauern = PackedFloat32Array(%s)" % _zahlen(w))
    enden.sort(key=lambda x: x[4])
    tief, hoch = enden[0][4] + 0.06, enden[1][4] + 0.06
    winkel = [math.degrees(math.atan2(dz, dx)) for (_, _, _, (dx, dz), _, _) in enden]
    grund = min(H(punkt[0] + dx * r, punkt[1] + dz * r) for dx in (-1, 0, 1) for dz in (-1, 0, 1)) - 0.5
    # Geschosse: unten ein Sockel bis an den tieferen Wehrgang, dann so viele gleich hohe wie nötig (je höchstens
    # 6,5 m) bis an den höheren, darüber noch eines bis an die Plattform. Jedes mindestens 5,6 m hoch: die Rampe
    # windet sich zweimal je Geschoss, darunter braucht man Kopffreiheit.
    stock = max(1, math.ceil((hoch - tief) / 6.5))
    je = max((hoch - tief) / stock, 5.6)
    hoehen = [min(grund - tief, -5.6)] + [(hoch - tief) * k / stock for k in range(stock + 1)] + [hoch - tief + je]
    nummern = list(range(-1, stock + 1))
    N(name, "Node3D", eltern, f"""transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {punkt[0]:.3f}, {tief:.3f}, {punkt[1]:.3f})
script = ExtResource("14_turm")
ebenen_nummern = PackedInt32Array({", ".join(str(n) for n in nummern)})
ebenen_namen = PackedStringArray({", ".join('"Treppe"' for _ in nummern)})
boden_hoehen = PackedFloat32Array({_zahlen(hoehen)})
aussen_radien = PackedFloat32Array({_zahlen([r] * len(nummern))})
wandstaerken = PackedFloat32Array({_zahlen([1.0] * len(nummern))})
eingaenge = PackedVector2Array(0, {winkel[0]:.2f}, {stock}, {winkel[1]:.2f})
eingang_breite = 1.8
eingang_hoehe = 2.7
achteck_winkel = {winkel[0]:.2f}
treppen_winkel = {(winkel[0] + winkel[1]) / 2 + 180:.2f}
windungen = 2
treppenhaus_radius = 2.25
saeulen_radius = 0.3
mit_schildern = false
material_wand = ExtResource("{mat}")
material_boden = ExtResource("Material_boden")
material_rampe = ExtResource("Material_holz")""")
    return tief, hoch
